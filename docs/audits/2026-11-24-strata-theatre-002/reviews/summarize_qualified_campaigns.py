#!/usr/bin/env python3
"""Extract exact qualification/cost observations from source-admitted campaigns."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import sys


def counters(process):
    resources = process['resources']
    return {'elapsed_seconds': process['seconds'], 'observed_process_tree_cpu_seconds': resources['observed_cpu_seconds'],
            'sampled_peak_process_tree_rss_bytes': resources['peak_observed_tree_rss_bytes'],
            'sample_count': resources['sample_count'], 'sample_interval_seconds': resources['sample_interval_seconds'],
            'resource_scope': resources['scope'], 'resource_semantics': resources['semantics']}


def interval_summary(sample):
    values = sorted(sample['callback_intervals_usec'])
    assert values
    expected = {'callback_p50_usec': values[len(values)//2],
                'callback_p95_usec': values[min(len(values)-1, math.ceil(len(values)*0.95)-1)],
                'callback_max_usec': values[-1]}
    assert all(sample[key] == value for key,value in expected.items())
    return {'mode':sample['mode'], 'atmosphere_enabled':sample['atmosphere_enabled'],
            'elapsed_usec':sample['elapsed_usec'], 'interval_samples':len(values), **expected,
            'callback_intervals_usec':sample['callback_intervals_usec'],
            'godot_tracked_static_memory_bytes':sample['godot_tracked_static_memory_bytes'],
            'native_snapshots_during_sample':sample['native_snapshots_during_sample'],
            'decorative_uploads_during_sample':sample['decorative_uploads_during_sample'],
            'resource_state':sample['resource_state'], 'scope':sample['scope']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository',type=Path,required=True)
    parser.add_argument('--campaign',type=Path,action='append',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    sys.path.insert(0,str(args.repository/'tools/ci'))
    import qualify_strata2_workbench as q
    source=q.identity()
    campaigns=[]
    for folder in args.campaign:
        report=q.verify_campaign(folder,source)
        scenes=[]
        for entry in report['scenes']:
            install=entry['phases']['install']; reopen=entry['phases']['reopen']
            result=install['result']; fresh=reopen['result']; route=result['route_probe']
            scenes.append({'scene':entry['name'],'extent':result['extent'],'status':entry['status'],
                'renderer':result['rendering_adapter'],'checks':{'install':result['checks'],'reopen':fresh['checks']},
                'admission_ms':{'install':result['admission_elapsed_ms'],'reopen':fresh['admission_elapsed_ms']},
                'admission_target_met':{'install':result['admission_target_met'],'reopen':fresh['admission_target_met']},
                'process_resources':{'install':counters(install['process']),'reopen':counters(reopen['process'])},
                'cold_ordinary_baseline':result['ordinary_disabled_baseline'],
                'matched_cost_samples':[interval_summary(sample) for sample in result['cost_samples']],
                'route':{'completed_native_ticks':route['completed_native_ticks'],'completed_rapier_ticks':route['completed_rapier_ticks'],
                    'elapsed_usec':route['elapsed_usec'],'callbacks':route['callbacks'],'forward_cells':route['forward_cells'],
                    'identity_before':route['before'],'identity_after':route['after'],'live_decorative_edit':route['live_decorative_edit'],
                    'scope':'End-to-end finite route-trial wall time including resume, real pilot inputs, mode/atmosphere toggles, native decorative edit/Undo and final pause settling; not isolated native tick cost, the complete authored route or a physical GPU frame metric.'},
                'atmosphere':{'visible_pixels':result['atmosphere']['visual_difference'],
                    'solo_leakage':result['atmosphere']['solo_leakage'],'native_capture_delta':result['atmosphere']['native_capture_delta'],
                    'native_hashes_before':result['atmosphere']['native_hashes_before'],'native_hashes_after':result['atmosphere']['native_hashes_after']},
                'transform_witness':result['transforms'],'native_grid_details':result['native_grid_details'],
                'background_pixel_oracle':result.get('play_visibility_pixels',{}).get('background_probe'),
                'composition_review':result.get('composition_review'), 'reference_import':result.get('reference_import'),
                'fresh_process':{'different_processes':result['process_id'] != fresh['process_id'],
                    'native_hashes_equal':result['plane_native_hashes'] == fresh['plane_native_hashes'],
                    'authored_settings_equal':result['authored_settings_sha256'] == fresh['authored_settings_sha256'],
                    'explicit_saved_authoring_equal':result['saved_authoring'] == fresh['saved_authoring'],
                    'save_sha256':result['save']['sha256'],'saved_authoring':result['saved_authoring']},
                'final_owner_diagnostics':result['final_diagnostics']['layers']})
        campaigns.append({'platform':report['platform'],'folder':str(folder),'original_report_sha256':q.sha(folder/'qualification.json'),
            'elapsed_seconds':report['elapsed_seconds'],'cases':len(report['cases']),
            'cases_resources':{case['label']:counters(case) for case in report['cases']},
            'maximum_paused':{'result':report['maximum']['result'],'resources':counters(report['maximum']['process'])},
            'scenes':scenes})
    data={'schema':'strata2-qualified-observations-v1','source_commit':source['source_commit'],'source_tree':source['source_tree'],
        'prospective_targets':q.PROSPECTIVE_TARGETS,'campaigns':campaigns,
        'interpretation':[
            'Every input campaign passed the exact frozen source verifier before observations were extracted.',
            'The four matched samples use one loaded scene in sequential disabled, flat, stack static and stack animated windows of45 callbacks; p50 uses the frozen harness upper-middle order statistic and p95 nearest-rank.',
            'Loaded-disabled samples retain three decorative Worlds and surfaces. Cold ordinary baseline is512x512 before Strata allocation, not matched scene memory.',
            'Per-case CPU and sampled peak RSS cover the entire process/descendants, including setup, hashing, captures, previews and Save. They do not isolate marginal Strata memory or GPU residency.',
            'Native/copy/upload counters describe observed work/traffic, not texture GPU residency. Independent candidate-allocation peaks were not measured.',
            'Actual native/Rapier completed counters are recorded over the end-to-end route trial, including resume, pilot inputs, toggles, decorative edit/Undo and final pause settling. This is not isolated native tick cost. No callback interval or hosted software-renderer result is presented physical NVIDIA FPS.',
            'Maximum2048x2048 qualification is paused. No sustained dense maximum-size Play or independently dynamic decorative native World is qualified.',
            'Physical Windows11/NVIDIA appearance, input response, real movement and aesthetic acceptance remain owner gates.'
        ]}
    args.output.write_text(json.dumps(data,indent=2)+'\n')
    lines=['# Strata Theatre002 qualified cost and execution observations','',
           'Application`'+source['source_commit']+'`; tree`'+source['source_tree']+'`.','',
           'These observations are extracted from original source-admitted reports. The JSON companion retains raw callback intervals, original report hashes, process counters, native identities and precise scopes.','']
    for campaign in campaigns:
        lines += ['## '+campaign['platform']+' — '+campaign['folder'],'',
                  '| Scene | Admission install/reopen s (45s target) | Install wall/observed CPU s | Install sampled RSS GiB | Stack static/animated callback p50 ms | Native/Rapier ticks and end-to-end route wall s |',
                  '|---|---:|---:|---:|---:|---:|']
        for row in campaign['scenes']:
            resources=row['process_resources']['install']; costs=row['matched_cost_samples']; route=row['route']
            static=next(v for v in costs if v['mode']=='stack' and not v['atmosphere_enabled'])
            animated=next(v for v in costs if v['mode']=='stack' and v['atmosphere_enabled'])
            admission='/'.join(f"{row['admission_ms'][phase]/1000:.3f} ({'met' if row['admission_target_met'][phase] else 'MISS'})" for phase in ('install','reopen'))
            lines.append('| '+row['scene']+' | '+admission+' | '+f"{resources['elapsed_seconds']:.3f}/{resources['observed_process_tree_cpu_seconds']:.3f}"+' | '+f"{resources['sampled_peak_process_tree_rss_bytes']/1024**3:.3f}"+' | '+f"{static['callback_p50_usec']/1000:.3f}/{animated['callback_p50_usec']/1000:.3f}"+' | '+f"{route['completed_native_ticks']}/{route['completed_rapier_ticks']} in{route['elapsed_usec']/1e6:.3f}"+' |')
        lines += ['', 'All unchanged static/animated windows must retain zero additional decorative native captures and uploads. See the original raw observations for p95/max, flat/loaded-disabled controls, per-case resources and admission misses.','']
    lines += ['## Interpretation and limits','']+['- '+line for line in data['interpretation']]+['']
    args.output.with_suffix('.md').write_text('\n'.join(lines))
    print(json.dumps({'source_commit':source['source_commit'],'campaigns':len(campaigns),'output':str(args.output),'status':'passed'}))


if __name__=='__main__': main()
