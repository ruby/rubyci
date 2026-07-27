namespace :reports do
  desc "Backfill reports.revision with full commit SHA extracted from ltsv"
  task :backfill_revision => :environment do
    scope = Report.where(revision: nil).where.not(ltsv: nil)
    total = scope.count
    puts "#{total} reports to scan"
    scanned = 0
    updated = 0
    scope.find_each do |report|
      scanned += 1
      sha = Report.extract_full_sha(report.ltsv)
      if sha
        report.update_column(:revision, sha)
        updated += 1
      end
      puts "#{scanned}/#{total} scanned, #{updated} updated" if scanned % 1000 == 0
    end
    puts "done: #{scanned} scanned, #{updated} updated"
  end
end
