"""Refuse unauthenticated reuse of otherwise unchanged actual host gates."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import run_gcr_creep as runner


class GateReuse(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.folder = self.root / 'old'
        (self.folder / 'windows').mkdir(parents=True)
        self.inputs = {'godot/scripts/rapier_physics_bridge.gd': 'unchanged',
                       'godot/qualification/gcr_creep_capture.gd': 'new-capture',
                       'godot/tests/test_gcr_creep_capture.gd': 'new-test'}
        old = dict(self.inputs)
        old['godot/qualification/gcr_creep_capture.gd'] = 'old-capture'
        old['godot/tests/test_gcr_creep_capture.gd'] = 'old-test'
        self.runtime = dict(native_sha256='n', native_source_inputs={'native/src/world.cpp': 'same'},
                            rapier_sha256='r', engine_sha256='e', engine_version='v')
        self.identity = {'source': '1' * 40, 'source_inputs': old, 'platforms': {'windows': self.runtime}}
        runner.write(self.folder / 'identity.json', self.identity)
        protocol = self.root / 'docs/audits/gcr001-2026-11-01/protocol.json'
        protocol.parent.mkdir(parents=True)
        protocol.write_text('registered\n')
        self.log = self.folder / 'windows/test_gcr_rest_bridge.log'
        self.log.write_text('actual retained successful host output\n')
        self.row = {'test': 'test_gcr_rest_bridge', 'ok': True, 'exit': 0,
                    'log_sha256': runner.sha(self.log)}
        runner.write(self.folder / 'windows/gates.json', [self.row])
        self.root_patch = patch.object(runner, 'ROOT', self.root)
        self.git_patch = patch.object(runner, 'git', return_value=b'registered\n')
        self.root_patch.start()
        self.git_patch.start()

    def tearDown(self):
        self.git_patch.stop()
        self.root_patch.stop()
        self.temp.cleanup()

    def reuse(self, inputs=None, runtime=None):
        return runner.reusable_gates(self.folder, 'windows', inputs or self.inputs, runtime or self.runtime)

    def test_changed_capture_does_not_repeat_unchanged_control(self):
        result = self.reuse()
        self.assertEqual(set(result), {'test_gcr_rest_bridge'})
        self.assertEqual(result['test_gcr_rest_bridge']['executed_source'], '1' * 40)

    def test_changed_shared_source_refuses(self):
        changed = dict(self.inputs, **{'godot/scripts/rapier_physics_bridge.gd': 'changed'})
        with self.assertRaisesRegex(RuntimeError, 'inputs changed'):
            self.reuse(inputs=changed)

    def test_changed_runtime_refuses(self):
        changed = dict(self.runtime, native_sha256='changed')
        with self.assertRaisesRegex(RuntimeError, 'runtime changed'):
            self.reuse(runtime=changed)

    def test_changed_original_log_refuses(self):
        self.log.write_text('different\n')
        with self.assertRaisesRegex(RuntimeError, 'bytes/exit changed'):
            self.reuse()

    def test_changed_legacy_protocol_refuses(self):
        (self.root / 'docs/audits/gcr001-2026-11-01/protocol.json').write_text('changed\n')
        with self.assertRaisesRegex(RuntimeError, 'protocol changed'):
            self.reuse()

    def test_appartus_gate_is_never_inherited(self):
        row = dict(self.row, test='test_gcr_creep_capture')
        runner.write(self.folder / 'windows/gates.json', [row])
        self.assertEqual(self.reuse(), {})

    def test_original_executed_source_survives_chained_reuse(self):
        original = self.root / 'original.log'
        original.write_bytes(self.log.read_bytes())
        self.log.unlink()
        row = dict(self.row, inherited_from=str(original), executed_source='2' * 40)
        runner.write(self.folder / 'windows/gates.json', [row])
        self.assertEqual(self.reuse()['test_gcr_rest_bridge']['executed_source'], '2' * 40)


if __name__ == '__main__':
    unittest.main()
