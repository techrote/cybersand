"""Registered circular-brush cutting regression; retain every attempt."""
import argparse
import json
import os
import shutil
import sys
from pathlib import Path
import workbench_freed as f

p=f.p
f.OUT=p.ROOT/'build/workbench-brush-cuts'
f.PROFILE='native/tests/fixtures/workbench_brush_cut_001.json'
original_identity=f.identity
def identity():
    return dict(**original_identity(),campaign_runner_sha256=p.sha(__file__))
f.identity=identity

def hosts(run,build_run):
    info=identity();folder=f.OUT/run
    assert not folder.exists();folder.mkdir()
    build=json.loads((f.OUT/build_run/'receipt.json').read_text())
    assert build['post_source_equality'] and build['identity']['source_inputs']==info['source_inputs']
    assert build['identity']['material_inputs']==info['material_inputs']
    receipt=dict(identity=info,build_receipt_sha256=p.sha(f.OUT/build_run/'receipt.json'),resource_before=f.resource(),hosts={})
    def save():p.write(folder/'receipt.json',receipt)
    for platform in p.BINARIES:
        f.resource(256*1024**2)
        target=folder/platform;target.mkdir();project=target/'godot'
        rapier=json.loads((p.ROOT/f'godot/addons/godot-rapier2d/runtime-provenance.{platform}.json').read_text())
        assert p.sha(p.ROOT/rapier['artifact'])==rapier['sha256']
        for name,digest in rapier['source_inputs'].items():assert p.lfsha(p.ROOT/name)==digest
        selected={rapier['artifact'],'godot/addons/cybersand_native/bin/'+p.BINARIES[platform]}
        for name in p.git('ls-files','godot').decode().splitlines():
            if '/bin/' in name and name not in selected:continue
            dst=project/Path(name).relative_to('godot');dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p.ROOT/name,dst)
        binary=p.ROOT/build['platforms'][platform]['output']
        assert p.sha(binary)==build['platforms'][platform]['sha256']
        shutil.copyfile(binary,project/'addons/cybersand_native/bin'/p.BINARIES[platform])
        state=dict(runtime_sha256=p.sha(binary),rapier_sha256=rapier['sha256'],project_files={str(x.relative_to(project)):p.sha(x) for x in project.rglob('*') if x.is_file()},commands=[])
        receipt['hosts'][platform]=state;save()
        def execute(name,script=None,env=None):
            values=dict(env or {});path=str(project) if platform=='windows' else p.wsl(project)
            args=[p.ENGINES[platform],'--headless','--path',path]
            args+=['--editor','--quit'] if script is None else ['--script','res://tests/'+script+'.gd']
            if platform=='linux':args=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in values.items()],*args]
            row=p.command(name,args,target,dict(os.environ,**values),timeout=300)
            state['commands'].append(row);save();return row
        if execute('import')['clean']:
            for worker in [1,4]:
                for script in ['test_workbench_brush_cuts','test_workbench_freed']:
                    output=target/f'{script}-w{worker}.json'
                    row=execute(f'{script}-w{worker}',script,dict(CYBERSAND_FREED_WORKERS=str(worker),CYBERSAND_FREED_REPORT=str(output) if platform=='windows' else p.wsl(output)))
                    row['report_complete']=False
                    if output.exists():
                        data=json.loads(output.read_text());row['report_complete']=not data['failures']
                        row['report']=dict(path=str(output.relative_to(p.ROOT)),sha256=p.sha(output),checks=data['checks'])
                    save()
            for script in ['test_workbench_cut_lifecycle','test_workbench_canvas_body','test_workbench_fleet_session','test_workbench_canvas','test_workbench_pilot_ui','test_workbench_input']:
                execute(script,script)
        save();f.resource()
    receipt['post_source_equality']=info==identity();receipt['resource_after']=f.resource();save()
    return int(not receipt['post_source_equality'] or not all(c['clean'] and c.get('report_complete',True) for h in receipt['hosts'].values() for c in h['commands']))

def observe(run,reuse):
    info=identity();prior=f.OUT/reuse;cohort=json.loads((prior/'receipt.json').read_text())
    assert cohort['post_source_equality'] and cohort['identity']['source_inputs']==info['source_inputs']
    assert cohort['identity']['material_inputs']==info['material_inputs']
    folder=f.OUT/run;assert not folder.exists();folder.mkdir()
    script=p.ROOT/'godot/tests/test_workbench_brush_cuts.gd'
    receipt=dict(identity=info,script_sha256=p.sha(script),reused_receipt_sha256=p.sha(prior/'receipt.json'),scope='Corrected external observer; byte-identical production project/runtime, fresh process/World/session. Earlier test-fixture failures are retained.',hosts={})
    for platform in p.BINARIES:
        project=prior/platform/'godot';target=folder/platform;target.mkdir();rows=[]
        inputs={n:d for n,d in cohort['hosts'][platform]['project_files'].items() if not n.endswith(('.import','.uid'))}
        assert all(p.sha(project/n)==d for n,d in inputs.items())
        # Every production script/resource must still match this source. The
        # candidate native artifact was overridden explicitly in the cohort.
        for name,digest in inputs.items():
            normalized=name.replace('\\','/')
            if not normalized.startswith('tests/') and '/bin/' not in normalized:
                assert p.sha(p.ROOT/'godot'/normalized)==digest,normalized
        receipt['hosts'][platform]=dict(commands=rows,unchanged_project_inputs=len(inputs),runtime_sha256=cohort['hosts'][platform]['runtime_sha256'])
        for worker in [1,4]:
            output=target/f'brush-w{worker}.json'
            values=dict(CYBERSAND_FREED_WORKERS=str(worker),CYBERSAND_FREED_REPORT=str(output) if platform=='windows' else p.wsl(output))
            args=[p.ENGINES[platform],'--headless','--path',str(project) if platform=='windows' else p.wsl(project),'--script',str(script) if platform=='windows' else p.wsl(script)]
            if platform=='linux':args=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in values.items()],*args]
            row=p.command(f'brush-w{worker}',args,target,dict(os.environ,**values),timeout=300);rows.append(row)
            row['report_complete']=False
            if output.exists():
                data=json.loads(output.read_text());row['report_complete']=not data['failures'] and len(data['evidence']['cuts'])==6
                row['report']=dict(path=str(output.relative_to(p.ROOT)),sha256=p.sha(output),checks=data['checks'])
            p.write(folder/'receipt.json',receipt)
        assert all(p.sha(project/n)==d for n,d in inputs.items())
    receipt['post_source_equality']=info==identity();receipt['resource_after']=f.resource();p.write(folder/'receipt.json',receipt)
    return int(not receipt['post_source_equality'] or not all(c['clean'] and c['report_complete'] for h in receipt['hosts'].values() for c in h['commands']))

if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('mode',choices=['build','native','hosts','observe']);parser.add_argument('--run',required=True);parser.add_argument('--build-run',default='runtimes-001');parser.add_argument('--reuse-run',default='hosts-001');a=parser.parse_args()
    assert Path(a.run).name==a.run
    f.resource(256*1024**2)
    if a.mode=='observe':sys.exit(observe(a.run,a.reuse_run))
    if a.mode=='build':p.OUT=f.OUT;p.identity=identity;sys.exit(p.build(a.run))
    sys.exit(f.native(a.run) if a.mode=='native' else hosts(a.run,a.build_run))
