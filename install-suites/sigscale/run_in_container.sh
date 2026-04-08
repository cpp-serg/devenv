#!/bin/bash
# Build and test OCS installation in a Rocky Linux 8.10 container
# Mounts local directories for persistent DB, logs, SSL certs, and configs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults
CONTAINER_NAME="ocs-test"
IMAGE="quay.io/rockylinux/rockylinux:8.10"
DATA_DIR="${SCRIPT_DIR}/data"
PORT_WEB=8080
PORT_ACCT=3868
PORT_AUTH=3869
PORT_RADIUS_AUTH=1812
PORT_RADIUS_ACCT=1813
REBUILD=false
SKIP_INSTALL=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run SigScale OCS in a Rocky Linux 8.10 container with persistent storage.

Options:
  --name NAME              Container name (default: ocs-test)
  --image IMAGE            Base image (default: quay.io/rockylinux/rockylinux:8.10)
  --data-dir PATH          Persistent data directory (default: ./data)
  --port-web PORT          Web UI port (default: 8080)
  --port-acct PORT         DIAMETER Accounting port (default: 3868)
  --port-auth PORT         DIAMETER Auth port (default: 3869)
  --port-radius-auth PORT  RADIUS Auth port (default: 1812)
  --port-radius-acct PORT  RADIUS Accounting port (default: 1813)
  --rebuild                Remove and recreate container from scratch
  --skip-install           Skip prereqs/OCS install (use with existing container)
  -h, --help               Show this help

Persistent data layout (under --data-dir):
  config/  — sys.config, ocs.env (editable on host, applied on start)
  db/      — Mnesia database
  log/     — Erlang logs
  ssl/     — TLS certificates
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)          CONTAINER_NAME="$2"; shift 2 ;;
        --image)         IMAGE="$2"; shift 2 ;;
        --data-dir)      DATA_DIR="$2"; shift 2 ;;
        --port-web)          PORT_WEB="$2"; shift 2 ;;
        --port-acct)         PORT_ACCT="$2"; shift 2 ;;
        --port-auth)         PORT_AUTH="$2"; shift 2 ;;
        --port-radius-auth)  PORT_RADIUS_AUTH="$2"; shift 2 ;;
        --port-radius-acct)  PORT_RADIUS_ACCT="$2"; shift 2 ;;
        --rebuild)           REBUILD=true; shift ;;
        --skip-install)      SKIP_INSTALL=true; shift ;;
        -h|--help)           usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Create persistent storage directories
CONFIG_DIR="${DATA_DIR}/config"
DB_DIR="${DATA_DIR}/db"
LOG_DIR="${DATA_DIR}/log"
SSL_DIR="${DATA_DIR}/ssl"
mkdir -p "${CONFIG_DIR}" "${DB_DIR}" "${LOG_DIR}" "${SSL_DIR}"

# Remove existing container if --rebuild
if [ "$REBUILD" = true ]; then
    echo "=== Removing existing container ${CONTAINER_NAME} ==="
    podman rm -f "${CONTAINER_NAME}" 2>/dev/null || true
fi

# Create container if it doesn't exist
if ! podman ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    echo "=== Creating container ${CONTAINER_NAME} ==="
    podman run -d --name "${CONTAINER_NAME}" \
        -v "${CONFIG_DIR}:/home/otp/config:Z" \
        -v "${DB_DIR}:/home/otp/db:Z" \
        -v "${LOG_DIR}:/home/otp/log:Z" \
        -v "${SSL_DIR}:/home/otp/ssl:Z" \
        -p "${PORT_WEB}:${PORT_WEB}" \
        -p "${PORT_ACCT}:${PORT_ACCT}" \
        -p "${PORT_AUTH}:${PORT_AUTH}" \
        -p "${PORT_RADIUS_AUTH}:${PORT_RADIUS_AUTH}/udp" \
        -p "${PORT_RADIUS_ACCT}:${PORT_RADIUS_ACCT}/udp" \
        "${IMAGE}" sleep infinity
else
    echo "=== Starting container ${CONTAINER_NAME} ==="
    podman start "${CONTAINER_NAME}" 2>/dev/null || true
fi

if [ "$SKIP_INSTALL" = false ]; then
    # Copy scripts and artifacts into container
    echo "=== Copying files into container ==="
    podman cp "${SCRIPT_DIR}/install-prereqs.sh" "${CONTAINER_NAME}:/root/"
    podman cp "${SCRIPT_DIR}/install-ocs.sh" "${CONTAINER_NAME}:/root/"
    podman cp "${SCRIPT_DIR}/output" "${CONTAINER_NAME}:/root/output"

    # Run install-prereqs.sh
    echo ""
    echo "=== Running install-prereqs.sh ==="
    podman exec "${CONTAINER_NAME}" bash /root/install-prereqs.sh

    # Run install-ocs.sh
    echo ""
    echo "=== Running install-ocs.sh ==="
    podman exec "${CONTAINER_NAME}" bash /root/install-ocs.sh \
        --port-web "${PORT_WEB}" \
        --port-acct "${PORT_ACCT}" \
        --port-auth "${PORT_AUTH}" \
        --port-radius-auth "${PORT_RADIUS_AUTH}" \
        --port-radius-acct "${PORT_RADIUS_ACCT}" \
        /root/output

    # Export configs to mounted volume (if not already present from a previous run)
    echo ""
    echo "=== Exporting configs to ${CONFIG_DIR}/ ==="
    OCS_VSN=$(podman exec "${CONTAINER_NAME}" bash -c 'basename /home/otp/releases/ocs-*/sys.config | head -1' 2>/dev/null || true)
    OCS_VSN_DIR=$(podman exec "${CONTAINER_NAME}" bash -c 'ls -d /home/otp/releases/ocs-*/ 2>/dev/null | head -1')

    if [ ! -f "${CONFIG_DIR}/sys.config" ]; then
        podman cp "${CONTAINER_NAME}:${OCS_VSN_DIR}sys.config" "${CONFIG_DIR}/sys.config"
        echo "  Exported sys.config"
    else
        echo "  sys.config already exists on host — using existing"
    fi
    if [ ! -f "${CONFIG_DIR}/ocs.env" ]; then
        podman cp "${CONTAINER_NAME}:/etc/default/ocs" "${CONFIG_DIR}/ocs.env"
        echo "  Exported ocs.env"
    else
        echo "  ocs.env already exists on host — using existing"
    fi

    # Fix ownership on mounted volumes
    podman exec "${CONTAINER_NAME}" chown -R otp:otp /home/otp/db /home/otp/log /home/otp/ssl /home/otp/config
