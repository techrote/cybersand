#!/usr/bin/env python3
"""Reduce LCB suite results and build the source-derived scenario registry.

Standard-library only.

  reduce  --w1 DIR --w4 DIR --out FILE   reduce one campaign into a dated controls
                                          file (refuses to overwrite: evidence is immutable)
  reledger [--check]                      re-reduce the retained 2026-10-23 controls with the
                                          signed ledger into a new versioned record
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
LEDGER_V2 = ROOT / "docs/reference/lcb-scenario-ledger-2026-10-23.v2.json"
LEDGER_RULE = "lcb-signed-ledger-v2"
# Declared reactions that may change the Water integer, per reactive species.
# Salt: Water+Salt -> Brine+Brine removes one Water cell of mass m in 1..255
# per consumed Salt cell and adds two Brine cells. Sodium: products include
# Steam that later condenses to full Water, so no Water sign is declared.
REACTIVE = {"salt", "sodium"}
FULL_WATER = 255
# Accounting states. Only CLOSED_STATES are eligible for acceptance.
CLOSED_STATES = {"closed", "closed_signed_reaction_ledger"}
UNVERIFIED_STATES = {"UNVERIFIED_REACTION_AMOUNT", "UNVERIFIED_PARTIAL_WATER_160"}

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


def signed_ledger(inventory: dict, ledger: dict, checkpoints: list) -> dict:
    """Signed per-species Water accounting (lcb-signed-ledger-v2).

    A reactive species is never an explanation by itself. A discrepancy is
    either bounded by the declared reaction and the available evidence, or it
    is OPEN_UNEXPLAINED. When the evidence cannot establish the reaction
    amount, the state is UNVERIFIED_* and the case is ineligible for
    acceptance. World-wide species counts are read from an optional
    checkpoint["species"] dict; the 2026-10-23 campaign has none.
    """
    cells = inventory.get("cells", {})
    w0, src, sink = ledger["initial_integer"], ledger["explicit_source"], ledger["explicit_sink"]
    series = [(c["tick"], c["water_integer"]) for c in checkpoints]
    final = series[-1][1]
    reactive = sorted(set(cells) & REACTIVE)
    base = {"rule": LEDGER_RULE, "initial": w0, "explicit_source": src, "explicit_sink": sink,
            "final_world_water": final, "signed_delta": final - (w0 + src - sink), "reactive_species": reactive}

    def result(state, reason, **extra):
        return {"state": state, "eligible_for_acceptance": state in CLOSED_STATES, "reason": reason, **base, **extra}

    gains = [(a[0], b[0], b[1] - a[1]) for a, b in zip(series, series[1:]) if b[1] > a[1]]
    if not reactive:
        if src == 0 and sink == 0:
            off = [(tick, w - w0) for tick, w in series if w != w0]
            if off:
                return result("OPEN_UNEXPLAINED", "Water integer differs from the initial value with no "
                              "source, sink or reactive species", deviations=off)
            return result("closed", "Water integer constant at every checkpoint")
        outside = [(tick, w) for tick, w in series if not w0 - sink <= w <= w0 + src]
        if final != w0 + src - sink or outside:
            return result("OPEN_UNEXPLAINED", "Water integer does not close against the explicit source/sink",
                          outside_bounds=outside)
        return result("closed", "final Water integer equals initial + explicit source - explicit sink")
    if all(w == w0 for _, w in series) and src == 0 and sink == 0:
        return result("closed", "Water integer constant at every checkpoint; no reaction changed it")
    species = [c.get("species") for c in checkpoints]
    if all(species) and reactive == ["salt"] and src == 0 and sink == 0:
        return _salt_species_ledger(result, cells, series, species)
    if "sodium" in reactive:
        return result("UNVERIFIED_REACTION_AMOUNT", "Sodium products include Steam that condenses to full "
                      "Water; no per-reaction amounts are retained, so neither sign nor amount is established",
                      checkpoint_gains=gains)
    if src or sink:
        return result("UNVERIFIED_REACTION_AMOUNT", "reaction and explicit source/sink overlap; no "
                      "per-reaction amounts are retained")
    # Salt only, Water-integer evidence only: the declared reaction can only
    # remove Water, at most one full cell per initial Salt cell.
    if gains:
        return result("OPEN_UNEXPLAINED", "Water gain with Salt as the only reactive species "
                      "(dissolution can only remove Water)", checkpoint_gains=gains)
    bound = FULL_WATER * cells["salt"]
    if w0 - final > bound:
        return result("OPEN_UNEXPLAINED", f"Water loss {w0 - final} exceeds the dissolution bound "
                      f"{FULL_WATER} x {cells['salt']} initial Salt cells", loss_bound=bound)
    return result("UNVERIFIED_REACTION_AMOUNT", "loss lies within the dissolution bound and never "
                  "reverses, but consumed Salt and Brine production are not retained world-wide, so the "
                  "reaction amount is not established", loss_bound=bound)


def _salt_species_ledger(result, cells, series, species) -> dict:
    w0, salt0, brine0 = series[0][1], cells["salt"], cells.get("brine", 0)
    others = {k: v for k, v in cells.items() if k not in {"water", "salt", "brine"}}
    rows, partial, last_s = [], False, None
    for (tick, w), sp in zip(series, species):
        s = salt0 - sp.get("salt", 0)
        dw, db = w - w0, sp.get("brine", 0) - brine0
        row = {"tick": tick, "salt_consumed": s, "brine_delta": db, "water_delta": dw}
        rows.append(row)
        if s < 0 or (last_s is not None and s < last_s[0]):
            return result("OPEN_UNEXPLAINED", "Salt reappeared", species_ledger=rows)
        if db != 2 * s:
            return result("OPEN_UNEXPLAINED", "Brine delta is not exactly 2 x consumed Salt", species_ledger=rows)
        if not -FULL_WATER * s <= dw <= -s:
            return result("OPEN_UNEXPLAINED", "Water delta outside [-255 s, -s] for consumed Salt s",
                          species_ledger=rows)
        if last_s is not None and s == last_s[0] and w != last_s[1]:
            return result("OPEN_UNEXPLAINED", "Water changed after dissolution stopped", species_ledger=rows)
        for name, count in others.items():
            if sp.get(name, count) != count:
                return result("OPEN_UNEXPLAINED", f"{name} cells changed", species_ledger=rows)
        partial |= dw != -FULL_WATER * s
        last_s = (s, w)
    if partial:
        return result("UNVERIFIED_PARTIAL_WATER_160", "within bounds, but some consumed Water cells were "
                      "partial (#160 boundary); per-cell consumed masses are not retained", species_ledger=rows)
    return result("closed_signed_reaction_ledger", "every consumed Salt cell removed one full Water cell and "
                  "produced two Brine cells; Water constant after dissolution", species_ledger=rows)


def reduce_cmd(args) -> int:
    out = Path(args.out)
    if out.exists():
        print(f"refusing to overwrite dated evidence {out}", file=sys.stderr)
        return 1
    metas = {s.id: s.metadata() for s in catalogue.build()}
    protected = {f["id"]: f for f in load(PROTECTED_MANIFEST)["fixtures"]}
    cases, problems, unverified = {}, [], []
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
            case["ledger"] = signed_ledger(meta.get("initial_inventory", {}), w1["capture"]["water_ledger"],
                                           w1["checkpoints"])
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
        elif case["ledger"]["state"] in UNVERIFIED_STATES:
            unverified.append(sid)
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
        "ledger_rule": LEDGER_RULE,
        "problems": problems,
        "accounting_unverified_ineligible_for_acceptance": unverified,
        "cases": cases,
    }
    del identity
    out.write_bytes((json.dumps(result, indent=2) + "\n").encode("utf-8"))
    print(f"wrote {out} with {len(cases)} cases; problems={problems}")
    return 0


def inventories() -> dict:
    out = {s.id: s.metadata()["initial_inventory"] for s in catalogue.build()}
    for fixture in load(PROTECTED_MANIFEST)["fixtures"]:
        definition = load(ROOT / fixture["path"])
        out[fixture["id"]] = catalogue.inventory_of(definition["rectangles"], definition["partial_water_fills"])
    return out


def reledger() -> dict:
    """Re-reduce the retained (immutable) 2026-10-23 controls with the signed ledger."""
    controls = load(CONTROLS)
    inv = inventories()
    cases = {}
    for sid, case in controls["cases"].items():
        if "ledger" not in case:
            continue
        old = case["ledger"]
        ledger = {"initial_integer": old["initial"], "explicit_source": old["explicit_source"],
                  "explicit_sink": old["explicit_sink"]}
        new = signed_ledger(inv[sid], ledger, case["checkpoints"])
        cases[sid] = {"superseded_state": old["state"], **new}
    return {
        "schema": "lcb-scenario-ledger-v2",
        "date": "2026-10-23",
        "rule": LEDGER_RULE,
        "status": "Corrected accounting reduction of retained characterization data. The historical controls "
                  "file and its states are preserved unchanged; this record supersedes only their ledger "
                  "classification. Characterization only: accepted evidence remains the CI-re-executed prefixes.",
        "input": {"controls_file": CONTROLS.relative_to(ROOT).as_posix(), "controls_sha256_lf": lf_sha256(CONTROLS),
                  "controls_source_commit": controls["source_commit"],
                  "reducer_sha256_lf": lf_sha256(Path(__file__))},
        "evidence_limits": "The campaign retained world Water integers per checkpoint and windowed observations; "
                           "it retained no world-wide per-species counts and no per-reaction log.",
        "open_unexplained": sorted(s for s, c in cases.items() if c["state"] == "OPEN_UNEXPLAINED"),
        "accounting_unverified_ineligible_for_acceptance": sorted(
            s for s, c in cases.items() if c["state"] in UNVERIFIED_STATES),
        "cases": cases,
    }


def reledger_cmd(args) -> int:
    text = json.dumps(reledger(), indent=2) + "\n"
    if args.check:
        current = LEDGER_V2.read_text(encoding="utf-8").replace("\r\n", "\n") if LEDGER_V2.exists() else ""
        if current != text:
            print("stale ledger record; run tools/lcb/lcb_registry.py reledger", file=sys.stderr)
            return 1
        print("signed ledger record matches the retained controls")
        return 0
    if LEDGER_V2.exists():
        print(f"refusing to overwrite dated evidence {LEDGER_V2.relative_to(ROOT)}", file=sys.stderr)
        return 1
    LEDGER_V2.write_bytes(text.encode("utf-8"))
    print(f"wrote {LEDGER_V2.relative_to(ROOT)}")
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


def entry(sid, meta, definition_path, control, matrix, protected_fixture=None, ledger_v2=None) -> dict:
    ledger_v2 = ledger_v2 or {}
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
                                      "outcome": control["outcome"], "ledger": ledger_v2.get("state"),
                                      "ledger_eligible_for_acceptance": ledger_v2.get("eligible_for_acceptance"),
                                      "ledger_rule": LEDGER_RULE,
                                      "controls_file": CONTROLS.relative_to(ROOT).as_posix(),
                                      "ledger_file": LEDGER_V2.relative_to(ROOT).as_posix()}
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
    ledgers = load(LEDGER_V2)["cases"] if LEDGER_V2.exists() else {}
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
        entries.append(entry(fixture["id"], meta, path, controls.get(fixture["id"]), matrix, fixture,
                             ledgers.get(fixture["id"])))
    for s in catalogue.build():
        entries.append(entry(s.id, s.metadata(), catalogue.OUT / f"{s.id}.json", controls.get(s.id), matrix,
                             ledger_v2=ledgers.get(s.id)))
    return {
        "schema": "lcb-scenario-registry-v1",
        "status": "LCB-003 preparation. Only arms with status starting 'measured' have executed; every blocked arm names its dependency.",
        "sources": {"capability_matrix": lf_sha256(MATRIX), "protected_manifest": lf_sha256(PROTECTED_MANIFEST),
                    "controls": lf_sha256(CONTROLS) if CONTROLS.exists() else None,
                    "ledger_v2": lf_sha256(LEDGER_V2) if LEDGER_V2.exists() else None,
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
    g = sub.add_parser("reledger")
    g.add_argument("--check", action="store_true")
    b = sub.add_parser("build")
    b.add_argument("--check", action="store_true")
    args = parser.parse_args()
    return {"reduce": reduce_cmd, "reledger": reledger_cmd, "build": build_cmd}[args.cmd](args)


if __name__ == "__main__":
    raise SystemExit(main())
