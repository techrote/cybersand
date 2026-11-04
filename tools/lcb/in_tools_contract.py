#!/usr/bin/env python3
"""Test-only #361 plan/source checks and a PROPOSED command receipt validator.

This does not implement a tool, mutate a World, or authenticate native receipts.
Successful validation establishes consistency of supplied copied values only.
Native execution is separately exercised by run_in_tools_native.py. The planned
host envelope must not be confused with the existing native run receipt v1.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / "godot/tests/fixtures/lcb/in_tools/in-tools-admission.v1.json"
FAMILIES = {3: {"freemass_v1", "inertial_cellular_v1"},
            24: {"cellular_yield_v1", "inertial_cellular_v1"}}
OPERATIONS = {"open_valve", "close_valve", "source", "sink"}
MAX_CELLS = 16
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
# v1 is the published six-fixture admission, not an arbitrary list that can
# shrink while retaining the same successful qualification label. These are
# planned coverage requirements; checking them still executes no host fixture.
WIDTH_VARIANTS = {"narrow-1", "baseline-2", "wide-4"}
SOURCE_VARIANTS = {"right-facing-guide", "left-facing-guide", "down-facing-guide"}
VALVE_EVENTS = {"open": (120, "open_valve"), "close": (600, "close_valve"),
                "reopen": (900, "open_valve")}
SINK_EVENTS = {f"sink-{n}": (tick, "sink") for n, tick in enumerate((121, 151, 181, 211, 601, 631))}
FIXTURES_V1 = {
    "in-tools.valve-side.v1": (WIDTH_VARIANTS, {"aperture_rect"},
                               {"vent": (0, "open_valve"), **VALVE_EVENTS}),
    "in-tools.valve-bottom.v1": (WIDTH_VARIANTS, {"aperture_rect"}, VALVE_EVENTS),
    "in-tools.sink-bottom.v1": (WIDTH_VARIANTS, {"aperture_rect", "intake_rect"},
                                {"open": (120, "open_valve"), **SINK_EVENTS}),
    "in-tools.sink-side.v1": (WIDTH_VARIANTS, {"aperture_rect", "intake_rect"},
                              {"vent": (0, "open_valve"), "open": (120, "open_valve"), **SINK_EVENTS}),
    "in-tools.source-channel.v1": (SOURCE_VARIANTS, {"source_rect", "static_wall_rects", "direction"},
                                   {f"source-{n}": (tick, "source") for n, tick in enumerate((120, 180, 240, 300))}),
    "in-tools.usable-liquid-drain.v1": (WIDTH_VARIANTS, {"intake_rect"},
        {"held-pulse": (120, "sink"), "after-stop-refusal": (600, "sink"),
         "after-reset-stale-refusal": (900, "sink")}),
}
COMPARISON_ROWS_V1 = (
    {(3, family, 3, bits, workers) for family in FAMILIES[3] for bits in (3, 8) for workers in (1, 4)} |
    {(24, family, 3, 8, workers) for family in FAMILIES[24] for workers in (1, 4)} |
    {(3, "freemass_v1", 2, 8, workers) for workers in (1, 4)}
)


class ContractError(ValueError):
    """Malformed registration or self-inconsistent proposed observation."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def parse_json(raw: str):
    """A copied proposal must have one unambiguous value for every JSON key."""
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, f"duplicate JSON key: {key}")
            result[key] = value
        return result

    def invalid_constant(value):
        raise ContractError(f"nonfinite JSON number: {value}")

    return json.loads(raw, object_pairs_hook=unique_object, parse_constant=invalid_constant)


def integer(value, name: str, low: int = 0, high: int = (1 << 63) - 1) -> int:
    require(type(value) is int and low <= value <= high, f"invalid integer: {name}")
    return value


def digest(value, name: str) -> str:
    require(isinstance(value, str) and HEX64.fullmatch(value) is not None,
            f"invalid digest: {name}")
    return value


def rectangle(value, name: str) -> tuple[int, int, int, int]:
    require(isinstance(value, list) and len(value) == 4, f"invalid rectangle: {name}")
    x, y = (integer(value[i], name, -(1 << 30), (1 << 30)) for i in range(2))
    w, h = (integer(value[i], name, 1, 1024) for i in range(2, 4))
    return x, y, w, h


