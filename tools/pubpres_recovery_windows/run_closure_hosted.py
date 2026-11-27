#!/usr/bin/env python3
"""Actual Windows source/native/engine application admission before packaging."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import sys

import atomic_delivery
from closure_request import validate
ROOT=Path(__file__).resolve().parents[2]
HERE=ROOT/'tools/pubpres_final_recovery'
sys.path.insert(0,str(HERE))
from identity import driver_identity,digest
from process_owner import bounded_process
from results import need


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('runtime','stock-engine','atomic-root','output'):parser.add_argument('--'+name,type=Path,required=True)
    args=parser.parse_args()
    need(os.name=='nt','This inventory requires actual Windows execution')
    request=validate();need(request['phase'] in ('full','delivery'),'Full application qualification was not requested')
    output=args.output.resolve();need(not output.exists(),'Preserve original hosted qualification output')
    output.mkdir(parents=True)
    runtime=args.runtime.resolve();stock=args.stock_engine.resolve();atomic_root=args.atomic_root.resolve()
    build=atomic_delivery.verify_payload(atomic_root);custom=atomic_root/build['gui_executable']
    pin=atomic_delivery.pin();identity=driver_identity()
    report={'schema':'pubpres-recovery-hosted-v1','closure_request':request,
        'request':{'phase':'integration','engine_artifact':{k:v for k,v in pin.items() if k!='gui_sha256'}},
        'driver':identity,'source':identity['source_commit'],'run':os.environ.get('GITHUB_RUN_ID'),
        'attempt':os.environ.get('GITHUB_RUN_ATTEMPT'),'platform':'windows','outcomes':[],'unexecuted':[],
        'closure_members_required':True,'closure_native_owner_required':True,'complete':False,'physical_acceptance':'HOLD',
        'scope':'Closure resulting-source actual Windows application admission. Original frozen19/submission2/water4 retained; multipart4 added. No physical NVIDIA or comparative performance acceptance.'}
    def save():
        (output/'INVENTORY.json').write_text(json.dumps(report,indent=2)+'\n')
    def execute(label,command,timeout=2400):
        row={'name':label,'command':[str(sys.executable),*map(str,command)],'timeout_seconds':timeout,
             'returncode':None,'timed_out':False}
        report['outcomes'].append(row);save()
        with (output/(label+'.log')).open('x',encoding='utf-8') as stream:
            status,timed_out=bounded_process(row['command'],cwd=ROOT,stdout=stream,timeout=timeout)
        row.update(returncode=status,timed_out=timed_out);save()
        return status==0 and not timed_out
    exact=['--engine-payload',atomic_root,'--engine-build-source',pin['source'],'--engine-build-run',pin['run'],
        '--engine-build-attempt',pin['attempt'],'--engine-proof-sha256',pin['proof_sha256']]
    def qualify(label,engine,focus,thread='safe',budget=0):
        return execute(label,[HERE/'run_qualification.py','--source',ROOT,'--runtime',runtime,'--engine',engine,
            '--output',output/label,'--focus',focus,'--render-thread',thread,'--lookahead',budget,
            *([] if engine==stock else exact)])
    save()
    stock_native=execute('stock-native-owner',[ROOT/'tools/pubpres_recovery_windows/run_native_owner.py',
        '--source',ROOT,'--runtime',runtime,'--engine',stock,'--output',output/'stock-native-owner'])
    atomic_native=execute('atomic-native-owner',[ROOT/'tools/pubpres_recovery_windows/run_native_owner.py',
        '--source',ROOT,'--runtime',runtime,'--engine',custom,'--output',output/'atomic-native-owner',*exact])
    stock_ok=stock_native and qualify('stock-frozen-correctness',stock,'frozen')
    if stock_ok:
        water_ok=qualify('stock-water-correctness',stock,'water')
        members_ok=qualify('stock-members-correctness',stock,'members')
    else:
        water_ok=members_ok=False
        report['unexecuted'].append({'gate':'Water/multipart/atomic','reason':'Original resulting-source Stock correctness failed'})
    if stock_ok and water_ok and members_ok and atomic_native:
        atomic_ok=qualify('atomic-frozen-correctness',custom,'frozen')
        if atomic_ok:
            for thread,budget in (('safe',0),('separate',0),('separate',4)):
                qualify(f'atomic-submission-{thread}-{budget}',custom,'submission',thread,budget)
                qualify(f'atomic-water-{thread}-{budget}',custom,'water',thread,budget)
            for thread,budget in (('safe',0),('separate',4)):
                qualify(f'atomic-members-{thread}-{budget}',custom,'members',thread,budget)
            execute('atomic-font-and-first-read',[HERE/'run_graphical_controls.py','--source',ROOT,'--runtime',runtime,
                '--stock-engine',stock,'--output',output/'atomic-font-and-first-read',*exact],3600)
        else:report['unexecuted'].append({'gate':'atomic application integration','reason':'Original custom-engine correctness failed'})
    elif stock_ok:
        report['unexecuted'].append({'gate':'atomic application integration','reason':'Stock Water/multipart or actual atomic native ownership failed'})
    report['complete']=not report['unexecuted'] and all(row['returncode']==0 and not row['timed_out'] for row in report['outcomes'])
    save()
    if report['complete']:
        try:
            from run_campaign import source_identity
            from retained_runtime import validate_runtime
            from qualification_gate import verify_inventory
            source=source_identity(ROOT);source['native_runtime']=validate_runtime(ROOT,source,runtime,False)
            admitted=verify_inventory(output/'INVENTORY.json',source,identity,stock,custom,True)
            (output/'ADMITTED.json').write_text(json.dumps(admitted,indent=2)+'\n')
        except Exception as exc:
            report['complete']=False
            report['reduction_failure']={'type':type(exc).__name__,'message':str(exc)}
            save()
    print(json.dumps({'complete':report['complete'],'outcomes':len(report['outcomes']),'unexecuted':report['unexecuted']}))
    return 0 if report['complete'] else 1


if __name__=='__main__':sys.exit(main())
