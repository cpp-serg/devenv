#!/usr/bin/env bash
# install.sh — Unified open5gs installer for Rocky Linux 8
#
# Supports LTE EPC, 5G Core, or all components via CLI flags or
# interactive terminal dialogs (whiptail/dialog).
#
# Usage:
#   ./install.sh [--rpm-dir DIR] [--components lte|5g|all] [--select]
#
# Examples:
#   ./install.sh                    # interactive: preset dialog → component checklist
#   ./install.sh -c lte             # non-interactive: install LTE preset
#   ./install.sh -c 5g --select     # start with 5G preset, customize in checklist
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/install-common.sh"

# ============================================================
# Component metadata
# ============================================================
declare -A COMP_DESC=(
    [mme]="Mobility Management Entity"
    [hss]="Home Subscriber Server"
    [pcrf]="Policy & Charging Rules"
    [sgwc]="Serving Gateway Control"
    [sgwu]="Serving Gateway User Plane"
    [smf]="Session Management Function"
    [upf]="User Plane Function"
    [nrf]="NF Repository Function"
    [scp]="Service Comm Proxy"
    [amf]="Access & Mobility Mgmt"
    [ausf]="Authentication Server Function"
    [udm]="Unified Data Management"
    [udr]="Unified Data Repository"
    [pcf]="Policy Control Function"
    [nssf]="Network Slice Selection"
    [bsf]="Binding Support Function"
    [sepp]="Security Edge Protection"
)

# Component → systemd daemon name
declare -A COMP_DAEMON=(
    [mme]=mmed   [hss]=hssd     [pcrf]=pcrfd  [sgwc]=sgwcd
    [sgwu]=sgwud [smf]=smfd     [upf]=upfd    [nrf]=nrfd
    [scp]=scpd   [amf]=amfd     [ausf]=ausfd  [udm]=udmd
    [udr]=udrd   [pcf]=pcfd     [nssf]=nssfd  [bsf]=bsfd
    [sepp]=seppd
)

# Components that use freeDiameter
declare -A COMP_FD=(
    [mme]=1 [hss]=1 [pcrf]=1 [smf]=1
)

# Component → loopback IP
declare -A COMP_IP=(
    [mme]=127.0.0.2   [sgwc]=127.0.0.3  [smf]=127.0.0.4
    [hss]=127.0.0.5   [sgwu]=127.0.0.6  [upf]=127.0.0.7
    [pcrf]=127.0.0.9  [nrf]=127.0.0.10  [scp]=127.0.0.200
    [amf]=127.0.0.5   [ausf]=127.0.0.11 [udm]=127.0.0.12
    [udr]=127.0.0.20  [pcf]=127.0.0.13  [nssf]=127.0.0.14
    [bsf]=127.0.0.15  [sepp]=127.0.0.250
)

# Default IPs in build-generated configs (from upstream templates)
# Only entries that DIFFER from COMP_IP need to be listed here.
declare -A BUILD_IP=(
    [hss]=127.0.0.8
)

# Path to BUILDROOT from the rpmbuild tree (exported by build.sh)
BUILDROOT="${SCRIPT_DIR}/rpms/rpmbuild/BUILDROOT/open5gs-2.7.7-1.el8.x86_64"

# Detect primary non-loopback IP of this host
HOST_IP=$(ip -4 route get 1.0.0.0 2>/dev/null | awk '/src/{print $7; exit}')

# ============================================================
# Presets
# ============================================================
PRESET_LTE=(mme hss pcrf sgwc sgwu smf upf)
PRESET_5G=(nrf scp amf ausf udm udr nssf bsf pcf smf upf)
PRESET_ALL=(mme hss pcrf sgwc sgwu smf upf nrf scp amf ausf udm udr nssf bsf pcf sepp)

# All known components (display order for checklist)
ALL_COMPONENTS=(mme hss pcrf sgwc sgwu smf upf nrf scp amf ausf udm udr pcf nssf bsf sepp)

