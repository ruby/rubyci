require 'test/unit'
require 'stringio'

require_relative '../../lib/chkbuild-ruby-info'

class TestChkBuildRubyInfoMisc < Test::Unit::TestCase
  def test_opt_type
    out = StringIO.new
    cb = ChkBuildRubyInfo.new(<<'End')
== ruby-trunk # 2010-12-02T16:51:01+09:00
End
    cb.opt_type = %w[target_name]
    cb.convert_to_json(out)
    assert_equal(<<'End', out.string)
[
{"type":"target_name","target_name":"ruby"}
]
End
  end

  def test_opt_enable_sole_record
    out = StringIO.new
    cb = ChkBuildRubyInfo.new(<<'End')
== ruby-trunk # 2010-12-02T16:51:01+09:00
End
    cb.opt_enable_sole_record = false
    cb.convert_to_json(out)
    assert_equal(<<'End', out.string)
[
{"type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00"},
{"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","status":"failure"}
]
End
  end

  def test_expand_type
    exc = nil
    out = StringIO.new
    cb = ChkBuildRubyInfo.new(<<'End')
== ruby-trunk # 2010-12-02T16:51:01+09:00
== start # 2014-06-21T06:05:42+09:00
option :ruby_branch => "trunk"
End
    cb.opt_expand_types = [['ruby_branch', nil]]
    cb.convert_to_json(out)
    #puts out.string
    assert_equal(<<'End', out.string)
[
{"ruby_branch":"trunk","type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00"},
{"ruby_branch":"trunk","type":"depsuffixed_name","depsuffixed_name":"ruby-trunk"},
{"ruby_branch":"trunk","type":"suffixed_name","suffixed_name":"ruby-trunk"},
{"ruby_branch":"trunk","type":"target_name","target_name":"ruby"},
{"ruby_branch":"trunk","type":"section_end","secname":"ruby-trunk","end_time":"2014-06-21T06:05:42+09:00","elapsed":112022081.0},
{"ruby_branch":"trunk","type":"section_start","secname":"start","start_time":"2014-06-21T06:05:42+09:00"},
{"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","ruby_branch":"trunk","status":"failure"}
]
End
  end

  def test_expand_type_with_prefix
    exc = nil
    out = StringIO.new
    cb = ChkBuildRubyInfo.new(<<'End')
== ruby-trunk # 2010-12-02T16:51:01+09:00
== version.h # 2014-06-22T10:34:09+09:00
#define RUBY_VERSION "2.2.0"
#define RUBY_RELEASE_DATE "2014-06-22"
#define RUBY_PATCHLEVEL -1
#define RUBY_BRANCH_NAME "trunk"
#define RUBY_RELEASE_YEAR 2014
#define RUBY_RELEASE_MONTH 6
#define RUBY_RELEASE_DAY 22
End
    cb.opt_expand_types = [['ruby_release', 'ruby_release']]
    cb.convert_to_json(out)
    #puts out.string
    assert_equal(<<'End', out.string)
[
{"ruby_release_version":"2.2.0","ruby_release_release_date":"2014-06-22","ruby_release_patchlevel":-1,"ruby_release_branch_name":"trunk","ruby_release_release_year":2014,"ruby_release_release_month":6,"ruby_release_release_day":22,"type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00"},
{"ruby_release_version":"2.2.0","ruby_release_release_date":"2014-06-22","ruby_release_patchlevel":-1,"ruby_release_branch_name":"trunk","ruby_release_release_year":2014,"ruby_release_release_month":6,"ruby_release_release_day":22,"type":"depsuffixed_name","depsuffixed_name":"ruby-trunk"},
{"ruby_release_version":"2.2.0","ruby_release_release_date":"2014-06-22","ruby_release_patchlevel":-1,"ruby_release_branch_name":"trunk","ruby_release_release_year":2014,"ruby_release_release_month":6,"ruby_release_release_day":22,"type":"suffixed_name","suffixed_name":"ruby-trunk"},
{"ruby_release_version":"2.2.0","ruby_release_release_date":"2014-06-22","ruby_release_patchlevel":-1,"ruby_release_branch_name":"trunk","ruby_release_release_year":2014,"ruby_release_release_month":6,"ruby_release_release_day":22,"type":"target_name","target_name":"ruby"},
{"ruby_release_version":"2.2.0","ruby_release_release_date":"2014-06-22","ruby_release_patchlevel":-1,"ruby_release_branch_name":"trunk","ruby_release_release_year":2014,"ruby_release_release_month":6,"ruby_release_release_day":22,"type":"section_end","secname":"ruby-trunk","end_time":"2014-06-22T10:34:09+09:00","elapsed":112124588.0},
{"ruby_release_version":"2.2.0","ruby_release_release_date":"2014-06-22","ruby_release_patchlevel":-1,"ruby_release_branch_name":"trunk","ruby_release_release_year":2014,"ruby_release_release_month":6,"ruby_release_release_day":22,"type":"section_start","secname":"version.h","start_time":"2014-06-22T10:34:09+09:00"},
{"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","ruby_release_version":"2.2.0","ruby_release_patchlevel":-1,"ruby_release_branch_name":"trunk","ruby_release_date":"2014-06-22","ruby_release_year":2014,"ruby_release_month":6,"ruby_release_day":22,"status":"failure"}
]
End
  end

  def test_expand_field
    exc = nil
    out = StringIO.new
    cb = ChkBuildRubyInfo.new(<<'End')
