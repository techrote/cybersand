#!/usr/bin/env python3
"""Measure a declared literal-keyword reference, separate from all model runs."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

from infer import load_compiler
from train_lora import balanced_rows, read_rows, sha256_file, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dev", type=Path, required=True)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--eval-count", type=int, default=24)
    args = parser.parse_args()
    compiler = load_compiler(args.compiler)
    rows = balanced_rows(read_rows(args.dev, "dev"), args.eval_count)
    outputs = []
    for row in rows:
        matches = [t for t in compiler.THEMES if re.search(r"\b" + re.escape(t) + r"\b", row["prompt"].lower())]
        record = {"id": row["id"], "prompt": row["prompt"], "requested_theme": row["theme"], "matched_keywords": matches, "program_valid": False, "theme_field_correct": False, "primary_motif_correct": False, "motif_layout_exact": False, "exact_target": False}
        if len(matches) == 1:
            program = compiler.make_program(matches[0])
            compiler.compile_program(program, 96, 96, int(row["seed"]))
            expected = json.loads(row["completion"])
            record.update({"program": program, "program_valid": True, "theme_field_correct": program["theme"] == row["theme"], "primary_motif_correct": program["layers"][0]["motif"] == expected["layers"][0]["motif"], "motif_layout_exact": [(l["motif"], l["layout"]) for l in program["layers"]] == [(l["motif"], l["layout"]) for l in expected["layers"]], "exact_target": program == expected})
        else:
            record["rejection"] = "Requires exactly one literal theme keyword; no synonym or model fallback"
        outputs.append(record)
    metrics = {key: sum(r[key] for r in outputs) for key in ("program_valid", "theme_field_correct", "primary_motif_correct", "motif_layout_exact", "exact_target")}
    exact_word_cases = [{"prompt": theme, "program": compiler.make_program(theme), "operation_count": len(compiler.compile_program(compiler.make_program(theme), 96, 96, 17))} for theme in compiler.THEMES]
    write_json(args.output, {"baseline": "literal-keyword fixed centered recipe", "method": "Exactly one whole-word theme keyword selects make_program(theme, variant_id=0). Layout/modifier language is ignored. No inference, repair or fallback.", "dev_sha256": sha256_file(args.dev), "compiler_sha256": sha256_file(args.compiler), "summary": {"count": len(outputs), **metrics, "native_execution": False}, "records": outputs, "exact_word_sanity": exact_word_cases})
    print(json.dumps({"count": len(outputs), **metrics, "exact_word_compiler_sanity": len(exact_word_cases)}))


if __name__ == "__main__":
    main()
