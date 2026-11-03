"""Adversarial acquisition-boundary tests; physical row checks have their own suite."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import analyze_gcr_causal as reader


class AcquisitionBoundary(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.folder = self.root / 'timing'
        self.cases = [{'id': f'case-{i}-C', 'arm': 'C', 'kind': 'flyer', 'ticks': 1800} for i in range(12)]
        self.protocol = self.root / 'protocol.json'
        self.write(self.protocol, {'registration': reader.TC, 'cases': self.cases, 'platforms': ['windows']})
        self.identity = {'source': 'a' * 40, 'protocol_sha256': reader.sha(self.protocol)}
        self.write(self.folder / 'identity.json', self.identity)
        self.completion = {'ok': True, 'inputs_unchanged': True, 'complete_registered_population': True,
            'source': 'a' * 40, 'end_source': 'a' * 40, 'identity_sha256': reader.sha(self.folder / 'identity.json'),
            'planned_captures': 40, 'completed_captures': 40, 'complete_selected_lanes': True,
            'selected_case': None, 'gates_only': False, 'selected_lanes': ['timing', 'event'],
            'selected_platforms': ['windows', 'linux']}
        self.write(self.folder / 'completion.json', self.completion)
        self.records = []
        for spec in self.cases:
            path = self.folder / 'windows' / (spec['id'] + '.json')
            self.write(path, {'synthetic_acquisition_unit_fixture': True})
            log = path.with_suffix('.log')
            log.write_text('Synthetic boundary unit fixture, no physical execution claim\n', encoding='utf-8')
            self.records.append({'case': spec['id'], 'ok': True, 'exit': 0, 'identity_ok': True,
                'rows': 1800, 'raw_sha256': reader.sha(path), 'log_sha256': reader.sha(log)})
        self.write(self.folder / 'windows/campaign.json', self.records)
        self.gates = []
        for test in ('test_gcr_causal_arena', 'test_gcr_event_causal'):
            path = self.root / 'windows' / (test + '.log')
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('GCR_CAUSAL_ARENA {"checks":1,"failures":0}\n' if test.endswith('arena') else 'unit fixture\n', encoding='utf-8')
            self.gates.append({'test': test, 'ok': True, 'exit': 0, 'timed_out': False, 'log_sha256': reader.sha(path)})
        self.write(self.root / 'windows/gates.json', self.gates)
        # Isolate campaign admission. Direct state, actuation, setter and physical
        # conservation checks are deliberately not simulated by this mock.
        self.inner = patch.object(reader, 'reduce_capture', side_effect=lambda raw, spec, identity, ph, platform, protocol:
                                  {'case': spec, 'platform': platform})
        self.inner.start()

    def tearDown(self):
        self.inner.stop()
        self.temp.cleanup()

    @staticmethod
    def write(path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value) + '\n', encoding='utf-8')

    def reduce(self):
        return reader.reduce_campaign(self.folder, self.protocol, ['windows'])

    def test_complete_synthetic_boundary_is_admitted(self):
        result = self.reduce()
        self.assertTrue(result['ok'])
        self.assertEqual(result['complete_captures'], 12)

    def test_changed_raw_bytes_are_preserved_as_failure(self):
        path = self.folder / 'windows' / (self.cases[0]['id'] + '.json')
        self.write(path, {'changed': True})
        result = self.reduce()
        self.assertFalse(result['ok'])
        self.assertEqual(len(result['failures']), 1)

    def test_changed_original_capture_log_refuses(self):
        path = self.folder / 'windows' / (self.cases[0]['id'] + '.log')
        path.write_text('changed\n', encoding='utf-8')
        self.assertFalse(self.reduce()['ok'])

    def test_changed_acquisition_exit_or_row_count_refuses(self):
        for key, value in [('exit', 124), ('rows', 1799), ('identity_ok', False), ('ok', False)]:
            with self.subTest(key=key):
                records = [dict(row) for row in self.records]
                records[0][key] = value
                self.write(self.folder / 'windows/campaign.json', records)
                self.assertFalse(self.reduce()['ok'])

    def test_changed_end_identity_or_incomplete_population_refuses(self):
        for key, value in [('end_source', 'b' * 40), ('completed_captures', 39), ('selected_case', 'case-0-C'),
                           ('gates_only', True), ('complete_registered_population', False), ('inputs_unchanged', False)]:
            with self.subTest(key=key):
                self.write(self.folder / 'completion.json', dict(self.completion, **{key: value}))
                with self.assertRaises(reader.EvidenceError):
                    self.reduce()

    def test_missing_or_reordered_capture_population_refuses(self):
        for rows in (self.records[:-1], list(reversed(self.records))):
            self.write(self.folder / 'windows/campaign.json', rows)
            with self.assertRaises(reader.EvidenceError):
                self.reduce()

    def test_new_mechanical_gate_cannot_be_reused_or_failed(self):
        for change in ({'inherited_from': 'some-old-log'}, {'exit': 1}, {'timed_out': True}, {'ok': False}):
            gates = [dict(row) for row in self.gates]
            gates[0].update(change)
            self.write(self.root / 'windows/gates.json', gates)
            with self.assertRaises(reader.EvidenceError):
                self.reduce()

    def test_new_mechanical_original_log_hash_is_required(self):
        (self.root / 'windows/test_gcr_causal_arena.log').write_text('changed\n', encoding='utf-8')
        with self.assertRaises(reader.EvidenceError):
            self.reduce()

    def test_timing_mechanical_failure_cannot_be_hashed_into_success(self):
        path = self.root / 'windows/test_gcr_causal_arena.log'
        path.write_text('GCR_CAUSAL_ARENA {"checks":1,"failures":1}\n', encoding='utf-8')
        self.gates[0]['log_sha256'] = reader.sha(path)
        self.write(self.root / 'windows/gates.json', self.gates)
        with self.assertRaises(reader.EvidenceError):
            self.reduce()


if __name__ == '__main__':
    unittest.main()
