"""Receipt-custody regressions; these synthetic records do not qualify Godot."""
from __future__ import annotations

import contextlib
import copy
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import check_gdscript_shadow as check
from check_native_parity import file_fact


class GodotReceiptGuards(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mat353-gd-receipt-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.protected = {"unit_test_only": True}
        self.receipt = {
            "schema_id": "cybersand.material-catalogue.native-parity", "schema_version": 2,
            "status": "PASS", "source_commit": check.compatibility.BASELINE,
            "source_commit_role": "immutable-metadata-baseline-not-candidate-head",
            "protected_sources": self.protected, "native_authored_compiled_shadow_facts_equal": True,
            "world_executed": False, "physics_qualification": False, "production_cutover": False,
        }
        for group, names in check.RECEIPT_PATHS.items():
            self.receipt[group] = []
            for name in names:
                path = self.root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture content for " + name + "\n")
                self.receipt[group].append(file_fact(path, self.root))

    def validate(self, receipt=None):
        check.validate_native_receipt(receipt or self.receipt, self.protected, self.root)

    def test_complete_inventory_is_required_independent_of_row_order(self):
        self.validate()
        for group in check.RECEIPT_PATHS:
            self.receipt[group].reverse()
        self.validate()

    def test_missing_stale_input_row_cannot_bypass_hash_check(self):
        path = self.root / "materials/catalogue/generated/inspection.json"
        original = path.read_bytes()
        path.write_bytes(b"X" + original[1:])
        with self.assertRaisesRegex(ValueError, "inspection.json.*sha256"):
            self.validate()
        self.receipt["inputs"] = [row for row in self.receipt["inputs"] if row["path"] != str(path.relative_to(self.root))]
        with self.assertRaisesRegex(ValueError, "complete 6-path custody inventory"):
            self.validate()

    def test_each_tool_and_input_is_mandatory(self):
        for group in check.RECEIPT_PATHS:
            for index in range(len(self.receipt[group])):
                with self.subTest(group=group, index=index):
                    changed = copy.deepcopy(self.receipt)
                    changed[group].pop(index)
                    with self.assertRaisesRegex(ValueError, "complete.*custody inventory"):
                        self.validate(changed)

    def test_duplicate_rows_cannot_pad_missing_sources(self):
        for group in check.RECEIPT_PATHS:
            with self.subTest(group=group):
                changed = copy.deepcopy(self.receipt)
                changed[group][-1] = copy.deepcopy(changed[group][0])
                with self.assertRaisesRegex(ValueError, "duplicate custody path"):
                    self.validate(changed)

    def test_alternate_path_or_traversal_is_not_same_canonical_inventory(self):
        for name in ("../outside.json", "materials/catalogue/./catalogue.json", "/tmp/catalogue.json"):
            with self.subTest(name=name):
                changed = copy.deepcopy(self.receipt)
                changed["inputs"][0]["path"] = name
                with self.assertRaisesRegex(ValueError, "custody path"):
                    self.validate(changed)

    def test_missing_source_digest_is_not_a_valid_fact(self):
        changed = copy.deepcopy(self.receipt)
        changed["inputs"][0].pop("sha256")
        with self.assertRaisesRegex(ValueError, "field mismatch"):
            self.validate(changed)

    def test_changed_tool_after_native_check_is_refused(self):
        (self.root / check.RECEIPT_PATHS["tool_sources"][0]).write_text("changed oracle")
        with self.assertRaisesRegex(ValueError, "native_oracle.cpp"):
            self.validate()

    def test_h1_checker_and_source_record_are_each_required_and_current(self):
        for group, name in (
                ("tool_sources", "tools/material_catalogue/h1_transition.py"),
                ("inputs", "materials/catalogue/h1-source-transition.json")):
            with self.subTest(path=name):
                original = (self.root / name).read_bytes()
                (self.root / name).write_bytes(original + b"stale")
                with self.assertRaisesRegex(ValueError, "native receipt.*(sha256|bytes)"):
                    self.validate()
                changed = copy.deepcopy(self.receipt)
                changed[group] = [row for row in changed[group] if row["path"] != name]
                with self.assertRaisesRegex(ValueError, "complete.*custody inventory"):
                    self.validate(changed)
                (self.root / name).write_bytes(original)

    def test_version1_receipts_are_historical_not_implicitly_upgraded(self):
        changed = copy.deepcopy(self.receipt)
        changed["schema_version"] = 1
        changed.pop("source_commit_role")
        changed["tool_sources"] = [row for row in changed["tool_sources"]
                                   if row["path"] != "tools/material_catalogue/h1_transition.py"]
        changed["inputs"] = [row for row in changed["inputs"]
                             if row["path"] != "materials/catalogue/h1-source-transition.json"]
        self.assertEqual(len(changed["tool_sources"]), 3)
        self.assertEqual(len(changed["inputs"]), 5)
        with self.assertRaisesRegex(ValueError, "native receipt version"):
            self.validate(changed)

    def test_baseline_cannot_be_relabelled_as_the_candidate_head(self):
        changed = copy.deepcopy(self.receipt)
        changed["source_commit_role"] = "candidate-head"
        with self.assertRaisesRegex(ValueError, "native receipt baseline role"):
            self.validate(changed)

    def test_receipt_must_assert_complete_shadow_equality_and_no_cutover(self):
        for field, bad in (("native_authored_compiled_shadow_facts_equal", False),
                           ("status", "FAIL"), ("world_executed", True),
                           ("production_cutover", True), ("schema_version", True)):
            with self.subTest(field=field):
                changed = copy.deepcopy(self.receipt)
                changed[field] = bad
                with self.assertRaises(ValueError):
                    self.validate(changed)

    def test_cli_refuses_input_output_alias_before_running_editor(self):
        inputs = {name: self.root / (name + ".json") for name in
                  ("godot", "archive", "native-snapshot", "native-report")}
        for path in inputs.values():
            path.write_text("preserve me\n")
        for selected in inputs.values():
            with self.subTest(input=str(selected)):
                before = (selected.read_bytes(), selected.stat().st_mtime_ns)
                arguments = [token for name, path in inputs.items() for token in ("--" + name, str(path))]
                arguments += ["--output", str(selected)]
                with patch.object(check, "verify", side_effect=AssertionError("editor must not run")):
                    with contextlib.redirect_stderr(io.StringIO()):
                        self.assertEqual(check.main(arguments), 1)
                self.assertEqual(before, (selected.read_bytes(), selected.stat().st_mtime_ns))


class GodotReportOutputGuards(unittest.TestCase):
    """Real CLI publication with a stubbed probe; no editor execution."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mat353-gd-report-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.input_directory = self.directory / "inputs"
        self.input_directory.mkdir()
        self.inputs = {name: self.input_directory / (name + ".json") for name in
                       ("godot", "archive", "native-snapshot", "native-report")}
        for path in self.inputs.values():
            path.write_text("retained " + path.name + "\n")
            os.utime(path, ns=(1_600_000_000_000_000_000, 1_600_000_000_000_000_000))
        self.before = self.state()

    def state(self):
        return {name: (path.read_bytes(), path.stat().st_mtime_ns)
                for name, path in self.inputs.items()}

    def invoke(self, output, effect=None):
        arguments = [token for name, path in self.inputs.items() for token in ("--" + name, str(path))]
        arguments += ["--output", str(output)]
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(check, "verify", side_effect=effect, return_value={"status": "test stub"}) as verify, \
                contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            result = check.main(arguments)
        self.assertEqual(self.state(), self.before, "report publication changed an input or its mtime")
        return result, verify, stdout.getvalue(), stderr.getvalue()

    def test_existing_external_symlinks_and_hardlinks_are_refused_before_verify(self):
        output = self.directory / "report.json"
        for target in self.inputs.values():
            for kind in ("symlink", "hardlink"):
                with self.subTest(target=target.name, kind=kind):
                    output.symlink_to(target) if kind == "symlink" else os.link(target, output)
                    try:
                        result, verify, stdout, stderr = self.invoke(output)
                        self.assertEqual(result, 1)
                        self.assertIn("must not overwrite an input", stderr)
                        self.assertEqual(stdout, "")
                        verify.assert_not_called()
                    finally:
                        output.unlink()

    def test_selected_input_symlink_is_resolved_before_verify(self):
        name = "native-report"
        target = self.inputs[name]
        alias = self.directory / "input-alias.json"
        alias.symlink_to(target)
        self.inputs[name] = alias
        result, verify, _, stderr = self.invoke(target)
        self.assertEqual(result, 1)
        self.assertIn("must not overwrite an input", stderr)
        verify.assert_not_called()

    def test_late_external_symlink_and_hardlink_are_refused_after_verify(self):
        output = self.directory / "report.json"
        for target in self.inputs.values():
            for kind in ("symlink", "hardlink"):
                with self.subTest(target=target.name, kind=kind):
                    def effect(*args):
                        output.symlink_to(target) if kind == "symlink" else os.link(target, output)
                        return {"status": "test stub"}
                    try:
                        result, verify, stdout, stderr = self.invoke(output, effect)
                        self.assertEqual(result, 1)
                        self.assertIn("must not overwrite an input", stderr)
                        self.assertEqual(stdout, "")
                        verify.assert_called_once()
                        self.assertTrue(output.samefile(target))
                    finally:
                        output.unlink(missing_ok=True)

    def test_late_parent_directory_alias_is_refused_after_verify(self):
        parent = self.directory / "reports"
        parent.mkdir()
        output = parent / "native-snapshot.json"
        def effect(*args):
            parent.rmdir()
            parent.symlink_to(self.input_directory, target_is_directory=True)
            return {"status": "test stub"}
        result, verify, stdout, stderr = self.invoke(output, effect)
        self.assertEqual(result, 1)
        self.assertIn("must not overwrite an input", stderr)
        self.assertEqual(stdout, "")
        verify.assert_called_once()

    def test_repository_build_and_suffix_fences_run_before_verify(self):
        repository = self.directory / "repository"
        with patch.object(check, "ROOT", repository):
            for output, diagnostic in ((repository / "docs/report.json", "beneath build/"),
                                       (self.directory / "report.txt", ".json report")):
                with self.subTest(output=output):
                    result, verify, _, stderr = self.invoke(output)
                    self.assertEqual(result, 1)
                    self.assertIn(diagnostic, stderr)
                    verify.assert_not_called()
                    self.assertFalse(output.exists())

    def test_independent_external_report_is_written(self):
        output = self.directory / "reports/report.json"
        result, verify, stdout, stderr = self.invoke(output)
        self.assertEqual(result, 0, stderr)
        verify.assert_called_once()
        self.assertEqual(json.loads(output.read_text()), {"status": "test stub"})
        self.assertEqual(output.read_text(), stdout)


if __name__ == "__main__":
    unittest.main()
