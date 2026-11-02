"""Reduce GCR-REST samples; nonadmission and missing certificates never mean rest."""
import argparse,hashlib,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(path):return json.loads(Path(path).read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def percentile(values,p):
    values=sorted(values)
    return values[min(len(values)-1,math.ceil(p*len(values))-1)] if values else None
def rest_bodies(receipt):return receipt.get('bodies',[]) if isinstance(receipt,dict) else []
def parts(raw,row):
    barrel=raw['case']['kind']=='barrel'
    if barrel:return row.get('gcr',{}),row.get('rest_receipt',{}),row.get('application',{})
    observation=row.get('metrics',{}).get('last_compound_observation',{})
    return observation.get('native_diagnostics',{}),observation.get('rest_receipt',{}),observation.get('application',{})

def finite_number(value):return isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value)

def configuration_receipts(raw,expected_case=None):
    """Bind the executed native configuration, independently of requested metadata."""
    expected=expected_case if expected_case is not None else raw.get('case',{})
    reasons={};examples=[];observed={};rows=raw.get('rows',[]);no_result=0;receipt_count=0
    def refuse(reason,index=None):
        reasons[reason]=reasons.get(reason,0)+1
        if len(examples)<8:examples.append({'reason':reason,'row':index})
    if raw.get('case')!=expected:refuse('capture_case_mismatch')
    mode=expected.get('mode');budget=expected.get('budget')
    if mode not in ['control','P','R','C','PRC'] or not finite_number(budget) or not 5<=budget<=80:refuse('invalid_expected_configuration')
    if not rows:refuse('no_receipt_observations')
    for index,row in enumerate(rows):
        mechanics,receipt,application=parts(raw,row)
        if not isinstance(receipt,dict) or not receipt:
            observation=row.get('metrics',{}).get('last_compound_observation',{})
            actionable=bool(application.get('accepted',False) or row.get('result') or observation.get('computed_result') or mechanics.get('computed',False))
            if actionable or receipt or not isinstance(receipt,dict):refuse('missing_or_malformed_actionable_native_receipt',index)
            else:no_result+=1
            continue
        receipt_count+=1
        actual_mode=receipt.get('mode');actual_budget=receipt.get('base_budget')
        key=str(actual_mode)+' / '+str(actual_budget);observed[key]=observed.get(key,0)+1
        if type(receipt.get('version')) is not int or receipt['version']!=1:refuse('native_receipt_version',index)
        if actual_mode!=mode:refuse('native_mode_mismatch',index)
        if not finite_number(actual_budget) or actual_budget!=budget:refuse('native_budget_mismatch',index)
    if not receipt_count:refuse('no_executed_native_configuration')
    return {'ok':not reasons,'observations':len(rows),'expected_mode':mode,'expected_base_budget':budget,
            'native_receipt_observations':receipt_count,'native_receipt_coverage':receipt_count/len(rows) if rows else None,'nonactionable_no_result_observations':no_result,
            'observed_native_mode_budget':observed,'refusals':reasons,'selected_failures':examples,
            'scope':'Every copied explicit native version1 receipt; requested case fields alone supply no execution proof'}

def current_application_step(raw,row,previous_snapshot=None,previous_call=None):
    """Verify new delivery in this physics call, not a held age0 observation."""
    marker=row.get('application_step',{})
    _,_,application=parts(raw,row)
    observation=row.get('metrics',{}).get('last_compound_observation',{})
    actual_snapshot=application.get('snapshot') if raw['case']['kind']=='barrel' else observation.get('snapshot_serial')
    call=row.get('tick') if raw['case']['kind']=='barrel' else row.get('row')
    integers=['version','physics_call','snapshot_before','snapshot_after']
    if not isinstance(marker,dict) or not all(type(marker.get(k)) is int for k in integers):return False,actual_snapshot,call
    valid=type(actual_snapshot) is int and type(call) is int and marker['version']==1 and marker['physics_call']==call and marker['snapshot_after']==actual_snapshot and marker['snapshot_after']==application.get('snapshot')
    valid=valid and marker['snapshot_after']>marker['snapshot_before'] and marker.get('delivered_this_step') is True and application.get('accepted') is True
    if previous_snapshot is not None:valid=valid and marker['snapshot_before']==previous_snapshot
    if previous_call is not None:valid=valid and type(call) is int and type(previous_call) is int and call>previous_call
    return valid,actual_snapshot,call

