#!/bin/bash
source "$(dirname "$0")/_install_preambule.sh"

curl -fsSL --retry 3 --retry-delay 2 https://sh.rustup.rs | sh -s -- -y || die "Failed to install Rust"

. "$HOME/.cargo/env"
echo "Rust $(rustc --version) installed successfully"
