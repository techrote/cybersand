#!/usr/bin/env python3
"""Real small child-process controls for Strata's CPU/RSS observer; no Godot."""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

import strata_process_metrics as metrics


class ProcessMetrics(unittest.TestCase):
    def run_child(self, code: str, timeout: float = 10):
        temporary = tempfile.TemporaryDirectory(prefix="strata-process-metrics-")
        self.addCleanup(temporary.cleanup)
        path = Path(temporary.name) / "case"
        receipt = metrics.execute([sys.executable, "-u", "-c", code], path, dict(os.environ), timeout)
        resources = json.loads((path / "resources.json").read_text())
        self.assertEqual(receipt["resources_sha256"], metrics.custody.sha(path / "resources.json"))
        self.assertEqual(receipt["log_sha256"], metrics.custody.sha(path / "process.log"))
        self.assertEqual(json.loads((path / "process.json").read_text()), receipt)
        return receipt, resources, path

    def test_actual_child_cpu_memory_and_descendant_identity(self):
        child = "import os,time; cells=bytearray(16*1024*1024); print('CHILD_PID',os.getpid(),flush=True); end=time.monotonic()+2.0\nwhile time.monotonic()<end: sum(cells[::4096])\n"
        parent = "import subprocess,sys; child=subprocess.Popen([sys.executable,'-u','-c'," + repr(child) + "]); child.wait()"
        receipt, resources, path = self.run_child(parent)
        self.assertEqual(receipt["status"], "passed")
        self.assertTrue(resources["available"])
        child_pid = int((path / "process.log").read_text().split("CHILD_PID ")[1].splitlines()[0])
        identities = {row[0] for row in resources["process_identities"]}
        self.assertEqual(identities, {receipt["pid"], child_pid})
        self.assertGreater(resources["observed_cpu_seconds"], 0)
        self.assertGreater(resources["peak_observed_tree_rss_bytes"], 16 * 1024 * 1024)
        self.assertGreaterEqual(resources["sample_count"], 2)
        self.assertTrue(any({row["pid"] for row in sample["processes"]} == identities for sample in resources["samples"]))
        for sample in resources["samples"]:
            self.assertEqual(sample["tree_rss_bytes"], sum(row["rss_bytes"] for row in sample["processes"]))
            for row in sample["processes"]:
                if row["pid"] == child_pid:
                    self.assertEqual(row["parent_pid"], receipt["pid"])

    def test_timeout_retains_original_failure_and_observations(self):
        receipt, resources, _ = self.run_child("import time; print('WAITING',flush=True); time.sleep(30)", 0.8)
        self.assertEqual(receipt["status"], "timeout")
        self.assertNotEqual(receipt["exit_code"], 0)
        self.assertTrue(resources["available"])
        self.assertIn("exceeded", receipt["error"])

    def test_zero_exit_with_script_error_remains_failed(self):
        receipt, _, _ = self.run_child("print('SCRIPT ERROR: deliberate observer control')")
        self.assertEqual(receipt["exit_code"], 0)
        self.assertEqual(receipt["status"], "failed")


if __name__ == "__main__":
    unittest.main()
