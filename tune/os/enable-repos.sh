#!/bin/bash

# set ${SUDO} conditionally
SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

if (yum repolist all appstream | grep disabled >/dev/null) then
    echo "Enalbe repos"
    ${SUDO} dnf config-manager --enable "*"
    ${SUDO} dnf config-manager --disable "media*"
    ${SUDO} dnf install -y epel-release
    ${SUDO} /usr/bin/crb enable
else
    echo "Repos are enabled"
fi
