"""Deterministic proposed corpus; only native.py can positively admit it.

Adapts #567 corpus/build_corpus.py's generation/admission separation and
cross-split checks. No historical rows, labels or native receipts are reused.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

try:
    from .compiler import COMPILER_VERSION, canonical_json, compile_program, digest, structural_signature, validate_program
    from .recipes import SEEDS, all_recipes
except ImportError:
    from compiler import COMPILER_VERSION, canonical_json, compile_program, digest, structural_signature, validate_program
    from recipes import SEEDS, all_recipes

CORPUS_VERSION = "cybersand.agent-painter.pilot/1"


def validate_splits(rows: list[dict]) -> None:
    seen_ids, groups, programs, structures, prompts = set(), {}, {}, {}, {}
    for row in rows:
        if row["id"] in seen_ids:
            raise ValueError("duplicate corpus example ID")
        seen_ids.add(row["id"])
        split = row["split"]
        if split not in ("TRAIN", "DEVELOPMENT", "FINAL"):
            raise ValueError("unknown corpus partition")
        validate_program(row["program"])
        if row["family"] != row["program"]["family"]:
            raise ValueError("family differs from program")
        if row.get("group_id", row["structural_group"]) != row["structural_group"]:
            raise ValueError("structural group aliases disagree")
        if row.get("completion", canonical_json(row["program"])) != canonical_json(row["program"]):
            raise ValueError("completion differs from exact canonical program")
        program_hash = digest(row["program"])
        if row.get("program_sha256", program_hash) != program_hash:
            raise ValueError("program hash differs from program")
        # Variation/seed changes never create a new structural partition.
        signature = structural_signature(row["program"])
        if row.get("structural_signature_sha256", digest(signature)) != digest(signature):
            raise ValueError("structural signature differs from program")
        for seen, key in ((groups, row["structural_group"]), (programs, program_hash),
                          (structures, digest(signature)),
                          (prompts, row["prompt"].strip().casefold())):
            if key in seen and seen[key] != split:
                raise ValueError("structural group, program or prompt crosses a partition")
            seen[key] = split


def build_candidates(*, include_final: bool = True) -> dict:
    examples = []
    groups = []
    for recipe in all_recipes(include_final=include_final):
        groups.append({k: recipe[k] for k in ("group_id", "family", "design", "split")})
        for seed in SEEDS:
            compiled = compile_program(recipe["program"], seed=seed)
            example_id = recipe["group_id"].replace("/", "-")+f"-s{seed}"
            examples.append({**recipe, "id": example_id, "seed": seed,
                             "completion": canonical_json(recipe["program"]),
                             "program_sha256": compiled["program_sha256"],
                             "structural_signature_sha256": digest(structural_signature(recipe["program"])),
                             "operations_sha256": compiled["operations_sha256"],
                             "native_case_id": example_id, "compiled": compiled,
                             "origin": "new-deterministic-reference-teacher",
                             "native_qualified": False})
    validate_splits(examples)
    root = Path(__file__).parent
    return {"schema": "cybersand.agent-painter.candidates/1", "corpus_version": CORPUS_VERSION,
            "compiler_version": COMPILER_VERSION,
            "source_files_sha256": {name: hashlib.sha256((root/name).read_bytes()).hexdigest()
                                     for name in ("compiler.py", "recipes.py", "corpus.py", "program.schema.json")},
            "state": "native-admission-pending", "examples": examples, "groups": groups,
            "seeds": list(SEEDS), "native_case_count": len(examples),
            "distinct_program_count": len({e["program_sha256"] for e in examples}),
            "split_counts": dict(Counter(e["split"] for e in examples)),
            "group_counts": dict(Counter(g["split"] for g in groups)),
            "examples_sha256": digest(examples),
            "split_claim": "Disjoint named structural/compositional groups and exact programs; shared primitives remain shared. Seeds are replay variants, not independent designs.",
            "final_policy": "FINAL native admission checks mechanics only; no gallery display, trainer consumption, quality feedback or candidate selection until a final protocol is frozen."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--exclude-final", action="store_true")
    args = parser.parse_args()
    manifest = build_candidates(include_final=not args.exclude_final)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2, allow_nan=False)+"\n")
    print(canonical_json({k: manifest[k] for k in ("state", "native_case_count", "split_counts", "group_counts")}))


if __name__ == "__main__":
    main()
