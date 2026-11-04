"""Strict source/quantity/wrench reader for the selective event successor."""
import argparse,json,math,statistics
from pathlib import Path
from analyze_gcr_creep import EvidenceError,require,read,sha,same_json,_all_finite,motion,application_summary
from run_gcr_causal import EXISTING

REG='GCR-SEL-001-2026-11-04'
REQUIRED_GATES=['import','test_gcr_granular_events','test_gcr_granular_events_playground','test_gcr_selective_events']+EXISTING+[
    'test_gcr_detachment','test_solid_detachment_displacement','test_solid_detachment_compound_response',
    'test_gcr_fleet_emissions','test_gcr_fleet_side_thrusters','test_gcr_review_navigation']

def selector(arm):
    require(arm in ('C','E','S'),'Unknown experiment arm')
    return {'C':'control','E':'off','S':'selective'}[arm]

def metadata_equal(actual,expected):
    """Godot JSON rounds doubles; retain the established absolute1e-12 input tolerance."""
    if isinstance(actual,bool) or isinstance(expected,bool):return type(actual) is type(expected) and actual==expected
    if isinstance(expected,(int,float)):return isinstance(actual,(int,float)) and abs(actual-expected)<=1e-12
    if isinstance(expected,dict):return isinstance(actual,dict) and actual.keys()==expected.keys() and all(metadata_equal(actual[k],v) for k,v in expected.items())
    if isinstance(expected,list):return isinstance(actual,list) and len(actual)==len(expected) and all(metadata_equal(a,b) for a,b in zip(actual,expected))
    return type(actual) is type(expected) and actual==expected

def state(row,kind):
    if kind=='flyer':return row['state']
    p=row['out'];return dict(position=p[:2],rotation=p[2],velocity=p[3:5],omega=p[5])

def quantities(value):
    return ({str(i):v for i,v in enumerate(value['counts']) if i not in (0,3) and v},value['water_mass'])

