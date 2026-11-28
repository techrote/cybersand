from pathlib import Path
import contextlib
from datetime import datetime, timezone
import hashlib
import json
import os
import sys
import time
import uuid

root=Path(__file__).resolve().parents[2]
base=Path(__file__).resolve().parent
sys.path.insert(0,str(root/'tools/objectshard'))
import qualify_workbench as q
from process_resources import run_observed_case

def digest(path):
    with Path(path).open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def main():
    out=base/'attempt-2'
    out.mkdir(exist_ok=False)
    user=out/'user-data';user.mkdir()
    app=base/'application'
    engine=Path('/home/agent/objectshard-recovery-20261125/shared-runtime/Godot_v4.7-stable_linux.x86_64')
    observer=base/'observe_authored_v2.gd'
    inputs=json.loads((base/'application-inputs.json').read_text())
    native=json.loads((base/'native-receipt.json').read_text())
    assert all(digest(app/p)==d for p,d in inputs['files'].items())
    assert digest(engine)=='f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75'
    q.runner.ROOT=app
    value={'schema':'objectshard-m4-authored-fresh-process-pair-custody-v2',
      'source_commit':inputs['source'],'source_tree':inputs['tree'],'local_equivalent':inputs['local_equivalent'],
      'observer_sha256':digest(observer),'runner_sha256':digest(__file__),
      'shared_runner_path':str(q.runner.__file__),'shared_runner_sha256':digest(q.runner.__file__),
      'application_inputs_sha256':digest(base/'application-inputs.json'),
      'native_receipt_sha256':digest(base/'native-receipt.json'),'native_build_source':native['source']['source_commit'],
      'native_source_inputs':native['source']['source_inputs'],'native_build_contract_inputs':native['source']['build_contract_inputs'],
      'runtime_hashes':inputs['runtime_hydration'],'engine_sha256':digest(engine),'status':'running',
      'external_parent_pid':os.getpid(),'parent_pid_namespace':os.readlink('/proc/self/ns/pid'),
      'parent_proc_start_ticks':int(Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19]),
      'process_identity_scope':'One external Python parent calls the shared Popen runner twice sequentially and records each completed lifetime. Numeric child PIDs alone are not identity.',
      'source_scope':'All 1023 frozen Godot files verified; declared retained runtime bytes have complete117native/5build-input equivalence; observer separate.',
      'scope':'Linux headless mounted authoring/Save/Load routes, ordinary brush and owner controls; no physical GPU or evolved checkpoint claim.',
      'superseded_observer_attempt':{'author_replay_sha256':digest(base/'author/replay.json'),
          'reopen_replay_sha256':digest(base/'reopen/replay.json'),'observer_sha256':digest(base/'observe_authored.gd'),
          'retained_result':'Author136PASS; reopen77FAIL from invalid cross-namespace PID inequality and JSON numeric typing comparison; application lifecycle, exact saved hashes and conservation passed.'},
      'processes':[]}
    q.save(out/'replay.json',value)
    failed=False
    previous_end=None
    for phase in ('author','reopen'):
        directory=out/phase;directory.mkdir()
        nonce=uuid.uuid4().hex
        env=dict(os.environ,CYBERSAND_SOURCE_REVISION=inputs['source'],
                 CYBERSAND_EXTERNAL_OBSERVER_SHA256=digest(observer),CYBERSAND_LAUNCH_NONCE=nonce,
                 CYBERSAND_EXTERNAL_RECEIPT=str(directory/'receipt.json'),
                 CYBERSAND_AUTHOR_RECEIPT=str(out/'author/receipt.json'),CYBERSAND_AUTHORED_PHASE=phase,
                 XDG_DATA_HOME=str(user),APPDATA=str(user),LOCALAPPDATA=str(user))
        env.pop('CYBERSAND_PACKAGE_MANIFEST',None)
        flags=('--script',str(observer))
        if phase=='reopen':flags+=('--','--objectshard-m4-workbench')
        case=q.runner.Case('authored_'+phase,flags,300,0)
        launch={'phase':phase,'launch_nonce':nonce,'started_utc':datetime.now(timezone.utc).isoformat(),
                'start_monotonic_ns':time.monotonic_ns(),'source_commit':inputs['source'],
                'previous_process_completed':previous_end is not None if phase=='reopen' else None}
        if previous_end is not None:assert launch['start_monotonic_ns']>previous_end
        with (directory/'driver.log').open('w') as log,contextlib.redirect_stdout(log):
            row,bad=run_observed_case(q.runner,str(engine),case,directory,'objectshard-m4-authored-recovery-v2',env=env)
        launch.update(case=row,completed_utc=datetime.now(timezone.utc).isoformat(),end_monotonic_ns=time.monotonic_ns())
        previous_end=launch['end_monotonic_ns']
        if (directory/'receipt.json').exists():
            receipt=json.loads((directory/'receipt.json').read_text())
            assert receipt['launch_nonce']==nonce and receipt['source_commit']==inputs['source'] and receipt['observer_sha256']==value['observer_sha256'] and receipt['phase']==phase
            assert receipt['process_id']==row['pid']
            launch.update(receipt_sha256=digest(directory/'receipt.json'),checks=receipt['checks'],failures=receipt['failures'],process_id=receipt['process_id'])
            bad=bad or bool(receipt['failures'])
            footers=[]
            for line in (directory/row['log']).read_text(errors='replace').splitlines():
                try:item=json.loads(line)
                except json.JSONDecodeError:continue
                if isinstance(item,dict) and item.get('schema')=='objectshard-m4-authored-extent-reopen-v1':footers.append(item)
            assert footers==[receipt]
        else:bad=True
        launch['status']='failed' if bad else 'passed'
        value['processes'].append(launch)
        q.save(out/'replay.json',value)
        if bad:
            failed=True;break
    value['inputs_unchanged']=all(digest(app/p)==d for p,d in inputs['files'].items())
    value['status']='failed' if failed or len(value['processes'])!=2 or not value['inputs_unchanged'] else 'passed'
    q.save(out/'replay.json',value)
    print(json.dumps({'status':value['status'],'processes':[{k:p.get(k) for k in ('phase','status','checks','failures','process_id','launch_nonce')} for p in value['processes']],
                      'inputs_unchanged':value['inputs_unchanged']}))
    raise SystemExit(0 if value['status']=='passed' else 1)

if __name__=='__main__':main()
