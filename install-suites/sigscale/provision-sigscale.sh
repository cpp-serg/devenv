#!/bin/bash
# Provision subscribers from Open5GS CSV data into SigScale OCS
# Usage: provision-sigscale.sh [OPTIONS]
#   -H HOST       OCS host (default: localhost:8080)
#   -u USER:PASS  OCS credentials (default: admin:admin)
#   -d DIR        Provision data directory (default: provision/)
#   -y            Skip interactive prompts, use first offering and no tariff
set -euo pipefail

OCS_HOST="${OCS_HOST:-localhost:8080}"
OCS_CRED="${OCS_CRED:-admin:admin}"
PROVISION_DIR="${PROVISION_DIR:-provision}"
AUTO_MODE=0

while getopts "H:u:d:y" opt; do
    case ${opt} in
        H) OCS_HOST="$OPTARG" ;;
        u) OCS_CRED="$OPTARG" ;;
        d) PROVISION_DIR="$OPTARG" ;;
        y) AUTO_MODE=1 ;;
        *) echo "Usage: $0 [-H host:port] [-u user:pass] [-d provision_dir] [-y]"; exit 1 ;;
    esac
done

OCS_URL="http://${OCS_HOST}"

# --- Helper ---
ocs_api() {
    local method="$1" path="$2"
    shift 2
    local ct_header=()
    if [ "$method" = "POST" ] || [ "$method" = "PATCH" ]; then
        ct_header=(-H 'Content-Type: application/json')
    fi
    curl -s -u "${OCS_CRED}" -X "${method}" "${OCS_URL}${path}" \
        "${ct_header[@]}" -H 'Accept: application/json' "$@"
}

# --- Validate connectivity ---
echo "Checking OCS at ${OCS_URL} ..."
HEALTH=$(curl -s -u "${OCS_CRED}" "${OCS_URL}/health" 2>&1) || { echo "ERROR: Cannot reach OCS"; exit 1; }
STATUS=$(echo "$HEALTH" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null) || STATUS="unknown"
if [ "$STATUS" != "pass" ]; then
    echo "ERROR: OCS health check failed (status: ${STATUS})"
    exit 1
fi
echo "OCS is healthy."

# --- Find input files ---
IMSI_CSV=$(ls "${PROVISION_DIR}"/IMSI_Provision_*.csv 2>/dev/null | head -1)
KEYS_CSV="${PROVISION_DIR}/keys.csv"
if [ -z "$IMSI_CSV" ] || [ ! -f "$KEYS_CSV" ]; then
    echo "ERROR: Cannot find IMSI_Provision_*.csv and/or keys.csv in ${PROVISION_DIR}/"
    exit 1
fi
SUBSCRIBER_COUNT=$(tail -n +2 "$IMSI_CSV" | wc -l)
echo "Found ${SUBSCRIBER_COUNT} subscribers in $(basename "$IMSI_CSV")"

# --- Fetch and display product offerings ---
echo ""
echo "=== Product Offerings ==="
OFFERINGS_JSON=$(ocs_api GET /catalogManagement/v2/productOffering)
OFFERING_NAMES=()
OFFERING_DESCS=()
OFFERING_BUNDLES=()
while IFS=$'\t' read -r name desc bundle; do
    OFFERING_NAMES+=("$name")
    OFFERING_DESCS+=("$desc")
    OFFERING_BUNDLES+=("$bundle")
