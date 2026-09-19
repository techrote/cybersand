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
 "quiet_phases":("initial_construction_ms","registration_ms","first_exact_capture_classification_ms",
  "first_region_publication_ms","steady_quiet_drain_ms"),
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
  "service_call_latency_ms","service_call_latency_sample_count","service_call_latency_p50_ms","service_call_latency_p95_ms","service_call_latency_p99_ms",
  "service_call_latency_max_ms","owner_tick_plus_observer_ms","owner_tick_plus_observer_sample_count","owner_tick_plus_observer_p50_ms",
  "owner_tick_plus_observer_p95_ms","owner_tick_plus_observer_p99_ms","owner_tick_plus_observer_max_ms",
  "throughput_per_second","total_ms"),
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
    topology_classes={
      "one-cell-bridge-add":"additive-bridge-merge",
      "one-cell-bridge-remove":"reconstruction-required-deletion",
      "alternate-path-nonsplit":"local-topology-preserving",
      "genuine-large-split":"reconstruction-required-deletion",
      "many-child-split":"reconstruction-required-deletion",
      "topology-preserving-interior-hole":"local-topology-preserving",
      "changed-port-partition":"changed-port-partition",
    }
    for n in topo:
        kw={"topology_class":topology_classes.get(n,"structural-control")}
        if n in one: kw.update({"intended_changed_cell_count":1,"mutation":{"selector":"canonical-topology-coordinate","field":"material","authoritative_cells_changed":1}})
        out.append(fixture(f"topology.{n}","connectivity-topology",n,**kw))
    for n in ("absent-location","absent-to-resident-registration","registered-unknown","unknown-to-ready-matching",
              "unknown-to-ready-nonmatching","unknown-to-canonical-empty","resident-untracked","excluded","re-entry",
              "capacity-refused","failed-read-world","new-facing-coverage-before-payload-ready"):
        out.append(fixture(f"coverage.{n}","coverage-absence-registration",n,expected_outcomes=["success","refused","source-failure","failed-world"],
          invariant="A dictionary miss alone never proves global completeness."))
    for n in ("future-deadline-insertion","earlier-replacement","cancellation","consumption","equal-deadline-ordering",
              "excluded-overdue-deadline","re-entry","no-write-keep-active","sleep-wake-transition","many-deadline-changes-no-payload-writes"):
        out.append(fixture(f"deadline.{n}","activity-deadline-no-write",n,
          invariant="A future nonzero deadline is not quiet before due." if n=="future-deadline-insertion" else "Deadline/activity state follows exact owner signals."))
    for n in ("direct-tuple-A-B-A","mask-set-clear","mask-reconfiguration","overlapping-event-acceptance-drain",
              "inclusion-requested-applied-ABA","same-barrier-restore","worker-effect-rectangle-fanout","event-dependency-halo-fanout"):
        out.append(fixture(f"aba.{n}","aba-fanout",n,
          expected_outcomes=["success","not-applicable"] if n=="same-barrier-restore" else ["success"],
          invariant="Monotonic witness state must survive restore-to-original final values."))
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
        outcomes=["refused"] if n=="allocation-failure-observer-replacement" else ["refused","source-failure","failed-world"]
        out.append(fixture(f"failure.{n}","capacity-failure",n,expected_outcomes=outcomes))
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
    return attach_protocols(out)

BASE_TUPLE={"material":"Wall","state_a":0,"state_b":0,"temperature":200,"occupied":False}
EMPTY_TUPLE={"material":"Empty","state_a":0,"state_b":0,"temperature":200,"occupied":False}
ONE_CELL_COORDS={"tile-interior":[16,16],"tile-face":[31,16],"tile-corner":[31,31],
                 "chunk-activity-boundary":[32,16]}
