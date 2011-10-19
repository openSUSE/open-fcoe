#
# spec file for package open-fcoe
#
# Copyright (c) 2011 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

# norootforbuild


Name:           open-fcoe
Url:            http://www.open-fcoe.org
License:        GPL v2 only
Group:          System/Daemons
PreReq:         %fillup_prereq %insserv_prereq
Requires:       libhbalinux2 lldpad
BuildRequires:  libHBAAPI2-devel libnl-devel lldpad-devel
AutoReqProv:    on
Version:        1.0.20
Release:        0.<RELEASE7>
Summary:        Open-FCoE userspace management tools
#the upstream source is available as - fcoe-utils-2.6.39.tar.gz
Source0:        http://www.open-fcoe.org/openfc/fcoe-utils-2.6.39.tar.bz2
Patch0:         fcoe-utils-sles11-sp2.diff.bz2
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
Userspace tools to manage FibreChannel over Ethernet (FCoE)
connections.



Authors:
--------
    Robert Love <robert.w.love@intel.com>

%prep
%setup -q -n fcoe-utils-2.6.39
%patch0 -p1

%build
autoreconf --install
%configure CFLAGS="-DUSE_LLDPAD ${RPM_OPT_FLAGS}"
make %{?_smp_mflags}

%install
%makeinstall
mv ${RPM_BUILD_ROOT}/etc/init.d/fcoe ${RPM_BUILD_ROOT}/etc/init.d/boot.fcoe
install -d ${RPM_BUILD_ROOT}/sbin
install -m 755 contrib/fcoe-setup.sh ${RPM_BUILD_ROOT}/sbin/fcoe-setup
install -d ${RPM_BUILD_ROOT}/lib/mkinitrd/scripts/
install -m 755 rpm/mkinitrd-boot.sh ${RPM_BUILD_ROOT}/lib/mkinitrd/scripts/boot-fcoe.sh
install -m 755 rpm/mkinitrd-setup.sh ${RPM_BUILD_ROOT}/lib/mkinitrd/scripts/setup-fcoe.sh
mkdir -p ${RPM_BUILD_ROOT}/usr/sbin
ln -s /etc/init.d/boot.fcoe ${RPM_BUILD_ROOT}/usr/sbin/rcfcoe
install -d ${RPM_BUILD_ROOT}/usr/share/fcoe/scripts/
install -m 755 contrib/fcc.sh ${RPM_BUILD_ROOT}/usr/share/fcoe/scripts/fcc.sh
install -m 755 contrib/fcoe_edd.sh ${RPM_BUILD_ROOT}/usr/share/fcoe/scripts/fcoe_edd.sh
install -m 755 debug/dcbcheck.sh ${RPM_BUILD_ROOT}/usr/share/fcoe/scripts/dcbcheck.sh
install -m 755 debug/fcoedump.sh ${RPM_BUILD_ROOT}/usr/share/fcoe/scripts/fcoedump.sh

%post
[ -x /sbin/mkinitrd_setup ] && mkinitrd_setup
%{fillup_and_insserv boot.fcoe}

%preun
%{stop_on_removal boot.fcoe} 

%postun
[ -x /sbin/mkinitrd_setup ] && mkinitrd_setup
%{insserv_cleanup boot.fcoe}

%files
%defattr(-,root,root,-)
%doc README
%doc COPYING
/sbin/fcoe-setup
%{_sbindir}/*
%{_mandir}/man8/*
/usr/share/fcoe
%dir %{_sysconfdir}/fcoe
%config %{_sysconfdir}/fcoe/config
%config %{_sysconfdir}/fcoe/cfg-ethx
%config %{_sysconfdir}/init.d/boot.fcoe
/lib/mkinitrd
%config %{_sysconfdir}/bash_completion.d/fcoeadm
%config %{_sysconfdir}/bash_completion.d/fcoemon

%changelog
