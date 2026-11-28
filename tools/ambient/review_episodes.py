#!/usr/bin/env python3
"""Independently audit the frozen AMBIENT-002 raw traces and reduced summary.

This post-run tool does not execute actors or contribute to the episode count.
Its computations are deliberately separate from analyze_episodes.py. Original
raw reports, reducer summaries and this script are identified by SHA-256.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import re
import statistics
import sys

SOCIAL_TYPES = {"follow_actor", "avoid_crowding", "observe_actor", "regroup",
                "align_peers", "disperse", "avoid_peer"}
GOAL_TYPES = {"investigate_material", "explore_unfamiliar", "revisit_interest", "patrol_route",
              "prefer_region", "search_last_seen", "exploration_destination", "seek_home_drive",
              "observe_actor", "regroup", "disperse"}
EXPECTED_CAMPAIGNS = 122
EXPECTED_EPISODES = 194
EXPECTED_AUXILIARIES = 16
DT = 0.1


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_bytes())


def close(actual, expected, label, tolerance=1e-6):
    if expected is None:
        require(actual is None, label+": expected unavailable value")
    else:
        require(isinstance(actual, (int, float)) and not isinstance(actual, bool)
                and math.isfinite(actual) and abs(actual-expected) <= tolerance,
                f"{label}: {actual!r} differs from independently computed {expected!r}")


def geometric_distance(a, b, flying):
    return math.dist(a, b) if flying else abs(a[0]-b[0])


def independent_metrics(campaign, actor):
    """Compute sampled movement without consulting the existing reducer."""
    trace = actor["trace"]
    require(trace, "Missing physical trajectory")
    flying = actor["model"] == "4ly_trainer"
    points = [sample["position"] for sample in trace] + [actor["last"]]
    bins = [(math.floor(p[0]/16), math.floor(p[1]/16) if flying else 0)
            for p in points[:-1]]
    occupancy = Counter(bins)
    visited = set()
    reentries = 0
    for i, cell in enumerate(bins):
        if i == 0 or cell != bins[i-1]:
            reentries += cell in visited
            visited.add(cell)
    active = stalled = transitions = idle = neutral = departures = returns = 0
    away = False
    for i, sample in enumerate(trace):
        require(abs(sample["seconds"]-i*DT) < 1e-5, "Incomplete physical observation clock")
        idle += sample["has_procedural_intent"] and (
            math.hypot(*sample["intent_direction"]) <= .05 or sample["intent_pace"] <= 0)
        neutral += math.hypot(*sample["action_move"]) <= .05
        home = geometric_distance(sample["position"], actor["start"], flying)
        if not away and home >= 40:
            away = True
            departures += 1
        elif away and home <= 16:
            away = False
            returns += 1
        for material in ("oil", "water"):
            target = sample[material]
            require(target["available"], "Outcome sensor coverage lost")
            if target["present"]:
                close(target["distance"], math.dist(target["nearest"], sample["position"]),
                      actor["episode_id"]+": "+material+" copied sample distance", 1e-4)
        if i == 0:
            continue
        prior = trace[i-1]
        transitions += sample["selection"] != prior["selection"]
        if math.hypot(*prior["action_move"]) > .05:
            active += 1
            stalled += geometric_distance(prior["position"], sample["position"], flying) < .25
    sampled_path = sum(math.dist(a, b) for a, b in zip(points, points[1:]))
    require(sampled_path <= actor["physical_path_cells"] + 1e-3,
            "Sampled centre path exceeds every-step physical path")
    result = {
        "x_range_cells": max(p[0] for p in points)-min(p[0] for p in points),
        "y_range_cells": max(p[1] for p in points)-min(p[1] for p in points),
        "net_displacement_cells": geometric_distance(points[-1], actor["start"], flying),
        "stable_territory_cells": sum(count >= 5 for count in occupancy.values()),
        "observed_territory_cells": len(occupancy), "territory_reentries": reentries,
        "intention_transitions": transitions, "intentional_idle_seconds": idle*DT,
        "neutral_command_seconds": neutral*DT, "active_intervals": active,
        "stalled_active_intervals": stalled,
        "stalled_active_fraction": stalled/active if active else None,
        "home_departures_40_cells": departures, "home_returns_16_cells": returns,
        "home_distance_final": geometric_distance(points[-1], actor["start"], flying),
    }
    close(actor["active_intervals"], active, actor["episode_id"]+": raw active counter")
    close(actor["stalled_active_intervals"], stalled, actor["episode_id"]+": raw stall counter")
    return result


def audit_copied_peers(campaign):
    actors = campaign["episodes"]
    count = 0
    for index in range(len(actors[0]["trace"])):
        points = [actor["trace"][index]["position"] for actor in actors]
        for slot, actor in enumerate(actors):
            sample = actor["trace"][index]
            distances = [math.dist(points[slot], p) for other, p in enumerate(points) if other != slot]
            close(sample["nearest_peer"], min(distances) if distances else None,
                  actor["episode_id"]+": copied peer distance", 1e-4)
            close(sample["observed_peer_count"], sum(d <= 96 for d in distances),
                  actor["episode_id"]+": bounded peer count")
            count += 1
    return count


def selection_activity(actor):
    """Describe recorded labels/phases without inventing missing goal identities."""
    trace = actor["trace"]
    types = {module["id"]: module["type"] for module in actor["profile"].get("modules", [])}
    changes = [(before, after) for before, after in zip(trace, trace[1:])
               if before["selection"] != after["selection"]]
    phases = sum(before["selection"] == after["selection"] and before.get("phase", "") != after.get("phase", "")
                 for before, after in zip(trace, trace[1:]))
    occupied = Counter((sample["selection"], sample.get("phase", "")) for sample in trace)
    return {
        "selection_label_changes": len(changes),
        "blend_to_blend_label_changes": sum(a["selection"].startswith("blend:") and b["selection"].startswith("blend:")
                                              for a, b in changes),
        "direct_goal_module_label_changes": sum(types.get(a["selection"]) in GOAL_TYPES and types.get(b["selection"]) in GOAL_TYPES
                                                 for a, b in changes),
        "same_module_phase_changes": phases,
        "goal_bearing_module_selected_seconds": sum(types.get(s["selection"]) in GOAL_TYPES for s in trace)*DT,
        "home_module_authored": any(t in {"seek_home_drive", "return_home"} for t in types.values()),
        "home_module_selected_seconds": sum(types.get(s["selection"]) in {"seek_home_drive", "return_home"} for s in trace)*DT,
        "selection_phase_seconds": [{"selection": selected, "phase": phase, "seconds": count*DT}
                                     for (selected, phase), count in occupied.items()],
        "goal_instance_count": None,
        "goal_instance_count_reason": "Trace records selection and phase, not goal_key; same-module new destinations cannot be counted.",
    }


def expected_ablation(profile, arm):
    altered = deepcopy(profile)
    if arm == "no_memory":
        require(altered["memory"]["enabled"] is True, "Memory ablation base already disabled")
        altered["memory"]["enabled"] = False
    elif arm == "no_traits":
        require(altered["personality"]["enabled"] is True and altered["drives_enabled"] is True,
                "Trait/drive ablation base already disabled")
        altered["personality"]["enabled"] = False
        altered["drives_enabled"] = False
    elif arm == "coarse_only":
        altered["perception"] = {"spacing_cells": 4, "near_radius_cells": 0,
                                  "refine_boundaries": False}
    elif arm == "no_social":
        changed = 0
        for module in altered["modules"]:
            if module["type"] in SOCIAL_TYPES and module["enabled"]:
                module["enabled"] = False
                changed += 1
        require(changed > 0, "Social ablation base has no enabled social module")
    else:
        raise ValueError("Unknown ablation: "+arm)
    return altered


def audit_ablations(campaigns):
    groups = defaultdict(dict)
    for campaign in campaigns:
        group = groups[campaign["matched_group"]]
        require(campaign["arm"] not in group, "Duplicated matched treatment")
        group[campaign["arm"]] = campaign
    pairs = []
    for group, treatments in sorted(groups.items()):
        if "stateful" not in treatments:
            continue
        original = treatments["stateful"]
        for arm in ("no_memory", "no_traits", "coarse_only", "no_social"):
            if arm not in treatments:
                continue
            treatment = treatments[arm]
            require(original["initial_materials"] == treatment["initial_materials"]
                    and original["initial_pose_sha256"] == treatment["initial_pose_sha256"]
                    and original["geometry"] == treatment["geometry"], "Ablation initial state differs")
            require(len(original["episodes"]) == len(treatment["episodes"]), "Ablation roster differs")
            subjects = 0
            for base, altered in zip(original["episodes"], treatment["episodes"]):
                require(base["actor_instance"] == altered["actor_instance"], "Ablation actor identity differs")
                if base["controller"] == "departing_peer":
                    require(base["profile"] == altered["profile"] == {}, "External companion profile changed")
                    continue
                require(expected_ablation(base["profile"], arm) == altered["profile"],
                        "Unexpected authored profile difference: "+altered["episode_id"])
                subjects += 1
            pairs.append({"matched_group": group, "ablation": arm, "subject_pairs": subjects,
                          "stateful_campaign": original["id"], "ablated_campaign": treatment["id"]})
    require(pairs, "No matched ablation treatment found")
    return pairs


PAIR_METRICS = ("stable_territory_cells", "x_range_cells", "net_displacement_cells",
                "intention_transitions", "intentional_idle_seconds", "stalled_active_fraction",
                "home_returns_16_cells")


def matched_deltas(campaigns, metrics):
    grouped = defaultdict(dict)
    for campaign in campaigns:
        if campaign["group"] == "main":
            grouped[(campaign["model"], campaign["seed"])][campaign["arm"]] = campaign
    deltas = defaultdict(list)
    for (model, seed), treatments in sorted(grouped.items()):
        require(set(treatments) == {"legacy", "random", "random_hold", "scripted", "stateful",
                                    "no_memory", "no_traits", "coarse_only"}, "Main comparator set incomplete")
        reference = metrics[treatments["stateful"]["episodes"][0]["episode_id"]]
        for arm, campaign in treatments.items():
            if arm == "stateful":
                continue
            other = metrics[campaign["episodes"][0]["episode_id"]]
            differences = {key: reference[key]-other[key]
                           if reference[key] is not None and other[key] is not None else None
                           for key in PAIR_METRICS}
            deltas[(model, arm)].append({"seed": seed, "stateful_minus_comparator": differences})
    result = []
    for (model, arm), pairs in sorted(deltas.items()):
        require({pair["seed"] for pair in pairs} == {605, 1701, 2909}, "Matched seed set incomplete")
        medians = {}
        for key in PAIR_METRICS:
            values = [p["stateful_minus_comparator"][key] for p in pairs
                      if p["stateful_minus_comparator"][key] is not None]
            medians[key] = statistics.median(values) if values else None
        result.append({"model": model, "comparator": arm, "independent_world_pairs": len(pairs),
                       "pairs": pairs, "median_paired_difference": medians})
    return result


def audit(report, summary):
    require(report.get("complete") is True and report.get("failures") == [] and report.get("mode") == "full",
            "Only the completed frozen full programme is accepted")
    require(summary.get("complete") is True and summary.get("mode") == "full", "Reducer summary incomplete")
    require(report["source_identity"] == summary["source_identity"], "Raw and summary source custody differs")
    campaigns = report["campaigns"]
    require(len(campaigns) == EXPECTED_CAMPAIGNS == report["expected_campaigns"] == report["completed_campaigns"],
            "Frozen campaign count differs")
    declared = {item["id"]: item for item in report["registration"]}
    require(len(declared) == len(report["registration"]) == EXPECTED_CAMPAIGNS
            and {c["id"] for c in campaigns} == set(declared), "Registered campaign set differs")
    reduced = {row["episode_id"]: row for row in summary["episodes"]}
    require(len(reduced) == len(summary["episodes"]) == EXPECTED_EPISODES, "Reducer episode identities differ")
    metrics, catalogue, negatives, activities = {}, [], [], []
    copied_peer_samples = auxiliaries = 0
    for campaign in campaigns:
        require(all(campaign.get(key) == value for key, value in declared[campaign["id"]].items()),
                "Actual treatment differs from registered treatment")
        require(campaign["native_ticks"] == campaign["physical_ticks"] == round(campaign["seconds"]*60),
                "Incomplete actual native/Rapier horizon")
        copied_peer_samples += audit_copied_peers(campaign)
        for actor in campaign["episodes"]:
            eid = actor["episode_id"]
            require(eid not in metrics and eid in reduced, "Duplicate or missing actual episode")
            computed = independent_metrics(campaign, actor)
            for key, value in computed.items():
                close(reduced[eid][key], value, eid+": "+key)
            metrics[eid] = computed
            activity = selection_activity(actor)
            activities.append(dict(episode_id=eid, **activity))
            auxiliary = actor["controller"] == "passive_companion"
            auxiliaries += auxiliary
            if campaign["group"] == "catalogue" and not auxiliary:
                catalogue.append({"profile_id": actor["profile"]["id"], "model": actor["model"],
                                  "episode_id": eid, "metrics": computed, "selection_activity": activity})
            if actor["canvas_center_incidents"] > 0:
                negatives.append({"episode_id": eid, "outside_canvas_tick_samples": actor["canvas_center_incidents"]})
    require(len(metrics) == EXPECTED_EPISODES == report["completed_actor_episodes"] == report["expected_actor_episodes"],
            "Actual actor count differs")
    require(auxiliaries == EXPECTED_AUXILIARIES and len(catalogue) == 16, "Auxiliary/personality count differs")
    require(summary["actor_episodes"] == len(metrics) and summary["auxiliary_actor_episodes"] == auxiliaries
            and summary["subject_actor_episodes"] == len(metrics)-auxiliaries,
            "Reducer subject/auxiliary counts differ")
    return {"schema": "ambient2-independent-physical-review/v1", "source_revision": report["source_identity"]["source_revision"],
            "campaign_clusters": len(campaigns), "actual_actor_episodes": len(metrics),
            "subject_actor_episodes": len(metrics)-auxiliaries, "auxiliary_actor_episodes": auxiliaries,
            "independently_checked_episode_metrics": len(metrics)*len(next(iter(metrics.values()))),
            "copied_peer_samples_checked": copied_peer_samples, "ablation_pairs": audit_ablations(campaigns),
            "matched_main_differences": matched_deltas(campaigns, metrics), "catalogue": catalogue,
            "selection_activity": activities,
            "outside_canvas_observations": negatives,
            "interpretation": [
                "Metrics are observations, not automatic scores of intelligence or entertainment.",
                "Stable bins include the starting bin. Small horizontal oscillation at a grid boundary can populate two bins; pair occupancy with range and net displacement.",
                "Bin count times bin width/area is nominal occupied-grid measure, not exact traversed extent.",
                "Paired differences are stateful minus comparator for matching seeds. Three World pairs do not establish general superiority.",
                "The legacy field intention_transitions counts changes of recorded selection labels. Blend-label changes can reflect contributor changes; separate phase counts are reported. No goal_key was recorded, so new goal-instance counts are unavailable.",
                "A zero geometric home-return count is not a failed homeward attempt when no home rule was authored or selected, or when no qualifying departure occurred.",
                "Social/population actors share Worlds. Auxiliary companions are physical actors but not independent personality subjects.",
                "No-traits jointly disables personality modifiers and accumulated drives; separate contributions are not identified.",
                "Intentional inactivity and neutral commands permit real momentum and drift.",
                "Headless trajectories do not qualify graphical presentation or owner NVIDIA playfeel.",
            ]}


def markdown(result):
    lines = ["# Independent AMBIENT-002 physical readback", "",
             f"Source `{result['source_revision']}`: {result['actual_actor_episodes']} actual actor episodes in "
             f"{result['campaign_clusters']} fresh World clusters; {result['auxiliary_actor_episodes']} actors are auxiliary companions.", "",
             f"Independently checked {result['independently_checked_episode_metrics']} reduced metric values and "
             f"{result['copied_peer_samples_checked']} copied peer samples against the original raw trajectories.", "",
             "## Matched seed differences", "",
             "Values are median paired stateful-minus-comparator differences across the three declared seeds. They are descriptive differences, not significance tests.", "",
             "| Rig | Comparator | Stable bins | X range | Net movement | Selection-label changes | Active stall fraction |",
             "|---|---|---:|---:|---:|---:|---:|"]
    for item in result["matched_main_differences"]:
        values = item["median_paired_difference"]
        cells = ["—" if values[key] is None else f"{values[key]:+.3f}" for key in
                 ("stable_territory_cells", "x_range_cells", "net_displacement_cells", "intention_transitions", "stalled_active_fraction")]
        lines.append("| "+item["model"]+" | "+item["comparator"]+" | "+" | ".join(cells)+" |")
    lines += ["", "## Descriptive catalogue episodes", "",
              "One 30-second treatment per editable profile, each with a real passive compatible companion. These are examples under one condition, not a replicated ranking.", "",
              "| Profile | Rig | Stable bins | X range | Net movement | Selection-label changes | Intentional idle seconds |",
              "|---|---|---:|---:|---:|---:|---:|"]
    for item in sorted(result["catalogue"], key=lambda value: value["profile_id"]):
        m = item["metrics"]
        lines.append(f"| {item['profile_id']} | {item['model']} | {m['stable_territory_cells']} | "
                     f"{m['x_range_cells']:.2f} | {m['net_displacement_cells']:.2f} | "
                     f"{m['intention_transitions']} | {m['intentional_idle_seconds']:.1f} |")
    lines += ["", "## Limits and retained negative observations", ""]
    lines += ["- "+text for text in result["interpretation"]]
    lines += ["", f"Outside-canvas centre observations occurred in {len(result['outside_canvas_observations'])} actor episodes; exact episode IDs and every-step sample counts are retained in the JSON readback."]
    return "\n".join(lines)+"\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require(re.fullmatch(r"[0-9a-f]{40}", args.source_sha), "Expected full source commit required")
    report, summary = read(args.report), read(args.summary)
    require(report["source_identity"]["source_revision"] == args.source_sha, "Unexpected physical source")
    require(summary["raw_report_sha256"] == digest(args.report), "Summary does not bind this original raw report")
    result = audit(report, summary)
    result["raw_report_sha256"] = digest(args.report)
    result["reducer_summary_sha256"] = digest(args.summary)
    result["reviewer_sha256"] = digest(__file__)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output/"independent-review.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    (args.output/"independent-review.md").write_text(markdown(result), encoding="utf-8")
    print("AMBIENT2_INDEPENDENT_REVIEW "+json.dumps({"status": "PASS", "source_revision": args.source_sha,
          "actor_episodes": result["actual_actor_episodes"], "campaign_clusters": result["campaign_clusters"],
          "metric_values_checked": result["independently_checked_episode_metrics"],
          "ablation_pairs_checked": len(result["ablation_pairs"]), "output": str(args.output)}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError) as error:
        print("AMBIENT2_INDEPENDENT_REVIEW_REFUSED: "+str(error), file=sys.stderr)
        raise SystemExit(1)
