"""Standalone GEN-007 payload: real canonical profiles, no checkout dependency."""
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from package_explore001_candidate import stage_generator_profiles, stage_vc_runtime, verify_vc_runtime


class Profiles(unittest.TestCase):
    def test_canonical_payload_and_missing_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary)
            with self.assertRaisesRegex(ValueError, "missing required"):
                stage_generator_profiles(package)
            shutil.copytree(ROOT / "examples/worldgen", package / "examples/worldgen")
            inventory = stage_generator_profiles(package)
            canonical = sorted((ROOT / "examples/worldgen").glob("*.json"))
            self.assertEqual(set(inventory), {p.name for p in canonical})
            self.assertGreaterEqual(len(inventory), 2)
            shutil.rmtree(package / "examples")
            self.assertFalse((package / ".git").exists())
            for profile in canonical:
                installed = package / "godot/authoring/worldgen" / profile.name
                self.assertEqual(profile.read_bytes(), installed.read_bytes())
                self.assertEqual(inventory[profile.name], hashlib.sha256(installed.read_bytes()).hexdigest())

    def test_broken_required_recipe_fails_packaging(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary)
            shutil.copytree(ROOT / "examples/worldgen", package / "examples/worldgen")
            (package / "examples/worldgen/gen007-deepworks.json").write_text("[]")
            with self.assertRaisesRegex(ValueError, "Invalid or oversized"):
                stage_generator_profiles(package)


class WindowsRuntime(unittest.TestCase):
    def stage(self, directory, machine=0x8664):
        # Synthetic bytes test packaging integrity only. Actual Microsoft
        # Authenticode and process-module resolution are Windows hosted gates.
        runtime = bytearray(256)
        runtime[:2] = b"MZ"
        struct.pack_into("<I", runtime, 0x3c, 128)
        runtime[128:132] = b"PE\x00\x00"
        struct.pack_into("<H", runtime, 132, machine)
        (directory / "vcruntime140.dll").write_bytes(runtime)
        for name in ("Microsoft-Visual-C-Runtime-LICENSE.docx", "Microsoft-Visual-Studio-2022-LICENSE.docx"):
            (directory / name).write_bytes(b"synthetic licence integrity fixture")
        provenance = {"schema": 1, "files_sha256": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.iterdir()}}
        (directory / "vc-runtime-provenance.json").write_text(json.dumps(provenance))
        return provenance

    def test_runtime_and_licences_survive_staging(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, package = root / "source", root / "package"
            source.mkdir()
            package.mkdir()
            original = self.stage(source)
            self.assertEqual(stage_vc_runtime(source, package), original["files_sha256"]["vcruntime140.dll"])
            self.assertEqual(verify_vc_runtime(package), original)
            self.assertEqual({p.name for p in source.iterdir()}, {p.name for p in package.iterdir()})

    def test_missing_and_changed_runtime_are_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            self.stage(source)
            runtime = source / "vcruntime140.dll"
            runtime.write_bytes(b"changed runtime")
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                verify_vc_runtime(source)
            runtime.unlink()
            with self.assertRaises(FileNotFoundError):
                verify_vc_runtime(source)

    def test_missing_licence_identity_and_wrong_architecture_are_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            identity = self.stage(source, machine=0x14c)
            with self.assertRaisesRegex(ValueError, "not x64"):
                verify_vc_runtime(source)
            del identity["files_sha256"]["Microsoft-Visual-Studio-2022-LICENSE.docx"]
            (source / "vc-runtime-provenance.json").write_text(json.dumps(identity))
            with self.assertRaisesRegex(ValueError, "both applicable licences"):
                verify_vc_runtime(source)


if __name__ == "__main__":
    unittest.main()
