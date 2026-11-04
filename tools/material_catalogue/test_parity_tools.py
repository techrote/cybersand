#!/usr/bin/env python3
"""Report-destination regressions; never compile or run native physics.

These exercise the CLI boundary against real temporary files and aliases. The
expensive check is replaced with a successful probe so an unsafe path would
actually overwrite the fixture, rather than accidentally fail for another reason.
"""
from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import check_native_parity as parity


class ReportOutputSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mat353-report-path-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.root = self.directory / "repository"
        self.external = self.directory / "external-candidate"
        self.source = self.external / "catalogue.json"
        self.candidate = self.external / "catalogue.shadow.hpp"
        self.inputs: list[Path] = []
        self.report = {"status": "PASS", "scope": "test stub; no native execution"}
        for path in (self.source, self.candidate, *(self.candidate.with_name(name) for name in (
            "catalogue_shadow.gd", "inspection.json", "manifest.json"
        ))):
            self.make_input(path)
        self.repository_inputs = sorted({
            self.root / parity.SOURCE, self.root / parity.CANDIDATE,
            self.root / parity.compatibility.LOCK, self.root / parity.ORACLE,
            self.root / parity.H1_TRANSITION_SOURCE, self.root / parity.H1_TRANSITION_RECORD,
            *(self.root / relative for relative in parity.compatibility.SOURCE_ROLES),
            *(self.root / "tools/material_catalogue" / name for name in (
                "check_native_parity.py", "compatibility.py", "compiler.py")),
            *((self.root / parity.CANDIDATE).with_name(name) for name in (
                "catalogue_shadow.gd", "inspection.json", "manifest.json")),
        })
        for path in self.repository_inputs:
            self.make_input(path)

    def make_input(self, path: Path) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(("retained fixture: " + str(path) + "\n").encode())
        # Deliberately old, exact timestamps make even identical-content
        # rewrites observable and independent of filesystem clock granularity.
        timestamp = 1_600_000_000_000_000_000 + len(self.inputs) * 1_000_000
        os.utime(path, ns=(timestamp, timestamp))
        self.inputs.append(path)
        return path

    @staticmethod
    def state(path: Path):
        if path.is_symlink():
            return ("symlink", str(path.readlink()), path.lstat().st_mtime_ns)
        if path.is_file():
            return ("file", path.read_bytes(), path.stat().st_mtime_ns)
        if path.exists():
            return ("directory", path.stat().st_mtime_ns)
        return None

    def input_state(self):
        return {str(path): self.state(path) for path in self.inputs}

    def arguments(self, output: Path, *, source=None, candidate=None):
        return ["--root", str(self.root), "--source", str(source or self.source),
                "--candidate", str(candidate or self.candidate), "--output", str(output)]

    def assert_refused(self, output: Path, *, source=None, candidate=None, message="aliases"):
        before, output_before = self.input_state(), self.state(output)
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(parity, "check", return_value=self.report) as check, \
                patch.object(parity, "run") as native_run, \
                redirect_stdout(stdout), redirect_stderr(stderr):
            result = parity.main(self.arguments(output, source=source, candidate=candidate))
        self.assertEqual(result, 1, stderr.getvalue())
        self.assertIn(message, stderr.getvalue())
        self.assertEqual(stdout.getvalue(), "")
        check.assert_not_called()
        native_run.assert_not_called()
        self.assertEqual(self.input_state(), before, "an input's bytes or mtime changed")
        self.assertEqual(self.state(output), output_before, "an output alias was changed")

    def test_selected_external_input_and_every_shadow_sibling_are_refused_before_check(self):
        for output in self.inputs[:5]:
            with self.subTest(output=output.name):
                self.assert_refused(output)

    def test_default_inputs_tools_lock_and_all_protected_sources_are_refused(self):
        # Require the alias diagnostic, not merely the build/ or .json fence,
        # so omission of a protected path cannot hide behind a different check.
        for output in self.repository_inputs:
            with self.subTest(output=output.relative_to(self.root)):
                self.assert_refused(output)

    def test_output_file_symlink_aliases_preserve_inputs_and_the_links(self):
        alias = self.directory / "report-alias.json"
        for target in (self.source, self.candidate, self.candidate.with_name("catalogue_shadow.gd"),
                       self.candidate.with_name("inspection.json"), self.candidate.with_name("manifest.json"),
                       self.root / parity.compatibility.LOCK, self.root / parity.ORACLE):
            with self.subTest(target=target.name):
                alias.symlink_to(target)
                try:
                    self.assert_refused(alias)
                finally:
                    alias.unlink()

    def test_selected_source_symlink_and_selected_candidate_symlink_are_resolved(self):
        other_source = self.make_input(self.directory / "other-inputs/source.json")
        source_link = self.directory / "source-link.json"
        source_link.symlink_to(other_source)
        self.assert_refused(other_source, source=source_link)

        other_candidate = self.make_input(self.directory / "other-inputs/candidate.hpp")
        other_inspection = self.make_input(other_candidate.with_name("inspection.json"))
        candidate_link = self.directory / "candidate-link.hpp"
        candidate_link.symlink_to(other_candidate)
        self.assert_refused(other_candidate, candidate=candidate_link)
        self.assert_refused(other_inspection, candidate=candidate_link)

    def test_parent_directory_symlink_and_normalized_parent_path_aliases_are_refused(self):
        alias_directory = self.directory / "candidate-directory-link"
        alias_directory.symlink_to(self.external, target_is_directory=True)
        self.assert_refused(alias_directory / "inspection.json")
        self.assert_refused(self.external / "unused" / ".." / "catalogue.json")

    def test_existing_hard_link_alias_is_refused(self):
        alias = self.directory / "hard-link-report.json"
        os.link(self.source, alias)
        self.assert_refused(alias)

    def test_json_suffix_is_checked_before_probe_and_does_not_create_directories(self):
        for name in ("report.txt", "report", "report.JSON"):
            with self.subTest(name=name):
                output = self.directory / "not-created" / name
                self.assert_refused(output, message=".json report")
                self.assertFalse(output.parent.exists())

    def test_directory_with_json_suffix_is_refused_before_probe(self):
        output = self.directory / "directory.json"
        output.mkdir()
        self.assert_refused(output, message="regular report file")

    def test_repository_output_fence_runs_before_probe_including_build_symlink_escape(self):
        for output in (self.root / "report.json", self.root / "docs/new-report.json"):
            with self.subTest(output=output):
                self.assert_refused(output, message="beneath build/")
                self.assertFalse(output.exists())
        (self.root / "build").mkdir()
        escape = self.root / "build/source-directory"
        escape.symlink_to(self.root / "docs", target_is_directory=True)
        self.assert_refused(escape / "new-report.json", message="beneath build/")

    def test_tooling_checkout_fence_remains_when_root_selects_another_checkout(self):
        tooling_checkout = self.directory / "tooling-checkout"
        output = tooling_checkout / "docs/report.json"
        with patch.object(parity, "ROOT", tooling_checkout):
            self.assert_refused(output, message="beneath build/")

    def assert_written(self, output: Path):
        before = self.input_state()
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(parity, "check", return_value=self.report) as check, \
                patch.object(parity, "run") as native_run, \
                redirect_stdout(stdout), redirect_stderr(stderr):
            result = parity.main(self.arguments(output))
        self.assertEqual(result, 0, stderr.getvalue())
        check.assert_called_once()
        native_run.assert_not_called()
        self.assertEqual(json.loads(output.read_text()), self.report)
        self.assertEqual(json.loads(stdout.getvalue()), self.report)
        self.assertEqual(stderr.getvalue(), "")
        self.assertEqual(self.input_state(), before)
        self.assertEqual(list(output.parent.glob(".native-parity-*.tmp")), [])

    def test_independent_external_report_succeeds_and_may_replace_an_existing_report(self):
        # The same basename as a checked input is fine in a different directory.
        output = self.directory / "reports/inspection.json"
        self.assert_written(output)
        output.write_text('{"old_report": true}\n')
        self.assert_written(output)

    def test_repository_build_report_succeeds(self):
        self.assert_written(self.root / "build/material-catalogue/native-parity.json")

    def test_alias_created_during_probe_is_refused_again_before_publication(self):
        output = self.directory / "late-link-report.json"
        before = self.input_state()
        stdout, stderr = io.StringIO(), io.StringIO()

        def change_destination(*args, **kwargs):
            output.symlink_to(self.source)
            return self.report

        with patch.object(parity, "check", side_effect=change_destination) as check, \
                patch.object(parity, "run") as native_run, \
                redirect_stdout(stdout), redirect_stderr(stderr):
            result = parity.main(self.arguments(output))
        self.assertEqual(result, 1)
        self.assertIn("aliases", stderr.getvalue())
        self.assertEqual(stdout.getvalue(), "")
        check.assert_called_once()
        native_run.assert_not_called()
        self.assertTrue(output.is_symlink())
        self.assertEqual(self.input_state(), before)


if __name__ == "__main__":
    unittest.main()
