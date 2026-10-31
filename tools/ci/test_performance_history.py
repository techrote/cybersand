"""History integrity/advisory controls; synthetic timings are not measurements."""
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest import mock
import urllib.error
import zipfile

import execution_telemetry
import performance_history as subject


def observation(run: int, seconds: float = 10, **changes):
    record = {"schema": execution_telemetry.SCHEMA,
        "recorded_utc": (datetime(2026, 1, 1, tzinfo=timezone.utc) + timedelta(days=run)).isoformat(),
        "source": {"commit": f"{run:040x}", "tree": f"{run + 100:040x}", "tracked_delta_sha256": None,
                   "run_id": str(run), "run_attempt": "1", "job": "graphical"},
        "host": {"platform": "Linux", "architecture": "x86_64", "cpu_model": "Test CPU model",
                 "logical_cpu_count": 4, "runner_class": "github-hosted", "runner_environment": "github-hosted",
                 "runner_image": "ubuntu24", "hardware_cohort": "github-hosted"},
        "fixture": "palette_warmup", "fixture_sha256": "a" * 64, "test_version": "fixture-v1", "phase": "startup",
        "renderer": {"backend": "opengl", "driver": "Test vendor driver 1", "compiler": "Test compiler 1",
                     "variant": "native", "cache_state": "cold", "shader_source_sha256": "b" * 64,
                     "shader_variant_sha256": "c" * 64},
        "configuration": {"material_inventory": [1, 2], "solver": "current", "world": "480x480", "workers": 1},
        "wall_seconds": seconds, "result": "passed", "natural_completion": True, "watchdog_reached": False,
        "metrics": {"first_main_usec": 1000}, "resources": {"available": False}}
    record.update(changes)
    return {"record": record, "origin": {"kind": "synthetic-test", "artifact_id": str(run)}}


def history_receipt():
    return {"status": "available", "artifacts": [{"artifact_id": "1"}], "unavailable": []}


