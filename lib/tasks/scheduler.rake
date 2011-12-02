desc "This task is called by the Heroku scheduler add-on"
task :update_reports => :environment do
    puts "Updating reports..."
    Report.update
    puts "done."
end

desc "mogok test"
task :mogok_test => :environment do
  require 'rbconfig'
  puts "mogok test"
  p `hostname`
  p ENV['HOSTNAME']
  p `uname -a`
  r = File.join(
    RbConfig::CONFIG['bindir'],
    RbConfig::CONFIG['ruby_install_name'] + RbConfig::CONFIG['EXEEXT']).
    sub(/.*\s.*/m, '"\&"')
    p r
  puts `/opt/ruby-1.9.2-p180/bin/ruby /app/.bundle/ruby/1.9.1/bin/rake assets:precompile RAILS_ENV=production RAILS_GROUPS=assets`
  p `#{r} -v`
  p system(r, '/app/.bundle/ruby/1.9.1/bin/rake', 'assets:precompile')
end
