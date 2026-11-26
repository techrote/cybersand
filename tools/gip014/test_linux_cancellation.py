"""Synthetic programme controls: explicit interruption cannot start another stage."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import qualify_linux


class LinuxCancellationControls(unittest.TestCase):
    def invoke(self, root, *, interrupt=None, memory_status="pass"):
        engine = root / "synthetic-engine"
        engine.write_bytes(b"not executable; all dispatch is mocked")
        output = root / "output"
        calls = []

        def process(command, env, log, timeout):
            phase = "graphical" if log.name == "graphical-driver.log" else "python-contracts"
            calls.append(phase)
            stopped = interrupt == phase
            log.write_text("Synthetic process receipt; no native execution.\n")
            return {"status": "cancelled" if stopped else "pass", "interrupted": stopped,
                    "exit_code": 130 if stopped else 0, "surviving_owned_pids": []}

        def source(argv):
            phase = argv[argv.index("--case") + 1]
            calls.append(phase)
            return 130 if phase == interrupt else 0

        def memory(godot, folder):
            calls.append("memory")
            folder.mkdir()
            result = {"status": memory_status, "operator_cancelled": interrupt == "memory",
                      "supervisor": {"interrupted": interrupt == "memory"}}
            (folder / "memory-qualification.json").write_text(json.dumps(result))
            return result

        def queue(argv):
            calls.append("queue")
            return 0

        with patch.object(qualify_linux.run_goblin, "git", return_value="a" * 40), \
                patch.object(qualify_linux.run_goblin, "runtime_identity", return_value={
                    "source_dirty": False, "source_commit": "a" * 40}), \
                patch.object(qualify_linux.run_goblin, "execute", side_effect=process), \
                patch.object(qualify_linux.run_goblin, "main", side_effect=source), \
                patch.object(qualify_linux.qualify_reproduction, "qualify", return_value={"status": "pass"}), \
                patch.object(qualify_linux.qualify_memory, "qualify", side_effect=memory), \
                patch.object(qualify_linux.campaign_queue, "main", side_effect=queue), \
                contextlib.redirect_stdout(io.StringIO()):
            code = qualify_linux.main(["--godot", str(engine), "--out", str(output), "--plan", "smoke"])
        return code, calls, json.loads((output / "linux-qualification.json").read_text())

    def test_each_explicit_stop_is_terminal_and_retains_its_stage(self):
        for phase in ("python-contracts", "discovery", "graphical", "memory"):
            with self.subTest(phase=phase), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                code, calls, report = self.invoke(root, interrupt=phase)
                self.assertEqual(code, 130)
                self.assertEqual(calls[-1], phase)
                self.assertNotIn("queue", calls)
                self.assertEqual(report["status"], "cancelled")
                self.assertTrue(report["operator_cancelled"])
                self.assertEqual(report["steps"][-1]["status"], "cancelled")
                self.assertEqual(report["steps"][-1]["exit_code"], 130)
                if phase in ("python-contracts", "graphical"):
                    name = "graphical-driver.json" if phase == "graphical" else "python-contracts.json"
                    self.assertTrue(json.loads((root / "output" / name).read_text())["interrupted"])
                elif phase == "memory":
                    self.assertTrue(json.loads((root / "output/memory-experiment/memory-qualification.json").read_text())["operator_cancelled"])

    def test_ordinary_memory_failure_keeps_independent_queue_and_failed_outcome(self):
        with tempfile.TemporaryDirectory() as folder:
            code, calls, report = self.invoke(Path(folder), memory_status="incomplete_or_failed")
            self.assertEqual((code, calls[-2:]), (2, ["memory", "queue"]))
            self.assertEqual(report["status"], "failed")
            self.assertFalse(report.get("operator_cancelled", False))

    def test_memory_custody_failure_blocks_queue_and_remains_infrastructure_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            code, calls, report = self.invoke(Path(folder), memory_status="evidence_failure")
            self.assertEqual(code, 2)
            self.assertEqual(calls[-1], "memory")
            self.assertNotIn("queue", calls)
            self.assertEqual(report["status"], "infrastructure_failure")
            self.assertIn("custody", report["error"])


if __name__ == "__main__":
    unittest.main()
