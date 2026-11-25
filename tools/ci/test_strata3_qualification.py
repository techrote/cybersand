#!/usr/bin/env python3
"""Adverse reader controls; synthetic counters never establish actual rendering."""
import copy
import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import tempfile
import unittest
from unittest.mock import patch

import qualify_strata3_workbench as q
import strata_process_metrics as metrics


def stats():
    return dict(play_processed=False, additional_worlds=0, additional_viewports=0,
                additional_textures=0, native_captures=0, native_writes=0,
                texture_uploads=0, material_count=0, uniform_writes=0,
                active=False, active_planes=[])


def population():
    # Explicitly synthetic small populations exercise the retained reader only.
    result = {'progression_registration':{'repeats':3,'callbacks_per_sample':90,
        'per_sample_watchdog_usec':90000000,'order':'forward/reverse/forward',
        'geometry_reset_between_samples':True,
        'quality_by_profile':{name:('high' if name=='diorama' else 'balanced') for name in q.PROGRESSION_PROFILES}},'progression_samples':[]}
    identity = dict(worker_id='worker',world_generation=1,physical_epoch=1,
                    actor_session_id='session',actor_body_ids=['body'],native_tick=0,rapier_tick=0)
    for repeat in range(3):
        for profile in q.PROGRESSION_PROFILES[::-1] if repeat % 2 else q.PROGRESSION_PROFILES:
            after = dict(identity,native_tick=3,rapier_tick=3)
            completed = [dict(rapier_tick=i,completed_usec=i*50000) for i in range(1,4)]
            callbacks = [5000]*90
            sample = dict(profile=profile,repeat=repeat,configuration={'profile':profile},quality='high' if profile=='diorama' else 'balanced',
                initial_native_play_sha256='a'*64,callbacks=90,elapsed_usec=500000,
                native_capture_delta=0,decorative_upload_delta=0,physical_gpu_acceptance=False,
                before=identity.copy(),after=after,completed_physical_steps=completed,
                physical_intervals_usec=[50000,50000],physical_distribution_usec=q.distribution([50000,50000]),
                callback_intervals_usec=callbacks,callback_distribution_usec=q.distribution(callbacks),godot_process_ms=[.2]*90,
                native_publications=[dict(native_tick=i,published_usec=(i+1)*50000) for i in range(3)],
                native_publication_interval_distribution_usec=q.distribution([50000,50000]),
                native_ticks_per_second=6.,rapier_ticks_per_second=6.,
                actor_position_before=[0.,0.],actor_position_after=[1.,0.],actor_distance_cells=1.,
                scene_admission_elapsed_ms=45001,scene_admission_target_met=False,optical_statistics=stats())
            result['progression_samples'].append(sample)
    return result


