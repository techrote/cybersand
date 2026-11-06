"""Independent full-coverage reduction; imports no candidate decision code."""
import argparse,collections,gzip,hashlib,json,math,statistics,struct
from pathlib import Path
import structure_cut as p
import workbench_common as w
import reduce_structure_cut as r

def load(path):
    raw=path.read_bytes();return json.loads((gzip.decompress(raw) if path.suffix=='.gz' else raw).decode('utf-8'))
def cells(receipt):
    tiles=receipt['diagnostic_tiles'];assert len(tiles)==4;out={};seen=set();ticks=set();hashes=set();water=0
    for d in tiles:
        assert d['size']==[512,512] and tuple(d['origin']) in {(0,0),(512,0),(0,512),(512,512)}
        origin=tuple(d['origin']);assert origin not in seen;seen.add(origin)
        part=r.cells({'diagnostic_snapshot':d});assert not out.keys()&part.keys();out.update(part)
        ticks.add(d['completed_ticks']);hashes.add(d['hash']);water+=d['water_mass'];assert not d['failed']
    assert len(ticks)==len(hashes)==1
    return out,water,next(iter(ticks))
def stats(a):
    q=statistics.quantiles(a,n=4,method='inclusive') if len(a)>1 else [a[0]]*3
    return dict(values=a,median=statistics.median(a),min=min(a),max=max(a),iqr=q[2]-q[0])
def com(body):
    return r.transform(r.state(body)[:6],body['local_com'])
def ulp32(value):
    bits=struct.unpack('<I',struct.pack('<f',abs(value)))[0]
    return struct.unpack('<f',struct.pack('<I',bits+1))[0]-struct.unpack('<f',struct.pack('<I',bits))[0]
def application_readback(b,a,action):
    velocity=[b[6],b[7]];clip_y=0.
    for axis in [0,1]:
        if velocity[axis]*action['correction'][axis]<0:
            if axis==1:clip_y=-b[9]*velocity[axis]
            velocity[axis]=0.
    residual=[b[9]*(a[6+k]-velocity[k])-action['impulse'][k] for k in [0,1]]
    torque=b[10]*(a[8]-b[8])-action['torque']
    for k in [0,1]:
        bound=16*b[9]*max(ulp32(velocity[k]),ulp32(a[6+k]),ulp32(action['impulse'][k]/b[9]))
        assert abs(residual[k])<=bound,'Workbench actual impulse differs beyond propagated float32 precision'
    bound=16*b[10]*max(ulp32(b[8]),ulp32(a[8]),ulp32(action['torque']/b[10]))
    assert abs(torque)<=bound,'Workbench actual torque differs beyond propagated float32 precision'
    return residual,torque,clip_y
def body_ok(body,d,n,inertia):
    a=r.state(body);assert body['valid'] and not body['frozen'] and all(math.isfinite(x) for x in a)
    assert a[9]==n and r.near(a[10],inertia) and body['body_rid']==d['body_rid'] and body['body_instance']==d['body_instance']
    assert body['generation']==d['initial_body']['generation'] and body['physics_epoch']==d['initial_body']['physics_epoch']
    for key in ['gravity','linear_damp','angular_damp','fixed_delta','terrain_revision']:assert body[key]==d['initial_body'][key]
