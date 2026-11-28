#!/usr/bin/env python3
"""Independent raw-clock selection check for the registered actual-task ABBA.

This supplements, never replaces, the unchanged complete physical oracle and
presentation geometry/ownership reader. No shared quantile or selection helper
is imported. Original receipts remain the authority.
"""
from __future__ import annotations

import argparse
import bisect
import hashlib
import json
import math
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def require(value, message):
    if not value:
        raise ValueError(message)


def distribution(values):
    values = sorted(values)
    if not values:
        return None
    def q(fraction):
        position = (len(values) - 1) * fraction
        left = int(position)
        right = min(left + 1, len(values) - 1)
        return values[left] + (values[right] - values[left]) * (position - left)
    return {"count": len(values), "p50": q(.5), "p95": q(.95),
            "p99": q(.99), "max": values[-1]}


def same_numbers(actual, recorded, context):
    require(set(actual) == set(recorded), context + ": fields differ")
    for key in actual:
        require(math.isclose(actual[key], recorded[key], rel_tol=1e-11, abs_tol=1e-9),
                context + ": independently reconstructed " + key + " differs")


def window(receipt, events, presentation, end):
    start = receipt["capture_start_usec"]
    steps = [row for row in events if row["event"] == "rapier_step" and start <= row["time_usec"] <= end]
    all_steps = {row["step"]: row for row in events if row["event"] == "rapier_step"}
    uploads = [row for row in events if row["event"] == "texture_upload"]
    upload_times = [row["time_usec"] for row in uploads]
    chosen = [row for row in presentation["submissions"] if start <= row["time_usec"] <= end]
    gaps = [(right["time_usec"] - left["time_usec"]) / 1000 for left, right in zip(steps, steps[1:])]
    pose_ages, material_ages, omitted, pose_unjoined, material_unjoined = [], [], 0, 0, 0
    for row in chosen:
        at = bisect.bisect_right(upload_times, row["time_usec"]) - 1
        if at < 0:
            material_unjoined += 1
        else:
            upload = uploads[at]
            require(row["render_serial"] == upload["render_serial"]
                    and row["world_generation"] == upload["world_generation"]
                    and row["material_generated_usec"] == upload["generated_usec"],
                    "Submitted material does not join the actual upload")
            material_ages.append((row["time_usec"] - upload["generated_usec"]) / 1000)
        for body in row["bodies"]:
            if not body["overlay_visible"]:
                omitted += 1
                continue
            step = all_steps.get(body["selected_step"])
            if step is None:
                require(body["selected_step"] <= receipt["capture_physical_tick_start"],
                        "Unjoined in-capture physical pose")
                pose_unjoined += 1
            else:
                require(step["time_usec"] <= row["time_usec"], "Future physical pose")
                pose_ages.append((row["time_usec"] - step["time_usec"]) / 1000)
    return {"completed_physical_steps": len(steps),
            "elapsed_seconds": (end - start) / 1e6,
            "real_steps_per_second": len(steps) * 1e6 / (end - start),
            "physical_gap_ms": distribution(gaps),
            "gap_counts_above_ms": {str(threshold): sum(gap > threshold for gap in gaps)
                                    for threshold in (100, 250, 500, 1000)},
            "selected_completion_age_ms": distribution(pose_ages),
            "material_generation_age_at_submission_ms": distribution(material_ages),
            "submissions": len(chosen), "withheld_body_submissions": omitted,
            "pre_capture_unjoined_visible_poses": pose_unjoined,
            "pre_capture_unjoined_material_submissions": material_unjoined}


