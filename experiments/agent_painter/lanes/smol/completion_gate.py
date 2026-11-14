#!/usr/bin/env python3
"""Fail-closed SMOL fresh120 training promotion gate; partial checkpoints remain evidence.

This is purely model-free and does not inspect TRAIN/DEVELOPMENT/FINAL examples.
The existing native workflow must not run DEVELOPMENT/native replay unless the
one fresh 120-step training job completed its exact requested global target.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

TARGET = 120
CHECKPOINT = "checkpoint-000120"
NATIVE_SOURCE = "633920373a3d406a2ede61ce4137c324f76be23b"
CORPUS = "2fdef5a3639606fb9af68319f9747a1de1e9a573da5c6197a2dcbc96579cb6cc"


def _require(obj, key, expected):
    value = obj.get(key)
    if type(value) is not type(expected) or value != expected:
        raise ValueError(f"non-promotable SMOL fresh120: {key}: {value!r}, expected {expected!r}")


def verify_completion(training: Path, exit_code: int, source_sha: str) -> dict:
    if type(exit_code) is not int or exit_code != 0:
        raise ValueError("non-promotable SMOL fresh120: trainer exit must be 0; partial checkpoint is evidence only")
    if len(source_sha) != 40 or any(c not in "0123456789abcdef" for c in source_sha):
        raise ValueError("non-promotable SMOL fresh120: invalid exact source SHA")
    summary = json.loads((training / "summary.json").read_text(encoding="utf-8"))
    lane = json.loads((training / "lane-receipt.json").read_text(encoding="utf-8"))
    if type(summary) is not dict or type(lane) is not dict:
        raise ValueError("non-promotable SMOL fresh120: receipts must be objects")
    requirements = {
        "status": "completed",
        "actual_training": True,
        "global_step": TARGET,
        "sample_cursor": TARGET,
        "optimizer_steps_this_job": TARGET,
        "checkpoint": CHECKPOINT,
        "checkpoint_readback_exact": True,
        "frozen_base_unchanged": True,
        "adapter_changed": True,
        "resume": None,
        "native_execution": False,
        "model_quality_claim": False,
    }
    for k, v in requirements.items():
        _require(summary, k, v)
    for k, v in {
        "lane": "smol",
        "source_sha": source_sha,
        "target_global_steps": TARGET,
        "actual_training": True,
        "actual_global_step": TARGET,
        "optimizer_steps_this_job": TARGET,
        "checkpoint": CHECKPOINT,
        "checkpoint_readback_exact": True,
        "status": "completed",
        "exit_code": 0,
        "native_execution": False,
        "final_targets_opened": False,
    }.items():
        _require(lane, k, v)
    config = summary.get("config")
    if type(config) is not dict:
        raise ValueError("non-promotable SMOL fresh120: missing configuration")
    for k, v in {
        "source_sha": source_sha, "native_source_sha": NATIVE_SOURCE,
        "corpus_manifest_sha256": CORPUS, "profile": "smol",
    }.items():
        _require(config, k, v)
    checkpoint = training / CHECKPOINT
    if checkpoint.is_symlink() or not checkpoint.is_dir():
        raise ValueError("non-promotable SMOL fresh120: missing real checkpoint directory")
    for file in ("receipt.json", "inventory.json", "adapter/adapter_model.safetensors"):
        path = checkpoint / file
        if path.is_symlink() or not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"non-promotable SMOL fresh120: missing/empty checkpoint member {file}")
    inventory_hash = hashlib.sha256((checkpoint / "inventory.json").read_bytes()).hexdigest()
    _require(summary, "checkpoint_inventory_sha256", inventory_hash)
    receipt = json.loads((checkpoint / "receipt.json").read_text(encoding="utf-8"))
    for k, v in {"global_step": TARGET, "sample_cursor": TARGET, "config": config}.items():
        _require(receipt, k, v)
    return {
        "schema": "cybersand.agent-painter.smol-fresh120-promotion/1",
        "source_sha": source_sha, "completed_step": TARGET,
        "checkpoint": CHECKPOINT, "checkpoint_inventory_sha256": inventory_hash,
        "promotable": True, "training": False,
        "native_execution": False, "final_targets_accessed": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--training", type=Path, required=True)
    parser.add_argument("--exit-code", type=int, required=True)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    print(json.dumps(verify_completion(args.training, args.exit_code, args.source_sha), sort_keys=True))


if __name__ == "__main__":
    main()
