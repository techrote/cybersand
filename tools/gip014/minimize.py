"""Bounded delta reduction over an injected real-game replay function.

This library cannot launch anything. The ordinary fixed Godot test launcher
supplies `replay(actions)` and returns a fully observed transcript from a new
isolated fixture. All attempted probes, including refusal/error/divergence,
remain in the result. Reduction never edits the original transcript.
"""
from __future__ import annotations

import copy
from dataclasses import dataclass
from typing import Callable

try:
    from .verify_transcript import canonical, digest, verify
    from .replay_identity import same as same_execution_identity
except ImportError:
    from verify_transcript import canonical, digest, verify
    from replay_identity import same as same_execution_identity


@dataclass(frozen=True)
class FailureKey:
    assertion: str
    action: str
    args: str
    expected: str


def failure_keys(tape: dict) -> set[FailureKey]:
    return {FailureKey(item["id"], row["action"]["id"], canonical(row["action"]["args"]), canonical(item.get("expected")))
            for row in tape["steps"] for item in row["assertions"]
            if item["status"] == "fail" and item["kind"] == "gameplay"}


def identity(tape: dict) -> dict:
    header = tape["header"]
    return {key: copy.deepcopy(header.get(key)) for key in
            ("fixture_id", "fixture_version", "initial_scene_identity", "seed", "provenance", "evidence_kind")}


def minimize(original: dict, replay: Callable[[list[dict]], dict], *, max_attempts: int = 24,
             repeats: int = 2, allow_unit_fixture: bool = False) -> dict:
    if not 1 <= max_attempts <= 64 or not 1 <= repeats <= 3:
        raise ValueError("reduction bounds are 1..64 probes and 1..3 confirming repeats")
    report = verify(original)
    if not report["valid"]:
        raise ValueError("original transcript is not valid evidence")
    if original["header"]["evidence_kind"] == "unit_fixture" and not allow_unit_fixture:
        raise ValueError("artificial unit fixtures cannot establish game-defect reproduction")
    targets = failure_keys(original)
    original_actions = [copy.deepcopy(row["action"]) for row in original["steps"]]
    result = {"status": "not_applicable", "original_actions": len(original_actions),
              "actions": copy.deepcopy(original_actions), "attempts": [], "target_failures":
              [{"assertion": key.assertion, "action": key.action, "args": key.args, "expected": key.expected} for key in sorted(targets, key=str)],
              "original_transcript_sha256": digest(original), "budget": max_attempts, "confirming_repeats": repeats}
    if not targets:
        return result
    source_identity = identity(original)

    def probe(actions: list[dict]) -> bool | None:
        if len(result["attempts"]) + repeats > max_attempts:
            return None
        # Keep one specific observed assertion + exact target action, rather
        # than accepting any failure that a shorter, ill-prepared tape creates.
        common = set(targets)
        for repetition in range(repeats):
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
                common &= failure_keys(actual)
                entry["status"] = "reproduced" if common else "not_reproduced"
                if not common:
                    return False
            except Exception as error:  # Preserve an attempted replay exception as evidence.
                entry.update(status="replay_error", error=f"{type(error).__name__}: {error}")
                return False
        return True

    repeatable = probe(original_actions)
    if repeatable is not True:
        result["status"] = "budget_exhausted" if repeatable is None else "original_not_repeatable"
        return result
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
            if not any((action["id"], canonical(action["args"])) in target_actions for action in reduced):
                continue
            matched = probe(reduced)
            if matched is None:
                budget_hit = True
                break
            if matched:
                candidate = reduced
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
    result.update(status="budget_exhausted" if budget_hit else "reduced", actions=candidate,
                  reduced_actions=len(candidate), confirmed_original=True,
                  one_minimal=not budget_hit and granularity >= len(candidate))
    return result
