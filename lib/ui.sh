#!/bin/bash
# Output helpers, the yes/no interview, and the run/ok/failed step tracker.
# Meant to be *sourced*.
#
# Honours three globals that setup.sh sets from the command line:
#   SP_INTERACTIVE  true when a terminal is attached and questions may be asked
#   SP_ASSUME_YES   true for --yes: never ask, take every default
#   SP_DRY_RUN      true for --dry-run: print what would run, change nothing

[ -n "${SP_UI_SOURCED:-}" ] && return 0
SP_UI_SOURCED=1

: "${SP_INTERACTIVE:=false}"
: "${SP_ASSUME_YES:=false}"
: "${SP_DRY_RUN:=false}"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

# ✓/✗ only when the locale can render them, so RL8 with LANG=C stays readable.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *[Uu][Tt][Ff]*) GLYPH_OK="✓"; GLYPH_NO="✗" ;;
    *)              GLYPH_OK="+"; GLYPH_NO="-" ;;
esac

say()  { printf '%s\n' "$*"; }
info() { printf '%s==>%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*"; }
step() { printf '%s -->%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
warn() { printf '%sWARN:%s %s\n' "$C_YELLOW$C_BOLD" "$C_RESET" "$*" >&2; }
err()  { printf '%sERROR:%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

header() {
    printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"
}

# have <cmd> : is the command on PATH?
have() { command -v "$1" >/dev/null 2>&1; }

# tool_version <cmd> : best-effort one-line version string
tool_version() {
    local v
    v=$("$1" --version 2>/dev/null | head -n1) || true
    [ -z "$v" ] && v=$("$1" -V 2>/dev/null | head -n1) || true
    # Trim the tool's own name off the front so the column stays narrow.
    printf '%s' "${v:-installed}"
}

# ask_yn <prompt> [default:y|n] : 0 = yes, 1 = no.
# Non-interactive or --yes takes the default without asking. Reads from /dev/tty
# rather than stdin, so it still works when the script itself arrived on stdin.
ask_yn() {
    local prompt="$1" def="${2:-y}" ans hint
    if [ "$def" = y ]; then hint="[Y/n]"; else hint="[y/N]"; fi

    if [ "$SP_ASSUME_YES" = true ] || [ "$SP_INTERACTIVE" != true ]; then
        [ "$def" = y ] && return 0 || return 1
    fi

    while :; do
        printf '%s %s ' "$prompt" "$hint" >/dev/tty
        IFS= read -r ans </dev/tty || ans=""
        case "$ans" in
            "")       [ "$def" = y ] && return 0 || return 1 ;;
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo])     return 1 ;;
            *)        printf 'Please answer y or n.\n' >/dev/tty ;;
        esac
    done
}

# ask_group <default:y|n> <title> <tool>... : show what is already present in
# this group, then ask once whether to install it.
#
#   Compilers/build (gcc, g++, make)
#     gcc      ✓ gcc (Debian 12.2.0-14) 12.2.0
#     g++      ✗ missing
#   Install this group? [Y/n]
ask_group() {
    local def="$1" title="$2"; shift 2
    local tool

    header "$title"
    for tool in "$@"; do
        if have "$tool"; then
            printf '  %-14s %s%s%s %s\n' "$tool" "$C_GREEN" "$GLYPH_OK" "$C_RESET" "$(tool_version "$tool")"
        else
            printf '  %-14s %s%s%s missing\n' "$tool" "$C_YELLOW" "$GLYPH_NO" "$C_RESET"
        fi
    done
    ask_yn "Install this group?" "$def"
}

# ---------------------------------------------------------------------------
# Step tracker: same ok/failed bookkeeping as install/rebuild_all_tools.sh, so
# one failing optional tool never aborts the whole bootstrap.
# ---------------------------------------------------------------------------
SP_OK=()
SP_FAILED=()
SP_SKIPPED=()

# run_step <label> <cmd> [args...]
# In dry-run the step still runs: pkg_install, alt_register and run_script all
# stop short of changing anything, so the output is the plan rather than a list
# of step names.
run_step() {
    local label="$1"; shift
    printf '\n%s==================== %s ====================%s\n' "$C_BOLD" "$label" "$C_RESET"
    if "$@"; then
        SP_OK+=("$label")
    else
        err "${label} FAILED"
        SP_FAILED+=("$label")
        return 1
    fi
}

skip_step() {
    step "skipping $1${2:+ ($2)}"
    SP_SKIPPED+=("$1${2:+ ($2)}")
}

print_summary() {
    header "==================== Summary ===================="
    printf 'OK (%d): %s\n' "${#SP_OK[@]}" "${SP_OK[*]:-none}"
    if [ "${#SP_SKIPPED[@]}" -ne 0 ]; then
        printf 'Skipped (%d): %s\n' "${#SP_SKIPPED[@]}" "${SP_SKIPPED[*]}"
    fi
    if [ "${#SP_FAILED[@]}" -ne 0 ]; then
        printf '%sFailed (%d): %s%s\n' "$C_RED$C_BOLD" "${#SP_FAILED[@]}" "${SP_FAILED[*]}" "$C_RESET" >&2
        return 1
    fi
    return 0
}
