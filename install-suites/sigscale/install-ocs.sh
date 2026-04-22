#!/bin/bash
# Install SigScale OCS from build artifacts onto Rocky Linux 8 or 9
# Usage: install-ocs.sh [OPTIONS] [OUTPUT_DIR]
# Run as root on the target system
set -euo pipefail

# Configurable ports (override via env or CLI flags)
OCS_PORT_WEB="${OCS_PORT_WEB:-8080}"
OCS_PORT_ACCT="${OCS_PORT_ACCT:-3868}"
OCS_PORT_AUTH="${OCS_PORT_AUTH:-3869}"
OCS_PORT_RADIUS_AUTH="${OCS_PORT_RADIUS_AUTH:-1812}"
OCS_PORT_RADIUS_ACCT="${OCS_PORT_RADIUS_ACCT:-1813}"

# DIAMETER identity (CER Origin-Host / Origin-Realm)
OCS_ORIGIN_HOST="${OCS_ORIGIN_HOST:-sigscale}"
OCS_ORIGIN_REALM="${OCS_ORIGIN_REALM:-ocs.localdomain}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [OUTPUT_DIR]

Options:
  --port-web PORT           Web UI port (default: 8080)
  --port-acct PORT          DIAMETER Accounting port (default: 3868)
  --port-auth PORT          DIAMETER Auth port (default: 3869)
  --port-radius-auth PORT   RADIUS Auth port (default: 1812)
  --port-radius-acct PORT   RADIUS Accounting port (default: 1813)
  --origin-host HOST        DIAMETER Origin-Host (default: sigscale)
  --origin-realm REALM      DIAMETER Origin-Realm (default: ocs.localdomain)
  -h, --help                Show this help

Environment variables OCS_PORT_WEB, OCS_PORT_ACCT, OCS_PORT_AUTH,
OCS_PORT_RADIUS_AUTH, OCS_PORT_RADIUS_ACCT, OCS_ORIGIN_HOST,
OCS_ORIGIN_REALM can also be used.
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port-web)          OCS_PORT_WEB="$2"; shift 2 ;;
        --port-acct)         OCS_PORT_ACCT="$2"; shift 2 ;;
        --port-auth)         OCS_PORT_AUTH="$2"; shift 2 ;;
        --port-radius-auth)  OCS_PORT_RADIUS_AUTH="$2"; shift 2 ;;
        --port-radius-acct)  OCS_PORT_RADIUS_ACCT="$2"; shift 2 ;;
        --origin-host)       OCS_ORIGIN_HOST="$2"; shift 2 ;;
        --origin-realm)      OCS_ORIGIN_REALM="$2"; shift 2 ;;
        -h|--help)           usage ;;
        -*)                  echo "Unknown option: $1"; usage ;;
        *)                   break ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

OUTPUT_DIR="${1:-output}"; shift 2>/dev/null || true
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "ERROR: Output directory '$OUTPUT_DIR' not found."
    echo "Usage: $0 [OUTPUT_DIR]"
    exit 1
fi

OTP_HOME=/home/otp
ERLANG_ROOT_DIR=$(erl -noinput -eval 'io:format("~s", [code:root_dir()]), init:stop().')
ERLANG_LIB_DIR="${ERLANG_ROOT_DIR}/lib"

# Detect OCS version from release tarball
OCS_TARBALL=$(ls "${OUTPUT_DIR}"/ocs-*.tar.gz 2>/dev/null | head -1)
if [ -z "$OCS_TARBALL" ]; then
    echo "ERROR: No ocs-*.tar.gz found in ${OUTPUT_DIR}/"
    exit 1
fi
OCS_VSN=$(basename "$OCS_TARBALL" .tar.gz)
echo "=== Installing ${OCS_VSN} ==="

# Step 1: Copy release tarball
echo "--- Copying release tarball ---"
cp "${OCS_TARBALL}" ${OTP_HOME}/releases/
chown otp:otp ${OTP_HOME}/releases/$(basename "$OCS_TARBALL")

# Step 2: Install OCS application to Erlang lib dir
echo "--- Installing OCS application ---"
if [ -d "${OUTPUT_DIR}/install_lib/${OCS_VSN}" ]; then
    cp -r "${OUTPUT_DIR}/install_lib/${OCS_VSN}" "${ERLANG_LIB_DIR}/${OCS_VSN}"
fi

