"""Four-stream D-1A matched offline controls; NOT a model/native fleet.

The frozen 36-decision fixtures and the accepted M1 contract are read-only.
An experimental 128-decision overlay is admitted only after the bounded
geometric oracle finishes under an explicit predecessor-probe cap.
"""
from __future__ import annotations

import hashlib
import json
import random
from pathlib import Path
from typing import Any

VERSION = "d1a-four-stream-controls/3"
M1_COMMIT = "8fa90de6be209ed0b7bd125039e6ec8b332fb1a6"
M1_SCHEMA_SHA256 = "ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d"
POLICIES = ("astar_or_contour", "random_legal", "random_legal_persistent_v1")
# Model families are intended future streams, NOT loaded checkpoint identities.
SLOTS = (
    ("d1a-wrangler-01", "d1-2B-Q4", "wall_step_v1", 103),
    ("d1a-wrangler-02", "LFM2.5-350M", "route_gate_v1", 211),
    ("d1a-wrangler-03", "Sprocket-500M", "wall_recess_v1", 307),
    ("d1a-wrangler-04", "SmolLM2-135M", "route_hook_v1", 401),
)
MACROS = (1, 2, 4, 8)
MAX_HORIZON = 128
MAX_ORACLE_PROBES = 3_000_000
EPISODE_ID_VERSION = "d1a-synthetic-episode-identity/1"


class ControlRefused(ValueError):
    """An input or resource gate prevented source-qualified offline controls."""


def digest(data: Any) -> str:
    return hashlib.sha256(json.dumps(data, sort_keys=True, separators=(",", ":"),
                                     allow_nan=False).encode("utf8")).hexdigest()


def _source_fingerprints(offline: Any, oracle: Any, character: Any) -> dict[str, str]:
    """Content identities for both completed and failed offline episodes."""
    return {
        "fleet_controls_source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "oracle_source_sha256": hashlib.sha256(Path(oracle.__file__).read_bytes()).hexdigest(),
        "offline_source_sha256": hashlib.sha256(Path(offline.__file__).read_bytes()).hexdigest(),
        "line_character_source_sha256": hashlib.sha256(Path(character.__file__).read_bytes()).hexdigest(),
    }


def _episode_run_id(slot: dict[str, Any], horizon: int, probe_cap: int,
                    source_fingerprints: dict[str, str]) -> str:
    """Distinguish actual synthetic episodes from the planned wrangler slot.

    A 36/128 run, a changed oracle cap, or changed executed Python source
    must not reuse a synthetic execution identity. This is never a model or
    native lease/receipt identifier.
    """
    return digest([EPISODE_ID_VERSION, slot["synthetic_run_id"], horizon,
                   probe_cap, source_fingerprints])


def _lane_modules():
    from . import offline, budget_oracle
    return offline, budget_oracle


def _get_fixture(fixture_id: str):
    offline, _ = _lane_modules()
    by_id = {f.fixture_id: f for f in offline.fixtures() if f.split == "development"}
    if fixture_id not in by_id:
        raise ControlRefused("Unknown or held-out fixture: outcomes remain sealed")
    fixture = by_id[fixture_id]
    offline.require_development_fixture(fixture)
    return fixture


