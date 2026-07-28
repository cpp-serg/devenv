#!/bin/bash
source "$(dirname "$0")/_install_preambule.sh"

# SCTP userspace libraries and headers (lksctp-tools on EL, libsctp-dev on
# Debian - see lib/pkgmap.sh).
pkg_install sctp || die "Failed to install SCTP packages"

# The module itself lives in an extra kernel package on both families. It is
# keyed to the running kernel, so a mismatch (or a container's host kernel) just
# means there is nothing to install here.
case "$OS_FAMILY" in
  el)     kmod_pkg="kernel-modules-extra-$(uname -r)" ;;
  debian) kmod_pkg="linux-modules-extra-$(uname -r)" ;;
  *)      kmod_pkg="" ;;
esac

if [ "$IS_CONTAINER" = true ]; then
  warn "running in a container: the SCTP module has to be loaded on the host, skipping module setup"
  echo "SCTP libraries installed"
  exit 0
fi

if [ -n "$kmod_pkg" ]; then
  if pkg_available "$kmod_pkg"; then
    pkg_install_native "$kmod_pkg" || warn "failed to install ${kmod_pkg}"
  else
    warn "${kmod_pkg} is not available; assuming the module is built into the kernel"
  fi
fi

# Comment out SCTP blacklist entry if it exists
if [[ -f /etc/modprobe.d/sctp-blacklist.conf ]]; then
  ${SUDO} sed -i 's/^blacklist sctp/#blacklist sctp/' /etc/modprobe.d/sctp-blacklist.conf \
    || die "Failed to comment out SCTP blacklist entry"
fi

# Load the SCTP module immediately
${SUDO} modprobe sctp || die "Failed to load SCTP module"

# Enable SCTP module to load on boot
${SUDO} install -d -m 755 /etc/modules-load.d
echo "sctp" | ${SUDO} tee /etc/modules-load.d/sctp.conf > /dev/null \
  || die "Failed to configure SCTP module autoload"

echo "SCTP module installed and enabled successfully"
