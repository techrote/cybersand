#!/usr/bin/env python3
"""Authenticate and independently reduce the frozen F2 primary H1 benchmark.

Usage: python audit.py --output-dir /new/nonexistent/directory
Reads existing native outputs only. No benchmark, compilation, or Git mutation.
All primary samples remain in every primary summary; fixed epoch strata explain
the original result without replacing it or creating an acceptance threshold.
"""
import argparse
import collections
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import statistics as st
import subprocess

WRAP_TICKS = {256, 511, 766, 1021}
WORK_FIELDS = ["tick", "jobs", "visited_cells", "active_blocks", "chunk_allocations",
               "temperature_allocations", "resident_cell_bytes", "observed_deadline_changes",
               "first_source_due", "first_source_material", "first_source_a"]


def fact(path):
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def verify(item, root=Path("/")):
    path = Path(item["path"])
    if not path.is_absolute():
        path = root / path
    data = path.read_bytes()
    assert len(data) == item["bytes"] and hashlib.sha256(data).hexdigest() == item["sha256"], path
    return data


def percentile(values, p):
    return sorted(values)[max(0, math.ceil(len(values) * p) - 1)]


def stats(values):
    if not values:
        return None
    return {"count": len(values), "mean_ns": st.mean(values), "median_ns": st.median(values),
            "p95_ns": percentile(values, .95), "p99_ns": percentile(values, .99), "max_ns": max(values),
            "min_ns": min(values), "stdev_ns": st.pstdev(values)}


def identity(values):
    return hashlib.sha256(json.dumps(values, separators=(",", ":")).encode()).hexdigest()


def ratio(new, old):
    return new / old if old else None