def quantity(material: int, family: str, bits: int, value, name: str) -> int:
    q = integer(value, name, 0, (1 << bits) - 1 if material == 3 else 1)
    if material == 3 and family == "inertial_cellular_v1":
        require(q in (0, (1 << bits) - 1), f"fractional IN cell: {name}")
    return q


def motion(value, material: int, name: str) -> tuple[int, ...]:
    require(isinstance(value, list) and len(value) == 4, f"invalid motion: {name}")
    ranges = [(-32, 32), (0, 32), (-15, 15), (-15, 15)]
    out = tuple(integer(v, name, lo, hi) for v, (lo, hi) in zip(value, ranges))
    if material in (0, 1):
        require(out == (0, 0, 0, 0), f"motion on Empty/Wall: {name}")
    return out


def source_check(plan: dict, root: Path = ROOT, comparison: bool = False) -> dict:
    """Validate explicit inspected inputs; never regenerate or relax the lock."""
    require(isinstance(plan["source_inputs"], dict) and bool(plan["source_inputs"]), "empty source lock")
    checked = 0
    for relative, expected in plan["source_inputs"].items():
        path = (root / relative).resolve()
        require(path.is_relative_to(root.resolve()), "source path escapes checkout")
        digest(expected, relative)
        require(path.is_file(), f"missing source input: {relative}")
        actual = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        require(actual == expected, f"source changed; re-admission required: {relative}")
        checked += 1
    external = 0
    if comparison:
        commit = plan["comparison"]["commit"]
        require(re.fullmatch(r"[0-9a-f]{40}", commit) is not None, "bad comparison commit")
        for entry in plan["comparison"]["reuse"]:
            require(not entry["path"].startswith("/") and ".." not in Path(entry["path"]).parts,
                    "bad comparison path")
            try:
                raw = subprocess.check_output(["git", "-C", str(root), "show",
                                               f"{commit}:{entry['path']}"],
                                              stderr=subprocess.PIPE, timeout=30)
            except subprocess.SubprocessError as exc:
                raise ContractError("comparison object unavailable; fetch the pinned PR source") from exc
            require(hashlib.sha256(raw).hexdigest() == entry["sha256"],
                    f"comparison bytes changed: {entry['path']}")
            external += 1
    return {"source_inputs_checked": checked, "comparison_inputs_checked": external,
            "scope": "source equality only; not runtime qualification"}


