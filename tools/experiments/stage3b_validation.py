"""Candidate-independent Stage-3B validation preregistration apparatus (#69)."""
from __future__ import annotations
import argparse, hashlib, json, math
from pathlib import Path
from typing import Any

PLAN_SCHEMA="cybersand.stage3b.validation-plan"; PLAN_VERSION=1
RESULT_SCHEMA="cybersand.stage3b.validation-result"; RESULT_VERSION=1
REPORT_SCHEMA="cybersand.stage3b.validation-report"; REPORT_VERSION=1
FIXTURE_SCHEMA="cybersand.stage3b.fixture-catalogue"; FIXTURE_VERSION=1
CONTRACT_VERSION="stage3b-validation-v1"
ORDER_SEED="cybersand-stage3b-preregistered-order-v1"
WORKERS=(1,4); BUDGETS=(1,8,64,256,1024); FINAL_REPEATS=5
SERVICES=({"id":"drain","budget":None},)+tuple({"id":f"budget-{b}","budget":b} for b in BUDGETS)
ARMS=(
 {"id":"current-discovery-disabled","class":"control","availability":"available"},
 {"id":"stage3a-untouched","class":"reference","availability":"reference-series"},
 {"id":"stage3a-runtime-sized","class":"matched-reference","availability":"unavailable"},
 {"id":"stage3b-sparse-producer","class":"intermediate","availability":"unavailable"},
 {"id":"stage3b-indexed-graph","class":"intermediate","availability":"unavailable"},
 {"id":"stage3b-candidate","class":"candidate","availability":"unavailable"},
)
RESULT_STATES=("success","correctness-failure","refused","timeout","source-failure",
               "failed-world","unavailable","not-applicable")
PROVENANCE_FIELDS=("source_commit","dirty_status","source_input_hashes","compiler_executable",
 "compiler_version","compiler_sha256","flags","executable_sha256","contract_version","capacities",
 "worker_count","fixture_id","fixture_version","seed","authoritative_mutation_schedule",
 "observer_service_schedule","arm_id","hardware","os","power_mode","run_order","repeat_index",
 "stdout_identity","stderr_identity","raw_result_identity")
MEASUREMENTS={
 "producer_signal":("changed_coverage","conservative_coverage","hook_reduction_ms","queue_entries",
  "queue_high_water","revision_witness_advances","overflow_refusal_count","unrelated_coverage_touched"),
 "deadline_activity":("deadline_changes","due_processing","parked_reentry_transitions",
  "heap_index_comparisons","unchanged_block_polling_count"),
 "exact_extraction":("source_reads","capture_ms","extraction_work","components","restarts","duplicate_reads"),
 "index":("lookups","comparisons","rotations_moves","collision_chains","insert_remove_cost","registration_work"),
 "retirement_dependency":("dependencies_subscribers_touched","publications_retired",
  "mutation_to_old_handle_invalid_ms","unrelated_regions_visited"),
 "merge_local_fast_path":("certificate_proof_operations","root_union_work","members_dependencies_moved",
  "fallback_count","invalidated_fast_path_attempts"),
 "reconstruction":("visited_components","incident_edges","dependency_witnesses","frontier_high_water",
  "restarts","cancellation_cause","service_rounds","time_to_complete_ms","refusal_reason"),
 "publication":("member_dependency_preparation","legacy_fold_composable_digest_work","validation_work",
  "commit_duration_ms","output_schema_version"),
 "reclamation":("nodes_retired","bytes_retired","cleanup_primitives","cleanup_ms","oldest_retained_generation",
  "reclamation_caused_deferral"),
 "end_to_end":("mutation_to_retirement_ms","dirty_to_local_observation_ms","dirty_to_global_observation_ms",
  "service_call_latency_ms","owner_tick_plus_observer_ms","throughput_per_second","total_ms"),
 "memory":("requested_capacity_bytes","layout_derived_bytes","allocator_committed_bytes","live_bytes",
  "staged_bytes","retired_bytes","scratch_high_water_bytes","process_rss_bytes"),
}
TUPLE_FIELDS=("material","state_a","state_b","temperature","occupancy","masks","events","inclusion",
              "completed_ticks","failure_quarantine","source_sink_quantity_ledgers")

def fixture(fid,family,desc,**kw):
    return {"id":fid,"version":1,"family":family,"description":desc,
            "tags":kw.pop("tags",[]),"expected_outcomes":kw.pop("expected_outcomes",["success"]),**kw}

