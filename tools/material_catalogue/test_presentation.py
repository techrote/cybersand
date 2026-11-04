#!/usr/bin/env python3
"""Strict-input, custody and publication regressions for Main's label resource.

Every writing call selects a fresh temporary root. The repository's catalogue,
presentation inputs and generated outputs are never written by these tests.
Actual old-versus-new Main/Web behavior belongs to the independent B consumer
check; generator tests alone are not a consumer-routing proof.
"""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import presentation

ROOT = Path(__file__).resolve().parents[2]


def state(path: Path):
    if path.is_symlink():
        return ("symlink", str(path.readlink()), path.lstat().st_mtime_ns)
    if path.is_file():
        return ("file", path.read_bytes(), path.stat().st_mtime_ns, path.stat().st_mode)
    return None


class PresentationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="mat353b-presentation-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.root = self.directory / "source"
        self.root.mkdir()
        for relative in presentation.INPUTS:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        self.catalogue = self.root / presentation.CATALOGUE
        self.authored = self.root / presentation.PRESENTATION
        self.script = self.root / presentation.SCRIPT
        self.manifest = self.root / presentation.MANIFEST
        self.data = json.loads(self.authored.read_text(encoding="utf-8"))

    def outputs(self):
        return {relative: state(self.root / relative) for relative in presentation.OUTPUTS}

    def write(self, value, path=None):
        (path or self.authored).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")

    def generate(self):
        return presentation.generate(self.root)

    def check(self):
        return presentation.check(self.root)

    def cli(self, *arguments):
        return subprocess.run(
            [sys.executable, str(ROOT / presentation.GENERATOR), "--root", str(self.root), *arguments],
            cwd=self.directory, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
            text=True, capture_output=True, timeout=30)

    def assert_invalid(self, value, pointer, path=None):
        self.write(value, path)
        before = self.outputs()
        with self.assertRaisesRegex(presentation.PresentationError, re.escape(pointer)):
            self.generate()
        self.assertEqual(self.outputs(), before)
        self.assertEqual(list(self.root.rglob(".presentation-*")), [])

    @staticmethod
    def names(script: bytes) -> list[str]:
        rows = re.findall(r"^\t(.+), # ([0-9]+)$", script.decode("utf-8"), re.M)
        assert [int(index) for _, index in rows] == list(range(132))
        return [json.loads(name) for name, _ in rows]

    def test_generated_resource_is_bounded_labels_only_with_five_exact_exceptions(self):
        self.assertEqual(set(self.generate()), set(presentation.OUTPUTS))
        script = self.script.read_bytes()
        names = self.names(script)
        self.assertEqual(names[0], "empty")
        self.assertEqual(names[10], "")
        exceptions = {80: "LED white", 83: "rough oak log", 113: "galvanised zinc sheet",
                      117: "bare iron plate", 131: "heat-shield tile"}
        catalogue = json.loads(self.catalogue.read_text(encoding="utf-8"))
        for row in catalogue["native"]["materials"]:
            material_id = row["id"]
            expected = "" if material_id == 10 else exceptions.get(material_id, row["name"].replace("-", " "))
            self.assertEqual(names[material_id], expected, material_id)
        self.assertEqual(script.count(b"const "), 1)
        self.assertIn(b"const NAMES: Array[String]", script)
        for token in (b"class_name", b"NATIVE_FACTS", b"func ", b"load(", b"FileAccess", b"JSON", b"density"):
            self.assertNotIn(token, script)
        for relative, content in presentation.render(self.root).items():
            self.assertTrue(content.endswith(b"\n"))
            self.assertNotIn(b"\r", content)
            content.decode("utf-8", errors="strict")
            self.assertLessEqual(len(content), presentation.BUDGETS[relative])
            self.assertNotIn(str(self.root).encode(), content)
        self.assertEqual(self.check()["status"], "PASS")

    def test_manifest_and_check_bind_actual_sources_tools_and_artifact_bytes(self):
        self.generate()
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(manifest["consumer"], "godot/scripts/main.gd::material_name")
        self.assertEqual(manifest["scope"], "ui-labels-only")
        facts = manifest["inputs"] + manifest["tool_sources"]
        self.assertEqual({row["path"] for row in facts}, set(presentation.INPUTS))
        for fact in facts:
            content = (self.root / fact["path"]).read_bytes().replace(b"\r\n", b"\n")
            self.assertEqual(fact["lf_sha256"], hashlib.sha256(content).hexdigest())
            self.assertEqual(fact["lf_bytes"], len(content))
        self.assertEqual(manifest["artifacts"], [{"path": presentation.SCRIPT,
                         "sha256": hashlib.sha256(self.script.read_bytes()).hexdigest(),
                         "bytes": len(self.script.read_bytes())}])
        for row in self.check()["artifacts"]:
            content = (self.root / row["path"]).read_bytes()
            self.assertEqual(row["sha256"], hashlib.sha256(content).hexdigest())
            self.assertEqual(row["bytes"], len(content))

    def test_two_clean_roots_produce_identical_bytes_and_check_never_writes(self):
        other = self.directory / "another-location"
        shutil.copytree(self.root, other)
        self.generate()
        presentation.generate(other)
        for relative in presentation.OUTPUTS:
            self.assertEqual((self.root / relative).read_bytes(), (other / relative).read_bytes())
        for relative in presentation.OUTPUTS:
            os.utime(self.root / relative, ns=(1_600_000_000_000_000_000, 1_600_000_000_000_000_000))
        before = self.outputs()
        self.assertEqual(self.generate(), [])
        self.check()
        result = self.cli("--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.outputs(), before)

    def test_crlf_inputs_retain_normalized_fingerprints_and_lf_outputs(self):
        first = presentation.render(self.root)
        for relative in presentation.INPUTS:
            target = self.root / relative
            target.write_bytes(target.read_bytes().replace(b"\n", b"\r\n"))
        self.assertEqual(presentation.render(self.root), first)

    def test_reordered_authorship_keeps_numeric_label_order_and_records_source_change(self):
        self.generate()
        script = self.script.read_bytes()
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        self.data["overrides"].reverse()
        self.write(self.data)
        catalogue = json.loads(self.catalogue.read_text(encoding="utf-8"))
        catalogue["native"]["materials"].reverse()
        self.write(catalogue, self.catalogue)
        self.generate()
        self.assertEqual(self.script.read_bytes(), script)
        updated = json.loads(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(updated["labels_sha256"], manifest["labels_sha256"])
        self.assertNotEqual(updated["inputs"], manifest["inputs"])

    def test_missing_output_check_has_no_creation_or_success_side_effect(self):
        before = self.outputs()
        with self.assertRaisesRegex(presentation.PresentationError, "missing"):
            self.check()
        result = self.cli("--check")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("missing", result.stderr)
        self.assertEqual(self.outputs(), before)
        self.assertFalse(self.script.parent.exists())

    def test_stale_or_malformed_output_check_refuses_without_repair(self):
        self.generate()
        for target in (self.script, self.manifest):
            with self.subTest(target=target):
                original = target.read_bytes()
                target.write_text("{malformed output\n", encoding="utf-8")
                before = self.outputs()
                with self.assertRaisesRegex(presentation.PresentationError, "stale or invalid"):
                    self.check()
                result = self.cli("--check")
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(target.name, result.stderr)
                self.assertEqual(self.outputs(), before)
                target.write_bytes(original)

    def test_unknown_missing_and_wrongly_typed_presentation_fields_preserve_output(self):
        self.generate()
        changes = []
        for value in (None, [], 1, True, "text"):
            changes.append((value, "expected an object"))
        for field in ("scope", "native", "NATIVE_FACTS", "defaults"):
            changed = copy.deepcopy(self.data)
            changed[field] = {}
            changes.append((changed, "/" + field))
        for field in self.data:
            changed = copy.deepcopy(self.data)
            del changed[field]
            changes.append((changed, "/" + field))
        for version in (0, 2, -1, True, 1.0, "1", None):
            changed = copy.deepcopy(self.data)
            changed["schema_version"] = version
            changes.append((changed, "/schema_version"))
        changed = copy.deepcopy(self.data)
        changed["schema_id"] += ".other"
        changes.append((changed, "/schema_id"))
        for value in (None, {}, 1, "five", True):
            changed = copy.deepcopy(self.data)
            changed["overrides"] = value
            changes.append((changed, "/overrides"))
        for value, pointer in changes:
            with self.subTest(pointer=pointer, value=value):
                self.assert_invalid(value, pointer)

    def test_duplicate_keys_bad_json_and_nonfinite_values_are_not_silently_accepted(self):
        self.generate()
        original = json.dumps(self.data)
        cases = [
            ('{\n "schema_version": 1,\n}\n', "line 3, column 1"),
            (original.replace('"schema_version": 1', '"schema_version": 1, "schema_version": 1'), "duplicate object key"),
            (original.replace('"id": 80', '"id": 80, "id": 83'), "duplicate object key"),
        ]
        for token in ("NaN", "Infinity", "-Infinity"):
            cases.append((original.replace('"id": 80', '"id": ' + token), "non-finite"))
        for source, diagnostic in cases:
            with self.subTest(diagnostic=diagnostic):
                self.authored.write_text(source, encoding="utf-8")
                before = self.outputs()
                with self.assertRaisesRegex(presentation.PresentationError, re.escape(diagnostic)):
                    self.generate()
                self.assertEqual(self.outputs(), before)

    def test_only_five_exact_exceptions_are_admitted(self):
        self.generate()
        for bad_id in (0, 10, 81, 132, -1, 256, True, 80.0, "80", None):
            with self.subTest(id=bad_id):
                changed = copy.deepcopy(self.data)
                changed["overrides"][0]["id"] = bad_id
                self.assert_invalid(changed, "/overrides/0/id")
        for value in (None, [], {}, 1, True, "", "led white", "LED-white", "LED  white", "LED white "):
            with self.subTest(display_name=value):
                changed = copy.deepcopy(self.data)
                changed["overrides"][0]["display_name"] = value
                self.assert_invalid(changed, "/overrides/0/display_name")
        for operation in ("missing", "duplicate", "extra", "unknown-field"):
            changed = copy.deepcopy(self.data)
            if operation == "missing":
                changed["overrides"].pop()
            elif operation == "duplicate":
                changed["overrides"][1] = copy.deepcopy(changed["overrides"][0])
            elif operation == "extra":
                changed["overrides"].append({"id": 82, "display_name": "birch log"})
            else:
                changed["overrides"][0]["physics"] = {}
            with self.subTest(operation=operation):
                self.assert_invalid(changed, "/overrides")

    def test_complete_catalogue_is_validated_including_non_label_fields(self):
        self.generate()
        original = json.loads(self.catalogue.read_text(encoding="utf-8"))
        for field, value in (("density", -1), ("kernel", 999), ("valid", False),
                             ("movable", "false"), ("unknown_field", 42)):
            with self.subTest(field=field):
                changed = copy.deepcopy(original)
                changed["native"]["materials"][3][field] = value
                self.assert_invalid(changed, "/native/materials/3", self.catalogue)

    def test_material_identity_changes_invalid10_and_synthetic132_are_refused(self):
        self.generate()
        original = json.loads(self.catalogue.read_text(encoding="utf-8"))
        changes = []
        changed = copy.deepcopy(original)
        changed["native"]["materials"][3]["name"] = "replacement-water"
        changes.append(changed)
        changed = copy.deepcopy(original)
        changed["native"]["materials"][3]["id"] = 4
        changes.append(changed)
        changed = copy.deepcopy(original)
        changed["native"]["materials"][10]["valid"] = True
        changes.append(changed)
        changed = copy.deepcopy(original)
        extra = copy.deepcopy(changed["native"]["materials"][2])
        extra.update(id=132, name="synthetic-powder")
        changed["native"]["materials"].append(extra)
        changes.append(changed)
        changed = copy.deepcopy(original)
        changed["scope"] = "isolated-synthetic"
        changes.append(changed)
        for index, changed in enumerate(changes):
            with self.subTest(case=index):
                self.assert_invalid(changed, presentation.CATALOGUE, self.catalogue)

    def test_registry_guard_is_independent_of_a_relaxed_compiler_validation_call(self):
        self.generate()
        accepted = presentation.compiler.load_catalogue(self.catalogue)
        accepted["native"]["materials"][3]["name"] = "replacement-water"
        before = self.outputs()
        with patch.object(presentation.compiler, "load_catalogue", return_value=accepted):
            with self.assertRaisesRegex(presentation.PresentationError, "frozen 132-slot"):
                self.generate()
        self.assertEqual(self.outputs(), before)

    def test_drifted_generator_or_parser_source_cannot_claim_executed_tool_custody(self):
        self.generate()
        for relative in (presentation.GENERATOR, presentation.COMPILER):
            path = self.root / relative
            original = path.read_bytes()
            with self.subTest(path=relative):
                path.write_bytes(original + b"# changed after the tool was loaded\n")
                before = self.outputs()
                for operation in (self.generate, self.check):
                    with self.assertRaisesRegex(presentation.PresentationError, "differs from executing tool"):
                        operation()
                    self.assertEqual(self.outputs(), before)
                path.write_bytes(original)

    def test_sources_and_output_symlinks_or_output_hardlinks_are_refused(self):
        self.generate()
        for relative in (*presentation.INPUTS, *presentation.OUTPUTS):
            path = self.root / relative
            held = self.directory / (path.name + ".held")
            path.rename(held)
            path.symlink_to(held)
            try:
                with self.subTest(alias=relative):
                    before = state(held)
                    with self.assertRaisesRegex(presentation.PresentationError, "symlink"):
                        self.generate()
                    self.assertEqual(state(held), before)
            finally:
                path.unlink()
                held.rename(path)
        for relative in presentation.OUTPUTS:
            path = self.root / relative
            held = self.directory / (path.name + ".held")
            os.link(path, held)
            try:
                with self.subTest(hardlink=relative):
                    before = state(held)
                    with self.assertRaisesRegex(presentation.PresentationError, "hard-linked"):
                        self.generate()
                    self.assertEqual(state(held), before)
            finally:
                held.unlink()

    def test_output_parent_alias_is_refused_without_writing_its_target(self):
        self.generate()
        parent = self.script.parent
        held = self.directory / "generated-held"
        parent.rename(held)
        parent.symlink_to(held, target_is_directory=True)
        before = {path.name: state(path) for path in held.iterdir()}
        with self.assertRaisesRegex(presentation.PresentationError, "symlink"):
            self.generate()
        self.assertEqual({path.name: state(path) for path in held.iterdir()}, before)

    def test_unrelated_generated_directory_files_are_preserved(self):
        self.generate()
        other = self.script.parent / "another-resource.gd"
        other.write_text("extends RefCounted\n", encoding="utf-8")
        before = state(other)
        self.script.write_bytes(self.script.read_bytes() + b"# stale\n")
        self.generate()
        self.assertEqual(state(other), before)

    def test_publication_failure_rolls_back_bytes_and_mtimes_of_all_old_outputs(self):
        self.generate()
        for relative in presentation.OUTPUTS:
            path = self.root / relative
            path.write_bytes(b"previous accepted output preserved by rollback\n")
            os.utime(path, ns=(1_600_000_000_000_000_000, 1_600_000_000_000_000_000))
        before = self.outputs()
        real_replace = os.replace
        calls = 0

        def fail_second(source, destination):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("injected second-output publication failure")
            return real_replace(source, destination)

        with patch.object(presentation.os, "replace", side_effect=fail_second):
            with self.assertRaisesRegex(OSError, "injected"):
                self.generate()
        self.assertGreaterEqual(calls, 3, "the already-replaced first output must be restored")
        self.assertEqual(self.outputs(), before)
        self.assertEqual(list(self.root.rglob(".presentation-*")), [])

    def test_publication_failure_removes_new_outputs_and_empty_created_directories(self):
        real_replace = os.replace
        calls = 0

        def fail_second(source, destination):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("injected second-output publication failure")
            return real_replace(source, destination)

        with patch.object(presentation.os, "replace", side_effect=fail_second):
            with self.assertRaisesRegex(OSError, "injected"):
                self.generate()
        self.assertFalse(self.script.exists())
        self.assertFalse(self.manifest.exists())
        self.assertFalse((self.root / "godot").exists())
        self.assertEqual(list(self.root.rglob(".presentation-*")), [])

    def test_source_change_during_staging_is_refused_before_any_output_replacement(self):
        self.generate()
        for relative in presentation.OUTPUTS:
            path = self.root / relative
            path.write_bytes(path.read_bytes() + b"stale\n")
        before = self.outputs()
        real_fsync = os.fsync

        def change_source(descriptor):
            self.authored.write_bytes(self.authored.read_bytes() + b" \n")
            return real_fsync(descriptor)

        with patch.object(presentation.os, "fsync", side_effect=change_source):
            with self.assertRaisesRegex(presentation.PresentationError, "changed during"):
                self.generate()
        self.assertEqual(self.outputs(), before)
        self.assertEqual(list(self.root.rglob(".presentation-*")), [])

    def test_budget_failure_is_checked_before_publication(self):
        self.generate()
        before = self.outputs()
        with patch.dict(presentation.BUDGETS, {presentation.SCRIPT: 1}):
            with self.assertRaisesRegex(presentation.PresentationError, "exceeds 1-byte budget"):
                self.generate()
        self.assertEqual(self.outputs(), before)


if __name__ == "__main__":
    unittest.main()
