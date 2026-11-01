"""Exact same-source replay comparison, including actual physical application."""
import argparse
import hashlib
import json
from pathlib import Path

PHYSICAL=['tick','body','in','out','pre_overlap','post_overlap','tick_overlap','conserved','water','material_count',
          'work','age','vertical_depth','horizontal_depth','hard_floor_contact','bearing_y','support','local_slip','gcr','legacy_application']


def projection(report):
    rows=[]
    for row in report['rows']:
        p={k:row[k] for k in PHYSICAL if k in row}
        for key in ['result','computed_result']:
            if key in row:p[key]=[value for i,value in enumerate(row[key]) if i not in [8,13]]
        if 'application' in row:
            a=row['application'];p['application']={k:v for k,v in a.items() if k!='snapshot'}
            p['application']['bodies']=[{k:v for k,v in b.items() if k!='sample'} for b in a.get('bodies',[])]
        rows.append(p)
    return {'case':report['case'],'candidate':report['candidate'],'rows':rows,'edits':report.get('edits',[]),
            'conserved':report.get('conserved'),'final':report.get('final')}


def hash_value(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def difference(a,b,path=''):
    if type(a)!=type(b):return {'path':path,'reference':a,'repeat':b}
    if isinstance(a,dict):
        if a.keys()!=b.keys():return {'path':path,'reference_keys':list(a),'repeat_keys':list(b)}
        for k in a:
            if a[k]!=b[k]:return difference(a[k],b[k],path+'/'+str(k))
    elif isinstance(a,list):
        if len(a)!=len(b):return {'path':path,'reference_length':len(a),'repeat_length':len(b)}
        for i,(x,y) in enumerate(zip(a,b)):
            if x!=y:return difference(x,y,path+'/'+str(i))
    elif a!=b:return {'path':path,'reference':a,'repeat':b}
    return None


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--reference',type=Path,required=True);parser.add_argument('--repeat',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();ref=json.loads(args.reference.read_text(encoding="utf-8"));repeat=json.loads(args.repeat.read_text(encoding="utf-8"))
    for key in ['source','protocol_sha256','native_sha256','rapier_sha256','input_identity']:
        if ref['identity'][key]!=repeat['identity'][key]:raise RuntimeError('Not same identity: '+key)
    lookup={(x['case'],x['arm']):x for x in ref['captures']};results=[]
    for capture in repeat['captures']:
        original=lookup[capture['case'],capture['arm']]
        a=projection(json.loads((args.reference.parent/original['raw']).read_text(encoding="utf-8")));b=projection(json.loads((args.repeat.parent/capture['raw']).read_text(encoding="utf-8")))
        mismatch=difference(a,b)
        results.append({'case':capture['case'],'arm':capture['arm'],'exact_physical_replay':mismatch is None,
                        'reference_raw_sha256':original['raw_sha256'],'repeat_raw_sha256':capture['raw_sha256'],
                        'reference_physical_sha256':hash_value(a),'repeat_physical_sha256':hash_value(b),'first_difference':mismatch})
    output={'schema':1,'identity':{k:ref['identity'][k] for k in ['source','protocol_sha256','native_sha256','rapier_sha256','input_identity']},
            'comparison':'Exact physical values, including application/refusal/age/scaled and translated wrench, recorded material observations, edits and final observations. Full cells/state hashes were not captured. Only clocks, source receipts, sample/session/snapshot identifiers excluded.',
            'all_exact':all(x['exact_physical_replay'] for x in results),'results':results, 'projection_script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'projection_script':'tools/experiments/compare_gcr_replay.py', 'scope_note':'The PHYSICAL whitelist and result/application identity omissions define the exact projection; no complete cell/state replay claim.'}
    args.output.write_text(json.dumps(output,indent=2),encoding='utf-8');print(json.dumps(output,indent=2))


if __name__=='__main__':main()
