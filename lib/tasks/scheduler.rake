desc "This task is called by the Heroku scheduler add-on"
task :update_reports => :environment do
    puts "Updating reports..."
    Report.update
    puts "done."
end
