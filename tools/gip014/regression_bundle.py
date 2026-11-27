#!/usr/bin/env python3
"""Data-only regression export and verification for bounded native goblin tapes.

This module never launches commands. The exported unittest is a fixed committed
template which reads separately observed evidence. Reproduction preserves the
original failing disposition; a passing regression must complete the same admitted
operation, rather than replacing it with a refusal.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path

try:
    from .verify_transcript import MAX_BYTES, canonical, verify
    from .replay_identity import same as same_execution_identity
except ImportError:
    from verify_transcript import MAX_BYTES, canonical, verify
    from replay_identity import same as same_execution_identity

SCHEMA = "cybersand-goblin-regression-case-v1"
MAX_TOTAL = 96 * 1024 * 1024
MAX_METADATA = 1024 * 1024
IDENTITY_FIELDS = ("fixture_id", "fixture_version", "fixture_sha256",
                   "initial_scene_identity", "seed", "pacing_ms", "evidence_kind")
FIXED_MEMBERS = frozenset({"original-transcript.json", "reduced-transcript.json",
    "initial-authored-fixture.json", "reproduction-fixture.json", "material-evidence.json",
    "README.md", "test_goblin_regression.py"})
TEST_TEMPLATE = '''"""Read actual separately reproduced evidence; never execute tape content."""
from pathlib import Path
import unittest
from tools.gip014.regression_bundle import assert_case


class GoblinRegression(unittest.TestCase):
    def test_observed_regression(self):
        assert_case(Path(__file__).resolve().parent)


if __name__ == "__main__":
    unittest.main()
'''


def _encoded(value) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")


def read_json(path: Path, limit: int = MAX_BYTES):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > limit:
        raise ValueError("Missing, linked or oversized bounded evidence file")
    def invalid_constant(value):
        raise ValueError("Non-finite JSON value: " + value)
    return json.loads(path.read_text(encoding="utf-8"), parse_constant=invalid_constant)


def _validated(tape: dict, allow_unit: bool = False) -> None:
    if len(_encoded(tape)) > MAX_BYTES:
        raise ValueError("Transcript exceeds the fixed byte budget")
    checked = verify(tape)
    if not checked["valid"]:
        raise ValueError("Invalid transcript evidence: " + str(checked.get("errors", [])))
    if tape["header"]["evidence_kind"] == "unit_fixture" and not allow_unit:
        raise ValueError("Artificial unit fixtures cannot establish native reproduction")
    if tape["header"].get("fixture_state", "installed") != "installed" or not tape["steps"]:
        raise ValueError("Reproduction requires an installed authored fixture and actual actions")


def _admission(row: dict) -> dict:
    return {key: row.get("admission", {}).get(key) for key in ("accepted", "status", "unsupported")}


def target_for(tape: dict) -> dict:
    termination = tape.get("summary", {}).get("termination")
    if termination == "assertion_failure":
        for row in tape["steps"]:
            for assertion in row["assertions"]:
                if assertion["status"] == "fail":
                    return {"kind": "failed_invariant", "id": assertion["id"],
                        "assertion_kind": assertion["kind"], "action_id": row["action"]["id"],
                        "action_args": copy.deepcopy(row["action"]["args"]),
                        "expected": copy.deepcopy(assertion.get("expected")),
                        "original_status": row["status"],
                        "original_classification": row["classification"],
                        "admission": _admission(row),
                        "required_regression_status": "completed" if row["status"] in ("completed", "partial") else row["status"]}
    if termination == "budget_complete" and tape["steps"] and tape["steps"][-1]["status"] == "completed":
        row = tape["steps"][-1]
        return {"kind": "semantic_outcome", "action_id": row["action"]["id"],
                "action_args": copy.deepcopy(row["action"]["args"]),
                "semantic_sha256": row["semantic_sha256"]}
    raise ValueError("Raw tape has no completed or failed-invariant reproduction target")


def _matches(tape: dict, target: dict, mode: str, target_step: int | None = None) -> bool:
    if mode not in ("reproduction", "regression"):
        raise ValueError("Unknown evidence acceptance mode")
    termination = tape["summary"]["termination"]
    if target_step is not None and not 0 <= target_step < len(tape["steps"]):
        return False
    rows = tape["steps"] if target_step is None else [tape["steps"][target_step]]
    if target["kind"] == "semantic_outcome":
        return termination == "budget_complete" and not tape["summary"]["failures"] and any(
            row["status"] == "completed" and row["action"]["id"] == target["action_id"]
            and row["action"]["args"] == target["action_args"]
            and row["semantic_sha256"] == target["semantic_sha256"] for row in rows)
    expected_terminal = "assertion_failure" if mode == "reproduction" else "budget_complete"
    if termination != expected_terminal or (mode == "regression" and tape["summary"]["failures"]):
        return False
    for row in rows:
        if row["action"]["id"] != target["action_id"] or row["action"]["args"] != target["action_args"]:
            continue
        if _admission(row) != target["admission"]:
            continue
        expected_status = target["original_status"] if mode == "reproduction" else target["required_regression_status"]
        expected_class = target["original_classification"] if mode == "reproduction" else (
            "game_observation" if expected_status == "completed" else target["original_classification"])
        if row["status"] != expected_status or row["classification"] != expected_class:
            continue
        for assertion in row["assertions"]:
            if assertion["id"] == target["id"] and assertion["kind"] == target["assertion_kind"] and assertion.get("expected") == target["expected"] \
                    and assertion["status"] == ("fail" if mode == "reproduction" else "pass"):
                return True
    return False


def _chosen_target_step(tape: dict, target: dict) -> int:
    # Reduction can move the target. Bind its observed occurrence only after the
    # chosen retained tape is fixed; duplicate earlier actions cannot mask it.
    candidates = [index for index in range(len(tape["steps"]))
                  if _matches(tape, target, "reproduction", index)]
    if not candidates:
        raise ValueError("Chosen tape lacks the original target occurrence")
    return candidates[-1] if target["kind"] == "semantic_outcome" else candidates[0]


def _same_fixture(first: dict, second: dict) -> bool:
    return all(first["header"].get(key) == second["header"].get(key) for key in IDENTITY_FIELDS)


def _actions(tape: dict) -> list[dict]:
    return [copy.deepcopy(row["action"]) for row in tape["steps"]]


def export_case(original: dict, output: Path, reduced: dict | None = None, *,
                reduction: dict | None = None, allow_unit: bool = False) -> dict:
    _validated(original, allow_unit)
    chosen = reduced if reduced else original
    _validated(chosen, allow_unit)
    target = target_for(original)
    if not _same_fixture(original, chosen) or not same_execution_identity(original["header"]["provenance"], chosen["header"]["provenance"]):
        raise ValueError("Reduced source/runtime/fixture identity differs from original")
    if not _matches(chosen, target, "reproduction"):
        raise ValueError("Chosen tape does not retain the original target observation")
    output = Path(output)
    if output.exists():
        raise ValueError("Regression export requires a new output directory")
    plan = {"schema": "cybersand-goblin-action-fixture-v1",
            "header": copy.deepcopy(chosen["header"]), "actions": _actions(chosen)}
    material = [{"step": row["index"], "action": row["action"], "native_receipt": row.get("native_receipt", {}),
                 "capture_before": row.get("capture_before", {}), "capture_after": row.get("capture_after", {}),
                 "persistence_capture": row.get("persistence_capture", {})}
                for row in chosen["steps"] if row.get("capture_before") or row.get("capture_after") or row.get("persistence_capture")]
    readme = """# Goblin reproduction case