def reduce_capture(raw,spec,arm,identity,platform,ph):
    _all_finite(raw)
    require(raw.get('ok') is True and raw.get('errors')==[] and raw.get('registration')==REG,'Failed/foreign capture')
    require(metadata_equal(raw['case'],spec) and raw['arm']==arm and raw['platform']==('Windows' if platform=='windows' else 'Linux'),'Fixture/arm/OS mismatch')
    actual=raw['identity'];runtime=identity['platforms'][platform]
    for key,value in dict(source=identity['source'],input_identity=identity['source_inputs_sha256'],protocol_sha256=ph,native_sha256=runtime['native_sha256'],engine_sha256=runtime['engine_sha256'],physics_backend='Rapier2D').items():
        require(actual.get(key)==value,'Identity mismatch '+key)
    require(abs(raw['dt']-1/60)<=1e-15 and isinstance(raw['initial_native_hash'],str) and len(raw['initial_native_hash'])==16,'Timestep/initial hash')
    mass=spec['configuration']['mass'] if spec['kind']=='barrel' else .1
    require(abs(raw['actual_mass']-mass)<=1e-6 and raw['actual_inertia']>0,'Registered mass/inertia')
    if spec['kind']=='barrel':
        config=dict(spec['configuration'],material=spec['material'],ticks=1800)
        config.update(granular_events=selector(arm),granular_event_experiment=REG)
        require(metadata_equal(raw['configuration'],config),'Authored barrel configuration')
    rows=raw['rows'];require(len(rows)==1800 and [r['tick'] for r in rows]==list(range(1800)),'Incomplete observation population')
    expected=quantities(raw['before']);edits={e['tick']:e for e in raw.get('edits',[])}
    seen=set();norm=[];censuses=0;first_hard=None;first_guard=None
    for row in rows:
        tick=row['tick'];a=row['application']
        require(a.get('accepted') is True and len(a['bodies'])==1,'Response refused/incomplete')
        b=a['bodies'][0];key=(b['session'],b['index'],b['sample'])
        require(b['age']==0 and key not in seen,'Stale or duplicate wrench');seen.add(key)
        require(row['selector']==selector(arm),'Selector readback')
        g=row['gcr']
        require(type(row.get('arrival_storage_bytes')) is int and row['arrival_storage_bytes']>0 and row['arrival_storage_bytes']%8==0,'Missing/bad arrival sidecar capacity')
        require(type(g.get('arrival_count')) is int and g['arrival_count']>=0,'Missing admitted source count')
        require(len(g.get('arrival_raw',[]))==2 and isinstance(g.get('arrival_raw_torque'),(float,int)),'Missing admitted wrench')
        if g['arrival_count']==0:require(g['arrival_raw']==[0,0] and g['arrival_raw_torque']==0,'Wrench without arrival witness')
        source=g['arrival_raw'] if arm=='S' else g['event_raw']
        torque=g['arrival_raw_torque'] if arm=='S' else g['event_raw_torque']
        scale=0 if arm=='E' else g['event_scale']
        require(0<=g['event_scale']<=1 and g['event_budget_cost']>=0,'Event scale/cost outside existing cap')
        if arm=='E':require(g['event_scale']==0,'Omitted channel retains nonzero scale')
        require(all(abs(g['event_accepted'][i]-source[i]*scale)<=1e-5*max(1,abs(source[i]*scale)) for i in range(2)) and abs(g['event_torque']-torque*scale)<=1e-5*max(1,abs(torque*scale)),'Event selector/source closure')
        require(g['legacy_non_granular']==[0,0],'Unexpected non-granular response')
        if arm=='E':require(g['event_accepted']==[0,0] and g['event_torque']==0 and g['event_budget_cost']==0,'Granular event/cost not omitted')
        if spec['kind']=='barrel':
            require(row['observed_native_steps']==row['observed_rapier_steps']==1,'Observed clock delta')
            if tick in edits:
                edit=edits[tick]
                require(quantities(dict(counts=edit['before'],water_mass=edit['water_before']))==expected,'Edit ledger starting quantity')
                expected=quantities(dict(counts=edit['after'],water_mass=edit['water_after']))
            require(row['conserved'] is True and row['material_count']==expected[0].get(str(spec['material']),0) and row['water']==expected[1],'Closed barrel quantity/edit accounting')
            overlap=row['tick_overlap']
        else:
            phase=row['phase'];counts=phase['counts']
            require(all(counts.get(k)==1 for k in ('native_tick','rapier_step','sample','response_calls','actuation')),'Flyer boundary counts')
            before,after=phase['counter_before'],phase['counter_after']
            require(after['native_tick']-before['native_tick']==after['rapier_steps']-before['rapier_steps']==after['rig_tick']-before['rig_tick']==1,'Flyer observed advancement')
            require(phase['fresh_sample_applied'] and after['last_applied_sample']==b['sample'],'Flyer fresh response identity')
            actual_j=phase['actuation']['actual_impulse']
            if spec['drive']=='unactuated':require(actual_j==[0,0] and phase['actuation']['actual_torque_impulse']==0,'Unexpected passive actuation')
            active=spec['drive']=='sustained' and 120<=tick<1200
            require(row['action']['trim']==(.15 if active else 0),'Drive schedule')
            if tick%60==0 or tick==1799:
                require(row.get('conserved') is True and quantities(row['census'])==expected,'Flyer native census');censuses+=1
            overlap=row['post_overlap']
        require(type(overlap) is int and overlap>=0,'Missing overlap coverage')
        if not row['hard_clearance'] and first_hard is None:first_hard=tick
        if row.get('movement_limited',False) and first_guard is None:first_guard=tick
        norm.append(dict(row,**state(row,spec['kind']),post_overlap=overlap,application_step={'delivered_this_step':True}))
    require(quantities(raw['after'])==expected,'Final native quantity')
    app=application_summary(norm)
    require(app['unique_accepted_applications']==1800 and app['delivered_linear_measurement_complete'] and app['delivered_angular_measurement_complete'],'Incomplete delivery ledger')
    require(max(app['delivered_delta_v_relative_error_max'],app['delivered_delta_omega_relative_error_max'])<=1e-5,'Wrench closure')
    tail=norm[1500:]
    initial=raw['initial']['position'] if spec['kind']=='flyer' else raw['initial'][:2]
    tail_apps=application_summary(tail)
    first_event=next((r['tick'] for r in rows if any(r['gcr']['event_raw']) or r['gcr']['event_raw_torque']!=0),None)
    time_values=[r['times_us'][1] for r in rows if 'times_us' in r]
    describe=lambda values:dict(p50=statistics.median(values),p95=sorted(values)[min(len(values)-1,math.ceil(len(values)*.95)-1)],p99=sorted(values)[min(len(values)-1,math.ceil(len(values)*.99)-1)],max=max(values)) if values else None
    peak_entry=max((r['horizontal_depth'] if spec['configuration']['layout']=='horizontal-entry' else r['vertical_depth']) for r in rows) if spec['kind']=='barrel' else None
    result=dict(case=spec['id'],arm=arm,platform=platform,initial=raw['initial'],initial_native_hash=raw['initial_native_hash'],
        actual_mass=raw['actual_mass'],actual_inertia=raw['actual_inertia'],exact_conservation=True,raw_census_checks=censuses,
        applications=app,first_hard=first_hard,first_guard=first_guard,peak_entry=peak_entry,peak_overlap=max(r['post_overlap'] for r in norm),
        peak_upward=max(0,-min(r['velocity'][1] for r in norm)),motion=motion(norm),tail_motion=motion(tail),tail_overlap=max(r['post_overlap'] for r in tail),
        tail_correction_duty=tail_apps['correction_active_applications']/300,
        event_attempt_active=sum(any(r['gcr']['event_raw']) or r['gcr']['event_raw_torque']!=0 for r in rows),
        accepted_event_sum=[sum(r['gcr']['event_accepted'][axis] for r in rows) for axis in range(2)],
        event_cost_sum=sum(r['gcr']['event_budget_cost'] for r in rows),first_attempted_event=first_event,
        moves_before_event=sum(r['work'][1] for r in rows[:first_event]) if first_event is not None else None,
        native_work_sum=[sum(r['work'][i] for r in rows) for i in range(3)],
        arrival_count_sum=sum(r['gcr']['arrival_count'] for r in rows),
        arrival_active_ticks=[r['tick'] for r in rows if r['gcr']['arrival_count']>0],
        arrival_raw_sum=[sum(r['gcr']['arrival_raw'][i] for r in rows) for i in range(2)],
        arrival_torque_abs_sum=sum(abs(r['gcr']['arrival_raw_torque']) for r in rows),
        arrival_storage_bytes_max=max(r['arrival_storage_bytes'] for r in rows),
        coupling_us=describe(time_values),support_probes=describe([r['gcr']['probes'] for r in rows if 'probes' in r['gcr']]),
        solver_updates=describe([r['gcr']['updates'] for r in rows if 'updates' in r['gcr']]),
        overlap_resolution_outcomes=dict(displaced=sum(r['result'][6] for r in rows),unresolved=sum(r['result'][7] for r in rows),scope='Packed outcome counts; after hard proximity includes non-granular refusals, not a no-target/search-attempt census') if spec['kind']=='barrel' else None,
        descent900=norm[900]['position'][1]-initial[1],final_y=norm[-1]['position'][1],
        edits=raw.get('edits',[]),scope='Registered independent-body observations; later hard/rig intervals are operational only')
    return result,norm

