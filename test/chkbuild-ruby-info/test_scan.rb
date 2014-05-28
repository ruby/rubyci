require 'test/unit'
require 'stringio'

require_relative '../../lib/chkbuild-ruby-info'

class TestChkBuildRubyInfo < Test::Unit::TestCase
  def check(src, expected, type=nil)
    src = StringIO.new(src)
    out = StringIO.new
    ChkBuildRubyInfo.new(src).convert_to_json(out)
    result = out.string.gsub(/,$/, '').sub(/\A\[\n/, '').sub(/\]\n\z/, '')
    if type
      json_type = JSON.dump(type)
      pat = /"type":#{Regexp.escape json_type}/
      result = result.lines.grep(pat).join
    end
    expected = expected.gsub(/,$/, '')
    assert_equal(expected, result)
  end

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

  def test_unexpected_format
    exc = nil
    out, err = capture_stdout_stderr {
      begin
        ChkBuildRubyInfo.new("foo").convert_to_json
      rescue SystemExit => exc
      end
    }
    assert_raise(SystemExit) {
      raise exc
    }
    assert_equal('', out)
  end

  def test_unexpected_format_html
    exc = nil
    out, err = capture_stdout_stderr {
      begin
        ChkBuildRubyInfo.new("<html>").convert_to_json
      rescue SystemExit => exc
      end
    }
    assert_raise(SystemExit) {
      raise exc
    }
    assert_equal('', out)
  end

# Following tests are not indented because here documents are used extensively.

def test_depsuffixed_name
check(<<'End1', <<'End2')
== ruby-trunk # 2010-12-02T16:51:01+09:00
End1
{"type":"section-start","secname":"ruby-trunk","start-time":"2010-12-02T16:51:01+09:00"},
{"type":"depsuffixed-name","depsuffixed-name":"ruby-trunk"},
{"type":"suffixed-name","suffixed-name":"ruby-trunk"},
{"type":"target-name","target-name":"ruby"}
End2
end

def test_nickname
check(<<'End1', <<'End2', 'nickname')
== ruby-trunk # 2010-12-02T16:51:01+09:00
Nickname: boron
End1
{"type":"nickname","nickname":"boron"},
End2
end

def test_uname
check(<<'End1', <<'End2', 'uname')
== ruby-trunk # 2010-12-02T16:51:01+09:00
uname_srvm: Linux 2.6.18-6-xen-686 #1 SMP Thu Nov 5 19:54:42 UTC 2009 i686
uname_s: Linux
uname_r: 2.6.18-6-xen-686
uname_v: #1 SMP Thu Nov 5 19:54:42 UTC 2009
uname_m: i686
uname_p: unknown
uname_i: unknown
uname_o: GNU/Linux
End1
{"type":"uname","sysname":"Linux","release":"2.6.18-6-xen-686","version":"#1 SMP Thu Nov 5 19:54:42 UTC 2009","machine":"i686","processor":"unknown","hardware-platform":"unknown","operating-system":"GNU/Linux"},
End2
end

def test_debian
check(<<'End1', <<'End2', 'debian')
== ruby-trunk # 2010-12-02T16:51:01+09:00
debian_version: 6.0.9
Debian Architecture: i386
End1
{"type":"debian","version":"6.0.9","architecture":"i386"},
End2
end

def test_lsb
check(<<'End1', <<'End2', 'lsb')
== ruby-trunk # 2010-12-02T16:51:01+09:00
Distributor ID: Debian
Description:    Debian GNU/Linux 6.0.9 (squeeze)
Release:        6.0.9
Codename:       squeeze
End1
{"type":"lsb","Distributor":"Debian","Release":"6.0.9","Codename":"squeeze"},
End2
end

end
