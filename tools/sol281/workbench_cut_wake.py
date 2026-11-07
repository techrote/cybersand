"""Registered cut wake/prefetch follow-up; preserve the prior cohort and failures."""
import argparse
import json
import os
from pathlib import Path
import sys
import workbench_cut_hitch as h

p=h.p;b=h.b;f=h.f
f.OUT=p.ROOT/'build/workbench-cut-wake'
f.PROFILE='native/tests/fixtures/workbench_cut_wake_001.json'
f.PARENT='c7af580978fba3ae21229fda46e9dd89c39ad8e8'
previous_identity=h.identity

def identity():
    return dict(**previous_identity(),wake_runner_sha256=p.sha(__file__),
        live_observer_sha256=p.sha(p.ROOT/'godot/tests/test_workbench_cut_live_latency.gd'))
h.identity=identity;b.identity=identity;f.identity=identity

def live(run,cohort,baseline):
    info=identity();folder=f.OUT/run;assert not folder.exists();folder.mkdir()
    old=json.loads((cohort/'receipt.json').read_text())
    assert old['post_source_equality'] and old['identity']['source_inputs']==info['source_inputs']
    result=dict(identity=info,cohort_receipt_sha256=p.sha(cohort/'receipt.json'),
        scope='Fresh live Worlds; exact external observer on immutable qualified production project',baseline=baseline,hosts={})
    for platform in ['windows','linux']:
        project=cohort/platform/'godot';target=folder/platform;target.mkdir()
        state=old['hosts'][platform]
        for name,digest in state['project_files'].items():
            normalized=name.replace('\\','/')
            if not normalized.startswith(('tests/','.godot/')) and not name.endswith('.import'):
                assert p.sha(project/name)==digest,name
                assert p.sha(p.ROOT/'godot'/normalized)==digest,name
        report=target/'live-w1.json';script=p.ROOT/'godot/tests/test_workbench_cut_live_latency.gd'
        env=dict(CYBERSAND_FREED_WORKERS='1',CYBERSAND_FREED_REPORT=str(report) if platform=='windows' else p.wsl(report))
        args=[p.ENGINES[platform],'--headless','--path',str(project) if platform=='windows' else p.wsl(project),
            '--script',str(script) if platform=='windows' else p.wsl(script)]
        if platform=='linux':args=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in env.items()],*args]
        row=p.command('live-w1',args,target,dict(os.environ,**env),timeout=300)
        row['report_complete']=False
        if report.exists():
            data=json.loads(report.read_text());row['report_complete']=not data['failures'] and len(data['evidence']['cuts'])==10
            row['report']=dict(path=report.relative_to(p.ROOT).as_posix(),sha256=p.sha(report),checks=data['checks'])
        result['hosts'][platform]=dict(commands=[row],runtime_sha256=state['runtime_sha256'])
        p.write(folder/'receipt.json',result)
    result['post_source_equality']=info==identity();result['resource_after']=f.resource();p.write(folder/'receipt.json',result)
    return int(not result['post_source_equality'] or not all(c['clean'] and c['report_complete'] for v in result['hosts'].values() for c in v['commands']))

if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('mode',choices=['baseline-live','hosts','live'])
    parser.add_argument('--run',required=True);parser.add_argument('--cohort',default='hosts-001');a=parser.parse_args()
    assert Path(a.run).name==a.run;f.resource(128*1024**2)
    if a.mode=='baseline-live':sys.exit(live(a.run,p.ROOT/'build/workbench-cut-hitch/candidate-001',True))
    if a.mode=='live':sys.exit(live(a.run,f.OUT/a.cohort,False))
    h.reuse()
    sys.exit(b.hosts(a.run,'unchanged-runtimes',['test_workbench_cut_hitch','test_workbench_rectangle_core'],
        ['test_workbench_rectangle_core_lifecycle','test_workbench_cut_wakeup','test_workbench_cut_transport']))
