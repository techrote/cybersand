"""Registered ordinary-workbench release qualification; retain every attempt."""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import structure_cut as p
import qualify_facade_refusal as facade

ROOT=p.ROOT
OUT=ROOT/'build/workbench-freed'
PARENT='f56795ba8acd6c3c4a2e7d9280b83083e48e1c81'
PROFILE='native/tests/fixtures/workbench_freed_001.json'

def resource(additional=0):
    registration=json.loads((ROOT/PROFILE).read_text())['resource']
    OUT.mkdir(parents=True,exist_ok=True)
    used=sum(x.stat().st_size for x in OUT.rglob('*') if x.is_file())
    free=shutil.disk_usage(OUT).free
    assert used+additional<=registration['cap_bytes'] and free-additional>=registration['minimum_free_bytes']
    return dict(bytes=used,free_bytes=free,**registration)

def identity():
    assert not p.git('status','--porcelain'),'Commit source before a qualified run'
    subprocess.run(['git','merge-base','--is-ancestor',PARENT,'HEAD'],cwd=ROOT,check=True)
    lock='materials/catalogue/compatibility-lock.json'
    assert (ROOT/lock).read_bytes()==p.git('show',PARENT+':'+lock)
    head=p.git('rev-parse','HEAD').decode().strip()
    protected=[lock,'tools/material_catalogue/compatibility.py']+[x['path'] for x in json.loads((ROOT/lock).read_text())['source_locks']]
    return dict(**facade.snapshot(ROOT,head),parent=PARENT,profile_sha256=p.sha(ROOT/PROFILE),
        material_inputs={n:p.sha(ROOT/n) for n in sorted(set(protected))},runner_sha256=p.sha(__file__))

def native(run):
    info=identity();folder=OUT/run;assert not folder.exists();folder.mkdir()
    result=dict(identity=info,resource_before=resource(),commands=[])
    def execute(name,args,env=None,timeout=900):
        row=p.command(name,args,folder,env,timeout);result['commands'].append(row);p.write(folder/'receipt.json',result)
        return row
    linux=['wsl.exe','-d','Ubuntu-24.04','--cd',p.wsl(ROOT),'--']
    core=['native/src/world.cpp','native/src/material_rules.cpp','native/src/scheduler_geometry.cpp','native/src/settled_world_discovery.cpp','native/src/render_snapshot.cpp','native/src/c_api.cpp']
    common=['g++','-std=c++20','-Wall','-Wextra','-Wpedantic','-Wconversion','-Wshadow','-Inative/include','-pthread']
    for mode in ['optimized','strict-asan-ubsan']:
        flags=['-O3','-DNDEBUG'] if mode=='optimized' else ['-O1','-g','-fno-omit-frame-pointer','-fsanitize=address,undefined']
        for suite in ['workbench_freed','solid_detachment']:
            resource(128*1024**2)
            binary=folder/(mode+'-'+suite)
            built=execute('build-'+binary.name,linux+common+flags+core+['native/tests/test_'+suite+'.cpp','-o',p.wsl(binary)])
            if built['clean']:
                execute('run-'+binary.name,linux+['env','ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1:halt_on_error=1','UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1',p.wsl(binary)],timeout=300)
                result.setdefault('binaries',{})[binary.name]=dict(sha256=p.sha(binary),bytes=binary.stat().st_size)
    result['resource_after']=resource();result['post_source_equality']=info==identity()
    p.write(folder/'receipt.json',result)
    return int(not result['post_source_equality'] or not all(x['clean'] for x in result['commands']))