def fixture_catalogue():
    out=[]
    phases=["initial-construction","registration","first-exact-capture-classification",
            "first-region-publication","steady-quiet-drain"]
    for s in (512,1024,2048):
        out.append(fixture(f"quiet.initial-{s}","quiet-initial-population",f"{s}-scale startup and steady quiet",phases=phases,parameters={"side":s}))
    out += [
      fixture("quiet.sparse-represented-coverage","quiet-initial-population","Sparse represented coverage",phases=phases,parameters={"authority_scale":2048,"coverage":"sparse"}),
      fixture("quiet.large-capacity-small-coverage","quiet-initial-population","Large capacity, small represented coverage",phases=phases,parameters={"capacity":4096,"represented":64})]
    fields=("material","state_a","state_b","temperature","occupied_material","canonical_empty","noncanonical_empty","negative_temperature")
    positions=("tile-interior","tile-face","tile-corner","chunk-activity-boundary")
    for f in fields:
        for p in positions:
            out.append(fixture(f"one-cell.{f}.{p}","genuine-one-cell-edit",f"Exactly one {f} edit at {p}",
              intended_changed_cell_count=1,mutation={"selector":p,"field":f,"authoritative_cells_changed":1},
              expected_outcomes=["success","not-applicable"] if f in {"noncanonical_empty","negative_temperature"} else ["success"]))
    out += [
      fixture("historical.local-edit-8x8","retained-historical-control","Historical local-edit",intended_changed_cell_count=64,retained_meaning="8x8 patch edit"),
      fixture("historical.bridge-whole-column","retained-historical-control","Historical bridge",retained_meaning="whole-column change"),
      *[fixture(f"historical.{n}","retained-historical-control",f"Historical {n}",retained_meaning=n) for n in ("churn","ring","mask","pending-event","exclusion")]]
    topo=("large-solid-connected-region","ring","comb-maze","holes","checkerboard-component-pressure",
          "one-cell-bridge-add","one-cell-bridge-remove","alternate-path-nonsplit","genuine-large-split",
          "many-child-split","topology-preserving-interior-hole","changed-port-partition")
    one={"one-cell-bridge-add","one-cell-bridge-remove","alternate-path-nonsplit","genuine-large-split",
         "many-child-split","topology-preserving-interior-hole","changed-port-partition"}
    for n in topo:
        kw={}
        if n in one: kw={"intended_changed_cell_count":1,"mutation":{"selector":"canonical-topology-coordinate","field":"material","authoritative_cells_changed":1}}
        out.append(fixture(f"topology.{n}","connectivity-topology",n,**kw))
    for n in ("absent-location","absent-to-resident-registration","registered-unknown","unknown-to-ready-matching",
              "unknown-to-ready-nonmatching","unknown-to-canonical-empty","resident-untracked","excluded","re-entry",
              "capacity-refused","failed-read-world","new-facing-coverage-before-payload-ready"):
        out.append(fixture(f"coverage.{n}","coverage-absence-registration",n,expected_outcomes=["success","refused","source-failure","failed-world"]))
    for n in ("future-deadline-insertion","earlier-replacement","cancellation","consumption","equal-deadline-ordering",
              "excluded-overdue-deadline","re-entry","no-write-keep-active","sleep-wake-transition","many-deadline-changes-no-payload-writes"):
        out.append(fixture(f"deadline.{n}","activity-deadline-no-write",n))
    for n in ("direct-tuple-A-B-A","mask-set-clear","mask-reconfiguration","overlapping-event-acceptance-drain",
              "inclusion-requested-applied-ABA","same-barrier-restore","worker-effect-rectangle-fanout","event-dependency-halo-fanout"):
        out.append(fixture(f"aba.{n}","aba-fanout",n,
          expected_outcomes=["success","not-applicable"] if n=="same-barrier-restore" else ["success"]))
    for n in ("continuous-local-churn","stable-nearby-candidate","stable-far-candidate","independent-pending-domains",
              "churn-every-1-service-call","churn-every-2-service-calls","churn-every-8-service-calls",
              "continuous-lower-coordinate-arrival","stale-work-before-validation","recovery-after-churn-stops","cleanup-reclamation-near-capacity"):
        out.append(fixture(f"progress.{n}","progress-churn-fairness",n,parameters={"record_remote_job_age":True}))
    caps=("tiles","local-components","graph-edges","dependencies","absence-certificates","dirty-signal-queues",
          "native-worker-signal-records","deadline-entries","reconstruction-jobs","frontier","visited","publications","retired-reclamation-storage")
    for c in caps:
        for b in ("exact-cap","one-past-cap"):
            out.append(fixture(f"capacity.{c}.{b}","capacity-failure",f"{c} {b}",
              parameters={"capacity_class":c,"boundary":b},expected_outcomes=["success","refused","not-applicable"]))
    for n in ("allocation-failure-construction","allocation-failure-observer-replacement","capacity-failure-staging",
              "failure-after-partial-preparation","source-capture-failure","failed-world-quarantine"):
        out.append(fixture(f"failure.{n}","capacity-failure",n,expected_outcomes=["refused","source-failure","failed-world"]))
    for n in ("forward-reverse-registration","successful-free-slot-order","allocation-order","equal-deadline-ties",
              "translated-signed-geometry","adversarial-hash-keys","scarce-publication-capacity-competition"):
        out.append(fixture(f"determinism.{n}","determinism-permutation",n,parameters={"workers":[1,4],"canonical_output_required":True},
          expected_outcomes=["success","not-applicable"] if n=="adversarial-hash-keys" else ["success"]))
    axes=("configured-capacity","represented-coverage","component-complexity","edge-complexity","dependency-fanout",
          "active-reconstruction-jobs","staged-generations","retired-unreclaimed-generations")
    for a in axes:
        for v in (64,256,1024,4096):
            out.append(fixture(f"memory.{a}.{v}","memory",f"{a}={v}",parameters={"sweep_axis":a,"value":v,"other_axes":"baseline"},
              expected_outcomes=["success","not-applicable"]))
    return out

