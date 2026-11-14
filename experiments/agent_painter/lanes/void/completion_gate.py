#!/usr/bin/env python3
"""Fail-closed, model-free promotion gate for the exact VOID fresh120 run.

A partial checkpoint is evidence, not a 120-step model. Verify original trainer
exit, summary, complete checkpoint inventory and optimizer-step receipts before
allowing DEVELOPMENT. This does not claim model quality or rerun optimization.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re

TARGET = 120
CHECKPOINT = "checkpoint-000120"
HEX64 = re.compile(r"[0-9a-f]{64}\Z")


def _sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def _read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def _checkpoint_guard(summary: dict, checkpoint: Path) -> dict:
    if checkpoint.name != CHECKPOINT or checkpoint.is_symlink() or not checkpoint.is_dir():
        raise ValueError("required complete checkpoint directory missing or symlinked")
    required_paths = {"inventory.json", "receipt.json", "training_state.pt",
                      "adapter/adapter_model.safetensors"}
    if not all((checkpoint / f).is_file() for f in required_paths):
        raise ValueError("complete checkpoint files missing")
    if not isinstance(summary.get("checkpoint_inventory_sha256"), str) or not HEX64.fullmatch(summary["checkpoint_inventory_sha256"]):
        raise ValueError("summary checkpoint inventory hash missing or invalid")
    if _sha(checkpoint / "inventory.json") != summary["checkpoint_inventory_sha256"]:
        raise ValueError("checkpoint inventory differs from completed training summary")
    inventory = _read_json(checkpoint / "inventory.json")
    if not isinstance(inventory, dict) or not required_paths.difference({"inventory.json"}).issubset(inventory):
        raise ValueError("checkpoint inventory is incomplete")
    actual = set()
    for path in checkpoint.rglob("*"):
        if path.is_symlink():
            raise ValueError("symlink in checkpoint inventory")
        if path.is_file():
            actual.add(path.relative_to(checkpoint).as_posix())
    if actual != set(inventory) | {"inventory.json"}:
        raise ValueError("checkpoint files and inventory disagree")
    for name, entry in inventory.items():
        parsed = PurePosixPath(name)
        if (not isinstance(name, str) or parsed.is_absolute() or
                not parsed.parts or any(p in (".", "..") for p in parsed.parts) or
                "\\" in name or parsed.as_posix() != name):
            raise ValueError("unsafe checkpoint inventory entry")
        path = checkpoint.joinpath(*parsed.parts)
        if not path.is_file() or path.is_symlink() or not isinstance(entry, dict):
            raise ValueError("checkpoint inventory entry is not a regular file")
        if (type(entry.get("bytes")) is not int or entry["bytes"] != path.stat().st_size or
                not isinstance(entry.get("sha256"), str) or not HEX64.fullmatch(entry["sha256"]) or
                _sha(path) != entry["sha256"]):
            raise ValueError("checkpoint content hash or length mismatch: " + name)
    receipt = _read_json(checkpoint / "receipt.json")
    if (not isinstance(receipt, dict) or type(receipt.get("global_step")) is not int or
            receipt["global_step"] != TARGET or type(receipt.get("sample_cursor")) is not int or
            receipt["sample_cursor"] != TARGET or receipt.get("config") != summary.get("config") or
            receipt.get("frozen_base_sha256") != summary.get("frozen_base_sha256")):
        raise ValueError("checkpoint step/cursor/config/base receipt differs from summary")
    history = receipt.get("history")
    if not isinstance(history, list) or len(history) != TARGET:
        raise ValueError("checkpoint history does not contain 120 optimizer receipts")
    if not isinstance(summary.get("sample_ids_this_job"), list) or len(summary["sample_ids_this_job"]) != TARGET:
        raise ValueError("summary sample IDs do not contain 120 training updates")
    for index, event in enumerate(history, 1):
        if (not isinstance(event, dict) or type(event.get("global_step")) is not int or
                event["global_step"] != index or type(event.get("sample_cursor")) is not int or
                event["sample_cursor"] != index or event.get("sample_id") != summary["sample_ids_this_job"][index - 1] or
                not isinstance(event.get("gradient_norm"), (float, int)) or
                isinstance(event["gradient_norm"], bool) or not math.isfinite(event["gradient_norm"]) or
                event["gradient_norm"] <= 0):
            raise ValueError("optimizer history step/cursor/sample/gradient mismatch")
    return {"checkpoint_inventory_sha256": summary["checkpoint_inventory_sha256"],
            "verified_optimizer_receipts": len(history), "verified_checkpoint_files": len(inventory)}


def verify_completion(summary: dict, exit_code: int, checkpoint: Path) -> dict:
    if type(exit_code) is not int or exit_code != 0:
        raise ValueError("trainer exit must be zero; partial/failure is non-promotable")
    if not isinstance(summary, dict):
        raise ValueError("training summary must be a JSON object")
    required = {
        "schema_version": 1, "status": "completed", "global_step": TARGET,
        "optimizer_steps_this_job": TARGET, "sample_cursor": TARGET,
        "checkpoint": CHECKPOINT, "actual_training": True,
        "checkpoint_readback_exact": True, "frozen_base_unchanged": True,
        "adapter_changed": True, "resume": None, "native_execution": False,
        "model_quality_claim": False,
    }
    for key, expected in required.items():
        value = summary.get(key)
        if key not in summary or type(value) is not type(expected) or value != expected:
            raise ValueError(f"120-step qualification mismatch: {key}={value!r}")
    if (not isinstance(summary.get("adapter_before_sha256"), str) or
            not isinstance(summary.get("adapter_after_sha256"), str) or
            not HEX64.fullmatch(summary["adapter_before_sha256"]) or
            not HEX64.fullmatch(summary["adapter_after_sha256"]) or
            summary["adapter_before_sha256"] == summary["adapter_after_sha256"]):
        raise ValueError("adapter change receipt is absent or inconsistent")
    verified = _checkpoint_guard(summary, checkpoint)
    return {"status": summary["status"], "actual_steps": summary["global_step"],
            "checkpoint": summary["checkpoint"], "wall_seconds": summary.get("wall_seconds"),
            "peak_rss_kib": summary.get("peak_rss_kib"), "promotable": True, **verified}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--exit-code", type=int, required=True)
    parser.add_argument("--checkpoint", type=Path, required=True)
    args = parser.parse_args()
    summary = _read_json(args.summary)
    print(json.dumps(verify_completion(summary, args.exit_code, args.checkpoint), sort_keys=True))


if __name__ == "__main__":
    main()
