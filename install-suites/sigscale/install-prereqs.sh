#!/bin/bash
# Install prerequisites for SigScale OCS on Rocky Linux 8 or 9
# Run as root on the target system
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

# Detect OS major version
OS_VERSION=$(rpm -E %{rhel})
if [ "$OS_VERSION" -ne 8 ] && [ "$OS_VERSION" -ne 9 ]; then
    echo "ERROR: Unsupported OS version (EL${OS_VERSION}). Requires Rocky Linux 8 or 9."
    exit 1
fi

echo "=== Installing OCS prerequisites on Rocky Linux ${OS_VERSION} ==="

# Enable extra packages repo
echo "--- Enabling extra packages repo ---"
dnf -y install dnf-plugins-core
if [ "$OS_VERSION" -eq 8 ]; then
    # Rocky Linux 8: repo is named 'powertools'
    dnf config-manager --set-enabled powertools
else
    # Rocky Linux 9: repo is named 'crb' (CodeReady Builder)
    dnf config-manager --set-enabled crb
fi

# Install Erlang/OTP from Erlang Solutions
echo "--- Installing Erlang/OTP ---"
if [ "$OS_VERSION" -eq 8 ]; then
    # Rocky Linux 8: packages under centos/8/
    ESL_ERLANG_URL="https://binaries2.erlang-solutions.com/centos/8/esl-erlang_26.2.1_1~centos~8_x86_64.rpm"
else
    # Rocky Linux 9: packages under rockylinux/esl-erlang-26/
    ESL_ERLANG_URL="https://binaries2.erlang-solutions.com/rockylinux/esl-erlang-26/esl-erlang_26.2.1_1~centos~8_x86_64.rpm"
fi
curl -o /tmp/esl-erlang.rpm "$ESL_ERLANG_URL"
dnf -y install /tmp/esl-erlang.rpm
rm -f /tmp/esl-erlang.rpm

# Install runtime dependencies
echo "--- Installing runtime dependencies ---"
dnf -y install openssl-devel lksctp-tools
dnf clean all

# Verify Erlang
echo "--- Verifying Erlang/OTP ---"
erl -noinput -eval \
    '[ok = application:ensure_started(A) || A <- [kernel,stdlib,sasl,mnesia,crypto,asn1,public_key,ssl,inets,xmerl,compiler,parsetools,syntax_tools,os_mon,snmp,diameter]], io:format("OTP apps OK~n"), init:stop().'

# Create otp system user
echo "--- Creating otp user ---"
if ! id -u otp &>/dev/null; then
    groupadd -r otp
    useradd -r -g otp -m -d /home/otp -s /bin/bash otp
else
    echo "User otp already exists."
fi

# Create directory structure
echo "--- Creating directory structure ---"
OTP_HOME=/home/otp
mkdir -p ${OTP_HOME}/{db,ssl,bin,releases,lib}
mkdir -p ${OTP_HOME}/log/{acct,auth,abmf,ipdr,export,http,sasl}
mkdir -p ${OTP_HOME}/snmp/{conf,db}
chown -R otp:otp ${OTP_HOME}

# Enable epmd (if systemd is available)
echo "--- Enabling epmd ---"
if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null 2>&1; then
    if systemctl list-unit-files epmd.socket 2>/dev/null | grep -q epmd.socket; then
        systemctl enable epmd.socket
        systemctl start epmd.socket
    else
        echo "epmd.socket unit not found — epmd will start automatically with Erlang nodes."
    fi
else
    echo "systemd not available — epmd will start automatically with Erlang nodes."
fi

echo ""
echo "=== Prerequisites installed successfully ==="
echo "OS: Rocky Linux ${OS_VERSION}"
echo "Erlang: $(erl -noinput -eval 'io:format("~s", [erlang:system_info(otp_release)]), init:stop().')"
