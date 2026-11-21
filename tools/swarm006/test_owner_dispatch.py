#!/usr/bin/env python3
"""Synthetic admission attacks only; this suite never claims Windows dispatch."""
from __future__ import annotations

import time
import unittest
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


if __name__ == '__main__': unittest.main(verbosity=2)
