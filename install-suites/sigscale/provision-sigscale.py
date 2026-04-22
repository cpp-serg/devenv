#!/usr/bin/env python3
"""Provision subscribers from Open5GS CSV data into SigScale OCS.

Each subscriber is provisioned with both voice calling and data plans.

Usage: provision-sigscale.py [OPTIONS]
  -H HOST              OCS host (default: localhost:8080)
  -u USER:PASS         OCS credentials (default: admin:admin)
  -d DIR               Provision data directory (default: provision/)
  -y                   Skip interactive prompts, auto-select voice+data bundle offering
  --data-allowance SIZE  Data allowance per subscriber (default: 500M, e.g. 500M, 1G, 10G)
  --redirect-url URL   Set redirect URL on offering(s) for payment portal on quota exhaustion
"""

import argparse
import csv
import glob
import os
import sys
from collections import defaultdict
from urllib.request import Request, urlopen
from urllib.error import URLError
from urllib.parse import quote
import json
import base64

# --- Helpers ---

def parse_size(s):
    """Parse human-readable size to octets: '10G', '500M', '1024'."""
    s = s.strip().upper()
    multipliers = {"K": 1_000, "M": 1_000_000, "G": 1_000_000_000, "T": 1_000_000_000_000}
    if s[-1] in multipliers:
        return int(float(s[:-1]) * multipliers[s[-1]])
    if s.endswith("B"):
        s = s[:-1]
    return int(s)


def format_size(octets):
    """Format octets as human-readable."""
    if octets >= 1_000_000_000:
        return f"{octets / 1_000_000_000:.1f}G"
    if octets >= 1_000_000:
        return f"{octets / 1_000_000:.0f}M"
    if octets >= 1_000:
        return f"{octets / 1_000:.0f}K"
    return f"{octets}B"


# --- OCS API client ---

class OCSClient:
    def __init__(self, host, credentials):
        self.base_url = f"http://{host}"
        user, password = credentials.split(":", 1)
        token = base64.b64encode(f"{user}:{password}".encode()).decode()
        self.auth_header = f"Basic {token}"

    def request(self, method, path, body=None, accept="application/json",
                content_type="application/json"):
        url = f"{self.base_url}{path}"
        data = json.dumps(body).encode() if body else None
        req = Request(url, data=data, method=method)
        if accept:
            req.add_header("Accept", accept)
        req.add_header("Authorization", self.auth_header)
        if body is not None:
            req.add_header("Content-Type", content_type)
        try:
            with urlopen(req) as resp:
                raw = resp.read().decode()
                return resp.status, json.loads(raw) if raw else {}
        except URLError as e:
            if hasattr(e, "read"):
                try:
                    raw = e.read().decode()
                    return e.code, json.loads(raw) if raw else {}
                except Exception:
                    return e.code, {}
            raise

    def get(self, path):
        return self.request("GET", path)

    def post(self, path, body):
        return self.request("POST", path, body)

    def patch(self, path, body):
        return self.request("PATCH", path, body,
                            content_type="application/json-patch+json")

    def delete(self, path):
        return self.request("DELETE", path, accept=None)


# --- Offering classification ---

VOICE_SPECS = {"5", "9"}   # VoiceProductSpec, PrepaidVoiceProductSpec
DATA_SPECS = {"4", "8"}    # DataProductSpec, PrepaidDataProductSpec


def classify_offerings(offerings):
    voice, data, bundles = [], [], []
    for o in offerings:
        name = o["name"]
        desc = o.get("description", "")
        if o.get("isBundle"):
            bundles.append((name, desc))
        else:
            spec_id = str(o.get("productSpecification", {}).get("id", ""))
            if spec_id in VOICE_SPECS:
                voice.append((name, desc))
            elif spec_id in DATA_SPECS:
                data.append((name, desc))
    return voice, data, bundles


def print_offering_list(label, offerings):
    if not offerings:
        return
    print(f"  {label}:")
    for i, (name, desc) in enumerate(offerings, 1):
        print(f"    {i:2d}) {name:<25s}  {desc}")


