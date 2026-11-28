from pathlib import Path
import hashlib,json,os,sys,subprocess
root=Path(__file__).resolve().parents[3];sys.path.insert(0,str(root/'tools/objectshard'))
import qualify_workbench as q
from process_resources import run_observed_case
base=Path(__file__).resolve().parent;out=base/'execution-portable';out.mkdir(exist_ok=False);user=out/'user-data';user.mkdir()
engine=Path('/home/agent/objectshard-recovery-20261125/shared-runtime/Godot_v4.7-stable_linux.x86_64')
fixture=root/'godot/tests/profile_object_shard_m4_disabled_control.gd';native=json.loads((base/'native-receipt.json').read_text())
source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip();tree=subprocess.check_output(['git','rev-parse','HEAD^{tree}'],cwd=root,text=True).strip()
inputs=q.committed_inputs();h=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert h(fixture)=='6fc42b178288ddc47c5f3801f1f46535904e54d9f55ba00a2ba8d8f8fb69c8ea'
assert all(h(root/p)==d for p,d in native['source']['source_inputs'].items())
assert all(h(root/p)==d for p,d in native['source']['build_contract_inputs'].items())
assert h(engine)=='f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75'
assert h(q.runner.runtime_paths()[0])==native['runtime']['sha256']
assert h(q.runner.runtime_paths()[1])=='566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a'
case=q.runner.Case('corrected_disabled_control',('--script','res://tests/profile_object_shard_m4_disabled_control.gd','--','--seconds=12','--output='+str(out/'control.json')),int(q.execution_policy.watchdog_seconds('ordinary_case_seconds')),0)
env=dict(os.environ,CYBERSAND_SOURCE_REVISION=source,XDG_DATA_HOME=str(user),APPDATA=str(user),LOCALAPPDATA=str(user));env.pop('CYBERSAND_PACKAGE_MANIFEST',None)
r={'schema':'objectshard-m4-disabled-pause-correction-v1','source_commit':source,'source_tree':tree,'fixture_sha256':h(fixture),'runner_sha256':h(__file__),'native_build_source':native['source']['source_commit'],'native_receipt_sha256':h(base/'native-receipt.json'),'engine_sha256':h(engine),'native_sha256':h(q.runner.runtime_paths()[0]),'rapier_sha256':h(q.runner.runtime_paths()[1]),'execution_inputs':inputs,'bootstrap_restoration_sha256':h(base/'bootstrap-restoration.json'),'prior_interrupted_attempt':'NOT PASS: pre-restart external run outcome unavailable; this is a separate exact committed-source execution','status':'running'}
q.save(out/'replay.json',r)
row,failed=run_observed_case(q.runner,str(engine),case,out,'objectshard-m4-recovery-disabled-pause',env=env);r['case']=row
if (out/'control.json').exists():
 receipt=json.loads((out/'control.json').read_text());r['receipt_sha256']=h(out/'control.json');r['checks']=receipt['checks'];r['failures']=receipt['failures'];failed=failed or bool(receipt['failures'])
 if not failed:q.validate_disabled_control(receipt,source,False)
r['inputs_unchanged']=q.committed_inputs()==inputs;r['status']='failed' if failed or not r['inputs_unchanged'] else 'passed';q.save(out/'replay.json',r);print(r['status'],r.get('checks'),r.get('failures'),flush=True)
raise SystemExit(0 if r['status']=='passed' else 1)