def validate_slot(slot: dict[str, Any], *, require_native: bool = False) -> None:
    """Reject fabricated execution identities and mismatched control recipes."""
    if type(slot) is not dict or slot.get("version") != VERSION:
        raise ControlRefused("Unknown handoff version")
    i = slot.get("slot_index")
    if type(i) is not int or not 0 <= i < len(SLOTS):
        raise ControlRefused("Not a registered slot")
    wrangler, family, fixture_id, seed = SLOTS[i]
    if (slot.get("wrangler_id"), slot.get("requested_model_family"),
        slot.get("fixture_id"), slot.get("seed")) != (wrangler, family, fixture_id, seed):
        raise ControlRefused("Slot identity/source mismatch")
    if (slot.get("m1_commit"), slot.get("m1_schema_sha256")) != (M1_COMMIT, M1_SCHEMA_SHA256):
        raise ControlRefused("M1 identity mismatch")
    if slot.get("source_kind") != "synthetic_development_only":
        raise ControlRefused("Synthetic controls cannot masquerade as native/model outcomes")
    if (slot.get("fixture_split") != "development" or
        slot.get("frozen_fixture_budget") != 36 or
        slot.get("policies") != list(POLICIES) or
        slot.get("macro_lengths") != list(MACROS) or
        slot.get("status") != "planned_offline_controls" or
        slot.get("native_logical_move_cap_unmodified") != 64 or
        slot.get("native_128_turn_approved") is not False):
        raise ControlRefused("Control recipe, split or 64-move host boundary changed")
    if any(slot.get(k) is not None for k in
           ("model_checkpoint_sha256", "github_run_id", "github_job_id", "resident_pid",
            "native_world_sha256", "native_receipt_artifact")):
        raise ControlRefused("Unverified real execution or model identity in planned slot")
    if slot.get("active_worms") != 0 or slot.get("sequential_native_receipts") != 0:
        raise ControlRefused("Planned synthetic slots cannot be counted as live worms")
    if slot.get("native_qualified") is not False or require_native:
        raise ControlRefused("No D-1A native execution or 128-turn host qualification")
    f = _get_fixture(fixture_id)
    if slot.get("fixture_sha256") != f.sha256:
        raise ControlRefused("Fixture source fingerprint changed")
    if slot.get("synthetic_run_id") != digest([VERSION, i, wrangler, fixture_id, f.sha256, seed]):
        raise ControlRefused("Synthetic run identity altered")


def make_slots() -> tuple[dict[str, Any], ...]:
    """Four distinct planned streams; never pretend to load any model."""
    result = []
    for i, (wrangler, family, fixture_id, seed) in enumerate(SLOTS):
        f = _get_fixture(fixture_id)
        record = {
            "version": VERSION, "slot_index": i, "wrangler_id": wrangler,
            "requested_model_family": family, "model_checkpoint_sha256": None,
            "github_run_id": None, "github_job_id": None, "resident_pid": None,
            "native_world_sha256": None, "native_receipt_artifact": None,
            "fixture_id": fixture_id, "fixture_sha256": f.sha256,
            "fixture_split": "development", "frozen_fixture_budget": f.budget,
            "seed": seed, "source_kind": "synthetic_development_only",
            "m1_commit": M1_COMMIT, "m1_schema_sha256": M1_SCHEMA_SHA256,
            "native_qualified": False, "sequential_native_receipts": 0,
            "active_worms": 0, "status": "planned_offline_controls",
            "policies": list(POLICIES), "macro_lengths": list(MACROS),
            "native_logical_move_cap_unmodified": 64,
            "native_128_turn_approved": False,
            "synthetic_run_id": digest([VERSION, i, wrangler, fixture_id, f.sha256, seed]),
        }
        validate_slot(record)
        result.append(record)
    if len({r["synthetic_run_id"] for r in result}) != 4:
        raise ControlRefused("Duplicate stream run identities")
    return tuple(result)


def _rollout(f, policy: str, seed: int, horizon: int) -> dict[str, Any]:
    """Source-matched synthetic cursor sweep, never a brush/material receipt."""
    offline, _ = _lane_modules()
    rng = random.Random(seed)
    pos = f.start
    path = [pos]
    events = []
    stop = "budget_exhausted"
    for decision in range(horizon):
        if pos == f.target:
            stop = "arrived"
            break
        options = offline.candidates(f, pos, MACROS)
        if not options or options[0].candidate_id != "STOP":
            raise ControlRefused("Frozen legal menu did not contain STOP")
        real_policy = ("contour_astar" if f.task == "wall_offset" else "astar") if policy == "astar_or_contour" else policy
        choice = offline.select_candidate(f, pos, options, real_policy, rng)
        if choice not in options or any(not f.legal(p) for p in choice.path):
            raise ControlRefused("Illegal proposed movement or swept path")
        before = pos
        if choice.stop:
            stop = ("no_legal_moves" if policy == "random_legal_persistent_v1"
                    and not any(not c.stop for c in options) else "policy_stop")
        else:
            path.extend(choice.path)
            pos = choice.path[-1]
        events.append({
            "decision": decision, "before": list(before),
            "legal_set_sha256": offline.digest([c.source() for c in options]),
            "choice_id": choice.candidate_id, "swept_cells": [list(p) for p in choice.path],
            "after": list(pos), "path_sha256": offline.digest(path),
            "native_receipt_ref": None,
        })
        if choice.stop:
            break
    else:
        if pos == f.target:
            stop = "arrived"
    score = offline.score_episode(f, path, len(events), stop)
    from .line_character import describe_cursor_path
    # Geometry descriptors quantify unusual steering; they do not score art
    # or imply painted material, model decisions or native evidence.
    character = describe_cursor_path(path)
    if character["movement_cells"] != score["cursor_cell_steps"] or (
        character["revisited_cursor_steps"] != score["retraced_cells"]
    ):
        raise ControlRefused("Cursor-line fingerprint and swept scoring disagree")
    return {
        "policy": policy, "seed": seed, "synthetic_decision_budget": horizon,
        "source_kind": "synthetic_development_only", "native_qualified": False,
        "sequential_native_receipts": 0, "material_effect": "none",
        "final_cursor": list(pos), "events": events, "path": [list(p) for p in path],
        "metrics": score, "line_character": character,
        "trajectory_sha256": digest([list(p) for p in path]),
        "record_sha256": digest([events, score]),
    }


