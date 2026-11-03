"""Synthetic estimator and aggregate-admission controls, not game measurements."""

import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import execution_telemetry
import godot_scheduling as subject
import run_godot_regressions as runner
from test_performance_history import observation


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "godot/tests").mkdir(parents=True)
        (self.root / "godot/tests/palette_warmup.gd").write_text("extends SceneTree\n")
        (self.root / "godot/tests/second_fixture.gd").write_text("extends SceneTree\n# independent fixture\n")
        self.profile = {"schema": "godot-scheduling-history-v1", "as_of_utc": "2026-01-20T00:00:00Z",
                        "platform_cohorts": {"palette_warmup": {}}, "observations": []}
        for platform in ("Linux", "Windows"):
            for run, seconds in enumerate((30, 32, 1000), 1):
                row = observation(run, seconds, phase="case")["record"]
                row["host"]["platform"] = platform
                row["fixture_sha256"] = execution_telemetry.digest(self.root / "godot/tests/palette_warmup.gd")
                row["source_input_sha256"] = subject.source_signature(self.root)
                self.profile["observations"].append(row)
            self.profile["platform_cohorts"]["palette_warmup"][platform] = execution_telemetry.cohort(row)

    def estimate(self, profile=None):
        return subject.estimate("palette_warmup", 15, profile or self.profile, root=self.root)

    def test_missing_invalid_and_empty_snapshot_falls_back(self):
        path = self.root / "profile.json"
        self.assertEqual(self.estimate(subject.load_profile(path)), (15, "missing_profile"))
        for text in ("{", "[]", '{"schema":"wrong"}', '{"schema":"godot-scheduling-history-v1","as_of_utc":NaN}'):
            path.write_text(text)
            self.assertEqual(self.estimate(subject.load_profile(path))[0], 15)
        profile = copy.deepcopy(self.profile)
        profile["observations"] = []
        self.assertEqual(self.estimate(profile), (15, "insufficient_comparable_history"))
        for nested in (None, [], "invalid"):
            profile = copy.deepcopy(self.profile)
            profile["platform_cohorts"]["palette_warmup"] = nested
            self.assertEqual(self.estimate(profile), (15, "invalid_fixture_cohorts"))

    def test_rolling_median_rejects_single_infrastructure_outlier(self):
        self.assertEqual(self.estimate(), (48, "comparable_rolling_median"))
        # A slower qualified Windows cohort is accounted for conservatively.
        for row in self.profile["observations"][3:]:
            row["wall_seconds"] *= 2
        self.assertEqual(self.estimate()[0], 96)

    def test_failures_incomplete_stale_wrong_source_and_noncomparable_are_excluded(self):
        changes = [{"result": "failed"}, {"natural_completion": False}, {"watchdog_reached": True},
                   {"recorded_utc": "2025-12-01T00:00:00Z"}, {"recorded_utc": "2027-01-01T00:00:00Z"},
                   {"fixture_sha256": "0" * 64}, {"source_input_sha256": "0" * 64},
                   {"wall_seconds": float("nan")}, {"wall_seconds": 0}]
        for changeset in changes:
            profile = copy.deepcopy(self.profile)
            profile["observations"][0].update(changeset)
            with self.subTest(changes=changeset):
                self.assertEqual(self.estimate(profile)[0], 15)
        profile = copy.deepcopy(self.profile)
        profile["observations"][0]["host"]["cpu_model"] = "Different CPU"
        self.assertEqual(self.estimate(profile)[0], 15)

    def test_duplicate_run_and_one_platform_do_not_supply_three_independent_samples(self):
        profile = copy.deepcopy(self.profile)
        profile["observations"][1]["source"]["run_id"] = profile["observations"][0]["source"]["run_id"]
        self.assertEqual(self.estimate(profile)[0], 15)
        profile["observations"][1]["source"]["run_id"] = int(profile["observations"][0]["source"]["run_id"])
        self.assertEqual(self.estimate(profile)[0], 15)
        profile = copy.deepcopy(self.profile)
        profile["observations"] = profile["observations"][:3]
        self.assertEqual(self.estimate(profile)[0], 15)

    def test_actual_weight_path_uses_profile_and_unseen_case_keeps_fallback(self):
        self.assertEqual(runner._weight("palette_warmup", profile=self.profile, root=self.root), 48)
        self.assertEqual(runner._weight("brand_new", profile=self.profile, root=self.root), subject.UNKNOWN_SECONDS)
        self.assertEqual(self.estimate(), self.estimate())

    def test_several_fixtures_have_independent_qualified_platform_cohorts(self):
        other = []
        self.profile["platform_cohorts"]["second_fixture"] = {}
        for original in self.profile["observations"]:
            row = copy.deepcopy(original)
            row.update(fixture="second_fixture", fixture_sha256=execution_telemetry.digest(
                self.root / "godot/tests/second_fixture.gd"), wall_seconds=100)
            other.append(row)
            self.profile["platform_cohorts"]["second_fixture"][row["host"]["platform"]] = execution_telemetry.cohort(row)
        self.profile["observations"].extend(other)
        self.assertEqual(runner._weight("palette_warmup", profile=self.profile, root=self.root), 48)
        self.assertEqual(runner._weight("second_fixture", profile=self.profile, root=self.root), 150)

    def test_source_signature_orders_canonical_strings_and_normalizes_text(self):
        directory = self.root / "native/src"
        directory.mkdir(parents=True)
        (directory / "Z.cpp").write_bytes(b"line\r\n")
        (directory / "a.cpp").write_bytes(b"other\n")
        expected = hashlib.sha256()
        paths = sorted(path.relative_to(self.root).as_posix() for path in self.root.rglob("*") if path.is_file())
        self.assertLess(paths.index("native/src/Z.cpp"), paths.index("native/src/a.cpp"))
        for relative in paths:
            expected.update(relative.encode() + b"\0")
            expected.update(hashlib.sha256((self.root / relative).read_bytes().replace(b"\r\n", b"\n")).digest())
        subject.source_signature.cache_clear()
        self.assertEqual(subject.source_signature(self.root), expected.hexdigest())