def episode(d):
    assert not d['apparatus_only'] and not d['failures'] and d['registration']=='SOL-WORKBENCH-LAW-001' and len(d['steps'])==720
    n=520 if d['structure']=='tree' else 356;r.handoff(d,n);pre=d['prepared']
    members=[tuple(pre['members'][i:i+6]) for i in range(0,len(pre['members']),6)];xy={(m[0],m[1]) for m in members}
    assert len(xy)==len(members)==n and all(m[2:]==(43,0,0,200) for m in members)
    cx=sum(x+.5 for x,y in xy)/n;cy=sum(y+.5 for x,y in xy)/n;inertia=sum((x+.5-cx)**2+(y+.5-cy)**2+1/6 for x,y in xy)
    union=set();rects=pre['rectangles']
    for i,shape in enumerate(d['server_shapes']):
        x,y,dx,dy=rects[4*i:4*i+4];part={(xx,yy) for yy in range(y,y+dy) for xx in range(x,x+dx)};assert not union&part;union|=part
        assert shape['type']==4 and not shape['owner_disabled'] and shape['data']==[dx/2,dy/2]
        t=shape['transform'];assert t[:4]==[1.,0.,0.,1.] and r.near(t[4],x+dx/2-pre['center'][0]) and r.near(t[5],y+dy/2-pre['center'][1])
    assert union==xy and len(d['server_shapes'])==(6 if n==520 else 5) and sum(d['proxy_masses'])==n
    if n==520:assert (60,32) not in xy and (68,50) not in xy
    before,wb,tb=cells(d['before_cut']);initial,wi,ti=cells(d['initial_native']);final,wf,tf=cells(d['final_native'])
    count=collections.Counter(initial.values());end_count=collections.Counter(final.values())
    assert {m:v for m,v in count.items() if m!=3}=={m:v for m,v in end_count.items() if m!=3} and wi==wf,'Native granular/hard or stored Water mass changed'
    policies=[x['liquid_policy'] for x in [d['before_cut'],d['initial_native'],d['final_native']]]
    assert len({x['policy_hash'] for x in policies})==1 and all(x['admission']=='current_defaults_only' for x in policies)
    water_policy=next(x for x in policies[0]['assignments'] if x['material']==3)
    assert water_policy['applied_family']=='freemass_v1' and water_policy['applied_variant']=='reference'
    assert collections.Counter(before.values())[43]-count[43]==n+8
    for native in [d['initial_native'],d['final_native']]:assert native['aggregate_owned']==n and native['native_source_members']==0 and native['members']==pre['members'] and not native['worker_failed'] and native['configured_workers']==d['workers']
    hard={q:m for q,m in initial.items() if m in [1,43]};assert hard=={q:m for q,m in final.items() if m in [1,43]}
    ages=collections.Counter();outcomes=collections.Counter();arrivals=missing=misaligned=0;main_usec=0;native_ticks=[];mechanical=0.;jysum=0.;clip_sum=0.;max_ke_gain=0.;ledger=[]
    previous=d['initial_body']['bits']
    for i,row in enumerate(d['steps']):
        assert row['step']==i and row['before']['bits']==previous;previous=row['after_step']['bits']
        for key in ['before','after_application','after_step']:body_ok(row[key],d,n,inertia)
        assert row['before']['manual_step']==i and row['after_step']['manual_step']==i+1 and row['audit']['outcome']=='Published'
        b=r.state(row['before']);a=r.state(row['after_application']);z=r.state(row['after_step']);main_usec+=row['elapsed_usec']
        native_ticks.append(row['after_step']['native_tick']);age=row.get('incoming_age',-1);ages[str(age)]+=1
        if d['arm']=='workbench-LA-SELECTIVE':
            packet=row['workbench_packet'];app=row['workbench_application'];assert packet['valid'] and packet['response']=='LA-SELECTIVE' and app['accepted']
            assert len(packet['rows'])==len(app['bodies'])==1
            q=packet['rows'][0];action=app['bodies'][0]
            assert q['mass']==n and r.near(q['inertia'],inertia) and q['proxy_count']==len(d['server_shapes']) and q['budget']==20 and q['body_capacity']==20*n
            assert not q['external_drive'] and q['generation']==d['initial_body']['physics_epoch'] and q['instance_id']==d['body_instance']
            assert q['sample']==row['before']['sample_serial']==action['sample'] and age==0 and action['age']==0
            assert packet['epoch']==d['initial_body']['physics_epoch'] and row['response_attempts_delta']==0 and 'ordinary' not in row
            arrivals+=q['arrival_count'];missing+=q['arrival_missing'];misaligned+=q['arrival_misaligned'];outcomes['Accepted']+=1
            # Record backend residuals, retaining correction/clipping separately
            # from impulse. Finite/ownership checks are hard admissions; no
            # fitted force/passivity clamp is added to main's combined packet.
            residual,torque_residual,clip=application_readback(b,a,action);clip_sum+=clip
            jysum+=action['impulse'][1]
        else:
            assert 'workbench_packet' not in row
            response=row.get('legacy_response',{})
            outcomes[response.get('outcome','Unknown') if row['response_attempts_delta'] else 'NOT_EVALUATED']+=1
            assert d['arm']=='legacy-pre' or row['response_attempts_delta']==0
            residual=None;torque_residual=None
        if d['arm']=='workbench-LA-SELECTIVE' or row['response_attempts_delta']:
            if 'before_sand' in row:
                u=r.state(row['before_sand']['state']);v=r.state(row['after_sand']['state']);max_ke_gain=max(max_ke_gain,r.ke(v)-r.ke(u))
        dy=com(row['after_step'])[1]-com(row['before'])[1];mechanical+=r.ke(z)-r.ke(b)-n*row['before']['gravity'][1]*dy
        ledger.append(dict(step=i,application_ke_change=r.ke(a)-r.ke(b),mechanical_change=r.ke(z)-r.ke(b)-n*row['before']['gravity'][1]*dy,application_linear_residual=residual,application_torque_residual=torque_residual))
    tail=d['steps'][600:];ys=[com(x['after_step'])[1] for x in tail];mean=statistics.mean(ys);sink=sum((i-59.5)*(y-mean) for i,y in enumerate(ys))/sum((i-59.5)**2 for i in range(120))
    finalpose=r.state(d['steps'][-1]['after_step'])[:6];sg=r.geometry(finalpose,d['server_shapes'],{q:m for q,m in final.items() if m==2});water=r.geometry(finalpose,d['server_shapes'],{q:m for q,m in final.items() if m==3});hg=r.geometry(finalpose,d['server_shapes'],hard)
    assert d['attempts']==720+d['no_step_attempts'] and sum(d['no_step_reasons'].values())==d['no_step_attempts']
    if d['arm']=='workbench-LA-SELECTIVE':assert d['metrics']['physical_contact']['response_attempts']==0
    return dict(host=d['platform'].lower(),structure=d['structure'],surroundings=d['surroundings'],workers=d['workers'],arm=d['arm'],repeat=d['repeat'],source=d['source'],steps=720,checks=d['checks'],ownership_pass=True,mass=n,inertia=r.state(d['initial_body'])[10],initial_material_sha256=hashlib.sha256(json.dumps(sorted(initial.items()),separators=(',',':')).encode()).hexdigest(),native_counts=dict(count),stored_water_mass=wf,native_census_ticks=[tb,ti,tf],tuple_sha256=hashlib.sha256(json.dumps(members,separators=(',',':')).encode()).hexdigest(),rest=r.rest([x['after_step'] for x in tail]),sink_cells_per_step=sink,sink_cells_per_second=sink*60,sand_terminal=sg,water_terminal=water,hard_terminal=hg,incoming_ages=dict(ages),response_outcomes=dict(outcomes),arrivals=arrivals,arrival_missing=missing,arrival_misaligned=misaligned,attempts=d['attempts'],no_step_attempts=d['no_step_attempts'],no_step_reasons=d['no_step_reasons'],main_ms_per_physical_step=d['attempt_usec']/1000/720,main_ms_per_attempt=d['attempt_usec']/1000/d['attempts'],native_tick_span=native_ticks[-1]-native_ticks[0],native_tick_deltas=dict(collections.Counter(b-a for a,b in zip(native_ticks,native_ticks[1:]))),mechanical_change=mechanical,declared_wb_jy_sum=jysum,wb_clip_momentum_y_sum=clip_sum,max_legacy_sand_ke_gain=max_ke_gain,metrics=d['metrics'],participation=d['participation'],ledger=ledger)