FIELD_TARGETS={
 "material":{**BASE_TUPLE,"material":"RedBrick"},
 "state_a":{**BASE_TUPLE,"state_a":1},
 "state_b":{**BASE_TUPLE,"state_b":1},
 "temperature":{**BASE_TUPLE,"temperature":210},
 "occupied_material":{**BASE_TUPLE,"occupied":True},
 "canonical_empty":EMPTY_TUPLE,
 "noncanonical_empty":{**EMPTY_TUPLE,"state_a":1},
 "negative_temperature":{**BASE_TUPLE,"temperature":-40},
}
TOPOLOGY_PROTOCOLS={
 "large-solid-connected-region":{"generator":"solid-rect","params":{"rect":[0,0,128,128]},"mutations":[]},
 "ring":{"generator":"rect-ring","params":{"outer":[0,0,65,65],"thickness":1},"mutations":[]},
 "comb-maze":{"generator":"comb","params":{"origin":[0,0],"width":96,"height":64,"spine_y":32,"tooth_stride":4,"tooth_length":31,"alternating":True},"mutations":[]},
 "holes":{"generator":"solid-rect-with-holes","params":{"rect":[0,0,96,96],"holes":[[24,24,8,8],[64,24,8,8],[24,64,8,8],[64,64,8,8]]},"mutations":[]},
 "checkerboard-component-pressure":{"generator":"checkerboard","params":{"rect":[0,0,32,32],"solid_on_even_parity":True},"mutations":[]},
 "one-cell-bridge-add":{"generator":"two-lobes-gap","params":{"left":[0,0,32,32],"right":[33,0,32,32]},"mutations":[{"step":1,"op":"set-tuple","at":[32,16],"tuple":BASE_TUPLE}]},
 "one-cell-bridge-remove":{"generator":"two-lobes-one-cell-neck","params":{"left":[0,0,32,32],"right":[33,0,32,32],"neck":[32,16]},"mutations":[{"step":1,"op":"set-tuple","at":[32,16],"tuple":EMPTY_TUPLE}]},
 "alternate-path-nonsplit":{"generator":"rect-ring","params":{"outer":[0,0,65,65],"thickness":1},"mutations":[{"step":1,"op":"set-tuple","at":[32,0],"tuple":EMPTY_TUPLE}]},
 "genuine-large-split":{"generator":"two-lobes-one-cell-neck","params":{"left":[0,0,64,64],"right":[65,0,64,64],"neck":[64,32]},"mutations":[{"step":1,"op":"set-tuple","at":[64,32],"tuple":EMPTY_TUPLE}]},
 "many-child-split":{"generator":"four-arms-one-cell-hub","params":{"hub":[32,32],"arm_length":31,"arm_width":1},"mutations":[{"step":1,"op":"set-tuple","at":[32,32],"tuple":EMPTY_TUPLE}]},
 "topology-preserving-interior-hole":{"generator":"solid-rect","params":{"rect":[0,0,64,64]},"mutations":[{"step":1,"op":"set-tuple","at":[32,32],"tuple":EMPTY_TUPLE}]},
 "changed-port-partition":{"generator":"port-partition-bridge","params":{"tile":[0,0,32,32],"ports":["west","east","north"],"bridge":[16,16]},"mutations":[{"step":1,"op":"set-tuple","at":[16,16],"tuple":EMPTY_TUPLE}]},
}
COVERAGE_OPERATIONS={
 "absent-location":[{"step":1,"op":"query","at":[0,0]}],
 "absent-to-resident-registration":[{"step":1,"op":"query","at":[0,0]},{"step":2,"op":"register-resident","rect":[0,0,32,32]}],
 "registered-unknown":[{"step":1,"op":"register-unknown","key":"A","rect":[0,0,32,32],"revision":1}],
 "unknown-to-ready-matching":[{"step":1,"op":"register-unknown","key":"A","rect":[0,0,32,32],"revision":1},{"step":2,"op":"publish-ready","key":"A","tuple":BASE_TUPLE,"revision":1}],
 "unknown-to-ready-nonmatching":[{"step":1,"op":"register-unknown","key":"A","rect":[0,0,32,32],"revision":1},{"step":2,"op":"publish-ready","key":"A","tuple":FIELD_TARGETS["state_a"],"revision":1}],
 "unknown-to-canonical-empty":[{"step":1,"op":"register-unknown","key":"A","rect":[0,0,32,32],"revision":1},{"step":2,"op":"publish-ready","key":"A","tuple":EMPTY_TUPLE,"revision":1}],
 "resident-untracked":[{"step":1,"op":"register-resident-untracked","rect":[0,0,32,32]}],
 "excluded":[{"step":1,"op":"exclude","rect":[0,0,32,32]}],
 "re-entry":[{"step":1,"op":"exclude","rect":[0,0,32,32]},{"step":2,"op":"reenter","rect":[0,0,32,32]}],
 "capacity-refused":[{"step":1,"op":"fill-capacity","class":"coverage","count":64},{"step":2,"op":"register-resident","rect":[2048,0,32,32]}],
 "failed-read-world":[{"step":1,"op":"inject-source-read-failure","at":[0,0]},{"step":2,"op":"capture","rect":[0,0,32,32]}],
 "new-facing-coverage-before-payload-ready":[{"step":1,"op":"publish-ready","key":"A","tuple":BASE_TUPLE,"revision":1},{"step":2,"op":"register-unknown","key":"B","rect":[32,0,32,32],"revision":1},{"step":3,"op":"observe-before-ready","key":"B"}],
}
DEADLINE_OPERATIONS={
 "future-deadline-insertion":[{"step":1,"op":"set-deadline","key":"A","tick":100},{"step":2,"op":"service-at-tick","tick":99},{"step":3,"op":"service-at-tick","tick":100}],
 "earlier-replacement":[{"step":1,"op":"set-deadline","key":"A","tick":100},{"step":2,"op":"set-deadline","key":"A","tick":50},{"step":3,"op":"service-at-tick","tick":50}],
 "cancellation":[{"step":1,"op":"set-deadline","key":"A","tick":100},{"step":2,"op":"cancel-deadline","key":"A"}],
 "consumption":[{"step":1,"op":"set-deadline","key":"A","tick":10},{"step":2,"op":"service-at-tick","tick":10},{"step":3,"op":"consume-deadline","key":"A"}],
 "equal-deadline-ordering":[{"step":1,"op":"set-deadline","key":"B","tick":100},{"step":2,"op":"set-deadline","key":"A","tick":100},{"step":3,"op":"service-at-tick","tick":100}],
 "excluded-overdue-deadline":[{"step":1,"op":"set-deadline","key":"A","tick":10},{"step":2,"op":"exclude","key":"A"},{"step":3,"op":"service-at-tick","tick":11}],
 "re-entry":[{"step":1,"op":"set-deadline","key":"A","tick":10},{"step":2,"op":"exclude","key":"A"},{"step":3,"op":"reenter","key":"A"},{"step":4,"op":"service-at-tick","tick":11}],
 "no-write-keep-active":[{"step":1,"op":"signal-keep-active","key":"A","writes":0},{"step":2,"op":"owner-tick","count":8}],
 "sleep-wake-transition":[{"step":1,"op":"owner-tick-until-sleep","key":"A"},{"step":2,"op":"wake","key":"A"},{"step":3,"op":"owner-tick","count":1}],
 "many-deadline-changes-no-payload-writes":[{"step":1,"op":"replace-deadline-sequence","key":"A","ticks":[128,96,112,64,80,48,32,16],"payload_writes":0}],
}
ABA_OPERATIONS={
 "direct-tuple-A-B-A":[{"step":1,"op":"set-tuple","at":[16,16],"tuple":FIELD_TARGETS["state_a"]},{"step":2,"op":"set-tuple","at":[16,16],"tuple":BASE_TUPLE}],
 "mask-set-clear":[{"step":1,"op":"mask-set","rect":[12,12,8,8]},{"step":2,"op":"mask-clear","rect":[12,12,8,8]}],
 "mask-reconfiguration":[{"step":1,"op":"mask-set","rect":[12,12,8,8]},{"step":2,"op":"mask-set","rect":[16,12,8,8]}],
 "overlapping-event-acceptance-drain":[{"step":1,"op":"queue-event","id":"E1","center":[16,16],"radius":2},{"step":2,"op":"queue-event","id":"E2","center":[17,16],"radius":2},{"step":3,"op":"drain-events"}],
 "inclusion-requested-applied-ABA":[{"step":1,"op":"request-inclusion","rect":[0,0,32,32],"included":False},{"step":2,"op":"apply-inclusion"},{"step":3,"op":"request-inclusion","rect":[0,0,32,32],"included":True},{"step":4,"op":"apply-inclusion"}],
 "same-barrier-restore":[{"step":1,"op":"worker-write","at":[16,16],"tuple":FIELD_TARGETS["state_b"],"barrier":1},{"step":2,"op":"worker-write","at":[16,16],"tuple":BASE_TUPLE,"barrier":1}],
 "worker-effect-rectangle-fanout":[{"step":1,"op":"worker-effect-rect","rect":[8,8,16,16]}],
 "event-dependency-halo-fanout":[{"step":1,"op":"queue-event","id":"E1","center":[16,16],"radius":2,"maximum_rule_radius":1,"effect_footprint_extra":2,"pending_observation_half_extent":5}],
}

