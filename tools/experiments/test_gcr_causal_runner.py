"""Authenticate control reuse and contain only the test-owned process tree."""
import csv
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import run_gcr_causal as runner


class RetainedControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.folder = self.root / 'evidence'
        (self.folder / 'windows').mkdir(parents=True)
        self.old = {'godot/scripts/physical_actor_arena.gd': 'unchanged', 'godot/project.godot': 'unchanged'}
        self.inputs = dict(self.old, **{'godot/qualification/gcr_causal_arena.gd': 'new'})
        self.runtime = {'native_sha256': 'n', 'native_source_inputs': {'native/src/world.cpp': 'w'},
                        'rapier_sha256': 'r', 'engine_sha256': 'e', 'engine_version': 'v'}
        runner.write(self.folder / 'identity.json', {'source': '1' * 40, 'source_inputs': self.old,
                                                    'platforms': {'windows': self.runtime}})
        self.log = self.folder / 'windows/test_gcr_rest_bridge.log'
        self.log.write_text('Retained successful real-host output\n')
        self.row = {'test': 'test_gcr_rest_bridge', 'ok': True, 'exit': 0, 'log_sha256': runner.sha(self.log)}
        runner.write(self.folder / 'windows/gates.json', [self.row])
        protocol = self.root / 'docs/audits/gcr001-2026-11-01/protocol.json'
        protocol.parent.mkdir(parents=True)
        protocol.write_bytes(b'registered\n')
        self.root_patch = patch.object(runner, 'ROOT', self.root)
        self.git_patch = patch.object(runner, 'git', return_value=b'registered\n')
        self.root_patch.start()
        self.git_patch.start()

    def tearDown(self):
        self.git_patch.stop()
        self.root_patch.stop()
        self.temp.cleanup()

    def reuse(self, inputs=None, runtime=None):
        return runner.retained_controls(self.folder, 'windows', inputs or self.inputs, runtime or self.runtime)

    def test_new_non_autoload_apparatus_keeps_original_execution_source(self):
        self.assertEqual(self.reuse()['test_gcr_rest_bridge']['executed_source'], '1' * 40)

    def test_changed_existing_physics_source_refuses(self):
        changed = dict(self.inputs, **{'godot/scripts/physical_actor_arena.gd': 'changed'})
        with self.assertRaisesRegex(RuntimeError, 'source changed'):
            self.reuse(inputs=changed)

    def test_changed_autoload_configuration_refuses(self):
        changed = dict(self.inputs, **{'godot/project.godot': 'changed'})
        with self.assertRaisesRegex(RuntimeError, 'source changed'):
            self.reuse(inputs=changed)

    def test_unregistered_added_executable_refuses(self):
        changed = dict(self.inputs, **{'godot/scripts/extra_owner.gd': 'new'})
        with self.assertRaisesRegex(RuntimeError, 'source changed'):
            self.reuse(inputs=changed)

    def test_changed_runtime_refuses(self):
        with self.assertRaisesRegex(RuntimeError, 'runtime changed'):
            self.reuse(runtime=dict(self.runtime, native_sha256='different'))

    def test_changed_original_log_refuses(self):
        self.log.write_text('different\n')
        with self.assertRaisesRegex(RuntimeError, 'log differs'):
            self.reuse()

    def test_failed_control_is_not_reused(self):
        runner.write(self.folder / 'windows/gates.json', [dict(self.row, ok=False, exit=1)])
        self.assertEqual(self.reuse(), {})

    def test_new_causal_gate_is_never_inherited(self):
        runner.write(self.folder / 'windows/gates.json', [dict(self.row, test='test_gcr_causal_arena')])
        self.assertEqual(self.reuse(), {})


class OwnedProcess(unittest.TestCase):
    @unittest.skipUnless(os.name == 'nt', 'Actual Windows-owned tree watchdog')
    def test_timeout_terminates_the_spawned_parent_and_child(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            script = root / 'owned_parent.py'
            script.write_text('import subprocess,sys,time\n'
                              'p=subprocess.Popen([sys.executable,"-c","import time;time.sleep(120)"])\n'
                              'print(p.pid,flush=True)\n'
                              'time.sleep(120)\n')
            log = root / 'owned.log'
            result = runner.run([sys.executable, str(script)], log, 2, dict(os.environ), 'windows', '')
            self.assertEqual(result['exit'], 124)
            self.assertTrue(result['timed_out'])
            self.assertFalse(result['ok'])
            child = int(log.read_text(encoding='utf-8').splitlines()[0])
            output = subprocess.check_output(['tasklist', '/FI', f'PID eq {child}', '/FO', 'CSV', '/NH'],
                                             text=True, creationflags=subprocess.CREATE_NO_WINDOW, timeout=30)
            rows = list(csv.reader(io.StringIO(output)))
            self.assertFalse(any(len(row) > 1 and row[1] == str(child) for row in rows))


class PopulationReceipt(unittest.TestCase):
    def setUp(self):
        self.protocols = {lane: (None, {'cases': [{'id': str(i)} for i in range(n)]}, None)
                          for lane, n in [('timing', 12), ('event', 8)]}

    def test_only_all_forty_is_complete_registered_population(self):
        r = runner.population_receipt(['timing', 'event'], ['windows', 'linux'], self.protocols, 40)
        self.assertTrue(r['complete_registered_population'])
        self.assertEqual(r['planned_captures'], 40)

    def test_single_lane_is_explicit_selected_completion(self):
        r = runner.population_receipt(['timing'], ['windows', 'linux'], self.protocols, 24)
        self.assertTrue(r['complete_selected_lanes'])
        self.assertFalse(r['complete_registered_population'])

    def test_incomplete_and_gates_only_are_not_primary_completion(self):
        for done, gates in [(39, False), (0, True)]:
            r = runner.population_receipt(['timing', 'event'], ['windows', 'linux'], self.protocols, done, gates_only=gates)
            self.assertFalse(r['complete_registered_population'])

    def test_single_case_cannot_claim_registered_completion(self):
        r = runner.population_receipt(['timing'], ['windows', 'linux'], self.protocols, 2, selected_case='0')
        self.assertEqual(r['planned_captures'], 2)
        self.assertFalse(r['complete_selected_lanes'])


if __name__ == '__main__':
    unittest.main()
