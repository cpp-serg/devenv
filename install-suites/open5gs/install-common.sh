#!/usr/bin/env bash
# install-common.sh — Shared function library for open5gs installers
#
# Source this file; no code runs at source time.
#   . ./install-common.sh
#
# Requires: bash 4+ (associative arrays)

# Guard against double-sourcing
[[ -n "${_INSTALL_COMMON_LOADED:-}" ]] && return 0
_INSTALL_COMMON_LOADED=1

# ============================================================
# Default configuration — override before sourcing or after
# ============================================================
: "${MONGODB_VERSION:=7.0}"
: "${NODEJS_VERSION:=18}"
: "${OPEN5GS_VERSION:=2.7.7}"
: "${OPEN5GS_REPO:=https://github.com/open5gs/open5gs.git}"
: "${RPM_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rpms}"

# Will be set by setup_sudo
SUDO=""

# ============================================================
# Utility functions
# ============================================================

section() {
    echo ""
    echo ">>> $1"
    echo ""
}

setup_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    else
        if ! sudo -v; then
            echo "ERROR: Cannot obtain sudo privileges." >&2
            exit 1
        fi
        SUDO="sudo"
    fi
}

check_rocky_linux() {
    if ! grep -q 'Rocky Linux release 8' /etc/redhat-release 2>/dev/null; then
        echo "WARNING: This script targets Rocky Linux 8.x. Detected:"
        cat /etc/redhat-release 2>/dev/null || echo "(unknown)"
        echo "Continuing anyway..."
    fi
}

# ============================================================
# RPM verification
# ============================================================

# Populates associative array RPM_FILES[comp] → path to RPM
declare -gA RPM_FILES

verify_rpms() {
    local missing=()
    for comp in "$@"; do
        local rpm_path
        rpm_path=$(ls "${RPM_DIR}"/open5gs-${comp}-*.el8.*.rpm 2>/dev/null | grep -v debuginfo | head -1)
        if [[ -z "${rpm_path}" ]]; then
            missing+=("${comp}")
        else
            RPM_FILES["${comp}"]="${rpm_path}"
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Cannot find RPMs for: ${missing[*]}" >&2
        echo "       Looked in: ${RPM_DIR}/" >&2
        echo "       Build them first with:  ./build.sh" >&2
        exit 1
    fi
}

# ============================================================
# MongoDB
# ============================================================

install_mongodb() {
    section "Installing MongoDB ${MONGODB_VERSION}"

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

    # Bind MongoDB to all interfaces
    if grep -q 'bindIp: 127.0.0.1' /etc/mongod.conf 2>/dev/null; then
        $SUDO sed -i 's/^  bindIp: 127.0.0.1/  bindIp: 0.0.0.0/' /etc/mongod.conf
    fi

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
}

# ============================================================
# System dependencies
# ============================================================

install_system_deps() {
    section "Installing system dependencies"

    $SUDO dnf -y install epel-release
    $SUDO dnf -y install lksctp-tools gnutls libgcrypt openssl-libs libidn \
        mongo-c-driver libyaml libnghttp2 libmicrohttpd libcurl libtalloc \
        logrotate kernel-modules-extra-"$(uname -r)"

    # Load SCTP kernel module (required by freeDiameter)
    if ! lsmod | grep -q '^sctp '; then
        $SUDO modprobe sctp
    fi

    echo "System dependencies installed."
}

# ============================================================
# RPM installation
# ============================================================

