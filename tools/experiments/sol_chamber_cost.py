#!/usr/bin/env python3
"""Fresh-session registered observer comparison; unchanged native production."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import sol_chamber_campaign as parent

ROOT=parent.ROOT;c=parent.c;p=parent.p
PROFILE="godot/tests/fixtures/sol_chamber/cost-001.json"

def ambient():
    start=time.monotonic()
    commands=[['powershell.exe','-NoProfile','-Command',"Get-Process | Where-Object {$_.ProcessName -match 'Godot|cc1plus|cmake|ninja|cl$'} | Select-Object Id,ProcessName,CPU | ConvertTo-Json -Compress"],
        ['wsl.exe','-d','Ubuntu-24.04','--','ps','-eo','pid,comm,pcpu,pmem']]
    results=[]
    for argv in commands:
        completed=subprocess.run(argv,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
        value=completed.stdout.decode('utf-8',errors='replace')
        if argv[0]=='wsl.exe':value='\n'.join(line for line in value.splitlines() if any(s in line.lower() for s in ['godot','cc1plus','cmake','ninja','g++']))
        results.append(dict(command=argv,exit=completed.returncode,output=value))
    return dict(qualification="shared-host; not isolated scaling",seconds=time.monotonic()-start,results=results)

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("--run",required=True)
    parser.add_argument("--platforms",default="windows,linux");parser.add_argument("--repeats",type=int,default=3)
    parser.add_argument("--workers",default="1,4");parser.add_argument("--cases",default="closed-unforced,closed-driven")
    args=parser.parse_args();assert Path(args.run).name==args.run and args.run not in ['.','..']
    started=time.monotonic();assert not c.git('status','--porcelain'),"Commit source before execution"
    info=c.identity();profile=json.loads((ROOT/PROFILE).read_text(encoding='utf-8'))
    if 'windows' in args.platforms.split(','):
        pin=info['runtimes']['windows']['retained_native']
        assert info['runtimes']['windows']['engine']['launcher_sha256']==pin['godot_validation_executable_sha256']
    base=ROOT/profile['base_profile'];assert p.sha(base.read_bytes())==profile['base_profile_sha256']
    platforms=args.platforms.split(',');workers=list(map(int,args.workers.split(',')));cases=args.cases.split(',')
    assert set(platforms)<=set(profile['platforms']) and set(workers)<=set(profile['workers']) and set(cases)<=set(profile['cases']) and 0<args.repeats<=3
    folder=ROOT/'build/sol-response-cost'/args.run;assert not folder.exists();folder.mkdir(parents=True)
    receipt=dict(identity=info,profile=profile,matrix=dict(platforms=platforms,workers=workers,cases=cases,repeats=args.repeats,observers=profile['observers']),results=[],effective_inputs={},ambient_start=ambient())
    def save():p.write(folder/'receipt.json',receipt)
    save()
    for platform in platforms:
        host=folder/platform;project=host/'godot'
        copy_start=time.monotonic()
        for name in info['copied_inputs']:
            target=project/Path(name).relative_to('godot');target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
        binary='cybersand_native.windows.x86_64.dll' if platform=='windows' else 'libcybersand_native.linux.x86_64.so'
        shutil.copyfile(ROOT/'build/la-physical/runtimes'/binary,project/'addons/cybersand_native/bin'/binary)
        inventory={f.relative_to(project).as_posix():p.sha(f.read_bytes()) for f in project.rglob('*') if f.is_file()}
        receipt['effective_inputs'][platform]=inventory;receipt.setdefault('copy_and_inventory_seconds',{})[platform]=time.monotonic()-copy_start;save()
        def run(name,output=None,environment=None):
            values=dict(CYBERSAND_SOURCE_REVISION=info['source'],**(environment or {}))
            argv=[p.ENGINES[platform],'--headless','--audio-driver','Dummy','--path',str(project) if platform=='windows' else p.wsl_path(project)]
            argv+=['--max-fps','120','--script','res://tests/support/sol_chamber_cost.gd'] if output else ['--editor','--import','--quit']
            if platform=='linux':argv=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in values.items()],*argv]
            row=p.command(name,argv,host,dict(os.environ,**values),timeout=180 if output else 240);row['platform']=platform;row['kind']='episode' if output else 'import';receipt['results'].append(row);save()
            if output:
                reports=list(output.glob('*.json'));row['reports']=[dict(path=f.relative_to(ROOT).as_posix(),sha256=p.sha(f.read_bytes())) for f in reports]
                row['report_validation']='PENDING';save()
                if row['clean']:
                    try:
                        assert len(reports)==1,'Missing episode'
                        data=json.loads(reports[0].read_text(encoding='utf-8'))
                        assert data['source']==info['source'] and data['registration']==profile['id'] and len(data['steps'])==180 and not data['failures']
                        row['report_validation']='PASS'
                    except Exception as error:
                        row['report_validation']=dict(status='FAIL',error=type(error).__name__+': '+str(error));save();raise
                else:row['report_validation']='UNAVAILABLE; failed process retained'
            save();return row
        imported=run('import')
        if not imported['clean']:continue
        for repeat in range(args.repeats):
            for worker in workers:
                for case in cases:
                    for observer in profile['observer_order_by_repeat'][repeat]:
                        name=f'{case}-{observer}-w{worker}-r{repeat}';output=host/'observations'/name
                        env=dict(SOL_CHAMBER_OUTPUT=str(output) if platform=='windows' else p.wsl_path(output),SOL_CHAMBER_CASE=case,SOL_CHAMBER_ARM='LA-SELECTIVE',SOL_CHAMBER_WORKERS=str(worker),SOL_CHAMBER_REPEAT=str(repeat),SOL_CHAMBER_OBSERVER=observer)
                        run(name,output,env)
        changes=[]
        for name,digest in inventory.items():
            current=project/name
            if p.sha(current.read_bytes())==digest:continue
            original=ROOT/'godot'/name
            if name.endswith('.import') and current.read_bytes().replace(b'\r\n',b'\n')==original.read_bytes().replace(b'\r\n',b'\n'):continue
            changes.append(name)
        receipt.setdefault('post_checks',{})[platform]=dict(unexpected_changes=changes);save();assert not changes
    receipt['ambient_end']=ambient()
    expected=len(platforms)*len(workers)*len(cases)*args.repeats*2
    receipt['expected_episodes']=expected
    receipt['complete_requested_process_matrix']=sum(row['kind']=='episode' for row in receipt['results'])==expected
    assert info['source']==c.git('rev-parse','HEAD').decode().strip() and info['copied_inputs']==c.identity()['copied_inputs'] and not c.git('status','--porcelain')
    receipt['campaign_elapsed_seconds']=time.monotonic()-started;save()
    return int(not receipt['complete_requested_process_matrix'] or not all(row['clean'] for row in receipt['results']))

if __name__=='__main__':raise SystemExit(main())
