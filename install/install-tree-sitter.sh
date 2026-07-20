#!/bin/bash
set -euo pipefail

command -v clang++ >/dev/null 2>&1 || { echo "No clang++ found, exiting" >&2; exit 1; }

exec "$(dirname "$0")/_install_with_rust.sh" tree-sitter-cli tree-sitter
