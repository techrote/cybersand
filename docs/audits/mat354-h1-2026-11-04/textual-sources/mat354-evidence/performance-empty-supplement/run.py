#!/usr/bin/env python3
"""Execute only the frozen, acknowledged 80-process empty-world supplement.

No source/worktree writes, rebuilds, benchmark overrides, sample exclusions,
performance threshold, or adoption decision. Existing outputs are never reused.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import statistics as st
import sys
import time

sys.dont_write_bytecode = True


def fact(path):
    data = path.read_bytes()
    return {"path": str(path.resolve()), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def verify(item, root=Path("/")):
    path = Path(item["path"])
    if not path.is_absolute():
        path = root / path
    data = path.read_bytes()
    if len(data) != item["bytes"] or hashlib.sha256(data).hexdigest() != item["sha256"]:
        raise ValueError("identity mismatch: " + str(path))
    return data


def require(condition, message):
    if not condition:
        raise ValueError(message)


def statistics(values):
    ordered = sorted(values)
    return {"count": len(values), "mean_ns": st.mean(values), "median_ns": st.median(values),
            "p95_ns": ordered[math.ceil(len(values) * .95) - 1], "p99_ns": ordered[math.ceil(len(values) * .99) - 1],
            "min_ns": min(values), "max_ns": max(values), "stdev_ns": st.pstdev(values)}


def observation(process, workers, plan):
    require(process["returncode"] == 0 and not process["timed_out"], "native process failed/timed out; raw retained")
    require(not verify(process["stderr"]), "unexpected native stderr; raw retained")
    data = [json.loads(line) for line in verify(process["stdout"]).splitlines()]
    require(len(data) == 1026, "incomplete raw row coverage")
    meta, summary, ticks = data[0], data[-1], data[1:-1]
    require(meta["type"] == "h1_benchmark_metadata" and summary["type"] == "h1_benchmark_summary", "missing endpoints")
    require(meta["workload"] == "empty" and meta["workers"] == workers and meta["diagnostics"] is False, "unexpected benchmark settings")
    require(meta["ticks"] == 1024 and meta["warmup_ticks"] == 32 and meta["warmup_world"] == "separate throwaway", "timing window changed")
    require(meta["resident_before"] == plan["expected_empty_state"]["resident_bytes"] and meta["initial_molten"] == 0, "empty geometry changed")
    require([r["tick"] for r in ticks] == list(range(1, 1025)), "noncontiguous ticks")
    zero_fields = ["jobs", "visited_cells", "active_blocks", "observed_workers", "chunk_allocations", "temperature_allocations",
                   "observed_deadline_changes", "first_source_due", "first_source_material", "first_source_a"]
    for row in ticks:
        require(row["type"] == "h1_benchmark_tick", "unexpected row type")
        require(all(row[k] == 0 for k in zero_fields), "empty world generated work/state")
        require(row["resident_cell_bytes"] == meta["resident_before"], "resident grew")
        require(row["kernel_entries_world"] is None and row["glass_conversions"] is None, "diagnostics unexpectedly enabled")
    require(all(b["elapsed_to_observation_ns"] > a["elapsed_to_observation_ns"] for a,b in zip(ticks,ticks[1:])), "elapsed clock reversed")
    require(summary["tick_ns_total"] == sum(r["tick_ns"] for r in ticks), "wall total mismatch")
    require(summary["cpu_clock_ticks_total"] == sum(r["cpu_clock_ticks"] for r in ticks), "CPU total mismatch")
    require(summary["physical_hash"] == plan["expected_empty_state"]["physical_hash"] and summary["tuple_hash"] == plan["expected_empty_state"]["tuple_hash"], "empty physical identity changed")
    require(summary["resident_after"] == meta["resident_before"] and summary["chunk_and_temperature_allocations"] == 0, "allocation/resident mismatch")
    require(all(summary[k] == 0 for k in ["jobs", "visited_cells", "max_workers_observed", "tail_769_1024_jobs", "final_molten", "final_glass"]), "empty summary generated work")
    require(meta["cpu_clock_available"] and meta["cpu_clock_ticks_per_second"] == plan["cpu_clock_ticks_per_second"], "CPU clock unavailable/changed")
    resolution = 1_000_000_000 / meta["cpu_clock_ticks_per_second"]
    wraps = set(plan["epoch_wrap_ticks"])
    windows = {"all": ticks, "tail_769_1024": ticks[768:], "epoch_wrap": [r for r in ticks if r["tick"] in wraps],
               "non_epoch_wrap": [r for r in ticks if r["tick"] not in wraps]}
    timing = {name: {"wall": statistics([r["tick_ns"] for r in rows]), "cpu": statistics([r["cpu_clock_ticks"] * resolution for r in rows])}
              for name, rows in windows.items()}
    return {"metadata": meta, "summary": summary, "timing": timing, "cpu_clock_resolution_ns": resolution,
            "epoch_wrap_samples": windows["epoch_wrap"],
            "largest_wall_ticks": sorted(ticks, key=lambda r:r["tick_ns"], reverse=True)[:10],
            "epoch_wrap_contribution_to_all_mean_ns": sum(r["tick_ns"] for r in windows["epoch_wrap"]) / 1024,
            "non_epoch_wrap_contribution_to_all_mean_ns": sum(r["tick_ns"] for r in windows["non_epoch_wrap"]) / 1024}


def aggregate(group):
    result = {"runs": len(group), "timing": {}}
    for window in ["all", "tail_769_1024", "epoch_wrap", "non_epoch_wrap"]:
        result["timing"][window] = {}
        for clock in ["wall", "cpu"]:
            values = [r["observation"]["timing"][window][clock] for r in group]
            means, medians = [v["mean_ns"] for v in values], [v["median_ns"] for v in values]
            result["timing"][window][clock] = {"mean_tick_ns": st.mean(means), "median_of_run_medians_ns": st.median(medians),
                "median_of_run_p95_ns": st.median(v["p95_ns"] for v in values), "median_of_run_p99_ns": st.median(v["p99_ns"] for v in values),
                "max_tick_ns": max(v["max_ns"] for v in values), "individual_run_means_ns": means, "individual_run_medians_ns": medians,
                "run_mean_stdev_ns": st.pstdev(means), "run_median_stdev_ns": st.pstdev(medians)}
    for key in ["epoch_wrap_contribution_to_all_mean_ns", "non_epoch_wrap_contribution_to_all_mean_ns"]:
        result[key] = st.mean(r["observation"][key] for r in group)
    return result


def comparisons(runs):
    result = []
    for workers in [1,4]:
        groups = {variant:[r for r in runs if r["workers"] == workers and r["variant"] == variant] for variant in ["baseline","successor"]}
        require(all(len(g) == 20 for g in groups.values()), "incomplete twenty-pair cohort")
        aggregates = {v:aggregate(g) for v,g in groups.items()}
        pairs = []
        for old,new in zip(groups["baseline"],groups["successor"]):
            require(old["repeat"] == new["repeat"], "mispaired repeats")
            pair = {"repeat":old["repeat"], "order":"AB" if old["ordinal"] < new["ordinal"] else "BA", "windows":{}}
            for window in ["all", "tail_769_1024", "epoch_wrap", "non_epoch_wrap"]:
                pair["windows"][window] = {}
                for clock in ["wall","cpu"]:
                    a,b = old["observation"]["timing"][window][clock],new["observation"]["timing"][window][clock]
                    pair["windows"][window][clock] = {"mean_delta_ns":b["mean_ns"]-a["mean_ns"],
                        "mean_ratio":b["mean_ns"]/a["mean_ns"] if a["mean_ns"] else None,
                        "median_delta_ns":b["median_ns"]-a["median_ns"]}
            pairs.append(pair)
        deltas = {}
        for window in ["all", "tail_769_1024", "epoch_wrap", "non_epoch_wrap"]:
            deltas[window] = {}
            for clock in ["wall","cpu"]:
                a,b=aggregates["baseline"]["timing"][window][clock],aggregates["successor"]["timing"][window][clock]
                deltas[window][clock] = {"mean_delta_ns":b["mean_tick_ns"]-a["mean_tick_ns"],
                    "mean_ratio":b["mean_tick_ns"]/a["mean_tick_ns"] if a["mean_tick_ns"] else None,
                    "paired_delta_stdev_ns":st.pstdev(p["windows"][window][clock]["mean_delta_ns"] for p in pairs),
                    "positive_mean_delta_pairs":sum(p["windows"][window][clock]["mean_delta_ns"] > 0 for p in pairs)}
        result.append({"workers":workers,**aggregates,"differences":deltas,"paired_runs":pairs})
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--plan",type=Path,default=Path(__file__).with_name("preregistration.json"))
    p.add_argument("--plan-sha256",required=True,help="Parent-acknowledged frozen plan digest")
    p.add_argument("--output",type=Path,required=True,help="New nonexistent attempt directory outside every source checkout")
    args=p.parse_args()
    require(fact(args.plan)["sha256"] == args.plan_sha256,"frozen plan digest mismatch")
    plan=json.loads(args.plan.read_text())
    require(plan["schema"] == "mat354.h1.empty-performance-supplement-plan.v1","wrong plan")
    require(plan["workloads"] == ["empty"] and plan["workers"] == [1,4] and plan["paired_repeats"] == 20 and plan["native_processes"] == 80,"supplement scope changed")
    require(plan["numeric_adoption_threshold"] is None and plan["epoch_wrap_ticks"] == [256,511,766,1021],"fixed interpretation contract changed")
    verify(plan["driver"])
    require(Path(plan["driver"]["path"]).resolve() == Path(__file__).resolve(),"wrong driver")
    primary=json.loads(verify(plan["primary_receipt"]))
    require(primary["mode"] == "performance" and primary["status"] == "EXECUTED","primary receipt incomplete")
    verify(plan["custody_helper"])
    spec=importlib.util.spec_from_file_location("mat354_empty_supplement_custody",plan["custody_helper"]["path"])
    custody=importlib.util.module_from_spec(spec);spec.loader.exec_module(custody)
    host=custody.cpu_identity()
    require(all(host[k] == plan["expected_host"][k] for k in ["cpu","hostname","machine","os","logical_cpus"]),"measurement host changed")
    for variant,source in primary["sources"].items():
        source_root=Path(source["root"])
        require(custody.git(source_root,"rev-parse","HEAD") == source["commit"],"frozen source commit changed")
        require(custody.git(source_root,"rev-parse","HEAD^{tree}") == source["tree"],"frozen source tree changed")
        require(not custody.git(source_root,"status","--porcelain"),"frozen source dirty")
        require(not args.output.resolve().is_relative_to(source_root.resolve()),"output is inside a source checkout")
        for item in source["inputs"] + primary["builds"][variant]["dependencies"]:
            verify(item,source_root)
        verify(plan["executables"][variant])
        require(plan["executables"][variant] == primary["builds"][variant]["executable"],"binary differs from primary")
    for item in primary["apparatus"]["inputs"]:
        verify(item,Path(primary["sources"]["successor"]["root"]))
    verify(primary["compiler"])
    require(not args.output.exists(),"refusing to overwrite any attempt")
    args.output.mkdir(parents=True)
    report={"schema":"mat354.h1.empty-performance-supplement.v1","status":"RUNNING","started_utc":custody.now(),
        "plan":plan,"plan_file":fact(args.plan),"driver":fact(Path(__file__).resolve()),"host":host,
        "affinity_observation":sorted(os.sched_getaffinity(0)) if hasattr(os,"sched_getaffinity") else None,
        "sources":primary["sources"],"executables":plan["executables"],"runs":[],
        "primary_is_unchanged":True,"owner_performance_disposition_required":True,"numeric_adoption_threshold":None}
    destination=args.output/"supplement.json"
    custody.write_json(destination,report)
    deadline=time.monotonic()+plan["campaign_timeout_seconds"]
    try:
        for workers in [1,4]:
            for repeat in range(20):
                for variant in (["baseline","successor"] if repeat%2==0 else ["successor","baseline"]):
                    remaining=deadline-time.monotonic()
                    require(remaining>0,"campaign timeout before launch")
                    prefix=args.output/f"empty-w{workers}-r{repeat}-{variant}"
                    proc=custody.process([plan["executables"][variant]["path"],"--bench","empty",str(workers),"0"],
                        primary["sources"]["successor"]["root"],prefix,min(plan["case_timeout_seconds"],remaining))
                    custody.write_json(Path(str(prefix)+".process.json"),proc)
                    row={"ordinal":len(report["runs"]),"workload":"empty","workers":workers,"repeat":repeat,"variant":variant,"process":proc}
                    report["runs"].append(row);custody.write_json(destination,report)
                    row["observation"]=observation(proc,workers,plan)
                    custody.write_json(destination,report)
        require(len(report["runs"]) == 80,"wrong execution count")
        report["comparisons"]=comparisons(report["runs"])
        report["raw_authentication"]=custody.verify_retained_outputs([r["process"] for r in report["runs"]])
        for item in plan["executables"].values():verify(item)
        for source in primary["sources"].values():
            source_root=Path(source["root"])
            require(custody.git(source_root,"rev-parse","HEAD") == source["commit"] and not custody.git(source_root,"status","--porcelain"),"source changed during supplement")
            for item in source["inputs"]:verify(item,source_root)
        verify(plan["primary_receipt"]);verify(plan["driver"])
        require(fact(args.plan)["sha256"] == args.plan_sha256,"plan changed during execution")
        report["status"]="EXECUTED_PERFORMANCE_DISPOSITION_PENDING"
        report["coverage"]={"processes":80,"ticks":81920,"primary_samples_removed":0,"new_acceptance_thresholds":0}
    except Exception as exc:
        report["status"]="FAILED";report["failure"]=type(exc).__name__+": "+str(exc)
    report["finished_utc"]=custody.now();custody.write_json(destination,report)
    print(json.dumps({"status":report["status"],"receipt":fact(destination)}))
    return 0 if report["status"]=="EXECUTED_PERFORMANCE_DISPOSITION_PENDING" else 1


if __name__=="__main__":
    raise SystemExit(main())
