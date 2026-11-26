"""Synthetic, non-runtime REC-001 v2 event-indexer tests."""
import copy
import hashlib
import json
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools' / 'recording'))
from index_rec001_events import EvidenceError, extract_session, main, render_svg


def save(root, name, value):
    (root / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def make_fixture(root, drops=1):
    roi = [-4, 7, 4, 2]
    manifest = {
        'schema_id': 'cybersand-state-recording-v2', 'schema_version': 2,
        'evidence_kind': 'simulation-state-evidence-not-exact-replay', 'disposition': 'complete',
        'identity': {'source': {'source_revision': 'SYNTHETIC-NOT-RUNTIME'}},
        'session': {'name': 'synthetic-review', 'start_monotonic_usec': 300000},
        'configuration': {'roi': roi, 'retain_raw_ids': True, 'capture_hz': 15},
        'counters': {'written_frames': 4, 'enqueued_frames': 4,
                     'capture_attempts': 4 + drops, 'dropped_frames': drops},
        'drops': {'retained': [{'attempt': 3, 'reason': 'queue-full',
                               'capture_observed_monotonic_usec': 330000}] if drops else [],
                  'omitted_count': 0}
    }
    save(root, 'recording.json', manifest)
    ids = [bytes([0] * 8), bytes([0] * 8), bytes([0, 0, 0, 0, 0, 0, 0, 3]), bytes([0, 0, 0, 0, 0, 0, 0, 3])]
    for n in range(1, 5):
        stem = f'frame-{n:06d}'
        meta = {'schema_id': manifest['schema_id'], 'evidence_kind': manifest['evidence_kind'],
                'frame_index': n, 'recording_roi': roi, 'elapsed_monotonic_usec': n * 20000,
                'material_generation': {'render_snapshot_serial': 1 if n <= 2 else 2,
                                        'completed_simulation_tick': 10 if n <= 2 else 12},
                'actor_sample': {'snapshot_serial': n, 'completed_simulation_tick': 10 + n},
                'player': {'origin': [1 if n == 1 else 2, 2], 'representation': 'sampled-baseline'},
                'rigid_bodies': [{'id': 7, 'center': [2 if n <= 3 else 3, 4]}],
                'scenario': {'id': 'synthetic-falling-material'},
                'worker_count': 4, 'backend': 'SyntheticNeverExecuted',
                'material_ids_file': stem + '.ids', 'review_bitmap_file': stem + '.bmp'}
        save(root, stem + '.json', meta)
        (root / (stem + '.ids')).write_bytes(ids[n-1])
    return manifest


class IndexTests(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.root = Path(self.t.name) / 'session'
        self.root.mkdir()
        self.manifest = make_fixture(self.root)

    def tearDown(self):
        self.t.cleanup()

    def mutate_frame(self, n, op):
        file = self.root / f'frame-{n:06d}.json'
        value = json.loads(file.read_text())
        op(value)
        save(self.root, file.name, value)

    def mutate_manifest(self, op):
        value = json.loads((self.root / 'recording.json').read_text())
        op(value)
        save(self.root, 'recording.json', value)

    def test_timing_distinguishes_material_and_actor_generations(self):
        r = extract_session(self.root)
        self.assertEqual(r['counter_summary']['material_generation_reused_frames'], 2)
        material = [e for e in r['events'] if e['kind'] == 'material-change-observed']
        self.assertEqual(len(material), 1)
        self.assertEqual(material[0]['changed_cells'], 1)
        self.assertEqual(material[0]['world_bbox_inclusive'], [-1, 8, -1, 8])
        self.assertEqual(material[0]['from_material_tick'], 10)
        self.assertEqual(material[0]['to_material_tick'], 12)
        player = [e for e in r['events'] if e['kind'] == 'player-displacement-observed']
        self.assertEqual(len(player), 1)
        self.assertEqual(player[0]['frame'], 2)
        self.assertEqual(player[0]['distance_cells'], 1)
        body = [e for e in r['events'] if e['kind'] == 'rigid-displacement-observed']
        self.assertEqual(len(body), 1)
        self.assertEqual(body[0]['frame'], 4)
        self.assertEqual(r['frames'][1]['material_tick'], 10)
        self.assertEqual(r['frames'][1]['actor_tick'], 12)
        self.assertEqual(r['frames'][2]['worker_count_claim'], 4)
        self.assertEqual(r['provenance_status'], 'unverified')
        self.assertEqual(r['semantics'], 'observation-only-not-exact-replay')

    def test_drop_capture_clock_and_svg(self):
        r = extract_session(self.root)
        d = [e for e in r['events'] if e['kind'] == 'capture-drop-recorded'][0]
        self.assertEqual(d['observed_elapsed_usec'], 30000)
        svg = render_svg(r)
        ET.fromstring(svg)
        self.assertIn('recorded capture drop attempt 3', svg)
        self.assertIn('Separate material / actor clocks', svg)

    def test_manifest_sha_and_raw_inputs_unchanged(self):
        before = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in self.root.iterdir()}
        r = extract_session(self.root)
        self.assertEqual(r['input_manifest_sha256'], before['recording.json'])
        self.assertEqual(before['frame-000001.ids'], r['frames'][0]['ids_sha256'])
        self.assertEqual(before, {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in self.root.iterdir()})

    def test_cli_creates_output_and_refuses_overwrite(self):
        output = Path(self.t.name) / 'output'
        self.assertEqual(main([str(self.root), str(output)]), 0)
        self.assertTrue((output / 'events.json').exists())
        ET.parse(output / 'timeline.svg')
        self.assertEqual(main([str(self.root), str(output)]), 2)

    def test_raw_id_changes_under_reused_generation_refused(self):
        (self.root / 'frame-000002.ids').write_bytes(bytes([1] * 8))
        with self.assertRaisesRegex(EvidenceError, 'without generation'):
            extract_session(self.root)

    def test_material_tick_changes_without_serial_refused(self):
        self.mutate_frame(2, lambda d: d['material_generation'].update(completed_simulation_tick=11))
        with self.assertRaisesRegex(EvidenceError, 'unchanged serial'):
            extract_session(self.root)

    def test_actor_pose_changes_without_sample_refused(self):
        self.mutate_frame(2, lambda d: d['actor_sample'].update(snapshot_serial=1, completed_simulation_tick=11))
        with self.assertRaisesRegex(EvidenceError, 'actor pose changed'):
            extract_session(self.root)

    def test_sample_goes_backwards_refused(self):
        self.mutate_frame(3, lambda d: d['actor_sample'].update(completed_simulation_tick=9))
        with self.assertRaises(EvidenceError):
            extract_session(self.root)

    def test_missing_raw_file_and_path_escape_refused(self):
        self.mutate_frame(1, lambda d: d.update(material_ids_file='../leak.ids'))
        with self.assertRaisesRegex(EvidenceError, 'invalid raw ID reference'):
            extract_session(self.root)
        self.mutate_frame(1, lambda d: d.update(material_ids_file='frame-000001.ids'))
        (self.root / 'frame-000001.ids').unlink()
        with self.assertRaisesRegex(EvidenceError, 'missing/unsafe file'):
            extract_session(self.root)

    def test_wrong_roi_and_truncation_refused(self):
        self.mutate_frame(3, lambda d: d.update(recording_roi=[0, 0, 10, 10]))
        with self.assertRaisesRegex(EvidenceError, 'ROI changed'):
            extract_session(self.root)
        self.mutate_frame(3, lambda d: d.update(recording_roi=[-4, 7, 4, 2]))
        (self.root / 'frame-000003.ids').write_bytes(b'1')
        with self.assertRaisesRegex(EvidenceError, 'wrong raw ID payload'):
            extract_session(self.root)

    def test_negative_review_counter_fixture_refused(self):
        self.mutate_manifest(lambda d: d['counters'].update(capture_attempts=4))
        with self.assertRaisesRegex(EvidenceError, 'complete capture counters inconsistent'):
            extract_session(self.root)

    def test_counter_drop_record_disagreement_refused(self):
        self.mutate_manifest(lambda d: d['drops'].update(retained=[]))
        with self.assertRaisesRegex(EvidenceError, 'drop ledger inconsistent'):
            extract_session(self.root)

    def test_bounded_ledger_omissions_are_explicit(self):
        self.mutate_manifest(lambda d: (d['counters'].update(capture_attempts=6, dropped_frames=2),
                                        d['drops'].update(omitted_count=1)))
        r = extract_session(self.root)
        self.assertEqual([e['kind'] for e in r['events']][-1], 'capture-drop-events-omitted')

    def test_incomplete_session_preserves_disposition(self):
        self.mutate_manifest(lambda d: (d.update(disposition='incomplete'),
                                        d['counters'].update(enqueued_frames=5, capture_attempts=6)))
        self.assertEqual(extract_session(self.root)['disposition'], 'incomplete')

    def test_duplicate_body_id_refused(self):
        self.mutate_frame(3, lambda d: d['rigid_bodies'].append(copy.deepcopy(d['rigid_bodies'][0])))
        with self.assertRaisesRegex(EvidenceError, 'duplicate rigid body'):
            extract_session(self.root)

    def test_symlinked_input_refused(self):
        (self.root / 'frame-000002.ids').unlink()
        (self.root / 'frame-000002.ids').symlink_to(self.root / 'frame-000001.ids')
        with self.assertRaisesRegex(EvidenceError, 'missing/unsafe file'):
            extract_session(self.root)

    def test_extreme_roi_budget_refused(self):
        self.mutate_manifest(lambda d: d['configuration'].update(roi=[-4, 7, 65536, 65536]))
        with self.assertRaisesRegex(EvidenceError, 'ROI cell budget exceeded'):
            extract_session(self.root)

    def test_scenario_switch_bookmarked(self):
        self.mutate_frame(4, lambda d: d['scenario'].update(id='synthetic-other-scene'))
        r = extract_session(self.root)
        self.assertEqual(len([e for e in r['events'] if e['kind']=='scenario-identity-change-observed']), 1)


if __name__ == '__main__':
    unittest.main()
