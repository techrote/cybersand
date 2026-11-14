#!/usr/bin/env python3
"""Stage identical test-only full-size Godot owner observations.

Works on the accepted baseline Godot application for BOTH C2048 native binaries.
No publication, save, native physics, frame pacing, source authority or runtime
provenance is altered. Result is a separate observable async experiment.
"""
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path

FIELDS = (
    "gas_nanoseconds","head_nanoseconds","preparation_nanoseconds",
    "pf_probe_gas_process_cpu_ns","pf_probe_gas_owner_cpu_ns",
    "pf_probe_head_process_cpu_ns","pf_probe_discovery_process_cpu_ns",
    "pf_probe_identity_process_cpu_ns","pf_probe_relabel_process_cpu_ns",
    "gas_seed_cells","gas_seed_probes","gas_bfs_cells","gas_bfs_probes",
    "gas_relabel_cells","gas_reference_passes","gas_reuses",
    "gas_component_reuses","gas_restart_fallbacks","gas_capacity_fallbacks",
    "gas_budget_fallbacks","gas_cache_builds","gas_identity_nodes",
    "water_material_calls","water_motion_calls",
)

def patched_once(text: str, before: str, after: str, name: str) -> str:
    count=text.count(before)
    if count!=1:
        raise RuntimeError(f"Test-only patch expected one {name} anchor, found {count}")
    return text.replace(before,after,1)

