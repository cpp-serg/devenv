#!/bin/bash

SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

function die() {
  echo "$1" 1>&2
  exit 1
}

${SUDO} dnf install -y clang-devel || die "Failed to install libclang"

. "$HOME/.cargo/env"

cargo install tree-sitter-cli || die "Failed to install tree-sitter-cli"

[[ ! -d /opt/tools ]] && ${SUDO} mkdir /opt/tools
[[ ! -x /opt/tools ]] && ${SUDO} chmod a+rx /opt/tools

${SUDO} cp "$HOME/.cargo/bin/tree-sitter" /opt/tools/ && ${SUDO} chmod 755 /opt/tools/tree-sitter

echo "tree-sitter $(tree-sitter --version) installed successfully"