def validate_plan(plan: dict) -> dict:
    require(plan["schema"] == "in-tools-admission-plan-v1", "unknown plan schema")
    require(plan["status"] == "planned-host-contract", "plan must remain explicitly Planned")
    require(plan["production_changes"] is False, "preparation cannot enable production changes")
    integer(plan["limits"]["cells_per_command"], "cells per command", MAX_CELLS, MAX_CELLS)
    command_limit = integer(plan["limits"]["commands_per_fixture"], "command limit", 1, 24)
    horizon_limit = integer(plan["limits"]["horizon_ticks_max"], "horizon limit", 1, 3600)
    require(isinstance(plan["comparison_arms"], list) and 1 <= len(plan["comparison_arms"]) <= 12,
            "invalid comparison arm count")
    comparison_rows: set[tuple] = set()
    for arm in plan["comparison_arms"]:
        material = integer(arm["material"], "arm material", 0, 255)
        require(material in FAMILIES, "unsupported comparison material")
        require(isinstance(arm["families"], list) and bool(arm["families"]), "missing families")
        require(all(isinstance(f, str) for f in arm["families"]), "invalid family name")
        require(len(arm["families"]) == len(set(arm["families"])), "duplicate families")
        require(all(f in FAMILIES[material] for f in arm["families"]), "unsupported comparison family")
        radius = integer(arm["radius"], "arm radius", 2, 3)
        require("inertial_cellular_v1" not in arm["families"] or radius == 3, "IN requires radius3")
        require(isinstance(arm["mass_bits"], list) and bool(arm["mass_bits"]), "missing mass precisions")
        for bits in arm["mass_bits"]:
            integer(bits, "arm mass bits", 3, 8)
        require(len(arm["mass_bits"]) == len(set(arm["mass_bits"])), "duplicate mass precisions")
        require(isinstance(arm["workers"], list) and bool(arm["workers"]), "missing worker arms")
        require(all(type(w) is int and w in (1, 4) for w in arm["workers"]), "unsupported worker arm")
        require(len(arm["workers"]) == len(set(arm["workers"])), "duplicate worker arms")
        for family in arm["families"]:
            for bits in arm["mass_bits"]:
                for workers in arm["workers"]:
                    row = (material, family, radius, bits, workers)
                    require(row not in comparison_rows, "duplicate comparison arm")
                    comparison_rows.add(row)
    require(comparison_rows == COMPARISON_ROWS_V1, "incomplete or unregistered v1 comparison coverage")
    require(isinstance(plan["fixtures"], list) and len(plan["fixtures"]) == len(FIXTURES_V1),
            "v1 requires all six registered host fixtures")
    ids: set[str] = set()
    for fixture in plan["fixtures"]:
        fid = fixture["id"]
        require(isinstance(fid, str) and fid.endswith(".v1") and fid not in ids, "bad fixture ID")
        require(fid in FIXTURES_V1, "unknown v1 fixture ID")
        required_variants, geometry_fields, expected_events = FIXTURES_V1[fid]
        ids.add(fid)
        require(fixture["execution"] == "planned_host_only", "host fixtures are not executed here")
        horizon = integer(fixture["horizon_ticks"], fid, 1, horizon_limit)
        rectangle(fixture["domain"], fid)
        variant_ids = set()
        require(isinstance(fixture["geometry_variants"], list) and
                1 <= len(fixture["geometry_variants"]) <= 24, "missing/bounded geometry variants")
        for variant in fixture["geometry_variants"]:
            require(isinstance(variant, dict) and geometry_fields <= set(variant),
                    "missing operation geometry")
            require(isinstance(variant["id"], str) and bool(variant["id"]), "invalid geometry variant ID")
            require(variant["id"] not in variant_ids, "duplicate geometry variant")
            variant_ids.add(variant["id"])
            for key in ("aperture_rect", "intake_rect", "source_rect"):
                if key in variant:
                    vx, vy, vw, vh = rectangle(variant[key], key)
                    dx, dy, dw, dh = rectangle(fixture["domain"], fid)
                    require(vw * vh <= MAX_CELLS and dx <= vx and dy <= vy and
                            vx + vw <= dx + dw and vy + vh <= dy + dh,
                            "geometry command exceeds domain/cell limit")
            for wall in variant.get("static_wall_rects", []):
                vx, vy, vw, vh = rectangle(wall, "static wall")
                dx, dy, dw, dh = rectangle(fixture["domain"], fid)
                require(dx <= vx and dy <= vy and vx + vw <= dx + dw and vy + vh <= dy + dh,
                        "static wall outside domain")
            if "static_wall_rects" in geometry_fields:
                require(isinstance(variant["static_wall_rects"], list) and bool(variant["static_wall_rects"]),
                        "missing source guide walls")
                direction = variant["direction"]
                require(isinstance(direction, list) and len(direction) == 2 and
                        all(type(v) is int for v in direction) and
                        direction in ([1, 0], [-1, 0], [0, 1]), "unregistered source guide direction")
        require(isinstance(fixture["variants"], list) and
                all(isinstance(v, str) for v in fixture["variants"]), "invalid variant list")
        require(len(fixture["variants"]) == len(set(fixture["variants"])), "duplicate variant list entry")
        require(variant_ids == set(fixture["variants"]), "variant list disagrees with geometry")
        require(variant_ids == required_variants, "incomplete or unregistered v1 geometry coverage")
        previous_tick = -1
        command_ids: set[str] = set()
        require(isinstance(fixture["events"], list) and 1 <= len(fixture["events"]) <= command_limit,
                "fixture needs a nonempty bounded command schedule")
        for event in fixture["events"]:
            tick = integer(event["tick"], fid, 0, horizon - 1)
            require(tick >= previous_tick, "events out of order")
            previous_tick = tick
            require(isinstance(event["id"], str) and 0 < len(event["id"]) <= 96 and
                    event["id"] not in command_ids, "bad/duplicate event ID")
            command_ids.add(event["id"])
            require(event["operation"] in OPERATIONS, "unsupported event operation")
            require(event["id"] in expected_events and
                    expected_events[event["id"]] == (tick, event["operation"]),
                    "event disagrees with registered v1 schedule")
            x, y, w, h = rectangle(event["rect"], fid)
            dx, dy, dw, dh = rectangle(fixture["domain"], fid)
            require(w * h <= MAX_CELLS and dx <= x and dy <= y and
                    x + w <= dx + dw and y + h <= dy + dh, "event exceeds bounded domain")
            require(event["motion"] == "zero_new_motion", "momentum inlet is unimplemented")
            require(event["on_occupied_close"] == "refuse_preserve_world",
                    "closure must not overwrite occupied cells")
        require(command_ids == set(expected_events), "incomplete v1 command schedule")
    require(ids == set(FIXTURES_V1), "missing tool registrations")
    return {"fixtures_checked": len(ids), "host_execution": "NOT_RUN",
            "gameplay_qualified": False}


