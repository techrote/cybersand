#!/usr/bin/env python3
"""Exercise the exact-source qualification refusal boundary without compiling C++."""
from pathlib import Path
import subprocess
import tempfile
import unittest

import qualify_metabolist as qualifier


class SourceIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="metabolist-provenance-")
        self.root = Path(self.temporary.name)
        self.paths = [*qualifier.SOURCES, qualifier.TEST, "Makefile",
                      "tools/architecture/qualify_metabolist.py"]
        for name in self.paths:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("committed fixture source\n")
        self.git("init", "-q")
        self.git("config", "user.name", "Provenance test")
        self.git("config", "user.email", "provenance@example.invalid")
        self.git("add", ".")
        self.git("commit", "-qm", "source fixture")

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, text=True)

    def test_clean_stable_source_passes(self):
        before = qualifier.source_identity(self.root)
        qualifier.require_unchanged_source(self.root, before)

    def test_dirty_source_refused_before_build(self):
        (self.root / qualifier.SOURCES[0]).write_text("uncommitted geometry\n")
        with self.assertRaisesRegex(RuntimeError, "committed clean"):
            qualifier.source_identity(self.root)

    def test_untracked_include_refused(self):
        (self.root / "native/src/new_geometry.inc").write_text("not in HEAD\n")
        with self.assertRaisesRegex(RuntimeError, "committed clean"):
            qualifier.source_identity(self.root)

    def test_mid_run_edit_refused(self):
        before = qualifier.source_identity(self.root)
        (self.root / qualifier.TEST).write_text("changed assertion\n")
        with self.assertRaises(RuntimeError):
            qualifier.require_unchanged_source(self.root, before)

    def test_assume_unchanged_cannot_hide_modified_bytes(self):
        self.git("update-index", "--assume-unchanged", qualifier.SOURCES[0])
        (self.root / qualifier.SOURCES[0]).write_text("hidden native mutation\n")
        with self.assertRaisesRegex(RuntimeError, "does not match HEAD"):
            qualifier.source_identity(self.root)

    def test_head_advance_refused_even_with_identical_tree(self):
        before = qualifier.source_identity(self.root)
        self.git("commit", "--allow-empty", "-qm", "metadata-only advance")
        with self.assertRaisesRegex(RuntimeError, "HEAD or tree changed"):
            qualifier.require_unchanged_source(self.root, before)

    def test_untracked_evidence_does_not_modify_source(self):
        before = qualifier.source_identity(self.root)
        path = self.root / "docs/images/native-preview.png"
        path.parent.mkdir(parents=True)
        path.write_bytes(b"evidence outside build source inputs")
        qualifier.require_unchanged_source(self.root, before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
