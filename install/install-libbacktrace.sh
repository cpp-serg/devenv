#!/bin/bash

function die {
    echo $1
    exit 1
}

git clone https://github.com/ianlancetaylor/libbacktrace.git || die "Failed to clone libbacktrace"
cd libbacktrace || die "Failed to cd into libbacktrace"
./configure || die "Failed to configure libbacktrace"
make || die "Failed to make libbacktrace"
make install || die "Failed to install libbacktrace"
cd ..
rm -rf libbacktrace

