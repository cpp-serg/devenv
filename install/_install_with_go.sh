#!/bin/bash
# Install a Go module via `go install` and deploy its binary to /opt/tools.
#   _install_with_go.sh <module> [binary]
# <binary> defaults to the basename of <module>; pass it explicitly when the
# produced binary name differs from the module's last path component.

source "$(dirname "${BASH_SOURCE[0]}")/_install_preambule.sh"

MODULE="${1:?Usage: $0 <module> [binary]}"
BINARY="${2:-$(basename "$MODULE")}"

export PATH=$PATH:/usr/local/go/bin

command -v go >/dev/null 2>&1 || die "Go not found; run install-golang.sh first"

go install "${MODULE}@latest" || die "Failed to install $BINARY"

_deploy_to_opt "$HOME/go/bin/$BINARY"