# Service start order: servers/infrastructure first, then clients
SERVICE_ORDER_LTE=(hssd pcrfd sgwcd sgwud smfd upfd mmed)
SERVICE_ORDER_5G=(nrfd scpd ausfd udmd udrd pcfd nssfd bsfd smfd upfd amfd)
SERVICE_ORDER_ALL=(nrfd scpd hssd pcrfd ausfd udmd udrd pcfd nssfd bsfd sgwcd sgwud smfd upfd mmed amfd seppd)

# ============================================================
# Dialog detection
# ============================================================
DIALOG_CMD=""

detect_dialog() {
    if command -v dialog &>/dev/null; then
        DIALOG_CMD="dialog"
    elif command -v whiptail &>/dev/null; then
        DIALOG_CMD="whiptail"
    else
        echo "Neither dialog nor whiptail found. Installing dialog..."
        $SUDO dnf -y install dialog
        DIALOG_CMD="dialog"
    fi
}

# ============================================================
# Dialog functions
# ============================================================

# Preset selection radiolist → sets SELECTED_PRESET and SELECTED_COMPONENTS
# Returns 0 on OK, 1 on Cancel
show_preset_dialog() {
    detect_dialog
    local choice
    choice=$($DIALOG_CMD --title "Open5GS Component Selection" \
        --radiolist "Select deployment type:" 15 50 3 \
        "lte"  "LTE EPC (4G)"      ON \
        "5g"   "5G Core"            OFF \
        "all"  "All components"     OFF \
        3>&1 1>&2 2>&3) || return 1

    SELECTED_PRESET="${choice}"
    apply_preset "${SELECTED_PRESET}"
}

# Component checklist → modifies SELECTED_COMPONENTS
# Returns 0 on OK, 1 on Cancel
show_component_dialog() {
    detect_dialog

    # Build checklist items
    local items=()
    for comp in "${ALL_COMPONENTS[@]}"; do
        local state="OFF"
        for sel in "${SELECTED_COMPONENTS[@]}"; do
            if [[ "${sel}" == "${comp}" ]]; then
                state="ON"
                break
            fi
        done
        items+=("${comp}" "${COMP_DESC[${comp}]}" "${state}")
    done

    local choices
    choices=$($DIALOG_CMD --title "Select Components" \
        --checklist "Choose components to install:" 22 55 17 \
        "${items[@]}" \
        3>&1 1>&2 2>&3) || return 1

    # Parse whiptail output (space-separated, quoted)
    SELECTED_COMPONENTS=()
    for item in ${choices}; do
        # Strip quotes
        item="${item//\"/}"
        SELECTED_COMPONENTS+=("${item}")
    done

    if [[ ${#SELECTED_COMPONENTS[@]} -eq 0 ]]; then
        return 1
    fi
}

# Main dialog with Install button — loops until user installs or cancels
show_main_dialog() {
    detect_dialog

    # Start with preset selection
    show_preset_dialog || { echo "Cancelled."; exit 1; }
    show_component_dialog || { echo "Cancelled."; exit 1; }

    # Main loop: show summary with Install / Edit / Cancel
    while true; do
        local IFS=','
        local summary="Selected: ${SELECTED_COMPONENTS[*]}"
        unset IFS

        local action
        action=$($DIALOG_CMD --title "Open5GS Installer" \
            --menu "${summary}\n\nChoose action:" 14 60 3 \
            "install"  "Start installation" \
            "edit"     "Change component selection" \
            "preset"   "Change deployment preset" \
            3>&1 1>&2 2>&3) || { echo "Cancelled."; exit 1; }

        case "${action}" in
            install)
                break
                ;;
            edit)
                show_component_dialog || true  # Cancel returns to main
                ;;
            preset)
                show_preset_dialog || true     # Cancel returns to main
                show_component_dialog || true
                ;;
        esac
    done
}