def compare_pair(c,e,cr,er,spec):
    require(same_json(c['initial'],e['initial']) and c['initial_native_hash']==e['initial_native_hash'],'Initial body/material inputs differ')
    require(c['actual_mass']==e['actual_mass'] and c['actual_inertia']==e['actual_inertia'],'Mass properties changed')
    end=min(x if x is not None else 1800 for x in (c['first_hard'],e['first_hard'],c['first_guard'],e['first_guard']))
    result=dict(case=spec['id'],platform=c['platform'],common_uncensored_end=end)
    if spec['kind']=='flyer':
        supported=end>900
        result['bank_descent']=dict(control=c['descent900'],candidate=e['descent900'],supported=supported,
            generalized_benefit=(e['descent900']<=.25*c['descent900']) if supported and spec['drive']=='unactuated' else None)
    elif spec['id'] not in ('falling-grains','continuous-grains','stationary-cap'):
        result['impact_guards']=dict(entry=e['peak_entry']<=c['peak_entry']+max(.5,.1*c['peak_entry']),
            overlap=e['peak_overlap']<=c['peak_overlap']+max(1,.1*c['peak_overlap']),
            rebound=e['peak_upward']<=c['peak_upward']+max(2,.25*c['peak_upward']))
        result['impact_guard_scope']='Whole operational capture; direct granular attribution requires the common hard/rig-clear prefix'
        result['entire_impact_hard_clear']=end==1800
        if end:
            axis='horizontal_depth' if spec['configuration']['layout']=='horizontal-entry' else 'vertical_depth'
            cp,ep=cr[:end],er[:end]
            ca,ea=max(r[axis] for r in cp),max(r[axis] for r in ep)
            co,eo=max(r['post_overlap'] for r in cp),max(r['post_overlap'] for r in ep)
            cv,ev=max(0,-min(r['velocity'][1] for r in cp)),max(0,-min(r['velocity'][1] for r in ep))
            result['prefix_impact_guards']=dict(entry=ea<=ca+max(.5,.1*ca),overlap=eo<=co+max(1,.1*co),rebound=ev<=cv+max(2,.25*cv))
    else:
        cm=motion(cr[:end]) if end else c['motion'];em=motion(er[:end]) if end else e['motion']
        travel_c=cm['sampled_path_length'];travel_e=em['sampled_path_length']
        spin_c=cm['sampled_angular_travel'];spin_e=em['sampled_angular_travel']
        exercised=end>0 and c['first_attempted_event'] is not None and c['first_attempted_event']<end and c['moves_before_event']>0
        result['moving_grain_loading']=dict(exercised=exercised,control_travel=travel_c,candidate_travel=travel_e,control_rotation=spin_c,candidate_rotation=spin_e,
            gap=exercised and ((travel_c>.5 and travel_e<.25*travel_c) or (spin_c>.05 and spin_e<.25*spin_c)),
            scope='Common prefix before first hard proximity or rig guard; sampled motion')
    result['tail_tradeoff']=any(e['tail_motion']['position_span'][i]-c['tail_motion']['position_span'][i]>max(.25,.25*c['tail_motion']['position_span'][i]) for i in range(2)) or e['tail_motion']['speed_p95']-c['tail_motion']['speed_p95']>max(.25,.25*c['tail_motion']['speed_p95'])
    if spec['id']=='excavate':
        result['excavation']=dict(control_fall=cr[660]['position'][1]-cr[599]['position'][1],candidate_fall=er[660]['position'][1]-er[599]['position'][1],
            candidate_tail_support_nodes=max(r['gcr']['nodes'] for r in er[660:900]),scope='Author removal at600; later floor contact is separate')
    return result


