#!/usr/bin/env python3
"""Adverse report-only scope tests, including real Git source and rename fixtures."""
from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).with_name("native_scope_classifier.py").resolve()
spec = importlib.util.spec_from_file_location("native_scope", SOURCE)
scope = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scope)


class ClassificationTests(unittest.TestCase):
    def check_required(self, paths):
        result = scope.classify(paths)
        self.assertTrue(result["candidate_native_execution_needed"])
        self.assertEqual(result["candidate_exemption_kind"], "none")
        self.assertIs(result["native_skip_authorized"], False)
        self.assertIs(result["existing_native_merge_gate_changed"], False)

    def test_original_twenty_fixtures_still_execute(self):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            scope.selftest()
        self.assertIn("20 conservative classification fixtures", output.getvalue())

    def test_raw_invalid_segments_fail_closed_before_normalization(self):
        for path in ("docs/./readme.md", "./docs/readme.md", "docs/../readme.md",
                     "/docs/readme.md", "docs//readme.md", "docs/readme.md/",
                     r"docs\readme.md", "", "docs/\0bad.md", "docs/line\nbreak.md",
                     "docs/tab\tname.md", "docs/\x7fbad.md"):
            with self.subTest(path=path):
                self.assertEqual(scope.reason(path), "unsafe-or-invalid")
                self.check_required([path])

    def test_empty_duplicate_unknown_and_mixed_sets_fail_closed(self):
        for paths in ([], ["README.md", "README.md"], ["unknown/new.bin"],
                      ["godot/scripts/main.gd", "native/src/world.cpp"],
                      ["godot/scripts/new.cpp"], [".github/workflows/new.yml"]):
            with self.subTest(paths=paths):
                self.check_required(paths)

    def test_malformed_inventory_cannot_become_an_exemption(self):
        for paths in (None, "README.md", {"README.md"}, [None], [{}], [42]):
            with self.subTest(paths=paths):
                with self.assertRaises(ValueError):
                    scope.classify(paths)

    def test_known_advice_never_authorizes_a_skip(self):
        for paths in (["README.md", "docs/architecture.md"],
                      ["godot/project.godot", "godot/shaders/material_palette.gdshader"],
                      ["godot/scripts/main.gd", "tools/play/run_pace003_campaign.py"]):
            with self.subTest(paths=paths):
                result = scope.classify(paths)
                self.assertFalse(result["candidate_native_execution_needed"])
                self.assertIs(result["native_skip_authorized"], False)
                self.assertIs(result["existing_native_merge_gate_changed"], False)

    def test_wrong_classifier_is_rejected_even_when_asserts_are_optimized_out(self):
        # Original PR313 printed PASS under optimize=1 for this adverse control.
        for optimization in (0, 1):
            with self.subTest(optimization=optimization):
                namespace = {"__name__": "adverse_scope_control"}
                exec(compile(SOURCE.read_text(), str(SOURCE), "exec",
                             optimize=optimization), namespace)
                namespace["classify"] = lambda paths: {
                    "candidate_native_execution_needed": False,
                    "candidate_exemption_kind": "documentation-only",
                    "native_skip_authorized": False,
                    "existing_native_merge_gate_changed": False,
                }
                with self.assertRaises((RuntimeError, AssertionError)):
                    namespace["selftest"]()


class GitSourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cybersand-scope-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repository"
        self.root.mkdir()
        self.output = Path(self.temp.name) / "result.json"
        self.git("init", "-q", "--initial-branch=main")
        self.git("config", "user.name", "Scope fixture")
        self.git("config", "user.email", "scope-fixture@example.invalid")
        self.write(".gitignore", "/build/\n__pycache__/\n")
        self.write("docs/readme.md", "baseline documentation\n")
        self.write("native/src/fixture.cpp", "source fixture\n")
        self.program = self.root / "tools/ci/native_scope_classifier.py"
        self.program.parent.mkdir(parents=True)
        shutil.copyfile(SOURCE, self.program)
        self.base = self.commit("source scope base")

    def git(self, *arguments):
        return subprocess.check_output(
            ["git", "-C", str(self.root), "-c", "commit.gpgsign=false", *arguments],
            stderr=subprocess.PIPE, timeout=30).decode().strip()

    def write(self, relative, contents):
        target = self.root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(contents)
        return target

    def commit(self, message):
        self.git("add", "-A")
        self.git("commit", "-qm", message)
        return self.git("rev-parse", "HEAD")

    def run_scope(self, *, base=None, head=None, program=None):
        return subprocess.run(
            [sys.executable, "-B", str(program or self.program),
             "--base-sha", base or self.base,
             "--head-sha", head or self.git("rev-parse", "HEAD"),
             "--output", str(self.output)],
            cwd=self.root, capture_output=True, text=True, timeout=30)

    def failed(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.output.exists(), "An invalid source produced a decision file")

    def test_clean_comparison_binds_both_trees_and_executed_classifier(self):
        self.write("docs/readme.md", "changed documentation\n")
        head = self.commit("documentation change")
        result = self.run_scope()
        self.assertEqual(result.returncode, 0, result.stderr)
        value = json.loads(self.output.read_text())
        self.assertEqual(value["base_sha"], self.base)
        self.assertEqual(value["head_sha"], head)
        self.assertEqual(value["base_tree"], self.git("rev-parse", self.base + "^{tree}"))
        self.assertEqual(value["head_tree"], self.git("rev-parse", head + "^{tree}"))
        self.assertEqual(value["classifier_sha256"], hashlib.sha256(self.program.read_bytes()).hexdigest())
        self.assertTrue(value["worktree_clean"])
        self.assertFalse(value["candidate_native_execution_needed"])
        self.assertIs(value["native_skip_authorized"], False)
        self.assertEqual(value["files"], ["docs/readme.md"])

    def test_real_rename_retains_removed_native_and_added_presentation_paths(self):
        old = self.root / "native/src/fixture.cpp"
        new = self.root / "godot/scripts/renamed.gd"
        new.parent.mkdir(parents=True)
        old.rename(new)
        self.commit("rename across dependency boundary")
        result = self.run_scope()
        self.assertEqual(result.returncode, 0, result.stderr)
        value = json.loads(self.output.read_text())
        self.assertEqual(value["files"], ["godot/scripts/renamed.gd", "native/src/fixture.cpp"])
        self.assertTrue(value["candidate_native_execution_needed"])
        self.assertEqual(value["file_classes"]["native/src/fixture.cpp"], "native-impact")
        self.assertIs(value["native_skip_authorized"], False)

    def test_removed_native_input_still_requires_native_advice(self):
        (self.root / "native/src/fixture.cpp").unlink()
        self.commit("delete native input")
        result = self.run_scope()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(self.output.read_text())["candidate_native_execution_needed"])

    def test_empty_committed_diff_does_not_authorize_an_exemption(self):
        result = self.run_scope()
        self.assertEqual(result.returncode, 0, result.stderr)
        value = json.loads(self.output.read_text())
        self.assertEqual(value["files"], [])
        self.assertTrue(value["candidate_native_execution_needed"])
        self.assertIs(value["native_skip_authorized"], False)

    def test_wrong_checkout_head_is_refused(self):
        self.write("docs/readme.md", "new head\n")
        self.commit("advance head")
        result = self.run_scope(head=self.base)
        self.failed(result)
        self.assertIn("wrong source HEAD", result.stderr)

    def test_short_or_nonexistent_commit_identity_is_refused(self):
        for sha in (self.base[:12], "f" * 40):
            with self.subTest(sha=sha):
                self.failed(self.run_scope(base=sha))

    def test_tag_object_is_not_accepted_as_a_literal_commit_identity(self):
        self.git("tag", "-a", "scope-tag", "-m", "annotated fixture tag")
        tag_object = self.git("rev-parse", "scope-tag")
        self.failed(self.run_scope(base=tag_object))

    def test_dirty_tracked_source_is_refused(self):
        self.write("docs/readme.md", "uncommitted change\n")
        result = self.run_scope()
        self.failed(result)
        self.assertIn("changed or untracked worktree", result.stderr)

    def test_untracked_input_is_refused(self):
        self.write("native/src/untracked.cpp", "not in committed comparison\n")
        result = self.run_scope()
        self.failed(result)
        self.assertIn("changed or untracked worktree", result.stderr)

    def test_external_classifier_cannot_claim_the_checkout_source(self):
        self.failed(self.run_scope(program=SOURCE))

    @unittest.skipIf(os.name == "nt", "newline filenames are unavailable on Windows")
    def test_nul_delimited_diff_preserves_a_control_character_path_for_refusal(self):
        self.write("docs/line\nbreak.md", "unusual Git path\n")
        self.commit("control character path")
        result = self.run_scope()
        self.assertEqual(result.returncode, 0, result.stderr)
        value = json.loads(self.output.read_text())
        self.assertEqual(value["files"], ["docs/line\nbreak.md"])
        self.assertEqual(value["file_classes"]["docs/line\nbreak.md"], "unsafe-or-invalid")
        self.assertTrue(value["candidate_native_execution_needed"])


if __name__ == "__main__":
    unittest.main()