def read_run(run, plan, ordinal):
    receipt = run["process"]
    assert receipt["returncode"] == 0 and not receipt["timed_out"]
    assert not verify(receipt["stderr"])
    data = [json.loads(line) for line in verify(receipt["stdout"]).splitlines()]
    meta, summary, ticks = data[0], data[-1], data[1:-1]
    diagnostic = run.get("diagnostic_only", False)
    assert meta["type"] == "h1_benchmark_metadata" and summary["type"] == "h1_benchmark_summary"
    assert meta["workload"] == run["workload"] and meta["workers"] == run["workers"] and meta["diagnostics"] == diagnostic
    assert meta["ticks"] == plan["benchmark_ticks"] == 1024 and meta["warmup_ticks"] == plan["benchmark_warmup_ticks"] == 32
    assert meta["warmup_world"] == "separate throwaway"
    assert [r["tick"] for r in ticks] == list(range(1, 1025))
    assert all(r["type"] == "h1_benchmark_tick" and r["observed_workers"] <= run["workers"] for r in ticks)
    assert all(r["chunk_allocations"] == r["temperature_allocations"] == 0 for r in ticks)
    assert all(r["resident_cell_bytes"] == meta["resident_before"] for r in ticks)
    assert summary["resident_after"] == meta["resident_before"] and summary["chunk_and_temperature_allocations"] == 0
    for total, field in [("jobs", "jobs"), ("visited_cells", "visited_cells"), ("tick_ns_total", "tick_ns"), ("cpu_clock_ticks_total", "cpu_clock_ticks")]:
        assert summary[total] == sum(r[field] for r in ticks), total
    assert summary["tail_769_1024_jobs"] == sum(r["jobs"] for r in ticks[768:])
    assert summary["max_workers_observed"] == max(r["observed_workers"] for r in ticks)
    assert all(b["elapsed_to_observation_ns"] > a["elapsed_to_observation_ns"] for a, b in zip(ticks, ticks[1:]))
    if diagnostic:
        assert summary["kernel_entries_world"] == sum(r["kernel_entries_world"] for r in ticks)
        assert summary["glass_conversions"] == sum(r["glass_conversions"] for r in ticks)
    else:
        assert all(r["kernel_entries_world"] is None and r["glass_conversions"] is None for r in ticks)
    if run["workload"].startswith("cold"):
        assert meta["initial_molten"] == summary["final_molten"] + summary["final_glass"]
        if run["variant"] == "successor":
            assert summary["final_molten"] == 0 and summary["final_glass"] == meta["initial_molten"]
    if run["workload"] in {"empty", "inert", "hot180"} or (run["variant"] == "successor" and run["workload"].startswith("cold")):
        assert not any(r["jobs"] or r["visited_cells"] or r["active_blocks"] or r["first_source_due"] for r in ticks[768:])
    resolution = 1_000_000_000 / meta["cpu_clock_ticks_per_second"]
    assert meta["cpu_clock_available"] and resolution == 1000
    sets = {"all": ticks, "active_jobs": [r for r in ticks if r["jobs"]], "tail_769_1024": ticks[768:],
            "epoch_wrap": [r for r in ticks if r["tick"] in WRAP_TICKS],
            "non_epoch_wrap": [r for r in ticks if r["tick"] not in WRAP_TICKS]}
    timing = {name: {"wall": stats([r["tick_ns"] for r in subset]),
                     "cpu": stats([r["cpu_clock_ticks"] * resolution for r in subset])} for name, subset in sets.items()}
    # Verify the frozen runner's published summaries by independent arithmetic.
    for key, target in [("all_ticks", ("all", "wall")), ("tail_769_1024", ("tail_769_1024", "wall")),
                        ("cpu_all_ticks", ("all", "cpu")), ("cpu_tail_769_1024", ("tail_769_1024", "cpu"))]:
        for field, value in run["observation"][key].items():
            assert timing[target[0]][target[1]][field] == value, (key, field)
    first_glass = next((r for r in ticks if r["first_source_material"] == 35), None)
    elapsed = first_glass["elapsed_to_observation_ns"] if first_glass else None
    cumulative = sum(r["tick_ns"] for r in ticks[:first_glass["tick"]]) if first_glass else None
    assert elapsed == run["observation"]["first_source_elapsed_wall_ns_to_glass"]
    assert cumulative == run["observation"]["first_source_cumulative_timed_tick_ns_to_glass"]
    work = {"jobs": summary["jobs"], "visited_cells": summary["visited_cells"],
        "last_job_tick": max((r["tick"] for r in ticks if r["jobs"]), default=0),
        "maximum_jobs_per_tick": max(r["jobs"] for r in ticks), "maximum_active_blocks": max(r["active_blocks"] for r in ticks),
        "tail_jobs": summary["tail_769_1024_jobs"], "tail_visited_cells": sum(r["visited_cells"] for r in ticks[768:]),
        "tail_maximum_active_blocks": max(r["active_blocks"] for r in ticks[768:]),
        "deadline_observation_changes": sum(r["observed_deadline_changes"] for r in ticks),
        "last_deadline_observation_change_tick": max((r["tick"] for r in ticks if r["observed_deadline_changes"]), default=0),
        "maximum_first_source_deadline": max(r["first_source_due"] for r in ticks),
        "last_nonzero_first_source_deadline_tick": max((r["tick"] for r in ticks if r["first_source_due"]), default=0),
        "initial_molten": meta["initial_molten"], "final_molten": summary["final_molten"], "final_glass": summary["final_glass"],
        "resident_bytes": summary["resident_after"], "chunk_temperature_allocations": 0,
        "work_state_trace_sha256": identity([[r[f] for f in WORK_FIELDS] for r in ticks]),
        "tuple_hash": summary["tuple_hash"], "physical_hash": summary["physical_hash"]}
    if diagnostic:
        work.update(kernel_entries_world=summary["kernel_entries_world"], glass_conversions=summary["glass_conversions"])
        if run["workload"] == "cold1":
            due_entries = sum(r["kernel_entries_world"] for r in ticks if r["tick"] % 4 == 0)
            work.update(singleton_due_lane_kernel_entries=due_entries,
                        singleton_off_lane_kernel_entries=summary["kernel_entries_world"] - due_entries)
    focus = run["workload"] in {"empty", "water_pf", "cold1", "cold64"}
    extract = lambda r: {k: r[k] for k in ["tick", "tick_ns", "cpu_clock_ticks", "jobs", "visited_cells", "active_blocks", "observed_workers"]}
    return {"ordinal": ordinal, "variant": run["variant"], "workload": run["workload"], "workers": run["workers"],
        "repeat": run.get("repeat"), "diagnostic_only": diagnostic, "process": receipt,
        "cpu_clock_resolution_ns": resolution, "timing": timing, "work": work,
        "observed_worker_claimants_max": summary["max_workers_observed"],
        "first_source_glass_tick": first_glass["tick"] if first_glass else None,
        "first_source_elapsed_wall_ns_to_glass": elapsed, "first_source_cumulative_timed_tick_ns_to_glass": cumulative,
        "epoch_wrap_samples": [extract(r) for r in sets["epoch_wrap"]],
        "largest_primary_wall_ticks": [extract(r) for r in sorted(ticks, key=lambda r: r["tick_ns"], reverse=True)[:8 if focus else 1]],
        "epoch_wrap_share_of_total_wall": sum(r["tick_ns"] for r in sets["epoch_wrap"]) / summary["tick_ns_total"],
        "epoch_wrap_contribution_to_all_tick_mean_ns": sum(r["tick_ns"] for r in sets["epoch_wrap"]) / 1024,
        "non_epoch_wrap_contribution_to_all_tick_mean_ns": sum(r["tick_ns"] for r in sets["non_epoch_wrap"]) / 1024}


