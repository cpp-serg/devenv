#!/bin/bash

function die() {
  echo "$1" 1>&2
  exit 1
}

export PATH=$PATH:/usr/local/go/bin

go install github.com/junegunn/fzf@latest || die "Failed to install fzf"

cp "$HOME/go/bin/fzf" /opt/tools/ && chmod 755 /opt/tools/fzf

echo "fzf $(/opt/tools/fzf --version) installed successfully"
