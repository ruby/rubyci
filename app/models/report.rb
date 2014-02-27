class Report < ActiveRecord::Base
  require 'net/http'
  require 'uri'
  require 'open-uri'
  belongs_to :server
  attr_accessible :server_id, :datetime, :branch, :option, :revision, :summary
  validates :server_id, :presence => true
  validates :revision, :numericality => { :only_integer => true }
  validates :datetime, :uniqueness => { :scope => [:server_id, :branch] }
  validates :branch, :presence => true
  validates :summary, :presence => true

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
    str = summary[/^[^\x28]+(?:\s*\([^\x29]*\)|\s*\[[^\x5D]*\])*\s*(\S.*?)(?: \(|\z)/, 1]
  end

  def diffstat
    summary[/((?:no )?diff[^)>]*)/, 1]
  end

  def branch_opts
    option ? "#{branch}-#{option}" : branch
  end

  def loguri
    server.uri + datetime.strftime("ruby-#{branch_opts}/log/%Y%m%dT%H%M%SZ.log.html.gz")
  end

  def diffuri
    server.uri + datetime.strftime("ruby-#{branch_opts}/log/%Y%m%dT%H%M%SZ.diff.html.gz")
  end

  def recenturi
    server.recent_uri(branch_opts)
  end

  REG_RCNT = /name="(\d+T\d{6}Z).*?a>\s*(\S.*)<br/

  def self.scan_recent(server, branch_opts, body, results)
    return unless /\A([0-9a-z\.]+)(?:-(.*))?\z/ =~ branch_opts
    branch = $1
    option = $2
    latest = Report.where(server_id: server.id, branch: branch, option: option).last
    body.scan(REG_RCNT) do |dt, summary|
      datetime = Time.utc(*dt.unpack("A4A2A2xA2A2A2"))
      break if latest and datetime <= latest.datetime
      puts "reporting #{server.name} #{branch_opts} #{dt} ..."
      results.push(
        server_id: server.id,
        datetime: datetime,
        branch: branch,
        option: option,
        revision: (summary[/\br(\d+)\b/, 1] ||
                   summary[/\brev:(\d+)\b/, 1] ||
                   summary[/(?:trunk|revision)\S* (\d+)\x29/, 1]).to_i,
        summary: summary.gsub(/<[^>]*>/, '')
      )
    end
    results
  end

  def self.scan_recent_ltsv(server, branch_opts, body, results)
    return unless /\A([0-9a-z\.]+)(?:-(.*))?\z/ =~ branch_opts
    branch = $1
    option = $2
    latest = Report.where(server_id: server.id, branch: branch, option: option).last
    body.each_line do |line|
      line.chomp!
      h = line.split("\t").map{|x|x.split(":", 2)}.to_h
      dt = h["start_time"]
      summary = h["title"]
      summary << ' success' if / \d+W\z/ =~ summary # workaround
      datetime = Time.utc(*dt.unpack("A4A2A2xA2A2A2"))
      break if latest and datetime <= latest.datetime
      puts "reporting #{server.name} #{branch_opts} #{dt} ..."
      results.push(
        server_id: server.id,
        datetime: datetime,
        branch: branch,
        option: option,
        revision: h["ruby_rev"][1,100].to_i,
        summary: summary
      )
    end
    results
  end

  def self.get_reports(server)
    ary = []
    uri = URI(server.uri)
    path = nil
    Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 10) do |h|
      path = basepath = uri.path
      puts "getting #{uri.host}#{basepath} ..."
      h.get(basepath).body.scan(/(?:href|HREF)="ruby-([^"\/]+)/) do |branch_opts,_|
        next if /\A(?:trunk|[1-9])/ !~ branch_opts

        begin # LTSV
          path = File.join(basepath, 'ruby-' + branch_opts, 'recent.ltsv')
          puts "getting #{uri.host}#{path} ..."
          res = h.get(path)
          p res
          res.value
          self.scan_recent_ltsv(server, branch_opts, res.body, ary)
          next
        rescue Net::HTTPServerException
        end

        begin# HTML
          path = File.join(basepath, 'ruby-' + branch_opts, 'recent.html')
          puts "getting #{uri.host}#{path} ..."
          res = h.get(path)
          res.value
          self.scan_recent(server, branch_opts, res.body, ary)
        rescue Net::HTTPServerException
        end
      end
    end
    ary.sort_by!{|h|h[:datetime]}
    return ary
  rescue Net::OpenTimeout => e
    p [e, uri, path, "failed to get_reports"]
    return []
  rescue Exception => e
    p [e, uri, path]
    puts e.backtrace
    return []
  end

  def self.fetch_recent
    ary = []
    Server.all.each do |server|
      ary.concat self.get_reports(server)
    end
    Report.transaction do
      ary.each do |item|
        Report.create! item
      end
    end
    ReportsController.expire_page '/'
    URI('http://rubyci.herokuapp.com/').read('Cache-Control' => 'no-cache')
    URI('http://rubyci.org/').read('Cache-Control' => 'no-cache')
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

class ServerResource < ActiveResource::Base
  self.site="http://rubyci.herokuapp.com"
  self.element_name = "server"
end
