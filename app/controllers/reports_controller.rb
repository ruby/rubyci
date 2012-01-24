class ReportsController < ApplicationController
  caches_page :current

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
    last = Report.last.updated_at.utc
    interval = 600 # cron interval
    margin = 30 # margin for cron's processing
    expires_in (last.to_i - Time.now.to_i + interval - margin) % interval
    if stale?(:last_modified => last, :etag => last.to_s, :public => true)
      @reports = Report.includes(:server).order('reports.branch DESC, servers.name').
        where('reports.id = (SELECT MAX(id) FROM reports R
         WHERE reports.server_id = R.server_id AND reports.branch = R.branch)').all
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

=begin
  REG_RCNT = /name="(\d+T\d{6}Z).*?a>\s*(\S.*)<br/
  # POST /reports/receive_recent
  def receive_recent
    server_id = request.params['server_id'].to_i
    branch = request.params['branch'].to_s
    body = request.params['body'].to_s

    unless server_id > 0 && branch.size > 0 && body.size > 0
      render :status => 400, :text => request.POST
      return
    end
    if branch !~ /\A(?:trunk|[2-9]|1\.9\.[2-9])\z/
      render :status => 200, :json => '[]'
      return
    end

    latest = Report.where(server_id: server_id, branch: branch).last
    if latest
      threshold = latest.datetime
      threshold = Time.now if threshold < Time.now - 7*24*3600
    else
      threshold = Time.now
    end

    ary = []
    Report.scan_recent(server, branch, body, ary)
    ary.sort_by!{|h|h[:datetime]}
    results = []
    Report.transaction do
      ary.each do |x|
        results << Report.create!(x)
      end
    end
    render :json => results
  end

  # GET /reports/new
  # GET /reports/new.json
  def new
    @report = Report.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @report }
    end
  end

  # GET /reports/1/edit
  def edit
    @report = Report.find(params[:id])
  end

  # POST /reports
  # POST /reports.json
  def create
    @report = Report.new(params[:report])

    respond_to do |format|
      if @report.save
        format.html { redirect_to @report, notice: 'Report was successfully created.' }
        format.json { render json: @report, status: :created, location: @report }
      else
        format.html { render action: "new" }
        format.json { render json: @report.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /reports/1
  # PUT /reports/1.json
  def update
    @report = Report.find(params[:id])

    respond_to do |format|
      if @report.update_attributes(params[:report])
        format.html { redirect_to @report, notice: 'Report was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @report.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /reports/1
  # DELETE /reports/1.json
  def destroy
    @report = Report.find(params[:id])
    @report.destroy

    respond_to do |format|
      format.html { redirect_to reports_url }
      format.json { head :ok }
    end
  end
=end
end
