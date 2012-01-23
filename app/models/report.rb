class Report < ActiveRecord::Base
  require 'net/http'
  require 'uri'
  require 'open-uri'
  belongs_to :server
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

  def build
    summary[/(\d*failed)\((?:svn|make|miniruby)[^)]*\)/]
  end

  def btest
    summary[/ (\d+)BFail /, 1] ? $1+'BF': nil
  end

  def testknownbug
    summary[/ KB(\d+F\d+E) /, 1]
  end

  def test
    t = summary[/ (\d+)NotOK /, 1] ? $1+'F' : nil
    a = [btest, testknownbug, t]
    a.compact!
    a.empty? ? nil : a.join(' ')
  end

  def testall
    summary[/ (\d+F\d+E(?:\d+S)?) /, 1] || summary[/(\d*failed)\(test/, 1]
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

  def loguri
    server.uri + datetime.strftime("ruby-#{branch}/log/%Y%m%dT%H%M%SZ.log.html.gz")
  end

  def diffuri
    server.uri + datetime.strftime("ruby-#{branch}/log/%Y%m%dT%H%M%SZ.diff.html.gz")
  end

  REG_RCNT = /name="(\d+T\d{6}Z).*?a>\s*(\S.*)<br/

  def self.scan_recent(server, branch, body, results)
    latest = Report.where(server_id: server.id, branch: branch).last
    body.scan(REG_RCNT) do |dt, summary|
      datetime = Time.utc(*dt.unpack("A4A2A2xA2A2A2"))
      break if latest and datetime <= latest.datetime
      puts "reporting #{server.name} #{branch} #{dt} ..."
      results.push(
        server_id: server.id,
        datetime: datetime,
        branch: branch,
        revision: summary[/(?:trunk|revision)\S+ (\d+)\x29/, 1].to_i,
        summary: summary.gsub(/<[^>]*>/, '')
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
      h.get(basepath).body.scan(/href="ruby-([^"\/]+)/) do |branch,_|
        next if branch !~ /\A(?:trunk|[2-9]|1\.9\.[2-9])\z/
        path = File.join(basepath, 'ruby-' + branch, 'recent.html')
        puts "getting #{uri.host}#{path} ..."
        self.scan_recent(server, branch, h.get(path).body, ary)
      end
    end
    ary.sort_by!{|h|h[:datetime]}
    return ary
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
          latest = Report.where(server_id: server.id, branch: branch).last
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
  self.site="http://rubyci.org"
  self.element_name = "server"
end
