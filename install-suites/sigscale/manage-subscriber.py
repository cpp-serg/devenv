#!/usr/bin/env python3
"""Manage provisioned data for a specific subscriber in SigScale OCS.

Usage:
  manage-subscriber.py show  <imsi>       [-H host] [-u cred]
  manage-subscriber.py show  --all       [-H host] [-u cred]
  manage-subscriber.py set   <imsi>      [field options]  [-H host] [-u cred]
  manage-subscriber.py reset <imsi>      [-H host] [-u cred]

Set options:
  --enabled BOOL         Enable/disable service
  --aka-k HEX            Set AKA K key
  --aka-opc HEX          Set AKA OPc key
  --multi-session BOOL   Set multiSession flag
  --balance-cents N      Set cents balance to N (replaces existing)
  --balance-data SIZE    Set data balance (replaces existing, e.g. 10G, 500M)
  --topup-cents N        Add N cents (additive)
  --topup-data SIZE      Add data (additive, e.g. 1G)
"""

import argparse
import json
import os
import sys
import base64
from urllib.request import Request, urlopen
from urllib.error import URLError


# --- OCS API client ---

class OCSClient:
    def __init__(self, host, credentials):
        self.base_url = f"http://{host}"
        user, password = credentials.split(":", 1)
        token = base64.b64encode(f"{user}:{password}".encode()).decode()
        self.auth_header = f"Basic {token}"

    def request(self, method, path, body=None, content_type=None):
        url = f"{self.base_url}{path}"
        data = json.dumps(body).encode() if body is not None else None
        req = Request(url, data=data, method=method)
        req.add_header("Authorization", self.auth_header)
        if method != "DELETE":
            req.add_header("Accept", "application/json")
        if content_type:
            req.add_header("Content-Type", content_type)
        elif body is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urlopen(req) as resp:
                raw = resp.read().decode()
                return resp.status, json.loads(raw) if raw else {}
        except URLError as e:
            if hasattr(e, "code"):
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

    def patch(self, path, operations):
        return self.request("PATCH", path, operations,
                            content_type="application/json-patch+json")

    def delete(self, path):
        return self.request("DELETE", path)


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
    n = int(str(octets).rstrip("b"))
    if n >= 1_000_000_000:
        return f"{n / 1_000_000_000:.1f} GB"
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f} MB"
    if n >= 1_000:
        return f"{n / 1_000:.1f} KB"
    return f"{n} B"


def format_cents(cents):
    n = int(cents)
    if n >= 0:
        return f"${n / 100:.2f}"
    return f"-${abs(n) / 100:.2f}"


def parse_bool(s):
    return s.lower() in ("true", "1", "yes")


def get_subscriber(ocs, imsi):
    """Fetch service, product, and buckets for an IMSI."""
    status, service = ocs.get(f"/serviceInventoryManagement/v2/service/{imsi}")
    if status != 200:
        print(f"ERROR: Service not found for IMSI {imsi} (HTTP {status})")
        sys.exit(1)

    product_id = service.get("product")
    product = None
    buckets = []

    if product_id:
        status, product = ocs.get(
            f"/productInventoryManagement/v2/product/{product_id}")
        if status != 200:
            product = None

        _, all_buckets = ocs.get("/balanceManagement/v1/bucket")
        for b in all_buckets:
            prod = b.get("product", {})
            pid = prod.get("id", "") if isinstance(prod, dict) else ""
            if pid == product_id:
                buckets.append(b)

    return service, product, buckets


# --- show ---

