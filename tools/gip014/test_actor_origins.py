"""Artificial actor-origin oracle controls; no native gameplay claim."""
import copy
import struct
import unittest

import verify_transcript as evidence


def record(action='actor_place', model='monowheel'):
    root = [120.0, 97.5 if model == 'monowheel' else 96.0]
    body = {'position': root[:], 'retained_parts': [{'position': root[:]}]}
    if model == 'monowheel':
        body['retained_parts'].append({'position': [120.0, 96.0]})
    actor = {'id': 1, 'model': model, 'observed': True, 'position': root[:],
             'authored_spawn': [120.0, 96.0], 'state': body}
    before = {'adapter_version': 2, 'native': {'generation': 1, 'revision': 1, 'tick': 0, 'failed': False},
              'actors': [copy.deepcopy(actor)], 'actor_ids': [1], 'selected_actor': 1, 'next_actor_id': 2}
    after = copy.deepcopy(before)
    after['native']['generation'] = 2
    args = {'model': model, 'x': 120, 'y': 96} if action == 'actor_place' else ({'x': 120, 'y': 96} if action == 'actor_move' else {})
    if action == 'actor_place':
        before.update(actors=[], actor_ids=[], next_actor_id=1)
    if action == 'actor_replace':
        before['actors'][0]['model'] = 'runner'
        after['actors'][0]['id'] = 2
        after['actor_ids'] = [2]
        args = {'model': model}
    return {'index': 0, 'action': {'id': action, 'args': args}, 'before': before, 'after': after,
            'status': 'completed', 'classification': 'game_observation', 'interval': {},
            'actor_authoring': {'spawn': [120.0, 96.0], 'authored_after': {'spawn': [120.0, 96.0]}, 'body': copy.deepcopy(body)}}


def failures(row, version=2):
    return {f['id'] for f in evidence.independent_failures({'header': {'fixture_version': version}, 'steps': [row]})}


class ActorOriginControls(unittest.TestCase):
    def test_all_supported_origins_and_wrong_physical_root(self):
        self.assertEqual(set(evidence.ACTOR_ROOT_OFFSETS), set(evidence.MODELS))
        for model in evidence.ACTOR_ROOT_OFFSETS:
            with self.subTest(model=model):
                row = record(model=model)
                self.assertEqual(failures(row), set())
                row['after']['actors'][0]['position'][1] += 0.25
                self.assertIn('actor_place_position', failures(row))

    def test_authored_and_part_tampering_cannot_hide_behind_correct_root(self):
        row = record()
        row['after']['actors'][0]['authored_spawn'][1] += 0.25
        self.assertIn('actor_place_authored_spawn', failures(row))
        for part in (0, 1):
            row = record()
            row['after']['actors'][0]['state']['retained_parts'][part]['position'][1] += 0.25
            self.assertIn('actor_place_part_origins', failures(row))
        row = record()
        del row['after']['actors'][0]['state']['retained_parts']
        self.assertIn('actor_place_part_origins', failures(row))

    def test_reset_move_replace_use_model_origin(self):
        names = {'actor_reset': 'actor_reset_authored_position', 'actor_move': 'actor_move_actual_position',
                 'actor_replace': 'actor_replacement_position'}
        for action, expected in names.items():
            with self.subTest(action=action):
                row = record(action)
                self.assertEqual(failures(row), set())
                row['after']['actors'][0]['position'][1] = 96.0
                self.assertIn(expected, failures(row))

    def test_legacy_zero_offset_observation_has_no_invented_part_requirement(self):
        row = record(model='runner')
        row['before']['adapter_version'] = row['after']['adapter_version'] = 1
        del row['after']['actors'][0]['state']
        del row['after']['actors'][0]['authored_spawn']
        del row['actor_authoring']
        self.assertEqual(failures(row, version=1), set())
        self.assertIn('actor_place_part_origins', failures(row, version=2))
        row['after']['actors'][0]['position'][1] += 0.25
        self.assertIn('actor_place_position', failures(row, version=1))

    def test_exact_float_boundary_and_malformed_origins(self):
        self.assertEqual(evidence.actor_origin_root('monowheel', [120, 96]), [120.0, 97.5])
        self.assertEqual(evidence.actor_origin_root('monowheel', [120, 127.99]), [120.0, 129.489990234375])
        for point in ([True, 96], [120, float('nan')], [120, float('inf')], [120, 10**1000], [120], '120,96'):
            self.assertEqual(evidence.actor_origin_root('monowheel', point), [])
        self.assertEqual(evidence.actor_origin_root('invented', [120, 96]), [])
        self.assertEqual(evidence.actor_origin_root({}, [120, 96]), [])

    def test_actual_json_spelling_preserves_exact_native_position(self):
        # Coordinate spelling from the request-4 actual expanded Capture row.
        spawn = [95.8000030517578, 224.130004882813]
        root = evidence.actor_origin_root('monowheel', spawn)
        published_root = [95.8000030517578, 225.630004882813]
        self.assertNotEqual(root, published_root)
        self.assertTrue(evidence.actor_point_matches(published_root, root))
        row = record('actor_reset')
        row['before']['actors'][0]['authored_spawn'] = spawn[:]
        actor = row['after']['actors'][0]
        actor.update(authored_spawn=spawn[:], position=published_root[:])
        actor['state'] = {'position': published_root[:], 'retained_parts': [
            {'position': published_root[:]}, {'position': spawn[:]}]}
        row['actor_authoring'] = {'spawn': spawn[:], 'body': copy.deepcopy(actor['state'])}
        self.assertEqual(failures(row), set())
        bits = struct.unpack('<I', struct.pack('<f', root[1]))[0]
        actor['position'][1] = struct.unpack('<f', struct.pack('<I', bits + 1))[0]
        self.assertIn('actor_reset_authored_position', failures(row))
        self.assertFalse(evidence.actor_point_matches([True, 96], [1, 96]))
        self.assertFalse(evidence.actor_point_matches([0, 10**1000], [0, 0]))


if __name__ == '__main__':
    unittest.main()
