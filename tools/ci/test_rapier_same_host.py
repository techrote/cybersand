import json
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import stress_rapier_same_host as subject


class SameHostTests(unittest.TestCase):
    def run_campaign(self, preflight_failure=False, final_drift=False):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        filename = "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if subject.sys.platform == "win32" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
        relative = "godot/addons/godot-rapier2d/bin/" + filename
        (root / relative).parent.mkdir(parents=True)
        (root / relative).write_bytes(b"baseline")
        (root / "native.dll").write_bytes(b"native")
        (root / "godot/fixture.gd").write_text("fixture")
        for variant in ("control", "patched"):
            build = root / variant
            build.mkdir()
            (build / filename).write_bytes(variant.encode())
            (build / "godot_rapier.pdb").write_bytes(b"symbols")
            (build / "rapier-build.json").write_text(json.dumps({"variant": variant}))
        calls = []
        self.checkpoints = []
        write_json = subject.runner.write_json

        def checkpoint(path, report):
            if path.name == "stress.json":
                self.checkpoints.append(copy.deepcopy(report))
            write_json(path, report)

        def execute(_godot, case, _output, role):
            variant = "control" if subject.runner.ROOT.name.startswith("control") else "patched"
            calls.append((variant, case.name, role))
            if final_drift and len(calls) == 62:
                (root / "out/control-source/godot/fixture.gd").write_text("changed after last trial")
            failed = (preflight_failure and role == "preflight" and variant == "control") or (not preflight_failure and len(calls) == 3)
            return {"name": case.name, "role": role, "status": "timeout" if failed else "passed"}, failed

        def command(args, **_kwargs):
            if args[0] == "git":
                return "native.dll\0" + relative + "\0godot/fixture.gd\0" if "ls-files" in args else "head\n"
            return "4.7\n"

        argv = ["pair", "--godot", "fake", "--output", str(root / "out"), "--host", subject.current_host(), "--batch", "0", "--control-build", str(root / "control"), "--patched-build", str(root / "patched")]
        with patch.object(subject.runner, "ROOT", root), patch.object(subject.sys, "argv", argv), \
                patch.object(subject, "hardware", return_value={"physical_cores": 2}), \
                patch.object(subject.subprocess, "check_output", side_effect=command), \
                patch.object(subject, "verify", side_effect=lambda _root, manifest: json.loads(manifest.read_text())), \
                patch.object(subject.runner, "runtime_paths", side_effect=lambda: (subject.runner.ROOT / "native.dll", subject.runner.ROOT / relative)), \
                patch.object(subject.runner, "discover_cases", return_value=[subject.runner.Case(n, (), 180, 1) for n in subject.SUSPECTS]), \
                patch.object(subject.runner, "run_case", side_effect=execute), \
                patch.object(subject.runner, "write_json", side_effect=checkpoint), \
                patch("run_windows_godot_regressions.verify_retained_runtime", return_value={}):
            code = subject.main()
        reports = {v: json.loads((root / "out" / v / "stress.json").read_text()) for v in ("control", "patched")}
        return code, calls, reports

    def test_failure_preserved_and_every_other_trial_runs_once_in_balanced_order(self):
        code, calls, reports = self.run_campaign()
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 62)
        for variant, report in reports.items():
            self.assertTrue(report["completed"])
            self.assertEqual(report["identity"]["host"], subject.current_host())
            self.assertEqual(report["identity"]["batch"], 0)
            self.assertEqual(report["identity"]["variant"], variant)
            self.assertEqual(len(report["results"]), 30)
            self.assertEqual(sum(r["pair_position"] == 0 for r in report["results"]), 15)
        self.assertEqual(sum(r["status"] == "timeout" for r in reports["control"]["results"]), 1)
        self.assertTrue(all(r["status"] == "passed" for r in reports["patched"]["results"]))
        self.assertEqual(reports["control"]["identity"]["pair_host_id"], reports["patched"]["identity"]["pair_host_id"])
        self.assertEqual(reports["control"]["identity"]["fixture_inputs"], reports["patched"]["identity"]["fixture_inputs"])

    def test_thirty_trials_are_incomplete_until_final_inputs_are_verified(self):
        _code, _calls, reports = self.run_campaign()
        unverified = [r for r in self.checkpoints if len(r["results"]) == 30 and not r["input_verification_complete"]]
        self.assertEqual(len(unverified), 2)
        self.assertTrue(all(not r["completed"] for r in unverified))
        self.assertTrue(all(r["completed"] and r["input_verification_complete"] for r in reports.values()))

    def test_final_input_drift_keeps_the_complete_trial_inventory_but_fails_completion(self):
        code, calls, reports = self.run_campaign(final_drift=True)
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 62)
        self.assertFalse(reports["control"]["completed"])
        self.assertEqual(reports["control"]["input_drift"], ["godot/fixture.gd"])
        self.assertEqual(len(reports["control"]["results"]), 30)
        self.assertTrue(all(not r["completed"] for r in self.checkpoints if not r["input_verification_complete"]))

    def test_import_failure_keeps_incomplete_reports_and_cannot_look_like_zero_timeouts(self):
        code, calls, reports = self.run_campaign(preflight_failure=True)
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 2)
        self.assertTrue(all(not r["completed"] for r in reports.values()))


if __name__ == "__main__":
    unittest.main()