def validate_fixtures(fs):
    ids=[f["id"] for f in fs]
    if len(ids)!=len(set(ids)): raise ValueError("duplicate fixture id")
    required={"quiet-initial-population","genuine-one-cell-edit","retained-historical-control","connectivity-topology",
      "coverage-absence-registration","activity-deadline-no-write","aba-fanout","progress-churn-fairness",
      "capacity-failure","determinism-permutation","memory"}
    missing=required-{f["family"] for f in fs}
    if missing: raise ValueError(f"missing fixture families: {sorted(missing)}")
    for f in fs:
        if f["family"]=="genuine-one-cell-edit" and (f.get("intended_changed_cell_count")!=1 or f["mutation"]["authoritative_cells_changed"]!=1):
            raise ValueError("one-cell fixture drift")
    by={f["id"]:f for f in fs}
    if by["historical.local-edit-8x8"]["retained_meaning"]!="8x8 patch edit": raise ValueError("historical local-edit drift")
    if by["historical.bridge-whole-column"]["retained_meaning"]!="whole-column change": raise ValueError("historical bridge drift")

def fixture_document():
    fs=fixture_catalogue(); validate_fixtures(fs)
    return {"schema":FIXTURE_SCHEMA,"version":1,"contract_version":CONTRACT_VERSION,"fixtures":fs}

def defaults():
    return {a["id"]:{"availability":a["availability"],"source_commit":None,"runtime_identity":None,
            "reason":"#70 must freeze unresolved identities before execution"} for a in ARMS}

ATTRIBUTION={"quiet.initial-2048","one-cell.material.tile-interior","topology.genuine-large-split",
             "deadline.many-deadline-changes-no-payload-writes","progress.continuous-local-churn",
             "memory.configured-capacity.4096"}

def role(f): return "paired" if f["family"] in {"quiet-initial-population","genuine-one-cell-edit","retained-historical-control","connectivity-topology","memory"} else "correctness"
def budget_sensitive(f):
    i=f["id"]
    return (f["family"]=="progress-churn-fairness"
        or (f["family"]=="activity-deadline-no-write" and i.endswith(("future-deadline-insertion","earlier-replacement","many-deadline-changes-no-payload-writes")))
        or (f["family"]=="connectivity-topology" and any(x in i for x in ("bridge","split","alternate-path","port-partition")))
        or (f["family"]=="capacity-failure" and any(x in i for x in ("reconstruction-jobs","frontier","visited","retired-reclamation-storage","failure-after-partial-preparation"))))
