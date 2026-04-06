%global commit_hash %(echo %{git_hash} 2>/dev/null || echo "unknown")

Name:           srsran4g
Version:        23.11
Release:        1%{?dist}
Summary:        srsRAN 4G - Open source LTE eNB and UE simulators
License:        AGPLv3
URL:            https://github.com/srsran/srsRAN_4G

BuildRequires:  cmake3 >= 3.10
BuildRequires:  gcc >= 7
BuildRequires:  gcc-c++ >= 7
BuildRequires:  fftw-devel
BuildRequires:  mbedtls-devel
BuildRequires:  boost-devel
BuildRequires:  lksctp-tools-devel
BuildRequires:  libconfig-devel
BuildRequires:  zeromq-devel
BuildRequires:  czmq-devel
BuildRequires:  patchelf

%description
srsRAN 4G is an open-source 4G software radio suite.
This package provides srsENB (eNodeB) and srsUE (UE) LTE simulators.

%package enb
Summary:        srsRAN 4G eNodeB LTE simulator
Requires:       fftw-libs
Requires:       mbedtls
Requires:       lksctp-tools
Requires:       libconfig

%description enb
srsENB is an open-source LTE eNodeB (base station) simulator
from the srsRAN 4G project.

%package ue
Summary:        srsRAN 4G UE LTE simulator
Requires:       fftw-libs
Requires:       mbedtls
Requires:       lksctp-tools

%description ue
srsUE is an open-source LTE User Equipment simulator
from the srsRAN 4G project.

# No standard source - we use pre-built binaries from cmake
%global debug_package %{nil}

%install
# Binaries
install -d %{buildroot}%{_bindir}
install -m 0755 %{_builddir}/srsenb %{buildroot}%{_bindir}/srsenb
install -m 0755 %{_builddir}/srsue %{buildroot}%{_bindir}/srsue

# Config files
install -d %{buildroot}%{_sysconfdir}/srsran

# eNB configs
install -m 0644 %{_builddir}/configs/enb.conf.example %{buildroot}%{_sysconfdir}/srsran/enb.conf.example
install -m 0644 %{_builddir}/configs/rr.conf.example %{buildroot}%{_sysconfdir}/srsran/rr.conf.example
install -m 0644 %{_builddir}/configs/sib.conf.example %{buildroot}%{_sysconfdir}/srsran/sib.conf.example
install -m 0644 %{_builddir}/configs/rb.conf.example %{buildroot}%{_sysconfdir}/srsran/rb.conf.example

# UE configs
install -m 0644 %{_builddir}/configs/ue.conf.example %{buildroot}%{_sysconfdir}/srsran/ue.conf.example

%files enb
%{_bindir}/srsenb
%dir %{_sysconfdir}/srsran
%config(noreplace) %{_sysconfdir}/srsran/enb.conf.example
%config(noreplace) %{_sysconfdir}/srsran/rr.conf.example
%config(noreplace) %{_sysconfdir}/srsran/sib.conf.example
%config(noreplace) %{_sysconfdir}/srsran/rb.conf.example

%files ue
%{_bindir}/srsue
%dir %{_sysconfdir}/srsran
%config(noreplace) %{_sysconfdir}/srsran/ue.conf.example
