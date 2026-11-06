"""Independent SOL-BEARING-GATE-001 reduction: alignment, native-law model check, lost correction and decision."""
import argparse,collections,hashlib,json,math,struct
from pathlib import Path
import order_common as o
import structure_cut as p
import reduce_structure_cut as r
import gate_live as g

REFERENCE_RECEIPT_SHA='5e29c6966bb48e5092298f26d79c783509ab3ebd380a9609e76075e9746eae53'
IN_STRIDE=11;OUT_STRIDE=9;CAP=.5;FRACTION=.99;SETTLE=4.;MODEL_TOL=1e-5;TAIL=(600,720)

def floats(hexbits):
    raw=bytes.fromhex(hexbits);return list(struct.unpack('<%df'%(len(raw)//4),raw))
def records(values,stride,id_index=0):
    assert len(values)%stride==0
    return {int(values[i+id_index]):values[i:i+stride] for i in range(0,len(values),stride)}
def law(now_y,previous_y):
    """Unchanged native granular bearing correction for 0<vy<=4 (cyber_native_cell_world.cpp)."""
    return -min(CAP,max(0.,now_y-previous_y)*FRACTION)
def limit(x,y,cap=CAP):
    n=math.hypot(x,y);return (x,y) if n<=cap or n==0 else (x*cap/n,y*cap/n)

def evaluate(entry,previous,masses):
    """Classify one aligned applied result. Returns None when misaligned."""
    states=records(floats(entry['states']),IN_STRIDE);results=records(floats(entry['results']),OUT_STRIDE)
    rows={int(row[0]):row for row in entry['rows']}
    if not (set(states)==set(results)==set(rows)==set(range(1,len(masses)+1))):return None
    for i in states:
        if not (int(states[i][10])==int(results[i][8])==int(rows[i][1])):return None
    prev=records(floats(previous['states']),IN_STRIDE) if previous else None
    total=sum(masses);ax=ay=cx=cy=0.;gated=supported=0;checks=fails=0
    for i in sorted(states):
        s=states[i];res=results[i];support=int(rows[i][8]);vy=s[7];w=masses[i-1]/total
        actual=res[4];ax+=res[3]*w;ay+=actual*w;cx+=res[3]*w;candidate=actual
        if prev is not None and i in prev:
            expected=law(s[2],prev[i][2]) if (support>0 and 0.<vy<=SETTLE) else 0.
            checks+=1;fails+=abs(actual-expected)>MODEL_TOL
            if support>0 and vy<=0.:candidate=law(s[2],prev[i][2])
        if support>0:supported+=1
        if support>0 and vy<=0.:gated+=1
        cy+=candidate*w
    return dict(actual=limit(ax,ay),counterfactual=limit(cx,cy),gated=gated,supported=supported,checks=checks,fails=fails,previous_known=prev is not None)

def com_y(body):
    a=r.state(body);return r.transform(a[:6],body['local_com'])[1]

def episode(d):
    assert not d['failures'] and len(d['steps'])==720 and d['bearing_registration']=='SOL-BEARING-GATE-001' and d['native_telemetry']
    n=520 if d['structure']=='tree' else 356;r.handoff(d,n);masses=d['proxy_masses'];assert sum(masses)==n
    by_serial={};by_tick={};overflow=0;total=0
    for row in d['steps']:
        ring=row.get('bearing_ring');assert ring is not None,'missing ring drain'
        overflow=ring['overflow'];total=ring['total']
        for e in ring['entries']:
            assert e['serial'] not in by_serial,'duplicate serial';by_serial[e['serial']]=e;by_tick.setdefault(e['tick'],e)
    c=collections.Counter();lost=[0.]*720;gate=[];ages=collections.Counter();outcomes=collections.Counter();checks=fails=0
    for k,row in enumerate(d['steps']):
        if row['response_is_new']:
            resp=row['response'];outcomes[resp['outcome']]+=1;ages[(resp['current_sample_serial']-resp['source_sample_serial'])%1000000]+=1
        stage=row['ordinary_stage']
        if not stage.get('observed') or not stage['receipt'].get('accepted'):c['not_applied']+=1;continue
        c['applied']+=1;entry=by_serial.get(stage['snapshot_serial'])
        if entry is None or entry['tick']!=stage['native_tick'] or entry['results']!=stage['native_results_bits'] or entry['states']!=stage['native_states_bits']:c['misaligned']+=1;continue
        previous=by_tick.get(entry['tick']-1)
        if previous is not None and previous['epoch']!=entry['epoch']:previous=None
        v=evaluate(entry,previous,masses)
        if v is None:c['misaligned']+=1;continue
        rec=stage['receipt']['correction'];receipt=(float(rec[0]),float(rec[1]))
        if max(abs(receipt[0]-v['actual'][0]),abs(receipt[1]-v['actual'][1]))>MODEL_TOL:
            if receipt==(0.,0.):c['age_zeroed']+=1;continue
            c['receipt_mismatch']+=1;continue
        if not v['previous_known']:c['previous_unknown']+=1;continue
        c['evaluated']+=1;checks+=v['checks'];fails+=v['fails'];gate.append(v['gated']>0)
        lost[k]=v['actual'][1]-v['counterfactual'][1]
    ys=[com_y(s['after_step']) for s in d['steps']];tail=[ys[k]-ys[k-1] for k in range(*TAIL)]
    attempts=sum(outcomes.values());model_pass=(checks-fails)/checks if checks else 0.
    return dict(host=d['platform'].lower(),workers=d['workers'],structure=d['structure'],arm='off' if not d['sand_response'] else d['contact_order'],source=d['source'],
        counts=dict(c),ring_total=total,ring_overflow=overflow,model_checks=checks,model_failures=fails,model_pass=model_pass,valid=model_pass>=.99 and c['evaluated']>0,
        gate_fraction=sum(gate)/len(gate) if gate else None,lost_total=sum(lost),lost_tail_per_step=sum(lost[TAIL[0]:TAIL[1]])/(TAIL[1]-TAIL[0]),
        tail_sink=sum(tail)/len(tail),acceptance=(outcomes.get('Accepted',0)/attempts) if attempts else None,attempts=attempts,outcomes=dict(outcomes),ages={str(k):v for k,v in ages.items()},
        after_bits=[s['after_step']['bits'] for s in d['steps']],lost=lost)

def decide(rows):
    pairs=[];verdict={}
    for s in ['tree','building']:
        eligible=[]
        for host in ['windows','linux']:
            for w in [1,4]:
                pick={v['arm']:v for v in rows if (v['host'],v['workers'],v['structure'])==(host,w,s)}
                pre,post=pick.get('pre'),pick.get('post')
                if pre is None or post is None:pairs.append(dict(structure=s,host=host,workers=w,eligible=False,reason='missing'));continue
                dsink=post['tail_sink']-pre['tail_sink'];dlost=post['lost_tail_per_step']-pre['lost_tail_per_step']
                ok=pre['valid'] and post['valid'] and (post['acceptance'] or 0)>=.5 and dsink>=.002
                row=dict(structure=s,host=host,workers=w,eligible=ok,delta_sink=dsink,delta_lost=dlost,ratio=dlost/dsink if dsink else None,
                    pre_gate=pre['gate_fraction'],post_gate=post['gate_fraction'],post_acceptance=post['acceptance'])
                pairs.append(row)
                if ok:eligible.append(row)
        supported=len(eligible)>=3 and all(e['post_gate']>=.5 and e['pre_gate']<=.2 and .5<=e['ratio']<=2 for e in eligible)
        rejected=len(eligible)>=3 and sum(e['ratio']<.5 for e in eligible)>=3
        verdict[s]='SUPPORTED' if supported else 'REJECTED' if rejected else 'INCONCLUSIVE'
    overall='H_gate_SUPPORTED' if all(v=='SUPPORTED' for v in verdict.values()) else 'H_gate_REJECTED_AS_PRIMARY' if all(v=='REJECTED' for v in verdict.values()) else 'INCONCLUSIVE'
    return dict(pairs=pairs,structures=verdict,decision=overall)

def perturbation(rows,reference):
    ref=Path(reference);assert o.sha(ref/'receipt.json')==REFERENCE_RECEIPT_SHA;out=[]
    for v in rows:
        if v['host']!='windows' or v['arm']=='off':continue
        d=json.loads((ref/'windows'/f"{v['structure']}-packed_sand-{v['arm']}-w{v['workers']}.json").read_text(encoding='utf-8'))
        bits=[s['after_step']['bits'] for s in d['steps']];equal=sum(a==b for a,b in zip(v['after_bits'],bits))
        first=next((k for k,(a,b) in enumerate(zip(v['after_bits'],bits)) if a!=b),None)
        out.append(dict(structure=v['structure'],workers=v['workers'],arm=v['arm'],equal_steps=equal,first_difference=first))
    return dict(episodes=out,status='NON_PERTURBING_WINDOWS' if len(out)==8 and all(e['equal_steps']==720 for e in out) else 'PERTURBATION_UNRESOLVED')

def main():
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);ap.add_argument('--reference',required=True);ap.add_argument('--output',default='reduction.json');a=ap.parse_args()
    assert Path(a.run).name==a.run and Path(a.output).name==a.output
    folder=g.OUT/a.run;dst=folder/a.output;assert not dst.exists();receipt=json.loads((folder/'receipt.json').read_text(encoding='utf-8'));assert receipt['post_source_equality'];rows=[]
    for host,h in receipt['hosts'].items():
        assert not h['post_inventory_unexpected']
        for c in h['commands']:
            assert c['clean'] and o.sha(o.ROOT/c['log'])==c['log_sha256']
            if 'report' not in c:continue
            assert c['report_complete'];path=o.ROOT/c['report']['path'];assert o.sha(path)==c['report']['sha256']
            v=episode(json.loads(path.read_text(encoding='utf-8')));assert v['host']==host and v['source']==receipt['identity']['source_commit'];v['raw']=c['report'];rows.append(v)
    smoke=receipt['smoke'];result=dict(receipt_sha256=o.sha(folder/'receipt.json'),reducer_sha256=o.sha(__file__),registration_sha256=receipt['registration_sha256'],smoke=smoke)
    if not smoke:
        assert len(rows)==24;result['decision']=decide(rows);result['perturbation']=perturbation(rows,a.reference)
    result['episodes']=[{k:v for k,v in row.items() if k!='after_bits'} for row in rows]
    result['qualifiers']=['Lost correction is first-order accounting of the unchanged native law, not a counterfactual trajectory.','Ordinary impulse, Sand impulse and damping are not attributed here.','Asynchronous Linux schedules are descriptive; Windows bit equality is the registered non-perturbation control.','Smoke outcomes are excluded from decisions.' if smoke else 'Registered matrix.']
    p.write(dst,result)
    for v in result['episodes']:
        print(v['host'],v['workers'],v['structure'],v['arm'],'valid',v['valid'],'gate',None if v['gate_fraction'] is None else round(v['gate_fraction'],3),'lost_tail/step',round(v['lost_tail_per_step'],5),'sink',round(v['tail_sink'],5),'acc',v['acceptance'],v['counts'],'model',v['model_checks'],v['model_failures'])
    if not smoke:print(json.dumps(result['decision']['structures']),result['decision']['decision'],result['perturbation']['status'])

if __name__=='__main__':main()
