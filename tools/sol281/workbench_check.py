"""Source-bound gates for the dependent SOL workbench experiment."""
import argparse,sys
from pathlib import Path
import structure_cut as p
import workbench_common as w

def main():
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);a=ap.parse_args();assert Path(a.run).name==a.run
    identity=w.identity();folder=w.OUT/a.run;assert not folder.exists();folder.mkdir();rows=[]
    commands=[('docs',['tools/ci/check_docs.py','--json',str(folder/'docs.json')]),('m11',['tools/ci/check_m11_consistency.py','--json',str(folder/'m11.json')]),('repository',['tools/ci/check_repository.py','--require-materialized','--json',str(folder/'repository.json')]),('material-guard',['tools/material_catalogue/compatibility.py','--check']),('state-admission',['tools/sol281/test_order_reduction.py']),('geometry-controls',['tools/sol281/test_structure_reducer.py']),('workbench-admission',['tools/sol281/test_workbench_reducer.py'])]
    for i,query in enumerate(['retrieval-questions.json','retrieval-questions-sol-order.json','retrieval-questions-sol-workbench.json']):commands.append(('retrieval'+str(i),['tools/docs/retrieval_eval.py','--queries','docs/reference/'+query,'--output',str(folder/('retrieval'+str(i)+'.json'))]))
    for name,args in commands:rows.append(p.command(name,[sys.executable,*args],folder,timeout=180))
    rows.append(p.command('diff-check',['git','diff','--check'],folder,timeout=120))
    assert identity==w.identity()
    p.write(folder/'receipt.json',dict(identity=identity,commands=rows,post_source_equality=True,resource=w.resource(),scope='Documentation and identity gates are separate from physical acceptance. Every nonzero gate remains a blocker.'))
    return int(not all(x['clean'] for x in rows))
if __name__=='__main__':raise SystemExit(main())
