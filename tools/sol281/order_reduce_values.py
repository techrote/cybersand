"""Independent scalar64 reduction of retained pure ordering results (no engine)."""
import argparse,collections,json,struct
from pathlib import Path
import order_common as o
import structure_cut as p

def state(bits):
    raw=bytes.fromhex(bits);assert len(raw)==88
    return struct.unpack('<11d',raw)

def energy(bits):
    a=state(bits);return .5*a[9]*(a[6]**2+a[7]**2)+.5*a[10]*a[8]**2

def reduce(folder):
    receipt=json.loads((folder/'receipt.json').read_text(encoding='utf-8'));assert receipt['post_source_equality']
    for name,digest in receipt['inputs'].items():assert o.sha(folder/'inputs'/name)==digest
    outputs={};hashes=[]
    for host,h in receipt['hosts'].items():
        path=o.ROOT/h['report']['path'];assert o.sha(path)==h['report']['sha256'];hashes.append(o.sha(path))
        d=json.loads(path.read_text(encoding='utf-8'));assert not d['failures'] and d['checks']==17053 and len(d['sessions'])==16
        sessions={}
        for s in d['sessions']:
            source=json.loads((folder/'inputs'/(s['id']+'.json')).read_text(encoding='utf-8'));assert len(s['rows'])==360
            windows={}
            for window,rows in [('all',s['rows']),('late120',s['rows'][240:])]:
                arms={}
                for arm in ['current','prediction','post']:
                    outcomes=collections.Counter();numerical=collections.Counter();count=0;dj=0.;max_gain=0.;virtual_gains=0;virtual_max=0.;nonempty=0
                    for row in rows:
                        a=row['arms'][arm];plan=a['plan'];outcomes[a['effective_outcome']]+=1;numerical[plan['outcome']]+=1
                        if a['admission']!='Admitted' or not plan.get('accepted'):continue
                        count+=1;change=energy(a['output_bits'])-energy(a['input_bits']);max_gain=max(max_gain,change)
                        assert change<=max(1e-8,energy(a['input_bits'])*1e-8)+1e-9
                        dj+=plan['total_impulse'][1];nonempty+=bool(plan['impulses'])
                        index=int(row['step']);assert index==row['step']
                        vchange=energy(a['unapplied_s1_bits'])-energy(source['steps'][index]['s1'])
                        virtual_gains+=vchange>1e-8;virtual_max=max(virtual_max,vchange)
                    controls=source['steps'][0];mass=state(controls['s1'])[9];g=abs(controls['gravity'][1]);dt=controls['dt']
                    arms[arm]=dict(effective_outcomes=dict(outcomes),numerical_outcomes_including_ineligible=dict(numerical),eligible_accepted=count,eligible_nonempty=nonempty,selected_jy_sum=dj,opposing_gravity_fraction_all_frames=-dj/(mass*g*dt*len(rows)),max_scalar64_energy_gain=max_gain,unapplied_on_actual_s1_gain_count=virtual_gains,unapplied_on_actual_s1_max_gain=virtual_max)
                windows[window]=arms
            sessions[s['id']]=windows
        outputs[host]=dict(checks=d['checks'],states=5760,sessions=sessions)
    assert len(set(hashes))==1,'Cross-host pure values differ'
    return dict(registration='SOL-CONTACT-ORDER-VALUES-001',receipt_sha256=o.sha(folder/'receipt.json'),hosts=outputs,cross_host_identical=True,scope='Pure values. No application, trajectory, clearance or live authority claim; numerical results behind wrapper refusal are ineligible.')

if __name__=='__main__':
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);a=ap.parse_args();assert Path(a.run).name==a.run
    folder=o.OUT/a.run;dst=folder/'reduction.json';assert not dst.exists();d=reduce(folder);p.write(dst,d)
    print(json.dumps(dict(cross_host_identical=d['cross_host_identical'],primary=d['hosts']['linux']['sessions']['linux-building-w1-on1']['late120'])))
