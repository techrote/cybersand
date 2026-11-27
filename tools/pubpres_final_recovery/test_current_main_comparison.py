"""Challenge admission of a current-main cohort, not a simulated performance result."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from run_current_main_comparison import ARCHITECTURES, REGISTRATION, digest, validate_cohort


class CurrentMainAdmission(unittest.TestCase):
    def test_prospective_windows_and_order_preserve_original_contract(self):
        new = json.loads(REGISTRATION.read_bytes())
        old = json.loads((REGISTRATION.parents[1]/'pubpres_final/registration.json').read_bytes())
        for key in ('minimum_capture_usec', 'minimum_real_steps', 'maximum_capture_usec', 'reported_gap_thresholds_ms'):
            self.assertEqual(new[key], old[key])
        self.assertEqual(new['order'], ['N', 'C', 'C', 'N'])
        self.assertEqual(new['current_main'], '7a15691a7c537d07ff10a1bc4da9d46491c0b9d6')

    def test_complete_cohort_and_independent_corruption_refusals(self):
        with tempfile.TemporaryDirectory() as directory:
            engine = Path(directory)/'engine'; engine.write_bytes(b'explicit synthetic test executable')
            engines = {'stock': engine}; sources = {'N': {'source_commit': 'n'*40}, 'C': {'source_commit': 'c'*40}}
            arms = []
            for index, role in enumerate(('N', 'C', 'C', 'N')):
                candidate = role == 'C'
                arms.append({'arm': role, 'index': index, 'observers': {'presentation_enabled': False},
                    'statistics': {'source': sources[role]['source_commit'],
                        'registered_material_treatment': {'backend': 'full', 'policy': ''},
                        'same_frame_continuation': {'enabled': False},
                        'match': {'engine': digest(engine), 'render_thread': {'requested': 'safe', 'runtime': 'safe'},
                                  'water_law': 'wave_flow_v1', 'water_profile': 'gameplay_main846f',
                                  'adapter': 'synthetic', 'workers_requested': 4},
                        'first_144_body_trajectory_sha256': 'body', 'first_144_admitted_moves_sha256': 'moves',
                        'command_counts': {}, 'command_mode': 'repeated_callback',
                        'windows': {'first_144_steps': {'completed_rapier_steps': 144,
                            'rapier_steps_per_second': 40 if candidate else 20,
                            'physical_gap_ms': {'p95': 30 if candidate else 60, 'p99': 40 if candidate else 70, 'max': 50 if candidate else 80}}},
                        'physical_gap_counts_above_ms': {'first_144_steps': {str(key): 0 for key in (100, 250, 500, 1000)}}}})
            result = validate_cohort(arms, sources, engines, ARCHITECTURES['stock_safe'])
            self.assertTrue(result['registered_direction']['repeatable_direction'])
            self.assertEqual(len(result['physical_outcome_parity']['pairs']), 6)
            mutations = [
                lambda rows: rows.pop(),
                lambda rows: rows[1].update(arm='N'),
                lambda rows: rows[1].update(index=0),
                lambda rows: rows[1]['statistics'].update(source='foreign'),
                lambda rows: rows[1]['statistics']['match'].update(adapter='another-host'),
                lambda rows: rows[1]['statistics']['match'].update(workers_requested=1),
                lambda rows: rows[1]['statistics']['match'].update(engine='wrong-binary'),
                lambda rows: rows[1]['statistics']['match']['render_thread'].update(runtime='separate'),
                lambda rows: rows[1]['statistics'].update(first_144_body_trajectory_sha256='different-physical-trajectory'),
                lambda rows: rows[1]['statistics'].update(first_144_admitted_moves_sha256='different-inputs'),
                lambda rows: rows[1]['statistics']['same_frame_continuation'].update(enabled=True),
                lambda rows: rows[1]['observers'].update(presentation_enabled=True),
            ]
            for index, mutate in enumerate(mutations):
                with self.subTest(corruption=index):
                    changed = copy.deepcopy(arms); mutate(changed)
                    with self.assertRaises(ValueError):
                        validate_cohort(changed, sources, engines, ARCHITECTURES['stock_safe'])
            adverse = copy.deepcopy(arms)
            adverse[1]['statistics']['windows']['first_144_steps']['physical_gap_ms']['max'] = 900
            result = validate_cohort(adverse, sources, engines, ARCHITECTURES['stock_safe'])
            self.assertFalse(result['registered_direction']['repeatable_direction'])


if __name__ == '__main__': unittest.main()
