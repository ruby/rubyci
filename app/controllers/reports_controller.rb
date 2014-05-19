class ReportsController < ApplicationController
  # GET /reports
  # GET /reports.json
  def index
    @use_opacity = false
    orderstr = defined?(SQLite3) ? 'datetime(datetime) DESC' : 'datetime DESC'
    @reports = Report.order(orderstr).limit(300).includes(:server)

    str = params[:branch].to_s[/\A(?:trunk|[\d.]+)\z/]
    @reports = @reports.where(branch: str) if str

    str = params[:result].to_s[/\A(?:success|failure)\z/]
    @reports = @reports.where(Report.arel_table[:ltsv].matches("%\tresult:#{str}\t%")) if str

    @reports = @reports.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @reports }
    end
  end

  def current
    @use_opacity = true
    last = Report.last
    last_modified = last ? last.updated_at.utc : Time.at(0)
    interval = 600 # cron interval
    margin = 30 # margin for cron's processing
    expires_in (last_modified.to_i - Time.now.to_i + interval - margin) % interval
    if stale?(:last_modified => last_modified, :etag => last_modified.to_s, :public => true)
      dt2weeksago = defined?(SQLite3) ? "datetime('now', '-14 days')" : "(now() - interval '14 days')"
      @reports = Report.includes(:server).order('reports.branch DESC, servers.ordinal ASC, reports.option ASC').
        where("reports.datetime > #{dt2weeksago}").
        where('reports.id IN (SELECT MAX(R.id) FROM reports R GROUP BY R.server_id, R.branch, R.option)').all
      render 'index'
    end
  end

  # GET /reports/1
  # GET /reports/1.json
  def show
    @report = Report.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @report }
    end
  end
end
