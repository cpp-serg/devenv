#!/bin/bash

SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

die() {
  echo "$1" 1>&2
  exit 1
}

# Install SCTP kernel module and development libraries
if command -v dnf &>/dev/null; then
  ${SUDO} dnf install -y kernel-modules-extra lksctp-tools lksctp-tools-devel || die "Failed to install SCTP packages"
elif command -v yum &>/dev/null; then
  ${SUDO} yum install -y kernel-modules-extra lksctp-tools lksctp-tools-devel || die "Failed to install SCTP packages"
elif command -v apt-get &>/dev/null; then
  ${SUDO} apt-get update && ${SUDO} apt-get install -y linux-modules-extra-$(uname -r) libsctp-dev lksctp-tools || die "Failed to install SCTP packages"
else
  die "Unsupported package manager"
fi

# Comment out SCTP blacklist entry if it exists
if [[ -f /etc/modprobe.d/sctp-blacklist.conf ]]; then
  ${SUDO} sed -i 's/^blacklist sctp/#blacklist sctp/' /etc/modprobe.d/sctp-blacklist.conf || die "Failed to comment out SCTP blacklist entry"
fi

# Load the SCTP module immediately
${SUDO} modprobe sctp || die "Failed to load SCTP module"

# Enable SCTP module to load on boot
echo "sctp" | ${SUDO} tee /etc/modules-load.d/sctp.conf > /dev/null || die "Failed to configure SCTP module autoload"

echo "SCTP module installed and enabled successfully"
