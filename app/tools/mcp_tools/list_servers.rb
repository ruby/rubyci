module McpTools
  class ListServers < MCP::Tool
    extend Helpers

    tool_name "list_servers"
    description "List the CI servers aggregated by rubyci.org. Use the returned id or name " \
                "as the `server` argument of the other tools."
    input_schema(properties: {}, required: [])
    annotations(Helpers::READ_ONLY)

    def self.call(server_context: nil)
      servers = Server.order(:ordinal).map do |s|
        { id: s.id, name: s.name, uri: s.uri, eol_date: s.eol_date&.iso8601 }.compact
      end
      json_response(servers: servers)
    end
  end
end
