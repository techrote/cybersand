#!/usr/bin/env python3
"""Verify and publish one immutable Smol DEVELOPMENT evidence packet.

No model is instantiated here. Checkpoint verification reads CPU tensors with
``weights_only=True`` and safetensors; native verification reduces actual saved
application receipts. Rejected model proposals remain publishable research.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import zipfile

import contracts
from contracts import common

LANE = Path(__file__).resolve().parent
PAINTER = LANE.parents[1]
REPOSITORY = "techrote/cybersand"
CORPUS_RUN = 43506373969
CORPUS_ARTIFACT = "agent-painter-native-" + contracts.FOUNDATION_SOURCE
ARMS = ("baseline", "candidate")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read(path):
    return common.read_json(path)


def sha(path):
    return common.sha256_file(path)


def verify_environments(directory, source, tree, run_id, attempt, request):
    """Bind both matrix jobs to this run and distinct ordinary hosted VMs."""
    receipts, downloads = {}, {}
    selected = common.profile("smol", require_supported=True)
    for arm in ARMS:
        folder = directory / arm / "environment"
        receipt = read(folder / "run-receipt.json")
        expected = {
            "schema_version": 1, "lane": "smol", "arm": arm,
            "repository": REPOSITORY, "source_sha": source, "source_tree": tree,
            "run_id": run_id, "run_attempt": attempt,
            "runner_environment": "github-hosted", "os": "Linux", "arch": "X64",
            "corpus": {"source_sha": contracts.FOUNDATION_SOURCE, "run_id": CORPUS_RUN,
                       "artifact": CORPUS_ARTIFACT},
            "model": {"model_id": contracts.MODEL_ID, "revision": contracts.MODEL_REVISION},
            "request": request,
        }
        require(all(receipt.get(key) == value for key, value in expected.items()),
                arm + ": environment/source/run/input custody mismatch")
        require(all(isinstance(receipt.get(key), str) and receipt[key]
                    for key in ("job_id", "runner_name", "hostname")),
                arm + ": missing VM identity")
        for name in ("cpu.txt", "pip-freeze.txt", "requirements.sha256"):
            require((folder / name).is_file() and (folder / name).stat().st_size > 0,
                    arm + ": missing runner installation evidence: " + name)
        lock = (folder / "requirements.sha256").read_text().split()
        require(bool(lock) and lock[0] == sha(PAINTER / "training/requirements.lock"),
                arm + ": installed requirement lock differs from source")
        download = read(folder / "model-download.json")
        require(download.get("model_id") == selected["model_id"]
                and download.get("revision") == selected["revision"]
                and download.get("trust_remote_code") is False,
                arm + ": model download pin mismatch")
        files = download.get("files", {})
        require(all(files.get(name, {}).get("sha256") == digest
                    for name, digest in selected["required_hashes"].items()),
                arm + ": model download bytes differ from reviewed pin")
        require(files and all(common.SHA256.fullmatch(str(item.get("sha256", "")))
                              and type(item.get("bytes")) is int and item["bytes"] > 0
                              for item in files.values()),
                arm + ": incomplete model download inventory")
        receipts[arm], downloads[arm] = receipt, download
    require(receipts["baseline"]["hostname"] != receipts["candidate"]["hostname"],
            "baseline and candidate must use separate hosted VMs")
    require(downloads["baseline"]["files"] == downloads["candidate"]["files"],
            "baseline and candidate model bytes differ")
    return receipts, downloads


def verify_evaluation(directory, arm, source, run_id, attempt, download):
    from lane_adapters import adapter_identity
    report = read(directory / "evaluation.json")
    require(report.get("schema_version") == 1 and report.get("kind") == "smol-development-first-pass"
            and report.get("arm") == arm and report.get("source_sha") == source,
            arm + ": evaluation identity mismatch")
    require(report.get("final_targets_opened") is False
            and report.get("native_execution") is False and report.get("visual_quality_claim") is False,
            arm + ": evaluation authority/custody claim mismatch")
    runner = report.get("runner", {})
    require(str(runner.get("github_run_id")) == str(run_id)
            and str(runner.get("github_run_attempt")) == str(attempt),
            arm + ": evaluation run/attempt mismatch")
    require(report.get("model") == common.profile("smol", require_supported=True)
            and report.get("model_id") == contracts.MODEL_ID
            and report.get("model_revision") == contracts.MODEL_REVISION
            and report.get("compiler_sha256") == contracts.COMPILER_SHA256,
            arm + ": evaluation model/compiler mismatch")
    corpus = report.get("corpus", {})
    require(corpus.get("manifest_sha256") == contracts.MANIFEST_SHA256
            and corpus.get("development_sha256") == contracts.DEVELOPMENT_SHA256
            and corpus.get("train_sha256") == contracts.TRAIN_SHA256
            and corpus.get("native_source_sha") == contracts.FOUNDATION_SOURCE,
            arm + ": frozen corpus custody mismatch")
    comparison = report["comparison_identity"]
    require(common.digest_json(comparison) == report.get("comparison_identity_sha256")
            and comparison.get("source_sha") == source and comparison.get("model") == report["model"]
            and comparison.get("model_files") == download["files"]
            and comparison.get("adapter_contract") == adapter_identity(report["model"])
            and comparison.get("corpus") == corpus
            and comparison.get("evaluator_sha256") == sha(LANE / "evaluate_native.py")
            and comparison.get("contracts_sha256") == sha(LANE / "contracts.py"),
            arm + ": comparison source/config custody mismatch")
    require(common.digest_json({"comparison": comparison, "arm": arm, "checkpoint": report["checkpoint"]})
            == report.get("evaluation_identity_sha256"), arm + ": arm/checkpoint identity mismatch")
    decoding = report["decoding"]
    require(comparison.get("decoding") == decoding and decoding.get("do_sample") is False
            and decoding.get("num_beams") == 1 and decoding.get("max_new_tokens") == 1024
            and decoding.get("max_seconds") == 1200
            and all(decoding.get(key) is False for key in ("repair", "retry", "fallback")),
            arm + ": first-pass decoding protocol changed")
    cases, generations, counts = report["cases"], report["generations"], report["counts"]
    require(len(cases) == len({row["id"] for row in cases}) == 12
            and len({row["group_id"] for row in cases}) == 6
            and len({row["prompt"] for row in cases}) == 6
            and len(generations) == len({row["id"] for row in generations}) == 6,
            arm + ": six-group/twelve-view denominator changed")
    expected_counts = {
        "case_views": 12, "structural_groups": 6, "distinct_prompts": 6,
        "model_generations_attempted": sum(row["attempted"] for row in generations),
        "attempted_case_views": sum(row["generation_attempted"] for row in cases),
        "accepted_case_views": sum(row["accepted"] for row in cases),
        "accepted_generations": len({row["generation_id"] for row in cases if row["accepted"]}),
        "family_matching_accepted_case_views": sum(row["accepted"] and row["requested_family_matches"] for row in cases),
    }
    require(counts == expected_counts, arm + ": evaluation counts differ from retained rows")
    by_generation = {row["id"]: row for row in generations}
    for case in cases:
        require(case.get("split") == "DEVELOPMENT" and case.get("native_execution") is False,
                arm + ": non-DEVELOPMENT or invented native evaluation row")
        require(set(case["paths"]) == set(case["sha256"]), arm + ": incomplete case inventory")
        for name, path in case["paths"].items():
            common.verify_file(directory, path, case["sha256"][name])
        receipt = read(common.relative_file(directory, case["paths"]["receipt"]))
        expected_receipt = {**case, "sha256": {key: value for key, value in case["sha256"].items() if key != "receipt"}}
        require(receipt == expected_receipt, arm + ": case receipt relabeled")
        raw = read(common.relative_file(directory, case["paths"]["raw_output"]))
        generation = by_generation[case["generation_id"]]
        require(raw == case["verdict"]
                and common.relative_file(directory, case["paths"]["completion"]).read_text() == raw["raw_text"]
                and common.digest_json(raw["token_ids"]) == generation["token_ids_sha256"]
                and case["generation_attempted"] == generation["attempted"]
                and case["id"] in generation["request_ids"]
                and case["prompt"] == generation["prompt"], arm + ": raw generation custody mismatch")
    common.verify_file(directory, "accepted-candidates.json", report["accepted_candidates_sha256"])
    accepted = read(directory / "accepted-candidates.json")
    require(accepted["source_sha"] == source and accepted["arm"] == arm
            and accepted["evaluation_identity_sha256"] == report["evaluation_identity_sha256"]
            and {row["id"] for row in accepted["examples"]} == {row["id"] for row in cases if row["accepted"]}
            and len(accepted["examples"]) == counts["accepted_case_views"],
            arm + ": accepted subset differs from full denominator")
    return report


def read_checkpoint(directory):
    """Read saved tensors and primitive optimizer state; never execute a model."""
    import torch
    from safetensors.torch import load_file
    receipt = common.verify_checkpoint(directory)
    state = torch.load(directory / "training_state.pt", map_location="cpu", weights_only=True)
    for key in ("global_step", "sample_cursor", "config", "frozen_base_sha256", "history"):
        require(state.get(key) == receipt.get(key), "checkpoint state/receipt differ: " + key)
    step = receipt["global_step"]
    require(type(step) is int and 1 <= step <= 120 and state["sample_cursor"] == step,
            "checkpoint optimizer/sampler step is outside this first iteration")
    history = state["history"]
    require(len(history) == step and [row["global_step"] for row in history] == list(range(1, step + 1))
            and [row["sample_cursor"] for row in history] == list(range(1, step + 1)),
            "checkpoint optimizer history is incomplete")
    order = state["config"]["sample_order"]
    require(len(order) == len(set(order)) == 12
            and [row["sample_id"] for row in history] == [order[index % len(order)] for index in range(step)],
            "checkpoint sampler history differs from frozen order")
    adapters = load_file(str(directory / "adapter/adapter_model.safetensors"), device="cpu")
    require(len(adapters) == 420 and sum(value.numel() for value in adapters.values()) == 2442240
            and all("lora_" in name and value.dtype == torch.float32 and torch.isfinite(value).all().item()
                    for name, value in adapters.items()), "checkpoint adapter tensor readback invalid")
    optimizer = state["optimizer"]
    require(len(optimizer["state"]) == len(adapters) and len(optimizer["param_groups"]) == 1,
            "checkpoint optimizer inventory incomplete")
    moments_nonzero = False
    for item in optimizer["state"].values():
        require(int(item["step"].item()) == step, "optimizer parameter step differs")
        for name in ("exp_avg", "exp_avg_sq"):
            value = item[name]
            require(value.is_floating_point() and torch.isfinite(value).all().item(),
                    "optimizer moment is nonfinite")
            moments_nonzero |= bool(torch.count_nonzero(value).item())
    require(moments_nonzero and state["scheduler"]["last_epoch"] == step
            and isinstance(state["torch_rng"], torch.Tensor) and state["torch_rng"].numel() > 0
            and isinstance(state["python_rng"], tuple), "optimizer/scheduler/RNG readback incomplete")
    return receipt


def verify_training(directory, evaluation, source, run_id, attempt, request):
    summary, wrapper = read(directory / "summary.json"), read(directory / "lane-receipt.json")
    step = summary.get("global_step")
    require(type(step) is int and 1 <= step <= request["candidate_steps"]
            and summary.get("actual_training") is True and summary.get("resume") is None
            and summary.get("optimizer_steps_this_job") == step and summary.get("sample_cursor") == step
            and summary.get("checkpoint_readback_exact") is True and summary.get("adapter_changed") is True
            and summary.get("frozen_base_unchanged") is True
            and summary.get("adapter_before_sha256") != summary.get("adapter_after_sha256"),
            "candidate lacks a bounded real optimizer/checkpoint receipt")
    expected_status = "completed" if step == request["candidate_steps"] else "stopped-checkpoint-saved"
    require(summary.get("status") == expected_status and wrapper.get("status") == expected_status
            and wrapper.get("exit_code") == (0 if expected_status == "completed" else 2)
            and wrapper.get("source_sha") == source and wrapper.get("actual_global_step") == step
            and wrapper.get("target_global_steps") == request["candidate_steps"]
            and wrapper.get("checkpoint_every") == request["checkpoint_every"]
            and wrapper.get("max_seconds") == request["training_seconds"]
            and wrapper.get("summary_sha256") == sha(directory / "summary.json")
            and wrapper.get("wrapper_sha256") == sha(LANE / "train.py")
            and wrapper.get("contracts_sha256") == sha(LANE / "contracts.py")
            and wrapper.get("failure") is None and wrapper.get("final_targets_opened") is False,
            "training wrapper/summary custody mismatch")
    config, comparison = summary["config"], evaluation["comparison_identity"]
    required_config = {
        "source_sha": source, "profile": "smol", "model": evaluation["model"],
        "native_source_sha": contracts.FOUNDATION_SOURCE, "corpus_manifest_sha256": contracts.MANIFEST_SHA256,
        "train_sha256": contracts.TRAIN_SHA256, "compiler_sha256": contracts.COMPILER_SHA256,
        "trainer_sha256": sha(PAINTER / "training/train.py"), "contract_sha256": sha(PAINTER / "training/common.py"),
        "model_files": comparison["model_files"], "numerics": comparison["numerics"],
        "adapter_contract": comparison["adapter_contract"],
        "system": comparison["system"], "system_sha256": comparison["system_sha256"],
        "chat_template_sha256": comparison["chat_template_sha256"],
        "device": "cpu", "dtype": "float32", "threads": 1, "seed": 568, "max_length": 2048,
        "rank": 8, "alpha": 16, "dropout": 0.05, "learning_rate": 0.0005,
        "native_execution_by_trainer": False, "final_targets_opened": False,
    }
    require(all(config.get(key) == value for key, value in required_config.items()),
            "training configuration differs from frozen lane/evaluation")
    require(str(summary["runner"].get("github_run_id")) == str(run_id)
            and str(summary["runner"].get("github_run_attempt")) == str(attempt), "training run/attempt differs")
    checkpoints = sorted(directory.glob("checkpoint-*"))
    require(bool(checkpoints) and all(path.is_dir() and not path.is_symlink() for path in checkpoints),
            "checkpoint directories missing or unsafe")
    receipts = {path.name: read_checkpoint(path) for path in checkpoints}
    require(all(receipt["config"] == config and receipt["global_step"] <= step for receipt in receipts.values()),
            "published checkpoint configuration differs")
    latest = common.relative_file(directory, summary["checkpoint"] + "/inventory.json").parent
    receipt = receipts[latest.name]
    require(receipt["global_step"] == step
            and receipt["frozen_base_sha256"] == summary["frozen_base_sha256"]
            and sha(latest / "inventory.json") == summary["checkpoint_inventory_sha256"]
            and sum(path.stat().st_size for path in latest.rglob("*") if path.is_file()) == summary["checkpoint_bytes"],
            "latest checkpoint differs from training summary")
    expected_checkpoint = {"global_step": step, "source_sha": source,
                           "inventory_sha256": sha(latest / "inventory.json"),
                           "adapter_sha256": sha(latest / "adapter/adapter_model.safetensors"),
                           "receipt_sha256": sha(latest / "receipt.json")}
    require(evaluation["checkpoint"] == expected_checkpoint, "candidate evaluation used a different checkpoint")
    return {"actual_optimizer_steps": step, "target_optimizer_steps": request["candidate_steps"],
            "status": expected_status, "checkpoint": latest.name,
            "checkpoint_inventory_sha256": expected_checkpoint["inventory_sha256"],
            "serialized_checkpoints_read": len(receipts), "checkpoint_tensor_readback_verified": True}


def inventory_files(root):
    """Publication never includes FINAL targets, symlinks or transient caches."""
    require(root.is_dir() and not root.is_symlink(), "missing/unsafe evidence component")
    result = []
    for path in sorted(root.rglob("*")):
        require(not path.is_symlink(), "symlink in evidence: " + str(path))
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        require("final.jsonl" not in {part.lower() for part in relative.parts}, "FINAL targets in publication")
        if any(part in {"__pycache__", ".godot", "userdata", "profile"} for part in relative.parts):
            continue
        result.append((relative.as_posix(), path))
    require(bool(result), "empty evidence component")
    return result


def archive(path, entries):
    require(not path.exists(), "refusing to overwrite published archive")
    require(len({name for name, _ in entries}) == len(entries), "duplicate archive member")
    with zipfile.ZipFile(path, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as stream:
        for name, file in entries:
            require(not Path(name).is_absolute() and ".." not in Path(name).parts,
                    "unsafe archive member")
            require(not file.is_symlink() and file.is_file(), "unsafe archive source")
            require("final.jsonl" not in {part.lower() for part in Path(name).parts}, "FINAL targets in publication")
            stream.write(file, name)
    with zipfile.ZipFile(path) as stream:
        require(stream.testzip() is None, "archive readback CRC failed")
    return {"file": path.name, "bytes": path.stat().st_size, "sha256": sha(path), "files": len(entries)}


def verify_regressions(directory):
    expected = {"art_batch", "stored_material", "deferred_manual", "undo_1", "undo_4",
                "combined_author", "combined_reopen"}
    results = read(directory / "results.json")
    require(isinstance(results, list) and len(results) == 7
            and {row.get("label") for row in results} == expected,
            "retained native regression suite inventory differs")
    checks = 0
    for row in results:
        completion = row.get("completion", {})
        require(row.get("status") == "passed" and row.get("exit_code") == 0
                and type(completion.get("checks")) is int and completion["checks"] > 0
                and completion.get("failures") in (0, []),
                "retained native regression failed: " + row["label"])
        require((directory / (row["label"] + ".log")).is_file(),
                "retained regression execution log missing: " + row["label"])
        checks += completion["checks"]
    return {"suites": 7, "checks": checks, "failures": 0,
            "results_sha256": sha(directory / "results.json")}


def package(directory, output, source):
    directory, output = Path(directory).resolve(), Path(output).resolve()
    require(not output.exists(), "immutable release output already exists")
    require(os.environ.get("GITHUB_ACTIONS") == "true"
            and os.environ.get("RUNNER_ENVIRONMENT") == "github-hosted"
            and os.environ.get("RUNNER_OS") == "Linux", "publication requires a Linux GitHub-hosted runner")
    from native_replay import verify_packet
    from native.runtime import ROOT, source_identity
    # Native qualification legitimately replaces the tracked retained binary.
    # Verify the frozen clean source inventory, then bind that freshly built
    # binary independently below. The model-execution guard stays unchanged.
    source_record = source_identity(ROOT, source)
    require(os.environ.get("GITHUB_SHA") == source and os.environ.get("GITHUB_REPOSITORY") == REPOSITORY,
            "publication repository/source environment mismatch")
    run_id, attempt = int(os.environ["GITHUB_RUN_ID"]), int(os.environ["GITHUB_RUN_ATTEMPT"])
    require(run_id > 0 and attempt > 0, "positive run/attempt required")
    tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=PAINTER, text=True).strip()
    request = read(LANE / "run-request.json")
    require(request == read(directory / "build/request.json") and request["candidate_steps"] == 120
            and request["checkpoint_every"] == 40 and request["training_seconds"] == 1200
            and request["evaluation_seconds"] == 1200 and request["generation_tokens"] == 1024
            and request["final_access"] is False, "published request differs from frozen bounded iteration")
    environments, downloads = verify_environments(directory, source, tree, run_id, attempt, request)
    evaluations = {arm: verify_evaluation(directory / arm / "evaluation", arm, source, run_id, attempt, downloads[arm])
                   for arm in ARMS}
    require(evaluations["baseline"]["checkpoint"] is None
            and evaluations["baseline"]["comparison_identity"] == evaluations["candidate"]["comparison_identity"],
            "baseline is not untuned or arm evaluation protocols differ")
    training = verify_training(directory / "candidate/training", evaluations["candidate"], source, run_id, attempt, request)
    proof = verify_packet(directory / "smol-native", source, details=True)
    native = {**proof["summary"], "runtime_sha256": proof["summary"]["runtime"]["native_sha256"]}
    require(native.get("native_passed") is True and native.get("native_global_gates")
            and all(value is True for value in native["native_global_gates"].values()),
            "publication requires completed source-qualified native gates")
    from native_gallery import verify_gallery
    gallery = verify_gallery(directory / "smol-native", directory / "smol-native/gallery", proof)
    require(gallery["case_views"] == 24 and gallery["native_images"] == native["counts"]["native_verified_views"],
            "gallery image/view counts differ from actual native results")
    for arm in ARMS:
        require(native["evaluation_sha256"][arm] == sha(directory / arm / "evaluation/evaluation.json"),
                arm + ": native replay consumed a different evaluation")
    build = read(directory / "native-build.json")
    require(all(build.get(key) == value for key, value in source_record.items())
            and build.get("source_tree") == tree
            and build.get("kind") == "agent-painter-source-build"
            and build.get("native_sha256") == native["runtime_sha256"], "native build/source publication mismatch")
    binary = directory / "build/runtime/libcybersand_native.linux.x86_64.so"
    require(sha(binary) == build["native_sha256"] and binary.stat().st_size == build["native_size"],
            "published native runtime bytes differ")
    require((directory / "build/source-commit.txt").read_text().strip() == source
            and (directory / "build/source-tree.txt").read_text().strip() == tree,
            "build log source identities differ")
    for name in ("godot-cpp.log", "native.log", "abi-floor.log", "import.log"):
        require((directory / "build" / name).is_file(), "missing source build log: " + name)
    regressions = verify_regressions(directory / "regressions")
    components = {arm: inventory_files(directory / arm) for arm in ARMS}
    components["native"] = inventory_files(directory / "smol-native")
    components["build"] = [("build/" + name, path) for name, path in inventory_files(directory / "build")]
    components["build"].append(("native-build.json", directory / "native-build.json"))
    components["build"].extend(("regressions/" + name, path) for name, path in inventory_files(directory / "regressions"))
    output.mkdir(parents=True)
    assets = [archive(output / f"smol-{name}-{source[:12]}-{run_id}-{attempt}.zip", files)
              for name, files in components.items()]
    standalone = output / "smol-gallery.html"
    standalone.write_bytes((directory / "smol-native/gallery/index.html").read_bytes())
    require(sha(standalone) == gallery["index_sha256"], "standalone gallery differs from verified original")
    assets.append({"file": standalone.name, "bytes": standalone.stat().st_size, "sha256": sha(standalone)})
    manifest = {
        "schema": "agent-painter-smol-release-v1", "repository": REPOSITORY,
        "source_sha": source, "source_tree": tree, "workflow_run_id": run_id, "workflow_run_attempt": attempt,
        "request": request, "corpus": {"source_sha": contracts.FOUNDATION_SOURCE, "run_id": CORPUS_RUN,
                                      "artifact": CORPUS_ARTIFACT, "manifest_sha256": contracts.MANIFEST_SHA256,
                                      "development_sha256": contracts.DEVELOPMENT_SHA256},
        "model": {"model_id": contracts.MODEL_ID, "revision": contracts.MODEL_REVISION},
        "independent_hosted_model_vms": {arm: {key: environments[arm][key] for key in ("hostname", "runner_name", "job_id")}
                                         for arm in ARMS},
        "training": training, "development_counts": {arm: evaluations[arm]["counts"] for arm in ARMS},
        "native": native, "gallery": gallery, "retained_native_regressions": regressions,
        "final_targets_opened": False, "artistic_model_qualification": False,
        "draft_hold": True, "assets": assets,
        "claim_limits": ["Twelve host-seed views per arm are six distinct first-pass requests.",
                         "A successful protocol publication can include rejected outputs and zero native model images.",
                         "Native structural checks do not certify requested-layout fulfillment or artistic quality.",
                         "Original training-corpus native admission remains attributed to source633; replay uses this exact source."],
    }
    common.write_json(output / "MANIFEST.json", manifest)
    sums = [{"file": "MANIFEST.json", "sha256": sha(output / "MANIFEST.json")}, *assets]
    (output / "SHA256SUMS.txt").write_text("".join(item["sha256"] + "  " + item["file"] + "\n" for item in sums))
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    result = package(args.directory, args.output, args.source_sha)
    print(json.dumps({"source_sha": result["source_sha"], "training": result["training"],
                      "development_counts": result["development_counts"], "assets": result["assets"]}, sort_keys=True))


if __name__ == "__main__":
    main()
