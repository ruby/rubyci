class Report < ActiveRecord::Base
  require 'net/http'
  require 'uri'
  belongs_to :server

  def shortsummary
    summary[/^[^\x28]+(?:\s*\([^\x29]*\)|\s*\[[^\x5D]*\])*\s*(\S.*?) \(</, 1]
  end

  def diffstat
    summary[/>([^<]*)</, 1]
  end

  def loguri
    server.uri + datetime.strftime("ruby-#{branch}/log/%Y%m%dT%H%M%SZ.log.html.gz")
  end

  def diffuri
    server.uri + datetime.strftime("ruby-#{branch}/log/%Y%m%dT%H%M%SZ.diff.html.gz")
  end

  REG_RCNT = /name="(\d+T\d{6}Z).*?a>\s*(\S.*)<br/

  def self.update
    ss = Server.all.map do |server|
      Thread.new do
        uri = URI(server.uri)
        begin
          Net::HTTP.start(uri.host, uri.port) do |h|
            basepath = uri.path
            puts "getting #{uri.host}#{basepath}..."
            h.get(basepath).body.scan(/href="ruby-([^"\/]+)/) do |branch,|
              path = File.join(basepath, 'ruby-' + branch, 'recent.html')
              puts "getting #{uri.host}#{path}..."
              h.get(path).body.scan(REG_RCNT) do |dt, summary,|
                datetime = Time.utc(*dt.unpack("A4A2A2xA2A2A2"))
                if Report.find_by_datetime(dt)
                  puts "finish"
                  break
                end
                puts "reporting #{uri.host}#{path} #{dt}..."
                Report.create!(
                  server_id: server.id,
                  datetime: datetime,
                  branch: branch,
                  revision: summary[/\d+(?=\x29)/],
                  summary: summary
                )
              end
            end
          end
        rescue StandardError, EOFError, Timeout::Error, Errno::ECONNREFUSED => e
          p e
          puts e.message
          puts e.backtrace
        end
      end
    end.map(&:join)
  end
end