def arms_for(f):
    if f["family"]=="memory": a=["stage3a-runtime-sized","stage3b-candidate"]
    elif role(f)=="paired": a=["current-discovery-disabled","stage3a-untouched","stage3a-runtime-sized","stage3b-candidate"]
    else: a=["stage3a-runtime-sized","stage3b-candidate"]
    if f["id"] in ATTRIBUTION: a += ["stage3b-sparse-producer","stage3b-indexed-graph"]
    canon=[x["id"] for x in ARMS]; return [x for x in canon if x in set(a)]
def okey(*p): return hashlib.sha256(":".join(map(str,(ORDER_SEED,*p))).encode()).hexdigest()

def selected(profile):
    fs=fixture_catalogue(); validate_fixtures(fs)
    if profile=="final": return fs
    ids={"quiet.initial-512","one-cell.material.tile-interior","topology.one-cell-bridge-add",
         "coverage.capacity-refused","failure.allocation-failure-construction",
         "determinism.forward-reverse-registration","memory.configured-capacity.64"}
    return [f for f in fs if f["id"] in ids]

def build_plan(apparatus_source_commit,profile="final",arm_manifest=None,execution_authority=None):
    if not apparatus_source_commit: raise ValueError("apparatus source commit required")
    manifest=defaults()
    for k,v in (arm_manifest or {}).items():
        if k not in manifest: raise ValueError(f"unknown arm: {k}")
        manifest[k]={**manifest[k],**v}
    if any(v["availability"] not in {"available","reference-series","unavailable"} for v in manifest.values()):
        raise ValueError("invalid arm availability")
    cells=[]
    for f in selected(profile):
        reps=FINAL_REPEATS if profile=="final" and role(f)=="paired" else 1
        cells.append((f,SERVICES[0],arms_for(f),reps))
        if budget_sensitive(f):
            ba=[a for a in arms_for(f) if a not in {"current-discovery-disabled","stage3a-untouched"}]
            for svc in SERVICES[1:]: cells.append((f,svc,ba,FINAL_REPEATS if profile=="final" else 1))
    expanded=sorted(((c,w) for c in cells for w in WORKERS),key=lambda x:okey(x[0][0]["id"],x[1],x[0][1]["id"]))
    runs=[]; n=0
    for (f,svc,aa,reps),w in expanded:
        for r in range(1,reps+1):
            order=aa if r%2 else list(reversed(aa))
            for pos,a in enumerate(order):
                n+=1; av=manifest[a]["availability"]
                runs.append({"run_id":f"{profile}-n{n:06d}","order_index":n,"order_key":okey(f["id"],w,svc["id"]),
                  "repeat_index":r,"cell_repeat_count":reps,"campaign_role":role(f),"arm_position":pos,"arm_id":a,
                  "arm_availability":av,"run_state":"scheduled" if av=="available" else av,"fixture_id":f["id"],
                  "fixture_version":1,"worker_count":w,"service_mode":svc["id"],"primitive_budget":svc["budget"],"seed":0})
    auth=execution_authority or {}
    return {"schema":PLAN_SCHEMA,"version":1,"contract_version":CONTRACT_VERSION,"profile":profile,
      "apparatus_source_commit":apparatus_source_commit,
      "execution_authority":{"status":auth.get("status","must-freeze-before-#70-execution"),
        "authoritative_simulation_material_baseline":auth.get("authoritative_simulation_material_baseline"),
        "notes":auth.get("notes"),
        "rule":"Matched observer arms share one authority where possible; unmatched Stage-3A stays a separate reference series."},
      "order_seed":ORDER_SEED,
      "ordering_policy":{"cells":"fixed sha256 shuffle of fixture/worker/service","arms":"normal odd repeats, reversed even repeats",
        "parallel_benchmark_processes":False,"warmup_qualification_separate":True},
      "repeat_policy":{"paired_drain_cells":5,"fixed_budget_cells":5,"correctness_only_drain_cells":1,
        "rule":"Five repeats apply to paired cells; correctness-only qualification is single-process unless amended before results inspection."},
      "workers":[1,4],"fixed_primitive_budgets":list(BUDGETS),
      "primitive_definition":"One bounded source-read, incidence/index, dependency, heap/tree, or reclamation action; a whole-region loop is never one primitive.",
      "arm_scope_policy":{"paired_core":["current-discovery-disabled","stage3a-untouched","stage3a-runtime-sized","stage3b-candidate"],
        "memory":["stage3a-runtime-sized","stage3b-candidate"],"correctness_only":["stage3a-runtime-sized","stage3b-candidate"],
        "intermediate_attribution_fixture_ids":sorted(ATTRIBUTION),"fixed_budget_excludes":["current-discovery-disabled","stage3a-untouched"]},
      "arms":[{**a,**manifest[a["id"]]} for a in ARMS],"fixture_catalogue":fixture_document(),"runs":runs}

