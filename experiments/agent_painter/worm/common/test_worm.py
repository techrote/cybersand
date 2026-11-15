"""WORM-001 source-only tests; not model or native evidence."""
import io
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from tempfile import TemporaryDirectory
from worm import ACTIONS, FAMILIES, POLICIES, run, png_bytes, write_result


class WormContracts(unittest.TestCase):
    def test_repeatable_and_split_seed(self):
        a = run(42, 'fidget', 'greebles', 250)
        self.assertEqual(a, run(42, 'fidget', 'greebles', 250))
        self.assertNotEqual(a['trajectory'], run(43, 'fidget', 'greebles', 250)['trajectory'])

    def test_every_step_legal_and_bounded(self):
        for family in FAMILIES:
            for mode in POLICIES:
                record = run(71, mode, family, 350)
                blocked = {tuple(p) for p in record['obstacles']}
                for x, y in record['trajectory']:
                    self.assertTrue(0 <= x < 96 and 0 <= y < 96)
                    self.assertNotIn((x, y), blocked)
                self.assertEqual(len(record['events']) + 1, len(record['trajectory']))
                for event in record['events']:
                    self.assertIn(event['applied'], event['observation']['legal'])
                    self.assertIn(event['applied'], ACTIONS)
                self.assertLessEqual(len(record['events']), 350)

    def test_raw_illegal_choice_is_recorded_not_executed(self):
        record = run(4, 'replay', 'pipework', 9, raw_actions=['TELEPORT', 'STOP'])
        self.assertEqual(record['metrics']['invalid_raw_choices'], 1)
        self.assertEqual(record['events'][0]['raw_choice'], 'TELEPORT')
        self.assertEqual(record['events'][0]['applied'], 'STOP')

    def test_stop_and_actual_png(self):
        record = run(8, 'replay', 'architecture', 40, raw_actions=['STOP'])
        self.assertEqual(record['steps_executed'], 1)
        data = png_bytes(record)
        self.assertTrue(data.startswith(b'\x89PNG\r\n\x1a\n'))
        self.assertTrue(data.endswith(b'\x00\x00\x00\x00IEND\xaeB' + b'\x60\x82'))
        with TemporaryDirectory() as directory:
            with redirect_stdout(io.StringIO()):
                write_result(record, Path(directory))
            self.assertEqual(len(list(Path(directory).glob('*.png'))), 1)
            self.assertEqual(len(list(Path(directory).glob('*.json'))), 1)

    def test_strict_budgets(self):
        for kwargs in ({'steps': -1}, {'steps': 5000}, {'size': 12}, {'mode': 'model'}):
            with self.assertRaises(ValueError):
                run(1, **kwargs)


if __name__ == '__main__':
    unittest.main()