def compare_three(triple,spec):
    require([x[0]['arm'] for x in triple]==['C','E','S'],'Three-arm order')
    (c,cr),(e,er),(s,sr)=triple
    compare_pair(c,e,cr,er,spec) # Enforce E inputs/mass equivalence too.
    result=compare_pair(c,s,cr,sr,spec)
    end=min(x if x is not None else 1800 for r in (c,e,s) for x in (r['first_hard'],r['first_guard']))
    result['common_three_arm_uncensored_end']=end
    if 'impact_guards' in result:
        # The event-off reference also participates in the registered common window.
        result['prefix_impact_guards']=None
        if end>0:
            axis='horizontal_depth' if spec['configuration']['layout']=='horizontal-entry' else 'vertical_depth'
            cp,sp=cr[:end],sr[:end]
            ca,sa=max(r[axis] for r in cp),max(r[axis] for r in sp)
            co,so=max(r['post_overlap'] for r in cp),max(r['post_overlap'] for r in sp)
            cv,sv=max(0,-min(r['velocity'][1] for r in cp)),max(0,-min(r['velocity'][1] for r in sp))
            result['prefix_impact_guards']=dict(entry=sa<=ca+max(.5,.1*ca),overlap=so<=co+max(1,.1*co),rebound=sv<=cv+max(2,.25*cv))
        result['prefix_impact_supported']=end>0
    if spec['id']=='excavate':
        window_end=min(end,900)
        supported=window_end>=661
        result['excavation'].update(window_supported=supported,support_window_end=window_end,
            candidate_clear_window_support_nodes=max(r['gcr']['nodes'] for r in sr[660:window_end]) if supported else None,
            scope='Removal at600; fall599..660 and support660..common clear boundary, at most900')
    if spec['kind']=='flyer':
        supported=end>900
        result['bank_preservation']=dict(control=c['descent900'],event_off=e['descent900'],selective=s['descent900'],supported=supported,
            event_off_proximity=s['descent900']<=e['descent900']+max(.5,.25*e['descent900']) if supported else None,
            control_benefit=s['descent900']<=.25*c['descent900'] if supported else None)
    if spec['id'] in ('falling-grains','continuous-grains'):
        cm=motion(cr[:end]) if end else c['motion'];sm=motion(sr[:end]) if end else s['motion']
        exercised=end>0 and c['first_attempted_event'] is not None and c['first_attempted_event']<end and c['moves_before_event']>0
        travel=cm['sampled_path_length'];spin=cm['sampled_angular_travel']
        events=sum(r['gcr']['arrival_count'] for r in sr[:end])
        impulse=sum(math.hypot(*r['gcr']['event_accepted']) for r in sr[:end])
        torque=sum(abs(r['gcr']['event_torque']) for r in sr[:end])
        result['loading_recovery']=dict(exercised=exercised,admitted_sources=events,accepted_linear_magnitude_sum=impulse,accepted_angular_magnitude_sum=torque,
            control_travel=travel,selective_travel=sm['sampled_path_length'],control_rotation=spin,selective_rotation=sm['sampled_angular_travel'],
            translation_recovered=(sm['sampled_path_length']>=.25*travel and sm['sampled_path_length']<=2*travel+.5 and impulse>0) if exercised and travel>.5 else None,
            torque_recovered=(sm['sampled_angular_travel']>=.25*spin and sm['sampled_angular_travel']<=2*spin+.05 and torque>0) if exercised and spin>.05 else None)
    if spec['id']=='continuous-grains':
        active=[r for r in sr[121:min(end,600)] if r['gcr']['arrival_count']>0]
        result['continued_loading']=dict(admitted_ticks_after120=len(active),fresh_source_observed=any(r['work'][1]>0 for r in sr[121:min(end,600)]),
            exercised=bool(active),scope='Admission after120 while external source active, before common hard proximity')
    if spec['id']=='stationary-cap':
        result['stationary_cap']=dict(initial_admitted_sources=sr[0]['gcr']['arrival_count'],no_paint_witness=all(r['gcr']['arrival_count']==0 for r in (cr[0],er[0],sr[0])),scope='First native step after direct paint; subsequent actual transport may legitimately create witnesses')
    return result

