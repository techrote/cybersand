#!/usr/bin/env python3
"""Replay genuine no-mutation SOL planner refusals; no native/Rapier instantiation."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import structure_cut as p

ROOT=p.ROOT
CANDIDATE='bbca191544f6a578ee14323c08d48021904893f7'
def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('--run',required=True);args=parser.parse_args();assert Path(args.run).name==args.run and args.run not in ['.','..']
    info=p.identity();folder=p.OUT/args.run;assert not folder.exists();folder.mkdir()
    baseline=p.OUT/'packed-001';receipt=json.loads((baseline/'receipt.json').read_text(encoding='utf-8'))
    assert receipt['post_source_equality'];cases=[];raw=[]
    for host,state in receipt['hosts'].items():
        for command in state['commands']:
            if 'report' not in command:continue
            assert command['clean'] and command['report_complete']
            path=ROOT/command['report']['path'];assert p.sha(path)==command['report']['sha256']
            data=json.loads(path.read_text(encoding='utf-8'));assert not data['failures'] and len(data['steps'])==360
            if not data['sand_response']:continue
            raw.append(command['report'])
            for row in data['steps']:
                response=row['response']
                if not row['response_is_new'] or response.get('outcome')!='NonDissipativeResponse':continue
                assert not response['accepted'] and response['impulses']==[] and response['impulse_apply_ms']==0 and response['readback_ms']==0
                cases.append(dict(id=f"{host}-{data['structure']}-w{data['workers']}-step{row['step']}",raw=command['report'],step=row['step'],
                    expected_outcome=response['outcome'],state_bits=row['after_application']['bits'],observation=row['contact_observation'],proxy_centres=data['proxy_centres'],proxy_sizes=data['proxy_sizes']))
    assert len(raw)==8 and cases
    inputs=folder/'inputs.json';p.write(inputs,dict(registration='SOL-STRUCTURE-ENERGY-REPLAY-001',cases=cases))
    control=(ROOT/'godot/scripts/solid_contact_response.gd').read_bytes()
    candidate=p.git('show',CANDIDATE+':godot/scripts/solid_contact_response.gd')
    probe=(ROOT/'tools/sol281/structure_energy_replay.gd').read_bytes()
    result=dict(identity=info,physical_receipt_sha256=p.sha(baseline/'receipt.json'),raw=raw,input_sha256=p.sha(inputs),cases=len(cases),
        candidate_source=CANDIDATE,control_sha256=p.sha(ROOT/'godot/scripts/solid_contact_response.gd'),candidate_sha256=p.hashlib.sha256(candidate).hexdigest(),hosts={},
        scope='Retrospective pure-planner diagnosis of genuine no-mutation refusals. No new physical episode, native World, Rapier body or workers; no force/geometry/threshold change.')
    for host in ['windows','linux']:
        target=folder/host;project=target/'godot';project.mkdir(parents=True)
        (project/'project.godot').write_bytes(b'config_version=5\n[application]\nconfig/name="SOL actual-refusal replay"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for name,data in [('control.gd',control),('candidate.gd',candidate),('probe.gd',probe)]:
            (project/name).write_bytes(data)
        inventory={f.name:p.sha(f) for f in project.iterdir()};rows=[]
        engine=p.ENGINES[host];output=target/'results.json'
        if host=='windows':
            assert p.sha(engine.replace('_console.exe','.exe'))==receipt['hosts'][host]['engine']['sha256']
            assert p.sha(engine)==receipt['hosts'][host]['engine']['launcher_sha256']
        else:
            row=p.command('engine-hash',['wsl.exe','-d','Ubuntu-24.04','--','sha256sum',engine],target);rows.append(row);assert row['clean']
            assert (ROOT/row['log']).read_text(encoding='utf-8').split()[0]==receipt['hosts'][host]['engine']['sha256']
        args=[engine,'--headless','--audio-driver','Dummy','--path',str(project) if host=='windows' else p.wsl(project),'--script','res://probe.gd']
        env=dict(p.os.environ,SOL_REPLAY_INPUT=str(inputs),SOL_REPLAY_OUTPUT=str(output))
        if host=='linux':args=['wsl.exe','-d','Ubuntu-24.04','--','env','SOL_REPLAY_INPUT='+p.wsl(inputs),'SOL_REPLAY_OUTPUT='+p.wsl(output),*args]
        row=p.command('replay',args,target,env,timeout=60);rows.append(row)
        record=dict(commands=rows,engine=receipt['hosts'][host]['engine'],copied_inputs=inventory,report=None)
        if output.is_file():record['report']=dict(path=str(output.relative_to(ROOT)),sha256=p.sha(output))
        assert inventory=={name:p.sha(project/name) for name in inventory}
        result['hosts'][host]=record;p.write(folder/'receipt.json',result)
    assert info==p.identity();result['post_source_equality']=True;p.write(folder/'receipt.json',result)
    print('cases',len(cases),flush=True)
    return int(not all(all(c['clean'] for c in h['commands']) and h['report'] for h in result['hosts'].values()))
if __name__=='__main__':raise SystemExit(main())
