#!/usr/bin/env python3
"""Win32 cleanup controls. Fake-kernel tests are portable; native cases require Windows.

No Godot, native compilation, graphics, cache changes or full-host dispatch.
"""
from __future__ import annotations

import os
import subprocess
import sys
import time
import unittest
from unittest.mock import patch

import play_busy001c_process as custody_module
from play_busy001c_process import CustodyError, ProcessCustody, _Windows


class Clock:
    def __init__(self):
        self.now = 0.0
        self.sleeps = []

    def sleep(self, seconds):
        if seconds < 0:
            raise AssertionError('negative sleep')
        self.sleeps.append(seconds)
        self.now += seconds


class Kernel:
    """Models retained objects; successful queries intentionally overwrite last-error."""
    def __init__(self, clock, *, result=0, error=5, retire_at=0.05, pid=10001):
        self.clock, self.result, self.error = clock, result, error
        self.retire_at, self.pid = retire_at, pid
        self.created = 100
        self.handle = 0x1234
        self.last_error = 0
        self.calls = []
        self.wait_failure = False
        self.wait_value = None

    def GetProcessTimes(self, handle, created, exited, kernel, user):
        self.calls.append(('times', handle))
        if handle != self.handle:
            raise AssertionError('identity reopened or handle substituted')
        created._obj.low = self.created
        created._obj.high = 0
        self.last_error = 998  # Must not replace the TerminateProcess error.
        return 1

    def WaitForSingleObject(self, handle, timeout):
        self.calls.append(('wait', handle, timeout))
        if handle != self.handle or timeout != 0:
            raise AssertionError('poll must use the same retained handle without a new budget')
        self.last_error = 77 if self.wait_failure else 999
        if self.wait_failure:
            return 0xFFFFFFFF
        if self.wait_value is not None:
            return self.wait_value
        return 0 if self.clock.now >= self.retire_at else 258

    def TerminateProcess(self, handle, code):
        self.calls.append(('terminate', handle, code))
        self.last_error = self.error
        return self.result

    def CloseHandle(self, handle):
        self.calls.append(('close', handle))
        return 1

    def error_value(self):
        self.calls.append(('get_last_error', self.last_error))
        return self.last_error


