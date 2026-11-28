#!/usr/bin/env python3
"""Replay the revealed SWARM006-HOLDOUT-001 corpus on a corrected successor.

This is regression qualification, never a new unseen experiment. The original
registration, frozen helper, harness, policies, denominators and 90-second child
limit stay byte-identical. Each execution has its own native process and files.
The old 480 reference executions may be consumed separately as retained controls;
they are not counted as newly executed by this tool.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
REGISTRATION = ROOT / "docs/audits/swarm006-holdout-001/registration.json"
REGISTRATION_SHA = "e2110f7fdbcc1ab5f507597f347c15ae68f7902ce29f1adbe21577571e49fc96"
RUNNER_SHA = "ea4c2161dc80a46a3a3faee6d158b5f23096090a40eac51b184f4b0aabb98868"
HARNESS_SHA = "54c176d9da9b47266075a1567afe9c54af7cd09239bbe348de904f01e058ae69"
CLASSIFICATION = "revealed_corpus_successor_regression"


def frozen_runner():
    path = ROOT / "native/experiments/gentek_swarm/run_swarm006.py"
    if hashlib.sha256(path.read_bytes()).hexdigest() != RUNNER_SHA:
        raise ValueError("Frozen runner bytes changed; do not silently revise comparison policy")
    spec = importlib.util.spec_from_file_location("swarm006_frozen_replay_helpers", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def registered_plan() -> dict:
    raw = REGISTRATION.read_bytes()
    if hashlib.sha256(raw).hexdigest() != REGISTRATION_SHA:
        raise ValueError("Original historical registration changed")
    plan = json.loads(raw)
    if len(plan["cases"]) != 96 or len(plan["policies"]) != 20 or plan["timeout_seconds"] != 90 or plan["controls"]:
        raise ValueError("Frozen case/policy/timeout contract changed")
    return plan


def verified_build(directory: Path, runner) -> dict:
    receipt = json.loads((directory / "build.json").read_bytes())
    root = Path(receipt["source_root"])
    if (receipt["result"] != "PASS" or receipt["variant"] != "swarm006" or receipt["source_dirty"]
            or receipt["allow_dirty_requested"] or receipt["source_custody_revalidated"] is not True):
        raise ValueError("Successor qualification requires an exact clean successful source build")
    if (runner.git(root, "rev-parse", "HEAD") != receipt["source_commit"]
            or runner.git(root, "rev-parse", "HEAD^{tree}") != receipt["source_tree"]
            or runner.git(root, "status", "--porcelain")
            or runner.source_inputs(root) != receipt["source_inputs"]
            or runner.definition(root) != receipt["definition_sha256"]):
        raise ValueError("Successor source no longer matches its executable receipt")
    if (receipt["runner_sha256"] != RUNNER_SHA or receipt["harness_sha256"] != HARNESS_SHA
            or runner.sha(Path(receipt["harness"])) != HARNESS_SHA
            or runner.sha(Path(receipt["binary"])) != receipt["binary_sha256"]):
        raise ValueError("Frozen harness/helper or source-built executable identity changed")
    return receipt


def execute_case(case: dict, policy: str, rounds: int, receipt: dict, output: Path, runner) -> dict:
    identity = f'{case["fixture"]}--{case["profile"]}--s{case["seed"]}--{policy}--r{rounds}'
    destination = output / identity
    command = [receipt["binary"], "run", str(destination), receipt["source_commit"],
               case["fixture"], case["profile"], str(case["seed"]), policy, str(rounds)]
    row = {**case, "id": identity, "policy": policy, "effective_policy": policy,
           "rounds": rounds, "status": "execution_failed", "can_apply": False}
    try:
        row["execution"] = runner.execute(command, output / (identity + ".log"), 90)
        raw = destination / "response-native.json"
        if not raw.is_file():
            raise ValueError("Native response absent; no successful generation or refusal established")
        envelope = json.loads((destination / "request-envelope.json").read_bytes())
        runner.atomic_json(destination / "request.json", envelope["input"])
        row["request_sha256"] = hashlib.sha256(runner.canonical(envelope["input"])).hexdigest()
        value = json.loads(raw.read_bytes())
        row.update(runner.reduce_result(value))
        row["input_representation"] = runner.verify_native_input(envelope["input"], value)
        if value["source"] != receipt["source_commit"]:
            raise ValueError("Native response declares another source")
        if row["execution"]["returncode"] != 0:
            raise ValueError("Native child failed; retained output cannot authorize success")
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        row["evidence_error"] = str(error)
        row["can_apply"] = False
    # Preserve malformed output and failed children as evidence as well.
    row["storage"] = {}
    try:
        if destination.is_dir():
            for path in sorted(destination.glob("*.json")):
                row["storage"][path.name] = runner.compress_json(path)
            runner.atomic_json(destination / "storage.json", row["storage"])
    except (ValueError, OSError) as error:
        row["evidence_error"] = str(error)
        row["can_apply"] = False
    return row


def endpoint(row: dict, foreign: bool = False) -> bool:
    execution = row.get("execution", {})
    return bool(execution.get("returncode") == 0 and execution.get("child_reaped") is True
                and not execution.get("timed_out")
                and not execution.get("cancelled") and not row.get("evidence_error")
                and row.get("status") == "complete" and row.get("can_apply") is True
                and row.get("closure_evaluated") is True and row.get("still_required") == 0
                and (not foreign or row.get("qualified_joints", 0) > 0))


def run(build: Path, output: Path, workers: int) -> int:
    runner = frozen_runner()
    plan = registered_plan()
    receipt = verified_build(build, runner)
    if output.is_relative_to(ROOT) or output.is_relative_to(build):
        raise ValueError("Evidence must be separate from source and build")
    runner.fresh_directory(output)
    (output / "historical-registration-unchanged.json").write_bytes(REGISTRATION.read_bytes())
    policies = [(p["name"], p["rounds"]) for p in plan["policies"]]
    manifest = {"schema": 1, "programme": "GENTEK-SWARM-006", "classification": CLASSIFICATION,
                "scope": "Revealed synthetic corpus; correctness regression, no unseen or owner-World claim",
                "suite": CLASSIFICATION, "variant": "swarm006", "source": receipt["source_commit"],
                "build_receipt": receipt, "build_receipt_sha256": runner.sha(build / "build.json"),
                "runner_sha256": RUNNER_SHA, "orchestrator_sha256": runner.sha(Path(__file__)),
                "historical_registration_sha256": REGISTRATION_SHA,
                "historical_source": plan["candidate"]["git_sha"], "cases": plan["cases"], "policies": policies,
                "limits": plan["limits"], "controls": False, "child_timeout_seconds": 90,
                "workers": workers, "expected_executions": 1920, "retained_reference_executions": 0,
                "started_utc": runner.now(), "result": "RUNNING", "records": [],
                "repair_scope": "Bounded provisional-history finalization accounting; unchanged grammar, candidate ordering and resource ceilings. Low-budget stop timing may change."}
    # The complete successor identity/plan is retained before the first child.
    runner.atomic_json(output / "replay-plan.json", manifest)
    runner.atomic_json(output / "manifest.json", manifest)
    tasks = list(itertools.product(plan["cases"], policies))
    records = [None] * len(tasks)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(execute_case, case, policy, rounds, receipt, output, runner): i
                   for i, (case, (policy, rounds)) in enumerate(tasks)}
        for count, future in enumerate(as_completed(futures), 1):
            index = futures[future]
            try:
                records[index] = future.result()
            except Exception as error:
                case, (policy, rounds) = tasks[index]
                records[index] = {**case, "id": f'{case["fixture"]}--{case["profile"]}--s{case["seed"]}--{policy}--r{rounds}',
                                  "policy": policy, "rounds": rounds, "status": "execution_failed", "can_apply": False,
                                  "execution": {"returncode": None, "child_reaped": False},
                                  "evidence_error": "Orchestrator exception: " + repr(error), "storage": {}}
            if count % 32 == 0 or count == len(tasks):
                manifest["records"] = [row for row in records if row is not None]
                manifest["retained_executions"] = count
                runner.atomic_json(output / "manifest.json", manifest)
                print(json.dumps({"completed": count, "total": len(tasks)}), flush=True)
    manifest["records"] = records
    manifest["distributions"] = {}
    for policy, rounds in policies:
        rows = [r for r in records if (r["policy"], r["rounds"]) == (policy, rounds)]
        result = runner.distribution(rows)
        result.update(denominator=96, A=sum(endpoint(r) for r in rows), R=sum(endpoint(r, True) for r in rows))
        manifest["distributions"][f"{policy}@{rounds}"] = result
    errors = [r["id"] for r in records if r.get("evidence_error") or r.get("execution", {}).get("returncode") != 0]
    try:
        verified_build(build, runner)
        registered_plan()
        if runner.sha(Path(__file__)) != manifest["orchestrator_sha256"] or runner.sha(Path(runner.__file__)) != RUNNER_SHA:
            raise ValueError("Replay orchestration/helper changed during execution")
        manifest["source_custody_revalidated"] = manifest["binary_custody_revalidated"] = True
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        errors.append(str(error))
        manifest["source_custody_revalidated"] = False
    manifest.update(result="FAIL" if errors else "PASS", errors=errors, ended_utc=runner.now())
    runner.atomic_json(output / "manifest.json", manifest)
    print(json.dumps({"result": manifest["result"], "retained_executions": len(records),
                      "primary": manifest["distributions"]["recovery@2"], "errors": errors}))
    return int(bool(errors))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--workers", type=int, choices=range(1, 5), default=4)
    args = parser.parse_args()
    return run(args.build.resolve(), args.out.resolve(), args.workers)


if __name__ == "__main__":
    sys.exit(main())
