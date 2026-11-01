#!/usr/bin/env python3
"""Adverse controls for retained shader evidence; these are not rendered results."""
from __future__ import annotations

import copy
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import tempfile
import tarfile
import unittest
import zlib
from unittest import mock

import numpy as np
from PIL import Image

import palette_qualification_contract as c
import run_palette_shader_qualification as runner


HASHES = {'full_crossfade': 'a' * 64, 'angle_bounded_crossfade': 'b' * 64}
# Original canonical CPU bytes, independently retained from 19ddd366's unchanged
# factory. Compression keeps the registered 8,192-byte golden input compact.
CANONICAL_PROGRAM = zlib.decompress(base64.b64decode(
    'eNrtmL9v00AUx2/OzFAkdEohQW6jVDiOU/+4S6+oEFoaknTOwHQzcyYvzJ0tFiR2zx6tm++PIHPn7jzHThWjyI9ihJA4v8XWR9/zu2/ee7mEkIeLPcT+ax9n9bw9r+ditr2j/c+h8i0mTyq8oucQuV7Zyk5O5YnyxQKefGUTRrsx6B2e83wN50x6SS+awfNQvlQ+7To+YYvy/dTWrOUkL8jF7vqU043eCZ1QinSkjrJZff4Zsj/Mv+8LhGPri2b+t2/ArQHtSq/wxyp57qB+RQ+jK8KW4b0nPUIOnoEzvOTj+EKfEyZukPwQ/hXJ7yPiT7TLA+Vzlo4q+vmfqs/f9Hde1N+nsv7k1t8B4XLQeQ533jrIK44exi5hccnTUezqQI/byP7F9e7+73zrsf5dNqw/6L8E+g5yJ/IY8i/6b6CZcx6fkSFB9NGUsEmYnILmOPaVP9noaR8cEdCz/Ur/edCXTLkV/bzZfGrMRUOOrf8a5WwF9XX3U33BROSJc9CB+caejFbWbUC79x5htyW3hprr4ZcOeYOs/xbhE4S/Q/j7hvqGPML0l80+P6y/yBUyHxfNOOZvhPl//Yj5s299hGcIJ9NmXFS4VX6/tXqtHu2nIz2Mpuh8qs8fy+8Dkh/CowpPIXK+DJch7TtiPc4q/BvElkci6Wm2nxfnG5gJR1W+gticr1zlar4ePxVkVj9fsoXh/zmv7w/DDTe85Plc3pxv7Twk/E79u+/nAQ+K87kcKNthsf+v+4f+/2C44YYbbrjhhhtuuOGGG2644Yb/Av8BLU5WzA=='))


def shader(variant='angle_bounded_crossfade'):
    return {'variant': variant, 'source_bound': True, 'source_file_bound': True,
            'source_path': 'res://shaders/material_palette.gdshader',
            'source_sha256': HASHES['full_crossfade'], 'source_file_sha256': HASHES['full_crossfade'],
            'variant_sha256': HASHES[variant]}


def godot_policy():
    value = c.policy.identity()
    return {'ok': True, 'path': 'res://tests/support/ci_execution_policy.json',
            'schema_version': value['schema_version'], 'scale': value['scale'], 'sha256': value['sha256'],
            'watchdogs': {key: value['watchdogs'][key] for key in c.GODOT_KEYS}}


def capture(directory, label, values):
    raw = directory / (label + '.raw'); png = directory / (label + '.png')
    values = values.astype('<f2')
    raw.write_bytes(values.tobytes())
    Image.fromarray(np.floor(np.clip(values.astype(float), 0, 1) * 255).astype('u1')).save(png)
    return {'label': label, 'raw': raw.name, 'png': png.name, 'raw_sha256': c.sha(raw),
            'png_sha256': c.sha(png), 'size': [values.shape[1], values.shape[0]], 'format': 15}


