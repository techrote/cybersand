"""Audit exact final hosted receipts and raw science directly from original ZIPs."""
from pathlib import Path
import hashlib
import json
import math
import sys
import zipfile

ROOT=Path('/tmp/ambient-002/perception')
OUT=Path('/tmp/ambient-002/evidence/perception/hosted-a725/independent-audit')
FINAL=OUT.parent/'artifact.zip'
BASE=Path('/tmp/ambient-002/evidence/perception/hosted-83a/artifact.zip')
SOURCE='a7250e15495667b2fcf564cbed1eaa8dea217c45'
sys.path.insert(0,str(ROOT/'tools/ambient'))
import run_episodes as runner
import analyze_episodes as reducer
import review_episodes as independent

def sha(data): return hashlib.sha256(data).hexdigest()

def file_sha(path):
    with Path(path).open('rb') as stream: return stream_sha(stream)

def stream_sha(stream):
    h=hashlib.sha256()
    while True:
        part=stream.read(65536)
        if not part: return h.hexdigest()
        h.update(part)

def member_sha(archive,name):
    with archive.open(name) as stream: return stream_sha(stream)

def read(archive,name):
    with archive.open(name) as stream: return json.load(stream)

class CopiedConsole:
    def __init__(self,label,data): self.label=label; self.data=data
    def read_text(self,**_kwargs): return self.data.decode('utf-8',errors='replace')
    def __str__(self): return self.label

def reversals(row):
    result=0
    for before,after in zip(row['trace'],row['trace'][1:]):
        if (before['has_procedural_intent'] and after['has_procedural_intent']
                and before['intent_pace']>0 and after['intent_pace']>0
                and abs(before['intent_direction'][0])>.05
                and abs(after['intent_direction'][0])>.05
                and before['intent_direction'][0]*after['intent_direction'][0]<0):
            result+=1
    return result