def validate_gates(folder,platform):
    folder=Path(folder)/platform;gates=read(folder/'gates.json')
    names=[x.get('test') for x in gates]
    require(len(names)==len(set(names)) and all(name in names for name in REQUIRED_GATES),'Missing or duplicate host gates')
    for gate in gates:
        log=folder/(gate['test']+'.log')
        require(gate.get('ok') is True and gate.get('exit')==0 and gate.get('timed_out') is False and 'inherited_from' not in gate and gate.get('log_sha256')==sha(log),'Host gate original process/log authentication')
    prefix='GCR_GRANULAR_EVENT_CHECKS '
    reports=[json.loads(x[len(prefix):]) for x in (folder/'test_gcr_granular_events.log').read_text(encoding='utf-8').splitlines() if x.startswith(prefix)]
    require(len(reports)==1 and reports[0].get('checks',0)>=59 and reports[0].get('failures')==[],'Granular host mechanical summary')
    prefix='GCR_SELECTIVE_EVENT_CHECKS '
    reports=[json.loads(x[len(prefix):]) for x in (folder/'test_gcr_selective_events.log').read_text(encoding='utf-8').splitlines() if x.startswith(prefix)]
    require(len(reports)==1 and reports[0].get('checks',0)>=170 and reports[0].get('failures')==[],'Selective host mechanical summary')

