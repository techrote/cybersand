"""Receipt-custody regressions; these synthetic records do not qualify Godot."""
from __future__ import annotations

import contextlib
import copy
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import check_gdscript_shadow as check
import proof_scopes
from check_native_parity import file_fact


class GodotReceiptGuards(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mat353-gd-receipt-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.protected = {"unit_test_only": True}
        # Read, never update, the independently retained historical v1 report.
        # Synthetic current custody below tests the reader, not native execution.
        historical = check.ROOT / "docs/audits/mat-auth371-integration-20261104/native-parity.json"
        self.historical = json.loads(historical.read_text())
        self.receipt = copy.deepcopy(self.historical)
        self.receipt.pop("production_cutover")
        self.receipt.update({
            "schema_version": 2, "protected_sources": self.protected,
            "scope": proof_scopes.NATIVE_PROOF_SCOPE,
            "source_commit_role": proof_scopes.NATIVE_SOURCE_COMMIT_ROLE,
            "authority_scopes": copy.deepcopy(proof_scopes.AUTHORITY_SCOPES),
            "b_consumer_requirement": copy.deepcopy(proof_scopes.B_CONSUMER_REQUIREMENT),
            "ui_behavior_executed": False, "b_consumer_qualified": False,
        })
        for group, names in check.RECEIPT_PATHS.items():
            self.receipt[group] = []
            for name in names:
                path = self.root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                if name == check.compatibility.LOCK.as_posix():
                    path.write_bytes((check.ROOT / check.compatibility.LOCK).read_bytes())
                else:
                    path.write_text("fixture content for " + name + "\n")
                self.receipt[group].append(file_fact(path, self.root))
        self.git("init", "--quiet")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "isolated receipt fixture")
        self.receipt["checked_source"] = proof_scopes.checked_source(
            self.root, {group: self.receipt[group] for group in check.RECEIPT_PATHS})

    def git(self, *arguments):
        subprocess.run(["git", "-C", str(self.root), "-c", "user.name=Receipt fixture",
                        "-c", "user.email=receipt-fixture@invalid.local", *arguments],
                       check=True, capture_output=True, timeout=30)

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

    def test_receipt_must_assert_complete_shadow_equality_and_no_ui_or_world_execution(self):
        for field, bad in (("native_authored_compiled_shadow_facts_equal", False),
                           ("status", "FAIL"), ("world_executed", True),
                           ("godot_executed", True), ("ui_behavior_executed", True),
                           ("b_consumer_qualified", True), ("schema_version", True)):
            with self.subTest(field=field):
                changed = copy.deepcopy(self.receipt)
                changed[field] = bad
                with self.assertRaises(ValueError):
                    self.validate(changed)

    def test_retained_v1_receipt_is_not_current_b_evidence(self):
        with self.assertRaisesRegex(ValueError, "historical v1 is not current B proof"):
            self.validate(self.historical)

    def test_ambiguous_global_cutover_claim_is_not_in_current_schema(self):
        for value in (False, True):
            changed = copy.deepcopy(self.receipt)
            changed["production_cutover"] = value
            with self.assertRaisesRegex(ValueError, "complete schema fields"):
                self.validate(changed)

    def test_exact_scope_and_mandatory_independent_b_requirement(self):
        for field in ("authority_scopes", "b_consumer_requirement"):
            changed = copy.deepcopy(self.receipt)
            changed.pop(field)
            with self.assertRaisesRegex(ValueError, "complete schema fields"):
                self.validate(changed)
        for field, bad in (("mandatory", False), ("mandatory", 1),
                           ("schema_version", 1), ("satisfied_by_this_report", True),
                           ("status", "PASS")):
            with self.subTest(field=field, value=bad):
                changed = copy.deepcopy(self.receipt)
                changed["b_consumer_requirement"][field] = bad
                with self.assertRaisesRegex(ValueError, "B proof requirement"):
                    self.validate(changed)
        changed = copy.deepcopy(self.receipt)
        changed["authority_scopes"]["native_runtime"]["production_cutover"] = True
        with self.assertRaisesRegex(ValueError, "authority scopes"):
            self.validate(changed)

    def test_stale_or_forged_current_source_context_is_refused(self):
        changed = copy.deepcopy(self.receipt)
        changed["checked_source"]["inventories_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "checked source identity"):
            self.validate(changed)
        self.git("commit", "--quiet", "--allow-empty", "-m", "different head, unchanged scoped files")
        with self.assertRaisesRegex(ValueError, "checked source identity"):
            self.validate()

    def test_original_manifest_and_new_consumer_inventory_are_authenticated(self):
        for name in ("materials/catalogue/generated/manifest.json",
                     *check.RECEIPT_PATHS["consumer_source_custody"]):
            with self.subTest(path=name):
                path = self.root / name
                previous = path.read_bytes()
                try:
                    path.write_bytes(previous + b"drift\n")
                    with self.assertRaisesRegex(ValueError, "native receipt.*" + path.name):
                        self.validate()
                finally:
                    path.write_bytes(previous)

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

    def test_editor_pin_output_alias_is_refused_before_and_after_probe(self):
        repository = self.directory / "repository"
        pin = repository / "third_party/godot-runtime.lock.json"
        pin.parent.mkdir(parents=True)
        pin.write_text("retained editor pin\n")
        before = (pin.read_bytes(), pin.stat().st_mtime_ns)
        output = self.directory / "pin-alias.json"
        for late in (False, True):
            with self.subTest(late=late), patch.object(check, "ROOT", repository):
                def effect(*args):
                    output.symlink_to(pin)
                    return {"status": "test stub"}
                if not late:
                    output.symlink_to(pin)
                try:
                    result, verify, stdout, stderr = self.invoke(output, effect if late else None)
                    self.assertEqual(result, 1)
                    self.assertIn("must not overwrite an input", stderr)
                    self.assertEqual(stdout, "")
                    if late:
                        verify.assert_called_once()
                    else:
                        verify.assert_not_called()
                    self.assertEqual((pin.read_bytes(), pin.stat().st_mtime_ns), before)
                finally:
                    output.unlink(missing_ok=True)

    def test_actual_godot_checker_source_is_an_implicit_protected_input(self):
        checker = self.directory / "readback.py"
        checker.write_text("retained reader source\n")
        before = (checker.read_bytes(), checker.stat().st_mtime_ns)
        output = self.directory / "checker-alias.json"
        output.symlink_to(checker)
        with patch.object(check, "__file__", str(checker)):
            result, verify, stdout, stderr = self.invoke(output)
        self.assertEqual(result, 1)
        self.assertIn("must not overwrite an input", stderr)
        self.assertEqual(stdout, "")
        verify.assert_not_called()
        self.assertEqual((checker.read_bytes(), checker.stat().st_mtime_ns), before)


if __name__ == "__main__":
    unittest.main()