class AdmissionTests(unittest.TestCase):
    def test_local_enlargement_preserves_policy_and_hosted_limit_is_still_strict(self):
        with mock.patch.dict(os.environ, {"CYBERSAND_CI_WATCHDOG_SCALE": "2", "GITHUB_ACTIONS": "false"}):
            self.assertEqual(subject.ExecutionBudget().seconds, 33600)
            with self.assertRaisesRegex(ValueError, "six-hour"):
                subject.execution_seconds()
        with mock.patch.dict(os.environ, {"CYBERSAND_CI_WATCHDOG_SCALE": "2", "GITHUB_ACTIONS": "true"}):
            with self.assertRaisesRegex(ValueError, "six-hour"):
                subject.ExecutionBudget()

    def test_next_case_receives_full_watchdog_or_remains_unstarted(self):
        with mock.patch.object(subject.time, "monotonic", return_value=100):
            budget = subject.ExecutionBudget(6000)
        with mock.patch.object(subject.time, "monotonic", return_value=200):
            admission = budget.admission(3940)
            self.assertTrue(admission["admitted"])
            self.assertEqual(admission["required_seconds"], 3940 + 300 + 240 + 900)
        with mock.patch.object(subject.time, "monotonic", return_value=1000):
            self.assertFalse(budget.admission(3940)["admitted"])

    def test_setup_cleanup_and_metadata_are_separate_from_expected_cost(self):
        budget = subject.ExecutionBudget()
        self.assertEqual(budget.seconds, 16800)
        self.assertEqual(budget.terminal_reserve, 900)
        self.assertEqual(subject.case_allowance(1200), 1740)
        self.assertEqual(subject.case_allowance(1200, readback=False), 1440)
        for value in (0, -1, float("inf"), float("nan"), True, 16801):
            with self.subTest(value=value), self.assertRaises(ValueError):
                subject.ExecutionBudget(value)


if __name__ == "__main__":
    unittest.main()
