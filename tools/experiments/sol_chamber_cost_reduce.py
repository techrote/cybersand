#!/usr/bin/env python3
"""Independent trajectory/payload equivalence and inclusive timing ledger."""
import argparse
from collections import Counter
from itertools import product
import json
from pathlib import Path
import subprocess
import sol_chamber_reduce as g

ROOT=Path(__file__).resolve().parents[2]
TIMERS=['preparation_us','native_tick_us','response_generation_us','application_us','rapier_us','statistics_us','observer_us','export_us','elapsed_us']

def state(value):return {k:v for k,v in value.items() if k!='rid'}
def scope(value):return {k:v for k,v in value.items() if k not in ['session','epoch']}

CAPTURES=[0,29,30,149,150,179]

def signature(data):
    states=['before','after_external_drive','live_before_application','after_application','after_step']
    physical=['force','external_api_kinetic_delta','preapplication_kinetic_delta','candidate_kinetic_delta','force_endpoint_work_estimate','force_impulse','rapier_kinetic_delta']
    return dict(geometry=data['geometry_f64le'],shapes=data['actual_shapes'],initial=state(data['initial']['state']),final=state(data['final']['state']),
        steps=[dict(step=s['step'],states={k:state(s[k]) for k in states},sample=scope(s['sample']),response=scope(s['response']),application=s['application'],
            physics={k:s[k] for k in physical},payload_sha256=s.get('payload',{}).get('sha256'),boundaries=[dict(boundary=b['boundary'],state=state(b['state']),revision=b['revision'],failed=b['failed']) for b in s['boundaries']]) for s in data['steps']])

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('directory',type=Path);parser.add_argument('--output',type=Path);args=parser.parse_args()
    analysis_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()
    folder=args.directory.resolve();output=args.output or folder/'reduction';assert not output.exists();output.mkdir(parents=True)
    receipt=json.loads((folder/'receipt.json').read_text(encoding='utf-8'));profile=receipt['profile'];matrix=receipt['matrix']
    assert profile==json.loads((ROOT/'godot/tests/fixtures/sol_chamber/cost-001.json').read_text(encoding='utf-8'))
    for key in ['platforms','cases','workers','observers']:
        assert matrix[key] and len(matrix[key])==len(set(matrix[key])) and set(matrix[key])<=set(profile[key])
    assert isinstance(matrix['repeats'],int) and 0<matrix['repeats']<=profile['repeats']
    base=json.loads((ROOT/profile['base_profile']).read_text(encoding='utf-8'));rows=[];reports={};admissible={};coverage=Counter()
    for process in receipt['results']:
        for item in process.get('reports',[]):
            path=ROOT/item['path'].replace('\\','/');raw=path.read_bytes();assert g.r.sha(raw)==item['sha256']
            data=json.loads(raw);observer=data['observer'];case=data['case']['id'];platform=process['platform']
            key=(platform,case,data['requested_workers'],data['repeat'],observer);coverage[key]+=1
            assert data['source']==receipt['identity']['source'] and data['mode']=='LA-SELECTIVE' and data['registration']==profile['id']
            assert data['base_profile_sha256']==profile['base_profile_sha256'] and data['cost_profile_sha256']==g.r.sha((ROOT/'godot/tests/fixtures/sol_chamber/cost-001.json').read_bytes())
            complete=process['clean'] and not data['failures'] and len(data['steps'])==180 and [s['step'] for s in data['steps']]==list(range(180))
            assert data['case']==next(s for s in base['cases'] if s['id']==case)
            assert [s['step'] for s in data['steps'] if 'payload' in s]==CAPTURES
            initial=g.payload(data['initial_payload']);final=g.payload(data['final_payload'])
            conserved=initial['material_counts']==final['material_counts'] and initial['tuple_multiset']==final['tuple_multiset']
            admissible[key]=complete and conserved
            for step in data['steps']:
                assert step['prepared'] and step['ticked'] and step['response']['valid'] and step['application']['accepted']
                assert step['response']['response']=='LA-SELECTIVE' and step['response']['sample_tick']==step['step']
                assert step['response']['session']==step['sample']['session'] and step['response']['epoch']==step['sample']['epoch']
                assert step['sample']['session']==data['initial_sample']['session'] and step['sample']['epoch']==data['initial_sample']['epoch']
                owner=step['sample']['bodies'][0];initial_owner=data['initial_sample']['bodies'][0]
                assert len(step['sample']['bodies'])==1 and {k:v for k,v in owner.items() if k!='external_drive'}=={k:v for k,v in initial_owner.items() if k!='external_drive'}
                assert len(step['sample']['states'])==6*17 and step['sample']['geometry']==data['initial_sample']['geometry']
                for proxy in range(6):
                    values=step['sample']['states'][proxy*17:(proxy+1)*17]
                    assert values[0]==proxy+1 and values[10]==data['initial_sample']['states'][10]+step['step']+1 and values[16]==step['sample']['session']
                if 'payload' in step:assert g.payload(step['payload'])['completed_tick']==step['step']+1
                assert len(step['response']['rows'])==1 and step['response']['rows'][0]['proxy_count']==6
                assert [b['boundary'] for b in step['boundaries']]==base['boundaries'] and all(b['world_instance']==data['initial']['world_instance'] and b['state']['rid']==data['initial']['state']['rid'] and not b['failed'] for b in step['boundaries'])
                assert all(isinstance(step[k],int) and step[k]>=0 for k in TIMERS)
                assert sum(step[k] for k in TIMERS if k!='elapsed_us')<=step['elapsed_us']
                row=step['response']['rows'][0];action=step['application']['bodies'][0]
                assert row['sample']==action['sample']==step['sample']['states'][10] and row['instance_id']==action['instance_id']==520
                assert row['generation']==owner['generation']==1 and row['id']==owner['id']==1
            geometry=g.report(path,base) if observer=='full' else None
            if geometry:assert geometry['complete_episode'] and geometry['valid_initial_geometry'] and geometry['exact_tuple_multiset_conservation']
            values={k:dict(sum_us=sum(s[k] for s in data['steps']),mean_us=sum(s[k] for s in data['steps'])/len(data['steps']),max_us=max(s[k] for s in data['steps'])) for k in TIMERS}
            reports[key]=data
            rows.append(dict(platform=platform,case=case,workers=data['requested_workers'],repeat=data['repeat'],observer=observer,source=data['source'],pid=data['godot_process_id'],complete=complete,exact_tuple_conservation=conserved,
                report=item,initial_payload_sha256=initial['sha256'],final_payload_sha256=final['sha256'],timings=values,process_seconds=process['seconds'],episode_us=data['episode_us'],
                participant_max=max(s['statistics']['values']['worker_threads_observed'] for s in data['steps']),arrival_history_peak=max(s['response']['arrival_storage_bytes'] for s in data['steps']),resident_bytes_peak=max(s['statistics']['values']['resident_cell_bytes'] for s in data['steps']),
                maximum_sand_area=geometry['maximum_observed_sand_area'] if geometry else None,maximum_sand_depth=geometry['maximum_observed_sand_depth'] if geometry else None,
                geometry_scope='full five-boundary recorded-transform audit' if geometry else 'intermediate geometry unavailable; paired trajectory/payload equivalence only'))
    expected=set(product(matrix['platforms'],matrix['cases'],matrix['workers'],range(matrix['repeats']),matrix['observers']))
    assert set(coverage)<=expected and all(v==1 for v in coverage.values())
    pairs=[]
    for key in product(matrix['platforms'],matrix['cases'],matrix['workers'],range(matrix['repeats'])):
        left=reports.get((*key,'full'));right=reports.get((*key,'minimal'))
        if left is None or right is None:pairs.append(dict(coordinates=key,equivalent=False,reason='missing observer'));continue
        if not admissible.get((*key,'full'),False) or not admissible.get((*key,'minimal'),False):pairs.append(dict(coordinates=key,equivalent=False,reason='failed/incomplete/unconserved report'));continue
        a=signature(left);b=signature(right);different=[k for k in a if a[k]!=b[k]]
        endpoint_equal=all(left[k]['sha256']==right[k]['sha256'] for k in ['initial_payload','final_payload'])
        equivalents=not different and endpoint_equal
        pairs.append(dict(coordinates=key,equivalent=equivalents,different_signature_sections=different,endpoint_payloads_equal=endpoint_equal,
            omitted_from_signature=['scoped body RID','session/epoch identity after per-report binding checks'],elapsed_difference_us=(sum(s['elapsed_us'] for s in left['steps'])-sum(s['elapsed_us'] for s in right['steps']))/180 if equivalents else None))
    complete=set(coverage)==expected and all(r['complete'] and r['exact_tuple_conservation'] for r in rows)
    full_expected=set(product(profile['platforms'],profile['cases'],profile['workers'],range(profile['repeats']),profile['observers']))
    result=dict(source=receipt['identity']['source'],registration=profile['id'],requested_matrix=matrix,complete_requested_matrix=complete,full_registered_matrix=complete and set(coverage)==full_expected,
        missing_coordinates=sorted(expected-set(coverage)),pairs=pairs,episodes=rows,all_pairs_equivalent=all(p['equivalent'] for p in pairs),process_attempts=len(receipt['results']),failed_processes=sum(not p['clean'] for p in receipt['results']),
        all_child_seconds=sum(p['seconds'] for p in receipt['results']),campaign_elapsed_seconds=receipt.get('campaign_elapsed_seconds'),scope='Shared-host API wall intervals; one-body surrogate, not original SOL CPU gate or scaling proof')
    assert analysis_source==subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()
    result.update(reducer_source=analysis_source,reducer_sha256=g.r.sha(Path(__file__).read_bytes().replace(b'\r\n',b'\n')))
    (output/'summary.json').write_bytes((json.dumps(result,indent=2)+'\n').encode())
    print(json.dumps(dict(episodes=len(rows),complete_requested=complete,full_registered=result['full_registered_matrix'],equivalent_pairs=sum(p['equivalent'] for p in pairs),pairs=len(pairs))))

if __name__=='__main__':main()
