"""FROZEN historical reducer for the lcb-signed-ledger-v2 record.

`signed_ledger` and `_salt_species_ledger` are verbatim copies from
tools/lcb/lcb_registry.py at 54a8d62 (file LF SHA-256 56293fc9...6583).
`reledger` is a faithful compatibility adapter, not literally verbatim: its
dependencies are injected and its recorded reducer hash is pinned to the
historical file hash. It exists only so
docs/reference/lcb-scenario-ledger-2026-10-23.v2.json stays verifiable against
the code that produced it. Do not edit; current accounting is
lcb-signed-ledger-v3 in lcb_registry.py. Known defects (re-review N3/N4) are
preserved deliberately.
"""
from __future__ import annotations

from pathlib import Path

LEDGER_RULE = "lcb-signed-ledger-v2"
REACTIVE = {"salt", "sodium"}
FULL_WATER = 255
CLOSED_STATES = {"closed", "closed_signed_reaction_ledger"}
UNVERIFIED_STATES = {"UNVERIFIED_REACTION_AMOUNT", "UNVERIFIED_PARTIAL_WATER_160"}
HISTORICAL_REDUCER_SHA256_LF = "56293fc96c243423f90b2381d98c5b54f5aff83b06fcfd8bad8d32befa3e6583"


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


def reledger(CONTROLS: Path, ROOT: Path, load, lf_sha256, inventories) -> dict:
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
                  "reducer_sha256_lf": HISTORICAL_REDUCER_SHA256_LF},
        "evidence_limits": "The campaign retained world Water integers per checkpoint and windowed observations; "
                           "it retained no world-wide per-species counts and no per-reaction log.",
        "open_unexplained": sorted(s for s, c in cases.items() if c["state"] == "OPEN_UNEXPLAINED"),
        "accounting_unverified_ineligible_for_acceptance": sorted(
            s for s, c in cases.items() if c["state"] in UNVERIFIED_STATES),
        "cases": cases,
    }