assert file_sha(FINAL)=='eac23768f3b18dc95a35554328f700daa8a81fa9920bab39fa7148aca1958e30'
assert file_sha(BASE)=='996c30c61f2edc55cc51d6467652ceb5b128e4ac678809d35e1898214365a199'
OUT.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(FINAL) as z,zipfile.ZipFile(BASE) as baseline:
    receipt=read(z,'episodes-full/runner-receipt.json')
    custody=read(z,'episodes-full/custody.json')
    original_custody=json.loads(Path('/tmp/ambient-002/evidence/perception/native-thin-a725/attempt-001/custody-before.json').read_text())
    assert receipt['complete'] and receipt['campaigns']==122 and receipt['actual_actor_episodes']==194
    assert receipt['source_revision']==custody['source']['source_commit']==SOURCE
    assert receipt['source_tree']==custody['source']['source_tree']=='a038e6df65d58529f4c496c01f26c65975654fa6'
    for key in ('source','runtime','loaded_project_sha256','experiment_tools_sha256'):
        assert custody[key]==original_custody[key],key
    assert custody['engine']['sha256']==original_custody['engine']['sha256']==receipt['godot_sha256']
    assert not custody['source']['local_delta']
    assert receipt['custody_sha256']==member_sha(z,'episodes-full/custody.json')
    assert receipt['report_sha256']==member_sha(z,'episodes-full/episodes.json')
    assert receipt['runner_sha256']==file_sha(ROOT/'tools/ambient/run_episodes.py')
    assert receipt['analyzer_sha256']==file_sha(ROOT/'tools/ambient/analyze_episodes.py')
    registry_name='episodes-full/'+receipt['registry']
    registry=read(z,registry_name)
    prefix=registry_name.rsplit('/',1)[0]+'/'
    registry_receipt=read(z,prefix+'execution.json')
    assert receipt['registry_sha256']==member_sha(z,registry_name)
    assert receipt['registration_receipt_sha256']==member_sha(z,prefix+'execution.json')
    assert registry_receipt['console_sha256']==member_sha(z,prefix+'console.log')
    assert registry_receipt['report_sha256']==member_sha(z,registry_name)
    assert registry_receipt['custody_sha256']==receipt['custody_sha256']
    runner.check_terminal(CopiedConsole(prefix+'console.log',z.read(prefix+'console.log')),
                          registry,registry_receipt,'',SOURCE,'registry')
    aggregate=read(z,'episodes-full/episodes.json')
    rows=reducer.validate(aggregate,source_root=ROOT)
    assert aggregate['registration']==registry['registration']
    assert len(aggregate['shard_receipts'])==122
    campaigns={c['id']:c for c in aggregate['campaigns']}
    cases=[]
    for retained in aggregate['shard_receipts']:
        report_name='episodes-full/'+retained['report']
        execution_name='episodes-full/'+retained['execution_receipt']
        console_name='episodes-full/'+retained['console']
        assert retained['report_sha256']==member_sha(z,report_name)
        assert retained['execution_receipt_sha256']==member_sha(z,execution_name)
        assert retained['console_sha256']==member_sha(z,console_name)
        shard=read(z,report_name); execution=read(z,execution_name)
        assert execution['report_sha256']==retained['report_sha256']
        assert execution['console_sha256']==retained['console_sha256']
        assert execution['custody_sha256']==receipt['custody_sha256']
        current=shard['campaigns'][0]; cid=current['id']
        runner.check_terminal(CopiedConsole(console_name,z.read(console_name)),shard,execution,cid,SOURCE,'full')
        reducer.validate(shard,source_root=ROOT)
        assert current==campaigns[cid]
        original=read(baseline,report_name)['campaigns'][0]
        for key in ('id','initial_materials','initial_pose_sha256','geometry','model','seed','seconds','actor_count'):
            assert current[key]==original[key],(cid,key)
        actors=[]
        for final,old in zip(current['episodes'],original['episodes']):
            assert final['episode_id']==old['episode_id'] and final['profile']==old['profile']
            diffs=[math.dist(a['position'],b['position']) for a,b in zip(final['trace'],old['trace'])]
            actors.append({'episode_id':final['episode_id'],'model':final['model'],
                'position_samples':len(diffs),'exact_position_samples':sum(d==0 for d in diffs),
                'maximum_position_difference_cells':max(diffs),'exact_complete_trace':final['trace']==old['trace'],
                'baseline_heading_reversals':reversals(old),'final_heading_reversals':reversals(final),
                'baseline_failure_events':old['final_memory'].get('failure_events'),
                'final_failure_events':final['final_memory'].get('failure_events')})
        cases.append({'campaign_id':cid,'group':current['group'],'arm':current['arm'],
            'model':current['model'],'seed':current['seed'],'seconds':current['seconds'],
            'initial_materials_pose_geometry_and_authored_profiles_match':True,
            'final_original_report_sha256':retained['report_sha256'],
            'baseline_original_report_sha256':member_sha(baseline,report_name),'actors':actors})
    summary=reducer.summarize(aggregate,rows)
    summary['raw_report_sha256']=receipt['report_sha256']
    summary['analyzer_sha256']=receipt['analyzer_sha256']
    summary_bytes=(json.dumps(summary,indent=2)+'\n').encode()
    assert sha(summary_bytes)==member_sha(z,'analysis/summary.json')
    independently_checked=independent.audit(aggregate,summary)
    independently_checked['raw_report_sha256']=receipt['report_sha256']
    independently_checked['reducer_summary_sha256']=sha(summary_bytes)
    independently_checked['reviewer_sha256']=file_sha(ROOT/'tools/ambient/review_episodes.py')
    independent_bytes=(json.dumps(independently_checked,indent=2)+'\n').encode()
    assert sha(independent_bytes)==member_sha(z,'independent-review/independent-review.json')
    (OUT/'summary.json').write_bytes(summary_bytes)
    (OUT/'independent-review.json').write_bytes(independent_bytes)
    (OUT/'independent-review.md').write_text(independent.markdown(independently_checked))
    base_custody=read(baseline,'episodes-full/custody.json')
    project_changes=[{'path':p,'baseline_sha256':base_custody['loaded_project_sha256'].get(p),'final_sha256':digest}
        for p,digest in custody['loaded_project_sha256'].items() if base_custody['loaded_project_sha256'].get(p)!=digest]
    assert {v['path'] for v in project_changes}=={'scripts/ambient/ambient_stateful_modules.gd','tests/test_ambient_living_engine.gd'}
    result={'status':'PASS','source_revision':SOURCE,'source_tree':receipt['source_tree'],
        'artifact_id':14990266435,'artifact_sha256':file_sha(FINAL),
        'raw_report_sha256':receipt['report_sha256'],'summary_sha256':sha(summary_bytes),
        'independent_review_sha256':sha(independent_bytes),
        'runner_receipt_sha256':member_sha(z,'episodes-full/runner-receipt.json'),
        'source_inputs':len(custody['source']['source_inputs_sha256']),
        'loaded_project_inputs':len(custody['loaded_project_sha256']),
        'campaigns':122,'actor_episodes':len(rows),'subject_actor_episodes':summary['subject_actor_episodes'],
        'auxiliary_actor_episodes':summary['auxiliary_actor_episodes'],
        'world_simulation_seconds':sum(c['seconds'] for c in aggregate['campaigns']),
        'actor_simulation_seconds':sum(c['seconds']*c['actor_count'] for c in aggregate['campaigns']),
        'native_steps':sum(c['native_ticks'] for c in aggregate['campaigns']),
        'physical_steps':sum(c['physical_ticks'] for c in aggregate['campaigns']),
        'accepted_commands':sum(r['accepted_commands'] for c,r in rows),
        'rejected_commands':sum(r['rejected_commands'] for c,r in rows),
        'canvas_center_incidents':sum(r['canvas_center_incidents'] for c,r in rows),
        'independently_checked_metrics':independently_checked['independently_checked_episode_metrics'],
        'copied_peer_samples_checked':independently_checked['copied_peer_samples_checked'],
        'exact_ablation_groups':len(independently_checked['ablation_pairs']),
        'reduction_byte_identical_to_hosted':True,'independent_review_byte_identical_to_hosted':True,
        'loaded_project_changes_from_baseline':project_changes,'baseline_comparison_cases':cases,
        'auditor_sha256':file_sha(Path(__file__)),
        'limits':['Final and baseline are separate hosted executions, not extra independent treatment registrations.',
            'Only the two stated loaded application/test files differ; physics reexecution is not promised bit-identical.',
            'The prior source-bound same-host nine-case repair probe is the tighter causal repair comparison.',
            'All original consoles, reports and per-process execution receipts were verified directly inside the original ZIP.']}
    (OUT/'receipt-chain-and-science.json').write_text(json.dumps(result,indent=2)+'\n')
    figures=[]
    for item in z.infolist():
        if item.filename.startswith('analysis/') and item.filename.endswith('.png'):
            target=OUT/Path(item.filename).name
            target.write_bytes(z.read(item.filename))
            figures.append({'path':target.name,'sha256':file_sha(target),'bytes':target.stat().st_size})
    (OUT/'figures.json').write_text(json.dumps(figures,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in {'baseline_comparison_cases','limits'}},indent=2))
