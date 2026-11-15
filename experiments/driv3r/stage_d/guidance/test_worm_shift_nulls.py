"""Offline adversarial controls; all fixtures are synthetic and self-sealed."""
import hashlib
import json
import struct
import unittest
from copy import deepcopy

try:
    from .worm_shift_nulls import audit_shifted_field_nulls
except ImportError:
    from experiments.driv3r.stage_d.guidance.worm_shift_nulls import audit_shifted_field_nulls


def digest(o):
    return hashlib.sha256(json.dumps(o, sort_keys=True, separators=(',', ':'),
                                     ensure_ascii=True, allow_nan=False).encode()).hexdigest()


def step(index, x, y, pen=True):
    return {"decision_index": index, "action": "MOVE", "to_xy": [x, y], "pen_down": pen}


def stop(index):
    return {"decision_index": index, "action": "STOP", "to_xy": [], "pen_down": False}


def synthetic_bound(field, free, soft, w=4, h=2):
    guide_sha = hashlib.sha256(field).hexdigest()
    routes, shapes = {}, {}
    for arm, trace in (("free", free), ("soft", soft)):
        ink = {tuple(i['to_xy']) for i in trace if i['action'] == 'MOVE' and i['pen_down']}
        count = sum(i['action'] == 'MOVE' and i['pen_down'] for i in trace)
        routes[arm] = {
            "trajectory_sha256": digest(trace),
            "pen_down_intent_reference": {"unique_target_cells": len(ink)},
            "pen_down_intent_moves": count,
        }
        shapes[arm] = {"validated_trace_sha256": digest(trace),
                       "distinct_intended_cells": len(ink),
                       "intended_contact_moves": count}
    movement = dict(arms=routes, frame=[0, 0, w, h], seed=570, initial_xy=[1, 1],
                    reference_guidance_sha256=guide_sha,
                    source_revision='a' * 40, scenario_sha256='b' * 64,
                    initial_world_sha256='c' * 64,
                    native_material_authority=False, model_inference_performed=False)
    shape = dict(arms=shapes, native_material_verified=False,
                 model_behavior_verified=False)
    return dict(protocol='cybersand.driv3r.d1b-worm-morphology-bound/1',
                evidence_class='source_bound_synthetic_ink_intent_only',
                native_material_verified=False, model_behavior_verified=False,
                native_undo_executions=0, source_revision='a' * 40,
                scenario_sha256='b' * 64, initial_world_sha256='c' * 64,
                guidance_sha256=guide_sha, frame=[0, 0, w, h], seed=570, initial_xy=[1, 1],
                movement_audit_sha256=digest(movement),
                morphology_audit_sha256=digest(shape),
                movement_audit=movement, morphology_audit=shape)


class ShiftedFieldNullTests(unittest.TestCase):
    def setUp(self):
        self.field = struct.pack('<8H', 0, 0, 1000, 65535, 0, 0, 1000, 65535)
        self.free = [step(1, 0, 1), step(2, 0, 0), stop(3)]
        self.soft = [step(1, 2, 1), step(2, 3, 1), stop(3)]
        self.report = synthetic_bound(self.field, self.free, self.soft)

    def audit(self, **changes):
        args = dict(bound_report=deepcopy(self.report), guidance_u16le=self.field,
                    free_trace=deepcopy(self.free), soft_trace=deepcopy(self.soft))
        args.update(changes)
        return audit_shifted_field_nulls(**args)

    def test_deterministic_unique_nonzero_shifts(self):
        a, b = self.audit(), self.audit()
        self.assertEqual(a, b)
        shifts = [tuple(x['translation_xy']) for x in a['nulls']]
        self.assertEqual(len(shifts), 7)
        self.assertEqual(len(set(shifts)), 7)
        self.assertNotIn((0, 0), shifts)
        self.assertEqual(a['audit_sha256'], digest({k: v for k, v in a.items()
                                                    if k != 'audit_sha256'}))

    def test_exact_rational_nonrepeated_ink_score(self):
        r = self.audit(max_null_shifts=3)
        o = r['observed']
        self.assertEqual(o['free'], dict(sum_u16=0, distinct_ink_cells=2))
        self.assertEqual(o['soft'], dict(sum_u16=66535, distinct_ink_cells=2))
        self.assertEqual(o['soft_minus_free_mean_unique_ink_u16'],
                         dict(numerator=133070, denominator=4))
        self.assertEqual(r['null_count'], 3)
        self.assertTrue(r['null_comparison_defined'])
        self.assertLessEqual(r['null_scores_at_least_observed_count'], 3)

    def test_repeated_contact_does_not_inflate_unique_score(self):
        soft = [step(1, 2, 1), step(2, 3, 1), step(3, 2, 1), step(4, 3, 1), stop(5)]
        report = synthetic_bound(self.field, self.free, soft)
        r = self.audit(soft_trace=soft, bound_report=report)
        self.assertEqual(r['observed']['soft'], dict(sum_u16=66535, distinct_ink_cells=2))

    def test_no_intended_ink_is_not_a_fabricated_score(self):
        free = [step(1, 0, 1, False), stop(2)]
        report = synthetic_bound(self.field, free, self.soft)
        r = self.audit(free_trace=free, bound_report=report)
        self.assertIsNone(r['observed']['soft_minus_free_mean_unique_ink_u16'])
        self.assertIsNone(r['null_scores_at_least_observed_count'])
        self.assertFalse(r['null_comparison_defined'])

    def test_identical_intended_ink_guarantees_zero_difference_for_every_shift(self):
        report = synthetic_bound(self.field, self.soft, self.soft)
        r = self.audit(free_trace=self.soft, bound_report=report)
        for x in [r['observed']] + r['nulls']:
            self.assertEqual(x['soft_minus_free_mean_unique_ink_u16']['numerator'], 0)
        self.assertEqual(r['null_scores_at_least_observed_count'], r['null_count'])

    def test_reject_forged_field_bytes(self):
        with self.assertRaisesRegex(ValueError, 'field byte provenance'):
            self.audit(guidance_u16le=bytes(len(self.field)))

    def test_reject_resealed_modified_trajectory(self):
        corrupted = deepcopy(self.soft)
        corrupted[0]['to_xy'] = [1, 1]
        with self.assertRaisesRegex(ValueError, 'trajectory seal'):
            self.audit(soft_trace=corrupted)

    def test_reject_modified_bound_source_audit(self):
        report = deepcopy(self.report)
        report['movement_audit']['source_revision'] = '0' * 40
        with self.assertRaisesRegex(ValueError, 'custody'):
            self.audit(bound_report=report)

    def test_reject_malformed_native_claims(self):
        for key, value in [('native_material_verified', True),
                           ('model_behavior_verified', True),
                           ('native_undo_executions', 1)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.audit(bound_report={**self.report, key: value})

    def test_reject_budget_and_small_field(self):
        with self.assertRaisesRegex(ValueError, 'budget'):
            self.audit(max_null_shifts=True)
        tiny = struct.pack('<H', 4000)
        report = synthetic_bound(tiny, [stop(1)], [stop(1)], w=1, h=1)
        with self.assertRaisesRegex(ValueError, 'frame'):
            self.audit(guidance_u16le=tiny, free_trace=[stop(1)],
                       soft_trace=[stop(1)], bound_report=report)


if __name__ == '__main__':
    unittest.main()
