#!/usr/bin/env python3
"""Reduce LCB suite results and build the source-derived scenario registry.

Standard-library only.

  reduce  --w1 DIR --w4 DIR --out FILE   reduce one campaign into a dated controls
                                          file (refuses to overwrite: evidence is immutable)
  reledger [--check] [--version v7|v6|v5|v4|v3|v2]
                                          re-reduce the retained 2026-10-23 controls into the
                                          versioned v7 record; v2-v7 are check-only: each is
                                          replayed by its own producer at its recorded revision
                                          in an isolated snapshot (H4)
  build   [--check]                       write/check godot/tests/fixtures/lcb/lcb-scenario-registry.json

The registry is consumed by the LCB-003 UI (Claude D / #202) and by
test_lcb_scenario_catalogue.gd. It never marks an arm runnable unless that arm
actually executed; every other arm carries its blocking dependency.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import subprocess
import sys
import tarfile
import tempfile
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
LEDGER_V3 = ROOT / "docs/reference/lcb-scenario-ledger-2026-10-23.v3.json"
LEDGER_V4 = ROOT / "docs/reference/lcb-scenario-ledger-2026-10-23.v4.json"
LEDGER_V5 = ROOT / "docs/reference/lcb-scenario-ledger-2026-10-23.v5.json"
LEDGER_V6 = ROOT / "docs/reference/lcb-scenario-ledger-2026-10-23.v6.json"
LEDGER_V7 = ROOT / "docs/reference/lcb-scenario-ledger-2026-10-23.v7.json"
LEDGER_RULE = "lcb-signed-ledger-v7"
# Each retained record and the revision whose own producer wrote it (H4).
# v7 still owns the latest accounting semantics; unrelated live-registry edits
# must not rewrite its dated whole-file producer identity.
# Verification replays that producer in an isolated snapshot of its revision,
# so current catalogue, loader or manifest changes cannot alter or break it.
HISTORICAL_LEDGERS = {
    "v2": ("13747d494dea43dcf259dc910ec0b1404e958a43", LEDGER_V2),
    "v3": ("b9b36c9d3de60f9241f5dc3eb09783fe0743f79c", LEDGER_V3),
    "v4": ("b2d522299db1664548b82046b9dec8b63cc08bae", LEDGER_V4),
    "v5": ("3248bf3b076f06a76d50582afdf1b95fe04a82dd", LEDGER_V5),
    "v6": ("db3fa22e1d9ec0d4e5f96ae7941cb110a29daee0", LEDGER_V6),
    "v7": ("e0d26fdf1ae6889fcc75325ce5e9018a95841945", LEDGER_V7),
}
SNAPSHOT_PATHS = ("tools/lcb", "docs/reference", "godot/tests/fixtures/lcb")
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
    "cellular_yield_v1": ("native whole-cell Water CY exists; this registered apparatus arm has no source-matched execution",
                          ["#213 LCB-000 PASS", "#200"]),
    "pressure_flow_v1": ("native Water pressure reference/cached/dormant exist; this registered apparatus arm has no source-matched execution",
                         ["#213 LCB-000 PASS", "#200", "#201 (cached, cached_dormant)"]),
    "inertial_cellular_v1": ("native Brine IN and isolated whole-cell Water IN exist; this registered apparatus arm has no source-matched execution",
                             ["#200 per-material policy", "#212"]),
}


def lf_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def _unique_pairs(pairs: list) -> dict:
    names = [k for k, _ in pairs]
    duplicates = sorted({k for k in names if names.count(k) > 1})
    if duplicates:
        raise ValueError(f"duplicate JSON object names {duplicates}")
    return dict(pairs)


def load(path: Path):
    """Strict JSON: duplicate object names are rejected, never last-value-wins (G4)."""
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_unique_pairs)


def _is_int(v) -> bool:
    return isinstance(v, int) and not isinstance(v, bool)


def report_shape_problems(report: dict) -> list:
    """Every report field the reducer reads, validated before use (I1).

    Observation values are integers (water_integer, material_cells, tick) or
    objects (cell_state), as the host emits them; ids are unique strings.
    """
    problems = []
    capture = report.get("capture")
    if "capture" in report and not isinstance(capture, dict):
        return ["capture is not an object"]
    capture = capture or {}
    items = capture.get("observations", [])
    if not isinstance(items, list):
        problems.append("capture.observations is not a list")
    else:
        ids = []
        for i, o in enumerate(items):
            if not isinstance(o, dict) or not isinstance(o.get("id"), str) or "value" not in o:
                problems.append(f"capture.observations[{i}] needs a string id and a value")
            elif not (_is_int(o["value"]) or isinstance(o["value"], dict)):
                problems.append(f"capture.observations[{i}] value must be an integer or an object")
            else:
                ids.append(o["id"])
        if len(ids) != len(set(ids)):
            problems.append("capture.observations has duplicate ids")
    timing = capture.get("timing")
    if "timing" in capture and not isinstance(timing, dict):
        problems.append("capture.timing is not an object")
    elif isinstance(timing, dict) and not all(v is None or (isinstance(v, (int, float)) and not isinstance(v, bool))
                                              for v in timing.values()):
        problems.append("capture.timing values must be numbers or null")
    if "runtime_identity" in capture and not isinstance(capture["runtime_identity"], dict):
        problems.append("capture.runtime_identity is not an object")
    if "checkpoints" in report and not isinstance(report["checkpoints"], list):
        problems.append("checkpoints is not a list")
    return problems


def load_report(path: Path) -> tuple[dict, str]:
    """A campaign report, or a structured refusal; a malformed report never aborts the reduction."""
    try:
        report = load(path)
    except (OSError, ValueError) as error:
        return {"status": "malformed_report"}, f"{path.name}: {error}"
    if not isinstance(report, dict):
        return {"status": "malformed_report"}, f"{path.name}: report is not an object"
    problems = report_shape_problems(report)
    if problems:
        return {"status": "malformed_report"}, f"{path.name}: " + "; ".join(problems)
    return report, ""


def capture_of(result: dict) -> dict:
    capture = result.get("capture")
    return capture if isinstance(capture, dict) else {}


def observations(result: dict) -> dict:
    items = capture_of(result).get("observations", [])
    return {o["id"]: o["value"] for o in items if isinstance(o, dict) and "id" in o} if isinstance(items, list) else {}


def report_identity(sid: str, w1: dict, w4: dict, expected_hash, expected_horizon, source_sha: str) -> dict:
    """Bind a 1/4-worker report pair to the requested scenario, definition, horizon and source (G3)."""
    checks = {}
    identities = {}
    for name, report, workers in (("w1", w1, 1), ("w4", w4, 4)):
        identity = capture_of(report).get("runtime_identity")
        identities[name] = identity if isinstance(identity, dict) else {}
        checks[f"{name}_id"] = report.get("id") == sid
        checks[f"{name}_workers"] = report.get("workers") == workers
        checks[f"{name}_definition_hash"] = expected_hash is not None and report.get("definition_hash") == expected_hash
        checks[f"{name}_horizon"] = expected_horizon is not None and report.get("horizon") == expected_horizon
        checks[f"{name}_source_revision"] = identities[name].get("source_revision") == source_sha
    for key in ("native_sha256", "godot", "script_set_sha256", "platform"):
        value = identities["w1"].get(key)
        checks[f"runtime_{key}_equal"] = value not in (None, "", "unavailable") and value == identities["w4"].get(key)
    return {"ok": all(checks.values()), "failed": sorted(k for k, v in checks.items() if not v)}


def derived(meta: dict, obs: dict) -> dict:
    obs = {k: v for k, v in obs.items() if _is_int(v)}  # object-valued observations carry no scalar
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
    """Signed per-species Water accounting (rule lcb-signed-ledger-v7).

    The accounting body is unchanged from v6. v7 adds campaign report-shape
    validation in load_report (I1), so the reducer identity and record version
    changed.

    Structure (F3/G1/G2): inventory and ledger must be objects and checkpoints a
    list of objects; cells/species are objects keyed by material name; a present
    inventory water_integer is a non-negative integer; a present events value is a
    list (an explicit null is malformed; omit the key for aggregate-only
    evidence); a present species value is an object. Malformed inputs return
    MALFORMED_EVIDENCE and never raise.

    Every quantity is bound to the declared initial ledger and inventory; the
    first checkpoint is validated against them, never substituted for them.

    Species domain: every non-Water species in the inventory, every key in any
    supplied observation, and Brine whenever Salt is declared or observed (F1),
    so the Salt ledger is never dispatched without complete Brine evidence. A species absent from
    the inventory is declared at 0. Every domain key must be observed at every
    checkpoint; a species outside a supported reaction must stay constant.

    Reactions: a reactive species is active only if its observed count changes
    (or, without species evidence, if its declared count is positive). Supplied
    species evidence is always evaluated before any constant-Water closure; only
    a Salt-only active set has a complete signed ledger, anything else with an
    active reaction is UNVERIFIED.

    Explicit sources/sinks close exactly only against timed per-event amounts
    (ledger["events"]: [{"tick", exactly one of "source" | "sink"}] by key presence
    (F2; an explicit 0 under one key is valid), in application order; an
    event indexed N is first observed at completed tick N+1). Every counted event
    must lie inside the observed horizon, and the cumulative Water balance must
    stay non-negative after every event. Aggregate-only totals reject impossible
    directions and gross budgets but cannot establish closure.

    The event horizon applies on every route, reaction closures included (F4).
    A closed source/sink state always has a zero final signed delta. Only
    CLOSED_STATES are eligible for acceptance.
    """
    base = {"rule": LEDGER_RULE}

    def result(state, reason, **extra):
        if state in ("closed", "closed_timed_source_sink"):
            # Without an active reaction, Water changes only through explicit sources/sinks.
            assert base.get("signed_delta") == 0, "a closed source/sink ledger must have a zero final signed delta"
        return {"state": state, "eligible_for_acceptance": state in CLOSED_STATES, "reason": reason, **base, **extra}

    def nonneg(v):
        return isinstance(v, int) and not isinstance(v, bool) and v >= 0

    # 1. Structure: every root, item and key is type-checked before use (F3/G1/G2).
    if not isinstance(inventory, dict) or not isinstance(ledger, dict) or not isinstance(checkpoints, list):
        return result("MALFORMED_EVIDENCE", "inventory and ledger must be objects and checkpoints a list")
    w0, src, sink = ledger.get("initial_integer"), ledger.get("explicit_source"), ledger.get("explicit_sink")
    base.update(initial=w0, explicit_source=src, explicit_sink=sink)
    cells = inventory.get("cells", {})
    if not isinstance(cells, dict) or not all(isinstance(k, str) for k in cells):
        return result("MALFORMED_EVIDENCE", "inventory cells must be an object keyed by material name")
    if "water_integer" in inventory and not nonneg(inventory["water_integer"]):
        return result("MALFORMED_EVIDENCE", "inventory water_integer, when present, must be a non-negative integer")
    if not (nonneg(w0) and nonneg(src) and nonneg(sink)):
        return result("MALFORMED_EVIDENCE", "initial, source and sink must be non-negative integers")
    if not all(nonneg(v) for v in cells.values()):
        return result("MALFORMED_EVIDENCE", "inventory cell counts must be non-negative integers")
    if not checkpoints:
        return result("MALFORMED_EVIDENCE", "no checkpoints")
    if not all(isinstance(c, dict) for c in checkpoints):
        return result("MALFORMED_EVIDENCE", "every checkpoint must be an object")
    ticks = [c.get("tick") for c in checkpoints]
    if not all(nonneg(t) for t in ticks) or ticks[0] != 0 or any(b <= a for a, b in zip(ticks, ticks[1:])):
        return result("MALFORMED_EVIDENCE", "checkpoint ticks must start at 0 and strictly increase")
    if not all(nonneg(c.get("water_integer")) for c in checkpoints):
        return result("MALFORMED_EVIDENCE", "every checkpoint needs a non-negative water_integer")
    series = [(c["tick"], c["water_integer"]) for c in checkpoints]
    horizon, final = series[-1]
    base.update(final_world_water=final, signed_delta=final - (w0 + src - sink))

    events = ledger["events"] if "events" in ledger else None
    if "events" in ledger and not isinstance(events, list):
        return result("MALFORMED_EVIDENCE", "ledger events, when present, must be a list (null, objects, strings, "
                                            "numbers and booleans are malformed; omit the key for aggregate-only "
                                            "evidence)")
    if events is not None:
        for e in events:
            if not isinstance(e, dict) or set(e) - {"tick", "source", "sink"}:
                return result("MALFORMED_EVIDENCE", "timed events may only carry tick, source and sink")
            keys = [k for k in ("source", "sink") if k in e]
            if len(keys) != 1:
                return result("MALFORMED_EVIDENCE", "a timed event records exactly one of source or sink (by key "
                                                    f"presence, whatever the amount); found {keys or 'neither'}")
            if not (nonneg(e.get("tick")) and nonneg(e[keys[0]])):
                return result("MALFORMED_EVIDENCE", "timed events need a non-negative integer tick and amount")
        if any(b["tick"] < a["tick"] for a, b in zip(events, events[1:])):
            return result("MALFORMED_EVIDENCE", "timed events must be listed in application order (non-decreasing "
                                                "tick; same-tick events in the order the host applied them)")
        if (sum(e.get("source", 0) for e in events), sum(e.get("sink", 0) for e in events)) != (src, sink):
            return result("MALFORMED_EVIDENCE", "timed source/sink events do not sum to the declared totals")

    species = [c.get("species") for c in checkpoints]
    if any("species" in c for c in checkpoints):
        if any(not isinstance(s, dict) for s in species):
            return result("MALFORMED_EVIDENCE", "species counts must be an object at every checkpoint (absent at "
                                                "some checkpoints, or null)")
        if not all(isinstance(k, str) for s in species for k in s):
            return result("MALFORMED_EVIDENCE", "species counts must be keyed by material name")
        if any("water" in s for s in species):
            return result("MALFORMED_EVIDENCE", "Water is accounted by water_integer, not as a species count")
        observed = set().union(*(set(s) for s in species))
        domain = sorted((set(cells) - {"water"}) | observed
                        | ({"brine"} if "salt" in cells or "salt" in observed else set()))
        base["species_domain"] = domain
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

    # 2b. Every counted event must be observed, on every route (F4): an event
    # indexed N is first observed at completed tick N+1.
    if events is not None:
        beyond = [e for e in events if e["tick"] >= horizon]
        if beyond:
            return result("UNVERIFIED_INCOMPLETE_HORIZON", f"{len(beyond)} counted event(s) at or after the last "
                          f"completed checkpoint t{horizon} are not observed (an event indexed N is first observed "
                          "at completed N+1); the declared totals cannot be reconciled", unobserved_events=beyond)

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
    pinned = {e["id"]: e["definition"]["canonical_hash"] for e in load(REGISTRY)["scenarios"]} \
        if REGISTRY.exists() else {}
    cases, problems, unverified, ineligible = {}, [], [], []
    for path in sorted(Path(args.w1).glob("*-w1.json")):
        sid = path.name[:-len("-w1.json")]
        if sid.startswith("summary"):
            continue
        w4path = Path(args.w4) / f"{sid}-w4.json"
        w1, w1_error = load_report(path)
        w4, w4_error = load_report(w4path) if w4path.exists() else ({"status": "missing"}, "")
        both = w1.get("status") == "completed" and w4.get("status") == "completed"

        def hashes(report):
            points = report.get("checkpoints")
            return [(c.get("tick"), c.get("content_hash"), c.get("state_hash")) for c in points
                    if isinstance(c, dict)] if isinstance(points, list) else None
        if sid in metas:
            meta = metas[sid]
            expected_hash, expected_horizon = pinned.get(sid), meta.get("horizon_ticks")
        elif sid in protected:
            definition = load(ROOT / protected[sid]["path"])
            meta = {"id": sid, "category": "protected-reference",
                    "initial_inventory": catalogue.inventory_of(definition["rectangles"], definition["partial_water_fills"],
                                                                definition["water_semantics"])}
            expected_hash, expected_horizon = protected[sid]["definition_hash"], protected[sid]["horizon_ticks"]
        else:
            meta, expected_hash, expected_horizon = {"id": sid, "initial_inventory": {}}, None, None
        identity = report_identity(sid, w1, w4, expected_hash, expected_horizon, args.source_sha)
        same = both and observations(w1) == observations(w4) and hashes(w1) is not None and hashes(w1) == hashes(w4)
        parity = ("identical" if same and identity["ok"] else "IDENTITY_MISMATCH" if same
                  else "MISMATCH" if both else "not_comparable")
        case = {
            "status": {"w1": w1.get("status"), "w4": w4.get("status")},
            "errors": {k: v for k, v in (("w1", w1_error or w1.get("error", "")), ("w4", w4_error or w4.get("error", "")))
                       if v},
            "parity_1_vs_4_workers": parity,
            "report_identity": identity,
            "definition_hash": w1.get("definition_hash"),
            "horizon": w1.get("horizon"),
            "outcome": capture_of(w1).get("outcome"),
            "observations": observations(w1),
            "checkpoints": w1.get("checkpoints", []) if isinstance(w1.get("checkpoints"), list) else [],
            "work": {"w1": w1.get("work"), "w4": w4.get("work")},
            "timing_ms_characterization_only": {
                k: {m: (capture_of(v).get("timing") or {}).get(m) for m in ("p50_ms", "p95_ms", "max_ms")}
                for k, v in (("w1", w1), ("w4", w4))},
            "report_sha256": {"w1": hashlib.sha256(path.read_bytes()).hexdigest(),
                              "w4": hashlib.sha256(w4path.read_bytes()).hexdigest() if w4path.exists() else None},
        }
        if w1.get("status") == "completed":
            case["ledger"] = signed_ledger(meta.get("initial_inventory", {}), capture_of(w1).get("water_ledger"),
                                           w1.get("checkpoints"))
            case["derived"] = derived(meta, case["observations"])
        if sid in protected:
            accepted = protected[sid]["arms"][0]["control"]
            case["protected_reproduction"] = {
                "accepted_definition_hash": protected[sid]["definition_hash"],
                "observations_match": accepted["observations"] == case["observations"],
                "final_hashes_match": (accepted["final"]["content_hash"], accepted["final"]["state_hash"])
                == (case["checkpoints"][-1]["content_hash"], case["checkpoints"][-1]["state_hash"]) if case["checkpoints"] else False,
            }
        # Orthogonal summaries (G5): a case can be a problem and also unverified.
        state = case.get("ledger", {}).get("state")
        if parity != "identical" or state in PROBLEM_STATES or w1.get("status") != "completed":
            problems.append(sid)
        if state in UNVERIFIED_STATES:
            unverified.append(sid)
        if sid in problems or not case.get("ledger", {}).get("eligible_for_acceptance"):
            ineligible.append(sid)  # complete: problems (incl. identity) and ineligible ledgers
        cases[sid] = case
    loaded = [load_report(p)[0] for p in sorted(Path(args.w1).glob("*-w1.json"))]
    any_w1 = next((r for r in loaded if isinstance(capture_of(r).get("runtime_identity"), dict)),
                  {"capture": {"runtime_identity": {}}})
    result = {
        "schema": "lcb-scenario-controls-v1",
        "date": args.date,
        "scope": "Current native defaults only; controlled fixed-tick native-only runs; no player, Rapier, render or Web",
        "platform": args.platform,
        "source_commit": args.source_sha,
        "runtime": {k: capture_of(any_w1)["runtime_identity"].get(k)
                    for k in ("native_sha256", "godot", "script_set_sha256")},
        "runner": "godot/tests/run_lcb_scenario_suite.gd + godot/tests/lcb_scenario_runner.gd",
        "ledger_rule": LEDGER_RULE,
        "problems": problems,
        "accounting_unverified_ineligible_for_acceptance": unverified,
        "ineligible_for_acceptance": ineligible,
        "cases": cases,
    }
    out.write_bytes((json.dumps(result, indent=2) + "\n").encode("utf-8"))
    print(f"wrote {out} with {len(cases)} cases; problems={problems}")
    return 0


def inventories() -> dict:
    out = {s.id: s.metadata()["initial_inventory"] for s in catalogue.build()}
    for fixture in load(PROTECTED_MANIFEST)["fixtures"]:
        definition = load(ROOT / fixture["path"])
        out[fixture["id"]] = catalogue.inventory_of(definition["rectangles"], definition["partial_water_fills"],
                                                     definition["water_semantics"])
    return out


def verify_historical(version: str) -> tuple[bool, list]:
    """Verify a retained record against its own producer at its recorded revision (H4).

    1. The current file must equal, byte for byte after LF normalization, the
       record as committed at that revision.
    2. That revision's own `lcb_registry.py reledger --check` is replayed in an
       isolated snapshot of its tools, references and fixtures, so the producer,
       inventories, loader and manifests are all historical. Nothing is written
       to the working tree. Requires full Git history.
    """
    commit, path = HISTORICAL_LEDGERS[version]
    rel = path.relative_to(ROOT).as_posix()
    notes = []

    def git(*args, **kw):
        return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, timeout=120, **kw)
    if git("cat-file", "-e", f"{commit}^{{commit}}").returncode != 0:
        return False, [f"revision {commit} unavailable (full Git history is required)"]
    published = git("show", f"{commit}:{rel}")
    if published.returncode != 0:
        return False, [f"{rel} absent at {commit}"]
    if published.stdout.replace(b"\r\n", b"\n") != path.read_bytes().replace(b"\r\n", b"\n"):
        return False, [f"{rel} differs from the record published at {commit[:7]}"]
    notes.append(f"{rel} equals the record published at {commit[:7]}")
    archive = git("archive", "--format=tar", commit, "--", *SNAPSHOT_PATHS)
    if archive.returncode != 0:
        return False, notes + [f"git archive failed at {commit[:7]}"]
    with tempfile.TemporaryDirectory(prefix=f"lcb-ledger-{version}-") as tmp:
        with tarfile.open(fileobj=io.BytesIO(archive.stdout)) as tar:
            tar.extractall(tmp, filter="data")
        replay = subprocess.run([sys.executable, "-B", "tools/lcb/lcb_registry.py", "reledger", "--check"],
                                cwd=tmp, capture_output=True, text=True, timeout=120)
    if replay.returncode != 0:
        return False, notes + [f"producer replay at {commit[:7]} failed: {(replay.stderr or replay.stdout).strip()}"]
    notes.append(f"producer replay at {commit[:7]} passed: {replay.stdout.strip()}")
    return True, notes


def reledger() -> dict:
    """Re-reduce the retained (immutable) 2026-10-23 controls with lcb-signed-ledger-v7."""
    controls = load(CONTROLS)
    v2, v3, v4, v5, v6 = (load(LEDGER_V2)["cases"], load(LEDGER_V3)["cases"], load(LEDGER_V4)["cases"],
                          load(LEDGER_V5)["cases"], load(LEDGER_V6)["cases"])
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
                                            "lcb-signed-ledger-v3": v3[sid]["state"],
                                            "lcb-signed-ledger-v4": v4[sid]["state"],
                                            "lcb-signed-ledger-v5": v5[sid]["state"],
                                            "lcb-signed-ledger-v6": v6[sid]["state"]}, **new}
    return {
        "schema": "lcb-scenario-ledger-v7",
        "date": "2026-10-23",
        "rule": LEDGER_RULE,
        "status": "Corrected accounting reduction of retained characterization data (re-review I1 report "
                  "validation; the signed ledger rule body is unchanged from v6). The historical controls file and "
                  "the v2-v6 records are preserved unchanged and stay "
                  "verifiable by replaying each record's own producer at its recorded revision; this record "
                  "supersedes only their ledger classification. "
                  "Characterization only: accepted evidence remains the CI-re-executed prefixes.",
        "input": {"controls_file": CONTROLS.relative_to(ROOT).as_posix(), "controls_sha256_lf": lf_sha256(CONTROLS),
                  "controls_source_commit": controls["source_commit"],
                  "superseded_records": {LEDGER_V2.relative_to(ROOT).as_posix(): lf_sha256(LEDGER_V2),
                                         LEDGER_V3.relative_to(ROOT).as_posix(): lf_sha256(LEDGER_V3),
                                         LEDGER_V4.relative_to(ROOT).as_posix(): lf_sha256(LEDGER_V4),
                                         LEDGER_V5.relative_to(ROOT).as_posix(): lf_sha256(LEDGER_V5),
                                         LEDGER_V6.relative_to(ROOT).as_posix(): lf_sha256(LEDGER_V6)},
                  "reducer": "tools/lcb/lcb_registry.py::signed_ledger",
                  "reducer_sha256_lf": lf_sha256(Path(__file__)),
                  "catalogue_tool_sha256_lf": lf_sha256(Path(catalogue.__file__)),
                  "protected_manifest_sha256_lf": lf_sha256(PROTECTED_MANIFEST)},
        "evidence_limits": "The campaign retained world Water integers per checkpoint, aggregate explicit "
                           "source/sink totals and windowed observations. It retained no world-wide per-species "
                           "counts, no per-reaction log and no per-event source/sink timing, so reactive cases "
                           "and cases with explicit sources/sinks cannot be closed from this record. R1-R4, "
                           "F1-F4 and G1/G2 concern species, timed-event and container evidence that this campaign "
                           "did not supply.",
        "open_unexplained_or_malformed": sorted(s for s, c in cases.items() if c["state"] in PROBLEM_STATES),
        "accounting_unverified_ineligible_for_acceptance": sorted(
            s for s, c in cases.items() if c["state"] in UNVERIFIED_STATES),
        "changed_from_v6": sorted(s for s, c in cases.items()
                                  if c["state"] != c["superseded_states"]["lcb-signed-ledger-v6"]),
        "cases": cases,
    }


def reledger_cmd(args) -> int:
    if args.version in HISTORICAL_LEDGERS:
        if not args.check:
            print(f"refusing to write historical record {args.version}; use --check", file=sys.stderr)
            return 1
        ok, notes = verify_historical(args.version)
        print("\n".join(notes), file=sys.stdout if ok else sys.stderr)
        return 0 if ok else 1
    text = json.dumps(reledger(), indent=2) + "\n"
    if args.check:
        current = LEDGER_V7.read_text(encoding="utf-8").replace("\r\n", "\n") if LEDGER_V7.exists() else ""
        if current != text:
            print(f"stale or altered ledger record {LEDGER_V7.relative_to(ROOT)}", file=sys.stderr)
            return 1
        print(f"{LEDGER_V7.name} matches the retained controls and its reducer")
        return 0
    if LEDGER_V7.exists():
        print(f"refusing to overwrite dated evidence {LEDGER_V7.relative_to(ROOT)}", file=sys.stderr)
        return 1
    LEDGER_V7.write_bytes(text.encode("utf-8"))
    print(f"wrote {LEDGER_V7.relative_to(ROOT)}")
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
                         "reason": "native families exist; this registered mixed-family apparatus arm has no source-matched execution"})
    return arms


def current_default_mapping(mapping: dict, rows: dict) -> bool:
    """True only if every material maps to its current_default family with the reference variant.

    An empty mapping (a scenario with no liquids) selects nothing and is trivially Current."""
    for material, value in mapping.items():
        family, _, variant = str(value).partition("/")
        cell = rows.get(material, {}).get("families", {}).get(family)
        if cell is None or cell.get("status") != "current_default" or variant not in ("", "reference"):
            return False
    return True


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
        # One availability rule for protected and generic arms (H1): only a
        # measured Current-default mapping is executable. A candidate mapping is
        # blocked whatever its manifest label until this registered arm has a
        # source-matched qualification run. Native admission alone is insufficient.
        arms = []
        for a in protected_fixture["arms"]:
            current = current_default_mapping(a["policy"], rows)
            measured = current and a["status"] == "measured"
            arm = {"id": a["id"], "mapping": a["policy"], "status": "measured" if measured else "blocked",
                   "executable_today": measured, "manifest_status": a["status"]}
            if not measured:
                arm["depends_on"] = a.get("blocked_by") or ["#213 LCB-000 PASS", "#200"]
                arm["reason"] = ("candidate mapping; this registered apparatus arm has no source-matched execution" if not current
                                 else "Current mapping without a measured control")
            arms.append(arm)
    for arm in arms:
        assert not arm["executable_today"] or current_default_mapping(arm["mapping"], rows), arm
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
                                      "ledger_file": LEDGER_V7.relative_to(ROOT).as_posix()}
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
    ledgers = load(LEDGER_V7)["cases"] if LEDGER_V7.exists() else {}
    manifest = load(PROTECTED_MANIFEST)
    entries = []
    for fixture in manifest["fixtures"]:
        path = ROOT / fixture["path"]
        definition = load(path)
        inventory = catalogue.inventory_of(definition["rectangles"], definition["partial_water_fills"],
                                           definition["water_semantics"])
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
                    "ledger_v7": lf_sha256(LEDGER_V7) if LEDGER_V7.exists() else None,
                    "catalogue_tool": lf_sha256(Path(catalogue.__file__)),
                    "registry_builder": lf_sha256(Path(__file__))},
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
    g.add_argument("--version", choices=["v7", "v6", "v5", "v4", "v3", "v2"], default="v7")
    b = sub.add_parser("build")
    b.add_argument("--check", action="store_true")
    args = parser.parse_args()
    return {"reduce": reduce_cmd, "reledger": reledger_cmd, "build": build_cmd}[args.cmd](args)


if __name__ == "__main__":
    raise SystemExit(main())
