#!/usr/bin/env python3
"""Independent Python readback of retained 4LY-003 DEVELOPMENT physical episodes.

Use AFTER the exact-host Godot process exits. This reads source-bound artifacts
from disk independently of the GDScript writer, verifies their full SHA-256
digests and whole-episode physical/action receipts, and writes a bounded report.
It never opens the sealed final teacher split or triggers neural training.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

EXPECTED = {
    "4ly_trainer": "f1f9286a27b929c96caca5aaf2be70cbd82e0fd933f29968c1aaaa43ac8f1704",
    "4ly_hauler": "e9979ed9e437d2fcdf5c4c52fb4385e788d4ccd6f40c7494308c60c26c11e10d",
    "4ly_drifter": "c195dd35677dcbdb76c85c798d0c1fbc103dcc40182932be7d70c755b1dbac24",
    "4ly_dart": "a48a58c388fb0826f5b5b29005a7469d2cd081dd2c0ed3bfe6c028d88cd04084",
}
CONTROLLER = "fb86190c68c6a87e7d2ef7e845b1fb97305f188723a326f67f07caa6971cc8ae"
CASES = {
    "free": "test_physical_flight_teacher_dev_free",
    "obstacle": "test_physical_flight_teacher_dev_obstacle",
}
MAX_TRACE_TICKS = 2400


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{path}: expected JSON object")
    return payload


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_group(base: Path, group: str, git_sha: str) -> dict[str, Any]:
    directory = base / ("4ly003-dev-" + group)
    summary_path = directory / "summary.json"
    summary = load_json(summary_path)
    errors: list[str] = []
    if summary.get("schema") != "4ly003-development-family-pilot/v1":
        errors.append("unexpected_summary_schema")
    if summary.get("group") != group or summary.get("split") != "development":
        errors.append("incorrect_or_final_split")
    if summary.get("github_sha") != git_sha:
        errors.append("github_commit_identity_mismatch")
    if summary.get("final_split_opened") is not False:
        errors.append("final_split_must_remain_sealed")
    if summary.get("physics_hz") != 60 or summary.get("decision_ticks") != 6:
        errors.append("invalid_declared_host_cadence")
    if summary.get("episodes", 0) < 1 or summary.get("episodes", 0) > 40:
        errors.append("episode_capacity")
    if summary.get("physical_ticks", -1) > 80000:
        errors.append("physical_tick_capacity")
    inventory: dict[str, dict] = {x["name"]: x for x in summary.get("digest_inventory", [])}
    entries = summary.get("results", [])
    if len(entries) != summary.get("episodes") or len(entries) != len(inventory):
        errors.append("episode_or_inventory_count_mismatch")
    total_ticks = 0
    total_bytes = 0
    count = 0
    for item in entries:
        name = str(item.get("trace_filename", ""))
        path = directory / name
        if not name or Path(name).name != name or name not in inventory or not path.is_file():
            errors.append("missing_or_unsafe_trace_filename:" + name)
            continue
        actual_sha = sha256(path)
        actual_bytes = path.stat().st_size
        if actual_sha != item.get("trace_sha256") or actual_sha != inventory[name].get("sha256"):
            errors.append("trace_hash_mismatch:" + name)
            continue
        if actual_bytes != inventory[name].get("bytes"):
            errors.append("trace_size_mismatch:" + name)
        record = load_json(path)
        manifest = record.get("manifest", {})
        metrics = record.get("metrics", {})
        trace = record.get("trace", [])
        model = item.get("model")
        if model not in EXPECTED or manifest.get("profile_hash") != EXPECTED.get(model):
            errors.append("frozen_profile_identity:" + name)
        if manifest.get("controller_sha256") != CONTROLLER:
            errors.append("controller_identity:" + name)
        if manifest.get("source_git_sha") != git_sha or manifest.get("teacher_source_sha256") != summary.get("teacher_source_sha256"):
            errors.append("checkout_or_teacher_source_identity:" + name)
        if manifest.get("source") != "teacher" or manifest.get("split") != "development":
            errors.append("producer_or_split:" + name)
        if manifest.get("host_schedule") != "synchronous-mask-actuation-effects-material-feedback-terrain-rapier/v1":
            errors.append("native_host_schedule:" + name)
        if manifest.get("split_geometry_version") != 3 or manifest.get("sealed_suite_sha256") is not None:
            errors.append("missing_split_v3_or_public_final_leak:" + name)
        if manifest.get("action_profile") != "4ly_velocity_v1":
            errors.append("physical_action_profile:" + name)
        if manifest.get("physics_hz") != 60 or manifest.get("decision_ticks") != 6:
            errors.append("cadence:" + name)
        if manifest.get("observation") != "4ly-observation/v1" or manifest.get("flat_observation_length") != 54:
            errors.append("observation_schema:" + name)
        if metrics.get("scenario") != item.get("scenario") or metrics.get("physical_ticks") != len(trace):
            errors.append("metric_or_trace_identity:" + name)
        if len(trace) > min(MAX_TRACE_TICKS, int(manifest.get("max_ticks", 0))):
            errors.append("episode_tick_capacity:" + name)
        if metrics.get("invalid_actions", 1) != 0 or metrics.get("failed") is True:
            errors.append("authoritative_failure:" + name)
        if metrics.get("successful_dwell") is True:
            if not any(x.get("dwell", 0) >= 36 for x in trace):
                errors.append("missing_low_speed_dwell:" + name)
            if metrics.get("final_speed_cells_per_second", 100) > 2.5001:
                errors.append("high_speed_arrival:" + name)
        if item.get("scenario") in {"neutral_control", "constant_control", "power_off"} and item.get("navigation_credit") is not False:
            errors.append("negative_navigation_credit:" + name)
        recovery_witness = True
        if item.get("family") == "recovery":
            disturbance_ticks = [
                int(x.get("tick", -1))
                for x in trace
                if isinstance(x.get("host_disturbance"), dict)
                and x.get("host_disturbance", {}).get("accepted") is True
            ]
            recovery_witness = bool(disturbance_ticks) and any(
                int(x.get("tick", -1)) >= disturbance_ticks[0] and x.get("contact") is True
                for x in trace
            )
            if not recovery_witness:
                errors.append("missing_post_disturbance_recovery_contact:" + name)
        expected_qualification_credit = bool(item.get("navigation_credit")) and recovery_witness
        if item.get("qualification_credit") is not expected_qualification_credit:
            errors.append("qualification_credit_mismatch:" + name)
        if item.get("recovery_witness") is not recovery_witness:
            errors.append("recovery_witness_mismatch:" + name)
        if any(x.get("physics_fault") for x in trace):
            errors.append("physics_fault_in_trace:" + name)
        # Verified source of each transition: same actual Rapier physics step,
        # contiguous native tick, physically published force/torque receipt.
        for index, x in enumerate(trace, 1):
            if x.get("tick") != index or x.get("world_tick") != index:
                errors.append(f"noncontiguous_native_episode_ticks:{name}:{index}")
                break
            receipt = x.get("physical_receipt", {})
            if not isinstance(receipt, dict) or receipt.get("physics_step") != index:
                errors.append(f"missing_physical_step_receipt:{name}:{index}")
                break
            if receipt.get("actor_id") != 0 or "controller" not in receipt:
                errors.append(f"missing_controller_receipt:{name}:{index}")
                break
        count += 1
        total_ticks += len(trace)
        total_bytes += actual_bytes
    if total_ticks != summary.get("physical_ticks"):
        errors.append("aggregate_physical_tick_count")
    if count != summary.get("episodes"):
        errors.append("retained_episode_count")
    return {
        "group": group, "status": "PASS" if not errors else "FAIL",
        "episodes_verified": count, "ticks_verified": total_ticks,
        "trace_bytes_verified": total_bytes,
        "summary_sha256": sha256(summary_path),
        "errors": errors[:100],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--regression-output", type=Path, required=True)
    parser.add_argument("--expect-source-sha", required=True)
    args = parser.parse_args()
    root = args.regression_output
    metadata = load_json(root / "timings.json")
    included = set(metadata.get("assigned_cases", []))
    build_identity = metadata.get("identity", {})
    runtime_errors: list[str] = []
    if build_identity.get("source_sha") != args.expect_source_sha:
        runtime_errors.append("regression_identity_source_sha_mismatch")
    runtime_identities: dict[str, Any] = {}
    for key in ("cybersand_runtime", "rapier_runtime"):
        item = build_identity.get(key, {})
        raw_path, reported_sha = item.get("path", ""), item.get("sha256", "")
        binary = (Path(__file__).resolve().parents[2] / raw_path).resolve()
        if not raw_path or not reported_sha or not binary.is_file() or sha256(binary) != reported_sha:
            runtime_errors.append("runtime_sha256_mismatch:" + key)
        runtime_identities[key] = {"path": raw_path, "sha256": reported_sha}
    if not str(build_identity.get("godot_version", "")).startswith("4.7."):
        runtime_errors.append("godot_4_7_identity")
    parts = [
        validate_group(root / "presentation", group, args.expect_source_sha)
        for group, case in CASES.items() if case in included
    ]
    result = {
        "schema": "4ly003-independent-development-readback/v1",
        "source_sha": args.expect_source_sha,
        "phase": "after_external_Godot_exit",
        "role": "independent_Python_full_file_and_physics_trace_readback",
        "split": "development_only_no_teacher_admission",
        "matched_scopes": len(parts),
        "groups": parts,
        "actual_host_runtime": {
            "godot_version": build_identity.get("godot_version", ""),
            "cybersand_native_and_rapier": runtime_identities,
            "staged_binary_and_checkout_errors": runtime_errors,
        },
        "status": "PASS" if not runtime_errors and all(p["status"] == "PASS" for p in parts) else "FAIL",
    }
    dest = root / "4ly003-independent-readback.json"
    dest.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("4LY003_INDEPENDENT_READBACK " + json.dumps(result, sort_keys=True))
    return int(result["status"] != "PASS")


if __name__ == "__main__":
    raise SystemExit(main())
