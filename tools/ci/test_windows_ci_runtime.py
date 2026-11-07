#!/usr/bin/env python3
"""Adversarial coverage of same-run source-attested Windows CI DLL custody."""
import json
import sys
from pathlib import Path
import subprocess
import tempfile
import unittest

import windows_ci_runtime as subject


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args],
                                   text=True).strip()


class WindowsCiRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        git(self.root, "init", "--quiet")
        git(self.root, "config", "user.email", "test@example.invalid")
        git(self.root, "config", "user.name", "Fixture")
        self.source = self.root / "native/include/cybersand/example.hpp"
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(b"#pragma once\n")
        self.impl = self.root / "native/src/world.cpp"
        self.impl.parent.mkdir(parents=True)
        self.impl.write_bytes(b"void example() {}\n")
        self.bridge = self.root / "godot/native_extension/bridge.cpp"
        self.bridge.parent.mkdir(parents=True)
        self.bridge.write_bytes(b"void bridge() {}\n")
        git(self.root, "add", ".")
        git(self.root, "commit", "--quiet", "-m", "native fixture")
        self.sha = git(self.root, "rev-parse", "HEAD")
        self.native = self.root / "compiled.dll"
        self.native.write_bytes(b"MZ" + b"compiled current native extension" * 96)
        self.bundle = self.root / "build/windows-runtime"

    def create(self):
        return subject.write_bundle(self.root, self.native, self.bundle,
                                    source_sha=self.sha, run_id="123", attempt="1")

    def verify(self):
        return subject.verify_bundle(self.root, self.bundle,
                                     source_sha=self.sha, run_id="123", attempt="1")

    def test_current_source_same_run_and_binary_are_exact(self):
        manifest = self.create()
        parsed, raw = self.verify()
        self.assertEqual(manifest, parsed)
        self.assertEqual(json.loads(raw), manifest)
        self.assertEqual(set(manifest["source_inputs"]), {
            "native/include/cybersand/example.hpp",
            "native/src/world.cpp",
            "godot/native_extension/bridge.cpp",
        })
        self.assertEqual(manifest["source_commit"], self.sha)
        self.assertEqual(manifest["source_tree"], git(self.root, "rev-parse", "HEAD^{tree}"))
        self.assertEqual((self.bundle / subject.DLL_NAME).read_bytes(), self.native.read_bytes())

    def test_changes_to_native_header_are_rejected(self):
        self.create()
        self.source.write_bytes(b"#pragma once\n#define CHANGED 1\n")
        with self.assertRaisesRegex(RuntimeError, "native source"):
            self.verify()

    def test_added_native_input_is_rejected(self):
        self.create()
        (self.root / "native/src/extra.hpp").write_bytes(b"new native input\n")
        with self.assertRaisesRegex(RuntimeError, "native source"):
            self.verify()

    def test_binary_mutation_is_rejected(self):
        self.create()
        (self.bundle / subject.DLL_NAME).write_bytes(b"MZ" + b"changed" * 300)
        with self.assertRaisesRegex(RuntimeError, "DLL bytes"):
            self.verify()

    def test_wrong_attempt_and_source_are_rejected(self):
        self.create()
        with self.assertRaisesRegex(RuntimeError, "identity mismatch"):
            subject.verify_bundle(self.root, self.bundle,
                                  source_sha=self.sha, run_id="123", attempt="2")
        with self.assertRaisesRegex(RuntimeError, "checkout SHA"):
            subject.verify_bundle(self.root, self.bundle,
                                  source_sha="0" * 40, run_id="123", attempt="1")

    def test_receipt_sealing_cannot_forge_source_digest(self):
        self.create()
        path = self.bundle / subject.RECEIPT_NAME
        receipt = json.loads(path.read_bytes())
        receipt["source_inputs"]["native/src/world.cpp"] = "0" * 64
        path.write_text(json.dumps(receipt))
        with self.assertRaisesRegex(RuntimeError, "native source"):
            self.verify()

    def test_pointer_or_symlink_is_not_a_current_run_binary(self):
        if sys.platform == "win32":
            self.skipTest("Windows hosted runners need not grant symlink privileges")
        self.create()
        dll = self.bundle / subject.DLL_NAME
        dll.unlink()
        dll.symlink_to(self.native)
        with self.assertRaisesRegex(RuntimeError, "symlinked"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
