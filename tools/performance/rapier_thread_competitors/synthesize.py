"""Synthesize bounded competitor replays; this never reads or runs gameplay.

Usage: python synthesize.py ANALYSIS_DIR --output result.json
Optional --worker-analysis-dir DIR may be repeated for separately stored worker
reader output. With no option, worker evidence is located inside ANALYSIS_DIR.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def trial_id(occupancy):
    match = re.search(r"trial-(\d+)", occupancy["raw"])
    if not match:
        raise ValueError("Raw input path must retain its trial-NN identity")
    return match.group(1)


def worker_evidence(folder, analysis, directories, raw_hash):
    current = folder
    while current.is_relative_to(analysis):
        census = current / "worker-census.json"
        state = current / "worker-state.json"
        if census.is_file() and state.is_file():
            value = read(census)
            if value["raw_sha256"] == raw_hash:
                return value, read(state), [str(census), str(state)]
        current = current.parent
    matches = []
    for directory in directories:
        for census in directory.rglob("worker-census.json"):
            value = read(census)
            state = census.with_name("worker-state.json")
            if value["raw_sha256"] == raw_hash and state.is_file():
                matches.append((value, read(state), [str(census), str(state)]))
    if len(matches) != 1:
        raise ValueError(f"Expected one matching worker evidence pair, found {len(matches)}")
    return matches[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("analysis_dir", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--worker-analysis-dir", type=Path, action="append", default=[])
    args = parser.parse_args()
    analysis = args.analysis_dir.resolve()
    directories = [p.resolve() for p in args.worker_analysis_dir]
    results = []
    seen = set()
    for path in sorted(analysis.rglob("cpu-occupancy.json")):
        occupancy = read(path)
        folder = path.parent
        sample_path = folder / "competitor-samples.json"
        samples = read(sample_path)
        if samples["schema"] != "inv154-worker-competitor-samples-v2":
            raise ValueError("Use explicit row-limit/truncation v2 samples")
        if samples["rows_truncated"]:
            raise ValueError("Eligible sample rows were truncated; no complete synthesis")
        if len(samples["rows"]) != samples["eligible_samples_in_windows"]:
            raise ValueError("Retained rows do not cover every eligible sample")
        trial = trial_id(occupancy)
        if trial in seen:
            raise ValueError("Ambiguous repeated trial " + trial)
        seen.add(trial)
        census, state, worker_paths = worker_evidence(
            folder, analysis, directories, occupancy["raw_sha256"])
        caller = set(census["caller_tids"])
        notifications = [event for window in state["long_events"]
                         for event in window["ready_events"]
                         if event["tid"] in caller and event["flags"] == 0]
        wakers = Counter(event["emitter_tid"] for event in notifications)
        critical = set(wakers)
        ancestry = [row for row in samples["rows"]
                    if any(frame["module"].lower() == "d3d10warp"
                           for frame in row["frames"])]
        interrupt_ancestry = [row for row in ancestry if row["dpc"] or row["isr"]]
        ordinary_ancestry = [row for row in ancestry if not row["dpc"] and not row["isr"]]
        # Identify associated threads only using samples not flagged ISR/DPC.
        associated = set(row["tid"] for row in ordinary_ancestry)
        slices = occupancy["slices"]
        total = occupancy["total_cpu_residency_usec"]
        associated_us = sum(row["usec"] for row in slices if row["tid"] in associated)
        priorities = defaultdict(float)
        for row in slices:
            if row["tid"] in associated:
                priorities[row["priority"]] += row["usec"]
        per_event = []
        for window in occupancy["windows"]:
            rows = [row for row in slices if row["window"] == window["index"]]
            cpu_us = sum(row["usec"] for row in rows)
            warp_us = sum(row["usec"] for row in rows if row["tid"] in associated)
            per_event.append({"index": window["index"], "start_qpc": window["start"],
                              "end_qpc": window["end"], "logical_cpu_residency_usec": cpu_us,
                              "warp_associated_tid_residency_usec": warp_us,
                              "warp_associated_tid_residency_fraction": warp_us / cpu_us})
        switches = occupancy["priority_switches"]
        histogram_in = Counter(row["new_priority"] for row in switches
                               if row["new_tid"] in critical)
        histogram_out = Counter(row["old_priority"] for row in switches
                                if row["old_tid"] in critical)
        result = {"trial": trial, "pid": census["process_id"],
                  "windows": len(occupancy["windows"]), "events_lost": occupancy["events_lost"],
                  "sample_row_limit": samples["row_limit"],
                  "eligible_samples": samples["eligible_samples_in_windows"],
                  "retained_sample_rows": len(samples["rows"]),
                  "sample_rows_truncated": samples["rows_truncated"],
                  "all_profile_samples": samples["samples_in_windows"],
                  "interrupt_profile_samples": samples["interrupt_samples_in_windows"],
                  "noninterrupt_profile_samples": samples["noninterrupt_samples_in_windows"],
                  "warp_ancestry_noninterrupt_samples": len(ordinary_ancestry),
                  "warp_ancestry_interrupt_samples": len(interrupt_ancestry),
                  "warp_noninterrupt_sample_fraction": len(ordinary_ancestry) / samples["noninterrupt_samples_in_windows"],
                  "warp_noninterrupt_fraction_of_all_samples": len(ordinary_ancestry) / samples["samples_in_windows"],
                  "warp_associated_tids": sorted(associated),
                  "total_cpu_residency_usec": total,
                  "warp_associated_tid_residency_usec": associated_us,
                  "warp_associated_tid_residency_fraction": associated_us / total,
                  "warp_associated_tid_residency_by_switch_in_priority_usec": dict(priorities),
                  "per_event_minimum_warp_associated_tid_residency_fraction": min(
                      row["warp_associated_tid_residency_fraction"] for row in per_event),
                  "per_event": per_event,
                  "critical_rayon_switch_in_priority_histogram": dict(histogram_in),
                  "critical_rayon_switch_out_priority_histogram": dict(histogram_out),
                  "caller_ready_emitters": dict(wakers), "worker_evidence": worker_paths,
                  "input_etlx_sha256": occupancy["etlx_sha256"],
                  "input_raw_sha256": occupancy["raw_sha256"],
                  "occupancy_sha256": digest(path), "samples_sha256": digest(sample_path),
                  "analyzer_identity": read(folder / "identity.json")}
        results.append(result)
    if not results:
        raise ValueError("No competitor analysis found")
    total = sum(row["total_cpu_residency_usec"] for row in results)
    associated = sum(row["warp_associated_tid_residency_usec"] for row in results)
    ordinary = sum(row["noninterrupt_profile_samples"] for row in results)
    warp_ordinary = sum(row["warp_ancestry_noninterrupt_samples"] for row in results)
    combined = {"windows": sum(row["windows"] for row in results),
                "total_cpu_residency_usec": total, "warp_associated_tid_residency_usec": associated,
                "warp_associated_tid_residency_fraction": associated / total,
                "all_profile_samples": sum(row["all_profile_samples"] for row in results),
                "interrupt_profile_samples": sum(row["interrupt_profile_samples"] for row in results),
                "noninterrupt_profile_samples": ordinary,
                "warp_ancestry_noninterrupt_samples": warp_ordinary,
                "warp_ancestry_interrupt_samples": sum(row["warp_ancestry_interrupt_samples"] for row in results),
                "warp_noninterrupt_sample_fraction": warp_ordinary / ordinary,
                "per_event_minimum_warp_associated_tid_residency_fraction": min(
                    row["per_event_minimum_warp_associated_tid_residency_fraction"] for row in results),
                "sample_rows_truncated": any(row["sample_rows_truncated"] for row in results)}
    for key in ("critical_rayon_switch_in_priority_histogram", "critical_rayon_switch_out_priority_histogram"):
        combined[key] = dict(sum((Counter(row[key]) for row in results), Counter()))
    payload = {"schema": "inv154-worker-cpu-competition-synthesis-v2", "trials": results,
               "combined": combined, "synthesis_source_sha256": digest(Path(__file__)),
               "limits": ["WARP-associated thread residency is identified by sampled stack ancestry; it does not establish WARP execution at every instant or resolve anonymous leaves.",
                          "ISR/DPC-flagged ancestry samples are reported separately and excluded from noninterrupt WARP sample counts.",
                          "Scheduler residency can include intervening interrupts/DPC or hypervisor interruptions.",
                          "Recorded switch priorities do not establish a fixed priority setting or the source of each boost.",
                          "This offline synthesis performs no gameplay trial, settings change or optimization."]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(combined, indent=2))


if __name__ == "__main__":
    main()
