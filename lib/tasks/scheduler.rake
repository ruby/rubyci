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

desc "fetch old logfiles"
task :fetch_logfile => :environment do
  Report.
    joins("LEFT OUTER JOIN logfiles AS l1 ON
          reports.id = l1.report_id AND l1.ext='log.txt'").
    joins("LEFT OUTER JOIN logfiles AS l2 ON
          reports.id = l2.report_id AND l2.ext='diff.txt'").
    joins("LEFT OUTER JOIN logfiles AS l3 ON
          reports.id = l2.report_id AND l3.ext='log.html'").
    joins("LEFT OUTER JOIN logfiles AS l4 ON
          reports.id = l4.report_id AND l4.ext='diff.html'").
    where('l1.report_id IS NULL OR l2.report_id IS NULL OR
          l3.report_id IS NULL OR l4.report_id IS NULL').
    where('reports.server_id = 4').
    select(['reports.*',
            'l1.id AS l1id', 'l2.id AS l2id', 'l3.id AS l3id', 'l4.id AS l4id']).
    find_each do |r|
    t = r.datetime.strftime('%Y%m%dT%H%M%SZ')
    lids = [r.l1id, r.l2id, r.l3id, r.l4id]
    %w[log.txt diff.txt log.html diff.html].each_with_index do |ext, i|
      next if lids[i]
      uri = "#{r.server.uri}ruby-#{r.branch}/log/#{t}.#{ext}.gz"
      puts uri
      begin
        data = URI(uri).read
        Logfile.create(report_id: r.id, ext: ext, data: data)
      rescue => e
        p e
      end
    end
  end
end