def digest(b:bytes)->str:return hashlib.sha256(b).hexdigest()

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--app",required=True)
    p.add_argument("--out",required=True)
    a=p.parse_args()
    root=Path(a.app)
    changed={}
    worker_path="godot/scripts/simulation_worker.gd"
    worker=(root/worker_path).read_bytes()
    text=worker.decode("utf-8")
    vars_insertion = """var _pf_full_checkpoint_world_generation: int = -1
var _pf_full_checkpoint_tick: int = -1
var _pf_full_checkpoints: Array[Dictionary] = []

"""
    text=patched_once(text,"var _pending_render_worker_step_time_ms: float = 0.0\n",
       vars_insertion+"var _pending_render_worker_step_time_ms: float = 0.0\n",worker_path)
    insertion = """\tif OS.get_environment("CYBERSAND_PF_FULL_PROFILE") == "1" and _workbench_extent != Vector2i.ZERO and _world.has_method(&"inspect_pressure_optimization"):
\t\tvar pf_profile_tick: int = int(_world.tick_index)
\t\tif _pf_full_checkpoint_world_generation != _world_generation:
\t\t\t_pf_full_checkpoints.clear()
\t\t\t_pf_full_checkpoint_tick = -1
\t\t\t_pf_full_checkpoint_world_generation = _world_generation
\t\t# Exactly periodic native completed-tick samples, all on the exclusive owner.
\t\t# This does not modify simulation, input, ownership or renderer timing decisions.
\t\tif pf_profile_tick > 0 and pf_profile_tick % 48 == 0 and pf_profile_tick > _pf_full_checkpoint_tick:
\t\t\t_pf_full_checkpoint_tick = pf_profile_tick
\t\t\tvar pf_q: Dictionary = _world.get_pressure_flow_ledger()
\t\t\tvar pf_g: Dictionary = _world.inspect_gas_compartments()
\t\t\tvar pf_spray: Dictionary = _world.get_water_spray()
\t\t\t_pf_full_checkpoints.append({
\t\t\t\t"tick":pf_profile_tick,
\t\t\t\t"physical_hash":str(_world.get_physical_state_hash()),
\t\t\t\t"hash_version":int(_world.get_physical_state_hash_version()),
\t\t\t\t"water_quantity":pf_q.get("pf_probe_quantity",{}).duplicate(true),
\t\t\t\t"gas_ledger":pf_g.get("ledger",{}).duplicate(true),
\t\t\t\t"gas_capacity":int(pf_g.get("compartment_capacity",0)),
\t\t\t\t"gas_compartments":(pf_g.get("compartments",[]) as Array).size(),
\t\t\t\t"ballistic_water":pf_spray.get("water",{}).duplicate(true),
\t\t\t\t"worker_sample":snapshot.native_worker_participation.duplicate(true),
\t\t\t})
\t\t\tif _pf_full_checkpoints.size() > 14:
\t\t\t\t_pf_full_checkpoints.pop_front()
\t\tvar pf_observation: Dictionary = _world.inspect_pressure_optimization()
\t\tvar pf_raw: Dictionary = pf_observation.get("counters",{})
\t\tvar pf_counts: Dictionary = {}
"""
    for f in FIELDS:
        insertion+=f'\t\tpf_counts["{f}"] = str(pf_raw.get("{f}",""))\n'
    insertion+="""\t\tsnapshot.lab_context["pf_full_profile"] = {
\t\t\t"tick":pf_profile_tick,
\t\t\t"native_generation":_world_generation,
\t\t\t"counters":pf_counts,
\t\t\t"gas_status":str(pf_observation.get("status","")),
\t\t\t"gas_pending":bool(pf_observation.get("gas_pending",false)),
\t\t\t"native_worker_participation":snapshot.native_worker_participation.duplicate(true),
\t\t\t"checkpoints":_pf_full_checkpoints.duplicate(true),
\t\t}
"""
    text=patched_once(text,"\t}\n\tif _workbench_extent != Vector2i.ZERO:\n",
                      "\t}\n"+insertion+"\tif _workbench_extent != Vector2i.ZERO:\n",worker_path)
    (root/worker_path).write_bytes(text.encode("utf-8"))
    changed[worker_path]={"original_sha256":digest(worker),
                          "instrumented_sha256":digest(text.encode("utf-8"))}
    fixture_path="godot/tests/pf504_stress_canvas_actual_workbench.gd"
    raw=(root/fixture_path).read_bytes()
    fixture=raw.decode("utf-8")
    fixture=patched_once(fixture,
        "\tvar wall_started_us: int = Time.get_ticks_usec()\n",
        """\tvar pf_observation_first: Dictionary = {}
\tvar pf_observation_last: Dictionary = {}
\tvar pf_worker_samples: Array[Dictionary] = []
\tvar pf_last_worker_sample_tick: int = -1
\tvar pf_checkpoints: Array[Dictionary] = []
\tvar pf_checkpoint_seen: Dictionary = {}
\tvar wall_started_us: int = Time.get_ticks_usec()
""",fixture_path)
    fixture=patched_once(fixture,
        "\tif not _require(panel.toggle_pause(), \"failed to start actual workbench play\"):\n",
        """\t# Explicit opt-in to native *observed* task participation, not config-only intent.
\tmain.simulation_worker.set_worker_participation_sampling(true)
\tif not _require(panel.toggle_pause(), "failed to start actual workbench play"):
""",fixture_path)
    fixture=patched_once(fixture,
        "\t\tobserved_snapshots += 1\n",
        """\t\tobserved_snapshots += 1
\t\tvar pf_this: Dictionary = snapshot.lab_context.get("pf_full_profile",{})
\t\tif not pf_this.is_empty():
\t\t\tif pf_observation_first.is_empty(): pf_observation_first = pf_this.duplicate(true)
\t\t\tpf_observation_last = pf_this.duplicate(true)
\t\t\tvar part: Dictionary = pf_this.get("native_worker_participation",{})
\t\t\tvar part_tick: int = int(part.get("completed_tick",-1))
\t\t\tif part_tick > pf_last_worker_sample_tick and part.has("workers_observed"):
\t\t\t\tpf_last_worker_sample_tick = part_tick
\t\t\t\tpf_worker_samples.append(part.duplicate(true))
\t\t\tfor checkpoint: Dictionary in pf_this.get("checkpoints",[]):
\t\t\t\tvar c_tick: int = int(checkpoint.get("tick",-1))
\t\t\t\tif c_tick >= from_tick + WARMUP_TICKS and c_tick <= after_tick and not pf_checkpoint_seen.has(c_tick):
\t\t\t\t\tpf_checkpoint_seen[c_tick] = true
\t\t\t\t\tpf_checkpoints.append(checkpoint.duplicate(true))
""",fixture_path)
    fixture=patched_once(fixture,
        '\t\t"packet": _percentiles(packet),\n',
        """\t\t"pf_full_profile": {
\t\t\t"begin":pf_observation_first,
\t\t\t"end":pf_observation_last,
\t\t\t"worker_participation":pf_worker_samples,
\t\t\t"checkpoints":pf_checkpoints,
\t\t},
\t\t"packet": _percentiles(packet),
""",fixture_path)
    fixture=patched_once(fixture,
        '\tvar ok: bool = true\n',
        """\tvar ok: bool = true
\tok = _require(not pf_observation_first.is_empty() and not pf_observation_last.is_empty(),
\t\t"native stage CPU readback absent") and ok
\tok = _require(pf_worker_samples.size() >= 2,
\t\t"actual native task-participant observations absent") and ok
\tok = _require(pf_checkpoints.size() >= 3,
\t\t"completed native physical hash/quantity checkpoints absent") and ok
\tfor checkpoint: Dictionary in pf_checkpoints:
\t\tvar quantity: Dictionary = checkpoint.get("water_quantity",{})
\t\tvar gas: Dictionary = checkpoint.get("gas_ledger",{})
\t\tvar ballistic: Dictionary = checkpoint.get("ballistic_water",{})
\t\tok = _require(
\t\t\tstr(checkpoint.get("physical_hash","")).length() == 16
\t\t\tand int(checkpoint.get("hash_version",0)) == 5
\t\t\tand int(checkpoint.get("gas_capacity",0)) == 2048
\t\t\tand int(checkpoint.get("gas_compartments",-1)) <= 2048,
\t\t\t"physical hash/C2048 gas authority checkpoint invalid") and ok
\t\tok = _require(bool(quantity.get("closed",false))
\t\t\tand int(quantity.get("actual",-1)) == int(quantity.get("produced",0))-int(quantity.get("consumed",0))
\t\t\tand bool(gas.get("closes",false))
\t\t\tand int(ballistic.get("total",-1)) == int(ballistic.get("expected",-2)),
\t\t\t"full Water/ballistic/gas native conservation failed") and ok
""",fixture_path)
    (root/fixture_path).write_bytes(fixture.encode("utf-8"))
    changed[fixture_path]={"original_sha256":digest(raw),
                           "instrumented_sha256":digest(fixture.encode("utf-8"))}
    out=Path(a.out)
    out.mkdir(parents=True,exist_ok=True)
    (out/"godot-source-probe.json").write_text(json.dumps({
        "schema":"pf504-fullsize-exclusive-owner-probe-v1",
        "source_app":"24a8bbe8ccf0d17196ebbab580b924930a964584",
        "identical_across_source_arms":True,"test_only":True,
        "counter_fields":FIELDS,"file_hashes":changed},indent=2,sort_keys=True)+"\n")
    print("PF504_FULLSIZE_TEST_ONLY_OWNER_OBSERVATION_PATCHED",json.dumps(changed))

if __name__=="__main__":
    main()
