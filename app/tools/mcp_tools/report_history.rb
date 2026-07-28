module McpTools
  class ReportHistory < MCP::Tool
    extend Helpers

    tool_name "report_history"
    description "Build history for a branch, newest first. Narrow by server and option to " \
                "follow a single configuration over time."
    input_schema(
      properties: {
        branch: { type: "string", description: "Branch, e.g. 'master' or '3.4'" },
        server: { type: "string", description: "Server id or name (see list_servers)" },
        option: { type: "string", description: "Build option, e.g. 'yjit' (exact match)" },
        from: { type: "string", description: "Start date (YYYY-MM-DD, UTC)" },
        to: { type: "string", description: "End date (YYYY-MM-DD, UTC, inclusive)" },
        result: { type: "string", enum: ["success", "failure"], description: "Filter by build result" },
        limit: { type: "integer", description: "Max reports to return (default 30, max 100)" },
      },
      required: ["branch"],
    )
    annotations(Helpers::READ_ONLY)

    def self.call(branch:, server: nil, option: nil, from: nil, to: nil, result: nil, limit: 30, server_context: nil)
      scope = Report.includes(:server).where(branch: branch).order(datetime: :desc)
      if server.present?
        srv = resolve_server(server)
        return error_response("Unknown server: #{server}") unless srv
        scope = scope.where(server_id: srv.id)
      end
      scope = scope.where(option: option) if option.present?
      from_t = parse_time(from)
      to_t = parse_time(to, end_of_day: true)
      scope = scope.where("datetime >= ?", from_t) if from_t
      scope = scope.where("datetime <= ?", to_t) if to_t
      if result.to_s.match?(/\A(?:success|failure)\z/)
        scope = scope.where(Report.arel_table[:ltsv].matches("%\tresult:#{result}\t%"))
      end
      reports = scope.limit(limit.to_i.clamp(1, 100)).to_a
      json_response(count: reports.size, reports: reports.map(&:as_mcp_json))
    end
  end
end
