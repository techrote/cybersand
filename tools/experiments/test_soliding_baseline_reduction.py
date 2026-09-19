"""Corruption checks use synthetic temporary evidence, never retained campaigns."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest

from summarize_soliding_baseline import digest, reduce


class ReductionIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='soliding-reducer-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        source = self.root / 'source' / 'native'
        source.mkdir(parents=True)
        (source / 'fixture.txt').write_text('synthetic input\n', encoding='utf-8')
        executable = self.root / 'synthetic-control'
        executable.write_bytes(b'not executed; reducer metadata fixture\n')
        self.artifact = self.root / 'artifact.json'
        self.write(self.artifact, {'source_ref': 'synthetic-source',
                                  'source_root': str(source.parent),
                                  'source_files': {'native/fixture.txt': digest(source / 'fixture.txt')},
                                  'executable': str(executable)})
        self.registration = {'artifact': str(self.artifact), 'artifact_sha256': digest(self.artifact),
                             'executable_sha256': digest(executable), 'source_ref': 'synthetic-source',
                             'measurement_protocol': 'soliding-baseline-v2',
                             'registered_timing_campaign': False,
                             'uncontended_note': 'synthetic test only', 'hardware_before': {},
                             'commands': []}
        self.completed = {'registration': self.registration, 'results': [], 'failures': 0,
                          'hardware_after': {}}
        for worker in (1, 4):
            name = f'r00-wall-128-w{worker}-x0-y0'
            command = [str(executable), 'wall', 128, worker, 1, 1, 6, 0, 0]
            self.registration['commands'].append([name, command])
            output = self.root / (name + '.stdout')
            sample = {'tick_ms': .01, 'edit_ms': 0, 'edit_cells': 0, 'epoch_clear': False,
                      'visited_cells': 0, 'moved_cells': 0, 'scheduled_cores': 0,
                      'active_blocks_after': 0, 'dirty_chunks': 0, 'chunk_allocations': 0,
                      'temperature_field_allocations': 0}
            counts = [0] * 256
            counts[0] = 16384
            raw = {'schema': 'soliding-baseline-v2', 'fixture': 'wall', 'size': 128,
                   'workers': worker, 'offset': [0, 0], 'settle_ticks': 1, 'warmup_ticks': 1,
                   'measured_ticks': 6, 'valid': True, 'conserved': True,
                   'initial_material_counts': counts, 'external_edit_delta': [0] * 256,
                   'final_material_counts': counts, 'final_content_hash': '11',
                   'final_state_hash': '22', 'resident_chunks': 1,
                   'resident_cell_bytes': 131328, 'cell_storage_bytes': 8,
                   'startup_samples': [dict(sample, tick=tick) for tick in range(1, 3)],
                   'samples': [dict(sample, tick=tick) for tick in range(3, 9)]}
            self.write(output, raw)
            output.with_suffix('.stderr').write_text('', encoding='utf-8')
            execution = {'command': [str(value) for value in command], 'exit': 0,
                         'stdout_sha256': digest(output),
                         'stderr_sha256': digest(output.with_suffix('.stderr'))}
            self.write(output.with_suffix('.execution.json'), execution)
            self.completed['results'].append({'name': name, 'exit': 0, 'output': str(output),
                                              'fixture': 'wall', 'size': 128, 'workers': worker,
                                              'offset': [0, 0]})
        self.write(self.root / 'registration.json', self.registration)
        self.path = self.root / 'completed.json'
        self.write(self.path, self.completed)

    @staticmethod
    def write(path, value):
        path.write_text(json.dumps(value), encoding='utf-8')

    def reduce(self):
        self.write(self.path, self.completed)
        return reduce(self.path)

    def assert_rejected(self, expected):
        value = self.reduce()
        messages = value['integrity_problems'] + [
            error for attempt in value['failed_attempts'] for error in attempt['errors']]
        self.assertTrue(any(expected in message for message in messages), messages)
        return value

    def first_output(self):
        return Path(self.completed['results'][0]['output'])

    def test_complete_registered_attempts_succeed(self):
        value = self.reduce()
        self.assertEqual(len(value['processes']), 2)
        self.assertEqual(value['integrity_problems'], [])
        self.assertEqual(value['failed_attempts'], [])

    def test_omitted_attempt_is_not_success(self):
        self.completed['results'].pop()
        self.assert_rejected('Missing registered attempt')

    def test_duplicate_attempt_is_not_success(self):
        self.completed['results'].append(copy.deepcopy(self.completed['results'][0]))
        self.assert_rejected('Duplicate completed attempt')

    def test_unregistered_attempt_is_not_success(self):
        self.completed['results'][0]['name'] = 'unregistered'
        self.assert_rejected('Unregistered attempt')

    def test_duplicate_registration_is_not_success(self):
        self.registration['commands'].append(copy.deepcopy(self.registration['commands'][0]))
        self.write(self.root / 'registration.json', self.registration)
        self.assert_rejected('Duplicate registered attempt')

    def test_empty_registration_cannot_pass_vacuously(self):
        self.registration['commands'] = []
        self.completed['results'] = []
        self.write(self.root / 'registration.json', self.registration)
        self.assert_rejected('Registration has no process commands')

    def test_embedded_registration_cannot_omit_retained_case(self):
        self.registration['commands'].pop()
        self.completed['results'].pop()
        self.assert_rejected('Embedded registration differs')

    def test_execution_command_must_match_registered_case(self):
        path = self.first_output().with_suffix('.execution.json')
        execution = json.loads(path.read_text())
        execution['command'][3] = '16'
        self.write(path, execution)
        self.assert_rejected('execution command differs')

    def test_raw_identity_rejected_even_with_matching_output_hash(self):
        output = self.first_output()
        original = json.loads(output.read_text())
        execution_path = output.with_suffix('.execution.json')
        execution = json.loads(execution_path.read_text())
        for field, replacement in [('fixture', 'redbrick'), ('size', 512), ('workers', 16),
                                   ('offset', [-1, 0]), ('settle_ticks', 2),
                                   ('warmup_ticks', 2), ('measured_ticks', 7)]:
            with self.subTest(field=field):
                value = dict(original, **{field: replacement})
                self.write(output, value)
                execution['stdout_sha256'] = digest(output)
                self.write(execution_path, execution)
                self.assert_rejected('raw process identity differs')

    def test_completed_identity_must_match_raw_output(self):
        self.completed['results'][0]['workers'] = 16
        self.assert_rejected('completed process identity differs')

    def test_attempts_cannot_reuse_an_output(self):
        self.completed['results'][1]['output'] = self.completed['results'][0]['output']
        self.assert_rejected('Reused process output')

    def test_filename_must_match_attempt(self):
        result = self.completed['results'][0]
        for suffix in ('.stdout', '.stderr', '.execution.json'):
            source = self.first_output().with_suffix(suffix)
            (self.root / ('different-name' + suffix)).write_bytes(source.read_bytes())
        result['output'] = str(self.root / 'different-name.stdout')
        self.assert_rejected('output filename differs')

    def test_changed_executable_registration_is_not_success(self):
        self.registration['commands'][0][1][0] = 'different-executable'
        self.write(self.root / 'registration.json', self.registration)
        self.assert_rejected('Registered executable differs')

    def test_changed_registered_source_is_not_success(self):
        self.registration['source_ref'] = 'other-source'
        self.write(self.root / 'registration.json', self.registration)
        self.assert_rejected('Registered source identity differs')

    def test_failed_malformed_output_is_retained(self):
        output = self.first_output()
        output.write_text('partial native failure', encoding='utf-8')
        execution_path = output.with_suffix('.execution.json')
        execution = json.loads(execution_path.read_text())
        execution.update(exit=124, stdout_sha256=digest(output))
        self.write(execution_path, execution)
        result = self.completed['results'][0]
        result['exit'] = 124
        self.completed['failures'] = 1
        value = self.assert_rejected('nonzero exit')
        self.assertEqual(len(value['processes']), 1)
        self.assertEqual(value['failed_attempts'][0]['name'], result['name'])
        self.assertEqual(value['reported_failure_count'], 1)

    def test_raw_corruption_is_not_silently_accepted(self):
        with self.first_output().open('a', encoding='utf-8') as stream:
            stream.write(' ')
        self.assert_rejected('stdout hash mismatch')


if __name__ == '__main__':
    unittest.main()
