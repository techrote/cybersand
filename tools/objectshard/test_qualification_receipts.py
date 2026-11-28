"""Adversarial receipt checks; synthetic custody fixtures, not runtime evidence."""
from __future__ import annotations

import contextlib
import copy
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import native_receipt
import qualify_lab


class CompletionReceipts(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.log = Path(self.directory.name) / "run.log"
        self.schema = "objectshard-lab-integration-test-v1"
        self.good = {"schema": self.schema, "checks": 359, "failures": 0}

    def test_one_actual_completion_after_diagnostics(self) -> None:
        self.log.write_text("Godot diagnostic line\n" + json.dumps(self.good) + "\n")
        self.assertEqual(qualify_lab.footer(self.log, self.schema), self.good)

    def test_duplicate_completion_is_not_accepted(self) -> None:
        self.log.write_text((json.dumps(self.good) + "\n") * 2)
        with self.assertRaises(ValueError):
            qualify_lab.footer(self.log, self.schema)

    def test_missing_failed_and_false_typed_completion(self) -> None:
        for value in ({"schema": "wrong", "failures": 0},
                      {**self.good, "failures": 1}, {**self.good, "failures": False}):
            with self.subTest(value=value):
                self.log.write_text(json.dumps(value))
                with self.assertRaises(ValueError):
                    qualify_lab.footer(self.log, self.schema)


class NativeBuildReceipts(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.receipt = self.root / "receipt.json"
        self.binary = self.root / "candidate.so"
        # An ELF header is only a custody fixture. No executable claim follows.
        self.binary.write_bytes(b"\x7fELF\x02\x01" + bytes(12) + b"\x3e\x00" + b"fixture")
        self.source = {"source_commit": "a" * 40, "source_tree": "b" * 40,
                       "source_inputs": {"native/src/world.cpp": "c" * 64},
                       "build_contract_inputs": {"build.sh": "d" * 64}}

    def command(self, action: str, source: dict | None = None) -> None:
        argv = ["native_receipt.py", action, "--receipt", str(self.receipt),
                "--runtime", str(self.binary), "--expected-source-sha", "a" * 40]
        with patch("sys.argv", argv), patch.object(native_receipt, "identity", return_value=source or self.source), \
                contextlib.redirect_stdout(io.StringIO()):
            native_receipt.main()

    def test_capture_then_build_seal_and_verify(self) -> None:
        self.command("snapshot")
        self.command("seal")
        self.command("verify")
        self.assertEqual(json.loads(self.receipt.read_text())["phase"], "sealed")

    def test_snapshot_cannot_overwrite_previous_build_identity(self) -> None:
        self.command("snapshot")
        with self.assertRaises(ValueError):
            self.command("snapshot")

    def test_source_change_during_build_refuses_seal(self) -> None:
        self.command("snapshot")
        changed = {**self.source, "source_inputs": {"native/src/world.cpp": "e" * 64}}
        with self.assertRaises(ValueError):
            self.command("seal", changed)
        self.assertEqual(json.loads(self.receipt.read_text())["phase"], "captured")

    def test_compiler_contract_change_during_build_refuses_seal(self) -> None:
        self.command("snapshot")
        changed = {**self.source, "build_contract_inputs": {"build.sh": "e" * 64}}
        with self.assertRaises(ValueError):
            self.command("seal", changed)

    def test_altered_binary_after_seal_is_refused(self) -> None:
        self.command("snapshot")
        self.command("seal")
        self.binary.write_bytes(self.binary.read_bytes() + b"alteration")
        with self.assertRaises(ValueError):
            self.command("verify")

    def test_stale_or_unsealed_receipt_is_refused(self) -> None:
        self.command("snapshot")
        with self.assertRaises(ValueError):
            self.command("verify")
        self.command("seal")
        with self.assertRaises(ValueError):
            self.command("verify", {**self.source, "source_commit": "e" * 40})

    def test_wrong_platform_header_is_refused(self) -> None:
        self.command("snapshot")
        self.binary.write_bytes(b"MZ" + bytes(80))
        with self.assertRaises(ValueError):
            self.command("seal")


class ExecutedSourceCustody(unittest.TestCase):
    def test_missing_windows_candidate_does_not_trust_installed_dll(self) -> None:
        with self.assertRaises(ValueError):
            qualify_lab.require_custody("win32", None, None, None)

    def test_ambiguous_windows_custody_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            qualify_lab.require_custody("win32", Path("candidate"), Path("package"), None)

    def test_linux_cannot_use_windows_receipt_or_unbound_runtime(self) -> None:
        for candidate, package, receipt in ((None, None, None), (Path("candidate"), None, Path("receipt"))):
            with self.subTest(candidate=candidate, package=package, receipt=receipt):
                with self.assertRaises(ValueError):
                    qualify_lab.require_custody("linux", candidate, package, receipt)

    def test_explicit_platform_custody_is_admitted(self) -> None:
        qualify_lab.require_custody("win32", Path("candidate"), None, None)
        qualify_lab.require_custody("win32", None, Path("package"), None)
        qualify_lab.require_custody("linux", None, None, Path("receipt"))

    def test_modified_delivered_lab_script_is_not_covered_by_root_hash(self) -> None:
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            script = root / "godot/scripts/object_shard_lab_session.gd"
            script.parent.mkdir(parents=True)
            script.write_bytes(b"committed Lab source\n")
            expected = {script.relative_to(root).as_posix(): hashlib.sha256(script.read_bytes()).hexdigest()}
            self.assertEqual(qualify_lab.verify_scripts(root, expected), expected)
            script.write_bytes(b"altered delivered Lab source\n")
            with self.assertRaises(ValueError):
                qualify_lab.verify_scripts(root, expected)



class NavigationCompletionReceipts(unittest.TestCase):
    def receipt(self) -> dict:
        return {"schema": "objectshard-worker-navigation-test-v1", "source_revision": "a" * 40,
                "checks": 100, "failures": 0,
                "cases": ["active_pending_repeated", "naturally_sleeping", "opening", "reset_superseded",
                          "held_interval", "stop_delivery_faults", "already_closed_prior_policy", "window_close_upgrade"],
                "observations": [{"case": "window_close_upgrade", "child_exit_code": 0,
                                  "child_report": {"schema": "objectshard-worker-navigation-quit-child-v1",
                                                   "source_revision": "a" * 40, "checks": 18, "failures": 0}}]}

    def test_complete_source_bound_parent_and_child_are_required(self) -> None:
        result = qualify_lab.validate_navigation_receipt(self.receipt(), "a" * 40)
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["child_checks"], 18)

    def test_incomplete_case_inventory_or_changed_source_is_refused(self) -> None:
        for delta in ({"cases": []}, {"source_revision": "b" * 40}, {"checks": 99},
                      {"checks": True}, {"failures": False}, {"observations": []}):
            value = self.receipt()
            value.update(delta)
            with self.subTest(delta=delta), self.assertRaises(ValueError):
                qualify_lab.validate_navigation_receipt(value, "a" * 40)

    def test_child_exit_failure_short_checks_and_wrong_identity_are_refused(self) -> None:
        for delta in ({"checks": 17}, {"failures": 1}, {"source_revision": "b" * 40},
                      {"schema": "wrong"}, {"failures": False}):
            value = self.receipt()
            value["observations"][0]["child_report"].update(delta)
            with self.subTest(delta=delta), self.assertRaises(ValueError):
                qualify_lab.validate_navigation_receipt(value, "a" * 40)
        for exit_code in (1, False):
            value = self.receipt()
            value["observations"][0]["child_exit_code"] = exit_code
            with self.subTest(exit_code=exit_code), self.assertRaises(ValueError):
                qualify_lab.validate_navigation_receipt(value, "a" * 40)

    def test_duplicate_window_close_child_is_refused(self) -> None:
        value = self.receipt()
        value["observations"].append(copy.deepcopy(value["observations"][0]))
        with self.assertRaises(ValueError):
            qualify_lab.validate_navigation_receipt(value, "a" * 40)


class WorkerSchedulingComparison(unittest.TestCase):
    def profiles(self) -> tuple[dict, dict]:
        control = {"schema": "objectshard-worker-scheduling-profile-v1", "failures": 0,
                   "notifications": False, "pump_budget_usec": 0, "completed_intervals": 240,
                   "actual_live_inputs": 60, "actual_physics_steps": 954,
                   "identity": {"revision": "a" * 40, "files": {"script": "b" * 64}, "engine_sha256": "c" * 64},
                   "publication_digests": ["d" * 64] * 240, "native_accounting": {"inventory": 123},
                   "play_elapsed_usec": 30_000_000}
        candidate = copy.deepcopy(control)
        candidate.update(pump_budget_usec=4000, play_elapsed_usec=15_000_000)
        return control, candidate

    def test_identical_workload_qualifies_without_manufactured_speed_threshold(self) -> None:
        control, candidate = self.profiles()
        candidate["play_elapsed_usec"] = 60_000_000
        result = qualify_lab.compare_worker_profiles(control, candidate, "a" * 40)
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["wall_progression_ratio"], 0.5)

    def test_empty_or_incomplete_live_workload_is_refused(self) -> None:
        for delta in ({"actual_live_inputs": 0}, {"actual_physics_steps": 0}, {"completed_intervals": 239},
                      {"publication_digests": []}, {"notifications": True}, {"pump_budget_usec": 0}):
            control, candidate = self.profiles()
            candidate.update(delta)
            with self.subTest(delta=delta), self.assertRaises(ValueError):
                qualify_lab.compare_worker_profiles(control, candidate, "a" * 40)

    def test_changed_pose_inventory_or_source_is_refused(self) -> None:
        for key in ("publication_digests", "native_accounting", "identity"):
            control, candidate = self.profiles()
            if key == "publication_digests":
                candidate[key][120] = "e" * 64
            elif key == "native_accounting":
                candidate[key]["inventory"] += 1
            else:
                candidate[key]["files"]["script"] = "e" * 64
            with self.subTest(key=key), self.assertRaises(ValueError):
                qualify_lab.compare_worker_profiles(control, candidate, "a" * 40)


if __name__ == "__main__":
    unittest.main()
