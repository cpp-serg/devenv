#!/usr/bin/env bash

# set ${SUDO} conditionally
SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

# Disable ssh banner
${SUDO} sed -i 's/^Banner /#Banner /' /etc/ssh/sshd_config

# enable ssh forwarding for remove VSCode/Cursor
${SUDO} sed -i -E 's/^(AllowTcpForwarding.*)no/\1yes/g' /etc/ssh/sshd_config
${SUDO} systemctl restart sshd

# disable tmux lock
${SUDO} sed -i 's/^set -g lock/#set -g lock/g' /etc/tmux.conf

# Add jpu_builds mount
# Add fstab entry for builds
if ! grep -q "/Builds" /etc/fstab; then
    echo "Adding fstab entry for builds"
    ${SUDO} echo '//10.20.7.41/Builds /mnt/builds cifs username=sergiy@pentenetworks.com  0 0' >> /etc/fstab
    ${SUDO} systemctl daemon-reload
fi

if [[ ! -d /mnt/builds ]]; then
    echo "Mounting builds"
    ${SUDO} mkdir -p /mnt/builds
    ${SUDO} mount /mnt/builds
fi


