#!/usr/bin/env python3
"""Synthetic admission attacks only; this suite never claims Windows dispatch."""
from __future__ import annotations

import ctypes
from ctypes import wintypes
import json
from pathlib import Path
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest import mock
import owner_dispatch as dispatch

ENGINE = r'C:\Owner package with spaces\Godot_v4.7-stable_win64.exe'
PROJECT = r'C:\Owner package with spaces\godot'

# Exact startup sequence retained from the failed c313 Windows dispatch. The
# original run remains failed; this is a classifier regression, not requalification.
REAL_C313_STARTUP_LOG = '''Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
WARNING: Your video card drivers seem not to support the required OpenGL 3.3 version, switching to ANGLE.
   at: DisplayServerWindows (platform/windows/display_server_windows.cpp:8059)
OpenGL API OpenGL ES 3.0 (ANGLE 2.1.1 git hash: aaebda1c5a40) - Compatibility - Using Device: Google Inc. (Microsoft) - ANGLE (Microsoft, Microsoft Basic Render Driver (0x0000008C) Direct3D11 vs_5_0 ps_5_0, D3D11-10.0.20348.5756)
ERROR: Condition "hr != ((HRESULT)0x00000000)" is true. Returning: ERR_CANT_OPEN
   at: audio_device_init (drivers/wasapi/audio_driver_wasapi.cpp:275)
ERROR: WASAPI: init_output_device error.
   at: init (drivers/wasapi/audio_driver_wasapi.cpp:600)
WARNING: All audio drivers failed, falling back to the dummy driver.
   at: initialize (servers/audio/audio_server.cpp:258)

PHYSICS ENGINE 2D: Rapier2D v0.35.2
SHARED_WORKBENCH_LAUNCH_READY
'''


def fixture() -> dict:
    value = {'schema': 2, 'audio_diagnostic_policy': dispatch.AUDIO_POLICY,
             'audio_prefix_grace_seconds': dispatch.AUDIO_PREFIX_GRACE_SECONDS,
             'platform': 'Windows', 'verify_only': False, 'launcher_returncode': 0,
             'verified_source_logged': True, 'owned_before_resume': True, 'job_empty_after_retirement': True,
             'window': {'visible': True, 'responsive': True, 'title': 'CyberSand · Development workbench',
                        'width': 1280, 'height': 720, 'job_member': True},
             'stable_seconds': 10.0, 'godot_argv': [ENGINE, '--path', PROJECT, '--', '--workbench'],
             'expected_engine': ENGINE, 'expected_project': PROJECT, 'launch_marker_observed': True,
             'initialization_errors': [], 'raw_initialization_errors': [],
             'recovered_audio_diagnostics': [], 'pending_audio_diagnostics': [],
             'screenshot': {'sha256': 'a' * 64, 'distinct_sampled_colors': 64,
                                                       'width': 1280, 'height': 720}}
    for key in ('engine_sha256', 'native_sha256', 'reciprocal_cli_sha256', 'manifest_sha256'):
        value[key] = value['expected_' + key] = 'b' * 64
    return value


