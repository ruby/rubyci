require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  SHA = "abcdef0123456789abcdef0123456789abcdef01"

  setup do
    @server = Server.create!(name: "search-srv", uri: "https://rubyci.s3.amazonaws.com/search-srv/", ordinal: 999)
    @report = Report.create!(
      server: @server,
      branch: "master",
      datetime: Time.utc(2026, 7, 20, 1, 2, 3),
      revision: SHA,
      summary: "ruby 3.5.0dev failed(test-all) (diff:test-all)",
      ltsv: "depsuffixed_name:ruby-master\tresult:failure",
    )
    LogExcerpt.create!(report: @report, content: "TestSearch#test_hit [foo_test.rb:12]:\nExpected true.")
  end

  test "top page without params shows only the form" do
    get search_url
    assert_response :success
    assert_no_match "TestSearch#test_hit", response.body
  end

  test "search by text matches excerpt content" do
    get search_url, params: { q: "test_hit" }
    assert_response :success
    assert_match "TestSearch#test_hit", response.body
    assert_match @report.loguri, response.body
  end

  test "search by text with no match" do
    get search_url, params: { q: "does_not_exist_anywhere" }
    assert_response :success
    assert_match "No matching failure logs", response.body
  end

  test "search by revision prefix" do
    get search_url, params: { revision: SHA[0, 10] }
    assert_response :success
    assert_match @report.loguri, response.body
  end

  test "search narrowed by branch and date range" do
    get search_url, params: { q: "test_hit", branch: "master", from: "2026-07-20", to: "2026-07-20" }
    assert_response :success
    assert_match @report.loguri, response.body

    get search_url, params: { q: "test_hit", branch: "ruby_3_4" }
    assert_match "No matching failure logs", response.body

    get search_url, params: { q: "test_hit", to: "2026-07-19" }
    assert_match "No matching failure logs", response.body
  end

  test "array page param does not raise" do
    get search_url, params: { q: "test_hit", page: ["1"] }
    assert_response :success
  end

  test "out of range page is clamped" do
    get search_url, params: { q: "test_hit", page: "99999999999999999999" }
    assert_response :success
    assert_match "No matching failure logs", response.body
  end

  test "search escapes LIKE wildcards" do
    get search_url, params: { q: "%" }
    assert_response :success
    assert_match "No matching failure logs", response.body
  end
end
