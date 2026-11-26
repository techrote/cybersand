"""Existing Architecture scripts retain exact cases, custody and failure semantics."""

from collections import Counter
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

import _architecture_campaign_context as context
import godot_job_plan
import run_godot_regressions as runner
import run_windows_godot_regressions as windows


def registered_cases():
    names = {name for _component, members, _paths in context.COMPONENTS for name in members}
    return [case for case in runner.discover_cases() if case.name in names]


class ArchitectureContextTests(unittest.TestCase):
    def test_complete_hosted_plans_keep_components_whole_ordered_and_every_case_once(self):
        discovered = runner.discover_cases()
        for platform in ("linux", "windows"):
            cases = [case for case in discovered if platform == "linux" or context.windows_applicable(case)]
            plan = godot_job_plan.plan(cases, platform=platform)
            shards, totals = runner.build_shard_plan(cases, plan["shard_count"])
            self.assertEqual(Counter(c.name for shard in shards for c in shard), Counter(c.name for c in cases))
            self.assertEqual(totals, [sum(c.weight for c in shard) for shard in shards])
            for shard in shards:
                self.assertLessEqual(len(shard), runner.scheduling.MAX_CASES_PER_SHARD)
                # The original Case objects, flags, display bits and complete
                # watchdogs survive scheduling, rather than synthetic wrappers.
                self.assertTrue(all(any(case is original for original in cases) for case in shard))
            for _component, names, _paths in context.COMPONENTS:
                containing = [shard for shard in shards if any(c.name in names for c in shard)]
                self.assertEqual(len(containing), 1)
                self.assertEqual([c.name for c in containing[0] if c.name in names], list(names))

    def test_partial_component_and_duplicate_case_are_refused(self):
        cases = registered_cases()
        cases = [case for case in cases if case.name != "test_architecture_stage_native"]
        with self.assertRaisesRegex(RuntimeError, "Incomplete Architecture context"):
            runner.build_shard_plan(cases, 2)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "Incomplete Architecture context"):
                context.prepare_contexts(cases, Path(directory))
        with self.assertRaisesRegex(RuntimeError, "exactly once"):
            runner.build_shard_plan([runner.Case("duplicate", (), 1200, 1)] * 2, 1)

    def test_contexts_share_only_the_registered_component_and_fabricate_no_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            contexts = context.prepare_contexts(registered_cases(), output)
            for _component, names, _paths in context.COMPONENTS:
                self.assertTrue(all(contexts[name] == contexts[names[0]] for name in names))
            profiles = [contexts[names[0]]["APPDATA"] for _component, names, _paths in context.COMPONENTS]
            self.assertEqual(len(profiles), len(set(profiles)))
            for overrides in contexts.values():
                for value in overrides.values():
                    self.assertTrue(Path(value).is_relative_to(output))
                for name in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME"):
                    self.assertTrue(Path(overrides[name]).is_dir())
            self.assertFalse(any(path.is_file() for path in output.rglob("*")))
            manifest = Path(contexts["test_architecture_gameplay"]["ARCHITECTURE_GAMEPLAY_MANIFEST"])
            self.assertFalse(manifest.exists())
            # Even a previous empty context cannot be reused to accidentally
            # inherit an old successful manifest/profile on a later run.
            with self.assertRaises(FileExistsError):
                context.prepare_contexts(registered_cases(), output)

    def test_complete_environment_preserves_source_and_path_and_other_cases_keep_defaults(self):
        cases = registered_cases()
        case = next(c for c in cases if c.name == "test_architecture_stage_native")
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {"PATH": "retained-path", "CYBERSAND_SOURCE_REVISION": "source-id"}):
            contexts = context.prepare_contexts(cases, Path(directory))
            kwargs = runner.context_case_kwargs(case, contexts, [])
            self.assertEqual(kwargs["env"]["PATH"], "retained-path")
            self.assertEqual(kwargs["env"]["CYBERSAND_SOURCE_REVISION"], "source-id")
            self.assertEqual(kwargs["env"]["APPDATA"], contexts[case.name]["APPDATA"])
            self.assertEqual(runner.context_case_kwargs(runner.Case("unrelated", (), 1200, 1), contexts, []), {})

    def test_failed_producer_still_runs_consumers_and_cannot_qualify_partial_inputs(self):
        # Real independent child processes: a failing producer leaves a file
        # that would otherwise let its consumer exit successfully. Keep both
        # raw logs and classify the consumer's context as failed nevertheless.
        names = context.COMPONENTS[3][1]
        cases = [runner.Case(name, ("--script", name + ".gd"), 3940, 1, name.endswith("_render")) for name in names]
        programs = {
            names[0]: "import os;from pathlib import Path;p=Path(os.environ['ARCHITECTURE_HIERARCHY_DIR'])/'hierarchy-native.json';p.write_text('{}');print('producer partial input');raise SystemExit(7)",
            names[1]: "import os;from pathlib import Path;assert (Path(os.environ['ARCHITECTURE_HIERARCHY_DIR'])/'hierarchy-native.json').is_file();print('consumer actually executed')",
            names[2]: "print('graphical consumer actually executed')",
        }
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            report = {"status": "running", "completed": False, "results": [], "log_sha256": {}}
            def command(_godot, case):
                if case.name == "import":
                    return [sys.executable, "-c", "print('imported')"]
                capture = ("import os;from pathlib import Path;"
                    "a=Path(os.environ['CYBERSAND_TEST_ARTIFACT_DIR']);a.mkdir();"
                    f"(a/'case.txt').write_text({case.name!r});")
                return [sys.executable, "-c", capture + programs[case.name]]
            with mock.patch.object(runner, "case_command", side_effect=command):
                windows.execute_cases("unused", output, report, cases)
            self.assertTrue(report["completed"])
            self.assertEqual(report["status"], "failed")
            self.assertEqual([r["name"] for r in report["results"]], ["import", *names])
            self.assertEqual([r["status"] for r in report["results"]], ["passed", "failed", "failed", "failed"])
            self.assertEqual([r["timeout_seconds"] for r in report["results"]][1:], [3940] * 3)
            for row in report["results"][2:]:
                self.assertEqual(row["returncode"], 0)
                self.assertEqual(row["process_status"], "passed")
                self.assertEqual(row["failed_context_producers"], [names[0]])
                self.assertIn("actually executed", (output / row["log"]).read_text())
                self.assertEqual(row["log_sha256"], runner.sha256(output / row["log"]))
            for name in names:
                self.assertEqual((output / (name + "-artifacts") / "case.txt").read_text(), name)

    def test_graphical_discovery_windows_intake_and_matrix_agree_without_broadening_scope(self):
        cases = runner.discover_cases()
        by_name = {case.name: case for case in cases}
        self.assertTrue(all(by_name[name].requires_display for name in context.GRAPHICAL_CASES))
        self.assertFalse(context.windows_applicable(runner.Case("unrelated_render", (), 1200, 1, True)))
        expected = [case for case in cases if context.windows_applicable(case)]
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            path = Path(directory) / "plan.json"
            with mock.patch.object(sys, "argv", ["planner", "--output", str(path)]):
                self.assertEqual(godot_job_plan.main(), 0)
            plan = json.loads(path.read_text())["windows"]
        report = {}
        windows.plan_cases(report, cases, shard_count=plan["shard_count"], shard_index=0)
        self.assertEqual(report["applicable_cases"], [case.name for case in expected])
        self.assertEqual(Counter(c["name"] for s in plan["shards"] for c in s["cases"]), Counter(report["applicable_cases"]))
        self.assertEqual(set(case.name for case in expected if case.requires_display), context.GRAPHICAL_CASES)
        self.assertEqual(report["case_plan"], plan["shards"][0]["cases"])
        command = runner.case_command("godot", by_name["test_architecture_gameplay"], "win32")
        self.assertNotIn("--headless", command)
        self.assertEqual(command[command.index("--rendering-method") + 1], "gl_compatibility")
        self.assertEqual(command[command.index("--rendering-driver") + 1], "opengl3_angle")

    def test_failed_context_does_not_erase_a_consumers_original_skip_or_timeout(self):
        for program, timeout, expected in (("print('SKIP: missing input')", 5, "skipped"),
                                            ("import time;time.sleep(30)", 0.1, "timeout")):
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
                case = runner.Case("fixture", (), timeout, 1)
                with mock.patch.object(runner, "case_command", return_value=[sys.executable, "-c", program]):
                    row, failed = runner.run_case("unused", case, Path(directory), "case", failed_context_producers=("producer",))
                self.assertTrue(failed)
                self.assertEqual(row["status"], expected)
                self.assertEqual(row["process_status"], expected)
                self.assertEqual(row["failed_context_producers"], ["producer"])


if __name__ == "__main__":
    unittest.main()
