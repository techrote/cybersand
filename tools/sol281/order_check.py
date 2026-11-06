"""Record source-bound documentation, provenance and focused independent checks."""
import argparse,json,sys
from pathlib import Path
import order_common as o
import structure_cut as p

def main():
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);a=ap.parse_args();assert Path(a.run).name==a.run
    identity=o.identity();folder=o.OUT/a.run;assert not folder.exists();folder.mkdir();rows=[]
    queries=['retrieval-questions.json','retrieval-questions-sol-order.json']
    commands=[('docs',['tools/ci/check_docs.py','--json',str(folder/'docs.json')]),('m11',['tools/ci/check_m11_consistency.py','--json',str(folder/'m11.json')]),('repository',['tools/ci/check_repository.py','--require-materialized','--json',str(folder/'repository.json')]),('material-guard',['tools/material_catalogue/compatibility.py','--check']),('state-admission',['tools/sol281/test_order_reduction.py']),('geometry-controls',['tools/sol281/test_structure_reducer.py'])]
    commands += [('retrieval'+str(i),['tools/docs/retrieval_eval.py','--queries','docs/reference/'+q,'--output',str(folder/('retrieval'+str(i)+'.json'))]) for i,q in enumerate(queries)]
    for name,args in commands:rows.append(p.command(name,[sys.executable,*args],folder,timeout=120))
    rows.append(p.command('diff-check',['git','diff','--check'],folder,timeout=120))
    assert identity==o.identity()
    p.write(folder/'receipt.json',dict(identity=identity,commands=rows,post_source_equality=True,resource=o.resource(),qualification='Every nonzero gate remains a blocker, including inherited material/runtime source identity failures.'))
    return int(not all(x['clean'] for x in rows))
if __name__=='__main__':raise SystemExit(main())
