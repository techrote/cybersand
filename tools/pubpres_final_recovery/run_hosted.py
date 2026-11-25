#!/usr/bin/env python3
"""Focused resulting-source qualification; every omitted or failed gate is retained."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import sys

from identity import ROOT, HERE, driver_identity, digest
from recovery_request import validate
from results import need
from run_focus import write_json
from process_owner import bounded_process


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('inputs','engine-root','output'):
        parser.add_argument('--'+name,type=Path,required=True)
    args=parser.parse_args()
    request=validate()
    output=args.output.resolve()
    need(not output.exists(),'Preserve original hosted results')
    output.mkdir(parents=True)
    windows=os.name=='nt'
    engine=args.engine_root.resolve()/('Godot_v4.7-stable_win64.exe' if windows else 'Godot_v4.7-stable_linux.x86_64')
    inputs=args.inputs.resolve()
    restore=json.loads((inputs/'RESTORE.json').read_bytes())
    shutil.copyfile(args.engine_root/'ENGINE.json',output/'ENGINE.json')
    display=[] if windows else ['--display-wrapper',str(ROOT/'tools/pubpres_playability_build/owned_xvfb.py')]
    identity=driver_identity()
    report={'schema':'pubpres-recovery-hosted-v1','request':request,'driver':identity,
        'source':identity['source_commit'],'run':os.environ.get('GITHUB_RUN_ID'),
        'attempt':os.environ.get('GITHUB_RUN_ATTEMPT'),'platform':'windows' if windows else 'linux',
        'restore':restore,'outcomes':[],'unexecuted':[],'complete':False,'physical_acceptance':'HOLD',
        'scope':'Resulting-source engineering and hosted graphics; no performance or physical-owner acceptance.',
        'retired_experiments':{'sha256':digest(HERE/'retired_experiments.json'),
                               'record':json.loads((HERE/'retired_experiments.json').read_bytes())}}
    def save(): write_json(output/'INVENTORY.json',report)
    def run(label,arguments,seconds=8400):
        row={'name':label,'command':[sys.executable,*map(str,arguments)],'timeout_seconds':seconds,
             'returncode':None,'timed_out':False}
        report['outcomes'].append(row); save()
        print('Executing '+label,flush=True)
        with (output/(label+'.log')).open('x',encoding='utf-8') as stream:
            status,timed_out=bounded_process(row['command'],cwd=ROOT,stdout=stream,timeout=seconds)
        row.update(returncode=status,timed_out=timed_out); save()
        return status==0 and not timed_out
    def qualify(label,selected,focus,thread='safe',lookahead=0,extra=()):
        return run(label,[HERE/'run_qualification.py','--source',ROOT,'--runtime',inputs/'runtime/C',
            '--engine',selected,'--output',output/label,'--focus',focus,
            '--render-thread',thread,'--lookahead',lookahead,*extra,*display])
    save()
    frozen=qualify('stock-frozen-correctness',engine,'frozen')
    # A failed new fixture does not conceal the already executed frozen gates.
    water=qualify('stock-water-correctness',engine,'water') if frozen else False
    if not frozen: report['unexecuted'].append({'gate':'stock-water-correctness','reason':'Frozen correctness failed'})
    if request['phase']=='integration' and windows:
        need('engine' in restore,'Atomic integration has no independently admitted engine')
        pin=request['engine_artifact']
        root=inputs/'engine'
        custom=root/restore['engine']['build']['gui_executable']
        exact=['--engine-payload',root,'--engine-build-source',pin['source'],
            '--engine-build-run',pin['run'],'--engine-build-attempt',pin['attempt'],
            '--engine-proof-sha256',pin['proof_sha256']]
        if frozen and water:
            # The complete inherited inventory remains Safe. Separate ownership
            # is exercised by dedicated actual-submission/Water/history gates.
            new_frozen=qualify('atomic-frozen-correctness',custom,'frozen',extra=exact)
            if new_frozen:
                for thread,budget in (('safe',0),('separate',0),('separate',4)):
                    qualify(f'atomic-submission-{thread}-{budget}',custom,'submission',thread,budget,exact)
                for budget in (0,4):
                    qualify(f'atomic-water-separate-{budget}',custom,'water','separate',budget,exact)
                run('atomic-font-and-first-read',[HERE/'run_graphical_controls.py','--source',ROOT,
                    '--runtime',inputs/'runtime/C','--stock-engine',engine,'--output',output/'atomic-font-and-first-read',*exact],3600)
            else: report['unexecuted'].append({'gate':'atomic application integration','reason':'New-engine frozen correctness failed'})
        else: report['unexecuted'].append({'gate':'atomic application integration','reason':'Stock correctness failed'})
    report['complete']=not report['unexecuted'] and all(row['returncode']==0 and not row['timed_out'] for row in report['outcomes'])
    save()
    print(json.dumps({'complete':report['complete'],'outcomes':len(report['outcomes']),
                      'unexecuted':report['unexecuted'],'physical_acceptance':'HOLD'}))
    return 0 if report['complete'] else 1

if __name__=='__main__': sys.exit(main())
