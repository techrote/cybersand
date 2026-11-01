"""Reduce registered compound captures; absent observations remain unsupported."""
import argparse
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
        for body in app.get('bodies',[app]):
            if isinstance(body,dict):
                ages.append(body.get('age'))
                corners.append(body.get('contact_displacement'))
    return {'receipts':receipts, 'accepted':accepted,'refused':refused,
            'actually_applied_impulse':total_j if receipts and supported_j else None,
            'actually_applied_angular_impulse':total_l if receipts and supported_l else None,
            'age':stats(ages),'corner_displacement':stats(corners)}


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
    tuples = source['members'] == final['members'] if 'members' in source and 'members' in final else None
    owner = final['aggregate_owned']==520 and final.get('native_source_members')==0 if 'aggregate_owned' in final and 'native_source_members' in final else None
    return {'sand':sand,'water_mass':water,'member_tuples':tuples,'sole_520_owner':owner,
            'all_supported_exact': all(x is True for x in [sand,water,tuples,owner]) if all(x is not None for x in [sand,water,tuples,owner]) else None}


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
    keyed={tuple(row['summary']['case'][k] for k in ['platform','workers','surroundings','arm','repeat']):row['summary'] for row in rows if 'summary' in row}
    pairs=[]
    for key,candidate in keyed.items():
        platform,workers,surroundings,arm,repeat=key
        if arm!='R2' or repeat!=0 or surroundings not in ['packed_sand','embedded_sand']:
            continue
        reference=keyed.get((platform,workers,surroundings,'legacy',0))
        pairs.append({'platform':platform,'workers':workers,'surroundings':surroundings,
                      'entry_gate':regression(reference.get('reference_entry_com_cells') if reference else None,candidate['reference_entry_com_cells'],.1,.5),
                      'overlap_gate':regression(reference.get('post_overlap_max') if reference else None,candidate['post_overlap_max'],.1,1.),
                      'reference_entry':reference.get('reference_entry_com_cells') if reference else None,'candidate_entry':candidate['reference_entry_com_cells'],
                      'scope':'COM downward reference entry is a fixture-relative proxy; missing overlap does not pass its gate'})
        pairs[-1]['functional_timing_investigation']={}
        for component,values in candidate['components']['timing'].items():
            base=reference['components']['timing'][component]['p95'] if reference else None
            current=values['p95']
            pairs[-1]['functional_timing_investigation'][component]=(current>1.25*base and current-base>25.) if base is not None and current is not None else None
        base=reference['components']['work']['updates']['max'] if reference else None
        current=candidate['components']['work']['updates']['max']
        pairs[-1]['work_over_2x']=(current>2.*base) if base is not None and current is not None else None
    result={'schema':'cybersand.gcr-detachment.analysis.v1','campaigns':campaigns,'captures':rows,'primary_pairs':pairs,
            'limits':['functional asynchronous timing only','A1 diagnostic only','cutoff derivatives are null',
                      'no cross-platform or full physical replay equality inferred','no penetration or owner-feel acceptance inferred']}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'captures':len(rows),'primary_pairs':len(pairs),'entry_failures':sum(p['entry_gate'] is False for p in pairs),
                      'overlap_unsupported':sum(p['overlap_gate'] is None for p in pairs)},indent=2))


if __name__=='__main__':
    main()
