#!/bin/bash

function die() {
  echo "$1" 1>&2
  exit 1
}

export PATH=$PATH:/usr/local/go/bin

go install github.com/peco/peco/cmd/peco@latest || die "Failed to install peco"

cp "$HOME/go/bin/peco" /opt/tools/ && chmod 755 /opt/tools/peco

echo "peco $(/opt/tools/peco --version) installed successfully"
