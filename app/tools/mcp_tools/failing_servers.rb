module McpTools
  class FailingServers < MCP::Tool
    extend Helpers

    MAX_MATCHES = 2000

    tool_name "failing_servers"
    description "Given a failure log substring (e.g. a test name or assertion message), list the " \
                "(server, branch, option) configurations where that failure occurred, with first " \
                "and last occurrence and whether the latest build of each configuration still has " \
                "it. Distinguishes an environment-specific failure from a global regression."
    input_schema(
      properties: {
        query: { type: "string", description: "Substring to match in failure logs" },
        branch: { type: "string", description: "Filter by branch, e.g. 'master'" },
        from: { type: "string", description: "Start date (YYYY-MM-DD, UTC; default 14 days ago)" },
        to: { type: "string", description: "End date (YYYY-MM-DD, UTC, inclusive)" },
      },
      required: ["query"],
    )
    annotations(Helpers::READ_ONLY)

    def self.call(query:, branch: nil, from: nil, to: nil, server_context: nil)
      return error_response("query must not be blank") if query.strip.empty?
      from_t = parse_time(from) || 14.days.ago.utc
      to_t = parse_time(to, end_of_day: true)

      scope = Report.joins(:log_excerpt).merge(LogExcerpt.content_match(query)).
        includes(:server).
        where("reports.datetime >= ?", from_t).
        order("reports.datetime ASC").limit(MAX_MATCHES)
      scope = scope.where("reports.datetime <= ?", to_t) if to_t
      scope = scope.where(branch: branch) if branch.present?
      matches = scope.to_a.reject { |r| r.server.nil? }
      if matches.empty?
        return json_response(query: query, branch: branch, message: "No matching failure in the window")
      end
      match_ids = matches.map(&:id).to_set

      configs = matches.group_by { |r| [r.server_id, r.branch, r.option] }.map do |(server_id, br, opt), reports|
        first = reports.first
        last = reports.last
        latest = Report.where(server_id: server_id, branch: br, option: opt).order(datetime: :desc).first
        {
          server: first.server.name,
          server_id: server_id,
          branch: br,
          option: opt,
          occurrences: reports.size,
          still_failing: match_ids.include?(latest.id),
          first_seen: first.as_mcp_json,
          last_seen: last.as_mcp_json.merge(matching_line: last.log_excerpt&.matching_line(query)).compact,
        }
      end
      configs.sort_by! { |c| c[:first_seen][:datetime] }

      json_response(
        query: query,
        branch: branch,
        from: from_t.iso8601,
        to: to_t&.iso8601,
        config_count: configs.size,
        total_occurrences: matches.size,
        truncated: matches.size >= MAX_MATCHES,
        configs: configs,
      )
    end
  end
end
