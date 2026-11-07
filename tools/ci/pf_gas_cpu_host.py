#!/usr/bin/env python3
"""Stage test-only worker observations without changing production gameplay code.

Applies identical read-only GDScript instrumentation to the accepted C2048 app
used for BOTH native DLL arms. A clean copy of #493's scenario stays unchanged
on the PR; only the temporary Actions worktree is patched.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

COUNTERS = (
    "preparation_nanoseconds", "gas_nanoseconds", "head_nanoseconds",
    "pf_probe_gas_process_cpu_ns", "pf_probe_gas_owner_cpu_ns",
    "pf_probe_head_process_cpu_ns", "pf_probe_discovery_process_cpu_ns",
    "pf_probe_identity_process_cpu_ns", "pf_probe_relabel_process_cpu_ns",
    "gas_seed_cells", "gas_seed_probes", "gas_bfs_cells", "gas_bfs_probes",
    "gas_bfs_nodes", "gas_relabel_cells", "gas_identity_nodes",
    "gas_reference_passes", "gas_reuses", "gas_restart_fallbacks",
    "gas_cache_builds", "gas_component_reuses", "gas_capacity_fallbacks",
    "gas_budget_fallbacks", "water_material_calls", "water_motion_calls",
)

def replace_one(s: str, original: str, replacement: str, path: str) -> str:
    count = s.count(original)
    if count!=1:
        raise ValueError(f"Expected exactly one {path} anchor; found {count}: {original[:110]}")
    return s.replace(original,replacement,1)

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def main() -> None:
    p=argparse.ArgumentParser()
    p.add_argument("--app",required=True)
    p.add_argument("--original-fixture",required=True)
    p.add_argument("--out",required=True)
    args=p.parse_args()
    app=Path(args.app).resolve()
    out=Path(args.out).resolve()
    out.mkdir(parents=True,exist_ok=True)
    src=app/"godot/scripts/simulation_worker.gd"
    fixture=app/"godot/tests/performance/water_factorial_stress.gd"
    fixture.parent.mkdir(parents=True,exist_ok=True)
    if fixture.exists():
        raise FileExistsError("Refusing to overwrite existing app-test profile copy")
    original_fixture=Path(args.original_fixture).read_bytes()
    fixture.write_bytes(original_fixture)
    records={}
    worker_raw=src.read_bytes()
    worker=worker_raw.decode("utf-8")
    # This insertion is inside _publish_snapshot after the copied lab_context
    # is built, while the simulation worker is exclusive owner of _world.
    insertion='''\tif OS.get_environment("CYBERSAND_PF_GAS_CPU_PROFILE") == "1" and _world.has_method(&"inspect_pressure_optimization"):
\t\tvar cpu_inspection: Dictionary = _world.inspect_pressure_optimization()
\t\tvar cpu_all: Dictionary = cpu_inspection.get("counters",{})
\t\tvar cpu_selected: Dictionary = {}
'''
    for field in COUNTERS:
        insertion+=f'\t\tcpu_selected["{field}"] = str(cpu_all.get("{field}",""))\n'
    insertion+='''\t\tsnapshot.lab_context["pf_cpu_profile"] = {
\t\t\t"tick":snapshot.tick_index,
\t\t\t"available":bool(cpu_inspection.get("available",false)),
\t\t\t"variant_status":str(cpu_inspection.get("status","unknown")),
\t\t\t"gas_pending":bool(cpu_inspection.get("gas_pending",false)),
\t\t\t"counters":cpu_selected,
\t\t\t"native_worker_participation":snapshot.native_worker_participation.duplicate(true),
\t\t}
'''
    worker = replace_one(worker,
        '\t}\n\tif _workbench_extent != Vector2i.ZERO:\n',
        '\t}\n'+insertion+'\tif _workbench_extent != Vector2i.ZERO:\n',
        "simulation_worker.gd")
    src.write_text(worker,encoding="utf-8",newline="\n")
    records["godot/scripts/simulation_worker.gd"]={
        "original_sha256":sha(worker_raw),"probe_sha256":sha(worker.encode("utf-8"))}
    original_fixture_txt=original_fixture.decode("utf-8")
    txt=original_fixture_txt
    txt=replace_one(txt,
        '\tvar start_tick: int = int(host.latest_snapshot.tick_index)\n',
        '''\tvar pf_cpu_profile_begin: Dictionary = host.latest_snapshot.lab_context.get("pf_cpu_profile",{}).duplicate(true)
\tvar start_tick: int = int(host.latest_snapshot.tick_index)
''',"water_factorial_stress.gd")
    txt=replace_one(txt,
        '\tvar stop_spray: Dictionary = host.tower_context.get("water_spray",{})\n',
        '''\tvar pf_cpu_profile_end: Dictionary = host.latest_snapshot.lab_context.get("pf_cpu_profile",{}).duplicate(true) if host.latest_snapshot != null else {}
\tvar stop_spray: Dictionary = host.tower_context.get("water_spray",{})
''',"water_factorial_stress.gd")
    txt=replace_one(txt,
        '\tif not world_failure.is_empty():\n',
        '''\tif OS.get_environment("CYBERSAND_PF_GAS_CPU_PROFILE") == "1":
\t\tresult["summary"]["pf_cpu_profile_begin"] = pf_cpu_profile_begin
\t\tresult["summary"]["pf_cpu_profile_end"] = pf_cpu_profile_end
\t\tif str(cfg.family) == "pressure_flow_v1" and (pf_cpu_profile_begin.is_empty() or pf_cpu_profile_end.is_empty()):
\t\t\tresult.status = "PROFILE_MISSING"
\t\t\tresult.reason = "native exclusive-owner gas-stage CPU probe unavailable"
\tif not world_failure.is_empty():
''',"water_factorial_stress.gd")
    patched=txt.encode("utf-8")
    fixture.write_bytes(patched)
    records["godot/tests/performance/water_factorial_stress.gd"]={
        "original_sha256":sha(original_fixture),"probe_sha256":sha(patched)}
    (out/"host-instrumentation.json").write_text(
        json.dumps({"schema":"pf-cpu-host-probe-v1", "test_only":True,
                    "source_app_sha":"24a8bbe8ccf0d17196ebbab580b924930a964584",
                    "module": "same Godot worker + fixture for both source built libraries",
                    "counters":list(COUNTERS),"files":records},indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("PROFILE_HOST_READ_ONLY_INSTRUMENTED "+json.dumps(records,sort_keys=True))

if __name__=="__main__":
    main()