def run_matched_controls(slot: dict[str, Any], *, horizon: int = 36,
                         oracle_probe_cap: int = MAX_ORACLE_PROBES) -> dict[str, Any]:
    """Run three synthetic controls only after a bounded oracle preflight.

    128 is an independent synthetic overlay, not a mutation of the sealed
    36-turn fixture or a native 64-logical-move-limit extension.
    """
    validate_slot(slot)
    if type(horizon) is not int or horizon not in (36, MAX_HORIZON):
        raise ControlRefused("Only 36 or synthetic 128 decision horizons admitted")
    if type(oracle_probe_cap) is not int or not 1 <= oracle_probe_cap <= MAX_ORACLE_PROBES:
        raise ControlRefused("Oracle work cap must be <= 3 million probes")
    f = _get_fixture(slot["fixture_id"])
    _, budget_oracle = _lane_modules()
    from . import offline, line_character
    source_fingerprints = _source_fingerprints(offline, budget_oracle, line_character)
    episode_id = _episode_run_id(slot, horizon, oracle_probe_cap, source_fingerprints)
    clearance = (lambda p: offline.wall_distance(f, p)) if f.task == "wall_offset" else None
    try:
        oracle = budget_oracle.bounded_optimal_route(
            f.width, f.height, f.start, f.target, f.legal, MACROS,
            clearance, decision_budget=horizon, max_predecessor_probes=oracle_probe_cap)
    except budget_oracle.PlanningBudgetExceeded as exc:
        return {
            "version": VERSION, "slot_index": slot["slot_index"],
            "synthetic_run_id": slot["synthetic_run_id"],
            "episode_run_id": episode_id, **source_fingerprints,
            "horizon": horizon, "state": "ORACLE_RESOURCE_EXHAUSTED",
            "error": str(exc), "oracle_probe_cap": exc.predecessor_probe_cap,
            "oracle_version": budget_oracle.VERSION,
            "oracle_predecessor_probes": exc.predecessor_probes,
            "oracle_failure_kind": "resource_exhausted_before_optimum",
            "oracle_optimal_cost_within_budget": None,
            "oracle_feasible_arrival_within_budget": None,
            "arms": [], "native_qualified": False, "sequential_native_receipts": 0,
            "model_outcome": None,
        }
    arms = [_rollout(f, policy, slot["seed"], horizon) for policy in POLICIES]
    first_menus = {a["events"][0]["legal_set_sha256"] for a in arms if a["events"]}
    if len(first_menus) != 1:
        raise ControlRefused("Matched-control initial legal menus differ")
    return {
        "version": VERSION, "slot_index": slot["slot_index"],
        "synthetic_run_id": slot["synthetic_run_id"],
        "episode_run_id": episode_id,
        "fixture_id": f.fixture_id, "fixture_sha256": f.sha256,
        "horizon": horizon, "state": "SYNTHETIC_CONTROLS_COMPLETE",
        "frozen_fixture_budget": f.budget, "source_kind": "synthetic_development_only",
        "oracle": {"version": oracle["version"],
                   "objective": oracle["objective"],
                   "predecessor_probes": oracle["predecessor_probes"],
                   "probe_cap": oracle["predecessor_probe_cap"],
                   "feasible_arrival_within_budget": oracle["feasible_arrival_within_budget"],
                   "optimal_cost_within_budget": oracle["optimal_cost_within_budget"]},
        **source_fingerprints,
        "common_initial_legal_set_sha256": next(iter(first_menus), None),
        "arms": arms, "native_qualified": False,
        "sequential_native_receipts": 0, "model_outcome": None,
        "native_128_turn_approved": False,
    }


