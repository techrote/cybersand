#!/usr/bin/env python3
"""Evaluate all preregistered operator equations; never fit coefficients."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct
import sol_node_trace_reduce as paths

ROOT=Path(__file__).resolve().parents[2]
MODELS=['gravity-only','gravity-then-rational-damping','rational-damping-then-gravity','gravity-then-linear-damping']
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_text(json.dumps(v,indent=2,allow_nan=False)+'\n',encoding='utf-8')
def f32(x):return struct.unpack('<f',struct.pack('<f',x))[0]
def motion(state):
    values=struct.unpack('<3d',bytes.fromhex(state['velocity_omega_f64le']))
    assert all(math.isfinite(v) for v in values)
    energy=.5*state['mass']*math.fsum(v*v for v in values[:2])+.5*state['inertia']*values[2]**2
    assert math.isclose(energy,state['kinetic'],rel_tol=1e-12,abs_tol=1e-9)
    assert len(bytes.fromhex(state['pose_f64le']))==48 and state['contacts']==0
    assert not state['sleeping'] and state['mass']>0 and state['inertia']>0
    return list(values)
def predict(v,g,dl,da,model,precision):
    cast=f32 if precision=='float32' else float;dt=cast(1/60)
    v=list(map(cast,v));g=list(map(cast,g));dl=cast(dl);da=cast(da)
    rational=[cast(1/cast(1+cast(d*dt))) for d in [dl,da]]
    linear=[cast(max(0,cast(1-cast(d*dt)))) for d in [dl,da]]
    if model=='gravity-only':return [cast(v[k]+cast(g[k]*dt)) for k in [0,1]]+[v[2]]
    if model=='gravity-then-rational-damping':return [cast(cast(v[k]+cast(g[k]*dt))*rational[0]) for k in [0,1]]+[cast(v[2]*rational[1])]
    if model=='rational-damping-then-gravity':return [cast(cast(v[k]*rational[0])+cast(g[k]*dt)) for k in [0,1]]+[cast(v[2]*rational[1])]
    if model=='gravity-then-linear-damping':return [cast(cast(v[k]+cast(g[k]*dt))*linear[0]) for k in [0,1]]+[cast(v[2]*linear[1])]
    raise ValueError(model)

def audit(data,profile):
    assert data['registration']==profile['registration'] and not data['failures']
    expected=Counter((m,s['id']) for m in profile['models'] for s in profile['initial_states'])
    assert Counter((e['model'],e['initial_motion']['id']) for e in data['episodes'])==expected
    results=[]
    for episode in data['episodes']:
        assert episode['native_World']=='ABSENT' and episode['native_workers']=='NOT_APPLICABLE' and episode['teardown']
        assert episode['initial_motion']==next(s for s in profile['initial_states'] if s['id']==episode['initial_motion']['id'])
        steps=episode['steps'];assert len(steps)==profile['steps']==32
        first=motion(steps[0]['before']);assert first[:2]==episode['initial_motion']['velocity']
        assert abs(first[2]-episode['initial_motion']['omega'])<=1e-7 # authored f32 setter
        for i,s in enumerate(steps):
            assert s['step']==i and s['after']['manual_step']==s['before']['manual_step']+1
            assert s['before']['manual_step']==i+1
            motion(s['before']);motion(s['after'])
            if i:assert s['before']==steps[i-1]['after']
            for key in ['gravity','linear_damp','angular_damp','reported_step']:
                assert s['before'][key]==steps[0]['before'][key] and s['after'][key]==s['before'][key]
            assert all(math.isfinite(v) for v in s['before']['gravity'])
            assert all(math.isfinite(s['before'][key]) and s['before'][key]>=0 for key in ['linear_damp','angular_damp','reported_step'])
            assert s['before']['reported_step']>0
        models=[]
        for name in MODELS:
            for precision in ['float64','float32']:
                one=[];trajectory=[];current=first.copy()
                for s in steps:
                    b=s['before'];actual=motion(s['after']);args=(b['gravity'],b['linear_damp'],b['angular_damp'],name,precision)
                    prediction=predict(motion(b),*args);current=predict(current,*args)
                    one.append(max(abs(x-y) for x,y in zip(prediction,actual)));trajectory.append(max(abs(x-y) for x,y in zip(current,actual)))
                models.append(dict(model=name,precision=precision,maximum_one_step_error=max(one),maximum_full_trajectory_error=max(trajectory),
                    final_full_trajectory_error=trajectory[-1],one_step_compatible=max(one)<=profile['gate']['absolute_velocity_omega_error']))
        results.append(dict(model=episode['model'],initial=episode['initial_motion']['id'],properties=episode['properties'],
            effective_gravity=steps[0]['before']['gravity'],effective_linear_damp=steps[0]['before']['linear_damp'],effective_angular_damp=steps[0]['before']['angular_damp'],
            reported_step=steps[0]['before']['reported_step'],steps=32,models=models))
    aggregate=[]
    for name in MODELS:
        for precision in ['float64','float32']:
            selected=[r for e in results for r in e['models'] if r['model']==name and r['precision']==precision]
            aggregate.append(dict(model=name,precision=precision,maximum_one_step_error=max(v['maximum_one_step_error'] for v in selected),
                maximum_full_trajectory_error=max(v['maximum_full_trajectory_error'] for v in selected),compatible=all(v['one_step_compatible'] for v in selected)))
    return dict(status='COMPLETE',episodes=len(results),body_steps=sum(r['steps'] for r in results),results=results,aggregate=aggregate)

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('directory',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    assert not args.output.exists();args.output.mkdir(parents=True)
    head=paths.source_head();receipt_path=args.directory/'receipt.json';receipt=read(receipt_path);profile=read(ROOT/'native/tests/fixtures/sol_gravity_operator_001.json')
    assert receipt['post_source_equality'] and receipt['registration']==profile
    results={}
    for host,state in receipt['hosts'].items():
        assert host in ['windows','linux'] and not state['post_inventory']['unexpected_changes'] and all(c['clean'] for c in state['commands'])
        meta=state['observations'];path=ROOT/meta['path'].replace('\\','/');assert sha(path)==meta['sha256'] and path.stat().st_size==meta['bytes']
        data=read(path);assert data['source']==receipt['identity']['source'];results[host]=dict(audit(data,profile),raw=meta,checks=data['checks'])
    assert set(results)=={'windows','linux'}
    summary=dict(registration=profile['registration'],analysis_source=head,execution_source=receipt['identity']['source'],input_receipt_sha256=sha(receipt_path),hosts=results,
        status='COMPLETE',episodes=18,body_steps=576,physics_promotion='NOT_ADMITTED',qualification='No-contact operator only; actual host equations, no predicted contact or original SOL recovery.')
    assert head==paths.source_head();write(args.output/'manifest.json',summary)
    print(json.dumps({h:r['aggregate'] for h,r in results.items()},indent=2));return 0

if __name__=='__main__':raise SystemExit(main())