done < <(echo "$OFFERINGS_JSON" | python3 -c "
import sys, json
offers = json.load(sys.stdin)
for o in offers:
    bundle = 'bundle' if o.get('isBundle') else 'single'
    print(f\"{o['name']}\t{o.get('description','')}\t{bundle}\")
")

for i in "${!OFFERING_NAMES[@]}"; do
    printf "  %2d) %-25s  %s [%s]\n" "$((i+1))" "${OFFERING_NAMES[$i]}" "${OFFERING_DESCS[$i]}" "${OFFERING_BUNDLES[$i]}"
done

if [ "$AUTO_MODE" -eq 1 ]; then
    OFFER_IDX=0
else
    echo ""
    read -rp "Select offering [1-${#OFFERING_NAMES[@]}]: " OFFER_CHOICE
    OFFER_IDX=$((OFFER_CHOICE - 1))
    if [ "$OFFER_IDX" -lt 0 ] || [ "$OFFER_IDX" -ge "${#OFFERING_NAMES[@]}" ]; then
        echo "ERROR: Invalid choice"
        exit 1
    fi
fi
SELECTED_OFFER="${OFFERING_NAMES[$OFFER_IDX]}"
echo "Selected offering: ${SELECTED_OFFER}"

# --- Fetch and display tariff tables ---
echo ""
echo "=== Tariff Tables ==="
TARIFFS_JSON=$(ocs_api GET /resourceInventoryManagement/v1/resource)
TARIFF_NAMES=()
TARIFF_IDS=()
while IFS=$'\t' read -r tid tname; do
    TARIFF_IDS+=("$tid")
    TARIFF_NAMES+=("$tname")
done < <(echo "$TARIFFS_JSON" | python3 -c "
import sys, json
resources = json.load(sys.stdin)
for r in resources:
    spec = r.get('resourceSpecification', {})
    if spec.get('name') == 'TariffTable':
        print(f\"{r['id']}\t{r['name']}\")
" 2>/dev/null)

if [ "${#TARIFF_NAMES[@]}" -eq 0 ]; then
    echo "  (no tariff tables found)"
    SELECTED_TARIFF=""
else
    printf "   0) (none)\n"
    for i in "${!TARIFF_NAMES[@]}"; do
        printf "  %2d) %s\n" "$((i+1))" "${TARIFF_NAMES[$i]}"
    done
    if [ "$AUTO_MODE" -eq 1 ]; then
        TARIFF_CHOICE=0
    else
        echo ""
        read -rp "Select tariff table [0-${#TARIFF_NAMES[@]}] (0=none): " TARIFF_CHOICE
    fi
    if [ "$TARIFF_CHOICE" -gt 0 ] 2>/dev/null && [ "$TARIFF_CHOICE" -le "${#TARIFF_NAMES[@]}" ]; then
        SELECTED_TARIFF="${TARIFF_NAMES[$((TARIFF_CHOICE - 1))]}"
        echo "Selected tariff: ${SELECTED_TARIFF}"
    else
        SELECTED_TARIFF=""
        echo "No tariff table selected."
    fi
fi

# --- Build IMSI-to-key lookup ---
declare -A KEY_MAP OPC_MAP
while IFS=',' read -r iccid imsi ki opc; do
    imsi="${imsi//$'\r'/}"
    ki="${ki//$'\r'/}"
    opc="${opc//$'\r'/}"
    [ "$imsi" = "IMSI" ] && continue
    KEY_MAP["$imsi"]="$ki"
    OPC_MAP["$imsi"]="$opc"
done < "$KEYS_CSV"

# --- Provision subscribers ---
echo ""
echo "=== Provisioning ${SUBSCRIBER_COUNT} subscribers ==="
echo "  Offering: ${SELECTED_OFFER}"
[ -n "$SELECTED_TARIFF" ] && echo "  Tariff:   ${SELECTED_TARIFF}"
echo ""

SUCCESS=0
FAIL=0
SKIP=0

while IFS=',' read -r iccid imsi msisdn profile pin1 pin2 puk1 puk2; do
    imsi="${imsi//$'\r'/}"
    [ "$imsi" = "IMSI" ] && continue

    KI="${KEY_MAP[$imsi]:-}"
    OPC="${OPC_MAP[$imsi]:-}"
    if [ -z "$KI" ] || [ -z "$OPC" ]; then
        echo "  SKIP ${imsi}: no AKA keys found"
        SKIP=$((SKIP + 1))
        continue
    fi

    # Step 1: Create service (subscriber identity + AKA credentials)
    SVC_BODY=$(cat <<EOFJ
{
  "id": "${imsi}",
  "serviceCharacteristic": [
    {"name": "serviceIdentity", "value": "${imsi}"},
    {"name": "serviceAkaK", "value": "${KI}"},
    {"name": "serviceAkaOPc", "value": "${OPC}"}
  ]
}
EOFJ
)
    SVC_RESP=$(ocs_api POST /serviceInventoryManagement/v2/service -d "$SVC_BODY" -w '\n%{http_code}')
    SVC_HTTP=$(echo "$SVC_RESP" | tail -1)
    SVC_JSON=$(echo "$SVC_RESP" | sed '$d')

    if [ "$SVC_HTTP" = "201" ]; then
        : # service created
    elif echo "$SVC_JSON" | grep -q "already exists" 2>/dev/null; then
        : # service already exists, continue to product
    else
        echo "  FAIL ${imsi}: service creation failed (HTTP ${SVC_HTTP})"
        FAIL=$((FAIL + 1))
        continue
    fi

    # Step 2: Create product inventory (links service to offering)
    PROD_BODY=$(cat <<EOFJ
{
  "productOffering": {"id": "${SELECTED_OFFER}"},
  "realizingService": [{"id": "${imsi}"}]
}
EOFJ
)
    PROD_RESP=$(ocs_api POST /productInventoryManagement/v2/product -d "$PROD_BODY" -w '\n%{http_code}')
    PROD_HTTP=$(echo "$PROD_RESP" | tail -1)

    if [ "$PROD_HTTP" = "201" ]; then
        SUCCESS=$((SUCCESS + 1))
        printf "  OK   %s (service + product)\r" "$imsi"
    elif echo "$PROD_RESP" | grep -q "has Product already" 2>/dev/null; then
        SKIP=$((SKIP + 1))
        printf "  SKIP %s (already provisioned)\r" "$imsi"
    else
        echo "  FAIL ${imsi}: product creation failed (HTTP ${PROD_HTTP})"
        FAIL=$((FAIL + 1))
    fi
done < "$IMSI_CSV"

echo ""
echo ""
echo "=== Provisioning Complete ==="
echo "  Created:  ${SUCCESS}"
echo "  Skipped:  ${SKIP}"
echo "  Failed:   ${FAIL}"

# --- Verify ---
echo ""
echo "=== Verification ==="

SVC_COUNT=$(ocs_api GET /serviceInventoryManagement/v2/service | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
PROD_COUNT=$(ocs_api GET /productInventoryManagement/v2/product | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
BUCKET_COUNT=$(ocs_api GET /balanceManagement/v1/bucket | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)

echo "  Services (subscribers):  ${SVC_COUNT}"
echo "  Product instances:       ${PROD_COUNT}"
echo "  Balance buckets:         ${BUCKET_COUNT}"

# Spot-check first and last IMSI
FIRST_IMSI=$(tail -n +2 "$IMSI_CSV" | head -1 | cut -d, -f2)
LAST_IMSI=$(tail -1 "$IMSI_CSV" | cut -d, -f2)

echo ""
echo "  Spot check (first): ${FIRST_IMSI}"
FIRST_SVC=$(ocs_api GET "/serviceInventoryManagement/v2/service/${FIRST_IMSI}" -w '\n%{http_code}')
FIRST_HTTP=$(echo "$FIRST_SVC" | tail -1)
if [ "$FIRST_HTTP" = "200" ]; then
    echo "    Service:  found"
    echo "    AKA-K:    $(echo "$FIRST_SVC" | sed '$d' | python3 -c "
import sys, json
s = json.load(sys.stdin)
for c in s.get('serviceCharacteristic', []):
    if c['name'] == 'serviceAkaK': print(c['value'])
" 2>/dev/null)"
else
    echo "    Service:  NOT FOUND (HTTP ${FIRST_HTTP})"
fi

echo ""
echo "  Spot check (last):  ${LAST_IMSI}"
LAST_SVC=$(ocs_api GET "/serviceInventoryManagement/v2/service/${LAST_IMSI}" -w '\n%{http_code}')
LAST_HTTP=$(echo "$LAST_SVC" | tail -1)
if [ "$LAST_HTTP" = "200" ]; then
    echo "    Service:  found"
    echo "    AKA-K:    $(echo "$LAST_SVC" | sed '$d' | python3 -c "
import sys, json
s = json.load(sys.stdin)
for c in s.get('serviceCharacteristic', []):
    if c['name'] == 'serviceAkaK': print(c['value'])
" 2>/dev/null)"
else
    echo "    Service:  NOT FOUND (HTTP ${LAST_HTTP})"
fi

echo ""
if [ "$FAIL" -eq 0 ] && [ "$SVC_COUNT" -ge "$SUBSCRIBER_COUNT" ]; then
    echo "All subscribers provisioned successfully."
else
    echo "WARNING: Some subscribers may not have been provisioned correctly."
    exit 1
fi
