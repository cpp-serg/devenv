#!/bin/bash

set -euo pipefail

SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

function die() {
  echo "$1" 1>&2
  exit 1
}

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  GOARCH="amd64" ;;
  aarch64) GOARCH="arm64" ;;
  *)       die "Unsupported architecture: $ARCH" ;;
esac

LATEST=$(curl -fsSL "https://go.dev/dl/?mode=json" | jq -r '.[0].version')
[[ -n "$LATEST" ]] && [[ "$LATEST" != "null" ]] || die "Failed to determine latest Go version"

ARCHIVE="${LATEST}.linux-${GOARCH}.tar.gz"

echo "Installing ${LATEST} for linux/${GOARCH}..."
curl -fsSL "https://go.dev/dl/${ARCHIVE}" -o /tmp/go.tar.gz || die "Failed to download Go"

${SUDO} rm -rf /usr/local/go
${SUDO} tar -C /usr/local -xzf /tmp/go.tar.gz || die "Failed to extract Go"
rm /tmp/go.tar.gz

echo 'export PATH=$PATH:/usr/local/go/bin' | ${SUDO} tee /etc/profile.d/go.sh > /dev/null

echo "Go $(/usr/local/go/bin/go version) installed successfully"
