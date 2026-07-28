module McpTools
  class SearchFailures < MCP::Tool
    extend Helpers

    MAX_LIMIT = 50

    tool_name "search_failures"
    description "Search log excerpts of failed builds (same index as https://rubyci.org/search). " \
                "Use order=asc to find the earliest record of a failure. Excerpts exist only for " \
                "failed builds on rubyci S3 servers and are pruned after about one year."
    input_schema(
      properties: {
        q: { type: "string", description: "Substring to match in failure logs, e.g. a test name or assertion message" },
        server: { type: "string", description: "Server id or name (see list_servers)" },
        branch: { type: "string", description: "Branch, e.g. 'master'" },
        revision: { type: "string", description: "Commit SHA or SVN revision prefix" },
        from: { type: "string", description: "Start date (YYYY-MM-DD, UTC)" },
        to: { type: "string", description: "End date (YYYY-MM-DD, UTC, inclusive)" },
        order: { type: "string", enum: ["asc", "desc"], description: "Sort by datetime (default desc)" },
        limit: { type: "integer", description: "Max hits to return (default 20, max #{MAX_LIMIT})" },
        page: { type: "integer", description: "Page number (default 1)" },
      },
      required: [],
    )
    annotations(Helpers::READ_ONLY)

    def self.call(q: nil, server: nil, branch: nil, revision: nil, from: nil, to: nil,
                  order: "desc", limit: 20, page: 1, server_context: nil)
      q = q.to_s.strip
      from_t = parse_time(from)
      to_t = parse_time(to, end_of_day: true)
      unless q.present? || server.present? || branch.present? || revision.present? || from_t || to_t
        return error_response("Give at least one filter: q, server, branch, revision, from or to")
      end

      reports = Report.joins(:log_excerpt).includes(:server).
        order("reports.datetime #{order == 'asc' ? 'ASC' : 'DESC'}")
      if server.present?
        srv = resolve_server(server)
        return error_response("Unknown server: #{server}") unless srv
        reports = reports.where(server_id: srv.id)
      end
      reports = reports.where(branch: branch) if branch.present?
      reports = reports.where("reports.datetime >= ?", from_t) if from_t
      reports = reports.where("reports.datetime <= ?", to_t) if to_t
      if revision.present?
        reports = reports.where("reports.revision LIKE ?", "#{Report.sanitize_sql_like(revision)}%")
      end
      reports = reports.merge(LogExcerpt.content_match(q)) if q.present?

      limit = limit.to_i.clamp(1, MAX_LIMIT)
      page = page.to_i.clamp(1, 200)
      hits = reports.limit(limit + 1).offset((page - 1) * limit).to_a
      has_next = hits.size > limit
      hits = hits.first(limit)

      results = hits.map do |report|
        entry = report.as_mcp_json
        entry[:matching_line] = report.log_excerpt&.matching_line(q) if q.present?
        entry.compact
      end
      json_response(count: results.size, page: page, has_next: has_next, reports: results)
    end
  end
end
