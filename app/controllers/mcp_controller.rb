# MCP (Model Context Protocol) endpoint. Streamable HTTP transport in
# stateless mode: each POST is self-contained, so it works across multiple
# Puma processes without sticky sessions. Read-only, no authentication,
# same public posture as /reports and /search.
class McpController < ApplicationController
  skip_forgery_protection

  TOOLS = [
    McpTools::ListServers,
    McpTools::CurrentStatus,
    McpTools::ReportHistory,
    McpTools::SearchFailures,
    McpTools::FindFailureOrigin,
    McpTools::FailingServers,
    McpTools::GetLogExcerpt,
  ].freeze

  INSTRUCTIONS = <<~TEXT.freeze
    rubyci.org aggregates chkbuild CI results for ruby/ruby. Typical triage flow:
    current_status to see what is failing now, failing_servers to see how widespread
    a specific failure is, then find_failure_origin to get the first bad build and a
    github.com/ruby/ruby compare URL for the suspect commit range. Chain the results
    with a GitHub MCP server (enumerate commits in compare_url, inspect diffs) and a
    bugs.ruby-lang.org MCP server (search or file issues using the matching_line
    snippet and commit SHA).
  TEXT

  def handle
    server = MCP::Server.new(
      name: "rubyci",
      version: "1.0.0",
      instructions: INSTRUCTIONS,
      tools: TOOLS,
    )
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      server,
      stateless: true,
      enable_json_response: true,
      # This is a public server; host-header validation is meant for local
      # stdio-adjacent deployments and would reject rubyci.org.
      dns_rebinding_protection: false,
    )
    status, headers, body = transport.handle_request(request)
    headers.each { |k, v| response.set_header(k, v) unless k.casecmp?("content-length") }
    body = Array(body).join
    if body.empty?
      head status
    else
      render body: body, status: status
    end
  end
end
