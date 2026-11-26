#!/usr/bin/env python3
"""Descriptive paired analysis of checked Goblin campaign observations.

This reads the fixed campaign queue and retained receipts. It never runs game
actions, resumes physics, promotes anomalies, or performs statistical inference.
Synthetic tests are explicitly labelled and are not gameplay evidence.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import math
from pathlib import Path
import statistics

from verify_transcript import digest
from vocabulary import FIXTURES, POLICIES

SCHEMA = "cybersand-goblin-paired-comparison-v1"
MAX_EPISODES = 512
MAX_ATTEMPTS_PER_EPISODE = 3
MATCHED_MODES = ("CONTROL", "WANDERER", "BUILDER", "TINKERER", "CURIOSITY", "RANDOM",
                 "STATEFUL", "NOVELTY", "COVERAGE_HUNTER")
DIMENSIONS = ("action", "action_transition", "state_transition", "material_interaction",
              "tool_material", "actor_environment", "lifecycle", "boundary_refusal", "outcome")
COUNTERS = {"attempted_actions": "attempted_records", "admitted_actions": "admitted_observed_actions",
            "completed_actions": "completed_admitted_actions", "partial_actions": "partial_admitted_actions",
            "refusals": "refused_actions"}
METRICS = tuple(COUNTERS) + tuple("unique_" + name for name in DIMENSIONS) + (
    "state_action_pairs", "completed_per_requested_action", "state_transitions_per_100_admitted",
    "wall_seconds", "peak_tree_rss_bytes")
EVIDENCE_FAILURES = {"evidence_failure", "coverage_mismatch", "malformed_evidence", "invalid_transcript"}


def finite(value) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def integral(value, low=0, high=2147483647) -> bool:
    return finite(value) and value == int(value) and low <= value <= high


def distribution(values: list) -> dict:
    """Linear interpolation over observed samples; missing values stay unknown."""
    observed = sorted(float(value) for value in values if finite(value))
    def percentile(fraction):
        if not observed:
            return None
        index = (len(observed) - 1) * fraction
        lower, upper = math.floor(index), math.ceil(index)
        return observed[lower] + (observed[upper] - observed[lower]) * (index - lower)
    return {"observed": len(observed), "missing": len(values) - len(observed),
            "minimum": observed[0] if observed else None, "p25": percentile(0.25),
            "median": statistics.median(observed) if observed else None, "p75": percentile(0.75),
            "maximum": observed[-1] if observed else None,
            "spread_definition": "p25/p75 use linear interpolation; no confidence interval"}


def _plan_rows(plan: dict) -> tuple[dict, dict]:
    rows = plan.get("episodes")
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_EPISODES:
        raise ValueError("Plan must contain 1..512 bounded episodes")
    by_id, blocks = {}, {}
    for episode in rows:
        if not isinstance(episode, dict):
            raise ValueError("Malformed planned episode")
        episode_id = episode.get("id")
        if (not isinstance(episode_id, str) or not 1 <= len(episode_id) <= 180
                or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in episode_id)
                or episode_id in by_id):
            raise ValueError("Duplicate or invalid immutable episode identity")
        if episode.get("policy") not in POLICIES or episode.get("fixture") not in FIXTURES:
            raise ValueError("Episode uses an uncommitted personality or fixture")
        if not integral(episode.get("seed"), -2147483648, 2147483647) or not integral(episode.get("budget"), 1, 1024):
            raise ValueError("Episode seed or budget exceeds the fixed contract")
        if episode.get("cohort") not in ("smoke", "matched", "long", "personality", "scenario"):
            raise ValueError("Unknown finite cohort")
        by_id[episode_id] = episode
        if episode["cohort"] == "matched":
            if episode["policy"] not in MATCHED_MODES:
                raise ValueError("Unexpected personality in matched baseline cohort")
            key = (episode["fixture"], int(episode["seed"]), int(episode["budget"]))
            block = blocks.setdefault(key, {})
            if episode["policy"] in block:
                raise ValueError("Duplicate matched policy within a fixture/seed/budget block")
            block[episode["policy"]] = episode_id
    return by_id, blocks


def _coverage(entry: dict | None) -> tuple[dict | None, str]:
    if entry is None:
        return None, "episode_unattempted"
    value = entry.get("coverage")
    if not isinstance(value, dict):
        return None, "coverage_unavailable"
    if value.get("schema") != "cybersand-goblin-independent-coverage-v1":
        return None, "coverage_schema_unsupported"
    if entry.get("status") in EVIDENCE_FAILURES:
        return None, "evidence_failure_retained"
    if value.get("recorded_count_mismatches") or value.get("recorded_dimension_mismatches"):
        return None, "recorded_coverage_mismatch"
    if value.get("recorded_coverage_present") is not True:
        return None, "current_episode_accounting_unavailable"
    if any(not integral(value.get(key), 0, 1024) for key in COUNTERS.values()):
        return None, "coverage_counters_invalid"
    attempted = int(value["attempted_records"])
    admitted = int(value["admitted_observed_actions"])
    completed = int(value["completed_admitted_actions"])
    partial = int(value["partial_admitted_actions"])
    refused = int(value["refused_actions"])
    if completed + partial != admitted or admitted + refused > attempted:
        return None, "coverage_counter_relationship_invalid"
    unique = value.get("unique")
    if not isinstance(unique, dict) or any(not integral(unique.get(key), 0, 2048) for key in DIMENSIONS):
        return None, "coverage_dimensions_invalid"
    if not integral(value.get("state_action_pairs"), 0, 2048):
        return None, "state_action_counter_invalid"
    return value, "observed"


def _metrics(episode: dict, entry: dict | None) -> dict:
    result = {key: None for key in METRICS}
    coverage, reason = _coverage(entry)
    if coverage is not None and coverage["attempted_records"] > episode["budget"]:
        coverage, reason = None, "observations_exceed_planned_budget"
    result["coverage_availability"] = reason
    if coverage is not None:
        for target, source in COUNTERS.items():
            result[target] = int(coverage[source])
        for dimension in DIMENSIONS:
            result["unique_" + dimension] = int(coverage["unique"][dimension])
        result["state_action_pairs"] = int(coverage["state_action_pairs"])
        result["completed_per_requested_action"] = result["completed_actions"] / episode["budget"]
        if result["admitted_actions"] > 0:
            result["state_transitions_per_100_admitted"] = result["unique_state_transition"] * 100.0 / result["admitted_actions"]
    process = entry.get("process", {}) if entry else {}
    if isinstance(process, dict):
        if finite(process.get("elapsed_seconds")) and process["elapsed_seconds"] >= 0:
            result["wall_seconds"] = float(process["elapsed_seconds"])
        if integral(process.get("peak_tree_rss_bytes"), 0, 2**53):
            result["peak_tree_rss_bytes"] = int(process["peak_tree_rss_bytes"])
    result["attempted_budget_completed"] = bool(
        entry and entry.get("status") == "pass" and coverage is not None
        and result["attempted_actions"] == episode["budget"])
    return result


def _cost(entries: list[dict]) -> dict:
    wall, memory = [], []
    for entry in entries:
        process = entry.get("process", {})
        elapsed = process.get("elapsed_seconds") if isinstance(process, dict) else None
        rss = process.get("peak_tree_rss_bytes") if isinstance(process, dict) else None
        wall.append(float(elapsed) if finite(elapsed) and elapsed >= 0 else None)
        memory.append(int(rss) if integral(rss, 0, 2**53) else None)
    known_wall = [value for value in wall if value is not None]
    known_memory = [value for value in memory if value is not None]
    return {"attempts": len(entries), "known_wall_seconds": sum(known_wall) if known_wall else None,
            "wall_measurements": len(known_wall), "wall_measurements_missing": len(wall) - len(known_wall),
            "wall_cost_complete": bool(entries) and len(known_wall) == len(entries),
            "peak_observed_tree_rss_bytes": max(known_memory) if known_memory else None,
            "memory_measurements_missing": len(memory) - len(known_memory),
            "status_counts": dict(sorted(Counter(entry.get("status", "unreported") for entry in entries).items())),
            "scope": "sum of observed per-process wall time; sampled tree RSS is a per-attempt peak, not cumulative memory"}


def _behavior(entry: dict | None, metrics: dict) -> Counter | None:
    """Completed action frequencies are usable only with agreeing observed totals."""
    if not entry or metrics["completed_actions"] is None:
        return None
    value = entry.get("summary", {}).get("completed_features")
    if not isinstance(value, dict) or len(value) > 64:
        return None
    if any(not isinstance(key, str) or len(key) > 80 or not integral(count, 0, 1024)
           for key, count in value.items()):
        return None
    if sum(value.values()) != metrics["completed_actions"]:
        return None
    return Counter({key: int(count) for key, count in value.items() if count > 0})


def _behavior_summary(entries: list[tuple[dict | None, dict]]) -> dict:
    total, measured = Counter(), 0
    for entry, metrics in entries:
        counts = _behavior(entry, metrics)
        if counts is not None:
            measured += 1
            total.update(counts)
    count = sum(total.values())
    entropy = -sum((n / count) * math.log2(n / count) for n in total.values()) if count else None
    return {"episodes_with_verified_action_frequencies": measured,
            "episodes_without_action_frequencies": len(entries) - measured,
            "completed_action_counts": dict(sorted(total.items())),
            "completed_action_proportions": {key: value / count for key, value in sorted(total.items())} if count else {},
            "shannon_entropy_bits": entropy, "effective_action_types": 2**entropy if entropy is not None else None,
            "scope": "observed completed-action distribution; diversity is not defect yield or successful navigation"}


def compare(episodes: list[dict], plan: dict, attempts: list[dict] | None = None) -> dict:
    """Analyze latest checked episodes; optional attempts retain retry costs."""
    planned, blocks = _plan_rows(plan)
    if not isinstance(episodes, list) or len(episodes) > len(planned):
        raise ValueError("Selected episode list exceeds immutable plan")
    selected = {}
    for entry in episodes:
        if not isinstance(entry, dict) or not isinstance(entry.get("episode"), dict):
            raise ValueError("Malformed selected result")
        episode_id = entry["episode"].get("id")
        if episode_id not in planned or entry["episode"] != planned[episode_id] or episode_id in selected:
            raise ValueError("Selected result differs from unique planned episode")
        selected[episode_id] = entry
    measured = {key: _metrics(episode, selected.get(key)) for key, episode in planned.items()}
    by_group = {}
    for key, episode in planned.items():
        by_group.setdefault(episode["cohort"] + "/" + episode["policy"], []).append(key)
    groups = {}
    for group, ids in sorted(by_group.items()):
        completed_ids = [key for key in ids if measured[key]["attempted_budget_completed"]]
        groups[group] = {"planned_episodes": len(ids), "selected_attempts": sum(key in selected for key in ids),
                         "attempted_budget_completed_episodes": len(completed_ids),
                         "completion_fraction_of_planned": len(completed_ids) / len(ids),
                         "all_planned_episode_metrics": {metric: distribution([measured[key][metric] for key in ids]) for metric in METRICS},
                         "budget_complete_episode_metrics": {metric: distribution([measured[key][metric] for key in completed_ids]) for metric in METRICS},
                         "coverage_availability": dict(sorted(Counter(measured[key]["coverage_availability"] for key in ids).items())),
                         "latest_attempt_cost": _cost([selected[key] for key in ids if key in selected]),
                         "observed_behavior": _behavior_summary([(selected.get(key), measured[key]) for key in ids])}
    block_rows = []
    for key, modes in sorted(blocks.items()):
        missing_plan = [mode for mode in MATCHED_MODES if mode not in modes]
        missing_result = [mode for mode, episode_id in modes.items() if episode_id not in selected]
        incomplete = {mode: selected[episode_id].get("status", "unreported")
                      for mode, episode_id in modes.items()
                      if episode_id in selected and not measured[episode_id]["attempted_budget_completed"]}
        block_rows.append({"fixture": key[0], "seed": key[1], "budget": key[2],
                           "expected_modes": list(MATCHED_MODES), "planned_modes": sorted(modes),
                           "missing_planned_modes": missing_plan, "unattempted_modes": sorted(missing_result),
                           "incomplete_or_invalid_modes": incomplete,
                           "all_modes_budget_complete": not (missing_plan or missing_result or incomplete)})
    paired = []
    comparisons = [(mode, "RANDOM") for mode in MATCHED_MODES if mode != "RANDOM"]
    comparisons += [(mode, "CONTROL") for mode in ("STATEFUL", "NOVELTY", "COVERAGE_HUNTER")]
    for candidate, baseline in comparisons:
        eligible, excluded = [], []
        for key, modes in sorted(blocks.items()):
            if candidate not in modes or baseline not in modes:
                excluded.append({"fixture": key[0], "seed": key[1], "budget": key[2], "reason": "pair_missing_from_plan"})
                continue
            pair = (modes[candidate], modes[baseline])
            if not all(measured[episode_id]["attempted_budget_completed"] for episode_id in pair):
                excluded.append({"fixture": key[0], "seed": key[1], "budget": key[2], "reason": "pair_not_both_budget_complete"})
                continue
            eligible.append((key, pair))
        measures = {}
        for metric in METRICS:
            differences, pairs = [], []
            for key, (first, second) in eligible:
                a, b = measured[first][metric], measured[second][metric]
                delta = a - b if finite(a) and finite(b) else None
                differences.append(delta)
                pairs.append({"fixture": key[0], "seed": key[1], "budget": key[2],
                              "candidate": a, "baseline": b, "difference": delta})
            measures[metric] = {"candidate_minus_baseline": distribution(differences), "pairs": pairs}
        paired.append({"candidate": candidate, "baseline": baseline, "eligible_blocks": len(eligible),
                       "excluded_blocks": excluded, "metrics": measures,
                       "selection_rule": "both selected episodes reached the requested attempted-action budget with valid coverage",
                       "interpretation": "descriptive paired differences; no causal ranking, confidence interval or significance claim"})
    attempt_report = {"available": attempts is not None, "scope": "all retained attempts supplied by the checked queue reader"}
    if attempts is not None:
        if not isinstance(attempts, list) or len(attempts) > len(planned) * MAX_ATTEMPTS_PER_EPISODE:
            raise ValueError("Retained attempts exceed finite queue retry bound")
        seen, first, attempt_groups = set(), {}, {}
        for entry in attempts:
            if not isinstance(entry, dict) or not isinstance(entry.get("episode"), dict):
                raise ValueError("Malformed retained attempt")
            episode_id = entry["episode"].get("id")
            number = entry.get("attempt_number", entry.get("attempt", {}).get("number"))
            if (episode_id not in planned or entry["episode"] != planned[episode_id]
                    or not integral(number, 1, MAX_ATTEMPTS_PER_EPISODE) or (episode_id, int(number)) in seen):
                raise ValueError("Retained attempt differs from unique bounded queue identity")
            seen.add((episode_id, int(number)))
            if episode_id not in first or number < first[episode_id][0]:
                first[episode_id] = (int(number), entry)
            group = planned[episode_id]["cohort"] + "/" + planned[episode_id]["policy"]
            attempt_groups.setdefault(group, []).append(entry)
        first_pass = sum(number == 1 and entry.get("status") == "pass" for number, entry in first.values())
        attempt_report.update(_cost(attempts))
        attempt_report["first_attempt_budget_completed_episodes"] = first_pass
        attempt_report["first_attempt_completion_fraction_of_planned"] = first_pass / len(planned)
        attempt_report["planned_episodes_without_first_attempt_receipt"] = sum(key not in first or first[key][0] != 1 for key in planned)
        attempt_report["groups"] = {key: _cost(entries) for key, entries in sorted(attempt_groups.items())}
    horizons = [{"episode": planned[key], "selected_status": selected.get(key, {}).get("status", "unattempted"),
                 "measurements": measured[key]} for key in planned if planned[key]["cohort"] == "long"]
    provenance = plan.get("provenance", {})
    return {"schema": SCHEMA, "plan_sha256": plan.get("plan_sha256"), "source_commit": provenance.get("source_commit"),
            "source_tree": provenance.get("source_tree"), "source_dirty": provenance.get("source_dirty"),
            "planned_episodes": len(planned), "selected_episode_results": len(selected),
            "matched_block_count": len(block_rows), "complete_matched_blocks": sum(row["all_modes_budget_complete"] for row in block_rows),
            "matched_blocks": block_rows, "groups": groups, "paired_comparisons": paired,
            "all_attempt_cost": attempt_report, "long_horizon_observations": horizons,
            "missing_data_rule": "unattempted or unavailable observations remain unknown; observed zero remains zero",
            "attempt_selection": "latest retained result per immutable episode; all attempts retain separate cost and first-attempt completion",
            "scope": "descriptive experiment accounting; valid partial observations remain distinct from completed episodes",
            "material_scope": "captured-region adjacency and edit transformations, not inferred chemical reactions or whole-world coverage",
            "actor_scope": "observed model, fixture, spatial zone and pilot role, not route completion",
            "long_horizon_scope": "one construction fixture and seed per policy/budget; no broad scaling inference",
            "confirmed_production_defects": [], "statistical_inference_performed": False}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="Existing bounded campaign queue directory")
    args = parser.parse_args(argv)
    # Import here to keep the analysis API independent of process-launch modules.
    from campaign_queue import collect, collect_attempts
    from run_goblin import write_json
    out = args.out.resolve(strict=True)
    queue_path = out / "queue.json"
    if queue_path.stat().st_size > 16 * 1024 * 1024:
        raise ValueError("Queue record exceeds the bounded analysis input")
    queue = json.loads(queue_path.read_text(encoding="utf-8"))
    if queue.get("schema") != "cybersand-goblin-experiment-queue-v1":
        raise ValueError("Unknown campaign queue")
    plan = queue["plan"]
    if digest({key: value for key, value in plan.items() if key != "plan_sha256"}) != plan.get("plan_sha256"):
        raise ValueError("Immutable plan checksum differs")
    report = compare(collect(out, queue, recheck=True), plan, collect_attempts(out, queue, recheck=True))
    write_json(out / "paired-comparison.json", report)
    print(json.dumps({"schema": report["schema"], "planned_episodes": report["planned_episodes"],
                      "matched_block_count": report["matched_block_count"],
                      "complete_matched_blocks": report["complete_matched_blocks"],
                      "statistical_inference_performed": False}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
