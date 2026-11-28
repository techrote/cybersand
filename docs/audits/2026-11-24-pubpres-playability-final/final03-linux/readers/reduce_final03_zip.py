#!/usr/bin/env python3
"""Stream retained Linux03 raw physical witnesses, using independent stdlib math."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--workspace-root',type=Path,default=Path('/workspace/scratch/0b2a9bdf7883'))
p.add_argument('--output',type=Path)
args=p.parse_args()
base=args.workspace_root.resolve()
sys.path.insert(0,str(base/'cybersand-qualification/tools/pubpres_final'))
import independent_reduction as independent

def need(value,message):
    if not value:raise ValueError(message)

def sha(data):return hashlib.sha256(data).hexdigest()

archive=base/'evidence-root/final-03/graphical-linux/original.zip'
with archive.open('rb') as stream:outer=hashlib.file_digest(stream,'sha256').hexdigest()
need(outer=='afc128e3d90d952b3c801ba489d9ce66db51d10c7420094fb9f2096dbb20da71','exact downloaded Linux03 artifact')
report={'schema':'pubpres-final03-linux-independent-physical-v1','archive_sha256':outer,
        'audit_program_sha256':sha(Path(__file__).read_bytes()),
        'independent_reader_sha256':sha(Path(independent.__file__).read_bytes()),
        'receipts':[],'failures':[],'separate_sustained_functional_receipts':[],
        'physical_acceptance':'HOLD',
        'scope':'Independent raw step/callback/native/terrain/body/input proof and per-process physical quantiles. Source/GPU/material/observer/cadence gates require their separate complete replay. Draw clocks are Main notifications, not scanout. Thresholds100/250/500/1000ms are reporting categories, not owner acceptance budgets.'}
with zipfile.ZipFile(archive) as z:
    summaries={name:json.loads(z.read(name)) for name in z.namelist() if name.endswith('/SUMMARY.json')}
    accepted={}
    for name,s in summaries.items():
        for case in s.get('cases',[]):
            for arm in case.get('arms',[case]):
                if 'receipt_sha256' in arm:
                    accepted[arm['receipt_sha256']]=(name,case['case'],arm)
    for name in sorted(x for x in z.namelist() if x.endswith('/receipt.json')):
        try:
            raw=z.read(name);data=json.loads(raw)
            if name.startswith('original-safe/'):
                report['separate_sustained_functional_receipts'].append({'member':name,'receipt_sha256':sha(raw),'schema':data.get('schema'),'scope':'Distinct functional sustained fixture, not silently substituted for timed V3 physical captures.'})
                continue
            trace_name=name.removesuffix('.json')+'-events.jsonl'
            trace=z.read(trace_name)
            need(sha(trace)==data['trace_sha256'],'actual original trace hash')
            allrows=[json.loads(line) for line in trace.decode('utf-8').splitlines()]
            need(allrows[0]['event']=='identity' and allrows[0]['source']==data['source_identity'],'trace identity')
            need(data['observer_mode']=='full' and data['complete'] is True and data['failures']==[],'complete raw full observer')
            rows=allrows[1:]
            steps,witness=independent.witnessed_steps(data,rows)
            windows={'whole_capture':independent.measure(data,rows,steps,data['capture_end_usec'])}
            if len(steps)>=144:windows['first_144_steps']=independent.measure(data,rows,steps,steps[143]['time_usec'])
            body=sha(json.dumps([row['bodies'] for row in steps[:144]],sort_keys=True,separators=(',',':')).encode())
            need(sha(raw) in accepted,'raw receipt included in actual qualification summary')
            summary_name,case,arm=accepted[sha(raw)]
            for window,result in windows.items():
                expected=arm['statistics']['windows'][window]
                need(abs(expected['rapier_steps_per_second']-result['rapier_steps_per_second'])<1e-10 and expected['completed_rapier_steps']==result['completed_rapier_steps'],'independent physical rate/count')
                need(all(abs(expected['physical_gap_ms'][k]-result['physical_gap_ms'][k])<1e-8 for k in ['p50','p95','p99','max']),'independent physical quantiles')
            result={'member':name,'receipt_sha256':sha(raw),'trace_sha256':sha(trace),
                    'summary_member':summary_name,'summary_sha256':sha(z.read(summary_name)),
                    'case':case,'source':data['source_identity']['source_sha'],'engine_sha256':data['source_identity']['engine_sha256'],
                    'cpu':data['cpu'],'adapter':data['adapter'],'renderer':data['renderer'],'render_thread':data['render_thread'],
                    'selectors_before':data['selectors_before'],'selectors_after':data['selectors_after'],
                    'physical_witness':witness,'windows':windows,'first_144_body_trajectory_sha256':body,
                    'agrees_with_retained_summary_physical_metrics':True}
            report['receipts'].append(result)
            print(name, len(steps), round(windows['whole_capture']['rapier_steps_per_second'],3),'steps/s',round(windows['whole_capture']['physical_gap_ms']['max'],3),'max ms',flush=True)
        except Exception as error:
            report['failures'].append({'member':name,'reason':repr(error)})
            print('FAILED',name,repr(error),flush=True)
report['complete']=not report['failures'] and len(report['receipts'])==47
output=args.output.resolve() if args.output else base/'evidence-c/final03-linux-independent-physical.json'
need(not output.exists(),'original independent reduction must not be overwritten')
output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'complete':report['complete'],'captures':len(report['receipts']),'failures':report['failures'],'output':str(output),'sha256':sha(output.read_bytes())}))
