require 'optparse'
require 'zlib'
require 'json'
require 'time'
require 'pp'

class ChkBuildRubyInfo
  attr_accessor :td_common

  def initialize(f)
    @f = f
    @unique_hash = {}
    @json_array_first = nil
    @td_common = nil

    @current_section_name = nil
    @current_section_start_time = nil
    @output_proc = nil
    @out = $stdout
  end

  def with_output_proc(callable)
    save = @output_proc
    @output_proc = callable
    begin
      yield
    ensure
      @output_proc = save
    end
  end

  def output_json_outermost_array
    @json_array_first = true
    yield
    if @json_array_first
      @out.print "[]\n"
    else
      @out.print "\n]\n"
    end
  end

  def output_json_object(hash)
    if self.class.opt_type
      unless self.class.opt_type.include? hash["type"]
        return
      end
    end
    if @td_common
      tblname = hash.delete("table") rescue nil
      tblname = hash["type"] unless tblname
      tblname.tr!('-','_')
      print "@[chkbuild.#{tblname}] "
      puts JSON.dump(hash.merge(@td_common))
      return
    elsif @json_array_first
      @out.print "[\n"
      @json_array_first = false
    else
      @out.print ",\n"
    end
    @out.print JSON.dump(hash)
  end

  def output_unique_hash(hash)
    hash = hash.dup.freeze
    if !@unique_hash.has_key?(hash)
      output_hash(hash)
      @unique_hash[hash] = true
    end
  end

  def first_paragraph(str)
    str.sub(/\n\n[\s\S]*\z/, '')
  end

  def path_after_time(str)
    if %r{/\d{8,}T\d{6}Z/} =~ str
      $'
    else
      str
    end
  end

  def output_hash(hash)
    @output_proc.call hash
  end

  def gsub_path_to_time(str)
    str.gsub(%r{/\S+/\d{8,}T\d{6}Z/}, '')
  end

  def strip_colon(str)
    str.gsub(/\A:|:\z/, '')
  end

  def scan_section_start(secname, rest)
    if /\d{4,}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d/ =~ rest
      t = $&
    end

    if @current_section_name
      h = { "type" => "section-end", "secname" => @current_section_name }
      h["end-time"] = t if t
      if t && @current_section_start_time
        h["elapsed-time[s]"] = Time.iso8601(t) - Time.iso8601(@current_section_start_time)
      end
      output_hash h
    end

    h = { "type" => "section-start", "secname" => secname }
    h["start-time"] = t if t
    output_hash h

    @current_section_name = secname
    @current_section_start_time = t
  end

  def scan_first_section(secname, section)
    #== ruby-trunk # 2014-05-24T22:36:01+09:00
    h = { "type" => "depsuffixed-name", "depsuffixed-name" => secname }
    output_hash h

    suffixed_name = secname[/\A[^_]+/]
    h = { "type" => "suffixed-name", "suffixed-name" => suffixed_name }
    output_hash h

    target_name = suffixed_name[/\A[^-]+/]
    h = { "type" => "target-name", "target-name" => target_name }
    output_hash h

    #Nickname: boron
    if /^Nickname: (\S+)/ =~ section
      output_hash({"type"=>"nickname", "nickname"=>$1 })
    end

    uname = { "type" => "uname" }
    uname["sysname"] = $1 if /^uname_s: (.+)$/ =~ section
    uname["release"] = $1 if /^uname_r: (.+)$/ =~ section
    uname["version"] = $1 if /^uname_v: (.+)$/ =~ section
    uname["machine"] = $1 if /^uname_m: (.+)$/ =~ section
    uname["processor"] = $1 if /^uname_p: (.+)$/ =~ section
    uname["hardware-platform"] = $1 if /^uname_i: (.+)$/ =~ section
    uname["operating-system"] = $1 if /^uname_o: (.+)$/ =~ section
    output_hash(uname) if 1 < uname.size

    debian = { "type" => "debian" }
    debian["version"] = $1 if /^debian_version: (\S+)$/ =~ section
    debian["architecture"] = $1 if /^Debian Architecture: (\S+)$/ =~ section
    output_hash(debian) if 1 < debian.size

    lsb = { "type" => "lsb" } # lsb_release
    lsb["Distributor"] = $1 if /^Distributor ID:\s*(\S+)$/ =~ section
    lsb["Description"] = $1 if /^Description:\s*(\S+)$/ =~ section
    lsb["Release"] = $1 if /^Release:\s*(\S+)$/ =~ section
    lsb["Codename"] = $1 if /^Codename:\s*(\S+)$/ =~ section
    output_hash(lsb) if 1 < lsb.size
  end

  def scan_start(section)
    if /^start-time: (\S+)/ =~ section
      output_unique_hash({"type"=>"start-time", "start-time"=>$1 })
    end

    if /^build-dir: (\S+)/ =~ section
      output_unique_hash({"type"=>"build-dir", "dir"=>$1 })
    end
  end

  def scan_autoconf_version(section)
    #autoconf (GNU Autoconf) 2.67
    if /^autoconf \(GNU Autoconf\) (\S+)/ =~ section
      output_hash({"type"=>"autoconf-version", "version"=>$1 })
    end
  end

  def scan_bison_version(section)
    #bison (GNU Bison) 2.4.1
    if /^bison \(GNU Bison\) (\S+)/ =~ section
      output_hash({"type"=>"bison-version", "version"=>$1 })
    end
  end

  def scan_version_h(section)
    ##define RUBY_VERSION "2.2.0"
    ##define RUBY_RELEASE_DATE "2014-05-24"
    ##define RUBY_PATCHLEVEL -1
    ##define RUBY_BRANCH_NAME "trunk"
    ##define RUBY_RELEASE_YEAR 2014
    ##define RUBY_RELEASE_MONTH 5
    ##define RUBY_RELEASE_DAY 24
    h = { "type" => "ruby-release" }
    h["version"] = $1 if /^\#define RUBY_VERSION "(\S+)"/ =~ section
    h["release_date"] = $1 if /^\#define RUBY_RELEASE_DATE "(\S+)"/ =~ section
    h["patchlevel"] = $1.to_i if /^\#define RUBY_PATCHLEVEL (\S+)/ =~ section
    h["branch_name"] = $1 if /^\#define RUBY_BRANCH_NAME "(\S+)"/ =~ section
    h["release_year"] = $1.to_i if /^\#define RUBY_RELEASE_YEAR (\S+)/ =~ section
    h["release_month"] = $1.to_i if /^\#define RUBY_RELEASE_MONTH (\S+)/ =~ section
    h["release_day"] = $1.to_i if /^\#define RUBY_RELEASE_DAY (\S+)/ =~ section
    output_hash(h) if 1 < h.size
  end

  def scan_configure(section)
    if %r{^\+ \S+/configure --prefix=(\S+/([0-9]{8,}T[0-9]{6}Z?))(?: |$)} =~ section
      output_unique_hash({"type"=>"start-time", "start-time"=>$2 })
      output_unique_hash({"type"=>"build-dir", "dir"=>$1 })
    end
  end

  def scan_verconf_h(section)
    ##define RUBY_PLATFORM "i686-linux"
    if /^\#define RUBY_PLATFORM "(\S+)"/ =~ section
      output_hash({"type"=>"ruby-platform", "platform"=>$1 })
    end
  end

  def scan_config_files(section)
    #config.guess: 2014-03-23
    #config.sub: 2014-05-01
    h = { "type" => "config-files" }
    h["config.guess"] = $1 if /^config\.guess: (\S+)/ =~ section
    h["config.sub"] = $1 if /^config\.sub: (\S+)/ =~ section
    output_hash(h) if 1 < h.size
  end

  def scan_cc_version(section)
    #gcc (GCC) 4.8.0
    if /^gcc \(GCC\) (\S+)/ =~ section
      output_hash({"type"=>"cc-version", "cc"=>"gcc", "version"=>$1 })
    end
  end

  def scan_miniruby_libc(section)
    #GNU C Library (Debian EGLIBC 2.11.3-4) stable release version 2.11.3, by Roland McGrath et al.
    if /^(GNU C Library .*), by/ =~ section
      output_hash({"type"=>"libc-version", "version"=>$1 })
    end
  end

  def scan_svn(section)
    # chkbuild run "svn info" since 2009-12-16.
    url = /^Repository Root: (\S+)$/.match(section)
    lastrev = /^Last Changed Rev: (\d+)$/.match(section)
    if url && lastrev
      h = {
        "type" => "svn",
        "URL" => url[1],
        "rev" => lastrev[1].to_i
      }
      output_hash h
    end
  end

  def scan_svn_old_chkbuild(section)
    # chkbuild didn't run "svn info" but recorded CHG line between 2007-11-01 and 2009-12-16.
    #
    #+ svn checkout -q http://svn.ruby-lang.org/repos/ruby/trunk ruby
    #CHG .   26102->26106    http://svn.ruby-lang.org/cgi-bin/viewvc.cgi?view=rev&revision=26106;diff_format=u
    url = /^\+ svn checkout -q (\S*)/.match(section)
    lastrev = /^CHG \.\t\d+->(\d+)/.match(section)
    if url && lastrev
      h = {
        "type" => "svn",
        "URL" => url[1],
        "rev" => lastrev[1].to_i
      }
      output_hash h
    end
  end

  def scan_git(section)
    #CHECKOUT git git://github.com/nurse/mspec.git mspec
    #LASTCOMMIT 88ffc944daaa9f1894521f8abaddc88d9a087342
    url = /^CHECKOUT git (\S+)/.match(section)
    commit = /^LASTCOMMIT (\S+)$/.match(section)
    if url && commit
      h = {
        "type" => "git",
        "URL" => url[1],
        "commit" => commit[1]
      }
      output_hash h
    end
  end

  def scan_method_list(section)
    #class ARGF.class [Enumerable, Object, Kernel, BasicObject]
    #ARGF.class#argv 0
    #ARGF.class#each -1
    #Array.[] -1
    #Array#<< 1
    #File.lchmod 0 not-implemented
    #module Comparable []
    #class fatal [Exception, Object, Kernel, BasicObject]
    #
    #Old format:
    #ARGF.class [Enumerable, Object, Kernel, BasicObject]
    section.each_line {|line|
      case line
      when /\A(?:(module|class) )?(\S+) \[(.*)\]\n/
        module_or_class = $1
        h = {
          'type' => 'builtin-module',
          'module' => $2,
          'ancestors' => $3.split(/,\s*/)
        }
        if module_or_class
          h['class'] = module_or_class == 'class'
        end
        output_hash h
      when /\A(\S+)\#(\S+) (-?\d+)( not-implemented)?\n/
        h = {
          'type' => 'builtin-instance-method',
          'class' => $1,
          'method' => $2,
          'arity' => $3.to_i,
          'implemented' => $4 ? false : true
        }
        output_hash h
      when /\A(\S+)\.(\S+) (-?\d+)( not-implemented)?\n/
        h = {
          'type' => 'builtin-class-method',
          'class' => $1,
          'method' => $2,
          'arity' => $3.to_i,
          'implemented' => $4 ? false : true
        }
        output_hash h
      end
    }
  end

  def scan_showflags(section)
    h = { 'type' => 'make-flags' }
    h["CC"] = $1.strip if /^[ \t]+CC = (.+)\n/ =~ section
    h["LD"] = $1.strip if /^[ \t]+LD = (.+)\n/ =~ section
    h["LDSHARED"] = $1.strip if /^[ \t]+LDSHARED = (.+)\n/ =~ section
    h["CFLAGS"] = $1.strip if /^[ \t]+CFLAGS = (.+)\n/ =~ section
    h["XCFLAGS"] = $1.strip if /^[ \t]+XCFLAGS = (.+)\n/ =~ section
    h["CPPFLAGS"] = $1.strip if /^[ \t]+CPPFLAGS = (.+)\n/ =~ section
    h["DLDFLAGS"] = $1.strip if /^[ \t]+DLDFLAGS = (.+)\n/ =~ section
    h["SOLIBS"] = $1.strip if /^[ \t]+SOLIBS = (.+)\n/ =~ section
    h["target"] = $1.strip if /^Target: (.+)\n/ =~ section
    output_hash h
  end

  def scan_ruby_v(section)
    #ruby 2.2.0dev (2014-05-24 trunk 46082) [i686-linux]
    if /^ruby .*/ =~ section
      output_hash({"type"=>"ruby-version", "version"=>$& })
    end
  end

  def scan_version_list(section)
    %w[
      libc
      gmp
      dbm
      gdbm
      readline
      openssl
      zlib
      tcltklib
      curses
    ].each {|lib|
      if /^#{Regexp.escape lib}: (.*)\n/ =~ section
        h = { 'type' => "ruby-#{lib}-version", "version" => $1 }
        output_hash h
      end
    }
  end

  def scan_abi_check(section)
    high = 0
    section.scan(/ High +([0-9])+ *$/) { high += $1.to_i }
    medium = 0
    section.scan(/ Medium +([0-9])+ *$/) { medium += $1.to_i }
    low = 0
    section.scan(/ Low +([0-9])+ *$/) { low += $1.to_i }
    h = {
      'type' => "abi-check-summary",
      "high" => high,
      "medium" => medium,
      "low" => low
    }
    output_hash h
  end

  BTEST_RESULT_MAP = {
    '.' => 'success',
    'F' => 'failure',
  }
  def scan_btest(secname, section)
    #test_io.rb
    ##257 test_io.rb:1 .
    ##258 test_io.rb:11 .
    ##259 test_io.rb:34 .
    ##260 test_io.rb:44 F
    #stderr output is not empty
    #   /extdisk/chkbuild/chkbuild/tmp/build/20140424T124800Z/ruby/lib/tmpdir.rb:8:in `require': cannot load such file -- etc.so (LoadError)
    #           from /extdisk/chkbuild/chkbuild/tmp/build/20140424T124800Z/ruby/lib/tmpdir.rb:8:in `<top (required)>'
    #           from bootstraptest.tmp.rb:2:in `require'
    #           from bootstraptest.tmp.rb:2:in `<main>'
    ##261 test_io.rb:60 F
    #stderr output is not empty
    #   /extdisk/chkbuild/chkbuild/tmp/build/20140424T124800Z/ruby/lib/tmpdir.rb:8:in `require': cannot load such file -- etc.so (LoadError)
    #           from /extdisk/chkbuild/chkbuild/tmp/build/20140424T124800Z/ruby/lib/tmpdir.rb:8:in `<top (required)>'
    #           from bootstraptest.tmp.rb:2:in `require'
    #           from bootstraptest.tmp.rb:2:in `<main>'
    ##262 test_io.rb:77 .
    ##263 test_io.rb:85 .
    ##264 test_io.rb:105 .
    ##265 test_io.rb:112 .

    #KNOWNBUGS.rb #1 KNOWNBUGS.rb:16:in `<top (required)>'
    #F

    section.scan(/\#(\d+) (\S+):(\d+)(.*)\s([.F])$/) {
      h = {
        "type" => "#{secname}-result",
        "test-suite" => secname,
        "testnum" => $1,
        "file" => $2,
        "line" => $3,
        "caller" => strip_colon($4),
        "result" => BTEST_RESULT_MAP.fetch($5, $5)
      }
      output_hash h
    }

    ##260 test_io.rb:44:
    #     require 'tmpdir'
    #     begin
    #       tmpname = "#{Dir.tmpdir}/ruby-btest-#{$$}-#{rand(0x100000000).to_s(36)}"
    #       rw = File.open(tmpname, File::RDWR|File::CREAT|File::EXCL)
    #     rescue Errno::EEXIST
    #       retry
    #     end
    #     save = STDIN.dup
    #     STDIN.reopen(rw)
    #     STDIN.reopen(save)
    #     rw.close
    #     File.unlink(tmpname) unless RUBY_PLATFORM['nacl']
    #     :ok
    #  #=> "" (expected "ok")

    ##1 KNOWNBUGS.rb:16:in `<top (required)>': 
    #     open("tst-remove-load.rb", "w") {|f|
    #       f << <<-'End'
    #         module Kernel
    #           remove_method :load
    #         end
    #         raise
    #       End
    #     }
    #     load "tst-remove-load.rb"
    #  #=> killed by SIGSEGV (signal 11)
    #| tst-remove-load.rb:4: [BUG] Segmentation fault
    #| ruby 1.9.2dev (2010-02-20 trunk 26717) [i686-linux]
    #| 
    #| -- control frame ----------
    #| c:0006 p:0019 s:0015 b:0015 l:000014 d:000014 TOP    tst-remove-load.rb:4
    #| c:0005 p:---- s:0013 b:0013 l:000012 d:000012 FINISH
    #  [ruby-dev:40234] [ruby-core:27959]
    #FAIL 1/1 tests failed

    section.scan(/^\#(\d+) (\S+):(\d+):(.*) \n((?: {5}.*\n)*)  \#=> (.*)/) {
      h = {
        "type" => "#{secname}-detail",
        "test-suite" => secname,
        "testnum" => $1,
        "file" => $2,
        "line" => $3,
        "caller" => strip_colon($4),
        "code" => $5,
        "message" => $6,
      }
      output_hash h
    }

    if /^No tests, no problem$/ =~ section
      h = {
        "type" => "#{secname}-summary",
        "test-suite" => secname,
        "tests" => 0,
        "failures" => 0
      }
      output_hash h
    elsif /^PASS all (\d+) tests/ =~ section
      h = {
        "type" => "#{secname}-summary",
        "test-suite" => secname,
        "tests" => $1.to_i,
        "failures" => 0
      }
      output_hash h
    elsif /^FAIL (\d+)\/(\d+) tests failed/ =~ section
      h = {
        "type" => "#{secname}-summary",
        "test-suite" => secname,
        "tests" => $2.to_i,
        "failures" => $1.to_i,
      }
      output_hash h
    end
  end

  def scan_testrb(section)
    #sample/test.rb:assignment .ok 1 (sample/test.rb:129:in `<main>')
    #.ok 2 (sample/test.rb:131:in `<main>')
    #.ok 3 (sample/test.rb:135:in `<main>')
    #.ok 4 (sample/test.rb:137:in `<main>')

    #.ok 59 (sample/test.rb:1719:in `<main>')
    #.ok 60 (sample/test.rb:1720:in `<main>')
    #Fnot ok string & char 61 -- sample/test.rb:1721:in `<main>'
    #.ok 62 (sample/test.rb:1728:in `<main>')
    # 62
    #sample/test.rb:assignment .ok 1 (sample/test.rb:1732:in `<main>')
    #.ok 2 (sample/test.rb:1733:in `<main>')
    #.ok 3 (sample/test.rb:1737:in `<main>')

    what = nil
    section.scan(%r{^sample/test\.rb:(.*) (?=[.F])|\.ok (\d+) \((.*)\)|not ok (.*) (\d+) -- (.*)\n}) {
      if $1
        what = $1
      elsif $2
        h = {
          "type" => "testrb-result",
          "test-suite" => "testrb",
          "what" => what,
          "testnum" => $2.to_i,
          "location" => $3,
          "result" => "success",
        }
        output_hash h
      else
        h = {
          "type" => "testrb-result",
          "test-suite" => "testrb",
          "what" => $4,
          "testnum" => $5.to_i,
          "location" => $6,
          "result" => "failure",
        }
        output_hash h
      end
    }

    if /^end of test\(test: (\d+)\)/ =~ section
      h = {
        "type" => "testrb-summary",
        "test-suite" => "testrb",
        "tests" => $1.to_i,
        "failures" => 0,
      }
      output_hash h
    elsif /^test: (\d+) failed (\d+)/ =~ section || %r{^not ok/test: (\d+) failed (\d+)} =~ section
      h = {
        "type" => "testrb-summary",
        "test-suite" => "testrb",
        "tests" => $1.to_i,
        "failures" => $2.to_i,
      }
      output_hash h
    end
  end

  TEST_ALL_RESULT_MAP = {
    '.' => 'success',
    'E' => 'error',
    'F' => 'failure',
    'S' => 'skip',
  }
  def scan_test_all(secname, section)
    if /^Finished tests in / =~ section
      list = $`
      detailed_failures = $'
    else
      # test-all not finished properly?
      list = section
    end

    list.scan(/^(\S+\#.+?) = ([\s\S]*?)(\d+\.\d+) s = ([EFS.])$/) {
      h = {
        "table" => "test-all-result",
        "type" => "#{secname}-result",
        "test-suite" => secname,
        "test-name" => $1,
        "output" => $2,
        "elapsed-time[s]" => $3.to_f,
        "result" => TEST_ALL_RESULT_MAP.fetch($4, $4),
      }
      output_hash h
    }

    if detailed_failures
      ary = detailed_failures.split(/^  (\d+)\) /)
      ary.slice_before(/\A\d+\z/).each {|num, body|
        next if /\A\d+\z/ !~ num || !body

        #  1) Error:
        #TestSymbol#test_gc_attrset:
        #NameError: cannot make unknown type anonymous ID 4:838aed5 attrset
        #    /extdisk/chkbuild/chkbuild/tmp/build/20140502T100500Z/ruby/test/ruby/test_symbol.rb:255:in `eval'
        #    /extdisk/chkbuild/chkbuild/tmp/build/20140502T100500Z/ruby/test/ruby/test_symbol.rb:255:in `block in <main>'
        #    /extdisk/chkbuild/chkbuild/tmp/build/20140502T100500Z/ruby/test/ruby/test_symbol.rb:254:in `each'
        #    /extdisk/chkbuild/chkbuild/tmp/build/20140502T100500Z/ruby/test/ruby/test_symbol.rb:254:in `<main>'
        if /\AError:\n(\S+):\n(\S+): (.*)\n/ =~ body
          h = {
            "table" => "test-all-error-detail",
            "type" => "#{secname}-error-detail",
            "test-suite" => secname,
            "test-name" => $1,
            "error-class" => $2,
            "error-message" => $3,
            "backtrace" => gsub_path_to_time(first_paragraph($'))
          }
          output_hash h
        end

        #  1) Failure:
        #TestThread#test_handle_interrupt [/extdisk/chkbuild/chkbuild/tmp/build/20140502T161600Z/ruby/test/ruby/test_thread.rb:551]:
        #<[:on_blocking, :c1]> expected but was
        #<[:on_blocking, :c2]>.
        if /\AFailure:\n(\S+) \[(.*)\]:\n/ =~ body
          h = {
            "table" => "test-all-failure-detail",
            "type" => "#{secname}-failure-detail",
            "test-suite" => secname,
            "test-name" => $1,
            "failure-location" => path_after_time($2),
            "detail" => first_paragraph($')
          }
          output_hash h
        end
      }
    end

    if /^(\d+) tests, (\d+) assertions, (\d+) failures, (\d+) errors(?:, (\d+) skips)?$/m =~ section
      h = {
        "table" => "test-all-summary",
        "type" => "#{secname}-summary",
        "test-suite" => secname,
        "tests" => $1.to_i,
        "assertions" => $2.to_i,
        "failures" => $3.to_i,
        "errors" => $4.to_i,
      }
      h["skips"] = $5.to_i if $5
      output_hash h
    end
  end

  def scan_rubyspec(secname, section)
    if /^1\)\n/ =~ section
      list = $`
      detailed_failures = $& + $'
    else
      # rubyspec not finished properly?
      list = section
    end

    if detailed_failures

      #1)
      #Process::Status#exited? for a terminated child returns false FAILED
      #Expected true to be false
      #/extdisk/chkbuild/chkbuild/tmp/build/20140511T004100Z/rubyspec/core/process/status/exited_spec.rb:25:in `block (4 levels) in <top (required)>'
      #/extdisk/chkbuild/chkbuild/tmp/build/20140511T004100Z/rubyspec/core/process/status/exited_spec.rb:3:in `<top (required)>'

      detailed_failures.split(/^\d+\)\n/).each {|body|
        body = first_paragraph(body)
        next if /\n/ !~ body
        h = {
          "table" => "rubyspec-detail",
          "type" => "#{secname}-detail",
          "test-suite" => secname,
          "description" => gsub_path_to_time($`),
          "detail" => gsub_path_to_time($')
        }
        output_hash h
      }
    end

    if /^(\d+) files?, (\d+) examples?, (\d+) expectations?, (\d+) failures?, (\d+) errors?$/m =~ section
      h = {
        "table" => "rubyspec-summary",
        "type" => "#{secname}-summary",
        "test-suite" => secname,
        "files" => $1.to_i,
        "examples" => $2.to_i,
        "expectations" => $3.to_i,
        "failures" => $4.to_i,
        "errors" => $5.to_i,
      }
      output_hash h
    end
  end

  def scan_bug(secname, section)
    section.each_line {|line|
      #sample/test.rb:1873: [BUG] Segmentation fault
      next if /\[BUG\]/ !~ line
      prefix = $`
      message = $'
      #Expected /#<Bogus:/ to match "-e:3: [BUG] Segmentation fault\nruby ...
      next if /\\n/ =~ line
      h = {
        'type' => 'BUG',
        'secname' => secname,
        'line-prefix' => prefix.strip,
        'message' => message.strip
      }
      output_hash h
    }
  end

  def scan_fatal(secname, section)
    section.each_line {|line|
      #[FATAL] failed to allocate memory
      next if /\[FATAL\]/ !~ line
      prefix = $`
      message = $'
      h = {
        'type' => 'FATAL',
        'secname' => secname,
        'line-prefix' => prefix.strip,
        'message' => message.strip
      }
      output_hash h
    }
  end

  def scan_make_failure(secname, section)
    section.scan(/^(.*)\n(.*)make: \*\*\* (.*)\n/) { # GNU make
      h = {
        "type" => "make-failure",
        "secname" => secname,
        "prev-line" => $1,
        "line-prefix" => $2,
        "message" => $3
      }
      output_hash h
    }
  end

  def scan_glibc_failure(secname, section)
    section.scan(/^(.*)\*\*\* (.*) \*\*\*(.*)\n/) {
      h = {
        "type" => "glibc-failure",
        "secname" => secname,
        "line-prefix" => $1,
        "message1" => $2,
        "message2" => $3.strip
      }
      output_hash h
    }
    section.scan(/^(.*): symbol lookup error: (.*)\n/) {
      h = {
        "type" => "glibc-symbol-lookup-error",
        "secname" => secname,
        "line-prefix" => $1,
        "message" => $2.strip
      }
      output_hash h
    }
  end

  def scan_timeout(secname, section)
    section.scan(/^(.*)timeout: ((command execution time exceeds|output interval exceeds|too long line\.) .*)\n/) {
      h = {
        "type" => "timeout",
        "secname" => secname,
        "line-prefix" => $1,
        "message" => $2
      }
      output_hash h
    }
  end

  def detect_section_failure(secname, section)
    if /^failed\((.*)\)\n\z/ =~ section
      h = {
        "type" => "section-failure",
        "secname" => secname,
        "message" => $1
      }
      output_hash h
    end
  end

  def extract_info(f)
    first = true
    f.each_line("\n== ") {|section|
      section.scrub!
      section.sub!(/\n== \z/, '')
      if first
        if /\A<html>/ =~ section
          $stderr.puts "chkbuild-ruby-info needs text log (not HTML log)."
          exit false
        end
        if /\A== / !~ section
          $stderr.puts "It seems not a chkbuild log."
          exit false
        end
      else
        section = '== ' + section
      end
      if /\n\z/ !~ section
        section << "\n"
      end
      section_line = section.lines.first
      _, secname, rest =  section_line.split(/\s+/, 3)
      scan_section_start(secname, rest)
      scan_first_section(secname, section) if first
      case secname
      when "start"
        scan_start(section)
      when "autoconf-version"
        scan_autoconf_version(section)
      when "bison-version"
        scan_bison_version(section)
      when "svn/ruby", "svn-info/ruby"
        scan_svn(section)
      when "svn"
        scan_svn_old_chkbuild(section)
      when "git/mspec", "git/rubyspec", "git-mspec", "git-rubyspec"
        scan_git(section)
      when "version.h"
        scan_version_h(section)
      when "configure"
        scan_configure(section)
      when "verconf.h"
        scan_verconf_h(section)
      when "config-files"
        scan_config_files(section)
      when "cc-version"
        scan_cc_version(section)
      when "miniruby-libc"
        scan_miniruby_libc(section)
      when "btest"
        scan_btest(secname, section)
      when "test.rb"
        scan_testrb(section)
      when "method-list"
        scan_method_list(section)
      when "showflags"
        scan_showflags(section)
      when "test-knownbug"
        scan_btest(secname, section)
      when "version"
        scan_ruby_v(section)
      when "version-list"
        scan_version_list(section)
      when "abi-check-notitle", "abi-check"
        scan_abi_check(section)
      when "test-all", %r{\Atest/}
        scan_test_all(secname, section)
      when "rubyspec", %r{\Arubyspec/}
        scan_rubyspec(secname, section)
      end
      scan_bug(secname, section)
      scan_fatal(secname, section)
      scan_make_failure(secname, section)
      scan_glibc_failure(secname, section)
      scan_timeout(secname, section)
      detect_section_failure(secname, section)
      first = false
    }
  end

  def extract(&block)
    with_output_proc(block) {
      extract_info(@f)
    }
  end

  def convert_to_json(out=$stdout)
    @out = out
    output_proc = lambda {|hash| output_json_object hash }
    with_output_proc(output_proc) {
      if @td_common
        extract_info(@f)
      else
        output_json_outermost_array {
          extract_info(@f)
        }
      end
    }
  end

  class << self
    attr_reader :opt_type
  end
  @opt_type = nil

  def self.optionparser
    o = OptionParser.new
    o.def_option('-h', 'show this message') { puts o; exit }
    o.def_option('--type TYPE,...', 'show only specified types') {|val|
      @opt_type = val.split(/,/)
    }
    o
  end

  def self.open_stdin
    magic = $stdin.read(2).b
    $stdin.ungetc(magic)
    if magic == "\x1f\x8b".b
      Zlib::GzipReader.wrap($stdin) {|f|
        yield f
      }
    else
      yield $stdin
    end
  end

  def self.open_log(filename)
    if /\.gz\z/ =~ filename
      Zlib::GzipReader.open(filename) {|f|
        yield f
      }
    else
      File.open(filename) {|f|
        yield f
      }
    end
  end

  def self.each_argfile(argv)
    if argv.empty?
      open_stdin {|f|
        yield f
      }
    else
      argv.each {|filename|
        open_log(filename) {|f|
          yield f
        }
      }
    end
  end

  def self.main(argv)
    optionparser.parse!(argv)
    each_argfile(argv) {|f|
      ChkBuildRubyInfo.new(f).convert_to_json
    }
  end

end