class OpticalEvidenceReader(unittest.TestCase):
    def test_complete_synthetic_population_is_reader_input_only(self):
        q.validate_progression(population())

    def test_incomplete_or_forged_physical_receipts_refuse(self):
        mutations = {
            'missing_window':lambda r:r['progression_samples'].pop(),
            'duplicate_window':lambda r:r['progression_samples'].__setitem__(1,copy.deepcopy(r['progression_samples'][0])),
            'wrong_order':lambda r:r['progression_samples'].reverse(),
            'no_geometry_reset':lambda r:r['progression_registration'].__setitem__('geometry_reset_between_samples',False),
            'different_geometry':lambda r:r['progression_samples'][1].__setitem__('initial_native_play_sha256','b'*64),
            'missing_completed_steps':lambda r:r['progression_samples'][0].__setitem__('completed_physical_steps',[]),
            'completion_gap':lambda r:r['progression_samples'][0]['completed_physical_steps'][1].__setitem__('rapier_tick',8),
            'forged_intervals':lambda r:r['progression_samples'][0]['physical_intervals_usec'].__setitem__(0,1),
            'forged_percentile':lambda r:r['progression_samples'][0]['physical_distribution_usec'].__setitem__('p95',1),
            'forged_stall_count':lambda r:r['progression_samples'][0]['physical_distribution_usec']['stalls_at_least_usec'].__setitem__('100000',8),
            'missing_callback':lambda r:r['progression_samples'][0]['callback_intervals_usec'].pop(),
            'missing_native_publications':lambda r:r['progression_samples'][0].__setitem__('native_publications',[]),
            'fake_progress_rate':lambda r:r['progression_samples'][0].__setitem__('rapier_ticks_per_second',60.),
            'new_native_owner':lambda r:r['progression_samples'][0]['after'].__setitem__('worker_id','other'),
            'new_native_capture':lambda r:r['progression_samples'][0].__setitem__('native_capture_delta',1),
            'new_material_upload':lambda r:r['progression_samples'][0].__setitem__('decorative_upload_delta',1),
            'static_actor':lambda r:r['progression_samples'][0].__setitem__('actor_distance_cells',0.),
            'fake_actor_motion':lambda r:r['progression_samples'][0].__setitem__('actor_distance_cells',100.),
            'weaken_admission':lambda r:r['progression_samples'][0].__setitem__('scene_admission_target_met',True),
            'physical_acceptance_claim':lambda r:r['progression_samples'][0].__setitem__('physical_gpu_acceptance',True),
            'different_profile':lambda r:r['progression_samples'][0]['configuration'].__setitem__('profile','diorama'),
            'nonfinite_elapsed':lambda r:r['progression_samples'][0].__setitem__('elapsed_usec',float('nan')),
            'classic_shader_work':lambda r:r['progression_samples'][0]['optical_statistics'].__setitem__('uniform_writes',1),
            'play_processed':lambda r:r['progression_samples'][0]['optical_statistics'].__setitem__('play_processed',True),
            'extra_world':lambda r:r['progression_samples'][0]['optical_statistics'].__setitem__('additional_worlds',1),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                result=population();mutate(result)
                with self.assertRaises((RuntimeError,ValueError,KeyError,TypeError)):q.validate_progression(result)

    def test_headless_never_satisfies_graphical_result(self):
        result=dict(schema='strata3-workbench-execution-v1',completed=True,failures=[],checks=1,
                    scene='industrial-underworks',phase='install',source_revision='a'*40,
                    ordinary_workbench=True,diagnostic_headless=True,display_server='headless',rendering_method='gl_compatibility')
        with self.assertRaisesRegex(RuntimeError,'graphical Workbench'):q.validate_result(result,'industrial-underworks','install','a'*40)

    def test_incomplete_motion_cannot_count_as_a_successful_sequence(self):
        for result in ({}, {'motion_sequences':[]}, {'motion_registration':{'profiles':list(q.MOTION_PROFILES),
                'frames_per_sequence':10,'actor_count':3,'actor_variant':[{}, {}, {}],
                'presentation_variant':{'parallax_strength':.65,'layer_depths':{'scripted':.15,'effects':.4,'background':.7}}},
                'motion_sequences':[]}):
            with self.subTest(result=result),self.assertRaises(RuntimeError):q.validate_motion(result)

    def test_evidence_paths_remain_relative_and_platform_independent(self):
        for host in (PurePosixPath, PureWindowsPath):
            with patch.object(q, 'Path', host):
                for value in ['', '../outside.png', '/outside.png', 'C:/outside.png',
                              'scene\\result.json', '//server/share.png', './result.json',
                              'scene//result.json', 'scene/./result.json', 'scene/../result.json',
                              'scene/\x00result.json']:
                    with self.subTest(host=host.__name__,value=value),self.assertRaises(RuntimeError):
                        q.safe_relative(value)
                self.assertEqual(q.safe_relative('scene/install/result.json').as_posix(),
                                 'scene/install/result.json')
        self.assertEqual(q.safe_relative('scene/install/result.json'),Path('scene/install/result.json'))

    def test_legacy_process_watchdog_remains600_unless_explicit(self):
        with tempfile.TemporaryDirectory() as directory:
            for timeout,limit in ((601,600),(1801,1800),(1,1801),(float('nan'),600)):
                with self.subTest(timeout=timeout,limit=limit),self.assertRaises(RuntimeError):
                    metrics.execute([],Path(directory)/'never-created',{},timeout,maximum_timeout=limit)
            self.assertFalse((Path(directory)/'never-created').exists())


if __name__=='__main__':unittest.main()
