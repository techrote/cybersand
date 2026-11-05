#!/usr/bin/env python3
"""Summarize independently reconstructed full chamber evidence without acceptance conflation."""
import argparse
import copy
from collections import Counter,defaultdict
import hashlib
import json
from pathlib import Path
import sol_active_normal_live_matrix as matrix
import la_selective_experiment as p

ROOT=Path(__file__).resolve().parents[2]

def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def interval(values):return dict(minimum=min(values),maximum=max(values))

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('directory',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    folder=args.directory.resolve();output=args.output.resolve();assert not output.exists();output.mkdir(parents=True)
    head=p.git('rev-parse','HEAD').decode().strip();manifest_path=folder/'independent-reduction/manifest.json';manifest=read(manifest_path)
    assert manifest['status']=='COMPLETE' and manifest['full_registered_chamber_evidence_complete'] and len(manifest['results'])==240
    receipt_path=folder/'receipt.json';receipt=read(receipt_path);assert matrix.coverage(receipt)['complete_registered_execution']
    groups=defaultdict(list);episodes=[];worker_ticks=defaultdict(Counter);capacity=defaultdict(Counter);commands=receipt['hosts']
    command_index={(host,c['name']):c for host,state in commands.items() for c in state['commands']}
    for entry in manifest['results']:
        assert entry['status']=='PASS';coordinate=entry['coordinate'];summary=entry['summary'];name=entry['name']
        derivative_path=folder/'independent-reduction'/(name+'.json');assert sha(derivative_path)==entry['derivative_sha256']
        derivative=read(derivative_path);raw_path=ROOT/summary['raw_path'];assert sha(raw_path)==summary['raw_sha256'];raw=read(raw_path)
        assert raw['construction_receipt']['worker_threads']==coordinate['workers']
        assert raw['construction_receipt']['workbench_response']==coordinate['mode']
        assert raw['construction_receipt']['completed_tick']==0
        command=command_index[(coordinate['platform'],matrix.tag(coordinate))]
        copied=copy.deepcopy(summary);scalar=derivative['scalar_accounting'];steps=raw['steps'];bounds=derivative['steps']
        copied.update(registered_arm_id=coordinate['arm_id'],normal_policy=coordinate['normal_policy'],
            raw_input_bytes=raw_path.stat().st_size,process_seconds=command['seconds'],
            externally_driven_work=sum(s['external_api_kinetic_delta'] for s in steps),
            actual_response_work=sum(s['candidate_kinetic_delta'] for s in steps),
            rapier_step_work=sum(s['rapier_kinetic_delta'] for s in steps),
            observed_legacy_wrench_f64=[sum(s['legacy_wrench_f64'][i] for s in scalar) for i in range(3)],
            normal_cap_hits=sum(s['normal_cap_hits'] for s in scalar),tangent_cap_hits=sum(s['tangent_cap_hits'] for s in scalar),
            initial_payload_sha256=raw['initial_payload']['sha256'],final_payload_sha256=raw['final_payload']['sha256'],
            post_drive_maximum_area=max(g['sand_area'] for s in bounds if s['step']>=150 for g in s['geometry']),
            post_drive_maximum_depth=max(g['sand_max_depth'] for s in bounds if s['step']>=150 for g in s['geometry']),
            known_cell_plus_arrival_bytes=max(s['statistics']['values']['resident_cell_bytes']+s['response']['arrival_storage_bytes'] for s in steps),
            observed_workers=sorted({s['statistics']['values']['worker_threads_observed'] for s in steps}))
        # Do not turn rounded vector subtraction into a measured legacy term.
        for axis in ['x','y']:
            source='legacy_residual_'+axis
            copied['wrench_component_sums']['rounded_vector_subtraction_residual_'+axis]=copied['wrench_component_sums'].pop(source)
        key=(coordinate['platform'],coordinate['case'],coordinate['arm_id']);groups[key].append(copied);episodes.append(copied)
        worker_key=(coordinate['platform'],coordinate['workers'])
        for step in steps:
            stats=step['statistics'];worker_ticks[worker_key][stats['values']['worker_threads_observed']]+=1
            capacity[worker_key]['maximum_phase_jobs']=max(capacity[worker_key]['maximum_phase_jobs'],*stats['phase_jobs_last_tick'])
            capacity[worker_key]['scheduled_cores_peak']=max(capacity[worker_key]['scheduled_cores_peak'],stats['values']['scheduled_cores'])
    table=[]
    for (host,case,arm),rows in sorted(groups.items()):
        assert len(rows)==6
        table.append(dict(platform=host,case=case,arm=arm,episodes=len(rows),workers=sorted({r['requested_workers'] for r in rows}),
            repeats=sorted({r['repeat'] for r in rows}),maximum_area=interval([r['maximum_observed_sand_area'] for r in rows]),
            maximum_depth=interval([r['maximum_observed_sand_depth'] for r in rows]),
            strict_all_observations_clear=sum(r['strict_all_observations_clear'] for r in rows),
            nonembedded_depth_screen=sum(r['nonembedded_depth_screen'] for r in rows),
            arrival_counts=None if rows[0]['selected_arrivals'] is None else interval([r['selected_arrivals'] for r in rows]),
            missing_arrival_counts=None if rows[0]['selected_arrivals'] is None else interval([r['native_counters']['arrival_missing'] for r in rows]),
            passive_rejections=sum(r['passive_rejections'] for r in rows),normal_cap_hits=sum(r['normal_cap_hits'] for r in rows),
            getter_mean_us=interval([r['getter_mean_us'] for r in rows]),getter_max_us=max(r['getter_max_us'] for r in rows),
            known_cell_plus_arrival_bytes=interval([r['known_cell_plus_arrival_bytes'] for r in rows])))
    worker_summary=[dict(platform=h,requested_workers=w,participant_tick_distribution=dict(sorted(counts.items())),
        **dict(capacity[(h,w)]),qualifier='Maximum distinct task-claiming participants per dispatch; not utilization') for (h,w),counts in worker_ticks.items()]
    result=dict(evaluator='SOL-ACTIVE-NORMAL-LIVE-001-FULL-CHAMBER-SYNTHESIS',analysis_source=head,
        execution_source=manifest['execution_source'],geometry_analysis_source=manifest['analysis_source'],
        input_receipt_sha256=sha(receipt_path),input_reduction_sha256=sha(manifest_path),
        execution_coverage=manifest['execution_coverage'],common_initial_inputs=manifest['common_initial_inputs'],
        episodes=240,steps=43200,observation_boundaries=216000,all_exact_tuple_multisets_conserved=all(r['exact_tuple_multiset_conservation'] for r in episodes),
        table=table,worker_participation=worker_summary,
        forced_strict_clearance_failures=sum(not r['strict_all_observations_clear'] for r in episodes if r['case']['driven']),
        forced_episodes=sum(r['case']['driven'] for r in episodes),
        scope='Registered chamber surrogate only. Strict descriptive full-window checks are not original SOL120+60 acceptance; original authority/composition unavailable.',
        timing_scope='Recorded full-observer shared-host timings; getter includes solve and diagnostic packet. No original SOL CPU gate or universal60Hz claim.',
        memory_scope='Known resident_cell_bytes plus separately reported arrival history; not total heap/process memory')
    for name,value in [('summary.json',result),('episodes.json',episodes)]:
        (output/name).write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))
    assert head==p.git('rev-parse','HEAD').decode().strip()
    print(json.dumps(dict(episodes=240,forced_failures=result['forced_strict_clearance_failures'],forced_total=result['forced_episodes'],common_groups=len(result['common_initial_inputs']))))

if __name__=='__main__':main()