This is a bounded authored-fixture restart. It is not exact asynchronous physical
continuation and does not by itself establish a production game defect.

At the recorded source/runtime, use the fixed committed launcher:

    python tools/gip014/run_goblin.py --godot PATH_TO_PINNED_GODOT --out NEW_DISPOSABLE_OUTPUT --case reproduce --fixture-file CASE/reproduction-fixture.json

Copy that run's actual goblin transcript to this case as observed-transcript.json.
Then verify the original observation:

    python tools/gip014/regression_bundle.py check CASE --mode reproduction

A passing corrective regression requires a separately observed complete tape
which passes the same target invariant for the same admitted action. Run the
constant exported test with the CyberSand source root on PYTHONPATH:

    python -m unittest discover -s CASE -p test_goblin_regression.py

A reviewed corrective source must be explicit: place its exact provenance in
candidate-provenance.json and use a separate candidate-reproduction-fixture.json
with that provenance. Preserve the original manifest and reproduction fixture.
A source mismatch is otherwise refused. Never execute commands from tape data.
"""
    members = {"original-transcript.json": _encoded(original),
        "initial-authored-fixture.json": _encoded(original.get("initial_authored_fixture", {})),
        "reproduction-fixture.json": _encoded(plan), "material-evidence.json": _encoded(material),
        "README.md": readme.encode(), "test_goblin_regression.py": TEST_TEMPLATE.encode()}
    if reduced:
        members["reduced-transcript.json"] = _encoded(reduced)
    # Keep trial records and acceptance metadata, without duplicating raw tapes.
    reduction_keys = ("schema", "ok", "status", "classification", "acceptance_rule",
        "original_actions", "reduced_actions", "reduction_success", "original_tape_sha256",
        "original_transcript_sha256", "probes", "attempts", "elapsed_msec", "max_trials",
        "max_trial_active_msec", "max_trial_absolute_msec", "full_physics_checkpoint",
        "gameplay_defect_confirmed", "budget", "confirming_repeats", "wall_limit_seconds")
    retained_reduction = {key: copy.deepcopy(reduction[key]) for key in reduction_keys if reduction and key in reduction}
    manifest = {"schema": SCHEMA, "classification": "unresolved_observation" if target["kind"] == "failed_invariant" else "legal_unusual_gameplay",
        "exact_provenance": copy.deepcopy(original["header"]["provenance"]), "target": target,
        "fixture_identity": {key: original["header"].get(key) for key in IDENTITY_FIELDS},
        "chosen_tape": "reduced-transcript.json" if reduced else "original-transcript.json",
        "chosen_target_step": _chosen_target_step(chosen, target),
        "required_action_ids": sorted({row["action"]["id"] for row in chosen["steps"]}),
        "observed_failures": copy.deepcopy(chosen["summary"]["failures"]),
        "original_actions": len(original["steps"]), "reduced_actions": len(chosen["steps"]),
        "reduction": retained_reduction, "fresh_reproduction_confirmed_by_export": False,
        "gameplay_defect_confirmed": False,
        "files": {name: hashlib.sha256(data).hexdigest() for name, data in members.items()}}
    metadata = _encoded(manifest)
    if len(metadata) > MAX_METADATA or any(len(data) > MAX_BYTES for data in members.values()) \
            or sum(map(len, members.values())) + len(metadata) > MAX_TOTAL:
        raise ValueError("Reproduction bundle exceeds its fixed evidence budget")
    output.mkdir(parents=True, exist_ok=False)
    for name, data in members.items():
        (output / name).write_bytes(data)
    (output / "case.json").write_bytes(metadata)
    return manifest


def assert_case(directory: Path, *, mode: str = "regression", allow_unit: bool = False) -> dict:
    directory = Path(directory)
    case = read_json(directory / "case.json", MAX_METADATA)
    if not isinstance(case, dict) or case.get("schema") != SCHEMA or not isinstance(case.get("files"), dict):
        raise ValueError("Unknown bounded regression manifest")
    names = set(case["files"])
    required = FIXED_MEMBERS - {"reduced-transcript.json"}
    if not required <= names <= FIXED_MEMBERS:
        raise ValueError("Manifest includes unsupported or missing fixed members")
    total = 0
    for name, expected in case["files"].items():
        path = directory / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_BYTES:
            raise ValueError("Missing, linked or oversized manifest member")
        data = path.read_bytes()
        total += len(data)
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError("Manifest evidence hash mismatch: " + name)
    if total > MAX_TOTAL:
        raise ValueError("Manifest exceeds total evidence budget")
    original = read_json(directory / "original-transcript.json")
    _validated(original, allow_unit)
    target = target_for(original)
    if case.get("target") != target or case.get("exact_provenance") != original["header"]["provenance"] \
            or case.get("fixture_identity") != {key: original["header"].get(key) for key in IDENTITY_FIELDS}:
        raise ValueError("Manifest authority differs from retained original evidence")
    chosen_name = case.get("chosen_tape")
    if chosen_name not in ("original-transcript.json", "reduced-transcript.json") or chosen_name not in names:
        raise ValueError("Manifest chosen tape is not a retained fixed member")
    chosen = read_json(directory / chosen_name)
    _validated(chosen, allow_unit)
    if not _same_fixture(original, chosen) or not same_execution_identity(original["header"]["provenance"], chosen["header"]["provenance"]) \
            or not _matches(chosen, target, "reproduction"):
        raise ValueError("Chosen tape lost original fixture/source/target identity")
    target_step = _chosen_target_step(chosen, target)
    if case.get("chosen_target_step") != target_step:
        raise ValueError("Manifest target occurrence differs from the chosen observed tape")
    plan = read_json(directory / "reproduction-fixture.json")
    if plan != {"schema": "cybersand-goblin-action-fixture-v1", "header": chosen["header"], "actions": _actions(chosen)}:
        raise ValueError("Action plan differs from retained observed tape")
    actual = read_json(directory / "observed-transcript.json")
    _validated(actual, allow_unit)
    if not _same_fixture(original, actual):
        raise AssertionError("Observed fixture or pacing differs from original")
    expected_provenance = original["header"]["provenance"]
    candidate = directory / "candidate-provenance.json"
    if candidate.exists():
        if mode != "regression":
            raise ValueError("A corrective candidate is only admitted for regression verification")
        expected_provenance = read_json(candidate, MAX_METADATA)
    if not same_execution_identity(expected_provenance, actual["header"]["provenance"]):
        raise AssertionError("Observed source/runtime differs; reviewed corrective candidate provenance must be explicit")
    actual_actions, requested = _actions(actual), plan["actions"]
    if actual_actions != requested[:len(actual_actions)] or (mode == "regression" and len(actual_actions) != len(requested)) \
            or (target["kind"] == "semantic_outcome" and len(actual_actions) != len(requested)):
        raise AssertionError("Observed actions differ from the literal requested sequence")
    if not _matches(actual, target, mode, target_step):
        raise AssertionError("Observed tape does not satisfy the exact " + mode + " acceptance contract")
    return {"ok": True, "mode": mode, "classification": case["classification"],
        "original_actions": len(original["steps"]), "reduced_actions": len(chosen["steps"]),
        "observed_actions": len(actual["steps"]), "source": actual["header"]["provenance"],
        "gameplay_defect_confirmed": False}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    export = sub.add_parser("export")
    export.add_argument("bundle", type=Path)
    export.add_argument("output", type=Path)
    check = sub.add_parser("check")
    check.add_argument("directory", type=Path)
    check.add_argument("--mode", choices=("reproduction", "regression"), default="regression")
    args = parser.parse_args(argv)
    if args.command == "export":
        bundle = read_json(args.bundle)
        if bundle.get("schema") != "cybersand-goblin-reproduction-bundle-v1":
            parser.error("Unknown game reproduction bundle")
        result = export_case(bundle["original_tape"], args.output, bundle.get("reduced_tape"), reduction=bundle.get("reduction"))
    else:
        result = assert_case(args.directory, mode=args.mode)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
