"""Recompute revealed recovery evidence using the unchanged registered readers."""
from __future__ import annotations

import gzip
import hashlib
import json
from pathlib import Path

import runtime_custody as custody


def request_options(policy: str, rounds: int) -> dict:
    treatment, *modifiers = policy.split("+")
    result = {"rounds": rounds, "vocabulary": True, "hierarchy": True,
              "shared_ownership": "fixed" not in modifiers, "frame_adaptation": "frame_frozen" not in modifiers,
              "mosaic_adaptation": "mosaic_frozen" not in modifiers, "optional_negotiation": "hard_only" not in modifiers,
              "native_mosaic_bearing": True, "supported_native_receptors": treatment in ("receptor_only", "both", "recovery"),
              "compact_native_termination": treatment in ("terminal_only", "both", "recovery"),
              "final_validation": True, "shared_extent": 13, "orientation_preference": -1}
    if treatment == "recovery":
        result.update(negotiated_recovery=True, recovery_offers="no_offers" not in modifiers)
    return result


def retained(directory: Path, row: dict, name: str) -> dict:
    storage = row["storage"][name]
    path = directory / row["id"] / (name + ".gz")
    custody.require(storage.get("file") == name + ".gz" and path.is_file() and not path.is_symlink(),
                    "Recovery original file absent or rebound: " + name)
    compressed = path.read_bytes()
    custody.require(type(storage.get("compressed_bytes")) is int and storage["compressed_bytes"] == len(compressed)
                    and storage.get("compressed_sha256") == hashlib.sha256(compressed).hexdigest(),
                    "Recovery compressed evidence changed: " + name)
    raw = gzip.decompress(compressed)
    custody.require(type(storage.get("raw_bytes")) is int and storage["raw_bytes"] == len(raw)
                    and storage.get("raw_sha256") == hashlib.sha256(raw).hexdigest(),
                    "Recovery original JSON changed: " + name)
    value = json.loads(raw)
    custody.require(isinstance(value, dict), "Recovery original document is not an object")
    return value


def validate_recovery_case(directory: Path, row: dict, case: dict, policy: str, rounds: int,
                           build: dict, runner) -> dict:
    identity = f'{case["fixture"]}--{case["profile"]}--s{case["seed"]}--{policy}--r{rounds}'
    expected = {**case, "id": identity, "policy": policy, "effective_policy": policy, "rounds": rounds}
    custody.require(all(type(row.get(key)) is type(value) and row.get(key) == value for key, value in expected.items()),
                    "Recovery original case or policy differs: " + identity)
    child = row.get("execution", {})
    custody.require(type(child.get("returncode")) is int and child["returncode"] == 0
                    and child.get("child_reaped") is True and child.get("timed_out") is False
                    and child.get("cancelled") is False and not row.get("evidence_error")
                    and child.get("timeout_seconds") == 90 and type(child.get("pid")) is int and child["pid"] > 0
                    and child.get("log_sha256") == custody.sha(directory / (identity + ".log")),
                    "Recovery original child failed: " + identity)
    argv = child.get("argv", [])
    custody.require(isinstance(argv, list) and len(argv) == 9 and argv[0] == build["binary"] and argv[1] == "run"
                    and Path(argv[2]).name == identity
                    and argv[3:] == [build["source_commit"], case["fixture"], case["profile"], str(case["seed"]), policy, str(rounds)],
                    "Recovery original native command differs: " + identity)
    custody.require(set(row.get("storage", {})) == {"request-envelope.json", "request.json", "response-native.json"}
                    and json.loads((directory / identity / "storage.json").read_bytes()) == row["storage"],
                    "Recovery original storage inventory is incomplete: " + identity)
    request = retained(directory, row, "request.json")
    envelope = retained(directory, row, "request-envelope.json")
    native = retained(directory, row, "response-native.json")
    custody.require(runner.canonical(request) == runner.canonical(envelope.get("input"))
                    and row.get("request_sha256") == hashlib.sha256(runner.canonical(request)).hexdigest()
                    and envelope.get("source") == native.get("source") == build["source_commit"],
                    "Recovery original request/source differs: " + identity)
    profile = "industrial" if case["profile"] == "industrial_gui" else case["profile"]
    custody.require(runner.canonical(request.get("options")) == runner.canonical(request_options(policy, rounds)),
                    "Recovery native request changed its registered policy: " + identity)
    modifiers = policy.split("+")[1:]
    fixture = "workbench_territory" if case["fixture"].startswith("owner_left_right_") else case["fixture"]
    dimensions = (128, 128) if case["fixture"] == "owner_left_right_128x128" else (192, 112)
    for owner, prefix in (("frame", "frameweaver.frontier-growth-v0."), ("mosaic", "mosaic.prepared-regions-v0.")):
        value = request.get(owner, {})
        custody.require(value.get("source") == build["source_commit"]
                        and value.get("definition") == prefix + build["definition_sha256"]
                        and type(value.get("seed")) is int and value["seed"] == case["seed"]
                        and value.get("profile", {}).get("name") == profile
                        and value.get("fixture") == fixture and (value.get("width"), value.get("height")) == dimensions,
                        "Recovery native request definition/seed/profile differs: " + identity)
        limits = value.get("limits", {})
        custody.require(limits.get("work") == (1 if owner + "_budget" in modifiers else 2_000_000)
                        and limits.get("solver_work") == (1 if owner == "mosaic" and "solver_budget" in modifiers else 4_000_000)
                        and limits.get("bytes") == (1024 if "memory_budget" in modifiers else 16_777_216),
                        "Recovery native request changed a registered resource ceiling: " + identity)
        if case["profile"] == "industrial_gui":
            custody.require(value["profile"].get("clutter") == 0, "Recovery GUI profile changed its native decoration")
    custody.require(type(native.get("schema")) is int and native["schema"] in (5, 6)
                    and native.get("type") == "reciprocal_assembly"
                    and native.get("status") in ("complete", "blocked", "unsat", "exhausted", "cancelled", "oscillation"),
                    "Recovery native output is not a completed execution or retained refusal: " + identity)
    # These frozen functions preserve unavailable closure, cancellation work and
    # the exact bounded-header refusal contract; no new semantic normalization.
    derived = runner.reduce_result(native)
    custody.require(all(key in row and runner.canonical(row[key]) == runner.canonical(value)
                        for key, value in derived.items()),
                    "Recovery summary differs from original native evidence: " + identity)
    custody.require(row.get("input_representation") == runner.verify_native_input(request, native),
                    "Recovery input representation differs: " + identity)
    text = (directory / (identity + ".log")).read_text(encoding="utf-8")
    completion = {"schema": 1, "variant": "swarm006", "status": derived["status"],
                  "can_apply": derived["can_apply"], "joints": derived["qualified_joints"]}
    custody.require(json.loads(text) == completion, "Recovery original completion differs: " + identity)
    return {**row, **derived}