def compound_conservation(raw,global_scope=True):
    """Account explicit native-to-body transfer and recorded authoritative edits."""
    field='global_census' if global_scope else 'diagnostic_snapshot'
    expected_scope='global authoritative cells' if global_scope else 'regional160x128 authoritative cells'
    inspections=[raw.get('before',{}),raw.get('after',{})]
    for edit in raw.get('edits',[]):inspections.extend([edit.get('before',{}),edit.get('after',{})])
    censuses=[inspection.get(field) for inspection in inspections]
    result={'conserved':None,'scope':expected_scope,'census_field':field,'inspections':len(inspections),
            'native_payload_transfer':520,'confirmed_cut':8,'isolated_stump_retirement':20 if raw['case']['surroundings'].startswith('isolated_') else 0,
            'count_exclusions':{'0':'Empty occupancy changes with motion','3':'Water occupancy is not quantity; exact water_mass is separately mandatory'}}
    if not all(isinstance(census,dict) and (not global_scope or census.get('ok') is True) for census in censuses):
        result['refusal']='MISSING_OR_REFUSED_CENSUS';return result
    counts=[census.get('counts') for census in censuses];water=[census.get('water_mass') for census in censuses]
    if not counts or not all(isinstance(c,list) and len(c)>43 and all(type(n) is int and n>=0 for n in c) for c in counts) or len({len(c) for c in counts})!=1 or not all(type(n) is int and n>=0 for n in water):
        result.update(conserved=False,refusal='MALFORMED_COUNTS_OR_NONINTEGER_WATER_QUANTITY');return result
    if global_scope and not all(census.get('domain')==[0,0,1024,1024] and census.get('tiles')==4 and type(census.get('completed_ticks')) is int and census['completed_ticks']>=0 and sum(census['counts'])==1048576 for census in censuses):
        result.update(conserved=False,refusal='INCOMPLETE_GLOBAL_DOMAIN_OR_TILING');return result
    expected=counts[0][:];expected[43]-=result['native_payload_transfer']+result['confirmed_cut']+result['isolated_stump_retirement']
    expected_water=water[0]
    for index in range(2,len(censuses),2):
        expected=[v+y-x for v,x,y in zip(expected,counts[index],counts[index+1])]
        expected_water+=water[index+1]-water[index]
    mismatches=[{'material':i,'expected':x,'actual':y} for i,(x,y) in enumerate(zip(expected,counts[1])) if i not in [0,3] and x!=y]
    balance=not mismatches and expected_water==water[1]
    result.update(conserved=None if raw.get('edits') else balance,observed_edit_adjusted_balance=balance if raw.get('edits') else None,count_mismatches=mismatches,
                  expected_water_mass=expected_water,actual_water_mass=water[1],water_quantity_exact=expected_water==water[1],
                  measured_scopes=sorted({str(c.get('scope',expected_scope)) for c in censuses}),refusal=None)
    if raw.get('edits'):
        result['refusal']='EDIT_REMOVAL_QUANTITY_NOT_INDEPENDENTLY_MEASURED'
        result['edit_delta_scope']='Observed edit inspection deltas span native ticks and may include unrelated changes; adjusted balance cannot establish strict conservation'
    return result