def pdigest(plan): return hashlib.sha256(json.dumps(plan,sort_keys=True,separators=(",",":")).encode()).hexdigest()
def validate_plan(p):
    if p.get("schema")!=PLAN_SCHEMA or p.get("version")!=1: raise ValueError("wrong plan schema/version")
    validate_fixtures(p["fixture_catalogue"]["fixtures"])
    if tuple(p["workers"])!=WORKERS or tuple(p["fixed_primitive_budgets"])!=BUDGETS: raise ValueError("worker/budget drift")
    if p["profile"]=="final" and (p["repeat_policy"]["paired_drain_cells"]!=5 or p["repeat_policy"]["fixed_budget_cells"]!=5): raise ValueError("repeat drift")
    if p["execution_authority"].get("status")=="frozen" and not p["execution_authority"].get("authoritative_simulation_material_baseline"): raise ValueError("frozen authority lacks baseline")
    ids=[r["run_id"] for r in p["runs"]]
    if len(ids)!=len(set(ids)) or any(r["order_index"]!=i for i,r in enumerate(p["runs"],1)): raise ValueError("run identity/order drift")

def empty_measurements(): return {g:{m:None for m in ms} for g,ms in MEASUREMENTS.items()}
def result_template(row,state=None):
    state=state or ("unavailable" if row["arm_availability"]!="available" else "success")
    prov={f:None for f in PROVENANCE_FIELDS}
    prov.update({"contract_version":CONTRACT_VERSION,"worker_count":row["worker_count"],"fixture_id":row["fixture_id"],
      "fixture_version":1,"seed":0,"authoritative_mutation_schedule":{"fixture_id":row["fixture_id"],"fixture_version":1},
      "observer_service_schedule":{"mode":row["service_mode"],"primitive_budget":row["primitive_budget"],
       "current_control_is_noop":row["arm_id"]=="current-discovery-disabled"},"arm_id":row["arm_id"],
      "run_order":row["order_index"],"repeat_index":row["repeat_index"]})
    return {"schema":RESULT_SCHEMA,"version":1,"contract_version":CONTRACT_VERSION,"run_id":row["run_id"],"state":state,
      "provenance":prov,"correctness":{"authoritative_equal":None,"tuple_fields_verified":list(TUPLE_FIELDS),
      "observer_read_only":None,"simulation_neutral":None,"details":None},"measurements":empty_measurements(),
      "remote_job_age_service_calls":None,"completion_or_refusal":None,
      "failure":{"kind":None,"message":None,"timeout_seconds":None}}

def validate_result(v,row):
    if v.get("schema")!=RESULT_SCHEMA or v.get("run_id")!=row["run_id"] or v.get("state") not in RESULT_STATES: raise ValueError("result identity/schema/state")
    p=v.get("provenance",{})
    for f in PROVENANCE_FIELDS:
        if f not in p: raise ValueError(f"missing provenance field: {f}")
    for k,e in {"worker_count":row["worker_count"],"fixture_id":row["fixture_id"],"arm_id":row["arm_id"],
                "run_order":row["order_index"],"repeat_index":row["repeat_index"]}.items():
        if p.get(k)!=e: raise ValueError(f"wrong provenance identity: {k}")
    ms=v.get("measurements",{})
    for g,keys in MEASUREMENTS.items():
        if g not in ms or set(keys)-set(ms[g]): raise ValueError(f"missing measurement group/metrics: {g}")
    if not set(TUPLE_FIELDS).issubset(v.get("correctness",{}).get("tuple_fields_verified",[])): raise ValueError("incomplete authoritative tuple comparison")
    if row["arm_id"]=="current-discovery-disabled":
        for g in ("producer_signal","deadline_activity","exact_extraction","index","retirement_dependency","merge_local_fast_path","reconstruction","publication","reclamation"):
            if any(x is not None for x in ms[g].values()): raise ValueError("Current fabricated observer measurements")
    state=v["state"]
    if state in {"success","correctness-failure","refused","timeout","source-failure","failed-world"}:
        for f in ("source_commit","dirty_status","compiler_executable","compiler_version","compiler_sha256","executable_sha256","stdout_identity","stderr_identity","raw_result_identity"):
            if p.get(f) in (None,""): raise ValueError(f"executed result missing provenance identity: {f}")
    if state in {"correctness-failure","refused","timeout","source-failure","failed-world"} and not v["failure"].get("kind"):
        raise ValueError("failure/refusal/timeout must retain explicit failure kind")
    if state=="unavailable" and row["arm_availability"]=="available": raise ValueError("available arm silently unavailable")
    if state=="success" and row["arm_availability"]=="unavailable": raise ValueError("unavailable arm reported success")

