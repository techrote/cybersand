#!/usr/bin/env python3
"""Portable evidence integrity and adversarial scalar-accounting checks."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import unittest
import sol_active_normal_live_reduce as r
import sol_active_normal_live_matrix as matrix

ROOT=Path(__file__).resolve().parents[2]
DATA=ROOT/'docs/audits/sol-active-normal-live-20261105'

def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

class LiveEvidence(unittest.TestCase):
    def test_artifact_custody(self):
        manifest=read(DATA/'manifest.json')
        for name,digest in manifest['files'].items():
            self.assertEqual(sha(DATA/name),digest,name)
            self.assertNotIn(b'\r\n',(DATA/name).read_bytes(),name)
        reference=read(DATA/'raw-reference-custody.json')
        self.assertEqual(sha(DATA/reference['public_file']),reference['sha256'])
        old=ROOT/reference['matched_original_reference']
        self.assertEqual(sha(old),reference['matched_original_sha256'])

    def test_complete_compact_coverage(self):
        data=read(DATA/'smoke-steps.json');self.assertEqual(len(data['cases']),8)
        for case in data['cases']:
            self.assertEqual(len(case['boundaries']),900)
            self.assertEqual(len(case['work']),180)
            self.assertEqual(len(case['scalar_rows']),180)
            self.assertEqual(len(case['native_identity_rows']),180)
            self.assertEqual([row[0] for row in case['work']],list(range(180)))
            for step in range(180):
                frames=[dict(zip(case['boundary_columns'],row)) for row in case['boundaries'][step*5:step*5+5]]
                self.assertEqual([f['step'] for f in frames],[step]*5)
                self.assertEqual([f['native_tick'] for f in frames],[step,step,step+1,step+1,step+1])
                self.assertEqual(len({f['world_instance'] for f in frames}),1)
                self.assertEqual(len({f['rid'] for f in frames}),1)
                for f in frames:
                    self.assertFalse(f['hard_exclusions'])
                    self.assertGreaterEqual(f['sand_area'],0)
            self.assertTrue(all(row[-1]==6 for row in case['native_identity_rows']))

    def test_observed_scalar_energy(self):
        data=read(DATA/'raw-reference-closed-driven-active.json')
        rows=r.scalar_audit(data,'active-normal-001')
        self.assertEqual(len(rows),180)
        self.assertEqual(sum(row['arrival_count'] for row in rows),3)
        self.assertEqual(sum(row['arrival_missing'] for row in rows),28980)
        self.assertTrue(all(row['legacy_wrench_f64']==[0,0,0] for row in rows))

    def test_smoke_coordinate_coverage_is_not_full_matrix(self):
        receipt=read(DATA/'smoke-execution.json');coverage=matrix.coverage(receipt)
        self.assertEqual(coverage['expected_coordinates'],8)
        self.assertEqual(coverage['attempted_episodes'],8)
        self.assertTrue(coverage['complete_requested_execution'])
        self.assertFalse(coverage['requested_equals_full_registration'])
        self.assertFalse(coverage['complete_registered_execution'])
        self.assertEqual(len(matrix.coordinates(receipt,True)),240)

    def test_registered_remaining_coordinate_counts(self):
        source=read(DATA/'smoke-execution.json')
        for suite,count in [('authored',192),('workload',72)]:
            data=copy.deepcopy(source);data['matrix'].update(suite=suite,cases='',arms='',platforms='windows,linux',workers='1,4',repeats=3)
            self.assertEqual(len(matrix.coordinates(data)),count)
            self.assertEqual(len(matrix.coordinates(data,True)),count)

    def test_missing_duplicate_and_unknown_coordinates_refused(self):
        source=read(DATA/'smoke-execution.json')
        host=source['hosts']['windows']
        episode=next(c for c in host['commands'] if c.get('reports'))
        missing=copy.deepcopy(source);missing['hosts']['windows']['commands'].remove(episode)
        result=matrix.coverage(missing);self.assertEqual(len(result['missing']),1);self.assertFalse(result['complete_requested_execution'])
        duplicate=copy.deepcopy(source);duplicate['hosts']['windows']['commands'].append(copy.deepcopy(episode))
        result=matrix.coverage(duplicate);self.assertEqual(len(result['duplicates']),1);self.assertFalse(result['complete_requested_execution'])
        unknown=copy.deepcopy(source);bad=copy.deepcopy(episode);bad['name']='unregistered-coordinate'
        unknown['hosts']['windows']['commands'].append(bad)
        result=matrix.coverage(unknown);self.assertEqual(len(result['unexpected']),1);self.assertFalse(result['complete_requested_execution'])

    def test_full_chamber_evidence_scope_and_custody(self):
        custody=read(DATA/'chamber-full-custody.json')
        for artifact in custody['artifacts']:
            self.assertEqual(sha(DATA/artifact['public_file']),artifact['public_lf_sha256'])
        summary=read(DATA/'chamber-full-summary.json')
        self.assertEqual((summary['episodes'],summary['steps'],summary['observation_boundaries']),(240,43200,216000))
        self.assertEqual((summary['forced_strict_clearance_failures'],summary['forced_episodes']),(120,120))
        self.assertTrue(summary['all_exact_tuple_multisets_conserved'])
        self.assertEqual(len(summary['common_initial_inputs']),48)
        self.assertTrue(all(g['matched'] and len(g['initial_payload_sha256'])==1 for g in summary['common_initial_inputs']))
        self.assertTrue(matrix.coverage(read(DATA/'chamber-full-execution.json'))['complete_registered_execution'])
        episodes=read(DATA/'chamber-full-episodes.json');self.assertEqual(len(episodes),240)
        for row in episodes:
            if row['mode']!='LA-SELECTIVE':self.assertIsNone(row['selected_arrivals'])
        self.assertEqual(sum(sum(v['participant_tick_distribution'].values()) for v in summary['worker_participation']),43200)
        self.assertTrue(all(set(v['participant_tick_distribution'])=={'1'} for v in summary['worker_participation']))

    def test_original_per_host_summary_parity(self):
        previous=read(ROOT/'docs/audits/sol-chamber-20261105/episodes.json')['episodes']
        current=read(DATA/'smoke-summary.json')['results']
        fields=['initial','final','maximum_observed_sand_area','maximum_observed_sand_depth',
            'observed_arrivals','candidate_kinetic_delta_sum','force_endpoint_work_estimate_sum','native_counters']
        for row in current:
            if row['normal_policy']!='original':continue
            old=next(v for v in previous if v['platform']==row['platform'] and v['mode']==row['mode']
                and v['case']==row['case'] and v['requested_workers']==row['requested_workers'] and v['repeat']==row['repeat'])
            for field in fields:self.assertEqual(old[field],row[field],(row['name'],field))

    def test_public_raw_geometry_and_recorded_trajectory(self):
        cases={c['name']:c for c in read(DATA/'smoke-steps.json')['cases']}
        for policy,path in [('original',ROOT/'docs/audits/sol-chamber-20261105/raw-reference-closed-driven-selective.json'),
                ('active',DATA/'raw-reference-closed-driven-active.json')]:
            raw=read(path);case=cases['windows-closed-driven-selective-'+policy+'-w1-r0']
            values=struct.unpack('<24d',bytes.fromhex(raw['geometry_f64le']))
            rectangles=[values[i:i+4] for i in range(0,24,4)];r.geometry.CACHE.clear()
            for step in raw['steps']:
                for capture,line in zip(step['boundaries'],case['boundaries'][step['step']*5:step['step']*5+5]):
                    record=dict(zip(case['boundary_columns'],line))
                    self.assertEqual(record['pose_f64le'],capture['state']['pose_f64le'])
                    self.assertEqual(record['velocity_omega_f64le'],capture['state']['velocity_omega_f64le'])
                    independent=r.geometry.geometry(capture,rectangles)
                    self.assertAlmostEqual(record['sand_area'],independent['sand_area'],places=9)
                    self.assertAlmostEqual(record['sand_max_depth'],independent['sand_max_depth'],places=9)
                    self.assertEqual(record['hard_exclusions'],independent['hard_exclusions'])

    def test_seven_corruptions_refused(self):
        source=read(DATA/'raw-reference-closed-driven-active.json')
        def packet(data):return data['steps'][30]['response']
        changes=[lambda d:packet(d).__setitem__('normal_policy','original'),
            lambda d:packet(d)['rows'][0].__setitem__('normal_policy','original'),
            lambda d:packet(d)['rows'][0].__setitem__('passive_energy_before',1),
            lambda d:packet(d)['rows'][0]['passive_raw_wrench_f64'].__setitem__(0,13),
            lambda d:packet(d)['rows'][0]['passive_accepted_wrench_f64'].__setitem__(0,13),
            lambda d:packet(d)['rows'][0].__setitem__('passivity_rejected',True),
            lambda d:packet(d)['rows'][0].__setitem__('updates',1)]
        for index,change in enumerate(changes):
            data=copy.deepcopy(source);change(data)
            with self.subTest(corruption=index),self.assertRaises(AssertionError):r.scalar_audit(data,'active-normal-001')

if __name__=='__main__':unittest.main()