def summarize(raw,rows):
    if not raw.get('ok') or not rows:return None
    barrel=raw['case']['kind']=='barrel';positions=[r['out'][:2] if barrel else r['position'] for r in rows]
    velocities=[r['out'][3:5] if barrel else r['velocity'] for r in rows];tail=positions[-300:];tail_v=velocities[-300:]
    mechanics=[];overlap=[];quiet=[];caught=[];fresh_applications=[];signatures=set();application_keys=set();applications=[];refusals={};limiters={};rest_scans=[]
    previous_snapshot=None;previous_call=None
    for row in rows:
        m,receipt,application=parts(raw,row);mechanics.append(m)
        fresh,previous_snapshot,previous_call=current_application_step(raw,row,previous_snapshot,previous_call)
        fresh_applications.append(fresh)
        overlap.append(row.get('post_overlap') if barrel else m.get('cellular_overlap_post'))
        bodies=rest_bodies(receipt);body=bodies[0] if len(bodies)==1 else {}
        matching=[];applied_bodies=application.get('bodies',[])
        for applied in applied_bodies if application.get('accepted',False) and len(bodies)==1 and len(applied_bodies)==1 else []:
            if body.get('sample') is not None and body.get('session',receipt.get('session')) is not None and applied.get('sample')==body.get('sample') and applied.get('session')==body.get('session',receipt.get('session')):
                if type(applied.get('age')) is int and applied['age']==0:matching.append(applied)
        quiet.append(bool(body.get('quiet_admitted',False)) and len(matching)==1 and fresh)
        caught.append(bool(body.get('catch_admitted',body.get('catch_applied',False))))
        if body.get('support_signature') is not None:signatures.add(str(body['support_signature']))
        refusal=str(body.get('refusal','missing_receipt'));refusals[refusal]=refusals.get(refusal,0)+1
        limiter=str(m.get('active_capacity_limiter','unmeasured'));limiters[limiter]=limiters.get(limiter,0)+1
        if 'rest_scans' in body:rest_scans.append(body['rest_scans'])
        for a in application.get('bodies',[]) if application.get('accepted',False) else []:
            key=(a.get('session',receipt.get('session')),a.get('index',a.get('id',1)),a.get('sample'))
            if key not in application_keys:
                application_keys.add(key);applications.append(a)
    values=[v for v in overlap if isinstance(v,(int,float))]
    hard_clear=[bool(r.get('rest_context',{}).get('hard_clearance',False)) if barrel else bool(r.get('hard_clearance',False)) for r in rows]
    entry=[r['vertical_depth'] if barrel else r['entry_com'] for r in rows]
    result={'samples':len(rows),'entry_peak':max(entry),'entry_definition':'body bottom relative to initial bed surface' if barrel else 'COM relative to release; not penetration volume',
            'observed_overlap_max':max(values) if values else None,'overlap_coverage':len(values)/len(rows),'rebound_upward':max(0,-min(v[1] for v in velocities)),
            'tail_x_span':max(p[0] for p in tail)-min(p[0] for p in tail),'tail_y_span':max(p[1] for p in tail)-min(p[1] for p in tail),'tail_abs_vy_p95':percentile([abs(v[1]) for v in tail_v],.95),
            'quiet_admitted_observations':sum(quiet),'fresh_application_observations':sum(fresh_applications),'catch_proposed_observations':sum(caught),'hard_clear_observations':sum(hard_clear),'support_signatures':len(signatures),'refusal_observations':refusals,
            'unique_accepted_applications':len(applications),'application_observation_deduplication':'session/body/sample; repeated snapshots not independent events',
            'maximum_nodes':max(m.get('nodes',0) for m in mechanics),'maximum_updates':max(m.get('updates',0) for m in mechanics),
            'normal_max':max(m.get('normal_accepted',0) for m in mechanics),'tangent_max':max(m.get('tangent_accepted',0) for m in mechanics),
            'normal_capacity_max':max(m.get('normal_capacity',0) for m in mechanics),'physical_wrench_application_max':max((a.get('physical_wrench_applications',0) for a in applications),default=0),
            'normal_measurement_coverage':sum('normal_accepted' in m for m in mechanics)/len(rows),'limiter_observations':limiters,'maximum_rest_scans':max(rest_scans) if rest_scans else None,
            'sampled_passive_energy_delta_max':max(m.get('energy_after',0)-m.get('energy_before',0) for m in mechanics),
            'rest_gate':None,'energy_ledger':energy_summary(applications)}
    # Genuine resting claims require a complete eligible hard-clear tail, not a
    # tiny stationary endpoint already carried by hard terrain.
    admitted_tail=all(quiet[-300:]) and all(hard_clear[-300:]) and len(quiet)>=300
    result['rest_gate']=result['tail_y_span']<=.5 and result['tail_abs_vy_p95']<=.1 if admitted_tail else None
    result['rest_scope']='admitted hard-clear tail' if admitted_tail else 'NO_QUALIFIED_REST_WINDOW'
    if raw['case'].get('comparison')=='water-only':
        complete=all(all(k in m for k in ['normal_accepted','tangent_accepted','event_budget_cost']) for m in mechanics)
        result['water_zero_granular_response']=all(m['normal_accepted']==0 and m['tangent_accepted']==0 and m['event_budget_cost']==0 for m in mechanics) if complete else None
    return result
