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
