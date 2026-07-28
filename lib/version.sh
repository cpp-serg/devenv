#!/bin/bash
# Version comparison, used to decide "is the distro package new enough or do we
# need to build from source". Meant to be *sourced*.

[ -n "${SP_VERSION_SOURCED:-}" ] && return 0
SP_VERSION_SOURCED=1

# version_ge <have> <want> : 0 when have >= want.
# Tolerates the suffixes real tools print (3.5a, 1.2.3-rc1, 0.10.0-dev).
version_ge() {
    local have want first
    have=$(version_normalize "$1")
    want=$(version_normalize "$2")
    [ -z "$have" ] && return 1
    [ "$have" = "$want" ] && return 0
    first=$(printf '%s\n%s\n' "$have" "$want" | sort -V | head -n1)
    [ "$first" = "$want" ]
}

# version_normalize <string> : keep the leading dotted-numeric part.
#   "tmux 3.5a" -> 3.5 ; "v0.11.4" -> 0.11.4
version_normalize() {
    printf '%s' "$1" | sed -nE 's/^[^0-9]*([0-9]+(\.[0-9]+)*).*/\1/p'
}

# cmd_version <cmd> : numeric version of an installed binary, empty if absent.
cmd_version() {
    command -v "$1" >/dev/null 2>&1 || return 0
    version_normalize "$("$1" --version 2>/dev/null | head -n1)"
}
