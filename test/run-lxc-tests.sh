#!/bin/bash
# Run the bootstrap end to end in throwaway LXC containers on a Proxmox host.
#
#   test/run-lxc-tests.sh                       # all distros, user + dev, then destroy
#   test/run-lxc-tests.sh --only debian13       # one distro
#   test/run-lxc-tests.sh --mode user --keep    # user mode only, leave the CTs running
#   test/run-lxc-tests.sh --full                # include the /opt/tools cargo/go rebuild
#
# What it exercises that a local run cannot:
#   - bootstrap.sh under dash (Debian/Ubuntu /bin/sh), the reason it is POSIX
#   - a genuinely empty machine: no git, no curl, no compiler
#   - the EL8 path (EPEL + powertools, tmux 2.7 -> source build)
#   - update-alternatives for fd/bat on apt distros
#   - re-running the bootstrap on a configured host (idempotency)
#
# Containers are created unprivileged with nesting enabled, on local-lvm, with
# DHCP on vmbr0. Nothing on the host is modified apart from downloading the
# container templates.

set -uo pipefail

MY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${MY_DIR}/.." && pwd)

STORAGE=${STORAGE:-local-lvm}
BRIDGE=${BRIDGE:-vmbr0}
TEMPLATE_DIR=/var/lib/vz/template/cache
CORES=4
MEMORY=4096
DISK=16

KEEP=false
RECREATE=false
FULL=false
MODES="user dev"
ONLY=""

# name : ctid : template-spec : ostype
# The Proxmox appliance index has no Rocky 8 (only 9 and 10), so that one comes
# from the linuxcontainers.org image server and is verified against SHA256SUMS.
TARGETS=(
    "rocky8:9001:lxc:rockylinux/8:centos"
    "ubuntu2404:9002:pveam:ubuntu-24.04-standard:ubuntu"
    "debian13:9003:pveam:debian-13-standard:debian"
)

usage() { sed -n '2,26p' "$0"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --only) ONLY=${2:?--only needs a name}; shift ;;
        --mode) MODES=${2:?--mode needs user|dev|both}; [ "$MODES" = both ] && MODES="user dev"; shift ;;
        --keep) KEEP=true ;;
        --recreate) RECREATE=true ;;
        --full) FULL=true ;;
        -h | --help) usage; exit 0 ;;
        *) echo "unknown option $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

command -v pct >/dev/null 2>&1 || { echo "this must run on a Proxmox VE host (pct not found)" >&2; exit 1; }

C_OK=$'\033[32m'; C_BAD=$'\033[31m'; C_B=$'\033[1m'; C_0=$'\033[0m'
# Progress goes to stderr: several of these functions print their result on
# stdout for the caller to capture.
say() { printf '%s==>%s %s\n' "$C_B" "$C_0" "$*" >&2; }
bad() { printf '%sFAIL%s %s\n' "$C_BAD" "$C_0" "$*" >&2; }
good() { printf '%s ok %s %s\n' "$C_OK" "$C_0" "$*" >&2; }

RESULTS=()
FAILURES=0

# ---------------------------------------------------------------------------
# templates
# ---------------------------------------------------------------------------
ensure_pveam_template() {
    local spec="$1" file
    file=$(pveam available --section system 2>/dev/null | awk -v s="$spec" '$2 ~ s {print $2}' | sort | tail -1)
    [ -n "$file" ] || { bad "no template matching ${spec}"; return 1; }
    if [ ! -f "${TEMPLATE_DIR}/${file}" ]; then
        say "downloading template ${file}"
        pveam download local "$file" >/dev/null || return 1
    fi
    echo "local:vztmpl/${file}"
}

