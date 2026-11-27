"""Bounded delta reduction over an injected real-game replay function.

This library cannot launch anything. The ordinary fixed Godot test launcher
supplies `replay(actions)` and returns a fully observed transcript from a new
isolated fixture. All attempted probes, including refusal/error/divergence,
remain in the result. Reduction never edits the original transcript.
"""
from __future__ import annotations

import copy
import time
from dataclasses import dataclass
from typing import Callable

try:
    from .verify_transcript import canonical, digest, verify, action_error
    from .replay_identity import same as same_execution_identity
except ImportError:
    from verify_transcript import canonical, digest, verify, action_error
    from replay_identity import same as same_execution_identity


@dataclass(frozen=True)
class FailureKey:
    assertion: str
    action: str
    args: str
    expected: str
    status: str
    classification: str
    admission: str


def failure_keys(tape: dict) -> set[FailureKey]:
    return {FailureKey(item["id"], row["action"]["id"], canonical(row["action"]["args"]), canonical(item.get("expected")),
                       row["status"], row["classification"], canonical({key: row["admission"].get(key) for key in ("accepted", "status", "unsupported")}))
            for row in tape["steps"] for item in row["assertions"]
            if item["status"] == "fail" and item["kind"] == "gameplay"}


def identity(tape: dict) -> dict:
    header = tape["header"]
    return {key: copy.deepcopy(header.get(key)) for key in
            ("fixture_id", "fixture_version", "fixture_sha256", "initial_scene_identity", "seed", "pacing_ms", "provenance", "evidence_kind")}