def prompt_choice(prompt, count):
    while True:
        try:
            choice = int(input(prompt))
            if 1 <= choice <= count:
                return choice - 1
        except (ValueError, EOFError):
            pass
        print(f"  Please enter a number between 1 and {count}")


# --- Offering redirect configuration ---

def set_offering_redirect(ocs, offering_name, redirect_url):
    """Set redirectServer on a product offering via JSON Patch (RFC 6902).

    If the offering already has prodSpecCharValueUse, append to it;
    otherwise add the array with the redirectServer entry.
    """
    path = f"/catalogManagement/v2/productOffering/{quote(offering_name, safe='')}"
    status, offering = ocs.get(path)
    if status != 200:
        return False, f"GET offering failed (HTTP {status})"

    char_uses = offering.get("prodSpecCharValueUse", [])
    redirect_entry = {
        "name": "redirectServer",
        "valueType": "String",
        "productSpecCharacteristicValue": [{"value": redirect_url}],
    }

    # Check if redirectServer is already set with this value
    for cu in char_uses:
        if cu.get("name") == "redirectServer":
            vals = cu.get("productSpecCharacteristicValue", [])
            if vals and vals[0].get("value") == redirect_url:
                return True, "already set"

    # Build JSON Patch operations
    existing_idx = None
    for i, cu in enumerate(char_uses):
        if cu.get("name") == "redirectServer":
            existing_idx = i
            break

    if existing_idx is not None:
        ops = [{"op": "replace",
                "path": f"/prodSpecCharValueUse/{existing_idx}",
                "value": redirect_entry}]
    elif char_uses:
        ops = [{"op": "add",
                "path": "/prodSpecCharValueUse/-",
                "value": redirect_entry}]
    else:
        ops = [{"op": "add",
                "path": "/prodSpecCharValueUse",
                "value": [redirect_entry]}]

    status, resp = ocs.patch(path, ops)
    if status == 200:
        return True, "configured"
    return False, f"PATCH failed (HTTP {status})"


# --- CSV loading ---