def cmd_show_all(ocs):
    """Show all subscribers as a table."""
    _, services = ocs.get("/serviceInventoryManagement/v2/service")
    _, products = ocs.get("/productInventoryManagement/v2/product")

    # Index products by their realizing service IDs
    prod_by_svc = {}
    for p in products:
        for s in p.get("realizingService", []):
            prod_by_svc.setdefault(s.get("id", ""), []).append(p)

    rows = []
    for svc in services:
        imsi = svc.get("id", "")
        enabled = svc.get("isServiceEnabled", "?")
        chars = {c["name"]: c.get("value", "")
                 for c in svc.get("serviceCharacteristic", [])}

        # Aggregate balance from all products linked to this service
        data_bal = ""
        cents_bal = ""
        offering = ""
        for p in prod_by_svc.get(imsi, []):
            if not offering:
                offering = p.get("productOffering", {}).get("name",
                           p.get("productOffering", {}).get("id", ""))
            for bal in p.get("balance", []):
                tb = bal.get("totalBalance", {})
                if tb.get("units") == "octets":
                    data_bal = format_size(tb.get("amount", 0))
                elif tb.get("units") == "cents":
                    cents_bal = format_cents(tb.get("amount", 0))

        rows.append((imsi, str(enabled), offering, data_bal, cents_bal))

    rows.sort(key=lambda r: r[0])

    if not rows:
        print("No subscribers found.")
        return

    # Column headers
    hdrs = ("IMSI", "Enabled", "Offering", "Data", "Cents")
    # Compute column widths
    widths = [len(h) for h in hdrs]
    for row in rows:
        for i, val in enumerate(row):
            widths[i] = max(widths[i], len(val))

    fmt = "  ".join(f"{{:<{w}}}" for w in widths)
    print(fmt.format(*hdrs))
    print(fmt.format(*("-" * w for w in widths)))
    for row in rows:
        print(fmt.format(*row))
    print(f"\n{len(rows)} subscriber(s)")


def cmd_show(ocs, imsi):
    service, product, buckets = get_subscriber(ocs, imsi)
    chars = {c["name"]: c.get("value", "")
             for c in service.get("serviceCharacteristic", [])}

    print(f"=== Subscriber: {imsi} ===")
    print()
    print("Service:")
    print(f"  State:          {service.get('state', '?')}")
    print(f"  Enabled:        {service.get('isServiceEnabled', '?')}")
    print(f"  AKA-K:          {chars.get('serviceAkaK', 'N/A')}")
    print(f"  AKA-OPc:        {chars.get('serviceAkaOPc', 'N/A')}")
    print(f"  Multi-session:  {chars.get('multiSession', 'N/A')}")

    if product:
        offering = product.get("productOffering", {})
        print()
        print("Product:")
        print(f"  ID:             {product['id']}")
        print(f"  Offering:       {offering.get('name', offering.get('id', '?'))}")

        for bal in product.get("balance", []):
            tb = bal.get("totalBalance", {})
            units = tb.get("units", "?")
            amount = tb.get("amount", "?")
            if units == "octets":
                print(f"  Data balance:   {format_size(amount)} ({amount} octets)")
            elif units == "cents":
                print(f"  Cents balance:  {format_cents(amount)} ({amount} cents)")
            else:
                print(f"  {bal.get('name', units)} balance: {amount} {units}")
    else:
        print("\nProduct: (none)")

    if buckets:
        print()
        print("Buckets:")
        for b in buckets:
            ra = b.get("remainedAmount", {})
            units = ra.get("units", "?")
            amount = ra.get("amount", "?")
            expires = b.get("validFor", {}).get("endDateTime", "")

            if units == "octets":
                display = f"{format_size(amount)}"
            elif units == "cents":
                display = f"{format_cents(amount)}"
            else:
                display = f"{amount} {units}"

            exp_str = f"  (expires: {expires})" if expires else ""
            print(f"  {b['id']}  {units:<8s} {display}{exp_str}")
    else:
        print("\nBuckets: (none)")


# --- set ---

