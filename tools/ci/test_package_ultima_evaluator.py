"""Adversarial admission tests; no engine/network/provider calls or owner saves."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import package_ultima_evaluator as package


HEAD = '1' * 40
TREE = '2' * 40
CASE_NAMES = (
    'test_goblin_contract', 'test_goblin_policies',
    'test_physics_instrumentation', 'test_thunderbowl_arena', 'test_thunderbowl_controllers',
    'import', 'test_gameplay_recorder', 'test_workbench_material_baseline', 'test_architectural_generator_ui',
    'test_workbench_generator_discovery', 'test_paint_editor_history',
    'test_paint_editor_history-reopen', 'test_workbench_canvas',
    'test_workbench_canvas-reopen', 'test_explore001_generated_workbench',
    'test_explore001_generated_workbench-reopen',
    'test_worldgen_workbench', 'test_material_lab_experiment', 'test_transport_profiles',
    'test_water_feel_controller', 'test_art_storage_integrity', 'test_art_traffic_integrity',
    'test_art_traffic_panel_safety', 'test_art_session_log', 'test_art_panel_ui',
    'test_art_history_receipt_identity',
)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n', encoding='utf-8')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def valid_qualification():
    q = {
        'schema': 'ultima-nonpublishing-qualification-v2', 'status': 'passed',
        'completed': True, 'host': 'win32', 'changed_inputs': [], 'errors': [],
        'source_head': HEAD, 'source_tree': TREE,
        'engine': {'version': package.windows.GODOT_VERSION,
                   'archive_sha512': package.windows.GODOT_SHA512,
                   'runtime_sha256': package.DEPENDENCIES['Godot_v4.7-stable_win64.exe'],
                   'console_sha256': package.DEPENDENCIES['Godot_v4.7-stable_win64_console.exe']},
        'cases': [{'name': name, 'status': 'passed', 'natural_completion': True,
                   'returncode': 0, 'skip_messages': [], 'timeout_kind': None,
                   'launch_error': None, 'capture_error': None, 'diagnostic_error': False,
                   'timeout_diagnostic_error': None} for name in CASE_NAMES],
    }
    cases = [{'kind': 'shared-helper', 'evidence_class': 'injected-and-native-boundaries',
              'result': {'checks': 75, 'failures': []}}]
    for kind in ('ordinary', 'generated', 'project'):
        cases.extend([
            {'kind': kind, 'evidence_class': 'real-writer-fresh-process-reload'},
            {'kind': kind, 'fault': 'locked-target', 'evidence_class': 'real-os-failure'},
        ])
    cases.extend([
        {'kind': 'helper', 'fault': 'locked-source-with-unlocked-destination', 'evidence_class': 'real-os-failure'},
        {'kind': 'helper', 'fault': 'process-termination-before-commit', 'evidence_class': 'real-process-termination'},
        {'kind': 'helper', 'evidence_class': 'real-concurrent-processes'},
    ])
    q['persistence'] = {'schema': 'workbench-save-qualification-v1', 'status': 'passed',
                        'completed': True, 'source_head': HEAD, 'platform': 'win32', 'cases': cases,
                        'engine_version': q['engine']['version'], 'engine_sha256': q['engine']['console_sha256']}
    q['microscenario_capture'] = {
        'schema': 'microscenario-capture-qualification-v1', 'status': 'passed',
        'completed': True, 'source_head': HEAD, 'platform': 'win32',
        'engine_version': q['engine']['version'], 'engine_sha256': q['engine']['console_sha256'],
        'cases': [{'kind': kind, 'evidence_class': evidence, **({'fault': fault} if fault else {})}
                  for kind, fault, evidence in sorted(package.WINDOWS_CAPTURE_CASES, key=str)],
    }
    q['recorder_storage'] = {
        'schema': 1, 'status': 'passed', 'passed': True, 'completed': True,
        'source_head': HEAD, 'platform': 'win32', 'engine_version': q['engine']['version'],
        'engine_sha256': q['engine']['console_sha256'],
        'cases': [{'fault': f, 'passed': True, 'exit_code': 0, 'natural_completion': True, 'engine_error_detected': False}
                  for f in ('none', 'locked-manifest')],
    }
    child = {'exit_code': 0, 'natural_completion': True, 'engine_error_detected': False}
    profile_children = {
        'before': child | {'format_loadable': True, 'acknowledged': True, 'loaded_value': 7,
                           'sha256': 'a' * 64, 'bytes': 100},
        'refusal': child | {'format_loadable': True, 'acknowledged': False, 'loaded_value': 7,
                            'sha256': 'a' * 64, 'bytes': 100},
        'replacement': child | {'format_loadable': True, 'acknowledged': True, 'loaded_value': 8,
                                'sha256': 'b' * 64, 'bytes': 101},
        'retry': child | {'format_loadable': True, 'acknowledged': True, 'loaded_value': 8,
                          'sha256': 'b' * 64, 'bytes': 101},
    }
    q['profile_save'] = {
        'schema': 'profile-save-qualification-v1', 'status': 'passed', 'completed': True,
        'source_head': HEAD, 'platform': 'win32', 'engine_version': q['engine']['version'],
        'engine_sha256': q['engine']['console_sha256'],
        'cases': [{'kind': kind, 'fault': fault, 'evidence_class': evidence,
                   **{name: copy.deepcopy(profile_children[name]) for name in
                      (('before', 'replacement') if fault == 'none' else ('before', 'refusal', 'retry'))}}
                  for kind in ('worldgen', 'material-lab', 'transport', 'water')
                  for fault, evidence in (('none', 'real-public-caller'),
                                          ('invalid-input', 'public-admission-refusal'),
                                          ('locked-target', 'real-os-failure'))],
    }
    q['art_storage'] = {
        'schema': 1, 'status': 'passed', 'passed': True, 'completed': True, 'inputs_unchanged': True,
        'source_head': HEAD, 'platform': 'win32', 'engine_version': q['engine']['version'],
        'engine_sha256': q['engine']['console_sha256'],
        'cases': [{'operation': operation, 'fault': fault, 'passed': True, **child}
                  for operation, fault in (('export', 'none'), ('new-event', 'none'), ('append', 'none'),
                                           ('export', 'locked-target'), ('append', 'locked-target'),
                                           ('settings', 'none'), ('settings', 'locked-target'),
                                           ('pending-history', 'none'), ('pending-history', 'existing-receipt'))],
    }
    for case in q['art_storage']['cases']:
        if case['operation'] not in ('settings', 'pending-history'):
            continue
        normal = case['fault'] == 'none'
        if case['operation'] == 'settings':
            case['ready'] = {'old_bytes': 100, 'old_sha256': 'a' * 64}
            first = {'success': normal, 'loadable': True, 'value': 8 if normal else 7, 'roundtrip': True,
                     'old_preserved': not normal, 'sha256': ('b' if normal else 'a') * 64,
                     'bytes': 101 if normal else 100, 'message': '' if normal else 'Previous file retained'}
            retry = first | {'success': True, 'value': 8, 'old_preserved': False,
                             'sha256': 'b' * 64, 'bytes': 101, 'message': ''}
        else:
            first = {'success': normal, 'loadable': True, 'old_preserved': True,
                     'values': [7, 8] if normal else [7], 'schema': 2 if normal else 0,
                     'frozen_projection': normal, 'item_has_file': normal, 'item_has_order': normal,
                     'clock_unchanged': not normal, 'message': '' if normal else 'Receipt not admitted'}
            retry = first | {'success': True, 'values': [7, 8], 'schema': 2, 'frozen_projection': True,
                             'item_has_file': True, 'item_has_order': True, 'message': ''}
        case['result'] = {'first': first, 'retry': retry, 'guards_preserved': True,
                          'stale_preserved': True, 'partial_files': []}
    for key, schema, kinds, value_key, loadable_key in (
            ('diagnostic_storage', 'diagnostic-storage-qualification-v1',
             ('physics', 'thunderbowl', 'physical-thunderbowl', 'goblin'), 'value', 'json_valid'),
            ('tower_observation', 'tower-observation-qualification-v1',
             ('ordinary', 'water-blind'), 'loaded_value', 'json_loadable')):
        records = []
        for kind in kinds:
            for fault in ('none', 'locked-target'):
                evidence = ('guarded-audit-writer' if kind == 'goblin' else 'real-public-cli') \
                    if key == 'diagnostic_storage' else 'real-public-caller'
                record = {'kind': kind, 'fault': fault,
                          'evidence_class': evidence if fault == 'none' else 'real-os-failure'}
                for name in (('before', 'replacement') if fault == 'none' else ('before', 'refusal', 'retry')):
                    child_record = copy.deepcopy(profile_children[name])
                    child_record[loadable_key] = child_record.pop('format_loadable')
                    child_record[value_key] = child_record.pop('loaded_value')
                    if name == 'refusal' and key == 'diagnostic_storage':
                        child_record['exit_code'] = 1 if kind == 'physics' else 2
                    record[name] = child_record
                records.append(record)
        q[key] = {'schema': schema, 'status': 'passed', 'completed': True, 'platform': 'win32',
                  'source_head': HEAD, 'engine_version': q['engine']['version'],
                  'engine_sha256': q['engine']['console_sha256'], 'cases': records, 'inputs_unchanged': True}
    return q


class QualificationAdmission(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ultima-package-admission-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.tracked = ['godot/probe.gd', 'third_party/pin.json']
        for path in self.tracked:
            file = self.source / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text('fixed input\n')
        self.receipt = self.root / 'evidence/qualification.json'
        self.map = self.receipt.with_name('source-inputs.json')
        self.inputs = {p: digest(self.source / p) for p in self.tracked}
        write_json(self.map, self.inputs)
        self.q = valid_qualification()
        self.q['source_inputs_sha256'] = digest(self.map)
        for case in self.q['cases']:
            log = self.receipt.parent / (case['name'] + '.log')
            log.write_text('FIXTURE checks=1 failures=0\n')
            case.update(log=log.name, log_sha256=digest(log))
        self.args = argparse.Namespace(qualification=self.receipt, dependencies=self.root / 'deps',
                                       output=self.root / 'package', manifest=self.root / 'manifest.json')

    def fake_git(self, *args, **kwargs):
        if args == ('rev-parse', 'HEAD'):
            return (HEAD + '\n').encode()
        if args == ('rev-parse', 'HEAD^{tree}'):
            return (TREE + '\n').encode()
        if args[:1] == ('diff',):
            return b''
        if args == ('ls-files', '-z'):
            return ('\0'.join(self.tracked) + '\0').encode()
        raise AssertionError('Unexpected Git operation before required refusal: ' + repr(args))

    def require_refusal(self, q=None):
        write_json(self.receipt, self.q if q is None else q)
        with patch.object(package, 'ROOT', self.source), patch.object(package, 'git', self.fake_git), \
             patch.object(package.windows, 'content_digest', side_effect=lambda root, p: digest(root / p)), \
             patch.object(package.windows, 'verify_retained_runtime', side_effect=AssertionError('Unqualified input reached runtime packaging')):
            with self.assertRaises((ValueError, RuntimeError)):
                package.build(self.args)
        self.assertFalse(self.args.output.exists(), 'Refusal must precede payload creation')

    def test_complete_positive_receipt_reaches_runtime_identity_gate(self):
        package.validate_qualification(self.q, HEAD, TREE)
        write_json(self.receipt, self.q)
        with patch.object(package, 'ROOT', self.source), patch.object(package, 'git', self.fake_git), \
             patch.object(package.windows, 'content_digest', side_effect=lambda root, p: digest(root / p)), \
             patch.object(package.windows, 'verify_retained_runtime', side_effect=AssertionError('Qualified identity gate reached')):
            with self.assertRaisesRegex(AssertionError, 'Qualified identity gate reached'):
                package.build(self.args)
        self.assertFalse(self.args.output.exists())

    def test_fault_engine_differs_from_normal_execution(self):
        self.q['persistence']['engine_sha256'] = 'f' * 64
        self.require_refusal()

    def test_older_qualification_contract_refuses(self):
        self.q['schema'] = 'ultima-nonpublishing-qualification-v1'
        self.require_refusal()

    def test_profile_missing_refuses(self):
        del self.q['profile_save']
        self.require_refusal()

    def test_profile_wrong_source_refuses(self):
        self.q['profile_save']['source_head'] = 'f' * 40
        self.require_refusal()

    def test_profile_wrong_engine_refuses(self):
        self.q['profile_save']['engine_sha256'] = 'f' * 64
        self.require_refusal()

    def test_profile_missing_lock_refuses_even_with_twelve_rows(self):
        self.q['profile_save']['cases'][-1] = copy.deepcopy(self.q['profile_save']['cases'][-2])
        self.require_refusal()

    def test_profile_refusal_child_must_complete(self):
        self.q['profile_save']['cases'][-1]['refusal']['natural_completion'] = False
        self.require_refusal()

    def test_profile_retry_cannot_have_engine_error(self):
        self.q['profile_save']['cases'][-1]['retry']['engine_error_detected'] = True
        self.require_refusal()

    def test_profile_failed_report_refuses(self):
        self.q['profile_save']['status'] = 'failed'
        self.require_refusal()

    def test_profile_false_success_on_refusal_refuses(self):
        self.q['profile_save']['cases'][-1]['refusal']['acknowledged'] = True
        self.require_refusal()

    def test_profile_changed_old_bytes_refuses(self):
        self.q['profile_save']['cases'][-1]['refusal']['sha256'] = 'f' * 64
        self.require_refusal()

    def test_profile_corrupt_reload_refuses(self):
        self.q['profile_save']['cases'][-1]['refusal']['format_loadable'] = False
        self.require_refusal()

    def test_profile_failed_retry_refuses(self):
        self.q['profile_save']['cases'][-1]['retry']['acknowledged'] = False
        self.require_refusal()

    def test_profile_wrong_saved_value_refuses(self):
        self.q['profile_save']['cases'][0]['replacement']['loaded_value'] = 7
        self.require_refusal()

    def test_art_missing_refuses(self):
        del self.q['art_storage']
        self.require_refusal()

    def test_art_wrong_source_refuses(self):
        self.q['art_storage']['source_head'] = 'f' * 40
        self.require_refusal()

    def test_art_wrong_engine_refuses(self):
        self.q['art_storage']['engine_sha256'] = 'f' * 64
        self.require_refusal()

    def test_art_duplicate_row_refuses_even_with_nine_rows(self):
        self.q['art_storage']['cases'][-1] = copy.deepcopy(self.q['art_storage']['cases'][-2])
        self.require_refusal()

    def test_art_settings_and_retained_journal_are_required(self):
        original = copy.deepcopy(self.q)
        for operation in ('settings', 'pending-history'):
            with self.subTest(operation=operation):
                self.q = copy.deepcopy(original)
                self.q['art_storage']['cases'] = [case for case in self.q['art_storage']['cases']
                                                  if case['operation'] != operation]
                self.require_refusal()

    def test_art_changed_inputs_refuse(self):
        self.q['art_storage']['inputs_unchanged'] = False
        self.require_refusal()

    def panel_refusals(self, change, *, refused_only=False):
        original = copy.deepcopy(self.q)
        for index, case in enumerate(original['art_storage']['cases']):
            if case['operation'] not in ('settings', 'pending-history') or (refused_only and case['fault'] == 'none'):
                continue
            with self.subTest(operation=case['operation'], fault=case['fault']):
                self.q = copy.deepcopy(original)
                change(self.q['art_storage']['cases'][index])
                self.require_refusal()

    def test_art_panel_missing_or_malformed_result_refuses(self):
        for value in (None, [], {}, {'first': [], 'retry': {}}):
            with self.subTest(value=value):
                self.panel_refusals(lambda case: case.update(result=copy.deepcopy(value)))

    def test_art_panel_false_success_on_refusal_refuses(self):
        self.panel_refusals(lambda case: case['result']['first'].update(success=True), refused_only=True)

    def test_art_panel_failed_retry_refuses(self):
        self.panel_refusals(lambda case: case['result']['retry'].update(success=False))

    def test_art_panel_false_guard_or_leaked_staging_refuses(self):
        for key, value in (('guards_preserved', False), ('stale_preserved', False), ('partial_files', ['leaked.partial'])):
            with self.subTest(key=key):
                self.panel_refusals(lambda case: case['result'].update({key: value}))

    def test_art_panel_settings_old_bytes_changed_refuses(self):
        case = next(c for c in self.q['art_storage']['cases'] if c['operation'] == 'settings' and c['fault'] != 'none')
        case['result']['first']['sha256'] = 'c' * 64
        self.require_refusal()

    def test_art_panel_journal_lost_receipt_or_clock_refuses(self):
        original = copy.deepcopy(self.q)
        for phase, key, value in (('first', 'clock_unchanged', False), ('retry', 'values', [8]),
                                  ('retry', 'item_has_file', False), ('retry', 'frozen_projection', False)):
            with self.subTest(phase=phase, key=key):
                self.q = copy.deepcopy(original)
                case = next(c for c in self.q['art_storage']['cases'] if c['operation'] == 'pending-history' and c['fault'] != 'none')
                case['result'][phase][key] = value
                self.require_refusal()

    def test_art_failed_case_refuses(self):
        self.q['art_storage']['cases'][-1]['passed'] = False
        self.require_refusal()

    def test_art_forced_exit_refuses(self):
        self.q['art_storage']['cases'][-1]['natural_completion'] = False
        self.require_refusal()

    def test_art_engine_error_refuses(self):
        self.q['art_storage']['cases'][-1]['engine_error_detected'] = True
        self.require_refusal()

    def additional_export_refusals(self, change):
        original = copy.deepcopy(self.q)
        for key in ('diagnostic_storage', 'tower_observation'):
            with self.subTest(matrix=key):
                self.q = copy.deepcopy(original)
                change(self.q, key)
                self.require_refusal()

    def test_additional_export_missing_refuses(self):
        self.additional_export_refusals(lambda q, key: q.pop(key))

    def test_additional_export_wrong_source_refuses(self):
        self.additional_export_refusals(lambda q, key: q[key].update(source_head='f' * 40))

    def test_additional_export_wrong_engine_refuses(self):
        self.additional_export_refusals(lambda q, key: q[key].update(engine_sha256='f' * 64))

    def test_additional_export_duplicate_lock_refuses(self):
        self.additional_export_refusals(lambda q, key: q[key]['cases'].__setitem__(-1, copy.deepcopy(q[key]['cases'][-2])))

    def test_additional_export_false_failure_ack_refuses(self):
        self.additional_export_refusals(lambda q, key: q[key]['cases'][-1]['refusal'].update(acknowledged=True))

    def test_additional_export_changed_old_bytes_refuses(self):
        self.additional_export_refusals(lambda q, key: q[key]['cases'][-1]['refusal'].update(sha256='f' * 64))

    def test_additional_export_failed_retry_refuses(self):
        self.additional_export_refusals(lambda q, key: q[key]['cases'][-1]['retry'].update(acknowledged=False))

    def test_additional_export_engine_error_refuses(self):
        self.additional_export_refusals(lambda q, key: q[key]['cases'][-1]['retry'].update(engine_error_detected=True))

    def test_diagnostic_false_zero_exit_on_refusal_refuses(self):
        self.q['diagnostic_storage']['cases'][-1]['refusal']['exit_code'] = 0
        self.require_refusal()

    def test_tower_changed_inputs_refuses(self):
        self.q['tower_observation']['inputs_unchanged'] = False
        self.require_refusal()

    def test_capture_missing_refuses(self):
        del self.q['microscenario_capture']
        self.require_refusal()

    def test_capture_wrong_source_refuses(self):
        self.q['microscenario_capture']['source_head'] = 'f' * 40
        self.require_refusal()

    def test_capture_wrong_engine_refuses(self):
        self.q['microscenario_capture']['engine_sha256'] = 'f' * 64
        self.require_refusal()

    def test_capture_missing_lock_refuses_even_with_four_rows(self):
        self.q['microscenario_capture']['cases'][-1] = copy.deepcopy(self.q['microscenario_capture']['cases'][0])
        self.require_refusal()

    def test_capture_failure_refuses(self):
        self.q['microscenario_capture']['status'] = 'failed'
        self.require_refusal()

    def test_recorder_missing_refuses(self):
        del self.q['recorder_storage']
        self.require_refusal()

    def test_recorder_wrong_source_refuses(self):
        self.q['recorder_storage']['source_head'] = 'f' * 40
        self.require_refusal()

    def test_recorder_missing_lock_refuses(self):
        self.q['recorder_storage']['cases'][1]['fault'] = 'none'
        self.require_refusal()

    def test_recorder_forced_exit_refuses(self):
        self.q['recorder_storage']['cases'][1]['natural_completion'] = False
        self.require_refusal()

    def test_recorder_engine_error_refuses(self):
        self.q['recorder_storage']['cases'][1]['engine_error_detected'] = True
        self.require_refusal()

    def test_missing_lock_case_refuses_even_with_ten_rows(self):
        self.q['persistence']['cases'][-3] = copy.deepcopy(self.q['persistence']['cases'][-2])
        self.require_refusal()

    def test_failed_helper_assertions_refuse(self):
        self.q['persistence']['cases'][0]['result']['failures'] = ['lost old bytes']
        self.require_refusal()

    def test_no_helper_assertions_is_not_qualification(self):
        self.q['persistence']['cases'][0]['result']['checks'] = 0
        self.require_refusal()

    def test_empty_claimed_pass_has_no_executed_cases(self):
        self.q['cases'] = []
        self.require_refusal()

    def test_skipped_workflow_cannot_be_passed(self):
        self.q['cases'][2]['skip_messages'] = ['not supported on this platform']
        self.require_refusal()

    def test_nonzero_exit_cannot_be_overridden_by_passed_label(self):
        self.q['cases'][2]['returncode'] = 3221225477
        self.require_refusal()

    def test_forced_termination_is_not_natural_completion(self):
        self.q['cases'][2]['natural_completion'] = False
        self.require_refusal()

    def test_duplicate_case_does_not_replace_required_reopen(self):
        self.q['cases'][-1] = copy.deepcopy(self.q['cases'][-2])
        self.require_refusal()

    def test_error_list_refuses_despite_passed_label(self):
        self.q['errors'] = ['previous failure']
        self.require_refusal()

    def test_missing_fault_matrix_refuses(self):
        del self.q['persistence']
        self.require_refusal()

    def test_failed_fault_matrix_refuses(self):
        self.q['persistence']['status'] = 'failed'
        self.require_refusal()

    def test_different_source_receipt_refuses(self):
        self.q['source_head'] = '3' * 40
        self.require_refusal()

    def test_linux_receipt_is_not_windows_qualification(self):
        self.q['host'] = 'linux'
        self.require_refusal()

    def test_map_file_tamper_refuses(self):
        self.map.write_text('{}')
        self.require_refusal()

    def test_self_consistent_but_incomplete_map_refuses(self):
        write_json(self.map, {self.tracked[0]: self.inputs[self.tracked[0]]})
        self.q['source_inputs_sha256'] = digest(self.map)
        self.require_refusal()

    def test_changed_input_bytes_refuse_without_git_delta(self):
        (self.source / self.tracked[0]).write_text('different bytes\n')
        self.require_refusal()

    def test_existing_manifest_is_not_overwritten(self):
        self.args.manifest.write_text('valuable existing file\n')
        before = self.args.manifest.read_bytes()
        self.require_refusal()
        self.assertEqual(before, self.args.manifest.read_bytes())


class ManifestIntegrity(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ultima-manifest-review-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.folder = self.root / 'package'
        self.folder.mkdir()
        self.file = self.folder / 'godot/project.godot'
        self.file.parent.mkdir()
        self.file.write_text('original payload\n')
        required = {
            'Godot_v4.7-stable_win64.exe', 'Godot_v4.7-stable_win64_console.exe', 'vcruntime140.dll',
            'Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt', 'Microsoft-Visual-C-Runtime-LICENSE.docx',
            'Microsoft-Visual-Studio-2022-LICENSE.docx', 'vc-runtime-provenance.json',
            'LICENSE_STATUS.md', 'THIRD_PARTY_NOTICES.md', 'Open Workbench.cmd', 'READ-ME.md',
            'qualification.json', 'godot/project.godot', package.windows.NATIVE, package.windows.RAPIER,
        }
        for relative in required:
            file = self.folder / relative
            file.parent.mkdir(parents=True, exist_ok=True)
            if not file.exists():
                file.write_text('synthetic integrity fixture; not an executable\n')
        write_json(self.folder / 'qualification.json', valid_qualification())
        self.record = {'schema': 1, 'kind': 'ultima-test-only-workbench',
                       'source_commit': HEAD, 'source_tree': TREE,
                       'qualification_sha256': digest(self.folder / 'qualification.json'),
                       'files_sha256': {name: digest(self.folder / name) for name in required}}

    def store(self):
        write_json(self.folder / 'candidate-manifest.json', self.record)
        return digest(self.folder / 'candidate-manifest.json')

    def check(self, expected=None):
        return package.verify(self.folder, expected or digest(self.folder / 'candidate-manifest.json'))

    def test_complete_positive_integrity_fixture(self):
        expected = self.store()
        self.assertEqual(self.check(expected)['source_commit'], HEAD)

    def test_manifest_rewrite_cannot_replace_trusted_digest(self):
        expected = self.store()
        del self.record['files_sha256']['godot/project.godot']
        self.store()
        with self.assertRaises(ValueError):
            self.check(expected)

    def test_subset_manifest_refuses_even_with_matching_digest(self):
        del self.record['files_sha256']['godot/project.godot']
        self.store()
        with self.assertRaises(ValueError):
            self.check()

    def test_missing_tree_is_not_a_source_identity(self):
        del self.record['source_tree']
        q = valid_qualification()
        q['source_tree'] = None
        write_json(self.folder / 'qualification.json', q)
        self.record['qualification_sha256'] = digest(self.folder / 'qualification.json')
        self.record['files_sha256']['qualification.json'] = self.record['qualification_sha256']
        self.store()
        with self.assertRaises(ValueError):
            self.check()

    def test_changed_payload_fails(self):
        self.store()
        self.file.write_text('changed payload\n')
        with self.assertRaises(ValueError):
            self.check()

    def test_parent_traversal_fails(self):
        outside = self.root / 'outside.txt'
        outside.write_text('outside\n')
        self.record['files_sha256']['../outside.txt'] = digest(outside)
        self.store()
        with self.assertRaises(ValueError):
            self.check()

    def test_absolute_path_fails(self):
        self.record['files_sha256'][str(self.file)] = digest(self.file)
        self.store()
        with self.assertRaises(ValueError):
            self.check()

    def test_windows_drive_or_stream_name_fails(self):
        # A colon is a legal Linux filename but a drive/alternate stream token on Windows.
        self.record['files_sha256']['engine.exe:payload'] = digest(self.file)
        self.store()
        with self.assertRaises(ValueError):
            self.check()

    def test_symlink_file_fails_even_when_target_is_inside_package(self):
        link = self.folder / 'alias'
        try:
            link.symlink_to(self.file)
        except OSError as error:
            self.skipTest(str(error))
        self.record['files_sha256']['alias'] = digest(self.file)
        self.store()
        with self.assertRaises(ValueError):
            self.check()

    def test_case_aliases_refuse_for_windows_package(self):
        other = self.folder / 'Godot/project.godot'
        other.parent.mkdir(exist_ok=True)
        other.write_text('case alias\n')
        self.record['files_sha256']['Godot/project.godot'] = digest(other)
        self.store()
        with self.assertRaises(ValueError):
            self.check()

    def test_duplicate_manifest_keys_fail_closed(self):
        self.store()
        manifest = self.folder / 'candidate-manifest.json'
        value = manifest.read_text()
        value = value.replace('"source_commit":', '"source_commit": "' + 'f'*40 + '", "source_commit":', 1)
        manifest.write_text(value)
        with self.assertRaises(ValueError):
            self.check()


if __name__ == '__main__':
    unittest.main()