def program_inputs(directory):
    canonical = np.frombuffer(CANONICAL_PROGRAM, '<f2').reshape(256, 4, 4)
    edited = canonical.copy()
    for row in range(256):
        edited[row, 0] = (0, 1, 0, .5)
        edited[row, 1] = (.25, .75, .25, .75)
        edited[row, 2] = (1, 1, 0, .125)
        edited[row, 3, :3] = (.5, 0, .25)
    clamped = edited.copy(); clamped[:, 3, 3] = np.minimum(clamped[:, 3, 3], 1)
    def cpu(name, values):
        path = directory / ('program_' + name + '.rgba16f'); path.write_bytes(values.tobytes())
        return {'file': path.name, 'sha256': c.sha(path), 'bytes': 8192, 'size': [4, 256], 'format': 15}
    def scalar_image(values):
        image = np.ones((256, 16, 4), dtype='<f2')
        for column in range(4):
            for channel in range(4):
                scalar = values[:, column, channel].astype(float) / (64 if (column, channel) == (3, 3) else 1)
                image[:, column * 4 + channel, :3] = scalar[:, None]
        return image
    bound = {'object_id': -5, 'rid': 9}; control = {'object_id': -6, 'rid': 10}
    def probe(role, texture, values, begin):
        return {'role': role, 'binding_before': copy.deepcopy(texture), 'binding_after': copy.deepcopy(texture),
                'requested_usec': begin, 'readback_usec': begin + 1,
                'capture': capture(directory, 'program_' + role, scalar_image(values))}
    return {'schema': 'palette-program-gpu-inputs-v1', 'scalar_count': 4096, 'flair_scale': 64,
            'canonical': cpu('canonical', canonical), 'edited': cpu('edited', edited),
            'probe_shader_sha256': c.PROGRAM_PROBE_SHA256,
            'production_bindings': [{'draw_index': i, 'before': copy.deepcopy(bound), 'after': copy.deepcopy(bound)}
                                    for i in range(24) if i % 8 != 0],
            'positive': probe('production_bound', bound, edited, 60),
            'negative': probe('clamped_control', control, clamped, 62),
            'positive_max_error': 0.0, 'negative_control_max_error': 0.0,
            'negative_rejection_max_error': 49 / 64, 'sand_rejection_error': .5, 'water_rejection_error': .4375}


def oracle(directory):
    result = {'fixture': c.ORACLE_VERSION, 'assertions': c.ORACLE_ASSERTIONS, 'failures': 0, 'backend': 'opengl3',
              'conditions': [0, 128, 255], 'blends': [0, .5, 1], 'material_slots': 132,
              'tolerance': c.TOLERANCE, 'shader': shader(), 'rows': [], 'oracle_inputs': [],
              'draw_timings': [{'requested_usec': 10 + i * 2, 'readback_usec': 11 + i * 2} for i in range(24)]}
    for condition in result['conditions']:
        reference = c.reference_pixels(condition).astype('<f2').astype(float)
        current = np.full((36, 64, 4), (.3, .2, .7, 1), dtype='<f2').astype(float)
        result['oracle_inputs'].append({'condition': condition,
            'reference': capture(directory, f'ref-{condition}', reference),
            'current': capture(directory, f'current-{condition}', current)})
        for blend in result['blends']:
            values = (reference * (1 - blend) + current * blend).astype('<f2').astype(float)
            panned = np.roll(values, (-2, -3), (0, 1))
            result['rows'].append({'condition': condition, 'blend': blend, 'material_slots': 132,
                'capture': capture(directory, f'actual-{condition}-{blend}', values),
                'pan_capture': capture(directory, f'pan-{condition}-{blend}', panned),
                'max_rgba_difference': 0.0, 'camera_pan_difference': 0.0})
    result['program_inputs'] = program_inputs(directory)
    return result


def context_fixture(platform='linux'):
    case = c.plan(platform, 'visual')[1]
    report = {'platform': platform, 'source_commit': 'c' * 40, 'shader_hashes': HASHES,
              'source_inputs': {'godot/tests/' + case['script']: 'd' * 64},
              'engine': {'runtime_sha256': 'e' * 64}, 'host_paths': host_paths(platform)}
    row = {'nonce': 'f' * 32, 'process': {'pid': 3456}, 'cache_root': '/owned/cache'}
    value = {'schema': 'palette-qualification-context-v1', 'source_revision': report['source_commit'],
             'nonce': row['nonce'], 'fixture': 'res://tests/' + case['script'], 'fixture_sha256': 'd' * 64,
             'platform': 'Linux' if platform == 'linux' else 'Windows',
             'backend': 'opengl3' if platform == 'linux' else 'opengl3_angle',
             'display_server': 'X11' if platform == 'linux' else 'Windows',
             'godot': {'hash': c.GODOT_HASH, 'major': 4, 'minor': 7, 'status': 'stable', 'build': 'official'},
             'engine_sha256': 'e' * 64, 'engine_path': report['host_paths']['engine'],
             'process_id': 3456, 'execution_policy': godot_policy(),
             'cache_state': case['cache'], 'user_data_dir': '/owned/cache/data/godot/app_userdata/CyberSand',
             'shader': shader()}
    if platform == 'win32':
        row['cache_root'] = r'C:\owned\cache'
        value['user_data_dir'] = r'C:\owned\cache\roaming\Godot\app_userdata\CyberSand'
    return value, case, report, row


