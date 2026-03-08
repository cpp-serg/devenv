#!/bin/bash

function die() {
  echo "$1" 1>&2
  exit 1
}

. "$HOME/.cargo/env"

cargo install bat || die "Failed to install bat"

cp "$HOME/.cargo/bin/bat" /opt/tools/ && chmod 755 /opt/tools/bat

echo "bat $(bat --version) installed successfully"
