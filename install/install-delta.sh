#!/bin/bash

function die() {
  echo "$1" 1>&2
  exit 1
}

. "$HOME/.cargo/env"

cargo install git-delta || die "Failed to install delta"

cp "$HOME/.cargo/bin/delta" /opt/tools/ && chmod 755 /opt/tools/delta

echo "delta $(delta --version) installed successfully"
