#!/usr/bin/env python3
"""Independently replay the three original source/runtime/dependency closures."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_final_recovery"))
# The retained identity module installs its unchanged original reader paths.
from identity import ROOT as DRIVER_ROOT
from runtime_replay import verify_recorded_runtime
from run_campaign import source_identity
from run_source_abba import TOOLCHAIN_FIELDS
from results import need


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("runtime-root", "accepted-main", "owner-reference", "candidate"):
        parser.add_argument("--" + key, type=Path, required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    args = parser.parse_args()
    paths = {"M": args.accepted_main, "P": args.owner_reference, "C": args.candidate}
    records, inputs, dependencies = {}, {}, {}
    for role, path in paths.items():
        source = source_identity(path)
        directory = args.runtime_root / role
        records[role] = {"source": source, "runtime": verify_recorded_runtime(
            path, source, directory, target_platform=args.platform)}
        inputs[role] = json.loads((directory / "PUBPRES-RUNTIME.json").read_bytes())["source_inputs_sha256"]
        dependencies[role] = json.loads((directory / "GODOT-CPP-DEPENDENCY.json").read_bytes())["source_inputs_sha256"]
    for field in TOOLCHAIN_FIELDS:
        need(all(row["runtime"]["toolchain"][field] == records["C"]["runtime"]["toolchain"][field]
                 for row in records.values()), "Three-source compiler/dependency mismatch: " + field)
    need(all(v == dependencies["C"] for v in dependencies.values()), "Different generated/authored dependency inputs")
    delta = {role: {name: {"reference": ledger.get(name), "candidate": inputs["C"].get(name)}
                   for name in sorted(ledger.keys() | inputs["C"].keys()) if ledger.get(name) != inputs["C"].get(name)}
             for role, ledger in inputs.items() if role != "C"}
    result = {"schema": "pubpres-mainline-native-custody-v1", "platform": args.platform,
              "roles": records, "native_deltas": delta, "matched_toolchain_fields": list(TOOLCHAIN_FIELDS),
              "all_dependency_inputs_identical": True, "complete": True, "physical_acceptance": "HOLD",
              "scope": "Three independently built native sources; this receipt supplies no gameplay or physical acceptance."}
    (args.runtime_root / "MAINLINE-NATIVE-CUSTODY.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"complete": True, "platform": args.platform,
                      "sources": {k: v["source"]["source_commit"] for k, v in records.items()}}))


if __name__ == "__main__":
    main()
