"""Reduce registered compound captures; absent observations remain unsupported."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path


def percentile(values, quantile):
    values = sorted(value for value in values if isinstance(value, (int, float)) and math.isfinite(value))
    if not values:
        return None
    point = (len(values)-1)*quantile
    lower = int(point)
    return values[lower] + (values[min(lower+1,len(values)-1)]-values[lower])*(point-lower)


def stats(values):
    return {name: percentile(values,q) for name,q in [('p50',.5),('p95',.95),('p99',.99),('max',1)]}


def vector(value):
    return isinstance(value, list) and len(value) == 2 and all(isinstance(x,(int,float)) and math.isfinite(x) for x in value)


def actual_application(application):
    """Never substitute a computed/raw wrench for a delivery receipt."""
    if not isinstance(application, dict) or 'accepted' not in application:
        return None, None
    if application['accepted'] is False:
        return [0.0,0.0], 0.0
    if vector(application.get('actual_impulse')):
        # Legacy compound reducer explicitly sums actual RPC impulses and their
        # rotated-proxy moments; this is not a measured body delta under contact.
        torque=application.get('actual_angular_impulse')
        return application['actual_impulse'],torque if isinstance(torque,(int,float)) else None
    rows = application.get('bodies')
    if rows is None:
        rows = [application]
    if not isinstance(rows, list):
        return None, None
    if not rows:
        return None, None
    impulses, torques = [], []
    for row in rows:
        if not isinstance(row,dict):
            return None,None
        impulse = row.get('impulse')
        torque = row.get('angular_impulse')
        if not vector(impulse):
            return None,None
        impulses.append(impulse)
        torques.append(torque)
    return [sum(v[i] for v in impulses) for i in range(2)], (sum(torques) if all(isinstance(t,(int,float)) for t in torques) else None)


def observation(row):
    return row.get('metrics',{}).get('last_compound_observation',{}) or {}


def application_ledger(rows):
    seen, total_j, total_l, supported_j, supported_l = set(), [0.,0.], 0., True, True
    accepted, refused, ages, corners = 0,0,[],[]
    receipts = 0
    refusal_reasons=Counter()
    empty_result_refusals=correction_count=zeroing_count=0
    correction_norms=[]
    for row in rows:
        value = observation(row)
        app = value.get('application',{})
        # Unchanged cached observations are not applications on later steps.
        serial = app.get('snapshot',value.get('snapshot_serial')) if isinstance(app,dict) else None
        if serial is None:
            continue
        if serial in seen:
            continue
        seen.add(serial); receipts += 1
        impulse, torque = actual_application(app)
        supported_j &= impulse is not None
        supported_l &= torque is not None
        if impulse is not None:
            total_j = [a+b for a,b in zip(total_j,impulse)]
        if torque is not None:
            total_l += torque
        accepted += app.get('accepted') is True
        refused += app.get('accepted') is False
        if app.get('accepted') is False:
            refusal_reasons[str(app.get('refusal') or app.get('outcome') or 'unspecified')]+=1
            empty_result_refusals += value.get('computed_result')==[]
        for body in app.get('bodies',[app]):
            if isinstance(body,dict):
                ages.append(body.get('age'))
                corners.append(body.get('contact_displacement'))
                correction=body.get('correction')
                applied=body.get('correction_applied')
                if applied is None:
                    count=body.get('correction_applications')
                    applied=numeric(count) and count>0
                if applied:
                    correction_count+=1
                    if vector(correction):correction_norms.append(math.hypot(*correction))
                before,after=body.get('velocity_before_correction'),body.get('velocity_after_zeroing')
                if vector(before) and vector(after) and before!=after:zeroing_count+=1
    return {'receipts':receipts, 'accepted':accepted,'refused':refused,
            'actually_applied_impulse':total_j if receipts and supported_j else None,
            'actually_applied_angular_impulse':total_l if receipts and supported_l else None,
            'age':stats(ages),'corner_displacement':stats(corners),
            'refusal_reasons':dict(refusal_reasons),'empty_result_refusals':empty_result_refusals,
            'correction_count':correction_count,'correction_norm':stats(correction_norms),'zeroing_count':zeroing_count,
            'provenance':'unique observed snapshot application receipts; cached frame echoes are deduplicated; J/L are API-requested values, not body momentum changes under gravity/hard contacts; legacy L is the reducer sum of rotated proxy offset cross actual RPC J'}


def numeric(value):
    return isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value)


def native_observed_ledger(rows):
    """Copied native measurements, distinct from the unsupported primary overlap."""
    seen=set();observed=0;native=[];overlaps=[];instrumented=False;scopes=set()
    for row in rows:
        value=observation(row);serial=value.get('snapshot_serial')
        if serial is None or serial in seen:continue
        seen.add(serial);observed+=1
        diagnostic=value.get('native_diagnostics') or {}
        instrumented |= 'overlap_measured' in diagnostic
        if (diagnostic.get('overlap_measured') is True
                and numeric(diagnostic.get('cellular_overlap_pre')) and numeric(diagnostic.get('cellular_overlap_post'))):
            overlaps.append((diagnostic['cellular_overlap_pre'],diagnostic['cellular_overlap_post']))
            scopes.add(str(diagnostic.get('overlap_scope','unspecified')))
        if diagnostic.get('computed') is True:native.append(diagnostic)
    fields=['normal_capacity','normal_accepted','tangent_accepted','event_budget_cost','legacy_budget','legacy_scale',
            'proxy_count','source_bins','nodes','updates','scratch_bytes','energy_before','energy_after']
    scalar={key:stats([d.get(key) for d in native]) for key in fields}
    energy=[d['energy_after']-d['energy_before'] for d in native if numeric(d.get('energy_before')) and numeric(d.get('energy_after'))]
    accepted_plus_event=[d['normal_accepted']+d['event_budget_cost'] for d in native if numeric(d.get('normal_accepted')) and numeric(d.get('event_budget_cost'))]
    return {'observed_snapshot_count':observed,'computed_snapshots':len(native),
            'overlap':{'instrumentation_present':instrumented,'measured_snapshots':len(overlaps),
                       'coverage':len(overlaps)/observed if instrumented and observed else None,
                       'observed_pre_peak':max((v[0] for v in overlaps),default=None),
                       'observed_post_peak':max((v[1] for v in overlaps),default=None),'native_scope':sorted(scopes),
                       'provenance':'rows[].metrics.last_compound_observation.native_diagnostics.cellular_overlap_pre/post, only when overlap_measured=true; unique observed snapshot_serial denominator; sampled native cell centers in rectangle union before/after conservative displacement, not full-square SAT; partial coverage is not a full-window peak and does not replace legacy comparative overlap gate'},
            'budget_work_energy':scalar,'normal_accepted_plus_event_cost':stats(accepted_plus_event),
            'passive_energy_delta':stats(energy),'passivity_rejected':sum(d.get('passivity_rejected') is True for d in native) if native else None,
            'refused':sum(d.get('refused') is True for d in native) if native else None,
            'provenance':'copied native_diagnostics only when computed=true; no getter/refetch or solver reevaluation during reduction; energy is sampled passive-solver bookkeeping and excludes whole-system event/legacy/correction/zeroing/gravity/hard-contact calibration'}


def component_metrics(rows):
    samples = {key:[] for key in ['worker_usec','native_tick_usec','result_generation_usec','main_sync_usec','rapier_usec']}
    work = {key:[] for key in ['nodes','updates','normal_capacity','normal_accepted','tangent_accepted','event_budget_cost','scratch_bytes','source_bins','energy_before','energy_after']}
    previous,seen = {},set()
    for row in rows:
        metrics=row.get('metrics',{})
        for source,target in [('main_sync_ms_total','main_sync_usec'),('rapier_step_ms_total','rapier_usec')]:
            value=metrics.get(source)
            if isinstance(value,(int,float)):
                if source in previous:
                    samples[target].append(max(0.,value-previous[source])*1000.)
                previous[source]=value
        observed=observation(row)
        serial=observed.get('snapshot_serial')
        if serial is None or serial in seen:
            continue
        seen.add(serial)
        for source,target in [('worker_step_ms','worker_usec'),('native_tick_ms','native_tick_usec')]:
            value=metrics.get(source)
            if isinstance(value,(int,float)):
                samples[target].append(value*1000.)
        samples['result_generation_usec'].append(observed.get('result_generation_usec'))
        native=observed.get('native_diagnostics',{}) or {}
        for key in work:
            work[key].append(native.get(key))
    return {'timing':{key:stats(values) for key,values in samples.items()},
            'work':{key:stats(values) for key,values in work.items()},
            'scope':'functional observed snapshots; distributions are not an uncontended timing campaign'}


def census(report, phase):
    return report.get(phase,{}).get('diagnostic_snapshot',{})


def conservation(report):
    before,after = census(report,'before'),census(report,'after')
    count_before,count_after = before.get('counts',[]),after.get('counts',[])
    sand = count_before[2] == count_after[2] if len(count_before)>2 and len(count_after)>2 else None
    water = before['water_mass'] == after['water_mass'] if 'water_mass' in before and 'water_mass' in after else None
    source,final = report.get('source_receipt',{}),report.get('after',{})
    tuples = (source['members'] == final['members'] and len(source['members'])==520*6) if 'members' in source and 'members' in final else None
    owner = final['aggregate_owned']==520 and final.get('native_source_members')==0 if 'aggregate_owned' in final and 'native_source_members' in final else None
    known_cut=report.get('external_edits_complete') is True and (report.get('cut_effect') or {}).get('known') is True
    cut=sum(edit['removed_cells'] for edit in report.get('external_edits',[]) if edit.get('removed_material')==43) if known_cut else None
    brick=(count_before[43]-cut==count_after[43]+final['aggregate_owned']) if cut is not None and len(count_before)>43 and len(count_after)>43 and numeric(final.get('aggregate_owned')) else None
    wall=count_before[1]==count_after[1] if len(count_before)>1 and len(count_after)>1 else None
    original=[sand,water,tuples,owner];extended=[*original,brick,wall]
    return {'sand':sand,'water_mass':water,'member_tuples':tuples,'sole_520_owner':owner,
            'all_supported_exact':all(x is True for x in original) if all(x is not None for x in original) else None,
            'brick_balance':brick,'wall_unchanged':wall,'confirmed_brick_cut':cut,
            'all_registered_observed_exact':all(x is True for x in extended) if all(x is not None for x in extended) else None,
            'provenance':'before/after.diagnostic_snapshot regional160x128 counts: before[43]-receipt-confirmedcut == after[43]+after.aggregate_owned; Wall[1] unchanged; Sand[2] unchanged, integer Water mass exact, original member tuples retained; no unmeasured full-world census claim'}


def summary(report):
    rows = report.get('rows',[])
    tail = rows[-300:]
    release = report.get('source_receipt',{}).get('center')
    entry = max([0.]+[row['position'][1]-release[1] for row in rows if vector(row.get('position'))]) if vector(release) else None
    positions = [row['position'] for row in tail if vector(row.get('position'))]
    span = [max(p[i] for p in positions)-min(p[i] for p in positions) for i in range(2)] if positions else None
    pre = [row.get('pre_overlap') for row in rows]
    post = [row.get('post_overlap') for row in rows]
    # All samples must be supported to use a maximum as a physical gate.
    def supported_max(values):
        return max(values) if values and all(isinstance(v,(int,float)) for v in values) else None
    return {'case':report['case'],'capture_ok':report.get('ok'), 'failures':report.get('failures',[]),
            'samples':len(rows),'release_native_tick':report.get('release_native_tick'),
            'stop_native_tick':report.get('stop_native_tick'),'observed_cutoff_overshoot':report.get('observed_cutoff_overshoot'),
            'reference_entry_com_cells':entry,'pre_overlap_max':supported_max(pre),'post_overlap_max':supported_max(post),
            'reference_union_bottom_entry_max':supported_max([r.get('reference_union_bottom_entry') for r in rows]),
            'first_lowest_union_floor_plane_step':next((r.get('step') for r in rows if r.get('lowest_union_at_or_below_floor_y') is True),None),
            'conservation':conservation(report),'application':application_ledger(rows),
            'native_observed':native_observed_ledger(rows),
            'tail':{'samples':len(tail),'position_span_cells':span,
                    'abs_vy':stats([abs(r['velocity'][1]) for r in tail if vector(r.get('velocity'))]),
                    'abs_omega':stats([abs(r['omega']) for r in tail if isinstance(r.get('omega'),(int,float))])},
            'observer_usec':stats([r.get('observer_usec') for r in rows]),
            'components':component_metrics(rows),
            'final_coupling':report.get('final_coupling'),
            'unsupported':report.get('unsupported',[]),'cutoff_derivative':report.get('cutoff_derivative')}


def regression(reference,candidate,relative,absolute):
    if reference is None or candidate is None:
        return None
    return candidate <= reference + max(absolute,relative*abs(reference))


def gate_eligible(row):
    return (row is not None and row.get('capture',{}).get('status')=='captured'
            and row.get('summary',{}).get('capture_ok') is True)


def pair_gates(reference,candidate):
    eligible=gate_eligible(reference) and gate_eligible(candidate)
    ref=reference.get('summary',{}) if reference else {}
    current=candidate.get('summary',{}) if candidate else {}
    return {'entry_gate':regression(ref.get('reference_entry_com_cells'),current.get('reference_entry_com_cells'),.1,.5) if eligible else None,
            'overlap_gate':regression(ref.get('post_overlap_max'),current.get('post_overlap_max'),.1,1.) if eligible else None,
            'gate_eligibility':{'reference':gate_eligible(reference),'candidate':gate_eligible(candidate),
                                'rule':'both outer capture.status=captured AND raw capture_ok=true; otherwise gates null and diagnostic metrics retained'}}


def reduce_campaign(path):
    campaign=json.loads(path.read_text(encoding='utf-8'))
    reduced=[]
    for capture in campaign['captures']:
        row={'capture':capture}
        if capture.get('raw'):
            raw=path.parent/capture['raw']
            if hashlib.sha256(raw.read_bytes()).hexdigest()!=capture['raw_sha256']:
                raise RuntimeError('Raw hash mismatch: '+str(raw))
            row['summary']=summary(json.loads(raw.read_text(encoding='utf-8')))
        reduced.append(row)
    return campaign,reduced


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('campaigns',nargs='+',type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    campaigns,rows=[],[]
    for path in args.campaigns:
        campaign,reduced=reduce_campaign(path)
        campaigns.append({'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                          'identity':campaign['identity'],'complete':campaign['complete']})
        rows.extend(reduced)
    keyed={}
    for row in rows:
        if 'summary' not in row:continue
        key=tuple(row['summary']['case'][k] for k in ['platform','workers','surroundings','arm','repeat'])
        if key in keyed:raise RuntimeError('Duplicate case would hide an earlier result: '+str(key))
        keyed[key]=row
    pairs=[]
    for key,candidate_row in keyed.items():
        platform,workers,surroundings,arm,repeat=key
        if arm!='R2' or repeat!=0 or surroundings not in ['packed_sand','embedded_sand']:
            continue
        reference_row=keyed.get((platform,workers,surroundings,'legacy',0))
        candidate=candidate_row['summary'];reference=reference_row['summary'] if reference_row else None
        eligible=gate_eligible(reference_row) and gate_eligible(candidate_row)
        pairs.append({'platform':platform,'workers':workers,'surroundings':surroundings,
                      **pair_gates(reference_row,candidate_row),
                      'reference_entry':reference.get('reference_entry_com_cells') if reference else None,'candidate_entry':candidate['reference_entry_com_cells'],
                      'scope':'COM downward reference entry is a fixture-relative proxy; missing overlap does not pass its gate'})
        pairs[-1]['functional_timing_investigation']={}
        for component,values in candidate['components']['timing'].items():
            base=reference['components']['timing'][component]['p95'] if reference else None
            current=values['p95']
            pairs[-1]['functional_timing_investigation'][component]=(current>1.25*base and current-base>25.) if eligible and base is not None and current is not None else None
        base=reference['components']['work']['updates']['max'] if reference else None
        current=candidate['components']['work']['updates']['max']
        pairs[-1]['work_over_2x']=(current>2.*base) if eligible and base is not None and current is not None else None
    method=Path(__file__).read_bytes()
    result={'schema':'cybersand.gcr-detachment.analysis.v2',
            'analysis_method':{'path':'tools/experiments/analyze_gcr_detachment.py',
                               'sha256':hashlib.sha256(method).hexdigest(),
                               'canonical_lf_sha256':hashlib.sha256(method.replace(b'\r\n',b'\n')).hexdigest()},
            'campaigns':campaigns,'captures':rows,'primary_pairs':pairs,
            'limits':['functional asynchronous timing only','A1 diagnostic only','cutoff derivatives are null',
                      'no cross-platform or full physical replay equality inferred','no penetration or owner-feel acceptance inferred']}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'captures':len(rows),'primary_pairs':len(pairs),'entry_failures':sum(p['entry_gate'] is False for p in pairs),
                      'overlap_unsupported':sum(p['overlap_gate'] is None for p in pairs)},indent=2))


if __name__=='__main__':
    main()
