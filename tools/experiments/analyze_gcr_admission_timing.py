"""Sequential timing reduction and selected physical telemetry-on/off comparison."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/experiments'))
from analyze_gcr_qualification import timings

NAMES=['rapier','coupling','native_tick','main_application']
FIELDS=['tick','body','in','out','pre_overlap','post_overlap','tick_overlap','conserved','water','material_count',
        'age','vertical_depth','horizontal_depth','hard_floor_contact','legacy_application']


def physical(report):
    rows=[]
    for row in report['rows']:
        value={k:row[k] for k in FIELDS if k in row}
        for key in ['result','computed_result']:
            if key in row:value[key]=[v for i,v in enumerate(row[key]) if i not in [8,13]]
        if 'application' in row:
            value['application']={k:v for k,v in row['application'].items() if k!='snapshot'}
            value['application']['bodies']=[{k:v for k,v in b.items() if k!='sample'} for b in row['application'].get('bodies',[])]
        rows.append(value)
    return {'case':report['case'],'candidate':report['candidate'],'rows':rows,'edits':report.get('edits',[]),
            'final_material_observations':{k:v for k,v in report['final'].items() if k in ['counts','sum_y','water_mass','completed_ticks','attempted_ticks','failed']}}


def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def firstdiff(a,b,path=''):
    if type(a)!=type(b):return {'path':path,'reference':a,'timing':b}
    if isinstance(a,dict):
        if a.keys()!=b.keys():return {'path':path,'reference_keys':list(a),'timing_keys':list(b)}
        for k in a:
            if a[k]!=b[k]:return firstdiff(a[k],b[k],path+'/'+str(k))
    elif isinstance(a,list):
        if len(a)!=len(b):return {'path':path,'reference_count':len(a),'timing_count':len(b)}
        for i,(x,y) in enumerate(zip(a,b)):
            if x!=y:return firstdiff(x,y,path+'/'+str(i))
    elif a!=b:return {'path':path,'reference':a,'timing':b}
    return None


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--timing',type=Path,required=True);parser.add_argument('--reference',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();campaign=json.loads(args.timing.read_text(encoding='utf-8'));reference=json.loads(args.reference.read_text(encoding='utf-8'))
    if not campaign['complete']:raise RuntimeError('Timing campaign incomplete')
    if campaign.get('functional_process_concurrency')!=1:raise RuntimeError('Timing was not sequential')
    for k in ['protocol_sha256','native_sha256','rapier_sha256','engine_sha256']:
        if campaign['identity'][k]!=reference['identity'][k]:raise RuntimeError('Physics runtime/registration changed: '+k)
    ref={(c['case'],c['arm']):c for c in reference['captures']};per_capture=[];pooled={};replays=[]
    for capture in campaign['captures']:
        report=json.loads((args.timing.parent/capture['raw']).read_text(encoding='utf-8'));warm=[r for r in report['rows'] if r['tick']>=120]
        if report.get('telemetry') is not False:raise RuntimeError('Expected telemetry-off timing')
        values={name:[r['times_us'][i] for r in warm] for i,name in enumerate(NAMES)}
        values['total_measured_components']=[sum(r['times_us'])+r.get('packing_us',0) for r in warm]
        for name in ['packing_us','coupling_prepare_us','result_generation_us','diagnostic_copy_us','admission_counter_copy_us']:
            values[name]=[r[name] for r in warm if name in r]
        values['scanned_work']=[r['work'][0] for r in warm]
        per_capture.append({'case':capture['case'],'arm':capture['arm'],'repeat':capture['repeat'],
                            'metrics':{name:timings(v) for name,v in values.items()},'component_sums':{name:sum(v) for name,v in values.items()},'raw_sha256':capture['raw_sha256']})
        key=(capture['case'],capture['arm'])
        if key not in pooled:pooled[key]={name:[] for name in values}
        for name,v in values.items():pooled[key][name].extend(v)
        original=ref.get((capture['case'],capture['arm']))
        if original is None:
            replays.append({'case':capture['case'],'arm':capture['arm'],'repeat':capture['repeat'],'selected_physical_values_exact':None,'reason':'No same-source telemetry-on primary reference in the registered R2 stratum.'});continue
        before=physical(json.loads((args.reference.parent/original['raw']).read_text(encoding='utf-8')));after=physical(report)
        mismatch=firstdiff(before,after)
        replays.append({'case':capture['case'],'arm':capture['arm'],'repeat':capture['repeat'],'selected_physical_values_exact':mismatch is None,
                        'reference_physical_sha256':digest(before),'timing_physical_sha256':digest(after),'first_difference':mismatch})
    pools=[{'case':case,'arm':arm,'metrics':{name:timings(v) for name,v in values.items()},'component_sums':{name:sum(v) for name,v in values.items()}} for (case,arm),values in pooled.items()]
    def comparisons(items):
        lookup={(x['case'],x.get('repeat',-1),x['arm']):x for x in items};result=[]
        for (case,repeat,arm),g in lookup.items():
            if arm!='GCR-A1':continue
            for reference_arm in ['Y1','GCR']:
                y=lookup[case,repeat,reference_arm];row={'case':case,'repeat':repeat,'reference':reference_arm,'candidate':'GCR-A1','components':{}}
                for name in NAMES+['total_measured_components']:
                    a,b=y['metrics'][name]['p95'],g['metrics'][name]['p95']
                    row['components'][name]={'reference_p95_us':a,'A1_p95_us':b,'delta_us':b-a,
                                             'ratio':b/a if a else None,'investigation_trigger':b>a*1.25 and b-a>25}
                a,b=y['metrics']['scanned_work']['p95'],g['metrics']['scanned_work']['p95']
                row['scanned_work']={'reference_p95':a,'A1_p95':b,'ratio':b/a if a else None,'investigation_trigger':b>a*2}
                result.append(row)
        return result
    output={'schema':1,'timing_identity':{k:v for k,v in campaign['identity'].items() if k!='project_inputs'},
            'reference_identity':{k:v for k,v in reference['identity'].items() if k!='project_inputs'},
            'per_capture':per_capture,'pooled_three_processes':pools,'per_repeat_comparisons':comparisons(per_capture),
            'pooled_comparisons':comparisons(pools),'telemetry_comparisons':replays,
            'all_supported_selected_physical_values_exact':all(x['selected_physical_values_exact'] is True for x in replays if x['selected_physical_values_exact'] is not None),'unsupported_telemetry_comparisons':sum(x['selected_physical_values_exact'] is None for x in replays),
            'limits':['120 warmup ticks removed; pooled quantiles pool samples, not process independence.',
                      'Recorded timing components exclude diagnostic observations, overlap scans, report construction and serialization.',
                      'No full solver/contact/event/passivity/slip ledger was acquired with telemetry off; those missing metrics remain null. Cheap immutable A1 admission counters remain measured.',
                      'Material counts/Water/positions/applications are compared; this is not full cell-state equality.',
                      'Recorded timing/reference identities are explicit; this captured pair shares source3d. Inspect maps rather than assuming different sources. Physics native/Rapier/engine/protocol hashes match.']}
    args.output.write_text(json.dumps(output,indent=2),encoding='utf-8');print('timing receipts',len(per_capture),'all supported selected physical exact',output['all_supported_selected_physical_values_exact'])
    for row in output['pooled_comparisons']:print(json.dumps(row))


if __name__=='__main__':main()
