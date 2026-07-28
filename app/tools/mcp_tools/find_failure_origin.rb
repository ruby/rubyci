module McpTools
  class FindFailureOrigin < MCP::Tool
    extend Helpers

    MAX_REPORTS_PER_CONFIG = 300
    MAX_MATCH_IDS = 10_000

    # Light per-report tuple loaded via pluck. Loading full rows per
    # configuration (ltsv is several KB each) took seconds per query on
    # production and blew past the 30s request timeout.
    Row = Struct.new(:id, :server_id, :option, :datetime, :summary) do
      def success?
        summary.include?(" success")
      end
    end

    tool_name "find_failure_origin"
    description "Locate when a failure started and the suspect commit range. For each failing " \
                "(server, branch, option) configuration, returns the first bad report, the last " \
                "good report before it, and a github.com/ruby/ruby compare URL between the two " \
                "commits when both are known. Without `query`, analyzes the current failing " \
                "streak of each configuration; with `query`, tracks the earliest failure log " \
                "matching that string (better for a specific test failure, tolerates flakiness). " \
                "Feed compare_url to a GitHub MCP server to enumerate suspect commits."
    input_schema(
      properties: {
        branch: { type: "string", description: "Branch, e.g. 'master'" },
        server: { type: "string", description: "Server id or name; omit to analyze all servers" },
        option: { type: "string", description: "Build option (exact match); omit to analyze all options" },
        query: { type: "string", description: "Substring identifying the failure in logs, e.g. a test name" },
        lookback_days: { type: "integer", description: "How many days back to scan (default 90, max 366)" },
      },
      required: ["branch"],
    )
    annotations(Helpers::READ_ONLY)

    def self.call(branch:, server: nil, option: nil, query: nil, lookback_days: 90, server_context: nil)
      since = lookback_days.to_i.clamp(1, 366).days.ago.utc
      scope = Report.where(branch: branch).where("datetime > ?", since)
      if server.present?
        srv = resolve_server(server)
        return error_response("Unknown server: #{server}") unless srv
        scope = scope.where(server_id: srv.id)
      end
      scope = scope.where(option: option) if option.present?

      rows = scope.pluck(:id, :server_id, :option, :datetime, :summary).map { |r| Row.new(*r) }
      return error_response("No reports found for branch #{branch} in the lookback window") if rows.empty?

      match_ids = nil
      if query.present?
        match_ids = scope.joins(:log_excerpt).merge(LogExcerpt.content_match(query)).
          limit(MAX_MATCH_IDS).pluck(:id).to_set
        if match_ids.empty?
          return json_response(branch: branch, query: query,
            message: "No failure log matching the query in the lookback window")
        end
      end

      boundaries = rows.group_by { |r| [r.server_id, r.option] }.filter_map do |_config, rs|
        rs.sort_by!(&:datetime)
        rs.reverse!
        rs = rs.first(MAX_REPORTS_PER_CONFIG)
        query.present? ? analyze_query(rs, match_ids) : analyze_streak(rs)
      end
      if boundaries.empty?
        return json_response(branch: branch, query: query,
          message: "No failing configuration found in the lookback window")
      end

      ids = boundaries.flat_map { |b| [b[:first_bad_id], b[:last_good_id]] }.compact
      records = Report.where(id: ids).includes(:server).index_by(&:id)

      results = boundaries.filter_map do |b|
        first_bad = records[b[:first_bad_id]]
        next if first_bad.nil? || first_bad.server.nil?
        last_good = b[:last_good_id] && records[b[:last_good_id]]
        entry = config_entry(first_bad, last_good, b)
        if query.present?
          line = first_bad.log_excerpt&.matching_line(query)
          entry[:first_bad][:matching_line] = line if line
        end
        entry
      end

      results.sort_by! { |r| r[:first_bad][:datetime] }
      earliest = results.first
      json_response(
        branch: branch,
        query: query.presence,
        earliest: {
          server: earliest[:server],
          option: earliest[:option],
          datetime: earliest[:first_bad][:datetime],
          commit_sha: earliest[:first_bad][:commit_sha],
          compare_url: earliest[:compare_url],
        }.compact,
        configs: results,
      )
    end

    # Boundary of the current failing streak: skip configurations whose latest
    # report succeeded.
    def self.analyze_streak(rows)
      return nil if rows.first.success?
      streak = rows.take_while { |r| !r.success? }
      {
        first_bad_id: streak.last.id,
        last_good_id: rows[streak.size]&.id,
        occurrences: streak.size,
        still_failing: true,
      }
    end

    # Earliest report whose failure log matches the query. last_good is the
    # newest report older than it without the matching failure (it may have
    # failed for an unrelated reason).
    def self.analyze_query(rows, match_ids)
      matching = rows.select { |r| match_ids.include?(r.id) }
      return nil if matching.empty?
      first_bad = matching.last
      {
        first_bad_id: first_bad.id,
        last_good_id: rows[rows.index(first_bad) + 1]&.id,
        occurrences: matching.size,
        still_failing: match_ids.include?(rows.first.id),
      }
    end

    def self.config_entry(first_bad, last_good, boundary)
      {
        server: first_bad.server.name,
        server_id: first_bad.server_id,
        option: first_bad.option,
        still_failing: boundary[:still_failing],
        occurrences: boundary[:occurrences],
        first_bad: first_bad.as_mcp_json,
        last_good: last_good&.as_mcp_json,
        compare_url: compare_url(last_good, first_bad),
        note: last_good ? nil :
          "No earlier report within the window (window exhausted or scan capped at #{MAX_REPORTS_PER_CONFIG} reports); the failure may have started earlier.",
      }.compact
    end
  end
end
