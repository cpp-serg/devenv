%define open5gs_user  open5gs
%define open5gs_group open5gs

Name:           open5gs
Version:        2.7.7
Release:        1%{?dist}
Summary:        Open source implementation of 5G Core and EPC
License:        AGPL-3.0-only
URL:            https://open5gs.org
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  gcc-c++
# meson installed via pip3 in container; skip rpm dependency check
#BuildRequires:  meson >= 0.43.0
BuildRequires:  ninja-build
BuildRequires:  cmake
BuildRequires:  bison
BuildRequires:  flex
BuildRequires:  pkgconfig
BuildRequires:  python3
BuildRequires:  git-core
BuildRequires:  lksctp-tools-devel
BuildRequires:  gnutls-devel
BuildRequires:  libgcrypt-devel
BuildRequires:  openssl-devel
BuildRequires:  libidn-devel
BuildRequires:  mongo-c-driver-devel
BuildRequires:  libyaml-devel
BuildRequires:  libnghttp2-devel
BuildRequires:  libmicrohttpd-devel
BuildRequires:  libcurl-devel
BuildRequires:  libtalloc-devel
BuildRequires:  systemd-rpm-macros

Requires:       %{name}-common = %{version}-%{release}
Requires:       %{name}-mme  = %{version}-%{release}
Requires:       %{name}-sgwc = %{version}-%{release}
Requires:       %{name}-sgwu = %{version}-%{release}
Requires:       %{name}-smf  = %{version}-%{release}
Requires:       %{name}-amf  = %{version}-%{release}
Requires:       %{name}-upf  = %{version}-%{release}
Requires:       %{name}-hss  = %{version}-%{release}
Requires:       %{name}-pcrf = %{version}-%{release}
Requires:       %{name}-nrf  = %{version}-%{release}
Requires:       %{name}-scp  = %{version}-%{release}
Requires:       %{name}-sepp = %{version}-%{release}
Requires:       %{name}-ausf = %{version}-%{release}
Requires:       %{name}-udm  = %{version}-%{release}
Requires:       %{name}-udr  = %{version}-%{release}
Requires:       %{name}-pcf  = %{version}-%{release}
Requires:       %{name}-nssf = %{version}-%{release}
Requires:       %{name}-bsf  = %{version}-%{release}

%description
Open5GS is a C-language implementation of 5G Core and EPC
(Release-17). It provides MME, SGW-C, SGW-U, HSS, PCRF for LTE/EPC
and AMF, SMF, UPF, NRF, AUSF, UDM, UDR, PCF, NSSF, BSF, SCP, SEPP
for 5G Core. This metapackage installs all network functions.

# ============================================================
# Subpackages
# ============================================================

%package common
Summary:  Open5GS shared libraries and configuration
Requires: logrotate
Requires(pre): shadow-utils

%description common
Shared libraries, configuration files, and freeDiameter plugins
required by all Open5GS network function packages.

%package mme
Summary:  Open5GS MME (Mobility Management Entity)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description mme
Open5GS MME — Mobility Management Entity for LTE/EPC.

%package sgwc
Summary:  Open5GS SGW-C (Serving Gateway Control Plane)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description sgwc
Open5GS SGW-C — Serving Gateway Control Plane for LTE/EPC.

%package sgwu
Summary:  Open5GS SGW-U (Serving Gateway User Plane)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description sgwu
Open5GS SGW-U — Serving Gateway User Plane for LTE/EPC.

%package smf
Summary:  Open5GS SMF (Session Management Function)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description smf
Open5GS SMF — Session Management Function.

%package amf
Summary:  Open5GS AMF (Access and Mobility Management Function)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description amf
Open5GS AMF — Access and Mobility Management Function.

%package upf
Summary:  Open5GS UPF (User Plane Function)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description upf
Open5GS UPF — User Plane Function.

%package hss
Summary:  Open5GS HSS (Home Subscriber Server)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description hss
Open5GS HSS — Home Subscriber Server for LTE/EPC.

