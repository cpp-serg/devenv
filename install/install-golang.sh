#!/bin/bash

source "$(dirname "$0")/_install_preambule.sh"

# translate the detected system architecture into Go's GOARCH naming
case "$SYSTEM_ARCH" in
  x86_64)  SYSTEM_GOARCH=amd64 ;;
  aarch64) SYSTEM_GOARCH=arm64 ;;
  *)       die "Unsupported architecture: $SYSTEM_ARCH" ;;
esac

LATEST=$(curl -fsSL --retry 3 --retry-delay 2 "https://go.dev/dl/?mode=json" | jq -r '.[0].version')
[[ -n "$LATEST" ]] && [[ "$LATEST" != "null" ]] || die "Failed to determine latest Go version"

ARCHIVE="${LATEST}.linux-${SYSTEM_GOARCH}.tar.gz"

echo "Installing ${LATEST} for linux/${SYSTEM_GOARCH}..."
curl -fsSL --retry 3 --retry-delay 2 "https://go.dev/dl/${ARCHIVE}" -o /tmp/go.tar.gz || die "Failed to download Go"

${SUDO} rm -rf /usr/local/go
${SUDO} tar -C /usr/local -xzf /tmp/go.tar.gz || die "Failed to extract Go"
rm /tmp/go.tar.gz

echo 'export PATH=$PATH:/usr/local/go/bin' | ${SUDO} tee /etc/profile.d/go.sh > /dev/null

echo "Go $(/usr/local/go/bin/go version) installed successfully"
