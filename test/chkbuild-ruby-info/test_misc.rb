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

  def test_expand_field_ruby_branch
    out = StringIO.new
    cb = ChkBuildRubyInfo.new(<<'End')
== ruby-trunk # 2010-12-02T16:51:01+09:00
== start # 2014-06-21T06:05:42+09:00
option :ruby_branch => "trunk"
End
    cb.opt_expand_fields = [['ruby_branch', nil]]
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
{"ruby_branch":"trunk","type":"ruby_branch"},
{"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","ruby_branch":"trunk","status":"failure"}
]
End
  end

  def test_expand_field_ruby_branch_with_prefix
    out = StringIO.new
    cb = ChkBuildRubyInfo.new(<<'End')
== ruby-trunk # 2010-12-02T16:51:01+09:00
== start # 2014-06-21T06:05:42+09:00
option :ruby_branch => "trunk"
End
    cb.opt_expand_fields = [['ruby_branch', 'foo']]
    cb.convert_to_json(out)
    #puts out.string
    assert_equal(<<'End', out.string)
[
{"foo":"trunk","type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00"},
{"foo":"trunk","type":"depsuffixed_name","depsuffixed_name":"ruby-trunk"},
{"foo":"trunk","type":"suffixed_name","suffixed_name":"ruby-trunk"},
{"foo":"trunk","type":"target_name","target_name":"ruby"},
{"foo":"trunk","type":"section_end","secname":"ruby-trunk","end_time":"2014-06-21T06:05:42+09:00","elapsed":112022081.0},
{"foo":"trunk","type":"section_start","secname":"start","start_time":"2014-06-21T06:05:42+09:00"},
{"foo":"trunk","type":"ruby_branch","ruby_branch":"trunk"},
{"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","ruby_branch":"trunk","status":"failure"}
]
End
  end

  def test_common
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