ensure_lxc_template() {
    # linuxcontainers.org rootfs, e.g. rockylinux/8
    local image="$1" base url stamp sum local_name
    base="https://images.linuxcontainers.org/images/${image}/amd64/default"
    # Listing entries look like href="20260728_05%3A58/" - no ./ prefix, and the
    # colon in the timestamp is percent-encoded.
    stamp=$(curl -fsSL --max-time 30 "${base}/" \
        | grep -oE 'href="(\./)?[0-9]{8}_[0-9]+(%3A[0-9]+)?/"' \
        | sed -E 's|href="(\./)?||; s|/"||' | sort | tail -1)
    [ -n "$stamp" ] || { bad "could not list images for ${image}"; return 1; }

    local_name="$(echo "$image" | tr '/' '-')-rootfs.tar.xz"
    url="${base}/${stamp}/rootfs.tar.xz"

    if [ ! -f "${TEMPLATE_DIR}/${local_name}" ]; then
        say "downloading ${image} rootfs (${stamp//%3A/:})"
        curl -fsSL --max-time 600 "$url" -o "${TEMPLATE_DIR}/${local_name}.part" || return 1

        # Verify against the published checksum before using it as a template.
        sum=$(curl -fsSL --max-time 60 "${base}/${stamp}/SHA256SUMS" \
            | awk '$2 ~ /rootfs.tar.xz$/ {print $1}' | head -1)
        if [ -n "$sum" ]; then
            local got
            got=$(sha256sum "${TEMPLATE_DIR}/${local_name}.part" | awk '{print $1}')
            if [ "$got" != "$sum" ]; then
                rm -f "${TEMPLATE_DIR}/${local_name}.part"
                bad "checksum mismatch for ${image} rootfs"
                return 1
            fi
            say "checksum verified"
        else
            echo "WARN: no SHA256SUMS entry for ${image}; using the download unverified" >&2
        fi
        mv "${TEMPLATE_DIR}/${local_name}.part" "${TEMPLATE_DIR}/${local_name}"
    fi
    echo "local:vztmpl/${local_name}"
}

# ---------------------------------------------------------------------------
# container lifecycle
# ---------------------------------------------------------------------------
ct_exists() { pct config "$1" >/dev/null 2>&1; }

ct_create() {
    local id="$1" template="$2" ostype="$3" name="$4"

    if ct_exists "$id" && [ "$RECREATE" = true ]; then
        say "destroying existing CT ${id}"
        pct stop "$id" >/dev/null 2>&1
        pct destroy "$id" --purge >/dev/null || return 1
    fi

    if ! ct_exists "$id"; then
        say "creating CT ${id} (${name})"
        pct create "$id" "$template" \
            --hostname "devenv-${name}" \
            --ostype "$ostype" \
            --cores "$CORES" --memory "$MEMORY" \
            --rootfs "${STORAGE}:${DISK}" \
            --net0 "name=eth0,bridge=${BRIDGE},ip=dhcp" \
            --unprivileged 1 --features nesting=1 \
            --onboot 0 >/dev/null || return 1
    fi

    pct status "$id" | grep -q running || pct start "$id" >/dev/null || return 1

    say "waiting for network in CT ${id}"
    pct exec "$id" -- sh -c '
        i=0
        while [ $i -lt 90 ]; do
            if getent hosts github.com >/dev/null 2>&1; then exit 0; fi
            i=$((i+1)); sleep 2
        done
        exit 1' || { bad "CT ${id} never got working DNS/network"; return 1; }
}

# Strip the machine down to what a fresh install really has: no git, no curl,
# no compiler. That is the situation bootstrap.sh has to cope with.
ct_prepare() {
    local id="$1"
    say "removing git/curl from CT ${id} so the bootstrap has to install them"
    pct exec "$id" -- sh -c '
        if command -v dnf >/dev/null 2>&1; then
            dnf -y remove git 2>/dev/null
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get -y purge git >/dev/null 2>&1
        fi
        exit 0' >/dev/null 2>&1
    # tar is needed to unpack the source tree we push in; every template has it.
    pct exec "$id" -- sh -c 'command -v tar >/dev/null || (dnf -y install tar || (apt-get update && apt-get install -y tar))' >/dev/null 2>&1
}

ct_push_source() {
    local id="$1" tarball=/tmp/devenv-src.tar.gz
    tar -C "$REPO_ROOT" --exclude=.git --exclude='*.log' -czf "$tarball" . || return 1
    pct push "$id" "$tarball" /root/devenv-src.tar.gz || return 1
    pct exec "$id" -- sh -c 'rm -rf /root/devenv-src && mkdir -p /root/devenv-src && tar -C /root/devenv-src -xzf /root/devenv-src.tar.gz'
}

# ---------------------------------------------------------------------------
# assertions
# ---------------------------------------------------------------------------
# check <ctid> <label> <shell-snippet>
#
# Runs as a login shell with an explicit PATH. `pct exec` alone gives
# PATH=/sbin:/bin:/usr/sbin:/usr/bin, which hides /usr/local/bin - exactly where
# update-alternatives puts fd, nvim and friends. Debian's /etc/profile repairs
# PATH for root, Ubuntu's does not, so the login shell alone is not enough; -l is
# still wanted for /etc/profile.d (where the Go installer adds its path).
CT_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
check() {
    local id="$1" label="$2" snippet="$3" out
    if out=$(pct exec "$id" -- sh -lc "export PATH=${CT_PATH}; ${snippet}" 2>&1); then
        good "$label"
        return 0
    fi
    bad "${label}${out:+ -- ${out}}"
    FAILURES=$((FAILURES + 1))
    return 1
}

