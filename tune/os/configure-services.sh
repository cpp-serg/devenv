#!/usr/bin/env bash
# Site-specific host tweaks: sshd, the tmux system config and the CIFS build
# share. Dev mode only (setup.sh --dev), skippable with --no-work-tweaks, and
# never run on a Proxmox host.
#
# Every change is conditional and idempotent, so re-running is a no-op and a
# host that does not have the file/service in question is simply left alone.

set -euo pipefail

MY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/pkg.sh
. "${MY_DIR}/../../lib/pkg.sh"

BUILDS_SHARE='//10.20.7.41/Builds'
BUILDS_MOUNT=/mnt/builds
BUILDS_USER=${SP_BUILDS_USER:-sergiy@pentenetworks.com}

if [ "$IS_PVE" = true ]; then
    warn "Proxmox VE host: skipping sshd/tmux/CIFS tweaks entirely"
    exit 0
fi

# ---------------------------------------------------------------------------
# sshd: no login banner, and TCP forwarding on for remote VSCode/Cursor
# ---------------------------------------------------------------------------
configure_sshd() {
    local cfg=/etc/ssh/sshd_config unit changed=false

    [ -f "$cfg" ] || { warn "${cfg} not found; skipping sshd tweaks"; return 0; }

    if ${SUDO} grep -qE '^Banner ' "$cfg"; then
        step "disabling the ssh banner"
        ${SUDO} sed -i 's/^Banner /#Banner /' "$cfg"
        changed=true
    fi

    if ${SUDO} grep -qiE '^[[:space:]]*AllowTcpForwarding[[:space:]]+no' "$cfg"; then
        step "enabling AllowTcpForwarding"
        ${SUDO} sed -i -E 's/^([[:space:]]*AllowTcpForwarding[[:space:]]+)no/\1yes/I' "$cfg"
        changed=true
    fi

    if [ "$changed" != true ]; then
        step "sshd config already as wanted"
        return 0
    fi

    # The unit is sshd on EL and ssh on Debian/Ubuntu.
    for unit in sshd ssh; do
        if systemctl list-unit-files "${unit}.service" >/dev/null 2>&1 \
            && systemctl cat "${unit}.service" >/dev/null 2>&1; then
            step "restarting ${unit}"
            ${SUDO} systemctl restart "$unit" || warn "could not restart ${unit}"
            return 0
        fi
    done
    warn "no sshd/ssh unit found; restart it yourself for the change to take effect"
}

# ---------------------------------------------------------------------------
# tmux: drop the distro's screen-lock binding
# ---------------------------------------------------------------------------
configure_tmux() {
    # Debian and Ubuntu ship no /etc/tmux.conf at all.
    if [ ! -f /etc/tmux.conf ]; then
        step "no /etc/tmux.conf on this distro; nothing to patch"
        return 0
    fi
    if ${SUDO} grep -qE '^set -g lock' /etc/tmux.conf; then
        step "disabling the tmux lock setting"
        ${SUDO} sed -i 's/^set -g lock/#set -g lock/g' /etc/tmux.conf
    else
        step "/etc/tmux.conf already patched"
    fi
}

# ---------------------------------------------------------------------------
# CIFS build share
# ---------------------------------------------------------------------------
configure_builds_mount() {
    if ! grep -q "$BUILDS_MOUNT" /etc/fstab 2>/dev/null; then
        step "adding the ${BUILDS_MOUNT} fstab entry"
        # NB: a redirect after ${SUDO} runs as the *calling* user, so this has to
        # go through tee to work when not already root.
        printf '%s %s cifs username=%s,noauto,_netdev 0 0\n' \
            "$BUILDS_SHARE" "$BUILDS_MOUNT" "$BUILDS_USER" \
            | ${SUDO} tee -a /etc/fstab >/dev/null
        ${SUDO} systemctl daemon-reload || true
    else
        step "fstab entry for ${BUILDS_MOUNT} already present"
    fi

    pkg_install_native cifs-utils \
        || warn "cifs-utils not installed; the share cannot be mounted"

    ${SUDO} install -d -m 755 "$BUILDS_MOUNT"

    if mountpoint -q "$BUILDS_MOUNT" 2>/dev/null; then
        step "${BUILDS_MOUNT} already mounted"
        return 0
    fi

    step "mounting ${BUILDS_MOUNT}"
    # Credentials are interactive, so a failure here is expected on an
    # unattended run and must not fail the whole bootstrap.
    ${SUDO} mount "$BUILDS_MOUNT" \
        || warn "could not mount ${BUILDS_MOUNT} (credentials needed?); entry left in /etc/fstab"
}

configure_sshd
configure_tmux
configure_builds_mount