apply_preset() {
    case "$1" in
        lte) SELECTED_COMPONENTS=("${PRESET_LTE[@]}") ;;
        5g)  SELECTED_COMPONENTS=("${PRESET_5G[@]}") ;;
        all) SELECTED_COMPONENTS=("${PRESET_ALL[@]}") ;;
        *)
            # Accept single component or comma-separated list (e.g. mme or mme,hss,pcrf)
            IFS=',' read -ra SELECTED_COMPONENTS <<< "$1"
            ;;
    esac
}

# ============================================================
# CLI parsing
# ============================================================
SELECTED_COMPONENTS=()
SELECTED_PRESET=""
OPT_SELECT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpm-dir)
            RPM_DIR="$2"; shift 2 ;;
        -c|--components)
            SELECTED_PRESET="$2"; shift 2 ;;
        -s|--select)
            OPT_SELECT=1; shift ;;
        -h|--help)
            echo "Usage: $0 [--rpm-dir DIR] [-c|--components lte|5g|all|comp1,comp2,...] [-s|--select]"
            echo ""
            echo "Options:"
            echo "  --rpm-dir DIR       Path to RPM directory (default: ./rpms)"
            echo "  -c, --components P  Use preset (lte, 5g, all) or comma-separated list"
            echo "                      e.g. -c mme,hss,pcrf,sgwc,sgwu,smf,upf"
            echo "  -s, --select        Open checklist dialog to customize selection"
            echo ""
            echo "No flags: interactive preset selection → component checklist"
            exit 0 ;;
        *)
            echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

# ============================================================
# Resolve component selection
# ============================================================
setup_sudo
check_rocky_linux

if [[ -n "${SELECTED_PRESET}" ]]; then
    apply_preset "${SELECTED_PRESET}"
    if [[ ${OPT_SELECT} -eq 1 ]]; then
        show_component_dialog || { echo "Cancelled."; exit 1; }
    fi
else
    # Fully interactive: preset → components → main loop with Install button
    show_main_dialog
fi

echo ""
echo "=== open5gs unified installer for Rocky Linux 8 ==="
echo ""
echo "Selected components: ${SELECTED_COMPONENTS[*]}"
echo ""

# ============================================================
# Helper: check if component is selected
# ============================================================
is_selected() {
    local comp="$1"
    for sel in "${SELECTED_COMPONENTS[@]}"; do
        [[ "${sel}" == "${comp}" ]] && return 0
    done
    return 1
}

# ============================================================
# Derive daemon list in correct start order
# ============================================================
get_ordered_daemons() {
    local order=()
    # Determine which order list to use
    if is_selected mme && is_selected amf; then
        order=("${SERVICE_ORDER_ALL[@]}")
    elif is_selected amf; then
        order=("${SERVICE_ORDER_5G[@]}")
    else
        order=("${SERVICE_ORDER_LTE[@]}")
    fi

    ORDERED_DAEMONS=()
    for daemon in "${order[@]}"; do
        # Find which component this daemon belongs to
        for comp in "${!COMP_DAEMON[@]}"; do
            if [[ "${COMP_DAEMON[${comp}]}" == "${daemon}" ]] && is_selected "${comp}"; then
                ORDERED_DAEMONS+=("${daemon}")
                break
            fi
        done
    done
}

# ============================================================
# Config helpers — copy from BUILDROOT and patch IPs
# ============================================================

# Replace build-default IPs with COMP_IP values in a file.
# Only IPs that differ between BUILD_IP and COMP_IP are touched.
patch_build_ips() {
    local file="$1"
    local comp
    for comp in "${!BUILD_IP[@]}"; do
        local from="${BUILD_IP[$comp]}"
        local to="${COMP_IP[$comp]}"
        if [[ "${from}" != "${to}" ]]; then
            sed -i "s/${from}/${to}/g" "${file}"
        fi
    done
}

