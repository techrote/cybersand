#!/usr/bin/env python3
"""Independent input, impulse, energy and trace accounting."""
import math

def kinetic(body,v,w):return .5*body['mass']*sum(x*x for x in v)+.5*body['inertia']*w*w
def near(a,b,tol=1e-12):return abs(a-b)<=tol

def record(case,rec,arm):
    assert rec['id']==case['id'] and rec['replays_equal']
    obs=rec['observation'];b=case['body'];result=obs['result'];nodes=obs['nodes']
    assert obs['body']==b and obs['null_bin']==case['null_bin']
    assert all(obs[k]==v for k,v in case['solve'].items())
    assert len(obs['input_bins'])==len(case['bins'])
    for actual,spec in zip(obs['input_bins'],case['bins']):
        points=spec['points'];n=spec['normal'];count=len(points);coords=[-n[1]*p[0]+n[0]*p[1] for p in points]
        mean=sum(coords)/count if count else 0
        expected=dict(tangent_mean=mean,tangent_m2=sum((x-mean)**2 for x in coords),tangent_min=min(coords,default=0),tangent_max=max(coords,default=0),maximum_radius=max((math.hypot(p[0]-b['com'][0],p[1]-b['com'][1]) for p in points),default=0))
        assert actual['count']==count and actual['normal']==(n if count else [0,0]) and actual['position_sum']==[sum(p[i] for p in points) for i in range(2)]
        assert actual['material_mask']==0 and actual['state_b_min']==255 and actual['state_b_max']==0
        assert all(near(actual[k],v) for k,v in expected.items())
        if count:assert near(sum(x*x for x in n),1)
    early=case['null_bin'] or len(case['bins'])>512
    if early:
        assert result['passive_rejected'] and result['scale']==0 and not nodes and not rec['trace']
        return dict(id=case['id'],refused=True,early_refusal=True)
    assert result['nodes']==len(nodes) and result['updates']==8*len(nodes)
    total_samples=sum(len(x['points']) for x in case['bins']);s=case['solve']
    capacity=min(max(0,min(s['available'],s['base_budget']*s['capacity_scale'])),2*total_samples*s['capacity_scale'])
    assert near(result['capacity'],capacity,1e-10)
    expected_nodes=[];clamps=0
    for spec in case['bins']:
        points=spec['points'];count=len(points)
        if not count:continue
        n=spec['normal'];t=[-n[1],n[0]];center=[sum(p[k] for p in points)/count for k in range(2)]
        coords=[sum(p[k]*t[k] for k in range(2)) for p in points];mean=sum(coords)/count
        sigma=math.sqrt(sum((x-mean)**2 for x in coords)/count);extent=max(0,min(mean-min(coords),max(coords)-mean));distance=min(sigma,extent)
        clamps+=sigma>extent+1e-12;signs=[-1,1] if distance else [0]
        for sign in signs:
            weight=count/total_samples/len(signs)
            expected_nodes.append(dict(position=[center[k]+sign*t[k]*distance for k in range(2)],normal=n,weight=weight,capacity=capacity*weight))
    assert len(nodes)==len(expected_nodes) and result['quadrature_clamps']==clamps and result['bins']==sum(bool(b['points']) for b in case['bins'])
    for actual,expected in zip(nodes,expected_nodes):
        assert all(near(a,z) for a,z in zip(actual['position'],expected['position'])) and actual['normal']==expected['normal']
        assert near(actual['weight'],expected['weight']) and near(actual['capacity'],expected['capacity'],1e-10)
    impulse=[0.,0.];torque=0.;normal=0.
    for node in nodes:
        assert -1e-12<=node['jn']<=node['capacity']+1e-12 and abs(node['jt'])<=b['mu']*node['jn']+1e-12
        n=node['normal'];t=[-n[1],n[0]];j=[n[k]*node['jn']+t[k]*node['jt'] for k in range(2)]
        r=[node['position'][k]-b['com'][k] for k in range(2)]
        impulse=[impulse[k]+j[k] for k in range(2)];torque+=r[0]*j[1]-r[1]*j[0];normal+=node['jn']
    assert impulse==result['raw_impulse'] and torque==result['raw_torque'] and normal<=capacity+1e-10
    v=[b['velocity'][k]+result['impulse'][k]/b['mass'] for k in range(2)];omega=b['omega']+result['torque']/b['inertia']
    before=kinetic(b,b['velocity'],b['omega']);after=kinetic(b,v,omega)
    assert near(before,result['energy_before'],1e-10) and near(after,result['energy_after'],1e-10)
    assert after<=before+1e-6*max(1,before)+1e-10
    if result['passive_rejected']:assert result['impulse']==[0,0] and result['torque']==0
    else:assert result['impulse']==result['raw_impulse'] and result['torque']==result['raw_torque']
    trace=rec['trace'];normal_increases=[];tangent_increases=[];previous_v=b['velocity'];previous_w=b['omega']
    if arm:assert len(trace)==8
    else:assert not trace
    for index,t in enumerate(trace):
        assert t['pass']==index//2 and t['axis']==index%2 and t['nodes']==len(nodes) and t['snapshots']==min(32,len(nodes))
        assert t['before']==previous_v and t['omega_before']==previous_w
        assert near(t['energy_before'],kinetic(b,t['before'],t['omega_before']),1e-10) and near(t['energy_after'],kinetic(b,t['after'],t['omega_after']),1e-10)
        previous_v=t['after'];previous_w=t['omega_after'];delta=t['energy_after']-t['energy_before']
        if t['axis']:tangent_increases.append(delta)
        else:normal_increases.append(delta)
        flags=[]
        for i,node in enumerate(nodes[:t['snapshots']]):
            r=[node['position'][k]-b['com'][k] for k in range(2)];n=node['normal']
            speed=(t['before'][0]-t['omega_before']*r[1])*n[0]+(t['before'][1]+t['omega_before']*r[0])*n[1]
            active=speed<0 or t['jn_before'][i]>0;flags.append(active)
            assert -1e-12<=t['jn_after'][i]<=node['capacity']+1e-12
            if t['axis']:assert abs(t['jt_after'][i])<=b['mu']*t['jn_after'][i]+1e-12
            else:
                assert t['active'][i]==active
                expected=node['weight']
                if arm==2 and t['active_count']!=len(nodes):expected=node['weight']/t['active_weight'] if active and t['active_weight']>0 else 0
                assert t['weight_used'][i]==expected
        if not t['axis'] and len(nodes)<=32:
            assert t['active_count']==sum(flags) and near(t['active_weight'],sum(n['weight'] for n,a in zip(nodes,flags) if a))
    residual=[(v[0]-omega*(n['position'][1]-b['com'][1]))*n['normal'][0]+(v[1]+omega*(n['position'][0]-b['com'][0]))*n['normal'][1] for n in nodes]
    if trace:
        raw_v=[b['velocity'][k]+result['raw_impulse'][k]/b['mass'] for k in range(2)];raw_w=b['omega']+result['raw_torque']/b['inertia']
        assert all(near(a,z) for a,z in zip(trace[-1]['after'],raw_v)) and near(trace[-1]['omega_after'],raw_w),'Final trace/wrench mismatch'
    return dict(id=case['id'],refused=result['passive_rejected'],early_refusal=False,velocity=v,omega=omega,energy_before=before,energy_after=after,energy_delta=after-before,
        maximum_approach_speed=max([-x for x in residual if x<0],default=0),normal_energy_increase_max=max(normal_increases,default=0),tangent_energy_increase_max=max(tangent_increases,default=0),
        normal_unwinds=sum(t['normal_unwinds'] for t in trace),tangent_unwinds=sum(t['tangent_unwinds'] for t in trace),normal_cap_hits=result['normal_cap_hits'],nodes=len(nodes),capacity=capacity)
