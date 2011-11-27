class Report < ActiveRecord::Base
  require 'net/http'
  require 'uri'

  REG_RCNT = /name="(\d+T\d{6}Z).*?a>\s*(\S.*?\S)\s+\(/

  def self.update
    ss = Server.all.map do |server|
      Thread.new do
        uri = URI(server.uri)
        Net::HTTP.start(uri.hostname, uri.port) do |h|
          basepath = uri.path
          puts "getting #{basepath}..."
          h.get(basepath).body.scan(/href="([^"\/]*)/) do |branch|
            path = File.join(basepath, branch, 'recent.html')
            puts "getting #{path}..."
            h.get(path).body.scan(REG_RCNT) do |datetime, summary|
              dt = Time.utc(*datetime.unpack("A4A2A2xA2A2A2"))
              if Report.find_by_datetime(dt)
                break
              end
              puts "reporting #{path} #{datetime}..."
              Report.create!(
                server_id: server.id,
                datetime: dt,
                branch: branch,
                revision: summary[/\d+(?=\x29)/],
                uri: uri + File.join(path, "../log/#{datetime}.log.html.gz"),
                summary: summary
              )
            end
          end
        end
      end
    end.map(&:join)
  end
end
