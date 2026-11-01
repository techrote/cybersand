"""Retained selected R2 trajectories across compositions, not runtime identity."""
import argparse
import hashlib
import json
from pathlib import Path

PHYSICAL=['tick','body','in','out','pre_overlap','post_overlap','tick_overlap','conserved','water','material_count',
          'work','age','vertical_depth','horizontal_depth','hard_floor_contact','bearing_y','support','local_slip','legacy_application']


def projection(report):
    rows=[]
    for row in report['rows']:
        p={k:row[k] for k in PHYSICAL if k in row}
        for key in ['result','computed_result']:
            if key in row:p[key]=[value for i,value in enumerate(row[key]) if i not in [8,13]]
        if 'gcr'in row:p['gcr']={k:v for k,v in row['gcr'].items() if k!='admission'}
        if 'application'in row:
            p['application']={k:v for k,v in row['application'].items() if k!='snapshot'}
            p['application']['bodies']=[{k:v for k,v in b.items() if k!='sample'} for b in row['application'].get('bodies',[])]
        rows.append(p)
    return {'case':report['case'],'candidate':report['candidate'],'rows':rows,'edits':report.get('edits',[]),'final':report['final'],'conserved':report.get('conserved')}


def diff(a,b,path=''):
    if type(a)!=type(b):return {'path':path,'reference':a,'successor':b}
    if isinstance(a,dict):
        if a.keys()!=b.keys():return {'path':path,'reference_keys':list(a),'successor_keys':list(b)}
        for key in a:
            if a[key]!=b[key]:return diff(a[key],b[key],path+'/'+str(key))
    elif isinstance(a,list):
        if len(a)!=len(b):return {'path':path,'reference_count':len(a),'successor_count':len(b)}
        for i,(x,y) in enumerate(zip(a,b)):
            if x!=y:return diff(x,y,path+'/'+str(i))
    elif a!=b:return {'path':path,'reference':a,'successor':b}
    return None


def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode('utf-8')).hexdigest()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--reference',type=Path,required=True);parser.add_argument('--successor',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();reference=json.loads(args.reference.read_text(encoding='utf-8'));successor=json.loads(args.successor.read_text(encoding='utf-8'))
    if not successor['complete']:raise RuntimeError('Successor campaign incomplete')
    lookup={(c['case'],c['arm']):c for c in reference['captures']};results=[]
    for cap in successor['captures']:
        if cap['arm']!='GCR' or cap['status']!='captured':continue
        old=lookup[cap['case'],'GCR'];oldraw=(args.reference.parent/old['raw']).read_bytes();newraw=(args.successor.parent/cap['raw']).read_bytes()
        if hashlib.sha256(oldraw).hexdigest()!=old['raw_sha256'] or hashlib.sha256(newraw).hexdigest()!=cap['raw_sha256']:raise RuntimeError('Raw hash changed')
        a=projection(json.loads(oldraw));b=projection(json.loads(newraw));mismatch=diff(a,b)
        results.append({'case':cap['case'],'selected_R2_physical_values_exact':mismatch is None,'reference_raw_sha256':old['raw_sha256'],'successor_raw_sha256':cap['raw_sha256'],
                        'reference_physical_sha256':digest(a),'successor_physical_sha256':digest(b),'first_difference':mismatch})
    identity=lambda c:{k:v for k,v in c['identity'].items() if k!='project_inputs'}
    output={'schema':1,'reference_identity':identity(reference),'successor_identity':identity(successor),
            'scope':'Exact selected retained R2 physical/material observations across explicitly different source/native compositions, not same-runtime identity or full cell-state equivalence.',
            'explicit_exclusions':['row timing fields','row new admission counters and counter-copy time','nested gcr.admission metadata','source/receipt metadata','result offsets8sample/13session','application.snapshot','application.bodies.sample'],
            'projection_script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'all_selected_exact':all(r['selected_R2_physical_values_exact'] for r in results),'results':results}
    args.output.write_text(json.dumps(output,indent=2),encoding='utf-8');print(len(results),'R2 comparisons; all selected exact',output['all_selected_exact'])


if __name__=='__main__':main()
