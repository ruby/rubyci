class SearchController < ApplicationController
  PER_PAGE = 50
  MAX_PAGE = 200

  # GET /search
  # Searches log excerpts of failed builds. Reports are narrowed by the
  # indexed columns (server_id, branch, datetime, revision) first, then
  # matched against log_excerpts.content (trigram GIN index on PostgreSQL).
  def index
    @q = params[:q].to_s.strip
    @server_id = params[:server].to_s[/\A\d+\z/]
    @branch = params[:branch].to_s.strip
    @revision = params[:revision].to_s.strip
    @from = parse_time(params[:from])
    @to = parse_time(params[:to], end_of_day: true)
    # to_s first: params[:page] is an Array for ?page[]=1, which has no to_i.
    # Clamping also keeps OFFSET within range for absurd page numbers.
    @page = params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    @servers = Server.order(:ordinal).to_a

    @searched = @q.present? || @revision.present? || @branch.present? ||
      @server_id.present? || @from || @to
    unless @searched
      @reports = []
      return
    end

    reports = Report.joins(:log_excerpt).includes(:server, :log_excerpt).
      order("reports.datetime DESC")
    reports = reports.where(server_id: @server_id) if @server_id
    reports = reports.where(branch: @branch) if @branch.present?
    reports = reports.where("reports.datetime >= ?", @from) if @from
    reports = reports.where("reports.datetime <= ?", @to) if @to
    if @revision.present?
      reports = reports.where("reports.revision LIKE ?", "#{Report.sanitize_sql_like(@revision)}%")
    end
    reports = reports.merge(LogExcerpt.content_match(@q)) if @q.present?

    page = reports.limit(PER_PAGE + 1).offset((@page - 1) * PER_PAGE).to_a
    @has_next = page.size > PER_PAGE
    @reports = page.first(PER_PAGE)
  end

  private

  def parse_time(str, end_of_day: false)
    return nil if str.blank?
    date = Date.parse(str) rescue nil
    return nil unless date
    time = Time.utc(date.year, date.month, date.day)
    end_of_day ? time + 86399 : time
  end
end
