"""Synthetic orchestration controls; no engine process or gameplay is executed."""
import contextlib
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import run_goblin as runner
from test_evidence import ACTIONS, tape


class RunnerCancellationControls(unittest.TestCase):
    def invoke(self, root, *, interrupt=None, fail_first=False, reduction=False):
        # The runner resolves --out. Match that boundary before a mocked log
        # path is made relative, including Windows temporary-directory aliases.
        root = root.resolve()
        engine = root / "synthetic-engine"
        engine.write_bytes(b"not an executable; all dispatch is mocked")
        original = tape(ACTIONS)
        # The fixed launcher only admits runtime execution kinds. This fixture
        # remains explicitly artificial and cannot escape the mocked dispatcher.
        original["header"]["evidence_kind"] = "headless_godot"
        provenance = {**original["header"]["provenance"], "source_dirty": False}
        calls = []

        def stage(project, **options):
            project.mkdir()
            (project / "project.godot").write_bytes(b"; synthetic, never executed\n")
            (project / "fixture.gd").write_bytes(b"# synthetic source custody control\n")
            files = {p.name: runner.sha_file(p) for p in project.iterdir()}
            return {"files": files, "project_files_sha256": "a" * 64}

        def execute(command, env, log, timeout, **options):
            calls.append(log.relative_to(root / "output").as_posix())
            interrupted = len(calls) == interrupt
            status = "cancelled" if interrupted else "pass"
            marker = ""
            if log.name != "import.log":
                if reduction:
                    profile = Path(env["CYBERSAND_GOBLIN_PROFILE"])
                    plan = json.loads((profile / "goblin-reproduction.json").read_text())
                    observed = tape(plan["actions"])
                    observed["header"] = copy.deepcopy(original["header"])
                    raw = profile / "goblin/transcript.json"
                    raw.parent.mkdir(parents=True)
                    raw.write_text("{ deliberately incomplete" if interrupted else json.dumps(observed))
                    marker = "GOBLIN_CAMPAIGN_COMPLETE\nGOBLIN_CAMPAIGN_RESULT " + json.dumps(
                        {"validation": {"ok": True, "errors": []}, "summary": observed["summary"]}) + "\n"
                    if not interrupted:
                        status = "test_failure"
                else:
                    marker = runner.COMPLETION_MARKERS[log.stem] + "synthetic\n"
                    if fail_first and len(calls) == 2:
                        status = "test_failure"
                    if interrupted:
                        raw = Path(env["CYBERSAND_GOBLIN_PROFILE"]) / "goblin/transcript.json"
                        raw.parent.mkdir(parents=True)
                        raw.write_text("{ deliberately incomplete")
            log.write_text(marker)
            return {"status": status, "interrupted": interrupted,
                    "exit_code": 130 if interrupted else (1 if status == "test_failure" else 0),
                    "elapsed_seconds": 0.001, "log_sha256": runner.sha_file(log),
                    "diagnostic_errors": [], "surviving_owned_pids": []}

        argv = ["--godot", str(engine), "--out", str(root / "output"), "--case", "reduce" if reduction else "unit"]
        if reduction:
            source = root / "synthetic-original.json"
            source.write_text(json.dumps(original))
            argv += ["--replay", str(source), "--confirmations", "1", "--max-probes", "8"]
        with patch.object(runner, "runtime_identity", return_value=provenance), \
                patch.object(runner, "stage_project", side_effect=stage), \
                patch.object(runner.replay_identity, "build", return_value={"schema": "synthetic"}), \
                patch.object(runner.replay_identity, "same", return_value=True), \
                patch.object(runner, "execute", side_effect=execute), contextlib.redirect_stdout(io.StringIO()):
            code = runner.main(argv)
        qualification = root / "output/qualification.json"
        if not qualification.is_file():
            error = root / "output/qualification-error.json"
            raise AssertionError("Synthetic runner failed before its expected terminal report: " +
                                 (error.read_text() if error.is_file() else str(code)))
        return code, calls, json.loads(qualification.read_text())

    def assert_source_retained(self, output):
        self.assertFalse((output / "project").exists())
        with zipfile.ZipFile(output / "executed-game-source.zip") as archive:
            self.assertEqual(set(archive.namelist()), {"project.godot", "fixture.gd"})
            self.assertEqual(archive.read("fixture.gd"), b"# synthetic source custody control\n")

    def test_import_interrupt_retains_receipt_and_never_launches_a_test(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            code, calls, report = self.invoke(root, interrupt=1)
            self.assertEqual((code, calls), (130, ["import.log"]))
            self.assertEqual(report["phase"], "import")
            self.assertTrue(report["operator_cancelled"])
            self.assertEqual(report["tests"], [])
            self.assertTrue(json.loads((root / "output/import-result.json").read_text())["interrupted"])
            self.assert_source_retained(root / "output")

    def test_resolved_output_alias_keeps_mock_log_paths_in_the_same_root(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "existing").mkdir()
            resolved = root / "actual"
            resolved.mkdir()
            alias = root / "existing" / ".." / "actual"
            self.assertNotEqual(alias, alias.resolve())
            code, calls, report = self.invoke(alias, interrupt=1)
            self.assertEqual((code, calls), (130, ["import.log"]))
            self.assertTrue(report["operator_cancelled"])
            self.assert_source_retained(resolved / "output")

    def test_test_interrupt_stops_before_next_child_despite_partial_tape(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            code, calls, report = self.invoke(root, interrupt=3)
            self.assertEqual(code, 130)
            self.assertEqual(calls, ["import.log", "test_goblin_policies.log", "test_goblin_contract.log"])
            self.assertEqual([row["status"] for row in report["tests"]], ["pass", "cancelled"])
            self.assertFalse((root / "output/profile-02-goblin_gameplay_contracts").exists())
            raw = root / "output/profile-01-test_goblin_contract/goblin/transcript.json"
            self.assertEqual(raw.read_text(), "{ deliberately incomplete")
            self.assert_source_retained(root / "output")

    def test_ordinary_failure_keeps_remaining_fixed_tests_and_exit_two(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            code, calls, report = self.invoke(root, fail_first=True)
            self.assertEqual(code, 2)
            self.assertEqual(len(calls), 4)
            self.assertEqual([row["status"] for row in report["tests"]], ["test_failure", "pass", "pass"])
            self.assertFalse(report.get("operator_cancelled", False))
            self.assert_source_retained(root / "output")

    def test_reducer_interrupt_escapes_retry_loop_and_keeps_current_probe(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            code, calls, report = self.invoke(root, interrupt=3, reduction=True)
            self.assertEqual(code, 130)
            self.assertEqual(calls, ["import.log", "probe-000/replay.log", "probe-001/replay.log"])
            self.assertEqual(report["phase"], "reduction")
            cancelled = json.loads((root / "output/reduction-cancelled.json").read_text())
            self.assertEqual(cancelled["probe"], 1)
            self.assertEqual(len(cancelled["attempts"]), 2)
            self.assertTrue(json.loads((root / "output/probe-001/process.json").read_text())["interrupted"])
            self.assertFalse((root / "output/probe-002").exists())
            self.assertEqual((root / "output/probe-001/profile/goblin/transcript.json").read_text(), "{ deliberately incomplete")
            self.assert_source_retained(root / "output")


if __name__ == "__main__":
    unittest.main()
