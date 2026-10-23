"""The stress summary must never hide missing experiments or mixed identities."""

import copy
import json
from pathlib import Path
import tempfile
import unittest

from stress_physical_actors import SUSPECTS
from summarize_physical_stress import summarize


class SummaryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.report = {
            "identity": {"source_sha": "a" * 40, "native_sha256": "native", "rapier_sha256": "rapier", "godot_version": "4.7"},
            "completed": True, "iterations_requested": 10,
            "results": [{"iteration": iteration, "name": case, "status": "passed"}
                        for iteration in range(10) for case in SUSPECTS],
        }
        for host in ("windows", "linux"):
            for batch in range(5):
                self.write(host, batch, self.report)

    def write(self, host, batch, report):
        path = self.root / f"physical-stress-{host}-{batch}" / "stress.json"
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps(report))

    def test_complete_three_hundred_trial_scope_passes(self):
        report = summarize(self.root)
        self.assertEqual(report["errors"], [])
        self.assertTrue(all(value == {"passed": 50} for value in report["counts"].values()))

    def test_timeout_keeps_phase_and_fails_campaign(self):
        report = copy.deepcopy(self.report)
        report["results"][0].update(status="timeout", last_progress={"phase": "close"})
        self.write("windows", 0, report)
        result = summarize(self.root)
        self.assertEqual(result["timeouts_by_phase"], {"windows/test_physical_actor_arena/close": 1})
        self.assertTrue(result["errors"])

    def test_missing_batch_cannot_report_zero_timeouts_as_success(self):
        (self.root / "physical-stress-linux-0/stress.json").unlink()
        self.assertTrue(summarize(self.root)["errors"])

    def test_duplicate_trial_cannot_replace_an_unexecuted_trial(self):
        report = copy.deepcopy(self.report)
        report["results"][0] = report["results"][1]
        self.write("linux", 0, report)
        self.assertTrue(any("duplicated" in error for error in summarize(self.root)["errors"]))

    def test_mixed_sources_or_runtimes_fail(self):
        report = copy.deepcopy(self.report)
        report["identity"].update(source_sha="b" * 40, native_sha256="other")
        self.write("linux", 0, report)
        errors = summarize(self.root)["errors"]
        self.assertTrue(any("source revision" in error for error in errors))
        self.assertTrue(any("runtime identities" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
