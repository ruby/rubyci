class Report < ActiveRecord::Base
  require 'net/http'
  require 'uri'
  require 'open-uri'
  belongs_to :server
  validates_associated :server
  validates :server_id, :numericality => { :only_integer => true }
  validates :revision, :numericality => { :only_integer => true }
  validates :datetime, :presence => true
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
    summary[/ (\d+F\d+E(?:\d+S)?) /, 1] || summary[/(\d*failed)\(test\/\)/, 1]
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

  def self.get_reports(server)
    ary = []
    uri = URI(server.uri)
    Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 10) do |h|
      path = basepath = uri.path
      puts "getting #{uri.host}#{basepath} ..."
      h.get(basepath).body.scan(/href="ruby-([^"\/]+)/) do |branch,_|
        latest = Report.where(server_id: server.id, branch: branch).last
        path = File.join(basepath, 'ruby-' + branch, 'recent.html')
        puts "getting #{uri.host}#{path} ..."
        h.get(path).body.scan(REG_RCNT) do |dt, summary|
          datetime = Time.utc(*dt.unpack("A4A2A2xA2A2A2"))
          break if latest and datetime <= latest.datetime
          puts "reporting #{server.name} #{branch} #{dt} ..."
          ary.push(
            server_id: server.id,
            datetime: datetime,
            branch: branch,
            revision: summary[/(?:trunk|revision) (\d+)\x29/, 1],
            summary: summary.gsub(/<[^>]*>/, '')
          )
        end
      end
    end
    ary.sort_by!{|h|h[:datetime]}
    return ary
  rescue Exception => e
    p [e, uri, path]
    puts e.backtrace
    return []
  end

  def self.update
    ary = []
    servers = Server.all
    threads = []
    until servers.empty? and threads.empty? and ary.empty?
      threads.reject!{|t|!t.alive?}
      while !servers.empty? and threads.size < 1
        threads << Thread.new{ ary.concat self.get_reports(servers.shift) }
      end
      unless ary.empty?
        Report.transaction do
          Report.create! ary.shift until ary.empty?
        end
      end
      Thread.pass
    end
    URI('http://rubyci.org/').read('Cache-Control' => 'no-cache')
  end

  def self.post_recent
    uri = nil
    path = nil
    Server.all.each do |server|
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
