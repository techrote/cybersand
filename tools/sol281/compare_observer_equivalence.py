#!/usr/bin/env python3
"""Compare retained and optimized native observer outputs on the same frozen inputs.

Run the identical godot/tests/support/sol364_observer_equivalence.gd with each
runtime. The fixture removes only observation_ms, native_geometry_ms,
native_payload_freeze_ms and payload_immutability from its equivalence_records.
Every other geometry, ownership, counter and refusal field must match exactly.
This is semantic equivalence evidence, not a CPU or physical acceptance gate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    inputs = {}
    failures = []
    for name, path in [("baseline", args.baseline), ("candidate", args.candidate)]:
        raw = path.read_bytes()
        report = json.loads(raw)
        inputs[name] = {"path":path.as_posix(), "sha256":hashlib.sha256(raw).hexdigest(),
                        "report":report}
        if report.get("schema") != "cybersand.sol281.contact-observation-test.v1":
            failures.append(f"{name}: wrong schema")
        if report.get("checks") != 129 or report.get("failures") != []:
            failures.append(f"{name}: original 129 checks did not all pass")
        if len(report.get("equivalence_records", [])) != 40:
            failures.append(f"{name}: expected all 40 frozen observations")
    a, b = inputs["baseline"]["report"], inputs["candidate"]["report"]
    for key in ["platform", "workers", "cases", "equivalence_records"]:
        if a.get(key) != b.get(key):
            failures.append(f"different {key}")
    result = {"schema":"sol364.observer-equivalence.v1", "passed":not failures,
              "failures":failures, "exact_observations":len(a.get("equivalence_records", [])),
              "original_checks_per_runtime":129,
              "ignored_native_fields":["observation_ms", "native_geometry_ms",
                                       "native_payload_freeze_ms", "payload_immutability"],
              "inputs":{k:{f:v for f,v in value.items() if f != "report"}
                        for k,value in inputs.items()},
              "scope":"Exact frozen native contact, geometry, ownership, probe and refusal values; not live CPU or physical acceptance."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps(result, indent=2))
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
