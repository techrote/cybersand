"""FROZEN historical reducer for the lcb-signed-ledger-v3 record.

`signed_ledger`, `_aggregate_source_sink` and `_salt_species_ledger` are verbatim
copies from tools/lcb/lcb_registry.py at b9b36c9 (file LF SHA-256 23dcb9a2...4355).
`reledger` is a faithful compatibility adapter, not literally verbatim: its
dependencies are injected and its recorded reducer hash is pinned to the
historical file hash. It exists only so
docs/reference/lcb-scenario-ledger-2026-10-23.v3.json stays verifiable against
the code that produced it. Do not edit. Current accounting is
lcb-signed-ledger-v4 in lcb_registry.py; the known v3 defects (re-review
R1-R4) are preserved deliberately.
"""
from __future__ import annotations

from pathlib import Path

LEDGER_RULE = "lcb-signed-ledger-v3"
REACTIVE = {"salt", "sodium"}
FULL_WATER = 255
CLOSED_STATES = {"closed", "closed_signed_reaction_ledger", "closed_timed_source_sink"}
UNVERIFIED_STATES = {"UNVERIFIED_REACTION_AMOUNT", "UNVERIFIED_PARTIAL_WATER_160", "UNVERIFIED_SOURCE_SINK_TIMING"}
PROBLEM_STATES = {"OPEN_UNEXPLAINED", "MALFORMED_EVIDENCE"}
HISTORICAL_REDUCER_SHA256_LF = "23dcb9a25649d1560ce2b319dd24402fabc6ef7415ee66ff2ccb484a15734355"


def signed_ledger(inventory: dict, ledger: dict, checkpoints: list) -> dict:
    """Signed per-species Water accounting (lcb-signed-ledger-v3).

    Every quantity is bound to the declared initial ledger and inventory; the
    first checkpoint is validated against them, never substituted for them.
    Supplied species evidence is validated before any constant-Water shortcut.
    Explicit sources/sinks close exactly only against timed per-event amounts
    (ledger["events"]: [{"tick", "source", "sink"}], applied after completed
    tick N and first observed at completed N+1). Aggregate-only totals reject
    impossible directions and gross budgets but cannot establish closure.
    A reactive species is never an explanation by itself. Only CLOSED_STATES
    are eligible for acceptance.
    """
    cells = inventory.get("cells", {})
    w0, src, sink = ledger.get("initial_integer"), ledger.get("explicit_source"), ledger.get("explicit_sink")
    reactive = sorted(set(cells) & REACTIVE)
    base = {"rule": LEDGER_RULE, "initial": w0, "explicit_source": src, "explicit_sink": sink,
            "reactive_species": reactive}

    def result(state, reason, **extra):
        return {"state": state, "eligible_for_acceptance": state in CLOSED_STATES, "reason": reason, **base, **extra}

    # 1. Structure.
    def nonneg(v):
        return isinstance(v, int) and not isinstance(v, bool) and v >= 0
    if not (nonneg(w0) and nonneg(src) and nonneg(sink)):
        return result("MALFORMED_EVIDENCE", "initial, source and sink must be non-negative integers")
    if not checkpoints:
        return result("MALFORMED_EVIDENCE", "no checkpoints")
    ticks = [c.get("tick") for c in checkpoints]
    if not all(nonneg(t) for t in ticks) or ticks[0] != 0 or any(b <= a for a, b in zip(ticks, ticks[1:])):
        return result("MALFORMED_EVIDENCE", "checkpoint ticks must start at 0 and strictly increase")
    if not all(nonneg(c.get("water_integer")) for c in checkpoints):
        return result("MALFORMED_EVIDENCE", "every checkpoint needs a non-negative water_integer")
    series = [(c["tick"], c["water_integer"]) for c in checkpoints]
    final = series[-1][1]
    base.update(final_world_water=final, signed_delta=final - (w0 + src - sink))
    events = ledger.get("events")
    if events is not None:
        if not all(nonneg(e.get("tick")) and nonneg(e.get("source", 0)) and nonneg(e.get("sink", 0))
                   for e in events):
            return result("MALFORMED_EVIDENCE", "timed source/sink events need non-negative tick/source/sink")
        if (sum(e.get("source", 0) for e in events), sum(e.get("sink", 0) for e in events)) != (src, sink):
            return result("MALFORMED_EVIDENCE", "timed source/sink events do not sum to the declared totals")
    species = [c.get("species") for c in checkpoints]
    tracked = sorted(set(cells) - {"water"} | ({"brine"} if "salt" in cells else set()))
    if any(s is not None for s in species):
        if any(s is None for s in species):
            return result("MALFORMED_EVIDENCE", "species counts are present at some checkpoints but not all")
        for s in species:
            missing = [k for k in tracked if k not in s]
            if missing or not all(nonneg(v) for v in s.values()):
                return result("MALFORMED_EVIDENCE", f"species counts incomplete or negative (missing {missing})")
    else:
        species = None
    # 2. Binding to the declared initial state.
    declared = inventory.get("water_integer")
    if declared is not None and declared != w0:
        return result("OPEN_UNEXPLAINED", f"ledger initial {w0} differs from the declared inventory {declared}")
    if series[0][1] != w0:
        return result("OPEN_UNEXPLAINED", f"tick-0 Water {series[0][1]} differs from the declared initial {w0}",
                      initial_discrepancy=series[0][1] - w0)
    if species is not None:
        off = {k: (species[0][k], cells.get(k, 0)) for k in tracked if species[0][k] != cells.get(k, 0)}
        if off:
            return result("OPEN_UNEXPLAINED", "tick-0 species counts differ from the declared inventory",
                          initial_species_discrepancy=off)
    # 3. Expected Water from explicit sources/sinks.
    deltas = [(a[0], b[0], b[1] - a[1]) for a, b in zip(series, series[1:])]
    if events is not None:
        expected = [w0 + sum(e.get("source", 0) - e.get("sink", 0) for e in events if e["tick"] < t)
                    for t, _ in series]
    else:
        expected = None
    if not reactive:
        if expected is not None:
            off = [(t, w - e) for (t, w), e in zip(series, expected) if w != e]
            if off:
                return result("OPEN_UNEXPLAINED", "Water differs from the timed source/sink ledger", deviations=off)
            return result("closed_timed_source_sink" if src or sink else "closed",
                          "Water equals initial + timed sources - timed sinks at every checkpoint")
        if src == 0 and sink == 0:
            off = [(t, w - w0) for t, w in series if w != w0]
            if off:
                return result("OPEN_UNEXPLAINED", "Water differs from the initial value with no source, sink or "
                              "reactive species", deviations=off)
            return result("closed", "Water constant at every checkpoint")
        return _aggregate_source_sink(result, w0, src, sink, final, deltas)
    # 4. Reactive species. Supplied evidence is validated before any shortcut.
    if species is not None and reactive == ["salt"] and src == 0 and sink == 0:
        return _salt_species_ledger(result, cells, w0, series, species)
    if "sodium" in reactive and not (src == 0 and sink == 0 and all(w == w0 for _, w in series)):
        return result("UNVERIFIED_REACTION_AMOUNT", "Sodium products include Steam that condenses to full "
                      "Water; no per-reaction amounts are retained, so neither sign nor amount is established",
                      checkpoint_gains=[d for d in deltas if d[2] > 0])
    if src or sink:
        return result("UNVERIFIED_REACTION_AMOUNT", "reaction and explicit source/sink overlap; no "
                      "per-reaction amounts are retained")
    if all(w == w0 for _, w in series):
        return result("closed", "Water constant at every checkpoint and no reaction evidence was supplied; "
                      "a dissolution would have removed Water")
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


