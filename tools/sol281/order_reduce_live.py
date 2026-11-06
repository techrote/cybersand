"""Independent body-bit, geometry, ownership and full-denominator order audit."""
import argparse,collections,hashlib,json,math
from pathlib import Path
import order_common as o
import structure_cut as p
import reduce_structure_cut as r

def episode(d):
    assert not d['failures'] and len(d['steps'])==720 and d['order_registration']=='SOL-CONTACT-ORDER-LIVE-001'
    n=520 if d['structure']=='tree' else 356;r.handoff(d,n);pre=d['prepared']
    members=[tuple(pre['members'][i:i+6]) for i in range(0,len(pre['members']),6)];xy={(m[0],m[1]) for m in members}
    assert len(xy)==len(members)==n and all(m[2:]==(43,0,0,200) for m in members)
    union=set();rects=pre['rectangles']
    for i in range(0,len(rects),4):
        x,y,w,h=rects[i:i+4];part={(xx,yy) for yy in range(y,y+h) for xx in range(x,x+w)};assert not union&part;union|=part
    assert union==xy and sum(d['proxy_masses'])==n and len(d['server_shapes'])==(6 if n==520 else 5)
    if n==520:assert (60,32) not in xy and (68,50) not in xy
    cx=sum(x+.5 for x,y in xy)/n;cy=sum(y+.5 for x,y in xy)/n;inertia=sum((x+.5-cx)**2+(y+.5-cy)**2+1/6 for x,y in xy)
    for i,s in enumerate(d['server_shapes']):
        x,y,w,h=rects[i*4:i*4+4];assert s['type']==4 and not s['owner_disabled'] and not d['scene_shapes'][i]['disabled'] and s['data']==[w/2,h/2] and d['proxy_sizes'][i]==[w,h]
        t=s['transform'];assert t[:4]==[1.,0.,0.,1.] and r.near(t[4],x+w/2-pre['center'][0]) and r.near(t[5],y+h/2-pre['center'][1]) and d['proxy_masses'][i]==w*h
    for native in [d['initial_native'],d['final_native']]:assert native['aggregate_owned']==n and native['native_source_members']==0 and native['members']==pre['members'] and not native['worker_failed'] and native['configured_workers']==d['workers']
    initial=r.cells(d['initial_native']);final=r.cells(d['final_native']);before=r.cells(d['before_cut']);counts=collections.Counter(initial.values());assert counts==collections.Counter(final.values())
    assert collections.Counter(before.values())[43]-counts[43]==n+8
    hard={q:m for q,m in initial.items() if m in [1,43]};assert hard=={q:m for q,m in final.items() if m in [1,43]}
    local=[sum(4*s['data'][0]*s['data'][1]*s['transform'][4+axis] for s in d['server_shapes'])/n for axis in range(2)]
    outcomes=collections.Counter();ages=collections.Counter();ledger=[];participation=[];gains=[];geoms=[];jy=0.
    for index,row in enumerate(d['steps']):
        assert row['step']==index and row['response_attempts_delta'] in [0,1]
        for label in ['before','after_application','after_step']:
            body=row[label];a=r.state(body);assert all(math.isfinite(v) for v in a) and a[9]==n and r.near(a[10],inertia) and body['body_rid']==d['body_rid'] and body['body_instance']==d['body_instance']
            assert body['physics_epoch']==d['initial_body']['physics_epoch'] and body['generation']==d['initial_body']['generation'] and body['gravity']==d['initial_body']['gravity']
            assert all(r.near(x,y) for x,y in zip(r.transform(a[:6],local),r.transform(a[:6],body['local_com'])))
        b=r.state(row['before']);a=r.state(row['after_application']);c=r.state(row['after_step']);assert row['after_step']['manual_step']==index+1
        geom=r.geometry(c[:6],d['server_shapes'],hard);geoms.append(geom);delta=None;response=row['response'];age=None
        if row['response_is_new']:
            assert row['response_attempts_delta']==1 and d['sand_response'];outcomes[response['outcome']]+=1
            first=row['before_sand'];last=row['after_sand'];advanced=int(d['contact_order']=='post')
            assert first['advanced']==last['advanced']==advanced and first['state']['manual_step']==index+advanced
            assert response['current_sample_serial']==(first['captured_current']+advanced)%1000000 and row['after_step']['sample_serial']==(first['captured_current']+1)%1000000
            assert first['snapshot']==last['snapshot']==row['ordinary_stage']['snapshot_serial'] and first['tick']==last['tick']==row['ordinary_stage']['native_tick']
            age=(response['current_sample_serial']-response['source_sample_serial']+1000000)%1000000;ages[age]+=1
            u=r.state(first['state']);v=r.state(last['state']);assert u[:6]==v[:6],'Sand response changed position'
            if response.get('accepted'):
                assert age<=1 and not response.get('failed',False);delta=r.ke(v)-r.ke(u);gains.append(delta)
                assert delta<=max(1e-4,r.ke(u)*1e-4),'Actual Sand readback energy gate violated';jy+=n*(v[7]-u[7])
            else:assert first['state']['bits']==last['state']['bits'],'Refusal changed RID'
        else:outcomes['NOT_EVALUATED']+=1
        if row.get('worker_participation'):participation.append(row['worker_participation'])
        potential=-n*row['after_step']['gravity'][1]*(c[5]-b[5])
        ledger.append(dict(step=index,hard_area=geom['area'],hard_depth=geom['depth'],kinetic_before=r.ke(b),kinetic_after_consume=r.ke(a),kinetic_final=r.ke(c),sand_kinetic_delta=delta,mechanical_change=r.ke(c)-r.ke(b)+potential,ordinary_position_change=[a[4]-b[4],a[5]-b[5]],response_outcome=response.get('outcome') if row['response_is_new'] else 'NOT_EVALUATED',sample_age=age))
    physical=d['metrics']['physical_contact'];assert sum(v for k,v in outcomes.items() if k!='NOT_EVALUATED')==physical['response_attempts'] and not physical['response_failures'] and physical['energy_violations']==0
    terminal=r.state(d['steps'][-1]['after_step']);arm='off' if not d['sand_response'] else d['contact_order'];times=[s['elapsed_us']/1000 for s in d['steps']]
    return dict(host=d['platform'].lower(),workers=d['workers'],structure=d['structure'],surroundings=d['surroundings'],arm=arm,source=d['source'],checks=d['checks'],steps=720,mass=n,inertia=terminal[10],tuple_sha256=hashlib.sha256(json.dumps(members,separators=(',',':')).encode()).hexdigest(),ownership_pass=True,native_material_counts=dict(counts),native_material_conserved=True,rest=r.rest([s['after_step'] for s in d['steps'][600:]]),hard_terminal=geoms[-1],hard_peak_area=max(g['area'] for g in geoms),hard_peak_depth=max(g['depth'] for g in geoms),hard_tail_area_pass=all(g['area']<=1e-6 for g in geoms[600:]),hard_tail_depth_pass=all(g['depth']<=2e-5 for g in geoms[600:]),sand_initial=r.geometry(r.state(d['initial_body'])[:6],d['server_shapes'],{q:m for q,m in initial.items() if m==2}),sand_terminal=r.geometry(terminal[:6],d['server_shapes'],{q:m for q,m in final.items() if m==2}),response_outcomes=dict(outcomes),sample_ages=dict(ages),actual_sand_ke_sum=sum(gains),actual_sand_ke_max=max(gains,default=None),actual_upward_sand_impulse_ratio_all720=-jy/(n*d['initial_body']['gravity'][1]*720/60),body_mechanical_change_sum=sum(v['mechanical_change'] for v in ledger),main_diagnostic_ms_mean=sum(times)/len(times),main_diagnostic_ms_max=max(times),participation_samples=participation,metrics=d['metrics'],ledger=ledger)

