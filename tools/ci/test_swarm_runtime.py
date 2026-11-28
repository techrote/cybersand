"""Retained executable/source mismatches must fail without running generation."""
import json
from pathlib import Path
import struct
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import check_swarm_runtime as subject


class SwarmRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in (*subject.EXTRA, "native/experiments/gentek_swarm/core.cpp",
                     "native/experiments/gentek_swarm/core.hpp"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("// exact test input\n")
        definition, inputs = subject.definition_inputs(self.root)
        protocol = self.root / "godot/scripts/workbench_reciprocal_protocol.gd"
        protocol.parent.mkdir(parents=True)
        protocol.write_text(f'const NATIVE_DEFINITION := "{definition}"\n')
        self.payloads, self.manifests = {}, {}
        for platform, name in subject.ARTIFACTS.items():
            data = bytearray(128)
            if platform == "linux":
                data[:6] = b"\x7fELF\x02\x01"
                struct.pack_into("<H", data, 18, 62)
            else:
                data[:2] = b"MZ"
                struct.pack_into("<I", data, 0x3c, 64)
                data[64:70] = b"PE\0\0\x64\x86"
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            path.chmod(0o755)
            self.payloads[platform] = path
            self.manifests[platform] = self.root / f"godot/tools/swarm004-runtime.{platform}.json"
            self.manifests[platform].write_text(json.dumps({"schema": 1, "programme": subject.PROGRAMME,
                "platform": platform, "artifact": name, "source": "a" * 40,
                "sha256": subject.sha(data), "bytes": len(data), "native_definition_sha256": definition,
                "native_definition_inputs_sha256": inputs}))

    def test_exact_payloads_and_pointer_materialization_are_distinct(self):
        self.assertEqual(subject.check(self.root, True)["status"], "passed")
        data = self.payloads["linux"].read_bytes()
        self.payloads["linux"].write_text("version https://git-lfs.github.com/spec/v1\noid sha256:" +
            subject.sha(data) + "\nsize " + str(len(data)) + "\n")
        self.assertEqual(subject.check(self.root)["status"], "passed")
        self.assertIn("not materialized", " ".join(subject.check(self.root, True)["errors"]))

    def test_changed_source_requires_new_binary_binding(self):
        (self.root / subject.EXTRA[0]).write_text("// changed native source\n")
        errors = " ".join(subject.check(self.root)["errors"])
        self.assertIn("admission pin", errors)
        self.assertIn("requires rebuild", errors)

    def test_truncated_inventory_cannot_attest_current_definition(self):
        path = self.manifests["windows"]
        value = json.loads(path.read_text())
        value["native_definition_inputs_sha256"].pop(subject.EXTRA[0])
        path.write_text(json.dumps(value))
        self.assertIn("requires rebuild", " ".join(subject.check(self.root)["errors"]))

    def test_changed_binary_and_foreign_target_are_rejected(self):
        self.payloads["windows"].write_bytes(self.payloads["windows"].read_bytes() + b"tamper")
        self.assertIn("bytes/target", " ".join(subject.check(self.root)["errors"]))

    def test_false_types_source_and_artifact_are_refused(self):
        path = self.manifests["linux"]
        original = json.loads(path.read_text())
        for field, bad in (("schema", True), ("bytes", True), ("source", "latest"),
                           ("artifact", "../foreign"), ("platform", "windows")):
            with self.subTest(field=field):
                path.write_text(json.dumps(dict(original, **{field: bad})))
                self.assertIn("malformed or foreign", " ".join(subject.check(self.root)["errors"]))

    def test_missing_binding_and_linux_execute_permission_are_refused(self):
        self.manifests["windows"].unlink()
        self.payloads["linux"].chmod(0o644)
        errors = " ".join(subject.check(self.root)["errors"])
        if subject.os.name != "nt":
            self.assertIn("execute permission", errors)
        self.assertIn("SWARM windows", errors)

    def test_windows_host_does_not_require_unix_mode_bits(self):
        self.payloads["linux"].chmod(0o644)
        with patch.object(subject, "os", SimpleNamespace(name="nt")):
            self.assertEqual(subject.check(self.root, True)["status"], "passed")


if __name__ == "__main__":
    unittest.main()
