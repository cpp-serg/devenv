#!/bin/bash
# Build libpcap from source (with remote capture support) and run rpcapd as a
# systemd service. Self-sufficient: no other devenv scripts need to run first,
# so it can be copied to a bare appliance host (e.g. Rocky 8 HyperCore edge
# nodes) and executed as-is.

set -euo pipefail

# sudo prefix when not already running as root, empty otherwise
SUDO=$([ "$(id -u)" -ne 0 ] && echo sudo || true)

function die() {
  echo "$1" 1>&2
  exit 1
}

# Appliance hosts (HyperCore) ship with every stock Rocky repo disabled, so
# enable the ones providing the build toolchain explicitly for this single
# transaction instead of relying on the host's repo configuration.
${SUDO} dnf install -y \
  --enablerepo baseos --enablerepo appstream \
  --enablerepo powertools --enablerepo devel \
  git gcc make ninja-build cmake flex bison

# Build in a fresh temporary directory that is removed automatically when the
# script exits (on success or failure), so re-runs stay clean.
workdir=$(mktemp -d)
trap "rm -rf '$workdir'" EXIT
cd "$workdir" || die "Failed to enter work directory $workdir"

git clone https://github.com/the-tcpdump-group/libpcap.git && cd libpcap

# The rpcap protocol has no set-datalink message, so remote clients are stuck
# with whatever link type the server opens the device with. Default the "any"
# pseudo-device to LINUX_SLL2 (cooked v2 header, carries per-packet ifindex)
# instead of LINUX_SLL; real interfaces keep their native DLT (e.g. EN10MB).
# git apply fails loudly (and aborts via set -e) if upstream drifts.
git apply <<'EOF' || die "LINUX_SLL2 default patch did not apply"
--- a/pcap-linux.c
+++ b/pcap-linux.c
@@ -2662,7 +2662,7 @@
 		 * Support both DLT_LINUX_SLL and DLT_LINUX_SLL2.
 		 */
 		handlep->cooked = 1;
-		handle->linktype = DLT_LINUX_SLL;
+		handle->linktype = DLT_LINUX_SLL2;
 		handle->dlt_list = (u_int *) malloc(sizeof(u_int) * 2);
 		if (handle->dlt_list == NULL) {
 			pcapint_fmt_errmsg_for_errno(handle->errbuf,
EOF

mkdir release && cd release
cmake -G Ninja -DBUILD_SHARED_LIBS=0 -DENABLE_REMOTE=1 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/libpcap ..
ninja && ${SUDO} ninja install

${SUDO} tee /etc/systemd/system/rpcapd.service > /dev/null <<EOF
[Unit]
Description=Rpcap Per-Connection Server
After=network.target

[Service]
ExecStart=/opt/libpcap/sbin/rpcapd -n

[Install]
WantedBy=multi-user.target
EOF

${SUDO} systemctl daemon-reload
${SUDO} systemctl enable --now rpcapd
