#!/usr/bin/env python3
"""Check original process/packet custody and reduce frozen #383 Linux evidence.

Run against the retained host-attempt-4 directory. This only reads evidence;
it does not run the application or create native-issued command receipts.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import statistics

SOURCE = "73b10f9b800e72f358f22f470e57a4531002c168"
TREE = "31c5a9a4b986820985658d3ed2228ebe9008828a"
COUNTS = {
    "test_physical_metered_desktop": 148, "test_physical_metered_drain": 1614,
    "test_physical_metered_equipment": 99, "test_physical_usables_runtime": 243,
    "test_physical_usables_admission": 35, "test_physical_usables_desktop": 28,
    "test_usables": 196, "test_physical_usable_equipment": 307,
    "test_physical_usable_lifecycle": 39, "test_physical_actor_session": 113,
    "test_actor_rig_session": 8425, "test_tick_failure_regression": None,
    "test_liquid_solver_policy": 642, "test_liquid_physical_preparation": 62,
    "test_liquid_water_reference_body": 75,
}

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def numeric(value: object) -> bool:
    return type(value) in (int, float)

def distribution(values: list[float]) -> dict:
    return {"n": len(values), "min": min(values), "median": statistics.median(values), "max": max(values)}

def reduce(host: Path) -> dict:
    processes = json.loads((host / "processes.json").read_text())
    before = json.loads((host / "identity-before.json").read_text())
    after = json.loads((host / "identity-after.json").read_text())
    assert processes["source_commit"] == before["source_commit"] == after["source_commit"] == SOURCE
    assert processes["source_tree"] == before["source_tree"] == after["source_tree"] == TREE
    assert before["initial_git_status"] == ""
    assert after["source_drift"] == after["runtime_drift"] == []
    assert before["source_inputs_count"] == after["source_inputs_count"] == 1109
    assert before["prior_754_source_inputs_unchanged"]
    assert processes["source_inputs_unchanged"] and processes["runtime_bytes_unchanged"]
    assert processes["status"] == "passed"
    records = {r["name"]: r for r in processes["results"]}
    assert len(records) == len(processes["results"]) == 16
    assert set(records) == set(COUNTS) | {"import"}
    for name, record in records.items():
        assert record["status"] == "passed" and record["returncode"] == 0 and record["natural_completion"]
        assert not record["diagnostic_error"] and not record["skip_messages"]
        log = host / record["log"]
        assert digest(log) == record["log_sha256"]
        text = log.read_text()
        assert "SCRIPT ERROR:" not in text and "ERROR:" not in text
        assert not re.search(r"\bskipped\b|^\s*SKIP\b", text, re.I | re.M)
        if name == "import":
            continue
        if name == "test_tick_failure_regression":
            assert "Tick failure regression: passed" in text
            continue
        count = COUNTS[name]
        assert re.search(rf"\b{count} assertions\b|\bassertions={count}\b|\bchecks={count}\b", text)
        assert re.search(r"\b0 failures\b|\bfailures=0\b|\b0 failed\b", text)

    packets = {}
    for filename, case, marker in (
        ("metered-drain-native-host.json", "test_physical_metered_drain", "METERED_DRAIN_PACKET"),
        ("metered-drain-desktop-host.json", "test_physical_metered_desktop", "PHYSICAL_METERED_DESKTOP_PACKET"),
    ):
        files = list(host.glob("xdg-data/godot/app_userdata/*/" + filename))
        assert len(files) == 1
        path = files[0]
        raw_hash = digest(path)
        log = (host / records[case]["log"]).read_text()
        matches = re.findall(rf"^{marker} path=(.+) sha256=([0-9a-f]{{64}})(?: rows=\d+)?$", log, re.M)
        assert len(matches) == 1 and matches[0][1] == raw_hash
        packet = json.loads(path.read_text())
        assert packet["failures"] == 0
        packets[filename] = {"file": path.relative_to(host).as_posix(), "sha256": raw_hash,
                             "bytes": path.stat().st_size, "data": packet}
    native = packets["metered-drain-native-host.json"]["data"]
    desktop = packets["metered-drain-desktop-host.json"]["data"]
    assert native["schema"] == "in-tools-metered-drain-native-host-v1"
    assert desktop["schema"] == "in-tools-metered-drain-desktop-host-v1"
    assert native["checks"] == 1613 and desktop["assertions"] == 147
    # The final additional assertion in each process checks writing its packet.
    assert native["fixture_sha256"] == "50a5ce0f6fc6d61add58e307e40cf3570849b354a5d61edc9ed8413e254aae12"
    assert desktop["fixture_sha256"] == "f1f9a606172b7d123f90b3d41c56adcc4e33e770c7da249fd331bd7cd5032d0b"
    assert len(native["rows"]) == 68 and len(native["commands"]) == 69 and len(desktop["reports"]) == 18

    command_rows = []
    for index, command in enumerate(native["commands"], 1):
        assert command["outcome_index"] == index
        receipt = command["receipt"]
        observation = receipt.get("metered_drain")
        if not observation:
            assert receipt["version"] == 1
            command_rows.append({"outcome_index": index, "scope": "legacy-version-1-control",
                                 "accepted": receipt["accepted"], "reason": receipt["reason"],
                                 "changed_cells": receipt["changed_cells"]})
            continue
        assert receipt["version"] == 2
        assert observation["provenance"] == "host-local-native-observation-v1"
        assert observation["sink_debit"] == observation["water_units_removed"] + observation["brine_cells_removed"]
        assert observation["budget_before"] - observation["sink_debit"] == observation["remaining_budget"]
        transitions = observation["transitions"]
        verified = [t for t in transitions if t["verified_removed"]]
        material = observation["requested_material"]
        verified_quantity = 0
        for t in verified:
            b, a = t["before"], t["after"]
            assert b["ok"] and a["ok"] and b["material"] == material and a["material"] == 0
            assert a["state_a"] == 0 and a["state_b"] == 0 and b["transient_body_id"] == 0
            assert (b["x"], b["y"]) == (a["x"], a["y"])
            verified_quantity += b["state_a"] if material == 3 else 1
        assert verified_quantity == observation["sink_debit"]
        if observation["status"] == "applied":
            assert receipt["accepted"] and observation["activation_accepted"] and observation["quantity_complete"]
            assert observation["preflight_complete"] and len(verified) == len(transitions) == receipt["changed_cells"]
            assert 0 < observation["sink_debit"] <= observation["requested_quantity_budget"]
            assert observation["world_instance_id"] == command["world_instance_observed"] != 0
            assert observation["native_generation"] == command["native_generation_observed"]
            assert observation["completed_tick_after"] == command["completed_tick_observed"]
            assert observation["applied_policy"]["policy_hash"] == observation["requested_policy_hash"]
            assert observation["charge_cost"] == 0.85 and observation["cooldown_after"] == 0.10
        elif observation["status"] == "refused":
            assert not receipt["accepted"] and not observation["activation_accepted"]
            assert not transitions and observation["writes_attempted"] == 0 and observation["sink_debit"] == 0
            assert observation["charge_cost"] == 0.0
        else:
            assert observation["status"] == "fault" and not receipt["accepted"]
            assert not observation["quantity_complete"] and observation["charge_cost"] == 0.0
        scalars = {k: v for k, v in observation.items() if not isinstance(v, (dict, list))}
        command_rows.append({"outcome_index": index, "scope": "host-local-native-observation-v1",
                             "request": {k: v for k, v in receipt.items() if not isinstance(v, (dict, list))},
                             "observation": scalars,
                             "observed_owner": {k: v for k, v in command.items() if k != "receipt"},
                             "verified_transition_count": len(verified),
                             "independently_summed_verified_transition_quantity": verified_quantity})

    arms = []
    for row in native["rows"]:
        if row["case"] != "quantity-and-shutoff":
            continue
        observation = row["command"]["metered_drain"]
        unit = "water" if row["material"] == 3 else "brine"
        residual = row["initial"][unit] - observation["sink_debit"] - row["final"][unit]
        assert residual == 0 and len(row["transport_observations"]) == 8
        for tick, sample in enumerate(row["transport_observations"], 1):
            assert sample["completed_tick"] == tick and sample["quantity"] == row["final"]
        assert row["actual_claimants_max"] == max(s["actual_phase_claimants"] for s in row["transport_observations"])
        assert row["actual_claimants_max"] == (1 if row["configured_workers"] == 1 else 2)
        arms.append({"material": row["material"], "family": row["family"], "mass_bits": row["bits"],
                     "fractional": row["fractional"], "configured_workers": row["configured_workers"],
                     "actual_claimants_max": row["actual_claimants_max"], "initial": row["initial"][unit],
                     "admitted_external_source": 0, "removed": observation["sink_debit"], "final": row["final"][unit],
                     "residual": residual, "unit": "Water units" if unit == "water" else "Brine cells",
                     "remaining_budget": observation["remaining_budget"], "charge": row["command"]["charge"],
                     "cooldown": row["command"]["cooldown"], "completed_shutoff_ticks": 8,
                     "policy_hash": observation["applied_policy"]["policy_hash"],
                     "radius": observation["applied_policy"]["maximum_rule_radius"],
                     "construction_receipt_hash": row["construction_receipt_hash"],
                     "world_instance_id": observation["world_instance_id"], "native_generation": observation["native_generation"],
                     "command_owner_usec": row["command_owner_usec"], "helper_usec": observation["command_overhead_usec"],
                     "native_tick_ms": row["native_tick_ms"]})
    assert len(arms) == 16
    desktop_rows = []
    for row in desktop["reports"]:
        if "initial" not in row:
            continue
        water = row["case"] != "brine-in-main"
        final = row["water_units_final"] if water else row["brine_cells_final"]
        sink = row["sink_debit"]
        ordinary = row["ordinary_control_sink_from_joined_censuses"]
        assert row["initial"] - sink - ordinary == final
        desktop_rows.append({"case": row["case"], "initial": row["initial"], "removed_metered": sink,
                             "ordinary_endpoint_difference": ordinary, "final": final, "residual": 0,
                             "unit": "Water units" if water else "Brine cells", "completed_tick": row["native_tick"],
                             "world_instance_id": row["ledger"]["world_instance_id"],
                             "native_generation": row["ledger"]["native_generation"],
                             "policy_hash": row["ledger"]["policy_hash"],
                             "water_allowance_remaining": row["ledger"]["water_units_remaining"],
                             "brine_allowance_remaining": row["ledger"]["brine_cells_remaining"],
                             "worker_observed": row["worker_readback"]["values"]["worker_threads_observed"]})
    assert len(desktop_rows) == 9
    witness = next(r for r in desktop["reports"] if r["case"] == "actual-rapier-protected-source-positions")
    assert len(witness["before_cells"]) == len(witness["after_cells"]) == 6
    expected_positions = {(100, 106), (97, 107), (98, 107), (99, 107), (100, 107), (101, 107)}
    assert {(c["x"], c["y"]) for c in witness["before_cells"]} == expected_positions
    assert witness["after_tick"] > witness["before_tick"]
    for old, new in zip(witness["before_cells"], witness["after_cells"]):
        # These are separate completed ticks, not duplicate endpoint snapshots.
        assert old["completed_tick"] == witness["before_tick"]
        assert new["completed_tick"] == witness["after_tick"]
        assert {k: v for k, v in old.items() if k != "completed_tick"} == {k: v for k, v in new.items() if k != "completed_tick"}
        assert old["material"] == 3 and old["state_a"] == 255 and old["transient_body_id"] == 1
    fault_rows = []
    for row in native["rows"]:
        if row["case"] not in ("skip-second-erase", "invalid-post-read"):
            continue
        m = row["receipt"]["metered_drain"]
        actual = row["initial"]["water"] - row["final"]["water"]
        assert actual == 255 and row["terminal"] and not m["quantity_complete"]
        fault_rows.append({"case": row["case"], "scope": row["scope"], "actual_removed_by_independent_census": actual,
                           "verified_sink_debit": m["sink_debit"], "unverified_actual_difference": actual - m["sink_debit"],
                           "quantity_complete": False, "writes_attempted": m["writes_attempted"], "terminal": True})
    assert len(fault_rows) == 2
    status_counts = Counter(c.get("observation", {}).get("status", "legacy-version-1-control") for c in command_rows)
    assert status_counts == {"applied": 27, "refused": 37, "fault": 2, "legacy-version-1-control": 3}
    return {
        "schema": "in-tools-383-independent-host-reduction-v1", "status": "PASS", "source_commit": SOURCE, "source_tree": TREE,
        "reducer_sha256": digest(Path(__file__)), "source_input_count_unchanged": 1109,
        "process_count": 16, "scoped_test_count": 15, "counted_assertions": sum(c for c in COUNTS.values() if c),
        "genuine_failed_tick_suite": "PASS; footer carries no numerical assertion count",
        "packet_assertion_count_note": "1613 and 147 are pre-write packet counts; final footers add one successful packet-write assertion each",
        "packet_custody": {k: {f: v for f, v in item.items() if f != "data"} for k, item in packets.items()},
        "commands": command_rows, "command_status_counts": dict(status_counts), "quantity_arms": arms,
        "desktop_quantity_rows": desktop_rows, "protected_source_witness": witness, "injected_faults": fault_rows,
        "timing_scope": "16 controlled accepted operations; instrumented local container; timings are exploratory, not rendered pacing or a production budget",
        "command_owner_usec": distribution([r["command_owner_usec"] for r in arms]),
        "helper_usec": distribution([r["helper_usec"] for r in arms]),
        "native_tick_ms": distribution([v for r in arms for v in r["native_tick_ms"]]),
        "physical_input": "UNTESTED", "rendered_desktop": "UNTESTED", "windows_execution": "UNTESTED",
        "receipt_scope": "Native initial construction receipt and host-composed command observation are separate; no native-issued per-command transaction receipt",
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = reduce(args.host_dir)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: result[k] for k in ("status", "scoped_test_count", "counted_assertions", "command_status_counts", "command_owner_usec", "helper_usec", "native_tick_ms")}))
