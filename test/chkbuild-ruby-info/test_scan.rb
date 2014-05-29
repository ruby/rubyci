require 'test/unit'
require 'stringio'

require_relative '../../lib/chkbuild-ruby-info'

class TestChkBuildRubyInfo < Test::Unit::TestCase
  @testnum = 0
  def self.defcheck(name, src, expected, type=nil)
    @testnum += 1
    define_method("test_#{@testnum}_#{name}") {
      check(src, expected, type)
    }
  end

  def check(src, expected, type=nil)
    src = StringIO.new(src)
    out = StringIO.new
    ChkBuildRubyInfo.new(src).convert_to_json(out)
    result = out.string.gsub(/,$/, '').sub(/\A\[\n/, '').sub(/\]\n\z/, '')
    if type
      if type.kind_of?(Array)
        json_type_pat = Regexp.union(*type.map {|t| JSON.dump(t) })
      else
        json_type_pat = Regexp.escape(JSON.dump(type))
      end
      pat = /"type":#{json_type_pat}/
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

defcheck(:depsuffixed_name, <<'End1', <<'End2')
== ruby-trunk # 2010-12-02T16:51:01+09:00
End1
{"type":"section-start","secname":"ruby-trunk","start-time":"2010-12-02T16:51:01+09:00"},
{"type":"depsuffixed-name","depsuffixed-name":"ruby-trunk"},
{"type":"suffixed-name","suffixed-name":"ruby-trunk"},
{"type":"target-name","target-name":"ruby"}
End2

defcheck(:nickname, <<'End1', <<'End2', 'nickname')
== ruby-trunk # 2010-12-02T16:51:01+09:00
Nickname: boron
End1
{"type":"nickname","nickname":"boron"},
End2

defcheck(:uname, <<'End1', <<'End2', 'uname')
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

defcheck(:test_debian, <<'End1', <<'End2', 'debian')
== ruby-trunk # 2010-12-02T16:51:01+09:00
debian_version: 6.0.9
Debian Architecture: i386
End1
{"type":"debian","version":"6.0.9","architecture":"i386"},
End2

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

defcheck(:start, <<'End1', <<'End2', %w[start-time build-dir])
== start # 2014-05-28T21:05:12+09:00
start-time: 20140528T120400Z
build-dir: /extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z
End1
{"type":"start-time","start-time":"20140528T120400Z"},
{"type":"build-dir","dir":"/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z"},
End2

["", " optflags=-O0"].each {|str|
defcheck(:configure, <<"End1", <<'End2', %w[start-time build-dir])
== configure # 2014-05-28T21:05:58+09:00
+ ./configure --prefix=/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z#{str}
End1
{"type":"start-time","start-time":"20140528T120400Z"},
{"type":"build-dir","dir":"/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z"},
End2
}

defcheck(:start_and_configure, <<'End1', <<'End2', %w[start-time build-dir])
== start # 2014-05-28T21:05:12+09:00
start-time: 20140528T120400Z
build-dir: /extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z
== configure # 2014-05-28T21:05:58+09:00
+ ./configure --prefix=/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z
End1
{"type":"start-time","start-time":"20140528T120400Z"},
{"type":"build-dir","dir":"/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z"},
End2

defcheck(:all_with_output, <<'End1', <<'End2', 'test-all-result')
== test-all # 2010-12-02T16:51:01+09:00
TestVariable#test_global_variable_0 = (eval):1: warning: possibly useless use of a variable in void context
0.12 s = .
End1
{"type":"test-all-result","test-suite":"test-all","test-name":"TestVariable#test_global_variable_0","output":"(eval):1: warning: possibly useless use of a variable in void context\n","elapsed-time[s]":0.12,"result":"success"},
End2

defcheck(:all_method_with_spaces, <<'End1', <<'End2', 'test-all-result')
== test-all # 2010-12-02T16:51:01+09:00
TestIOScanf#test_" ,10,1.1"(" ,%d,%f") = 0.00 s = .
End1
{"type":"test-all-result","test-suite":"test-all","test-name":"TestIOScanf#test_\" ,10,1.1\"(\" ,%d,%f\")","output":"","elapsed-time[s]":0.0,"result":"success"},
End2

defcheck(:bug, <<'End1', <<'End2', 'BUG')
== ruby-trunk # 2010-12-02T16:51:01+09:00
sample/test.rb:1873: [BUG] Segmentation fault
End1
{"type":"BUG","secname":"ruby-trunk","line-prefix":"sample/test.rb:1873:","message":"Segmentation fault"},
End2

defcheck(:fatal, <<'End1', <<'End2', 'FATAL')
== ruby-trunk # 2010-12-02T16:51:01+09:00
[FATAL] failed to allocate memory
End1
{"type":"FATAL","secname":"ruby-trunk","line-prefix":"","message":"failed to allocate memory"},
End2

defcheck(:make_failure, <<'End1', <<'End2', 'make-failure')
== ruby-trunk # 2010-12-02T16:51:01+09:00
foo
bar make: *** baz
End1
{"type":"make-failure","secname":"ruby-trunk","prev-line":"foo","line-prefix":"bar ","message":"baz"},
End2

defcheck(:glibc_symbol_lookup_error, <<'End1', <<'End2', 'glibc-symbol-lookup-error')
== ruby-trunk # 2010-12-02T16:51:01+09:00
bar: symbol lookup error: baz
End1
{"type":"glibc-symbol-lookup-error","secname":"ruby-trunk","line-prefix":"bar","message":"baz"},
End2

defcheck(:timeout, <<'End1', <<'End2', 'timeout')
== ruby-trunk # 2010-12-02T16:51:01+09:00
foo timeout: command execution time exceeds 1800s
End1
{"type":"timeout","secname":"ruby-trunk","line-prefix":"foo ","message":"command execution time exceeds 1800s"},
End2

defcheck(:glibc_failure, <<'End1', <<'End2', 'glibc-failure')
== ruby-trunk # 2010-12-02T16:51:01+09:00
bar *** baz *** qux
End1
{"type":"glibc-failure","secname":"ruby-trunk","line-prefix":"bar ","message1":"baz","message2":"qux"},
End2

end