def aggregate(runs):
    result = {"run_count": len(runs), "observed_claimants_max": max(r["observed_worker_claimants_max"] for r in runs),
              "work": runs[0]["work"], "timing": {}}
    for window in runs[0]["timing"]:
        result["timing"][window] = {}
        for clock in ["wall", "cpu"]:
            values = [r["timing"][window][clock] for r in runs]
            if values[0] is None:
                result["timing"][window][clock] = None
                continue
            means, medians = [r["mean_ns"] for r in values], [r["median_ns"] for r in values]
            result["timing"][window][clock] = {"mean_tick_ns": st.mean(means), "median_of_run_medians_ns": st.median(medians),
                "median_of_run_p95_ns": st.median(r["p95_ns"] for r in values), "median_of_run_p99_ns": st.median(r["p99_ns"] for r in values),
                "maximum_tick_ns": max(r["max_ns"] for r in values), "run_mean_range_ns": [min(means), max(means)],
                "run_mean_stdev_ns": st.pstdev(means), "run_median_range_ns": [min(medians), max(medians)],
                "run_median_stdev_ns": st.pstdev(medians), "individual_run_means_ns": means, "individual_run_medians_ns": medians}
    for field in ["epoch_wrap_contribution_to_all_tick_mean_ns", "non_epoch_wrap_contribution_to_all_tick_mean_ns"]:
        result[field] = st.mean(r[field] for r in runs)
    for field in ["first_source_elapsed_wall_ns_to_glass", "first_source_cumulative_timed_tick_ns_to_glass"]:
        values = [r[field] for r in runs]
        result[field] = {"values_ns": values, "mean_ns": st.mean(values), "median_ns": st.median(values), "range_ns": [min(values), max(values)]} if values[0] is not None else None
    return result


def epoch_assembly(q):
    result = {}
    for variant in ["baseline", "successor"]:
        exe = q["builds"][variant]["executable"]["path"]
        nm = subprocess.check_output(["nm", "-S", exe], text=True)
        symbol = next(s for s in nm.splitlines() if s.endswith("_ZN9cybersand5World10begin_tickERNS_9TickStatsE"))
        start, size = [int(s, 16) for s in symbol.split()[:2]]
        command = ["objdump", "-d", "-C", "--no-show-raw-insn", f"--start-address={start}", f"--stop-address={start + 0xe4}", exe]
        raw = subprocess.check_output(command, text=True)
        normalized = []
        for line in raw.splitlines():
            match = re.match(r"\s*[0-9a-f]+:\s*(.*)", line)
            if not match:
                continue
            instruction = match[1].split("#")[0].strip()
            instruction = re.sub(r"\b[0-9a-f]+\s+<cybersand::World::begin_tick\(cybersand::TickStats&\)\+(0x[0-9a-f]+)>", r"relative:\1", instruction)
            instruction = re.sub(r"0x[0-9a-f]+\(%rip\)", "RIP_RELOCATION(%rip)", instruction)
            normalized.append(instruction)
        result[variant] = {"executable": q["builds"][variant]["executable"], "begin_tick_address": hex(start), "begin_tick_bytes": size,
                           "command": command, "prefix_disassembly": raw, "normalized_epoch_prefix": normalized}
    result["normalized_prefix_equal"] = result["baseline"]["normalized_epoch_prefix"] == result["successor"]["normalized_epoch_prefix"]
    result["scope"] = "Observed epoch prefix instruction sequence only; RIP relocation and addresses ignored. Does not establish equal cache/layout behavior or explain timing variance."
    assert result["normalized_prefix_equal"]
    return result


