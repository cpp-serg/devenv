#!/usr/bin/env bash
# install-pcrf.sh — Install & configure open5gs PCRF standalone on Rocky Linux 8
#
# Installs: MongoDB 7.0, open5gs PCRF + common RPMs, WebUI, db tools, Python lib
#
# Usage:
#   ./install-pcrf.sh [--rpm-dir /path/to/rpms]
#
# Works both as root and as a regular user (sudo used only when needed).
#
set -euo pipefail

# ============================================================
# Configuration — edit these if needed
# ============================================================
MONGODB_VERSION="7.0"
NODEJS_VERSION="18"
OPEN5GS_VERSION="2.7.7"
OPEN5GS_REPO="https://github.com/open5gs/open5gs.git"

# Where the built RPMs live (default: ./rpms/)
RPM_DIR="$(cd "$(dirname "$0")" && pwd)/rpms"

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpm-dir) RPM_DIR="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# ============================================================
# Preflight
# ============================================================
# Use sudo only when not already root
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    if ! sudo -v; then
        echo "ERROR: Cannot obtain sudo privileges." >&2
        exit 1
    fi
    SUDO="sudo"
fi

if ! grep -q 'Rocky Linux release 8' /etc/redhat-release 2>/dev/null; then
    echo "WARNING: This script targets Rocky Linux 8.x. Detected:"
    cat /etc/redhat-release 2>/dev/null || echo "(unknown)"
    echo "Continuing anyway..."
fi

PCRF_RPM=$(ls "${RPM_DIR}"/open5gs-pcrf-*.el8.*.rpm 2>/dev/null | head -1)
COMMON_RPM=$(ls "${RPM_DIR}"/open5gs-common-*.el8.*.rpm 2>/dev/null | head -1)
if [[ -z "${PCRF_RPM}" || -z "${COMMON_RPM}" ]]; then
    echo "ERROR: Cannot find open5gs-pcrf and open5gs-common RPMs in ${RPM_DIR}/" >&2
    echo "       Build them first with:  ./build.sh" >&2
    exit 1
fi

echo "=== open5gs PCRF standalone installer for Rocky Linux 8 ==="
echo ""

# ============================================================
# 1. MongoDB 7.0
# ============================================================
section() { echo ""; echo ">>> $1"; echo ""; }

section "1/6 — Installing MongoDB ${MONGODB_VERSION}"

if ! command -v mongod &>/dev/null; then
    $SUDO tee /etc/yum.repos.d/mongodb-org-${MONGODB_VERSION}.repo >/dev/null <<EOF
[mongodb-org-${MONGODB_VERSION}]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/${MONGODB_VERSION}/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-${MONGODB_VERSION}.asc
EOF

    $SUDO dnf -y install mongodb-org
    echo "MongoDB installed."
else
    echo "MongoDB already installed, skipping."
fi

# Bind MongoDB to all interfaces for external access
if grep -q 'bindIp: 127.0.0.1' /etc/mongod.conf 2>/dev/null; then
    $SUDO sed -i 's/^  bindIp: 127.0.0.1/  bindIp: 0.0.0.0/' /etc/mongod.conf
fi

# Enable and start mongod
$SUDO systemctl enable mongod
$SUDO systemctl start mongod || $SUDO systemctl restart mongod
echo "MongoDB is running."

# Wait for mongod to be ready
for i in $(seq 1 10); do
    if mongosh --quiet --eval "db.runCommand({ping:1})" &>/dev/null; then
        break
    fi
    echo "  Waiting for MongoDB to be ready... ($i)"
    sleep 1
done

# ============================================================
# 2. open5gs PCRF RPMs
# ============================================================
section "2/6 — Installing open5gs PCRF RPMs"

# Install runtime deps that the RPMs need
$SUDO dnf -y install epel-release
$SUDO dnf -y install lksctp-tools gnutls libgcrypt openssl-libs libidn \
    mongo-c-driver libyaml libnghttp2 libmicrohttpd libcurl libtalloc \
    logrotate kernel-modules-extra-"$(uname -r)"

# Load SCTP kernel module (required by freeDiameter)
if ! lsmod | grep -q '^sctp '; then
    $SUDO modprobe sctp
fi

# Install the RPMs (common + pcrf)
# --noscripts: the RPM %systemd_pre macro is undefined on this host, causing
# the prein scriptlet to fail (%systemd_pre is parsed as shell `%` = `fg`).
# We handle systemd enable/start manually in section 3 below.
$SUDO rpm -Uvh --force --noscripts "${COMMON_RPM}" "${PCRF_RPM}"

