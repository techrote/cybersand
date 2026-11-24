"""Packaging guard unit controls. No Windows execution is simulated as proof."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import package_evaluator as package


class PackageGuards(unittest.TestCase):
    def make_payload(self, directory):
        root = Path(directory)
        (root / "godot").mkdir()
        source = root / "godot/project.godot"
        source.write_text("; artificial package guard fixture\n", encoding="utf-8")
        manifest = {"schema": package.SCHEMA, "source_commit": "1" * 40, "source_tree": "2" * 40,
                    "files_sha256": {"godot/project.godot": package.sha(source)}, "provenance": {}}
        (root / package.MANIFEST).write_text(json.dumps(manifest), encoding="utf-8")
        return root, manifest

    def test_complete_payload_identity_is_not_windows_qualification(self):
        with tempfile.TemporaryDirectory() as directory:
            root, _ = self.make_payload(directory)
            result = package.verify_extracted(root)
            self.assertTrue(result["payload_verified"])
            self.assertFalse(result["qualified"])

    def test_changed_or_missing_payload_rejects(self):
        with tempfile.TemporaryDirectory() as directory:
            root, _ = self.make_payload(directory)
            (root / "godot/project.godot").write_text("changed", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                package.verify_extracted(root)
            (root / "godot/project.godot").unlink()
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                package.verify_extracted(root)

    def test_relative_member_boundary(self):
        self.assertTrue(package.safe_relative("godot/goblin/goblin.tscn"))
        for value in ("../other", "/absolute", "C:/other", "a\\b", "a/../b", "a//b", "a/./b", ""):
            self.assertFalse(package.safe_relative(value), value)

    def test_symlink_payload_is_not_packaged_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root, _ = self.make_payload(directory)
            try:
                (root / "link").symlink_to(root / "godot", target_is_directory=True)
            except OSError:
                self.skipTest("host does not permit symlink test fixture")
            with self.assertRaises(ValueError):
                package.checked_member(root, "link")

    def test_no_qualification_from_header_only_or_wrong_platform(self):
        with tempfile.TemporaryDirectory() as directory:
            root, manifest = self.make_payload(directory)
            report = {"schema": "cybersand-goblin-package-selftest-v1", "status": "pass", "platform": "Linux",
                      "manifest_sha256": package.sha(root / package.MANIFEST), "source_commit": manifest["source_commit"],
                      "source_tree": manifest["source_tree"], "cases": []}
            output = root / "unit-report.json"
            output.write_text(json.dumps(report), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "did not pass"):
                package.verify_extracted(root, output)
            report["platform"] = "Windows"
            output.write_text(json.dumps(report), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Complete actor-workshop"):
                package.verify_extracted(root, output)
            report["manifest_sha256"] = "0" * 64
            output.write_text(json.dumps(report), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "different package"):
                package.verify_extracted(root, output)

    def test_existing_pin_is_consumed_without_new_engine_version(self):
        pins = package.windows_pin()
        self.assertEqual(pins["GODOT_VERSION"], "4.7.stable.official.5b4e0cb0f")
        self.assertEqual(len(pins["GODOT_SHA512"]), 128)

    def test_dirty_source_cannot_be_packaged(self):
        with patch.object(package, "git", return_value=" M godot/script.gd"):
            with self.assertRaisesRegex(ValueError, "clean committed"):
                package.build(Path("unused.zip"), Path("unused"), Path("unused"), Path("unused-output.zip"))

    def test_native_source_and_materialized_bytes_are_required(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            common = root / "native-input.cpp"
            # Match the retained source-manifest contract on every host. This
            # artificial CRLF fixture verifies canonical LF hashing explicitly.
            common.write_bytes(b"// original source\r\n")
            expected = hashlib.sha256(common.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
            for name, relative in (("native", "godot/addons/cybersand_native/runtime-provenance.json"),
                                   ("rapier", "godot/addons/godot-rapier2d/runtime-provenance.windows.json")):
                artifact = root / (name + ".dll")
                artifact.write_bytes(b"unit fixture, not executable")
                target = root / relative
                target.parent.mkdir(parents=True)
                target.write_text(json.dumps({"artifact": artifact.name, "sha256": package.sha(artifact),
                    "size": artifact.stat().st_size, "source_inputs": {common.name: expected}, "build_commit": "1" * 40}), encoding="utf-8")
            with patch.object(package, "ROOT", root):
                _, sources = package.runtime_inputs()
                self.assertEqual(sources, {common.name: expected})
                common.write_text("// changed\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "source drift"):
                    package.runtime_inputs()


if __name__ == "__main__":
    unittest.main()