def replay_matched_controls(slot: dict[str, Any], report: dict[str, Any]) -> bool:
    """Reject altered synthetic evidence; do not evaluate any held-out case."""
    validate_slot(slot)
    if report.get("state") != "SYNTHETIC_CONTROLS_COMPLETE":
        raise ControlRefused("Resource-exhausted/incomplete report has no success replay")
    f = _get_fixture(slot["fixture_id"])
    if (report.get("synthetic_run_id") != slot["synthetic_run_id"] or
        report.get("fixture_sha256") != f.sha256 or
        report.get("horizon") not in (36, 128)):
        raise ControlRefused("Report/source/horizon mismatch")
    original = report.get("arms")
    if type(original) is not list or len(original) != len(POLICIES):
        raise ControlRefused("Missing or extra matched control arms")
    oracle = report.get("oracle")
    if type(oracle) is not dict:
        raise ControlRefused("Oracle provenance absent")
    probe_cap = oracle.get("probe_cap")
    if type(probe_cap) is not int or not 1 <= probe_cap <= MAX_ORACLE_PROBES:
        raise ControlRefused("Invalid oracle probe cap")
    # Re-execute exact bounded oracle and all three controls; compare the
    # complete record, including oracle cost, source bytes and negative arms.
    expected = run_matched_controls(slot, horizon=report["horizon"],
                                    oracle_probe_cap=probe_cap)
    if report != expected:
        raise ControlRefused("Source/oracle/control replay mismatch")
    return True