def fixture_protocol(item):
    family=item["family"]; fid=item["id"]; suffix=fid.split(".",1)[1] if "." in fid else fid
    base={"schema":"cybersand.stage3b.fixture-protocol/v1","coordinate_model":{"origin":[0,0],"tile_size":32,"chunk_size":32},
          "service_checkpoints":["after-setup","after-each-operation","final"]}
    if family=="quiet-initial-population":
        if suffix.startswith("initial-"):
            setup={"generator":"uniform-square","side":int(suffix.rsplit("-",1)[1]),"tuple":BASE_TUPLE}
        elif suffix=="sparse-represented-coverage":
            setup={"generator":"uniform-authority-sparse-coverage","authority_side":2048,"tile_size":32,
                   "represented_tile_coords":[[0,0],[63,0],[0,63],[63,63],[32,32]],"tuple":BASE_TUPLE}
        else:
            setup={"generator":"large-capacity-small-coverage","configured_tile_capacity":4096,
                   "represented_tile_rect":[0,0,8,8],"tuple":BASE_TUPLE}
        return {**base,"setup":setup,"operations":[],"assertions":["separate cold/startup phases from steady quiet drain"]}
    if family=="genuine-one-cell-edit":
        _,field,position=fid.split(".",2)
        return {**base,"setup":{"generator":"uniform-square","side":64,"tuple":BASE_TUPLE},
          "operations":[{"step":1,"op":"set-tuple","at":ONE_CELL_COORDS[position],"tuple":FIELD_TARGETS[field],"authoritative_cells_changed":1}],
          "assertions":["exactly one authoritative cell changes"]}
    if family=="retained-historical-control":
        protocols={
          "local-edit-8x8":{"setup":{"generator":"uniform-square","side":64,"tuple":BASE_TUPLE},"operations":[{"step":1,"op":"toggle-rect","rect":[28,28,8,8],"iterations":64,"every_iterations":16,"first_tuple":EMPTY_TUPLE,"second_tuple":BASE_TUPLE}]},
          "bridge-whole-column":{"setup":{"generator":"uniform-square","side":64,"tuple":BASE_TUPLE},"operations":[{"step":1,"op":"toggle-column","x":32,"y0":0,"length":64,"iterations":64,"every_iterations":1,"first_tuple":EMPTY_TUPLE,"second_tuple":BASE_TUPLE}]},
          "churn":{"setup":{"generator":"uniform-square","side":64,"tuple":BASE_TUPLE},"operations":[{"step":1,"op":"toggle-rect","rect":[16,16,32,32],"iterations":64,"every_iterations":1,"first_tuple":EMPTY_TUPLE,"second_tuple":BASE_TUPLE}]},
          "ring":{"setup":{"generator":"predicate-square","side":64,"tuple":BASE_TUPLE,"solid_predicate":"x==0 || y==0 || x==63 || y==63 || x==32 || y==32"},"operations":[]},
          "mask":{"setup":{"generator":"uniform-square","side":64,"tuple":BASE_TUPLE},"operations":[{"step":1,"op":"toggle-transient-obstacle-mask","rect":[28,28,8,8],"body_id":1,"iterations":64,"set_on_even_iterations":True}]},
          "pending-event":{"setup":{"generator":"uniform-square","side":64,"tuple":BASE_TUPLE},"operations":[{"step":1,"op":"queue-explosion","center":[32,32],"radius":2,"collapse_strength":0,"iterations":64,"every_iterations":8}]},
          "exclusion":{"setup":{"generator":"uniform-square","side":64,"tuple":BASE_TUPLE},"operations":[{"step":1,"op":"toggle-simulation-region","excluded_rect":[128,0,64,64],"iterations":64,"exclude_on_even_iterations":True}]},
        }
        return {**base,**protocols[suffix],"assertions":["retain historical meaning exactly"]}
    if family=="connectivity-topology":
        p=TOPOLOGY_PROTOCOLS[suffix]
        return {**base,"setup":{"generator":p["generator"],**p["params"]},"operations":p["mutations"],
          "assertions":["classify update as "+item["topology_class"]]}
    if family=="coverage-absence-registration":
        return {**base,"setup":{"generator":"coverage-control","rect":[0,0,64,64],"tuple":BASE_TUPLE},
          "operations":COVERAGE_OPERATIONS[suffix],"assertions":[item["invariant"]]}
    if family=="activity-deadline-no-write":
        return {**base,"setup":{"generator":"single-ready-domain","key":"A","rect":[0,0,32,32],"tuple":BASE_TUPLE},
          "operations":DEADLINE_OPERATIONS[suffix],"assertions":[item["invariant"]]}
    if family=="aba-fanout":
        assertions=[item["invariant"]]
        if suffix=="event-dependency-halo-fanout":
            assertions += ["event effect reach is radius + 2",
              "pending observation half-extent is (radius + 2) + maximum_rule_radius"]
        return {**base,"setup":{"generator":"uniform-square","side":64,"tuple":BASE_TUPLE},
          "operations":ABA_OPERATIONS[suffix],"assertions":assertions}
    if family=="progress-churn-fairness":
        cadence={"churn-every-1-service-call":1,"churn-every-2-service-calls":2,"churn-every-8-service-calls":8}.get(suffix)
        ops=[{"step":1,"op":"configure-localities","churning":[0,0],"stable_near":[64,0],"stable_far":[1024,1024],"rounds":64}]
        if cadence: ops.append({"step":2,"op":"churn","at":[0,0],"every_service_calls":cadence,"rounds":64})
        elif suffix=="continuous-local-churn": ops.append({"step":2,"op":"churn","at":[0,0],"every_service_calls":1,"rounds":64})
        elif suffix=="independent-pending-domains": ops.append({"step":2,"op":"queue-domains","coords":[[0,0],[64,0],[0,64],[1024,1024]]})
        elif suffix=="continuous-lower-coordinate-arrival": ops.append({"step":2,"op":"inject-lower-coordinate-work","start":[0,0],"delta":[-32,0],"rounds":64})
        elif suffix=="stale-work-before-validation": ops += [{"step":2,"op":"advance-to-validation-minus-one","at":[1024,1024]},{"step":3,"op":"mutate","at":[1024,1024]}]
        elif suffix=="recovery-after-churn-stops": ops += [{"step":2,"op":"churn","at":[0,0],"every_service_calls":1,"rounds":32},{"step":3,"op":"stop-churn-and-drain"}]
        elif suffix=="cleanup-reclamation-near-capacity": ops.append({"step":2,"op":"retire-and-replace","domain_count":63,"configured_capacity":64})
        else: ops.append({"step":2,"op":"service-unmodified-control","target":suffix,"rounds":64})
        return {**base,"setup":{"generator":"three-locality-fairness-control","tuple":BASE_TUPLE},"operations":ops,
          "assertions":["record remote job age and completion/refusal outcome"]}
    if family=="capacity-failure":
        if fid.startswith("capacity."):
            _,klass,boundary=fid.split(".",2); limit=64
            count=limit if boundary=="exact-cap" else limit+1
            return {**base,"setup":{"generator":"capacity-boundary","capacity_class":klass,"limit":limit},
              "operations":[{"step":1,"op":"populate-capacity-class","class":klass,"count":count}],
              "assertions":["one-past-cap refusal is explicit and never a missing result"]}
        fault=suffix
        fault_ops={
          "allocation-failure-construction":{"phase":"construction","allocation_ordinal":1},
          "allocation-failure-observer-replacement":{"phase":"observer-replacement","allocation_ordinal":1},
          "capacity-failure-staging":{"phase":"staging","capacity_ordinal":1},
          "failure-after-partial-preparation":{"phase":"publication-preparation","after_successful_primitives":3},
          "source-capture-failure":{"phase":"source-capture","read_ordinal":1},
          "failed-world-quarantine":{"phase":"world","failure":"quarantine"},
        }
        if fault=="allocation-failure-observer-replacement":
            return {**base,"setup":{"generator":"fault-injection-control","tuple":BASE_TUPLE},
              "operations":[{"step":1,"op":"establish-live-observation"},
                {"step":2,"op":"inject-fault",**fault_ops[fault]},
                {"step":3,"op":"clear-authority-and-replace-observer"},
                {"step":4,"op":"attempt-observation"},
                {"step":5,"op":"clear-authority-and-replace-observer","fault_injection":"none"},
                {"step":6,"op":"attempt-observation"}],
              "assertions":["retire the old observer before destructive reset and replacement construction",
                "replacement construction failure leaves discovery unavailable and World not failed",
                "later successful clear constructs a fresh observer incarnation; no stale handle revives"]}
        return {**base,"setup":{"generator":"fault-injection-control","tuple":BASE_TUPLE},
          "operations":[{"step":1,"op":"inject-fault",**fault_ops[fault]},{"step":2,"op":"attempt-observation"}],
          "assertions":["failure/refusal is explicit and partial publication is forbidden"]}
    if family=="determinism-permutation":
        variants={
          "forward-reverse-registration":[["A","B","C"],["C","B","A"]],
          "successful-free-slot-order":[["alloc-A","alloc-B","free-A","alloc-C"],["alloc-B","alloc-A","free-B","alloc-C"]],
          "allocation-order":[["A","B","C"],["B","C","A"]],
          "equal-deadline-ties":[["A@100","B@100","C@100"],["C@100","A@100","B@100"]],
          "translated-signed-geometry":[["origin",0,0],["origin",-257,1]],
          "adversarial-hash-keys":[["key",0,0],["key",65536,0],["key",131072,0]],
          "scarce-publication-capacity-competition":[["capacity",2,"candidates","A","B","C"],["capacity",2,"candidates","C","B","A"]],
        }
        return {**base,"setup":{"generator":"determinism-control","tuple":BASE_TUPLE},
          "operations":[{"step":1,"op":"run-permutations","variants":variants[suffix]}],
          "assertions":["canonical admission/output must be permutation-independent"]}
    if family=="memory":
        axis=item["parameters"]["sweep_axis"]; value=item["parameters"]["value"]
        return {**base,"setup":{"generator":"memory-axis-control","axis":axis,"value":value,"other_axes":"baseline"},
          "operations":[{"step":1,"op":"populate-axis","axis":axis,"value":value},{"step":2,"op":"drain-and-record-memory"}],
          "assertions":["requested/layout/committed/live/staged/retired/scratch/RSS remain distinct"]}
    raise ValueError("fixture family lacks frozen protocol: "+family)

