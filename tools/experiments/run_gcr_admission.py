"""Run only the preregistered admission successor population after its mechanical gate."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

import run_gcr_qualification as legacy

ROOT=legacy.ROOT
PROTOCOL=ROOT/'docs/audits/gcr-admission-2026-11-01/protocol.json'
REGISTRATION='GCR-ADMISSION-001-2026-11-01'


def function_body(text, name):
    start=text.index(name);brace=text.index('{',start);level=1;end=brace+1
    while level:
        if text[end]=='{':level+=1
        elif text[end]=='}':level-=1
        end+=1
    return text[start:end]


def validate_registration(protocol):
    inherited=protocol['inherited_scenarios'];path=ROOT/inherited['path']
    canonical=legacy.git('show','HEAD:'+inherited['path'])
    if hashlib.sha256(canonical).hexdigest()!=inherited['canonical_sha256'] or path.read_bytes().replace(b'\r\n',b'\n')!=canonical:
        raise RuntimeError('Frozen GCR001 registration changed')
    original=json.loads(canonical)
    for key in ['cases','controls','async_cases']:
        if protocol[key]!=original[key]:raise RuntimeError('Inherited scenario change: '+key)
    for relative,expected in protocol['frozen_law_files'].items():
        if legacy.digest(ROOT/relative,True)!=expected:raise RuntimeError('Frozen law/controller changed: '+relative)
    adapter=(ROOT/'godot/native_extension/cyber_native_cell_world.cpp').read_text()
    for name,expected in protocol['frozen_adapter_functions'].items():
        if hashlib.sha256(function_body(adapter,name).encode()).hexdigest()!=expected:
            raise RuntimeError('Frozen response/ejection function changed: '+name)


def authenticate(args):
    protocol,identity=legacy.authenticate(args,PROTOCOL,REGISTRATION)
    validate_registration(protocol)
    return protocol,identity


def schedule(protocol, phase):
    if phase=='primary':
        result=[];r2=set(protocol['synchronous']['additional_R2_case_ids'])
        for index,case in enumerate(protocol['synchronous']['case_ids']):
            arms=['Y1','GCR','GCR-A1'] if case in r2 else ['Y1','GCR-A1']
            for arm in (arms if index%2==0 else list(reversed(arms))):result.append((case,arm,0,'sync'))
        return result
    if phase=='timing':
        return [(case,arm,repeat,'sync') for repeat,arms in enumerate(protocol['performance']['repeat_arm_orders'])
                for case in protocol['performance']['case_ids'] for arm in arms]
    group=protocol[{'async':'async','controls':'negative_dynamic','replay':'replay'}[phase]]
    return [(case,arm,1 if phase=='replay' else 0,'async' if phase=='async' else 'sync')
            for index,case in enumerate(group['case_ids']) for arm in (group['arms'] if index%2==0 else list(reversed(group['arms'])))]


def validate_mechanical_receipt(path,identity):
    if path is None:raise RuntimeError('Physical acquisition requires the source-bound native/query/oracle/adapter mechanical receipt')
    value=json.loads(path.read_text())
    if value.get('ok') is not True:raise RuntimeError('Mechanical gate is not passing')
    for key in ['source','protocol_sha256','native_sha256','input_identity']:
        if value.get(key)!=identity[key]:raise RuntimeError('Stale mechanical receipt: '+key)
    for key in ['native_query','independent_oracle','adapter']:
        if value.get('gates',{}).get(key) is not True:raise RuntimeError('Mechanical prerequisite missing: '+key)
    return legacy.digest(path)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,default=Path('C:/Godot47/Godot_v4.7-stable_win64_console.exe'))
    parser.add_argument('--project',type=Path,default=ROOT/'godot')
    parser.add_argument('--native-manifest',type=Path,default=ROOT/('godot/addons/cybersand_native/runtime-provenance.json' if os.name=='nt' else 'godot/addons/cybersand_native/runtime-provenance.linux.json'))
    parser.add_argument('--output',type=Path,default=ROOT/'out/gcr-admission')
    parser.add_argument('--phase',choices=['primary','async','controls','replay','timing','review'],default='primary')
    parser.add_argument('--mechanical-receipt',type=Path)
    parser.add_argument('--case',action='append');parser.add_argument('--arms',nargs='+')
    parser.add_argument('--jobs',type=int,choices=[1,2,3],default=1)
    parser.add_argument('--timeout',type=int,default=240)
    parser.add_argument('--identity-only',action='store_true')
    args=parser.parse_args();args.project=args.project.resolve();args.output=args.output.resolve()
    protocol,identity=authenticate(args)
    if args.identity_only:print(json.dumps(identity,indent=2));return 0
    mechanical_sha=validate_mechanical_receipt(args.mechanical_receipt,identity)
    if args.phase=='review':
        env=os.environ.copy();env['CYBERSAND_SOURCE_REVISION']=identity['source']
        return subprocess.call([str(args.godot),'--path',str(args.project),'res://y1_envelope_review.tscn','--',f'--protocol={PROTOCOL}'],env=env)
    if args.phase=='timing' and args.jobs!=1:raise RuntimeError('Timing acquisition must be sequential after all other jobs finish')
    tasks=schedule(protocol,args.phase)
    if args.case:
        if not set(args.case)<={task[0] for task in tasks}:raise RuntimeError('Cases outside registered phase')
        tasks=[task for task in tasks if task[0] in args.case]
    if args.arms:
        if not set(args.arms)<=set(protocol['arms']):raise RuntimeError('Unregistered arm')
        tasks=[task for task in tasks if task[1] in args.arms]
    if not tasks:raise RuntimeError('No registered case/arm pairs selected')
    args.telemetry='off' if args.phase=='timing' else 'on'
    args.output.mkdir(parents=True,exist_ok=True);index=args.output/'campaign.json'
    if index.exists():raise RuntimeError('Use a fresh output directory; preserve earlier failures')
    campaign={'schema':1,'registration':REGISTRATION,'phase':args.phase,'identity':identity,'mechanical_receipt_sha256':mechanical_sha,
              'planned_captures':len(tasks),'functional_process_concurrency':args.jobs,
              'timing_scope':'sequential' if args.jobs==1 else 'functional concurrent timings are not performance evidence','captures':[],'complete':False}
    index.write_text(json.dumps(campaign,indent=2))
    def execute(task):
        _,current=authenticate(args)
        if current!=identity:raise RuntimeError('Source/runtime/project changed during campaign')
        if legacy.digest(args.mechanical_receipt)!=mechanical_sha:raise RuntimeError('Mechanical receipt changed during campaign')
        row=legacy.capture(args,identity,*task,protocol_path=PROTOCOL)
        if row['status']=='captured':
            report=json.loads((args.output/row['raw']).read_text());wanted='A1' if task[1]=='GCR-A1' else ('R2' if task[1]=='GCR' else 'disabled')
            if report.get('registration')!=REGISTRATION or report.get('granular_identity',{}).get('admission_variant')!=wanted:
                row['status']='failed';row['identity_refusal']='actual admission variant or registration mismatch'
        return row
    with ThreadPoolExecutor(args.jobs) as pool:
        for row in pool.map(execute,tasks):
            campaign['captures'].append(row);index.write_text(json.dumps(campaign,indent=2));print(row['status'],row['case'],row['arm'],row['repeat'],flush=True)
    campaign['complete']=len(campaign['captures'])==len(tasks) and all(r['status']=='captured' for r in campaign['captures'])
    index.write_text(json.dumps(campaign,indent=2));return 0 if campaign['complete'] else 1


if __name__=='__main__':sys.exit(main())
