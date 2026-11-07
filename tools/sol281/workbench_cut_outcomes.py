"""Fresh authored post-cut representation comparison; no production law changes."""
import argparse
import json
import os
from pathlib import Path
import sys
import workbench_cut_hitch as h

p=h.p;f=h.f;b=h.b
f.OUT=p.ROOT/'build/workbench-cut-outcomes'
f.PROFILE='native/tests/fixtures/workbench_cut_outcomes_001.json'
f.PARENT='dc4fe60fbd503a7043c7e63934da44015bd849b3'
previous_identity=h.identity

def identity():
    return dict(**previous_identity(),outcome_runner_sha256=p.sha(__file__),
        outcome_test_sha256=p.sha(p.ROOT/'godot/tests/test_workbench_cut_outcomes.gd'))
h.identity=identity;f.identity=identity;b.identity=identity

def run(name):
    info=identity();folder=f.OUT/name;assert not folder.exists();folder.mkdir()
    cohort=p.ROOT/'build/workbench-cut-wake/hosts-001'
    old=json.loads((cohort/'receipt.json').read_text())
    assert old['post_source_equality'] and old['identity']['source_inputs']==info['source_inputs']
    assert old['identity']['material_inputs']==info['material_inputs']
    result=dict(identity=info,scope='External test-only authored states on unchanged source3ad15 production project and native artifacts',cohort_receipt_sha256=p.sha(cohort/'receipt.json'),hosts={})
    for platform,worker,spot in [('windows',1,False),('linux',1,True),('windows',4,True)]:
        f.resource(32*1024**2)
        key=platform+'-w'+str(worker);target=folder/key;target.mkdir();project=cohort/platform/'godot'
        for filename,digest in old['hosts'][platform]['project_files'].items():
            normalized=filename.replace('\\','/')
            if not normalized.startswith(('tests/','.godot/')) and not filename.endswith('.import'):
                assert p.sha(project/filename)==digest,filename
                assert p.sha(p.ROOT/'godot'/normalized)==digest,filename
        script=p.ROOT/'godot/tests/test_workbench_cut_outcomes.gd';output=target/'outcomes.json'
        env=dict(CYBERSAND_FREED_WORKERS=str(worker),CYBERSAND_OUTCOMES_SPOT='1' if spot else '0',CYBERSAND_FREED_REPORT=str(output) if platform=='windows' else p.wsl(output))
        args=[p.ENGINES[platform],'--headless','--path',str(project) if platform=='windows' else p.wsl(project),'--script',str(script) if platform=='windows' else p.wsl(script)]
        if platform=='linux':args=['wsl.exe','-d','Ubuntu-24.04','--','env',*[k+'='+v for k,v in env.items()],*args]
        row=p.command('outcomes',args,target,dict(os.environ,**env),timeout=1800)
        row['report_complete']=False
        if output.exists():
            data=json.loads(output.read_text());row['report_complete']=not data['failures'] and len(data['evidence']['cuts'])==(6 if spot else 60)
            row['report']=dict(path=output.relative_to(p.ROOT).as_posix(),sha256=p.sha(output),checks=data['checks'],episodes=len(data['evidence']['cuts']))
        result['hosts'][key]=dict(commands=[row],runtime_sha256=old['hosts'][platform]['runtime_sha256'],rapier_sha256=old['hosts'][platform]['rapier_sha256'],spot=spot)
        p.write(folder/'receipt.json',result)
    result['post_source_equality']=info==identity();result['resource_after']=f.resource();p.write(folder/'receipt.json',result)
    return int(not result['post_source_equality'] or not all(c['clean'] and c['report_complete'] for v in result['hosts'].values() for c in v['commands']))

if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('--run',required=True);a=parser.parse_args();assert Path(a.run).name==a.run
    f.resource(32*1024**2);sys.exit(run(a.run))
