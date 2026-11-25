"""Artificial custody/acceptance controls; no production gameplay discoveries."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import regression_bundle as bundle
from test_evidence import ACTIONS, tape
import verify_transcript as evidence


def fixture(*, injected=True):
    value = tape(ACTIONS, injected=injected)
    value["header"].update(fixture_state="installed", fixture_version=2,
                           fixture_sha256="6" * 64, pacing_ms=0)
    value["initial_authored_fixture"] = {"schema": "artificial-fixture-only"}
    return value


def write(path, value):
    Path(path).write_text(json.dumps(value), encoding="utf-8")


class RegressionBundleControls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.case = self.root / "case"

    def export(self, original=None):
        return bundle.export_case(original or fixture(), self.case, allow_unit=True)

    def actual(self, value):
        write(self.case / "observed-transcript.json", value)

    def test_original_failure_and_passing_regression_are_distinct(self):
        self.export()
        self.actual(fixture())
        self.assertTrue(bundle.assert_case(self.case, mode="reproduction", allow_unit=True)["ok"])
        with self.assertRaises(AssertionError):
            bundle.assert_case(self.case, allow_unit=True)
        self.actual(fixture(injected=False))
        self.assertTrue(bundle.assert_case(self.case, allow_unit=True)["ok"])
        with self.assertRaises(AssertionError):
            bundle.assert_case(self.case, mode="reproduction", allow_unit=True)

    def test_unit_controls_cannot_claim_native_cases(self):
        with self.assertRaisesRegex(ValueError, "Artificial"):
            bundle.export_case(fixture(), self.case)
        self.export()
        self.actual(fixture(injected=False))
        with self.assertRaisesRegex(ValueError, "Artificial"):
            bundle.assert_case(self.case)

    def test_custody_and_explicit_corrective_source(self):
        self.export()
        actual = fixture(injected=False)
        actual["header"]["provenance"]["source_commit"] = "7" * 40
        self.actual(actual)
        with self.assertRaisesRegex(AssertionError, "source/runtime"):
            bundle.assert_case(self.case, allow_unit=True)
        write(self.case / "candidate-provenance.json", actual["header"]["provenance"])
        self.assertTrue(bundle.assert_case(self.case, allow_unit=True)["ok"])
        (self.case / "README.md").write_text("tampered", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            bundle.assert_case(self.case, allow_unit=True)

    def test_timeout_and_different_invariant_do_not_qualify(self):
        original = fixture()
        original["summary"]["termination"] = "timeout"
        with self.assertRaisesRegex(ValueError, "no completed"):
            bundle.export_case(original, self.case, allow_unit=True)
        self.export()
        actual = fixture(injected=False)
        actual["steps"][-1]["assertions"][0]["id"] = "different_invariant"
        actual["summary"] = evidence.summarize(actual)
        self.actual(actual)
        with self.assertRaises(AssertionError):
            bundle.assert_case(self.case, allow_unit=True)

    def test_fixture_and_pacing_drift_are_rejected(self):
        self.export()
        for key, value in (("fixture_sha256", "8" * 64), ("pacing_ms", 50)):
            actual = fixture(injected=False)
            actual["header"][key] = value
            self.actual(actual)
            with self.assertRaisesRegex(AssertionError, "fixture or pacing"):
                bundle.assert_case(self.case, allow_unit=True)

    def test_reviewed_oracle_change_is_not_an_unchanged_invariant_fix(self):
        self.export()
        actual = fixture(injected=False)
        actual["header"]["provenance"]["source_commit"] = "7" * 40
        actual["steps"][-1]["assertions"][0]["expected"] = False
        actual["summary"] = evidence.summarize(actual)
        self.actual(actual)
        write(self.case / "candidate-provenance.json", actual["header"]["provenance"])
        self.assertTrue(evidence.verify(actual)["valid"])
        with self.assertRaisesRegex(AssertionError, "acceptance contract"):
            bundle.assert_case(self.case, allow_unit=True)

    def test_literal_action_sequence_and_fixed_plan_are_required(self):
        self.export()
        actual = fixture(injected=False)
        actual["steps"][0]["action"]["goal"] = "substituted proposal"
        self.actual(actual)
        with self.assertRaisesRegex(AssertionError, "literal"):
            bundle.assert_case(self.case, allow_unit=True)
        plan_path = self.case / "reproduction-fixture.json"
        plan = bundle.read_json(plan_path)
        plan["actions"][0]["goal"] = "rewritten request"
        write(plan_path, plan)
        manifest = bundle.read_json(self.case / "case.json")
        manifest["files"]["reproduction-fixture.json"] = hashlib.sha256(plan_path.read_bytes()).hexdigest()
        write(self.case / "case.json", manifest)
        with self.assertRaisesRegex(ValueError, "Action plan"):
            bundle.assert_case(self.case, allow_unit=True)

    def test_accepted_partial_cannot_be_fixed_by_refusal(self):
        original = fixture()
        original["steps"][-1]["status"] = "partial"
        original["summary"] = evidence.summarize(original)
        self.export(original)
        refused = fixture(injected=False)
        refused["steps"][-1].update(status="refused", classification="not_applicable")
        refused["summary"] = evidence.summarize(refused)
        self.actual(refused)
        with self.assertRaises(AssertionError):
            bundle.assert_case(self.case, allow_unit=True)
        self.actual(fixture(injected=False))
        self.assertTrue(bundle.assert_case(self.case, allow_unit=True)["ok"])

    def test_earlier_duplicate_success_cannot_mask_target_refusal(self):
        actions = [{"id": "panel", "args": {"panel": "details", "open": True}},
                   {"id": "select_material", "args": {"material": 58}},
                   {"id": "panel", "args": {"panel": "details", "open": True}}]
        original = tape(actions)
        original["steps"][-1]["status"] = "partial"
        original["summary"] = evidence.summarize(original)
        self.export(original)
        actual = tape(actions, injected=False)
        actual["steps"][-1].update(status="refused", classification="not_applicable")
        actual["steps"][-1]["admission"] = {"accepted": False}
        actual["summary"] = evidence.summarize(actual)
        self.actual(actual)
        self.assertTrue(evidence.verify(actual)["valid"])
        with self.assertRaisesRegex(AssertionError, "acceptance contract"):
            bundle.assert_case(self.case, allow_unit=True)


if __name__ == "__main__":
    unittest.main()
