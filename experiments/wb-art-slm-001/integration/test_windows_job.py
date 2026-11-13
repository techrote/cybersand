"""Windows-only process-tree invariants for the opt-in Art inference bridge.

Policy-compliant hosted testing: no weights, model training, native World or GPU.
"""
import os
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

from local_art_bridge import BridgeRefusal, _run_owned_inference


@unittest.skipUnless(os.name == "nt", "Windows Job Objects only")
class WindowsJobObjectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.root = root
        self.ready = root / "descendant-ready"
        self.late = root / "descendant-late"
        self.child = root / "descendant.py"
        self.child.write_text(
            "import pathlib,sys,time\n"
            "ready,late = map(pathlib.Path,sys.argv[1:3])\n"
            "ready.write_text('started')\n"
            "time.sleep(0.9)\n"
            "late.write_text('late side effect')\n", encoding="utf-8")
        self.parent = root / "inference_wrapper.py"
        self.parent.write_text(
            "import pathlib,subprocess,sys,time\n"
            "child,ready,late,hold = sys.argv[1:5]\n"
            "subprocess.Popen([sys.executable,child,ready,late],"
            " stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,"
            " stderr=subprocess.DEVNULL)\n"
            "for i in range(200):\n"
            "    if pathlib.Path(ready).exists(): break\n"
            "    time.sleep(0.01)\n"
            "else: raise RuntimeError('descendant never reported readiness')\n"
            "if hold=='yes': time.sleep(15)\n", encoding="utf-8")

    def command(self, hold=False):
        return [sys.executable, str(self.parent), str(self.child),
                str(self.ready), str(self.late), "yes" if hold else "no"]

    def test_direct_parent_exit_cannot_leave_delayed_descendant(self):
        with (self.root / "inference.log").open("wb") as log:
            code = _run_owned_inference(self.command(), log, 5)
        self.assertEqual(code, 0, "fake wrapper did not exit cleanly")
        self.assertTrue(self.ready.exists(), "descendant did not execute")
        time.sleep(1.1)
        self.assertFalse(self.late.exists(), "parent-exit descendant escaped the owned job")

    def test_stop_fences_descendant_and_refuses_late_art(self):
        stop = threading.Event()
        outcome = []
        def run():
            with (self.root / "inference.log").open("wb") as log:
                try:
                    outcome.append(_run_owned_inference(
                        self.command(hold=True), log, 8, cancellation_probe=stop.is_set))
                except BridgeRefusal as exc:
                    outcome.append(str(exc))
        worker = threading.Thread(target=run, daemon=True)
        worker.start()
        for _ in range(150):
            if self.ready.exists():
                break
            time.sleep(0.02)
        self.assertTrue(self.ready.exists(), "child never began")
        stop.set()
        worker.join(5)
        self.assertFalse(worker.is_alive(), "Stop left its inference lock occupied")
        self.assertEqual(len(outcome), 1)
        self.assertIn("canceled", outcome[0])
        time.sleep(1.1)
        self.assertFalse(self.late.exists(), "canceled descendant wrote after Stop")

    def test_job_assignment_refusal_produces_no_batch(self):
        with mock.patch("local_art_bridge._WindowsOwnedProcessJob",
                        side_effect=OSError("simulated Job assignment refusal")):
            with (self.root / "inference.log").open("wb") as log:
                with self.assertRaisesRegex(BridgeRefusal, "owned process-tree admission failed"):
                    _run_owned_inference(self.command(hold=True), log, 5)
        self.assertFalse(self.late.exists())


if __name__ == "__main__":
    unittest.main()