== ruby-trunk # 2010-12-02T16:51:01+09:00
== version.h # 2014-06-22T10:34:09+09:00
#define RUBY_VERSION "2.2.0"
#define RUBY_RELEASE_DATE "2014-06-22"
#define RUBY_PATCHLEVEL -1
#define RUBY_BRANCH_NAME "trunk"
#define RUBY_RELEASE_YEAR 2014
#define RUBY_RELEASE_MONTH 6
#define RUBY_RELEASE_DAY 22
End
    cb.opt_expand_fields = [['ruby_release_version']]
    cb.convert_to_json(out)
    #puts out.string
    assert_equal(<<'End', out.string)
[
{"ruby_release_version":"2.2.0","type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00"},
{"ruby_release_version":"2.2.0","type":"depsuffixed_name","depsuffixed_name":"ruby-trunk"},
{"ruby_release_version":"2.2.0","type":"suffixed_name","suffixed_name":"ruby-trunk"},
{"ruby_release_version":"2.2.0","type":"target_name","target_name":"ruby"},
{"ruby_release_version":"2.2.0","type":"section_end","secname":"ruby-trunk","end_time":"2014-06-22T10:34:09+09:00","elapsed":112124588.0},
{"ruby_release_version":"2.2.0","type":"section_start","secname":"version.h","start_time":"2014-06-22T10:34:09+09:00"},
{"ruby_release_version":"2.2.0","type":"ruby_release","version":"2.2.0","release_date":"2014-06-22","patchlevel":-1,"branch_name":"trunk","release_year":2014,"release_month":6,"release_day":22},
{"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","ruby_release_version":"2.2.0","ruby_release_patchlevel":-1,"ruby_release_branch_name":"trunk","ruby_release_date":"2014-06-22","ruby_release_year":2014,"ruby_release_month":6,"ruby_release_day":22,"status":"failure"}
]
End
  end

  def test_common
    exc = nil
    out = StringIO.new
    cb = ChkBuildRubyInfo.new(<<'End')
== ruby-trunk # 2010-12-02T16:51:01+09:00
End
    cb.common_hash = {
      server_id: 1,
      depsuffixed_name: 'ruby-trunk',
      epoch: 1291276261,
      revision: 4200,
    }
    cb.convert_to_json(out)
    assert_equal(<<'End', out.string)
[
{"server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200,"type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00"},
{"server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200,"type":"depsuffixed_name"},
{"server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200,"type":"suffixed_name","suffixed_name":"ruby-trunk"},
{"server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200,"type":"target_name","target_name":"ruby"},
{"server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200,"type":"build","suffixed_name":"ruby-trunk","target_name":"ruby","status":"failure"}
]
End
  end

  def test_td
    exc = nil
    out = StringIO.new
    cb = ChkBuildRubyInfo.new(<<'End')
== ruby-trunk # 2010-12-02T16:51:01+09:00
End
    cb.common_hash = {
      server_id: 1,
      depsuffixed_name: 'ruby-trunk',
      epoch: 1291276261,
      revision: 4200,
    }
    cb.convert_to_td(out)
    assert_equal(<<'End', out.string)
@[chkbuild.section_start] {"server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200,"type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00"}
@[chkbuild.build] {"server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200,"type":"build","suffixed_name":"ruby-trunk","target_name":"ruby","status":"failure"}
End
  end
end
