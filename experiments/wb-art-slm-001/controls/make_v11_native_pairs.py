"""Produce immutable-input, paired v1/v1.1 coral manifests for actual native replay.

Does NOT execute Godot or assert native pass. Output must be stored as a new
artifact; never replace a corpus manifest or historical replay input.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import pattern_compiler as v1
import pattern_compiler_v11 as v11


def make_pairs(width=96, height=96, seeds=(17, 73)):
    cases, aliases = [], {}
    for variant in range(8):
        program = v1.make_program("coral", variant)
        parent_id = f"reference-coral-v{variant}"
        for seed in seeds:
            matched = {}
            for tag, compiler in (("c10", v1), ("c11", v11)):
                case_id = f"{tag}-coral-v{variant}-s{seed}"
                if len(case_id) > 38:
                    raise ValueError("native save-name budget would be exceeded")
                report = compiler.compile_with_report(program, width, height, seed)
                operations = report["operations"]
                digest = hashlib.sha256(v1.canonical_json(operations).encode()).hexdigest()
                if not operations or report["program_sha256"] != hashlib.sha256(v1.canonical_json(program).encode()).hexdigest():
                    raise ValueError("compiler output or program binding invalid")
                cases.append({"id": case_id, "theme": "coral", "width": width, "height": height,
                              "seed": seed, "program_sha256": report["program_sha256"],
                              "operations_sha256": digest, "operations": operations})
                matched[tag] = {"case_id": case_id, "compiler_version": report["compiler_version"],
                                "operations_sha256": digest}
            aliases[f"{parent_id}-s{seed}"] = matched
    ids = [case["id"] for case in cases]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate native fixture case IDs")
    return {"schema_version": 1, "purpose": "not-yet-executed-v1-v11-coral-native-pair",
            "note": "Reference programs, not model predictions. Native success remains unclaimed.",
            "parent_compiler_sha256": v11.BASE_COMPILER_SHA256,
            "candidate_compiler_version": v11.COMPILER_VERSION,
            "aliases": aliases, "cases": cases}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--width", type=int, default=96)
    parser.add_argument("--height", type=int, default=96)
    args = parser.parse_args()
    result = make_pairs(args.width, args.height)
    data = (json.dumps(result, indent=2, allow_nan=False) + "\n").encode()
    # O_EXCL prevents a rerun silently overwriting evidence or a prior input.
    with args.out.open("xb") as handle:
        handle.write(data)
    print(json.dumps({"path": str(args.out), "cases": len(result["cases"]),
                      "aliases": len(result["aliases"]),
                      "sha256": hashlib.sha256(data).hexdigest(),
                      "native_executed": False}))


if __name__ == "__main__":
    main()
