module McpTools
  class CurrentStatus < MCP::Tool
    extend Helpers

    tool_name "current_status"
    description "Latest build result for each (server, branch, option) configuration within " \
                "the last 14 days. Start here to see which configurations are currently failing."
    input_schema(
      properties: {
        branch: { type: "string", description: "Filter by branch, e.g. 'master' or '3.4'" },
        failures_only: { type: "boolean", description: "Return only failing configurations" },
      },
      required: [],
    )
    annotations(Helpers::READ_ONLY)

    def self.call(branch: nil, failures_only: false, server_context: nil)
      reports = Report.includes(:server).latest_per_config(14.days.ago).to_a
      reports.reject! { |r| r.server.nil? || r.branch == 'trunk' }
      reports.select! { |r| r.branch == branch } if branch.present?
      reports.reject!(&:success?) if failures_only
      reports.sort_by! { |r| [r.branch, r.server.ordinal, r.option.to_s] }
      json_response(count: reports.size, reports: reports.map(&:as_mcp_json))
    end
  end
end
