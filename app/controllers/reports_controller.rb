class ReportsController < ApplicationController
  # GET /reports
  # GET /reports.json
  def index
    @reports = Report.order('datetime desc').limit(100).includes(:server).all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @reports }
    end
  end

  def current
    last = Report.last
    last_modified = last ? last.updated_at.utc : Time.at(0)
    interval = 600 # cron interval
    margin = 30 # margin for cron's processing
    expires_in (last_modified.to_i - Time.now.to_i + interval - margin) % interval
    if stale?(:last_modified => last_modified, :etag => last_modified.to_s, :public => true)
      @reports = Report.includes(:server).order('reports.branch DESC, servers.ordinal ASC, reports.option ASC').
        where("reports.datetime > (now() - interval '14 days')").
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