def validate_receipt(command: dict, receipt: dict, owner: dict) -> dict:
    """Check one future host command at a same-tick exclusive-owner boundary.

    The packet is an apparatus proposal. No caller-supplied hash, mask, tuple or
    source claim is independently authenticated here. The future integration
    must bind these observations to the native owner and a full-world census.
    """
    require(command["schema"] == "in-tools-command-proposal-v1", "bad command schema")
    require(receipt["schema"] == "in-tools-receipt-proposal-v1", "bad receipt schema")
    require(receipt["command_id"] == command["id"], "wrong command identity")
    require(isinstance(command["id"], str) and 0 < len(command["id"]) <= 96, "bad command ID")
    for name in ("generation", "control_generation", "equipment_epoch", "last_sequence", "tick"):
        integer(owner[name], f"owner.{name}")
    for name in ("generation", "control_generation", "equipment_epoch", "sequence", "issued_tick", "expires_tick"):
        integer(command[name], f"command.{name}")
    require(command["issued_tick"] <= command["expires_tick"], "invalid command lease")
    digest(owner["policy_sha256"], "owner.policy")
    digest(command["policy_sha256"], "command.policy")
    require(receipt["generation"] == owner["generation"] and type(receipt["generation"]) is int,
            "receipt from old World")
    require(receipt["policy_sha256"] == owner["policy_sha256"], "receipt policy is not applied policy")
    require(receipt["construction_receipt_sha256"] ==
            digest(owner["construction_receipt_sha256"], "owner construction receipt"),
            "receipt is not for the current native construction")
    require(receipt["tick"] == owner["tick"] and type(receipt["tick"]) is int, "wrong applied tick")
    require(receipt["sequence"] == command["sequence"] and type(receipt["sequence"]) is int,
            "wrong sequence")
    before_hash = digest(receipt["before_hash"], "before_hash")
    after_hash = digest(receipt["after_hash"], "after_hash")
    require(before_hash == digest(owner["state_hash"], "owner.state_hash"),
            "receipt is not for the current state")
    stale = (any(command[k] != owner[k] for k in
                 ("generation", "control_generation", "equipment_epoch", "policy_sha256")) or
             command["sequence"] <= owner["last_sequence"] or
             not command["issued_tick"] <= owner["tick"] <= command["expires_tick"])
    require(type(owner["failed"]) is bool, "bad health flag")
    requested_material = integer(command["material"], "requested material", 0, 255)
    material = integer(owner["material"], "owner.material", 0, 255)
    require(material in FAMILIES, "unsupported quantity-observation material")
    bits = integer(owner["mass_bits"], "mass_bits", 3, 8)
    family = owner["family"]
    quantum = (1 << bits) - 1 if material == 3 else 1
    requested = integer(command["requested_units"], "requested_units", 0, MAX_CELLS * 255)
    op = command["operation"]
    require(op in OPERATIONS, "unsupported operation")
    x, y, w, h = rectangle(command["rect"], "command.rect")
    require(w * h <= MAX_CELLS, "command footprint exceeds bound")
    dx, dy, dw, dh = rectangle(owner["domain"], "owner.domain")
    outside = not (dx <= x and dy <= y and x + w <= dx + dw and y + h <= dy + dh)
    invalid_policy = (requested_material != material or
                      family not in FAMILIES.get(material, set()))
    radius = integer(owner["radius"], "owner.radius", 2, 3)
    invalid_policy |= family == "inertial_cellular_v1" and radius != 3
    direction = command["direction"]
    require(isinstance(direction, list) and len(direction) == 2 and
            all(type(v) is int and -1 <= v <= 1 for v in direction), "bad direction")
    speed = integer(command["speed_q16"], "speed_q16", 0, 32)
    unsupported_momentum = speed != 0 or command["motion"] != "zero_new_motion"
    fractional = material == 3 and family == "inertial_cellular_v1" and requested % quantum != 0
    require(op in {"source", "sink"} or requested == 0, "valve carries a liquid budget")
    require(op not in {"source", "sink"} or requested <= w * h * quantum,
            "request exceeds footprint capacity")
    if stale or owner["failed"] or outside or invalid_policy or unsupported_momentum or fractional:
        require(receipt["outcome"] == "refused", "inadmissible command was applied")
    require(receipt["outcome"] in {"applied", "refused"}, "unknown command outcome")
    if receipt["outcome"] == "refused":
        require(isinstance(receipt["reason"], str) and bool(receipt["reason"]), "missing refusal reason")
    else:
        require(receipt["reason"] == "", "applied command has refusal reason")

    cells = receipt["cells"]
    require(isinstance(cells, list) and len(cells) == w * h, "incomplete command-local census")
    seen = set()
    inside_domain_count = 0
    source = sink = wall_added = wall_removed = local_before = local_after = 0
    for cell in cells:
        cx, cy = cell["xy"]
        integer(cx, "x", -(1 << 30), 1 << 30)
        integer(cy, "y", -(1 << 30), 1 << 30)
        require(x <= cx < x + w and y <= cy < y + h and (cx, cy) not in seen,
                "duplicate/outside cell")
        seen.add((cx, cy))
        old_mat = integer(cell["before_material"], "before material", 0, 255)
        new_mat = integer(cell["after_material"], "after material", 0, 255)
        mask = integer(cell["body_id"], "body_id", 0, 65535)
        if dx <= cx < dx + dw and dy <= cy < dy + dh:
            inside_domain_count += 1
        else:
            require(old_mat == new_mat == 0 and mask == 0, "nonempty cell outside complete World domain")
        old_q = quantity(material, family, bits, cell["before_units"], "before_units")
        new_q = quantity(material, family, bits, cell["after_units"], "after_units")
        require(old_q == 0 if old_mat != material else old_q > 0, "wrong before quantity unit")
        require(new_q == 0 if new_mat != material else new_q > 0, "wrong after quantity unit")
        before_state = digest(cell["before_state_sha256"], "before_state")
        after_state = digest(cell["after_state_sha256"], "after_state")
        before_motion = motion(cell["before_motion"], old_mat, "before_motion")
        after_motion = motion(cell["after_motion"], new_mat, "after_motion")
        if family != "inertial_cellular_v1":
            require(old_mat != material or before_motion == (0, 0, 0, 0), "motion on non-IN cell")
            require(new_mat != material or after_motion == (0, 0, 0, 0), "motion on non-IN cell")
        changed = (old_mat != new_mat or old_q != new_q or before_state != after_state or
                   before_motion != after_motion)
        if old_mat != new_mat or old_q != new_q or before_motion != after_motion:
            require(before_state != after_state, "changed tuple has unchanged cell state digest")
        if receipt["outcome"] == "refused":
            require(not changed, "refusal changed a cell")
        if changed:
            require(mask == 0, "write into body mask")
            if op == "source":
                require(old_mat == 0 and new_mat == material and new_q > 0,
                        "source overwrites material")
                require(cell["after_motion"] == [0, 0, 0, 0] and
                        all(type(v) is int for v in cell["after_motion"]), "source injected motion")
            elif op == "sink":
                require(old_mat == material and new_mat == 0 and new_q == 0,
                        "sink changes the wrong material or removes a fraction")
            elif op == "open_valve":
                require(old_mat == 1 and new_mat == 0, "opening erases non-Wall")
            elif op == "close_valve":
                require(old_mat == 0 and new_mat == 1, "closure overwrites liquid or terrain")
        source += max(0, new_q - old_q)
        sink += max(0, old_q - new_q)
        local_before += old_q
        local_after += new_q
        wall_added += int(old_mat != 1 and new_mat == 1)
        wall_removed += int(old_mat == 1 and new_mat != 1)
    if receipt["outcome"] == "applied":
        require(before_hash != after_hash, "applied effect has unchanged state identity")
        if op == "open_valve":
            require(wall_removed == w * h and wall_added == 0, "partial valve opening")
        elif op == "close_valve":
            require(wall_added == w * h and wall_removed == 0, "partial valve closure")
        else:
            require(0 < source + sink <= requested, "empty success or budget exceeded")
    else:
        require(before_hash == after_hash, "refused command changed authoritative hash")
    require(source == integer(receipt["source_units"], "source_units"), "source receipt mismatch")
    require(sink == integer(receipt["sink_units"], "sink_units"), "sink receipt mismatch")
    before = integer(receipt["stored_before"], "stored_before")
    after = integer(receipt["stored_after"], "stored_after")
    require(before == integer(owner["stored_units"], "owner.stored_units"),
            "stored baseline mismatch")
    require(local_before <= before and local_after <= after, "local census exceeds World quantity")
    # owner.domain is the complete finite observed World, never a cropped ROI.
    # A refused footprint may lie partly or wholly outside the finite World.
    # Only its intersection consumes observed-domain capacity; external Empty
    # copies cannot stand in for missing cells in the full-world inventory.
    other_capacity = (dw * dh - inside_domain_count) * quantum
    require(before <= other_capacity + local_before and after <= other_capacity + local_after,
            "World quantity exceeds declared domain capacity")
    if material == 3 and family == "inertial_cellular_v1":
        require(before % quantum == 0 and after % quantum == 0, "fractional IN World quantity")
    require(after == before + source - sink, "unexplained creation/deletion")
    supply_before = integer(receipt["supply_before"], "supply_before")
    supply_after = integer(receipt["supply_after"], "supply_after")
    require(supply_before == integer(owner["supply_remaining"], "owner.supply_remaining"),
            "source budget baseline mismatch")
    require(supply_after == supply_before - source, "source supply debit mismatch")
    sink_before = integer(receipt["sink_budget_before"], "sink_budget_before")
    sink_after = integer(receipt["sink_budget_after"], "sink_budget_after")
    require(sink_before == integer(owner["sink_remaining"], "owner.sink_remaining"),
            "sink budget baseline mismatch")
    require(sink_after == sink_before - sink, "sink budget debit mismatch")
    return {"status": "consistent_supplied_values", "gameplay_qualified": False,
            "native_receipt_authenticated": False, "source_units": source, "sink_units": sink}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, default=PLAN)
    parser.add_argument("--check-comparison", action="store_true")
    parser.add_argument("--packet", type=Path, help="Optional copied {command,receipt,owner} proposal")
    args = parser.parse_args()
    try:
        plan = parse_json(args.plan.read_text(encoding="utf-8"))
        result = {**validate_plan(plan), **source_check(plan, comparison=args.check_comparison)}
        if args.packet:
            result["packet"] = validate_receipt(**parse_json(args.packet.read_text(encoding="utf-8")))
        print(json.dumps(result, indent=2))
        return 0
    except (ContractError, KeyError, TypeError, ValueError, OSError) as exc:
        print(json.dumps({"status": "refused", "reason": str(exc), "gameplay_qualified": False}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
