#!/usr/bin/env python3
"""Actual Windows/Linux no-contact Rapier operator, no native World."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sol_node_trace_runtime as runtime
import la_selective_experiment as p

ROOT=runtime.ROOT
PROFILE='native/tests/fixtures/sol_gravity_operator_001.json'

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('--run',required=True);args=parser.parse_args()
    assert Path(args.run).name==args.run and args.run not in ['.','..'] and os.name=='nt'
    info=runtime.identity()
    assert (ROOT/PROFILE).read_bytes().replace(b'\r\n',b'\n')==p.git('show','19082e0b:'+PROFILE),'Frozen registration changed'
    folder=ROOT/'build/sol-gravity-operator'/args.run;assert not folder.exists();folder.mkdir(parents=True)
    profile=json.loads((ROOT/PROFILE).read_text(encoding='utf-8'))
    assert shutil.disk_usage(ROOT).free>=profile['resource']['minimum_free_bytes']
    copied={n:runtime.sha(ROOT/n) for n in p.git('ls-files','godot').decode().splitlines() if (ROOT/n).is_file()}
    receipt=dict(identity=info,registration=profile,profile_sha256=runtime.lfsha(ROOT/PROFILE),runner_sha256=runtime.lfsha(Path(__file__)),
        copied_inputs=copied,hosts={},qualification='Actual no-contact Rapier only. Native library loaded/source-equivalent, no native World or workers. Full-observer diagnostic, not CPU gate.')
    def save():p.write(folder/'receipt.json',receipt)
    save()
    for platform in ['windows','linux']:
        host=folder/platform;project=host/'godot';host.mkdir();rows=[]
        for name in copied:
            target=project/Path(name).relative_to('godot');target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
        shutil.copyfile(ROOT/PROFILE,project/'tests/fixtures/sol_gravity_operator_001.json')
        override=info['rebuild']['platforms'][platform]
        shutil.copyfile(ROOT/override['output'],project/'addons/cybersand_native/bin'/runtime.BINARIES[platform])
        inventory={f.relative_to(project).as_posix():runtime.sha(f) for f in project.rglob('*') if f.is_file()}
        native=json.loads((ROOT/('godot/addons/cybersand_native/runtime-provenance'+('.linux' if platform=='linux' else '')+'.json')).read_text(encoding='utf-8'))
        rapier=json.loads((ROOT/f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json').read_text(encoding='utf-8'))
        assert runtime.sha(ROOT/rapier['artifact'])==rapier['sha256']
        for name,digest in rapier['source_inputs'].items():assert runtime.lfsha(ROOT/name)==digest,name
        state=dict(commands=rows,effective_inputs=inventory,native_override=override,rapier=rapier);receipt['hosts'][platform]=state;save()
        def run(name,script=None,env=None,version=False):
            forwarded=dict(CYBERSAND_SOURCE_REVISION=info['source'],**(env or {}));argv=[p.ENGINES[platform]]
            if version:argv+=['--version']
            else:
                argv+=['--headless','--audio-driver','Dummy','--path',str(project) if platform=='windows' else p.wsl_path(project)]
                argv+=['--editor','--import','--quit'] if script is None else ['--max-fps','120','--script','res://tests/'+script+'.gd']
            if platform=='linux':argv=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in forwarded.items()],*argv]
            row=p.command(name,argv,host,dict(os.environ,**forwarded),timeout=300);rows.append(row);save();return row
        version=run('engine-version',version=True);assert version['clean']
        assert (ROOT/version['log']).read_text(encoding='utf-8').strip()==native['godot_version']
        if platform=='windows':
            launcher=runtime.sha(Path(p.ENGINES[platform]));engine=runtime.sha(Path(p.ENGINES[platform].replace('_console.exe','.exe')))
            assert launcher==native['godot_validation_executable_sha256']
        else:
            row=p.command('engine-hash',['wsl.exe','-d','Ubuntu-24.04','--','sha256sum',p.ENGINES[platform]],host);rows.append(row);assert row['clean']
            engine=(ROOT/row['log']).read_text(encoding='utf-8').split()[0];launcher=engine
        assert engine==native['godot_executable_sha256'];state['engine']=dict(sha256=engine,launcher_sha256=launcher,version=native['godot_version']);save()
        imported=run('import')
        if imported['clean']:
            output=host/'observations.json';run('gravity-operator','test_sol_gravity_operator',{'SOL_GRAVITY_OUTPUT':str(output) if platform=='windows' else p.wsl_path(output)})
            if output.is_file():state['observations']=dict(path=str(output.relative_to(ROOT)),sha256=runtime.sha(output),bytes=output.stat().st_size)
        changes=[];normalized=[]
        for name,digest in inventory.items():
            target=project/name
            if target.is_file() and runtime.sha(target)==digest:continue
            original=ROOT/'godot'/name
            if name.endswith('.import') and original.is_file() and target.is_file() and target.read_bytes().replace(b'\r\n',b'\n')==original.read_bytes().replace(b'\r\n',b'\n'):normalized.append(name)
            else:changes.append(name)
        state['post_inventory']=dict(unexpected_changes=changes,import_LF_normalization_only=normalized);save();assert not changes
        assert sum(f.stat().st_size for f in folder.rglob('*') if f.is_file())<=profile['resource']['new_artifact_cap_bytes']
    assert copied=={n:runtime.sha(ROOT/n) for n in copied}
    assert info==runtime.identity(),'Source/runtime changed during oracle'
    receipt['post_source_equality']=True;save()
    return int(not all(c['clean'] for h in receipt['hosts'].values() for c in h['commands']))

if __name__=='__main__':raise SystemExit(main())
