#!/usr/bin/env python3
"""Independently recompute retained Strata campaign observations from raw data.

This is a read-only evidence audit. The original source-bound graphical/package
verifier remains a separate gate. No Godot execution or GPU measurement occurs.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import re

SOURCE='934cc0c0eef70dad528155e9a92eebe25e2757eb'
TREE='0c30ea3eaea61c5091c23b984837f29d7b7c828e'
PLANES={'play','scripted','effects','background'}
SCENES={'orbital-terminal','neon-rain-arcology','industrial-underworks','abyss-foundry','vertical-transfer-spine'}

def sha(path):
    digest=hashlib.sha256()
    with path.open('rb') as handle:
        for block in iter(lambda:handle.read(1024*1024),b''):digest.update(block)
    return digest.hexdigest()

def require(condition,message):
    if not condition: raise ValueError(message)

def hashes(value):
    return isinstance(value,dict) and set(value)==PLANES and all(re.fullmatch(r'[0-9a-f]{64}',str(v)) for v in value.values())

def interval(sample):
    raw=sample['callback_intervals_usec']
    require(isinstance(raw,list) and len(raw)>0 and all(type(v) in (int,float) and math.isfinite(v) and v>0 for v in raw),'Invalid raw callback intervals')
    values=sorted(raw); n=len(values)
    derived={'callback_p50_usec':values[n//2], 'callback_p95_usec':values[math.ceil(n*0.95)-1], 'callback_max_usec':values[-1]}
    require(all(sample[k]==v for k,v in derived.items()),'Recorded percentiles differ from actual raw callback order statistics')
    require(sample['native_snapshots_during_sample']==0 and sample['decorative_uploads_during_sample']==0,'Unchanged decoration recaptured native cells or uploaded textures')
    return {'mode':sample['mode'],'atmosphere_enabled':sample['atmosphere_enabled'],'interval_count':n,
        **derived,'window_elapsed_usec':sample['elapsed_usec'],'raw_intervals_usec':raw,
        'native_snapshot_delta':sample['native_snapshots_during_sample'],'decorative_upload_delta':sample['decorative_uploads_during_sample'],
        'godot_tracked_static_memory_bytes':sample['godot_tracked_static_memory_bytes'],
        'scope':'Sequential paused-scene callback window; p50 upper-middle and p95 nearest-rank. No presented physical GPU FPS or steady-state Play throughput.'}

def resource(folder,case):
    location=folder/case['label']
    path=location/'resources.json'; raw=json.loads(path.read_text())
    require(sha(path)==case['resources_sha256'],'Resource receipt hash changed: '+case['label'])
    require({k:v for k,v in raw.items() if k!='samples'}==case['resources'],'Embedded resource summary differs from original raw receipt')
    require(raw['sample_count']==len(raw['samples']) and raw['sample_count']>0,'Resource sample count mismatch')
    latest={}; peaks=[]
    for sample in raw['samples']:
        rss=0
        active=set()
        for row in sample['processes']:
            require(type(row['pid']) is int and row['pid']>0 and type(row['start_id']) is int and row['start_id']>0,'Invalid observed process identity')
            require(type(row['cpu_seconds']) in (int,float) and math.isfinite(row['cpu_seconds']) and row['cpu_seconds']>=0,'Invalid observed CPU counter')
            require(type(row['rss_bytes']) is int and row['rss_bytes']>=0,'Invalid observed resident byte count')
            identity=(row['pid'],row['start_id']); cpu=row['cpu_seconds']; rss+=row['rss_bytes']
            require(identity not in active,'Duplicate observed process in one simultaneous sample')
            active.add(identity)
            require(identity not in latest or cpu>=latest[identity],'Observed process CPU counter regressed')
            latest[identity]=cpu
        require(rss==sample['tree_rss_bytes'],'Simultaneous RSS does not equal its recorded process rows')
        require(math.isclose(sum(latest.values()),sample['tree_cpu_seconds_observed'],abs_tol=1e-6,rel_tol=1e-9),'Cumulative observed CPU does not equal last valid per-process counters')
        peaks.append(rss)
    require(max(peaks)==raw['peak_observed_tree_rss_bytes'],'Peak RSS differs from observed sample maximum')
    require(math.isclose(sum(latest.values()),raw['observed_cpu_seconds'],abs_tol=1e-6,rel_tol=1e-9),'CPU total differs from reconstructed last per-process observations')
    require({tuple(v) for v in raw['process_identities']}==set(latest),'Recorded observed process identities differ from raw samples')
    return {'whole_process_elapsed_seconds':case['seconds'],'observed_process_tree_cpu_seconds':sum(latest.values()),
        'sampled_peak_process_tree_rss_bytes':max(peaks),'samples':len(peaks),'sample_interval_seconds':raw['sample_interval_seconds'],
        'original_resources_sha256':sha(path),'scope':raw['scope'],'semantics':raw['semantics'],'observation_errors':raw['observation_errors']}

def campaign(folder):
    path=folder/'qualification.json'; original=json.loads(path.read_text())
    require(original['source_commit']==SOURCE and original['source_tree']==TREE,'Wrong frozen source')
    require(original['status']=='passed' and original['completed'] is True and original['input_custody']=='passed' and original['local_delta']==[],'Only original completed source-admitted campaigns may be summarized')
    require(original['prospective_targets']['scene_admission_callback_ms']==45000,'Admission target changed')
    require({s['name'] for s in original['scenes']}==SCENES and len(original['scenes'])==5,'Incomplete scene coverage')
    resources={case['label']:resource(folder,case) for case in original['cases']}
    rows=[]
    for scene in original['scenes']:
        require(scene['status']=='passed' and set(scene['phases'])=={'install','reopen'},'Incomplete scene pair')
        states={}
        admissions={}
        for phase in ('install','reopen'):
            receipt=scene['phases'][phase]; result_path=folder/scene['name']/(phase+'.json')
            require(sha(result_path)==receipt['report_sha256'],'Original phase result changed')
            result=json.loads(result_path.read_text());require(result==receipt['result'],'Original/embedded result mismatch')
            require(result['source_revision']==SOURCE and result['completed'] is True and result['failures']==[],'Failed or unbound execution result')
            require(result['admission_target_ms']==45000 and result['admission_target_met']==(result['admission_elapsed_ms']<=45000),'Admission outcome contradicts unchanged45-second target')
            states[phase]=result; admissions[phase]={'elapsed_ms':result['admission_elapsed_ms'],'target_ms':45000,'met':result['admission_target_met']}
        install=states['install']; fresh=states['reopen']; costs=[interval(v) for v in install['cost_samples']]
        require(len(costs)==4 and {(r['mode'],r['atmosphere_enabled']) for r in costs}=={('disabled',False),('flat',False),('stack',False),('stack',True)},'Missing matched control window')
        baseline=install['ordinary_disabled_baseline']
        require(baseline['extent']==[512,512] and baseline['strata_initialized'] is False,'Cold diagnostic baseline is not the declared pre-Strata512 context')
        route=install['route_probe']; before=route['before'];after=route['after']
        for kind in ('native','rapier'):
            require(route['completed_'+kind+'_ticks']==after[kind+'_tick']-before[kind+'_tick'],'Tick completion counter mismatch')
        require(route['completed_native_ticks']>0 and route['completed_rapier_ticks']>=60 and route['elapsed_usec']>0 and route['forward_cells']>1,'No measured actual physical progression')
        for key in ('world_generation','physical_epoch','worker_id','actor_session_id','actor_body_ids'):
            require(before[key]==after[key]==route['live_decorative_edit']['before'][key]==route['live_decorative_edit']['after'][key],'Play/actor ownership changed during actual route')
        edit=route['live_decorative_edit']
        require(edit['committed'] is True and edit['native_written']==edit['marker']!=edit['native_before'] and edit['native_restored']==edit['native_before'],'Live decorative edit or actual Undo readback absent')
        require(after['native_tick']>edit['after']['native_tick'] and after['rapier_tick']>edit['after']['rapier_tick'],'Physical progress did not continue after decoration')
        atmosphere=install['atmosphere']
        require(hashes(atmosphere['native_hashes_before']) and atmosphere['native_hashes_before']==atmosphere['native_hashes_after'] and atmosphere['native_capture_delta']==0,'Atmosphere changed native materials or recurring capture')
        require(atmosphere['solo_leakage']['changed_samples']==0 and atmosphere['visual_difference']['changed_samples']>=8,'Atmosphere framebuffer observation missing or leaked')
        for first,second in (('paused_before','paused_after'),('hidden_before','hidden_after')):
            require(all(atmosphere[first][plane]['phase_seconds']==atmosphere[second][plane]['phase_seconds'] for plane in ('scripted','effects','background')),'Excluded visual clock advanced')
        require(install['process_id']!=fresh['process_id'] and fresh['fresh_process_reopen'] is True,'Reopen is not a fresh process')
        require(hashes(install['plane_native_hashes']) and install['plane_native_hashes']==fresh['plane_native_hashes'],'Saved authored native layouts differ on fresh reopen')
        require(install['authored_settings_sha256']==fresh['authored_settings_sha256'] and install['saved_authoring']==fresh['saved_authoring'] and install['save']['sha256']==fresh['save']['sha256'],'Saved authored settings/provenance or save bytes differ')
        require(install['authored_mutations']['after']==fresh['saved_authoring']['native_marker']['material']!=install['authored_mutations']['before'],'Reopened native marker is not the deliberate changed authored cell')
        require(fresh['saved_authoring']['atmosphere']['paused'] is True,'Explicit saved atmosphere pause lost')
        rows.append({'scene':scene['name'],'extent':install['extent'],'renderer':install['rendering_adapter'],
            'admission':admissions,'cost_samples':costs,'install_process':resources[scene['name']+'/install'],
            'reopen_process':resources[scene['name']+'/reopen'],
            'route':{'native_ticks':route['completed_native_ticks'],'rapier_ticks':route['completed_rapier_ticks'],'elapsed_usec':route['elapsed_usec'],
                'forward_cells':route['forward_cells'],'callbacks':route['callbacks'],'identity_unchanged':True,'actual_edit_undo':True,
                'scope':'End-to-end finite route trial includes resume, pilot control, toggles, native decoration edit/Undo and final pause settling; not isolated tick cost or complete-route traversal.'},
            'fresh_process':{'different_pids':True,'saved_native_hashes':fresh['plane_native_hashes'],'authored_settings_sha256':fresh['authored_settings_sha256'],
                'save_sha256':fresh['save']['sha256'],'explicit_saved_authoring':fresh['saved_authoring'],
                'scope':'Install hashes were captured for Save before the later physical route probe; this demonstrates authored-layout reopening, not continuation of evolved Play state.'}})
    return {'platform':original['platform'],'original_report_sha256':sha(path),'report':str(path),'scenes':rows,
        'all_process_resources':resources,'paused_maximum':{'result':original['maximum']['result'],'resources':resources['maximum']}}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--campaign',type=Path,action='append',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(); require(not args.output.exists(),'Do not overwrite prior evidence')
    records=[campaign(p) for p in args.campaign]
    result={'schema':'strata2-independent-observation-audit-v1','status':'raw-observations-verified',
        'source_commit':SOURCE,'source_tree':TREE,'campaigns':records,'auditor_sha256':sha(Path(__file__)),
        'scope':'Independent arithmetic, source/report identity and original resource/sample/readback checks. Original full qualification verifier and final package audit remain distinct. No new native/Godot execution.',
        'limits':['Sequential single windows do not establish statistical performance equivalence or an isolated atmosphere cost.',
            'Godot tracked static memory, whole-process sampled RSS, per-process CPU and GPU memory are different quantities; GPU residency was not measured.',
            'Cold ordinary diagnostic is512x512 before Strata allocation; disabled matched samples retain all allocated scene resources.',
            'No per-import or candidate-allocation marginal peak was independently measured.',
            'Maximum2048-square case is paused; no sustained dense maximum-size Play or native decorative dynamics is qualified.',
            'Physical Windows/NVIDIA appearance, interaction and actual displayed pacing remain owner acceptance gates.']}
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print(json.dumps({'status':result['status'],'source':SOURCE,'campaigns':len(records),'scenes':sum(len(v['scenes']) for v in records),'output':str(args.output)}))

if __name__=='__main__':main()
