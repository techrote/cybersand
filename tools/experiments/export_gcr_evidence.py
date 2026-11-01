"""Export compact GCR evidence without changing or relabelling original captures.

Example: python tools/experiments/export_gcr_evidence.py --campaign primary=build/gcr-primary/campaign.json
         --campaign async=build/gcr-async/campaign.json --output build/gcr-export
Use separate labels/directories for each source-matched campaign generation.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(subprocess.check_output(['git','rev-parse','--show-toplevel'], cwd=Path(__file__).parent, text=True).strip())
sys.path.insert(0, str(ROOT/'tools/experiments'))
from analyze_gcr_qualification import summarize, compare_pair, applied_wrench

SELECTED = {'sand-vertical','sand-horizontal','sand-glancing','sand-stream','anchor-90','heavy-90','angle45-30','stone-excavate'}
METRICS = ['complete','conserved','peak_horizontal_entry','peak_vertical_entry','total_peak_horizontal_entry',
           'total_peak_vertical_entry','peak_pre_overlap','peak_post_overlap','peak_tick_overlap',
           'first_unresolved_tick','first_hard_floor_tick','pre_hard_peak_abs_omega','late_peak_speed',
           'late_peak_abs_omega','total_applied_Jx_Jy_L','total_observed_packet_Jx_Jy_L',
           'peak_abs_local_slip','passivity_rejections','timing_us','async_timing_us','work']
LEDGER = ['bins','nodes','updates','normal_capacity','normal_raw','normal_accepted','normal_rejected',
          'tangent_accepted','event_budget_cost','event_accepted','normal_impulse','tangent_impulse',
          'legacy_non_granular','impulse','torque','passive_torque','passivity_rejected','refused']


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda:handle.read(1024*1024),b''): digest.update(block)
    return digest.hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2), encoding='utf-8')


def native_rows(report):
    if report['mode']=='desktop-asynchronous':
        return [dict(body,tick=row['tick']) for row in report.get('worker_trace',[]) if isinstance(row,dict)
                for body in row.get('gcr',{}).get('bodies',[])]
    return [dict(row['gcr'],tick=row['tick']) for row in report['rows'] if 'gcr' in row]


def mechanism_counts(report):
    rows=report['rows']; native=native_rows(report); supported=[r for r in native if r.get('bins',0)>0]
    result={'native_ledger_boundaries':len(native),'supported_native_boundaries':len(supported) if native else None,
            'positive_normal_native_boundaries':sum(r.get('normal_accepted',0)>0 for r in native) if native else None,
            'maximum_bins':max((r.get('bins',0) for r in native),default=None),
            'maximum_nodes':max((r.get('nodes',0) for r in native),default=None),
            'maximum_updates':max((r.get('updates',0) for r in native),default=None),
            'held_deliveries':sum(bool(r.get('held')) for r in rows)}
    if report['candidate'].startswith('GCR'):
        accepted=[r for r in rows if not r.get('held') and r.get('application',{}).get('accepted')]
        bodies=[b for r in accepted for b in r['application'].get('bodies',[]) if b.get('index')==int(r.get('body',1))-1]
        result.update(accepted_main_boundaries=len(accepted),
                      refusal_reasons=dict(collections.Counter(r.get('application',{}).get('refusal','unsupported') for r in rows if not r.get('application',{}).get('accepted'))),
                      accepted_age_histogram=dict(collections.Counter(str(b['age']) for b in bodies)),
                      maximum_accepted_contact_displacement=max((b.get('contact_displacement',0) for b in bodies),default=None))
    else:
        result['nonzero_actual_main_impulses']=sum(any(x!=0 for x in (applied_wrench(r,report['candidate']) or [])) for r in rows)
    return result


def event_analysis(report):
    floor=next((r['tick'] for r in report['rows'] if r.get('hard_floor_contact')),None)
    supported=[r for r in native_rows(report) if r.get('bins',0)>0 and (floor is None or r['tick']<floor)]
    if not supported: return None
    saturated=[r for r in supported if r.get('event_budget_cost',0)>=20-1e-5]
    capacity_reduction=[max(0,min(20,2*sum(b['count'] for b in r.get('contact_bins',[])))-r['normal_capacity']) for r in supported]
    main_rows=[r for r in report['rows'] if floor is None or r['tick']<floor]
    actual=[applied_wrench(r,report['candidate']) for r in main_rows]
    return {'scope':'native ledger boundaries before first observed hard floor; these are computed values, not actual applications',
            'supported_boundaries':len(supported),'event_budget20_boundaries':len(saturated),
            'event_budget20_positive_downward_y':sum(r['event_accepted'][1]>0 for r in saturated),
            'event_budget20_zero_passive_normal':sum(r['normal_accepted']==0 for r in saturated),
            'maximum_event_budget_cost':max(r['event_budget_cost'] for r in supported),
            'capacity_reduced_boundaries_vs_no_event':sum(value>1e-6 for value in capacity_reduction),
            'sum_capacity_reduction_vs_min20_2samples':sum(capacity_reduction),
            'positive_downward_event_y_boundaries':sum(r['event_accepted'][1]>0 for r in supported),
            'mean_remaining_normal_capacity':sum(r['normal_capacity'] for r in supported)/len(supported),
            'sum_computed_event_y':sum(r['event_accepted'][1] for r in supported),
            'sum_computed_passive_normal_y':sum(r['normal_impulse'][1] for r in supported),
            'sum_computed_tangent_y':sum(r['tangent_impulse'][1] for r in supported),
            'sum_computed_total_y':sum(r['impulse'][1] for r in supported),
            'main_delivery_rows_beforehard':len(main_rows),
            'sum_actual_main_applied_y_beforehard':sum(value[1] for value in actual) if all(value is not None for value in actual) else None,
            'comparison_limit':'Native computed-boundary sums and actual main-delivery sums have different populations/cadence; their difference is not a matched counterfactual.'}


def selected_trace(report):
    if report['case']['id'] not in SELECTED: return None
    rows=report['rows']; indices=set()
    if not rows: return []
    indices.add(0);indices.add(len(rows)-1)
    for key in ['vertical_depth','horizontal_depth','pre_overlap','post_overlap']:
        valid=[i for i,r in enumerate(rows) if r.get(key) is not None]
        if valid: indices.add(max(valid,key=lambda i:rows[i][key]))
    for predicate in [lambda r: r.get('hard_floor_contact'),lambda r:r.get('gcr',{}).get('bins',0)>0,
                      lambda r:r.get('gcr',{}).get('event_budget_cost',0)>0,lambda r:r.get('tick',0)>=600]:
        index=next((i for i,r in enumerate(rows) if predicate(r)),None)
        if index is not None:
            indices.add(index)
            if index>0:indices.add(index-1)
    worker={r['tick']:r for r in report.get('worker_trace',[]) if isinstance(r,dict)}
    result=[]
    for i in sorted(indices)[:12]:
        row=rows[i]; value={k:row[k] for k in ['tick','body','rapier_tick','delivery','held','in','out','vertical_depth','horizontal_depth',
                        'pre_overlap','post_overlap','tick_overlap','hard_floor_contact','age','result','computed_result','application','legacy_application'] if k in row}
        if 'gcr' in row:value['gcr']={k:row['gcr'][k] for k in LEDGER if k in row['gcr']}
        elif row['tick'] in worker:
            bodies=worker[row['tick']].get('gcr',{}).get('bodies',[])
            index=int(row.get('body',1))-1
            if index<len(bodies):value['native_ledger_at_published_tick']={k:bodies[index][k] for k in LEDGER if k in bodies[index]}
        result.append(value)
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--campaign',action='append',required=True,help='Unique label=campaign.json')
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--bundle',action='append',type=Path,default=[],help='Existing raw archive to hash; never creates/rewrites one')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=False)
    manifest={'schema':1,'campaigns':[],'raw_files':[],'archives':[],'exporter_sha256':sha(__file__),
              'reducer_sha256':sha(ROOT/'tools/experiments/analyze_gcr_qualification.py')}
    labels=set()
    for item in args.campaign:
        label,rawpath=item.split('=',1)
        if label in labels or not label.replace('-','').replace('_','').isalnum():raise ValueError('Unique simple labels required')
        labels.add(label);path=Path(rawpath);campaign=json.loads(path.read_text(encoding='utf-8'));identity=campaign['identity']
        compact_identity={k:v for k,v in identity.items() if k!='project_inputs'}
        compact_identity['project_input_count']=len(identity.get('project_inputs',{}))
        manifest['campaigns'].append({'label':label,'path':str(path),'sha256':sha(path),'identity':compact_identity})
        receipts=[];traces=[];failures=[]
        for capture in campaign['captures']:
            record={k:capture.get(k) for k in ['case','arm','mode','repeat','status','raw','raw_sha256','log','log_sha256']};record['campaign']=label
            manifest['raw_files'].append(record)
            if capture['status']!='captured':failures.append(capture);continue
            raw=path.parent/capture['raw']
            if sha(raw)!=capture['raw_sha256']:raise RuntimeError('Raw hash differs: '+str(raw))
            report=json.loads(raw.read_text(encoding='utf-8'))
            for key in ['protocol_sha256','input_identity']:
                if report[key]!=identity[key]:raise RuntimeError('Mixed identity '+key)
            reduced=summarize(report)
            reduced.update(repeat=capture['repeat'],raw_sha256=capture['raw_sha256'])
            reduced['mechanism_counts']=mechanism_counts(report);reduced['event_analysis']=event_analysis(report)
            receipts.append(reduced)
            selected=selected_trace(report)
            if selected is not None:traces.append({'case':capture['case'],'arm':capture['arm'],'repeat':capture['repeat'],'raw_sha256':capture['raw_sha256'],'rows':selected})
        grouped={(r['case'],r['candidate'],r['repeat']):r for r in receipts};pairs=[]
        for (case,arm,repeat),y1 in grouped.items():
            if arm=='Y1' and (case,'GCR',repeat) in grouped:pairs.append(compare_pair(y1,grouped[(case,'GCR',repeat)],repeat))
        boolean_keys=sorted({k for p in pairs for k,v in p.items() if isinstance(v,bool) or (v is None and (k.endswith('nonworsening') or k.endswith('gate') or k.endswith('required')))})
        gate_counts={}
        for key in boolean_keys:
            applicable=[p for p in pairs if key in p]
            investigation=key.endswith('required')
            gate_counts[key]={'applicable_pairs':len(applicable),'true':sum(p[key] is True for p in applicable),
                              'false':sum(p[key] is False for p in applicable),'unsupported':sum(p[key] is None for p in applicable),
                              'meaning':'true requests investigation' if investigation else 'true satisfies this comparison',
                              'true_cases':[p['case'] for p in applicable if p[key] is True],
                              'false_cases':[p['case'] for p in applicable if p[key] is False]}
        compact_receipts=[dict({'case':r['case'],'candidate':r['candidate'],'repeat':r['repeat'],'mode':r['mode'],'raw_sha256':r['raw_sha256'],
                                'mechanism_counts':r['mechanism_counts'],'event_analysis':r['event_analysis']},**{k:r[k] for k in METRICS if k in r}) for r in receipts]
        summary={'schema':1,'label':label,'identity':compact_identity,'campaign_complete':campaign['complete'],
                 'timing_scope':campaign.get('timing_scope','unclassified'),
                 'counts':{'captures':len(receipts),'pairs':len(pairs),'execution_failures':len(failures),'complete_receipts':sum(r['complete'] for r in receipts),'quantity_conserved_receipts':sum(r['conserved'] for r in receipts)},
                 'gate_counts':gate_counts,'pairs':pairs,'receipts':compact_receipts,'execution_failures':failures,
                 'limits':['Completion/conservation does not establish efficacy, torque causality or human acceptance.',
                           'Missing measurements remain null; computed event ledgers are not actual applied body impulses.',
                           'Concurrent functional timings are not performance qualification; keep failed source generations separate.']}
        write(args.output/f'{label}-summary.json',summary);write(args.output/f'{label}-selected-traces.json',{'schema':1,'label':label,'identity':compact_identity,'traces':traces})
    for path in args.bundle:manifest['archives'].append({'path':str(path),'size':path.stat().st_size,'sha256':sha(path)})
    canonical=json.dumps(manifest['raw_files'],sort_keys=True,separators=(',',':')).encode()
    manifest['raw_file_manifest_sha256']=hashlib.sha256(canonical).hexdigest()
    write(args.output/'raw-bundle-manifest.json',manifest)
    print(json.dumps({'campaigns':len(labels),'raw_receipts':len(manifest['raw_files']),'output':str(args.output),'manifest_sha256':sha(args.output/'raw-bundle-manifest.json')}))


if __name__=='__main__':main()
