require 'test/unit'
require 'stringio'

require_relative '../../lib/chkbuild-ruby-info'

class TestChkBuildRubyInfoTD < Test::Unit::TestCase
  def capture_stdout_stderr
    orig_stdout = $stdout
    orig_stderr = $stderr
    $stdout = out = StringIO.new
    $stderr = err = StringIO.new
    begin
      yield
    ensure
      $stdout = orig_stdout
      $stderr = orig_stderr
    end
    return out.string, err.string
  end

  def test_td
    exc = nil
    out, err = capture_stdout_stderr {
      cb = ChkBuildRubyInfo.new(<<'End')
== ruby-trunk # 2010-12-02T16:51:01+09:00
End
      cb.td_common = {
        server_id: 1,
        depsuffixed_name: 'ruby-trunk',
        epoch: 1291276261,
        revision: 4200,
      }
      cb.convert_to_json
    }
    assert_equal(<<'End', out)
@[chkbuild.section_start] {"type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200}
@[chkbuild.depsuffixed_name] {"type":"depsuffixed_name","depsuffixed_name":"ruby-trunk","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200}
@[chkbuild.suffixed_name] {"type":"suffixed_name","suffixed_name":"ruby-trunk","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200}
@[chkbuild.target_name] {"type":"target_name","target_name":"ruby","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200}
@[chkbuild.build] {"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","server_id":1,"depsuffixed_name":"ruby-trunk","epoch":1291276261,"revision":4200}
End
  end
end
