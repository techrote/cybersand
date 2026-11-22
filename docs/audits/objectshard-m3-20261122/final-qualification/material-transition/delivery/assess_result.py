"""Read retained CI evidence; never execute native code or change repository inputs."""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
COMMIT = '73018218092e79fbe935aa60890e33bd9f4859ac'
RUN = 45003383402
JOB = 137149569699

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

run = json.loads((OUT/'run-final.json').read_text())
jobs = json.loads((OUT/'jobs-final.json').read_text())['jobs']
assert run['id'] == RUN and run['head_sha'] == COMMIT
assert run['status'] == 'completed' and run['conclusion'] == 'success'
checkout = json.loads((OUT/'checkout-merge-commit.json').read_text())
source_inputs = json.loads((OUT/'source-inputs.json').read_text())
assert checkout['sha'] == 'bd8a9503507273c3348b2e711e6b3638860a9274'
assert checkout['tree']['sha'] == source_inputs['source_tree'] == 'ede95a3ad7102f4059f8b425167c7fa6c1948663'
assert [p['sha'] for p in checkout['parents']] == ['44abd754d014a44078a41792d2d46967a9b8cf30',COMMIT]
assert len(jobs) == 1 and jobs[0]['id'] == JOB
job = jobs[0]
assert job['status'] == 'completed' and job['conclusion'] == 'success'
assert all(s['status'] == 'completed' for s in job['steps'])
failed = [s for s in job['steps'] if s['conclusion'] not in ('success','skipped')]
assert not failed, failed
skipped = [s for s in job['steps'] if s['conclusion'] == 'skipped']
assert [(s['number'],s['name']) for s in skipped] == [(10,'Validate dependency pins and published runtime provenance')]

log_path = OUT/f'documentation-{RUN}-{JOB}.log'
lines = log_path.read_text(encoding='utf-8-sig').splitlines()
start = next(i for i,s in enumerate(lines) if '##[group]Run' in s and 'tools/material_catalogue/compatibility.py' in s)
command_end = next(i for i in range(start+1,len(lines)) if '##[endgroup]' in lines[i])
end = next(i for i in range(command_end+1,len(lines)) if '##[group]' in lines[i])
section = lines[start:end]
clean = '\n'.join(re.sub(r'\x1b\[[0-9;]*m','',re.sub(r'^\d{4}-\d\d-\d\dT[^ ]+ ', '',s)) for s in section)
tests = re.findall(r'^Ran (\d+) tests in ([0-9.]+)s$',clean,re.M)
assert len(tests) == 1 and re.search(r'^OK$',clean,re.M), tests
assert all(name in clean for name in ('compatibility.py --check','compiler.py --check',"discover -s tools/material_catalogue -p 'test_*.py'",'check_native_parity.py --output'))
objects=[]
decoder=json.JSONDecoder()
position=0
while True:
    match=re.search(r'(?:^|\n)\{',clean[position:])
    if match is None: break
    first=position+match.end()-1
    try:
        obj,last=decoder.raw_decode(clean,first)
    except ValueError:
        position=first+1
        continue
    objects.append(obj)
    position=last
assert len(objects)==2, [list(x) for x in objects]
guard, logged_parity=objects
assert guard['status']=='PASS' and guard['runtime_execution'] is False
assert logged_parity['schema_id']=='cybersand.material-catalogue.native-parity'
parity_paths=list(OUT.glob('*/native-parity.json'))
assert len(parity_paths)==1,parity_paths
parity_path=parity_paths[0]
parity=json.loads(parity_path.read_text())
assert parity==logged_parity
assert parity['status']=='PASS' and parity['protected_sources']==guard
assert parity['world_executed'] is False and parity['physics_qualification'] is False and parity['godot_executed'] is False
input_verification=[]
for fact in parity['tool_sources']+parity['inputs']:
    blob=subprocess.check_output(['git','-C',str(ROOT),'show',COMMIT+':'+fact['path']])
    assert len(blob)==fact['bytes'] and hashlib.sha256(blob).hexdigest()==fact['sha256'],fact
    input_verification.append(fact)
transition=guard['reviewed_transitions'][-1]
assert transition['path']=='native/src/world.cpp'
assert transition['from_lf_sha256']=='bc24ccd2e7457f61c75abdc13d20c2ccd82863fdf427f0c13ccaa1a05ad9d214'
assert transition['to_lf_sha256']=='5bb8ccded21bb73077ea86086d6fb25b9cbca67bda84013e67fa87d96b1c8cd1'
stamp=lambda line: datetime.datetime.fromisoformat(line.split(' ',1)[0].replace('Z','+00:00'))
stage_seconds=(stamp(section[-1])-stamp(section[0])).total_seconds()
(OUT/'catalogue-stage.log').write_text('\n'.join(section)+'\n')
(OUT/'compatibility-receipt.json').write_text(json.dumps(guard,indent=2)+'\n')
summary={
 'schema':'objectshard-material-transition-delivery-assessment-v1',
 'source_commit':COMMIT,'run_id':RUN,'job_id':JOB,'run_attempt':run['run_attempt'],
 'actual_ci_checkout_commit':checkout['sha'],'actual_ci_checkout_tree':checkout['tree']['sha'],
 'ci_checkout_tree_equals_published_transition_tree':True,
 'ci_conclusion':run['conclusion'],'run_event':run['event'],
 'catalogue_tests':int(tests[0][0]),'catalogue_test_seconds':float(tests[0][1]),
 'catalogue_stage_observed_seconds':stage_seconds,
 'catalogue_commands_all_reached':True,'compatibility_status':guard['status'],
 'compiler_check_scope':'Read-only generated shadow drift check; success established by same fail-fast shell reaching subsequent tests/parity and completing step16.',
 'reviewed_transition':transition,'protected_source_count':guard['protected_sources'],
 'metadata_native_parity_status':parity['status'],'metadata':parity['metadata'],
 'metadata_parity_costs':parity['measured_tool_costs'],'compiled_queries':parity['compiled_queries'],
 'metadata_parity_snapshot_sha256':parity['snapshot_sha256'],
 'parity_tool_and_input_facts_verified_against_commit':input_verification,
 'parity_receipt_source_commit_field_scope':'Historical compatibility baseline; actual new checkout/source custody is bound by GitHub head_sha, input hashes and the appended reviewed transition.',
 'parity_scope':parity['scope'],'aggregate_world_scope':'Nine native World tests each compile reference/candidate from current World and external generated adapters; no coordinator or Rapier execution in catalogue tests.',
 'skipped_steps':skipped,
 'production_provenance_condition':"github.event_name != 'pull_request' || github.event.pull_request.draft == false",
 'full_production_gate_passed':False,
 'qualified_executable_source_unchanged':'e034f2294663e0485cfb9adcc8ada46a6e977cee',
 'runtime_campaigns_dispatched':0,'reruns_dispatched':0,
 'log_path':str(log_path),'log_sha256':digest(log_path),
 'native_parity_path':str(parity_path),'native_parity_sha256':digest(parity_path),
 'success_does_not_establish':['Production retained native runtime provenance','Ordinary production-default ObjectShard adoption','Windows11/NVIDIA physical owner acceptance'],
}
(OUT/'delivery-assessment.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({key:summary[key] for key in ('source_commit','ci_conclusion','catalogue_tests','catalogue_test_seconds','catalogue_stage_observed_seconds','metadata_native_parity_status','full_production_gate_passed')}))
