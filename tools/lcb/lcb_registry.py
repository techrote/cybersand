#!/usr/bin/env python3
"""Reduce LCB suite results and build the source-derived scenario registry.

Standard-library only.

  reduce  --w1 DIR --w4 DIR --out FILE   reduce one campaign into a dated controls
                                          file (refuses to overwrite: evidence is immutable)
  reledger [--check] [--version v4|v3|v2] re-reduce the retained 2026-10-23 controls into the
                                          versioned v4 record; v2 and v3 are check-only against
                                          their frozen historical reducers (ledger_v*_historical.py)
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
import ledger_v2_historical  # noqa: E402
import ledger_v3_historical  # noqa: E402
import scenario_catalogue as catalogue  # noqa: E402

FIXTURES = ROOT / "godot/tests/fixtures/lcb"
REGISTRY = FIXTURES / "lcb-scenario-registry.json"
MATRIX = ROOT / "docs/reference/liquid-solver-capability-matrix.json"
PROTECTED_MANIFEST = ROOT / "docs/reference/lcb-fixture-manifest.json"
CONTROLS = ROOT / "docs/reference/lcb-scenario-controls-2026-10-23.json"
LEDGER_V2 = ROOT / "docs/reference/lcb-scenario-ledger-2026-10-23.v2.json"
LEDGER_V3 = ROOT / "docs/reference/lcb-scenario-ledger-2026-10-23.v3.json"
LEDGER_V4 = ROOT / "docs/reference/lcb-scenario-ledger-2026-10-23.v4.json"
LEDGER_RULE = "lcb-signed-ledger-v4"
# Declared reactions that may change the Water integer, per reactive species.
# Salt: Water+Salt -> Brine+Brine removes one Water cell of mass m in 1..255
# per consumed Salt cell and adds two Brine cells. Sodium: products include
# Steam that later condenses to full Water, so no Water sign is declared.
REACTIVE = {"salt", "sodium"}
FULL_WATER = 255
# Accounting states. Only CLOSED_STATES are eligible for acceptance.
CLOSED_STATES = {"closed", "closed_signed_reaction_ledger", "closed_timed_source_sink"}
UNVERIFIED_STATES = {"UNVERIFIED_REACTION_AMOUNT", "UNVERIFIED_PARTIAL_WATER_160", "UNVERIFIED_SOURCE_SINK_TIMING",
                     "UNVERIFIED_INCOMPLETE_HORIZON"}
PROBLEM_STATES = {"OPEN_UNEXPLAINED", "MALFORMED_EVIDENCE"}

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
    """Signed per-species Water accounting (lcb-signed-ledger-v4).

    Every quantity is bound to the declared initial ledger and inventory; the
    first checkpoint is validated against them, never substituted for them.

    Species domain: every non-Water species in the inventory, Brine when Salt is
    present, and every key in any supplied observation. A species absent from
    the inventory is declared at 0. Every domain key must be observed at every
    checkpoint; a species outside a supported reaction must stay constant.

    Reactions: a reactive species is active only if its observed count changes
    (or, without species evidence, if its declared count is positive). Supplied
    species evidence is always evaluated before any constant-Water closure; only
    a Salt-only active set has a complete signed ledger, anything else with an
    active reaction is UNVERIFIED.

    Explicit sources/sinks close exactly only against timed per-event amounts
    (ledger["events"]: [{"tick", "source" | "sink"}], in application order; an
    event indexed N is first observed at completed tick N+1). Every counted event
    must lie inside the observed horizon, and the cumulative Water balance must
    stay non-negative after every event. Aggregate-only totals reject impossible
    directions and gross budgets but cannot establish closure.

    A closed state always has a zero final signed delta. Only CLOSED_STATES are
    eligible for acceptance.
    """
    cells = inventory.get("cells", {})
    w0, src, sink = ledger.get("initial_integer"), ledger.get("explicit_source"), ledger.get("explicit_sink")
    base = {"rule": LEDGER_RULE, "initial": w0, "explicit_source": src, "explicit_sink": sink}

    def result(state, reason, **extra):
        if state in ("closed", "closed_timed_source_sink"):
            # Without an active reaction, Water changes only through explicit sources/sinks.
            assert base.get("signed_delta") == 0, "a closed source/sink ledger must have a zero final signed delta"
        return {"state": state, "eligible_for_acceptance": state in CLOSED_STATES, "reason": reason, **base, **extra}

    def nonneg(v):
        return isinstance(v, int) and not isinstance(v, bool) and v >= 0

    # 1. Structure.
    if not (nonneg(w0) and nonneg(src) and nonneg(sink)):
        return result("MALFORMED_EVIDENCE", "initial, source and sink must be non-negative integers")
    if not all(nonneg(v) for v in cells.values()):
        return result("MALFORMED_EVIDENCE", "inventory cell counts must be non-negative integers")
    if not checkpoints:
        return result("MALFORMED_EVIDENCE", "no checkpoints")
    ticks = [c.get("tick") for c in checkpoints]
    if not all(nonneg(t) for t in ticks) or ticks[0] != 0 or any(b <= a for a, b in zip(ticks, ticks[1:])):
        return result("MALFORMED_EVIDENCE", "checkpoint ticks must start at 0 and strictly increase")
    if not all(nonneg(c.get("water_integer")) for c in checkpoints):
        return result("MALFORMED_EVIDENCE", "every checkpoint needs a non-negative water_integer")
    series = [(c["tick"], c["water_integer"]) for c in checkpoints]
    horizon, final = series[-1]
    base.update(final_world_water=final, signed_delta=final - (w0 + src - sink))

    events = ledger.get("events")
    if events is not None:
        for e in events:
            amounts = (e.get("source", 0), e.get("sink", 0))
            if not (nonneg(e.get("tick")) and all(nonneg(a) for a in amounts)) or set(e) - {"tick", "source", "sink"}:
                return result("MALFORMED_EVIDENCE", "timed events need a non-negative tick and source or sink")
            if amounts[0] and amounts[1]:
                return result("MALFORMED_EVIDENCE", "a timed event records a source or a sink, not both")
        if any(b["tick"] < a["tick"] for a, b in zip(events, events[1:])):
            return result("MALFORMED_EVIDENCE", "timed events must be listed in application order (non-decreasing "
                                                "tick; same-tick events in the order the host applied them)")
        if (sum(e.get("source", 0) for e in events), sum(e.get("sink", 0) for e in events)) != (src, sink):
            return result("MALFORMED_EVIDENCE", "timed source/sink events do not sum to the declared totals")

    species = [c.get("species") for c in checkpoints]
    if any(s is not None for s in species):
        if any(not isinstance(s, dict) for s in species):
            return result("MALFORMED_EVIDENCE", "species counts are present at some checkpoints but not all")
        if any("water" in s for s in species):
            return result("MALFORMED_EVIDENCE", "Water is accounted by water_integer, not as a species count")
        domain = sorted((set(cells) - {"water"}) | ({"brine"} if "salt" in cells else set())
                        | set().union(*(set(s) for s in species)))
        for tick, s in zip(ticks, species):
            missing = [k for k in domain if k not in s]
            if missing:
                return result("MALFORMED_EVIDENCE", f"species {missing} not observed at tick {tick}; a missing "
                                                    "observation is never treated as unchanged")
            if not all(nonneg(v) for v in s.values()):
                return result("MALFORMED_EVIDENCE", f"negative or non-integer species count at tick {tick}")
    else:
        species, domain = None, []
    base["species_domain"] = domain

    # 2. Binding to the declared initial state.
    declared = inventory.get("water_integer")
    if declared is not None and declared != w0:
        return result("OPEN_UNEXPLAINED", f"ledger initial {w0} differs from the declared inventory {declared}")
    if series[0][1] != w0:
        return result("OPEN_UNEXPLAINED", f"tick-0 Water {series[0][1]} differs from the declared initial {w0}",
                      initial_discrepancy=series[0][1] - w0)
    if species is not None:
        off = {k: (species[0][k], cells.get(k, 0)) for k in domain if species[0][k] != cells.get(k, 0)}
        if off:
            return result("OPEN_UNEXPLAINED", "tick-0 species counts differ from the declared inventory "
                          "(a species absent from the inventory is declared 0)", initial_species_discrepancy=off)

    # 3. Active reactions. With species evidence, a reactive species is active
    # only if its observed count changes; without it, if its declared count is
    # positive. Zero-count species never open a reaction route.
    if species is not None:
        active = sorted(k for k in REACTIVE & set(domain) if len({s[k] for s in species}) > 1)
        changed = sorted(k for k in domain if len({s[k] for s in species}) > 1)
    else:
        active = sorted(k for k in REACTIVE if cells.get(k, 0) > 0)
        changed = []
    base["active_reactions"] = active
    deltas = [(a[0], b[0], b[1] - a[1]) for a, b in zip(series, series[1:])]

    # 4. Species evidence is evaluated before any constant-Water closure.
    if species is not None:
        if not active:
            unexplained = changed
            if unexplained:
                return result("OPEN_UNEXPLAINED", f"species {unexplained} changed with no active reaction",
                              changed_species=unexplained)
        elif active == ["salt"]:
            outside = [k for k in changed if k not in ("salt", "brine")]
            if outside:
                return result("OPEN_UNEXPLAINED", f"species {outside} changed outside Water+Salt->Brine+Brine",
                              changed_species=outside)
            if src or sink:
                return result("UNVERIFIED_REACTION_AMOUNT", "Salt dissolution and explicit source/sink overlap; "
                              "per-event attribution is not established")
            return _salt_species_ledger(result, cells, w0, series, species)
        else:
            return result("UNVERIFIED_REACTION_AMOUNT", f"active reactions {active} have no complete signed "
                          "ledger in this rule; the reaction amounts are not established", changed_species=changed)
    elif active and active != ["salt"]:
        return result("UNVERIFIED_REACTION_AMOUNT", f"active reactions {active} without species evidence; "
                      "neither sign nor amount is established, even if Water is constant",
                      checkpoint_gains=[d for d in deltas if d[2] > 0])
    elif active:
        if src or sink:
            return result("UNVERIFIED_REACTION_AMOUNT", "reaction and explicit source/sink overlap; no "
                          "per-reaction amounts are retained")
        if any(w != w0 for _, w in series):
            gains = [d for d in deltas if d[2] > 0]
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
        # Constant Water with Salt only and no species evidence: any dissolution
        # would have removed Water, so none occurred. Falls through to step 5.

    # 5. No active reaction: Water changes only through explicit sources/sinks.
    if events is not None:
        return _timed_source_sink(result, w0, series, events, horizon)
    if src == 0 and sink == 0:
        off = [(t, w - w0) for t, w in series if w != w0]
        if off:
            return result("OPEN_UNEXPLAINED", "Water differs from the initial value with no source, sink or "
                          "active reaction", deviations=off)
        return result("closed", "Water constant at every checkpoint; no source, sink or active reaction")
    return _aggregate_source_sink(result, w0, src, sink, final, deltas)


def _timed_source_sink(result, w0, series, events, horizon) -> dict:
    """Timed per-event amounts: horizon coverage, chronological balance, every checkpoint."""
    beyond = [e for e in events if e["tick"] >= horizon]
    if beyond:
        return result("UNVERIFIED_INCOMPLETE_HORIZON", f"{len(beyond)} counted event(s) at or after the last "
                      f"completed checkpoint t{horizon} are not observed (an event indexed N is first observed at "
                      "completed N+1); the declared totals cannot be reconciled", unobserved_events=beyond)
    balance, prefix = w0, []
    for e in events:
        balance += e.get("source", 0) - e.get("sink", 0)
        prefix.append((e["tick"], balance))
        if balance < 0:
            return result("OPEN_UNEXPLAINED", f"the event at tick {e['tick']} removes more Water than exists "
                          f"(implied balance {balance})", event_prefix=prefix)
    expected = [w0 + sum(e.get("source", 0) - e.get("sink", 0) for e in events if e["tick"] < t) for t, _ in series]
    off = [(t, w - x) for (t, w), x in zip(series, expected) if w != x]
    if off:
        return result("OPEN_UNEXPLAINED", "Water differs from the timed source/sink ledger", deviations=off)
    if series[-1][1] != w0 + sum(e.get("source", 0) - e.get("sink", 0) for e in events):
        return result("OPEN_UNEXPLAINED", "final Water does not equal initial + source - sink")
    return result("closed_timed_source_sink" if events else "closed",
                  "Water equals initial + timed sources - timed sinks at every checkpoint; every event observed "
                  "and the chronological balance never negative")


def _aggregate_source_sink(result, w0, src, sink, final, deltas) -> dict:
    """Aggregate-only source/sink totals (no event timing): never closed."""
    gains = sum(d for _, _, d in deltas if d > 0)
    losses = -sum(d for _, _, d in deltas if d < 0)
    detail = {"positive_increments": gains, "negative_increments": losses}
    if src == 0 and gains:
        return result("OPEN_UNEXPLAINED", "Water gain with no declared source", **detail)
    if sink == 0 and losses:
        return result("OPEN_UNEXPLAINED", "Water loss with no declared sink", **detail)
    if gains > src:
        return result("OPEN_UNEXPLAINED", f"positive increments {gains} exceed the declared source {src}", **detail)
    if losses > sink:
        return result("OPEN_UNEXPLAINED", f"negative increments {losses} exceed the declared sink {sink}", **detail)
    if final != w0 + src - sink:
        return result("OPEN_UNEXPLAINED", "final Water does not equal initial + source - sink", **detail)
    return result("UNVERIFIED_SOURCE_SINK_TIMING", "directions and gross budgets are consistent and the final "
                  "balance closes, but without per-event source/sink timing the intermediate checkpoints "
                  "cannot be reconciled", **detail)


def _salt_species_ledger(result, cells, w0, series, species) -> dict:
    """Water+Salt->Brine+Brine against the declared initial state; every other species constant."""
    salt0, brine0 = cells.get("salt", 0), cells.get("brine", 0)
    rows, partial, last = [], False, None
    for (tick, w), sp in zip(series, species):
        s = salt0 - sp["salt"]
        dw, db = w - w0, sp["brine"] - brine0
        rows.append({"tick": tick, "salt_consumed": s, "brine_delta": db, "water_delta": dw})
        if s < 0 or (last is not None and s < last[0]):
            return result("OPEN_UNEXPLAINED", "Salt reappeared", species_ledger=rows)
        if db != 2 * s:
            return result("OPEN_UNEXPLAINED", "Brine delta is not exactly 2 x consumed Salt", species_ledger=rows)
        if not -FULL_WATER * s <= dw <= -s:
            return result("OPEN_UNEXPLAINED", "Water delta outside [-255 s, -s] for consumed Salt s",
                          species_ledger=rows)
        if last is not None and s == last[0] and w != last[1]:
            return result("OPEN_UNEXPLAINED", "Water changed after dissolution stopped", species_ledger=rows)
        partial |= dw != -FULL_WATER * s
        last = (s, w)
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
        if not parity or case.get("ledger", {}).get("state") in PROBLEM_STATES or w1.get("status") != "completed":
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


def reledger_v2() -> dict:
    """The historical v2 record, regenerated only by its frozen reducer (check-only)."""
    return ledger_v2_historical.reledger(CONTROLS, ROOT, load, lf_sha256, inventories)


def reledger_v3() -> dict:
    """The historical v3 record, regenerated only by its frozen reducer (check-only)."""
    return ledger_v3_historical.reledger(CONTROLS, LEDGER_V2, PROTECTED_MANIFEST, ROOT, load, lf_sha256,
                                         inventories, catalogue.__file__)


def reledger() -> dict:
    """Re-reduce the retained (immutable) 2026-10-23 controls with lcb-signed-ledger-v4."""
    controls = load(CONTROLS)
    v2, v3 = load(LEDGER_V2)["cases"], load(LEDGER_V3)["cases"]
    inv = inventories()
    cases = {}
    for sid, case in controls["cases"].items():
        if "ledger" not in case:
            continue
        old = case["ledger"]
        ledger = {"initial_integer": old["initial"], "explicit_source": old["explicit_source"],
                  "explicit_sink": old["explicit_sink"]}
        new = signed_ledger(inv[sid], ledger, case["checkpoints"])
        cases[sid] = {"superseded_states": {"controls_2026_10_23": old["state"],
                                            "lcb-signed-ledger-v2": v2[sid]["state"],
                                            "lcb-signed-ledger-v3": v3[sid]["state"]}, **new}
    return {
        "schema": "lcb-scenario-ledger-v4",
        "date": "2026-10-23",
        "rule": LEDGER_RULE,
        "status": "Corrected accounting reduction of retained characterization data (re-review R1-R4). The "
                  "historical controls file and the v2/v3 records are preserved unchanged and stay verifiable "
                  "against their frozen reducers; this record supersedes only their ledger classification. "
                  "Characterization only: accepted evidence remains the CI-re-executed prefixes.",
        "input": {"controls_file": CONTROLS.relative_to(ROOT).as_posix(), "controls_sha256_lf": lf_sha256(CONTROLS),
                  "controls_source_commit": controls["source_commit"],
                  "superseded_records": {LEDGER_V2.relative_to(ROOT).as_posix(): lf_sha256(LEDGER_V2),
                                         LEDGER_V3.relative_to(ROOT).as_posix(): lf_sha256(LEDGER_V3)},
                  "reducer": "tools/lcb/lcb_registry.py::signed_ledger",
                  "reducer_sha256_lf": lf_sha256(Path(__file__)),
                  "catalogue_tool_sha256_lf": lf_sha256(Path(catalogue.__file__)),
                  "protected_manifest_sha256_lf": lf_sha256(PROTECTED_MANIFEST)},
        "evidence_limits": "The campaign retained world Water integers per checkpoint, aggregate explicit "
                           "source/sink totals and windowed observations. It retained no world-wide per-species "
                           "counts, no per-reaction log and no per-event source/sink timing, so reactive cases "
                           "and cases with explicit sources/sinks cannot be closed from this record. R1-R4 concern "
                           "species and timed-event evidence that this campaign did not supply.",
        "open_unexplained_or_malformed": sorted(s for s, c in cases.items() if c["state"] in PROBLEM_STATES),
        "accounting_unverified_ineligible_for_acceptance": sorted(
            s for s, c in cases.items() if c["state"] in UNVERIFIED_STATES),
        "changed_from_v3": sorted(s for s, c in cases.items()
                                  if c["state"] != c["superseded_states"]["lcb-signed-ledger-v3"]),
        "cases": cases,
    }


def reledger_cmd(args) -> int:
    path, build = {"v2": (LEDGER_V2, reledger_v2), "v3": (LEDGER_V3, reledger_v3),
                   "v4": (LEDGER_V4, reledger)}[args.version]
    text = json.dumps(build(), indent=2) + "\n"
    if args.check:
        current = path.read_text(encoding="utf-8").replace("\r\n", "\n") if path.exists() else ""
        if current != text:
            print(f"stale or altered ledger record {path.relative_to(ROOT)}", file=sys.stderr)
            return 1
        print(f"{path.name} matches the retained controls and its reducer")
        return 0
    if args.version != "v4" or path.exists():
        print(f"refusing to overwrite dated evidence {path.relative_to(ROOT)}", file=sys.stderr)
        return 1
    path.write_bytes(text.encode("utf-8"))
    print(f"wrote {path.relative_to(ROOT)}")
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
                                      "ledger_file": LEDGER_V4.relative_to(ROOT).as_posix()}
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
    ledgers = load(LEDGER_V4)["cases"] if LEDGER_V4.exists() else {}
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
                    "ledger_v4": lf_sha256(LEDGER_V4) if LEDGER_V4.exists() else None,
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
    g.add_argument("--version", choices=["v4", "v3", "v2"], default="v4")
    b = sub.add_parser("build")
    b.add_argument("--check", action="store_true")
    args = parser.parse_args()
    return {"reduce": reduce_cmd, "reledger": reledger_cmd, "build": build_cmd}[args.cmd](args)


if __name__ == "__main__":
    raise SystemExit(main())
