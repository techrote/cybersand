"""Original Q5 process joins and adversarial transaction-evidence regressions.

The Windows wrapper originals must remain refused. Constructed mutations only
exercise readers; they are not hosted execution or replacement Q5 evidence.
"""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

import reduce_evidence as subject
import runtime_custody as custody
import shared


FIXTURES = Path(__file__).with_name("fixtures") / "ui_process_q5"


class OriginalProcessIdentity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.provenance = json.loads((FIXTURES / "provenance.json").read_text())
        for row in cls.provenance["files"]:
            data = (FIXTURES / row["file"]).read_bytes()
            if len(data) != row["bytes"] or hashlib.sha256(data).hexdigest() != row["sha256"]:
                raise AssertionError("Byte-original Q5 fixture changed: " + row["file"])

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.install("linux")

    def install(self, platform):
        self.platform = platform
        for suffix, fixture_suffix in ((".json", ".json"), ("-process.json", ".process.json"),
                                      (".log", ".stdout.txt")):
            target = self.root / ("transaction/create" + suffix)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((FIXTURES / (platform + "-create" + fixture_suffix)).read_bytes())
        self.original = json.loads((self.root / "transaction/create.json").read_text())
        self.row = json.loads((self.root / "transaction/create-process.json").read_text())
        self.source = self.provenance["execution_source"]
        self.cli = self.original["native_source"]["sha256"]
        self.test = self.original["test_sha256"]

    def join(self):
        records = custody.inventory(self.root)
        text = subject.completed_process(self.root, records, self.row, "transaction/create", 420)
        return subject.ui_process_report(self.root, records, self.row, text, "transaction/create")

    def validate(self):
        report = self.join()
        errors = shared.ui_report_errors(report, "create", "transaction", self.source,
                                         self.cli, self.test, self.platform)
        custody.require(not errors, "; ".join(errors))
        return report

    def rewrite(self, report, *, marker=True, process=True):
        """Rehash adversarial copies, without altering retained fixtures."""
        path = self.root / "transaction/create.json"
        custody.write_json(path, report)
        self.row["report_sha256"] = custody.sha(path)
        if process:
            self.row["process_id"] = report["process_id"]
        if marker:
            log = self.root / "transaction/create.log"
            lines = log.read_text().splitlines()
            lines = [("SWARM004_WORKBENCH " + json.dumps(report)) if line.startswith("SWARM004_WORKBENCH ")
                     else line for line in lines]
            log.write_text("\n".join(lines) + "\n")
            self.row["log_sha256"] = custody.sha(log)
        custody.write_json(self.root / "transaction/create-process.json", self.row)

    def test_original_linux_process_report_and_log_join_passes(self):
        self.assertEqual(self.row["process_id"], 9041)
        self.assertEqual(self.validate(), self.original)

    def test_original_windows_wrapper_process_join_remains_refused(self):
        self.install("windows")
        self.assertEqual(self.row["process_id"], 5148)
        self.assertEqual(self.original["process_id"], 7432)
        self.assertEqual(self.row["report_sha256"], custody.sha(self.root / "transaction/create.json"))
        with self.assertRaisesRegex(ValueError, "process identity differs"):
            self.validate()

    def test_mismatched_process_identity_is_not_a_windows_exception(self):
        for platform in ("linux", "windows"):
            with self.subTest(platform=platform):
                self.install(platform)
                self.row["process_id"] = self.original["process_id"] + 1
                custody.write_json(self.root / "transaction/create-process.json", self.row)
                with self.assertRaisesRegex(ValueError, "process identity differs"):
                    self.join()

    def test_fabricated_rehashed_report_must_match_unique_original_log(self):
        altered = copy.deepcopy(self.original)
        altered["checks"] += 1
        self.rewrite(altered, marker=False)
        with self.assertRaisesRegex(ValueError, "unique original log marker"):
            self.join()

    def test_wrong_source_runtime_and_test_identity_are_refused_after_rehash(self):
        for field in ("source", "sha256", "test_sha256"):
            with self.subTest(field=field):
                self.install("linux")
                altered = copy.deepcopy(self.original)
                if field == "test_sha256":
                    altered[field] = "0" * 64
                else:
                    altered["native_source"][field] = "0" * (40 if field == "source" else 64)
                self.rewrite(altered)
                with self.assertRaisesRegex(ValueError, "attested source|exact test source"):
                    self.validate()

    def test_missing_report_and_substituted_reopen_are_refused(self):
        (self.root / "transaction/create.json").unlink()
        with self.assertRaisesRegex(ValueError, "not inventoried"):
            self.join()
        self.install("linux")
        reopened = json.loads((FIXTURES / "linux-reopen.json").read_text())
        self.rewrite(reopened)
        with self.assertRaisesRegex(ValueError, "schema, mode or fixed example"):
            self.validate()

    def test_unrelated_missing_and_unacknowledged_transaction_are_refused(self):
        changes = (
            lambda report: report.update(native_receipt={}),
            lambda report: report["native_receipt"].update(proposal_sha256="0" * 64),
            lambda report: report["native_receipt"].update(changed_cells=0),
            lambda report: report.update(native_status="blocked", native_can_apply=False),
        )
        for change in changes:
            self.install("linux")
            altered = copy.deepcopy(self.original)
            change(altered)
            self.rewrite(altered)
            with self.assertRaises(ValueError):
                self.validate()

    def test_missing_duplicate_and_fabricated_log_markers_are_refused(self):
        for kind in ("missing", "duplicate", "fabricated"):
            with self.subTest(kind=kind):
                self.install("linux")
                log = self.root / "transaction/create.log"
                lines = log.read_text().splitlines()
                marker = next(line for line in lines if line.startswith("SWARM004_WORKBENCH "))
                if kind == "missing":
                    lines.remove(marker)
                elif kind == "duplicate":
                    lines.append(marker)
                else:
                    lines[lines.index(marker)] = 'SWARM004_WORKBENCH {"process_id": 9041}'
                log.write_text("\n".join(lines) + "\n")
                self.row["log_sha256"] = custody.sha(log)
                custody.write_json(self.root / "transaction/create-process.json", self.row)
                with self.assertRaisesRegex(ValueError, "marker"):
                    self.join()

    def test_real_direct_child_pid_joins_without_alias_or_report_rewriting(self):
        # This is an actual subprocess identity test, not a Godot/UI claim.
        output = self.root / "direct-child"
        output.mkdir()
        code = ("import json,os,pathlib; value={'process_id':os.getpid()}; "
                "pathlib.Path(os.environ['IDENTITY_REPORT']).write_text(json.dumps(value)); "
                "print('SWARM004_WORKBENCH '+json.dumps(value))")
        row = shared.legacy.execute("create", [sys.executable, "-c", code],
                                    dict(os.environ, IDENTITY_REPORT=str(output / "create.json")), output, 10)
        row["report_sha256"] = custody.sha(output / "create.json")
        shared.legacy.validate_result(row, [], output)
        records = custody.inventory(self.root)
        text = subject.completed_process(self.root, records, row, "direct-child/create", 10)
        report = subject.ui_process_report(self.root, records, row, text, "direct-child/create")
        self.assertGreater(report["process_id"], 0)
        self.assertEqual(report["process_id"], row["process_id"])


