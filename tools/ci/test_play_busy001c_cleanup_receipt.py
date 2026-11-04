#!/usr/bin/env python3
"""Execute the actual runner's failure/finally path with explicit fake children.

These are orchestration controls, not graphical host or renderer evidence.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

from play_busy001c_process import CustodyError


def load_runner():
    policy = types.ModuleType('execution_policy')
    policy.godot_process_cleanup_seconds = lambda: 240
    monitor = types.ModuleType('godot_process_monitor')
    monitor.wait = None
    diagnostics = types.ModuleType('godot_timeout_diagnostics')
    diagnostics.stop_process_tree = None
    spec = importlib.util.spec_from_file_location(
        'busy001c_cleanup_runner_under_test', Path(__file__).with_name('run_play_busy001c_render.py'))
    module = importlib.util.module_from_spec(spec)
    with patch.dict(sys.modules, execution_policy=policy,
                    godot_process_monitor=monitor, godot_timeout_diagnostics=diagnostics):
        spec.loader.exec_module(module)
    return module


class CleanupReceiptTests(unittest.TestCase):
    def exercise(self, *, timed_out=True, timeout_kind='progress', live=True,
                 cleanup_fails=False, observation_fails=False):
        runner = load_runner()
        instances = []

        class Child:
            pid = 6164
            returncode = None

            def poll(self):
                return self.returncode

            def wait(self, timeout):
                if self.returncode is None:
                    raise AssertionError('fake monitor/stop must retire original launcher')
                return self.returncode

        child = Child()

        class Custody:
            def __init__(self, platform):
                self.live = live
                self.cleanup_calls = 0
                self.remaining_calls = 0
                self.closed = False
                self.observation_errors = []
                self.cleanup_termination_errors = {}
                self.observed_processes = {
                    '6164': {'pid': 6164, 'creation_time': 10, 'role': 'host'},
                    '7932': {'pid': 7932, 'creation_time': 11, 'role': 'host', 'parent_pid': 6164},
                }
                instances.append(self)

            def observe(self, pid):
                if pid != 6164:
                    raise AssertionError('launcher changed')

            def remaining(self):
                self.remaining_calls += 1
                if observation_fails and self.remaining_calls == 1:
                    self.observation_errors.append('inventory unavailable')
                    raise CustodyError('inventory unavailable')
                return {'7932': self.observed_processes['7932']} if self.live else {}

            def stop_remaining(self, timeout_seconds=3.0):
                self.cleanup_calls += 1
                if timeout_seconds != 3.0:
                    raise AssertionError('cleanup budget changed')
                self.cleanup_termination_errors['7932'] = {'creation_time': 11, 'error': 5}
                if cleanup_fails:
                    raise CustodyError('Owned processes remain after bounded failure cleanup')
                self.live = False
                return {'7932': self.observed_processes['7932']}

            def close(self):
                self.closed = True

        def spawn(command, log, environment):
            row = {'stage': 'display_ready', 'process_pid': 7932,
                   'process_nonce': environment['CYBERSAND_PLAY_BUSY_NONCE'],
                   'source_sha': environment['CYBERSAND_PLAY_BUSY_SOURCE_SHA']}
            log.write('PLAY_BUSY001C_PROGRESS ' + json.dumps(row) + '\n')
            log.flush()
            return child

        def wait(process, case, deadline, started, log, diagnostic, **kwargs):
            self.assertEqual(deadline, 120)
            self.assertEqual(case, 'play_busy001c_render')
            if not timed_out:
                child.returncode = 0
            return timed_out, timeout_kind if timed_out else None, None

        def stop(process):
            self.assertIs(process, child)
            child.returncode = -9

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in ['godot_console.exe', 'godot.exe', 'native.dll', 'rapier.dll']:
                (root/name).write_bytes(name.encode())
            out = root/'out'
            argv = ['run_play_busy001c_render.py', '--platform', 'windows',
                    '--source-sha', 'a'*40, '--godot', str(root/'godot_console.exe'),
                    '--runtime', str(root/'native.dll'), '--rapier', str(root/'rapier.dll'),
                    '--output', str(out)]
            with contextlib.ExitStack() as stack:
                stack.enter_context(patch.object(sys, 'argv', argv))
                stack.enter_context(patch.object(runner, 'sys', types.SimpleNamespace(platform='win32')))
                stack.enter_context(patch.dict(os.environ, CYBERSAND_PLAY_BUSY_RENDER_EVIDENCE=str(root/'frames')))
                stack.enter_context(patch.object(runner.subprocess, 'check_output', side_effect=['a'*40, 'b'*40]))
                stack.enter_context(patch.object(runner, 'ProcessCustody', Custody))
                spawn_mock = stack.enter_context(patch.object(runner, '_spawn_render_child', side_effect=spawn))
                wait_mock = stack.enter_context(patch.object(runner.monitor, 'wait', side_effect=wait))
                stack.enter_context(patch.object(runner.diagnostics, 'stop_process_tree', side_effect=stop))
                stack.enter_context(patch.object(runner, 'cache_inventory', return_value={'policy': 'observed-not-modified'}))
                stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
                result = runner.main()
            receipt = json.loads((out/'render-process.json').read_text())
            self.assertEqual(spawn_mock.call_count, 1)
            self.assertEqual(wait_mock.call_count, 1)
            self.assertEqual(receipt['budgets'], {'absolute_seconds': 120,
                             'progress_snapshot_seconds': 30, 'progress_fail_seconds': 45})
            self.assertEqual(receipt['parent_seconds'], 360)
            self.assertTrue(instances[0].closed)
            return result, receipt, instances[0]

    def test_progress_timeout_survives_successful_failure_cleanup(self):
        result, receipt, custody = self.exercise()
        self.assertEqual(result, 1)
        self.assertEqual(receipt['status'], 'failed')
        self.assertTrue(receipt['timed_out'])
        self.assertEqual(receipt['timeout_kind'], 'progress')
        self.assertTrue(receipt['forced_cleanup'])
        self.assertTrue(receipt['cleanup_complete'])
        self.assertEqual(receipt['cleanup_termination_errors']['7932']['error'], 5)
        self.assertEqual(custody.cleanup_calls, 1)

    def test_absolute_timeout_survives_successful_failure_cleanup(self):
        result, receipt, _ = self.exercise(timeout_kind='absolute')
        self.assertEqual(result, 1)
        self.assertTrue(receipt['timed_out'])
        self.assertEqual(receipt['timeout_kind'], 'absolute')
        self.assertTrue(receipt['cleanup_complete'])
        self.assertEqual(receipt['status'], 'failed')

    def test_failed_cleanup_does_not_restart_its_allowance(self):
        result, receipt, custody = self.exercise(cleanup_fails=True)
        self.assertEqual(result, 1)
        self.assertFalse(receipt['cleanup_complete'])
        self.assertTrue(receipt['timed_out'])
        self.assertIn('bounded failure cleanup', receipt['error'])
        self.assertEqual(custody.cleanup_calls, 1)

    def test_zero_exit_launcher_with_forced_descendant_cleanup_is_negative(self):
        result, receipt, custody = self.exercise(timed_out=False)
        self.assertEqual(result, 1)
        self.assertEqual(receipt['returncode'], 0)
        self.assertFalse(receipt['timed_out'])
        self.assertTrue(receipt['forced_cleanup'])
        self.assertEqual(receipt['status'], 'failed')
        self.assertEqual(custody.cleanup_calls, 1)

    def test_observation_failure_cannot_be_erased_by_later_cleanup(self):
        result, receipt, custody = self.exercise(observation_fails=True)
        self.assertEqual(result, 1)
        self.assertFalse(receipt['cleanup_complete'])
        self.assertIn('inventory unavailable', receipt['error'])
        self.assertEqual(receipt['observation_errors'], ['inventory unavailable'])
        self.assertEqual(custody.cleanup_calls, 1)

    def test_natural_zero_exit_control_needs_no_failure_cleanup(self):
        result, receipt, custody = self.exercise(timed_out=False, live=False)
        self.assertEqual(result, 0)  # Runner control only, not 001C acceptance.
        self.assertEqual(receipt['status'], 'completed')
        self.assertFalse(receipt['forced_cleanup'])
        self.assertFalse(receipt['timed_out'])
        self.assertTrue(receipt['cleanup_complete'])
        self.assertEqual(custody.cleanup_calls, 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
