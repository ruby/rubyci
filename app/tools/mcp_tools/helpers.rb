module McpTools
  # Shared class-level helpers for MCP tool classes.
  module Helpers
    READ_ONLY = {
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true,
      open_world_hint: false,
    }.freeze

    def json_response(payload)
      MCP::Tool::Response.new([{ type: "text", text: JSON.generate(payload) }])
    end

    def error_response(message)
      MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
    end

    def parse_time(str, end_of_day: false)
      return nil if str.blank?
      date = Date.parse(str.to_s) rescue nil
      return nil unless date
      time = Time.utc(date.year, date.month, date.day)
      end_of_day ? time + 86399 : time
    end

    # Accepts a numeric id or a server name.
    def resolve_server(value)
      return nil if value.blank?
      if value.to_s.match?(/\A\d+\z/)
        Server.find_by(id: value)
      else
        Server.find_by(name: value.to_s)
      end
    end

    def compare_url(good, bad)
      return nil unless good&.git_sha && bad&.git_sha
      "https://github.com/ruby/ruby/compare/#{good.git_sha}...#{bad.git_sha}"
    end
  end
end