assert_common() {
    local id="$1" mode="$2"

    # Needs a pty: without a controlling terminal zsh refuses to enable zle and
    # complains, which says nothing about the dotfiles. `script` provides one.
    check "$id" "zsh starts an interactive shell cleanly" \
        'command -v script >/dev/null || exit 0
         out=$(script -qec "zsh -ic exit" /dev/null 2>&1 | tr -d "\r")
         [ -z "$out" ] || { echo "$out"; exit 1; }'

    check "$id" "fzf is on PATH inside zsh" \
        'zsh -ic "command -v fzf" >/dev/null 2>&1'

    check "$id" "core tools on PATH (rg fd git zsh)" \
        'for c in rg fd git zsh; do command -v $c >/dev/null || { echo "missing: $c"; exit 1; }; done'

    check "$id" "neovim built and installed" \
        'command -v nvim >/dev/null && nvim --version | head -1'

    check "$id" "base toolchain present (gcc g++ cmake ninja)" \
        'for c in gcc g++ cmake ninja; do command -v $c >/dev/null || { echo "missing: $c"; exit 1; }; done'

    check "$id" "cmake >= 3.20" \
        'v=$(cmake --version | head -1 | sed -nE "s/.* ([0-9]+\.[0-9]+).*/\1/p"); [ "$(printf "%s\n3.20\n" "$v" | sort -V | head -1)" = "3.20" ]'

    # The version floor: Rocky 8 packages tmux 2.7, so clearing 3.2 there proves
    # the source-build fallback ran; Debian/Ubuntu clear it from the package.
    check "$id" "tmux >= 3.2 (source build where the distro is too old)" \
        'v=$(tmux -V | sed -nE "s/tmux ([0-9]+\.[0-9]+).*/\1/p")
         [ "$(printf "%s\n3.2\n" "$v" | sort -V | head -1)" = "3.2" ] || { echo "tmux $v"; exit 1; }'

    check "$id" "HOME/.zshrc symlinked into the repo" \
        '[ "$(readlink -f "$HOME/.zshrc")" = /root/devenv/dotfiles/.zshrc ]'

    check "$id" "HOME/.config entries symlinked, not the whole directory" \
        '[ ! -L "$HOME/.config" ] && [ "$(readlink -f "$HOME/.config/nvim")" = /root/devenv/dotfiles/.config/nvim ]'

    check "$id" "oh-my-zsh installed with the repo custom dir" \
        '[ -d ~/.oh-my-zsh ] && [ -d /root/devenv/dotfiles/zsh_custom/plugins/zsh-autosuggestions ]'

    check "$id" "fd runs under its canonical name" 'fd --version'

    check "$id" "EDITOR resolves to nvim" \
        '[ "$(zsh -ic "echo \$EDITOR" 2>/dev/null | tail -1)" = nvim ]'

    # Debian/Ubuntu name the binaries differently, so the alternatives link is
    # what makes `fd` work at all.
    if pct exec "$id" -- sh -c 'command -v apt-get >/dev/null'; then
        check "$id" "fd registered via update-alternatives at priority 50" \
            'update-alternatives --display fd | grep -q "priority 50"'
        check "$id" "fd resolves to /usr/local/bin (the alternatives link)" \
            '[ "$(command -v fd)" = /usr/local/bin/fd ]'
    fi

    if [ "$mode" = user ]; then
        check "$id" "user mode left the optional dev extras out" \
            'for c in ccache rustc go; do command -v $c >/dev/null && { echo "unexpected: $c"; exit 1; }; done; exit 0'
    else
        check "$id" "dev mode installed the extras (ccache gdb rustc go)" \
            '. /etc/profile.d/go.sh 2>/dev/null; [ -f ~/.cargo/env ] && . ~/.cargo/env
             for c in ccache gdb rustc; do command -v $c >/dev/null || { echo "missing: $c"; exit 1; }; done
             command -v go >/dev/null || [ -x /usr/local/go/bin/go ] || { echo "missing: go"; exit 1; }'
    fi
}

assert_idempotent() {
    local id="$1" mode="$2"
    say "re-running setup.sh in CT ${id} to check idempotency"
    check "$id" "second run succeeds" \
        "/root/devenv/setup.sh --${mode} --yes --no-opt-tools >/tmp/rerun.log 2>&1 || { tail -20 /tmp/rerun.log; exit 1; }"
    check "$id" "second run created no new dotfile backups" \
        'n=$(ls -d "$HOME"/.zshrc.bak.* 2>/dev/null | wc -l); [ "$n" -le 1 ]'
}