echo "open5gs-common and open5gs-pcrf installed."

# ============================================================
# 3. Configure PCRF
# ============================================================
section "3/6 — Configuring PCRF"

# Ensure the open5gs user exists
getent group open5gs >/dev/null || $SUDO groupadd -r open5gs
getent passwd open5gs >/dev/null || \
    $SUDO useradd -r -g open5gs -d /run/open5gs -s /sbin/nologin -c "Open5GS daemon" open5gs

# Log directory
$SUDO install -d -m 0750 -o open5gs -g open5gs /var/log/open5gs

# Runtime directory
$SUDO install -d -m 0755 -o open5gs -g open5gs /run/open5gs-pcrfd

# Backup existing config if present, write a clean one
PCRF_YAML="/etc/open5gs/pcrf.yaml"
if [[ -f "${PCRF_YAML}" ]]; then
    $SUDO cp -n "${PCRF_YAML}" "${PCRF_YAML}.bak"
fi

$SUDO mkdir -p "$(dirname "${PCRF_YAML}")"
$SUDO tee "${PCRF_YAML}" >/dev/null <<'PCRF_EOF'
logger:
  file:
    path: /var/log/open5gs/pcrf.log

db_uri: mongodb://localhost/open5gs

pcrf:
  freeDiameter: /etc/freeDiameter/pcrf.conf
PCRF_EOF

# freeDiameter config for PCRF (Gx server, Rx server)
PCRF_FD_CONF="/etc/freeDiameter/pcrf.conf"
if [[ -f "${PCRF_FD_CONF}" ]]; then
    $SUDO cp -n "${PCRF_FD_CONF}" "${PCRF_FD_CONF}.bak"
fi

$SUDO mkdir -p "$(dirname "${PCRF_FD_CONF}")"

# Generate self-signed TLS certs if missing (freeDiameter requires them even with No_TLS)
if [[ ! -f /etc/freeDiameter/pcrf.cert.pem || ! -f /etc/freeDiameter/pcrf.key.pem ]]; then
    $SUDO openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -subj "/CN=pcrf.localdomain" \
        -keyout /etc/freeDiameter/pcrf.key.pem \
        -out /etc/freeDiameter/pcrf.cert.pem \
        2>/dev/null
    $SUDO chown open5gs:open5gs /etc/freeDiameter/pcrf.key.pem /etc/freeDiameter/pcrf.cert.pem
    $SUDO chmod 640 /etc/freeDiameter/pcrf.key.pem
    echo "Generated self-signed TLS certs for freeDiameter."
fi

$SUDO tee "${PCRF_FD_CONF}" >/dev/null <<'FD_EOF'
# freeDiameter configuration for open5gs PCRF
#
# This identity must match what peers use to connect.
# Adjust for your deployment.
Identity = "pcrf.localdomain";
Realm = "localdomain";
Port = 3868;
SecPort = 5868;

# TLS — self-signed certs for local/dev use.
TLS_Cred = "/etc/freeDiameter/pcrf.cert.pem", "/etc/freeDiameter/pcrf.key.pem";
TLS_CA = "/etc/freeDiameter/pcrf.cert.pem";

# Gx peer: the SMF/PGW-C connects here
# Uncomment and adjust when integrating with an SMF:
# ConnectPeer = "smf.localdomain" { ConnectTo = "127.0.0.4"; Port = 3868; No_TLS; };

# Load required Diameter dictionaries
LoadExtension = "dbg_msg_dumps.fdx" : "0x8888";
LoadExtension = "dict_rfc5777.fdx";
LoadExtension = "dict_mip6i.fdx";
LoadExtension = "dict_nasreq.fdx";
LoadExtension = "dict_nas_mipv6.fdx";
LoadExtension = "dict_dcca.fdx";
LoadExtension = "dict_dcca_3gpp.fdx";
FD_EOF

echo "PCRF configuration written to ${PCRF_YAML} and ${PCRF_FD_CONF}"

# Enable and start PCRF
$SUDO systemctl daemon-reload
$SUDO systemctl enable open5gs-pcrfd
$SUDO systemctl start open5gs-pcrfd || true
echo "PCRF service enabled."