def audit(root):
    path = root / "performance-attempt-1/qualification.json"
    q = json.loads(path.read_text())
    assert q["mode"] == "performance" and q["status"] == "EXECUTED" and len(q["runs"]) == 336
    assert q["performance"]["numeric_adoption_threshold"] is None and q["performance"]["owner_performance_disposition_required"]
    correctness = json.loads(verify(q["build_report"]))
    assert correctness["status"] == "EXECUTED" and correctness["mode"] == "correctness"
    assert correctness["sources"] == q["sources"] and correctness["builds"] == q["builds"] and correctness["plan"] == q["plan"]
    for variant, source in q["sources"].items():
        for item in source["inputs"] + q["builds"][variant]["dependencies"]:
            verify(item, Path(source["root"]))
        verify(q["builds"][variant]["executable"])
    verify(q["compiler"])
    for item in q["apparatus"]["inputs"]:
        verify(item, Path(q["sources"]["successor"]["root"]))
    runs = [read_run(r, q["plan"], i) for i, r in enumerate(q["runs"])]
    expected = []
    for workers in q["plan"]["benchmark_workers"]:
        for workload in q["plan"]["benchmark_workloads"]:
            for repeat in range(5):
                for variant in (["baseline", "successor"] if repeat % 2 == 0 else ["successor", "baseline"]):
                    expected.append((workload, workers, variant, repeat, False))
            for variant in ["baseline", "successor"]:
                expected.append((workload, workers, variant, None, True))
    assert [(r["workload"], r["workers"], r["variant"], r["repeat"], r["diagnostic_only"]) for r in runs] == expected
    assert all(a["process"]["finished_utc"] <= b["process"]["started_utc"] for a, b in zip(runs, runs[1:]))
    work_groups = collections.defaultdict(list)
    for r in runs:
        work_groups[(r["variant"], r["workload"])].append(r)
    for key, group in work_groups.items():
        assert len(group) == 12
        assert len({r["work"]["work_state_trace_sha256"] for r in group}) == 1, key
        assert len({(r["work"]["physical_hash"], r["work"]["tuple_hash"]) for r in group}) == 1, key
    for workload in q["plan"]["benchmark_exact_control_workloads"]:
        a, b = work_groups[("baseline", workload)][0], work_groups[("successor", workload)][0]
        assert a["work"] == b["work"], workload
    comparisons = []
    for workers in [1, 4]:
        for workload in q["plan"]["benchmark_workloads"]:
            paired = {v: sorted([r for r in runs if r["workload"] == workload and r["workers"] == workers and r["variant"] == v and not r["diagnostic_only"]], key=lambda r: r["repeat"]) for v in ["baseline", "successor"]}
            agg = {v: aggregate(group) for v, group in paired.items()}
            pairs = []
            for a, b in zip(paired["baseline"], paired["successor"]):
                item = {"repeat": a["repeat"], "order": "AB" if a["ordinal"] < b["ordinal"] else "BA"}
                for clock in ["wall", "cpu"]:
                    old, new = a["timing"]["all"][clock], b["timing"]["all"][clock]
                    item[clock] = {"mean_delta_ns": new["mean_ns"] - old["mean_ns"], "mean_ratio": ratio(new["mean_ns"], old["mean_ns"]),
                                   "median_delta_ns": new["median_ns"] - old["median_ns"], "median_ratio": ratio(new["median_ns"], old["median_ns"])}
                pairs.append(item)
            differences = {}
            for clock in ["wall", "cpu"]:
                old, new = agg["baseline"]["timing"]["all"][clock], agg["successor"]["timing"]["all"][clock]
                differences[clock] = {"mean_delta_ns": new["mean_tick_ns"] - old["mean_tick_ns"],
                    "mean_ratio": ratio(new["mean_tick_ns"], old["mean_tick_ns"]),
                    "median_of_run_medians_delta_ns": new["median_of_run_medians_ns"] - old["median_of_run_medians_ns"],
                    "paired_mean_delta_stdev_ns": st.pstdev(p[clock]["mean_delta_ns"] for p in pairs),
                    "positive_mean_delta_pairs": sum(p[clock]["mean_delta_ns"] > 0 for p in pairs)}
            old, new = agg["baseline"], agg["successor"]
            decomposition = {key: new[key] - old[key] for key in ["epoch_wrap_contribution_to_all_tick_mean_ns", "non_epoch_wrap_contribution_to_all_tick_mean_ns"]}
            comparisons.append({"workload": workload, "workers": workers, **agg, "differences": differences,
                                "paired_runs": pairs, "fixed_epoch_mean_delta_decomposition_ns": decomposition})
    scaling = []
    for workload in q["plan"]["benchmark_workloads"]:
        one, four = [next(c for c in comparisons if c["workload"] == workload and c["workers"] == n) for n in [1, 4]]
        for variant in ["baseline", "successor"]:
            a, b = one[variant], four[variant]
            scaling.append({"workload": workload, "variant": variant,
                "wall_speedup_one_over_four": ratio(a["timing"]["all"]["wall"]["mean_tick_ns"], b["timing"]["all"]["wall"]["mean_tick_ns"]),
                "cpu_cost_ratio_four_over_one": ratio(b["timing"]["all"]["cpu"]["mean_tick_ns"], a["timing"]["all"]["cpu"]["mean_tick_ns"]),
                "observed_claimants_one": a["observed_claimants_max"], "observed_claimants_four": b["observed_claimants_max"]})
    result = {"schema": "mat354.h1.performance-audit.v1", "status": "EXECUTION_AND_BOUNDED_WORK_VERIFIED_PERFORMANCE_DISPOSITION_PENDING",
        "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "analysis_script": fact(Path(__file__).resolve()),
        "source_receipts": [fact(path), q["build_report"], q["plan_file"]], "sources": q["sources"], "builds": q["builds"],
        "apparatus": q["apparatus"], "compiler": q["compiler"], "compiler_version": verify(q["compiler_version"]["stdout"]).decode(),
        "host": q["host"], "started_utc": q["started_utc"], "finished_utc": q["finished_utc"],
        "coverage": {"processes": 336, "primary_processes": 280, "diagnostic_processes": 56,
            "primary_tick_rows": 280 * 1024, "diagnostic_tick_rows": 56 * 1024, "verified_process_output_facts": 672,
            "frozen_AB_BA_order_and_serial_execution_verified": True, "deterministic_work_state_trace_groups_of_12": 28,
            "cross_source_exact_control_workloads": q["plan"]["benchmark_exact_control_workloads"]},
        "work_state_trace_fields": WORK_FIELDS, "comparisons": comparisons, "worker_scaling": scaling,
        "all_run_observations": runs, "epoch_wrap_ticks": sorted(WRAP_TICKS), "epoch_assembly_observation": epoch_assembly(q),
        "numeric_adoption_threshold": None, "owner_performance_disposition_required": True,
        "scope_limits": [
            "All 1024 primary ticks and all five pairs remain in primary metrics; epoch/non-epoch strata and largest ticks are explanation only.",
            "Within-run ticks are correlated. Five run-level observations are retained; no artificial independent-5120-sample confidence claim.",
            "Process CPU resolution is 1000ns; includes worker CPU and surrounding wall-clock calls. Quantized zero/submicrosecond observations remain unchanged.",
            "TickStats covers chunk/temperature allocations only. resident_cell_bytes omits hash nodes, scheduler buffers, total heap/RSS. Complete heap/RSS evidence is unavailable.",
            "Benchmark quantity evidence is cold MoltenGlass+Glass conservation and exact final tuple/control identity. Full Water ledgers are in the separate source-qualified correctness packet.",
            "Only singleton diagnostic material entries identify per-cell execution. Multicell per-source thermal/off-lane visits and every coalesced deadline request are not directly observable.",
            "No stale-wake creation/retirement event counter exists in this apparatus. Recorded deadline changes and last jobs bound observed activity, without counting every request.",
            "All workload/source repeats and worker settings preserve complete recorded work/state traces plus final physical/tuple identity. Benchmark rows do not carry full per-tick physical hashes.",
            "Configured four workers can yield one actual claimant; small cold1 and Water fixtures are not distributed scaling proofs.",
            "The worker1 and worker4 cohorts run in fixed separate windows, not interleaved cross-worker pairs; host variance can affect scaling estimates.",
            "No other owned task ran during the primary cohort according to root orchestration; no host-wide isolation/frequency/affinity or representative-target-hardware guarantee is established by receipts.",
            "Empty-world mean and epoch-reset CPU increases remain unresolved performance observations. Unchanged source/normalized instructions do not prove a benign cause.",
            "No numerical H1 budget exists. This audit does not grant performance acceptance, compatibility adoption, final independent GO, or merge permission.",
        ]}
    return result