# Add HOST_IP as an additional server address for external-facing interfaces.
# These are the interfaces that eNodeBs/gNBs connect to and must be reachable
# from the radio network, not just loopback.
#
# Component  Interface  Protocol  Why public
# ─────────  ─────────  ────────  ──────────────────────────
# mme        s1ap       SCTP      eNodeB S1-MME signalling
# mme        gtpc       GTP-C     S11 towards SGW-C
# sgwu       gtpu       GTP-U     S1-U user plane from eNodeB
# upf        gtpu       GTP-U     N3 user plane from gNB (5G)
# amf        ngap       SCTP      gNB N2 signalling (5G)
#
patch_public_ip() {
    local comp="$1"
    local file="$2"

    [[ -z "${HOST_IP:-}" ]] && return 0

    local loopback="${COMP_IP[$comp]:-}"
    [[ -z "${loopback}" ]] && return 0

    case "${comp}" in
        mme)
            # Add HOST_IP to s1ap and gtpc server sections
            _add_public_addr "${file}" "${loopback}" "s1ap" "${HOST_IP}"
            _add_public_addr "${file}" "${loopback}" "gtpc" "${HOST_IP}"
            ;;
        sgwu)
            # Add HOST_IP to gtpu server section
            _add_public_addr "${file}" "${loopback}" "gtpu" "${HOST_IP}"
            ;;
        upf)
            # Add HOST_IP to gtpu server section only in 5G mode.
            # In LTE mode SGW-U already binds GTP-U on the public IP;
            # UPF talks to SGW-U over loopback via PFCP/GTP-U.
            if is_selected amf; then
                _add_public_addr "${file}" "${loopback}" "gtpu" "${HOST_IP}"
            fi
            ;;
        amf)
            # Add HOST_IP to ngap server section
            _add_public_addr "${file}" "${loopback}" "ngap" "${HOST_IP}"
            ;;
    esac
}

# Insert an additional "- address: <ip>" line after the first server address
# entry within a specific interface's server block.
# Usage: _add_public_addr <file> <loopback_ip> <section_name> <public_ip>
_add_public_addr() {
    local file="$1" loopback="$2" section="$3" public_ip="$4"

    # Use python for reliable YAML-aware patching: add public_ip to the
    # server address list of the given section only (not client/metrics).
    python3 -c "
import sys, re

section = '${section}'
loopback = '${loopback}'
public_ip = '${public_ip}'

with open('${file}', 'r') as f:
    lines = f.readlines()

result = []
in_section = False
in_server = False
inserted = False

for i, line in enumerate(lines):
    stripped = line.rstrip()
    indent = len(line) - len(line.lstrip())
    result.append(line)

    if not inserted:
        # Detect entering target section (e.g. '  s1ap:')
        if re.match(r'^  ' + section + r':\s*$', line.rstrip()):
            in_section = True
            in_server = False
            continue
        # Left the section (another top-level or same-indent key)
        if in_section and indent <= 2 and stripped and not stripped.startswith('#') and not stripped.startswith('-'):
            if not stripped.startswith(section):
                in_section = False
                in_server = False
                continue
        if in_section:
            if re.match(r'^\s+server:\s*$', line):
                in_server = True
                continue
            # Detect leaving server block (client:, metrics:, or other key)
            if in_server and re.match(r'^\s+\w+:', line) and 'server' not in line:
                in_server = False
                continue
            if in_server and loopback in line and '- address:' in line:
                # Insert public IP with same indentation
                new_line = line.replace(loopback, public_ip)
                result.append(new_line)
                inserted = True

with open('${file}', 'w') as f:
    f.writelines(result)
"
}

# ============================================================
# YAML config writers
# ============================================================

