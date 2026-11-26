"""Synthetic Windows child-environment controls; no Windows gameplay claim."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import re
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import qualify_extracted as qualification


class CompleteSelfTestEnvelopeControls(unittest.TestCase):
    def test_parent_covers_the_source_owned_selftest_children_and_cleanup(self):
        # Read the independent launcher contract, including call multiplicity,
        # so adding or lengthening a child cannot silently outrun this parent.
        source = Path(__file__).with_name("Open-goblin.ps1").read_text(encoding="utf-8")
        limits = {name: int(seconds) for name, seconds in re.findall(
            r"Invoke-FixedGodot \$(?:profile|preflight|Profile) '([^']+)' [^\r\n]+\) (\d+)", source)}
        self.assertEqual(limits["import"], 240)
        self.assertEqual(limits["authored-lineage"], 300)
        self.assertIn("foreach ($fixture in @('actor_workshop', 'save_reopen'))", source)
        self.assertIn("$discovery = Invoke-CampaignCase 'alchemy' 'COVERAGE_HUNTER'", source)
        self.assertIn("foreach ($item in @($FirstCase, $LastCase))", source)
        self.assertIn("$imported = Import-ProfileMemory $fresh $current", source)
        self.assertIn("[Math]::Min(1200, [Math]::Max(210, $actionCount * 1.2 + 60))", source)
        complete = (limits["import"] + limits["authored-lineage"] + 3 * limits["campaign"]
                    + 1200 + 3 * limits["corpus-admission"] + limits["interactive-smoke"])
        self.assertEqual(complete, 2640)
        self.assertEqual(qualification.SELFTEST_CHILD_SECONDS, complete)
        self.assertGreaterEqual(qualification.SELFTEST_PARENT_RESERVE_SECONDS, 120)
        self.assertEqual(qualification.SELFTEST_WALL_SECONDS,
                         complete + qualification.SELFTEST_PARENT_RESERVE_SECONDS)
        self.assertLessEqual(qualification.SELFTEST_WALL_SECONDS, 5400)


class WindowsPowerShellEnvironmentControls(unittest.TestCase):
    def test_only_module_path_is_removed_case_insensitively(self):
        original = {"PSModulePath": "core-modules", "PSMODULEPATH": "core-modules-2",
                    "psmodulepath": "core-modules-3", "Path": "program-search",
                    "SystemRoot": "windows-root", "CYBERSAND_GOBLIN_PROFILE": "disposable-profile",
                    "CYBERSAND_GOBLIN_DISPOSABLE": "1", "PSMODULEPATH_BACKUP": "untouched"}
        before = dict(original)
        clean = qualification.windows_powershell_environment(original)
        self.assertEqual(clean, {key: value for key, value in before.items() if key.upper() != "PSMODULEPATH"})
        self.assertEqual(original, before)
        self.assertIsNot(clean, original)
        self.assertEqual(qualification.windows_powershell_environment(clean), clean)

    def run_probe(self, root, *, clean_status="pass", clean_module="Microsoft.PowerShell.Utility",
                  clean_digest=None, duplicate=False):
        environment = {"PSMODULEPATH": "synthetic-core-module-path", "Path": "keep-search-path",
                       "CYBERSAND_GOBLIN_PROFILE": "keep-disposable-profile"}
        calls = []
        expected_digest = hashlib.sha256(qualification.MODULE_PROBE.encode("utf-8")).hexdigest()

        def execute(command, env, log, timeout, **options):
            calls.append((list(command), dict(env), timeout, options))
            if "PSMODULEPATH" in env:
                log.write_text("GOBLIN_POWERSHELL_PROBE_REFUSED SyntheticMissingModule\n", encoding="utf-8")
                return {"status": "test_failure", "exit_code": 3}
            line = "GOBLIN_POWERSHELL_PROBE_PASS 5.1.0.0 " + clean_module + " Function " + (clean_digest or expected_digest) + "\n"
            log.write_text(line * (2 if duplicate else 1), encoding="utf-8")
            return {"status": clean_status, "exit_code": 0}

        with patch.object(qualification, "execute", side_effect=execute):
            report = qualification.probe_powershell(root, root / "extracted.log", environment)
        return report, calls, environment

    def test_inherited_failure_and_clean_success_are_retained_separately(self):
        with tempfile.TemporaryDirectory(prefix="goblin-powershell-control-") as name:
            root = Path(name)
            report, calls, original = self.run_probe(root)
            self.assertEqual(report["status"], "pass")
            self.assertTrue(report["inherited_module_path_present"])
            self.assertEqual([row["get_file_hash_available"] for row in report["attempts"]], [False, True])
            self.assertEqual(calls[0][1], original)
            self.assertEqual(calls[1][1], qualification.windows_powershell_environment(original))
            self.assertEqual(calls[0][0], calls[1][0])
            for command, _, timeout, options in calls:
                self.assertEqual(timeout, 30)
                self.assertEqual(options, {"cwd": root, "memory_limit_mib": 512})
                self.assertEqual(command[:-1], ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"])
                self.assertEqual(Path(command[-1]).read_bytes(), qualification.MODULE_PROBE.encode("utf-8"))
            stored = json.loads((root / "extracted.powershell-environment.json").read_text())
            self.assertEqual(stored, report)
            self.assertNotIn("synthetic-core-module-path", json.dumps(stored))
            self.assertNotIn("keep-disposable-profile", json.dumps(stored))

    def test_clean_process_failure_cannot_be_overridden_by_success_marker(self):
        with tempfile.TemporaryDirectory(prefix="goblin-powershell-control-") as name:
            for status in ("timeout", "resource_limit", "output_limit", "test_failure", "leaked_child"):
                report, _, _ = self.run_probe(Path(name), clean_status=status)
                self.assertEqual(report["status"], "powershell_environment_failure", status)

    def test_clean_module_digest_and_single_marker_must_match(self):
        with tempfile.TemporaryDirectory(prefix="goblin-powershell-control-") as name:
            for options in ({"clean_module": "SyntheticWrongModule"}, {"clean_digest": "a" * 64}, {"duplicate": True}):
                report, _, _ = self.run_probe(Path(name), **options)
                self.assertEqual(report["status"], "powershell_environment_failure", options)


class WindowsCancellationControls(unittest.TestCase):
    def invoke(self, root, interrupt):
        (root / "Open goblin.ps1").write_text("# synthetic; never executed\n")
        digest = hashlib.sha256(qualification.MODULE_PROBE.encode("utf-8")).hexdigest()
        calls = []

        def execute(command, env, log, timeout, **options):
            calls.append(list(command))
            stopped = len(calls) == interrupt
            log.write_text("interrupted partial output" if stopped else
                           "GOBLIN_POWERSHELL_PROBE_PASS 5.1.0.0 Microsoft.PowerShell.Utility Function " + digest + "\n")
            return {"status": "cancelled" if stopped else "pass", "interrupted": stopped,
                    "exit_code": 130 if stopped else 0, "surviving_owned_pids": []}

        fake_os = SimpleNamespace(name="nt", environ={"PSMODULEPATH": "synthetic", "Path": "synthetic"})
        with patch.object(qualification, "os", fake_os), \
                patch.object(qualification, "execute", side_effect=execute), contextlib.redirect_stdout(io.StringIO()):
            code = qualification.main(["--package", str(root), "--log", str(root / "extracted.log")])
        return code, calls

    def test_interrupting_either_probe_never_launches_next_probe_or_selftest(self):
        for stop in (1, 2):
            with self.subTest(probe=stop), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                code, calls = self.invoke(root, stop)
                self.assertEqual(code, 130)
                self.assertEqual(len(calls), stop)
                self.assertTrue(all("SelfTest" not in command for command in calls))
                report = json.loads((root / "extracted.powershell-environment.json").read_text())
                self.assertEqual(report["status"], "cancelled")
                self.assertTrue(report["operator_cancelled"])
                self.assertEqual(len(report["attempts"]), stop)
                self.assertTrue(report["attempts"][-1]["process"]["interrupted"])
                self.assertFalse((root / "extracted.process.json").exists())

    def test_selftest_interrupt_retains_process_before_marker_parsing(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            code, calls = self.invoke(root, 3)
            self.assertEqual(code, 130)
            self.assertEqual(len(calls), 3)
            self.assertIn("SelfTest", calls[-1])
            self.assertEqual((root / "extracted.log").read_text(), "interrupted partial output")
            process = json.loads((root / "extracted.process.json").read_text())
            self.assertTrue(process["interrupted"])
            preflight = json.loads((root / "extracted.powershell-environment.json").read_text())
            self.assertEqual(preflight["status"], "pass")


if __name__ == "__main__":
    unittest.main()