def technical_gates(comparisons,platform):
    cases={x['case']:x for x in comparisons if x['platform']==platform}
    bank_ids=('bank-sand','bank-salt','bank-dust','powered-bank')
    impact_ids=('barrel-gentle','barrel-high','barrel-heavy','barrel-angle','barrel-edge','barrel-horizontal','excavate')
    require(set(cases)==set(bank_ids+impact_ids+('falling-grains','continuous-grains','stationary-cap')),'Physical gate population incomplete')
    banks=[cases[x]['bank_preservation'] for x in bank_ids]
    load=cases['falling-grains']['loading_recovery']
    impacts=[cases[x] for x in impact_ids]
    valid_guards=lambda value:isinstance(value,dict) and set(value)=={'entry','overlap','rebound'} and all(x is True for x in value.values())
    unsupported=[x['case'] for x in impacts if not x.get('prefix_impact_supported',False)]
    excavation=cases['excavate']['excavation']
    return dict(platform=platform,creep_preserved=all(x['supported'] is True and x['event_off_proximity'] is True and x['control_benefit'] is True for x in banks),
        falling_loading_recovered=load['exercised'] is True and load['translation_recovered'] is True and load['torque_recovered'] is True,
        barrel_guards=not unsupported and all(valid_guards(x['impact_guards']) and valid_guards(x.get('prefix_impact_guards')) for x in impacts),
        barrel_guard_unsupported=unsupported,
        excavation_release=excavation['window_supported'] is True and excavation['candidate_fall']>0 and excavation['candidate_clear_window_support_nodes']==0,
        excavation_window_supported=excavation['window_supported'],
        continuous_arrivals_exercised=cases['continuous-grains']['continued_loading']['exercised'] is True,
        direct_paint_not_arrival=cases['stationary-cap']['stationary_cap']['no_paint_witness'] is True,
        tail_tradeoffs=[x['case'] for x in cases.values() if x['tail_tradeoff']])


def reduce_campaign(folder,protocol):
    folder=Path(folder);p=read(protocol);identity=read(folder/'identity.json');done=read(folder/'completion.json')
    require(p['registration']==REG and len(p['cases'])==14 and done['ok'] and done['complete_registered_population'] and done['completed_captures']==84,'Incomplete registered campaign')
    require(done['source']==done['end_source']==identity['source'] and done['inputs_unchanged'] and done['identity_sha256']==sha(folder/'identity.json') and identity['protocol_sha256']==sha(protocol),'End-input/protocol authentication')
    results=[];comparisons=[]
    for platform in p['platforms']:
        validate_gates(folder,platform)
        records=read(folder/platform/'campaign.json')
        require([(r['case'],r['arm']) for r in records]==[(s['id'],a) for s in p['cases'] for a in p['arms']],'Case population/order')
        for spec in p['cases']:
            pair=[]
            for arm in p['arms']:
                path=folder/platform/(spec['id']+'-'+arm+'.json');acq=next(r for r in records if r['case']==spec['id'] and r['arm']==arm)
                require(acq['ok'] and acq['exit']==0 and not acq['timed_out'] and acq['identity_ok'] and acq['raw_sha256']==sha(path) and acq['log_sha256']==sha(path.with_suffix('.log')),'Original raw/process receipt')
                result,rows=reduce_capture(read(path),spec,arm,identity,platform,sha(protocol))
                result.update(raw_file=path.relative_to(folder).as_posix(),raw_sha256=sha(path));results.append(result);pair.append((result,rows))
            comparisons.append(compare_three(pair,spec))
    decisions=[technical_gates(comparisons,platform) for platform in p['platforms']]
    return dict(schema='cybersand.gcr-selective-events.v1',source=identity['source'],ok=True,captures=results,comparisons=comparisons,technical_gates=decisions,owner_acceptance=None,production_acceptance=False)

def main():
    p=argparse.ArgumentParser();p.add_argument('--folder',type=Path,required=True);p.add_argument('--protocol',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    result=reduce_campaign(a.folder,a.protocol);a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(dict(ok=True,captures=len(result['captures']),comparisons=result['comparisons'])))

if __name__=='__main__':main()