def compact_handoff(slots: tuple[dict[str, Any], ...],
                    reports: tuple[dict[str, Any], ...]) -> dict[str, Any]:
    """Commander/Ethologist summary without laundering model or native claims."""
    if len(slots) != 4 or len(reports) != 4:
        raise ControlRefused("Require four independently named streams")
    if len({s["synthetic_run_id"] for s in slots}) != 4:
        raise ControlRefused("Duplicate synthetic run identity")
    summary = []
    cohort_horizons: set[int] = set()
    cohort_caps: set[int] = set()
    episode_ids: set[str] = set()
    for slot, report in zip(slots, reports):
        validate_slot(slot)
        if report.get("synthetic_run_id") != slot["synthetic_run_id"]:
            raise ControlRefused("Wrong paired slot report")
        if report.get("state") == "SYNTHETIC_CONTROLS_COMPLETE":
            replay_matched_controls(slot, report)
        elif report.get("state") == "ORACLE_RESOURCE_EXHAUSTED":
            cap = report.get("oracle_probe_cap")
            if (type(cap) is not int or not 1 <= cap <= MAX_ORACLE_PROBES or
                report.get("arms") != [] or report.get("sequential_native_receipts") != 0 or
                report.get("native_qualified") is not False or
                report.get("model_outcome") is not None or
                report.get("oracle_predecessor_probes") != cap + 1 or
                report.get("oracle_failure_kind") != "resource_exhausted_before_optimum" or
                report.get("oracle_optimal_cost_within_budget") is not None or
                report.get("oracle_feasible_arrival_within_budget") is not None):
                raise ControlRefused("Invalid resource-exhaustion evidence")
            if report != run_matched_controls(slot, horizon=report["horizon"],
                                              oracle_probe_cap=cap):
                raise ControlRefused("Resource-exhaustion replay mismatch")
        else:
            raise ControlRefused("Unqualified report state")
        cohort_horizons.add(report["horizon"])
        actual_cap = (report["oracle"]["probe_cap"] if
                      report["state"] == "SYNTHETIC_CONTROLS_COMPLETE"
                      else report["oracle_probe_cap"])
        cohort_caps.add(actual_cap)
        episode_id = report.get("episode_run_id")
        if not isinstance(episode_id, str) or len(episode_id) != 64 or episode_id in episode_ids:
            raise ControlRefused("Duplicate or missing exact synthetic episode identity")
        episode_ids.add(episode_id)
        summary.append({
            "episode_run_id": episode_id,
            "wrangler_id": slot["wrangler_id"],
            "requested_model_family": slot["requested_model_family"],
            "synthetic_run_id": slot["synthetic_run_id"],
            "fixture_id": slot["fixture_id"], "seed": slot["seed"],
            "horizon": report["horizon"], "state": report["state"],
            "oracle_predecessor_probes": report.get("oracle", {}).get(
                "predecessor_probes", report.get("oracle_predecessor_probes")),
            "oracle_probe_cap": report.get("oracle", {}).get("probe_cap", report.get("oracle_probe_cap")),
            "oracle_version": report.get("oracle", {}).get("version", report.get("oracle_version")),
            "oracle_failure_kind": report.get("oracle_failure_kind"),
            "oracle_objective": report.get("oracle", {}).get("objective"),
            "oracle_optimal_cost_within_budget": report.get("oracle", {}).get("optimal_cost_within_budget"),
            "oracle_feasible_arrival_within_budget": report.get("oracle", {}).get("feasible_arrival_within_budget"),
            "fleet_controls_source_sha256": report.get("fleet_controls_source_sha256"),
            "oracle_source_sha256": report.get("oracle_source_sha256"),
            "offline_source_sha256": report.get("offline_source_sha256"),
            "line_character_source_sha256": report.get("line_character_source_sha256"),
            "arm_line_character": {
                arm["policy"]: {
                    "character_sha256": digest(arm["line_character"]),
                    "turn_fraction": arm["line_character"]["turn_fraction_per_heading_transition"],
                    "clockwise_turns": arm["line_character"]["right_angle_clockwise_turns"],
                    "counterclockwise_turns": arm["line_character"]["left_angle_counterclockwise_turns"],
                    "reverse_turns": arm["line_character"]["immediate_reverse_turns"],
                    "closed_loops": arm["line_character"]["nontrivial_loop_closures"],
                    "reused_edges": arm["line_character"]["reused_undirected_edge_steps"],
                    "heading_entropy_bits": arm["line_character"]["heading_entropy_bits"],
                    "longest_straight": arm["line_character"]["maximum_consecutive_straight_cells"],
                } for arm in report["arms"]
            },
            "common_initial_legal_set_sha256": report.get("common_initial_legal_set_sha256"),
            "arm_trajectory_sha256": {a["policy"]: a["trajectory_sha256"] for a in report["arms"]},
            "arm_metrics": {a["policy"]: a["metrics"] for a in report["arms"]},
            "source_kind": "synthetic_development_only",
            "native_receipts": 0, "model_outcome": None,
        })
    if len(cohort_horizons) != 1 or len(cohort_caps) != 1:
        raise ControlRefused("Four-stream comparison requires the same horizon and oracle probe cap")
    return {
        "version": VERSION, "recipient_roles": ["Wormfleet Commander", "Worm Ethologist"],
        "matched_horizon": next(iter(cohort_horizons)),
        "matched_oracle_probe_cap": next(iter(cohort_caps)),
        "m1_commit": M1_COMMIT, "m1_schema_sha256": M1_SCHEMA_SHA256,
        "streams": summary, "native_64_logical_move_limit_unchanged": True,
        "four_loaded_models": False, "native_128_approved": False,
        "heldout_outcomes_evaluated": False,
        "cohort_sha256": digest(summary),
    }

def main() -> int:
    """CLI: exact-source-gated CPU-only matched controls; never dispatch native."""
    import argparse
    from .qualification import source_fence
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--horizon", type=int, choices=(36, 128), default=36)
    parser.add_argument("--oracle-probe-cap", type=int, default=MAX_ORACLE_PROBES)
    parser.add_argument("--output", type=Path, help="Optional local JSON handoff path")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[4]
    source_sha = source_fence(root)
    slots = make_slots()
    reports = tuple(run_matched_controls(slot, horizon=args.horizon,
                                         oracle_probe_cap=args.oracle_probe_cap)
                    for slot in slots)
    handoff = compact_handoff(slots, reports)
    handoff["source_commit"] = source_sha
    handoff["all_four_controls_completed"] = all(
        report["state"] == "SYNTHETIC_CONTROLS_COMPLETE" for report in reports)
    payload = json.dumps(handoff, sort_keys=True, indent=2) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
    else:
        print(payload, end="")
    return 0 if handoff["all_four_controls_completed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
