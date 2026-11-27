#!/usr/bin/env python3
"""Exact native SWARM005 V3 shared-territory regression; not owner graphical acceptance."""
import argparse
import json
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument("--exe", type=Path, required=True)
p.add_argument("--output", type=Path, required=True)
args = p.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
profiles = {
    "viaduct_like": (.65, .05, .15, 0.0, .55, .25, .35),
    "irregular_megastructure": (.65, .95, .25, 0.0, 1.0, .7, .2),
}
W, H, border, reach, seed = 192, 112, 4, 13, 605
source = "swarm005-v3-source-matched-regression"
rows = []
for expression, profile in profiles.items():
    for compact, supported in ((0, 0), (1, 0), (0, 1), (1, 1)):
        experiment = bool(compact or supported)
        prefix = f"{expression}-cap{compact}-receptor{supported}"
        options = " ".join(f"{v:.8f}" for v in profile)
        lines = ["SWARM005 3" if experiment else "SWARM004 1",
                 f"{W} {H} {seed} 0 0 2 {reach} -1", expression, options + " 1"]
        if experiment:
            lines.extend([options + " 1", f"{compact} {supported}"])
        lines.extend(["1", "64 48"])
        for y in range(H):
            for x in range(W):
                inside = border <= x < W-border and border <= y < H-border
                left = int(inside and x < W//2)
                right = int(inside and x >= W//2)
                shared = int(inside and W//2 - 1 - reach <= x <= W//2 + reach)
                lines.append(f"{left} {right} 0 {shared} 0")
        inp = args.output / (prefix + ".txt")
        out = args.output / (prefix + ".json")
        inp.write_text("\n".join(lines) + "\n")
        proc = subprocess.run([str(args.exe), "request", str(inp), str(out), source],
                              capture_output=True, text=True, timeout=90)
        assert proc.returncode == 0 and out.exists(), (prefix, proc.stderr)
        value = json.loads(out.read_text())
        opts = value["input"]["options"]
        assert value["source"] == source and value["schema"] == 5
        assert opts["compact_native_termination"] is bool(compact)
        assert opts["supported_native_receptors"] is bool(supported)
        assert opts["rounds"] == 2 and opts["shared_ownership"] is True
        still = int(value.get("metrics", {}).get("still_required", -1))
        applied = bool(value["can_apply"])
        status = value["status"]
        assert applied == (status == "complete" and still == 0), (prefix, status, still)
        if applied:
            assert value["cells"]
            assert all(o["state"] == "FOREIGN_JOINED" and o["foreign_joined"]
                       for o in value["obligations"]), prefix
        row = {"profile": expression, "compact": compact, "supported": supported,
               "status": status, "can_apply": applied, "still_required": still,
               "joints": len(value["joints"]),
               "native_material_cells": sum(int(x) != 0 for x in value["cells"])}
        rows.append(row)
        print(json.dumps(row), flush=True)
found = {(r["profile"], r["compact"], r["supported"]): r for r in rows}
assert found["irregular_megastructure", 0, 0]["status"] == "blocked"
assert found["irregular_megastructure", 1, 0]["can_apply"]
assert found["irregular_megastructure", 1, 1]["can_apply"]
assert found["viaduct_like", 1, 1]["status"] == "blocked"
reference = (args.output / "irregular_megastructure-cap1-receptor1.txt").read_text().splitlines()
for name in ("bad_bool", "swarm005_wrong_version", "swarm004_wrong_version", "trailing"):
    invalid = reference.copy()
    if name == "bad_bool":
        invalid[5] = "2 1"
    elif name == "swarm005_wrong_version":
        invalid[0] = "SWARM005 2"
    elif name == "swarm004_wrong_version":
        invalid[0] = "SWARM004 3"
    else:
        invalid.append("9999")
    inp = args.output / (name + ".txt")
    out = args.output / (name + ".json")
    inp.write_text("\n".join(invalid) + "\n")
    proc = subprocess.run([str(args.exe), "request", str(inp), str(out), source],
                          capture_output=True, text=True, timeout=20)
    assert proc.returncode != 0 and not out.exists(), name
(args.output / "summary.json").write_text(json.dumps(rows, indent=2) + "\n")
print("PASS SWARM005_V3_NATIVE_SHARED: eight paired native cases and four denied malformed requests")
