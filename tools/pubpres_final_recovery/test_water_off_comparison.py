import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import qualification_gate as gate


class WaterOffComparisonTests(unittest.TestCase):
    def setUp(self):
        self.failed = 'atomic-water-separate-4'
        self.report = {
            'schema': 'pubpres-recovery-hosted-v1', 'complete': False, 'platform': 'windows',
            'source': 'a' * 40, 'driver': {'driver': 1}, 'run': '10', 'attempt': '1',
            'request': {'phase': 'integration'}, 'unexecuted': [],
            'closure_members_required': True, 'closure_native_owner_required': True,
            'outcomes': [{'name': name, 'returncode': int(name == self.failed), 'timed_out': False}
                         for name in sorted(gate.NON_WATER_GROUPS | gate.WATER_GROUPS)],
        }

    def test_only_water_can_fail_after_every_required_group_executed(self):
        self.assertEqual(gate.water_only_failures(self.report), [self.failed])
        for name in gate.NON_WATER_GROUPS:
            report = copy.deepcopy(self.report)
            next(row for row in report['outcomes'] if row['name'] == name)['returncode'] = 1
            self.assertEqual(gate.water_only_failures(report), [], name)
        for field, value in [('complete', True), ('closure_members_required', False),
                             ('closure_native_owner_required', False), ('unexecuted', ['members']),
                             ('reduction_failure', 'unverified')]:
            self.assertEqual(gate.water_only_failures(dict(self.report, **{field: value})), [])
        rows = self.report['outcomes']
        for invalid in (rows[:-1], rows[:-1] + rows[:1], [dict(row, returncode=0) for row in rows],
                        [dict(row, returncode=None) for row in rows]):
            self.assertEqual(gate.water_only_failures(dict(self.report, outcomes=invalid)), [])

    def test_fallback_replays_only_for_bounded_water_off_and_binds_failed_original(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            raw = directory / 'INVENTORY.json'
            raw.write_text(json.dumps(self.report))
            original = raw.read_bytes()
            log = directory / (self.failed + '.log')
            log.write_text('failed original Water assertions')
            args = ({'source_commit': self.report['source']}, self.report['driver'], 'stock', 'custom')
            marker = directory / gate.WATER_OFF_ADMISSION
            with patch.object(gate, '_replay_inventory', return_value={'raw': 'verified'}) as verify:
                proof = gate.admit_water_off_comparison(raw, *args)
                verify.assert_called_once_with(raw, self.report, *args, False)
                marker.write_text(json.dumps(proof))
                self.assertEqual(gate.verify_bounded_inventory(marker, *args, 0), proof)
                self.assertEqual(raw.read_bytes(), original)
                with self.assertRaises(ValueError):
                    gate.verify_bounded_inventory(marker, *args, 1)
                with self.assertRaises(ValueError):
                    gate.verify_inventory(marker, *args, 0)
                with self.assertRaises(ValueError):
                    gate.verify_bounded_inventory(raw, *args, 0)
                log.write_text('replaced failure')
                with self.assertRaises(ValueError):
                    gate.verify_bounded_inventory(marker, *args, 0)

    def test_source_substitution_and_missing_raw_gate_cannot_create_fallback(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw = Path(tmp) / 'INVENTORY.json'
            raw.write_text(json.dumps(self.report))
            with self.assertRaises(ValueError):
                gate.admit_water_off_comparison(raw, {'source_commit': 'b' * 40}, {}, 'stock', 'custom')
            with self.assertRaises(FileNotFoundError):
                gate.admit_water_off_comparison(raw, {'source_commit': self.report['source']},
                                                self.report['driver'], 'stock', 'custom')


if __name__ == '__main__':
    unittest.main()
