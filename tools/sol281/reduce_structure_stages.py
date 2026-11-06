"""Independent four-stage structural load/accounting diagnosis; no physics code imports."""
import argparse,collections,hashlib,json,math,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/sol281'))
import reduce_structure_cut as base
def f(x):return struct.unpack('<f',struct.pack('<f',x))[0]
def floats(s):
    b=bytes.fromhex(s);assert len(b)%4==0;return struct.unpack('<'+'f'*(len(b)//4),b)
def add(a,b):return (a[0]+b[0],a[1]+b[1])
def sub(a,b):return (a[0]-b[0],a[1]-b[1])
def mul(a,k):return (a[0]*k,a[1]*k)
def dot(a,b):return a[0]*b[0]+a[1]*b[1]
def norm2(a):return f(f(a[0]*a[0])+f(a[1]*a[1]))
def length(a):return f(math.sqrt(norm2(a)))
def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def momentum(a,b):return mul(sub(b[6:8],a[6:8]),a[9])
def clipped_velocity(v,c):return tuple(0. if c[i]!=0 and v[i]*c[i]<0 else v[i] for i in range(2))
def energy(s,r):
    com=base.transform(s[:6],r['local_com']);return base.ke(s)-s[9]*dot(r['gravity'],com)
def load_reference(m,g,dt):return m*math.hypot(*g)*dt
def support(j,g):
    size=math.hypot(*g);return -dot(j,g)/size if size else None
def normalize(j,g,load):
    value=support(j,g);return value/load if value is not None and load else None
def wrench(raw,centres,pose,scale):
    proposed=(0.,0.);applied=(0.,0.);torque=0.;kept=0;discarded=0.;scaled_magnitudes=0.
    for index,centre in enumerate(centres):
        j=tuple(f(x*f(scale)) for x in raw[index]);proposed=add(proposed,j);scaled_magnitudes+=length(j)
        if norm2(j)<=1e-6:discarded+=length(j);continue
        # Float32 transform then subtract origin, matching the existing offset ABI.
        offset=tuple(f(f(f(f(pose[k]*centre[0])+f(pose[k+2]*centre[1]))+pose[k+4])-pose[k+4]) for k in range(2))
        applied=add(applied,j);torque+=cross(offset,j);kept+=1
    return dict(proposed=proposed,applied=applied,torque=torque,applications=kept,discarded_magnitude=discarded,scaled_magnitudes=scaled_magnitudes)
def ordinary_model(mid,d,pose):
    receipt=mid['receipt'];results=floats(mid['native_results_bits']);states=floats(mid['native_states_bits']);count=len(d['proxy_centres'])
    assert len(results)==count*9 and len(states)==count*11 and all(math.isfinite(x) for x in results+states)
    assert sorted(int(results[i*9]) for i in range(count))==list(range(1,count+1))
    assert len({results[i*9+8] for i in range(count)})==1
    raw=[None]*count
    for i in range(count):raw[int(results[i*9])-1]=results[i*9+1:i*9+3]
    if not receipt['accepted']:return dict(accepted=False,raw_magnitudes=sum(length(x) for x in raw))
    sample=int(receipt['sample_serial']);assert all(results[i*9+8]==sample for i in range(count))
    current=int(mid['state']['sample_serial']);age=(current-sample+1000000)%1000000;assert age<=8
    scale=1/(1+age*.25);budget=sum(length(x)*scale for x in raw);saturated=budget>3.
    if saturated:scale*=3/budget
    out=wrench(raw,d['proxy_centres'],pose,scale);out.update(accepted=True,age=age,raw_magnitudes=sum(length(x) for x in raw),cap_denominator=budget,cap_hit=saturated,scale=scale)
    assert out['applications']==receipt['impulse_applications'],'application threshold/count disagreement'
    return out
def step(row,d,previous=None):
    r0=row['before'];r2=row['after_application'];r3=row['after_step'];mid=row['ordinary_stage'];observed=mid['observed']
    r1=mid['state'] if observed else r0;states=[base.state(r) for r in [r0,r1,r2,r3]];s0,s1,s2,s3=states
    assert [r['manual_step'] for r in [r0,r1,r2,r3]]==[row['step']]*3+[row['step']+1]
    assert row['ordinary_stage_calls']==int(observed)
    assert all(r['body_rid']==d['body_rid'] and r['generation']==r0['generation'] and r['physics_epoch']==r0['physics_epoch'] for r in [r0,r1,r2,r3])
    assert all(s[9:11]==s0[9:11] and all(math.isfinite(x) for x in s) for s in states)
    assert all(r['gravity']==r0['gravity'] and r['fixed_delta']==r0['fixed_delta'] for r in [r1,r2,r3])
    continuity=previous is None or r0['bits']==previous['bits'];assert continuity,'unexplained rigid-state change between manual steps'
    receipt=mid['receipt'] if observed else {};correction=(0.,0.);model=None
    if observed:
        assert mid['owner_epoch']==r0['physics_epoch'] and mid['snapshot_serial']==r1['snapshot_serial'] and mid['native_tick']==r1['native_tick']
        if not receipt['accepted']:assert r0['bits']==r1['bits']
        elif receipt['correction_applications']:correction=tuple(receipt['correction'])
        model=ordinary_model(mid,d,s1[:6])
    else:assert r0['bits']==r2['bits']
    expected_position=tuple(f(s0[4+i]+correction[i]) for i in range(2));assert tuple(s1[4:6])==expected_position
    assert s1[:4]==s0[:4] and s2[:6]==s1[:6],'application stage changed angular pose or Sand changed pose'
    vc=clipped_velocity(s0[6:8],correction);j0=mul(sub(s1[6:8],vc),s0[9]);js=momentum(s1,s2);jb=momentum(s2,s3)
    clip_ke=.5*s0[9]*(dot(vc,vc)-dot(s0[6:8],s0[6:8]));clip_j=mul(sub(vc,s0[6:8]),s0[9]);tau0=s0[10]*(s1[8]-s0[8]);taus=s0[10]*(s2[8]-s1[8])
    e=[energy(s,r) for s,r in zip(states,[r0,r1,r2,r3])];de=[e[i+1]-e[i] for i in range(3)]
    assert abs((e[3]-e[0])-sum(de))<=256*sys.float_info.epsilon*max(1.,*[abs(x) for x in e])
    response=row['response'];response_new=row['response_is_new'];accepted=response_new and response.get('accepted',False)
    if not accepted and not (response_new and response.get('failed',False)):assert r1['bits']==r2['bits']
    g=r0['gravity'];dt=r0['fixed_delta'];load=load_reference(s0[9],g,dt);dx=sub(s1[4:6],s0[4:6]);correction_u=-s0[9]*dot(g,dx)
    native_residual=None;native_torque_residual=None
    if model and model['accepted']:
        native_residual=sub(j0,model['applied']);native_torque_residual=tau0-model['torque']
    # Numeric model residuals are diagnostics, not tuned physical acceptance bounds.
    pub=row['contact_observation'].get('published_usec');age_usec=mid['capture_usec']-pub if observed and isinstance(pub,(int,float)) else None
    return dict(step=row['step'],ordinary_executed=observed,ordinary_outcome=receipt.get('outcome','NOT_EXECUTED'),sand_executed=response_new,sand_outcome=response.get('outcome') if response_new else 'NOT_EXECUTED',
        native_tick=r1['native_tick'],snapshot=r1['snapshot_serial'],sample=r1['sample_serial'],publication_age_usec=age_usec,
        gravity_load_reference=load,nominal_mg_over60=s0[9]*math.hypot(*g)/60,
        ordinary_impulse=j0,ordinary_torque=tau0,ordinary_support_ratio=normalize(j0,g,load),clip_impulse=clip_j,clip_support_ratio=normalize(clip_j,g,load),clip_ke=clip_ke,
        correction=dx,correction_potential=correction_u,correction_mechanical=clip_ke+correction_u,ordinary_impulse_ke=base.ke(s1)-base.ke(s0)-clip_ke,
        sand_impulse=js,sand_torque=taus,sand_support_ratio=normalize(js,g,load),sand_ke=base.ke(s2)-base.ke(s1),backend_impulse=jb,backend_ke=base.ke(s3)-base.ke(s2),
        stage_energy=de,total_energy_change=e[3]-e[0],ordinary_model=model,ordinary_momentum_residual=native_residual,ordinary_torque_residual=native_torque_residual,
        wake_request=bool(observed and receipt.get('accepted') and (receipt.get('correction_applications',0) or receipt.get('impulse_applications',0))),
        wake_transition=[r0['sleeping'] and not r1['sleeping'],r1['sleeping'] and not r2['sleeping'],r2['sleeping'] and not r3['sleeping']],
        ordinary_v0=list(s0[6:8]),after_ordinary_velocity=list(s1[6:8]),after_sand_velocity=list(s2[6:8]),after_rapier_velocity=list(s3[6:8]),
        ordinary_omega0=s0[8],after_ordinary_omega=s1[8],after_sand_omega=s2[8],after_rapier_omega=s3[8],sleeping=r3['sleeping'])
def window(rows):
    load=sum(r['gravity_load_reference'] for r in rows)
    def ratio(key):return sum((r[key] or 0)*r['gravity_load_reference'] for r in rows)/load if load else None
    energies=[sum(r['stage_energy'][i] for r in rows) for i in range(3)];positive=[sum(max(0.,r['stage_energy'][i]) for r in rows) for i in range(3)]
    return dict(samples=len(rows),gravity_load_sum=load,ordinary_support_ratio=ratio('ordinary_support_ratio'),clip_support_ratio=ratio('clip_support_ratio'),sand_support_ratio=ratio('sand_support_ratio'),stage_energy_sum=energies,stage_energy_positive_sum=positive,clip_ke=sum(r['clip_ke'] for r in rows),correction_potential=sum(r['correction_potential'] for r in rows),ordinary_impulse_ke=sum(r['ordinary_impulse_ke'] for r in rows),sand_ke=sum(r['sand_ke'] for r in rows),
        correction_steps=sum(r['correction']!= (0.,0.) for r in rows),clip_steps=sum(r['clip_ke']<0 for r in rows),wake_requests=sum(r['wake_request'] for r in rows),ordinary_outcomes=dict(collections.Counter(r['ordinary_outcome'] for r in rows)),sand_outcomes=dict(collections.Counter(r['sand_outcome'] for r in rows)),
        cap_hits=sum(bool(r['ordinary_model'] and r['ordinary_model'].get('cap_hit')) for r in rows),discarded_impulse_magnitude=sum(r['ordinary_model'].get('discarded_magnitude',0) if r['ordinary_model'] else 0 for r in rows),
        peak_speed=max(math.hypot(*r['after_rapier_velocity']) for r in rows),rms_speed=math.sqrt(sum(dot(r['after_rapier_velocity'],r['after_rapier_velocity']) for r in rows)/len(rows)),peak_abs_omega=max(abs(r['after_rapier_omega']) for r in rows),sleeping=sum(r['sleeping'] for r in rows),
        max_ordinary_momentum_residual=max((math.hypot(*r['ordinary_momentum_residual']) for r in rows if r['ordinary_momentum_residual'] is not None),default=None))
def episode(d):
    assert d['stage_trace'] and d['stage_registration']=='SOL-STRUCTURE-STAGES-001' and not d['failures'];rows=[];previous=None
    for r in d['steps']:rows.append(step(r,d,previous));previous=r['after_step']
    return dict(full=window(rows),tail120=window(rows[-120:]),window=[len(rows)-120,len(rows)-1],rows=rows)
def main():
    p=argparse.ArgumentParser(__doc__);p.add_argument('--runs',nargs='+',required=True);p.add_argument('--output',type=Path,required=True);args=p.parse_args();assert not args.output.exists();episodes=[];receipts=[]
    for run in args.runs:
        folder=ROOT/'build/sol-structure-cut'/run;r=json.loads((folder/'receipt.json').read_text(encoding='utf-8'));assert r['post_source_equality'] and r['matrix']['stage_trace'];receipts.append(dict(run=run,sha256=base.sha(folder/'receipt.json'),source=r['identity']['source_commit']))
        for host,h in r['hosts'].items():
            expected={}
            for w in map(int,r['matrix']['workers'].split(',')):
                for structure in ['tree','building']:
                    for response in ([False,True] if r['matrix']['suite']=='packed' else [False]):
                        surroundings='packed_sand' if r['matrix']['suite']=='packed' else 'empty';expected[f'{structure}-{surroundings}-response{int(response)}-w{w}']=(structure,surroundings,response,w)
            for c in base.physical_commands(h['commands'],expected):
                raw=c['report'];path=ROOT/raw['path'].replace('\\','/');assert c['clean'] and c['report_complete'] and base.sha(path)==raw['sha256'];d=json.loads(path.read_text(encoding='utf-8'));base.coordinate(d,host,*expected[c['name']],r['identity']['source_commit']);qualified=base.episode(d,raw);trace=episode(d)
                trace.update(run=run,host=host,structure=d['structure'],workers=d['workers'],sand_response=d['sand_response'],raw=raw,registered_dry_rest=qualified['tail120'] if d['surroundings']=='empty' else None,terminal_hard=qualified['terminal_hard'],terminal_sand=qualified['terminal_sand'],native_material_counts=qualified['native_material_counts']);episodes.append(trace)
    output=dict(reducer_sha256=base.sha(__file__),base_reducer_sha256=base.sha(base.__file__),receipts=receipts,episodes=episodes,qualifiers=['Actual stage attribution, not counterfactual causation or schedule-matched replay.','M*g*dt is a load reference including zero/refused/sleeping frames. Correction clipping and potential work are separate from applied impulses.','Native wrench float32 reconstruction residual is diagnostic; backend stage includes gravity/damping/hardcontact/wake/integration; cached contact impulses never integrated. No closed-system energy/physical clearance/CPU acceptance.'])
    args.output.write_text(json.dumps(output,indent=2)+'\n',encoding='utf-8');print('episodes',len(episodes),'steps',sum(len(e['rows']) for e in episodes))
if __name__=='__main__':main()