install_rpms() {
    section "Installing open5gs RPMs"

    local rpms=()
    for comp in "$@"; do
        if [[ -n "${RPM_FILES[${comp}]:-}" ]]; then
            rpms+=("${RPM_FILES[${comp}]}")
        fi
    done

    if [[ ${#rpms[@]} -gt 0 ]]; then
        $SUDO rpm -Uvh --force --noscripts "${rpms[@]}"
        echo "Installed RPMs: $*"
    fi
}

# ============================================================
# User / directories
# ============================================================

create_open5gs_user() {
    getent group open5gs >/dev/null || $SUDO groupadd -r open5gs
    getent passwd open5gs >/dev/null || \
        $SUDO useradd -r -g open5gs -d /run/open5gs -s /sbin/nologin -c "Open5GS daemon" open5gs
}

create_log_dir() {
    $SUDO install -d -m 0750 -o open5gs -g open5gs /var/log/open5gs
}

create_run_dirs() {
    for daemon in "$@"; do
        $SUDO install -d -m 0755 -o open5gs -g open5gs "/run/open5gs-${daemon}"
    done
}

# ============================================================
# freeDiameter certificates
# ============================================================

generate_fd_certs() {
    local name="$1"
    if [[ ! -f "/etc/freeDiameter/${name}.cert.pem" || ! -f "/etc/freeDiameter/${name}.key.pem" ]]; then
        $SUDO mkdir -p /etc/freeDiameter
        $SUDO openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
            -subj "/CN=${name}.localdomain" \
            -keyout "/etc/freeDiameter/${name}.key.pem" \
            -out "/etc/freeDiameter/${name}.cert.pem" \
            2>/dev/null
        $SUDO chown open5gs:open5gs "/etc/freeDiameter/${name}.key.pem" "/etc/freeDiameter/${name}.cert.pem"
        $SUDO chmod 640 "/etc/freeDiameter/${name}.key.pem"
        echo "Generated self-signed TLS certs for ${name}."
    fi
}

# ============================================================
# Service management
# ============================================================

enable_services() {
    section "Enabling and starting services"

    $SUDO systemctl daemon-reload
    for daemon in "$@"; do
        $SUDO systemctl enable "open5gs-${daemon}"
        $SUDO systemctl start "open5gs-${daemon}" || true
        echo "  Started open5gs-${daemon}"
    done
}

# ============================================================
# DB tools
# ============================================================

install_dbctl() {
    section "Installing open5gs-dbctl"

    local tools_dir="/usr/local/share/open5gs"
    $SUDO install -d "${tools_dir}"

    $SUDO curl -fsSL "https://raw.githubusercontent.com/open5gs/open5gs/v${OPEN5GS_VERSION}/misc/db/open5gs-dbctl" \
        -o "${tools_dir}/open5gs-dbctl"
    $SUDO chmod +x "${tools_dir}/open5gs-dbctl"
    $SUDO ln -sf "${tools_dir}/open5gs-dbctl" /usr/local/bin/open5gs-dbctl

    echo "open5gs-dbctl installed → /usr/local/bin/open5gs-dbctl"
}

install_python_db_lib() {
    section "Installing Python DB library"

    local tools_dir="/usr/local/share/open5gs"
    local python_dir="${tools_dir}/python"
    $SUDO install -d "${python_dir}"

    $SUDO curl -fsSL "https://raw.githubusercontent.com/open5gs/open5gs/v${OPEN5GS_VERSION}/misc/db/python/Open5GS.py" \
        -o "${python_dir}/Open5GS.py"

    $SUDO pip3 install pymongo 2>/dev/null || $SUDO python3 -m pip install pymongo

    echo "Open5GS.py installed → ${python_dir}/Open5GS.py"
}

# ============================================================
# WebUI
# ============================================================

install_webui() {
    section "Installing open5gs WebUI"

    local webui_dir="/opt/open5gs-webui"

    # Node.js
    if ! command -v node &>/dev/null; then
        $SUDO dnf -y module reset nodejs 2>/dev/null || true
        $SUDO dnf -y module enable nodejs:${NODEJS_VERSION}
        $SUDO dnf -y install nodejs npm
    fi
    echo "Node.js $(node --version) installed."

    # Clone WebUI
    if [[ -d "${webui_dir}" ]]; then
        echo "WebUI directory exists, removing for clean install..."
        $SUDO rm -rf "${webui_dir}"
    fi

    $SUDO git clone --depth 1 --branch "v${OPEN5GS_VERSION}" \
        "${OPEN5GS_REPO}" /tmp/open5gs-webui-src
    $SUDO mv /tmp/open5gs-webui-src/webui "${webui_dir}"
    $SUDO rm -rf /tmp/open5gs-webui-src

    pushd "${webui_dir}" >/dev/null
    $SUDO npm ci --production 2>/dev/null || $SUDO npm install --production
    $SUDO npm run build 2>/dev/null || true

    # Change default admin password from 1423 to admin
    $SUDO sed -i "s/Account.register(newAccount, '1423'/Account.register(newAccount, 'admin'/" server/index.js
    popd >/dev/null

    # systemd service
    $SUDO tee /etc/systemd/system/open5gs-webui.service >/dev/null <<EOF
[Unit]
Description=Open5GS WebUI
After=network.target mongod.service
Requires=mongod.service

[Service]
Type=simple
WorkingDirectory=${webui_dir}
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
}

# ============================================================
# Firewall
# ============================================================

open_firewall_ports() {
    section "Opening firewall ports"

    if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
        local args=()
        for port_proto in "$@"; do
            args+=("--add-port=${port_proto}")
        done
        $SUDO firewall-cmd --permanent "${args[@]}"
        $SUDO firewall-cmd --reload
        echo "Firewall ports opened: $*"
    else
        echo "firewalld not active, skipping."
    fi
}

# ============================================================
# Config file helper
# ============================================================

backup_and_write() {
    local path="$1"
    $SUDO mkdir -p "$(dirname "${path}")"
    if [[ -f "${path}" ]]; then
        $SUDO cp -n "${path}" "${path}.bak"
    fi
    $SUDO tee "${path}" >/dev/null
}

# ============================================================
# TUN interface setup (for UPF)
# ============================================================

setup_tun_interface() {
    section "Setting up TUN interface for UPF"

    if ! ip link show ogstun &>/dev/null; then
        $SUDO ip tuntap add name ogstun mode tun
        $SUDO ip addr add 10.45.0.1/16 dev ogstun
        $SUDO ip link set ogstun up
        echo "Created ogstun interface."
    else
        echo "ogstun interface already exists."
    fi

    # IP forwarding
    $SUDO sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" | $SUDO tee /etc/sysctl.d/30-open5gs.conf >/dev/null

    # NAT masquerade
    if ! iptables -t nat -C POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null; then
        $SUDO iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
        echo "Added NAT masquerade rule."
    else
        echo "NAT masquerade rule already exists."
    fi
}