%package pcrf
Summary:  Open5GS PCRF (Policy and Charging Rules Function)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description pcrf
Open5GS PCRF — Policy and Charging Rules Function for LTE/EPC.

%package nrf
Summary:  Open5GS NRF (Network Repository Function)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description nrf
Open5GS NRF — Network Repository Function.

%package scp
Summary:  Open5GS SCP (Service Communication Proxy)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description scp
Open5GS SCP — Service Communication Proxy.

%package sepp
Summary:  Open5GS SEPP (Security Edge Protection Proxy)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description sepp
Open5GS SEPP — Security Edge Protection Proxy.

%package ausf
Summary:  Open5GS AUSF (Authentication Server Function)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description ausf
Open5GS AUSF — Authentication Server Function.

%package udm
Summary:  Open5GS UDM (Unified Data Management)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description udm
Open5GS UDM — Unified Data Management.

%package udr
Summary:  Open5GS UDR (Unified Data Repository)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description udr
Open5GS UDR — Unified Data Repository.

%package pcf
Summary:  Open5GS PCF (Policy Control Function)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description pcf
Open5GS PCF — Policy Control Function.

%package nssf
Summary:  Open5GS NSSF (Network Slice Selection Function)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description nssf
Open5GS NSSF — Network Slice Selection Function.

%package bsf
Summary:  Open5GS BSF (Binding Support Function)
Requires: %{name}-common = %{version}-%{release}
%{?systemd_requires}
%description bsf
Open5GS BSF — Binding Support Function.

# ============================================================
# Build
# ============================================================

%prep
%setup -q

# Patch PLMN: replace default 999/70 with 315/010 in MME config template
sed -i '/^  gummei:/,/^  tai:/{s/mcc: 999/mcc: 315/;s/mnc: 70/mnc: 010/}' \
    configs/open5gs/mme.yaml.in
sed -i '/^  tai:/,/^  security:/{s/mcc: 999/mcc: 315/;s/mnc: 70/mnc: 010/}' \
    configs/open5gs/mme.yaml.in

%define _vpath_builddir %{_target_platform}

%build
# Suppress -Werror=array-bounds false positives in libtins (GCC 8/11).
export CXXFLAGS="${CXXFLAGS:-%{optflags}} -Wno-error=array-bounds"
# Call meson via python3.9 explicitly to avoid platform-python (3.6) issues.
python3.9 /usr/local/bin/meson setup %{_vpath_builddir} \
    --prefix=%{_prefix} --libdir=%{_libdir} --buildtype=release
ninja -v -C %{_vpath_builddir} %{?_smp_mflags}

%install
DESTDIR=%{buildroot} ninja -v -C %{_vpath_builddir} install

# --- Patch UPF systemd unit: grant CAP_NET_ADMIN so it can create TUN ---
sed -i '/^Group=open5gs/a\\nAmbientCapabilities=CAP_NET_ADMIN\nCapabilityBoundingSet=CAP_NET_ADMIN' \
    %{_vpath_builddir}/configs/systemd/open5gs-upfd.service