write_yaml_config() {
    local comp="$1"
    local yaml_path="/etc/open5gs/${comp}.yaml"
    local build_yaml_dir="${BUILDROOT}/etc/open5gs"

    # Map component name to BUILDROOT filename (sepp uses sepp1.yaml)
    local src_name="${comp}.yaml"
    [[ "${comp}" == "sepp" ]] && src_name="sepp1.yaml"
    local src="${build_yaml_dir}/${src_name}"

    if [[ ! -f "${src}" ]]; then
        echo "ERROR: build-generated config not found: ${src}" >&2
        echo "       Run ./build.sh first to generate configs." >&2
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    cp "${src}" "${tmp}"
    patch_build_ips "${tmp}"
    patch_public_ip "${comp}" "${tmp}"
    backup_and_write "${yaml_path}" < "${tmp}"
    rm -f "${tmp}"
}

_DEAD_write_yaml_config() {
    # Legacy hand-crafted YAML generation — kept for reference only.
    local comp="$1"
    local yaml_path="/etc/open5gs/${comp}.yaml"
    local ip="${COMP_IP[${comp}]:-127.0.0.1}"

    case "${comp}" in
        mme)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/mme.log

mme:
  freeDiameter: /etc/freeDiameter/mme.conf
  s1ap:
    server:
      - address: ${ip}
  gtpc:
    server:
      - address: ${ip}
    client:
      sgwc:
        - address: ${COMP_IP[sgwc]}
      smf:
        - address: ${COMP_IP[smf]}
  gummei:
    - plmn_id:
        mcc: 315
        mnc: 010
      mme_gid: 2
      mme_code: 1
  tai:
    - plmn_id:
        mcc: 315
        mnc: 010
      tac: 1
  security:
    integrity_order: [EIA2, EIA1, EIA0]
    ciphering_order: [EEA0, EEA1, EEA2]
  network_name:
    full: Open5GS
  mme_name: open5gs-mme0
EOF
            ;;
        hss)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/hss.log

db_uri: mongodb://localhost/open5gs

hss:
  freeDiameter: /etc/freeDiameter/hss.conf
EOF
            ;;
        pcrf)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/pcrf.log

db_uri: mongodb://localhost/open5gs

pcrf:
  freeDiameter: /etc/freeDiameter/pcrf.conf
EOF
            ;;
        sgwc)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/sgwc.log

sgwc:
  gtpc:
    server:
      - address: ${ip}
  pfcp:
    server:
      - address: ${ip}
    client:
      sgwu:
        - address: ${COMP_IP[sgwu]}
EOF
            ;;
        sgwu)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/sgwu.log

sgwu:
  gtpu:
    server:
      - address: ${ip}
  pfcp:
    server:
      - address: ${ip}
    client:
      sgwc:
        - address: ${COMP_IP[sgwc]}
EOF
            ;;
        smf)
            local smf_yaml
            smf_yaml="logger:
  file:
    path: /var/log/open5gs/smf.log

smf:"
            # Include freeDiameter only when LTE components present
            if is_selected pcrf; then
                smf_yaml+="
  freeDiameter: /etc/freeDiameter/smf.conf"
            fi
            smf_yaml+="
  pfcp:
    server:
      - address: ${ip}
    client:
      upf:
        - address: ${COMP_IP[upf]}
  gtpc:
    server:
      - address: ${ip}
  gtpu:
    server:
      - address: ${ip}
  subnet:
    - addr: 10.45.0.1/16
    - addr: 2001:db8:cafe::1/48"
            # Include SBI section for 5G mode
            if is_selected nrf; then
                smf_yaml+="
  sbi:
    server:
      - address: ${ip}
        port: 7777
    client:
      scp:
        - uri: http://${COMP_IP[scp]}:7777"
            fi
            echo "${smf_yaml}" | backup_and_write "${yaml_path}"
            ;;
        upf)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/upf.log

upf:
  pfcp:
    server:
      - address: ${ip}
    client:
      smf:
        - address: ${COMP_IP[smf]}
  gtpu:
    server:
      - address: ${ip}
  subnet:
    - addr: 10.45.0.1/16
    - addr: 2001:db8:cafe::1/48
EOF
            ;;
        nrf)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/nrf.log

