#!/bin/bash

function die() {
  echo "$1" 1>&2
  exit 1
}

export PATH=$PATH:/usr/local/go/bin

go install github.com/jesseduffield/lazygit@latest || die "Failed to install lazygit"

cp "$HOME/go/bin/lazygit" /opt/tools/ && chmod 755 /opt/tools/lazygit

echo "lazygit installed successfully"
