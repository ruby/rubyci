require "test_helper"

class ServerTest < ActiveSupport::TestCase
  @@ordinal = 500

  def create_server(uri)
    Server.create!(name: "srv-#{@@ordinal}", uri: uri, ordinal: (@@ordinal += 1))
  end

  test "rubyci_s3? accepts both schemes" do
    assert_predicate create_server("https://rubyci.s3.amazonaws.com/ubuntu/"), :rubyci_s3?
    assert_predicate create_server("http://rubyci.s3.amazonaws.com/rhel9"), :rubyci_s3?
  end

  test "rubyci_s3? rejects other hosts" do
    assert_not create_server("https://example.com/rubyci.s3.amazonaws.com/x").rubyci_s3?
    assert_not create_server("https://rubyci.s3.amazonaws.com.evil.test/x").rubyci_s3?
    assert_not create_server("http://ci.rvm.jp/chkbuild/logs/").rubyci_s3?
  end

  test "log_base_uri points bucket-backed servers at the CDN" do
    assert_equal "https://logs.rubyci.org/ubuntu", create_server("https://rubyci.s3.amazonaws.com/ubuntu/").log_base_uri
    assert_equal "https://logs.rubyci.org/rhel9", create_server("http://rubyci.s3.amazonaws.com/rhel9").log_base_uri
  end

  test "log_base_uri keeps other servers as registered" do
    assert_equal "http://ci.rvm.jp/chkbuild/logs", create_server("http://ci.rvm.jp/chkbuild/logs/").log_base_uri
  end

  test "recent_uri uses the CDN host" do
    server = create_server("https://rubyci.s3.amazonaws.com/debian/")
    assert_equal "https://logs.rubyci.org/debian/ruby-master/recent.html", server.recent_uri("master")
  end

  test "rubyci_s3 scope selects the same servers as rubyci_s3?" do
    servers = [
      create_server("https://rubyci.s3.amazonaws.com/scope-https/"),
      create_server("http://rubyci.s3.amazonaws.com/scope-http/"),
      create_server("http://ci.rvm.jp/chkbuild/scope-other/"),
    ]
    selected = Server.rubyci_s3.where(id: servers.map(&:id)).order(:id).to_a
    assert_equal servers.select(&:rubyci_s3?), selected
  end
end
