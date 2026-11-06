"""Shared custody for the dependent contact-order experiment; parent is read-only."""
import hashlib,json,shutil
from pathlib import Path
import structure_cut as p
ROOT=p.ROOT
OUT=ROOT/'build/sol-contact-order'
PARENT=Path('C:/Users/_/.codex/worktrees/sol-structure-cut-20261106/khybersand')
PARENT_SHA='61924a9788f507620706dfa19d28dc12d819156b'
CAP=2*1024**3
RESERVE=5*1024**3
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def resource():
    OUT.mkdir(parents=True,exist_ok=True);used=sum(f.stat().st_size for f in OUT.rglob('*') if f.is_file());free=shutil.disk_usage(OUT).free
    assert used<=CAP and free>=RESERVE,'Resource budget exhausted; preserve previous evidence'
    return dict(bytes=used,free=free,cap=CAP,reserve=RESERVE)
def parent_receipt():
    path=PARENT/'build/sol-structure-cut/mass-fix-001/receipt.json';data=json.loads(path.read_text(encoding='utf-8'));assert data['post_source_equality']
    assert data['identity']['source_commit']=='c0d8544fc01653c329a7ff0f235666532967d29d'
    return path,data
def identity():
    data=p.identity();p.subprocess.run(['git','-C',str(ROOT),'merge-base','--is-ancestor',PARENT_SHA,'HEAD'],check=True)
    assert p.subprocess.check_output(['git','-C',str(PARENT),'rev-parse','HEAD']).decode().strip()==PARENT_SHA,'Parent worktree moved'
    assert not p.subprocess.check_output(['git','-C',str(PARENT),'status','--porcelain']),'Parent source changed'
    return data
