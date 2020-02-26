class ReportsController < ApplicationController
  # Put server name and branch which you want to hide without waiting for 14 days
  DEPRECATED_SERVER_BRANCHES = {
    # report_name => [branch]
    # ex) 'Debian 8.8 x86_64' => ['master']
    'CentOS 6.9 x86_64' => ['master'],
  }

  # GET /reports
  # GET /reports.json
  def index
    @use_opacity = false
    @reports = Report.order('datetime DESC').limit(300).includes(:server)

    str = params[:branch].to_s[/\A(?:trunk|master|[\d.]+)\z/]
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
      @reports = Report.includes(:server).order('reports.branch DESC, servers.ordinal ASC, reports.option ASC').
        references(:server).
        where("reports.datetime > (now() - interval '14 days')").
        where('reports.id IN (SELECT MAX(R.id) FROM reports R GROUP BY R.server_id, R.branch, R.option)').all
      @reports = @reports.to_a.delete_if{|report| report.server.nil? }

      @reports = filter_deprecated(@reports)

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

  private

  def filter_deprecated(reports)
    reports.select do |report|
      deprecated_branches = DEPRECATED_SERVER_BRANCHES.fetch(report.server&.name, [])
      report.branch != 'trunk' && deprecated_branches.exclude?(report.branch)
    end
  end
end
