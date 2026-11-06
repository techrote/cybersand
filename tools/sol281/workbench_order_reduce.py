"""Independent primitive-stage and complete-coverage ordering evaluator."""
import argparse,collections,hashlib,json,math,statistics
from pathlib import Path
import structure_cut as p
import workbench_order_common as w
import workbench_reduce as q
import reduce_structure_cut as r

PIN_RECEIPT=Path('C:/Users/_/.codex/worktrees/sol-structure-cut-20261106/khybersand/build/sol-structure-cut/mass-fix-001/receipt.json')

def authenticate_inputs(host,project):
    assert not host.get('post_inventory_unexpected',[])
    for name,digest in host['effective_inputs'].items():
        path=project/name
        if path.is_file() and p.sha(path)==digest:continue
        original=w.ROOT/'godot'/name
        assert name.endswith('.import') and original.is_file() and path.is_file() and path.read_bytes().replace(b'\r\n',b'\n')==original.read_bytes().replace(b'\r\n',b'\n'),'Changed host input'

def qualification(folder,identity,build_sha):
    """Reconstruct the prerequisite, including actual reversed-arm delivery."""
    path=folder/'receipt.json';receipt=q.load(path)
    assert receipt['post_source_equality'] and not receipt['errors'] and receipt['matrix']['smoke'] and receipt['identity']==identity
    assert receipt['build_receipt_sha256']==build_sha and p.sha(PIN_RECEIPT)==receipt['engine_pin_receipt_sha256']
    profile=q.load(w.ROOT/w.FIXTURE);assert p.sha(w.ROOT/w.FIXTURE)==identity['ordering_registration_sha256']
    assert set(receipt['hosts'])=={'windows','linux'};reports=[];count=0;physical=0
    for host,h in receipt['hosts'].items():
        authenticate_inputs(h,folder/host/'godot');seen=set();adapter_seen=False
        for c in h['commands']:
            assert c['clean'] and p.sha(w.ROOT/c['log'])==c['log_sha256']
            if 'report' not in c:continue
            raw=c['report'];d=q.archive(w.ROOT/raw['path'],raw);reports.append(raw)
            assert d['source']==identity['source_commit'] and d['platform'].lower()==host and not d['failures']
            if c.get('apparatus'):
                assert not adapter_seen and d['registration']=='SOL-WORKBENCH-ORDER-001-ADAPTER';adapter_seen=True
                cases=d['cases'];coordinates={(x['structure'],x['case'],x['implementation']) for x in cases}
                expected={(s,x['name'],arm) for s in ['tree','building'] for x in profile['adapter_cases'] for arm in ['production','correction-first','impulse-first']}
                assert len(cases)==len(coordinates)==60 and coordinates==expected
                for case in cases:
                    assert case['before']['bits']==case['before']['server_bits'] and case['after']['bits']==case['after']['server_bits']
                    if case['implementation']=='production':continue
                    stages=case['stages'];assert [x['stage'] for x in stages]==profile['stage_order'][case['implementation']]
                    assert stages[0]['bits']==case['before']['bits'] and stages[-1]['bits']==case['after']['bits']
                    for s in stages:
                        assert s['bits']==s['server_bits'] and s['manual_step']==0 and s['body_rid']==stages[0]['body_rid'] and s['body_instance']==stages[0]['body_instance']
                    for b,a in zip(stages,stages[1:]):primitive(r.state(b),r.state(a),a['stage'],case['action']);count+=1
                    if case['implementation']=='correction-first':assert case['after']==next(x['after'] for x in cases if (x['structure'],x['case'],x['implementation'])==(case['structure'],case['case'],'production'))
            else:
                assert c['report_complete'] and d['registration']=='SOL-WORKBENCH-ORDER-001' and d['apparatus_only'] and len(d['steps'])==12
                coordinate=(d['structure'],d['surroundings'],d['arm']);assert coordinate not in seen;seen.add(coordinate);physical+=1
                n=520 if d['structure']=='tree' else 356;inertia=r.state(d['initial_body'])[10];q.controls(d,n,inertia);r.handoff(d,n)
                q.cells(d['initial_native']);q.cells(d['final_native'])
                for row in d['steps']:
                    assert [x['stage'] for x in row['order_stages']]==profile['stage_order'][d['arm']]
                    for s in row['order_stages']:q.body_ok(s,d,n,inertia);assert s['bits']==s['server_bits']
                    for b,a in zip(row['order_stages'],row['order_stages'][1:]):primitive(r.state(b),r.state(a),a['stage'],row['order_action']);count+=1
        assert adapter_seen and seen=={(s,e,arm) for s in ['tree','building'] for e in ['packed_sand','mixed'] for arm in profile['arms']}
    facade_path=w.OUT/'facade-002/receipt.json';facade=q.load(facade_path)
    assert facade['post_source_equality'] and facade['build_receipt_sha256']==build_sha and facade['identity']['source_inputs']==identity['source_inputs'] and facade['identity']['material_inputs']==identity['material_inputs']
    facade_reports=[]
    for host,h in facade['hosts'].items():
        assert h['post_input_equality'];authenticate_inputs(h,facade_path.parent/host/'godot')
        for c in h['commands']:
            assert c['clean'] and p.sha(w.ROOT/c['log'])==c['log_sha256']
            if 'report' not in c:continue
            raw=c['report'];assert p.sha(w.ROOT/raw['path'])==raw['sha256'];d=q.load(w.ROOT/raw['path'])
            assert d['schema']=='cybersand.sol-facade-refusals.v1' and not d['failures'] and d['checks']==3260 and d['case_count']==16 and d['workers'] in [1,4] and d['platform'].lower()==host
            assert len(d['cases'])==16 and {x['case'] for x in d['cases']}==p.facade.EXTENDED_CASES and all(x['checks']>0 and not x['failures'] for x in d['cases'])
            assert d['script_sha256']==identity['source_inputs']['godot/tests/test_sol_facade_refusals.gd']['sha256'];facade_reports.append(raw)
    assert len(facade_reports)==4
    return dict(path=str(path.relative_to(w.ROOT)),sha256=p.sha(path),build_receipt_sha256=build_sha,engine_pin_receipt_sha256=p.sha(PIN_RECEIPT),facade_receipt_sha256=p.sha(facade_path),adapter_and_smoke_primitive_checks=count,smoke_episodes=physical,reports=reports,facade_reports=facade_reports)