def pct(xs,p):
    if not xs:return None
    xs=sorted(xs); return xs[max(0,math.ceil(p*len(xs))-1)]

def numeric_summary(values):
    values=sorted(float(x) for x in values)
    if not values:return None
    n=len(values)
    return {"count":n,"total":sum(values),"min":values[0],"p50":pct(values,.5),
      "p95":pct(values,.95) if n>=20 else None,
      "p99":pct(values,.99) if n>=100 else None,"max":values[-1]}

def metric_summaries(values):
    out={}
    for group,keys in MEASUREMENTS.items():
        reported={}
        for key in keys:
            numbers=[v["measurements"][group][key] for v in values
                     if isinstance(v["measurements"][group][key],(int,float))
                     and not isinstance(v["measurements"][group][key],bool)]
            if numbers: reported[key]=numeric_summary(numbers)
        if reported: out[group]=reported
    return out

def metric_max(values,group,key):
    numbers=[v["measurements"][group][key] for v in values
             if isinstance(v["measurements"][group][key],(int,float))
             and not isinstance(v["measurements"][group][key],bool)]
    return max(numbers) if numbers else None

def reduce_results(plan,results):
    validate_plan(plan); rows={r["run_id"]:r for r in plan["runs"]}; seen=set(); valid=[]
    for value in results:
        rid=value.get("run_id")
        if rid not in rows or rid in seen: raise ValueError("result absent/duplicate in plan")
        validate_result(value,rows[rid]); seen.add(rid); valid.append(value)
    counts={s:sum(value["state"]==s for value in valid) for s in RESULT_STATES}; groups={}
    for value in valid:
        row=rows[value["run_id"]]
        groups.setdefault((row["arm_id"],row["fixture_id"],row["worker_count"],row["service_mode"]),[]).append(value)
    summaries=[]; insufficient=[]
    for key,values in sorted(groups.items()):
        successful=[value for value in values if value["state"]=="success"]
        reasons={}
        for value in values:
            reason=value["measurements"]["reconstruction"]["refusal_reason"]
            if reason not in (None,""): reasons[str(reason)]=reasons.get(str(reason),0)+1
        overflow=[value["measurements"]["producer_signal"]["overflow_refusal_count"] for value in values
                  if isinstance(value["measurements"]["producer_signal"]["overflow_refusal_count"],(int,float))
                  and not isinstance(value["measurements"]["producer_signal"]["overflow_refusal_count"],bool)]
        summaries.append({"arm_id":key[0],"fixture_id":key[1],"worker_count":key[2],"service_mode":key[3],
          "attempted_records":len(values),"successful_records":len(successful),
          "states":{s:sum(value["state"]==s for value in values) for s in RESULT_STATES if any(value["state"]==s for value in values)},
          "successful_numeric_metrics":metric_summaries(successful),
          "high_water_across_all_terminal_records":{
            "producer_queue":metric_max(values,"producer_signal","queue_high_water"),
            "reconstruction_frontier":metric_max(values,"reconstruction","frontier_high_water"),
            "scratch_bytes":metric_max(values,"memory","scratch_high_water_bytes")},
          "refusals":{"terminal_refused":sum(value["state"]=="refused" for value in values),
            "overflow_refusal_counter_total":sum(overflow) if overflow else None,
            "reconstruction_reasons":reasons}})
        required=max(rows[value["run_id"]]["cell_repeat_count"] for value in values)
        if plan["profile"]=="final" and any(rows[value["run_id"]]["arm_availability"]=="available" for value in values) and len(successful)<required:
            insufficient.append({"arm_id":key[0],"fixture_id":key[1],"worker_count":key[2],"service_mode":key[3],
              "successful_records":len(successful),"required":required})
    return {"schema":REPORT_SCHEMA,"version":1,"contract_version":CONTRACT_VERSION,"plan_sha256":pdigest(plan),
      "records_supplied":len(valid),"state_counts":counts,
      "missing_available_run_ids":[row["run_id"] for row in plan["runs"] if row["run_id"] not in seen and row["arm_availability"]=="available"],
      "insufficient_sample_cells":insufficient,"summaries":summaries,
      "provenance_index":[{"run_id":value["run_id"],"state":value["state"],"provenance":value["provenance"]} for value in valid],
      "summary_statistics_policy":{"p50_min_samples":1,"p95_min_samples":20,"p99_min_samples":100,
        "rule":"Percentiles summarize one recorded metric population only; separately reported percentiles are never added."},
      "interpretation":"Correctness failures remain distinct from performance measurements. Unavailable/refused/failed/timeout records are retained. Configured-memory reduction is not treated as algorithmic performance. No candidate-specific winner or universal percent-faster threshold is encoded."}

