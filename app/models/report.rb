class Report < ActiveRecord::Base
  require 'net/http'
  require 'uri'

  REG_RCNT = /name="(\d+T\d{6}Z).*?a>\s*(\S.*?\S)\s+\(/

  def self.update
    ss = Server.all.map do |server|
      Thread.new do
        uri = URI(server.uri)
        begin
          Net::HTTP.start(uri.host, uri.port) do |h|
            basepath = uri.path
            puts "getting #{uri.host}#{basepath}..."
            h.get(basepath).body.scan(/href="ruby-([^"\/]+)/) do |branch|
              path = File.join(basepath, branch, 'recent.html')
              puts "getting #{uri.host}#{path}..."
              h.get(path).body.scan(REG_RCNT) do |datetime, summary|
                dt = Time.utc(*datetime.unpack("A4A2A2xA2A2A2"))
                if Report.find_by_datetime(dt)
                  break
                end
                puts "reporting #{uri.host}#{path} #{datetime}..."
                Report.create!(
                  server_id: server.id,
                  datetime: dt,
                  branch: branch,
                  revision: summary[/\d+(?=\x29)/],
                  uri: (uri + File.join(path, "../log/#{datetime}.log.html.gz")).to_s,
                  summary: summary
                )
              end
            end
          end
        rescue StandardError, EOFError, Timeout::Error => e
          p e
          puts e.message
          puts e.backtrace
        end
      end
    end.map(&:join)
  end
end
