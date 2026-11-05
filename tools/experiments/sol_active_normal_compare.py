#!/usr/bin/env python3
"""Separate preregistered merit decision from process/execution completion."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import sol_active_normal_inputs as inputs
import sol_active_normal_audit as audit

ROOT=Path(__file__).resolve().parents[2]

def compare(receipt):
    profile,_,cases=inputs.load();assert receipt['registration']==profile
    counts=Counter((e['platform'],e['arm_index']) for e in receipt['executions'])
    expected={(p,a) for p in ['linux-opt','linux-san','windows-msvc'] for a in range(3)}
    complete=set(counts)==expected and all(v==1 for v in counts.values()) and all(e['audit_status']=='PASS' and e['process']['clean'] for e in receipt['executions'])
    result=dict(execution_source=receipt['source'],complete_execution_matrix=complete,platforms=[],scope='Copied values only; live World/Rapier and original SOL clearance unavailable')
    if not complete:result['candidate_decision']='UNAVAILABLE';return result
    for platform in ['linux-opt','linux-san','windows-msvc']:
        entries=[next(e for e in receipt['executions'] if e['platform']==platform and e['arm_index']==arm) for arm in range(3)]
        data=[]
        for e in entries:
            raw=(ROOT/e['process']['log']).read_bytes();assert hashlib.sha256(raw).hexdigest()==e['process']['log_sha256'];data.append(json.loads(raw))
        assert [r['observation'] for r in data[0]['cases']]==[r['observation'] for r in data[1]['cases']]
        metrics=[[audit.record(c,r,arm) for c,r in zip(cases,d['cases'])] for arm,d in enumerate(data)]
        failures=[];worse=[];rejections=[];strict_energy=[];rows=[];benefits=[]
        def check(ok,message):
            if not ok:failures.append(message)
        for index,case in enumerate(cases):
            name=case['id'];a=metrics[0][index];b=metrics[2][index];oa=data[0]['cases'][index]['observation'];ob=data[2]['cases'][index]['observation'];oracle=case['oracle']
            topology=lambda obs:[{k:n[k] for k in ['position','normal','weight','capacity']} for n in obs['nodes']]
            check(topology(oa)==topology(ob) and oa['result']['capacity']==ob['result']['capacity'],name+': changed capacity/topology')
            check(a['early_refusal']==b['early_refusal'],name+': changed early refusal')
            if b['early_refusal']:continue
            if b['refused'] and not a['refused']:rejections.append(name)
            if b['maximum_approach_speed']>a['maximum_approach_speed']+1e-12:worse.append(name)
            if b['energy_delta']>1e-10:strict_energy.append(name)
            check(b['normal_energy_increase_max']<=profile['normal_energy_tolerance'],name+': normal batch energy increase')
            for prefix,metric in [('baseline',a),('candidate',b)]:
                if prefix+'_velocity' in oracle:check(all(audit.near(x,y) for x,y in zip(metric['velocity'],oracle[prefix+'_velocity'])),name+': '+prefix+' analytic velocity')
                if prefix+'_omega' in oracle:check(audit.near(metric['omega'],oracle[prefix+'_omega']),name+': '+prefix+' analytic omega')
            if name in profile['benefit_targets']:
                passed=not b['refused'] and math.hypot(*b['velocity'])<=1e-12 and b['normal_cap_hits']==0
                benefits.append(dict(case=name,pass_=passed,baseline_velocity=a['velocity'],candidate_velocity=b['velocity']))
                check(passed,name+': registered benefit target failed')
            if 'quadrature_clamps' in oracle:check(ob['result']['quadrature_clamps']==oracle['quadrature_clamps'],name+': quadrature clamp')
            if 'front_capacity' in oracle:check(audit.near(ob['nodes'][0]['capacity'],oracle['front_capacity']),name+': capacity redistributed')
            rows.append(dict(case=name,baseline=a,candidate=b))
        by_name={c['id']:i for i,c in enumerate(cases)}
        for arm in [1,2]:
            d=data[arm]['cases'];base=d[by_name['loaded-unwind']]['observation']['result']
            for name in ['offset-com','unwind-reversed-order']:
                other=d[by_name[name]]['observation']['result'];check(base['impulse']==other['impulse'] and base['torque']==other['torque'],name+': transformed equivalence')
            trace=d[by_name['loaded-unwind']]['trace']
            check([trace[k]['jn_after'][0] for k in [0,2,4]]==[.5,.25,0.],'loaded normal impulse did not unwind')
        trace=data[2]['cases'][by_name['separating-contact-activates']]['trace']
        check(trace[0]['active_count']==1 and trace[2]['active_count']==2,'active set not recomputed')
        index=by_name['shrinking-friction-cone'];check(metrics[2][index]['tangent_energy_increase_max']>0,'shrinking cone witness not observed')
        check(data[2]['cases'][index]['observation']==data[0]['cases'][index]['observation'],'all-loaded rounding/control changed')
        check(len(benefits)==9,'missing benefit target')
        decision='NO-GO' if failures else ('CONDITIONAL' if worse or rejections or strict_energy else 'PASS')
        result['platforms'].append(dict(platform=platform,decision=decision,failures=failures,benefits=benefits,worse_residual_cases=worse,new_rejections=rejections,strict_energy_increases=strict_energy,cases=rows))
    decisions=[p['decision'] for p in result['platforms']]
    result['candidate_decision']='NO-GO' if 'NO-GO' in decisions else ('CONDITIONAL' if 'CONDITIONAL' in decisions else 'PASS')
    return result

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('directory',type=Path);args=parser.parse_args()
    path=args.directory/'comparison.json';assert not path.exists();receipt=json.loads((args.directory/'receipt.json').read_text(encoding='utf-8'));result=compare(receipt)
    path.write_bytes((json.dumps(result,indent=2)+'\n').encode());print(json.dumps({k:v for k,v in result.items() if k!='platforms'}))

if __name__=='__main__':main()