def synthetic_smoke(commit):
    p=build_plan(commit,"smoke"); validate_plan(p); rs=[]
    for r in p["runs"]:
        state="success" if r["arm_availability"]=="available" else "unavailable"; v=result_template(r,state)
        if state=="success":
            v["provenance"].update({"source_commit":commit,"dirty_status":"clean","source_input_hashes":{"synthetic":"smoke"},
              "compiler_executable":"synthetic","compiler_version":"synthetic","compiler_sha256":"synthetic","flags":[],
              "executable_sha256":"synthetic","capacities":{},"hardware":{"synthetic":True},"os":"synthetic",
              "power_mode":"synthetic","stdout_identity":"synthetic","stderr_identity":"synthetic","raw_result_identity":r["run_id"]})
            v["correctness"].update({"authoritative_equal":True,"observer_read_only":True,"simulation_neutral":True,
              "details":"synthetic parser/reducer smoke; excluded from acceptance statistics"})
            v["measurements"]["end_to_end"]["total_ms"]=1.0; v["measurements"]["memory"]["process_rss_bytes"]=1
            v["completion_or_refusal"]="completed"
        else:
            v["provenance"].update({"source_input_hashes":{},"flags":[],"capacities":{},"hardware":{},"raw_result_identity":f"unavailable:{r['arm_id']}"})
            v["completion_or_refusal"]="arm unavailable in smoke"
        validate_result(v,r); rs.append(v)
    return p,rs,reduce_results(p,rs)

def load(p): return json.loads(Path(p).read_text())
def write(p,v): Path(p).write_text(json.dumps(v,indent=2,sort_keys=True)+"\n")
def main():
    ap=argparse.ArgumentParser(); sp=ap.add_subparsers(dest="cmd",required=True)
    q=sp.add_parser("fixtures"); q.add_argument("--output",required=True)
    q=sp.add_parser("generate-plan"); q.add_argument("--apparatus-source-commit",required=True); q.add_argument("--profile",choices=("final","smoke"),default="final"); q.add_argument("--arm-manifest"); q.add_argument("--execution-authority"); q.add_argument("--output",required=True)
    q=sp.add_parser("validate-plan"); q.add_argument("plan")
    q=sp.add_parser("synthetic-smoke"); q.add_argument("--apparatus-source-commit",required=True); q.add_argument("--output",required=True)
    q=sp.add_parser("reduce"); q.add_argument("--plan",required=True); q.add_argument("--results",required=True); q.add_argument("--output",required=True)
    a=ap.parse_args()
    if a.cmd=="fixtures": write(a.output,fixture_document())
    elif a.cmd=="generate-plan": write(a.output,build_plan(a.apparatus_source_commit,a.profile,load(a.arm_manifest) if a.arm_manifest else None,load(a.execution_authority) if a.execution_authority else None))
    elif a.cmd=="validate-plan": validate_plan(load(a.plan))
    elif a.cmd=="synthetic-smoke":
        p,r,rep=synthetic_smoke(a.apparatus_source_commit); write(a.output,{"plan":p,"results":r,"report":rep})
    else: write(a.output,reduce_results(load(a.plan),load(a.results)))
if __name__=="__main__": main()
