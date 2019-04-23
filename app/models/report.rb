require 'net/http'
require 'uri'
require 'open-uri'
require 'chkbuild-ruby-info'
require "tempfile"

class Report < ApplicationRecord
  belongs_to :server
  validates :server_id, :presence => true
  validates :revision, :numericality => { :only_integer => true }, allow_nil: true
  validates :datetime, :uniqueness => { :scope => [:server_id, :branch] }
  validates :branch, :presence => true
  validates :summary, :presence => true

  def revision
    rev = meta["ruby_rev"]
    return rev if rev
    rev = meta[meta_ruby_repo_key]
    return rev[0, 10] if rev
    nil
  end

  def revisionuri
    if !revision
      nil
    elsif revision.start_with?('r')
      "https://svn.ruby-lang.org/cgi-bin/viewvc.cgi?view=revision&revision=#{revision}"
    else
      "https://github.com/ruby/ruby/commit/#{revision}"
    end
  end

  def meta_ruby_repo_key
    svnpath = branch == 'trunk' ? branch : "branches/#{branch.tr('-.', '_')}"
    [
      %Q["http\\x3A//svn.ruby-lang.org/repos/ruby/#{svnpath}"],
      %Q[http://svn.ruby-lang.org/repos/ruby/#{svnpath}],
      %Q["https\\x3A//github.com/ruby/ruby"],
      %Q[https://github.com/ruby/ruby],
    ].find do |key|
      if meta.include?(key)
        return key
      end
    end
    nil
  end

  def dt
    datetime.strftime("%Y%m%dT%H%M%SZ")
  end

  def jstdt
    (datetime + 32400).strftime("%Y-%m-%d %H:%M:%S +0900")
  end

  def sjstdt
    (datetime + 32400).strftime("%m-%d %H:%M")
  end

  def patchlevel
    summary[/ ruby \d+\.\d+\.\d+(p\d+) /, 1]
  end

  def build
    summary[/(\d*failed)\((?:svn|make|miniruby)[^)]*\)/]
  end

  def btest
    /failed\(btest/ =~ summary ? 'BF' : summary[/ (\d+)BFail /, 1] ? $1+'BF' : nil
  end

  def testknownbug
    summary[/ KB(\d+F\d+E) /, 1]
  end

  def test
    t = /failed\(test\./ =~ summary ? 'F' : summary[/ (\d+)NotOK /, 1] ? $1+'F' : nil
    a = [btest, testknownbug, t]
    a.compact!
    a.empty? ? nil : a.join(' ')
  end

  def testall
    summary[/ (\d+F\d+E(?:\d+S)?) /, 1] || summary[/(\d*failed)\(test-all/, 1]
  end

  def rubyspec
    summary[/ rubyspec:(\d+F\d+E) /, 1] || summary[/(failed)\(git-rubyspec/, 1] || summary[/(\d*failed)\(rubyspec\/\)/, 1]
  end

  def shortsummary
    summary[/^[^\x28]+(?:\s*\([^\x29]*\)|\s*\[[^\x5D]*\])*\s*(\S.*?) \(/, 1]
  end

  def diffstat
    summary[/((?:no )?diff[^)>]*)/, 1]
  end

  def depsuffixed_name
    if /vc/ =~ server.uri
      # mswin
      "ruby-#{branch_opts}"
    else
      ltsv ? ltsv[/depsuffixed_name:([^\t]+)/, 1] : option ? "#{branch}-#{option}" : branch
    end
  end

  def branch_opts
    option ? "#{branch}-#{option}" : branch
  end

  def loguri
    server.uri.chomp('/') + datetime.strftime("/#{depsuffixed_name}/log/%Y%m%dT%H%M%SZ.log.html.gz")
  end

  def diffuri
    server.uri.chomp('/') + datetime.strftime("/#{depsuffixed_name}/log/%Y%m%dT%H%M%SZ.diff.html.gz")
  end

  def failuri
    meta&.[]('compressed_failhtml_relpath') ? "#{server.uri.chomp('/')}/#{depsuffixed_name}/#{meta['compressed_failhtml_relpath']}" : nil
  end

  def recenturi
    server.recent_uri(branch_opts)
  end

  def meta
    if defined?(@meta)
      @meta
    else
      @meta = (l = ltsv) ? l.split("\t").map{|x|x.split(":", 2)}.to_h : nil
    end
  end

  def self.store_log(server_id, http, path, datetime, branch, option, revision,
                     ltsv, summary, depsuffixed_name)
    begin
      if ENV.key?('TREASURE_DATA_API_KEY')
        res = http.get(path)
        res.value
        cb = ChkBuildRubyInfo.new(res.body)
        cb.common_hash = {
          server_id: server_id,
          depsuffixed_name: depsuffixed_name,
          epoch: datetime.to_i,
          revision: revision,
        }
      end
    rescue Net::HTTPServerException
    end

    Report.create!(
      server_id: server_id,
      datetime: datetime,
      branch: branch,
      option: option,
      revision: revision,
      ltsv: ltsv,
      summary: summary
    )

    cb.convert_to_td if cb
  rescue => e
    warn [e, e&.record&.errors, server_id, http, path, datetime, branch, option, revision,
      ltsv, summary, depsuffixed_name].inspect
    warn e.backtrace
  end

  REG_RCNT = /name="(\d+T\d{6}Z).*?a>\s*(\S.*)<br/

  def self.sql_datetime(col)
    if defined?(SQLite3)
      "datetime(#{col})"
    else # PostgreSQL
      col
    end
  end

  def self.scan_recent(server, depsuffixed_name, body, http, recentpath)
    return unless /\Aruby-([0-9a-z\.]+)(?:-(.*))?\z/ =~ depsuffixed_name
    branch = $1
    option = $2
    latest = Report.where(server_id: server.id, branch: branch, option: option).
      order("#{sql_datetime("datetime")} ASC").last

    ary = []
    body.scan(REG_RCNT) do |dt, summary|
      datetime = Time.utc(*dt.unpack("A4A2A2xA2A2A2"))
      break if latest and datetime <= latest.datetime
      ary << [dt, summary, datetime]
    end

    ary.reverse_each do |dt, summary, datetime|
      puts "reporting #{server.name} #{depsuffixed_name} #{dt} ..."
      revision = (summary[/\br(\d+)\b/, 1] ||
                  summary[/\brev:(\d+)\b/, 1] ||
                  summary[/(?:trunk|revision)\S* (\d+)\x29/, 1]).to_i

      store_log(
        server.id,
        http,
        File.join(recentpath, "../log/#{dt}.log.txt.gz"),
        datetime,
        branch,
        option,
        revision,
        nil,
        summary.gsub(/<[^>]*>/, ''),
        depsuffixed_name,
      )
    end
  end

  def self.scan_recent_ltsv(server, depsuffixed_name, body, http, recentpath)
    return unless /\A(?:cross)?ruby-([0-9a-z\.]+)(?:-(.*))?\z/ =~ depsuffixed_name
    branch = $1
    option = $2
    path = nil
    latest = Report.where(server_id: server.id, branch: branch, option: option).
      order("#{sql_datetime("datetime")} ASC").last
    ary = []
    body.each_line do |line|
      line.chomp!
      h = line.split("\t").map{|x|x.split(":", 2)}.to_h
      dt = h["start_time"]
      datetime = Time.utc(*dt.unpack("A4A2A2xA2A2A2"))
      break if latest and datetime <= latest.datetime
      ary << [line, h, dt, datetime]
    end
    ary.reverse_each do |line, h, dt, datetime|
      puts "reporting #{server.name} #{depsuffixed_name} #{dt} ..."
      # subversion revision of ruby is less than 99999
      revision = h["ruby_rev"] && h["ruby_rev"].size <= 6 ? h["ruby_rev"][1, 5].to_i : nil
      summary = h["title"]
      summary << ' success' if h["result"] == 'success'
      diff = h["different_sections"]
      summary << (diff ? " (diff:#{diff})" : " (no diff)")

      store_log(
        server.id,
        http,
        File.join(recentpath, "../log/#{dt}.log.txt.gz"),
        datetime,
        branch,
        option,
        revision,
        line,
        summary.gsub(/<[^>]*>/, ''),
        depsuffixed_name,
      )
    end
  rescue RuntimeError => e # It seems not a chkbuild log
    warn [e, server.uri, path, "failed to scan_reports"].inspect
  rescue => e
    warn [e, server.uri, path, "failed to scan_reports", e.backtrace].inspect
  end

  def self.get_reports(server)
    uri = URI(server.uri)
    if uri.host.end_with?('s3.amazonaws.com')
      basepath = uri.path
      path = "/?prefix=#{basepath[/[\w\-]+/]}%2F&delimiter=%2F"
    else
      path = basepath = uri.path
      path += '?restype=container&comp=list&delimiter=%2F' if uri.host.end_with?('.blob.core.windows.net')
    end
    Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 10) do |h|
      puts "getting #{uri.host}#{path} ..."
      h.get(path).body.scan(/(?:<Prefix>[\w\-]+\/|<Name>|(?:href|HREF)=")((?:cross)?ruby-[^"\/]+)/) do |depsuffixed_name,_|
        next if /\Acrossruby-trunk-[a-z0-9]+|\Aruby-(?:trunk|[1-9])/ !~ depsuffixed_name

        begin # LTSV
          path = File.join(basepath, depsuffixed_name, 'recent.ltsv')
          puts "getting #{uri.host}#{path} ..."
          res = h.get(path)
          res.value
          self.scan_recent_ltsv(server, depsuffixed_name, res.body, h, path)
        rescue Net::HTTPServerException
          begin # HTML
            path = File.join(basepath, depsuffixed_name, 'recent.html')
            puts "getting #{uri.host}#{path} ..."
            res = h.get(path)
            res.value
            self.scan_recent(server, depsuffixed_name, res.body, h, path)
          rescue Net::HTTPServerException
          end
        end
      end
    end
  rescue SocketError => e
    p [e, uri, path, "failed to get_reports"]
  rescue Net::OpenTimeout => e
    p [e, uri, path, "failed to get_reports"]
  rescue => e
    p [e, uri, path]
    puts e.backtrace
    return []
  end

  def self.fetch_recent
    Server.order(:id).all.each do |server|
      self.get_reports(server)
    end
  end

  def self.post_recent
    uri = nil
    path = nil

    ServerResource.all.each do |server|
      uri = URI(server.uri)
      ary = []
      Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 10) do |h|
        path = basepath = uri.path
        puts "getting #{uri.host}#{basepath} ..."
        h.get(basepath).body.scan(/href="ruby-([^"\/]+)/) do |branch,_|
          path = File.join(basepath, 'ruby-' + branch, 'recent.html')
          puts "getting #{uri.host}#{path} ..."
          ary.push(
            'server_id' => server.id,
            'branch' => branch,
            'body' => h.get(path).body,
          )
        end
      end
      next if ary.empty?

      Net::HTTP.start('rubyci.herokuapp.com', 80, open_timeout: 10, read_timeout: 10) do |h|
        ary.each do |report|
          data = JSON(report)
          res = h.post('/reports/receive_recent.json', data, 'Content-Type' => 'application/json')
          p res
          puts res.body
        end
      end
    end
  rescue Exception => e
    p [e, uri, path]
    puts e.backtrace
    return []
  end
end
