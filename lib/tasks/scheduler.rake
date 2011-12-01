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
  p File.join(
    RbConfig::CONFIG['bindir'],
    RbConfig::CONFIG['ruby_install_name'] + RbConfig::CONFIG['EXEEXT']).
    sub(/.*\s.*/m, '"\&"')
end