# Install dependency libraries (radierl, sigscale_mibs, mochiweb)
for dep_dir in "${OUTPUT_DIR}"/install_lib/*/; do
    dep_name=$(basename "$dep_dir")
    if [ "$dep_name" != "${OCS_VSN}" ] && [ ! -d "${ERLANG_LIB_DIR}/${dep_name}" ]; then
        echo "  Installing dependency: ${dep_name}"
        cp -r "$dep_dir" "${ERLANG_LIB_DIR}/${dep_name}"
    fi
done

# Step 3: Install sys.config (will be patched after release install)
echo "--- Installing sys.config ---"
RELEASE_DIR=${OTP_HOME}/releases/${OCS_VSN}
mkdir -p "${RELEASE_DIR}"
cp "${OUTPUT_DIR}/sys.config" "${RELEASE_DIR}/sys.config"

# Step 4: Install ocs.rel
cp "${OUTPUT_DIR}/ocs.rel" "${RELEASE_DIR}/${OCS_VSN}.rel"

# Step 5: Install environment file
echo "--- Installing environment file ---"
if [ -f "${OUTPUT_DIR}/scripts/ocs.env" ]; then
    cp "${OUTPUT_DIR}/scripts/ocs.env" /etc/default/ocs
else
    cat > /etc/default/ocs << ENVEOF
NODENAME=ocs
ROOTDIR=${ERLANG_ROOT_DIR}
RELDIR=${OTP_HOME}/releases
START_ERL_DATA=releases/start_erl.data
RUN_ERL_LOG_MAXSIZE=1000000
RUN_ERL_LOG_GENERATIONS=100
RUN_ERL_LOG_ALIVE_IN_UTC=1
TERM=vt100
ENVEOF
fi
# Ensure RELDIR points to /home/otp/releases
sed -i "s|^RELDIR=.*|RELDIR=${OTP_HOME}/releases|" /etc/default/ocs
sed -i "s|^ROOTDIR=.*|ROOTDIR=${ERLANG_ROOT_DIR}|" /etc/default/ocs

# Step 6: Install systemd service
echo "--- Installing systemd service ---"
cat > /etc/systemd/system/ocs.service << 'SVCEOF'
[Unit]
Description=SigScale OCS
Documentation=https://github.com/sigscale/ocs
After=epmd.service epmd.socket

[Service]
User=otp
Group=otp
WorkingDirectory=/home/otp
RuntimeDirectory=ocs
RuntimeDirectoryMode=0750
EnvironmentFile=/etc/default/ocs
ExecStart=/bin/bash -c 'ERL_LIBS=lib exec ${ROOTDIR}/bin/start_erl ${ROOTDIR} ${RELDIR} ${START_ERL_DATA} -boot_var OTPHOME . +K true +A 32 +Bi -sname ${NODENAME} -noinput'
Type=simple
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF
if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null 2>&1; then
    systemctl daemon-reload
else
    echo "systemd not available — skipping daemon-reload"
fi

# Fix ownership before helper scripts run as otp user
chown -R otp:otp ${OTP_HOME}

# Step 7: Install helper scripts
echo "--- Installing helper scripts ---"
SCRIPT_DIR=${OTP_HOME}/bin
cp "${OUTPUT_DIR}/scripts/install_tables.escript" "${SCRIPT_DIR}/"
cp "${OUTPUT_DIR}/scripts/install_snmp.sh" "${SCRIPT_DIR}/"
cp "${OUTPUT_DIR}/scripts/install_certs.sh" "${SCRIPT_DIR}/"
cp "${OUTPUT_DIR}/scripts/install_release.sh" "${SCRIPT_DIR}/"
chmod +x "${SCRIPT_DIR}"/*

# Step 8: Generate TLS certificates (if not existing)
echo "--- TLS certificates ---"
su - otp -c "bash ${SCRIPT_DIR}/install_certs.sh"

# Step 9: Initialize SNMP (if not existing)
echo "--- SNMP configuration ---"
su - otp -c "bash ${SCRIPT_DIR}/install_snmp.sh"

# Step 10: Run release install script
echo "--- Installing OCS release ---"
su - otp -c "bash ${SCRIPT_DIR}/install_release.sh ${OCS_VSN}"

# Step 10b: Patch sys.config (after release install which may overwrite it)
echo "--- Patching ports and DIAMETER config ---"
DIAM_IDENT="{'Origin-Host', \"${OCS_ORIGIN_HOST}\"}, {'Origin-Realm', \"${OCS_ORIGIN_REALM}\"}"
awk -v acct="${OCS_PORT_ACCT}" -v auth="${OCS_PORT_AUTH}" \
    -v racct="${OCS_PORT_RADIUS_ACCT}" -v rauth="${OCS_PORT_RADIUS_AUTH}" \
    -v web="${OCS_PORT_WEB}" -v ident="${DIAM_IDENT}" '
    /{radius,/  { in_radius=1 }
    /{diameter,/ { in_radius=0; in_diameter=1 }
    /acct_log_rotate/ { in_diameter=0 }
    in_radius && /{auth,/ { next_is="radius_auth" }
    in_radius && /{acct,/ { next_is="radius_acct" }
    in_diameter && /{acct,/ { next_is="diameter_acct" }
    in_diameter && /{auth,/ { next_is="diameter_auth" }
    next_is == "radius_auth" && /{0,0,0,0}/ {
        gsub(/{0,0,0,0}, [0-9]+/, "{0,0,0,0}, " rauth); next_is="" }
    next_is == "radius_acct" && /{0,0,0,0}/ {
        gsub(/{0,0,0,0}, [0-9]+/, "{0,0,0,0}, " racct); next_is="" }
    next_is == "diameter_acct" && /{0,0,0,0}/ {
        gsub(/{0,0,0,0}, [0-9]+, \[\]/, "{0,0,0,0}, " acct ", [{transport_module, diameter_sctp}, " ident "]"); next_is="" }
    next_is == "diameter_auth" && /{0,0,0,0}/ {
        gsub(/{0,0,0,0}, [0-9]+, \[\]/, "{0,0,0,0}, " auth ", [{transport_module, diameter_sctp}, " ident "]"); next_is="" }
    /{port, [0-9]+}/ { gsub(/{port, [0-9]+}/, "{port, " web "}") }
    { print }
' "${RELEASE_DIR}/sys.config" > "${RELEASE_DIR}/sys.config.tmp" \
    && mv "${RELEASE_DIR}/sys.config.tmp" "${RELEASE_DIR}/sys.config"

# Add os_mon memory watermark if not already present
if ! grep -q 'system_memory_high_watermark' "${RELEASE_DIR}/sys.config"; then
    sed -i 's|{snmp,|{os_mon,\n      [{system_memory_high_watermark, 0.95}]},\n{snmp,|' \
        "${RELEASE_DIR}/sys.config"
fi

# Step 11: Initialize database (if first install)
if [ ! -d "${OTP_HOME}/db/Mnesia.ocs@$(hostname -s)" ]; then
    echo "--- Initializing Mnesia database ---"
    su - otp -c "cd ${OTP_HOME} && ERL_LIBS=lib erl -noinput -sname ocs \
        -config releases/${OCS_VSN}/sys \
        -eval 'mnesia:create_schema([node()]), mnesia:start()' \
        -s ocs_app install \
        -s init stop"
else
    echo "--- Mnesia database already exists, skipping init ---"
fi

# Step 12: Set permissions
echo "--- Setting permissions ---"
chown -R otp:otp ${OTP_HOME}

# Step 13: Enable and start service
if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null 2>&1; then
    echo "--- Enabling and starting OCS service ---"
    systemctl enable ocs.service
    systemctl start ocs.service
    echo ""
    systemctl status ocs.service --no-pager || true
else
    echo "--- systemd not available — skipping service enable/start ---"
    echo "    To start manually: su - otp -c 'cd /home/otp && ERL_LIBS=lib /usr/lib64/erlang/bin/run_erl -daemon /tmp/ log \"exec /usr/lib64/erlang/bin/start_erl /usr/lib64/erlang /home/otp/releases releases/start_erl.data -boot_var OTPHOME . +K true +A 32 +Bi -sname ocs\"'"
fi

echo ""
echo "=== OCS ${OCS_VSN} installed successfully ==="
echo "Web UI:        http://$(hostname):${OCS_PORT_WEB}  (default: admin/admin)"
echo "DIAMETER Acct: $(hostname):${OCS_PORT_ACCT}"
echo "DIAMETER Auth: $(hostname):${OCS_PORT_AUTH}"
echo "RADIUS Auth:   $(hostname):${OCS_PORT_RADIUS_AUTH}"
echo "RADIUS Acct:   $(hostname):${OCS_PORT_RADIUS_ACCT}"
echo "DIAMETER ID:   ${OCS_ORIGIN_HOST}@${OCS_ORIGIN_REALM}"
