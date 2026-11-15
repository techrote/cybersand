#!/usr/bin/env python3
"""Adversarial custody/inventory checks for the reconciliation evaluation."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import package_camera_stack_windows as package


class PackageGuards(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def put(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value)
        return path

    def runtime(self, artifact=package.NATIVE, source="native/src/example.cpp"):
        self.put(source, b"original native input\n")
        binary = self.put(artifact, b"MZ" + bytes(range(256)))
        return {"source_commit": "a" * 40, "source_inputs": {
            source: hashlib.sha256(b"original native input\n").hexdigest()},
            "artifact": artifact, "sha256": package.sha(binary), "size": binary.stat().st_size}

    def evaluation(self):
        native = self.runtime()
        rapier = self.runtime(package.RAPIER, "third_party/rapier-build.txt")
        rapier.pop("source_commit")
        rapier.update(schema_version=1, status="source-matched-cooperative-bvh-backport", build_commit="c" * 40,
                      build_record={"source_sha": "c" * 40, "variant": "patched", "godot_version": package.ENGINE_VERSION,
                                    "join_regression_exit": 0, "artifacts": {Path(package.RAPIER).name: rapier["sha256"]}})
        package.write_json(self.root / package.NATIVE_PROVENANCE, native)
        package.write_json(self.root / "godot/addons/godot-rapier2d/runtime-provenance.windows.json", rapier)
        for name in (package.ENGINE, package.CONSOLE, "Test It.cmd", "Open Workbench.cmd"):
            self.put(name, name.encode())
        script = b"# exact committed runner\n"
        self.put("Run-Camera-Stack.ps1", script)
        self.put("tools/ci/run_camera_stack_windows.ps1", script)
        self.put("godot/scripts/new.gd", b"extends Node\n")
        self.put("godot/source.png.import", b"original metadata\n")
        package.write_json(self.root / "Test-Plan.json", package.test_plan())
        manifest = {"schema": "camera-stack-windows-evaluation-v1", "source_commit": "b" * 40,
                    "accepted_main": package.ACCEPTED_MAIN, "retained_native_unchanged": True,
                    "native_build_commit": native["source_commit"], "native_sha256": native["sha256"],
                    "rapier_sha256": rapier["sha256"], "generator_profiles_sha256": {},
                    "source_files_sha256": {"tools/ci/run_camera_stack_windows.ps1": hashlib.sha256(script).hexdigest()},
                    "files_sha256": package.inventory(self.root)}
        package.write_json(self.root / package.MANIFEST, manifest)
        return manifest

    def test_rejects_windows_path_traversal_aliases_and_devices(self):
        for value in ("../escape", "/absolute", "C:/drive", "bad\\path", "a//b", "./a", ".",
                      "NUL", "dir/COM1.txt", "trailing.", "trailing ", 'dir/<bad>'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                package.safe_name(value)
        self.assertEqual(str(package.safe_name("godot/scripts/main.gd")), "godot/scripts/main.gd")

    def test_reuses_original_build_identity_only_with_equal_native_inputs(self):
        manifest = self.runtime()
        package.verify_runtime(self.root, manifest)
        self.assertEqual(manifest["source_commit"], "a" * 40)
        self.put("native/src/example.cpp", b"altered native algorithm\n")
        with self.assertRaisesRegex(ValueError, "native source mismatch"):
            package.verify_runtime(self.root, manifest)

    def test_platform_line_endings_do_not_change_compiler_input_identity(self):
        manifest = self.runtime()
        self.put("native/src/example.cpp", b"original native input\r\n")
        package.verify_runtime(self.root, manifest)

    def test_pointer_and_altered_runtime_are_rejected(self):
        manifest = self.runtime()
        for body in (b"version https://git-lfs.github.com/spec/v1\n", b"MZchanged"):
            self.put(package.NATIVE, body)
            with self.assertRaises(ValueError):
                package.verify_runtime(self.root, manifest)

    def test_rapier_requires_its_distinct_build_record_not_native_source_commit(self):
        self.evaluation()
        manifest = package.read_json(self.root / "godot/addons/godot-rapier2d/runtime-provenance.windows.json")
        package.verify_runtime(self.root, manifest, kind="rapier")
        manifest["build_record"]["source_sha"] = "d" * 40
        with self.assertRaisesRegex(ValueError, "Rapier build-record"):
            package.verify_runtime(self.root, manifest, kind="rapier")

    def test_exact_evaluation_and_generated_metadata_after_legitimate_use(self):
        self.evaluation()
        package.verify(self.root)
        self.put("godot/scripts/new.gd.uid", b"uid://generated")
        self.put("godot/.godot/imported/generated.cache", b"cache")
        self.put("godot/source.png.import", b"new metadata")
        self.put("Test-It-Results/run/stdout.log", b"original evidence")
        package.verify(self.root, used=True)
        with self.assertRaises(ValueError):
            package.verify(self.root)

    def test_used_package_still_rejects_product_source_changes(self):
        self.evaluation()
        self.put("godot/scripts/new.gd", b"extends Node\n# changed\n")
        with self.assertRaisesRegex(ValueError, "Package files"):
            package.verify(self.root, used=True)

    def test_used_package_refuses_unexpected_executable_source(self):
        self.evaluation()
        self.put("godot/scripts/injected.gd", b"extends Node\n")
        with self.assertRaisesRegex(ValueError, "Package files"):
            package.verify(self.root, used=True)

    def test_missing_payload_is_not_an_import_exception(self):
        self.evaluation()
        (self.root / "Test It.cmd").unlink()
        with self.assertRaisesRegex(ValueError, "Package files"):
            package.verify(self.root, used=True)

    def test_rehashed_runner_still_must_match_committed_script(self):
        manifest = self.evaluation()
        self.put("Run-Camera-Stack.ps1", b"# substituted runner\n")
        manifest["files_sha256"] = package.inventory(self.root)
        package.write_json(self.root / package.MANIFEST, manifest)
        with self.assertRaisesRegex(ValueError, "exact Git source"):
            package.verify(self.root)

    def test_rehashed_reduced_plan_is_rejected(self):
        manifest = self.evaluation()
        reduced = package.test_plan()
        reduced["cases"] = reduced["cases"][:1]
        package.write_json(self.root / "Test-Plan.json", reduced)
        manifest["files_sha256"] = package.inventory(self.root)
        package.write_json(self.root / package.MANIFEST, manifest)
        with self.assertRaisesRegex(ValueError, "qualification plan"):
            package.verify(self.root)


if __name__ == "__main__":
    unittest.main()
