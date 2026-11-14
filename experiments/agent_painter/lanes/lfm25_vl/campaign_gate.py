#!/usr/bin/env python3
"""Fail-closed, model-free promotion gate for the historical fresh48/fresh120 CPU dose.

A partial training checkpoint is retained as evidence, never a completed
candidate. This gate validates original optimizer, source and checkpoint
receipts before inference. It does not inspect FINAL or judge painting quality.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import sys

TRAINING = Path(__file__).resolve().parents[2] / "training"
sys.path.insert(0, str(TRAINING))
from common import read_json, sha256_file, verify_checkpoint

SHA = re.compile(r"[a-f0-9]{40}\Z")
CORPUS_SOURCE = "633920373a3d406a2ede61ce4137c324f76be23b"
CORPUS_SHA = "2fdef5a3639606fb9af68319f9747a1de1e9a573da5c6197a2dcbc96579cb6cc"
MODEL_ID = "LiquidAI/LFM2.5-VL-450M"
MODEL_REVISION = "fc6221ca597f3315e4f82fc2df606783267b34ba"
ARMS = {"fresh48": 48, "fresh120": 120}


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def exact_int(value, expected):
    return type(value) is int and value == expected


def validate(summary, preflight, receipt, progress, *, arm, source_sha, run_id=None):
    """Pure receipt checks, separated for adversarial model-free tests."""
    require(arm in ARMS, "unknown fresh-dose arm")
    require(isinstance(source_sha, str) and SHA.fullmatch(source_sha), "bad source SHA")
    steps = ARMS[arm]
    require(summary.get("status") == "completed" and summary.get("actual_training") is True,
            "partial/non-training summary cannot be promoted")
    for key in ("global_step", "optimizer_steps_this_job", "sample_cursor"):
        require(exact_int(summary.get(key), steps), "incomplete summary " + key)
    require(summary.get("resume") is None, "fresh arms cannot use resumed checkpoints")
    require(summary.get("adapter_changed") is True
            and summary.get("frozen_base_unchanged") is True
            and summary.get("checkpoint_readback_exact") is True,
            "adapter/base/checkpoint integrity not demonstrated")
    require(summary.get("native_execution") is False
            and summary.get("model_quality_claim") is False,
            "training cannot claim native painting or model quality")
    require(summary.get("checkpoint") == f"checkpoint-{steps:06d}", "wrong final checkpoint")
    require(isinstance(summary.get("adapter_before_sha256"), str)
            and summary.get("adapter_before_sha256") != summary.get("adapter_after_sha256"),
            "adapter unchanged")
    config = summary.get("config")
    require(isinstance(config, dict), "missing training config")
    require(config.get("profile") == "lfm25_vl" and config.get("source_sha") == source_sha,
            "source/profile mismatch")
    require(config.get("native_source_sha") == CORPUS_SOURCE
            and config.get("corpus_manifest_sha256") == CORPUS_SHA,
            "native corpus identity mismatch")
    model = config.get("model")
    require(isinstance(model, dict) and model.get("model_id") == MODEL_ID
            and model.get("revision") == MODEL_REVISION, "official model revision mismatch")
    numerics = config.get("numerics")
    require(isinstance(numerics, dict)
            and numerics.get("profile") == "portable-cpu-fp32-v1",
            "unqualified numerical recipe")
    require(config.get("device") == "cpu" and config.get("dtype") == "float32"
            and exact_int(config.get("threads"), 1), "CPU numerical boundary changed")
    require(config.get("final_targets_opened") is False, "FINAL access claimed")
    require(preflight.get("config") == config and preflight.get("resume") is None,
            "preflight configuration/resume mismatch")
    require(exact_int(preflight.get("train_rows"), 12)
            and exact_int(preflight.get("trainable_parameters"), 2998272),
            "TRAIN cohort or qualified LoRA boundary changed")
    require(receipt.get("config") == config, "checkpoint receipt config mismatch")
    for key in ("global_step", "sample_cursor"):
        require(exact_int(receipt.get(key), steps), "partial checkpoint " + key)
    require(receipt.get("frozen_base_sha256") == summary.get("frozen_base_sha256"),
            "frozen base identity mismatch")
    history = receipt.get("history")
    require(type(history) is list and len(history) == steps, "incomplete history")
    require(type(progress) is list and len(progress) == steps, "incomplete progress")
    require(history == progress, "checkpoint history differs from optimizer log")
    # Verify the original balanced cycle over 12 native-admitted TRAIN seed rows
    # (six independent structures). Repeating a single row is not a full dose.
    order = config.get("sample_order")
    require(type(order) is list and len(order) == 12
            and all(type(sample) is str and sample for sample in order)
            and len(set(order)) == 12, "invalid original TRAIN sampler inventory")
    observed = [event.get("sample_id") for event in progress]
    require(observed == [order[index % 12] for index in range(steps)],
            "optimizer sample order differs from original TRAIN sampler")
    require(summary.get("sample_ids_this_job") == observed, "sample order mismatch")
    for index, event in enumerate(progress, 1):
        require(isinstance(event, dict), "malformed optimizer event")
        require(exact_int(event.get("global_step"), index)
                and exact_int(event.get("sample_cursor"), index),
                "nonsequential optimizer event")
        for key in ("loss", "gradient_norm"):
            value = event.get(key)
            require(type(value) in (int, float) and math.isfinite(value)
                    and (value > 0 if key == "gradient_norm" else True),
                    "invalid optimizer " + key)
        require(type(event.get("loss_tokens")) is int and event["loss_tokens"] > 0,
                "missing supervised tokens")
        require(type(event.get("sequence_tokens")) is int
                and event["sequence_tokens"] >= event["loss_tokens"],
                "invalid supervised sequence length")
        for key in ("prompt_bytes", "completion_bytes"):
            require(type(event.get(key)) is int and event[key] > 0,
                    "invalid training payload " + key)
        elapsed = event.get("seconds")
        require(type(elapsed) in (int, float) and math.isfinite(elapsed) and elapsed >= 0,
                "invalid optimizer step duration")
    totals = {
        "loss_tokens_this_job": sum(e["loss_tokens"] for e in progress),
        "sequence_tokens_this_job": sum(e["sequence_tokens"] for e in progress),
        "bytes_this_job": sum(e["prompt_bytes"] + e["completion_bytes"] for e in progress),
    }
    for field, total in totals.items():
        require(exact_int(summary.get(field), total),
                "aggregate TRAIN receipt mismatch: " + field)
    require(summary.get("first_loss") == progress[0]["loss"]
            and summary.get("last_loss") == progress[-1]["loss"],
            "TRAIN first/last loss mismatch")
    if run_id is not None:
        require(str(run_id).isdigit(), "invalid hosted run ID")
        runner = summary.get("runner")
        require(isinstance(runner, dict)
                and runner.get("github_run_id") == str(run_id),
                "hosted run lineage mismatch")


def check(output, *, arm, source_sha, run_id=None):
    require(output.is_dir() and not output.is_symlink(), "missing/symlinked output")
    require(arm in ARMS, "unrecognized dose arm")
    summary = read_json(output / "summary.json")
    preflight = read_json(output / "preflight.json")
    checkpoint = output / f"checkpoint-{ARMS[arm]:06d}"
    require(checkpoint.is_dir() and not checkpoint.is_symlink(),
            "missing/symlinked final checkpoint")
    receipt = verify_checkpoint(checkpoint)  # Full inventory and file bytes.
    require(sha256_file(checkpoint / "inventory.json")
            == summary.get("checkpoint_inventory_sha256"),
            "checkpoint inventory digest mismatch")
    with (output / "progress.jsonl").open(encoding="utf-8") as stream:
        progress = [json.loads(line) for line in stream if line.strip()]
    validate(summary, preflight, receipt, progress, arm=arm,
             source_sha=source_sha, run_id=run_id)
    print(json.dumps({"arm": arm, "source_sha": source_sha,
                      "global_step": ARMS[arm], "model_quality_claim": False,
                      "status": "training-completion-and-custody-pass"}, sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--arm", choices=sorted(ARMS), required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--run-id")
    args = parser.parse_args()
    check(args.output, arm=args.arm, source_sha=args.source_sha, run_id=args.run_id)


if __name__ == "__main__":
    main()
