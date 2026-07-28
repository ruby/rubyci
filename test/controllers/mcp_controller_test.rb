require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  SHA_GOOD = "aaaa000000000000000000000000000000000001"
  SHA_BAD  = "bbbb000000000000000000000000000000000002"
  SHA_HEAD = "cccc000000000000000000000000000000000003"

  setup do
    # ordinal base 2000: other test files use 0, 100, 500 and 999
    @server = Server.create!(name: "mcp-srv", uri: "https://rubyci.s3.amazonaws.com/mcp-srv/", ordinal: 2000)
    @other = Server.create!(name: "mcp-srv2", uri: "https://rubyci.s3.amazonaws.com/mcp-srv2/", ordinal: 2001)
    base = Time.now.utc.change(usec: 0)

    @good = create_report(@server, base - 3.days, SHA_GOOD, success: true)
    @first_bad = create_report(@server, base - 2.days, SHA_BAD, success: false)
    LogExcerpt.create!(report: @first_bad, content: "TestMcp#test_origin [mcp_test.rb:1]:\nExpected true.")
    @latest_bad = create_report(@server, base - 1.day, SHA_HEAD, success: false)
    LogExcerpt.create!(report: @latest_bad, content: "TestMcp#test_origin [mcp_test.rb:1]:\nExpected true.\nsecond line here")

    @other_bad = create_report(@other, base - 12.hours, SHA_HEAD, success: false)
    LogExcerpt.create!(report: @other_bad, content: "TestMcp#test_origin [mcp_test.rb:1]:\nExpected true.")
  end

  test "initialize returns server info and instructions" do
    res = mcp_post(method: "initialize", params: {
      protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "0" }
    })
    assert_equal "rubyci", res.dig("result", "serverInfo", "name")
    assert_match "find_failure_origin", res.dig("result", "instructions")
  end

  test "tools/list returns all tools" do
    res = mcp_post(method: "tools/list")
    names = res.dig("result", "tools").map { |t| t["name"] }
    assert_equal %w[list_servers current_status report_history search_failures
                    find_failure_origin failing_servers get_log_excerpt].sort, names.sort
  end

  test "GET is not allowed in stateless mode" do
    get "/mcp"
    assert_response :method_not_allowed
  end

  test "list_servers" do
    result = call_tool("list_servers")
    names = result["servers"].map { |s| s["name"] }
    assert_includes names, "mcp-srv"
    assert_includes names, "mcp-srv2"
  end

  test "current_status failures_only" do
    result = call_tool("current_status", { branch: "master", failures_only: true })
    entries = result["reports"].select { |r| r["server"].start_with?("mcp-srv") }
    assert_equal 2, entries.size
    assert entries.all? { |r| r["result"] == "failure" }
    latest = entries.find { |r| r["server"] == "mcp-srv" }
    assert_equal @latest_bad.id, latest["id"]
  end

  test "report_history filters by server and result" do
    result = call_tool("report_history", { branch: "master", server: "mcp-srv" })
    assert_equal 3, result["count"]
    assert_equal [@latest_bad.id, @first_bad.id, @good.id], result["reports"].map { |r| r["id"] }

    result = call_tool("report_history", { branch: "master", server: "mcp-srv", result: "success" })
    assert_equal [@good.id], result["reports"].map { |r| r["id"] }
  end

  test "report_history rejects unknown server" do
    res = mcp_post(method: "tools/call", params: { name: "report_history",
      arguments: { branch: "master", server: "no-such-server" } })
    assert res.dig("result", "isError")
  end

  test "search_failures returns matching_line and orders ascending" do
    result = call_tool("search_failures", { q: "test_origin", order: "asc" })
    assert_equal 3, result["count"]
    assert_equal @first_bad.id, result["reports"].first["id"]
    assert_match "TestMcp#test_origin", result["reports"].first["matching_line"]
  end

  test "search_failures requires a filter" do
    res = mcp_post(method: "tools/call", params: { name: "search_failures", arguments: {} })
    assert res.dig("result", "isError")
  end

  test "find_failure_origin without query finds the streak boundary" do
    result = call_tool("find_failure_origin", { branch: "master", server: "mcp-srv" })
    config = result["configs"].first
    assert_equal @first_bad.id, config.dig("first_bad", "id")
    assert_equal @good.id, config.dig("last_good", "id")
    assert_equal "https://github.com/ruby/ruby/compare/#{SHA_GOOD}...#{SHA_BAD}", config["compare_url"]
    assert_equal config["compare_url"], result.dig("earliest", "compare_url")
  end

  test "find_failure_origin with query reports occurrences across servers" do
    result = call_tool("find_failure_origin", { branch: "master", query: "test_origin" })
    assert_equal 2, result["configs"].size
    mine = result["configs"].find { |c| c["server"] == "mcp-srv" }
    assert_equal 2, mine["occurrences"]
    assert mine["still_failing"]
    assert_equal @first_bad.id, mine.dig("first_bad", "id")
    assert_match "TestMcp#test_origin", mine.dig("first_bad", "matching_line")
    assert_equal "mcp-srv", result.dig("earliest", "server")
  end

  test "find_failure_origin flags same-commit boundary as flaky" do
    base = Time.now.utc.change(usec: 0)
    good = create_report(@server, base - 10.hours, SHA_HEAD, success: true)
    good.update!(branch: "4.0")
    bad = create_report(@server, base - 5.hours, SHA_HEAD, success: false)
    bad.update!(branch: "4.0")
    LogExcerpt.create!(report: bad, content: "TestFlaky#test_same_commit failed")

    result = call_tool("find_failure_origin", { branch: "4.0", query: "test_same_commit" })
    config = result["configs"].first
    assert_equal bad.id, config.dig("first_bad", "id")
    assert_equal good.id, config.dig("last_good", "id")
    assert_nil config["compare_url"]
    assert_match "flaky", config["note"]
  end

  test "find_failure_origin with unmatched query" do
    result = call_tool("find_failure_origin", { branch: "master", query: "no_such_failure" })
    assert_match "No failure log", result["message"]
  end

  test "failing_servers groups by configuration" do
    result = call_tool("failing_servers", { query: "test_origin" })
    assert_equal 2, result["config_count"]
    assert_equal 3, result["total_occurrences"]
    mine = result["configs"].find { |c| c["server"] == "mcp-srv" }
    assert_equal 2, mine["occurrences"]
    assert mine["still_failing"]
    assert_equal @first_bad.id, mine.dig("first_seen", "id")
    assert_equal @latest_bad.id, mine.dig("last_seen", "id")
    assert_match "TestMcp#test_origin", mine.dig("last_seen", "matching_line")
  end

  test "get_log_excerpt with grep" do
    result = call_tool("get_log_excerpt", { report_id: @latest_bad.id, grep: "second line", context_lines: 0 })
    assert_equal "second line here", result["content"].strip
    refute result["truncated"]
  end

  test "get_log_excerpt for a report without excerpt" do
    res = mcp_post(method: "tools/call", params: { name: "get_log_excerpt",
      arguments: { report_id: @good.id } })
    assert res.dig("result", "isError")
  end

  private

  def create_report(server, datetime, sha, success:)
    if success
      summary = "ruby 3.5.0dev success (no diff)"
      ltsv = "depsuffixed_name:ruby-master\tresult:success\truby_rev:#{sha}"
    else
      summary = "ruby 3.5.0dev failed(test-all) (diff:test-all)"
      ltsv = "depsuffixed_name:ruby-master\tresult:failure\truby_rev:#{sha}"
    end
    Report.create!(server: server, branch: "master", option: nil, datetime: datetime,
      revision: sha, summary: summary, ltsv: ltsv)
  end

  def mcp_post(method:, params: nil)
    payload = { jsonrpc: "2.0", id: 1, method: method }
    payload[:params] = params if params
    post "/mcp", params: payload.to_json, headers: {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "MCP-Protocol-Version" => "2025-11-25",
    }
    assert_response :success
    JSON.parse(response.body)
  end

  def call_tool(name, arguments = {})
    res = mcp_post(method: "tools/call", params: { name: name, arguments: arguments })
    refute res.dig("result", "isError"), "tool errored: #{res.inspect}"
    JSON.parse(res.dig("result", "content", 0, "text"))
  end
end
