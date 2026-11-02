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
def summarize(raw,rows):
    if not raw.get('ok') or not rows:return None
    barrel=raw['case']['kind']=='barrel';positions=[r['out'][:2] if barrel else r['position'] for r in rows]
    velocities=[r['out'][3:5] if barrel else r['velocity'] for r in rows];tail=positions[-300:];tail_v=velocities[-300:]
    mechanics=[];overlap=[];quiet=[];caught=[];signatures=set();application_keys=set();applications=[];refusals={};limiters={};rest_scans=[]
    for row in rows:
        m,receipt,application=parts(raw,row);mechanics.append(m)
        overlap.append(row.get('post_overlap') if barrel else m.get('cellular_overlap_post'))
        bodies=rest_bodies(receipt);body=bodies[0] if len(bodies)==1 else {}
        matching=[]
        for applied in application.get('bodies',[]) if application.get('accepted',False) else []:
            if body.get('sample') is not None and body.get('session',receipt.get('session')) is not None and applied.get('sample')==body.get('sample') and applied.get('session')==body.get('session',receipt.get('session')):
                matching.append(applied)
        quiet.append(bool(body.get('quiet_admitted',False)) and len(matching)==1)
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
            'quiet_admitted_observations':sum(quiet),'catch_proposed_observations':sum(caught),'hard_clear_observations':sum(hard_clear),'support_signatures':len(signatures),'refusal_observations':refusals,
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
    def kinetic(a,v,w):
        return .5*float(a['actual_mass'])*(v[0]*v[0]+v[1]*v[1])+.5*float(a['actual_inertia'])*w*w
    errors=[];closure=[];removed=[];selected=[]
    for a in applications:
        local=[]
        for suffix,field in [('before_correction','kinetic_before_correction'),('after_zeroing','kinetic_after_zeroing'),('after_wrench','kinetic_after_wrench')]:
            if all(k in a for k in ['actual_mass','actual_inertia','velocity_'+suffix,'omega_'+suffix,field]):
                local.append(abs(kinetic(a,a['velocity_'+suffix],a['omega_'+suffix])-a[field]))
        errors+=local
        if a.get('catch_applied',False) and all(k in a for k in ['uncaught_counterfactual_kinetic','kinetic_after_wrench','catch_removed_energy']):
            closure.append(abs(a['uncaught_counterfactual_kinetic']-a['kinetic_after_wrench']-a['catch_removed_energy']))
            removed.append(a['catch_removed_energy'])
            if len(selected)<4:selected.append(a)
    zeroing=[a['zeroing_removed_energy'] for a in applications if 'zeroing_removed_energy' in a]
    potential=[a['correction_potential_delta'] for a in applications if 'correction_potential_delta' in a]
    return {'unique_accepted_applications':len(applications),'catch_applied_samples':sum(bool(a.get('catch_applied',False)) for a in applications),
            'zeroing_removed_energy_sum':sum(zeroing) if len(zeroing)==len(applications) and applications else None,
            'catch_removed_energy_sum':sum(removed) if removed else None,'catch_removed_energy_min':min(removed) if removed else None,
            'maximum_kinetic_field_error':max(errors) if errors else None,'maximum_catch_removed_closure_error':max(closure) if closure else None,
            'correction_potential_change_sum':sum(potential) if len(potential)==len(applications) and applications else None,
            'selected_catch_applications':selected,'scope':'Kinetic ledgers and correction potential reported separately; no whole-system energy claim'}
def reduce_capture(path):
    raw=read(path)
    if not raw.get('ok') or not raw.get('rows'):return {'status':'failed','metrics':None,'raw_sha256':sha(path)}
    barrel=raw['case']['kind']=='barrel'
    budget_rows=[r for r in raw['rows'] if (int(r['tick'])<1200 if barrel else int(r.get('native_relative_tick',0))<=1200)]
    conserved=all(r.get('conserved',False) for r in raw['rows']) if barrel else None
    if not barrel:
        before=raw.get('before',{}).get('diagnostic_snapshot',{});after=raw.get('after',{}).get('diagnostic_snapshot',{})
        b=list(before.get('counts',[]));a=list(after.get('counts',[]));expected=b[:]
        if len(expected)>43:expected[43]-=528+(20 if raw['case']['surroundings'].startswith('isolated_') else 0)
        for edit in raw.get('edits',[]):
            eb=edit.get('before',{}).get('diagnostic_snapshot',{}).get('counts',[]);ea=edit.get('after',{}).get('diagnostic_snapshot',{}).get('counts',[])
            if len(eb)==len(ea)==len(expected):expected=[v+y-x for v,x,y in zip(expected,eb,ea)]
        conserved=bool(b) and len(expected)==len(a) and all(x==y for i,(x,y) in enumerate(zip(a,expected)) if i not in [0,3]) and before.get('water_mass')==after.get('water_mass')
    return {'status':'captured','capture_identity':raw.get('identity',{}),'raw_sha256':sha(path),'case':raw['case'],'outcome':raw.get('outcome'),
            'material_conserved':conserved,'support_loss_qualified':raw.get('support_loss_qualified'), 'support_loss_triggered_under_admitted_rest':raw.get('support_loss_triggered_under_admitted_rest',False),'full_window':summarize(raw,raw['rows']),
            'budget_first1200':summarize(raw,budget_rows),'support_loss_event':raw.get('edits',[])}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('campaign',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    protocol=read(ROOT/'docs/audits/gcr-rest-2026-11-02/protocol.json');captures={};pairs=[]
    for platform in ['windows','linux']:
        for case in protocol['cases']:
            key=platform+'-'+case['id'];path=args.campaign/(key+'.json')
            captures[key]=reduce_capture(path) if path.exists() else {'status':'missing','metrics':None}
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
                gates['conservation']=a['material_conserved'] and b['material_conserved'];gates['qualified_rest']=y['rest_gate']
            pairs.append({'platform':platform,'case':case['id'],'control':control['id'],'gates':gates})
    result={'registration':protocol['registration'],'captures':captures,'pairs':pairs,'complete':all(v['status']=='captured' for v in captures.values()),'owner_acceptance':None,'production_accepted':False,
            'unsupported':['Whole-system energy beyond explicit kinetic/application ledger','Uncontended performance','Unreported generic actor drive','Owner gameplay acceptance']}
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
if __name__=='__main__':main()
