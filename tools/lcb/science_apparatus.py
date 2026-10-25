#!/usr/bin/env python3
"""Prepare immutable, actor-free LCB science inputs using the real Godot host.

This apparatus does not launch the full scientific campaign. Its prepared
workers1 receipt remains a precursor when the native consumer varies workers.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime
import hashlib
import importlib.util
import json
import math
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAX_SNAPSHOT = 128 * 1024 * 1024
MAX_EVENTS = 128
LEDGER_UNSIGNED = {"updates", "unit_moves", "density_swaps", "contacts", "rests", "velocity_retired",
                   "maximum_read_reach", "maximum_write_reach"}
LEDGER_KEYS = LEDGER_UNSIGNED | {"gravity_y", "impulse_x", "impulse_y", "loss", "support", "remainder",
                               "retired_x", "retired_y", "external_x", "external_y", "external_speed"}


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def unique_pairs(pairs: list[tuple[str, object]]) -> dict:
    out: dict = {}
    for key, value in pairs:
        require(key not in out, "duplicate JSON name: " + key)
        out[key] = value
    return out


def loads(text: str) -> object:
    def finite_float(value: str) -> float:
        result = float(value)
        require(math.isfinite(result), "nonfinite JSON number")
        return result
    return json.loads(text, object_pairs_hook=unique_pairs,
                      parse_float=finite_float,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError("nonfinite JSON: " + value)))


def load(path: Path) -> object:
    return loads(path.read_text(encoding="utf-8"))


def save_new(path: Path, value: object) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n")


def integer(value: object, low: int, high: int, label: str) -> int:
    require(type(value) is int and low <= value <= high, "invalid integer " + label)
    return value


def decimal64(value: object, unsigned: bool = False) -> int:
    require(isinstance(value, str) and re.fullmatch(r"0|[1-9][0-9]*|-[1-9][0-9]*", value) is not None,
            "noncanonical decimal64")
    n = int(value)
    require((0 if unsigned else -(1 << 63)) <= n < (1 << (64 if unsigned else 63)), "decimal64 overflow")
    return n


def canonical_definition(value: object) -> bytes:
    """Type-preserving value comparison, not another scenario compiler.

    The real validator supplies a complete resolved schema2 definition. This
    apparatus additionally admits only original values already equal to that
    resolved form; it never silently resolves a shorthand transport profile.
    """
    def numbers(item: object) -> object:
        if type(item) is float:
            require(math.isfinite(item), "nonfinite definition number")
            return int(item) if item.is_integer() else item
        if isinstance(item, list):
            return [numbers(v) for v in item]
        if isinstance(item, dict):
            return {k: numbers(v) for k, v in item.items()}
        return item
    return json.dumps(numbers(value), sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf8")


def bind_definition(sidecar: dict, definition: dict, receipt: dict) -> None:
    original = loads(sidecar["definition_text"])
    require(isinstance(original, dict) and canonical_definition(original) == canonical_definition(definition),
            "original definition differs from normalized program; apparatus requires fully resolved inputs")
    digest = sha(canonical_definition(definition))
    require(digest == sidecar["definition_hash"], "independent canonical definition hash mismatch")
    # Reuse the existing independent receipt encoder, preserving canonical
    # descriptor ownership rather than adding a second native receipt codec.
    import liquid_run_receipt_contract as encoding
    setup = {"kind": 2, "definition_schema": 2, "definition_digest": digest,
             "seed": integer(definition["seed"], 0, (1 << 31) - 1, "definition seed"),
             "domain": [0, 0, 1024, 1024], "coverage": 2, "gaps": 63}
    expected = encoding.setup_hash(bytes.fromhex(receipt["prepared_payload_hash"]), setup).hex()
    require(expected == receipt["prepared_setup_hash"], "definition/seed/payload differs from native prepared setup identity")


def event_wire(definition: dict, horizon: int) -> tuple[bytes, list[dict]]:
    """Translate real live-event semantics; setup-coherence scaling is distinct."""
    integer(horizon, 0, 4800, "horizon")
    semantics = definition["water_semantics"]
    require(isinstance(semantics, list) and len(semantics) == 4, "Water semantics shape")
    bits = integer(semantics[1], 3, 8, "mass bits")
    coherence_limit = integer(semantics[2], 0, 12, "coherence limit")
    maximum = (1 << bits) - 1
    events = definition["events"]
    require(isinstance(events, list) and len(events) <= MAX_EVENTS, "event count")
    wire: list[str] = []
    dispositions: list[dict] = []
    previous = -1
    for index, event in enumerate(events):
        require(isinstance(event, dict), "event object")
        tick = integer(event["tick"], 0, 4800, "event tick")
        require(tick >= previous, "event order")
        previous = tick
        kind = event["kind"]
        require(kind in ("fill", "erase", "sample"), "event kind")
        row = {"index": index, "tick": tick, "original": event}
        if tick >= horizon:
            row["disposition"] = "outside_requested_horizon"
        elif kind == "sample":
            row["disposition"] = "read_only_host_observation"
        else:
            x = integer(event["x"], 0, 1023, "event x")
            y = integer(event["y"], 0, 1023, "event y")
            width = integer(event["width"], 1, 1024 - x, "event width")
            height = integer(event["height"], 1, 1024 - y, "event height")
            if kind == "fill":
                require(event["material"] == 3, "fill material must be Water")
                mass = integer(event["normalized_mass"], 1, 255, "source normalized mass")
                # The actual adapter scales mass, but passes coherence directly.
                state_a = (2 * mass * maximum + 255) // 510
                state_b = integer(event["coherence"], 0, coherence_limit, "live event coherence")
            else:
                require(event["material"] == 0 and event["normalized_mass"] == 0 and event["coherence"] == 0,
                        "erase carries material or quantity")
                state_a = state_b = 0
            if kind == "fill" and state_a == 0:
                row["disposition"] = "rounded_zero_source_noop"
            else:
                values = (tick, int(kind == "fill"), x, y, width, height,
                          3 if kind == "fill" else 0, state_a, state_b)
                wire.append(" ".join(map(str, values)))
                row.update(disposition="ordered_native_action", wire_index=len(wire) - 1, wire=list(values))
        dispositions.append(row)
    data = (f"lcb-science-events-v1 {len(wire)}\n" + "".join(line + "\n" for line in wire)).encode("ascii")
    require(len(data) <= 128 * 1024, "event wire byte budget")
    return data, dispositions


def read_precursor(folder: Path) -> tuple[dict, dict]:
    sidecar = load(folder / "precursor.json")
    require(isinstance(sidecar, dict) and sidecar.get("schema") == "lcb-science-precursor-v2"
            and sidecar.get("status") == "prepared", "incomplete precursor")
    payload = (folder / "initial.cyps").read_bytes()
    require(8 <= len(payload) <= MAX_SNAPSHOT and payload[:4] == b"CYPS", "invalid snapshot envelope")
    require(sha(payload) == sidecar["snapshot_sha256"]
            and decimal64(sidecar["snapshot_bytes"], True) == len(payload), "snapshot identity mismatch")
    require(struct.unpack_from("<I", payload, 4)[0] == decimal64(sidecar["cyps_version"], True) in (2, 3),
            "unsupported CYPS version")
    definition = loads(sidecar["normalized_definition_json"])
    require(isinstance(definition, dict), "normalized definition")
    # Recheck source JSON names independently of Godot's JSON parser.
    require(isinstance(loads(sidecar["definition_text"]), dict), "original definition")
    require(sha(sidecar["definition_text"].encode("utf8")) == sidecar["definition_file_sha256"],
            "original definition bytes mismatch")
    receipt = sidecar["prepared_receipt"]
    bind_definition(sidecar, definition, receipt)
    canonical = bytes.fromhex(sidecar["prepared_receipt_canonical_bytes_hex"])
    require(canonical and sha(canonical) == receipt["receipt_hash"], "native receipt bytes/hash mismatch")
    require(receipt["canonical_bytes"] == {"encoding": "hex", "value": canonical.hex()}, "receipt copied bytes mismatch")
    require(receipt["worker_threads"] == sidecar["precursor_workers"] == "1"
            and receipt["completed_tick"] == "0" and receipt["initial_body_count"] == "0"
            and receipt["run_intent"] == "controlled" and receipt["pacing"] == "fixed_steps"
            and receipt["simulation_window_enabled"] is True
            and receipt["eligible_for_full_matched_evidence"] is False, "qualified prepared precursor required")
    runtime = sidecar["runtime"]
    require(runtime["mapped_module_binding"] == runtime["source_execution_binding"] == "unverified",
            "precursor cannot grant module/script identity")
    baselines = sidecar["qualification_baselines"]
    count = decimal64(sidecar["qualification_ticks"], True)
    require(count <= 30 and len(baselines) == count + 1, "bounded qualification history")
    require([row["completed_tick"] for row in baselines] == list(map(str, range(count + 1))), "qualification clock sequence")
    require(baselines[0]["physical_hash"] == receipt["physical_state_hash"], "initial physical binding")
    restored = sidecar["restored_initial_checkpoint"]
    require(sidecar["restored_initial_snapshot_sha256"] == sidecar["snapshot_sha256"]
            and restored["completed_tick"] == "0", "actual Godot-restored initial boundary")
    for key in ["physical_hash", "physical_hash_version", "quiescent_hash", "pressure_equivalence_hash"]:
        require(restored[key] == baselines[0][key], "prepared/restored authority mismatch: " + key)
    require(restored["water"]["content_hash"] == baselines[0]["water"]["content_hash"], "prepared/restored visible content mismatch")
    require(receipt["maximum_rule_radius"] in ("2", "3"), "explicit prepared execution radius")
    return sidecar, definition


def momentum_closure(previous: dict, current: dict) -> None:
    """Independent adjacent-phase closure, with nonzero initial offsets retained."""
    left = previous["census"]["inertial"]
    right = current["census"]["inertial"]
    before, after = previous["ledger"], current["ledger"]

    def delta(key: str) -> int:
        return decimal64(after[key], key in LEDGER_UNSIGNED) - decimal64(before[key], key in LEDGER_UNSIGNED)

    expected = {"sum_vx": delta("impulse_x") + delta("external_x") - delta("retired_x"),
                "sum_vy": delta("gravity_y") + delta("impulse_y") + delta("external_y") - delta("retired_y"),
                "l1": delta("gravity_y") - delta("loss") + delta("external_speed") - delta("velocity_retired")}
    for key, amount in expected.items():
        require(decimal64(right[key], key == "l1") - decimal64(left[key], key == "l1") == amount,
                "independent momentum closure failed: " + key)


def validate_native_report(path: Path, precursor_folder: Path, events_path: Path, workers: int,
                           horizon: int, require_rest: bool = False) -> dict:
    """Stream strict raw native rows; retain a canonical worker-parity digest."""
    integer(workers, 1, 4, "workers")
    require(workers in (1, 4), "only configured workers1/4 admitted")
    integer(horizon, 0, 4800, "horizon")
    precursor, definition = read_precursor(precursor_folder)
    expected_wire, dispositions = event_wire(definition, horizon)
    require(events_path.read_bytes() == expected_wire, "events differ from prepared definition/phase schedule")
    actions = [d for d in dispositions if d["disposition"] == "ordered_native_action"]
    batches = {}
    for action in actions:
        batches[action["tick"]] = batches.get(action["tick"], 0) + 1
    schedule = [("completed", 0, 0, 0)]
    applied = 0
    for tick in range(horizon):
        if tick in batches:
            applied += batches[tick]
            schedule.append(("post_event", tick, applied, batches[tick]))
        schedule.append(("completed", tick + 1, applied, 0))
    require(path.stat().st_size <= 512 * 1024 * 1024, "native result byte budget")
    raw_hash = hashlib.sha256()
    parity = hashlib.sha256()
    rows = 0
    previous = None
    header = footer = None
    observed_max = 0
    first_quiescent = None
    baselines = {int(v["completed_tick"]): v for v in precursor["qualification_baselines"]}
    policy = precursor["applied_policy"]
    inertial_materials = {int(v["material"]) for v in policy["assignments"]
                          if v["applied_family"] == "inertial_cellular_v1"}
    expected_inertial = policy.get("family_parameters", {}).get("inertial_cellular_v1", {}).get("extension_identity")
    with path.open("rb") as stream:
        for raw in stream:
            require(raw.endswith(b"\n") and len(raw) <= 2 * 1024 * 1024, "incomplete/overlong native row")
            raw_hash.update(raw)
            value = loads(raw.decode("utf8"))
            require(isinstance(value, dict) and value.get("schema") == "lcb-native-science-v1", "native schema")
            if header is None:
                require(value.get("type") == "header" and integer(value["workers"], 1, 4, "native configured workers") == workers
                        and integer(value["backend"], 1, 1, "native backend") == 1,
                        "native configuration header")
                header = value
                require(value["snapshot_sha256"] == value["roundtrip_sha256"] == precursor["snapshot_sha256"]
                        and value["events_sha256"] == sha(expected_wire), "native input/roundtrip identity")
                require(value["policy_hash"] == precursor["prepared_receipt"]["policy_hash"]
                        and value["inertial_identity"] == expected_inertial
                        and integer(value["cyps_version"], 2, 3, "native CYPS version") == int(precursor["cyps_version"]), "actual applied family identity")
                config = value["config"]
                expected_config = {"chunk_size": 128, "activity_block_size": 32, "scheduling_core_size": 64,
                    "maximum_rule_radius": int(precursor["prepared_receipt"]["maximum_rule_radius"]),
                    "sleep_after_quiet_ticks": 3, "ambient_temperature": 200, "initial_chunk_reserve": 64,
                    "worker_threads": workers, "parallel_job_threshold": 2, "active_core_capacity": 1024,
                    "active_chunk_capacity": 128, "maximum_chunk_count": 128, "deferred_event_capacity": 1024,
                    "maximum_explosion_radius": 64, "physics_diagnostics_enabled": True,
                    "disable_powder_exchange_targets": False, "mercury_viscosity": -1,
                    "pressure_index_chunk_capacity": 4096, "pressure_head_repair_cell_budget": 4194304,
                    "pressure_gas_member_capacity": 1048576, "pressure_gas_invalidation_pair_budget": 4194304,
                    "settled_discovery_enabled": False, "settled_region_connectivity_enabled": False,
                    "mass_bits": definition["water_semantics"][1], "coherence_ticks": definition["water_semantics"][2],
                    "adhesion": definition["execution"]["liquid_surface_adhesion_enabled"]}
                for key, expected in expected_config.items():
                    require(key in config and type(config[key]) is type(expected) and config[key] == expected,
                            "retained execution config mismatch: " + key)
                roster = [tuple(decimal64(x) for x in coord) for coord in value["roster"]]
                expected_roster = [(x, y) for x in range(-1, 9) for y in range(-1, 9)]
                require(roster == expected_roster, "prepared full1024/halo resident roster mismatch")
                coverage = value["coverage"]
                integer(coverage["chunk_side"], 128, 128, "census chunk side")
                require(coverage == {"resident_chunks": "100", "chunk_side": 128, "slots": "1638400",
                                     "min_x": "-128", "max_x": "1151", "min_y": "-128", "max_y": "1151"}, "census coverage")
                continue
            require(footer is None, "native data after footer")
            if value.get("type") == "footer":
                require(rows == len(schedule) and value["status"] == "completed"
                        and value["completed_horizon"] == str(horizon) and value["rows"] == str(rows)
                        and value["events_applied"] == str(len(actions)) and value["roster_unchanged"] is True
                        and value["closure"] is True, "incomplete native footer")
                require(value["snapshot_sha256"] == precursor["snapshot_sha256"] and value["events_sha256"] == sha(expected_wire), "footer input binding")
                for key, count in [("tick", horizon), ("census", rows), ("hash", rows), ("output", rows)]:
                    require(decimal64(value["timing"][key]["count"], True) == count, "timing sample count")
                footer = value
                continue
            require(value.get("type") == "observation" and rows < len(schedule), "unexpected native row")
            phase, tick, applied, batch = schedule[rows]
            require((value["phase"], value["tick"], value["events_applied"], value["events_in_phase"])
                    == (phase, str(tick), str(applied), str(batch)), "native action/completed phase sequence")
            ledger = value["ledger"]
            require(set(ledger) == LEDGER_KEYS, "incomplete nineteen-field ledger")
            for key, number in ledger.items():
                decimal64(number, key in LEDGER_UNSIGNED)
            require(0 <= int(ledger["support"]) <= int(ledger["loss"]) and int(ledger["maximum_read_reach"]) <= 3
                    and int(ledger["maximum_write_reach"]) <= 2, "native loss/reach bounds")
            census, quantity = value["census"], value["quantity"]
            cells = [decimal64(n, True) for n in census["material_cells"]]
            require(len(cells) == 256 and cells[0] == 0 and sum(cells) + decimal64(census["empty_cells"], True) == 1638400,
                    "complete resident material census")
            require(census["material_cells"] == quantity["material_cells"]
                    and census["water_visible"] == quantity["water_visible"]
                    and census["water_overfill"] == quantity["water_overfill"], "independent census/quantity mismatch")
            water = decimal64(census["water_visible"], True) + decimal64(census["water_overfill"], True)
            require(water == decimal64(census["water_total"], True), "total Water census")
            require(integer(quantity["schema_version"], 1, 1, "quantity schema") == 1
                    and integer(quantity["mass_bits"], 3, 8, "quantity mass bits") == definition["water_semantics"][1], "quantity schema/quantum")
            for key, count in [("kinds", 6), ("pair_rules", 56), ("kernel_rules", 19)]:
                require(len(quantity[key]) == count, "quantity flow slots")
                for flow in quantity[key]:
                    require(set(flow) == {"produced", "consumed"}, "quantity flow shape")
                    for n in flow.values():
                        decimal64(n, True)
            require(water == decimal64(quantity["baseline_water"], True) + sum(int(v["produced"]) - int(v["consumed"]) for v in quantity["kinds"]),
                    "independent Water source/sink closure")
            require(len(quantity["pair_events"]) == 56 and len(quantity["prepared_material_cells"]) == 256, "quantity cause/population slots")
            for n in quantity["pair_events"] + quantity["prepared_material_cells"]:
                decimal64(n, True)
            construction = quantity["construction"]
            require(construction is not None and construction["prepared_setup_identity"] == precursor["prepared_receipt"]["prepared_setup_hash"]
                    and construction["prepared_payload_digest"] == precursor["prepared_receipt"]["prepared_payload_hash"], "one-shot prepared quantity identity")
            for key in ["baseline_water", "normalization_produced", "normalization_consumed", "expected_final_water"]:
                decimal64(construction[key], True)
            require(construction["baseline_water"] == quantity["baseline_water"]
                    and quantity["kinds"][0] == {"produced": construction["normalization_produced"],
                                               "consumed": construction["normalization_consumed"]}, "one-shot normalization quantities")
            if previous is not None:
                require(construction == previous["quantity"]["construction"]
                        and quantity["prepared_material_cells"] == previous["quantity"]["prepared_material_cells"], "prepared ledger seed changed")
                for key in LEDGER_UNSIGNED | {"gravity_y", "loss", "support", "remainder"}:
                    require(int(ledger[key]) >= int(previous["ledger"][key]), "cumulative ledger moved backwards: " + key)
                for key in ["kinds", "pair_rules", "kernel_rules"]:
                    for before, after in zip(previous["quantity"][key], quantity[key]):
                        require(all(int(after[k]) >= int(before[k]) for k in ["produced", "consumed"]), "quantity flow moved backwards")
            else:
                require(water == int(construction["expected_final_water"]), "prepared initial quantity differs from construction seed")
            motion = census["inertial"]
            for key, n in motion.items():
                decimal64(n, key not in {"sum_vx", "sum_vy", "sum_ax", "sum_ay"})
            require(motion["foreign_nonzero_slots"] == "0" and int(motion["max_abs_vx"]) <= 32
                    and int(motion["max_vy"]) <= 32 and int(motion["max_abs_ax"]) < 16 and int(motion["max_abs_ay"]) < 16
                    and int(motion["nonzero_slots"]) <= sum(cells[m] for m in inertial_materials), "carrier/foreign motion bounds")
            require(int(motion["l1"]) >= abs(int(motion["sum_vx"])) + abs(int(motion["sum_vy"])) and int(motion["sum_vy"]) >= 0,
                    "momentum census magnitude bound")
            if previous is not None:
                momentum_closure(previous, value)
            hashes = value["hashes"]
            require(set(hashes) == {"physical", "state", "content", "quiescent", "pf_equivalence"}
                    and all(isinstance(v, str) and re.fullmatch("[0-9a-f]{16}", v) for v in hashes.values()), "complete hash projections")
            if require_rest:
                if first_quiescent is None:
                    first_quiescent = hashes["quiescent"]
                require(motion["nonzero_slots"] == "0" and all(motion[k] == "0" for k in ["sum_vx", "sum_vy", "sum_ax", "sum_ay", "l1"])
                        and hashes["quiescent"] == first_quiescent, "registered static rest failed")
            stats = value["stats"]
            for key, number in stats.items():
                if key not in {"observed_available", "phase_jobs"}:
                    decimal64(number, True)
            require(stats["observed_available"] is True and stats["configured_workers"] == str(workers)
                    and stats["tick"] == str(tick)
                    and stats["chunk_allocations"] == stats["temperature_field_allocations"] == "0", "actual workers/allocation readback")
            jobs = [decimal64(n, True) for n in stats["phase_jobs"]]
            require(len(jobs) == 4 and sum(jobs) == int(stats["scheduled_cores"]), "actual phase-job accounting")
            observed = int(stats["observed_workers"])
            require(0 <= observed <= min(workers, max(jobs)) and (sum(jobs) == 0 or observed > 0), "actual maximum participants in one dispatch")
            observed_max = max(observed_max, observed)
            regions = value["regions"]
            requested = [str(n) for n in definition["interest"]["region"]]
            x, y, width, height = map(int, requested)
            selected = list(map(str, [x // 64, y // 64, (x + width - 1) // 64, (y + height - 1) // 64]))
            require(regions["requested"] == requested and regions["selected"] == selected
                    and (tick == 0 or regions["applied"] == selected), "actual fixed-interest selection differs")
            if phase == "completed" and tick in baselines:
                baseline = baselines[tick]
                state_baseline = precursor["restored_initial_checkpoint"] if tick == 0 else baseline
                require(hashes["physical"] == baseline["physical_hash"] and hashes["state"] == state_baseline["water"]["state_hash"].zfill(16)
                        and hashes["content"] == baseline["water"]["content_hash"].zfill(16)
                        and hashes["quiescent"] == baseline["quiescent_hash"]
                        and hashes["pf_equivalence"] == baseline["pressure_equivalence_hash"], "actual Godot/native consumer qualification disagreement")
            for n in value["timing"].values():
                decimal64(n, True)
            projection = {k: value[k] for k in ["phase", "tick", "events_applied", "events_in_phase", "census", "ledger", "quantity", "hashes", "regions"]}
            projection["work"] = {k: v for k, v in stats.items() if k not in {"configured_workers", "observed_workers", "observed_available"}}
            parity.update((json.dumps(projection, sort_keys=True, separators=(",", ":")) + "\n").encode())
            previous = value
            rows += 1
    require(header is not None and footer is not None, "missing native completion header/footer")
    return {"schema": "lcb-science-independent-reduction-v1", "status": "completed", "workers": workers,
            "horizon": horizon, "observation_rows": rows, "events": len(actions), "raw_sha256": raw_hash.hexdigest(),
            "worker_parity_projection_sha256": parity.hexdigest(), "actual_max_workers_observed": observed_max,
            "global_resident_slots_per_row": 1638400, "closure_each_phase": True,
            "godot_host_completed_baselines_checked": min(horizon, len(baselines) - 1) + 1,
            "initial_legacy_hashes": {"prepared": precursor["qualification_baselines"][0]["water"]["state_hash"],
                                      "actual_godot_restored": precursor["restored_initial_checkpoint"]["water"]["state_hash"],
                                      "equivalence_claim": False},
            "timing": footer["timing"], "final": previous,
            "scope": "Independent source-bound actor-free native accounting and optional short Godot precursor comparison. Scientific screen/feel/full-host acceptance requires separately preregistered campaign; Web deferred."}


def prepare(args: argparse.Namespace) -> None:
    """Stage exact consumed inputs; use the established bounded process wrapper."""
    root = ROOT
    integer(args.horizon, 0, 4800, "requested horizon")
    out = args.out.resolve()
    require(not out.exists() and not out.is_relative_to(root), "output must be new and outside source checkout")
    definition_path = args.definition.resolve()
    original = definition_path.read_bytes()
    require(len(original) <= 4 * 1024 * 1024 and isinstance(loads(original.decode("utf8")), dict), "definition input")
    platform = "windows" if sys.platform == "win32" else "linux" if sys.platform.startswith("linux") else "unsupported"
    require(platform != "unsupported", "unsupported apparatus platform")
    manifest_path = root / "godot/addons/cybersand_native" / ("runtime-provenance.json" if platform == "windows" else "runtime-provenance.linux.json")
    manifest = load(manifest_path)
    native = args.native_runtime.resolve()
    require(sha(native.read_bytes()) == manifest["sha256"], "apparatus requires actual published runtime bytes")
    for path, expected in manifest["source_inputs"].items():
        require(sha((root / path).read_bytes().replace(b"\r\n", b"\n")) == expected, "native source mismatch: " + path)
    lock = load(root / "godot/third_party/rapier2d.lock.json")
    rapier_manifest = load(root / lock["runtime_overrides"][platform])
    rapier = args.rapier_runtime.resolve()
    require(sha(rapier.read_bytes()) == rapier_manifest["sha256"], "actual selected Rapier bytes required")
    source_paths = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "godot", "examples"], cwd=root).decode().splitlines()
    source = {path: sha((root / path).read_bytes()) for path in source_paths}
    out.mkdir(parents=True)
    for path in source:
        target = out / "snapshot" / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((root / path).read_bytes())
    payload_overrides = {}
    for path, actual in [(manifest["artifact"], native), (rapier_manifest["artifact"], rapier)]:
        shutil.copy2(actual, out / "snapshot" / path)
        payload_overrides[path] = {"source_raw_sha256": source[path], "staged_actual_sha256": sha(actual.read_bytes())}
    fixture = out / "definition.json"
    fixture.write_bytes(original)
    prepared = out / "prepared"
    prepared.mkdir()
    assignments = []
    for selection in args.assign:
        material, family, variant = selection.split(":")
        assignments.append({"material": integer(int(material), 0, 255, "assignment material"),
                            "family": family, "variant": variant})
    require(len({a["material"] for a in assignments}) == len(assignments), "duplicate material assignment")
    job = {"schema": "lcb-science-prepare-job-v1", "definition_path": str(fixture), "output_dir": str(prepared),
           "maximum_rule_radius": args.radius, "qualification_ticks": args.qualification_ticks,
           "normalization": args.normalization, "assignments": assignments}
    save_new(out / "job.json", job)
    project = {p.relative_to(out / "snapshot").as_posix(): sha(p.read_bytes())
               for p in (out / "snapshot").rglob("*") if p.is_file()}
    binding = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root).decode().strip(),
               "status": subprocess.check_output(["git", "status", "--short"], cwd=root).decode(),
               "source": source, "native_source_inputs": manifest["source_inputs"], "project": project,
               "native_manifest_sha256": sha(manifest_path.read_bytes()), "payload_overrides": payload_overrides,
               "godot_sha256": sha(args.godot.resolve().read_bytes()), "definition_sha256": sha(original)}
    save_new(out / "INPUTS.json", binding)
    runner_path = root / "tools/ci/run_godot_regressions.py"
    spec = importlib.util.spec_from_file_location("_lcb_science_bounded_godot", runner_path)
    require(spec is not None and spec.loader is not None, "bounded runner unavailable")
    runner = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = runner
    original_path = list(sys.path)
    try:
        sys.path.insert(0, str(root / "tools/ci"))
        spec.loader.exec_module(runner)
    finally:
        sys.path[:] = original_path
    original_root = runner.ROOT
    results = []
    try:
        runner.ROOT = out / "snapshot"
        cases = [runner.Case("import", ("--editor", "--quit"), 240, 3.0),
                 runner.Case("prepare", ("--script", "res://tests/lcb_science_prepare.gd", "--", str(out / "job.json")), 180, 3.0)]
        for case in cases:
            with (out / (case.name + "-driver.stdout")).open("x", encoding="utf8") as stream, contextlib.redirect_stdout(stream):
                result, failed = runner.run_case(str(args.godot.resolve()), case, out, "preflight" if case.name == "import" else "case")
            results.append(result)
            save_new(out / (case.name + "-result.json"), result)
            log = (out / (case.name + ".log")).read_text(encoding="utf8")
            require(not failed and result["returncode"] == 0 and not result["skip_messages"]
                    and not any(line.lstrip().startswith("WARNING:") for line in log.splitlines()), "strict Godot process failure: " + case.name)
            if case.name == "import":
                transitions = {}
                for path, expected in project.items():
                    data = (out / "snapshot" / path).read_bytes()
                    if sha(data) != expected:
                        require(path.startswith("godot/addons/godot-rapier2d/") and path.endswith(".import")
                                and data.replace(b"\r\n", b"\n") == (root / path).read_bytes().replace(b"\r\n", b"\n"), "import changed consumed input: " + path)
                        transitions[path] = {"before": expected, "after": sha(data), "cr_only": True}
                save_new(out / "IMPORT-TRANSITIONS.json", transitions)
                project = {p: sha((out / "snapshot" / p).read_bytes()) for p in project}
            require(source == {p: sha((root / p).read_bytes()) for p in source}, "source changed during preparation")
            require(project == {p: sha((out / "snapshot" / p).read_bytes()) for p in project}, "consumed snapshot changed")
    finally:
        runner.ROOT = original_root
        sys.modules.pop(spec.name, None)
    precursor, normalized = read_precursor(prepared)
    wire, dispositions = event_wire(normalized, args.horizon)
    (out / "events.txt").write_bytes(wire)
    save_new(out / "EVENTS.json", {"schema": "lcb-science-event-translation-v1", "horizon": args.horizon,
                                   "wire_sha256": sha(wire), "dispositions": dispositions})
    save_new(out / "PREPARATION-RECEIPT.json", {"utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
             "status": "prepared", "results": results, "snapshot_sha256": precursor["snapshot_sha256"],
             "precursor_sha256": sha((prepared / "precursor.json").read_bytes()), "events_sha256": sha(wire),
             "source_and_consumed_inputs_held": True, "scope": "Qualified immutable workers1 precursor only. No full scientific/native-consumer campaign, performance or complete-host acceptance. Web deferred."})
    print(json.dumps({"status": "prepared", "out": str(out), "snapshot_sha256": precursor["snapshot_sha256"]}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("prepare")
    p.add_argument("--godot", type=Path, required=True)
    p.add_argument("--native-runtime", type=Path, required=True)
    p.add_argument("--rapier-runtime", type=Path, required=True)
    p.add_argument("--definition", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--horizon", type=int, required=True, help="completed ticks, 0..4800")
    p.add_argument("--radius", type=int, required=True, choices=[2, 3])
    p.add_argument("--qualification-ticks", type=int, default=0, choices=range(0, 31))
    p.add_argument("--normalization", choices=["", "water-normalize-v1"], default="")
    p.add_argument("--assign", action="append", default=[], metavar="MATERIAL:FAMILY:VARIANT")
    v = sub.add_parser("validate", help="independently validate completed raw native output")
    v.add_argument("--report", type=Path, required=True)
    v.add_argument("--precursor", type=Path, required=True)
    v.add_argument("--events", type=Path, required=True)
    v.add_argument("--workers", type=int, required=True, choices=[1, 4])
    v.add_argument("--horizon", type=int, required=True)
    v.add_argument("--out", type=Path, required=True)
    v.add_argument("--require-rest", action="store_true", help="apply a separately registered static-rest condition")
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            prepare(args)
        else:
            report = validate_native_report(args.report, args.precursor, args.events, args.workers, args.horizon, args.require_rest)
            save_new(args.out, report)
            print(json.dumps({"status": "completed", "report": str(args.out),
                              "worker_parity_projection_sha256": report["worker_parity_projection_sha256"]}))
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        print("LCB science apparatus refused: " + str(error), file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
