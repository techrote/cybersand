"""Regress the terminal authority check using original Windows execution reports.

These report-reader tests never substitute for native execution or the separate
fresh-process Reopen required after every actual Apply-positive evaluation.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import unittest

import shared


FIXTURES = Path(__file__).with_name("fixtures") / "saved_inspection_q1"
POSITIVES = ("swarm006_industrial_on", "swarm006_viaduct_on",
             "swarm006_irregular_on", "swarm006_irregular_square_on")


class ActualSavedInspection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        provenance = json.loads((FIXTURES / "provenance.json").read_text())
        cls.reports = {}
        for row in provenance["files"]:
            raw = (FIXTURES / row["file"]).read_bytes()
            if len(raw) != row["bytes"] or hashlib.sha256(raw).hexdigest() != row["sha256"]:
                raise AssertionError("Original Windows regression report changed: " + row["file"])
            value = json.loads(raw)
            if value["native_source"]["source"] != provenance["source"]:
                raise AssertionError("Original Windows regression report source changed")
            cls.reports[value["example"]] = value

    def errors(self, report):
        native = report["native_source"]
        return shared.ui_report_errors(report, report["mode"], report["example"],
                                       native["source"], native["sha256"], report["test_sha256"], "windows")

    def test_actual_positive_evaluations_end_in_saved_read_only_inspection(self):
        for name in POSITIVES:
            with self.subTest(example=name):
                report = self.reports[name]
                self.assertEqual(report["failures"], [])
                self.assertEqual(report["checks"], 283)
                self.assertEqual(self.errors(report), [])

    def test_saved_inspection_cannot_restore_or_omit_transaction_authority(self):
        for name in POSITIVES:
            original = self.reports[name]
            for field, invalid in (("historical_only", False), ("controller_phase", "installed"),
                                   ("apply_disabled", False), ("undo_disabled", False), ("applied", False)):
                with self.subTest(example=name, field=field):
                    altered = copy.deepcopy(original)
                    altered[field] = invalid
                    self.assertTrue(self.errors(altered))
                    del altered[field]
                    self.assertTrue(self.errors(altered))
            for missing in (False, True):
                altered = copy.deepcopy(original)
                if missing:
                    del altered["transport_refusals"]["corrupted_saved_evidence"]
                else:
                    altered["transport_refusals"]["corrupted_saved_evidence"] = False
                self.assertTrue(self.errors(altered))

    def test_fresh_create_and_unsuccessful_evaluation_remain_nonhistorical(self):
        for name in ("transaction", "swarm006_industrial_off"):
            original = self.reports[name]
            self.assertFalse(original["historical_only"])
            self.assertEqual(self.errors(original), [])
            altered = copy.deepcopy(original)
            altered.update(historical_only=True, controller_phase="historical",
                           apply_disabled=True, undo_disabled=True)
            self.assertTrue(self.errors(altered))

    def test_each_actual_apply_positive_evaluation_still_requires_fresh_reopen(self):
        examples = {name: {"native_outcome": {"native_can_apply": name in POSITIVES}}
                    for name in shared.legacy.EXAMPLES}
        processes = shared.graphical_processes(examples)
        self.assertEqual(len(processes), 24)
        for name in POSITIVES:
            self.assertIn(("evaluate", name), processes)
            self.assertIn(("reopen", name), processes)
        self.assertNotIn(("reopen", "swarm006_industrial_off"), processes)


if __name__ == "__main__":
    unittest.main()
