#!/usr/bin/env python3
"""Convert accepted raw model predictions to native replay inputs without repair."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from infer import load_compiler
from train_lora import canonical, sha256_file, strict_json, write_json
import hashlib


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
    compiler = load_compiler(args.compiler)
    config = json.loads(args.run_config.read_text())
    if sha256_file(args.compiler) != config["compiler_sha256"]:
        raise ValueError("Compiler differs from the evaluated training contract")
    evaluation = json.loads(args.evaluation.read_text())
    cases, excluded = [], []
    for row in evaluation["records"]:
        try:
            if row.get("first_pass_accepted") is not True:
                raise ValueError("Prediction not accepted on the strict first pass")
            program = strict_json(row["completion"])
            compiler.validate_program(program)
            for seed in args.seeds:
                report = compiler.compile_with_report(program, 96, 96, seed)
                cases.append({"id": f"{args.prefix}-{row['id']}-s{seed}", "kind": "model-prediction", "theme": row["theme"], "predicted_theme": program["theme"], "prompt": row["prompt"], "raw_completion": row["completion"], "split": config.get("suite", "dev"), "group_id": row["group_id"], "prediction_id": row["id"], "program": program, "operations_sha256": hashlib.sha256(canonical(report["operations"]).encode()).hexdigest(), **report})
        except (ValueError, TypeError, KeyError) as exc:
            excluded.append({"id": row["id"], "error": str(exc)})
    provenance = {"model_id": config["model_id"], "revision": config["revision"], "evaluation_sha256": sha256_file(args.evaluation), "run_config_sha256": sha256_file(args.run_config), "compiler_sha256": config["compiler_sha256"], "adapter_sha256": sha256_file(args.adapter / "adapter_model.safetensors") if args.adapter else None, "native_execution": "pending; this file only requests replay", "no_json_repair": True}
    write_json(args.output, {"manifest": provenance, "cases": cases, "excluded_predictions": excluded})
    print(json.dumps({"cases": len(cases), "excluded_predictions": len(excluded), "path": str(args.output)}))


if __name__ == "__main__":
    main()
