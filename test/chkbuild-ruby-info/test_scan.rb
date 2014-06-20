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

  def self.defcheck_build(name, src, expected_hash)
    @testnum += 1
    define_method("test_#{@testnum}_#{name}") {
      check_build(src, expected_hash)
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

  def check_build(src, expected_hash)
    src = StringIO.new(src)
    build_hash = nil
    ChkBuildRubyInfo.new(src).extract {|hash|
      if hash['type'] == 'build'
        build_hash = hash
        break
      end
    }
    assert(build_hash != nil)
    expected_hash.each {|k, v|
      assert_equal(v, build_hash[k], "key: #{k.inspect}")
    }
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

debian_gnu_linux_first_section = <<'End'
== echo # 2014-06-07T22:14:02+09:00
Nickname: boron
uname_srvm: Linux 2.6.26-2-xen-686 #1 SMP Thu Jan 27 05:44:37 UTC 2011 i686
uname_s: Linux
uname_r: 2.6.26-2-xen-686
uname_v: #1 SMP Thu Jan 27 05:44:37 UTC 2011
uname_m: i686
uname_p: unknown
uname_i: unknown
uname_o: GNU/Linux
debian_version: 7.5
Debian Architecture: i386
Distributor ID: Debian
Description:    Debian GNU/Linux 7.5 (wheezy)
Release:        7.5
Codename:       wheezy
End

defcheck(:uname, debian_gnu_linux_first_section, <<'End2', 'uname')
{"type":"uname","sysname":"Linux","release":"2.6.26-2-xen-686","version":"#1 SMP Thu Jan 27 05:44:37 UTC 2011","machine":"i686","processor":"unknown","hardware_platform":"unknown","operating_system":"GNU/Linux"},
End2

defcheck(:test_debian, debian_gnu_linux_first_section, <<'End2', %w[debian_version debian_architecture])
{"type":"debian_version","debian_version":"7.5"},
{"type":"debian_architecture","debian_architecture":"i386"},
End2

defcheck(:test_lsb, debian_gnu_linux_first_section, <<'End2', 'lsb')
{"type":"lsb","distributor":"Debian","description":"Debian GNU/Linux 7.5 (wheezy)","release":"7.5","codename":"wheezy"},
End2

defcheck(:os_debian, debian_gnu_linux_first_section, <<'End2' , 'os')
{"type":"os","os":"Debian GNU/Linux 7.5 (wheezy)","arch":"i686"}
End2

defcheck_build(:build_debian, debian_gnu_linux_first_section,
               "debian_version" => "7.5",
               "debian_architecture" => "i386",
               "lsb_distributor" => "Debian",
               "lsb_description" => "Debian GNU/Linux 7.5 (wheezy)",
               "lsb_release" => "7.5",
               "lsb_codename" => "wheezy",
               "os" => "Debian GNU/Linux 7.5 (wheezy)",
               "arch" => "i686")

debian_gnu_linux_first_sections =<<'End'
== ruby-trunk # 2014-06-11T23:46:38+09:00
Nickname: dew
== uname # 2014-06-11T23:46:38+09:00
uname_srvm: Linux 3.2.0-4-amd64 #1 SMP Debian 3.2.57-3+deb7u2 x86_64
uname_s: Linux
uname_r: 3.2.0-4-amd64
uname_v: #1 SMP Debian 3.2.57-3+deb7u2
uname_m: x86_64
uname_p: unknown
uname_i: unknown
uname_o: GNU/Linux
== /etc/debian_version # 2014-06-11T23:46:38+09:00
7.5
== dpkg # 2014-06-11T23:46:38+09:00
architecture: amd64
== lsb_release # 2014-06-11T23:46:38+09:00
Distributor ID: Debian
Description:    Debian GNU/Linux 7.5 (wheezy)
Release:        7.5
Codename:       wheezy
End

defcheck_build(:build_debian, debian_gnu_linux_first_sections,
               "debian_version" => "7.5",
               "debian_architecture" => "amd64",
               "lsb_distributor" => "Debian",
               "lsb_description" => "Debian GNU/Linux 7.5 (wheezy)",
               "lsb_release" => "7.5",
               "lsb_codename" => "wheezy",
               "os" => "Debian GNU/Linux 7.5 (wheezy)",
               "arch" => "x86_64")

debian_gnu_kfreebsd_first_section = <<'End'
== echo # 2014-06-07T22:49:33+09:00
Nickname: debian7-kfreebsd
uname_srvm: GNU/kFreeBSD 9.0-2-amd64 #0 Sat Nov 24 04:44:27 UTC 2012 x86_64
uname_s: GNU/kFreeBSD
uname_r: 9.0-2-amd64
uname_v: #0 Sat Nov 24 04:44:27 UTC 2012
uname_m: x86_64
uname_p: amd64
uname_i: QEMU Virtual CPU version 1.1.2
uname_o: GNU/kFreeBSD
debian_version: 7.0
Debian Architecture: kfreebsd-amd64
Distributor ID: Debian
Description:    Debian GNU/kFreeBSD 7.0 (wheezy)
Release:        7.0
Codename:       wheezy
End

defcheck(:test_debian_kfreebsd, debian_gnu_kfreebsd_first_section, <<'End2', %w[debian_version debian_architecture])
{"type":"debian_version","debian_version":"7.0"},
{"type":"debian_architecture","debian_architecture":"kfreebsd-amd64"},
End2

defcheck(:os_debian_kfreebsd, debian_gnu_kfreebsd_first_section, <<'End2' , 'os')
{"type":"os","os":"Debian GNU/kFreeBSD 7.0 (wheezy)","arch":"x86_64"}
End2

defcheck_build(:build_debian_kfreebsd, debian_gnu_kfreebsd_first_section,
               "debian_version" => "7.0",
               "debian_architecture" => "kfreebsd-amd64",
               "lsb_distributor" => "Debian",
               "lsb_description" => "Debian GNU/kFreeBSD 7.0 (wheezy)",
               "lsb_release" => "7.0",
               "lsb_codename" => "wheezy",
               "os" => "Debian GNU/kFreeBSD 7.0 (wheezy)",
               "arch" => "x86_64")

debian_gnu_kfreebsd_first_sections = <<'End'
== echo # 2014-06-12T21:00:41+09:00
Nickname: debian7-kfreebsd
== uname # 2014-06-12T21:00:41+09:00
uname_srvm: GNU/kFreeBSD 9.0-2-amd64 #0 Sat Nov 24 04:44:27 UTC 2012 x86_64
uname_s: GNU/kFreeBSD
uname_r: 9.0-2-amd64
uname_v: #0 Sat Nov 24 04:44:27 UTC 2012
uname_m: x86_64
uname_p: amd64
uname_i: QEMU Virtual CPU version 1.1.2
uname_o: GNU/kFreeBSD
== /etc/debian_version # 2014-06-12T21:00:41+09:00
7.0
== dpkg # 2014-06-12T21:00:41+09:00
architecture: kfreebsd-amd64
== lsb_release # 2014-06-12T21:00:41+09:00
Distributor ID: Debian
Description:    Debian GNU/kFreeBSD 7.0 (wheezy)
Release:        7.0
Codename:       wheezy
End

defcheck_build(:build_debian_kfreebsd, debian_gnu_kfreebsd_first_sections,
               "debian_version" => "7.0",
               "debian_architecture" => "kfreebsd-amd64",
               "lsb_distributor" => "Debian",
               "lsb_description" => "Debian GNU/kFreeBSD 7.0 (wheezy)",
               "lsb_release" => "7.0",
               "lsb_codename" => "wheezy",
               "os" => "Debian GNU/kFreeBSD 7.0 (wheezy)",
               "arch" => "x86_64")

debian_gnu_hurd_first_section = <<'End'
== echo # 2014-06-07T22:50:06+09:00
Nickname: hurd
uname_srvm: GNU 0.3 GNU-Mach 1.3.99-486/Hurd-0.3 i686-AT386
uname_s: GNU
uname_r: 0.3
uname_v: GNU-Mach 1.3.99-486/Hurd-0.3
uname_m: i686-AT386
uname_p: unknown
uname_i: unknown
uname_o: GNU
debian_version: 7.0
Debian Architecture: hurd-i386
Distributor ID: Debian
Description:    Debian GNU 7.0 (wheezy)
Release:        7.0
Codename:       wheezy
End

defcheck(:test_debian_hurd, debian_gnu_hurd_first_section, <<'End2', %w[debian_version debian_architecture])
{"type":"debian_version","debian_version":"7.0"},
{"type":"debian_architecture","debian_architecture":"hurd-i386"},
End2

defcheck(:os_debian_hurd, debian_gnu_hurd_first_section, <<'End2' , 'os')
{"type":"os","os":"Debian GNU/Hurd 7.0 (wheezy)","arch":"i386"}
End2

defcheck_build(:build_debian_hurd, debian_gnu_hurd_first_section,
               "debian_version" => "7.0",
               "debian_architecture" => "hurd-i386",
               "lsb_distributor" => "Debian",
               "lsb_description" => "Debian GNU 7.0 (wheezy)",
               "lsb_release" => "7.0",
               "lsb_codename" => "wheezy",
               "os" => "Debian GNU/Hurd 7.0 (wheezy)",
               "arch" => "i386")

debian_gnu_hurd_first_sections = <<'End'
== echo # 2014-06-12T21:07:28+09:00
Nickname: hurd
== uname # 2014-06-12T21:07:28+09:00
uname_srvm: GNU 0.3 GNU-Mach 1.3.99-486/Hurd-0.3 i686-AT386
uname_s: GNU
uname_r: 0.3
uname_v: GNU-Mach 1.3.99-486/Hurd-0.3
uname_m: i686-AT386
uname_p: unknown
uname_i: unknown
uname_o: GNU
== /etc/debian_version # 2014-06-12T21:07:28+09:00
7.0
== dpkg # 2014-06-12T21:07:29+09:00
architecture: hurd-i386
== lsb_release # 2014-06-12T21:07:32+09:00
Distributor ID: Debian
Description:    Debian GNU 7.0 (wheezy)
Release:        7.0
Codename:       wheezy
End

defcheck_build(:build_debian_hurd, debian_gnu_hurd_first_sections,
               "debian_version" => "7.0",
               "debian_architecture" => "hurd-i386",
               "lsb_distributor" => "Debian",
               "lsb_description" => "Debian GNU 7.0 (wheezy)",
               "lsb_release" => "7.0",
               "lsb_codename" => "wheezy",
               "os" => "Debian GNU/Hurd 7.0 (wheezy)",
               "arch" => "i386")

ubuntu_first_section = <<'End'
== ruby-trunk # 2014-06-07T21:33:01+09:00
Nickname: u64b
uname_srvm: Linux 3.5.0-47-generic #71~precise1-Ubuntu SMP Wed Feb 19 22:02:52 UTC 2014 x86_64
uname_s: Linux
uname_r: 3.5.0-47-generic
uname_v: #71~precise1-Ubuntu SMP Wed Feb 19 22:02:52 UTC 2014
uname_m: x86_64
uname_p: x86_64
uname_i: x86_64
uname_o: GNU/Linux
debian_version: wheezy/sid
Debian Architecture: amd64
Distributor ID: Ubuntu
Description:    Ubuntu 12.04.4 LTS
Release:        12.04
Codename:       precise
End

defcheck(:test_ubuntu, ubuntu_first_section, <<'End2', 'lsb')
{"type":"lsb","distributor":"Ubuntu","description":"Ubuntu 12.04.4 LTS","release":"12.04","codename":"precise"},
End2

defcheck(:os_debian, ubuntu_first_section, <<'End2' , 'os')
{"type":"os","os":"Ubuntu 12.04.4 LTS","arch":"x86_64"}
End2

defcheck_build(:build_ubuntu, ubuntu_first_section,
               "debian_version" => "wheezy/sid",
               "debian_architecture" => "amd64",
               "lsb_distributor" => "Ubuntu",
               "lsb_description" => "Ubuntu 12.04.4 LTS",
               "lsb_release" => "12.04",
               "lsb_codename" => "precise",
               "os" => "Ubuntu 12.04.4 LTS",
               "arch" => "x86_64")

fedora_first_section = <<'End'
== ruby-trunk # 2014-06-20T00:00:03-07:00
Nickname: gcc1-power7
uname_srvm: Linux 3.8.8-202.fc18.ppc64p7 #1 SMP Thu Apr 18 14:11:12 MST 2013 ppc64
uname_s: Linux
uname_r: 3.8.8-202.fc18.ppc64p7
uname_v: #1 SMP Thu Apr 18 14:11:12 MST 2013
uname_m: ppc64
uname_p: ppc64
uname_i: ppc64
uname_o: GNU/Linux
redhat-release: Fedora release 18 (Spherical Cow)
End

defcheck(:test_fedora, fedora_first_section, <<'End2', 'redhat_release')
{"type":"redhat_release","redhat_release":"Fedora release 18 (Spherical Cow)"},
End2

defcheck_build(:build_fedora, fedora_first_section,
               "redhat_release" => "Fedora release 18 (Spherical Cow)",
               "os" => "Fedora release 18 (Spherical Cow)",
               "arch" => "ppc64")

fedora_first_sections = <<'End'
== echo # 2014-06-20T07:30:00-07:00
Nickname: gcc1-power7
== uname # 2014-06-20T07:30:00-07:00
uname_srvm: Linux 3.8.8-202.fc18.ppc64p7 #1 SMP Thu Apr 18 14:11:12 MST 2013 ppc64
uname_s: Linux
uname_r: 3.8.8-202.fc18.ppc64p7
uname_v: #1 SMP Thu Apr 18 14:11:12 MST 2013
uname_m: ppc64
uname_p: ppc64
uname_i: ppc64
uname_o: GNU/Linux
== /etc/redhat-release # 2014-06-20T07:30:00-07:00
Fedora release 18 (Spherical Cow)
== /etc/system-release # 2014-06-20T07:30:00-07:00
Fedora release 18 (Spherical Cow)
== /etc/os-release # 2014-06-20T07:30:00-07:00
NAME=Fedora
VERSION="18 (Spherical Cow)"
ID=fedora
VERSION_ID=18
PRETTY_NAME="Fedora 18 (Spherical Cow)"
ANSI_COLOR="0;34"
CPE_NAME="cpe:/o:fedoraproject:fedora:18"
End

defcheck(:test_fedora, fedora_first_sections, <<'End2', 'redhat_release')
{"type":"redhat_release","redhat_release":"Fedora release 18 (Spherical Cow)"},
End2

defcheck_build(:build_fedora, fedora_first_sections,
               "redhat_release" => "Fedora release 18 (Spherical Cow)",
               "os" => "Fedora release 18 (Spherical Cow)",
               "arch" => "ppc64")

# FreeBSD's "uname -v" produces a space at line end.
freebsd_first_section = <<'End'.gsub(/\$$/, '')
== ruby-trunk # 2014-06-07T20:33:01+09:00$
Nickname: freebsd82-64$
uname_srvm: FreeBSD 10.0-RELEASE-p3 FreeBSD 10.0-RELEASE-p3 #0: Tue May 13 18:31:10 UTC 2014     root@amd64-builder.daemonology.net:/usr/obj/usr/src/sys/GENERIC  amd64$
uname_s: FreeBSD$
uname_r: 10.0-RELEASE-p3$
uname_v: FreeBSD 10.0-RELEASE-p3 #0: Tue May 13 18:31:10 UTC 2014     root@amd64-builder.daemonology.net:/usr/obj/usr/src/sys/GENERIC $
uname_m: amd64$
uname_p: amd64$
uname_i: GENERIC$
uname_o: FreeBSD$
End

defcheck(:test_uname_freebsd, freebsd_first_section, <<'End2', 'uname')
{"type":"uname","sysname":"FreeBSD","release":"10.0-RELEASE-p3","version":"FreeBSD 10.0-RELEASE-p3 #0: Tue May 13 18:31:10 UTC 2014     root@amd64-builder.daemonology.net:/usr/obj/usr/src/sys/GENERIC","machine":"amd64","processor":"amd64","hardware_platform":"GENERIC","operating_system":"FreeBSD"},
End2

defcheck(:os_freebsd, freebsd_first_section, <<'End2' , 'os')
{"type":"os","os":"FreeBSD 10.0-RELEASE-p3","arch":"amd64"}
End2

defcheck_build(:build_freebsd, freebsd_first_section,
               "os" => "FreeBSD 10.0-RELEASE-p3",
               "arch" => "amd64")

freebsd_first_sections = <<'End'.gsub(/\$$/, '')
== echo # 2014-06-12T21:09:52+09:00
Nickname: freebsd10
== uname # 2014-06-12T21:09:52+09:00
uname_srvm: FreeBSD 10.0-RELEASE FreeBSD 10.0-RELEASE #0 r260789: Thu Jan 16 22:34:59 UTC 2014     root@snap.freebsd.org:/usr/obj/usr/src/sys/GENERIC  amd64
uname_s: FreeBSD
uname_r: 10.0-RELEASE
uname_v: FreeBSD 10.0-RELEASE #0 r260789: Thu Jan 16 22:34:59 UTC 2014     root@snap.freebsd.org:/usr/obj/usr/src/sys/GENERIC 
uname_m: amd64
uname_p: amd64
uname_i: GENERIC
uname_o: FreeBSD
End

defcheck_build(:build_freebsd, freebsd_first_sections,
               "os" => "FreeBSD 10.0-RELEASE",
               "arch" => "amd64")

netbsd_first_section = <<'End'
== echo # 2014-06-07T23:07:42+09:00
Nickname: netbsd61
uname_srvm: NetBSD 6.1.3 NetBSD 6.1.3 (GENERIC) amd64
uname_s: NetBSD
uname_r: 6.1.3
uname_v: NetBSD 6.1.3 (GENERIC)
uname_m: amd64
uname_p: x86_64
End

defcheck(:os_netbsd, netbsd_first_section, <<'End2' , 'os')
{"type":"os","os":"NetBSD 6.1.3","arch":"amd64"}
End2

defcheck_build(:build_netbsd, netbsd_first_section,
               "os" => "NetBSD 6.1.3",
               "arch" => "amd64")

netbsd_first_sections = <<'End'
== echo # 2014-06-12T21:11:42+09:00
Nickname: netbsd61
== uname # 2014-06-12T21:11:42+09:00
uname_srvm: NetBSD 6.1.3 NetBSD 6.1.3 (GENERIC) amd64
uname_s: NetBSD
uname_r: 6.1.3
uname_v: NetBSD 6.1.3 (GENERIC)
uname_m: amd64
uname_p: x86_64
End

defcheck_build(:build_netbsd, netbsd_first_sections,
               "os" => "NetBSD 6.1.3",
               "arch" => "amd64")

openbsd_first_section = <<'End'
== echo # 2014-06-07T23:07:47+09:00
Nickname: openbsd55
uname_srvm: OpenBSD 5.5 GENERIC#271 amd64
uname_s: OpenBSD
uname_r: 5.5
uname_v: GENERIC#271
uname_m: amd64
uname_p: amd64
End

defcheck(:os_openbsd, openbsd_first_section, <<'End2' , 'os')
{"type":"os","os":"OpenBSD 5.5","arch":"amd64"}
End2

defcheck_build(:build_openbsd, openbsd_first_section,
               "os" => "OpenBSD 5.5",
               "arch" => "amd64")

openbsd_first_sections = <<'End'
== echo # 2014-06-12T21:13:02+09:00
Nickname: openbsd55
== uname # 2014-06-12T21:13:02+09:00
uname_srvm: OpenBSD 5.5 GENERIC#271 amd64
uname_s: OpenBSD
uname_r: 5.5
uname_v: GENERIC#271
uname_m: amd64
uname_p: amd64
End

defcheck_build(:build_openbsd, openbsd_first_sections,
               "os" => "OpenBSD 5.5",
               "arch" => "amd64")

# DragonFly BSD's "uname -v" produces a space at line end.
dragonfly_first_section = <<'End'.gsub(/\$$/, '')
== echo # 2014-06-07T23:07:44+09:00$
Nickname: dragonfly362$
uname_srvm: DragonFly 3.6-RELEASE DragonFly v3.6.2-RELEASE #11: Wed Apr  9 19:27:24 PDT 2014     root@pkgbox64.dragonflybsd.org:/usr/obj/build/home/justin/src/sys/X86_64_GENERIC  x86_64$
uname_s: DragonFly$
uname_r: 3.6-RELEASE$
uname_v: DragonFly v3.6.2-RELEASE #11: Wed Apr  9 19:27:24 PDT 2014     root@pkgbox64.dragonflybsd.org:/usr/obj/build/home/justin/src/sys/X86_64_GENERIC $
uname_m: x86_64$
uname_p: x86_64$
uname_i: X86_64_GENERIC$
End

defcheck(:os_dragonfly, dragonfly_first_section, <<'End2' , 'os')
{"type":"os","os":"DragonFly 3.6-RELEASE","arch":"x86_64"}
End2

defcheck_build(:build_dragonfly, dragonfly_first_section,
               "os" => "DragonFly 3.6-RELEASE",
               "arch" => "x86_64")

dragonfly_first_sections = <<'End'.gsub(/\$$/, '')
== echo # 2014-06-12T21:13:03+09:00
Nickname: dragonfly362
== uname # 2014-06-12T21:13:03+09:00
uname_srvm: DragonFly 3.6-RELEASE DragonFly v3.6.2-RELEASE #11: Wed Apr  9 19:27:24 PDT 2014     root@pkgbox64.dragonflybsd.org:/usr/obj/build/home/justin/src/sys/X86_64_GENERIC  x86_64
uname_s: DragonFly
uname_r: 3.6-RELEASE
uname_v: DragonFly v3.6.2-RELEASE #11: Wed Apr  9 19:27:24 PDT 2014     root@pkgbox64.dragonflybsd.org:/usr/obj/build/home/justin/src/sys/X86_64_GENERIC 
uname_m: x86_64
uname_p: x86_64
uname_i: X86_64_GENERIC
End

defcheck_build(:build_dragonfly, dragonfly_first_sections,
               "os" => "DragonFly 3.6-RELEASE",
               "arch" => "x86_64")

mac_first_section = <<'End'
== ruby-trunk-m64-o0 # 2014-06-07T10:15:19+02:00
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
End

defcheck(:test_mac, mac_first_section, <<'End2', 'mac')
{"type":"mac","product_name":"Mac OS X","product_version":"10.9.3","build_version":"13D65"},
End2

defcheck(:os_mac, mac_first_section, <<'End2' , 'os')
{"type":"os","os":"Mac OS X 10.9.3","arch":"x86_64"}
End2

defcheck_build(:build_mac, mac_first_section,
               "os" => "Mac OS X 10.9.3",
               "arch" => "x86_64")

mac_first_sections = <<'End'
== ruby-trunk-m64-o0 # 2014-06-07T10:15:19+02:00
Nickname: P524
== uname # 2014-06-07T10:15:19+02:00
uname_srvm: Darwin 13.2.0 Darwin Kernel Version 13.2.0: Thu Apr 17 23:03:13 PDT 2014; root:xnu-2422.100.13~1/RELEASE_X86_64 x86_64
uname_s: Darwin
uname_r: 13.2.0
uname_v: Darwin Kernel Version 13.2.0: Thu Apr 17 23:03:13 PDT 2014; root:xnu-2422.100.13~1/RELEASE_X86_64
uname_m: x86_64
uname_p: i386
== sw_vers # 2014-06-07T10:15:19+02:00
ProductName:    Mac OS X
ProductVersion: 10.9.3
BuildVersion:   13D65
End

defcheck_build(:build_mac, mac_first_sections,
               "os" => "Mac OS X 10.9.3",
               "arch" => "x86_64")

sunos_first_section = <<'End'
== echo # 2014-06-07T21:54:40+09:00
Nickname: sunos
uname_srvm: SunOS 5.11 oi_151a7 i86pc
uname_s: SunOS
uname_r: 5.11
uname_v: oi_151a7
uname_m: i86pc
uname_p: i386
uname_i: i86pc
release: OpenIndiana Development oi_151.1.7 X86 (powered by illumos)
End

defcheck(:test_sunos, sunos_first_section, <<'End2', 'sunos')
{"type":"sunos","release":"OpenIndiana Development oi_151.1.7 X86 (powered by illumos)"},
End2

defcheck(:os_sunos, sunos_first_section, <<'End2' , 'os')
{"type":"os","os":"OpenIndiana 151a7","arch":"i386"}
End2

defcheck_build(:build_sunos, sunos_first_section,
               "os" => "OpenIndiana 151a7",
               "arch" => "i386")

sunos_first_sections = <<'End'
== echo # 2014-06-12T21:17:58+09:00
Nickname: sunos
== uname # 2014-06-12T21:17:58+09:00
uname_srvm: SunOS 5.11 oi_151a7 i86pc
uname_s: SunOS
uname_r: 5.11
uname_v: oi_151a7
uname_m: i86pc
uname_p: i386
uname_i: i86pc
== /etc/release # 2014-06-12T21:18:02+09:00
OpenIndiana Development oi_151.1.7 X86 (powered by illumos)
End

defcheck_build(:build_sunos, sunos_first_sections,
               "os" => "OpenIndiana 151a7",
               "arch" => "i386")

aix_first_section = <<'End'
== echo # 2014-06-07T05:53:20-07:00
Nickname: power-aix
uname_srvm: AIX 1 7 00F84C0C4C00
uname_s: AIX
uname_r: 1
uname_v: 7
uname_m: 00F84C0C4C00
uname_p: powerpc
oslevel: 7.1.0.0
oslevel_s: 7100-02-02-1316
End

defcheck(:test_aix, aix_first_section, <<'End2', 'aix')
{"type":"aix","oslevel":"7.1.0.0","oslevel_s":"7100-02-02-1316"},
End2

defcheck(:os_aix, aix_first_section, <<'End2' , 'os')
{"type":"os","os":"AIX 7.1","arch":"powerpc"}
End2

defcheck_build(:build_aix, aix_first_section,
               "os" => "AIX 7.1",
               "arch" => "powerpc")

aix_first_sections = <<'End'
== echo # 2014-06-12T05:20:37-07:00
Nickname: power-aix
== uname # 2014-06-12T05:20:37-07:00
uname_srvm: AIX 1 7 00F84C0C4C00
uname_s: AIX
uname_r: 1
uname_v: 7
uname_m: 00F84C0C4C00
uname_p: powerpc
== oslevel # 2014-06-12T05:20:38-07:00
oslevel: 7.1.0.0
oslevel_s: 7100-02-02-1316
End

defcheck_build(:build_aix, aix_first_sections,
               "os" => "AIX 7.1",
               "arch" => "powerpc")

defcheck(:start, <<'End1', <<'End2', %w[start_time build_dir ruby_branch])
== start # 2014-05-28T21:05:12+09:00
start-time: 20140528T120400Z
build-dir: /extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z
option :ruby_branch => "branches/ruby_2_0_0"
End1
{"type":"start_time","start_time":"20140528T120400Z"},
{"type":"build_dir","dir":"/extdisk/chkbuild/chkbuild/tmp/build/20140528T120400Z"},
{"type":"ruby_branch","ruby_branch":"branches/ruby_2_0_0"},
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

# btest since 2014-06-08
defcheck(:btest_result_simple_line, <<'End1', <<'End2', %w[btest_result])
== btest # 2014-05-28T21:05:12+09:00
test_attr.rb 
#1 test_attr.rb:1:in `<top (required)>' F 0.006
stderr output is not empty
   bootstraptest.tmp.rb:2:in `<main>': undefined local variable or method `x' for main:Object (NameError)
#2 test_attr.rb:28:in `<top (required)>' . 0.007
End1
{"type":"btest_result","test_suite":"btest","testnum":1,"file":"test_attr.rb","line":1,"caller":"in `<top (required)>'","result":"failure","elapsed":0.006},
{"type":"btest_result","test_suite":"btest","testnum":2,"file":"test_attr.rb","line":28,"caller":"in `<top (required)>'","result":"success","elapsed":0.007},
End2

defcheck(:btest_result_simple_line, <<'End1', <<'End2', %w[btest_result])
== btest # 2014-05-28T21:05:12+09:00
test_io.rb
#259 test_io.rb:34 .
#260 test_io.rb:44 F
End1
{"type":"btest_result","test_suite":"btest","testnum":259,"file":"test_io.rb","line":34,"caller":"","result":"success"},
{"type":"btest_result","test_suite":"btest","testnum":260,"file":"test_io.rb","line":44,"caller":"","result":"failure"},
End2

defcheck(:btest_result_caller, <<'End1', <<'End2', %w[btest_result])
== btest # 2014-05-28T21:05:12+09:00
test_autoload.rb 
#3 test_autoload.rb:1:in `<top (required)>' .
#4 test_autoload.rb:13:in `<top (required)>' .
End1
{"type":"btest_result","test_suite":"btest","testnum":3,"file":"test_autoload.rb","line":1,"caller":"in `<top (required)>'","result":"success"},
{"type":"btest_result","test_suite":"btest","testnum":4,"file":"test_autoload.rb","line":13,"caller":"in `<top (required)>'","result":"success"},
End2

defcheck(:btest_result_ignore_mixed, <<'End1', <<'End2', %w[btest_result])
== btest # 2014-05-28T21:05:12+09:00
test_io.rb
#260 test_io.rb:44 F
stderr output is not empty
   /extdisk/chkbuild/chkbuild/tmp/build/20140424T124800Z/ruby/lib/tmpdir.rb:8:in `require': cannot load such file -- etc.so (LoadError)
           from /extdisk/chkbuild/chkbuild/tmp/build/20140424T124800Z/ruby/lib/tmpdir.rb:8:in `<top (required)>'
           from bootstraptest.tmp.rb:2:in `require'
           from bootstraptest.tmp.rb:2:in `<main>'
#261 test_io.rb:60 F
End1
{"type":"btest_result","test_suite":"btest","testnum":260,"file":"test_io.rb","line":44,"caller":"","result":"failure"},
{"type":"btest_result","test_suite":"btest","testnum":261,"file":"test_io.rb","line":60,"caller":"","result":"failure"},
End2

btest_detail_log = <<'End'
== btest # 2010-02-18T04:19:47+09:00
#260 test_io.rb:44: 
     require 'tmpdir'
     begin
       tmpname = "#{Dir.tmpdir}/ruby-btest-#{$$}-#{rand(0x100000000).to_s(36)}"
       rw = File.open(tmpname, File::RDWR|File::CREAT|File::EXCL)
     rescue Errno::EEXIST
       retry
     end
     save = STDIN.dup
     STDIN.reopen(rw)
     STDIN.reopen(save)
     rw.close
     File.unlink(tmpname) unless RUBY_PLATFORM['nacl']
     :ok
  #=> "" (expected "ok")
End

btest_detail_src = btest_detail_log[/^     require(?:[\s\S]*?):ok\n/]
btest_detail_msg = btest_detail_log[/"".*/]
defcheck(:btest_detail_io, btest_detail_log, <<"End2", %w[btest_detail])
{"type":"btest_detail","test_suite":"btest","testnum":260,"file":"test_io.rb","line":44,"caller":"","code":#{JSON.dump btest_detail_src},"message":#{JSON.dump btest_detail_msg}}
End2

knownbug_log = <<'End'
== test-knownbug # 2010-02-18T04:19:47+09:00
KNOWNBUGS.rb #1 KNOWNBUGS.rb:16:in `<top (required)>'
F
#1 KNOWNBUGS.rb:16:in `<top (required)>': 
     open("tst-remove-load.rb", "w") {|f|
       f << <<'End'
   module Kernel
     remove_method :load
   end
   raise
   End
     }
     load "tst-remove-load.rb"
  #=> killed by SIGSEGV (signal 11)
| tst-remove-load.rb:4: [BUG] Segmentation fault
| ruby 1.9.2dev (2010-02-18 trunk 26704) [i686-linux]
| 
| -- control frame ----------
| c:0006 p:0019 s:0015 b:0015 l:000014 d:000014 TOP    tst-remove-load.rb:4
| c:0005 p:---- s:0013 b:0013 l:000012 d:000012 FINISH
  [ruby-dev:40234] [ruby-core:27959]
FAIL 1/1 tests failed
End

defcheck(:btest_result_knownbugs, knownbug_log, <<'End2', %w[btest_result])
{"type":"btest_result","test_suite":"test-knownbug","testnum":1,"file":"KNOWNBUGS.rb","line":16,"caller":"in `<top (required)>'","result":"failure"}
End2

known_bug_src = knownbug_log[/^     open(?:[\s\S]*?)"tst-remove-load.rb"\n/]
defcheck(:btest_detail_knownbugs, knownbug_log, <<"End2", %w[btest_detail])
{"type":"btest_detail","test_suite":"test-knownbug","testnum":1,"file":"KNOWNBUGS.rb","line":16,"caller":"in `<top (required)>'","code":#{JSON.dump known_bug_src},"message":"killed by SIGSEGV (signal 11)"}
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
{"type":"exception","secname":"ruby-trunk","prev_line":"/home/akr/chkbuild/tmp/build/ruby-trunk/20110614T005500Z/ruby/test/psych/test_string.rb:31: warning: assigned but unused variable - str","loc":"/home/akr/chkbuild/tmp/build/ruby-trunk/20110614T005500Z/ruby/test/psych/helper.rb:63","caller_name":"<top (required)>","message":": psych should define to_yaml","error_class":"RuntimeError"},
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
{"type":"make_failure","secname":"ruby-trunk","prev_line":"foo","line_prefix":"bar","level":0,"message":"baz"},
End2

defcheck(:make_failure_gmake, <<'End1', <<'End2', 'make_failure')
== ruby-trunk # 2010-12-02T16:51:01+09:00
foo
bar gmake: *** baz
End1
{"type":"make_failure","secname":"ruby-trunk","prev_line":"foo","line_prefix":"bar","level":0,"message":"baz"},
End2

defcheck(:make_failure_levels, <<'End1', <<'End2', 'make_failure')
== dist # 2010-12-02T16:51:01+09:00
generating ext/ripper/ripper.c
make[2]: Entering directory `/home/chkbuild/build/20140620T113301Z/tmp/ruby-snapshot20140620-6898-12b8jdy/ruby-2.2.0-r46480/ext/ripper'
extracting ripper.y from ../../parse.y
compiling compiler ripper.y
bison: I/O error
make[2]: *** [ripper.c] Error 1
make[2]: Leaving directory `/home/chkbuild/build/20140620T113301Z/tmp/ruby-snapshot20140620-6898-12b8jdy/ruby-2.2.0-r46480/ext/ripper'
make[1]: *** [ext/ripper/ripper.c] Error 2
make[1]: Leaving directory `/home/chkbuild/build/20140620T113301Z/tmp/ruby-snapshot20140620-6898-12b8jdy/ruby-2.2.0-r46480'
prerequisites failed
gmake: *** [dist] Error 1
exit 2
failed(dist)
End1
{"type":"make_failure","secname":"dist","prev_line":"bison: I/O error","line_prefix":"","level":2,"message":"[ripper.c] Error 1"},
{"type":"make_failure","secname":"dist","prev_line":"make[2]: Leaving directory `/home/chkbuild/build/20140620T113301Z/tmp/ruby-snapshot20140620-6898-12b8jdy/ruby-2.2.0-r46480/ext/ripper'","line_prefix":"","level":1,"message":"[ext/ripper/ripper.c] Error 2"},
{"type":"make_failure","secname":"dist","prev_line":"prerequisites failed","line_prefix":"","level":0,"message":"[dist] Error 1"},
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