def review(campaign, physical_path):
    summary = read(campaign / "SUMMARY.json")
    independent = read(physical_path)
    require(summary["complete"] is True and summary["failures"] == [], "Incomplete campaign")
    require(summary["mode"] == "task-completion-abba", "Wrong experiment")
    require(len(independent["receipts"]) == 8 and independent["failures"] == [],
            "Original independent physical reducer did not admit all eight raw receipts")
    by_hash = {row["receipt_sha256"]: row for row in independent["receipts"]}
    require([arm["task_completion"] for arm in summary["order"]] == [False, True, True, False],
            "Registered ABBA order changed")
    cases, identities = [], []
    for case in summary["cases"]:
        arms = []
        for recorded in case["arms"]:
            index = recorded["index"]
            directory = campaign / case["case"] / f"{index}-C-slots2"
            receipt_path = directory / "receipt.json"
            receipt = read(receipt_path)
            process = read(directory / "process.json")
            presentation = read(directory / "receipt-presentation.json")
            events = [json.loads(line) for line in (directory / "receipt-events.jsonl").read_bytes().splitlines()]
            require(sha(receipt_path) == recorded["receipt_sha256"] in by_hash,
                    "Receipt is not the raw independently admitted arm")
            require(sha(directory / "receipt-events.jsonl") == receipt["trace_sha256"], "Trace binding differs")
            physical = by_hash[sha(receipt_path)]
            require(physical["capture_claims_complete"] is True and physical["capture_failures"] == [],
                    "Physical authority failed")
            require(receipt["process_id"] == process["observed_application_pid"]
                    == presentation["process_id"] and process["exit_code"] == 0
                    and not process["timed_out"] and process["app_sampler_pid_matched"] is True,
                    "Actual process identity or exit differs")
            require(presentation["complete"] is True
                    and presentation["source_identity"] == receipt["source_identity"]
                    and presentation["capture_start_usec"] == receipt["capture_start_usec"]
                    and presentation["capture_end_usec"] == receipt["capture_end_usec"]
                    and all(presentation[name] == 0 for name in ("dropped_submissions", "dropped_notifications", "invalid_samples")),
                    "Presentation clock, source, or bounded capture differs")
            identities.append(receipt["source_identity"])
            actual = index in (1, 2)
            mode = "actual_tasks" if actual else "all_workers"
            before, after = [receipt[key]["task_completion"] for key in ("selectors_before", "selectors_after")]
            require(all(value["schema"] == "PUBPRES-TASK-COMPLETION-V1" and value["mode"] == mode
                        for value in (before, after)), "Actual native mode was not exercised throughout capture")
            require(all(type(after[key]) is int and type(before[key]) is int
                        and after[key] > before[key] >= 0 for key in ("completed_dispatches", "completed_tasks")),
                    "Native dispatch/task exercise is absent")
            steps = [row for row in events if row["event"] == "rapier_step"]
            require(len(steps) >= 144, "Insufficient real physical completion")
            moves_sha = hashlib.sha256(json.dumps([row["admitted_move"] for row in steps[:144]],
                                                  sort_keys=True, separators=(",", ":")).encode()).hexdigest()
            require(moves_sha == recorded["statistics"]["first_144_admitted_moves_sha256"],
                    "Admitted movement sequence does not reconstruct from actual physical rows")
            windows = {"first_144_steps": window(receipt, events, presentation, steps[143]["time_usec"]),
                       "whole_capture": window(receipt, events, presentation, receipt["capture_end_usec"])}
            for name, result in windows.items():
                same_numbers(result["physical_gap_ms"], recorded["statistics"]["windows"][name]["physical_gap_ms"], "Physical gaps")
                require(math.isclose(result["real_steps_per_second"], recorded["statistics"]["windows"][name]["rapier_steps_per_second"], rel_tol=1e-11), "Physical rate differs")
                for metric in ("selected_completion_age_ms", "material_generation_age_at_submission_ms"):
                    same_numbers(result[metric], recorded["observers"]["presentation"]["windows"][name][metric], metric)
                require(result["withheld_body_submissions"] == recorded["observers"]["presentation"]["windows"][name]["withheld_body_submissions"], "Omission count differs")
            memory = read(directory / "process-memory.json")
            require(memory and all(row["pid"] == receipt["process_id"] for row in memory), "Memory belongs to another process")
            rss = [row["rss_bytes"] for row in memory if type(row.get("rss_bytes")) is int]
            require(rss, "No actual process memory sample")
            arms.append({"index": index, "mode": mode, "receipt_sha256": sha(receipt_path),
                         "trace_sha256": receipt["trace_sha256"],
                         "presentation_sha256": sha(directory / "receipt-presentation.json"),
                         "process_id": receipt["process_id"],
                         "task_dispatches_delta": after["completed_dispatches"] - before["completed_dispatches"],
                         "tasks_delta": after["completed_tasks"] - before["completed_tasks"],
                         "windows": windows,
                         "equal_step_body_sha256": physical["first_144_body_trajectory_sha256"],
                         "equal_step_admitted_moves_sha256": moves_sha,
                         "sampled_peak_rss_bytes": max(rss), "sampled_last_rss_bytes": rss[-1],
                         "memory_sample_count": len(memory),
                         "memory_samples_without_rss": len(memory) - len(rss),
                         "process_cpu_mean_core_equivalents": recorded["observers"]["cpu"]["mean_cpu_core_equivalents"],
                         "observer_total_usec": presentation["observer_total_usec"],
                         "observer_max_usec": presentation["observer_max_usec"]})
        require([row["index"] for row in arms] == list(range(4)), "Missing/reordered arm")
        require(len({row["equal_step_body_sha256"] for row in arms}) == 1
                and len({row["equal_step_admitted_moves_sha256"] for row in arms}) == 1,
                "Equal-step physical or admitted movement trajectory differs")
        controls = [arms[index]["windows"]["first_144_steps"] for index in (0, 3)]
        candidates = [arms[index]["windows"]["first_144_steps"] for index in (1, 2)]
        criteria = {"both_candidate_rates_exceed_both_controls": min(row["real_steps_per_second"] for row in candidates) > max(row["real_steps_per_second"] for row in controls)}
        for metric in ("physical_gap_ms", "selected_completion_age_ms", "material_generation_age_at_submission_ms"):
            for quantile in ("p99", "max"):
                criteria[metric + "_" + quantile + "_no_worse_than_worst_control"] = max(row[metric][quantile] for row in candidates) <= max(row[metric][quantile] for row in controls)
        cases.append({"case": case["case"], "arms": arms, "equal_step_trajectory_parity": True,
                      "original_registered_necessary_criteria": criteria,
                      "necessary_criteria_all_pass": all(criteria.values()),
                      "stricter_frozen_direction": case["registered_direction"],
                      "selection": "NOT_SELECTED" if not all(criteria.values()) else "LATER_GATES_REQUIRED"})
    require(all(identity == identities[0] for identity in identities), "Application/runtime/engine differ across arms")
    return {"schema": "pubpres-closure-independent-native-abba-v1", "reviewer": "Specialist C",
            "campaign_summary_sha256": sha(campaign / "SUMMARY.json"),
            "independent_physical_reducer_program_sha256": independent["program_sha256"],
            "independent_physical_reduction_sha256": sha(physical_path),
            "registration_sha256": summary["task_completion_registration_sha256"],
            "registration_criterion": summary["task_completion_registration"]["comparison"]["selection"],
            "source_commit": identities[0]["source_sha"], "engine_sha256": identities[0]["engine_sha256"],
            "native_sha256": identities[0]["files"]["res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"],
            "native_toolchain": "Local GCC14.2.0 drift, explicitly registered. This is not pinned hosted platform qualification.",
            "raw_physical_receipts_admitted": 8, "independently_recomputed_windows": 16, "cases": cases,
            "disposition": "NOT_SELECTED / DEFAULT OFF / original all-worker path retained",
            "limits": ["Neither workload meets the original necessary performance criteria. No later medium/mixed/sustained promotion is justified for this unchanged candidate.",
                       "Task counts are actual whole-capture dispatch/task readbacks. Wave512 captures contain different total step counts; unequal full-capture task totals do not imply omitted equal-step work.",
                       "Three control arms each contain one transient withheld submission; no candidate withholding appears in these captures. First-capture poses/material without a trace join are counted separately. This is not a complete display visibility qualification.",
                       "Submitted pose/material ages are Main pre-draw observations. No GPU completion, display scanout, or input-to-visible claim is made.",
                       "Process CPU and RSS sample the process lifetime including setup. These short captures do not qualify sustained retention or prove bounded GPU resource memory.",
                       "Original complete physical and submitted-geometry readers remain mandatory; this independent reduction does not replace their full correctness inventories."]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--campaign", type=Path, required=True)
    parser.add_argument("--physical-reduction", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = review(args.campaign, args.physical_reduction)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(result["disposition"])


if __name__ == "__main__":
    main()
