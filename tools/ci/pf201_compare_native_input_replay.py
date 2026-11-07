#!/usr/bin/env python3
"""Fail-closed exact-fullsize source and worker replay comparison.

A single Godot-exported full-size 2048x1024 material fixture and one immutable
eight-body/edits/jet tape are inputs to four identical native source lanes.
Compare EVERY completed tick, all future-affecting physical hashes, entire
native Water accounting digest and gas authority, not async Rapier snapshots.
"""
from __future__ import annotations
import csv, hashlib, json, pathlib, sys

FIELDS=("physical_hash","quantity_digest","gas_digest","water_visible",
        "water_overfill","water_ballistic","water_expected","gas_live",
        "gas_created","gas_absorbed","gas_vented","gas_collapsed",
        "gas_compartments")

def sha(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def require(ok:bool,msg:str)->None:
    if not ok: raise ValueError(msg)

def load(root:pathlib.Path,role:str,workers:int,camera:int):
    name=f"{role}-w{workers}-camera{camera}"
    path=root/f"{name}.csv"
    require(path.is_file(),f"missing required exact-source replay {name}")
    with path.open(newline="") as fd:
        rows=list(csv.DictReader(fd))
    require(len(rows)==264,f"{name}: expected 264 native completed ticks, got {len(rows)}")
    require(all(int(r["tick"])==i for i,r in enumerate(rows,1)),
            f"{name}: native tape skipped/reordered ticks")
    require(all(len(r["physical_hash"])==16 and r["physical_hash"]!="0000000000000000"
                and int(r["gas_compartments"])<=2048
                and int(r["water_visible"])+int(r["water_overfill"])+int(r["water_ballistic"])
                      ==int(r["water_expected"])
                and int(r["gas_live"])+int(r["gas_vented"])+int(r["gas_collapsed"])
                      ==int(r["gas_created"])+int(r["gas_absorbed"])
                for r in rows), f"{name}: corrupt native physical/accounting record")
    require(all(1<=int(r["workers_observed"])<=workers for r in rows),
            f"{name}: invalid measured worker participation")
    return rows,{"name":name,"sha256":sha(path),"observed_workers_max":
                 max(int(x["workers_observed"]) for x in rows)}
def main()->None:
    if len(sys.argv)!=2: raise SystemExit("usage: compare <replay evidence dir>")
    root=pathlib.Path(sys.argv[1])
    inp=json.loads((root/"replay-input-manifest.json").read_text())
    tape=root/"replay-tape.csv"
    fixture=root/"fixtures/stress-canvas.csv"
    require(inp["tape_sha256"]==sha(tape),"tape mutated between source arms")
    require(inp["material_fixture_sha256"]==sha(fixture),"not the original authored Godot fixture")
    traces={}
    files=[]
    for workers in (1,4):
        for camera in (0,1):
            for role in ("baseline","candidate"):
                rows,detail=load(root,role,workers,camera)
                traces[role,workers,camera]=rows
                files.append(detail)
    comparisons=[]
    for workers in (1,4):
        for camera in (0,1):
            a=traces["baseline",workers,camera]
            b=traces["candidate",workers,camera]
            for t,(x,y) in enumerate(zip(a,b),1):
                for field in FIELDS:
                    require(x[field]==y[field],
                            f"EXACT NATIVE PHYSICAL/QUANTITY MISMATCH tick={t}, "
                            f"workers={workers}, camera={camera}, field={field}, "
                            f"baseline={x[field]}, candidate={y[field]}")
            comparisons.append({"worker_threads":workers,"camera_moving":bool(camera),
                                "matched_tick_hashes":264,
                                "matched_water_ledgers":264,
                                "matched_gas_table_and_history":264})
    # 1-worker and 4-worker executions share the same material stream/masks
    # and camera lane, so physical results must not depend on pool width.
    cross=[]
    for camera in (0,1):
        for role in ("baseline","candidate"):
            a=traces[role,1,camera]
            b=traces[role,4,camera]
            for t,(x,y) in enumerate(zip(a,b),1):
                for field in ("physical_hash","quantity_digest","gas_digest","water_expected",
                              "gas_live","gas_created","gas_absorbed","gas_vented","gas_collapsed"):
                    require(x[field]==y[field],
                            f"NONDETERMINISTIC NATIVE WORKER PARITY {role=} camera={camera} "
                            f"tick={t} field={field} w1={x[field]} w4={y[field]}")
            cross.append({"source":role,"camera_moving":bool(camera),
                          "worker1_vs_worker4_physical_and_quantity_ticks":264})
    report={
        "schema":"pf201-post405-real-workbench-derived-native-replay-v1",
        "status":"PASS","fullsize_authored_fixture":True,"extent":[2048,1024],
        "body_count":8,"tape_kind":inp["input_type"],
        "source_parent_baseline":"81bbd5ff5cf366159e2b8a630609359c13560080",
        "candidate_source":"exact checked-out candidate source in source-heads.txt",
        "input_manifest":inp,"source_binary_sha256":json.loads((root/"binaries.json").read_text()),
        "same_input_source_pair_comparisons":comparisons,
        "native_source_matched_physical_hashes":sum(x["matched_tick_hashes"] for x in comparisons),
        "native_source_matched_water_gas_ledgers":sum(x["matched_water_ledgers"] for x in comparisons),
        "cross_worker_parity":cross,
        "work_by_source":{f"{role}-w{workers}-camera{camera}":{
            key:int(traces[role,workers,camera][-1][key])
            for key in ("gas_reference_passes","gas_reuses","seed_cells","bfs_cells","relabel_cells",
                        "gas_component_reuses","gas_cache_builds","gas_member_validations","gas_cache_build_cells")}
            for workers in (1,4) for camera in (0,1) for role in ("baseline","candidate")},
        "traces":files,
        "boundaries":[
          "Each source runs the same Godot-authored 2048x1024 material geometry",
          "All body masks, edits and water jet inputs are a fixed recorded CSV; no Rapier time or threading controls the tape",
          "This is a deterministic SCRIPTED native-input replay derived from the actual workbench, not the real eight-barrel Rapier input capture",
          "Per-tick native C2048 full physical hash and complete mass ledger are source-compared; no visual application FPS is asserted",
          "No main/PR production code, material law, runtime LFS or default policy is modified by the test",
        ],
    }
    (root/"native-identical-input-parity.json").write_text(json.dumps(report,indent=2,sort_keys=True)+"\n")
    print(f"PF201_POST405_IDENTICAL_INPUT_PHYSICAL_PARITY_PASS "
          f"{report['native_source_matched_physical_hashes']} source-matched full physical tick hashes; "
          f"{len(cross)*264} cross-worker physical tick checks; "
          f"full 2048x1024 Godot-authored setup; 2 camera modes; 8 replayed body masks")

if __name__=="__main__":
    try: main()
    except Exception as e:
        print("PF201_POST405_IDENTICAL_INPUT_PHYSICAL_PARITY_FAIL "+str(e),file=sys.stderr)
        raise
