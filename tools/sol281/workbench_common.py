"""Custody of the admitted-source SOL/main composition; old collections read-only."""
import json,shutil,subprocess
from pathlib import Path
import qualify_facade_refusal as facade
import structure_cut as p
ROOT=p.ROOT
OUT=ROOT/'build/sol-workbench-law'
PARENT='cba3c0de35c4fae410b2fa16fa821524308c1ce8'
MAIN='554d27b199e10613c01dbd7933f3fc6205d3ecdb'
CAP=2*1024**3
RESERVE=5*1024**3
def resource():
    OUT.mkdir(parents=True,exist_ok=True);used=sum(x.stat().st_size for x in OUT.rglob('*') if x.is_file());free=shutil.disk_usage(OUT).free
    assert used<=CAP and free>=RESERVE,'Keep evidence; registered resource limit reached'
    return dict(bytes=used,free=free,cap=CAP,reserve=RESERVE)
def identity():
    assert not p.git('status','--porcelain'),'Commit source before execution'
    for commit in [PARENT,MAIN]:subprocess.run(['git','-C',str(ROOT),'merge-base','--is-ancestor',commit,'HEAD'],check=True)
    lock='materials/catalogue/compatibility-lock.json';assert (ROOT/lock).read_bytes()==p.git('show',MAIN+':'+lock),'Frozen lock must not change'
    protected=[lock,'tools/material_catalogue/compatibility.py']+[x['path'] for x in json.loads((ROOT/lock).read_text(encoding='utf-8'))['source_locks']]
    head=p.git('rev-parse','HEAD').decode().strip()
    return dict(**facade.snapshot(ROOT,head),material_inputs={n:p.sha(ROOT/n) for n in sorted(set(protected))},parent=PARENT,main=MAIN,registration_sha256=p.sha(ROOT/'native/tests/fixtures/sol_workbench_law_001.json'))
