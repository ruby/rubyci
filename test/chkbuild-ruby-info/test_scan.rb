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

  def test_unexpected_format
    exc = nil
    assert_raise(RuntimeError) {
      ChkBuildRubyInfo.new("foo").convert_to_json
    }
  end

  def test_unexpected_format_html
    assert_raise(RuntimeError) {
      ChkBuildRubyInfo.new("<html>").convert_to_json
    }
  end

# Following tests are not indented because here documents are used extensively.

defcheck(:depsuffixed_name, <<'End1', <<'End2', %w[section_start depsuffixed_name suffixed_name target_name])
== ruby-trunk # 2010-12-02T16:51:01+09:00
End1
{"type":"section_start","secname":"ruby-trunk","start_time":"2010-12-02T16:51:01+09:00"},
{"type":"depsuffixed_name","depsuffixed_name":"ruby-trunk"},
{"type":"suffixed_name","suffixed_name":"ruby-trunk"},
{"type":"target_name","target_name":"ruby"}
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
{"type":"uname","sysname":"Linux","release":"2.6.18-6-xen-686","version":"#1 SMP Thu Nov 5 19:54:42 UTC 2009","machine":"i686","processor":"unknown","hardware_platform":"unknown","operating_system":"GNU/Linux"},
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
{"type":"lsb","distributor":"Debian","release":"6.0.9","codename":"squeeze"},
End2
end

defcheck(:test_mac, <<'End1', <<'End2', 'mac')
== ruby-trunk # 2010-12-02T16:51:01+09:00
Nickname: P524
uname_srvm: Darwin 13.2.0 Darwin Kernel Version 13.2.0: Thu Apr 17 23:03:13 PDT 2014; root:xnu-2422.100.13~1/RELEASE_X86_64 x86_64
uname_s: Darwin
uname_r: 13.2.0
uname_v: Darwin Kernel Version 13.2.0: Thu Apr 17 23:03:13 PDT 2014; root:xnu-2422.100.13~1/RELEASE_X86_64
uname_m: x86_64
uname_p: i386
ProductName:    Mac OS X
ProductVersion: 10.9.3
BuildVersion:   13D65
End1
{"type":"mac","product_name":"Mac OS X","product_version":"10.9.3","build_version":"13D65"},
End2

defcheck(:start, <<'End1', <<'End2', %w[start_time build_dir])
== start # 2014-05-28T21:05:12+09:00
start-time: 20140528T120400Z
build-dir: /extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z
End1
{"type":"start_time","start_time":"20140528T120400Z"},
{"type":"build_dir","dir":"/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z"},
End2

["", " optflags=-O0"].each {|str|
defcheck(:configure, <<"End1", <<'End2', %w[start_time build_dir])
== configure # 2014-05-28T21:05:58+09:00
+ ./configure --prefix=/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z#{str}
End1
{"type":"start_time","start_time":"20140528T120400Z"},
{"type":"build_dir","dir":"/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z"},
End2
}

defcheck(:start_and_configure, <<'End1', <<'End2', %w[start_time build_dir])
== start # 2014-05-28T21:05:12+09:00
start-time: 20140528T120400Z
build-dir: /extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z
== configure # 2014-05-28T21:05:58+09:00
+ ./configure --prefix=/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z
End1
{"type":"start_time","start_time":"20140528T120400Z"},
{"type":"build_dir","dir":"/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z"},
End2

defcheck(:all_with_output, <<'End1', <<'End2', 'test_all_result')
== test-all # 2010-12-02T16:51:01+09:00
TestVariable#test_global_variable_0 = (eval):1: warning: possibly useless use of a variable in void context
0.12 s = .
End1
{"type":"test_all_result","test_suite":"test-all","test_name":"TestVariable#test_global_variable_0","output":"(eval):1: warning: possibly useless use of a variable in void context\n","elapsed":0.12,"result":"success"},
End2

defcheck(:all_method_with_spaces, <<'End1', <<'End2', 'test_all_result')
== test-all # 2010-12-02T16:51:01+09:00
TestIOScanf#test_" ,10,1.1"(" ,%d,%f") = 0.00 s = .
End1
{"type":"test_all_result","test_suite":"test-all","test_name":"TestIOScanf#test_\" ,10,1.1\"(\" ,%d,%f\")","output":"","elapsed":0.0,"result":"success"},
End2

defcheck(:test_all_error_detail, <<'End1', <<'End2', 'test_all_error_detail')
== test-all # 2010-12-02T16:51:01+09:00
  1) Error:
