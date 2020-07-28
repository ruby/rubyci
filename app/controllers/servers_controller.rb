class ServersController < ApplicationController
  before_action :auth, except: [:index, :show]

  # GET /servers
  # GET /servers.json
  def index
    @servers = Server.order(:ordinal).all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @servers }
    end
  end

  # GET /servers/1
  # GET /servers/1.json
  def show
    @server = Server.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @server }
    end
  end

  # GET /servers/new
  # GET /servers/new.json
  def new
    @server = Server.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @server }
    end
  end

  # GET /servers/1/edit
  def edit
    @server = Server.find(params[:id])
  end

  # POST /servers
  # POST /servers.json
  def create
    @server = Server.new(server_params)

    respond_to do |format|
      if @server.save
        format.html { redirect_to @server, notice: 'Server was successfully created.' }
        format.json { render json: @server, status: :created, location: @server }
      else
        format.html { render action: "new" }
        format.json { render json: @server.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /servers/1
  # PUT /servers/1.json
  def update
    @server = Server.find(params[:id])

    respond_to do |format|
      if @server.update_attributes(server_params)
        format.html { redirect_to @server, notice: 'Server was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @server.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /servers/1
  # DELETE /servers/1.json
  def destroy
    @server = Server.find(params[:id])
    @server.destroy

    respond_to do |format|
      format.html { redirect_to servers_url }
      format.json { head :ok }
    end
  end

  def moveup
    servers = Server.order(:ordinal).all
    idx = params[:id].to_i
    idx = servers.find_index{|x| x.id == idx }
    raise ActionController::BadRequest, 'invalid id param' unless idx
    case idx
    when 0
      # nop
    when 1
      pre = servers[idx-1]
      cur = servers[idx]
      cur.ordinal = pre.ordinal - 1
    else
      pre2 = servers[idx-2]
      pre = servers[idx-1]
      cur = servers[idx]
      cur.ordinal = (pre2.ordinal + pre.ordinal) / 2
    end

    respond_to do |format|
      if cur&.save
        format.html { redirect_to servers_url }
        format.json { head :ok }
      else
        format.html { redirect_to servers_url }
        format.json { head :ng }
      end
    end
  end

  def movedown
    servers = Server.order(:ordinal).all
    idx = params[:id].to_i
    idx = servers.find_index{|x| x.id == idx }
    raise ActionController::BadRequest, 'invalid id param' unless idx
    case idx - servers.length
    when -1
      # nop
    when -2
      cur = servers[idx]
      nex = servers[idx+1]
      cur.ordinal = nex.ordinal + 1
    else
      cur = servers[idx]
      nex = servers[idx+1]
      nex2 = servers[idx+2]
      cur.ordinal = (nex.ordinal + nex2.ordinal) / 2
    end

    respond_to do |format|
      if cur&.save
        format.html { redirect_to servers_url }
        format.json { head :ok }
      else
        format.html { redirect_to servers_url }
        format.json { head :ng }
      end
    end
  end

  private
  def auth
    authenticate_or_request_with_http_basic do |user, pass|
      ENV['ROOT_PASSWORD'] && user == 'root' && pass == ENV['ROOT_PASSWORD']
    end
  end

  def server_params
    params.require(:server).permit(:name, :arch, :os, :version, :uri, :ordinal)
  end
end
