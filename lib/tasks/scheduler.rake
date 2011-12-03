desc "This task is called by the Heroku scheduler add-on"
task :update_reports => :environment do
    puts "Updating reports..."
    Report.update
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
  p URI("http://210.138.109.139").read(100) rescue nil
end
