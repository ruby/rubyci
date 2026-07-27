require "test_helper"

class ReportTest < ActiveSupport::TestCase
  SHA = "0123456789abcdef0123456789abcdef01234567"

  @@ordinal = 0

  def create_server(name)
    Server.create!(name: name, uri: "https://rubyci.s3.amazonaws.com/#{name}", ordinal: (@@ordinal += 1))
  end

  def build_report(attrs = {})
    server = attrs.delete(:server) || create_server("server-#{attrs.object_id}")
    Report.new({
      server: server,
      branch: "master",
      datetime: Time.now.utc,
      summary: "ruby 3.5.0dev success",
    }.merge(attrs))
  end

  test "revision accepts nil, digits and 40-hex SHA" do
    assert_predicate build_report(revision: nil), :valid?
    assert_predicate build_report(revision: "12345"), :valid?
    assert_predicate build_report(revision: SHA), :valid?
  end

  test "revision rejects other strings" do
    assert_not build_report(revision: "r12345").valid?
    assert_not build_report(revision: SHA[0, 11]).valid?
    assert_not build_report(revision: "#{SHA} ").valid?
  end

  test "revisionuri for svn revision" do
    report = build_report(revision: "12345")
    assert_equal "https://svn.ruby-lang.org/cgi-bin/viewvc.cgi?view=revision&revision=12345", report.revisionuri
  end

  test "revisionuri for git commit SHA" do
    report = build_report(revision: SHA)
    assert_equal "https://github.com/ruby/ruby/commit/#{SHA}", report.revisionuri
  end

  test "revisionuri falls back to SHA from ltsv" do
    report = build_report(revision: nil, ltsv: "depsuffixed_name:ruby-master\thttps://github.com/ruby/ruby:#{SHA}")
    assert_equal "https://github.com/ruby/ruby/commit/#{SHA}", report.revisionuri
  end

  test "revisionuri without revision and ltsv" do
    assert_nil build_report(revision: nil, ltsv: nil).revisionuri
  end

  test "sha1 prefers revision column" do
    report = build_report(revision: SHA, ltsv: nil)
    assert_equal SHA, report.sha1
  end

  test "sha1 falls back to ltsv" do
    report = build_report(revision: nil, ltsv: "https://github.com/ruby/ruby:#{SHA}")
    assert_equal SHA, report.sha1

    report = build_report(revision: nil, ltsv: %["https\\x3A//github.com/ruby/ruby":#{SHA}])
    assert_equal SHA, report.sha1
  end

  test "extract_full_sha" do
    assert_equal SHA, Report.extract_full_sha("https://github.com/ruby/ruby:#{SHA}")
    assert_equal SHA, Report.extract_full_sha(%["https\\x3A//github.com/ruby/ruby":#{SHA}])
    assert_nil Report.extract_full_sha("https://github.com/ruby/ruby:#{SHA[0, 11]}")
    assert_nil Report.extract_full_sha(nil)
  end

  test "scan_recent_ltsv stores full SHA from ltsv" do
    server = create_server("scan-sha")
    line = [
      "start_time:20260727T051800Z",
      "https://github.com/ruby/ruby:#{SHA}",
      "title:ruby 3.5.0dev (2026-07-27) [x86_64-linux]",
      "result:success",
    ].join("\t")
    Report.scan_recent_ltsv(server, "ruby-master", line + "\n")
    report = Report.where(server_id: server.id).last
    assert_equal SHA, report.revision
  end

  test "scan_recent_ltsv stores svn revision as digits" do
    server = create_server("scan-svn")
    line = [
      "start_time:20260727T051800Z",
      "ruby_rev:r54321",
      "title:ruby 2.7.0dev (2026-07-27) [x86_64-linux]",
      "result:success",
    ].join("\t")
    Report.scan_recent_ltsv(server, "ruby-2.7", line + "\n")
    report = Report.where(server_id: server.id).last
    assert_equal "54321", report.revision
  end
end
