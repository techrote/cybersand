#!/usr/bin/env python3
"""Reduce LCB suite results and build the source-derived scenario registry.

Standard-library only.

  reduce  --w1 DIR --w4 DIR --out FILE   reduce one campaign into a dated controls
                                          file (refuses to overwrite: evidence is immutable)
  build   [--check]                       write/check godot/tests/fixtures/lcb/lcb-scenario-registry.json

The registry is consumed by the LCB-003 UI (Claude D / #202) and by
test_lcb_scenario_catalogue.gd. It never marks an arm runnable unless that arm
actually executed; every other arm carries its blocking dependency.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import scenario_catalogue as catalogue  # noqa: E402

FIXTURES = ROOT / "godot/tests/fixtures/lcb"
REGISTRY = FIXTURES / "lcb-scenario-registry.json"
MATRIX = ROOT / "docs/reference/liquid-solver-capability-matrix.json"
PROTECTED_MANIFEST = ROOT / "docs/reference/lcb-fixture-manifest.json"
CONTROLS = ROOT / "docs/reference/lcb-scenario-controls-2026-10-23.json"
REACTIVE = {"salt", "sodium"}

BLOCKED = {
    "cellular_yield_v1": ("#200 per-material policy; Gate D whole-cell Water regime not implemented",
                          ["#213 LCB-000 PASS", "#200"]),
    "pressure_flow_v1": ("pressure_flow_v1 not implemented; port of corrected 7ef2aac candidate is LCB-001",
                         ["#213 LCB-000 PASS", "#200", "#201 (cached, cached_dormant)"]),
    "inertial_cellular_v1": ("inertial_cellular_v1 not implemented; Brine qualification belongs to LCB-005",
                             ["#200 per-material policy", "#212"]),
}


def lf_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def observations(result: dict) -> dict:
    return {o["id"]: o["value"] for o in result.get("capture", {}).get("observations", [])}


def derived(meta: dict, obs: dict) -> dict:
    out = {}
    cat, inv = meta.get("category"), meta.get("initial_inventory", {})
    if "reservoir-t1800" in obs and inv.get("water_integer"):
        out["reservoir_retained_fraction_t1800"] = round(obs["reservoir-t1800"] / inv["water_integer"], 4)
    for t in (240, 1200):
        bands = sorted(k for k in obs if re.fullmatch(rf"band\d+-t{t}", k))
        if bands:
            wet = [int(k[4:k.index("-")]) for k in bands if obs[k] > 0]
            out[f"front_band_t{t}"] = max(wet) if wet else 0
            out[f"front_band_count_t{t}"] = len(bands)
    if cat == "communicating-head":
        for t in (0, 300, 1200, 2400):
            if f"left-t{t}" in obs:
                out[f"limb_level_difference_rows_t{t}"] = round((obs[f"left-t{t}"] - obs[f"right-t{t}"]) / (48 * 255), 3)
    if cat == "viscous" and meta["id"].endswith("lane-gallery.v1"):
        for name in ("water", "oil", "brine", "slush", "paste", "mercury"):
            start = obs.get(f"{name}-compartment-t0")
            if start:
                out[f"{name}_runout_fraction_t1200"] = round(obs.get(f"{name}-runout-t1200", 0) / start, 4)
    return out


def ledger_state(result: dict, inventory_names: set) -> dict:
    ledger = result["capture"]["water_ledger"]
    final = result["checkpoints"][-1]["water_integer"]
    expected = ledger["initial_integer"] + ledger["explicit_source"] - ledger["explicit_sink"]
    if final == expected:
        state = "closed"
    elif inventory_names & REACTIVE:
        state = "open_by_declared_reaction"
    else:
        state = "OPEN_UNEXPLAINED"
    return {"state": state, "initial": ledger["initial_integer"], "explicit_source": ledger["explicit_source"],
            "explicit_sink": ledger["explicit_sink"], "final_world_water": final}


def reduce_cmd(args) -> int:
    out = Path(args.out)
    if out.exists():
        print(f"refusing to overwrite dated evidence {out}", file=sys.stderr)
        return 1
    metas = {s.id: s.metadata() for s in catalogue.build()}
    protected = {f["id"]: f for f in load(PROTECTED_MANIFEST)["fixtures"]}
    cases, problems = {}, []
    for path in sorted(Path(args.w1).glob("*-w1.json")):
        sid = path.name[:-len("-w1.json")]
        if sid.startswith("summary"):
            continue
        w1, w4path = load(path), Path(args.w4) / f"{sid}-w4.json"
        w4 = load(w4path) if w4path.exists() else {"status": "missing"}
        both = w1.get("status") == "completed" and w4.get("status") == "completed"
        parity = (both and observations(w1) == observations(w4)
                  and [(c["tick"], c["content_hash"], c["state_hash"]) for c in w1["checkpoints"]]
                  == [(c["tick"], c["content_hash"], c["state_hash"]) for c in w4["checkpoints"]])
        if sid in metas:
            meta = metas[sid]
        else:
            definition = load(ROOT / protected[sid]["path"])
            meta = {"id": sid, "category": "protected-reference",
                    "initial_inventory": catalogue.inventory_of(definition["rectangles"], definition["partial_water_fills"])}
        names = set(meta.get("initial_inventory", {}).get("cells", {}))
        case = {
            "status": {"w1": w1.get("status"), "w4": w4.get("status")},
            "errors": {k: v.get("error", "") for k, v in (("w1", w1), ("w4", w4)) if v.get("error")},
            "parity_1_vs_4_workers": "identical" if parity else ("MISMATCH" if both else "not_comparable"),
            "definition_hash": w1.get("definition_hash"),
            "horizon": w1.get("horizon"),
            "outcome": w1.get("capture", {}).get("outcome"),
            "observations": observations(w1),
            "checkpoints": w1.get("checkpoints", []),
            "work": {"w1": w1.get("work"), "w4": w4.get("work")},
            "timing_ms_characterization_only": {
                k: {m: v.get("capture", {}).get("timing", {}).get(m) for m in ("p50_ms", "p95_ms", "max_ms")}
                for k, v in (("w1", w1), ("w4", w4))},
            "report_sha256": {"w1": hashlib.sha256(path.read_bytes()).hexdigest(),
                              "w4": hashlib.sha256(w4path.read_bytes()).hexdigest() if w4path.exists() else None},
        }
        if w1.get("status") == "completed":
            case["ledger"] = ledger_state(w1, names)
            case["derived"] = derived(meta, case["observations"])
        if sid in protected:
            accepted = protected[sid]["arms"][0]["control"]
            case["protected_reproduction"] = {
                "accepted_definition_hash": protected[sid]["definition_hash"],
                "observations_match": accepted["observations"] == case["observations"],
                "final_hashes_match": (accepted["final"]["content_hash"], accepted["final"]["state_hash"])
                == (case["checkpoints"][-1]["content_hash"], case["checkpoints"][-1]["state_hash"]) if case["checkpoints"] else False,
            }
        if not parity or case.get("ledger", {}).get("state") == "OPEN_UNEXPLAINED" or w1.get("status") != "completed":
            problems.append(sid)
        cases[sid] = case
    identity = next(iter(cases.values()))
    any_w1 = load(next(Path(args.w1).glob("*-w1.json")))
    result = {
        "schema": "lcb-scenario-controls-v1",
        "date": args.date,
        "scope": "Current native defaults only; controlled fixed-tick native-only runs; no player, Rapier, render or Web",
        "platform": args.platform,
        "source_commit": args.source_sha,
        "runtime": {"native_sha256": any_w1["capture"]["runtime_identity"]["native_sha256"],
                    "godot": any_w1["capture"]["runtime_identity"]["godot"],
                    "script_set_sha256": any_w1["capture"]["runtime_identity"].get("script_set_sha256")},
        "runner": "godot/tests/run_lcb_scenario_suite.gd + godot/tests/lcb_scenario_runner.gd",
        "problems": problems,
        "cases": cases,
    }
    del identity
    out.write_bytes((json.dumps(result, indent=2) + "\n").encode("utf-8"))
    print(f"wrote {out} with {len(cases)} cases; problems={problems}")
    return 0


def arms_for(sid: str, liquids: list, control: dict | None, sealed: bool) -> list:
    measured = control and control["status"]["w1"] == "completed" and control["parity_1_vs_4_workers"] == "identical"
    defaults = {m: "freemass_v1/reference" if m == "water" else "cellular_yield_v1/reference" for m in liquids}
    current_status = "measured" if measured else ("failed" if control else "unmeasured")
    if sealed and measured:
        current_status = "measured_not_a_sealed_control"
    arms = [{"id": "W-FM" if liquids == ["water"] else "C0", "mapping": defaults, "status": current_status,
             "executable_today": True,
             "note": "Current defaults; Current Water has no gas state, so roofed limbs behave as vented" if sealed
             else "unchanged production defaults"}]
    if "water" in liquids:
        for arm, family, variants in (("W-CY", "cellular_yield_v1", ["reference"]),
                                      ("W-PF", "pressure_flow_v1", ["reference", "cached", "cached_dormant"]),
                                      ("W-IN", "inertial_cellular_v1", ["reference"])):
            reason, deps = BLOCKED[family]
            arms.append({"id": arm, "mapping": {**defaults, "water": f"{family}/{'|'.join(variants)}"},
                         "status": "blocked", "executable_today": False, "reason": reason, "depends_on": deps})
    if "brine" in liquids:
        reason, deps = BLOCKED["inertial_cellular_v1"]
        arms.append({"id": "BRINE-IN", "mapping": {**defaults, "brine": "inertial_cellular_v1/reference"},
                     "status": "blocked", "executable_today": False, "reason": reason, "depends_on": deps})
    if {"water", "oil", "brine"} <= set(liquids):
        for arm, water, brine, count in (("M1", "freemass_v1/reference", "inertial_cellular_v1/reference", 3),
                                         ("M2", "pressure_flow_v1/reference", "inertial_cellular_v1/reference", 3),
                                         ("M2b", "pressure_flow_v1/reference", "cellular_yield_v1/reference", 2)):
            deps = sorted({*(BLOCKED["inertial_cellular_v1"][1] if "inertial" in brine else []),
                           *(BLOCKED["pressure_flow_v1"][1] if "pressure" in water else [])})
            arms.append({"id": arm, "mapping": {**defaults, "water": water, "brine": brine}, "families_active": count,
                         "status": "blocked", "executable_today": False, "depends_on": deps,
                         "reason": "requires families that do not exist in this build"})
    return arms


def entry(sid, meta, definition_path, control, matrix, protected_fixture=None) -> dict:
    definition = load(definition_path)
    rows = {r["name"]: r for r in matrix["liquid_rows"]}
    inventory = meta["initial_inventory"]
    liquids = sorted(n for n in inventory.get("cells", {}) if n in rows)
    pres = definition.get("presentation", {})
    sealed = sid == "lcb.head.sealed-two-limb.v1"
    arms = arms_for(sid, liquids, control, sealed)
    if protected_fixture:
        arms = [{"id": a["id"], "mapping": a["policy"], "status": a["status"],
                 "executable_today": a["status"] == "measured", **({"depends_on": a["blocked_by"]} if "blocked_by" in a else {})}
                for a in protected_fixture["arms"]]
    rel = definition_path.relative_to(ROOT).as_posix()
    return {
        "id": sid, "version": 1, "category": meta["category"], "title": pres.get("title", sid),
        "purpose": meta.get("purpose") or pres.get("instructions", ""),
        "protected": bool(protected_fixture),
        "definition": {"res_path": "res://" + rel[len("godot/"):], "repo_path": rel,
                       "file_sha256_lf": lf_sha256(definition_path),
                       "canonical_hash": control["definition_hash"] if control else None,
                       "contract": "MicroScenario schema %d" % definition["schema_version"]},
        "setup": {"seed": definition["seed"], "horizon_ticks": meta["horizon_ticks"],
                  "transport_profile": definition["transport_profile"]["name"],
                  "water_semantics": definition["water_semantics"], "interest": definition["interest"],
                  "execution": definition["execution"], "events": definition["events"],
                  "initial_inventory": inventory},
        "observations": [{k: o[k] for k in ("id", "tick", "metric", "material", "region")} for o in definition["observations"]],
        "conditions": definition["conditions"],
        "camera": {"origin": definition["camera_origin"], "overview": meta.get("overview"),
                   "bookmarks": pres.get("regions", [])},
        "manual": meta.get("manual", {"free_play": True, "note": ""}),
        "liquids": liquids,
        "compatibility": {n: rows[n]["families"] for n in liquids},
        "arms": arms,
        "qualification": {
            "windows_local_native": ({"status": "measured" if arms[0]["status"].startswith("measured") else arms[0]["status"],
                                      "parity_1_vs_4_workers": control["parity_1_vs_4_workers"],
                                      "outcome": control["outcome"], "ledger": control.get("ledger", {}).get("state"),
                                      "controls_file": CONTROLS.relative_to(ROOT).as_posix()}
                                     if control else {"status": "unmeasured"}),
            "linux_ci": "test_lcb_scenario_catalogue.gd: tick-30 prefix hashes and 1/4-worker parity on GitHub-hosted Linux (non-draft PR)",
            "web": "not executed", "rapier_player_render": "not executed (native-only runner)",
        },
        "goldens": ({"initial_water_integer": inventory.get("water_integer"),
                     "tick30": next(({"content_hash": c["content_hash"], "state_hash": c["state_hash"],
                                      "water_integer": c["water_integer"]}
                                     for c in control["checkpoints"] if c["tick"] == 30), None)}
                    if control else None),
    }


def build() -> dict:
    matrix = load(MATRIX)
    controls = load(CONTROLS)["cases"] if CONTROLS.exists() else {}
    manifest = load(PROTECTED_MANIFEST)
    entries = []
    for fixture in manifest["fixtures"]:
        path = ROOT / fixture["path"]
        definition = load(path)
        inventory = catalogue.inventory_of(definition["rectangles"], definition["partial_water_fills"])
        # Cross-check against the accepted PR #215 measured initial state; never rewrite it.
        for key, value in fixture["initial"].items():
            derived_value = inventory["water_integer"] if key == "water_integer" else \
                inventory["cells"].get(key[:-len("_cells")], 0) if key.endswith("_cells") else value
            if derived_value != value:
                raise SystemExit(f"{fixture['id']}: derived {key}={derived_value} != accepted {value}")
        meta = {"category": "protected-reference", "horizon_ticks": fixture["horizon_ticks"],
                "initial_inventory": inventory,
                "overview": [32, 64, 960, 200] if "dam" in fixture["id"] else [64, 96, 896, 168],
                "purpose": definition["presentation"]["instructions"],
                "manual": {"free_play": True, "note": "manual variant is exploratory; controlled run uses this frozen definition"}}
        entries.append(entry(fixture["id"], meta, path, controls.get(fixture["id"]), matrix, fixture))
    for s in catalogue.build():
        entries.append(entry(s.id, s.metadata(), catalogue.OUT / f"{s.id}.json", controls.get(s.id), matrix))
    return {
        "schema": "lcb-scenario-registry-v1",
        "status": "LCB-003 preparation. Only arms with status starting 'measured' have executed; every blocked arm names its dependency.",
        "sources": {"capability_matrix": lf_sha256(MATRIX), "protected_manifest": lf_sha256(PROTECTED_MANIFEST),
                    "controls": lf_sha256(CONTROLS) if CONTROLS.exists() else None,
                    "catalogue_tool": lf_sha256(Path(catalogue.__file__))},
        "integration_requirements": [
            "#200: LiquidSolverPolicy, refusal codes and effective readback so blocked arms can execute",
            "#212: inertial_cellular_v1 and Brine qualification (M1, BRINE-IN, W-IN)",
            "#201: pressure cached/cached_dormant variants (W-PF variants)",
            "#202: launcher/panel consumption of this registry; exploratory marking; Rapier/player/body stations",
            "#203: sequential isolated timing; Linux/Windows packaged and Web execution",
        ],
        "scenarios": entries,
    }


def build_cmd(args) -> int:
    text = json.dumps(build(), indent=2) + "\n"
    if args.check:
        current = REGISTRY.read_text(encoding="utf-8").replace("\r\n", "\n") if REGISTRY.exists() else ""
        if current != text:
            print("stale registry; run tools/lcb/lcb_registry.py build", file=sys.stderr)
            return 1
        print("scenario registry matches its sources")
        return 0
    REGISTRY.write_bytes(text.encode("utf-8"))
    print(f"wrote {REGISTRY.relative_to(ROOT)}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("reduce")
    r.add_argument("--w1", required=True)
    r.add_argument("--w4", required=True)
    r.add_argument("--out", default=str(CONTROLS))
    r.add_argument("--date", required=True)
    r.add_argument("--platform", required=True)
    r.add_argument("--source-sha", required=True)
    b = sub.add_parser("build")
    b.add_argument("--check", action="store_true")
    args = parser.parse_args()
    return reduce_cmd(args) if args.cmd == "reduce" else build_cmd(args)


if __name__ == "__main__":
    raise SystemExit(main())