def archive(files: dict[str, bytes]) -> bytes:
    result = io.BytesIO()
    with zipfile.ZipFile(result, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for name, contents in files.items():
            bundle.writestr(name, contents)
    return result.getvalue()


class ComparisonControls(unittest.TestCase):
    def reduce(self, current, history, **kwargs):
        return subject.build_report(current, history, history_receipt(), [], is_parent=lambda *_: False, **kwargs)

    def test_median_and_prominent_ratio_are_advisory(self):
        report = self.reduce([observation(10, 30)], [observation(1, 10), observation(2, 12), observation(3, 11)])
        row = report["comparisons"][0]
        self.assertEqual(row["baseline_median_wall_seconds"], 11)
        self.assertEqual(row["advisory"], "prominent")
        self.assertTrue(report["advisory_only"])
        self.assertFalse(report["functional_status_changed"])
        self.assertIn("prominent", subject.markdown(report))

    def test_minimum_three_distinct_runs_and_duplicate_consolidation(self):
        first = observation(1)
        repeat = observation(1, 12)
        report = self.reduce([observation(10, 30)], [first, deepcopy(first), repeat, observation(2)])
        self.assertEqual(report["history_record_count"], 3)
        self.assertEqual(report["comparisons"][0]["comparison"], "insufficient_history")
        self.assertEqual(report["comparisons"][0]["comparable_runs"], 2)

    def test_last_ten_runs_define_rolling_baseline(self):
        report = self.reduce([observation(20, 12)], [observation(run, run) for run in range(1, 16)])
        baseline = next(iter(report["baselines"].values()))
        self.assertEqual(baseline["sample_count"], 10)
        self.assertEqual(baseline["samples"][0]["run_id"], "6")
        self.assertEqual(baseline["median_wall_seconds"], 10.5)

    def test_gradual_drift_can_flag_without_single_warning_ratio(self):
        report = self.reduce([observation(6, 121)], [observation(run, wall) for run, wall in enumerate((100, 104, 108, 112, 116), 1)])
        row = report["comparisons"][0]
        self.assertLess(row["ratio"], 1.5)
        self.assertEqual(row["advisory"], "gradual-drift")
        self.assertTrue(row["drift"]["flagged"])
        self.assertEqual(row["drift"]["steps"], 5)
        self.assertEqual(row["drift"]["cumulative_ratio"], 1.21)

    def test_oscillation_is_not_five_increasing_steps(self):
        report = self.reduce([observation(6, 121)], [observation(run, wall) for run, wall in enumerate((100, 105, 103, 112, 116), 1)])
        self.assertFalse(report["comparisons"][0]["drift"]["flagged"])

    def test_failed_hung_and_incomplete_observations_are_all_retained(self):
        failed = observation(1, result="failed")
        hung = observation(2, result="timeout", natural_completion=False, watchdog_reached=True)
        incomplete = observation(3, result="running", natural_completion=False)
        report = self.reduce([failed, hung, incomplete], [observation(4, result="failed"), observation(5, result="timeout")])
        self.assertEqual(len(report["failed_or_incomplete_current"]), 3)
        self.assertEqual(len(report["excluded_history"]), 2)
        self.assertFalse(report["baselines"])
        self.assertTrue(all(row["comparison"] == "incomparable" for row in report["comparisons"]))

    def test_failed_history_does_not_lower_or_inflate_median(self):
        data = [observation(1, 10), observation(2, 10), observation(3, 10), observation(4, 99999, result="failed")]
        report = self.reduce([observation(10, 15)], data)
        self.assertEqual(report["comparisons"][0]["ratio"], 1.5)
        self.assertEqual(report["comparisons"][0]["advisory"], "warning")
        self.assertEqual(len(report["excluded_history"]), 1)

    def test_platform_renderer_driver_compiler_cache_hardware_and_configuration_do_not_mix(self):
        mutations = [
            lambda row: row["host"].update(platform="Windows"),
            lambda row: row["host"].update(cpu_model="Other CPU"),
            lambda row: row["host"].update(logical_cpu_count=8),
            lambda row: row["host"].update(hardware_cohort="other-hardware"),
            lambda row: row["renderer"].update(backend="angle"),
            lambda row: row["renderer"].update(driver="Different driver"),
            lambda row: row["renderer"].update(compiler="Different compiler"),
            lambda row: row["renderer"].update(cache_state="warm"),
            lambda row: row["configuration"].update(workers=4),
            lambda row: row.update(test_version="fixture-v2"),
            lambda row: row.update(fixture="other-case"),
        ]
        for mutate in mutations:
            history = [observation(run) for run in (1, 2, 3)]
            for entry in history:
                mutate(entry["record"])
            with self.subTest(mutation=mutate):
                report = self.reduce([observation(10, 20)], history)
                self.assertEqual(report["comparisons"][0]["comparison"], "insufficient_history")
                self.assertEqual(len(report["excluded_history"]), 3)

    def test_avrea_and_unknown_cohorts_cannot_become_github_baselines(self):
        for mutate in (
            lambda row: row["host"].update(runner_class="avrea", hardware_cohort="avrea"),
            lambda row: row["host"].update(cpu_model="unknown"),
            lambda row: row["host"].update(logical_cpu_count=None),
            lambda row: row["renderer"].update(compiler="unknown"),
            lambda row: row["renderer"].update(cache_state="unknown"),
            lambda row: row["configuration"].update(world="unknown"),
        ):
            history = [observation(run) for run in (1, 2, 3)]
            for entry in history:
                mutate(entry["record"])
            report = self.reduce([observation(10, 20)], history)
            self.assertEqual(report["comparisons"][0]["comparison"], "insufficient_history")
            self.assertEqual(len(report["excluded_history"]), 3)

    def test_nonfinite_boolean_and_unknown_timing_never_compare(self):
        for value in (float("nan"), float("inf"), 1 << 10000, -1, 0, True, None, "unknown"):
            with self.subTest(value=value):
                self.assertIn("invalid_wall_seconds", subject.comparison_issues(observation(1, value)["record"]))
        for payload in (b'{"x":NaN}', b'{"x":Infinity}', b'{"x":1e999}', b'{"x":1,"x":2}'):
            with self.assertRaises(ValueError):
                subject.strict_json(payload)

    def test_finite_but_extreme_numbers_cannot_create_nonfinite_ratios(self):
        report = self.reduce([observation(10, 1e308)], [observation(run, 1e-308) for run in (1, 2, 3)])
        self.assertEqual(report["comparisons"][0]["comparison"], "incomparable")
        self.assertEqual(report["comparisons"][0]["reasons"], ["nonfinite_derived_ratio"])
        json.dumps(report, allow_nan=False)

    def test_current_run_and_future_history_are_never_baselines(self):
        current = observation(10, 20)
        same_run = observation(10, 10)
        future = observation(11, 10)
        report = self.reduce([current], [same_run, future, observation(1)])
        self.assertEqual(report["comparisons"][0]["comparison"], "insufficient_history")
        reasons = {reason for row in report["excluded_history"] for reason in row["excluded_for"]}
        self.assertIn("current_run_cannot_supply_its_baseline", reasons)
        self.assertIn("history_not_earlier_than_current", reasons)

    def test_sha_changes_are_reported_without_splitting_same_method_cohort(self):
        current = observation(10, 20)
        current["record"]["fixture_sha256"] = "d" * 64
        current["record"]["renderer"]["shader_source_sha256"] = "e" * 64
        report = self.reduce([current], [observation(run) for run in (1, 2, 3)])
        row = report["comparisons"][0]
        self.assertEqual(row["comparison"], "compared")
        self.assertTrue(row["source_changes"]["fixture_sha256"]["changed"])
        self.assertTrue(row["source_changes"]["shader_source_sha256"]["changed"])
        self.assertNotIn("introducing_commit_candidate", row)

    def test_malformed_optional_hash_metadata_cannot_break_other_comparisons(self):
        for change in (
            lambda row: row["source"].update(tree={"wrong": "type"}),
            lambda row: row.update(fixture_sha256=["wrong-type"]),
            lambda row: row["renderer"].update(shader_source_sha256=123),
            lambda row: row["renderer"].update(shader_variant_sha256="invalid"),
        ):
            malformed = observation(10, 20)
            change(malformed["record"])
            report = self.reduce([malformed, observation(11, 20)], [observation(run) for run in (1, 2, 3)])
            self.assertEqual(report["comparisons"][0]["comparison"], "incomparable")
            self.assertEqual(report["comparisons"][1]["comparison"], "compared")
            json.dumps(report, allow_nan=False)

    def test_introducing_commit_candidate_requires_verified_direct_parent(self):
        current = [observation(10, 20)]
        history = [observation(run) for run in (1, 2, 3)]
        report = subject.build_report(current, history, history_receipt(), [], is_parent=lambda new, old: new == f"{10:040x}" and old == f"{3:040x}")
        candidate = report["comparisons"][0]["introducing_commit_candidate"]
        self.assertEqual(candidate["commit"], f"{10:040x}")
        self.assertFalse(candidate["causality_established"])


class ArchiveControls(unittest.TestCase):
    def test_safe_jsonl_is_read_without_extracting_files(self):
        row = observation(1)["record"]
        data = archive({"linux/current.jsonl": json.dumps(row).encode() + b"\n", "summary.md": b"old advice"})
        rows, errors, expanded = subject.read_archive(data, {"artifact_id": "1"})
        self.assertEqual(rows[0]["record"], row)
        self.assertFalse(errors)
        self.assertGreater(expanded, 0)

    def test_unsafe_paths_symlinks_and_duplicate_members_refuse(self):
        for name in ("../current.jsonl", "/current.jsonl", "C:/current.jsonl", "a\\current.jsonl", "a/./current.jsonl", "a//current.jsonl", "bad\nname.jsonl"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                subject.read_archive(archive({name: b"{}"}), {})
        target = io.BytesIO()
        with zipfile.ZipFile(target, "w") as bundle:
            member = zipfile.ZipInfo("symlink.jsonl")
            member.create_system = 3
            member.external_attr = (stat.S_IFLNK | 0o777) << 16
            bundle.writestr(member, "outside")
        with self.assertRaises(ValueError):
            subject.read_archive(target.getvalue(), {})

    def test_expansion_and_member_count_are_bounded(self):
        data = archive({"current.jsonl": b" " * 1024})
        with mock.patch.object(subject, "MAX_MEMBER_BYTES", 100), self.assertRaises(ValueError):
            subject.read_archive(data, {})
        data = archive({"one": b"x", "two": b"y"})
        with mock.patch.object(subject, "MAX_MEMBERS", 1), self.assertRaises(ValueError):
            subject.read_archive(data, {})


class HistoryTransportControls(unittest.TestCase):
    def client(self, *, branch="main", event="push", record_run=3, status="completed"):
        row = observation(record_run)["record"]
        data = archive({"current.jsonl": json.dumps(row).encode() + b"\n"})
        artifact = {"id": 31, "name": "execution-performance-linux", "expired": False,
                    "size_in_bytes": len(data), "digest": "sha256:" + hashlib.sha256(data).hexdigest(),
                    "created_at": "2026-01-04T00:00:00Z", "workflow_run": {"id": 3, "head_branch": branch}}
        run = {"id": 3, "run_attempt": 1, "status": status, "head_branch": branch,
               "event": event, "head_repository": {"full_name": "owner/repo"}, "head_sha": f"{3:040x}"}
        api = mock.Mock()
        def get(path):
            if path == "/repos/owner/repo":
                return {"default_branch": "main"}
            if "/actions/artifacts?" in path:
                return {"artifacts": [deepcopy(artifact)]}
            if path == "/repos/owner/repo/actions/runs/3":
                return run
            raise AssertionError(path)
        api.json.side_effect = get
        api.request.return_value = data
        return api

    def test_completed_default_branch_artifact_has_exact_run_source_provenance(self):
        rows, receipt = subject.collect_history("owner/repo", None, 10, token="test-only-token", client=self.client())
        self.assertEqual(receipt["status"], "available")
        self.assertEqual(len(rows), 1)
        self.assertNotIn("history_identity_error", rows[0])
        self.assertEqual(receipt["artifacts"][0]["run_id"], "3")
        self.assertNotIn("test-only-token", json.dumps(receipt))

    def test_pr_incomplete_other_branch_and_current_run_do_not_supply_history(self):
        for kwargs in ({"event": "pull_request"}, {"status": "in_progress"}, {"branch": "feature"}):
            api = self.client(**kwargs)
            rows, _ = subject.collect_history("owner/repo", None, 10, token="test", client=api)
            self.assertFalse(rows)
            api.request.assert_not_called()
        rows, _ = subject.collect_history("owner/repo", None, 10, token="test", current_run="3", client=self.client())
        self.assertFalse(rows)

    def test_wrong_run_rows_are_retained_as_excluded_history(self):
        rows, receipt = subject.collect_history("owner/repo", None, 10, token="test", client=self.client(record_run=2))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["history_identity_error"], "artifact_run_source_mismatch")
        report = subject.build_report([observation(10)], rows, receipt, [], is_parent=lambda *_: False)
        self.assertIn("artifact_run_source_mismatch", report["excluded_history"][0]["excluded_for"])

    def test_missing_token_and_api_failure_are_explicitly_unavailable(self):
        rows, receipt = subject.collect_history("owner/repo", None, 10, token=None)
        self.assertFalse(rows)
        self.assertEqual(receipt["status"], "unavailable")
        api = self.client()
        api.json.side_effect = urllib.error.HTTPError("https://secret.invalid/?token=should-not-leak", 403, "Forbidden", {}, None)
        _, receipt = subject.collect_history("owner/repo", None, 10, token="test", client=api)
        self.assertEqual(receipt["unavailable"][0]["reason"], "HTTP 403")
        self.assertNotIn("should-not-leak", json.dumps(receipt))

    def test_digest_failure_and_unsafe_zip_are_unavailable_without_numeric_credit(self):
        for data in (b"corrupt downloaded archive", archive({"../current.jsonl": b"{}"})):
            api = self.client()
            api.request.return_value = data
            rows, receipt = subject.collect_history("owner/repo", None, 10, token="test", client=api)
            self.assertFalse(rows)
            self.assertEqual(receipt["status"], "unavailable")
            self.assertEqual(len(receipt["unavailable"]), 1)

    def test_last_ten_matching_artifacts_are_selected_without_crediting_unrelated_names(self):
        api = mock.Mock()
        def row(run):
            return {"id": 100 + run, "name": "execution-performance-" + str(run), "expired": False,
                    "size_in_bytes": 1024, "created_at": observation(run)["record"]["recorded_utc"],
                    "workflow_run": {"id": run, "head_branch": "main"}}
        def get(path):
            if path == "/repos/owner/repo":
                return {"default_branch": "main"}
            if "/actions/artifacts?" in path:
                return {"artifacts": [row(run) for run in range(1, 13)] + [row(13) | {"name": "unrelated"}]}
            run = int(path.rsplit("/", 1)[1])
            return {"run_attempt": 1, "status": "completed", "head_branch": "main", "event": "push",
                    "head_repository": {"full_name": "owner/repo"}, "head_sha": f"{run:040x}"}
        api.json.side_effect = get
        api.request.side_effect = lambda path, **_: archive({"current.jsonl": json.dumps(observation(int(path.split("/")[-2]) - 100)["record"]).encode()})
        rows, receipt = subject.collect_history("owner/repo", None, 10, token="test", client=api)
        self.assertEqual(len(rows), 10)
        self.assertEqual([item["run_id"] for item in receipt["artifacts"]], [str(run) for run in range(12, 2, -1)])
        self.assertEqual(api.request.call_count, 10)

    def test_signed_storage_redirect_never_receives_repository_token(self):
        api = subject.GitHub("test-only-secret")
        response = mock.MagicMock()
        response.headers = {}
        response.__enter__.return_value = response
        response.read.side_effect = [b"zip-bytes", b""]
        redirect = urllib.error.HTTPError("https://api.github.com/a", 302, "Found",
            {"Location": "https://storage.example.invalid/signed?sig=private"}, None)
        api.opener = mock.Mock()
        api.opener.open.side_effect = [redirect, response]
        self.assertEqual(api.request("/repos/owner/repo/actions/artifacts/31/zip"), b"zip-bytes")
        first, second = [call.args[0] for call in api.opener.open.call_args_list]
        self.assertEqual(first.get_header("Authorization"), "Bearer test-only-secret")
        self.assertIsNone(second.get_header("Authorization"))


class CollectorControls(unittest.TestCase):
    def test_high_ratio_cli_returns_zero_and_retains_failed_raw_rows(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "shards/linux"
            source.mkdir(parents=True)
            current = [observation(10, 30), observation(10, 60, result="failed")]
            raw = "".join(json.dumps(entry["record"]) + "\n" for entry in current)
            path = source / "performance.jsonl"
            path.write_text(raw)
            step = root / "step.md"
            history = [observation(run) for run in (1, 2, 3)]
            with mock.patch.object(subject, "collect_history", return_value=(history, history_receipt())), mock.patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(step)}):
                result = subject.main(["--current", str(root / "shards"), "--output", str(root / "report")])
            self.assertEqual(result, 0)
            report = json.loads((root / "report/summary.json").read_text())
            self.assertEqual(report["comparisons"][0]["advisory"], "prominent")
            self.assertEqual(len(report["failed_or_incomplete_current"]), 1)
            self.assertEqual(len((root / "report/current.jsonl").read_text().splitlines()), 2)
            self.assertEqual(path.read_text(), raw)
            self.assertIn("Advisory only", step.read_text())

    def test_unavailable_history_does_not_invent_zero_or_a_baseline(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "performance.jsonl"
            path.write_text(json.dumps(observation(10)["record"]) + "\n")
            self.assertEqual(subject.main(["--current", str(path), "--output", str(root / "report"), "--no-history"]), 0)
            report = json.loads((root / "report/summary.json").read_text())
            self.assertFalse(report["baselines"])
            self.assertNotIn("ratio", report["comparisons"][0])
            self.assertEqual(report["history"]["status"], "not_requested")

    def test_nonfinite_line_is_retained_as_input_error_without_losing_valid_rows(self):
        data = (json.dumps(observation(1)["record"]) + "\n" + '{"schema":"execution-performance-v1","wall_seconds":1e999}\n').encode()
        rows, errors = subject.parse_jsonl(data, {"path": "synthetic.jsonl"})
        self.assertEqual(len(rows), 1)
        self.assertEqual(len(errors), 1)
        self.assertEqual(errors[0]["line"], 2)
        self.assertEqual(len(errors[0]["line_sha256"]), 64)

    def test_output_cannot_replace_explicit_raw_input(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            raw = root / "current.jsonl"
            raw.write_text(json.dumps(observation(1)["record"]) + "\n")
            before = raw.read_bytes()
            self.assertEqual(subject.main(["--current", str(raw), "--output", str(root), "--no-history"]), 0)
            self.assertEqual(raw.read_bytes(), before)

    def test_step_summary_failure_preserves_durable_report_and_original_failures(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            raw = root / "performance.jsonl"
            raw.write_text(json.dumps(observation(1, result="failed")["record"]) + "\n")
            with mock.patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": str(root / "absent/step.md")}):
                self.assertEqual(subject.main(["--current", str(raw), "--output", str(root / "report"), "--no-history"]), 0)
            report = json.loads((root / "report/summary.json").read_text())
            self.assertEqual(len(report["failed_or_incomplete_current"]), 1)
            self.assertEqual(report["presentation_errors"][0]["scope"], "step_summary")

    def test_unexpected_reducer_error_keeps_current_failure_observations(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            raw = root / "performance.jsonl"
            record = observation(1, result="failed")["record"]
            raw.write_text(json.dumps(record) + "\n")
            with mock.patch.object(subject, "build_report", side_effect=RuntimeError("synthetic reader failure")):
                self.assertEqual(subject.main(["--current", str(raw), "--output", str(root / "report"), "--no-history"]), 0)
            self.assertEqual(json.loads((root / "report/current.jsonl").read_text()), record)


if __name__ == "__main__":
    unittest.main()