def energy_summary(applications):
    missing={};nonfinite={};invalid_properties={};errors=[];closure=[];removed=[];selected=[]
    delivery_linear=[];delivery_angular=[];delivery_linear_relative=[];delivery_angular_relative=[]
    catch_linear=[];catch_angular=[];catch_counterfactual_errors=[];actual_removed=[];wrench_energy_deltas=[];zeroing=[];potential=[];catch_count=0
    def value(a,key,vector=False):
        if key not in a:
            missing[key]=missing.get(key,0)+1;return None
        v=a[key]
        valid=isinstance(v,(list,tuple)) and len(v)==2 and all(finite_number(x) for x in v) if vector else finite_number(v)
        if not valid:nonfinite[key]=nonfinite.get(key,0)+1;return None
        return v
    def kinetic(mass,inertia,v,w):return .5*mass*(v[0]*v[0]+v[1]*v[1])+.5*inertia*w*w
    for a in applications:
        mass=value(a,'actual_mass');inertia=value(a,'actual_inertia')
        for key,v in [('actual_mass',mass),('actual_inertia',inertia)]:
            if v is not None and v<=0:invalid_properties[key]=invalid_properties.get(key,0)+1
        properties=mass is not None and inertia is not None and mass>0 and inertia>0
        stages={}
        for suffix,field in [('before_correction','kinetic_before_correction'),('after_zeroing','kinetic_after_zeroing'),('after_wrench','kinetic_after_wrench')]:
            v=value(a,'velocity_'+suffix,True);w=value(a,'omega_'+suffix);k=value(a,field)
            stages[suffix]=(v,w,k)
            if properties and v is not None and w is not None and k is not None:errors.append(abs(kinetic(mass,inertia,v,w)-k))
        j=value(a,'impulse',True);l=value(a,'angular_impulse')
        before,omega_before,_=stages['after_zeroing'];after,omega_after,after_k=stages['after_wrench']
        if properties and before is not None and after is not None and omega_before is not None and omega_after is not None:
            wrench_energy_deltas.append(kinetic(mass,inertia,after,omega_after)-kinetic(mass,inertia,before,omega_before))
        if properties and j is not None and before is not None and after is not None:
            expected=[j[i]/mass for i in range(2)];actual=[after[i]-before[i] for i in range(2)]
            error=math.hypot(*(actual[i]-expected[i] for i in range(2)))
            delivery_linear.append(error);delivery_linear_relative.append(error/max(1.,math.hypot(*expected),math.hypot(*actual)))
        if properties and l is not None and omega_before is not None and omega_after is not None:
            expected=l/inertia;actual=omega_after-omega_before;error=abs(actual-expected)
            delivery_angular.append(error);delivery_angular_relative.append(error/max(1.,abs(expected),abs(actual)))
        for key,output in [('zeroing_removed_energy',zeroing),('correction_potential_delta',potential)]:
            v=value(a,key)
            if v is not None:output.append(v)
        if a.get('catch_applied',False):
            catch_count+=1
            uncaught_k=value(a,'uncaught_counterfactual_kinetic');removed_k=value(a,'catch_removed_energy')
            if uncaught_k is not None and after_k is not None and removed_k is not None:closure.append(abs(uncaught_k-after_k-removed_k))
            if removed_k is not None:removed.append(removed_k)
            uncaught_j=value(a,'uncaught_impulse',True);uncaught_l=value(a,'uncaught_angular_impulse')
            delta_j=value(a,'catch_delta_impulse',True);delta_l=value(a,'catch_delta_angular_impulse')
            # Counterfactual catch delivery is checked against actual measured
            # post-wrench velocity, not just two reported kinetic fields.
            if properties and before is not None and after is not None and uncaught_j is not None and delta_j is not None:
                catch_linear.append(math.hypot(*(after[i]-before[i]-(uncaught_j[i]+delta_j[i])/mass for i in range(2))))
            if properties and omega_before is not None and omega_after is not None and uncaught_l is not None and delta_l is not None:
                catch_angular.append(abs(omega_after-omega_before-(uncaught_l+delta_l)/inertia))
            if properties and before is not None and after is not None and omega_before is not None and omega_after is not None and uncaught_j is not None and uncaught_l is not None:
                counterfactual=kinetic(mass,inertia,[before[i]+uncaught_j[i]/mass for i in range(2)],omega_before+uncaught_l/inertia)
                actual_removed.append(counterfactual-kinetic(mass,inertia,after,omega_after))
                if uncaught_k is not None:catch_counterfactual_errors.append(abs(counterfactual-uncaught_k))
            if len(selected)<4:selected.append(a)
    count=len(applications)
    return {'unique_accepted_applications':count,'catch_applied_samples':catch_count,
            'zeroing_removed_energy_sum':sum(zeroing) if len(zeroing)==count and count else None,
            'catch_removed_energy_sum':sum(removed) if len(removed)==catch_count and catch_count else None,
            'catch_removed_energy_min':min(removed) if removed else None,'negative_catch_removed_energy_samples':sum(v<0 for v in removed),
            'independently_calculated_catch_removed_energy_min':min(actual_removed) if actual_removed else None,
            'negative_independently_calculated_catch_removed_energy_samples':sum(v<0 for v in actual_removed),
            'catch_removed_energy_measurement_complete':len(removed)==catch_count if catch_count else None,
            'maximum_kinetic_field_error':max(errors) if errors else None,'maximum_catch_removed_closure_error':max(closure) if closure else None,
            'maximum_catch_counterfactual_kinetic_field_error':max(catch_counterfactual_errors) if catch_counterfactual_errors else None,
            'maximum_delivered_wrench_kinetic_change':max(wrench_energy_deltas) if wrench_energy_deltas else None,
            'delivered_linear_samples':len(delivery_linear),'delivered_angular_samples':len(delivery_angular),
            'delivered_wrench_measurement_complete':count>0 and len(delivery_linear)==len(delivery_angular)==count,
            'maximum_delivered_delta_v_error':max(delivery_linear) if delivery_linear else None,
            'maximum_delivered_delta_omega_error':max(delivery_angular) if delivery_angular else None,
            'maximum_delivered_delta_v_relative_error':max(delivery_linear_relative) if delivery_linear_relative else None,
            'maximum_delivered_delta_omega_relative_error':max(delivery_angular_relative) if delivery_angular_relative else None,
            'maximum_catch_delivered_delta_v_error':max(catch_linear) if catch_linear else None,
            'maximum_catch_delivered_delta_omega_error':max(catch_angular) if catch_angular else None,
            'missing_field_observations':missing,'nonfinite_or_malformed_field_observations':nonfinite,'nonpositive_property_observations':invalid_properties,
            'correction_potential_change_sum':sum(potential) if len(potential)==count and count else None,
            'selected_catch_applications':selected,
            'scope':'Delivered closure uses measured post-zeroing to post-wrench delta-v=J/m and delta-omega=L/I with actual scaled/translated J/L. Kinetic arithmetic closure alone proves neither force delivery nor passivity. Correction potential is separate; no whole-system energy claim or unregistered tolerance is implied.'}