TestSymbol#test_gc_attrset:
NameError: cannot make unknown type anonymous ID 4:838aed5 attrset
    /extdisk/chkbuild/chkbuild/tmp/build/20140502T100500Z/ruby/test/ruby/test_symbol.rb:255:in `eval'
    /extdisk/chkbuild/chkbuild/tmp/build/20140502T100500Z/ruby/test/ruby/test_symbol.rb:255:in `block in <main>'
End1
{"type":"test_all_error_detail","test_suite":"test-all","test_name":"TestSymbol#test_gc_attrset","error_class":"NameError","error_message":"cannot make unknown type anonymous ID 4:838aed5 attrset","backtrace":"    ruby/test/ruby/test_symbol.rb:255:in `eval'\n    ruby/test/ruby/test_symbol.rb:255:in `block in <main>'\n"},
End2

defcheck(:test_all_error_detail, <<'End1', <<'End2', 'test_all_error_detail')
== test-all # 2010-12-02T16:51:01+09:00
 16) Error:
test_make_socket_ipv6_multicast(Rinda::TestRingServer):
Errno::EINVAL: Invalid argument - bind(2) for [ff02::1]:7647
    /extdisk/chkbuild/chkbuild/tmp/build/20130411T015300Z/ruby/lib/rinda/ring.rb:117:in `bind'
    /extdisk/chkbuild/chkbuild/tmp/build/20130411T015300Z/ruby/lib/rinda/ring.rb:117:in `make_socket'
    /extdisk/chkbuild/chkbuild/tmp/build/20130411T015300Z/ruby/test/rinda/test_rinda.rb:582:in `test_make_socket_ipv6_multicast'
End1
{"type":"test_all_error_detail","test_suite":"test-all","test_name":"test_make_socket_ipv6_multicast(Rinda::TestRingServer)","error_class":"Errno::EINVAL","error_message":"Invalid argument - bind(2) for [ff02::1]:7647","backtrace":"    ruby/lib/rinda/ring.rb:117:in `bind'\n    ruby/lib/rinda/ring.rb:117:in `make_socket'\n    ruby/test/rinda/test_rinda.rb:582:in `test_make_socket_ipv6_multicast'\n"},
End2

defcheck(:test_all_failure_detail, <<'End1', <<'End2', 'test_all_failure_detail')
== test-all # 2010-12-02T16:51:01+09:00
  1) Failure:
TestThread#test_handle_interrupt [/extdisk/chkbuild/chkbuild/tmp/build/20140502T161600Z/ruby/test/ruby/test_thread.rb:551]:
<[:on_blocking, :c1]> expected but was
<[:on_blocking, :c2]>.
End1
{"type":"test_all_failure_detail","test_suite":"test-all","test_name":"TestThread#test_handle_interrupt","failure_location":"ruby/test/ruby/test_thread.rb:551","detail":"<[:on_blocking, :c1]> expected but was\n<[:on_blocking, :c2]>.\n"}
End2

defcheck(:rubyspec_detail, <<'End1', <<'End2', 'rubyspec_detail')
== rubyspec # 2010-12-02T16:51:01+09:00
1)
Process::Status#exited? for a terminated child returns false FAILED
Expected true to be false
/extdisk/chkbuild/chkbuild/tmp/build/20140511T004100Z/rubyspec/core/process/status/exited_spec.rb:25:in `block (4 levels) in <top (required)>'
/extdisk/chkbuild/chkbuild/tmp/build/20140511T004100Z/rubyspec/core/process/status/exited_spec.rb:3:in `<top (required)>'
End1
{"type":"rubyspec_detail","test_suite":"rubyspec","description":"Process::Status#exited? for a terminated child returns false","outcome":"FAILED","detail":"Expected true to be false\nrubyspec/core/process/status/exited_spec.rb:25:in `block (4 levels) in <top (required)>'\nrubyspec/core/process/status/exited_spec.rb:3:in `<top (required)>'\n"}
End2

