namespace :log_excerpts do
  desc "Backfill log excerpts from S3. FROM/TO (date, default last 1 year), START_ID to force resume point, SLEEP (default 0.1)"
  task :backfill => :environment do
    from = ENV["FROM"] ? Time.parse(ENV["FROM"]) : 1.year.ago
    to = ENV["TO"] ? Time.parse(ENV["TO"]) : Time.now
    interval = (ENV["SLEEP"] || 0.1).to_f

    scope = Report.joins(:server).
      where(datetime: from..to).
      where.not(ltsv: nil).
      where("ltsv NOT LIKE '%result:success%'").
      where("servers.uri LIKE 'https://rubyci.s3.amazonaws.com/%'")

    start_id = ENV["START_ID"]&.to_i ||
      LogExcerpt.joins(:report).where(reports: { datetime: from..to }).maximum(:report_id) ||
      0
    remaining = scope.where("reports.id > ?", start_id)
    total = remaining.count
    puts "backfilling #{total} reports (datetime #{from}..#{to}, report_id > #{start_id})"

    done = 0
    remaining.includes(:server).find_each(batch_size: 100) do |report|
      begin
        LogExcerpt.capture(report)
      rescue => e
        warn "report #{report.id}: #{e.class}: #{e.message}"
      end
      done += 1
      puts "#{done}/#{total} (report_id=#{report.id})" if done % 100 == 0
      sleep interval
    end
    puts "done: #{done}/#{total}"
  end

  desc "Delete log excerpts older than KEEP_DAYS (default 366) days"
  task :prune => :environment do
    keep_days = (ENV["KEEP_DAYS"] || 366).to_i
    cutoff = keep_days.days.ago
    scope = LogExcerpt.where(report_id: Report.where("datetime < ?", cutoff).select(:id))
    deleted = 0
    scope.in_batches(of: 10_000) do |batch|
      deleted += batch.delete_all
    end
    puts "deleted #{deleted} log excerpts older than #{cutoff}"
  end
end
