"""Source-bound gates for the dependent SOL workbench experiment."""
import argparse,json,sys
from pathlib import Path
import structure_cut as p
import workbench_common as w

def runtime_roster():
    sys.path.insert(0,str(w.ROOT/'tools/ci'))
    from run_windows_godot_regressions import native_input_paths,verify_retained_runtime
    paths=native_input_paths(w.ROOT);assert len(paths)==93
    for filename in ['runtime-provenance.json','runtime-provenance.linux.json']:
        manifest=json.loads((w.ROOT/'godot/addons/cybersand_native'/filename).read_text(encoding='utf-8'))
        assert set(manifest['source_inputs'])==paths
        assert all(p.lfsha(w.ROOT/name)==digest for name,digest in manifest['source_inputs'].items())
        assert p.sha(w.ROOT/manifest['evidence'])==manifest['evidence_sha256']
    result=verify_retained_runtime(w.ROOT)
    print('Complete native roster',len(paths),'canonical committed LFS, materialized Windows and pinned Rapier identities PASS',result['cybersand_runtime']['sha256'])

def main():
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run');ap.add_argument('--runtime-only',action='store_true');a=ap.parse_args()
    if a.runtime_only:runtime_roster();return 0
    assert a.run and Path(a.run).name==a.run
    identity=w.identity();folder=w.OUT/a.run;assert not folder.exists();folder.mkdir();rows=[]
    commands=[('docs',['tools/ci/check_docs.py','--json',str(folder/'docs.json')]),('m11',['tools/ci/check_m11_consistency.py','--json',str(folder/'m11.json')]),('repository',['tools/ci/check_repository.py','--require-materialized','--json',str(folder/'repository.json')]),('material-guard',['tools/material_catalogue/compatibility.py','--check']),('state-admission',['tools/sol281/test_order_reduction.py']),('geometry-controls',['tools/sol281/test_structure_reducer.py']),('workbench-admission',['tools/sol281/test_workbench_reducer.py'])]
    commands.append(('runtime-roster',['tools/sol281/workbench_check.py','--runtime-only']))
    for i,query in enumerate(['retrieval-questions.json','retrieval-questions-sol-order.json','retrieval-questions-sol-workbench.json']):commands.append(('retrieval'+str(i),['tools/docs/retrieval_eval.py','--queries','docs/reference/'+query,'--output',str(folder/('retrieval'+str(i)+'.json'))]))
    for name,args in commands:rows.append(p.command(name,[sys.executable,*args],folder,timeout=180))
    rows.append(p.command('diff-check',['git','diff','--check'],folder,timeout=120))
    assert identity==w.identity()
    p.write(folder/'receipt.json',dict(identity=identity,commands=rows,post_source_equality=True,resource=w.resource(),scope='Documentation and identity gates are separate from physical acceptance. Every nonzero gate remains a blocker.'))
    return int(not all(x['clean'] for x in rows))
if __name__=='__main__':raise SystemExit(main())
