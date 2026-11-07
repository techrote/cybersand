#!/usr/bin/env python3
"""Exact-input physical comparison for PR #532 selective gas-cache bootstrap."""
from __future__ import annotations
import csv, json, pathlib, sys

TICKS = 264
PHYSICAL = (
    "physical_hash","quantity_digest","gas_digest","water_visible","water_overfill",
    "water_ballistic","water_expected","gas_live","gas_created","gas_absorbed",
    "gas_vented","gas_collapsed","gas_compartments",
)
WORK = (
    "gas_reference_passes","gas_reuses","gas_component_reuses","gas_member_validations",
    "gas_invalidation_pairs","gas_component_invalidations","gas_cache_builds",
    "gas_valid_components","gas_members","seed_cells","bfs_cells","relabel_cells",
)

def need(ok: bool, msg: str) -> None:
    if not ok:
        raise ValueError(msg)

def load(root: pathlib.Path, role: str, workers: int, camera: int) -> list[dict[str,str]]:
    path = root / f"{role}-w{workers}-camera{camera}.csv"
    need(path.is_file(), f"missing {path.name}")
    with path.open(newline="") as fd:
        rows = list(csv.DictReader(fd))
    need(len(rows) == TICKS, f"{path.name}: expected {TICKS} ticks, got {len(rows)}")
    need(all(int(row["tick"]) == i for i,row in enumerate(rows,1)), f"{path.name}: discontinuous ticks")
    return rows

def exact(a: list[dict[str,str]], b: list[dict[str,str]], label: str) -> None:
    for i,(left,right) in enumerate(zip(a,b),1):
        for field in PHYSICAL:
            need(left[field] == right[field],
                 f"{label}: tick {i} field {field} differs: {left[field]} != {right[field]}")

def final(rows: list[dict[str,str]]) -> dict[str,int]:
    row=rows[-1]
    return {field:int(row[field]) for field in WORK}

def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: pf532_compare_native_input_replay.py <evidence-dir>")
    root=pathlib.Path(sys.argv[1])
    lanes={}
    for workers in (1,4):
        for camera in (0,1):
            base=load(root,"baseline",workers,camera)
            cand=load(root,"candidate",workers,camera)
            exact(base,cand,f"source w{workers} camera{camera}")
            lanes[(workers,camera,"baseline")]=base
            lanes[(workers,camera,"candidate")]=cand
    for role in ("baseline","candidate"):
        for camera in (0,1):
            exact(lanes[(1,camera,role)],lanes[(4,camera,role)],f"worker parity {role} camera{camera}")

    summaries={}
    positive=0
    for workers in (1,4):
        for camera in (0,1):
            b=final(lanes[(workers,camera,"baseline")])
            c=final(lanes[(workers,camera,"candidate")])
            need(c["gas_reference_passes"] == b["gas_reference_passes"],
                 f"w{workers} camera{camera}: whole-gas reference-pass count changed")
            if c["gas_component_reuses"] > b["gas_component_reuses"]:
                positive += 1
            summaries[f"w{workers}-camera{camera}"]={"baseline":b,"candidate":c}
    need(positive >= 2, f"selective cache did not activate in enough workbench-derived lanes: {positive}/4")
    need(sum(v["candidate"]["gas_member_validations"] for v in summaries.values()) > 0,
         "candidate never validated cached gas members")
    need(sum(v["candidate"]["bfs_cells"] for v in summaries.values()) <
         sum(v["baseline"]["bfs_cells"] for v in summaries.values()),
         "candidate did not reduce authoritative BFS cell visits")

    observed=max(int(row["workers_observed"]) for row in lanes[(4,0,"candidate")])
    need(observed >= 2, f"four-worker lane did not dispatch native work: observed {observed}")
    report={
        "schema":"pf532-fullsize-identical-native-input-v1",
        "status":"PASS",
        "ticks_per_lane":TICKS,
        "physical_fields":list(PHYSICAL),
        "source_physical_parity":"exact every tick",
        "worker_physical_parity":"exact every tick",
        "cache_positive_lanes":positive,
        "candidate_worker_participants_max":observed,
        "lanes":summaries,
    }
    (root/"comparison.json").write_text(json.dumps(report,indent=2,sort_keys=True)+"\n")
    print("PF532_IDENTICAL_NATIVE_INPUT_PASS",json.dumps(report,sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