def primitive(before,after,stage,action):
    """Check actual delivery before any later clip can cancel it."""
    assert all(math.isfinite(x) for x in before+after) and before[9:]==after[9:]
    changed=set()
    if stage=='after_translation':
        changed={4,5}
        for axis in [0,1]:
            expected=action['correction'][axis];residual=after[4+axis]-before[4+axis]-expected
            assert abs(residual)<=16*max(q.ulp32(before[4+axis]),q.ulp32(after[4+axis]),q.ulp32(expected)),'Translation differs from admitted correction'
        assert all(abs(after[k]-before[k])<=16*max(q.ulp32(before[k]),q.ulp32(after[k])) for k in range(4))
        changed|=set(range(4)) # Transform set may re-encode its existing basis.
    elif stage=='after_clip':
        changed={6,7}
        for axis in [0,1]:assert after[6+axis]==(0. if before[6+axis]*action['correction'][axis]<0 else before[6+axis]),'Clip uses velocity at its actual stage'
    elif stage=='after_central_impulse':
        changed={6,7}
        for axis in [0,1]:
            residual=before[9]*(after[6+axis]-before[6+axis])-action['impulse'][axis]
            bound=16*before[9]*max(q.ulp32(before[6+axis]),q.ulp32(after[6+axis]),q.ulp32(action['impulse'][axis]/before[9]))
            assert abs(residual)<=bound,'Central impulse not delivered before later clipping'
    elif stage=='after_torque_impulse':
        changed={8};residual=before[10]*(after[8]-before[8])-action['torque']
        bound=16*before[10]*max(q.ulp32(before[8]),q.ulp32(after[8]),q.ulp32(action['torque']/before[10]))
        assert abs(residual)<=bound,'Torque impulse not delivered'
    else:assert stage=='after_wake'
    assert all(after[k]==before[k] for k in range(11) if k not in changed),'Primitive changed an unrelated state component'

