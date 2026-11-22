#!/usr/bin/env python3
"""Real-process lifecycle checks for the reconstructed qualification runner."""
from __future__ import annotations

import json
from copy import deepcopy
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import run_resilience as runner_module
from run_resilience import CommandRunner, RunnerCancelled, fingerprint, read_selection


def running(pid):
    try:
        stat = Path(f"/proc/{pid}/stat").read_text()
        return stat.rsplit(") ", 1)[1][0] != "Z"
    except FileNotFoundError:
        return False


def wait_file(path, timeout=8):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.is_file() and path.stat().st_size:
            return
        time.sleep(0.025)
    raise AssertionError(f"Child did not create {path}")


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="gentek-runner-test-")
        self.out = Path(self.temporary.name)
        self.manifest = {"commands": []}
        self.manifest_path = self.out / "manifest.json"
        self.runner = CommandRunner(self.out, self.manifest, self.save, cwd=self.out, grace_seconds=1)

    def tearDown(self):
        self.temporary.cleanup()

    def save(self):
        self.manifest_path.write_text(json.dumps(self.manifest))

    def assert_stopped(self, *pids):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline and any(running(pid) for pid in pids):
            time.sleep(0.025)
        try:
            self.assertFalse([pid for pid in pids if running(pid)], "Live descendant survived runner cleanup")
        finally:
            for pid in pids:
                if running(pid):
                    try:
                        os.kill(pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass

    def test_success_and_failure_receipts(self):
        receipt = self.runner.execute("success", [sys.executable, "-c", "print('native result retained')"], 10)
        self.assertEqual(receipt["outcome"], "PASS")
        self.assertEqual(receipt["exit_code"], 0)
        self.assertEqual(receipt["log_sha256"], fingerprint(self.out / "success.log"))
        self.assertIn("native result retained", (self.out / "success.log").read_text())
        with self.assertRaises(RuntimeError):
            self.runner.execute("failed", [sys.executable, "-c", "raise SystemExit(7)"], 10)
        persisted = json.loads(self.manifest_path.read_text())["commands"]
        self.assertEqual(persisted[-1]["outcome"], "FAIL")
        self.assertEqual(persisted[-1]["exit_code"], 7)
        with self.assertRaises(ValueError):
            self.runner.execute("success", [sys.executable, "-c", "print('overwrite')"], 10)
        self.assertEqual((self.out / "success.log").read_text(), "native result retained\n")

    def test_timeout_stops_command_and_descendant(self):
        pidfile = self.out / "pids.json"
        script = ("import json,os,pathlib,subprocess,sys,time; "
                  "child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(300)']); "
                  f"pathlib.Path({str(pidfile)!r}).write_text(json.dumps([os.getpid(),child.pid])); "
                  "time.sleep(300)")
        with self.assertRaises(RuntimeError):
            self.runner.execute("timeout", [sys.executable, "-c", script], 0.3)
        self.assertEqual(self.manifest["commands"][-1]["outcome"], "TIMEOUT")
        self.assert_stopped(*json.loads(pidfile.read_text()))

    def test_launch_window_cancellation_has_child_identity(self):
        original = subprocess.Popen
        children = []

        def launch(*args, **kwargs):
            child = original(*args, **kwargs)
            children.append(child.pid)
            os.kill(os.getpid(), signal.SIGTERM)
            return child

        with patch("run_resilience.subprocess.Popen", launch):
            with self.assertRaises(RunnerCancelled):
                self.runner.execute("launch-cancel", [sys.executable, "-c", "import time; time.sleep(300)"], 10)
        self.assertEqual(self.manifest["commands"][-1]["outcome"], "CANCELLED")
        self.assertEqual(self.manifest["commands"][-1]["cancellation_signal"], "SIGTERM")
        self.assert_stopped(*children)

    def test_nested_cancellation_reaches_separate_child_group(self):
        here = Path(__file__).resolve().parent
        leaf_pid = self.out / "leaf.pid"
        nested_out = self.out / "nested"
        nested_out.mkdir()
        leaf = ("import os,pathlib,time; "
                f"pathlib.Path({str(leaf_pid)!r}).write_text(str(os.getpid())); time.sleep(300)")
        nested = self.out / "nested.py"
        nested.write_text("\n".join([
            "import json,sys", "from pathlib import Path", f"sys.path.insert(0,{str(here)!r})",
            "from run_resilience import CommandRunner,RunnerCancelled", f"out=Path({str(nested_out)!r})", "m={'commands':[]}",
            "def save(): (out/'manifest.json').write_text(json.dumps(m))",
            "try:", f"    CommandRunner(out,m,save,grace_seconds=1).execute('leaf',[sys.executable,'-c',{leaf!r}],300)",
            "except RunnerCancelled: raise SystemExit(3)", ""]))
        outer_out = self.out / "outer"
        outer_out.mkdir()
        driver = self.out / "driver.py"
        driver.write_text("\n".join([
            "import json,sys", "from pathlib import Path", f"sys.path.insert(0,{str(here)!r})",
            "from run_resilience import CommandRunner,RunnerCancelled", f"out=Path({str(outer_out)!r})", "m={'commands':[]}",
            "def save(): (out/'manifest.json').write_text(json.dumps(m))",
            "try:", f"    CommandRunner(out,m,save,grace_seconds=4).execute('nested',[sys.executable,{str(nested)!r}],300)",
            "except RunnerCancelled: raise SystemExit(3)", ""]))
        with (self.out / "driver.log").open("w") as log:
            process = subprocess.Popen([sys.executable, str(driver)], stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                wait_file(leaf_pid)
                pid = int(leaf_pid.read_text())
                process.send_signal(signal.SIGTERM)
                self.assertEqual(process.wait(timeout=10), 3)
                self.assertEqual(json.loads((outer_out / "manifest.json").read_text())["commands"][0]["outcome"], "CANCELLED")
                self.assertEqual(json.loads((nested_out / "manifest.json").read_text())["commands"][0]["outcome"], "CANCELLED")
                self.assert_stopped(pid)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
                if leaf_pid.is_file():
                    self.assert_stopped(int(leaf_pid.read_text()))

    def test_launch_error_is_retained(self):
        with self.assertRaises(RuntimeError):
            self.runner.execute("absent-executable", [self.out / "does-not-exist"], 5)
        saved = json.loads(self.manifest_path.read_text())["commands"][0]
        self.assertEqual(saved["outcome"], "ERROR")
        self.assertIsNone(saved["exit_code"])
        self.assertIn("FileNotFoundError", saved["error"])

    def test_fresh_validation_requires_committed_exact_selection(self):
        path = self.out / "SELECTION-CONTINUATION.json"
        value = {"selected_policy": "native_receiver_six", "fresh_validation_seeds": [8191, 12289]}
        path.write_text(json.dumps(value) + "\n")

        def frozen_git(*args):
            if args[0] in ("hash-object", "rev-parse"):
                return "2" * 40
            if args[0] == "log":
                return "1" * 40
            return path.name

        receipt = read_selection(path, "native_receiver_six", True, self.out, frozen_git)
        self.assertEqual(receipt["selected_policy"], "native_receiver_six")
        with self.assertRaises(ValueError):
            read_selection(path, "native_receiver_six", False, self.out, frozen_git)
        with self.assertRaises(ValueError):
            read_selection(path, "native_receiver_eight", True, self.out, frozen_git)
        def changed_git(*args):
            return "3" * 40 if args[0] == "hash-object" else frozen_git(*args)
        with self.assertRaises(ValueError):
            read_selection(path, "native_receiver_six", True, self.out, changed_git)
        value["fresh_validation_seeds"] = [2718, 4099]
        path.write_text(json.dumps(value))
        with self.assertRaises(ValueError):
            read_selection(path, "native_receiver_six", True, self.out, frozen_git)

    def test_source_custody_detects_git_hidden_mutation_and_deletion(self):
        root = self.out / "source-repo"
        harness = root / "harness"
        harness.mkdir(parents=True)
        source = harness / "source.cpp"
        original = b"int source_identity = 1;\n"
        source.write_bytes(original)
        (root / "donor.cpp").write_text("int frozen_donor = 1;\n")

        def local_git(*args):
            return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.STDOUT, timeout=10).decode().strip()

        local_git("init", "-q")
        local_git("add", ".")
        local_git("-c", "user.name=Custody Test", "-c", "user.email=custody-test@example.invalid",
                  "commit", "-qm", "frozen inputs")
        with patch.multiple(runner_module, ROOT=root, HERE=harness, HARNESS=Path("harness"),
                            DONORS=[Path("donor.cpp")], git=local_git):
            runner_module.verify_committed_inputs(runner_module.retained_source_inputs())
            local_git("update-index", "--assume-unchanged", "harness/source.cpp")
            source.write_text("int source_identity = 2;\n")
            self.assertEqual(local_git("status", "--porcelain"), "")
            with self.assertRaisesRegex(ValueError, "differs from committed HEAD"):
                runner_module.verify_committed_inputs(runner_module.retained_source_inputs())
            source.write_bytes(original)
            local_git("update-index", "--no-assume-unchanged", "harness/source.cpp")
            local_git("update-index", "--skip-worktree", "harness/source.cpp")
            source.unlink()
            self.assertEqual(local_git("status", "--porcelain"), "")
            with self.assertRaisesRegex(ValueError, "inventory differs from committed HEAD"):
                runner_module.verify_committed_inputs(runner_module.retained_source_inputs())


class HistoricalEquivalenceTests(unittest.TestCase):
    """Mutations must not hide inside reviewed prose/accounting exemptions."""

    def setUp(self):
        self.gate = runner_module.HistoricalEquivalence()

    def pair(self):
        # A small structural fixture for the comparison layer, using one
        # observed old/new accounting pair. Native legality is independently
        # checked by the C++ suites and gallery, not inferred by this fixture.
        domains = [{"influences": [{"slot_id": i}] if i < 4 else [], "modified_domain": 1, "selected": -1} for i in range(84)]
        attempt = {"solver": {"status": "unsat", "attempted": True, "work": None, "work_observed": False, "work_limit": 4_000_000},
                   "categories": [-1] * 84, "domains": [1] * 84, "optional_ids": [1, 2, 3, 4]}
        result = {"status": "unsat", "work": 52307, "solver_work": 0, "cells": [0] * 84,
                  "roles": [0] * 84, "metrics": {"resilience_solver_receipt_work": 3840, "resilience_domain_preparation_work": 16},
                  "notes": []}
        before = {"schema": 4, "options": {"receivers": "closed-only", "optional_capacity": 4},
                  "trace": {"solver": {"width": 12, "height": 7, "category_ids": list(range(16)), "preparation_work": 3840,
                              "aggregate_limit": 4_000_000, "allocated_limit": 4_000_000, "attempts": [attempt]},
                            "receivers": [], "admission": {"work": 0}, "final_authorized_ids": [1, 2, 3, 4]},
                  "candidate": {"mosaic": {"domains": domains, "responses": [{"slot_id": i} for i in range(4)], "result": result,
                                            "categories": [-1] * 84},
                                "final_mosaic": deepcopy(result), "cells": [0] * 84, "seams": [],
                                "mosaic_request": {"limits": {"work": 2_000_000, "solver_work": 4_000_000}},
                                "metrics": {"candidate_generator_work": 115997, "candidate_charged_work_upper_bound": 10_000_000}}}
        after = deepcopy(before)
        after["trace"]["solver"]["preparation_work"] = 3712
        for result in (after["candidate"]["mosaic"]["result"], after["candidate"]["final_mosaic"]):
            result["work"] = 52179
            result["metrics"]["resilience_solver_receipt_work"] = 3712
        after["candidate"]["metrics"]["candidate_generator_work"] = 115869
        return before, after

    def test_reviewed_accounting_and_prose_remain_visible(self):
        before, after = self.pair()
        old = "No partial assignment is rasterised; failed-attempt work remains unavailable and exhaustion is not UNSAT."
        new = "No partial categorical assignment is rasterised; failed donor work is unavailable, not fabricated."
        before["candidate"]["mosaic"]["result"]["notes"] = [old]
        after["candidate"]["mosaic"]["result"]["notes"] = [new]
        report = self.gate.compare(before, after)
        self.assertTrue(report["equivalent"], report)
        self.assertFalse(report["accounting_errors"])
        self.assertTrue(report["differences"])
        self.assertEqual(next(d for d in report["differences"] if d["path"].endswith("/notes/0"))["before"], old)

    def test_native_domain_path_status_limits_and_donor_work_stay_strict(self):
        mutations = {
            "cell": lambda d: d["candidate"]["cells"].__setitem__(0, 62),
            "domain": lambda d: d["candidate"]["mosaic"]["domains"][0].__setitem__("modified_domain", 3),
            "assignment": lambda d: d["candidate"]["mosaic"]["categories"].__setitem__(0, 0),
            "path": lambda d: d["candidate"]["seams"].append({"joined": True, "cells": [[0, 0], [1, 0]]}),
            "status": lambda d: d["candidate"]["mosaic"]["result"].__setitem__("status", "complete"),
            "limit": lambda d: d["candidate"]["mosaic_request"]["limits"].__setitem__("solver_work", 4_000_001),
            "donor work": lambda d: d["trace"]["solver"]["attempts"][0]["solver"].__setitem__("work", 1),
            "authority": lambda d: d["trace"]["final_authorized_ids"].append(5),
            "unknown metric": lambda d: d["candidate"]["metrics"].__setitem__("invented_counter", 0),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                before, after = self.pair()
                mutate(after)
                report = self.gate.compare(before, after)
                self.assertFalse(report["equivalent"])
                self.assertTrue(report["unexpected_differences"])

    def test_nested_numeric_types_are_never_conflated(self):
        mutations = (
            lambda d: d["candidate"]["cells"].__setitem__(0, False),
            lambda d: d["candidate"]["mosaic"]["categories"].__setitem__(0, -1.0),
            lambda d: d["candidate"]["mosaic"]["domains"][0].__setitem__("modified_domain", True),
            lambda d: d["trace"]["solver"]["attempts"][0]["solver"].__setitem__("attempted", 1),
        )
        for mutate in mutations:
            before, after = self.pair()
            mutate(after)
            report = self.gate.compare(before, after)
            self.assertFalse(report["equivalent"])
            self.assertTrue(any(d["kind"] == "type" for d in report["unexpected_differences"]))

    def test_failed_category_shape_and_unknown_prose_reject(self):
        before, after = self.pair()
        after["trace"]["solver"]["attempts"][0]["categories"] = []
        self.assertFalse(self.gate.compare(before, after)["equivalent"])
        before, after = self.pair()
        before["candidate"]["mosaic"]["result"]["notes"] = ["No partial assignment is rasterised; failed-attempt work remains unavailable and exhaustion is not UNSAT."]
        after["candidate"]["mosaic"]["result"]["notes"] = ["An unreviewed new claim"]
        self.assertFalse(self.gate.compare(before, after)["equivalent"])

    def test_accounting_reconciliation_and_formula_cannot_be_bypassed(self):
        before, after = self.pair()
        after["trace"]["solver"]["preparation_work"] = 3776
        for result in (after["candidate"]["mosaic"]["result"], after["candidate"]["final_mosaic"]):
            result["metrics"]["resilience_solver_receipt_work"] = 3776
            result["work"] += 64
        after["candidate"]["metrics"]["candidate_generator_work"] += 64
        report = self.gate.compare(before, after)
        self.assertFalse(report["equivalent"])
        self.assertIn("Reconstructed solver preparation formula differs", report["accounting_errors"])
        for invalid in (True, -1, 3712.0):
            before, after = self.pair()
            after["trace"]["solver"]["preparation_work"] = invalid
            self.assertFalse(self.gate.compare(before, after)["equivalent"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