# --- Configuration files ---
install -d %{buildroot}%{_sysconfdir}/open5gs
install -d %{buildroot}%{_sysconfdir}/freeDiameter
for f in %{_vpath_builddir}/configs/open5gs/*.yaml; do
    install -m 0644 "$f" %{buildroot}%{_sysconfdir}/open5gs/
done
for f in %{_vpath_builddir}/configs/freeDiameter/*.conf; do
    install -m 0644 "$f" %{buildroot}%{_sysconfdir}/freeDiameter/
done

# --- Systemd service units ---
install -d %{buildroot}%{_unitdir}
for f in %{_vpath_builddir}/configs/systemd/*.service; do
    install -m 0644 "$f" %{buildroot}%{_unitdir}/
done

# --- Logrotate ---
install -d %{buildroot}%{_sysconfdir}/logrotate.d
install -m 0644 %{_vpath_builddir}/configs/logrotate/open5gs \
    %{buildroot}%{_sysconfdir}/logrotate.d/open5gs

# --- Log directory ---
install -d %{buildroot}%{_localstatedir}/log/open5gs

# --- tmpfiles.d for runtime directories ---
install -d %{buildroot}%{_tmpfilesdir}
cat > %{buildroot}%{_tmpfilesdir}/open5gs.conf <<'TMPEOF'
d /run/open5gs-mmed  0755 open5gs open5gs -
d /run/open5gs-sgwcd 0755 open5gs open5gs -
d /run/open5gs-sgwud 0755 open5gs open5gs -
d /run/open5gs-smfd  0755 open5gs open5gs -
d /run/open5gs-amfd  0755 open5gs open5gs -
d /run/open5gs-upfd  0755 open5gs open5gs -
d /run/open5gs-hssd  0755 open5gs open5gs -
d /run/open5gs-pcrfd 0755 open5gs open5gs -
d /run/open5gs-nrfd  0755 open5gs open5gs -
d /run/open5gs-scpd  0755 open5gs open5gs -
d /run/open5gs-seppd 0755 open5gs open5gs -
d /run/open5gs-ausfd 0755 open5gs open5gs -
d /run/open5gs-udmd  0755 open5gs open5gs -
d /run/open5gs-udrd  0755 open5gs open5gs -
d /run/open5gs-pcfd  0755 open5gs open5gs -
d /run/open5gs-nssfd 0755 open5gs open5gs -
d /run/open5gs-bsfd  0755 open5gs open5gs -
TMPEOF

# ============================================================
# Scriptlets
# ============================================================

%pre common
getent group %{open5gs_group} >/dev/null || groupadd -r %{open5gs_group}
getent passwd %{open5gs_user} >/dev/null || \
    useradd -r -g %{open5gs_group} -d /run/open5gs -s /sbin/nologin \
    -c "Open5GS daemon" %{open5gs_user}
exit 0

%post common
/sbin/ldconfig
%tmpfiles_create %{_tmpfilesdir}/open5gs.conf

%postun common -p /sbin/ldconfig

# --- MME ---
%pre    mme
%systemd_pre open5gs-mmed.service
%post   mme
%systemd_post open5gs-mmed.service
%preun  mme
%systemd_preun open5gs-mmed.service
%postun mme
%systemd_postun_with_restart open5gs-mmed.service

# --- SGW-C ---
%pre    sgwc
%systemd_pre open5gs-sgwcd.service
%post   sgwc
%systemd_post open5gs-sgwcd.service
%preun  sgwc
%systemd_preun open5gs-sgwcd.service
%postun sgwc
%systemd_postun_with_restart open5gs-sgwcd.service

# --- SGW-U ---
%pre    sgwu
%systemd_pre open5gs-sgwud.service
%post   sgwu
%systemd_post open5gs-sgwud.service
%preun  sgwu
%systemd_preun open5gs-sgwud.service
%postun sgwu
%systemd_postun_with_restart open5gs-sgwud.service

# --- SMF ---
%pre    smf
%systemd_pre open5gs-smfd.service
%post   smf
%systemd_post open5gs-smfd.service
%preun  smf
%systemd_preun open5gs-smfd.service
%postun smf
%systemd_postun_with_restart open5gs-smfd.service

# --- AMF ---
%pre    amf
%systemd_pre open5gs-amfd.service
%post   amf
%systemd_post open5gs-amfd.service
%preun  amf
%systemd_preun open5gs-amfd.service
%postun amf
%systemd_postun_with_restart open5gs-amfd.service

# --- UPF ---
%pre    upf
%systemd_pre open5gs-upfd.service
%post   upf
%systemd_post open5gs-upfd.service
%preun  upf
%systemd_preun open5gs-upfd.service
%postun upf
%systemd_postun_with_restart open5gs-upfd.service

# --- HSS ---
%pre    hss
%systemd_pre open5gs-hssd.service
%post   hss
%systemd_post open5gs-hssd.service
%preun  hss
%systemd_preun open5gs-hssd.service
%postun hss
%systemd_postun_with_restart open5gs-hssd.service

# --- PCRF ---
%pre    pcrf
%systemd_pre open5gs-pcrfd.service
%post   pcrf
%systemd_post open5gs-pcrfd.service
%preun  pcrf
%systemd_preun open5gs-pcrfd.service
%postun pcrf
%systemd_postun_with_restart open5gs-pcrfd.service

# --- NRF ---
%pre    nrf
%systemd_pre open5gs-nrfd.service
%post   nrf
%systemd_post open5gs-nrfd.service
%preun  nrf
%systemd_preun open5gs-nrfd.service
%postun nrf
%systemd_postun_with_restart open5gs-nrfd.service

# --- SCP ---
%pre    scp
%systemd_pre open5gs-scpd.service
%post   scp
%systemd_post open5gs-scpd.service
%preun  scp
%systemd_preun open5gs-scpd.service
%postun scp
%systemd_postun_with_restart open5gs-scpd.service

# --- SEPP ---
%pre    sepp
%systemd_pre open5gs-seppd.service
%post   sepp
%systemd_post open5gs-seppd.service
%preun  sepp
%systemd_preun open5gs-seppd.service
%postun sepp
%systemd_postun_with_restart open5gs-seppd.service

# --- AUSF ---
%pre    ausf
%systemd_pre open5gs-ausfd.service
%post   ausf
%systemd_post open5gs-ausfd.service
%preun  ausf
%systemd_preun open5gs-ausfd.service
%postun ausf
%systemd_postun_with_restart open5gs-ausfd.service

# --- UDM ---
%pre    udm
%systemd_pre open5gs-udmd.service
%post   udm
%systemd_post open5gs-udmd.service
%preun  udm
%systemd_preun open5gs-udmd.service
%postun udm
%systemd_postun_with_restart open5gs-udmd.service

# --- UDR ---
%pre    udr
%systemd_pre open5gs-udrd.service
%post   udr
%systemd_post open5gs-udrd.service
%preun  udr
%systemd_preun open5gs-udrd.service
%postun udr
%systemd_postun_with_restart open5gs-udrd.service

# --- PCF ---
%pre    pcf
%systemd_pre open5gs-pcfd.service
%post   pcf
%systemd_post open5gs-pcfd.service
%preun  pcf
%systemd_preun open5gs-pcfd.service
%postun pcf
%systemd_postun_with_restart open5gs-pcfd.service

# --- NSSF ---
%pre    nssf
%systemd_pre open5gs-nssfd.service
%post   nssf
%systemd_post open5gs-nssfd.service
%preun  nssf
%systemd_preun open5gs-nssfd.service
%postun nssf
%systemd_postun_with_restart open5gs-nssfd.service

# --- BSF ---
%pre    bsf
%systemd_pre open5gs-bsfd.service
%post   bsf
%systemd_post open5gs-bsfd.service
%preun  bsf
%systemd_preun open5gs-bsfd.service
%postun bsf
%systemd_postun_with_restart open5gs-bsfd.service

# ============================================================
# File lists
# ============================================================

%files
# metapackage — no files, just dependencies

%files common
%license LICENSE
%doc README.md
%dir %{_sysconfdir}/open5gs
%dir %{_sysconfdir}/freeDiameter
%config(noreplace) %{_sysconfdir}/logrotate.d/open5gs
%{_tmpfilesdir}/open5gs.conf
%attr(0750,%{open5gs_user},%{open5gs_group}) %{_localstatedir}/log/open5gs
# Shared libraries (freeDiameter + open5gs + bundled subprojects)
%{_libdir}/libfd*.so*
%{_libdir}/libogs*.so*
%{_libdir}/libprom.so*
%{_libdir}/libtins.so*
%dir %{_libdir}/freeDiameter
%{_libdir}/freeDiameter/*.fdx

# --- NFs with freeDiameter configs ---

%files mme
%{_bindir}/open5gs-mmed
%config(noreplace) %{_sysconfdir}/open5gs/mme.yaml
%config(noreplace) %{_sysconfdir}/freeDiameter/mme.conf
%{_unitdir}/open5gs-mmed.service

%files hss
%{_bindir}/open5gs-hssd
%config(noreplace) %{_sysconfdir}/open5gs/hss.yaml
%config(noreplace) %{_sysconfdir}/freeDiameter/hss.conf
%{_unitdir}/open5gs-hssd.service

%files pcrf
%{_bindir}/open5gs-pcrfd
%config(noreplace) %{_sysconfdir}/open5gs/pcrf.yaml
%config(noreplace) %{_sysconfdir}/freeDiameter/pcrf.conf
%{_unitdir}/open5gs-pcrfd.service

%files smf
%{_bindir}/open5gs-smfd
%config(noreplace) %{_sysconfdir}/open5gs/smf.yaml
%config(noreplace) %{_sysconfdir}/freeDiameter/smf.conf
%{_unitdir}/open5gs-smfd.service

# --- NFs without freeDiameter configs ---

%files sgwc
%{_bindir}/open5gs-sgwcd
%config(noreplace) %{_sysconfdir}/open5gs/sgwc.yaml
%{_unitdir}/open5gs-sgwcd.service

%files sgwu
%{_bindir}/open5gs-sgwud
%config(noreplace) %{_sysconfdir}/open5gs/sgwu.yaml
%{_unitdir}/open5gs-sgwud.service

%files amf
%{_bindir}/open5gs-amfd
%config(noreplace) %{_sysconfdir}/open5gs/amf.yaml
%{_unitdir}/open5gs-amfd.service

%files upf
%caps(cap_net_admin=ep) %{_bindir}/open5gs-upfd
%config(noreplace) %{_sysconfdir}/open5gs/upf.yaml
%{_unitdir}/open5gs-upfd.service

%files nrf
%{_bindir}/open5gs-nrfd
%config(noreplace) %{_sysconfdir}/open5gs/nrf.yaml
%{_unitdir}/open5gs-nrfd.service

%files scp
%{_bindir}/open5gs-scpd
%config(noreplace) %{_sysconfdir}/open5gs/scp.yaml
%{_unitdir}/open5gs-scpd.service

%files sepp
%{_bindir}/open5gs-seppd
%config(noreplace) %{_sysconfdir}/open5gs/sepp1.yaml
%config(noreplace) %{_sysconfdir}/open5gs/sepp2.yaml
%{_unitdir}/open5gs-seppd.service

%files ausf
%{_bindir}/open5gs-ausfd
%config(noreplace) %{_sysconfdir}/open5gs/ausf.yaml
%{_unitdir}/open5gs-ausfd.service

%files udm
%{_bindir}/open5gs-udmd
%config(noreplace) %{_sysconfdir}/open5gs/udm.yaml
%{_unitdir}/open5gs-udmd.service

%files udr
%{_bindir}/open5gs-udrd
%config(noreplace) %{_sysconfdir}/open5gs/udr.yaml
%{_unitdir}/open5gs-udrd.service

%files pcf
%{_bindir}/open5gs-pcfd
%config(noreplace) %{_sysconfdir}/open5gs/pcf.yaml
%{_unitdir}/open5gs-pcfd.service

%files nssf
%{_bindir}/open5gs-nssfd
%config(noreplace) %{_sysconfdir}/open5gs/nssf.yaml
%{_unitdir}/open5gs-nssfd.service

%files bsf
%{_bindir}/open5gs-bsfd
%config(noreplace) %{_sysconfdir}/open5gs/bsf.yaml
%{_unitdir}/open5gs-bsfd.service

%changelog
* Tue Mar 17 2026 Open5GS Builder <builder@open5gs.org> - 2.7.7-1
- Build for Rocky Linux 9
- Adapted from community openSUSE spec (home:mnhauke:open5gs)
- Added SCP and SEPP network functions
- Uses meson subprojects for libtins, libprom, freeDiameter
