#!/usr/bin/env python3
"""Read-only, source-matched SMOL terminal-EOS-v2 TRAIN census.

No model weights, optimizer, native execution, DEVELOPMENT or FINAL targets.
Actual multi-VM optimizer/continuation qualification remains a separate gate.
"""
from __future__ import annotations

import argparse
from collections import Counter
import os
from pathlib import Path
import subprocess

from common import (ROOT, SMOL_SUPERVISION_POLICY_V2, encode_row,
                    load_training_corpus, profile, read_json, sha256_file, write_json)

NATIVE_SOURCE = "633920373a3d406a2ede61ce4137c324f76be23b"
NATIVE_MANIFEST = "2fdef5a3639606fb9af68319f9747a1de1e9a573da5c6197a2dcbc96579cb6cc"
SYSTEM = "Return only one valid CyberSand painter program JSON object. Follow the requested structure. Do not set host seeds, material permissions or focus."


def qualify(native: Path, tokenizer_dir: Path, output: Path):
    from transformers import AutoTokenizer

    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if os.environ.get("GITHUB_SHA") != head or os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("source-matched hosted GitHub qualification required")
    chosen = profile("smol", require_supported=True)
    for name in ("config.json", "tokenizer.json", "tokenizer_config.json"):
        if sha256_file(tokenizer_dir / name) != chosen["required_hashes"][name]:
            raise ValueError("pinned SMOL tokenizer/config byte mismatch: " + name)
    if sha256_file(native / "admitted-corpus.json") != NATIVE_MANIFEST:
        raise ValueError("original native-admitted manifest changed")
    rows, manifest = load_training_corpus(native)
    if manifest["source_sha"] != NATIVE_SOURCE or len(rows) != 12:
        raise ValueError("unexpected native source/structural TRAIN row count")
    groups = {row["group_id"] for row in rows}
    families = Counter(row["family"] for row in rows)
    if len(groups) != 6 or families != {"greebles": 4, "pipework": 4, "architecture": 4}:
        raise ValueError("changed independent TRAIN structure/family allocation")

    tokenizer = AutoTokenizer.from_pretrained(
        str(tokenizer_dir), local_files_only=True, trust_remote_code=False)
    results = []
    for row in rows:
        old = encode_row(tokenizer, row, SYSTEM, 2048)
        new = encode_row(tokenizer, row, SYSTEM, 2048,
                         supervision_policy=SMOL_SUPERVISION_POLICY_V2)
        if (old["input_ids"][-2:] != [2, 198] or
                new["input_ids"] != old["input_ids"][:-1] or
                new["prefix_ids"] != old["prefix_ids"] or
                new["boundary"] != old["boundary"] or
                new["labels"] != old["labels"][:-1] or
                new["labels"][-1] != 2 or
                new["labels"][new["boundary"]:].count(2) != 1 or
                not new["supervised_eos_terminal"] or
                new["completion_bytes"] != old["completion_bytes"]):
            raise ValueError("SMOL v2 changed more than presentation LF: " + row["id"])
        results.append({"id": row["id"], "family": row["family"], "group_id": row["group_id"],
                        "old_tokens": len(old["input_ids"]), "new_tokens": len(new["input_ids"]),
                        "prefix_masked": new["boundary"], "supervised": new["target_tokens"],
                        "terminal_eos": True, "removed_token_id": 198})

    receipt = {"status": "PASS", "schema": "smol-upstream-terminal-eos-v2-qualification-v1",
               "policy": SMOL_SUPERVISION_POLICY_V2, "source_sha": head,
               "native_source_sha": NATIVE_SOURCE, "native_manifest_sha256": NATIVE_MANIFEST,
               "model_id": chosen["model_id"], "model_revision": chosen["revision"],
               "tokenizer_hashes": {k: chosen["required_hashes"][k] for k in
                                    ("config.json", "tokenizer.json", "tokenizer_config.json")},
               "train_rows": len(rows), "train_structures": len(groups),
               "train_families": dict(families), "rows": results,
               "weights_downloaded": False, "optimizer_steps": 0, "new_native_execution": False,
               "development_targets_opened": False, "final_targets_opened": False,
               "shared_train_groups_added": 0, "model_quality_claim": False,
               "native_admission_claim": False, "multi_vm_continuation_qualified": False}
    write_json(output, receipt)
    print(f"SMOL v2 genuine tokenizer and original TRAIN rows: {len(rows)}/12 PASS; no training",
          flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", type=Path, required=True)
    parser.add_argument("--tokenizer", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    qualify(args.native, args.tokenizer, args.output)