def episode(d):
    assert d['registration']=='SOL-WORKBENCH-ORDER-001' and not d['apparatus_only'] and not d['failures'] and len(d['steps'])==720
    assert d['structure'] in ['tree','building'] and d['arm'] in ['correction-first','impulse-first']
    n=520 if d['structure']=='tree' else 356;r.handoff(d,n);pre=d['prepared'];members=[tuple(pre['members'][i:i+6]) for i in range(0,len(pre['members']),6)];xy={(m[0],m[1]) for m in members}
    assert len(xy)==len(members)==n and all(m[2:]==(43,0,0,200) for m in members)
    center=[sum(v[axis]+.5 for v in xy)/n for axis in [0,1]];inertia=sum((x+.5-center[0])**2+(y+.5-center[1])**2+1/6 for x,y in xy)
    assert pre['mass']==n and r.near(pre['inertia'],inertia) and all(r.near(x,y) for x,y in zip(pre['center'],center));q.controls(d,n,inertia)
    union=set();rects=pre['rectangles'];assert len(d['server_shapes'])==(6 if n==520 else 5)
    for i,s in enumerate(d['server_shapes']):
        x,y,dx,dy=rects[4*i:4*i+4];part={(xx,yy) for yy in range(y,y+dy) for xx in range(x,x+dx)};assert not union&part;union|=part
        assert s['type']==4 and not s['owner_disabled'] and s['data']==[dx/2,dy/2] and s['transform'][:4]==[1.,0.,0.,1.]
        assert d['proxy_masses'][i]==dx*dy and d['proxy_sizes'][i]==[dx,dy]
        assert all(r.near(a,b) for a,b in zip(s['transform'][4:6],[x+dx/2-pre['center'][0],y+dy/2-pre['center'][1]]))
        assert all(r.near(a,b) for a,b in zip(d['proxy_centres'][i],s['transform'][4:6]))
    assert union==xy and sum(d['proxy_masses'])==n
    if n==520:assert (60,32) not in xy and (68,50) not in xy
    before,water_before,tb=q.cells(d['before_cut']);initial,water_initial,ti=q.cells(d['initial_native']);final,water_final,tf=q.cells(d['final_native'])
    counts=collections.Counter(initial.values());end=collections.Counter(final.values());assert {k:v for k,v in counts.items() if k!=3}=={k:v for k,v in end.items() if k!=3} and water_initial==water_final
    assert collections.Counter(before.values())[43]-counts[43]==n+8
    hard={x:m for x,m in initial.items() if m in [1,43]};assert hard=={x:m for x,m in final.items() if m in [1,43]}
    for native in [d['initial_native'],d['final_native']]:assert native['aggregate_owned']==n and native['native_source_members']==0 and native['members']==pre['members'] and native['configured_workers']==d['workers'] and not native['worker_failed']
    policies=[d[k]['liquid_policy'] for k in ['before_cut','initial_native','final_native']];assert len({x['policy_hash'] for x in policies})==1 and all(x['admission']=='current_defaults_only' for x in policies)
    water_policy=next(x for x in policies[0]['assignments'] if x['material']==3);assert water_policy['applied_family']=='freemass_v1' and water_policy['applied_variant']=='reference'
    order=['after_translation','after_clip','after_central_impulse','after_torque_impulse'] if d['arm']=='correction-first' else ['after_central_impulse','after_torque_impulse','after_translation','after_clip']
    previous=d['initial_body']['bits'];ages=collections.Counter();events=missing=misaligned=0;nonempty=0;active_usec=0;ledger=[];stage_totals=collections.Counter();stage_momentum=collections.Counter();tail_arrivals=0;tail_events=0.;tail_passive=0.;timings=collections.defaultdict(list)
    for i,row in enumerate(d['steps']):
        assert row['step']==i and row['before']['bits']==previous;previous=row['after_step']['bits'];assert row['audit']['outcome']=='Published'
        for label in ['before','after_application','after_step']:q.body_ok(row[label],d,n,inertia)
        assert row['before']['manual_step']==i and row['after_step']['manual_step']==i+1 and row['response_attempts_delta']==0 and 'ordinary' not in row
        packet=row['workbench_packet'];application=row['workbench_application'];assert packet['valid'] and packet['response']=='LA-SELECTIVE' and application['accepted'] and len(packet['rows'])==len(application['bodies'])==1
        native=packet['rows'][0];action=application['bodies'][0];assert action==row['order_action']
        assert native['mass']==n and r.near(native['inertia'],inertia) and native['proxy_count']==len(d['server_shapes']) and native['budget']==20 and native['body_capacity']==20*n and not native['external_drive']
        assert native['instance_id']==d['body_instance'] and native['generation']==packet['epoch']==d['initial_body']['physics_epoch']
        assert native['sample']==action['sample']==row['before']['sample_serial'] and row['incoming_age']==action['age']==0
        stages=row['order_stages'];assert [s['stage'] for s in stages]==['before_action',*order,'after_wake']
        assert stages[0]['bits']==row['before']['bits'] and stages[-1]['bits']==row['after_application']['bits']
        for s in stages:
            q.body_ok(s,d,n,inertia);assert s['bits']==s['server_bits'] and s['manual_step']==i and s['sample_serial']==action['sample']
            assert all(r.near(a,b) for a,b in zip(s['world_com'],q.com(s)))
        primitives=[]
        for old,new in zip(stages,stages[1:]):
            b=r.state(old);a=r.state(new);label=new['stage'];primitive(b,a,label,action)
            dk=r.ke(a)-r.ke(b);dy=q.com(new)[1]-q.com(old)[1];dp=-n*old['gravity'][1]*dy;jy=n*(a[7]-b[7]);tau=a[10]*(a[8]-b[8])
            stage_totals[label]+=dk+dp;stage_momentum[label]+=jy
            primitives.append(dict(stage=label,kinetic_change=dk,potential_change=dp,momentum_y=jy,angular_momentum=tau))
        a=r.state(row['after_application']);z=r.state(row['after_step']);dy=q.com(row['after_step'])[1]-q.com(row['after_application'])[1]
        integration=r.ke(z)-r.ke(a)-n*row['before']['gravity'][1]*dy
        ledger.append(dict(step=i,primitives=primitives,integration_mechanical_change=integration,declared_jy=action['impulse'][1],declared_torque=action['torque']))
        active_usec+=row['elapsed_usec'];ages[str(row['incoming_age'])]+=1;events+=native['arrival_count'];missing+=native['arrival_missing'];misaligned+=native['arrival_misaligned'];nonempty+=bool(any(action['impulse']) or action['torque'] or any(action['correction']))
        if i>=600:tail_arrivals+=native['arrival_count'];tail_events+=math.hypot(*native['event_accepted']);tail_passive+=native['passive_impulse'][1]
        t=row['native_timing']
        for key in ['native_tick_ms','worker_step_ms','snapshot_copy_ms']:timings[key].append(t[key])
    assert d['attempts']==720+d['no_step_attempts'] and sum(d['no_step_reasons'].values())==d['no_step_attempts'] and active_usec+d['no_step_usec']==d['attempt_usec']
    assert d['metrics']['physical_contact']['response_attempts']==0
    tail=[x['after_step'] for x in d['steps'][600:]];ys=[q.com(x)[1] for x in tail];mean=statistics.mean(ys);sink=sum((i-59.5)*(y-mean) for i,y in enumerate(ys))/sum((i-59.5)**2 for i in range(120))
    finalpose=r.state(d['steps'][-1]['after_step'])[:6];geometry={name:r.geometry(finalpose,d['server_shapes'],{x:m for x,m in final.items() if m in ids}) for name,ids in [('sand',[2]),('water',[3]),('hard',[1,43])]}
    signature=dict(body_bits=d['initial_body']['bits'],local_com=d['initial_body']['local_com'],gravity=d['initial_body']['gravity'],damping=[d['initial_body']['linear_damp'],d['initial_body']['angular_damp']],fixed_delta=d['initial_body']['fixed_delta'],authored=d['authored'],policy=policies[0],members=members,shapes=d['server_shapes'])
    return dict(host=d['platform'].lower(),workers=d['workers'],structure=d['structure'],surroundings=d['surroundings'],arm=d['arm'],repeat=d['repeat'],source=d['source'],steps=720,mass=n,inertia=r.state(d['initial_body'])[10],controls_sha256=hashlib.sha256(json.dumps(signature,sort_keys=True,separators=(',',':')).encode()).hexdigest(),initial_map_sha256=hashlib.sha256(json.dumps(sorted(initial.items()),separators=(',',':')).encode()).hexdigest(),tuple_sha256=hashlib.sha256(json.dumps(members,separators=(',',':')).encode()).hexdigest(),native_counts=dict(counts),stored_water_mass=water_final,census_ticks=[tb,ti,tf],terminal_census_tick_gap=tf-d['steps'][-1]['after_step']['native_tick'],rest=r.rest(tail),sink_cells_per_step=sink,sink_cells_per_nominal_second=sink*60,geometry=geometry,incoming_completed_step_ages=dict(ages),arrival_count=events,arrival_missing=missing,arrival_misaligned=misaligned,accepted_empty=720-nonempty,accepted_nonempty=nonempty,tail_arrival_count=tail_arrivals,tail_event_magnitude_sum=tail_events,tail_passive_jy_mean=tail_passive/120,stage_mechanical_change=dict(stage_totals),stage_momentum_y=dict(stage_momentum),attempts=d['attempts'],no_step_attempts=d['no_step_attempts'],no_step_reasons=d['no_step_reasons'],main_ms_per_step=d['attempt_usec']/720/1000,wall_ms_per_step=d['physical_episode_usec']/720/1000,native_timing={k:q.stats(v) for k,v in timings.items()},participation=d['participation'],ledger=ledger)