db_uri: mongodb://localhost/open5gs

nrf:
  sbi:
    server:
      - address: ${ip}
        port: 7777
  serving:
    - plmn_id:
        mcc: 999
        mnc: 70
EOF
            ;;
        scp)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/scp.log

scp:
  sbi:
    server:
      - address: ${ip}
        port: 7777
    client:
      nrf:
        - uri: http://${COMP_IP[nrf]}:7777
EOF
            ;;
        amf)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/amf.log

amf:
  sbi:
    server:
      - address: ${ip}
        port: 7777
    client:
      scp:
        - uri: http://${COMP_IP[scp]}:7777
  ngap:
    server:
      - address: ${ip}
  guami:
    - plmn_id:
        mcc: 999
        mnc: 70
      amf_id:
        region: 2
        set: 1
  tai:
    - plmn_id:
        mcc: 999
        mnc: 70
      tac: 1
  plmn_support:
    - plmn_id:
        mcc: 999
        mnc: 70
      s_nssai:
        - sst: 1
  security:
    integrity_order: [NIA2, NIA1, NIA0]
    ciphering_order: [NEA0, NEA1, NEA2]
  network_name:
    full: Open5GS
  amf_name: open5gs-amf0
EOF
            ;;
        ausf)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/ausf.log

ausf:
  sbi:
    server:
      - address: ${ip}
        port: 7777
    client:
      scp:
        - uri: http://${COMP_IP[scp]}:7777
EOF
            ;;
        udm)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/udm.log

udm:
  sbi:
    server:
      - address: ${ip}
        port: 7777
    client:
      scp:
        - uri: http://${COMP_IP[scp]}:7777
EOF
            ;;
        udr)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/udr.log

db_uri: mongodb://localhost/open5gs

udr:
  sbi:
    server:
      - address: ${ip}
        port: 7777
    client:
      scp:
        - uri: http://${COMP_IP[scp]}:7777
EOF
            ;;
        pcf)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/pcf.log

db_uri: mongodb://localhost/open5gs

pcf:
  sbi:
    server:
      - address: ${ip}
        port: 7777
    client:
      scp:
        - uri: http://${COMP_IP[scp]}:7777
EOF
            ;;
        nssf)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/nssf.log

nssf:
  sbi:
    server:
      - address: ${ip}
        port: 7777
    client:
      scp:
        - uri: http://${COMP_IP[scp]}:7777
      nsi:
        - uri: http://${COMP_IP[nrf]}:7777
          s_nssai:
            sst: 1
EOF
            ;;
        bsf)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/bsf.log

bsf:
  sbi:
    server:
      - address: ${ip}
        port: 7777
    client:
      scp:
        - uri: http://${COMP_IP[scp]}:7777
EOF
            ;;
        sepp)
            backup_and_write "${yaml_path}" <<EOF
logger:
  file:
    path: /var/log/open5gs/sepp.log

sepp:
  sbi:
    server:
      - address: ${ip}
        port: 7777
    client:
      scp:
        - uri: http://${COMP_IP[scp]}:7777
EOF
            ;;
        *)
            echo "WARNING: No YAML config template for component: ${comp}" >&2
            ;;
    esac
}

# ============================================================
# freeDiameter config writers
# ============================================================

write_fd_config() {
    local comp="$1"
    local fd_path="/etc/freeDiameter/${comp}.conf"
    local ip="${COMP_IP[${comp}]:-127.0.0.1}"
    local src="${BUILDROOT}/etc/freeDiameter/${comp}.conf"

    if [[ ! -f "${src}" ]]; then
        echo "ERROR: build-generated config not found: ${src}" >&2
        echo "       Run ./build.sh first to generate configs." >&2
        return 1
    fi

    $SUDO mkdir -p /etc/freeDiameter

    local tmp
    tmp=$(mktemp)
    cp "${src}" "${tmp}"
    patch_build_ips "${tmp}"

    # PCRF: also listen on host's external IP
    if [[ "${comp}" == "pcrf" && -n "${HOST_IP:-}" && "${HOST_IP}" != "${ip}" ]]; then
        sed -i "/^ListenOn = \"${ip}\";/a ListenOn = \"${HOST_IP}\";" "${tmp}"
    fi

    backup_and_write "${fd_path}" < "${tmp}"
    rm -f "${tmp}"
}