class WindowsCleanupTests(unittest.TestCase):
    def setup_kernel(self, **kwargs):
        clock = Clock()
        kernel = Kernel(clock, **kwargs)
        backend = object.__new__(_Windows)
        backend.kernel = kernel
        backend.handles = {kernel.pid: kernel.handle}
        backend.table = lambda: {kernel.pid: {'pid': kernel.pid, 'parent_pid': os.getpid()}}
        self.enterContext(patch.object(custody_module.C, 'get_last_error', kernel.error_value, create=True))
        self.enterContext(patch.object(custody_module.time, 'monotonic', lambda: clock.now))
        self.enterContext(patch.object(custody_module.time, 'sleep', clock.sleep))
        custody = ProcessCustody('windows', _backend=backend)
        self.addCleanup(custody.close)
        custody.observe(kernel.pid)
        return custody, backend, kernel, clock

    def test_error_is_captured_before_any_followup_win32_call(self):
        custody, backend, kernel, _ = self.setup_kernel()
        kernel.calls.clear()
        error = backend.terminate(custody._observed[kernel.pid])
        self.assertEqual(error, 5)
        self.assertEqual(kernel.calls[-2:], [('terminate', kernel.handle, 1), ('get_last_error', 5)])

    def test_error5_then_retirement_uses_existing_allowance(self):
        custody, backend, kernel, clock = self.setup_kernel(retire_at=0.05)
        attempted = custody.stop_remaining()
        self.assertEqual(set(attempted), {str(kernel.pid)})
        self.assertEqual(custody.remaining(), {})
        self.assertGreaterEqual(clock.now, 0.05)
        self.assertLessEqual(clock.now, 3.0)
        self.assertEqual(custody.cleanup_termination_errors[str(kernel.pid)],
                         {'creation_time': 100, 'error': 5})
        self.assertEqual(sum(call[0] == 'terminate' for call in kernel.calls), 1)
        self.assertTrue(all(call[1] == kernel.handle for call in kernel.calls if call[0] == 'wait'))

    def test_error5_persistent_nonsignaling_is_not_clean(self):
        custody, _, kernel, clock = self.setup_kernel(retire_at=float('inf'))
        with self.assertRaisesRegex(CustodyError, "bounded failure cleanup.*'error': 5"):
            custody.stop_remaining()
        self.assertAlmostEqual(clock.now, 3.0)
        self.assertEqual(sum(call[0] == 'terminate' for call in kernel.calls), 1)
        self.assertTrue(custody.remaining())

    def test_successful_async_request_still_requires_signaling(self):
        custody, _, kernel, clock = self.setup_kernel(result=1, retire_at=0.08)
        custody.stop_remaining()
        self.assertGreaterEqual(clock.now, 0.08)
        self.assertEqual(sum(call[0] == 'terminate' for call in kernel.calls), 1)
        self.assertEqual(custody.cleanup_termination_errors, {})

    def test_successful_request_without_retirement_still_times_out(self):
        custody, _, kernel, clock = self.setup_kernel(result=1, retire_at=float('inf'))
        with self.assertRaisesRegex(CustodyError, 'bounded failure cleanup'):
            custody.stop_remaining(timeout_seconds=0.025)
        self.assertAlmostEqual(clock.now, 0.025)
        self.assertEqual(sum(call[0] == 'terminate' for call in kernel.calls), 1)
        self.assertLessEqual(max(clock.sleeps), 0.01)

    def test_last_error_is_not_overwritten_by_subsequent_observation(self):
        custody, _, _, _ = self.setup_kernel(error=123, retire_at=0.03)
        custody.stop_remaining()
        self.assertEqual(custody.cleanup_termination_errors['10001']['error'], 123)

    def test_already_signaled_never_terminates(self):
        custody, backend, kernel, _ = self.setup_kernel(retire_at=0)
        self.assertIsNone(backend.terminate(custody._observed[kernel.pid]))
        self.assertEqual(custody.stop_remaining(), {})
        self.assertFalse(any(call[0] == 'terminate' for call in kernel.calls))

    def test_identity_mismatch_cannot_terminate_reused_pid(self):
        custody, backend, kernel, _ = self.setup_kernel()
        kernel.created = 200
        self.assertIsNone(backend.terminate(custody._observed[kernel.pid]))
        self.assertFalse(any(call[0] == 'terminate' for call in kernel.calls))

    def test_wait_failed_captures_its_own_error_and_fails_closed(self):
        custody, backend, kernel, _ = self.setup_kernel()
        kernel.wait_failure = True
        with self.assertRaisesRegex(CustodyError, 'WAIT_FAILED, error=77'):
            backend.alive(custody._observed[kernel.pid])
        self.assertEqual(kernel.calls[-2:], [('wait', kernel.handle, 0), ('get_last_error', 77)])
        with self.assertRaisesRegex(CustodyError, 'WAIT_FAILED'):
            custody.stop_remaining()
        self.assertTrue(custody.observation_errors)

    def test_unexpected_wait_result_is_not_retirement(self):
        custody, backend, kernel, _ = self.setup_kernel()
        kernel.wait_value = 128  # WAIT_ABANDONED is not valid process retirement.
        with self.assertRaisesRegex(CustodyError, 'retirement: 128'):
            backend.alive(custody._observed[kernel.pid])

    def test_final_deadline_observation_can_confirm_retirement(self):
        custody, _, kernel, clock = self.setup_kernel(retire_at=0.025)
        custody.stop_remaining(timeout_seconds=0.025)
        self.assertAlmostEqual(clock.now, 0.025)
        self.assertEqual(sum(call[0] == 'terminate' for call in kernel.calls), 1)

    def test_observation_failure_remains_recorded_after_cleanup(self):
        custody, backend, kernel, _ = self.setup_kernel(retire_at=0.03)
        with patch.object(backend, 'table', side_effect=CustodyError('inventory refused')):
            with self.assertRaisesRegex(CustodyError, 'inventory refused'):
                custody.stop_remaining()
        self.assertTrue(custody.observation_errors)
        self.assertEqual(custody.remaining(), {})
        self.assertEqual(custody.cleanup_termination_errors[str(kernel.pid)]['error'], 5)


@unittest.skipUnless(sys.platform == 'win32', 'actual Win32 handle test; required on hosted Windows')
class NativeWindowsHandleTests(unittest.TestCase):
    def test_actual_exited_handle_error5_and_signaled_state(self):
        backend = _Windows()
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(20)'])
        try:
            identity = backend.identity(child.pid)
            handle = backend.handles[child.pid]
            child.terminate()
            child.wait(timeout=3)
            self.assertEqual(backend.kernel.TerminateProcess(handle, 1), 0)
            error = custody_module.C.get_last_error()
            self.assertEqual(error, 5)
            self.assertEqual(backend.kernel.WaitForSingleObject(handle, 0), 0)
            self.assertFalse(backend.alive(identity))
        finally:
            if child.poll() is None:
                child.kill()
            child.wait(timeout=3)
            backend.close()

    def test_actual_live_owned_process_retires_with_same_handle(self):
        custody = ProcessCustody('windows')
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(20)'])
        try:
            custody.observe(child.pid)
            handle = custody.backend.handles[child.pid]
            attempted = custody.stop_remaining()
            child.wait(timeout=3)
            self.assertIn(str(child.pid), attempted)
            self.assertEqual(custody.backend.handles[child.pid], handle)
            self.assertEqual(custody.remaining(), {})
        finally:
            if child.poll() is None:
                child.kill()
            child.wait(timeout=3)
            custody.close()


if __name__ == '__main__':
    if '--require-windows' in sys.argv:
        sys.argv.remove('--require-windows')
        if sys.platform != 'win32':
            raise SystemExit('FAIL: hosted Windows controls cannot be replaced by a non-Windows skip')
    unittest.main(verbosity=2)