def load_keys(keys_csv):
    keys = {}
    with open(keys_csv, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            imsi = row["IMSI"].strip()
            keys[imsi] = (row["KI"].strip(), row["OPC"].strip())
    return keys


def load_subscribers(imsi_csv):
    subs = []
    with open(imsi_csv, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            subs.append({
                "imsi": row["IMSI"].strip(),
                "msisdn": row["MSISDN"].strip(),
            })
    return subs


# --- Provisioning ---

def create_service(ocs, svc_id, characteristics):
    body = {
        "id": svc_id,
        "serviceCharacteristic": characteristics,
    }
    status, resp = ocs.post("/serviceInventoryManagement/v2/service", body)
    if status == 201:
        return True, "created"
    if "already exists" in json.dumps(resp):
        return True, "exists"
    return False, f"HTTP {status}"


def create_product(ocs, offering_id, service_id):
    body = {
        "productOffering": {"id": offering_id},
        "realizingService": [{"id": service_id}],
    }
    status, resp = ocs.post("/productInventoryManagement/v2/product", body)
    if status == 201:
        return True, "created", resp.get("id")
    if "has Product already" in json.dumps(resp):
        return True, "exists", None
    return False, f"HTTP {status}", None


def cleanup_negative_buckets(ocs, product_id):
    """Delete negative balance buckets that block credit authorization.

    OCS charge1() rejects all credit grants (CREDIT_LIMIT_REACHED 4012)
    when any bucket has a negative balance, regardless of unit type.
    Installation and subscription charges create negative cents buckets
    that block unrelated octets-based data grants.
    """
    if not product_id:
        return 0
    status, buckets = ocs.get("/balanceManagement/v1/bucket")
    if status != 200:
        return 0
    deleted = 0
    for b in buckets:
        if b.get("product", {}).get("id") != product_id:
            continue
        amount_str = b.get("remainedAmount", {}).get("amount", "0")
        amount_str = amount_str.rstrip("b")
        try:
            if int(amount_str) < 0:
                ocs.delete(b["href"])
                deleted += 1
        except ValueError:
            pass
    return deleted


def adjust_data_balance(ocs, product_id, octets):
    """Replace auto-created octets buckets with a specific data allowance."""
    if not product_id or octets is None:
        return
    status, buckets = ocs.get("/balanceManagement/v1/bucket")
    if status != 200:
        return
    for b in buckets:
        if b.get("product", {}).get("id") != product_id:
            continue
        if b.get("remainedAmount", {}).get("units") == "octets":
            ocs.delete(b["href"])
    ocs.post(f"/balanceManagement/v1/product/{product_id}/balanceTopup",
             {"amount": {"amount": octets, "units": "octets"}})


def find_products_for_service(service_id, products_cache):
    """Return product IDs whose realizingService includes service_id."""
    result = []
    for p in products_cache:
        for rs in p.get("realizingService", []):
            if rs.get("id") == service_id:
                result.append(p["id"])
                break
    return result


def update_existing_products(ocs, service_id, octets, products_cache):
    """Clean negatives and enforce data allowance on all linked products."""
    product_ids = find_products_for_service(service_id, products_cache)
    for pid in product_ids:
        cleanup_negative_buckets(ocs, pid)
        adjust_data_balance(ocs, pid, octets)
    return len(product_ids)


def provision_bundle(ocs, sub, ki, opc, bundle_name, data_allowance=None,
                     products_cache=None):
    """Provision with a single bundle offering (voice + data)."""
    imsi = sub["imsi"]

    ok, reason = create_service(ocs, imsi, [
        {"name": "serviceIdentity", "value": imsi},
        {"name": "serviceAkaK", "value": ki},
        {"name": "serviceAkaOPc", "value": opc},
        {"name": "multiSession", "value": True},
    ])
    if not ok:
        return "fail", f"service creation failed ({reason})"

    ok, reason, product_id = create_product(ocs, bundle_name, imsi)
    if not ok:
        return "fail", f"product creation failed ({reason})"

    if reason == "exists":
        n = update_existing_products(ocs, imsi, data_allowance,
                                     products_cache or [])
        return "update", f"updated {n} existing product(s)"

    cleanup_negative_buckets(ocs, product_id)
    adjust_data_balance(ocs, product_id, data_allowance)
    # Also update any pre-existing sibling products linked to the same service
    if products_cache:
        for pid in find_products_for_service(imsi, products_cache):
            if pid != product_id:
                cleanup_negative_buckets(ocs, pid)
                adjust_data_balance(ocs, pid, data_allowance)
    return "ok", "bundle: voice + data"


def provision_separate(ocs, sub, ki, opc, voice_offering, data_offering,
                       data_allowance=None, products_cache=None):
    """Provision with separate voice and data offerings."""
    imsi = sub["imsi"]
    msisdn = sub["msisdn"]

    # IMSI service (for data)
    ok, reason = create_service(ocs, imsi, [
        {"name": "serviceIdentity", "value": imsi},
        {"name": "serviceAkaK", "value": ki},
        {"name": "serviceAkaOPc", "value": opc},
        {"name": "multiSession", "value": True},
    ])
    if not ok:
        return "fail", f"IMSI service failed ({reason})"

    # MSISDN service (for voice) — service can only link to one product
    if not msisdn:
        return "skip", "no MSISDN for voice service"
    ok, reason = create_service(ocs, msisdn, [
        {"name": "serviceIdentity", "value": msisdn},
    ])
    if not ok:
        return "fail", f"MSISDN service failed ({reason})"

    # Voice product -> MSISDN service
    v_ok, v_reason, v_product_id = create_product(ocs, voice_offering, msisdn)
    # Data product -> IMSI service
    d_ok, d_reason, d_product_id = create_product(ocs, data_offering, imsi)

    if not v_ok or not d_ok:
        parts = []
        if not v_ok:
            parts.append(f"voice({v_reason})")
        if not d_ok:
            parts.append(f"data({d_reason})")
        return "fail", " ".join(parts)

    if v_reason == "exists" and d_reason == "exists":
        cache = products_cache or []
        n = update_existing_products(ocs, imsi, data_allowance, cache)
        # voice products (MSISDN) only need negative-bucket cleanup, not data adjust
        for pid in find_products_for_service(msisdn, cache):
            cleanup_negative_buckets(ocs, pid)
        return "update", f"updated {n} existing product(s)"

    cleanup_negative_buckets(ocs, v_product_id)
    cleanup_negative_buckets(ocs, d_product_id)
    adjust_data_balance(ocs, d_product_id, data_allowance)
    # Also update any pre-existing sibling data products for this IMSI
    if products_cache:
        for pid in find_products_for_service(imsi, products_cache):
            if pid != d_product_id:
                cleanup_negative_buckets(ocs, pid)
                adjust_data_balance(ocs, pid, data_allowance)
    return "ok", f"voice={msisdn} + data={imsi}"


# --- Verification ---

def verify(ocs, subscribers, use_bundle):
    print("\n=== Verification ===")
    _, services = ocs.get("/serviceInventoryManagement/v2/service")
    _, products = ocs.get("/productInventoryManagement/v2/product")
    _, buckets = ocs.get("/balanceManagement/v1/bucket")

    svc_count = len(services)
    prod_count = len(products)
    bucket_count = len(buckets)
    sub_count = len(subscribers)

    if use_bundle:
        print(f"  Services (subscribers):  {svc_count}")
        print(f"  Product instances:       {prod_count} (expected: ~{sub_count}, 1 bundle per subscriber)")
    else:
        print(f"  Services (IMSI+MSISDN):  {svc_count} (expected: ~{sub_count * 2})")
        print(f"  Product instances:       {prod_count} (expected: ~{sub_count * 2}, voice+data per subscriber)")
    print(f"  Balance buckets:         {bucket_count}")

    # Spot-check first and last subscriber
    for label, sub in [("first", subscribers[0]), ("last", subscribers[-1])]:
        imsi = sub["imsi"]
        msisdn = sub["msisdn"]
        print(f"\n  Spot check ({label}): {imsi} (MSISDN: {msisdn})")

        # Service check
        status, svc = ocs.get(f"/serviceInventoryManagement/v2/service/{imsi}")
        if status == 200:
            chars = {c["name"]: c.get("value", "") for c in svc.get("serviceCharacteristic", [])}
            k = chars.get("serviceAkaK", "")
            print(f"    IMSI service: found")
            print(f"    AKA-K:        {k[:16]}...")
        else:
            print(f"    IMSI service: NOT FOUND (HTTP {status})")

        # MSISDN service check (separate mode)
        if not use_bundle and msisdn:
            ms_status, _ = ocs.get(f"/serviceInventoryManagement/v2/service/{msisdn}")
            state = "found" if ms_status == 200 else f"NOT FOUND (HTTP {ms_status})"
            print(f"    MSISDN service: {state}")

        # Products for this subscriber
        search_ids = {imsi, msisdn} if not use_bundle else {imsi}
        found = []
        for p in products:
            svc_ids = {s.get("id", "") for s in p.get("realizingService", [])}
            if svc_ids & search_ids:
                offer = p.get("productOffering", {})
                offer_name = offer.get("id", offer.get("name", "unknown"))
                pid = p.get("id", "unknown")
                is_bundle = p.get("isBundle", False)
                balance = p.get("balance", [])
                found.append((pid, offer_name, is_bundle, svc_ids & search_ids, balance))

        if not found:
            print("    Products: NONE FOUND")
        else:
            for pid, offer_name, is_bundle, matched, balance in found:
                ptype = "bundle" if is_bundle else "single"
                svc_str = ", ".join(sorted(matched))
                print(f"    Product: {pid} (offering: {offer_name}) [{ptype}] -> svc: {svc_str}")
                for b in balance:
                    tb = b.get("totalBalance", {})
                    print(f"      Balance: {b.get('name', '?')} = {tb.get('amount', '?')} {tb.get('units', '?')}")
            if use_bundle:
                print("    Voice+Data: covered by bundle offering")
            elif len(found) >= 2:
                print(f"    Voice+Data: {len(found)} products (OK)")

    return prod_count, sub_count


# --- Main ---

def main():
    parser = argparse.ArgumentParser(
        description="Provision subscribers into SigScale OCS with voice + data plans")
    parser.add_argument("-H", "--host", default=os.environ.get("OCS_HOST", "localhost:8080"),
                        help="OCS host:port (default: localhost:8080)")
    parser.add_argument("-u", "--credentials", default=os.environ.get("OCS_CRED", "admin:admin"),
                        help="OCS user:password (default: admin:admin)")
    parser.add_argument("-d", "--dir", default=os.environ.get("PROVISION_DIR", "provision"),
                        help="Provision data directory (default: provision/)")
    parser.add_argument("-y", "--auto", action="store_true",
                        help="Skip interactive prompts, auto-select bundle offering")
    parser.add_argument("--data-allowance", default="500M",
                        help="Data allowance per subscriber, e.g. 500M, 1G (default: 500M)")
    parser.add_argument("--redirect-url",
                        default=os.environ.get("OCS_REDIRECT_URL"),
                        help="Redirect URL for payment portal on quota exhaustion")
    args = parser.parse_args()

    ocs = OCSClient(args.host, args.credentials)

    # --- Health check ---
    print(f"Checking OCS at http://{args.host} ...")
    try:
        status, health = ocs.request("GET", "/health", accept=None)
        if health.get("status") != "pass":
            print(f"ERROR: OCS health check failed (status: {health.get('status', 'unknown')})")
            sys.exit(1)
    except Exception as e:
        print(f"ERROR: Cannot reach OCS: {e}")
        sys.exit(1)
    print("OCS is healthy.")

    # --- Find input files ---
    csv_matches = sorted(glob.glob(os.path.join(args.dir, "IMSI_Provision_*.csv")))
    keys_csv = os.path.join(args.dir, "keys.csv")
    if not csv_matches or not os.path.isfile(keys_csv):
        print(f"ERROR: Cannot find IMSI_Provision_*.csv and/or keys.csv in {args.dir}/")
        sys.exit(1)
    imsi_csv = csv_matches[0]

    keys = load_keys(keys_csv)
    subscribers = load_subscribers(imsi_csv)
    print(f"Found {len(subscribers)} subscribers in {os.path.basename(imsi_csv)}")

    # --- Fetch and classify offerings ---
    print("\n=== Product Offerings ===")
    _, offerings = ocs.get("/catalogManagement/v2/productOffering")
    voice, data, bundles = classify_offerings(offerings)

    print_offering_list("Bundle offerings (voice + data)", bundles)
    print_offering_list("Voice offerings", voice)
    print_offering_list("Data offerings", data)

    # --- Select offerings ---
    use_bundle = False
    selected_bundle = None
    selected_voice = None
    selected_data = None

    if args.auto:
        if bundles:
            selected_bundle = bundles[0][0]
            use_bundle = True
            print(f"\nAuto-selected bundle: {selected_bundle}")
        elif voice and data:
            selected_voice = voice[0][0]
            selected_data = data[0][0]
            print(f"\nAuto-selected voice: {selected_voice}")
            print(f"Auto-selected data:  {selected_data}")
        else:
            print("ERROR: No suitable offerings for voice+data provisioning")
            sys.exit(1)
    else:
        if bundles:
            ans = input("\nUse a bundle offering for voice+data? [Y/n]: ").strip() or "Y"
        else:
            ans = "n"

        if ans.lower().startswith("y"):
            use_bundle = True
            if len(bundles) == 1:
                selected_bundle = bundles[0][0]
            else:
                idx = prompt_choice(f"Select bundle [1-{len(bundles)}]: ", len(bundles))
                selected_bundle = bundles[idx][0]
            print(f"Selected bundle: {selected_bundle}")
        else:
            if not voice or not data:
                print("ERROR: Need both voice and data offerings available")
                sys.exit(1)
            idx = prompt_choice(f"Select voice offering [1-{len(voice)}]: ", len(voice))
            selected_voice = voice[idx][0]
            idx = prompt_choice(f"Select data offering [1-{len(data)}]: ", len(data))
            selected_data = data[idx][0]
            print(f"Selected voice: {selected_voice}")
            print(f"Selected data:  {selected_data}")

    # --- Configure redirect on selected offering(s) ---
    if args.redirect_url:
        print(f"\n=== Configuring Redirect Server ===")
        print(f"  URL: {args.redirect_url}")
        offerings_to_update = []
        if use_bundle:
            offerings_to_update.append(selected_bundle)
        else:
            offerings_to_update.append(selected_voice)
            offerings_to_update.append(selected_data)
        for offer_name in offerings_to_update:
            ok, detail = set_offering_redirect(ocs, offer_name, args.redirect_url)
            status_str = "OK" if ok else "FAIL"
            print(f"  {status_str}  {offer_name}: {detail}")
            if not ok:
                print("ERROR: Failed to configure redirect on offering")
                sys.exit(1)

    # --- Fetch tariff tables ---
    print("\n=== Tariff Tables ===")
    _, resources = ocs.get("/resourceInventoryManagement/v1/resource")
    tariffs = [(r["id"], r["name"]) for r in resources
               if r.get("resourceSpecification", {}).get("name") == "TariffTable"]

    selected_tariff = None
    if not tariffs:
        print("  (no tariff tables found)")
    else:
        print("   0) (none)")
        for i, (tid, tname) in enumerate(tariffs, 1):
            print(f"  {i:2d}) {tname}")
        if args.auto:
            choice = 0
        else:
            try:
                choice = int(input(f"\nSelect tariff table [0-{len(tariffs)}] (0=none): "))
            except (ValueError, EOFError):
                choice = 0
        if 1 <= choice <= len(tariffs):
            selected_tariff = tariffs[choice - 1][1]
            print(f"Selected tariff: {selected_tariff}")
        else:
            print("No tariff table selected.")

    # --- Provision ---
    data_allowance = parse_size(args.data_allowance)

    print(f"\n=== Provisioning {len(subscribers)} subscribers (voice + data) ===")
    if use_bundle:
        print(f"  Mode:    bundle")
        print(f"  Bundle:  {selected_bundle}")
    else:
        print(f"  Mode:    separate voice + data")
        print(f"  Voice:   {selected_voice}")
        print(f"  Data:    {selected_data}")
    print(f"  Data:    {format_size(data_allowance)} per subscriber")
    if selected_tariff:
        print(f"  Tariff:  {selected_tariff}")
    if args.redirect_url:
        print(f"  Redirect: {args.redirect_url}")
    print()

    # Pre-fetch products once so per-subscriber updates don't re-query
    _, products_cache = ocs.get("/productInventoryManagement/v2/product")
    if not isinstance(products_cache, list):
        products_cache = []

    counts = defaultdict(int)

    for sub in subscribers:
        imsi = sub["imsi"]
        if imsi not in keys:
            print(f"  SKIP {imsi}: no AKA keys found")
            counts["skip"] += 1
            continue

        ki, opc = keys[imsi]

        if use_bundle:
            result, detail = provision_bundle(ocs, sub, ki, opc,
                                              selected_bundle, data_allowance,
                                              products_cache)
        else:
            result, detail = provision_separate(ocs, sub, ki, opc,
                                                selected_voice, selected_data,
                                                data_allowance, products_cache)

        counts[result] += 1
        if result == "ok":
            print(f"  OK   {imsi} ({detail})", end="\r")
        elif result == "update":
            print(f"  UPD  {imsi} ({detail})", end="\r")
        elif result == "skip":
            print(f"  SKIP {imsi} ({detail})", end="\r")
        else:
            print(f"  FAIL {imsi}: {detail}")

    print()
    print(f"\n=== Provisioning Complete ===")
    print(f"  Created:  {counts['ok']}")
    print(f"  Updated:  {counts['update']}")
    print(f"  Skipped:  {counts['skip']}")
    print(f"  Failed:   {counts['fail']}")

    # --- Verify ---
    prod_count, sub_count = verify(ocs, subscribers, use_bundle)

    expected = sub_count if use_bundle else sub_count * 2
    print()
    if counts["fail"] == 0 and prod_count >= expected:
        print("All subscribers provisioned with voice and data plans.")
    else:
        print("WARNING: Some subscribers may not have been provisioned correctly.")
        sys.exit(1)


if __name__ == "__main__":
    main()
