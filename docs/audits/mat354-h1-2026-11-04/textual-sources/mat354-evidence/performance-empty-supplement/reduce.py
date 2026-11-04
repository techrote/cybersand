#!/usr/bin/env python3
"""Independent arithmetic/raw-custody reduction; never invokes native code.

Creates one fresh directory with a supplement audit/report and repository-ready
primary+supplement result section. Does not change any primary/supplement input.
"""
import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import statistics as st

PLAN_SHA="de2b592d03d9bf0198ed59d48d16bbbc7df581779482bd5954414233e740cf3d"
DRIVER_SHA="0b986b9370f11ada9726c53c9b4a826e3ef8a2d79b85dc21207d7b0470bcfc64"
WRAPS={256,511,766,1021}


def fact(p):
    b=p.read_bytes();return {"path":str(p),"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}


def verify(f):
    p=Path(f["path"]);a=fact(p)
    assert a["bytes"]==f["bytes"] and a["sha256"]==f["sha256"],p
    return p.read_bytes()


def statistics(v):
    s=sorted(v)
    return {"count":len(v),"mean_ns":st.mean(v),"median_ns":st.median(v),"p95_ns":s[math.ceil(len(v)*.95)-1],
            "p99_ns":s[math.ceil(len(v)*.99)-1],"min_ns":min(v),"max_ns":max(v),"stdev_ns":st.pstdev(v)}


def audit(root):
    base=root/"performance-empty-supplement";p=base/"attempt-1/supplement.json";q=json.loads(p.read_text())
    assert q["status"]=="EXECUTED_PERFORMANCE_DISPOSITION_PENDING" and len(q["runs"])==80
    assert fact(base/"preregistration.json")["sha256"]==PLAN_SHA and fact(base/"run.py")["sha256"]==DRIVER_SHA
    assert q["plan_file"]["sha256"]==PLAN_SHA and q["driver"]["sha256"]==DRIVER_SHA
    primary=json.loads(verify(q["plan"]["primary_receipt"]))
    for variant,exe in q["executables"].items():
        verify(exe);assert exe==primary["builds"][variant]["executable"]
    assert q["sources"]==primary["sources"]
    expected=[]
    for workers in [1,4]:
        for repeat in range(20):
            for variant in (["baseline","successor"] if repeat%2==0 else ["successor","baseline"]):expected.append((workers,repeat,variant))
    assert [(r["workers"],r["repeat"],r["variant"]) for r in q["runs"]]==expected
    assert all(a["process"]["finished_utc"]<=b["process"]["started_utc"] for a,b in zip(q["runs"],q["runs"][1:]))
    reductions=[]
    for run in q["runs"]:
        proc=run["process"];assert proc["returncode"]==0 and not proc["timed_out"] and not verify(proc["stderr"])
        rows=[json.loads(x) for x in verify(proc["stdout"]).splitlines()];meta,last,ts=rows[0],rows[-1],rows[1:-1]
        assert len(rows)==1026 and [r["tick"] for r in ts]==list(range(1,1025))
        assert meta["workload"]=="empty" and meta["workers"]==run["workers"] and not meta["diagnostics"]
        assert meta["warmup_ticks"]==32 and meta["warmup_world"]=="separate throwaway" and meta["ticks"]==1024
        assert meta["cpu_clock_available"] and meta["cpu_clock_ticks_per_second"]==1000000
        assert meta["resident_before"]==last["resident_after"]==4202496
        zero=["jobs","visited_cells","active_blocks","observed_workers","chunk_allocations","temperature_allocations","observed_deadline_changes","first_source_due","first_source_material","first_source_a"]
        assert all(r["type"]=="h1_benchmark_tick" and all(r[f]==0 for f in zero) and r["resident_cell_bytes"]==4202496 for r in ts)
        assert last["tick_ns_total"]==sum(r["tick_ns"] for r in ts) and last["cpu_clock_ticks_total"]==sum(r["cpu_clock_ticks"] for r in ts)
        assert last["physical_hash"]==q["plan"]["expected_empty_state"]["physical_hash"] and last["tuple_hash"]==q["plan"]["expected_empty_state"]["tuple_hash"]
        windows={"all":ts,"tail_769_1024":ts[768:],"epoch_wrap":[r for r in ts if r["tick"] in WRAPS],"non_epoch_wrap":[r for r in ts if r["tick"] not in WRAPS]}
        timings={w:{"wall":statistics([r["tick_ns"] for r in v]),"cpu":statistics([r["cpu_clock_ticks"]*1000.0 for r in v])} for w,v in windows.items()}
        assert timings==run["observation"]["timing"]
        reductions.append({"workers":run["workers"],"repeat":run["repeat"],"variant":run["variant"],"timing":timings})
    for c in q["comparisons"]:
        for variant in ["baseline","successor"]:
            selected=[r for r in reductions if r["workers"]==c["workers"] and r["variant"]==variant]
            assert len(selected)==20
            for window in ["all","tail_769_1024","epoch_wrap","non_epoch_wrap"]:
                for clock in ["wall","cpu"]:
                    values=[r["timing"][window][clock] for r in selected];a=c[variant]["timing"][window][clock]
                    assert a["individual_run_means_ns"]==[x["mean_ns"] for x in values]
                    assert a["individual_run_medians_ns"]==[x["median_ns"] for x in values]
                    assert a["mean_tick_ns"]==st.mean(x["mean_ns"] for x in values)
                    assert a["median_of_run_medians_ns"]==st.median(x["median_ns"] for x in values)
                    assert a["median_of_run_p95_ns"]==st.median(x["p95_ns"] for x in values)
                    assert a["median_of_run_p99_ns"]==st.median(x["p99_ns"] for x in values)
        for pair in c["paired_runs"]:
            old,new=[next(r for r in reductions if r["workers"]==c["workers"] and r["repeat"]==pair["repeat"] and r["variant"]==v) for v in ["baseline","successor"]]
            for window in pair["windows"]:
                for clock in ["wall","cpu"]:
                    a,b=old["timing"][window][clock],new["timing"][window][clock];d=pair["windows"][window][clock]
                    assert d["mean_delta_ns"]==b["mean_ns"]-a["mean_ns"]
                    assert d["mean_ratio"]==b["mean_ns"]/a["mean_ns"]
    primary_audit=json.loads(verify(q["plan"]["primary_audit"]))
    return {"schema":"mat354.h1.empty-supplement-audit.v1","status":"EXECUTION_VERIFIED_PERSISTENT_WRAP_COST_REQUIRES_DISPOSITION",
        "created_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"reproducer":fact(Path(__file__).resolve()),
        "receipts":[fact(p),fact(base/"preregistration.json"),fact(base/"run.py"),fact(base/"isolation-1.json"),fact(base/"launch-1.json"),q["plan"]["primary_audit"]],
        "coverage":{"processes":80,"raw_output_facts":160,"tick_rows":81920,"paired_repeats_per_worker_setting":20,"samples_removed":0},
        "sources":q["sources"],"executables":q["executables"],"comparisons":q["comparisons"],"all_recomputed_run_timings":reductions,
        "conclusion":"The primary +64.96% one-worker whole-tick empty wall mean is not reproduced at that magnitude; supplemental means are +6.49% one-worker/-1.69% four-worker. Epoch-wrap CPU cost remains higher in18/20 and17/20 pairs, respectively. This persistent observed cost is unresolved, not declared benign or accepted. No primary sample or Water PressureFlow observation is superseded.",
        "numeric_adoption_threshold":None,"owner_performance_disposition_required":True},q,primary_audit


def supplement_report(a,q):
    out=["# Empty-world performance supplement", "", "**All80 preregistered processes executed; performance acceptance remains pending.** The successor's higher epoch-wrap cost persists. The primary cohort remains unchanged, and this empty-only supplement does not dispose Water PressureFlow observations.", "",
         "The root acknowledged plan SHA `"+PLAN_SHA+"` and driver SHA `"+DRIVER_SHA+"` before launch. Exact original F2 binaries ran20 alternating AB/BA pairs at each of configured workers1/4. Each fresh32-chunk empty World runs1024 ticks after32 warmup ticks on a separate throwaway World. There were no other owned local process tasks during timing; this does not guarantee host-wide isolation. Affinity was observed as0–8 and was not modified.", "",
         "## Whole-tick measurements", "", "Values are µs. Means retain every sample. Medians/p95/p99 are medians of the20 individual run statistics. CPU is process CPU with1µs nominal resolution.", "",
         "| Workers | Clock | Baseline mean | H1 mean | Δ µs | Δ % | Median B→H1 | p95 B→H1 | p99 B→H1 | Positive paired means |", "|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for c in q["comparisons"]:
        for clock in ["wall","cpu"]:
            b,n=[c[v]["timing"]["all"][clock] for v in ["baseline","successor"]];d=c["differences"]["all"][clock]
            pair=lambda k:f"{b[k]/1000:.3f}→{n[k]/1000:.3f}"
            out.append(f"| {c['workers']} | {clock} | {b['mean_tick_ns']/1000:.6f} | {n['mean_tick_ns']/1000:.6f} | {d['mean_delta_ns']/1000:+.6f} | {(d['mean_ratio']-1)*100:+.2f}% | {pair('median_of_run_medians_ns')} | {pair('median_of_run_p95_ns')} | {pair('median_of_run_p99_ns')} | {d['positive_mean_delta_pairs']}/20 |")
    out += ["", "## Fixed epoch and non-epoch strata", "", "The fixed epoch-wrap ticks are256,511,766,1021, derived from the fresh World's byte epoch0 and reset-to1 behavior. These ticks remain in all whole-tick statistics. Their separate reduction is explanatory; no outlier is dropped.", "",
            "| Workers | Stratum | Clock | Mean B→H1 µs | Relative change | Positive pairs |", "|---:|---|---|---:|---:|---:|"]
    for c in q["comparisons"]:
        for window in ["epoch_wrap","non_epoch_wrap"]:
            for clock in ["wall","cpu"]:
                b,n=[c[v]["timing"][window][clock] for v in ["baseline","successor"]];d=c["differences"][window][clock]
                out.append(f"| {c['workers']} | {window} | {clock} | {b['mean_tick_ns']/1000:.3f}→{n['mean_tick_ns']/1000:.3f} | {(d['mean_ratio']-1)*100:+.2f}% | {d['positive_mean_delta_pairs']}/20 |")
    out += ["", "Epoch CPU rises78.49% in the one-worker cohort and30.63% in the four-worker cohort, while non-epoch cost improves. Whole-tick means are sensitive to these opposite contributions and run-level outliers; improved whole-tick medians do not resolve the persistent wrap increase. The unchanged normalized epoch-clearing instruction prefix does not identify its cause. No causal claim that host interference or source code explains all variation is established.", "",
            "## Integrity, scope and disposition", "", "The independent arithmetic reduction authenticates160 raw output facts and all81,920 contiguous tick rows, recomputes every per-run window quantile and every paired ratio, and confirms exact original binary hashes. All samples have zero jobs, visits, active blocks, observed claimants, deadline changes and counted allocations; resident_cell_bytes remains4,202,496. Final empty physical/tuple identity matches the primary cohort. Complete heap/RSS, hardware counters, frequency and host-wide scheduling are not measured.", "",
            "No numerical H1 acceptance threshold exists. An owner performance disposition and independent final review remain required. The primary results, primary failed evidence and Water PressureFlow timing observations are retained without reclassification.", ""]
    return "\n".join(out)


def repository_section(primary,supplement):
    out=["## Native performance qualification — measured, owner disposition pending", "",
         "The primary source-qualified comparison used accepted main `751edc0b495dc85484ad5509a7c95f863651c76b` (tree `b0d42a256285e6049a6d3bdd1613d7ecd89f43c6`) and frozen F2 `9d218bb179e72e9fa68b755d82680dbd739fb85e` (tree `d025ee050b8c782873161443428f804dd1622cfb`). World SHA-256 values are `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1` and `df0bb080084972c49ca400b7bfc6504f7ec27fa474112bc2bd56abe5d3d21539`. Later public source-anchor metadata reconciliation is separate and does not rewrite these execution identities.", "",
         "Measurements ran on AMD EPYC9V74 / Linux6.18.57 / x86_64,9 reported logical CPUs, GCC13.3.0, identical `-O3 -DNDEBUG` source-qualified build flags. Primary protocol:14 workloads × workers1/4 ×5 AB/BA pairs =280 processes/286,720 timed ticks;56 separate diagnostic replays supply57,344 work-trace ticks. Each measured World is fresh, after32 warmup ticks on a separate World, then1024 retained ticks. No other owned local work ran during timing; host-wide isolation is not established.", "",
         "The tables report µs per tick. Wall mean includes every tick across all five runs. Median/p95 are medians of the five corresponding per-run statistics. σ is population SD across the five run means, not across an assumed independent5120-tick sample. CPU mean is process CPU including worker time, at1µs nominal resolution; CPU/wall are distinct observations. Full p99/max, raw values, all individual runs/pairs and variance are retained in the audit packet."]
    for workers in [1,4]:
        out += ["",f"### Configured workers{workers}","","| Workload | Wall mean B→H1 | Δ µs (%) | Median B→H1 | p95 B→H1 | Run-mean σ B→H1 | CPU mean B→H1 (Δ%) |","|---|---:|---:|---:|---:|---:|---:|"]
        for c in primary["comparisons"]:
            if c["workers"]!=workers:continue
            b,n=[c[v]["timing"]["all"] for v in ["baseline","successor"]];dw,dc=c["differences"]["wall"],c["differences"]["cpu"]
            pair=lambda clock,key:f"{b[clock][key]/1000:.3f}→{n[clock][key]/1000:.3f}"
            out.append(f"| {c['workload']} | {pair('wall','mean_tick_ns')} | {dw['mean_delta_ns']/1000:+.3f} ({(dw['mean_ratio']-1)*100:+.2f}%) | {pair('wall','median_of_run_medians_ns')} | {pair('wall','median_of_run_p95_ns')} | {pair('wall','run_mean_stdev_ns')} | {pair('cpu','mean_tick_ns')} ({(dc['mean_ratio']-1)*100:+.2f}%) |")
    out += ["", "### Work, retirement and memory bounds", "", "Historical cold sources stop after only a few visits; the successor performs the finite cooling work and converts them. The large cold timing ratios therefore include restored work absent from the defective baseline. They do not establish acceptability by themselves.", "",
            "| Workload | Jobs B→H1 | Visited cells B→H1 | H1 last job | H1 tail jobs | H1 deadline changes | H1 final Molten/Glass | Actual claimants at4 B→H1 |", "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for c in primary["comparisons"][:14]:
        b,n=c["baseline"]["work"],c["successor"]["work"];four=next(x for x in primary["comparisons"] if x["workload"]==c["workload"] and x["workers"]==4)
        out.append(f"| {c['workload']} | {b['jobs']}→{n['jobs']} | {b['visited_cells']}→{n['visited_cells']} | {n['last_job_tick']} | {n['tail_jobs']} | {n['deadline_observation_changes']} | {n['final_molten']}/{n['final_glass']} | {four['baseline']['observed_claimants_max']}→{four['successor']['observed_claimants_max']} |")
    out += ["", "Across both worker configurations and all repeats, cold1/16/64 and mixed stop added work bytick723; cooling deadline observations cease changing bytick720. All have zero jobs, visits and active blocks throughout tail769–1024. Hot180 retains144 MoltenGlass cells and only the original3 jobs/432 visits. The ten control workloads have exact old/new final physical/tuple identity and complete recorded work/state trajectories. All12 runs per workload/source (five at each worker setting plus both diagnostic replays) have the same work/state trace.", "",
            "Every measured tick records zero chunk/temperature allocations and constant resident_cell_bytes:131,328 bytes for singleton/small fixtures;2,101,248 for cold16;8,404,992 for cold64;4,202,496 for mixed and the32-chunk empty world. These counters omit general heap/hash/scheduler storage and RSS; they are not a complete memory-growth qualification. Cold1 diagnostics record180 due-lane and540 ordinary off-lane entries, then one conversion. Multicell thermal/off-lane visits are aggregate-only; deadline changes do not count every coalesced request or stale-wake event.", "",
            "Water CY's256 tail jobs are unchanged existing behavior. PressureFlow has zero tail scheduled jobs while preserving substantial existing whole-tick CPU cost. No zero-CPU-idle claim follows from zero jobs.", "",
            "### Conversion latency and observed worker cost", "", "The sampled cold source at(11,8) converts at tick720. Elapsed values include between-tick observation/clock overhead; cumulative timed-tick cost is separately retained in receipts.", "",
            "| Workload | Mean elapsed to sampled Glass,1 worker ms | Mean elapsed,4 workers ms | Four-worker wall speedup | Four/one CPU cost |", "|---|---:|---:|---:|---:|"]
    for workload in ["cold1","cold16","cold64","mixed"]:
        one,four=[next(c for c in primary["comparisons"] if c["workload"]==workload and c["workers"]==w) for w in [1,4]]
        s=next(x for x in primary["worker_scaling"] if x["workload"]==workload and x["variant"]=="successor")
        out.append(f"| {workload} | {one['successor']['first_source_elapsed_wall_ns_to_glass']['mean_ns']/1e6:.3f} | {four['successor']['first_source_elapsed_wall_ns_to_glass']['mean_ns']/1e6:.3f} | {s['wall_speedup_one_over_four']:.3f}× | {s['cpu_cost_ratio_four_over_one']:.3f}× |")
    out += ["", "The inherited Phase A apparatus uses parallel_job_threshold=1; production WorldConfig defaults to8. Thus configured4 with one cold source dispatches the existing pool for one useful claimant and is about2.85× slower in wall time than configured1. This identifies a coordination path but does not attribute every measured delta to it; threshold8 performance was not measured. Cold16/64 and mixed show four real claimants. The worker1 and worker4 cohorts occupy separate windows, so scaling ratios also inherit host variance.", "",
            "### Preserved outliers and the preregistered empty-only supplement", "", "Primary empty one-worker wall mean is1.840658→3.036268µs (+64.96%) despite median1.131→1.001µs. Fixed epoch resets at256/511/766/1021 contribute +0.597254µs to that +1.195611µs all-tick delta; non-epoch samples contribute +0.598356µs. Successor repeat1/ticks725,737 cost1733.753/955.796µs wall and1736/957µs process CPU with zero jobs. The CPU evidence prevents dismissing them as ordinary descheduling alone.", "",
            "One separately frozen empty-only supplement used the same binaries,32-chunk geometry,32 warmup/1024 measured ticks,20 AB/BA pairs at each worker count:80 processes/81,920 ticks. Plan SHA `"+PLAN_SHA+"`; driver SHA `"+DRIVER_SHA+"`. All samples, every pair and fixed epoch/non-epoch strata remain retained; no primary result was replaced.", "",
            "| Workers | All-tick wall mean B→H1 µs | Wall Δ | All-tick CPU mean B→H1 µs | CPU Δ | Wrap CPU B→H1 µs | Wrap positive pairs |", "|---:|---:|---:|---:|---:|---:|---:|"]
    for c in supplement["comparisons"]:
        b,n=[c[v]["timing"] for v in ["baseline","successor"]];d=c["differences"]
        pair=lambda win,clock:f"{b[win][clock]['mean_tick_ns']/1000:.6f}→{n[win][clock]['mean_tick_ns']/1000:.6f}"
        out.append(f"| {c['workers']} | {pair('all','wall')} | {(d['all']['wall']['mean_ratio']-1)*100:+.2f}% | {pair('all','cpu')} | {(d['all']['cpu']['mean_ratio']-1)*100:+.2f}% | {pair('epoch_wrap','cpu')} | {d['epoch_wrap']['cpu']['positive_mean_delta_pairs']}/20 |")
    out += ["", "The primary whole-tick idle increase is not reproduced at the same magnitude. The epoch-wrap CPU increase persists (+78.49% at1worker, +30.63% at4), while non-wrap means improve. The source and normalized compiled epoch-clearing prefix are unchanged, which narrows investigation but does not explain or waive the measured cost. This remains an unresolved performance observation requiring disposition.", "",
            "Water PressureFlow one-worker primary means rise +5.87% wall/+5.97% CPU, with four of five paired increases; four-worker means fall−8.28% wall/−8.93% CPU. Individual paired/run distributions remain available. The empty-only supplement does not resolve this variance-sensitive observation.", "",
            "**Performance disposition: pending; no adoption GO.** The repository provides no numerical H1 adoption threshold. Finite work, deterministic controls and bounded recorded allocation/resident behavior are demonstrated, but those facts do not replace an explicit owner performance disposition, representative-target qualification, compatibility resolution and independent final review. No outlier removal, new numerical threshold, scheduler-policy change, runtime adoption or merge is implied.", ""]
    return "\n".join(out)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--evidence-root",type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument("--output-dir",type=Path,required=True)
    args=p.parse_args();assert not args.output_dir.exists(),"refusing to overwrite any output directory"
    report,supplement,primary=audit(args.evidence_root.resolve());args.output_dir.mkdir()
    output={"supplement-audit.json":json.dumps(report,indent=2,sort_keys=True)+"\n","supplement-report.md":supplement_report(report,supplement),"repository-results-section.md":repository_section(primary,supplement)}
    for name,content in output.items():
        with (args.output_dir/name).open("x") as f:f.write(content);f.flush();os.fsync(f.fileno())
    print(json.dumps({"status":report["status"],"files":[fact(args.output_dir/n) for n in output]}))
