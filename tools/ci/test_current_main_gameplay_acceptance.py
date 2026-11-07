#!/usr/bin/env python3
import copy
import tempfile
import unittest
from pathlib import Path
import importlib.util

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("acceptance", HERE / "current_main_gameplay_acceptance.py")
acceptance = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(acceptance)


def profile(name):
    return {
        "name": name,
        "completed": True,
        "elapsed_wall_ms": 60000.0,
        "completed_native_ticks": 100,
        "completed_rapier_ticks": 100,
        "completed_native_hz": 20.0,
        "completed_rapier_hz": 20.0,
        "water_checks": 100,
        "water_mismatches": 0,
        "screenshot": name + ".png",
        "spray_final": {"totals": {"launched": 1, "lifted": 0}, "ledger": {"launched_parcels": 2}},
        "water_assignment": {"applied_family": "pressure_flow_v1", "applied_variant": "cached_dormant"},
        "process_interval_ms": {"p95": 16.7},
        "native_tick_ms": {"p95": 10.0},
        "retained_snapshot_age_ms": {"p95": 20.0},
        "main_workbench_terrain_gate_ms": {"p95": 0.5},
        "rapier_wait_callbacks": 1,
        "rapier_callbacks": 100,
        "hard_surface_revision_changes": 2,
    }


def accepted():
    return {
        "schema": acceptance.SCHEMA,
        "registered_main": acceptance.BASE_MAIN,
        "source_revision": "a" * 40,
        "platform": "Windows",
        "display_server": "windows",
        "godot": "4.7.stable",
        "profiles": [profile(name) for name in acceptance.REQUIRED_PROFILES],
        "failures": 0,
        "worker_joined": True,
    }


class AcceptanceEvaluationTests(unittest.TestCase):
    def test_complete_evidence_accepts_without_performance_thresholds(self):
        verdict, problems = acceptance.evaluate(accepted())
        self.assertEqual(("ACCEPT", []), (verdict, problems))

    def test_water_mismatch_repairs(self):
        data = accepted()
        data["profiles"][1]["water_mismatches"] = 1
        verdict, problems = acceptance.evaluate(data)
        self.assertEqual("REPAIR", verdict)
        self.assertTrue(any("Water conservation" in problem for problem in problems))

    def test_slow_but_complete_profile_is_not_rejected(self):
        data = accepted()
        data["profiles"][2]["completed_native_hz"] = 0.5
        data["profiles"][2]["native_tick_ms"] = {"p95": 1900.0}
        self.assertEqual("ACCEPT", acceptance.evaluate(data)[0])

    def test_missing_screenshot_and_ballistic_transport_repair(self):
        data = accepted()
        data["profiles"][0]["screenshot"] = ""
        data["profiles"][0]["spray_final"]["ledger"]["launched_parcels"] = 0
        verdict, problems = acceptance.evaluate(data)
        self.assertEqual("REPAIR", verdict)
        self.assertGreaterEqual(len(problems), 2)

    def test_package_requires_at_least_one_body_impact_spray_profile(self):
        data = accepted()
        for row in data["profiles"]:
            row["spray_final"]["totals"] = {"launched": 0, "lifted": 0}
        verdict, problems = acceptance.evaluate(data)
        self.assertEqual("REPAIR", verdict)
        self.assertTrue(any("body-driven impact spray" in problem for problem in problems))

    def test_summary_writes_markdown_csv_and_machine_record(self):
        data = accepted()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            results = root / "results.json"
            results.write_text("{}", encoding="utf-8")
            data["_results_path"] = str(results)
            verdict, problems = acceptance.write_summary(
                data, root / "SUMMARY.md", root / "summary.csv", root / "qualification.json")
            self.assertEqual("ACCEPT", verdict)
            self.assertFalse(problems)
            self.assertIn("Verdict: ACCEPT", (root / "SUMMARY.md").read_text())
            self.assertIn("my-canvas", (root / "summary.csv").read_text())
            self.assertEqual("ACCEPT", __import__("json").loads(
                (root / "qualification.json").read_text())["verdict"])


if __name__ == "__main__":
    unittest.main()