def reduce_capture(path,expected_case=None):
    raw=read(path)
    if not raw.get('ok') or not raw.get('rows'):return {'status':'failed','metrics':None,'raw_sha256':sha(path)}
    configuration=configuration_receipts(raw,expected_case)
    if not configuration['ok']:return {'status':'failed','metrics':None,'raw_sha256':sha(path),'native_configuration':configuration,'qualification_failure':'NATIVE_CONFIGURATION_NOT_PROVEN'}
    barrel=raw['case']['kind']=='barrel'
    budget_rows=[r for r in raw['rows'] if (int(r['tick'])<1200 if barrel else int(r.get('native_relative_tick',0))<=1200)]
    global_conservation=compound_conservation(raw) if not barrel else None
    regional_conservation=compound_conservation(raw,False) if not barrel else None
    conserved=all(r.get('conserved',False) for r in raw['rows']) if barrel else global_conservation['conserved']
    return {'status':'captured','capture_identity':raw.get('identity',{}),'raw_sha256':sha(path),'case':raw['case'],'outcome':raw.get('outcome'),'native_configuration':configuration,
            'material_conserved':conserved,'global_conservation':global_conservation,'regional_conservation':regional_conservation,
            'support_loss_qualified':raw.get('support_loss_qualified'), 'support_loss_triggered_under_admitted_rest':raw.get('support_loss_triggered_under_admitted_rest',False),'full_window':summarize(raw,raw['rows']),
            'budget_first1200':summarize(raw,budget_rows),'support_loss_event':raw.get('edits',[])}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('campaign',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    protocol=read(ROOT/'docs/audits/gcr-rest-2026-11-02/protocol.json');captures={};pairs=[]
    for platform in ['windows','linux']:
        for case in protocol['cases']:
            key=platform+'-'+case['id'];path=args.campaign/(key+'.json')
            captures[key]=reduce_capture(path,case) if path.exists() else {'status':'missing','metrics':None}
        for case in protocol['cases']:
            if case['mode']=='control' and case['budget']==20:continue
            control=next((c for c in protocol['cases'] if c['comparison']==case['comparison'] and c['mode']=='control' and c['budget']==20),None)
            if control is None:continue
            a=captures[platform+'-'+control['id']];b=captures[platform+'-'+case['id']];gates={}
            if a['status']=='captured' and b['status']=='captured':
                window='budget_first1200' if case['budget']!=20 or case['comparison'].startswith(('budget-','partial-')) else 'full_window';x=a[window];y=b[window]
                for metric,absolute,relative in [('entry_peak',.5,.1),('observed_overlap_max',1,.1),('rebound_upward',2,0)]:
                    gates[metric]=None if x.get(metric) is None or y.get(metric) is None else y[metric]<=x[metric]+max(absolute,relative*x[metric])
                if x['overlap_coverage']<1 or y['overlap_coverage']<1:gates['observed_overlap_max']=None
                conservation=[a['material_conserved'],b['material_conserved']]
                gates['conservation']=False if any(v is False for v in conservation) else (None if any(v is None for v in conservation) else all(v is True for v in conservation))
                gates['qualified_rest']=y['rest_gate']
            pairs.append({'platform':platform,'case':case['id'],'control':control['id'],'gates':gates})
    result={'registration':protocol['registration'],'captures':captures,'pairs':pairs,'complete':all(v['status']=='captured' for v in captures.values()),'owner_acceptance':None,'production_accepted':False,
            'unsupported':['Whole-system energy beyond explicit kinetic/application ledger','Uncontended performance','Unreported generic actor drive','Independent actual edit-removal quantities (edited capture conservation stays null)','Owner gameplay acceptance']}
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
if __name__=='__main__':main()
