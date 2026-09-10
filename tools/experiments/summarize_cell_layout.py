"""Reduce a complete registered L1 campaign; never runs or selects benchmark samples."""
from __future__ import annotations
import argparse
from collections import defaultdict
import csv
from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path
import statistics
import struct


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def normalized_timing_record(path, ticks):
    """Exact L1 work/final-state bytes, omitting only the trailing observer entries."""
    with path.open("rb") as stream:
        work = stream.read(ticks * 15 * 8)
        size = stream.read(8)
        if len(work) != ticks * 120 or len(size) != 8:
            raise ValueError(f"Truncated work/frame header: {path}")
        count = struct.unpack("<Q", size)[0]
        if count % 22:
            raise ValueError(f"Invalid semantic record size: {path}")
        cells = stream.read(count)
        final = stream.read(16 * 8)
        events = stream.read(8)
        if len(cells) != count or len(final) != 128 or len(events) != 8:
            raise ValueError(f"Truncated semantic frame: {path}")
        event_bytes = struct.unpack("<Q", events)[0] * 16
        if len(stream.read(event_bytes)) != event_bytes or stream.read(1):
            raise ValueError(f"Truncated or extra event data: {path}")
        return work + size + cells + final


def ratio_summary(values):
    return dict(median=statistics.median(values), minimum=min(values), maximum=max(values), pairs=values)