# ============================================================
# Derive firewall ports from selected components
# ============================================================
get_firewall_ports() {
    FIREWALL_PORTS=("9999/tcp" "27017/tcp")

    is_selected mme  && FIREWALL_PORTS+=("36412/sctp")
    is_selected amf  && FIREWALL_PORTS+=("38412/sctp")

    if is_selected sgwu || is_selected upf; then
        FIREWALL_PORTS+=("2152/udp")
    fi

    if is_selected mme || is_selected hss || is_selected pcrf || is_selected smf; then
        FIREWALL_PORTS+=("3868/tcp" "3868/sctp" "5868/tcp" "5868/sctp")
    fi
}

# ============================================================
# Main installation flow
# ============================================================

# Verify RPMs exist
verify_rpms common "${SELECTED_COMPONENTS[@]}"

# Core infrastructure
install_mongodb
install_system_deps

# Install RPMs
install_rpms common "${SELECTED_COMPONENTS[@]}"

# User and directories
create_open5gs_user
create_log_dir

# Create runtime directories for selected daemons
DAEMON_LIST=()
for comp in "${SELECTED_COMPONENTS[@]}"; do
    DAEMON_LIST+=("${COMP_DAEMON[${comp}]}")
done
create_run_dirs "${DAEMON_LIST[@]}"

# Generate freeDiameter certs for FD components
for comp in "${SELECTED_COMPONENTS[@]}"; do
    if [[ -n "${COMP_FD[${comp}]:-}" ]]; then
        generate_fd_certs "${comp}"
    fi
done

# Write configuration files
section "Writing configuration files"
for comp in "${SELECTED_COMPONENTS[@]}"; do
    write_yaml_config "${comp}"
    if [[ -n "${COMP_FD[${comp}]:-}" ]]; then
        write_fd_config "${comp}"
    fi
    echo "  Configured: ${comp}"
done

# TUN interface for UPF
if is_selected upf; then
    setup_tun_interface
fi

# Enable and start services in dependency order
get_ordered_daemons
enable_services "${ORDERED_DAEMONS[@]}"

# Tooling
install_dbctl
install_python_db_lib
install_webui

# Firewall
get_firewall_ports
open_firewall_ports "${FIREWALL_PORTS[@]}"

# ============================================================
# Summary
# ============================================================
echo ""
echo "================================================================"
echo "  open5gs installation complete"
echo "================================================================"
echo ""
echo "  Installed components: ${SELECTED_COMPONENTS[*]}"
echo ""
echo "  Services:"
echo "    MongoDB:    systemctl status mongod"
for daemon in "${ORDERED_DAEMONS[@]}"; do
    printf "    %-12s systemctl status open5gs-%s\n" "${daemon}:" "${daemon}"
done
echo "    WebUI:      systemctl status open5gs-webui"
echo ""
echo "  Configuration:"
echo "    YAML:       /etc/open5gs/*.yaml"
if [[ ${#COMP_FD[@]} -gt 0 ]]; then
    echo "    Diameter:   /etc/freeDiameter/*.conf"
fi
echo ""
echo "  DB tools:"
echo "    CLI:        open5gs-dbctl help"
echo "    Python:     /usr/local/share/open5gs/python/Open5GS.py"
echo ""
echo "  WebUI:        http://$(hostname -I | awk '{print $1}'):9999  (admin / admin)"
echo ""
echo "  Quick test — add a subscriber:"
echo "    open5gs-dbctl add 999700000000001 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA"
echo ""
echo "================================================================"
