"""FROZEN historical reducer for the lcb-signed-ledger-v4 record.

`signed_ledger`, `_timed_source_sink`, `_aggregate_source_sink` and
`_salt_species_ledger` are verbatim copies from tools/lcb/lcb_registry.py at
b2d5222 (file LF SHA-256 69a48fa5...43d2). `reledger` is a faithful
compatibility adapter, not literally verbatim: its dependencies are injected
and its recorded reducer hash is pinned to the historical file hash. It exists
only so docs/reference/lcb-scenario-ledger-2026-10-23.v4.json stays verifiable
against the code that produced it. Do not edit. Current accounting is
lcb-signed-ledger-v5 in lcb_registry.py; the known v4 defects (re-review F1/F2)
are preserved deliberately.
"""
from __future__ import annotations

from pathlib import Path

LEDGER_RULE = "lcb-signed-ledger-v4"
REACTIVE = {"salt", "sodium"}
FULL_WATER = 255
CLOSED_STATES = {"closed", "closed_signed_reaction_ledger", "closed_timed_source_sink"}
UNVERIFIED_STATES = {"UNVERIFIED_REACTION_AMOUNT", "UNVERIFIED_PARTIAL_WATER_160", "UNVERIFIED_SOURCE_SINK_TIMING",
                     "UNVERIFIED_INCOMPLETE_HORIZON"}
PROBLEM_STATES = {"OPEN_UNEXPLAINED", "MALFORMED_EVIDENCE"}
HISTORICAL_REDUCER_SHA256_LF = "69a48fa557e0219811f1ba88dadca61685f0f5a2cf323862568874d6367a43d2"


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


def reledger(CONTROLS: Path, LEDGER_V2: Path, LEDGER_V3: Path, PROTECTED_MANIFEST: Path, ROOT: Path,
             load, lf_sha256, inventories, catalogue_file: str) -> dict:
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
                  "reducer_sha256_lf": HISTORICAL_REDUCER_SHA256_LF,
                  "catalogue_tool_sha256_lf": lf_sha256(Path(catalogue_file)),
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
