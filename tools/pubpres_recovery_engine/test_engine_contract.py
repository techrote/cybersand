import json
from pathlib import Path
import tempfile
import unittest

import engine_contract as contract


class EngineContract(unittest.TestCase):
    def stage(self, root):
        names = set(contract.LEGACY_INPUTS)
        names.update(path.relative_to(contract.ROOT).as_posix() for path in
                     (contract.ROOT / contract.DIRECTORY).iterdir() if path.is_file())
        for name in names:
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((contract.ROOT / name).read_bytes())

    def test_only_fourth_patch_and_declared_identity_change(self):
        proof = contract.validate_derivation()
        self.assertEqual(len(proof["patches"]), 4)
        previous = json.loads((contract.ROOT / contract.BOUNDED_DIRECTORY / "engine.lock.json").read_bytes())
        current = json.loads((contract.ROOT / contract.DIRECTORY / "engine.lock.json").read_bytes())
        self.assertEqual(current["patches"][:3], previous["patches"])
        for key in ("scons", "angle", "accesskit", "official_reference", "scons_flags", "source_commit"):
            self.assertEqual(current[key], previous[key])
        self.assertEqual(current["build_name"], "cybersand_egl_font_atomic")

    def test_builder_reader_helper_predecessor_and_patch_drift_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.stage(root)
            paths = [contract.DIRECTORY + "/" + name for name in
                     ("build_engine.py", "payload.py", "admission_clock.h", "godot-atomic-submission.patch", "godot-final-source.patch")]
            paths += [contract.BOUNDED_DIRECTORY + "/engine_contract.py", "tools/pubpres_final_engine/engine_contract.py"]
            for name in paths:
                path = root / name; original = path.read_bytes()
                path.write_bytes(original + b"\n# invalid drift\n")
                with self.subTest(name=name), self.assertRaises(ValueError): contract.validate_derivation(root)
                path.write_bytes(original)

    def test_no_compiler_dependency_abi_or_source_relaxation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); self.stage(root)
            path = root / contract.DIRECTORY / "engine.lock.json"; original = path.read_bytes()
            for name in ("version", "build_name", "source_commit", "scons_flags", "angle", "patches"):
                altered = json.loads(original); altered[name] = None
                path.write_text(json.dumps(altered))
                with self.subTest(name=name), self.assertRaises(ValueError): contract.validate_derivation(root)
            path.write_bytes(original)


if __name__ == "__main__": unittest.main()
