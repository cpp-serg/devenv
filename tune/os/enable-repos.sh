#!/bin/bash

function die {
    echo "ERROR: $*" 1>&2
    exit 1
}

# set ${SUDO} conditionally
SUDO=$(test $(id -u) -ne 0 && echo sudo)

dnf install -y --enablerepo="baseos" dnf-plugins-core 

${SUDO} dnf install -y --enablerepo="devel" --enablerepo="extras" epel-release \
    && /usr/bin/crb enable \
    || die "Failed to isntall/enable EPEL"

${SUDO} dnf config-manager --set-enabled "baseos*" "appstream*" "powertools*" "extras" "devel" "epel*" \
    || die "Failed to enable repos"
