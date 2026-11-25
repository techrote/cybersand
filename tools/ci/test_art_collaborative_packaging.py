"""Reject incomplete, stale or mis-scoped collaborative application evidence.

These receipt mutations are synthetic unit adversaries. They do not execute
Godot or qualify a Windows evaluator.
"""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools/ci"))
import package_art_collaborative as package
import run_art_collaborative_gates as gates

COMMIT = "a" * 40
TREE = "b" * 40


def fixture(graphical: bool = False) -> dict:
    return {
        "schema": gates.SCHEMA, "status": "passed", "model_calls": 0,
        "source": {"commit": COMMIT, "tree": TREE, "tracked_source_clean": True},
        "platform": "windows", "graphical": graphical,
        "runtime": {
            "godot_sha256": "c" * 64, "godot_version": "4.7.stable.official.5b4e0cb0f",
            "provenance_sha256": "d" * 64,
            "payloads": {path: "e" * 64 for path in gates.RUNTIME_PATHS["windows"]},
        },
        "cases": [{"name": name, "marker": marker, "status": "passed", "exit_code": 0,
                   "timed_out": False, "log_sha256": "f" * 64,
                   "result": {"checks": 1, "failures": [], "model_calls": 0,
                              "display": "Windows" if graphical else "headless"}}
                  for name, marker in gates.TESTS.items()],
    }


class CollaborativeReceiptBoundary(unittest.TestCase):
    def validate(self, value: dict, graphical: bool = False) -> dict:
        return gates.validate_receipt(value, commit=COMMIT, tree=TREE,
                                      platform_name="windows", graphical=graphical)

    def test_complete_synthetic_receipt_is_structurally_admitted(self):
        for graphical in (False, True):
            value = fixture(graphical)
            self.assertIs(self.validate(value, graphical), value)

    def test_incomplete_or_duplicate_case_inventory_refuses(self):
        for mutation in ("missing", "duplicate", "unknown"):
            value = fixture()
            if mutation == "missing":
                value["cases"].pop()
            elif mutation == "duplicate":
                value["cases"][-1] = copy.deepcopy(value["cases"][0])
            else:
                value["cases"][-1]["name"] = "not_a_registered_case"
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.validate(value)

    def test_every_nonpass_process_disposition_refuses(self):
        for field, bad in (("status", "skipped"), ("exit_code", 1), ("exit_code", None), ("timed_out", True)):
            value = fixture()
            value["cases"][0][field] = bad
            with self.subTest(field=field, bad=bad), self.assertRaises(ValueError):
                self.validate(value)

    def test_case_failure_empty_checks_marker_and_hash_refuse(self):
        mutations = [
            lambda row: row.update(marker="UNRELATED_PASS"),
            lambda row: row.update(log_sha256="not-a-hash"),
            lambda row: row["result"].update(failures=["a failed assertion"]),
            lambda row: row["result"].update(checks=0),
            lambda row: row["result"].update(model_calls=1),
        ]
        for mutation in mutations:
            value = fixture()
            mutation(value["cases"][0])
            with self.assertRaises(ValueError):
                self.validate(value)

    def test_stale_source_and_dirty_source_refuse(self):
        for key, bad in (("commit", "0" * 40), ("tree", "0" * 40), ("tracked_source_clean", False)):
            value = fixture()
            value["source"][key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(value)

    def test_wrong_platform_or_display_scope_refuses(self):
        for key, bad in (("platform", "linux"), ("graphical", True), ("model_calls", 1),
                         ("status", "running"), ("schema", "legacy")):
            value = fixture()
            value[key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(value)

    def test_missing_native_rapier_or_engine_identity_refuses(self):
        value = fixture()
        value["runtime"]["payloads"].pop(next(iter(value["runtime"]["payloads"])))
        with self.assertRaises(ValueError):
            self.validate(value)
        for key, bad in (("godot_sha256", ""), ("godot_version", "another-engine")):
            value = fixture()
            value["runtime"][key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(value)

    def test_pair_must_use_identical_payloads(self):
        headless, displayed = fixture(), fixture(True)
        package.validate_pair(headless, displayed)
        displayed["runtime"]["godot_sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            package.validate_pair(headless, displayed)

    def test_marker_parser_requires_one_complete_success(self):
        marker = "FIXTURE_RESULT"
        valid = '{"checks":2,"failures":[],"model_calls":0}'
        self.assertEqual(gates.parse_case_output(marker + " " + valid, marker)["checks"], 2)
        for content in ("", marker + " " + valid + "\n" + marker + " " + valid,
                        marker + ' {"checks":2,"failures":["failure"]}',
                        marker + ' {"checks":0,"failures":[]}',
                        marker + " invalid"):
            with self.subTest(content=content[:40]), self.assertRaises((ValueError, json.JSONDecodeError)):
                gates.parse_case_output(content, marker)

    def test_packager_requires_complete_original_logs(self):
        value = fixture()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "summary.json"
            for case in value["cases"]:
                log = path.parent / case["name"] / "process.log"
                log.parent.mkdir()
                log.write_text(case["marker"] + " " + json.dumps(case["result"]) + "\n", encoding="utf-8")
                case["log_sha256"] = hashlib.sha256(log.read_bytes()).hexdigest()
            path.write_text(json.dumps(value), encoding="utf-8")
            package.receipt(path, COMMIT, TREE, False)
            value["cases"][0]["result"]["checks"] += 1
            path.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(ValueError):
                package.receipt(path, COMMIT, TREE, False)
            value["cases"][0]["result"]["checks"] -= 1
            path.write_text(json.dumps(value), encoding="utf-8")
            log.write_text("changed log\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                package.receipt(path, COMMIT, TREE, False)
            log.unlink()
            with self.assertRaises(ValueError):
                package.receipt(path, COMMIT, TREE, False)

    def test_graphical_receipt_requires_actual_ui_backend_field(self):
        value = fixture(True)
        ui = next(case for case in value["cases"] if case["name"] == "test_art_collaboration_workspace")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "summary.json"
            for bad in (None, "", "headless"):
                ui["result"]["display"] = bad
                path.write_text(json.dumps(value), encoding="utf-8")
                with self.subTest(display=bad), self.assertRaises(ValueError):
                    package.receipt(path, COMMIT, TREE, True, check_logs=False)


if __name__ == "__main__":
    unittest.main()
