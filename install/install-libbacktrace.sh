#!/bin/bash
source "$(dirname "$0")/_install_preambule.sh"

_workdir
git clone https://github.com/ianlancetaylor/libbacktrace.git || die "Failed to clone libbacktrace"
cd libbacktrace || die "Failed to cd into libbacktrace"
./configure || die "Failed to configure libbacktrace"
make || die "Failed to make libbacktrace"
${SUDO} make install || die "Failed to install libbacktrace"

