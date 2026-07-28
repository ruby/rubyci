desc "This task is called by the Heroku scheduler add-on"
task :fetch_recent => :environment do
    puts "Fetching recent results..."
    Report.fetch_recent
    puts "done."
end

desc "This task is called by the Heroku scheduler add-on"
task :post_recent => :environment do
    puts "Posting recent results..."
    Report.post_recent
    puts "done."
end

desc "inspect the environment"
task :inspect_env => :environment do
  require 'rbconfig'
  require 'open-uri'
  require 'pp'
  puts "inspecting..."
  p `hostname`
  p `uname -a`
  Dir["/etc/{*_version,*-release}"].each do |path|
    p path
    puts IO.read(path)
  end
  pp ENV
  p URI("http://www.yahoo.co.jp").read(100) rescue nil
end

desc "sync server settings"
task :sync_servers => :environment do
  require 'open-uri'
  data = JSON(URI('http://rubyci.org/servers.json').read)
  servers = {}
  Server.all.each do |s|
    servers[s.uri] = s
  end
  data.each do |x|
    unless s = servers.delete(x['uri'])
      s = Server.new
      s.uri = x['uri']
    end
    s.name = x['name']
    s.ordinal = x['ordinal']
    begin
      s.save!
    rescue => e
      if e.message == "Validation failed: Ordinal has already been taken"
        STDERR.puts e.message
        s.ordinal = rand * 100
        s.save!
        STDERR.puts "Validation failer repaired"
      else
        raise
      end
    end
  end
  servers.each_value do |s|
    s.destroy
  end
end
