#!/usr/bin/env python3
"""Synthetic admission attacks only; this suite never claims Windows dispatch."""
from __future__ import annotations

import unittest
import owner_dispatch as dispatch

ENGINE = r'C:\Owner package with spaces\Godot_v4.7-stable_win64.exe'
PROJECT = r'C:\Owner package with spaces\godot'


def fixture() -> dict:
    value = {'platform': 'Windows', 'verify_only': False, 'launcher_returncode': 0,
             'verified_source_logged': True, 'owned_before_resume': True, 'job_empty_after_retirement': True,
             'window': {'visible': True, 'responsive': True, 'title': 'CyberSand · Development workbench',
                        'width': 1280, 'height': 720, 'job_member': True},
             'stable_seconds': 10.0, 'godot_argv': [ENGINE, '--path', PROJECT, '--', '--workbench'],
             'expected_engine': ENGINE, 'expected_project': PROJECT, 'launch_marker_observed': True,
             'initialization_errors': [], 'screenshot': {'sha256': 'a' * 64, 'distinct_sampled_colors': 64,
                                                       'width': 1280, 'height': 720}}
    for key in ('engine_sha256', 'native_sha256', 'reciprocal_cli_sha256', 'manifest_sha256'):
        value[key] = value['expected_' + key] = 'b' * 64
    return value


class DispatchAdmission(unittest.TestCase):
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
