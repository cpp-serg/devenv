#!/bin/bash

function die() {
  echo "$1" 1>&2
  exit 1
}

LATEST=$(curl -fsSL "https://go.dev/dl/?mode=json" | grep -o '"version":"go[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$LATEST" ] || die "Failed to determine latest Go version"

ARCHIVE="${LATEST}.linux-amd64.tar.gz"

curl -fsSL "https://go.dev/dl/${ARCHIVE}" -o /tmp/go.tar.gz || die "Failed to download Go"

rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/go.tar.gz || die "Failed to extract Go"
rm /tmp/go.tar.gz

echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh

echo "Go $(/usr/local/go/bin/go version) installed successfully"