def host_paths(platform):
    if platform == 'linux':
        return {'source_root': '/source', 'project_root': '/source/godot',
                'launcher': '/engine/Godot_v4.7-stable_linux.x86_64', 'engine': '/engine/Godot_v4.7-stable_linux.x86_64'}
    return {'source_root': r'C:\source', 'project_root': r'C:\source\godot',
            'launcher': r'C:\engine\Godot_v4.7-stable_win64_console.exe',
            'engine': r'C:\engine\Godot_v4.7-stable_win64.exe'}


class InventoryAndIdentity(unittest.TestCase):
    def test_exact_six_cohorts_and_nineteen_process_cases(self):
        plan = c.hosted_plan()['include']
        self.assertEqual({(row['platform'], row['group'], row['shard_index']) for row in plan},
                         {(platform, group, index) for platform in ('linux', 'win32')
                          for group, count in (('visual', 2), ('main-cache', 1)) for index in range(count)})
        self.assertEqual(sum(row['cases'] for row in plan), 19)
        for platform in ('linux', 'win32'):
            combined = c.cohort_plan(platform, 'visual', 0) + c.cohort_plan(platform, 'visual', 1)
            self.assertEqual(combined, c.plan(platform, 'visual'))
        self.assertEqual([row['name'] for row in c.plan('linux', 'visual')][-2:],
                         ['atlas-baseline-full', 'atlas-candidate-full'])
        self.assertEqual(c.plan('win32', 'visual')[-1]['name'], 'atlas-candidate-bounded')

    def test_parent_includes_readback_metadata_and_rounded_steps(self):
        for row in c.hosted_plan()['include']:
            cases = c.cohort_plan(row['platform'], row['group'], row['shard_index'])
            self.assertEqual(row['case_total_seconds'], sum(case['timeout'] + sum(row['process_overhead'].values()) for case in cases))
            self.assertEqual(row['process_overhead']['cleanup_seconds'], c.policy.godot_process_cleanup_seconds())
            self.assertEqual(row['process_overhead']['observer_join_seconds'], c.observer_join_seconds())
            self.assertEqual(row['suite_seconds'], row['case_total_seconds'] + row['import_with_cleanup_seconds']
                             + sum(row['execution_metadata'].values()) + c.policy.watchdog_seconds('aggregate_headroom_seconds'))
            total = row['suite_minutes'] + row['dependency_minutes'] + row['readback_minutes'] + row['metadata_steps'] * row['metadata_step_minutes']
            self.assertEqual(total, row['total_stage_minutes'])
            self.assertGreaterEqual(row['job_minutes'], total)
            self.assertLessEqual(row['job_minutes'], 360)
        reducer = c.reducer_budget()
        self.assertGreaterEqual(reducer['job_minutes'], reducer['total_stage_minutes'])
        self.assertGreaterEqual(reducer['readback_minutes'] * 60, 6 * c.policy.watchdog_seconds('godot_metadata_seconds'))

    def test_scale_cannot_silently_shrink_or_overbook_hosted_parent(self):
        with mock.patch.dict(os.environ, {'CYBERSAND_CI_WATCHDOG_SCALE': '.5'}):
            with self.assertRaises(ValueError): c.hosted_plan()
        with mock.patch.dict(os.environ, {'CYBERSAND_CI_WATCHDOG_SCALE': '2'}):
            with self.assertRaisesRegex(ValueError, 'split'): c.hosted_plan()

    def test_actual_native_and_angle_contexts_pass(self):
        for platform in ('linux', 'win32'):
            c.verify_context(*context_fixture(platform))

    def test_wrong_backend_source_pid_cache_policy_and_variant_refuse(self):
        for key, value in [('backend', 'opengl3_angle'), ('display_server', 'headless'),
                           ('source_revision', '0' * 40), ('nonce', '0' * 32), ('fixture_sha256', '0' * 64),
                           ('process_id', 99), ('process_id', True), ('engine_sha256', '0' * 64),
                           ('engine_path', '/engine/wrong'), ('cache_state', 'warm'),
                           ('user_data_dir', '/outside/userdata'), ('user_data_dir', '/owned/cache/../outside')]:
            context, case, report, row = context_fixture()
            context[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): c.verify_context(context, case, report, row)
        context, case, report, row = context_fixture()
        context['execution_policy']['watchdogs']['main_ack_seconds'] = 15
        with self.assertRaises(ValueError): c.verify_context(context, case, report, row)
        context, case, report, row = context_fixture()
        context['shader']['variant_sha256'] = HASHES['full_crossfade']
        with self.assertRaises(ValueError): c.verify_context(context, case, report, row)

    def test_process_cannot_pass_on_exit_code_without_natural_policy_bound_completion(self):
        case = c.plan('linux', 'visual')[0]
        report = {'platform': 'linux', 'host_paths': host_paths('linux')}
        value = {'status': 'passed', 'returncode': 0, 'natural_completion': True,
                 'execution_policy': c.policy.identity(), 'timeout_seconds': case['timeout'], 'seconds': 1,
                 'requires_display': False, 'command': c.expected_command(case, report),
                 'name': case['name'], 'log': case['name'] + '.log', 'role': 'source-bound shader qualification'}
        c.verify_process(value, case, '', report)
        for key, replacement in [('natural_completion', False), ('returncode', False), ('timeout_seconds', 60),
                                 ('seconds', float('nan')), ('skip_messages', ['skipped']), ('timeout_kind', 'absolute')]:
            changed = copy.deepcopy(value); changed[key] = replacement
            with self.subTest(key=key), self.assertRaises(ValueError): c.verify_process(changed, case, '', report)
        for log in ('SCRIPT ERROR: parse failed', 'fixture skipped', 'ERROR: empty readback'):
            with self.assertRaises(ValueError): c.verify_process(value, case, log, report)

    def test_full_argv_and_import_cannot_change_driver_project_binary_or_extra_flags(self):
        for platform in ('linux', 'win32'):
            report = {'platform': platform, 'host_paths': host_paths(platform)}
            for case in [c.plan(platform, 'visual')[1], {'name': 'import', 'rendered': False,
                                                       'timeout': c.policy.watchdog_seconds('godot_import_seconds')}]:
                command = c.expected_command(case, report)
                value = {'status': 'passed', 'returncode': 0, 'natural_completion': True,
                         'execution_policy': c.policy.identity(), 'timeout_seconds': case['timeout'], 'seconds': 1,
                         'requires_display': case['rendered'], 'command': command, 'name': case['name'],
                         'log': case['name'] + '.log', 'role': 'source-bound shader qualification'}
                c.verify_process(value, case, '', report)
                altered = [command + ['--quit-after', '1'], ['another-engine', *command[1:]],
                           [('/wrong/project' if item == report['host_paths']['project_root'] else item) for item in command],
                           [item for item in command if item not in ('--editor', '--audio-driver')]]
                if '--rendering-driver' in command:
                    changed = list(command); changed[changed.index('--rendering-driver') + 1] = 'vulkan'; altered.append(changed)
                for changed in altered:
                    with self.subTest(platform=platform, fixture=case['name']), self.assertRaises(ValueError):
                        c.verify_process(dict(value, command=changed), case, '', report)

    def test_all_git_calls_consume_one_shared_remaining_phase(self):
        clock = [100.0]
        with mock.patch.object(runner.time, 'monotonic', side_effect=lambda: clock[0]), \
                mock.patch.object(runner.subprocess, 'check_output', return_value=b'value') as call:
            with runner.metadata_budget('test aggregate', 300):
                runner.git('rev-parse', 'HEAD')
                self.assertEqual(call.call_args.kwargs['timeout'], 300)
                clock[0] += 200
                with runner.metadata_budget('nested source phase', 300):
                    runner.git('archive', 'HEAD')
                    self.assertEqual(call.call_args.kwargs['timeout'], 100)
                self.assertEqual(runner.metadata_remaining(), 100)
            with self.assertRaises(RuntimeError):
                with runner.metadata_budget('expired', 1): clock[0] += 2
        with self.assertRaises(ValueError): runner.metadata_remaining()

    def test_only_known_import_newlines_may_change_between_actual_source_hashes(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp) / 'source.tar'
            name = sorted(runner.NORMALIZED_IMPORTS)[0]
            original = b'[remap]\nimporter="texture"\n'; crlf = original.replace(b'\n', b'\r\n')
            digest = lambda value: hashlib.sha256(value).hexdigest()
            with tarfile.open(archive, 'w:') as bundle:
                info = tarfile.TarInfo(name); info.size = len(original); bundle.addfile(info, io.BytesIO(original))
            before = {name: digest(crlf), 'godot/shaders/material_palette.gdshader': digest(b'original\n')}
            after = dict(before, **{name: digest(original)})
            self.assertEqual(runner.source_rewrites(before, after, archive), [name])
            changed = dict(after, **{name: digest(b'[remap]\nmodified=true\n')})
            with self.assertRaises(ValueError): runner.source_rewrites(before, changed, archive)
            changed = dict(after, **{'godot/shaders/material_palette.gdshader': digest(b'original\r\n')})
            with self.assertRaises(ValueError): runner.source_rewrites(before, changed, archive)
            with self.assertRaises(ValueError): runner.source_rewrites(before, {}, archive)

    def test_missing_or_duplicate_completion_packet_refuses(self):
        for text in ('', c.CONTEXT + '{}\n' + c.CONTEXT + '{}\n'):
            with self.assertRaises(ValueError): c.one(text, c.CONTEXT)

    def test_isolated_cache_inventory_rejects_symlinks_and_reproduces_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); environment = runner.cache_environment(root / 'cache')
            self.assertEqual(runner.cache_inventory(root / 'cache'), {})
            path = Path(environment['XDG_CACHE_HOME']) / 'shader.bin'; path.write_bytes(b'actual-cache')
            inventory = runner.cache_inventory(root / 'cache')
            self.assertEqual(inventory['cache/shader.bin']['sha256'], c.sha(path))
            if os.name != 'nt':
                (root / 'cache' / 'link').symlink_to(path)
                with self.assertRaises(ValueError): runner.cache_inventory(root / 'cache')

    def test_artifact_escape_and_file_symlink_refuse(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); (root / 'ok').write_bytes(b'original')
            self.assertEqual(c.file(root, 'ok'), root / 'ok')
            for name in ('../ok', '/ok', 'C:/ok', 'a\\ok'):
                with self.assertRaises(ValueError): c.file(root, name)
            if os.name != 'nt':
                (root / 'link').symlink_to(root / 'ok')
                with self.assertRaises(ValueError): c.file(root, 'link')


