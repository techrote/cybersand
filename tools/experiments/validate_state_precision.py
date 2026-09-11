"""Run current docs/retrieval and historical gates without rewriting companion links."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
def main():
    out=ROOT/'validation/local/issue-17'/('validation-'+time.strftime('%Y%m%d-%H%M%S'))
    source=out/'workspace/source';source.mkdir(parents=True)
    paths=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines()
    hashes={}
    for name in paths:
        p=ROOT/name
        if not p.is_file():continue
        q=source/name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
        hashes[name]=hashlib.sha256(q.read_bytes()).hexdigest()
    for name in ['SOURCE-PROVENANCE.json','docs/WEB_THREADING.md','tools/dev.py','docs/LOCAL_DEVELOPMENT.md','validation/browser-results.json']:
        q=source.parent/name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(Path('C:/kybersand')/name,q)
    (source/'.git').write_text('gitdir: '+subprocess.check_output(['git','rev-parse','--absolute-git-dir'],cwd=ROOT,text=True).strip()+'\n')
    commands={
      'docs-direct':[sys.executable,'tools/ci/check_docs.py'],
      'docs':[sys.executable,'tools/ci/check_docs.py','--root',source],
      'm11':[sys.executable,'tools/ci/check_m11_consistency.py'],
      'repository':[sys.executable,'tools/ci/check_repository.py','--root',source],
      'repository-baseline':[sys.executable,'C:/kybersand/source/tools/ci/check_repository.py','--root','C:/kybersand/source'],
      'precision-tests':[sys.executable,'-m','unittest','discover','-s','tools/experiments','-p','test_state_precision.py'],
      'validation-contracts':[sys.executable,'-m','unittest','discover','-s','tools/ci','-p','test_validation_contracts.py'],
      'diff':['git','diff','--check'],
    }
    for key,queries in [('frozen','retrieval-questions.json'),('challenges','retrieval-challenges.json'),('programme','architecture-programme-questions.json'),('gates','programme-gate-questions.json'),('precision','state-precision-questions.json')]:
        commands['retrieval-'+key]=[sys.executable,'tools/docs/retrieval_eval.py','--root',source,'--queries',ROOT/'docs/reference'/queries,'--output',out/('retrieval-'+key+'.json')]
    results={}
    for name,args in commands.items():
        args=list(map(str,args))
        with (out/(name+'.log')).open('w') as f:
            r=subprocess.run(args,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=300)
        results[name]={'command':args,'exit':r.returncode,'log':name+'.log'}
        print(name,r.returncode,flush=True)
    (out/'manifest.json').write_text(json.dumps({'source_hashes':hashes,'checks':results},indent=2)+'\n')
    print(out)
if __name__=='__main__':main()
