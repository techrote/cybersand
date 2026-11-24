#!/usr/bin/env python3
import json
from pathlib import Path
import tempfile
import unittest
import engine_contract as contract


class EngineContractTests(unittest.TestCase):
    def stage(self, root):
        names = set(contract.LEGACY_INPUTS)
        names.update(path.relative_to(contract.ROOT).as_posix() for path in
                     (contract.ROOT / contract.DIRECTORY).iterdir() if path.is_file())
        for name in names:
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((contract.ROOT / name).read_bytes())

    def test_exact_derivation_retains_every_predecessor_gate(self):
        proof = contract.validate_derivation()
        self.assertEqual(len(proof['patches']), 3)
        self.assertEqual(set(proof['patches'][-1]['files']), set(contract.PATCH_SOURCES))
        font = json.loads((contract.ROOT / contract.FONT_DIRECTORY / 'engine.lock.json').read_bytes())
        current = json.loads((contract.ROOT / contract.DIRECTORY / 'engine.lock.json').read_bytes())
        self.assertEqual(current['patches'][:2], font['patches'])
        for key in ('scons', 'angle', 'accesskit', 'official_reference', 'scons_flags', 'source_commit'):
            self.assertEqual(current[key], font[key])
        self.assertNotEqual(current['version'], font['version'])

    def test_builder_reader_header_and_frozen_predecessor_mutations_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.stage(root)
            for name in ('build_engine.py', 'payload.py', 'cybersand_frame_budget.h', 'godot-bounded-main-turns.patch'):
                path = root / contract.DIRECTORY / name
                original = path.read_bytes()
                path.write_bytes(original + b'\n# drift\n')
                with self.subTest(name=name), self.assertRaises(ValueError): contract.validate_derivation(root)
                path.write_bytes(original)
            path = root / contract.FONT_DIRECTORY / 'engine_contract.py'
            path.write_bytes(path.read_bytes() + b'\n# drift\n')
            with self.assertRaises(ValueError): contract.validate_derivation(root)

    def test_identity_source_compiler_flags_or_dependency_drift_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.stage(root)
            path = root / contract.DIRECTORY / 'engine.lock.json'
            original = path.read_bytes()
            for name in ('version', 'build_name', 'source_commit', 'scons_flags', 'angle', 'patches'):
                altered = json.loads(original)
                altered[name] = None
                path.write_text(json.dumps(altered))
                with self.subTest(name=name), self.assertRaises(ValueError): contract.validate_derivation(root)
            path.write_bytes(original)


if __name__ == '__main__':
    unittest.main()