def main():
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);a=ap.parse_args();assert Path(a.run).name==a.run
    folder=o.OUT/a.run;dst=folder/'reduction.json';assert not dst.exists();receipt=json.loads((folder/'receipt.json').read_text(encoding='utf-8'));assert receipt['post_source_equality'];rows=[]
    for host,h in receipt['hosts'].items():
        assert not h['post_inventory_unexpected'];seen=set()
        for c in h['commands']:
            assert c['clean'] and o.sha(o.ROOT/c['log'])==c['log_sha256']
            if 'report' not in c:continue
            assert c['report_complete'];raw=c['report'];path=o.ROOT/raw['path'];assert o.sha(path)==raw['sha256'];d=json.loads(path.read_text(encoding='utf-8'));row=episode(d)
            assert row['host']==host and row['source']==receipt['identity']['source_commit'];key=(row['workers'],row['structure'],row['surroundings'],row['arm']);assert key not in seen;seen.add(key);row['raw']=raw;rows.append(row)
        assert seen=={(w,s,env,arm) for w in [1,4] for s in ['tree','building'] for env,arm in [('empty','off'),('packed_sand','off'),('packed_sand','pre'),('packed_sand','post')]}
    assert len(rows)==32 and sum(v['steps'] for v in rows)==23040
    for s in ['tree','building']:assert len({v['tuple_sha256'] for v in rows if v['structure']==s})==1
    p.write(dst,dict(receipt_sha256=o.sha(folder/'receipt.json'),reducer_sha256=o.sha(__file__),episodes=rows,qualifiers=['Fresh common setups; asynchronous trajectories are not deterministic matches.','Independent hard geometry eachstep. Sand terminal census paused, not synchronized clearance.','Mechanical changes include gravity/potential, ordinary correction/contact and damping; native Sand energy/mass units uncalibrated.','Full-observer timing, not original CPU gate. Configured workers and sampled claimers differ.']))
    print('episodes',len(rows),'steps',sum(v['steps'] for v in rows),'dry rest',sum(v['rest']['screen_pass'] for v in rows if v['surroundings']=='empty'),'/8','packed rest',sum(v['rest']['screen_pass'] for v in rows if v['surroundings']=='packed_sand'),'/24')
if __name__=='__main__':main()
