desc "This task is called by the Heroku scheduler add-on"
task :update_reports => :environment do
    puts "Updating reports..."
    Report.update
    puts "done."
end

desc "mogok test"
task :mogok_test => :environment do
  require 'rbconfig'
  require 'open-uri'
  puts "mogok test"
  p `uname -a`
  p URI("http://210.138.109.139").read
  puts `/opt/ruby-1.9.2-p180/bin/ruby /app/.bundle/ruby/1.9.1/bin/rake assets:precompile RAILS_ENV=production RAILS_GROUPS=assets --trace`
  p `#{r} -v`
  p system(r, '/app/.bundle/ruby/1.9.1/bin/rake', 'assets:precompile')
end
