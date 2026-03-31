#!/usr/bin/env python3
"""
Provision open5gs PCRF subscribers from CSV files.

Reads keys.csv (ICCID,IMSI,KI,OPC) and IMSI_Provision_*.csv (ICCID,IMSI,MSISDN,...)
joins on IMSI, and upserts each subscriber into the open5gs MongoDB.

Usage:
    python3 provision-pcrf.py [--source-dir provision] [--db-host 127.0.0.1]
"""
import argparse
import csv
import os
import sys

from pymongo import MongoClient

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def load_keys(path):
    """Return dict: IMSI -> {ki, opc}"""
    keys = {}
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            keys[row["IMSI"]] = {
                "ki": row["KI"].upper(),
                "opc": row["OPC"].upper(),
            }
    return keys


def load_imsi_provision(path):
    """Return dict: IMSI -> {msisdn}"""
    subs = {}
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            subs[row["IMSI"]] = {
                "msisdn": row["MSISDN"],
            }
    return subs


def build_subscriber(imsi, msisdn, ki, opc):
    return {
        "schema_version": 1,
        "imsi": imsi,
        "msisdn": [msisdn],
        "security": {
            "k": ki,
            "opc": opc,
            "op": None,
            "amf": "8000",
        },
        "ambr": {
            "downlink": {"value": 1000000000, "unit": 0},
            "uplink": {"value": 1000000000, "unit": 0},
        },
        "slice": [{
            "sst": 1,
            "default_indicator": True,
            "session": [{
                "name": "internet",
                "type": 3,
                "qos": {
                    "index": 9,
                    "arp": {
                        "priority_level": 8,
                        "pre_emption_capability": 1,
                        "pre_emption_vulnerability": 2,
                    },
                },
                "ambr": {
                    "downlink": {"value": 1, "unit": 3},
                    "uplink": {"value": 1, "unit": 3},
                },
                # "pcc_rule": [{
                #     "flow": [
                #         {"direction": 1,
                #          "description": "permit out ip from any to 10.45.0.0/16"},
                #         {"direction": 2,
                #          "description": "permit out ip from 10.45.0.0/16 to any"},
                #     ],
                #     "qos": {
                #         "index": 9,
                #         "arp": {
                #             "priority_level": 8,
                #             "pre_emption_capability": 1,
                #             "pre_emption_vulnerability": 2,
                #         },
                #     },
                # }],
            }],
        }],
        "access_restriction_data": 32,
        "subscriber_status": 0,
        "network_access_mode": 0,
        "operator_determined_barring": 0,
        "subscribed_rau_tau_timer": 12,
    }


def main():
    parser = argparse.ArgumentParser(description="Provision open5gs subscribers from CSV files")
    parser.add_argument("--source-dir", default=os.path.join(SCRIPT_DIR, "provision"),
                        help="Directory containing keys.csv and IMSI_Provision_*.csv (default: provision/)")
    parser.add_argument("--db-host", default="127.0.0.1")
    parser.add_argument("--db-port", type=int, default=27017)
    parser.add_argument("--keys", default=None,
                        help="Path to keys.csv (default: <source-dir>/keys.csv)")
    parser.add_argument("--imsi-provision", default=None,
                        help="Path to IMSI_Provision_*.csv (auto-detected from source-dir if omitted)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be done without writing to DB")
    args = parser.parse_args()

    source_dir = os.path.abspath(args.source_dir)
    if not os.path.isdir(source_dir):
        print(f"ERROR: Source directory not found: {source_dir}", file=sys.stderr)
        sys.exit(1)

    # Resolve keys file
    if args.keys is None:
        args.keys = os.path.join(source_dir, "keys.csv")
    if not os.path.isfile(args.keys):
        print(f"ERROR: Keys file not found: {args.keys}", file=sys.stderr)
        sys.exit(1)

    # Auto-detect IMSI provision file
    if args.imsi_provision is None:
        for f in os.listdir(source_dir):
            if f.startswith("IMSI_Provision") and f.endswith(".csv"):
                args.imsi_provision = os.path.join(source_dir, f)
                break
    if args.imsi_provision is None:
        print(f"ERROR: No IMSI_Provision_*.csv found in {source_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"Source dir:     {source_dir}")
    print(f"Keys file:      {args.keys}")
    print(f"Provision file: {args.imsi_provision}")

    keys = load_keys(args.keys)
    provisions = load_imsi_provision(args.imsi_provision)

    # Join on IMSI
    imsis = sorted(set(keys.keys()) & set(provisions.keys()))
    if not imsis:
        print("ERROR: No matching IMSIs between keys.csv and provision CSV", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(imsis)} subscribers to provision")

    if args.dry_run:
        for imsi in imsis[:3]:
            print(f"  [dry-run] {imsi}  MSISDN={provisions[imsi]['msisdn']}  K={keys[imsi]['ki']}")
        if len(imsis) > 3:
            print(f"  ... and {len(imsis) - 3} more")
        return

    client = MongoClient(args.db_host, args.db_port)
    db = client.open5gs

    added = 0
    updated = 0
    for imsi in imsis:
        k = keys[imsi]
        p = provisions[imsi]
        doc = build_subscriber(imsi, p["msisdn"], k["ki"], k["opc"])

        result = db.subscribers.update_one(
            {"imsi": imsi},
            {"$set": doc},
            upsert=True,
        )
        if result.upserted_id:
            added += 1
        elif result.modified_count:
            updated += 1

    print(f"Done: {added} added, {updated} updated, {len(imsis) - added - updated} unchanged")
    client.close()


if __name__ == "__main__":
    main()
