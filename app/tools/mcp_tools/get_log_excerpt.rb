module McpTools
  class GetLogExcerpt < MCP::Tool
    extend Helpers

    DEFAULT_MAX_BYTES = 20_000

    tool_name "get_log_excerpt"
    description "Stored failure log excerpt (fail.txt + diff.txt, up to 100KB) for a report. " \
                "Use `grep` to narrow to matching lines with context. Excerpts exist only for " \
                "failed builds on rubyci S3 servers and are pruned after about one year; use " \
                "the report's log_url for the full log."
    input_schema(
      properties: {
        report_id: { type: "integer", description: "Report id (from other tools)" },
        grep: { type: "string", description: "Return only lines containing this substring, with context" },
        context_lines: { type: "integer", description: "Context lines around each grep match (default 5, max 50)" },
        max_bytes: { type: "integer", description: "Byte cap of the returned content (default #{DEFAULT_MAX_BYTES}, max #{LogExcerpt::MAX_CONTENT_BYTES})" },
      },
      required: ["report_id"],
    )
    annotations(Helpers::READ_ONLY)

    def self.call(report_id:, grep: nil, context_lines: 5, max_bytes: DEFAULT_MAX_BYTES, server_context: nil)
      report = Report.find_by(id: report_id)
      return error_response("Report not found: #{report_id}") unless report
      excerpt = report.log_excerpt
      if excerpt.nil? || excerpt.content.empty?
        return error_response("No log excerpt stored for report #{report_id}. " \
          "Excerpts exist only for failed builds on rubyci S3 servers and are pruned after about one year.")
      end

      content = excerpt.content
      if grep.present?
        content = grep_with_context(content, grep, context_lines.to_i.clamp(0, 50))
        return json_response(report: report.as_mcp_json, grep: grep, content: "",
          message: "No lines matched") if content.empty?
      end

      max = max_bytes.to_i.clamp(1_000, LogExcerpt::MAX_CONTENT_BYTES)
      truncated = content.bytesize > max
      content = LogExcerpt.truncate_bytes(content, max)
      json_response(report: report.as_mcp_json, grep: grep.presence, truncated: truncated,
        content: content)
    end

    def self.grep_with_context(content, grep, context)
      lines = content.lines
      needle = grep.downcase
      indexes = lines.each_index.select { |i| lines[i].downcase.include?(needle) }
      return "" if indexes.empty?
      ranges = indexes.map { |i| [[i - context, 0].max, [i + context, lines.size - 1].min] }
      merged = [ranges.first]
      ranges.drop(1).each do |lo, hi|
        if lo <= merged.last[1] + 1
          merged.last[1] = [merged.last[1], hi].max
        else
          merged << [lo, hi]
        end
      end
      merged.map { |lo, hi| lines[lo..hi].join }.join("...\n")
    end
  end
end
