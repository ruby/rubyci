require 'net/http'
require 'zlib'
require 'stringio'

class LogExcerpt < ApplicationRecord
  belongs_to :report

  MAX_CONTENT_BYTES = 100_000

  # Fetch fail.txt and diff.txt from S3 for the report and store them as a
  # searchable excerpt. Creates an empty-content row when nothing is available
  # (missing or empty objects) so that backfill can resume by max report_id.
  # Network errors are raised to the caller.
  def self.capture(report)
    return nil unless report.server&.rubyci_s3?
    content = fetch_content(report)
    excerpt = find_or_initialize_by(report_id: report.id)
    excerpt.content = content
    excerpt.save!
    excerpt
  end

  def self.fetch_content(report)
    sections = [report.failtxt_uri, report.difftxt_uri].filter_map do |uri|
      body = fetch_text(uri)
      body unless body.nil? || body.empty?
    end
    return "" if sections.empty?
    # Budget each section separately, otherwise a fail.txt over the limit
    # crowds the diff out entirely. A section under budget donates its
    # remainder to the other one. The separators come out of the budget so
    # the joined result still fits in MAX_CONTENT_BYTES.
    budget = (MAX_CONTENT_BYTES - (sections.size - 1)) / sections.size
    slack = sections.sum { |s| [budget - s.bytesize, 0].max }
    sections.map { |s| truncate_bytes(s, budget + slack) }.join("\n")
  end

  # GET a gzipped text file. Returns nil on 404. S3 serves these either with
  # Content-Encoding: gzip (Net::HTTP inflates the body) or as raw gzip bytes.
  def self.fetch_text(uri)
    uri = URI(uri)
    res = Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 30, use_ssl: uri.scheme == "https") do |h|
      h.get(uri.path)
    end
    return nil if res.code == "404"
    res.value
    body = res.body
    begin
      body = Zlib::GzipReader.new(StringIO.new(body)).read
    rescue Zlib::Error
    end
    body.force_encoding(Encoding::UTF_8).scrub("?").tr("\0", "")
  end

  def self.truncate_bytes(str, max)
    return str if str.bytesize <= max
    str.byteslice(0, max).scrub("")
  end

  # Substring match on content. On PostgreSQL the trigram GIN index makes
  # ILIKE efficient; SQLite (development/test) falls back to plain LIKE.
  def self.content_match(query)
    operator = defined?(SQLite3) ? "LIKE" : "ILIKE"
    # explicit ESCAPE: SQLite's LIKE has no default escape character
    where("log_excerpts.content #{operator} ? ESCAPE '\\'", "%#{sanitize_sql_like(query)}%")
  end

  def matching_line(query)
    return nil if query.blank?
    q = query.downcase
    line = content.each_line.find { |l| l.downcase.include?(q) }
    line&.strip&.truncate(200)
  end
end
