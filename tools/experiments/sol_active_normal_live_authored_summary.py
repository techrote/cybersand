#!/usr/bin/env python3
"""Post-result synthesis of registered authored/workload observations; no new gates."""
import argparse
from collections import Counter, defaultdict
import copy
import hashlib
import json
from pathlib import Path
import la_selective_experiment as p
import sol_active_normal_live_matrix as matrix

def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def interval(values):return dict(minimum=min(values),maximum=max(values))
def write(path,value):path.write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('directory',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    folder=args.directory.resolve();output=args.output.resolve();assert not output.exists();output.mkdir(parents=True)
    head=p.git('rev-parse','HEAD').decode().strip()
    manifest_path=folder/'independent-001/manifest.json';receipt_path=folder/'receipt.json'
    manifest=read(manifest_path);receipt=read(receipt_path)
    assert manifest['status']=='COMPLETE' and manifest['full_registered_evidence_complete']
    assert matrix.coverage(receipt)['complete_registered_execution'] and sha(receipt_path)==manifest['input_receipt_sha256']
    assert len(manifest['results'])=={'authored':192,'workload':72}[manifest['suite']]
    episodes=[];groups=defaultdict(list);workers=defaultdict(Counter)
    for entry in manifest['results']:
        assert entry['status']=='PASS';c=entry['coordinate'];row=copy.deepcopy(entry['summary'])
        derivative=folder/'independent-001'/(entry['name']+'.json');assert sha(derivative)==entry['derivative_sha256'];data=read(derivative)
        assert row['configured_workers']==[c['workers']]
        areas=Counter();depths=Counter();outside=0
        for observation in data['geometry_observations']:
            for body in observation['bodies']:
                if body['outside']:outside+=1;continue
                for m,v in body['area_by_material'].items():areas[m]=max(areas[m],v)
                for m,v in body['maximum_convex_proxy_depth'].items():depths[m]=max(depths[m],v)
        scalar=data['native_scalar_accounting']
        row.update(name=entry['name'],repeat=c['repeat'],maximum_sampled_area_by_material=dict(areas),maximum_sampled_proxy_depth_by_material=dict(depths),outside_sampled_body_observations=outside,
            normal_cap_hits=sum(s['normal_cap_hits'] for s in scalar),tangent_cap_hits=sum(s['tangent_cap_hits'] for s in scalar),independent_derivative_sha256=entry['derivative_sha256'])
        episodes.append(row);groups[(c['platform'],c['case'],c['workers'],c['arm_id'])].append(row)
        workers[(c['platform'],c['workers'])].update({int(k):v for k,v in row['actual_worker_tick_distribution'].items()})
    fields=['selected_arrivals','arrival_missing','arrival_misaligned','actual_response_work','explicit_api_work','controller_or_other_work','preapplication_work','rapier_step_work','passive_energy_delta','getter_mean_us','process_seconds','resident_cell_bytes_peak','arrival_history_bytes_peak','known_cell_plus_arrival_bytes_peak']
    table=[]
    for (host,case,count,arm),rows in sorted(groups.items()):
        assert len(rows)==3 and sorted(r['repeat'] for r in rows)==[0,1,2]
        materials=sorted({m for r in rows for m in r['maximum_sampled_area_by_material']})
        table.append(dict(platform=host,case=case,requested_workers=count,arm=arm,powered=rows[0]['powered'],episodes=3,
            **{k:interval([r[k] for r in rows]) for k in fields},simulation_mean_us=interval([r['timings']['mean_simulation_us'] for r in rows]),
            simulation_max_us=max(r['timings']['max_simulation_us'] for r in rows),getter_max_us=max(r['getter_max_us'] for r in rows),
            total_control_us=sum(r['timings']['total_control_us'] for r in rows),total_control_attempts=sum(r['timings']['total_control_attempts'] for r in rows),
            passive_rejections=sum(r['passive_rejections'] for r in rows),normal_cap_hits=sum(r['normal_cap_hits'] for r in rows),tangent_cap_hits=sum(r['tangent_cap_hits'] for r in rows),
            maximum_RID_error=max(r['maximum_actual_RID_error'] for r in rows),maximum_legacy_display_KE_error=max(r['maximum_scalar_observer_legacy_error'] for r in rows),
            sampled_maximum_area_by_material={m:interval([r['maximum_sampled_area_by_material'].get(m,0) for r in rows]) for m in materials},
            sampled_maximum_proxy_depth_by_material={m:interval([r['maximum_sampled_proxy_depth_by_material'].get(m,0) for r in rows]) for m in materials},terminal120_stability=[r['stability'] for r in rows]))
    summary=dict(evaluator='SOL-ACTIVE-NORMAL-LIVE-001-'+manifest['suite'].upper()+'-SYNTHESIS',synthesis_source=head,execution_source=manifest['execution_source'],independent_analysis_source=manifest['analysis_source'],runtime_build_source=manifest['runtime_build_source'],
        input_receipt_sha256=sha(receipt_path),input_reduction_sha256=sha(manifest_path),episodes=len(episodes),steps=sum(r['steps'] for r in episodes),execution_coverage=manifest['execution_coverage'],common_initial_inputs=manifest['common_initial_inputs'],
        all_material_source_ledgers_close=all(r['material_source_ledger_closes'] for r in episodes),all_closed_tuple_multisets_equal=all(r['closed_tuple_multiset_equal'] for r in episodes if r['closed_tuple_multiset_equal'] is not None),
        maximum_RID_error=max(r['maximum_actual_RID_error'] for r in episodes),worker_participation=[dict(platform=h,requested_workers=w,participant_tick_distribution=dict(sorted(c.items()))) for (h,w),c in sorted(workers.items())],table=table,
        all_command_seconds_including_preparation=sum(c['seconds'] for state in receipt['hosts'].values() for c in state['commands']),
        scope='Registered authored/workload observations; no original SOL authority or physical-clearance acceptance.',
        geometry_scope='Sampled material ROI and maximum individual convex-proxy depth; not complete five-boundary union geometry.',
        energy_scope='Observed scalar64 rigid-body work; powered/control and insertion/removal separate. Full grain/body energy conservation unavailable.',
        memory_scope='Resident-cell estimate and arrival history separate; their sum is not total process/native heap.',
        timing_scope='Instrumented shared host, fixed Original-then-Active order, three repetitions. Getter includes solve/packet; simulation/control/process separate. No isolated causal overhead, universal60Hz or original24group SOL CPU-gate claim.')
    write(output/'summary.json',summary);write(output/'episodes.json',episodes)
    assert head==p.git('rev-parse','HEAD').decode().strip()
    print(json.dumps(dict(suite=manifest['suite'],episodes=len(episodes),steps=summary['steps'],matched_groups=len(summary['common_initial_inputs']))))

if __name__=='__main__':main()
