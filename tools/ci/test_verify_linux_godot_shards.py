"""Adverse controls for mandatory Linux source and original-artifact coverage."""

import json
from pathlib import Path
import tempfile
import unittest

import execution_policy
import run_godot_regressions as runner
import verify_linux_godot_shards as subject


class LinuxCoverageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.cases = [runner.Case("unit", ("--script", "res://unit.gd"), 1200, 1),
                      runner.Case("pixels_render", ("--script", "res://pixels.gd"), 1200, 1, True)]
        self.options = {"cases": self.cases, "source": "a" * 40, "tree": "b" * 40,
            "runtime": {"cybersand_runtime": {"path": "native.so", "sha256": "c" * 64},
                        "rapier_runtime": {"path": "rapier.so", "sha256": "d" * 64}},
            "run_id": "123", "attempt": "1", "shard_count": 2, "godot_version": "4.7.control"}
        self.reports = []
        shards, _ = runner.build_shard_plan(self.cases, 2)
        for index, cases in enumerate(shards):
            directory = self.root / str(index)
            directory.mkdir()
            identity = {"source_sha": self.options["source"], "source_tree": self.options["tree"],
                "execution_policy": execution_policy.identity(), "shard_index": index,
                "shard_count": 2, "run_id": "123", "run_attempt": "1",
                "godot_version": "4.7.control", **self.options["runtime"]}
            report = {"identity": identity, "status": "passed", "completed": True,
                "assigned_cases": [case.name for case in cases], "results": []}
            for offset, case in enumerate([runner.Case("import", ("--editor", "--quit"), 1200, 1), *cases]):
                log = directory / (case.name + ".log")
                log.write_text("controlled assertions passed\n", encoding="utf-8")
                report["results"].append({"name": case.name, "role": "preflight" if offset == 0 else "case",
                    "timeout_seconds": case.timeout, "requires_display": case.requires_display,
                    "execution_policy": execution_policy.identity(), "status": "passed", "returncode": 0,
                    "natural_completion": True, "log": log.name, "log_sha256": subject.digest(log),
                    "command": runner.case_command("/controlled/Godot", case, "linux")})
            path = directory / "timings.json"
            path.write_text(json.dumps(report), encoding="utf-8")
            self.reports.append(path)

    def change(self, callback, index=0):
        path = self.reports[index]
        value = json.loads(path.read_text())
        callback(value)
        path.write_text(json.dumps(value))

    def verify(self):
        return subject.verify(self.root, **self.options)

    def test_complete_source_matched_originals_pass(self):
        self.assertEqual(self.verify()["case_count"], 2)

    def test_missing_or_duplicate_shard_fails(self):
        self.change(lambda report: report["identity"].update(shard_index=0), index=1)
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            self.verify()
        self.reports[1].unlink()
        with self.assertRaisesRegex(ValueError, "count"):
            self.verify()

    def test_changed_source_attempt_runtime_or_policy_fails(self):
        for key, value in (("source_sha", "f" * 40), ("source_tree", "f" * 40),
                           ("run_attempt", "2"), ("cybersand_runtime", {}), ("execution_policy", {})):
            path = self.reports[0]
            original = path.read_bytes()
            self.change(lambda report: report["identity"].update({key: value}))
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "identity"):
                self.verify()
            path.write_bytes(original)

    def test_natural_completion_is_required_even_after_zero_exit(self):
        self.change(lambda report: report["results"][1].update(natural_completion=False))
        with self.assertRaisesRegex(ValueError, "naturally"):
            self.verify()

    def test_late_failure_or_missing_case_cannot_be_hidden(self):
        self.change(lambda report: report["results"][1].update(returncode=19))
        with self.assertRaisesRegex(ValueError, "naturally"):
            self.verify()
        self.change(lambda report: report["results"].pop())
        with self.assertRaisesRegex(ValueError, "results missing"):
            self.verify()

    def test_changed_original_log_or_forged_error_status_fails(self):
        path = self.reports[0]
        report = json.loads(path.read_text())
        log = path.parent / report["results"][1]["log"]
        log.write_text("ERROR: late assertion\n")
        with self.assertRaisesRegex(ValueError, "log changed"):
            self.verify()
        self.change(lambda report: report["results"][1].update(log_sha256=subject.digest(log)))
        with self.assertRaisesRegex(ValueError, "error or skipped"):
            self.verify()

    def test_original_render_cannot_be_replaced_with_headless(self):
        self.change(lambda report: report["results"][1].update(command=["Godot", "--headless"]), index=1)
        with self.assertRaisesRegex(ValueError, "command differs"):
            self.verify()

    def test_original_import_command_is_required(self):
        self.change(lambda report: report["results"][0].update(command=["Godot", "--headless"]))
        with self.assertRaisesRegex(ValueError, "command differs"):
            self.verify()

    def test_missing_play_independent_readback_is_rejected(self):
        # A real PLAY name activates its source-selected raw evidence reader.
        from unittest import mock
        with mock.patch.object(runner, "case_readback_contract", return_value=runner.LIFE010_READBACK):
            with self.assertRaisesRegex(ValueError, "PLAY readback"):
                self.verify()

    def test_path_escape_is_not_an_original_artifact(self):
        self.change(lambda report: report["results"][1].update(log="../foreign.log"))
        with self.assertRaisesRegex(ValueError, "escapes"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