class PixelReadback(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.result = oracle(self.directory)

    def check(self):
        return c.verify_oracle(self.result, self.directory, {'shader_hashes': HASHES})

    def replace(self, row, key, data):
        row[key] = capture(self.directory, row[key]['label'], data)

    def test_complete_independent_half_precision_oracle_passes(self):
        value = self.check()
        self.assertEqual((value['frames'], value['material_slots'], value['retained_images']), (9, 132, 24))

    def test_registered_cpu_program_has_positive_outgoing_conditions(self):
        zero, full = c.reference_pixels(0), c.reference_pixels(255)
        np.testing.assert_array_equal(zero[0, 0], [.25, 0, 0, 1])
        np.testing.assert_array_equal(full[0, 0], [.4375, .5, .03125, 1])
        self.assertGreater(float(np.max(abs(c.reference_pixels(128) - zero))), .1)

    def test_outgoing_full_finish_substitution_fails_positive_base_oracle(self):
        row = self.result['rows'][0]
        current = c.pixels(self.directory, self.result['oracle_inputs'][0]['current'])
        self.replace(row, 'capture', current)
        with self.assertRaisesRegex(ValueError, 'outgoing'): self.check()

    def test_midpoint_and_final_corruption_fail_even_with_updated_capture_hashes(self):
        for blend in (.5, 1):
            original = copy.deepcopy(self.result)
            row = next(row for row in self.result['rows'] if row['condition'] == 255 and row['blend'] == blend)
            values = c.pixels(self.directory, row['capture']); values[5, 5, 0] += .1
            self.replace(row, 'capture', values)
            with self.subTest(blend=blend), self.assertRaisesRegex(ValueError, 'outgoing'): self.check()
            self.result = original
            self.result = oracle(self.directory)

    def test_camera_corruption_fails_its_retained_overlap(self):
        row = self.result['rows'][1]
        values = c.pixels(self.directory, row['pan_capture']); values[3, 3, 1] += .1
        self.replace(row, 'pan_capture', values)
        with self.assertRaisesRegex(ValueError, 'camera'): self.check()

    def test_reference_corruption_cannot_redefine_the_expected_program(self):
        row = self.result['oracle_inputs'][0]
        values = c.pixels(self.directory, row['reference']); values[:, :, 0] += .1
        self.replace(row, 'reference', values)
        with self.assertRaisesRegex(ValueError, 'CPU colour'): self.check()

    def test_missing_frame_condition_timing_or_image_is_incomplete(self):
        for key in ('rows', 'oracle_inputs', 'draw_timings'):
            original = copy.deepcopy(self.result); self.result[key].pop()
            with self.subTest(key=key), self.assertRaises(ValueError): self.check()
            self.result = original
        (self.directory / self.result['rows'][0]['capture']['raw']).unlink()
        with self.assertRaises(ValueError): self.check()

    def test_wrong_shader_or_assertion_receipt_refuses(self):
        for key, value in [('failures', True), ('assertions', 1215), ('tolerance', .1), ('fixture', 'v1')]:
            original = copy.deepcopy(self.result); self.result[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): self.check()
            self.result = original
        self.result['shader']['source_file_bound'] = False
        with self.assertRaises(ValueError): self.check()

    def test_reported_error_must_equal_independent_pixels(self):
        self.result['rows'][0]['max_rgba_difference'] = .005
        with self.assertRaisesRegex(ValueError, 'self-report'): self.check()

    def test_mutated_raw_png_nonfinite_and_byte_count_refuse(self):
        record = self.result['rows'][0]['capture']; raw = self.directory / record['raw']
        original = raw.read_bytes()
        raw.write_bytes(original + b'\0'); record['raw_sha256'] = c.sha(raw)
        with self.assertRaisesRegex(ValueError, 'byte count'): self.check()
        values = np.frombuffer(original, dtype='<f2').copy(); values[0] = np.nan
        raw.write_bytes(values.tobytes()); record['raw_sha256'] = c.sha(raw)
        with self.assertRaisesRegex(ValueError, 'Nonfinite'): self.check()
        raw.write_bytes(original); record['raw_sha256'] = c.sha(raw)
        Image.new('RGBA', (64, 36), 'black').save(self.directory / record['png'])
        record['png_sha256'] = c.sha(self.directory / record['png'])
        with self.assertRaisesRegex(ValueError, 'PNG does not represent'): self.check()

    def test_actual_gpu_hdr_input_and_rendered_clamped_negative_are_independent(self):
        value = self.check()['program_inputs']
        self.assertEqual(value['canonical_sha256'], '6ab9c18f2f2993eda7c552b86a28d639a70fb03e0ffdfb2ae070da5c587bb60d')
        self.assertEqual((value['scalars_per_probe'], value['retained_probe_images'], value['production_bindings']), (4096, 2, 21))
        self.assertEqual((value['sand_rejection_error'], value['water_rejection_error']), (.5, .4375))

    def test_coherent_endpoints_cannot_absorb_clamped_positive_gpu_program(self):
        inputs = self.result['program_inputs']
        clamped = c.pixels(self.directory, inputs['negative']['capture'])
        self.replace(inputs['positive'], 'capture', clamped)
        # All original endpoint/base/interpolation/camera pixels remain coherent.
        with self.assertRaisesRegex(ValueError, 'positive instruction'): self.check()

    def test_rehashed_canonical_and_edited_program_mutations_refuse(self):
        for key in ('canonical', 'edited'):
            inputs = self.result['program_inputs']; record = inputs[key]; path = self.directory / record['file']
            values = np.frombuffer(path.read_bytes(), '<f2').copy().reshape(256, 4, 4)
            values[2, 3, 3] = 1; path.write_bytes(values.tobytes()); record['sha256'] = c.sha(path)
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'independent'): self.check()
            self.result = oracle(self.directory)

    def test_production_or_probe_binding_substitution_and_alias_refuse(self):
        changes = [lambda v: v['positive']['binding_before'].update(rid=99),
                   lambda v: v['positive']['binding_after'].update(object_id=99),
                   lambda v: v['production_bindings'][3]['after'].update(rid=99),
                   lambda v: v['production_bindings'][0].update(draw_index=0),
                   lambda v: v['negative']['binding_before'].update(rid=9),
                   lambda v: v['negative']['binding_before'].update(object_id=-5),
                   lambda v: v['positive']['binding_before'].update(object_id=True)]
        for change in changes:
            original = copy.deepcopy(self.result); change(self.result['program_inputs'])
            with self.assertRaises(ValueError): self.check()
            self.result = original

    def test_negative_must_actually_render_the_clamped_recipe(self):
        inputs = self.result['program_inputs']
        good = c.pixels(self.directory, inputs['positive']['capture'])
        for values in (good, np.zeros((256, 16, 4))):
            self.replace(inputs['negative'], 'capture', values)
            with self.assertRaisesRegex(ValueError, 'registered clamped'): self.check()

    def test_program_probe_inventory_order_and_reduction_are_mandatory(self):
        changes = [lambda v: v.pop('program_inputs'),
                   lambda v: v['program_inputs'].update(scalar_count=4095),
                   lambda v: v['program_inputs'].update(probe_shader_sha256='0' * 64),
                   lambda v: v['program_inputs']['production_bindings'].pop(),
                   lambda v: v['program_inputs']['positive'].update(requested_usec=1),
                   lambda v: v['program_inputs']['negative'].update(requested_usec=60),
                   lambda v: v['program_inputs'].update(negative_rejection_max_error=0),
                   lambda v: v['program_inputs']['positive']['capture'].update(size=[16, 255]),
                   lambda v: v.update(fixture='palette-bounded-crossfade-v2')]
        for change in changes:
            original = copy.deepcopy(self.result); change(self.result)
            with self.assertRaises(ValueError): self.check()
            self.result = original

    def test_backend_finish_difference_is_retained_as_failed_diagnostic(self):
        other = self.directory / 'angle'; other.mkdir(); right = oracle(other); right['backend'] = 'opengl3_angle'
        for control in right['oracle_inputs']:
            current = c.pixels(other, control['current']); current[30, 10, :3] += [.015, .12, .0975]
            control['current'] = capture(other, control['current']['label'], current)
            current = c.pixels(other, control['current'])
            reference = c.pixels(other, control['reference'])
            for row in right['rows']:
                if row['condition'] != control['condition']: continue
                values = (reference * (1 - row['blend']) + current * row['blend']).astype('<f2').astype(float)
                row['capture'] = capture(other, row['capture']['label'], values)
                row['pan_capture'] = capture(other, row['pan_capture']['label'], np.roll(values, (-2, -3), (0, 1)))
        c.verify_oracle(right, other, {'shader_hashes': HASHES}); self.check()
        c.write(self.directory / 'crossfade.json', self.result); c.write(other / 'crossfade.json', right)
        result = c.compare_bounded_backends(self.directory, other)
        self.assertEqual(result['status'], 'passed')
        diagnostic = result['finished_image_diagnostic']
        self.assertEqual(diagnostic['status'], 'failed'); self.assertEqual(diagnostic['original_threshold'], 2 / 255)
        self.assertEqual(len(diagnostic['frames']), 9); self.assertEqual(len(result['outgoing_base_frames']), 3)
        self.assertGreater(max(row['max_rgba_difference'] for row in diagnostic['frames']), .1)
        row = right['rows'][0]; values = c.pixels(other, row['capture']); values[0, 0, 0] += .1
        row['capture'] = capture(other, row['capture']['label'], values); c.write(other / 'crossfade.json', right)
        with self.assertRaisesRegex(ValueError, 'outgoing CPU-base'): c.compare_bounded_backends(self.directory, other)


