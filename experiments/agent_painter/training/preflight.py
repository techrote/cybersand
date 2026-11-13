#!/usr/bin/env python3
"""Bounded model preflight requests and genuine hosted evidence publication.

The unchanged admitted corpus retains its own native source identity. A newer
trainer never relabels that native execution as a build of the trainer commit.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import zipfile

from common import (COMMIT, ROOT, load_training_corpus, profile, read_json,
                    sha256_file, verify_checkpoint, write_json)
from lane_adapters import adapter_identity

NATIVE_SOURCE = "633920373a3d406a2ede61ce4137c324f76be23b"
CORPUS_RUN = "43506373969"
CORPUS_ARTIFACT = "agent-painter-native-" + NATIVE_SOURCE
CORPUS_SHA256 = "2fdef5a3639606fb9af68319f9747a1de1e9a573da5c6197a2dcbc96579cb6cc"


def request(path, source_sha):
    data = read_json(path)
    fixed = {"schema": "agent-painter-model-preflight-v1", "native_source_sha": NATIVE_SOURCE,
             "corpus_run_id": CORPUS_RUN, "corpus_artifact": CORPUS_ARTIFACT,
             "corpus_manifest_sha256": CORPUS_SHA256, "optimizer_steps": 2,
             "resume_from_step": 1, "resume_target_step": 2, "max_inference_tokens": 128,
             "full_training": False, "publish_research_evidence": True}
    if set(data) != set(fixed) | {"sequence", "profiles"}:
        raise ValueError("unexpected preflight request fields")
    for key, value in fixed.items():
        if type(data[key]) is not type(value) or data[key] != value:
            raise ValueError("unapproved preflight scope: " + key)
    lanes = data["profiles"]
    if (not isinstance(lanes, list) or not lanes or len(lanes) != len(set(lanes))
            or not set(lanes).issubset({"void", "sprocket", "lfm25_vl"})):
        raise ValueError("only the three requested model preflights are allowed")
    if type(data["sequence"]) is not int or not 1 <= data["sequence"] <= 1000:
        raise ValueError("bounded positive request sequence required")
    if not COMMIT.fullmatch(source_sha):
        raise ValueError("full source SHA required")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if head != source_sha:
        raise ValueError("preflight checkout differs from requested source")
    subprocess.run(["git", "merge-base", "--is-ancestor", NATIVE_SOURCE, head], cwd=ROOT, check=True)
    for lane in lanes:
        profile(lane, require_supported=True)
    return {"source_sha": head, "request_sha256": sha256_file(path), "request": data}


def package(directory, output, source_sha, lane):
    """Validate actual optimizer/checkpoint/inference evidence before publication."""
    selected = profile(lane, require_supported=True)
    if not COMMIT.fullmatch(source_sha) or output.exists():
        raise ValueError("immutable source and new publication directory required")
    run_id, attempt = os.environ.get("GITHUB_RUN_ID", ""), os.environ.get("GITHUB_RUN_ATTEMPT", "")
    if (os.environ.get("GITHUB_ACTIONS") != "true" or not re.fullmatch(r"[1-9][0-9]*", run_id)
            or not re.fullmatch(r"[1-9][0-9]*", attempt)):
        raise ValueError("hosted GitHub run and attempt identity required for publication")
    validated_request = request(ROOT / "preflight-request.json", source_sha)
    if lane not in validated_request["request"]["profiles"]:
        raise ValueError("publication lane is outside the explicit preflight request")
    rows, admission = load_training_corpus(directory / "native/corpus")
    if (admission["source_sha"] != NATIVE_SOURCE or len(rows) != 12
            or sha256_file(directory / "native/corpus/admitted-corpus.json") != CORPUS_SHA256):
        raise ValueError("preflight must consume the unchanged qualified TRAIN pilot")
    first_checkpoint = directory / "fresh/checkpoint-000001"
    first_receipt = verify_checkpoint(first_checkpoint)
    first_inventory = sha256_file(first_checkpoint / "inventory.json")
    expected_fresh_artifact = (f"agent-painter-preflight-{lane}-fresh-"
                               f"{os.environ.get('GITHUB_RUN_ID')}-{os.environ.get('GITHUB_RUN_ATTEMPT')}")
    summaries = {}
    for component, updates in (("fresh", 2), ("resume", 1)):
        folder = directory / component
        summary = read_json(folder / "summary.json")
        config = summary["config"]
        if (summary.get("status") != "completed" or summary.get("actual_training") is not True
                or summary.get("global_step") != 2 or summary.get("optimizer_steps_this_job") != updates
                or summary.get("checkpoint_readback_exact") is not True
                or summary.get("adapter_changed") is not True or summary.get("frozen_base_unchanged") is not True
                or config.get("source_sha") != source_sha or config.get("native_source_sha") != NATIVE_SOURCE
                or config.get("model") != selected or config.get("profile") != lane
                or config.get("corpus_manifest_sha256") != CORPUS_SHA256
                or config.get("compiler_sha256") != admission["compiler_sha256"]
                or config.get("trainer_sha256") != sha256_file(Path(__file__).with_name("train.py"))
                or config.get("contract_sha256") != sha256_file(Path(__file__).with_name("common.py"))
                or config.get("adapter_contract") != adapter_identity(selected)
                or config.get("final_targets_opened") is not False):
            raise ValueError("incomplete model-specific real training evidence: " + component)
        receipt = verify_checkpoint(folder / "checkpoint-000002")
        if (receipt["config"] != config or receipt["global_step"] != 2
                or summary["checkpoint_inventory_sha256"] != sha256_file(folder / "checkpoint-000002/inventory.json")):
            raise ValueError("summary does not bind the actual serialized checkpoint")
        preflight = read_json(folder / "preflight.json")
        masks = preflight["mask_checks"]
        if (preflight.get("config") != config or preflight.get("model_contract") != summary.get("model_contract")
                or preflight["train_rows"] != len(rows) or len(masks) != len(rows)
                or {item["id"] for item in masks} != {row["id"] for row in rows}
                or not all(item["supervised_eos"] is True and item["prompt_tokens"] > 0
                           and item["loss_tokens"] > 0 for item in masks)
                or not 1 <= preflight["max_sequence_tokens"] <= config["max_length"] <= selected["max_sequence_tokens"]):
            raise ValueError("incomplete full-target loss-mask evidence")
        origins = read_json(folder / "environment/artifact-origins.json")
        if (origins["source_sha"] != source_sha or origins["corpus"] != {"artifact": CORPUS_ARTIFACT, "run_id": CORPUS_RUN}
                or summary["runner"]["github_run_id"] != run_id
                or summary["runner"]["github_run_attempt"] != attempt):
            raise ValueError("hosted run or native artifact origin differs")
        if component == "resume":
            continuation = summary.get("resume") or {}
            if (continuation.get("from_step") != 1 or continuation.get("restored_all_state_exactly") is not True
                    or first_receipt.get("global_step") != 1 or first_receipt.get("config") != config
                    or continuation.get("inventory_sha256") != first_inventory
                    or (origins.get("resume") or {}).get("run_id") != os.environ.get("GITHUB_RUN_ID")
                    or origins["resume"].get("artifact") != expected_fresh_artifact
                    or origins["resume"]["checkpoint"] != "checkpoint-000001"):
                raise ValueError("fresh-runner full-state continuation is missing")
        summaries[component] = summary
    comparison = read_json(directory / "verification/resume-comparison.json")
    if (comparison.get("passed") is not True or comparison.get("global_step") != 2
            or comparison.get("atol") != 1e-6 or comparison.get("rtol") != 1e-5
            or comparison.get("fresh_inventory_sha256") != summaries["fresh"]["checkpoint_inventory_sha256"]
            or comparison.get("resumed_inventory_sha256") != summaries["resume"]["checkpoint_inventory_sha256"]):
        raise ValueError("actual checkpoint continuation comparison failed")
    inference = read_json(directory / "fresh/inference/receipt.json")
    raw = read_json(directory / "fresh/inference/raw-output.json")
    if (inference["model_id"] != selected["model_id"] or inference["model_revision"] != selected["revision"]
            or inference["adapter_sha256"] != sha256_file(directory / "fresh/checkpoint-000002/adapter/adapter_model.safetensors")
            or not 1 <= inference["output_tokens"] <= 128 or len(raw["token_ids"]) != inference["output_tokens"]
            or inference.get("native_execution") is not False or inference.get("visual_quality_claim") is not False):
        raise ValueError("bounded actual model inference evidence missing")
    output.mkdir(parents=True)
    assets = []
    for component in ("fresh", "resume", "verification"):
        folder = directory / component
        archive = output / f"agent-painter-{lane}-{component}-{source_sha[:12]}.zip"
        with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as target:
            for path in sorted(folder.rglob("*")):
                if path.is_symlink():
                    raise ValueError("symlink in evidence")
                if path.is_file() and "__pycache__" not in path.parts:
                    target.write(path, path.relative_to(folder).as_posix())
        assets.append({"file": archive.name, "sha256": sha256_file(archive), "bytes": archive.stat().st_size})
    manifest = {"schema": "agent-painter-model-preflight-release-v1", "passed": True,
                "source_sha": source_sha, "profile": lane, "model": selected,
                "native_source_sha": NATIVE_SOURCE, "corpus_manifest_sha256": CORPUS_SHA256,
                "corpus_run_id": CORPUS_RUN, "corpus_artifact": CORPUS_ARTIFACT,
                "workflow_run": os.environ.get("GITHUB_RUN_ID"), "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
                "optimizer_steps": {"fresh": 2, "resume": 1}, "comparison": comparison,
                "bounded_inference_accepted": inference["accepted"],
                "useful_painter_quality_claim": False, "native_rebuild_claim": False, "draft_hold": True,
                "assets": assets}
    write_json(output / "MANIFEST.json", manifest)
    (output / "SHA256SUMS.txt").write_text("".join(item["sha256"] + "  " + item["file"] + "\n" for item in assets), encoding="utf-8")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="mode", required=True)
    validate = sub.add_parser("request")
    validate.add_argument("--path", type=Path, default=ROOT / "preflight-request.json")
    validate.add_argument("--source-sha", required=True)
    validate.add_argument("--output", type=Path, required=True)
    publish = sub.add_parser("package")
    publish.add_argument("--directory", type=Path, required=True)
    publish.add_argument("--output", type=Path, required=True)
    publish.add_argument("--source-sha", required=True)
    publish.add_argument("--profile", required=True)
    args = parser.parse_args()
    if args.mode == "request":
        result = request(args.path, args.source_sha)
        write_json(args.output, result)
    else:
        result = package(args.directory, args.output, args.source_sha, args.profile)
    print(result)


if __name__ == "__main__":
    main()
