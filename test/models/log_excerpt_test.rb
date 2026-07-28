require "test_helper"

class LogExcerptTest < ActiveSupport::TestCase
  @@ordinal = 100

  def create_server(name, uri: "https://rubyci.s3.amazonaws.com/#{name}/")
    Server.create!(name: name, uri: uri, ordinal: (@@ordinal += 1))
  end

  # minitest 6 no longer bundles minitest/mock, so swap the singleton method
  def stub_fetch_text(callable)
    singleton = LogExcerpt.singleton_class
    original = LogExcerpt.method(:fetch_text)
    singleton.send(:define_method, :fetch_text) { |uri| callable.call(uri) }
    yield
  ensure
    singleton.send(:define_method, :fetch_text, original)
  end

  def create_report(server, attrs = {})
    Report.create!({
      server: server,
      branch: "master",
      datetime: Time.now.utc,
      summary: "ruby 3.5.0dev failed(test-all)",
    }.merge(attrs))
  end

  test "failtxt_uri and difftxt_uri from ltsv relpath" do
    server = create_server("uri-ltsv")
    report = create_report(server, ltsv: "depsuffixed_name:ruby-master\tcompressed_failhtml_relpath:log/20260727T023004Z.fail.html.gz\tcompressed_diffhtml_relpath:log/20260727T023004Z.diff.html.gz")
    assert_equal "https://rubyci.s3.amazonaws.com/uri-ltsv/ruby-master/log/20260727T023004Z.fail.txt.gz", report.failtxt_uri
    assert_equal "https://rubyci.s3.amazonaws.com/uri-ltsv/ruby-master/log/20260727T023004Z.diff.txt.gz", report.difftxt_uri
  end

  test "failtxt_uri falls back to datetime" do
    server = create_server("uri-dt")
    report = create_report(server, datetime: Time.utc(2026, 7, 27, 2, 30, 4))
    assert_equal "https://rubyci.s3.amazonaws.com/uri-dt/master/log/20260727T023004Z.fail.txt.gz", report.failtxt_uri
  end

  test "capture stores fail and diff content" do
    server = create_server("cap-both")
    report = create_report(server)
    fetch = ->(uri) { uri.include?(".fail.") ? "FAIL BODY" : "DIFF BODY" }
    stub_fetch_text(fetch) do
      LogExcerpt.capture(report)
    end
    assert_equal "FAIL BODY\nDIFF BODY", report.reload.log_excerpt.content
  end

  test "capture truncates content to MAX_CONTENT_BYTES" do
    server = create_server("cap-trunc")
    report = create_report(server)
    stub_fetch_text(->(uri) { "x" * 200_000 }) do
      LogExcerpt.capture(report)
    end
    assert_operator report.reload.log_excerpt.content.bytesize, :<=, LogExcerpt::MAX_CONTENT_BYTES
  end

  test "capture keeps the diff section when fail is over budget" do
    server = create_server("cap-budget")
    report = create_report(server)
    fetch = ->(uri) { uri.include?(".fail.") ? "F" * 200_000 : "D" * 1_000 }
    stub_fetch_text(fetch) do
      LogExcerpt.capture(report)
    end
    content = report.reload.log_excerpt.content
    assert_operator content.bytesize, :<=, LogExcerpt::MAX_CONTENT_BYTES
    assert_equal 1_000, content.count("D")
    assert_operator content.count("F"), :>, 90_000
  end

  test "capture lets one section use the other's unused budget" do
    server = create_server("cap-slack")
    report = create_report(server)
    fetch = ->(uri) { uri.include?(".fail.") ? "F" * 90_000 : "D" * 1_000 }
    stub_fetch_text(fetch) do
      LogExcerpt.capture(report)
    end
    content = report.reload.log_excerpt.content
    assert_equal 90_000, content.count("F")
    assert_equal 1_000, content.count("D")
  end

  test "capture saves empty row when nothing is available" do
    server = create_server("cap-empty")
    report = create_report(server)
    stub_fetch_text(->(uri) { nil }) do
      LogExcerpt.capture(report)
    end
    assert_equal "", report.reload.log_excerpt.content
  end

  test "capture skips non-rubyci servers" do
    server = create_server("cap-other", uri: "https://example.com/chkbuild/logs")
    report = create_report(server)
    stub_fetch_text(->(uri) { flunk "must not fetch" }) do
      assert_nil LogExcerpt.capture(report)
    end
    assert_nil report.reload.log_excerpt
  end

  test "capture is idempotent per report" do
    server = create_server("cap-idem")
    report = create_report(server)
    stub_fetch_text(->(uri) { "first" }) do
      LogExcerpt.capture(report)
    end
    stub_fetch_text(->(uri) { "second" }) do
      LogExcerpt.capture(report)
    end
    assert_equal 1, LogExcerpt.where(report_id: report.id).count
    assert_equal "second\nsecond", report.reload.log_excerpt.content
  end

  test "content_match finds substring" do
    server = create_server("cap-match")
    report = create_report(server)
    LogExcerpt.create!(report: report, content: "TestFoo#test_bar [test.rb:1]:\nExpected 1 to equal 2.")
    assert_includes LogExcerpt.content_match("test_bar").to_a.map(&:report_id), report.id
    assert_empty LogExcerpt.content_match("no_such_token").where(report_id: report.id).to_a
  end

  test "matching_line returns first matching line" do
    excerpt = LogExcerpt.new(content: "line one\nTestFoo#test_bar failed\nline three")
    assert_equal "TestFoo#test_bar failed", excerpt.matching_line("TEST_BAR")
    assert_nil excerpt.matching_line("absent")
    assert_nil excerpt.matching_line("")
  end

  test "scan_recent_ltsv captures excerpt for failed build" do
    server = create_server("scan-fail")
    line = [
      "start_time:20260727T051800Z",
      "title:ruby 3.5.0dev (2026-07-27) [x86_64-linux]",
      "result:failure",
      "compressed_failhtml_relpath:log/20260727T051800Z.fail.html.gz",
      "compressed_diffhtml_relpath:log/20260727T051800Z.diff.html.gz",
    ].join("\t")
    stub_fetch_text(->(uri) { "some failure output" }) do
      Report.scan_recent_ltsv(server, "ruby-master", line + "\n")
    end
    report = Report.where(server_id: server.id).last
    assert_equal "some failure output\nsome failure output", report.log_excerpt.content
  end

  test "scan_recent_ltsv does not capture excerpt for success build" do
    server = create_server("scan-ok")
    line = [
      "start_time:20260727T051800Z",
      "title:ruby 3.5.0dev (2026-07-27) [x86_64-linux]",
      "result:success",
    ].join("\t")
    stub_fetch_text(->(uri) { flunk "must not fetch" }) do
      Report.scan_recent_ltsv(server, "ruby-master", line + "\n")
    end
    report = Report.where(server_id: server.id).last
    assert_nil report.log_excerpt
  end

  test "scan_recent_ltsv survives capture errors" do
    server = create_server("scan-err")
    line = [
      "start_time:20260727T051800Z",
      "title:ruby 3.5.0dev (2026-07-27) [x86_64-linux]",
      "result:failure",
    ].join("\t")
    stub_fetch_text(->(uri) { raise Net::OpenTimeout }) do
      Report.scan_recent_ltsv(server, "ruby-master", line + "\n")
    end
    report = Report.where(server_id: server.id).last
    assert_not_nil report
    assert_nil report.log_excerpt
  end
end