class DispatchAdmission(unittest.TestCase):
    def test_exact_recovered_audio_is_retained_without_waiving_graphical_gates(self):
        diagnostics = dispatch.classify_startup_logs({'godot.log': REAL_C313_STARTUP_LOG})
        self.assertEqual(diagnostics['initialization_errors'], [])
        self.assertEqual(diagnostics['pending_audio_diagnostics'], [])
        self.assertEqual(len(diagnostics['raw_initialization_errors']), 2)
        self.assertEqual(len(diagnostics['recovered_audio_diagnostics']), 1)
        recovered = diagnostics['recovered_audio_diagnostics'][0]
        self.assertEqual(recovered['source_log'], 'godot.log')
        self.assertEqual(recovered['start_line'], 5)
        self.assertEqual(recovered['raw_lines'], REAL_C313_STARTUP_LOG.splitlines()[4:10])
        report = fixture();report.update(diagnostics)
        self.assertEqual(dispatch.evidence_errors(report), [])
        report['window']['responsive'] = False
        self.assertTrue(dispatch.evidence_errors(report))

    def test_audio_stack_engine_or_fallback_changes_remain_fatal(self):
        mutations = (
            ('audio_driver_wasapi.cpp:275', 'audio_driver_wasapi.cpp:276'),
            ('audio_driver_wasapi.cpp:600', 'audio_driver_wasapi.cpp:601'),
            ('audio_server.cpp:258', 'audio_server.cpp:259'),
            ('v4.7.stable.official.5b4e0cb0f', 'v4.7.stable.official.different'),
            ('WARNING: All audio drivers failed, falling back to the dummy driver.\n', ''),
            ('ERROR: WASAPI: init_output_device error.', 'ERROR: WASAPI: unknown output failure.'),
        )
        for before, after in mutations:
            with self.subTest(before=before):
                diagnostics = dispatch.classify_startup_logs({'godot.log': REAL_C313_STARTUP_LOG.replace(before, after)})
                self.assertTrue(diagnostics['initialization_errors'])
                self.assertEqual(diagnostics['recovered_audio_diagnostics'], [])
                report = fixture();report.update(diagnostics)
                self.assertTrue(dispatch.evidence_errors(report))

    def test_audio_fallback_cannot_be_borrowed_from_another_log_or_boot(self):
        prefix, fallback = REAL_C313_STARTUP_LOG.split('WARNING: All audio drivers failed,', 1)
        for logs in (
            {'first.log': prefix, 'second.log': 'WARNING: All audio drivers failed,' + fallback},
            {'godot.log': prefix + dispatch.PINNED_ENGINE_HEADER + '\nWARNING: All audio drivers failed,' + fallback},
        ):
            diagnostics = dispatch.classify_startup_logs(logs)
            self.assertEqual(diagnostics['recovered_audio_diagnostics'], [])
            report = fixture();report.update(diagnostics)
            self.assertTrue(dispatch.evidence_errors(report))

    def test_partial_audio_log_prefix_never_authorizes_success(self):
        lines = REAL_C313_STARTUP_LOG.splitlines(keepends=True)
        for count in range(5, 10):
            for text in (''.join(lines[:count]), ''.join(lines[:count])[:-4]):
                diagnostics = dispatch.classify_startup_logs({'godot.log': text})
                self.assertEqual(diagnostics['recovered_audio_diagnostics'], [])
                self.assertEqual(len(diagnostics['pending_audio_diagnostics']), 1)
                report = fixture();report.update(diagnostics)
                self.assertTrue(dispatch.evidence_errors(report))
        lone = dispatch.classify_startup_logs({'godot.log': lines[0] + lines[4] + 'unrelated next line\n'})
        self.assertTrue(lone['initialization_errors'])
        self.assertEqual(lone['pending_audio_diagnostics'], [])

    def test_other_startup_errors_still_fail_after_exact_audio_recovery(self):
        for error in ('SCRIPT ERROR: failed script', 'ERROR: GDExtension failed', 'Failed to load native library',
                      'Parse Error: invalid script', 'Unable to create native World'):
            diagnostics = dispatch.classify_startup_logs({'godot.log': REAL_C313_STARTUP_LOG + error + '\n'})
            self.assertEqual(diagnostics['initialization_errors'], [error])
            self.assertEqual(len(diagnostics['recovered_audio_diagnostics']), 1)
            report = fixture();report.update(diagnostics)
            self.assertTrue(dispatch.evidence_errors(report))

    def test_repeated_first_audio_error_remains_bounded_and_fails(self):
        count = 100000
        text = dispatch.PINNED_ENGINE_HEADER + '\n' + (dispatch.RECOVERED_AUDIO_BLOCK[0] + '\n') * count
        self.assertLess(len(text.encode()), dispatch.MAX_LOG_BYTES)
        started = time.monotonic()
        diagnostics = dispatch.classify_startup_logs({'godot.log': text})
        self.assertLess(time.monotonic() - started, 5.0)
        self.assertEqual(len(diagnostics['raw_initialization_errors']), count)
        self.assertEqual(len(diagnostics['initialization_errors']), count - 1)
        self.assertEqual(diagnostics['recovered_audio_diagnostics'], [])
        self.assertEqual(len(diagnostics['pending_audio_diagnostics']), 1)
        report = fixture();report.update(diagnostics)
        self.assertTrue(dispatch.evidence_errors(report))

    def test_old_receipts_and_forged_audio_accounting_are_rejected(self):
        for key, value in [('schema', 1), ('audio_diagnostic_policy', 'ignore-all-audio'),
                           ('audio_prefix_grace_seconds', 240)]:
            report = fixture();report[key] = value
            self.assertTrue(dispatch.evidence_errors(report), key)
        diagnostics = dispatch.classify_startup_logs({'godot.log': REAL_C313_STARTUP_LOG})
        report = fixture();report.update(diagnostics);report['raw_initialization_errors'] = []
        self.assertTrue(dispatch.evidence_errors(report))
        report = fixture();report.update(diagnostics)
        report['recovered_audio_diagnostics'][0]['raw_lines'][1] = 'at: unrelated failure'
        self.assertTrue(dispatch.evidence_errors(report))

    def test_windows_powershell_rebuilds_its_child_only_module_path(self):
        for spelling in ('PSModulePath', 'PSMODULEPATH', 'psmodulepath'):
            inherited = {spelling: r'C:\Program Files\PowerShell\7\Modules',
                         'PATH': r'C:\Windows\System32', 'APPDATA': r'C:\Owner profile with spaces',
                         'CYBERSAND_SOURCE_REVISION': 'a' * 40}
            before = inherited.copy()
            child = dispatch.windows_powershell_env(inherited)
            self.assertEqual(child, {key: value for key, value in before.items() if key != spelling})
            self.assertEqual(inherited, before)

    def test_full_observation_and_paths_with_spaces_are_required(self):
        self.assertEqual(dispatch.evidence_errors(fixture()), [])
        self.assertTrue(dispatch.owner_command([ENGINE, '--path', PROJECT, '--', '--workbench'], ENGINE, PROJECT))
        self.assertFalse(dispatch.owner_command([ENGINE, '--path', PROJECT, '--path', PROJECT, '--', '--workbench'], ENGINE, PROJECT))

    def test_verify_only_other_platform_and_unverified_launcher_are_rejected(self):
        for key, value in [('platform', 'Linux'), ('verify_only', True), ('launcher_returncode', 1), ('verified_source_logged', False)]:
            report = fixture();report[key] = value
            self.assertTrue(dispatch.evidence_errors(report), key)

    def test_direct_test_script_headless_other_engine_or_project_is_rejected(self):
        for argv in ([ENGINE, '--headless', '--path', PROJECT, '--', '--workbench'],
                     [ENGINE, '--path', PROJECT, '--script', 'res://tests/smoke.gd', '--', '--workbench'],
                     [ENGINE, '--path', PROJECT, '--editor', '--', '--workbench'],
                     [ENGINE, '--path', PROJECT, '--', '--workbench', '--quit'],
                     [r'C:\stale\Godot.exe', '--path', PROJECT, '--', '--workbench'],
                     [ENGINE, '--path', r'C:\stale\godot', '--', '--workbench']):
            report = fixture();report['godot_argv'] = argv
            self.assertTrue(dispatch.evidence_errors(report), argv)

    def test_title_alone_or_marker_alone_does_not_pass_graphical_boot(self):
        for key in ('visible', 'responsive', 'job_member'):
            report = fixture();report['window'][key] = False
            self.assertTrue(dispatch.evidence_errors(report), key)
        for key, value in [('stable_seconds', 9.9), ('launch_marker_observed', False), ('initialization_errors', ['SCRIPT ERROR: startup'])]:
            report = fixture();report[key] = value
            self.assertTrue(dispatch.evidence_errors(report), key)
        report = fixture();report['window']['title'] = 'Godot splash screen'
        self.assertTrue(dispatch.evidence_errors(report))

    def test_surviving_or_unowned_process_tree_is_rejected(self):
        for key in ('owned_before_resume', 'job_empty_after_retirement'):
            report = fixture();report[key] = False
            self.assertTrue(dispatch.evidence_errors(report), key)

    def test_blank_capture_or_changed_source_bound_files_are_rejected(self):
        for key in ('engine_sha256', 'native_sha256', 'reciprocal_cli_sha256', 'manifest_sha256'):
            report = fixture();report[key] = 'c' * 64
            self.assertTrue(dispatch.evidence_errors(report), key)
        report = fixture();report['screenshot']['distinct_sampled_colors'] = 1
        self.assertTrue(dispatch.evidence_errors(report))
        report = fixture();report['screenshot']['sha256'] = ''
        self.assertTrue(dispatch.evidence_errors(report))


