"""Source-pinned cut latency and carried-material qualification; no native rebuild."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import workbench_brush_cut as b

p=b.p;f=b.f
f.OUT=p.ROOT/'build/workbench-cut-feedback'
f.PROFILE='native/tests/fixtures/workbench_cut_responsiveness_001.json'
f.PARENT='2253eb2dd2e22f5dacb30cedd37084600e776656'
base_identity=b.identity

def identity():
    return dict(**base_identity(),feedback_runner_sha256=p.sha(__file__),
        tests={n:p.sha(p.ROOT/'godot/tests'/n) for n in ['test_workbench_cut_responsiveness.gd','test_workbench_carried_material_render.gd']})
b.identity=identity;f.identity=identity

def reuse():
    folder=f.OUT/'unchanged-runtimes';folder.mkdir(exist_ok=True)
    prior=p.ROOT/'build/workbench-small-debris/runtimes-001/receipt.json'
    receipt=json.loads(prior.read_text())
    assert receipt['identity']['source_inputs']==identity()['source_inputs']
    assert receipt['identity']['material_inputs']==identity()['material_inputs']
    for row in receipt['platforms'].values(): assert p.sha(p.ROOT/row['output'])==row['sha256']
    p.write(folder/'receipt.json',receipt)

def baseline(run):
    info=identity();folder=f.OUT/run;assert not folder.exists();folder.mkdir()
    prior=p.ROOT/'build/workbench-small-debris/hosts-001'
    cohort=json.loads((prior/'receipt.json').read_text())
    result=dict(identity=info,baseline=f.PARENT,baseline_receipt_sha256=p.sha(prior/'receipt.json'),hosts={})
    for platform in p.BINARIES:
        f.resource(256*1024**2)
        target=folder/platform;project=target/'godot'
        shutil.copytree(prior/platform/'godot',project,ignore=shutil.ignore_patterns('.godot'))
        for name,digest in cohort['hosts'][platform]['project_files'].items(): assert p.sha(project/name)==digest,name
        shutil.copyfile(p.ROOT/'godot/tests/test_workbench_cut_responsiveness.gd',project/'tests/test_workbench_cut_responsiveness.gd')
        rows=[];result['hosts'][platform]=dict(commands=rows,runtime_sha256=cohort['hosts'][platform]['runtime_sha256'])
        for worker in [1,4]:
            report=target/f'baseline-w{worker}.json'
            values=dict(CYBERSAND_FREED_WORKERS=str(worker),CYBERSAND_CUT_BASELINE='1',CYBERSAND_FREED_REPORT=str(report) if platform=='windows' else p.wsl(report))
            args=[p.ENGINES[platform],'--headless','--path',str(project) if platform=='windows' else p.wsl(project),'--script','res://tests/test_workbench_cut_responsiveness.gd']
            if platform=='linux':args=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in values.items()],*args]
            row=p.command(f'baseline-w{worker}',args,target,dict(os.environ,**values),timeout=600);rows.append(row)
            row['report_complete']=False
            if report.exists():
                data=json.loads(report.read_text());row['report_complete']=not data['failures'] and len(data['evidence']['cuts'])==10
                row['report']=dict(path=str(report.relative_to(p.ROOT)),sha256=p.sha(report),checks=data['checks'])
            p.write(folder/'receipt.json',result)
    result['post_source_equality']=info==identity();result['resource_after']=f.resource();p.write(folder/'receipt.json',result)
    return int(not result['post_source_equality'] or not all(c['clean'] and c['report_complete'] for h in result['hosts'].values() for c in h['commands']))

def graphics(run,cohort):
    info=identity();folder=f.OUT/run;assert not folder.exists();folder.mkdir()
    receipt=dict(identity=info,hosts={})
    for platform in p.BINARIES:
        project=f.OUT/cohort/platform/'godot';target=folder/platform;target.mkdir()
        captures=target/'captures';captures.mkdir()
        commands=[];receipt['hosts'][platform]=dict(commands=commands)
        for script in ['test_workbench_carried_material_render','test_material_presentation_render','test_palette_shader_compile_bounds','test_material_appearance_lut']:
            values=dict(CYBERSAND_SOURCE_REVISION=info['source_commit'],CYBERSAND_SHADER_CAPTURE=str(captures) if platform=='windows' else p.wsl(captures))
            args=[p.ENGINES[platform],'--path',str(project) if platform=='windows' else p.wsl(project),'--rendering-method','gl_compatibility','--script','res://tests/'+script+'.gd']
            if platform=='linux':args=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in values.items()],*args]
            commands.append(p.command(script,args,target,dict(os.environ,**values),timeout=300))
            p.write(folder/'receipt.json',receipt)
    receipt['post_source_equality']=info==identity();receipt['resource_after']=f.resource();p.write(folder/'receipt.json',receipt)
    return int(not receipt['post_source_equality'] or not all(c['clean'] for h in receipt['hosts'].values() for c in h['commands']))

if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('mode',choices=['baseline','hosts','graphics']);parser.add_argument('--run',required=True);parser.add_argument('--cohort',default='hosts-001');a=parser.parse_args()
    assert Path(a.run).name==a.run
    f.resource(256*1024**2)
    if a.mode=='baseline':sys.exit(baseline(a.run))
    if a.mode=='graphics':sys.exit(graphics(a.run,a.cohort))
    reuse()
    sys.exit(b.hosts(a.run,'unchanged-runtimes',['test_workbench_cut_responsiveness','test_workbench_small_debris','test_workbench_brush_cuts','test_workbench_freed']))
