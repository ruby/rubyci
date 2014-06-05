require 'test/unit'
require 'stringio'

require_relative '../../lib/chkbuild-ruby-info'

class TestChkBuildRubyInfoMisc < Test::Unit::TestCase
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
{"type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200},
{"type":"depsuffixed_name","depsuffixed_name":"ruby-trunk","server_id":1,"epoch":1291276261,"revision":4200},
{"type":"suffixed_name","suffixed_name":"ruby-trunk","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200},
{"type":"target_name","target_name":"ruby","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200},
{"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","server_id":1,"epoch":1291276261,"revision":4200}
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
@[chkbuild.section_start] {"type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200}
@[chkbuild.depsuffixed_name] {"type":"depsuffixed_name","depsuffixed_name":"ruby-trunk","server_id":1,"epoch":1291276261,"revision":4200}
@[chkbuild.suffixed_name] {"type":"suffixed_name","suffixed_name":"ruby-trunk","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200}
@[chkbuild.target_name] {"type":"target_name","target_name":"ruby","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200}
@[chkbuild.build] {"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","server_id":1,"epoch":1291276261,"revision":4200}
End
  end
end