def main():
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);a=ap.parse_args();assert Path(a.run).name==a.run
    folder=w.OUT/a.run;dst=folder/'reduction.json';assert not dst.exists();receipt=q.load(folder/'receipt.json');assert receipt['post_source_equality'] and not receipt['errors'] and not receipt['matrix']['smoke']
    assert p.sha(w.ROOT/w.FIXTURE)==receipt['identity']['ordering_registration_sha256'];assert set(receipt['hosts'])=={'windows','linux'}
    buildpath=w.OUT/receipt['matrix']['build']/'receipt.json';assert p.sha(buildpath)==receipt['build_receipt_sha256'];build=q.load(buildpath);assert build['post_source_equality'] and build['identity']['source_inputs']==receipt['identity']['source_inputs']
    assert build['identity']['material_inputs']==receipt['identity']['material_inputs'] and p.sha(PIN_RECEIPT)==receipt['engine_pin_receipt_sha256']
    for name,digest in receipt['identity']['experiment_inputs'].items():assert p.sha(w.ROOT/name)==digest,'Experiment input differs from executed source'
    assert qualification(w.OUT/receipt['matrix']['qualification'],receipt['identity'],receipt['build_receipt_sha256'])==receipt['qualification']
    episodes=[]
    for host,h in receipt['hosts'].items():
        assert not h['post_inventory_unexpected'];seen=set();project=folder/host/'godot'
        assert h['compiled_native']==build['platforms'][host] and p.sha(w.ROOT/h['compiled_native']['output'])==h['compiled_native']['sha256']
        for name,digest in h['effective_inputs'].items():
            path=project/name
            if path.is_file() and p.sha(path)==digest:continue
            original=w.ROOT/'godot'/name;assert name.endswith('.import') and original.is_file() and path.is_file() and path.read_bytes().replace(b'\r\n',b'\n')==original.read_bytes().replace(b'\r\n',b'\n')
        for c in h['commands']:
            assert c['clean'] and p.sha(w.ROOT/c['log'])==c['log_sha256']
            if 'report' not in c:continue
            assert c['report_complete'];raw=c['report'];d=q.archive(w.ROOT/raw['path'],raw);row=episode(d)
            assert row['host']==host and row['source']==receipt['identity']['source_commit'];key=(row['workers'],row['repeat'],row['structure'],row['surroundings'],row['arm']);assert key not in seen;seen.add(key);row['raw']=raw;episodes.append(row)
        assert seen=={(k,i,s,e,arm) for k in [1,4] for i in range(5 if k==1 else 1) for s in ['tree','building'] for e in ['packed_sand','mixed'] for arm in ['correction-first','impulse-first']}
    assert len(episodes)==96 and sum(x['steps'] for x in episodes)==69120
    for setup in {(x['host'],x['workers'],x['structure'],x['surroundings']) for x in episodes}:
        rows=[x for x in episodes if (x['host'],x['workers'],x['structure'],x['surroundings'])==setup];assert len({x['controls_sha256'] for x in rows})==len({x['initial_map_sha256'] for x in rows})==1
    groups={}
    for x in episodes:groups.setdefault((x['host'],x['workers'],x['structure'],x['surroundings'],x['arm']),[]).append(x)
    cells=[];decisions=[]
    for key,rows in sorted(groups.items()):
        rows.sort(key=lambda x:x['repeat']);cell=dict(zip(['host','workers','structure','surroundings','arm'],key));cell.update(repeats=len(rows),rest_count=sum(x['rest']['screen_pass'] for x in rows))
        for name,values in [('sand_area',[x['geometry']['sand']['area'] for x in rows]),('sand_depth',[x['geometry']['sand']['depth'] for x in rows]),('sink',[x['sink_cells_per_step'] for x in rows]),('water_area',[x['geometry']['water']['area'] for x in rows]),('max_speed',[x['rest']['max_speed'] for x in rows]),('wall_ms_per_step',[x['wall_ms_per_step'] for x in rows])]:cell[name]=q.stats(values)
        cell['incoming_completed_step_ages']=[x['incoming_completed_step_ages'] for x in rows];cell['accepted_fraction']=q.stats([1. for x in rows]);cells.append(cell)
    for host in ['windows','linux']:
        for structure in ['tree','building']:
            for env in ['packed_sand','mixed']:
                rows=[x for x in cells if (x['host'],x['workers'],x['structure'],x['surroundings'])==(host,1,structure,env)];old=next(x for x in rows if x['arm']=='correction-first');new=next(x for x in rows if x['arm']=='impulse-first');assert old['repeats']==new['repeats']==5
                rest=new['rest_count']>=(3 if env=='packed_sand' else old['rest_count']);area=new['sand_area']['median']<=old['sand_area']['median'];depth=new['sand_depth']['median']<=old['sand_depth']['median'];decisions.append(dict(host=host,structure=structure,surroundings=env,decision='GO' if rest and area and depth else 'NO-GO',rest=rest,area=area,depth=depth))
    packed=all(x['decision']=='GO' for x in decisions if x['surroundings']=='packed_sand');mixed=all(x['decision']=='GO' for x in decisions if x['surroundings']=='mixed');decision='GO' if packed and mixed else 'CONDITIONAL' if packed else 'NO-GO'
    p.write(dst,dict(registration='SOL-WORKBENCH-ORDER-001',receipt_sha256=p.sha(folder/'receipt.json'),reducer_sha256=p.sha(__file__),decision=decision,cell_decisions=decisions,cells=cells,episodes=episodes,scope='Fixed-action ordering only, unchanged native law/fence/constants; paused endpoint geometry, no original clearance/CPU/default or closed material energy claim.'))
    print('episodes',len(episodes),'steps',69120,'decision',decision)
if __name__=='__main__':main()