defcheck(:rubyspec_detail, <<'End1', <<'End2', 'rubyspec_detail')
== rubyspec # 2010-12-02T16:51:01+09:00
2)
An exception occurred during: Mock.verify_count
Digest::MD5#== equals the appropriate object that responds to to_str FAILED
Mock 'd41d8cd98f00b204e9800998ecf8427e' expected to receive 'to_str' exactly 1 times
but received it 2 times
/extdisk/chkbuild/chkbuild/tmp/build/20140606T222802Z/rubyspec/library/digest/md5/equal_spec.rb:4:in `<top (required)>'
End1
{"type":"rubyspec_detail","test_suite":"rubyspec","description":"An exception occurred during: Mock.verify_count\nDigest::MD5#== equals the appropriate object that responds to to_str","outcome":"FAILED","detail":"Mock 'd41d8cd98f00b204e9800998ecf8427e' expected to receive 'to_str' exactly 1 times\nbut received it 2 times\nrubyspec/library/digest/md5/equal_spec.rb:4:in `<top (required)>'\n"}
End2

defcheck(:exception, <<"End1", <<'End2', 'exception')
== ruby-trunk # 2010-12-02T16:51:01+09:00
sample/test.rb:1873: [BUG] Segmentation fault
/home/akr/chkbuild/tmp/build/ruby-trunk/20110614T005500Z/ruby/test/readline/test_readline_history.rb:280: warning: assigned but unused variable - lines
/home/akr/chkbuild/tmp/build/ruby-trunk/20110614T005500Z/ruby/test/psych/test_string.rb:31: warning: assigned but unused variable - str
/home/akr/chkbuild/tmp/build/ruby-trunk/20110614T005500Z/ruby/test/psych/helper.rb:63:in `<top (required)>': psych should define to_yaml (RuntimeError)
\tfrom /home/akr/chkbuild/tmp/build/ruby-trunk/20110614T005500Z/ruby/lib/rubygems/custom_require.rb:42:in `require'
\tfrom /home/akr/chkbuild/tmp/build/ruby-trunk/20110614T005500Z/ruby/lib/rubygems/custom_require.rb:42:in `require'
\tfrom /home/akr/chkbuild/tmp/build/ruby-trunk/20110614T005500Z/ruby/test/psych/test_string.rb:1:in `<top (required)>'
End1
{"type":"exception","secname":"ruby-trunk","prev_line":"/home/akr/chkbuild/tmp/build/ruby-trunk/20110614T005500Z/ruby/test/psych/test_string.rb:31: warning: assigned but unused variable - str","location":"/home/akr/chkbuild/tmp/build/ruby-trunk/20110614T005500Z/ruby/test/psych/helper.rb:63","caller_name":"<top (required)>","message":": psych should define to_yaml","error_class":"RuntimeError"},
End2

defcheck(:bug, <<'End1', <<'End2', 'bug')
== ruby-trunk # 2010-12-02T16:51:01+09:00
TestRand#test_rand_0x100000000 = 0.00 s = .
TestRand#test_rand_reseed_on_fork = [BUG] Segmentation fault
ruby 2.1.0dev (2013-06-29 trunk 41693) [i686-linux]
End1
{"type":"bug","secname":"ruby-trunk","prev_line":"TestRand#test_rand_0x100000000 = 0.00 s = .","line_prefix":"TestRand#test_rand_reseed_on_fork =","message":"Segmentation fault"},
End2

defcheck(:fatal, <<'End1', <<'End2', 'fatal')
== ruby-trunk # 2010-12-02T16:51:01+09:00
#943 test_thread.rb:268 F
stderr output is not empty
[FATAL] failed to allocate memory
End1
{"type":"fatal","secname":"ruby-trunk","prev_line":"stderr output is not empty","line_prefix":"","message":"failed to allocate memory"},
End2

defcheck(:make_failure, <<'End1', <<'End2', 'make_failure')
== ruby-trunk # 2010-12-02T16:51:01+09:00
foo
bar make: *** baz
End1
{"type":"make_failure","secname":"ruby-trunk","prev_line":"foo","line_prefix":"bar","message":"baz"},
End2

defcheck(:make_failure_gmake, <<'End1', <<'End2', 'make_failure')
== ruby-trunk # 2010-12-02T16:51:01+09:00
foo
bar gmake: *** baz
End1
{"type":"make_failure","secname":"ruby-trunk","prev_line":"foo","line_prefix":"bar","message":"baz"},
End2

