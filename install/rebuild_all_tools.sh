#!/bin/bash
# Refresh the Rust and Go toolchains, then rebuild and reinstall every tool
# whose installer deploys a binary into /opt/tools.
#
# The set of "tools that go to /opt/tools" is discovered automatically: any
# install-*.sh in this directory that builds through the rust/go helpers or
# calls _deploy_to_opt. Adding a new such installer needs no change here.

source "$(dirname "$0")/_install_preambule.sh"

MY_DIR=$(cd "$(dirname "$0")" && pwd)

ok=()
failed=()

# run <label> <cmd...> : run one step, record its outcome, never abort the batch
run() {
  local label="$1"; shift
  echo
  echo "==================== ${label} ===================="
  if "$@"; then
    ok+=("$label")
  else
    echo "!!! ${label} FAILED" >&2
    failed+=("$label")
  fi
}

# --- 1. Toolchains -----------------------------------------------------------
# Bring Rust up to the latest stable (or install it if missing), then Go
# (the Go installer always fetches the latest release).
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env" || true
if command -v rustup >/dev/null 2>&1; then
  run "rust: rustup update" rustup update
else
  run "rust: install-rust.sh" "$MY_DIR/install-rust.sh"
fi

run "go: install-golang.sh" "$MY_DIR/install-golang.sh"

# --- 2. Tools that install into /opt/tools -----------------------------------
for script in "$MY_DIR"/install-*.sh; do
  grep -qE '_install_with_(rust|go)|_deploy_to_opt' "$script" || continue
  run "$(basename "$script")" "$script"
done

# --- Summary -----------------------------------------------------------------
echo
echo "==================== Summary ===================="
echo "OK (${#ok[@]}): ${ok[*]:-none}"
if [ "${#failed[@]}" -ne 0 ]; then
  echo "FAILED (${#failed[@]}): ${failed[*]}" >&2
  exit 1
fi
echo "All tools rebuilt successfully."
