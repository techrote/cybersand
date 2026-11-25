from pathlib import Path
import json,os,sys,subprocess
root=Path(__file__).resolve().parents[3];sys.path.insert(0,str(root/'tools/objectshard'))
import qualify_workbench as q
from process_resources import run_observed_case
out=Path(__file__).resolve().parent/'execution';out.mkdir(exist_ok=False)
engine=Path('/home/agent/objectshard-recovery-20261125/shared-runtime/Godot_v4.7-stable_linux.x86_64')
source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip();inputs=q.committed_inputs();user=out/'user-data';user.mkdir()
case=q.runner.Case('test_object_shard_m4_edit_delivery_fence',('--script','res://tests/test_object_shard_m4_edit_delivery_fence.gd','--','--objectshard-m4-workbench'),int(q.execution_policy.watchdog_seconds('ordinary_case_seconds')),0)
env=dict(os.environ,CYBERSAND_SOURCE_REVISION=source,XDG_DATA_HOME=str(user),APPDATA=str(user),LOCALAPPDATA=str(user));env.pop('CYBERSAND_PACKAGE_MANIFEST',None)
r={'schema':'objectshard-m4-edit-delivery-fence-execution-v1','source_commit':source,'source_tree':subprocess.check_output(['git','rev-parse','HEAD^{tree}'],cwd=root,text=True).strip(),'execution_inputs':inputs,'engine_sha256':q.runner.sha256(engine),'native_sha256':q.runner.sha256(q.runner.runtime_paths()[0]),'rapier_sha256':q.runner.sha256(q.runner.runtime_paths()[1]),'scope':'Exact committed-source value-only boundary; no native World or Rapier mutation','status':'running'}
q.save(out/'replay.json',r)
row,failed=run_observed_case(q.runner,str(engine),case,out,'objectshard-m4-independent-delivery-fence',env=env);r['case']=row
try:
 receipt=q.completion(out/row['log'],'objectshard-m4-edit-delivery-fence-v1');q.save(out/'receipt.json',receipt);r['receipt_sha256']=q.runner.sha256(out/'receipt.json');r['checks']=receipt['checks'];r['failures']=receipt['failures']
except Exception as e:r['receipt_error']=str(e);failed=True
r['inputs_unchanged']=q.committed_inputs()==inputs;r['status']='failed' if failed or not r['inputs_unchanged'] else 'passed';q.save(out/'replay.json',r);print(r['status'],r.get('checks'),r.get('failures'),flush=True)
raise SystemExit(0 if r['status']=='passed' else 1)