def main():
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);a=ap.parse_args();assert Path(a.run).name==a.run
    folder=w.OUT/a.run;dst=folder/'reduction.json';assert not dst.exists();receipt=load(folder/'receipt.json');assert receipt['post_source_equality'] and not receipt['errors'] and not receipt['matrix']['smoke']
    episodes=[]
    for host,h in receipt['hosts'].items():
        assert not h['post_inventory_unexpected'];seen=set()
        for c in h['commands']:
            assert c['clean'] and p.sha(w.ROOT/c['log'])==c['log_sha256']
            if 'report' not in c:continue
            raw=c['report'];path=w.ROOT/raw['path'];assert c['report_complete'] and p.sha(path)==raw['sha256']
            if 'raw_sha256' in raw:assert hashlib.sha256(gzip.decompress(path.read_bytes())).hexdigest()==raw['raw_sha256']
            d=load(path)
            row=episode(d);assert row['host']==host and row['source']==receipt['identity']['source_commit'];key=(row['workers'],row['repeat'],row['structure'],row['surroundings'],row['arm']);assert key not in seen;seen.add(key);row['raw']=raw;episodes.append(row)
        assert seen=={(k,i,s,e,arm) for k in [1,4] for i in range(5 if k==1 else 1) for s in ['tree','building'] for e in ['packed_sand','mixed'] for arm in ['legacy-off','legacy-pre','workbench-LA-SELECTIVE']}
    assert len(episodes)==144 and sum(x['steps'] for x in episodes)==103680
    groups={}
    for row in episodes:groups.setdefault((row['host'],row['workers'],row['structure'],row['surroundings'],row['arm']),[]).append(row)
    summaries=[];decisions=[]
    for key,rows in sorted(groups.items()):
        rows.sort(key=lambda x:x['repeat']);summary=dict(zip(['host','workers','structure','surroundings','arm'],key));summary.update(rest_count=sum(x['rest']['screen_pass'] for x in rows),repeats=len(rows),sand_area=stats([x['sand_terminal']['area'] for x in rows]),sand_depth=stats([x['sand_terminal']['depth'] for x in rows]),sink=stats([x['sink_cells_per_step'] for x in rows]),incoming_ages=[x['incoming_ages'] for x in rows],response_outcomes=[x['response_outcomes'] for x in rows],water_area=stats([x['water_terminal']['area'] for x in rows]));summaries.append(summary)
    for host in ['windows','linux']:
        for structure in ['tree','building']:
            for env in ['packed_sand','mixed']:
                rows=[x for x in summaries if (x['host'],x['workers'],x['structure'],x['surroundings'])==(host,1,structure,env)];wb=next(x for x in rows if x['arm']=='workbench-LA-SELECTIVE');old=next(x for x in rows if x['arm']=='legacy-pre')
                assert all(x['repeats']==5 for x in rows)
                initial={x['initial_material_sha256'] for x in episodes if (x['host'],x['workers'],x['structure'],x['surroundings'])==(host,1,structure,env)};assert len(initial)==1,'Initial material map changed across matched setups'
                rest=wb['rest_count']>=(3 if env=='packed_sand' else old['rest_count']);area=wb['sand_area']['median']<=old['sand_area']['median'];depth=wb['sand_depth']['median']<=old['sand_depth']['median'];decisions.append(dict(host=host,structure=structure,surroundings=env,decision='GO' if rest and area and depth else 'NO-GO',rest=rest,area=area,depth=depth))
    packed=all(x['decision']=='GO' for x in decisions if x['surroundings']=='packed_sand');mixed=all(x['decision']=='GO' for x in decisions if x['surroundings']=='mixed')
    p.write(dst,dict(registration='SOL-WORKBENCH-LAW-001',receipt_sha256=p.sha(folder/'receipt.json'),reducer_sha256=p.sha(__file__),decision='GO' if packed and mixed else 'CONDITIONAL' if packed else 'NO-GO',cell_decisions=decisions,cells=summaries,episodes=episodes,scope='Repeated law+pacing package comparison, paused same-tick tiled terminal census; no original synchronized clearance/CPU/total-material-energy or default promotion. Water terminal overlap is observed; intermediate Water contact remains unqualified in the incompatible legacy observation channel.'))
    print('episodes',len(episodes),'decision','GO' if packed and mixed else 'CONDITIONAL' if packed else 'NO-GO')
if __name__=='__main__':main()
