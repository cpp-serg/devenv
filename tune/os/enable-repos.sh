#!/bin/bash

function die {
    echo "ERROR: $*" 1>&2
    exit 1
}

# set ${SUDO} conditionally
SUDO=$(test $(id -u) -ne 0 && echo sudo)

${SUDO} dnf install -y dnf-plugins-core
${SUDO} dnf config-manager --set-enabled baseos appstream powertools \
    || die "Failed to enable baseos and powertools"

${SUDO} dnf install -y epel-release \
    && /usr/bin/crb enable \
    || die "Failed to enable EPEL"

