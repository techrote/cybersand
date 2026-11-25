#!/usr/bin/env python3
"""Adversarial input-equivalence checks; these fixtures grant no runtime credit."""
from __future__ import annotations

import copy
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

from retained_runtime import EXTRA_INPUTS, build_inputs, tree


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


class RetainedNativeInputs(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.names = ["native/src/world.cpp", "godot/native_extension/adapter.cpp",
                      "tools/build_native_extension.sh", "tools/pubpres_playability_build/build_runtime.py",
                      *EXTRA_INPUTS, "godot/scripts/main.gd"]
        for name in self.names:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(("original " + name + "\n").encode())
        self.commit("original")
        self.old = self.git("rev-parse", "HEAD")
        self.runtime = {"source_commit": self.old, "source_tree": tree(self.root, self.old),
                        "source_inputs_sha256": {name: sha((self.root / name).read_bytes()) for name in self.names[:2]},
                        "build_script": self.names[2], "build_script_sha256": sha((self.root / self.names[2]).read_bytes()),
                        "driver_inputs_sha256": {"build_runtime.py": sha((self.root / self.names[3]).read_bytes())}}

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True).strip()

    def commit(self, message):
        self.git("add", ".")
        self.git("commit", "-qm", message)

    def application(self):
        ref = self.git("rev-parse", "HEAD")
        return {"source_commit": ref, "source_tree": tree(self.root, ref)}

    def test_application_only_edit_keeps_original_build_identity(self):
        (self.root / "godot/scripts/main.gd").write_text("new application\n")
        self.commit("application-only")
        before = copy.deepcopy(self.runtime)
        inputs = build_inputs(self.root, self.application(), self.runtime)
        self.assertEqual(inputs["native/src/world.cpp"], self.runtime["source_inputs_sha256"]["native/src/world.cpp"])
        self.assertEqual(self.runtime, before)
        self.assertNotEqual(self.application()["source_commit"], self.runtime["source_commit"])

    def test_changed_native_source_is_not_reusable(self):
        (self.root / "native/src/world.cpp").write_text("changed physics\n")
        self.commit("changed-native")
        with self.assertRaisesRegex(ValueError, "requires an independent rebuild"):
            build_inputs(self.root, self.application(), self.runtime)

    def test_added_native_header_is_not_hidden_by_old_input_map(self):
        (self.root / "native/src/new.hpp").write_text("new dependency\n")
        self.commit("new-native-input")
        with self.assertRaisesRegex(ValueError, "different native source closure"):
            build_inputs(self.root, self.application(), self.runtime)

    def test_changed_builder_policy_requires_rebuild(self):
        for name in EXTRA_INPUTS:
            original = (self.root / name).read_bytes()
            (self.root / name).write_text("changed build policy\n")
            self.commit("policy-drift")
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "requires an independent rebuild"):
                build_inputs(self.root, self.application(), self.runtime)
            (self.root / name).write_bytes(original)
            self.commit("restore-policy")

    def test_mutable_tree_and_wrong_tree_identity_are_refused(self):
        app = self.application()
        (self.root / "native/src/world.cpp").write_text("uncommitted native edit\n")
        with self.assertRaisesRegex(ValueError, "requires an independent rebuild"):
            build_inputs(self.root, app, self.runtime)
        app["source_tree"] = "0" * 40
        with self.assertRaisesRegex(ValueError, "tree differs"):
            build_inputs(self.root, app, self.runtime)


if __name__ == "__main__":
    unittest.main()