def cmd_set(ocs, imsi, args):
    service, product, buckets = get_subscriber(ocs, imsi)
    product_id = service.get("product")
    applied = []

    # -- Service-level changes --
    patch_ops = []

    if args.enabled is not None:
        val = parse_bool(args.enabled)
        patch_ops.append({"op": "replace", "path": "/isServiceEnabled", "value": val})
        applied.append(f"enabled -> {val}")

    if args.aka_k is not None or args.aka_opc is not None or args.multi_session is not None:
        chars = list(service.get("serviceCharacteristic", []))
        by_name = {c["name"]: c for c in chars}

        if args.aka_k is not None:
            if "serviceAkaK" in by_name:
                by_name["serviceAkaK"]["value"] = args.aka_k
            else:
                chars.append({"name": "serviceAkaK", "value": args.aka_k})
            applied.append(f"AKA-K -> {args.aka_k[:16]}...")

        if args.aka_opc is not None:
            if "serviceAkaOPc" in by_name:
                by_name["serviceAkaOPc"]["value"] = args.aka_opc
            else:
                chars.append({"name": "serviceAkaOPc", "value": args.aka_opc})
            applied.append(f"AKA-OPc -> {args.aka_opc[:16]}...")

        if args.multi_session is not None:
            val = parse_bool(args.multi_session)
            if "multiSession" in by_name:
                by_name["multiSession"]["value"] = val
            else:
                chars.append({"name": "multiSession", "value": val})
            applied.append(f"multiSession -> {val}")

        patch_ops.append({"op": "replace", "path": "/serviceCharacteristic",
                          "value": chars})

    if patch_ops:
        status, _ = ocs.patch(
            f"/serviceInventoryManagement/v2/service/{imsi}", patch_ops)
        if status != 200:
            print(f"ERROR: Service update failed (HTTP {status})")
            return

    # -- Balance set (replace: delete existing buckets, then topup) --
    if args.balance_cents is not None and product_id:
        for b in buckets:
            if b.get("remainedAmount", {}).get("units") == "cents":
                ocs.delete(f"/balanceManagement/v1/bucket/{b['id']}")
        status, _ = ocs.post(
            f"/balanceManagement/v1/product/{product_id}/balanceTopup",
            {"amount": {"amount": int(args.balance_cents), "units": "cents"}})
        if status == 201:
            applied.append(f"cents balance -> {args.balance_cents}")
        else:
            print(f"ERROR: Cents balance set failed (HTTP {status})")

    if args.balance_data is not None and product_id:
        octets = parse_size(args.balance_data)
        for b in buckets:
            if b.get("remainedAmount", {}).get("units") == "octets":
                ocs.delete(f"/balanceManagement/v1/bucket/{b['id']}")
        status, _ = ocs.post(
            f"/balanceManagement/v1/product/{product_id}/balanceTopup",
            {"amount": {"amount": octets, "units": "octets"}})
        if status == 201:
            applied.append(f"data balance -> {format_size(octets)}")
        else:
            print(f"ERROR: Data balance set failed (HTTP {status})")

    # -- Balance topup (additive) --
    if args.topup_cents is not None and product_id:
        status, _ = ocs.post(
            f"/balanceManagement/v1/product/{product_id}/balanceTopup",
            {"amount": {"amount": int(args.topup_cents), "units": "cents"}})
        if status == 201:
            applied.append(f"topped up {args.topup_cents} cents")
        else:
            print(f"ERROR: Cents topup failed (HTTP {status})")

    if args.topup_data is not None and product_id:
        octets = parse_size(args.topup_data)
        status, _ = ocs.post(
            f"/balanceManagement/v1/product/{product_id}/balanceTopup",
            {"amount": {"amount": octets, "units": "octets"}})
        if status == 201:
            applied.append(f"topped up {format_size(octets)}")
        else:
            print(f"ERROR: Data topup failed (HTTP {status})")

    if applied:
        print("Applied:")
        for a in applied:
            print(f"  {a}")
    else:
        print("Nothing to set. Use --help for available options.")


# --- reset ---

