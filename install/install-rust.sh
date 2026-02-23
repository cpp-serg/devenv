#!/bin/bash

function die() {
  echo "$1" 1>&2
  exit 1
}

curl -fsSL https://sh.rustup.rs | sh -s -- -y || die "Failed to install Rust"

. "$HOME/.cargo/env"
echo "Rust $(rustc --version) installed successfully"
