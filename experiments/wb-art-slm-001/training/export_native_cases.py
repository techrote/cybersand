#!/usr/bin/env python3
"""Export strict raw model predictions for native replay without altering them.

The replay harness prepends ``slm-pilot-`` when saving; its Workbench save-name
limit therefore requires each exported ID to be at most 38 safe characters.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

from infer import load_compiler
from train_lora import canonical, sha256_file, strict_json, write_json

MAX_CASE_ID = 38
SAFE_ID = re.compile(r"[A-Za-z0-9_-]+\Z")


def replay_case_id(prefix: str, prediction_id: str, seed: int) -> tuple[str, str]:
    """Return a stable bounded replay ID and the *unmodified* original ID.

    Prefer readable IDs when safe; otherwise use a content-addressed alias.
    Include all original bytes, prefix and seed in the digest, even if the
    readable prefix is shortened. The caller rejects collisions globally.
    """
    if not isinstance(prefix, str) or not SAFE_ID.fullmatch(prefix):
        raise ValueError("Replay prefix must be nonempty ASCII letters, digits, '_' or '-'")
    if not isinstance(prediction_id, str) or not prediction_id:
        raise ValueError("Original prediction ID must be nonempty text")
    if type(seed) is not int or not 0 <= seed <= 2**63 - 1:
        raise ValueError("Host replay seed must be in 0..2**63-1")
    original = f"{prefix}-{prediction_id}-s{seed}"
    if len(original) <= MAX_CASE_ID and SAFE_ID.fullmatch(original):
        return original, original
    identity = json.dumps([prefix, prediction_id, seed], ensure_ascii=False, separators=(",", ":"))
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()
    stem = prefix[:10]
    suffix = f"-s{seed}"
    # A very long integer seed remains supported without exceeding the name cap.
    if len(stem) + len(suffix) + 17 > MAX_CASE_ID:
        alias = "case-" + digest[:32]
    else:
        alias = f"{stem}-{digest[:MAX_CASE_ID - len(stem) - len(suffix) - 1]}{suffix}"
    if len(alias) > MAX_CASE_ID or not SAFE_ID.fullmatch(alias):
        raise AssertionError("Generated replay ID exceeded the native save-name contract")
    return alias, original


def export_predictions(evaluation: dict, config: dict, compiler, seeds: list[int], prefix: str) -> dict:
    """Generate a complete auditable fixture, keeping every rejection in scope.

    All seeds for a single accepted request compile *before* any are admitted.
    This prevents a partially exported request masquerading as full replay.
    """
    if not isinstance(seeds, list) or not seeds or len(set(seeds)) != len(seeds):
        raise ValueError("Replay seeds must be nonempty and distinct")
    replay_case_id(prefix, "preflight", seeds[0])
    records = evaluation.get("records")
    if not isinstance(records, list) or not records:
        raise ValueError("No raw evaluation records")
    if len({r["id"] for r in records}) != len(records):
        raise ValueError("Duplicate original prediction IDs")
    summary = evaluation.get("summary", {})
    if not isinstance(summary, dict) or summary.get("count") != len(records):
        raise ValueError("Raw evaluation denominator differs from its summary")
    cases, excluded, aliases = [], [], {}
    accepted = 0
    for row in records:
        original_id = row["id"]
        try:
            if any(row.get(key) is not True for key in ("first_pass_accepted", "eos_emitted", "json_valid", "program_valid")):
                raise ValueError("Prediction lacks strict complete first-pass acceptance/EOS")
            program = strict_json(row["completion"])
            compiler.validate_program(program)
            temporary_cases, temporary_aliases = [], {}
            for seed in seeds:
                case_id, original_case_id = replay_case_id(prefix, original_id, seed)
                if case_id in aliases or case_id in temporary_aliases:
                    raise ValueError("Duplicate or colliding replay case ID: " + case_id)
                report = compiler.compile_with_report(program, 96, 96, seed)
                temporary_cases.append({**report, "id": case_id, "kind": "model-prediction",
                                        "theme": row["theme"], "predicted_theme": program["theme"],
                                        "prompt": row["prompt"], "raw_completion": row["completion"],
                                        "split": config.get("suite", "dev"), "group_id": row["group_id"],
                                        "prediction_id": original_id, "program": program,
                                        "operations_sha256": hashlib.sha256(canonical(report["operations"]).encode()).hexdigest()})
                temporary_aliases[case_id] = {"prediction_id": original_id,
                                              "original_case_id": original_case_id,
                                              "seed": seed, "aliased": case_id != original_case_id}
            cases.extend(temporary_cases)
            aliases.update(temporary_aliases)
            accepted += 1
        except (ValueError, TypeError, KeyError) as exc:
            excluded.append({"id": original_id, "error": str(exc)})
    if accepted + len(excluded) != len(records) or len(cases) != accepted * len(seeds):
        raise AssertionError("Exported native denominator is inconsistent")
    return {"cases": cases, "excluded_predictions": excluded,
            "case_id_aliases": aliases,
            "counts": {"raw_requests": len(records), "raw_first_pass_accepted": sum(r.get("first_pass_accepted") is True for r in records),
                       "replay_eligible_requests": accepted, "excluded_requests": len(excluded),
                       "replay_cases": len(cases), "seeds_per_request": len(seeds)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evaluation", type=Path, required=True)
    parser.add_argument("--run-config", type=Path, required=True)
    parser.add_argument("--adapter", type=Path)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--seeds", type=int, nargs="+", default=[17, 73])
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError("Refusing to overwrite native replay evidence: " + str(args.output))
    compiler = load_compiler(args.compiler)
    config = json.loads(args.run_config.read_text(encoding="utf-8"))
    if sha256_file(args.compiler) != config["compiler_sha256"]:
        raise ValueError("Compiler differs from the evaluated training contract")
    evaluation = json.loads(args.evaluation.read_text(encoding="utf-8"))
    bundle = export_predictions(evaluation, config, compiler, args.seeds, args.prefix)
    bundle["manifest"] = {"model_id": config["model_id"], "revision": config["revision"],
                          "evaluation_sha256": sha256_file(args.evaluation),
                          "run_config_sha256": sha256_file(args.run_config),
                          "compiler_sha256": config["compiler_sha256"],
                          "adapter_sha256": sha256_file(args.adapter / "adapter_model.safetensors") if args.adapter else None,
                          "native_execution": "pending; this file only requests replay",
                          "no_json_repair": True, "max_native_case_id_length": MAX_CASE_ID,
                          "native_save_prefix": "slm-pilot-"}
    write_json(args.output, bundle)
    print(json.dumps({**bundle["counts"], "path": str(args.output)}))


if __name__ == "__main__":
    main()