def _aggregate_source_sink(result, w0, src, sink, final, deltas) -> dict:
    """Non-reactive Water with aggregate-only source/sink totals (no event timing)."""
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
    salt0, brine0 = cells["salt"], cells.get("brine", 0)
    others = {k: v for k, v in cells.items() if k not in {"water", "salt", "brine"}}
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
        for name, count in others.items():
            if sp[name] != count:
                return result("OPEN_UNEXPLAINED", f"{name} cells changed", species_ledger=rows)
        partial |= dw != -FULL_WATER * s
        last = (s, w)
    if partial:
        return result("UNVERIFIED_PARTIAL_WATER_160", "within bounds, but some consumed Water cells were "
                      "partial (#160 boundary); per-cell consumed masses are not retained", species_ledger=rows)
    return result("closed_signed_reaction_ledger", "every consumed Salt cell removed one full Water cell and "
                  "produced two Brine cells; Water constant after dissolution", species_ledger=rows)


def reledger(CONTROLS: Path, LEDGER_V2: Path, PROTECTED_MANIFEST: Path, ROOT: Path, load, lf_sha256,
             inventories, catalogue_file: str) -> dict:
    """Re-reduce the retained (immutable) 2026-10-23 controls with lcb-signed-ledger-v3."""
    controls = load(CONTROLS)
    v2 = load(LEDGER_V2)["cases"]
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
                                            "lcb-signed-ledger-v2": v2[sid]["state"]}, **new}
    return {
        "schema": "lcb-scenario-ledger-v3",
        "date": "2026-10-23",
        "rule": LEDGER_RULE,
        "status": "Corrected accounting reduction of retained characterization data (re-review N3/N4). The "
                  "historical controls file and the v2 record are preserved unchanged; this record supersedes only "
                  "their ledger classification. Characterization only: accepted evidence remains the "
                  "CI-re-executed prefixes.",
        "input": {"controls_file": CONTROLS.relative_to(ROOT).as_posix(), "controls_sha256_lf": lf_sha256(CONTROLS),
                  "controls_source_commit": controls["source_commit"],
                  "superseded_record": LEDGER_V2.relative_to(ROOT).as_posix(),
                  "superseded_record_sha256_lf": lf_sha256(LEDGER_V2),
                  "reducer": "tools/lcb/lcb_registry.py::signed_ledger",
                  "reducer_sha256_lf": HISTORICAL_REDUCER_SHA256_LF,
                  "catalogue_tool_sha256_lf": lf_sha256(Path(catalogue_file)),
                  "protected_manifest_sha256_lf": lf_sha256(PROTECTED_MANIFEST)},
        "evidence_limits": "The campaign retained world Water integers per checkpoint, aggregate explicit "
                           "source/sink totals and windowed observations. It retained no world-wide per-species "
                           "counts, no per-reaction log and no per-event source/sink timing, so reactive cases "
                           "and cases with explicit sources/sinks cannot be closed from this record.",
        "open_unexplained_or_malformed": sorted(s for s, c in cases.items() if c["state"] in PROBLEM_STATES),
        "accounting_unverified_ineligible_for_acceptance": sorted(
            s for s, c in cases.items() if c["state"] in UNVERIFIED_STATES),
        "changed_from_v2": sorted(s for s, c in cases.items()
                                  if c["state"] != c["superseded_states"]["lcb-signed-ledger-v2"]),
        "cases": cases,
    }