def minimize(original: dict, replay: Callable[[list[dict]], dict], *, max_attempts: int = 24,
             repeats: int = 2, allow_unit_fixture: bool = False, target_outcome: bool = False, simplify_parameters: bool = True, max_seconds: int = 1800) -> dict:
    if not 1 <= max_attempts <= 64 or not 1 <= repeats <= 3:
        raise ValueError("reduction bounds are 1..64 probes and 1..3 confirming repeats")
    if not 1 <= max_seconds <= 7200:
        raise ValueError("reduction wall bound is1..7200seconds")
    deadline = time.monotonic() + max_seconds
    report = verify(original)
    if not report["valid"]:
        raise ValueError("original transcript is not valid evidence")
    if original["header"]["evidence_kind"] == "unit_fixture" and not allow_unit_fixture:
        raise ValueError("artificial unit fixtures cannot establish game-defect reproduction")
    targets = failure_keys(original)
    original_actions = [copy.deepcopy(row["action"]) for row in original["steps"]]
    outcome = next((row for row in reversed(original["steps"]) if row["status"] == "completed"), None) if target_outcome and not targets else None
    outcome_key = {"action": outcome["action"]["id"], "args": canonical(outcome["action"]["args"]),
                   "semantic_sha256": outcome["semantic_sha256"]} if outcome else None
    result = {"status": "not_applicable", "original_actions": len(original_actions),
              "actions": copy.deepcopy(original_actions), "attempts": [], "target_failures":
              [{"assertion": key.assertion, "action": key.action, "args": key.args, "expected": key.expected,
                "status": key.status, "classification": key.classification, "admission": key.admission} for key in sorted(targets, key=str)],
              "original_transcript_sha256": digest(original), "budget": max_attempts, "confirming_repeats": repeats,
              "acceptance_rule": {"kind": "semantic_outcome", **outcome_key} if outcome_key else {"kind": "failed_invariant", "exact_target_action_and_expected_value": True},
              "classification": "legal_unusual_gameplay" if outcome_key else "unresolved_observation",
              "parameter_simplifications": [], "selected_probe": None, "wall_limit_seconds": max_seconds}
    if not targets and outcome_key is None:
        return result
    expected_terminal = "assertion_failure" if targets else "budget_complete"
    if original.get("summary", {}).get("termination") != expected_terminal:
        result.update(status="original_incomplete", reason="Original target lacks its required clean terminal outcome")
        return result
    source_identity = identity(original)

    def probe(actions: list[dict]) -> bool | None:
        if len(result["attempts"]) + repeats > max_attempts or time.monotonic() >= deadline:
            return None
        # Keep one specific observed assertion + exact target action, rather
        # than accepting any failure that a shorter, ill-prepared tape creates.
        common = set(targets)
        for repetition in range(repeats):
            if time.monotonic() >= deadline:
                return None
            entry = {"index": len(result["attempts"]), "actions": len(actions),
                     "actions_sha256": digest(actions), "repeat": repetition, "status": "pending"}
            result["attempts"].append(entry)
            try:
                actual = replay(copy.deepcopy(actions))
                checked = verify(actual)
                entry["transcript_sha256"] = digest(actual)
                entry["termination"] = actual.get("summary", {}).get("termination")
                if not checked["valid"]:
                    entry.update(status="invalid_evidence", errors=checked["errors"])
                    return False
                actual_identity = identity(actual)
                same_metadata = all(actual_identity[k] == source_identity[k] for k in source_identity if k != "provenance")
                if not same_metadata or not same_execution_identity(actual_identity["provenance"], source_identity["provenance"]):
                    entry["status"] = "source_fixture_runtime_mismatch"
                    return False
                actual_actions = [row["action"] for row in actual["steps"]]
                # Stop-on-failure may end early; it must be a literal prefix of
                # this proposed sequence, never a substituted policy campaign.
                if actual_actions != actions[:len(actual_actions)]:
                    entry["status"] = "action_replay_divergence"
                    return False
                if outcome_key and len(actual_actions) != len(actions):
                    entry["status"] = "action_replay_divergence"
                    return False
                common &= failure_keys(actual)
                outcome_matches = outcome_key is not None and actual.get("summary", {}).get("termination") == "budget_complete" and not actual.get("summary", {}).get("failures") and any(
                    row["status"] == "completed" and row["action"]["id"] == outcome_key["action"] and canonical(row["action"]["args"]) == outcome_key["args"] and row["semantic_sha256"] == outcome_key["semantic_sha256"] for row in actual["steps"])
                reproduced = outcome_matches if outcome_key else (bool(common) and actual.get("summary", {}).get("termination") == "assertion_failure")
                entry["status"] = "reproduced" if reproduced else "not_reproduced"
                if not reproduced:
                    return False
            except Exception as error:  # Preserve an attempted replay exception as evidence.
                entry.update(status="replay_error", error=f"{type(error).__name__}: {error}")
                return False
        result["last_accepted_probe"] = result["attempts"][-1]["index"]
        return True

    repeatable = probe(original_actions)
    if repeatable is not True:
        result["status"] = "budget_exhausted" if repeatable is None else "original_not_repeatable"
        return result
    result["selected_probe"] = result["last_accepted_probe"]
    candidate = copy.deepcopy(original_actions)
    granularity = 2
    budget_hit = False
    while len(candidate) > 1:
        size = max(1, (len(candidate) + granularity - 1) // granularity)
        accepted = False
        for offset in range(0, len(candidate), size):
            reduced = candidate[:offset] + candidate[offset + size:]
            if not reduced:
                continue
            target_actions = {(key.action, key.args) for key in targets}
            if outcome_key:
                target_actions.add((outcome_key["action"], outcome_key["args"]))
            if not any((action["id"], canonical(action["args"])) in target_actions for action in reduced):
                continue
            matched = probe(reduced)
            if matched is None:
                budget_hit = True
                break
            if matched:
                candidate = reduced
                result["selected_probe"] = result["last_accepted_probe"]
                granularity = max(2, granularity - 1)
                accepted = True
                break
        if budget_hit:
            break
        if accepted:
            continue
        if granularity >= len(candidate):
            break
        granularity = min(len(candidate), granularity * 2)
    # Simplify only non-target parameters, and only after repeated actual game
    # acceptance. Timing/setup changes that lose the exact target are rejected.
    if simplify_parameters and not budget_hit:
        target_actions = {(key.action, key.args) for key in targets}
        if outcome_key:
            target_actions.add((outcome_key["action"], outcome_key["args"]))
        for index in range(len(candidate)):
            action = candidate[index]
            if (action["id"], canonical(action["args"])) in target_actions:
                continue
            for simpler in parameter_candidates(action):
                changed = copy.deepcopy(candidate)
                changed[index] = simpler
                matched = probe(changed)
                if matched is None:
                    budget_hit = True
                    break
                if matched:
                    result["parameter_simplifications"].append({"index": index, "before": candidate[index], "after": simpler})
                    candidate = changed
                    result["selected_probe"] = result["last_accepted_probe"]
                    break
            if budget_hit:
                break
    result.update(status="budget_exhausted" if budget_hit else "reduced", actions=candidate,
                  reduced_actions=len(candidate), confirmed_original=True,
                  one_minimal=not budget_hit and not result["parameter_simplifications"] and granularity >= len(candidate),
                  minimality_scope="single action deletion under the exact repeated acceptance rule; parameter search is bounded")
    return result


def parameter_candidates(action: dict) -> list[dict]:
    """Small declarative simplifications; never invent an executable action."""
    candidates = []
    for key, value in action.get("args", {}).items():
        if key in ("radius", "ticks") and type(value) in (int, float):
            smaller = 0 if key == "radius" else 1
            if value <= smaller:
                continue
            candidate = copy.deepcopy(action)
            candidate["args"][key] = smaller
            if action_error(candidate) is None:
                candidates.append(candidate)
    return candidates