# ============================================================
# 4. DB tools (open5gs-dbctl)
# ============================================================
section "4/6 — Installing open5gs-dbctl"

TOOLS_DIR="/usr/local/share/open5gs"
$SUDO install -d "${TOOLS_DIR}"

# Download open5gs-dbctl from the matching release
$SUDO curl -fsSL "https://raw.githubusercontent.com/open5gs/open5gs/v${OPEN5GS_VERSION}/misc/db/open5gs-dbctl" \
    -o "${TOOLS_DIR}/open5gs-dbctl"
$SUDO chmod +x "${TOOLS_DIR}/open5gs-dbctl"

# Symlink into PATH
$SUDO ln -sf "${TOOLS_DIR}/open5gs-dbctl" /usr/local/bin/open5gs-dbctl

echo "open5gs-dbctl installed → /usr/local/bin/open5gs-dbctl"
echo "  Usage: open5gs-dbctl add <imsi> <key> <opc>"

# ============================================================
# 5. Python DB library
# ============================================================
section "5/6 — Installing Python DB library"

PYTHON_DIR="${TOOLS_DIR}/python"
$SUDO install -d "${PYTHON_DIR}"

$SUDO curl -fsSL "https://raw.githubusercontent.com/open5gs/open5gs/v${OPEN5GS_VERSION}/misc/db/python/Open5GS.py" \
    -o "${PYTHON_DIR}/Open5GS.py"

# Install pymongo dependency
$SUDO pip3 install pymongo 2>/dev/null || $SUDO python3 -m pip install pymongo

echo "Open5GS.py installed → ${PYTHON_DIR}/Open5GS.py"

# Write an example script
$SUDO tee "${PYTHON_DIR}/example_add_subscriber.py" >/dev/null <<'PYEOF'
#!/usr/bin/env python3
"""
Example: Add a subscriber with PCC rules to open5gs MongoDB.

Usage:
    python3 example_add_subscriber.py

Adjust the subscriber data below for your deployment.
"""
import sys
sys.path.insert(0, "/usr/local/share/open5gs/python")
from Open5GS import Open5GS

db = Open5GS("localhost", 27017)

subscriber = {
    "schema_version": 1,
    "imsi": "999700000000001",
    "msisdn": ["0900000001"],
    "security": {
        "k":   "465B5CE8B199B49FAA5F0A2EE238A6BC",
        "opc": "E8ED289DEBA952E4283B54E88E6183CA",
        "op":  None,
        "amf": "8000",
    },
    "ambr": {
        "downlink": {"value": 1000000000, "unit": 0},  # 1 Gbps
        "uplink":   {"value": 1000000000, "unit": 0},
    },
    "slice": [{
        "sst": 1,
        "default_indicator": True,
        "session": [{
            "name": "internet",
            "type": 3,  # IPv4v6
            "qos": {
                "index": 9,  # QCI 9 (default bearer)
                "arp": {
                    "priority_level": 8,
                    "pre_emption_capability": 1,
                    "pre_emption_vulnerability": 2,
                },
            },
            "ambr": {
                "downlink": {"value": 1, "unit": 3},  # 1 Gbps
                "uplink":   {"value": 1, "unit": 3},
            },
            # --- PCC rules (PCRF reads these and sends via Gx) ---
            "pcc_rule": [{
                "flow": [
                    {"direction": 1,  # uplink
                     "description": "permit out ip from any to 10.45.0.0/16"},
                    {"direction": 2,  # downlink
                     "description": "permit out ip from 10.45.0.0/16 to any"},
                ],
                "qos": {
                    "index": 5,  # QCI 5 (dedicated bearer, e.g. IMS signaling)
                    "arp": {
                        "priority_level": 3,
                        "pre_emption_capability": 1,
                        "pre_emption_vulnerability": 2,
                    },
                    "mbr": {
                        "downlink": {"value": 100, "unit": 2},  # 100 Mbps
                        "uplink":   {"value": 50,  "unit": 2},
                    },
                    "gbr": {
                        "downlink": {"value": 50, "unit": 2},  # 50 Mbps
                        "uplink":   {"value": 25, "unit": 2},
                    },
                },
            }],
        }],
    }],
    "access_restriction_data": 32,
    "subscriber_status": 0,
    "network_access_mode": 0,
    "operator_determined_barring": 0,
    "subscribed_rau_tau_timer": 12,
}