def hosts(run,build_run):
    info=identity();build=json.loads((OUT/build_run/'receipt.json').read_text())
    assert build['post_source_equality'] and build['identity']['source_inputs']==info['source_inputs']
    folder=OUT/run;assert not folder.exists();folder.mkdir()
    receipt=dict(identity=info,build_receipt_sha256=p.sha(OUT/build_run/'receipt.json'),resource_before=resource(),hosts={})
    def save():p.write(folder/'receipt.json',receipt)
    save()
    for platform in ['windows','linux']:
        resource(256*1024**2)
        target=folder/platform;target.mkdir();project=target/'godot'
        shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','*.uid'))
        binary=OUT/build['platforms'][platform]['output'].split('build/workbench-freed/')[-1]
        binary=ROOT/build['platforms'][platform]['output']
        assert p.sha(binary)==build['platforms'][platform]['sha256']
        shutil.copy2(binary,project/'addons/cybersand_native/bin'/p.BINARIES[platform])
        state=dict(runtime_sha256=p.sha(binary),commands=[],project_files={x.relative_to(project).as_posix():p.sha(x) for x in project.rglob('*') if x.is_file()})
        receipt['hosts'][platform]=state;save()
        def execute(name,script=None,extra=None,env=None):
            values=dict(env or {})
            path=str(project) if platform=='windows' else p.wsl(project)
            args=[p.ENGINES[platform],'--headless','--path',path]
            args+=['--editor','--quit'] if script is None else ['--script','res://tests/'+script+'.gd',*(extra or [])]
            if platform=='linux':args=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in values.items()],*args]
            row=p.command(name,args,target,dict(os.environ,**values),timeout=300)
            state['commands'].append(row);save();return row
        if platform=='windows':state['engine_sha256']=p.sha(p.ENGINES[platform].replace('_console.exe','.exe'))
        else:
            row=p.command('engine-hash',['wsl.exe','-d','Ubuntu-24.04','--','sha256sum',p.ENGINES[platform]],target)
            state['commands'].append(row);state['engine_sha256']=(ROOT/row['log']).read_text().split()[0]
        imported=execute('import')
        if imported['clean']:
            for worker in [1,4]:
                output=target/f'freed-w{worker}.json'
                row=execute(f'freed-w{worker}','test_workbench_freed',env=dict(CYBERSAND_FREED_WORKERS=str(worker),CYBERSAND_FREED_REPORT=str(output) if platform=='windows' else p.wsl(output)))
                row['report_complete']=False
                if output.exists():
                    data=json.loads(output.read_text());row['report_complete']=not data['failures'] and len(data['evidence']['cuts'])==2
                    row['report']=dict(path=str(output.relative_to(ROOT)),sha256=p.sha(output),checks=data['checks'])
                save()
            for script in ['test_workbench_cut_lifecycle','test_workbench_canvas_body','test_workbench_fleet_session','test_workbench_canvas','test_workbench_pilot_ui','test_workbench_input']:
                execute(script,script)
        save();resource()
    receipt['post_source_equality']=info==identity();receipt['resource_after']=resource();save()
    return int(not receipt['post_source_equality'] or not all(c['clean'] and c.get('report_complete',True) for h in receipt['hosts'].values() for c in h['commands']))

def observe(run,reuse):
    info=identity();previous=OUT/reuse;cohort=json.loads((previous/'receipt.json').read_text())
    assert cohort['post_source_equality'] and cohort['identity']['source_inputs']==info['source_inputs']
    resource(16*1024**2)
    folder=OUT/run;assert not folder.exists();folder.mkdir()
    receipt=dict(identity=info,reused_receipt_sha256=p.sha(previous/'receipt.json'),scope='New external value observer; unchanged immutable production project inputs, fresh process/World/session per run. No duplicate project copies within the registered cap.',hosts={})
    script=ROOT/'godot/tests/test_workbench_freed.gd'
    for platform in ['windows','linux']:
        host=previous/platform;project=host/'godot'
        # Import records and caches are generated; all runtime/source/resources
        # used by the previous cohort must still be byte-identical.
        inputs={n:d for n,d in cohort['hosts'][platform]['project_files'].items() if not n.endswith(('.import','.uid'))}
        assert all(p.sha(project/n)==d for n,d in inputs.items())
        target=folder/platform;target.mkdir();rows=[];receipt['hosts'][platform]=dict(commands=rows,project_inputs_equal=True)
        for worker in [1,4]:
            output=target/f'freed-w{worker}.json'
            values=dict(CYBERSAND_FREED_WORKERS=str(worker),CYBERSAND_FREED_REPORT=str(output) if platform=='windows' else p.wsl(output))
            args=[p.ENGINES[platform],'--headless','--path',str(project) if platform=='windows' else p.wsl(project),'--script',str(script) if platform=='windows' else p.wsl(script)]
            if platform=='linux':args=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in values.items()],*args]
            row=p.command(f'freed-w{worker}',args,target,dict(os.environ,**values),timeout=300);rows.append(row)
            row['report_complete']=False
            if output.exists():
                data=json.loads(output.read_text());row['report_complete']=not data['failures'] and len(data['evidence']['cuts'])==2 and len(data['evidence']['refused_strokes'])==3
                row['report']=dict(path=str(output.relative_to(ROOT)),sha256=p.sha(output),checks=data['checks'])
            p.write(folder/'receipt.json',receipt)
        assert all(p.sha(project/n)==d for n,d in inputs.items())
    receipt['post_source_equality']=info==identity();receipt['resource_after']=resource();p.write(folder/'receipt.json',receipt)
    return int(not receipt['post_source_equality'] or not all(c['clean'] and c['report_complete'] for h in receipt['hosts'].values() for c in h['commands']))

if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('mode',choices=['build','native','hosts','observe']);parser.add_argument('--run',required=True);parser.add_argument('--build-run',default='runtimes-001');parser.add_argument('--reuse-run',default='hosts-005');a=parser.parse_args()
    assert Path(a.run).name==a.run
    resource(16*1024**2 if a.mode=='observe' else 256*1024**2)
    if a.mode=='observe':sys.exit(observe(a.run,a.reuse_run))
    if a.mode=='build':p.OUT=OUT;p.identity=identity;sys.exit(p.build(a.run))
    sys.exit(native(a.run) if a.mode=='native' else hosts(a.run,a.build_run))
