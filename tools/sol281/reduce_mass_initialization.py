"""Independent immediate/poststep known-wrench oracle; frozen analytic tolerance."""
import argparse,json,math,struct
from pathlib import Path
import structure_cut as p

def close(x,y):return abs(x-y)<=16*2**-23*max(abs(y),1e-12)
def decode(s):return struct.unpack('<3d',bytes.fromhex(s))
def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('--run',required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();assert not args.output.exists()
    folder=p.OUT/args.run;receipt=json.loads((folder/'receipt.json').read_text(encoding='utf-8'));assert receipt['post_source_equality'];result={}
    for host,h in receipt['hosts'].items():
        c=next(c for c in h['commands'] if c['name']=='mass-init');raw=c['report'];path=p.ROOT/raw['path'].replace('\\','/');assert c['clean'] and c['report_complete'] and p.sha(path)==raw['sha256'];report=json.loads(path.read_text(encoding='utf-8'));assert not report['failures']
        rows=[];coordinates=set()
        for case in report['cases']:
            key=(case['structure'],case['arm'],case.get('inertia_scale',1),case['impulse_kind']);assert key not in coordinates;coordinates.add(key)
            expected=case['expected'];before=decode(case['before']['velocity_bits']);immediate=decode(case['immediate']['velocity_bits']);post=decode(case['post']['velocity_bits'])
            assert all(math.isfinite(x) for x in before+immediate+post)
            delta=[b-a for a,b in zip(before,immediate)];post_delta=[b-a for a,b in zip(before,post)]
            assert all(x==y for x,y in zip(delta,case['observed'])) and all(x==y for x,y in zip(post_delta,case['post_observed']))
            immediate_pass=all(close(x,y) for x,y in zip(delta,expected));post_pass=all(close(x,y) for x,y in zip(post_delta,expected))
            assert all(case[k]['velocity_bits']==case[k]['direct_velocity_bits'] for k in ['initial','before','immediate','post']),'getter/direct-state disagree'
            if case['arm'] in ['custom_after_zero_g_step','auto_com_before_custom_inertia_fresh']:assert immediate_pass and post_pass,'ready control fails frozen analytic bound'
            if case['arm']=='custom_fresh':assert delta==[0.,0.,0.] and post_delta==[0.,0.,0.],'fresh negative control differs from reproduced lost-impulse outcome'
            assert case['before']['steps']==int(case['arm']=='custom_after_zero_g_step') and case['post']['steps']==case['before']['steps']+1
            local=case['immediate']['local_com'];lever_difference=-(local[0]*3.)/case['immediate']['inertia'] if case['impulse_kind']=='offcentre' else 0.
            rows.append(dict(coordinate=key,expected=expected,immediate=delta,post=post_delta,immediate_pass=immediate_pass,post_pass=post_pass,post_scalar_params=case['post'],COM_lever_reference_difference=lever_difference))
        expected_arms={'custom_fresh','custom_after_zero_g_step','auto_com_custom_inertia_fresh'}
        scales={1}
        if len(rows)==32:expected_arms.add('auto_com_before_custom_inertia_fresh');scales={1,2}
        assert coordinates=={(s,a,i,w) for s in ['tree','building'] for a in expected_arms for i in scales for w in ['central','offcentre']}
        result[host]=dict(raw=raw,cases=rows,ready_controls=sum(x['immediate_pass'] and x['post_pass'] for x in rows),lost_impulse_controls=sum(x['coordinate'][1]=='custom_fresh' for x in rows))
    p.write(args.output,dict(reducer_sha256=p.sha(__file__),receipt_sha256=p.sha(folder/'receipt.json'),scope='Isolated backend initialization only; cached params are not effective mass proof; no nativeWorld or handoff warmstep. Frozen impulse/torque references unchanged; COM lever delta is an extra diagnostic.',hosts=result));print({h:dict(cases=len(r['cases']),ready=r['ready_controls'],lost=r['lost_impulse_controls']) for h,r in result.items()})
if __name__=='__main__':main()
