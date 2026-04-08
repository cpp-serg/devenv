# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a wrapper/orchestration project for **SigScale OCS** (Online Charging System) — a 3GPP-compliant prepaid billing system built with Erlang/OTP. The `ocs/` subdirectory is a git clone of [sigscale/ocs](https://github.com/sigscale/ocs). The wrapper provides containerized build, deployment scripts, and Python admin tools.

## Architecture

```
sigscale/                      Wrapper orchestration
├── build.sh                   Container build via Podman + Containerfile
├── install-prereqs.sh         Erlang/OTP + OS deps on Rocky Linux 8/9
├── install-ocs.sh             Deploy release artifacts to target system
├── run_in_container.sh        Run OCS in Podman with persistent storage
├── provision-sigscale.py      Bulk provision subscribers (voice+data bundles)
├── manage-subscriber.py       Per-subscriber CRUD (show/set/reset)
├── provision/                 CSV input data (IMSI, AKA keys)
├── output/                    Build artifacts (release tarball, configs)
├── Containerfile              Multi-layer build (Rocky 8.10 + Erlang 26.2.1)
└── ocs/                       Git clone of sigscale/ocs (Erlang source)
    ├── src/                   113 Erlang modules
    ├── test/                  25 Common Test suites
    ├── priv/www/              Polymer web GUI
    ├── priv/schema/           OpenAPI/Swagger specs
    ├── include/ocs.hrl        Core record definitions (service, product, bucket, offer)
    ├── c_src/                 C NIFs (Milenage, ECC crypto)
    └── scripts/               DB init, cert gen, SNMP setup
```

## Build & Deploy

```bash
# Full container build (extracts artifacts to output/)
./build.sh              # -c for clean/no-cache

# Direct on Rocky Linux 8/9
./install-prereqs.sh
sudo ./install-ocs.sh output/

# Run in container with persistent storage
./run_in_container.sh                    # first run: installs everything
./run_in_container.sh --skip-install     # subsequent: just start
./run_in_container.sh --rebuild          # nuke and recreate
```

## OCS Build System (Erlang/Autotools)

OCS itself uses GNU Autotools, built out-of-tree:

```bash
cd ocs
aclocal && autoheader && autoconf && libtoolize --automake && automake --add-missing
mkdir ../ocs.build && cd ../ocs.build
ERLANG_INSTALL_LIB_DIR=$PWD/shell/lib ERL_LIBS=$PWD/shell/lib ../ocs/configure
make                  # build
make check            # dialyzer + Common Test suites
make install          # install to ERL_LIBS
make release          # produce ocs-X.Y.Z.tar.gz
```

Dependencies (fetched during container build): mochiweb, radierl, sigscale_mibs.

## OCS REST APIs

The OCS exposes TM Forum Open APIs on port 8080 (HTTP Basic Auth, default `admin:admin`):

| API | Base Path |
|-----|-----------|
| Product Catalog | `/catalogManagement/v2/productOffering` |
| Product Inventory | `/productInventoryManagement/v2/product` |
| Service Inventory | `/serviceInventoryManagement/v2/service` |
| Balance/Buckets | `/balanceManagement/v1/bucket` |
| Resource Inventory | `/resourceInventoryManagement/v1/resource` |
| Health | `/health` (no Accept header — returns 415 with `application/json`) |

Service PATCH uses `Content-Type: application/json-patch+json` (RFC 6902).

## Data Model

A subscriber consists of three linked entities:

- **Service** (`/service/{imsi}`) — identity + AKA credentials (K, OPc). Has a 1:1 `product` reference.
- **Product** (`/product/{id}`) — links an offering to service(s). Has `balance` (aggregated) and `realizingService` list.
- **Bucket** (`/bucket/{id}`) — individual balance unit (cents or octets). References parent product.

Deletion order matters: **services → products** (OCS returns 403 if a product is still referenced by a service). Buckets can be deleted independently.

## Product Offerings

OCS ships with example offerings (created on first install):

- **Data**: "Data (1G/4G/10G)" — spec `"8"` (PrepaidDataProductSpec), monthly subscription + overage
- **Voice**: "Voice Calling" — spec `"9"` (PrepaidVoiceProductSpec), tariff-based
- **Bundles**: "Voice & Data (1G/4G/10G)" — `isBundle=true`, combines data + voice

Bundle offerings are preferred for provisioning: one product per subscriber covers both voice and data. The OCS auto-creates balance buckets from the offering's price alterations.

## Python Admin Tools

Both use stdlib only (`urllib`, `csv`, `json`, `argparse`). No pip dependencies.

```bash
# Bulk provision from CSV
python3 provision-sigscale.py -y                    # auto-select bundle
python3 provision-sigscale.py -H host:port -d dir/  # custom host/data dir

# Per-subscriber management
python3 manage-subscriber.py show --all                         # table view
python3 manage-subscriber.py show 315010999976000               # single detail
python3 manage-subscriber.py set 315010999976000 --enabled false --balance-data 5G
python3 manage-subscriber.py reset 315010999976000              # re-provision from offering
```

## Default Ports

| Service | Port | Protocol |
|---------|------|----------|
| Web UI / REST | 8080 | HTTP |
| DIAMETER Accounting | 3868 | SCTP |
| DIAMETER Auth | 3869 | SCTP |
| RADIUS Auth | 1812 | UDP |
| RADIUS Accounting | 1813 | UDP |

## Provision Data Format

- `provision/IMSI_Provision_*.csv` — columns: `ICCID,IMSI,MSISDN,PROFILENAME,PIN1,PIN2,PUK1,PUK2`
- `provision/keys.csv` — columns: `ICCID,IMSI,KI,OPC`
