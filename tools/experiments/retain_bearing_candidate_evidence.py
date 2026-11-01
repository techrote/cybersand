"""Retain complete qualified JSON evidence, excluding redundant JSONL and logs.

Capsule parts retain every parsed native capsule value. The original native
JSONL text and process logs stay in the local acquisition directories. No source
acquisition file is edited or removed. Output must be new.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil

from bearing_candidate_qualification import qualify, read, sha


def retain(source, output):
    source, output = Path(source).resolve(), Path(output).resolve()
    if output.exists() or output.is_relative_to(source):
        raise ValueError("new output outside frozen acquisition required")
    qualified = qualify(source)
    output.mkdir(parents=True)
    index = {"schema": 1, "qualification_pass": qualified["pass"], "cases": {},
             "capsules": "Every attempt retained in original sealed <=500-capsule JSON parts; no deduplication/drop.",
             "local_only": "Original native events.jsonl text and process logs remain at source. JSON parts preserve all parsed capsule values with additive identity/provenance fields.",
             "ownership": "Successful immutable artifacts may be hard-linked locally; no input mutation or deletion. Git checkouts contain ordinary files."}
    for mode in ("B0", "Y1", "A2"):
        for arm in ("speed0", "speed30", "speed90", "excavation", "hard", "water"):
            for details in ("on", "off"):
                name = "-".join((mode, arm, details))
                original, target = source/name, output/name
                target.mkdir()
                paths = sorted(original.glob("*.json"))
                for path in paths:
                    try:
                        os.link(path, target/path.name)
                    except OSError:
                        shutil.copy2(path, target/path.name)
                receipt = read(original/"receipt.json")
                index["cases"][name] = {"source": receipt["source"], "tree": receipt["tree"],
                    "attempts": receipt["attempts"], "json_files": len(paths),
                    "json_bytes": sum(p.stat().st_size for p in paths),
                    "receipt_sha256": sha(target/"receipt.json"),
                    "original_native_jsonl_sha256": sha(original/"events.jsonl"),
                    "original_acquisition_directory": str(original)}
    # Re-run custody/neutrality against the retained copies, not just the source.
    retained = qualify(output)
    if retained != qualified:
        raise ValueError("retained evidence differs from qualified source")
    (output/"retention-index.json").write_text(json.dumps(index, indent=2)+"\n", encoding="utf-8", newline="\n")
    return index


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = retain(args.input, args.output)
    print(json.dumps({"cases": len(result["cases"]),
                      "attempts": sum(c["attempts"] for c in result["cases"].values()),
                      "json_files": sum(c["json_files"] for c in result["cases"].values()),
                      "json_bytes": sum(c["json_bytes"] for c in result["cases"].values())}))
