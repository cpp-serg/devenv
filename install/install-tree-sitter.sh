#!/bin/bash

function die() {
  echo "$1" 1>&2
  exit 1
}

dnf install -y clang-devel || die "Failed to install libclang"

. "$HOME/.cargo/env"

cargo install tree-sitter-cli || die "Failed to install tree-sitter-cli"

cp "$HOME/.cargo/bin/tree-sitter" /opt/tools/ && chmod 755 /opt/tools/tree-sitter

echo "tree-sitter $(tree-sitter --version) installed successfully"