fi

# Apply configs from mounted volume before starting
echo ""
echo "=== Applying configs from ${CONFIG_DIR}/ ==="
OCS_VSN_DIR=$(podman exec "${CONTAINER_NAME}" bash -c 'ls -d /home/otp/releases/ocs-*/ 2>/dev/null | head -1')

if [ -f "${CONFIG_DIR}/sys.config" ]; then
    podman cp "${CONFIG_DIR}/sys.config" "${CONTAINER_NAME}:${OCS_VSN_DIR}sys.config"
    podman exec "${CONTAINER_NAME}" chown otp:otp "${OCS_VSN_DIR}sys.config"
    echo "  Applied sys.config"
fi
if [ -f "${CONFIG_DIR}/ocs.env" ]; then
    podman cp "${CONFIG_DIR}/ocs.env" "${CONTAINER_NAME}:/etc/default/ocs"
    echo "  Applied ocs.env"
fi

# Start OCS manually (no systemd in container)
echo ""
echo "=== Starting OCS ==="
ERLANG_ROOT=$(podman exec "${CONTAINER_NAME}" erl -noinput -eval 'io:format("~s", [code:root_dir()]), init:stop().')
podman exec "${CONTAINER_NAME}" su - otp -c \
    "cd /home/otp && ERL_LIBS=lib ${ERLANG_ROOT}/bin/run_erl -daemon /tmp/ /home/otp/log \
    \"exec ${ERLANG_ROOT}/bin/start_erl ${ERLANG_ROOT} /home/otp/releases releases/start_erl.data \
    -boot_var OTPHOME . +K true +A 32 +Bi -sname ocs\""

# Wait for OCS to start
echo "Waiting for OCS to start..."
for i in $(seq 1 15); do
    if podman exec "${CONTAINER_NAME}" bash -c "echo > /dev/tcp/localhost/${PORT_WEB}" 2>/dev/null; then
        echo "OCS is up!"
        break
    fi
    if [ "$i" -eq 15 ]; then
        echo "ERROR: OCS failed to start within 15 seconds"
        echo "=== Log output ==="
        podman exec "${CONTAINER_NAME}" su - otp -c 'cat /home/otp/log/erlang.log.1' 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# Verify ports
echo ""
echo "=== Verification ==="
HOST_IP=$(hostname -I | awk '{print $1}')

for port_name in "Web UI:${PORT_WEB}:tcp" "DIAMETER Acct:${PORT_ACCT}:sctp" "DIAMETER Auth:${PORT_AUTH}:sctp"; do
    IFS=: read -r name port proto <<< "$port_name"
    if [ "$proto" = "sctp" ]; then
        if podman exec "${CONTAINER_NAME}" bash -c "grep -q ' ${port} ' /proc/net/sctp/eps 2>/dev/null"; then
            echo "  ${name} (port ${port}/sctp): LISTENING"
        else
            echo "  ${name} (port ${port}/sctp): NOT LISTENING"
        fi
    else
        if podman exec "${CONTAINER_NAME}" bash -c "echo > /dev/tcp/localhost/${port}" 2>/dev/null; then
            echo "  ${name} (port ${port}): LISTENING"
        else
            echo "  ${name} (port ${port}): NOT LISTENING"
        fi
    fi
done

# Test web UI
HTTP_CODE=$(podman exec "${CONTAINER_NAME}" bash -c "curl -s -o /dev/null -w '%{http_code}' -u admin:admin http://localhost:${PORT_WEB}/" 2>/dev/null || echo "000")
echo "  Web UI auth test: HTTP ${HTTP_CODE}"

echo ""
echo "=== OCS running in container ${CONTAINER_NAME} ==="
echo "Web UI:        http://${HOST_IP}:${PORT_WEB}  (admin/admin)"
echo "DIAMETER Acct: ${HOST_IP}:${PORT_ACCT}"
echo "DIAMETER Auth: ${HOST_IP}:${PORT_AUTH}"
echo "RADIUS Auth:   ${HOST_IP}:${PORT_RADIUS_AUTH}"
echo "RADIUS Acct:   ${HOST_IP}:${PORT_RADIUS_ACCT}"
echo ""
echo "Persistent data: ${DATA_DIR}/"
echo "  config/ — sys.config, ocs.env (edit on host, restart to apply)"
echo "  db/     — Mnesia database"
echo "  log/    — Erlang logs"
echo "  ssl/    — TLS certificates"
echo ""
echo "Commands:"
echo "  Erlang shell:  podman exec -it ${CONTAINER_NAME} su - otp -c '${ERLANG_ROOT}/bin/to_erl /tmp/'"
echo "  Restart OCS:   $0 --skip-install --name ${CONTAINER_NAME}"
echo "  Full rebuild:  $0 --rebuild --name ${CONTAINER_NAME}"
echo "  Stop:          podman stop ${CONTAINER_NAME}"
