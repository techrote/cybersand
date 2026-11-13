"""Real process-tree cleanup with a signal-resistant descendant and control."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from process import ProcessRefusal, run_owned


@unittest.skipUnless(os.name == "posix", "POSIX process owner is explicitly bounded")
class ProcessTests(unittest.TestCase):
    def test_successful_parent_exit_still_cleans_resistant_descendant(self):
        with tempfile.TemporaryDirectory() as directory:
            marker, ready = Path(directory)/"late", Path(directory)/"ready"
            child = f"import signal,time,pathlib;signal.signal(signal.SIGTERM,signal.SIG_IGN);pathlib.Path({str(ready)!r}).write_text('ready');time.sleep(0.7);pathlib.Path({str(marker)!r}).write_text('late')"
            # Positive side-effect control establishes that the fixture would
            # otherwise perform the late mutation after direct parent exit.
            subprocess.run([sys.executable,"-c",child], check=True, timeout=4)
            self.assertTrue(marker.exists()); marker.unlink(); ready.unlink()
            parent = f"import subprocess,sys,time,pathlib;subprocess.Popen([sys.executable,'-c',{child!r}]);\nwhile not pathlib.Path({str(ready)!r}).exists(): time.sleep(0.01)"
            with (Path(directory)/"process.log").open("wb") as log:
                self.assertEqual(run_owned([sys.executable,"-c",parent], log, 5),0)
            time.sleep(0.8)
            self.assertFalse(marker.exists())

    def test_deadline_and_cancellation_return_no_success(self):
        with tempfile.TemporaryDirectory() as directory:
            with (Path(directory)/"process.log").open("wb") as log:
                with self.assertRaisesRegex(ProcessRefusal,"deadline"):
                    run_owned([sys.executable,"-c","import time;time.sleep(10)"], log, 0.1)
                start = time.monotonic()
                with self.assertRaisesRegex(ProcessRefusal,"Canceled"):
                    run_owned([sys.executable,"-c","import time;time.sleep(10)"], log, 5,
                              canceled=lambda: time.monotonic()-start > 0.1)

    def test_non_posix_refuses_before_spawn(self):
        with patch("process.os.name", "nt"), patch("process.subprocess.Popen") as spawn:
            with self.assertRaises(ProcessRefusal):
                run_owned([sys.executable,"-c","pass"], None, 5)
            spawn.assert_not_called()


if __name__ == "__main__":
    unittest.main()
