"""B4 read-only B3 initial-world signed-IN policy adversary (research only).

On an exact checkout of B3 PR #555, run:
python3 b3_seed_policy_adversary.py --model /path/to/handoff_contract.py

The checker refuses mismatched Git blobs. No native CyberSand code is imported.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

ACCEPTED_MAIN = "d4b18e7f06839b35c8f6a66195206da0f33c5fa3"
B3_HEAD = "acf7ce6e14bd7b0e46f61e308d1b42a8867829d8"
B3_BLOB = "fd389750d19a05d740e3f8894af514314d590780"

def git_blob_id(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()

def load_exact(path: Path):
    raw = path.read_bytes()
    blob = git_blob_id(raw)
    if blob != B3_BLOB:
        raise ValueError(f"SOURCE_MISMATCH expected {B3_BLOB} actual {blob}")
    spec = importlib.util.spec_from_file_location("b4_b3_seed_probe", path)
    if spec is None or spec.loader is None:
        raise ValueError("could not import exact B3 module")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    return mod

def probe(mod):
    cases = []
    for signed in (False, True):
        for vy in (-8, 0, 8):
            expected = signed or vy >= 0
            try:
                w = mod.World.start(
                    3, [mod.Record("water", mod.Owner.INERTIAL,
                                   mod.WHOLE_CELL, velocity_q256=(0, vy))],
                    signed_inertial_world_enabled=signed)
            except ValueError:
                admitted = False
            else:
                admitted = True
                w.assert_invariants()
                w.material_identity()
            cases.append(dict(signed_world=signed, vy_q256=vy,
                              expected_admission=expected,
                              observed_admission=admitted,
                              unsupported_seed_admitted=admitted and not expected))
    try:
        mod.World.start(3, [mod.Record("water", mod.Owner.INERTIAL, 255)],
                        signed_inertial_world_enabled=False)
    except ValueError:
        whole_cell_guard = True
    else:
        whole_cell_guard = False
    return cases, whole_cell_guard

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", type=Path, required=True)
    args = ap.parse_args()
    mod = load_exact(args.model)
    cases, whole_cell = probe(mod)
    result = dict(scope="research-model-only", accepted_main=ACCEPTED_MAIN,
                  b3_head=B3_HEAD, b3_blob=B3_BLOB,
                  exact_module_executed=True, whole_cell_guard=whole_cell,
                  seed_misadmissions=sum(c["unsupported_seed_admitted"] for c in cases),
                  cases=cases)
    print(json.dumps(result, sort_keys=True, indent=2))
    if not whole_cell:
        raise AssertionError("whole-cell negative control missing")
    if sum(c["unsupported_seed_admitted"] for c in cases) != 1:
        raise AssertionError("registered defect absent or unexpected; inspect changed source")

if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, AssertionError) as exc:
        print("INCONCLUSIVE:", exc, file=sys.stderr)
        sys.exit(2)