class FailureDiagnostics(unittest.TestCase):
    def test_api_failure_keeps_original_error_before_handle_cleanup(self):
        observer = dispatch.WindowsObserver.__new__(dispatch.WindowsObserver)
        observer.w, observer.job, observer.failure_context = wintypes, SimpleNamespace(_handle=7), {}
        last_error = {'code': 5}
        def membership(_handle, _job, member):
            member._obj.value = True
            return True
        def close(_handle):
            last_error['code'] = 6
            return True
        observer.kernel = SimpleNamespace(OpenProcess=lambda *_: 17, IsProcessInJob=membership,
            QueryFullProcessImageNameW=lambda *_: False, CloseHandle=mock.Mock(side_effect=close))
        original = PermissionError(13, 'Access is denied.');original.winerror = 5
        with mock.patch.object(dispatch.ctypes, 'get_last_error', lambda: last_error['code'], create=True), \
             mock.patch.object(dispatch.ctypes, 'WinError', return_value=original, create=True) as winerror:
            with self.assertRaises(PermissionError) as failure:
                observer.process(41)
        self.assertIs(failure.exception, original)
        winerror.assert_called_once_with(5)
        observer.kernel.CloseHandle.assert_called_once_with(17)
        self.assertEqual(last_error['code'], 6)
        self.assertEqual(observer.failure_context, {'api': 'QueryFullProcessImageNameW', 'pid': 41, 'winerror': 5})

    def test_window_callback_defers_the_same_failure_and_retains_its_context(self):
        observer = dispatch.WindowsObserver.__new__(dispatch.WindowsObserver)
        observer.w = SimpleNamespace(DWORD=ctypes.c_uint32)
        observer.callback = lambda function: function
        observer.failure_context = {'api': 'GetProcessTimes', 'pid': 41, 'winerror': 5}
        original = PermissionError(13, 'Access is denied.');original.winerror = 5
        def process(_pid):
            raise original
        def window_pid(_hwnd, pid):
            pid._obj.value = 41
            return 1
        observer.process = process
        observer.api_failure = mock.Mock(side_effect=AssertionError('Callback failure must not become stale EnumWindows last-error'))
        observer.user = SimpleNamespace(GetWindowThreadProcessId=window_pid, IsWindowVisible=lambda _: True,
                                       EnumWindows=lambda callback, argument: callback(4242, argument))
        try:
            observer.windows([41], Path(ENGINE))
        except PermissionError as error:
            self.assertIs(error, original)
            details = dispatch.failure_details(error, {'stage': 'enumerate_owned_windows'}, observer.failure_context)
        else:
            self.fail('Callback failure was silently ignored')
        observer.api_failure.assert_not_called()
        self.assertEqual(details['observer'], {'callback': 'EnumWindowsProc', 'hwnd': 4242,
                                              'pid': 41, 'api': 'GetProcessTimes', 'winerror': 5})
        self.assertIn('observe', details['traceback'])
        self.assertIn('PermissionError', details['traceback'])

    def test_recorded_observation_failure_still_fails_and_retires_owned_children(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            launcher = root / 'launcher.ps1';launcher.write_text('synthetic diagnostic fixture\n')
            lifecycle = []
            owner = SimpleNamespace(assign_and_resume=lambda _: lifecycle.append('owned'),
                                    terminate=lambda: lifecycle.append('terminated'), close=lambda: lifecycle.append('closed'))
            process = SimpleNamespace(pid=41, returncode=None, poll=lambda: None,
                                      kill=lambda: lifecycle.append('unexpected direct kill'))
            def wait(**_):
                process.returncode = 0
            process.wait = wait
            observer = SimpleNamespace(failure_context={}, members=lambda: [] if 'terminated' in lifecycle else [41])
            original = PermissionError(13, 'Access is denied.');original.winerror = 5
            def inspect(pid):
                observer.failure_context = {'api': 'QueryFullProcessImageNameW', 'pid': pid, 'winerror': 5}
                raise original
            observer.process = inspect
            module = SimpleNamespace(WindowsJob=lambda: owner, CREATE_SUSPENDED=4)
            specification = SimpleNamespace(loader=SimpleNamespace(exec_module=lambda _: None))
            with mock.patch.object(dispatch, 'os', SimpleNamespace(name='nt', environ={})), \
                 mock.patch.object(dispatch, 'WindowsObserver', return_value=observer), \
                 mock.patch.object(dispatch.importlib.util, 'spec_from_file_location', return_value=specification), \
                 mock.patch.object(dispatch.importlib.util, 'module_from_spec', return_value=module), \
                 mock.patch.object(dispatch.subprocess, 'Popen', return_value=process), \
                 mock.patch.object(dispatch.subprocess, 'CREATE_NEW_PROCESS_GROUP', 512, create=True), \
                 mock.patch.object(dispatch.subprocess, 'CREATE_NO_WINDOW', 0x08000000, create=True):
                report = dispatch.qualify(launcher, root / 'archive.zip', root / 'fresh install', root / 'evidence',
                                          'a' * 40, {'archive_sha256': 'b' * 64})
            self.assertEqual(lifecycle, ['owned', 'terminated', 'closed'])
            self.assertFalse(report['passed'])
            self.assertEqual(report['failure'], str(original))
            self.assertTrue(report['job_empty_after_retirement'])
            details = report['failure_details']
            self.assertEqual(details['type'], 'builtins.PermissionError')
            self.assertEqual((details['errno'], details['winerror']), (13, 5))
            self.assertEqual(details['phase'], {'stage': 'observe_owned_process', 'pid': 41})
            self.assertEqual(details['observer'], {'api': 'QueryFullProcessImageNameW', 'pid': 41, 'winerror': 5})
            self.assertIn('inspect', details['traceback'])
            self.assertEqual(json.loads((root / 'evidence/owner-dispatch-qualification.json').read_text()), report)


if __name__ == '__main__': unittest.main(verbosity=2)