defcheck(:glibc_symbol_lookup_error, <<'End1', <<'End2', 'glibc_symbol_lookup_error')
== ruby-trunk # 2010-12-02T16:51:01+09:00
TestBasicInstructions#test_string = 0.00 s = .
TestBasicInstructions#test_xstr = echo: symbol lookup error: /extdisk/chkbuild/chkbuild/tmp/build/20140325T233501Z/ruby/libruby.so.2.2.0: undefined symbol: _start
0.06 s = F
End1
{"type":"glibc_symbol_lookup_error","secname":"ruby-trunk","prev_line":"TestBasicInstructions#test_string = 0.00 s = .","line_prefix":"TestBasicInstructions#test_xstr = echo","library":"/extdisk/chkbuild/chkbuild/tmp/build/20140325T233501Z/ruby/libruby.so.2.2.0","symbol":"_start"},
End2

defcheck(:glibc_symbol_lookup_error, <<'End1', <<'End2', 'glibc_symbol_lookup_error')
== ruby-trunk # 2010-12-02T16:51:01+09:00
TestProcess#test_system_shell = 0.21 s = .
TestProcess#test_system_sigpipe = yes: symbol lookup error: /extdisk/chkbuild/chkbuild/tmp/build/20140325T233501Z/ruby/libruby.so.2.2.0: undefined symbol: _start
ls: symbol lookup error: /extdisk/chkbuild/chkbuild/tmp/build/20140325T233501Z/ruby/libruby.so.2.2.0: undefined symbol: _start
0.20 s = .
TestProcess#test_system_wordsplit = 0.11 s = .
End1
{"type":"glibc_symbol_lookup_error","secname":"ruby-trunk","prev_line":"TestProcess#test_system_shell = 0.21 s = .","line_prefix":"TestProcess#test_system_sigpipe = yes","library":"/extdisk/chkbuild/chkbuild/tmp/build/20140325T233501Z/ruby/libruby.so.2.2.0","symbol":"_start"},
{"type":"glibc_symbol_lookup_error","secname":"ruby-trunk","prev_line":"TestProcess#test_system_sigpipe = yes: symbol lookup error: /extdisk/chkbuild/chkbuild/tmp/build/20140325T233501Z/ruby/libruby.so.2.2.0: undefined symbol: _start","line_prefix":"ls","library":"/extdisk/chkbuild/chkbuild/tmp/build/20140325T233501Z/ruby/libruby.so.2.2.0","symbol":"_start"},
End2

defcheck(:timeout, <<'End1', <<'End2', 'timeout')
== ruby-trunk # 2010-12-02T16:51:01+09:00
Socket#connect_nonblock
- connects the socket to the remote sidetimeout: output interval exceeds 1800.0 seconds.
timeout: the process group 17750 is alive.
End1
{"type":"timeout","secname":"ruby-trunk","prev_line":"Socket#connect_nonblock","line_prefix":"- connects the socket to the remote side","message":"output interval exceeds 1800.0 seconds."},
End2

defcheck(:glibc_failure, <<'End1', <<'End2', 'glibc_failure')
== ruby-trunk # 2010-12-02T16:51:01+09:00
TestArray#test_sort_with_callcc: 0.02 s: .
TestArray#test_sort_with_replace: *** glibc detected *** ./ruby: free(): invalid pointer: 0x088b6dd4 ***
End1
{"type":"glibc_failure","secname":"ruby-trunk","prev_line":"TestArray#test_sort_with_callcc: 0.02 s: .","line_prefix":"TestArray#test_sort_with_replace:","message1":"glibc detected","message2":"./ruby: free(): invalid pointer: 0x088b6dd4 ***"},
End2

defcheck(:section_failure, <<'End1', <<'End2', 'section_failure')
== rubyspec # 2010-12-02T16:51:01+09:00
- writes the buffered data to permanent storage
signal SIGKILL (9)
failed(rubyspec)
End1
{"type":"section_failure","secname":"rubyspec","prev_line":"signal SIGKILL (9)","message":"rubyspec"},
End2

defcheck(:status_success, <<'End1', <<'End2', 'build')
== ruby-trunk # 2014-05-30T08:56:01+09:00
== success # 2014-05-30T09:34:33+09:00
End1
{"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","status":"success"}
End2

defcheck(:status_failure, <<'End1', <<'End2', 'build')
== ruby-trunk # 2014-05-28T10:00:01+09:00
End1
{"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","status":"failure"}
End2

defcheck(:status_netfail, <<'End1', <<'End2', 'build')
== ruby-trunk # 2014-04-12T01:41:00+09:00
== neterror # 2014-04-12T02:41:05+09:00
End1
{"type":"build","depsuffixed_name":"ruby-trunk","suffixed_name":"ruby-trunk","target_name":"ruby","status":"netfail"}
End2

end
