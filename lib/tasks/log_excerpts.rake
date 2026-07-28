module LogExcerptTaskEnv
  module_function

  # UTC to match reports.datetime, which Report.scan_recent_ltsv stores as UTC.
  def time(key, default)
    value = ENV[key].presence or return default
    date = begin
      Date.strptime(value, "%Y-%m-%d")
    rescue Date::Error
      abort "#{key} must be a date like 2026-07-20 (UTC), got #{value.inspect}"
    end
    Time.utc(date.year, date.month, date.day)
  end

  def integer(key, default)
    value = ENV[key].presence or return default
    Integer(value) rescue abort("#{key} must be an integer, got #{value.inspect}")
  end

  def float(key, default)
    value = ENV[key].presence or return default
    Float(value) rescue abort("#{key} must be a number of seconds, got #{value.inspect}")
  end
end

namespace :log_excerpts do
  desc "Backfill log excerpts from S3. FROM/TO (UTC date, default last 1 year), START_ID to force resume point, SLEEP seconds between reports (default 0.1), FORCE=1 to refetch reports that already have an excerpt"
  task :backfill => :environment do
    from = LogExcerptTaskEnv.time("FROM", 1.year.ago)
    to = LogExcerptTaskEnv.time("TO", Time.now)
    interval = LogExcerptTaskEnv.float("SLEEP", 0.1)
    start_id = LogExcerptTaskEnv.integer("START_ID", nil)

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
    puts "backfilling #{total} reports (datetime #{from}..#{to}, sleep #{interval}s#{start_id ? ", report_id > #{start_id}" : ""}#{ENV["FORCE"] ? ", forced" : ""})"

    started = Time.now
    captured = empty = failed = 0
    failed_ids = []
    scope.includes(:server).find_each(batch_size: 100) do |report|
      begin
        excerpt = LogExcerpt.capture(report)
        excerpt&.content.presence ? captured += 1 : empty += 1
      rescue => e
        failed += 1
        failed_ids << report.id
        warn "report #{report.id} (#{report.failtxt_uri}): #{e.class}: #{e.message}"
      end
      done = captured + empty + failed
      puts "#{done}/#{total} (report_id=#{report.id}, #{(Time.now - started).round}s elapsed)" if done % 100 == 0
      sleep interval
    end

    puts "done in #{(Time.now - started).round}s: #{captured} captured, #{empty} empty, #{failed} failed"
    unless failed.zero?
      warn "failed report ids: #{failed_ids.join(", ")}"
      abort "backfill finished with #{failed} failures"
    end
  end

  desc "Delete log excerpts whose report datetime is older than KEEP_DAYS (default 366) days. DRY_RUN=1 to only count."
  task :prune => :environment do
    keep_days = LogExcerptTaskEnv.integer("KEEP_DAYS", 366)
    abort "KEEP_DAYS must be at least 1, got #{keep_days}" if keep_days < 1
    cutoff = keep_days.days.ago
    scope = LogExcerpt.where(report_id: Report.where("datetime < ?", cutoff).select(:id))

    if ENV["DRY_RUN"]
      puts "would delete #{scope.count} log excerpts of reports older than #{cutoff}"
      next
    end

    deleted = 0
    scope.in_batches(of: 10_000) do |batch|
      deleted += batch.delete_all
      puts "deleted #{deleted} ..."
    end
    puts "deleted #{deleted} log excerpts of reports older than #{cutoff}"
    puts "note: disk space returns via autovacuum; VACUUM FULL is needed to reclaim it immediately"
  end
end