def cmd_reset(ocs, imsi):
    """Reset subscriber to offering defaults by re-provisioning."""
    service, product, buckets = get_subscriber(ocs, imsi)

    chars = {c["name"]: c.get("value", "")
             for c in service.get("serviceCharacteristic", [])}
    aka_k = chars.get("serviceAkaK")
    aka_opc = chars.get("serviceAkaOPc")
    offering_name = (product.get("productOffering", {}).get("id", "")
                     if product else "")

    if not offering_name:
        print("ERROR: Cannot determine product offering for reset")
        sys.exit(1)

    print(f"Resetting {imsi} to defaults (offering: {offering_name})")

    # 1. Delete buckets
    for b in buckets:
        ocs.delete(f"/balanceManagement/v1/bucket/{b['id']}")
    print(f"  Deleted {len(buckets)} bucket(s)")

    # 2. Delete service (unlocks product deletion)
    status, _ = ocs.delete(f"/serviceInventoryManagement/v2/service/{imsi}")
    if status not in (204, 404):
        print(f"  ERROR: Failed to delete service (HTTP {status})")
        sys.exit(1)
    print("  Deleted service")

    # 3. Delete product
    if product:
        status, _ = ocs.delete(
            f"/productInventoryManagement/v2/product/{product['id']}")
        if status not in (204, 404):
            print(f"  ERROR: Failed to delete product (HTTP {status})")
            sys.exit(1)
        print("  Deleted product")

    # 4. Re-create service with original AKA credentials
    svc_chars = [{"name": "serviceIdentity", "value": imsi}]
    if aka_k:
        svc_chars.append({"name": "serviceAkaK", "value": aka_k})
    if aka_opc:
        svc_chars.append({"name": "serviceAkaOPc", "value": aka_opc})

    status, _ = ocs.post("/serviceInventoryManagement/v2/service",
                         {"id": imsi, "serviceCharacteristic": svc_chars})
    if status != 201:
        print(f"  ERROR: Failed to re-create service (HTTP {status})")
        sys.exit(1)
    print("  Re-created service")

    # 5. Re-create product (OCS auto-creates buckets from offering)
    status, _ = ocs.post("/productInventoryManagement/v2/product", {
        "productOffering": {"id": offering_name},
        "realizingService": [{"id": imsi}],
    })
    if status != 201:
        print(f"  ERROR: Failed to re-create product (HTTP {status})")
        sys.exit(1)
    print("  Re-created product")

    # Show result
    print()
    cmd_show(ocs, imsi)


# --- Main ---

def main():
    parser = argparse.ArgumentParser(
        description="Manage provisioned data for a subscriber in SigScale OCS")
    parser.add_argument("-H", "--host",
                        default=os.environ.get("OCS_HOST", "localhost:8080"),
                        help="OCS host:port (default: localhost:8080)")
    parser.add_argument("-u", "--credentials",
                        default=os.environ.get("OCS_CRED", "admin:admin"),
                        help="OCS user:password (default: admin:admin)")

    sub = parser.add_subparsers(dest="command", required=True)

    p_show = sub.add_parser("show", help="Show provisioned data")
    p_show.add_argument("imsi", nargs="?", default=None,
                        help="Subscriber IMSI (omit with --all)")
    p_show.add_argument("--all", action="store_true",
                        help="Show all subscribers as a table")

    p_set = sub.add_parser("set", help="Update specific fields")
    p_set.add_argument("imsi")
    p_set.add_argument("--enabled", metavar="BOOL",
                       help="Enable/disable service (true/false)")
    p_set.add_argument("--aka-k", metavar="HEX", help="Set AKA K key")
    p_set.add_argument("--aka-opc", metavar="HEX", help="Set AKA OPc key")
    p_set.add_argument("--multi-session", metavar="BOOL",
                       help="Set multiSession (true/false)")
    p_set.add_argument("--balance-cents", metavar="N", type=int,
                       help="Set cents balance to N (replaces existing)")
    p_set.add_argument("--balance-data", metavar="SIZE",
                       help="Set data balance, e.g. 10G (replaces existing)")
    p_set.add_argument("--topup-cents", metavar="N", type=int,
                       help="Add N cents (additive)")
    p_set.add_argument("--topup-data", metavar="SIZE",
                       help="Add data, e.g. 1G (additive)")

    p_reset = sub.add_parser("reset",
                             help="Reset to offering defaults (re-provisions)")
    p_reset.add_argument("imsi")

    args = parser.parse_args()
    ocs = OCSClient(args.host, args.credentials)

    if args.command == "show":
        if getattr(args, "all", False):
            cmd_show_all(ocs)
            return
        if not args.imsi:
            print("ERROR: provide an IMSI or use --all")
            sys.exit(1)
        cmd_show(ocs, args.imsi)
    elif args.command == "set":
        cmd_set(ocs, args.imsi, args)
    elif args.command == "reset":
        cmd_reset(ocs, args.imsi)


if __name__ == "__main__":
    main()
