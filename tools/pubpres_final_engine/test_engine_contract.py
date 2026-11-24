#!/usr/bin/env python3
import json
from pathlib import Path
import tempfile
import unittest

import engine_contract as contract


class EngineContractTests(unittest.TestCase):
    def stage(self, folder: Path) -> None:
        for relative in (contract.FROZEN_BUILDER, "third_party/workbench-godot.lock.json",
                         "third_party/patches/godot-egl-current-window.patch",
                         contract.DIRECTORY + "/build_engine.py", contract.DIRECTORY + "/engine.lock.json",
                         contract.DIRECTORY + "/godot-font-image-snapshot.patch"):
            target = folder / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((contract.ROOT / relative).read_bytes())

    def test_declared_build_preserves_original_gates_and_dependencies(self):
        result = contract.validate_derivation()
        self.assertEqual(result["source_commit"], "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88")
        self.assertEqual(len(result["patches"]), 2)
        self.assertEqual(set(result["patches"][1]["files"]), set(contract.FONT_SOURCES))

    def test_refuses_api_gate_relaxation_and_changed_base_builder(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.stage(root)
            path = root / contract.DIRECTORY / "build_engine.py"
            original = path.read_bytes()
            path.write_bytes(original.replace(b"require(same and interface_same,", b"require(same or interface_same,"))
            with self.assertRaises(ValueError): contract.validate_derivation(root)
            path.write_bytes(original)
            base = root / contract.FROZEN_BUILDER
            base.write_bytes(base.read_bytes() + b"\n# changed predecessor\n")
            with self.assertRaises(ValueError): contract.validate_derivation(root)

    def test_refuses_dependency_flag_identity_and_patch_drift(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.stage(root)
            path = root / contract.DIRECTORY / "engine.lock.json"
            original = path.read_bytes()
            for key in ("version", "source_commit", "scons_flags", "angle", "patches"):
                value = json.loads(original)
                value[key] = None
                path.write_text(json.dumps(value))
                with self.assertRaises(ValueError): contract.validate_derivation(root)
            path.write_bytes(original)
            font = root / contract.DIRECTORY / "godot-font-image-snapshot.patch"
            font.write_bytes(font.read_bytes() + b"\n")
            with self.assertRaises(ValueError): contract.validate_derivation(root)

    def test_new_repair_cannot_be_mislabelled_original_engine(self):
        original = json.loads((contract.ROOT / "third_party/workbench-godot.lock.json").read_bytes())
        new = contract.expected_lock(original)
        self.assertNotEqual(new["version"], original["version"])
        self.assertNotEqual(new["build_name"], original["build_name"])
        self.assertEqual(new["patches"][:1], original["patches"])
        self.assertEqual(new["scons_flags"], original["scons_flags"])
        for name in ("angle", "scons", "accesskit", "official_reference"):
            self.assertEqual(new[name], original[name])


if __name__ == "__main__":
    unittest.main()
