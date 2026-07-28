namespace :log_excerpts do
  desc "Backfill log excerpts from S3. FROM/TO (date, default last 1 year), START_ID to force resume point, SLEEP (default 0.1), FORCE=1 to refetch reports that already have an excerpt"
  task :backfill => :environment do
    from = ENV["FROM"] ? Time.parse(ENV["FROM"]) : 1.year.ago
    to = ENV["TO"] ? Time.parse(ENV["TO"]) : Time.now
    interval = (ENV["SLEEP"] || 0.1).to_f
    start_id = ENV["START_ID"]&.to_i

    scope = Report.joins(:server).
      where(datetime: from..to).
      where.not(ltsv: nil).
      where("ltsv NOT LIKE '%result:success%'").
      where("servers.uri LIKE 'https://rubyci.s3.amazonaws.com/%'")

    # Resume by skipping reports that already have an excerpt. Using the max
    # captured report_id instead would skip everything, because scan_recent_ltsv
    # captures new failures as they arrive and that id is always the newest one.
    scope = scope.where.missing(:log_excerpt) unless ENV["FORCE"]
    scope = scope.where("reports.id > ?", start_id) if start_id
    total = scope.count
    puts "backfilling #{total} reports (datetime #{from}..#{to})"

    done = 0
    scope.includes(:server).find_each(batch_size: 100) do |report|
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