def validate_recovery_records(directory: Path, value: dict, build: dict, receipt: dict, replay, runner, plan: dict) -> None:
    custody.require(build.get("result") == "PASS" and build.get("variant") == "swarm006"
                    and build.get("source_commit") == receipt["source_commit"]
                    and build.get("source_tree") == receipt["source_tree"]
                    and build.get("source_dirty") == "" and build.get("allow_dirty_requested") is False
                    and build.get("source_custody_revalidated") is True
                    and build.get("runner_sha256") == replay.RUNNER_SHA
                    and build.get("harness_sha256") == replay.HARNESS_SHA
                    and build.get("definition_sha256") == receipt["native_definition_sha256"]
                    and build.get("source_inputs") == runner.source_inputs(custody.ROOT)
                    and value.get("runner_sha256") == replay.RUNNER_SHA
                    and value.get("orchestrator_sha256") == custody.sha(Path(replay.__file__))
                    and value.get("historical_registration_sha256") == replay.REGISTRATION_SHA,
                    "Recovery original scientific build, runner or native inputs differ")
    tasks = [(case, policy["name"], policy["rounds"]) for case in plan["cases"] for policy in plan["policies"]]
    rows = value.get("records", [])
    custody.require(isinstance(rows, list) and len(rows) == len(tasks) == 1920, "Recovery original case inventory is incomplete")
    derived = [validate_recovery_case(directory, row, case, policy, rounds, build, runner)
               for row, (case, policy, rounds) in zip(rows, tasks)]
    distributions = {}
    for item in plan["policies"]:
        policy, rounds = item["name"], item["rounds"]
        selected = [row for row in derived if (row["policy"], row["rounds"]) == (policy, rounds)]
        summary = runner.distribution(selected)
        summary.update(denominator=96, A=sum(replay.endpoint(row) for row in selected),
                       R=sum(replay.endpoint(row, True) for row in selected))
        distributions[f"{policy}@{rounds}"] = summary
    custody.require(runner.canonical(value.get("distributions")) == runner.canonical(distributions),
                    "Recovery published distributions differ from original native outcomes")