def markdown(report):
    lines = ["# MAT354 H1 primary performance audit", "", "**Execution and finite work are verified; performance disposition remains pending.** No primary sample is discarded and no acceptance threshold is introduced.", "",
             f"The frozen successor is `{report['sources']['successor']['commit']}`, tree `{report['sources']['successor']['tree']}`. The accepted baseline is `{report['sources']['baseline']['commit']}`. Source inventories, compiled dependencies, compiler/binary hashes, the completed correctness receipt, and all 672 raw-output facts authenticate.", "",
             "## Coverage and measurement", "", "The same host/compiler/binaries executed 14 workloads at configured workers1/4, five alternating AB/BA pairs each: 280 primary runs and 286,720 timed ticks. The 56 diagnostic replays contribute 57,344 separate trace ticks; their timings are never pooled. The observed host is " + report['host']['cpu'] + " / " + report['host']['os'] + ", with " + str(report['host']['logical_cpus']) + " reported logical CPUs.", "",
             "Each measured World begins fresh after a separate32-tick throwaway warmup. Each row times World::tick only; first-conversion elapsed time also includes observation overhead. POSIX process CPU includes workers, with1000ns nominal resolution. Medians/p95 below are medians of the five per-run values; mean includes all5120 primary ticks per source/workload/worker setting.", "",
             "## Absolute and relative primary costs", "", "Wall and CPU values are microseconds per tick. Ratios compare successor to baseline. Every individual run, paired difference, p99, maximum and variance is retained in the JSON.", "",
             "| Workload | Workers | Wall mean old→new µs | Wall ratio | Wall median old→new µs | Wall p95 old→new µs | CPU mean old→new µs |", "|---|---:|---:|---:|---:|---:|---:|"]
    for c in report["comparisons"]:
        a, b = c['baseline']['timing']['all'], c['successor']['timing']['all']
        def pair(clock, field): return f"{a[clock][field]/1000:.3f}→{b[clock][field]/1000:.3f}"
        lines.append(f"| {c['workload']} | {c['workers']} | {pair('wall','mean_tick_ns')} | {c['differences']['wall']['mean_ratio']:.3f}× | {pair('wall','median_of_run_medians_ns')} | {pair('wall','median_of_run_p95_ns')} | {pair('cpu','mean_tick_ns')} |")
    lines += ["", "## Finite work, deadlines and retirement", "", "All12 observations for each workload/source (five runs at each worker setting plus both diagnostic replays) have identical recorded job/visit/block/deadline/source-state trajectories. All ten control workloads preserve these complete recorded trajectories and final physical/tuple identity across sources. Every primary/diagnostic tick has zero chunk/temperature allocations and unchanged resident_cell_bytes.", "",
              "| Workload | Jobs old→new | Visited cells old→new | Successor final MoltenGlass/Glass | Last successor job | Deadline changes old→new | Tail jobs |", "|---|---:|---:|---:|---:|---:|---:|"]
    for c in report['comparisons'][:14]:
        a,b=c['baseline']['work'],c['successor']['work']
        lines.append(f"| {c['workload']} | {a['jobs']}→{b['jobs']} | {a['visited_cells']}→{b['visited_cells']} | {b['final_molten']}/{b['final_glass']} | {b['last_job_tick']} | {a['deadline_observation_changes']}→{b['deadline_observation_changes']} | {b['tail_jobs']} |")
    lines += ["", "Cold1/16/64 and mixed finish added work bytick723. All have zero tail jobs/visited cells/active blocks; all observed cooling deadline changes end bytick720. Hot180 keeps144 MoltenGlass cells, executes only the original3 jobs/432 visits, and sleeps. Water CY's256 tail jobs are unchanged historical behavior. PressureFlow has zero tail jobs but retains its existing nonzero tick cost; zero scheduled jobs must not be equated with zero whole-tick CPU.", "",
              "Cold1 diagnostic execution records180 due-lane entries and540 ordinary off-lane entries, then one Glass conversion. Multicell diagnostics record actual aggregate entries/conversions but do not individually identify every cell's due/off-lane visit. Deadline-change observations are not counts of all coalesced requests.", "",
              "## Variance and unresolved performance observations", "", "The epoch wraps occur at256,511,766,1021 from an initial epoch0. The source and normalized compiled epoch-clearing instruction prefix are unchanged; address/layout differs. The audit splits these predetermined ticks only for explanation and retains them in every primary mean."]
    for workers in [1,4]:
        c=next(c for c in report['comparisons'] if c['workload']=='empty' and c['workers']==workers)
        a,b=c['baseline'],c['successor'];d=c['fixed_epoch_mean_delta_decomposition_ns']
        lines += ["", f"Empty workers{workers}: mean {a['timing']['all']['wall']['mean_tick_ns']/1000:.6f}→{b['timing']['all']['wall']['mean_tick_ns']/1000:.6f}µs. Wrap samples average {a['timing']['epoch_wrap']['wall']['mean_tick_ns']/1000:.3f}→{b['timing']['epoch_wrap']['wall']['mean_tick_ns']/1000:.3f}µs; their contribution to the all-tick delta is {d['epoch_wrap_contribution_to_all_tick_mean_ns']/1000:+.6f}µs. Non-wrap contribution is {d['non_epoch_wrap_contribution_to_all_tick_mean_ns']/1000:+.6f}µs. Every empty tick has zero jobs/visits/deadline changes."]
    lines += ["", "The largest one-worker successor empty tick is repeat1/tick725:1733.753µs wall and1736µs process CPU, with zero jobs. Tick737 adds955.796µs wall/957µs CPU. CPU follows these spikes, so ordinary descheduling alone does not explain them. Empty means and Water PressureFlow variance require disposition; improved medians do not erase the mean increases.", "",
              "## Observed worker scaling", "", "These are cohort ratios, not separately paired worker-count experiments. Values below are successor observations; actual claimant counts and CPU ratios prevent interpreting a configured four-worker setting as four-way useful parallelism.", "",
              "| Workload | Wall speedup 1÷4 | CPU cost 4÷1 | Actual claimants at4 |", "|---|---:|---:|---:|"]
    for s in report['worker_scaling']:
        if s['variant']=='successor':lines.append(f"| {s['workload']} | {s['wall_speedup_one_over_four']:.3f}× | {s['cpu_cost_ratio_four_over_one']:.3f}× | {s['observed_claimants_four']} |")
    lines += ["", "Cold64 benefits from four actual claimants; cold1 has one and pays substantially higher four-worker coordination cost. Existing one-claimant Water CY has the same direction of scaling loss. These measurements are preserved as performance risks, without changing unrelated scheduler policy.", "", "## Limits and disposition", ""]
    lines += ["- "+s for s in report['scope_limits']]
    return "\n".join(lines)+"\n"


if __name__ == "__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--evidence-root",type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument("--output-dir",type=Path,required=True)
    args=p.parse_args()
    assert not args.output_dir.exists(), "refusing to overwrite any audit directory"
    report=audit(args.evidence_root.resolve())
    args.output_dir.mkdir()
    outputs={"performance-audit.json":json.dumps(report,indent=2,sort_keys=True)+"\n", "performance-audit.md":markdown(report)}
    for name,data in outputs.items():
        with (args.output_dir/name).open("x",encoding="utf-8") as f:
            f.write(data);f.flush();os.fsync(f.fileno())
    print(json.dumps({"status":report['status'],"files":[fact(args.output_dir/name) for name in outputs]}))