print("Adding subscriber IMSI:", subscriber["imsi"])
db.AddSubscriber(subscriber)
print("Done. Verify with: open5gs-dbctl showpretty")
PYEOF
$SUDO chmod +x "${PYTHON_DIR}/example_add_subscriber.py"
echo "Example script → ${PYTHON_DIR}/example_add_subscriber.py"

# ============================================================
# 6. WebUI
# ============================================================
section "6/6 — Installing open5gs WebUI"

WEBUI_DIR="/opt/open5gs-webui"

# Node.js (from AppStream module)
if ! command -v node &>/dev/null; then
    $SUDO dnf -y module reset nodejs 2>/dev/null || true
    $SUDO dnf -y module enable nodejs:${NODEJS_VERSION}
    $SUDO dnf -y install nodejs npm
fi

echo "Node.js $(node --version) installed."

# Clone WebUI from the matching tag
if [[ -d "${WEBUI_DIR}" ]]; then
    echo "WebUI directory exists, removing for clean install..."
    $SUDO rm -rf "${WEBUI_DIR}"
fi

$SUDO git clone --depth 1 --branch "v${OPEN5GS_VERSION}" \
    "${OPEN5GS_REPO}" /tmp/open5gs-webui-src
$SUDO mv /tmp/open5gs-webui-src/webui "${WEBUI_DIR}"
$SUDO rm -rf /tmp/open5gs-webui-src

pushd "${WEBUI_DIR}" >/dev/null
$SUDO npm ci --production 2>/dev/null || $SUDO npm install --production
$SUDO npm run build 2>/dev/null || true

# Change default admin password from 1423 to admin
$SUDO sed -i "s/Account.register(newAccount, '1423'/Account.register(newAccount, 'admin'/" server/index.js
popd >/dev/null

# Create systemd service for WebUI
$SUDO tee /etc/systemd/system/open5gs-webui.service >/dev/null <<EOF
[Unit]
Description=Open5GS WebUI
After=network.target mongod.service
Requires=mongod.service

[Service]
Type=simple
WorkingDirectory=${WEBUI_DIR}
Environment=NODE_ENV=production
Environment=DB_URI=mongodb://127.0.0.1/open5gs
Environment=HOSTNAME=0.0.0.0
Environment=PORT=9999
Environment=NODE_OPTIONS=--max-old-space-size=256
ExecStart=/usr/bin/node server/index.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

$SUDO systemctl daemon-reload
$SUDO systemctl enable open5gs-webui
$SUDO systemctl start open5gs-webui || true

echo "WebUI installed → http://$(hostname -I | awk '{print $1}'):9999"
echo "  Default credentials: admin / admin"

# ============================================================
# 7. Firewall
# ============================================================
section "7 — Opening firewall ports"

if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
    $SUDO firewall-cmd --permanent \
        --add-port=9999/tcp \
        --add-port=3868/tcp --add-port=3868/sctp \
        --add-port=5868/tcp --add-port=5868/sctp \
        --add-port=27017/tcp
    $SUDO firewall-cmd --reload
    echo "Firewall ports opened: 9999/tcp 3868/tcp,sctp 5868/tcp,sctp 27017/tcp"
else
    echo "firewalld not active, skipping."
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "================================================================"
echo "  open5gs PCRF standalone installation complete"
echo "================================================================"
echo ""
echo "  Services:"
echo "    MongoDB:    systemctl status mongod"
echo "    PCRF:       systemctl status open5gs-pcrfd"
echo "    WebUI:      systemctl status open5gs-webui"
echo ""
echo "  Configuration files:"
echo "    PCRF:       /etc/open5gs/pcrf.yaml"
echo "    Diameter:   /etc/freeDiameter/pcrf.conf"
echo ""
echo "  DB tools:"
echo "    CLI:        open5gs-dbctl help"
echo "    Python:     ${PYTHON_DIR}/Open5GS.py"
echo "    Example:    python3 ${PYTHON_DIR}/example_add_subscriber.py"
echo ""
echo "  WebUI:        http://localhost:9999  (admin / admin)"
echo ""
echo "  Quick test — add a subscriber:"
echo "    open5gs-dbctl add 999700000000001 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA"
echo ""
echo "  Or with PCC rules (for PCRF):"
echo "    python3 ${PYTHON_DIR}/example_add_subscriber.py"
echo ""
echo "  Check PCRF log:"
echo "    tail -f /var/log/open5gs/pcrf.log"
echo "================================================================"
