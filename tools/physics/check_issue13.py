"""Retain separate current/history/retrieval validation outcomes, including failures."""
import argparse,json,subprocess,sys
from pathlib import Path
from run import ROOT
p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
commands={
'docs':[sys.executable,'tools/ci/check_docs.py'],
'history':[sys.executable,'tools/ci/check_m11_consistency.py'],
'repository':[sys.executable,'tools/ci/check_repository.py'],
'checker-tests':[sys.executable,'-m','unittest','discover','-s','tools/ci','-p','test_validation_contracts.py'],
'retrieval':[sys.executable,'tools/docs/retrieval_eval.py','--output',str(a.output/'retrieval.json')],
'challenges':[sys.executable,'tools/docs/retrieval_eval.py','--queries','docs/reference/retrieval-challenges.json','--output',str(a.output/'challenges.json')],
'diff':['git','diff','--check']}
results={}
for name,cmd in commands.items():
    r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
    (a.output/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8')
    results[name]={'command':cmd,'exit':r.returncode,'timeout_seconds':180}
    print(name,r.returncode,flush=True)
(a.output/'validation.json').write_text(json.dumps(results,indent=2))