class ActualEngineSelection(unittest.TestCase):
    def test_pinned_console_argument_resolves_to_actual_engine(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            wrapper = root / "Godot_v4.7-stable_win64_console.exe"
            engine = root / "Godot_v4.7-stable_win64.exe"
            wrapper.write_bytes(b"test wrapper")
            engine.write_bytes(b"test engine")
            self.assertEqual(shared.qualification_engine(wrapper, "windows"), engine.resolve())
            self.assertEqual(shared.qualification_engine(engine, "windows"), engine.resolve())
            engine.unlink()
            with self.assertRaisesRegex(ValueError, "actual Windows engine"):
                shared.qualification_engine(wrapper, "windows")
            engine.mkdir()
            with self.assertRaisesRegex(ValueError, "actual Windows engine"):
                shared.qualification_engine(wrapper, "windows")

    def test_unpinned_name_and_linked_engine_are_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            other = root / "another_console.exe"
            other.write_bytes(b"test executable")
            with self.assertRaisesRegex(ValueError, "pinned Windows engine filename"):
                shared.qualification_engine(other, "windows")
            engine = root / "Godot_v4.7-stable_win64.exe"
            try:
                engine.symlink_to(other)
            except OSError:
                self.skipTest("Creating symlinks is unavailable on this test host")
            with self.assertRaisesRegex(ValueError, "linked qualification engine"):
                shared.qualification_engine(engine, "windows")

    def test_all_windows_preservation_lanes_receive_the_actual_engine(self):
        # The runtime preservation gate compares this same executable hash.
        prepare = (Path(__file__).with_name("prepare_windows.ps1")).read_text()
        self.assertIn("$engine = Join-Path $engineDir 'Godot_v4.7-stable_win64.exe'", prepare)
        self.assertIn("'SWARM45_PACKAGE_ENGINE=' + (Join-Path $validation 'Godot_v4.7-stable_win64.exe')", prepare)
        self.assertNotIn("Godot_v4.7-stable_win64_console.exe", prepare)


if __name__ == "__main__":
    unittest.main()
