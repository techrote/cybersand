#!/usr/bin/env python3
"""Supplement retained physical traces with exact recorded interval overlaps.

This is an audit, not an acceptance gate. It does not rerun a workload or infer
native start, GPU completion, scanout, CPU utilization, or the counterfactual
benefit of removing an observed Main publication transaction.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from independent_reduction import require, sha, summary, witnessed_steps


def clock(value, label):
    require(type(value) is int and value >= 0, f"Invalid {label} clock")
    return value


def union_intervals(intervals):
    """Return disjoint half-open intervals; nested observations count once."""
    ordered = []
    for start, end in intervals:
        clock(start, "interval start"); clock(end, "interval end")
        require(start <= end, "Reversed Main publication interval")
        if start != end:
            ordered.append((start, end))
    result = []
    for start, end in sorted(ordered):
        if result and start <= result[-1][1]:
            result[-1] = (result[-1][0], max(end, result[-1][1]))
        else:
            result.append((start, end))
    return result


def intersection_usec(intervals, start, end):
    clock(start, "intersection start"); clock(end, "intersection end")
    require(start <= end, "Reversed observation window")
    return sum(max(0, min(end, upper)-max(start, lower))
               for lower, upper in union_intervals(intervals))


def partition(previous, current, native, intervals):
    """Preserve a nonordered boundary as unavailable, without moving it."""
    observed = None if native is None else clock(native["time_usec"], "native observation")
    boundaries = {
        "previous_physical_completion_usec":clock(previous["time_usec"], "previous physical completion"),
        "native_completion_observed_usec":observed,
        "successful_callback_start_usec":clock(current["start_usec"], "callback start"),
        "physical_completion_usec":clock(current["time_usec"], "physical completion"),
    }
    result = {"physical_step":current["step"], "native_tick":current["native_tick_used"],
              "completed_body_sample":current["completed_body_sample"], "boundaries":boundaries,
              "ordered":False, "partition_ms":None, "publication_overlap_ms":None}
    a, b, c, d = boundaries.values()
    require(a <= d, "Recorded physical completions moved backwards")
    # The physical gap remains known even when an internal boundary does not
    # permit this ordered decomposition. Tail inventories retain those gaps.
    result["gap_ms"] = (d-a)/1000
    if b is None:
        result["unavailable_reason"] = "No independently observed matching native completion"
        return result
    if not a <= b <= c <= d:
        result["unavailable_reason"] = "Recorded native/callback boundaries do not form the ordered partition"
        return result
    stages = {"previous_completion_to_native_observation":(a,b),
              "native_observation_to_successful_callback":(b,c),
              "successful_callback_to_completion":(c,d)}
    result["ordered"] = True
    result["unavailable_reason"] = None
    result["partition_ms"] = {key:(end-start)/1000 for key,(start,end) in stages.items()}
    result["publication_overlap_ms"] = {key:intersection_usec(intervals,start,end)/1000
                                        for key,(start,end) in stages.items()}
    result["publication_overlap_ms"]["entire_gap"] = intersection_usec(intervals,a,d)/1000
    require(math.isclose(sum(result["partition_ms"].values()), result["gap_ms"], abs_tol=1e-9),
            "Physical gap partition does not sum to the recorded span")
    require(math.isclose(sum(result["publication_overlap_ms"][key] for key in stages),
                         result["publication_overlap_ms"]["entire_gap"], abs_tol=1e-9),
            "Unioned Main publication overlap does not sum across partitions")
    return result


def aggregate(gaps):
    ordered = [row for row in gaps if row["ordered"]]
    result = {"observed_gaps":len(gaps), "ordered_gaps":len(ordered),
              "unpartitioned_gaps":len(gaps)-len(ordered),
              "unpartitioned_steps":[row["physical_step"] for row in gaps if not row["ordered"]],
              "all_observed_gap_ms":summary(row["gap_ms"] for row in gaps)}
    if not ordered:
        result.update({"gap_ms":None, "partition":None, "publication_overlap":None})
        return result
    span = math.fsum(row["gap_ms"] for row in ordered)
    result["gap_ms"] = summary(row["gap_ms"] for row in ordered)
    result["ordered_inter_step_span_ms"] = span
    result["partition"] = {}
    result["publication_overlap"] = {}
    for key in ordered[0]["partition_ms"]:
        values = [row["partition_ms"][key] for row in ordered]
        total = math.fsum(values)
        overlap = [row["publication_overlap_ms"][key] for row in ordered]
        overlap_total = math.fsum(overlap)
        result["partition"][key] = {"elapsed_ms":summary(values), "total_ms":total,
                                    "share_of_ordered_inter_step_span":total/span if span else None}
        result["publication_overlap"][key] = {
            "elapsed_ms":summary(overlap), "total_ms":overlap_total,
            "gaps_with_positive_overlap":sum(value > 0 for value in overlap),
            "share_of_this_partition":overlap_total/total if total else None,
            "share_of_ordered_inter_step_span":overlap_total/span if span else None,
        }
    whole = [row["publication_overlap_ms"]["entire_gap"] for row in ordered]
    result["publication_overlap"]["entire_gap"] = {
        "elapsed_ms":summary(whole), "total_ms":math.fsum(whole),
        "share_of_ordered_inter_step_span":math.fsum(whole)/span if span else None,
    }
    return result


def native_elapsed(current, rows):
    """Join the retained native profiler value without inventing a start clock."""
    candidates = [row for row in rows if row.get("event") == "worker_snapshot"
                  and row.get("world_generation") == current["world_generation"]
                  and row.get("tick_index") == current["native_tick_used"]
                  and row.get("completed_body_sample") == current["completed_body_sample"]
                  and row.get("failed") is False
                  and row.get("required_hard_revision") == current["required_hard_revision"]
                  and row.get("hard_surface_revision") == current["packet_hard_revision"]
                  and row.get("time_usec", math.inf) <= current["time_usec"]]
    values = {row.get("native_tick_ms") for row in candidates}
    if len(values) != 1:
        return {"available":False, "native_tick_ms":None,
                "reason":"No unique native profiler value in matching healthy retained packets"}
    value = values.pop()
    require(type(value) in (int,float) and math.isfinite(value) and value >= 0,
            "Invalid matched native profiler elapsed value")
    return {"available":True, "native_tick_ms":value, "reason":None}


def reduce(path):
    path = Path(path); data = json.loads(path.read_bytes())
    trace = path.with_name(path.stem+"-events.jsonl")
    require(sha(trace) == data["trace_sha256"], "Trace differs from original receipt checksum")
    rows = [json.loads(line) for line in trace.read_text(encoding="utf-8").splitlines()]
    require(rows[0].get("event") == "identity" and rows[0]["source"] == data["source_identity"],
            "Trace and receipt source identities differ")
    require(data["observer_mode"] == "full", "Complete physical/native observations are required")
    rows = rows[1:]
    steps, witness = witnessed_steps(data,rows)
    native_rows = [row for row in rows if row.get("event") == "native_completion_observed"]
    native = {(row["world_generation"],row["tick_index"],row["body_sample"]):row for row in native_rows}
    require(len(native) == len(native_rows), "Duplicate independent native completion identities")
    uploads = [row for row in rows if row.get("event") == "texture_upload"]
    intervals = union_intervals((row["start_usec"],row["time_usec"]) for row in uploads)
    causal = path.with_name(path.stem+"-causal-events.jsonl")
    causal_info = {"present":causal.is_file(), "native_start_clock_available":False,
                   "reason":"No native start clock is retained in the base observation schema"}
    if causal.is_file():
        causal_rows = [json.loads(line) for line in causal.read_text(encoding="utf-8").splitlines()]
        require(causal_rows and causal_rows[0].get("event") == "causal_identity",
                "Causal sidecar identity is missing")
        identity = causal_rows[0]
        require(identity["base_trace_sha256"] == sha(trace) and identity["source"] == data["source_identity"]
                and identity["capture_start_usec"] == data["capture_start_usec"]
                and identity["capture_end_usec"] == data["capture_end_usec"], "Causal sidecar binding differs")
        require(identity.get("enabled") is False and len(causal_rows) == 1,
                "This retained-schema audit does not interpret an enabled causal sidecar")
        causal_info.update({"sha256":sha(causal), "enabled":False, "records":len(causal_rows)})
    gaps = []
    for previous, current in zip(steps,steps[1:]):
        key = (current["world_generation"],current["native_tick_used"],current["completed_body_sample"])
        row = partition(previous,current,native.get(key),intervals)
        row["native_reported_elapsed"] = native_elapsed(current,rows)
        source_end = current.get("native_completed_usec")
        observed = row["boundaries"]["native_completion_observed_usec"]
        row["source_native_completion_usec"] = source_end
        row["source_completion_to_independent_observation_usec"] = (
            observed-source_end if type(source_end) is int and source_end > 0 and observed is not None else None)
        row["recorded_solver_elapsed_ms"] = current["solver_usec"]/1000
        gaps.append(row)
    windows = {"whole_capture":aggregate(gaps)}
    if len(steps) >= 144:
        windows["first_144_steps"] = aggregate(gaps[:143])
        windows["first_144_steps"]["tails_above_ms"] = {
            str(limit):aggregate([row for row in gaps[:143] if row.get("gap_ms",-1) > limit])
            for limit in (100,250,500,1000)}
    return {"receipt":str(path), "receipt_sha256":sha(path), "trace_sha256":sha(trace),
            "source_identity":data["source_identity"], "cpu":data["cpu"], "adapter":data["adapter"],
            "renderer":data["renderer"], "render_thread":data["render_thread"], "fixture":data["fixture"],
            "physical_witness":witness, "native_clock_coverage":causal_info,
            "recorded_publication_transactions":len(uploads), "unioned_publication_intervals":len(intervals),
            "windows":windows, "gaps":gaps}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input",type=Path,action="append",required=True)
    parser.add_argument("--output",type=Path,required=True)
    args = parser.parse_args()
    require(not args.output.exists(), "Preserve original interval evidence")
    paths = sorted({path for root in args.input for path in ([root] if root.is_file() else root.rglob("receipt.json"))})
    require(paths, "No retained receipts found")
    report = {
        "schema":"pubpres-final-retained-causal-intervals-v1", "program_sha256":sha(__file__),
        "physical_witness_program_sha256":sha(Path(__file__).with_name("independent_reduction.py")),
        "receipts":[], "failures":[], "physical_acceptance":"HOLD",
        "scope":"Recorded time intervals only. Native observation is the independently observed existing post-tick result-capture entry, an upper bound on native completion. The post-native interval includes publication delivery, terrain installation and scheduling; it does not certify every physical prerequisite was ready at native completion. Main publication is consume_render_snapshot entry-to-return for an actual accepted upload, including any waiting/descheduling; unioned overlaps are occupancy observations, not GPU/driver attribution, CPU utilization or counterfactual speedups. No native start is inferred from the separately reported native profiler duration. Nonordered boundaries remain unavailable with their original clocks. Reporting thresholds are not owner acceptance budgets. The historical Full/Target negative remains relevant: shorter submission calls alone did not establish better physical progression.",
    }
    for path in paths:
        try:
            report["receipts"].append(reduce(path))
        except (ValueError,KeyError,TypeError,OSError) as error:
            report["failures"].append({"receipt":str(path),"reason":str(error)})
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"receipts":len(report["receipts"]),"failures":report["failures"],
                      "output":str(args.output),"sha256":sha(args.output)}))
    return int(bool(report["failures"]))


if __name__ == "__main__":
    raise SystemExit(main())
