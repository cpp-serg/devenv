#!/bin/bash
# Install a Rust crate via cargo and deploy its binary to /opt/tools.
#   _install_with_rust.sh <crate> [binary]
# <binary> defaults to <crate>; pass it explicitly when the produced binary
# name differs from the crate name (e.g. crate git-delta -> binary delta).

source "$(dirname "${BASH_SOURCE[0]}")/_install_preambule.sh"

CRATE="${1:?Usage: $0 <crate> [binary]}"
BINARY="${2:-$CRATE}"

[ -f "$HOME/.cargo/env" ] || die "Rust/cargo not found; run install-rust.sh first"
. "$HOME/.cargo/env"

cargo install "$CRATE" || die "Failed to install $CRATE"

_deploy_to_opt "$HOME/.cargo/bin/$BINARY"