class MainReadback(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        image = np.zeros((540, 960, 4), dtype=float); image[:, :, 3] = 1
        image[:, 100:500, 0] = .5
        self.context = {'fixture': 'synthetic reader control; no runtime claim'}
        self.result = {'schema': 'palette-main-recreation-v1', 'context': self.context,
            'failures': 0, 'assertions': 27, 'joined_workers': 2, 'retired_sessions': 2,
            'rig': 'acrobat', 'workers_requested': 1, 'fixture_started_usec': 100,
            'fixture_finished_usec': 2000, 'elapsed_usec': 1900, 'lifetimes': [], 'waits': []}
        for index in range(2):
            start = 200 + index * 1000
            self.result['lifetimes'].append({'index': index, 'worker_id': 10 + index, 'session_id': 20 + index,
                'shader_instance_id': 30, 'bounded_define_count': 0, 'shader': shader('full_crossfade'),
                'world_surface_visible': True, 'world_material_bound': True, 'world_texture_bound': True,
                'ready': True, 'worker_joined': True, 'session_retired': True, 'initial_native_tick': 10,
                'native_tick': 11, 'initial_rapier_tick': 20, 'rapier_tick': 23, 'frames_after_ready': 2,
                'started_usec': start, 'acknowledged_usec': start + 10, 'readback_usec': start + 50,
                'retired_usec': start + 100, 'shutdown_usec': 50, 'main_ack_seconds': .00001,
                'capture': capture(self.directory, 'main-' + str(index), image)})
            for label, key in [('Main construction acknowledgement', 'main_ack_seconds'),
                               ('automatic native and Rapier progress', 'operation_seconds')]:
                allowance = c.policy.watchdog_microseconds(key)
                self.result['waits'].append({'label': label, 'passed': True, 'started_usec': start,
                    'ended_usec': start + 5, 'deadline_usec': start + allowance, 'allowance_usec': allowance})

    def check(self):
        return c.verify_main(self.result, self.context, self.directory, {'platform': 'linux', 'shader_hashes': HASHES})

    def test_actual_reader_requires_both_retired_lifetimes(self):
        self.assertEqual(self.check()['lifetimes'], 2)
        for key in ('joined_workers', 'retired_sessions'):
            self.result[key] = 1
            with self.subTest(key=key), self.assertRaises(ValueError): self.check()
            self.result[key] = 2

    def test_godot_opaque_signed_ids_are_nonzero_and_lossless(self):
        for index, life in enumerate(self.result['lifetimes']):
            life['worker_id'] = -9223371963387345224 + index
            life['shader_instance_id'] = -9223371964930849138
        self.check()
        for key in ('worker_id', 'session_id', 'shader_instance_id'):
            original = self.result['lifetimes'][0][key]
            for bad in (0, True, 1.5, 2**63):
                self.result['lifetimes'][0][key] = bad
                with self.subTest(key=key), self.assertRaises(ValueError): self.check()
            self.result['lifetimes'][0][key] = original

    def test_missing_progress_owner_reuse_wrong_variant_or_draw_refuses(self):
        for key, value in [('worker_id', 10), ('session_id', 20), ('shader_instance_id', 31),
                           ('bounded_define_count', 1), ('native_tick', 10), ('rapier_tick', 22),
                           ('frames_after_ready', 0), ('worker_joined', False), ('session_retired', False),
                           ('world_surface_visible', False), ('world_material_bound', False), ('world_texture_bound', False)]:
            original = copy.deepcopy(self.result); self.result['lifetimes'][1][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): self.check()
            self.result = original

    def test_empty_readback_does_not_qualify_main(self):
        self.result['lifetimes'][0]['capture'] = capture(self.directory, 'flat', np.ones((540, 960, 4)))
        with self.assertRaisesRegex(ValueError, 'empty/flat'): self.check()

    def test_wait_allowance_cannot_shrink_or_fabricate_an_extra_window(self):
        original = copy.deepcopy(self.result)
        for allowance in (15_000_000, 9999_000_000):
            self.result['waits'][0]['allowance_usec'] = allowance
            self.result['waits'][0]['deadline_usec'] = self.result['waits'][0]['started_usec'] + allowance
            with self.assertRaisesRegex(ValueError, 'allowance'): self.check()
            self.result = copy.deepcopy(original)

    def test_inconsistent_whole_fixture_or_overlapping_retirement_refuses(self):
        self.result['elapsed_usec'] += 1
        with self.assertRaisesRegex(ValueError, 'clock'): self.check()
        self.result['elapsed_usec'] -= 1
        self.result['lifetimes'][0]['retired_usec'] = self.result['lifetimes'][1]['started_usec'] + 1
        with self.assertRaisesRegex(ValueError, 'overlapped'): self.check()


if __name__ == '__main__':
    unittest.main()