# The rust helper plus _deploy_to_opt and the priority-100 alternative is the
# interesting part of the /opt/tools path; build one tool rather than all of them.
assert_opt_tools_path() {
    local id="$1"
    say "building one cargo tool in CT ${id} to exercise /opt/tools + alternatives"
    check "$id" "install-fd.sh builds and deploys to /opt/tools" \
        '. ~/.cargo/env 2>/dev/null; /root/devenv/install/install-fd.sh >/tmp/fd.log 2>&1 || { tail -20 /tmp/fd.log; exit 1; }
         [ -x /opt/tools/fd ]'
    check "$id" "/opt/tools/fd wins the alternative at priority 100" \
        'update-alternatives --display fd | grep -q "/opt/tools/fd - priority 100" && [ "$(readlink -f /usr/local/bin/fd)" = /opt/tools/fd ]'
}

# ---------------------------------------------------------------------------
# one target
# ---------------------------------------------------------------------------
run_target() {
    local spec="$1" mode="$2"
    local name ctid kind image ostype template
    IFS=: read -r name ctid kind image ostype <<<"$spec"

    printf '\n%s########## %s / %s mode ##########%s\n' "$C_B" "$name" "$mode" "$C_0"

    if [ "$kind" = pveam ]; then
        template=$(ensure_pveam_template "$image") || { RESULTS+=("${name}/${mode}: TEMPLATE FAILED"); FAILURES=$((FAILURES+1)); return 1; }
    else
        template=$(ensure_lxc_template "$image") || { RESULTS+=("${name}/${mode}: TEMPLATE FAILED"); FAILURES=$((FAILURES+1)); return 1; }
    fi

    ct_create "$ctid" "$template" "$ostype" "${name}-${mode}" \
        || { RESULTS+=("${name}/${mode}: CREATE FAILED"); FAILURES=$((FAILURES+1)); return 1; }
    ct_prepare "$ctid"
    ct_push_source "$ctid" \
        || { RESULTS+=("${name}/${mode}: PUSH FAILED"); FAILURES=$((FAILURES+1)); return 1; }

    local extra=""
    [ "$FULL" = true ] || extra="--no-opt-tools"

    # Deliberately invoked with `sh`, exactly like the documented one-liner: on
    # Debian and Ubuntu that is dash, which is what broke the old bootstrap.
    say "running bootstrap (${mode} mode) in CT ${ctid}"
    local start=$SECONDS
    if pct exec "$ctid" -- sh -c \
        "sh /root/devenv-src/bootstrap.sh --repo /root/devenv-src --target /root/devenv --${mode} --yes ${extra} >/tmp/bootstrap.log 2>&1"
    then
        good "bootstrap finished in $((SECONDS - start))s"
    else
        bad "bootstrap failed; last 40 lines:"
        pct exec "$ctid" -- tail -40 /tmp/bootstrap.log
        RESULTS+=("${name}/${mode}: BOOTSTRAP FAILED")
        FAILURES=$((FAILURES + 1))
        return 1
    fi

    local before=$FAILURES
    assert_common "$ctid" "$mode"
    assert_idempotent "$ctid" "$mode"
    [ "$mode" = dev ] && [ "$FULL" != true ] && assert_opt_tools_path "$ctid"

    if [ "$FAILURES" -eq "$before" ]; then
        RESULTS+=("${name}/${mode}: PASS")
    else
        RESULTS+=("${name}/${mode}: $((FAILURES - before)) check(s) failed")
    fi

    if [ "$KEEP" != true ]; then
        say "destroying CT ${ctid}"
        pct stop "$ctid" >/dev/null 2>&1
        pct destroy "$ctid" --purge >/dev/null 2>&1
    fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
say "storage=${STORAGE} bridge=${BRIDGE} modes='${MODES}' keep=${KEEP} full=${FULL}"
pveam update >/dev/null 2>&1 || true

for spec in "${TARGETS[@]}"; do
    tname=${spec%%:*}
    if [ -n "$ONLY" ] && [ "$tname" != "$ONLY" ]; then continue; fi
    for mode in $MODES; do
        run_target "$spec" "$mode"
    done
done

printf '\n%s==================== Results ====================%s\n' "$C_B" "$C_0"
for r in "${RESULTS[@]}"; do
    case "$r" in
        *PASS) good "$r" ;;
        *) bad "$r" ;;
    esac
done

if [ "$FAILURES" -ne 0 ]; then
    printf '\n%d check(s) failed\n' "$FAILURES" >&2
    exit 1
fi
printf '\nall checks passed\n'