@lru_cache(maxsize=None)
def initial_quantities(fixture, extent):
    if fixture == "dense":
        xs, ys = range(extent), range(extent // 2)
    else:
        center = extent // 2
        xs, ys = range(center - 64, center + 64), range(center - 64, center)
    sand = water = smoke = 0
    for y in ys:
        for x in xs:
            selector = (x * 17 + y * 31) % 13
            sand += selector < 7
            water += 7 <= selector < 10
            smoke += selector == 10
    return dict(sand_cells=sand, water_mass=water * 255, smoke_cells=smoke)


def final_quantities(path, ticks):
    data = normalized_timing_record(path, ticks)
    offset = ticks * 120
    size = struct.unpack_from("<Q", data, offset)[0]
    counts = defaultdict(int)
    water_mass = 0
    for x, y, material, a, b, temperature in struct.iter_unpack("<qqHBBh", data[offset+8:offset+8+size]):
        counts[material] += 1
        if material == 3:
            if a == 0:
                raise ValueError("Non-normalized zero-mass Water")
            water_mass += a
    return dict(sand_cells=counts[2], water_mass=water_mass, smoke_cells=counts[4], species_cells=dict(counts))


def summarize_samples(rows):
    ns = sorted(int(r["ns"]) for r in rows)
    visited = sum(int(r["visited"]) for r in rows)
    if not ns or ns[0] < 0 or visited < 0:
        raise ValueError("Invalid tick samples")
    return dict(**{f"p{p}": ns[math.ceil(len(ns) * p / 100) - 1] for p in (50, 95, 99)},
                maximum=max(ns), total=sum(ns), visited=visited,
                ns_per_visited=sum(ns) / visited if visited else None)


def work_summary(path, ticks, workers):
    with path.open("rb") as stream:
        data = stream.read(len(ticks) * 120)
    if len(data) != len(ticks) * 120:
        raise ValueError(f"Truncated work record: {path}")
    work = list(struct.iter_unpack("<15Q", data))
    if any(row[0] != int(sample["tick"]) or row[1] != int(sample["visited"])
           or sum(row[11:15]) != row[7] for row, sample in zip(work, ticks)):
        raise ValueError(f"Work/CSV tick, visit or phase mismatch: {path}")
    return dict(total_visited=sum(row[1] for row in work), total_moved=sum(row[2] for row in work),
                total_scheduled_cores=sum(row[7] for row in work),
                chunk_allocations=sum(row[8] for row in work),
                temperature_allocations=sum(row[9] for row in work),
                total_deferred_events=sum(row[10] for row in work),
                peak_active_chunks=max(max(row[3], row[4]) for row in work),
                peak_scheduled_cores=max(row[7] for row in work),
                pool_dispatches_inferred_from_phase_jobs=sum(n >= 8 for row in work for n in row[11:15])
                    if workers == 4 else 0,
                pool_jobs_inferred_from_phase_jobs=sum(n for row in work for n in row[11:15] if n >= 8)
                    if workers == 4 else 0,
                inference="Configured four-worker pool dispatches exactly when phase job count >= unchanged threshold8")


def epoch_proxy(rows):
    """Tag the source-defined 8-bit wrap ticks; this is not a direct clear observer."""
    result = []
    for i, row in enumerate(rows):
        tick = int(row["tick"])
        if tick < 256 or (tick - 256) % 255:
            continue
        neighbors = [int(rows[j]["ns"]) for j in range(max(0, i - 2), min(len(rows), i + 3)) if j != i]
        result.append(dict(tick=tick, sample=int(row["sample"]), tick_ns=int(row["ns"]),
                           ordinary_neighbor_median_ns=statistics.median(neighbors),
                           excess_ns=int(row["ns"]) - statistics.median(neighbors),
                           visited=int(row["visited"])))
    return result


def summarize(directory):
    plan = json.loads((directory / "plan.json").read_text())
    rows = json.loads((directory / "results.json").read_text())
    if len(rows) != len(plan) or len(rows) != 196:
        raise ValueError(f"Incomplete registered campaign: {len(rows)} / {len(plan)} / expected196")
    pairs, groups, epochs = defaultdict(dict), defaultdict(list), []
    repeat_references = {}
    for i, (row, expected) in enumerate(zip(rows, plan)):
        if any(row[k] != v for k, v in expected.items()):
            raise ValueError(f"Plan mismatch at process {i}")
        prefix = Path(row["prefix"])
        execution = json.loads(prefix.with_suffix(".execution.json").read_text())
        if execution["exit_code"] != 0:
            raise ValueError(f"Failed execution: {prefix}")
        with prefix.with_suffix(".ticks.csv").open() as stream:
            ticks = list(csv.DictReader(stream))
        if len(ticks) != row["ticks"] or any(int(t["sample"]) != j for j, t in enumerate(ticks)):
            raise ValueError(f"Incomplete tick sequence: {prefix}")
        if any(int(t["tick"]) != int(ticks[0]["tick"]) + j for j, t in enumerate(ticks)):
            raise ValueError(f"Invalid world tick sequence: {prefix}")
        if row["warmup"] != summarize_samples(ticks[:120]) or row["steady"] != summarize_samples(ticks[120:]):
            raise ValueError(f"Driver summary does not match raw samples: {prefix}")
        row["epoch_proxy"] = epoch_proxy(ticks)
        epochs.extend(dict(process=i, fixture=row["fixture"], extent=row["extent"],
                           workers=row["workers"], width=row["width"], observer=row["observer"], **e)
                      for e in row["epoch_proxy"])
        row["record_sha256"] = sha256(prefix.with_suffix(".records"))
        row["ticks_sha256"] = sha256(prefix.with_suffix(".ticks.csv"))
        row["execution_sha256"] = sha256(prefix.with_suffix(".execution.json"))
        row["log_sha256"] = sha256(prefix.with_suffix(".log"))
        row["work"] = work_summary(prefix.with_suffix(".records"), ticks, row["workers"])
        initial = initial_quantities(row["fixture"], row["extent"])
        final = final_quantities(prefix.with_suffix(".records"), row["ticks"])
        if any(initial[k] != final[k] for k in ("sand_cells", "water_mass")):
            raise ValueError(f"Whole-world final Water/Sand accounting failed: {prefix}")
        row["quantity_ledger"] = dict(initial=initial, final=final,
                                      smoke_lifecycle_net_loss=initial["smoke_cells"] - final["smoke_cells"],
                                      scope="Final whole-world accounting; timing runs do not contain per-tick semantic snapshots")
        repeat_key = (row["fixture"], row["extent"], row["width"], row["observer"])
        if repeat_key in repeat_references:
            reference = repeat_references[repeat_key]
            if reference.read_bytes() != prefix.with_suffix(".records").read_bytes():
                raise ValueError(f"Worker/repeat state/work mismatch: {repeat_key}")
        else:
            repeat_references[repeat_key] = prefix.with_suffix(".records")
        if row["comparison"] == "width":
            group = ("width", row["fixture"], row["extent"], row["workers"])
            variant = row["width"]
        else:
            group = ("observer", row["fixture"], row["extent"], row["workers"], row["width"])
            variant = row["observer"]
        key = (*group, row["pair"])
        if variant in pairs[key]:
            raise ValueError(f"Duplicate member: {key}")
        pairs[key][variant] = row
    for key, members in pairs.items():
        ids = (4, 8) if key[0] == "width" else (0, 1)
        if set(members) != set(ids):
            raise ValueError(f"Missing pair member: {key}")
        control, candidate = (members[v] for v in ids)
        a, b = (Path(v["prefix"]).with_suffix(".records") for v in (control, candidate))
        if key[0] == "width":
            # Recheck bytes, not merely hashes, independent of driver's earlier check.
            if a.read_bytes() != b.read_bytes():
                raise ValueError(f"Width state/work mismatch: {key}")
        elif normalized_timing_record(a, control["ticks"]) != normalized_timing_record(b, candidate["ticks"]):
            raise ValueError(f"Observer state/work mismatch: {key}")
        ratios = {}
        for phase in ("warmup", "steady"):
            ratios[phase] = {metric: candidate[phase][metric] / control[phase][metric]
                             for metric in ("p50", "p95", "p99", "maximum", "total", "ns_per_visited")
                             if control[phase][metric] not in (None, 0)}
        left = {e["tick"]: e for e in control["epoch_proxy"]}
        right = {e["tick"]: e for e in candidate["epoch_proxy"]}
        if left.keys() != right.keys():
            raise ValueError(f"Epoch identity mismatch: {key}")
        groups[key[:-1]].append(dict(pair=key[-1], ratios=ratios,
            control=control, candidate=candidate,
            extra_epoch_proxy_ns=[right[t]["excess_ns"] - left[t]["excess_ns"] for t in left]))
    reduced = []
    for key, values in groups.items():
        values.sort(key=lambda r: r["pair"])
        if [v["pair"] for v in values] != list(range(7)):
            raise ValueError(f"Not seven registered pairs: {key}")
        metrics = {phase: {metric: ratio_summary([v["ratios"][phase][metric] for v in values])
                          for metric in values[0]["ratios"][phase]} for phase in ("warmup", "steady")}
        extra = [n for v in values for n in v["extra_epoch_proxy_ns"]]
        reduced.append(dict(group=key, metrics=metrics, paired_results=values,
                            review_p95_pairs=[v["pair"] for v in values if v["ratios"]["steady"]["p95"] > 1.15],
                            median_p95_review=metrics["steady"]["p95"]["median"] > 1.15,
                            extra_epoch_proxy_max_ns=max(extra),
                            extra_epoch_proxy_over_1ms_count=sum(n > 1_000_000 for n in extra),
                            absolute={label: {
                                "steady": {metric: ratio_summary([v[label]["steady"][metric] for v in values])
                                           for metric in ("p50", "p95", "p99", "maximum", "total", "visited")},
                                "startup_and_memory": {
                                    metric: ratio_summary([v[label]["startup_and_memory"][metric] for v in values])
                                    for metric in ("startup_ns", "cells", "temperatures", "activity", "chunk_objects",
                                                   "map_buckets_estimate", "coordinator_vectors", "parallel_vectors",
                                                   "legacy_aggregate", "working_set", "private_bytes", "peak_working_set")}}
                                for label in ("control", "candidate")}))
    worker_scaling = []
    for fixture, extent in (("dense", 512), ("dense", 1024), ("sparse", 512), ("sparse", 1024), ("sleeping", 4096)):
        for width in (4, 8):
            series = {workers: [r for r in rows if r["comparison"] == "width" and r["fixture"] == fixture
                       and r["extent"] == extent and r["width"] == width and r["workers"] == workers]
                      for workers in (1, 4)}
            worker_scaling.append(dict(fixture=fixture, extent=extent, width=width,
                one_worker_median_total_ns=statistics.median(r["steady"]["total"] for r in series[1]),
                four_worker_median_total_ns=statistics.median(r["steady"]["total"] for r in series[4]),
                total_speedup=statistics.median(r["steady"]["total"] for r in series[1]) /
                              statistics.median(r["steady"]["total"] for r in series[4]),
                four_worker_dispatches=series[4][0]["work"]["pool_dispatches_inferred_from_phase_jobs"],
                scope="Descriptive ratio of seven-run medians; worker series were not interleaved with each other"))
    report = dict(scope="L1 original4/padded8 and representative observer cost; no layout adoption",
                  raw_results_sha256=sha256(directory / "results.json"), plan_sha256=sha256(directory / "plan.json"),
                  process_count=len(rows), exact_width_pairs=70, exact_observer_pairs=28,
                  worker_and_repeat_records_equal=True,
                  groups=reduced, epoch_proxy=epochs, worker_scaling=worker_scaling,
                  limitations=["Epoch values tag the source-defined wrap schedule and measure whole-tick neighbor excess; clear calls/durations are not directly observed in L1.",
                               "Process memory includes harness and allocator retention; component totals are incomplete.",
                               "Descriptive paired ratios are not confidence intervals or production limits.",
                               "No PMU/cache/bandwidth counters or cross-platform acceptance."])
    (directory / "reduced.json").write_text(json.dumps(report, indent=2) + "\n")
    lines = ["# L1 paired timing results", "", "Median candidate/control ratios; all seven pair ratios retained in reduced.json.", "",
             "| Comparison | Fixture | Extent | Workers | p50 | p95 | p99 | Total | p95 review pairs |",
             "|---|---|---:|---:|---:|---:|---:|---:|---|"]
    for g in reduced:
        comparison, fixture, extent, workers, *width = g["group"]
        label = comparison + (f"-{width[0]}" if width else "")
        m = g["metrics"]["steady"]
        lines.append(f"| {label} | {fixture} | {extent} | {workers} | " +
                     " | ".join(f"{m[k]['median']:.4f}" for k in ("p50", "p95", "p99", "total")) +
                     f" | {g['review_p95_pairs']} |")
    (directory / "summary.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    summarize(parser.parse_args().directory.resolve())