def attach_protocols(fixtures):
    for item in fixtures:
        protocol=fixture_protocol(item)
        item["protocol"]=protocol
        item["protocol_sha256"]=hashlib.sha256(json.dumps(protocol,sort_keys=True,separators=(",",":")).encode()).hexdigest()
    return fixtures

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
    for f in fs:
        protocol=f.get("protocol"); expected=f.get("protocol_sha256")
        actual=hashlib.sha256(json.dumps(protocol,sort_keys=True,separators=(",",":")).encode()).hexdigest() if protocol else None
        if not protocol or expected!=actual: raise ValueError("fixture protocol identity drift: "+f["id"])
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
                  "fixture_version":1,"fixture_protocol_sha256":f["protocol_sha256"],"fixture_expected_outcomes":f["expected_outcomes"],"worker_count":w,"service_mode":svc["id"],"primitive_budget":svc["budget"],"seed":0})
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
      "determinism_contract":["worker finish order","allocator address","tree rotation","unordered iteration","free-slot order","registration order","equal-deadline ties"],
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
      "fixture_version":1,"seed":0,"authoritative_mutation_schedule":{"fixture_id":row["fixture_id"],"fixture_version":1,"protocol_sha256":row["fixture_protocol_sha256"]},
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
    if p.get("authoritative_mutation_schedule",{}).get("protocol_sha256")!=row.get("fixture_protocol_sha256"): raise ValueError("fixture protocol provenance mismatch")
    ms=v.get("measurements",{})
    for g,keys in MEASUREMENTS.items():
        if g not in ms or set(keys)-set(ms[g]): raise ValueError(f"missing measurement group/metrics: {g}")
    if not set(TUPLE_FIELDS).issubset(v.get("correctness",{}).get("tuple_fields_verified",[])): raise ValueError("incomplete authoritative tuple comparison")
    if row["arm_id"]=="current-discovery-disabled":
        for g in ("quiet_phases","producer_signal","deadline_activity","exact_extraction","index","retirement_dependency","merge_local_fast_path","reconstruction","publication","reclamation"):
            if any(x is not None for x in ms[g].values()): raise ValueError("Current fabricated observer measurements")
    state=v["state"]
    if state in {"success","correctness-failure","refused","timeout","source-failure","failed-world"}:
        for f in ("source_commit","dirty_status","compiler_executable","compiler_version","compiler_sha256","executable_sha256","stdout_identity","stderr_identity","raw_result_identity"):
            if p.get(f) in (None,""): raise ValueError(f"executed result missing provenance identity: {f}")
    if state in {"correctness-failure","refused","timeout","source-failure","failed-world","not-applicable"} and not v["failure"].get("kind"):
        raise ValueError("failure/refusal/timeout must retain explicit failure kind")
    for prefix in ("service_call_latency","owner_tick_plus_observer"):
        sample_count=ms["end_to_end"][prefix+"_sample_count"]
        if ms["end_to_end"][prefix+"_p95_ms"] is not None and (not isinstance(sample_count,int) or sample_count<20):
            raise ValueError(prefix+" p95 requires at least 20 samples")
        if ms["end_to_end"][prefix+"_p99_ms"] is not None and (not isinstance(sample_count,int) or sample_count<100):
            raise ValueError(prefix+" p99 requires at least 100 samples")
    if state=="not-applicable" and "not-applicable" not in row.get("fixture_expected_outcomes",[]): raise ValueError("fixture does not permit not-applicable")
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
