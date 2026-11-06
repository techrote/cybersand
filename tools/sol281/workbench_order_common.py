"""Separate fixed-action ordering campaign; old scientific collections immutable."""
import json,shutil,subprocess
from pathlib import Path
import workbench_common as previous
import structure_cut as p
ROOT=p.ROOT
OUT=ROOT/'build/sol-workbench-order'
PARENT='c0be3a4ea42643e762f9ef55285cdcb23342d97a'
FIXTURE='native/tests/fixtures/sol_workbench_order_001.json'
CAP=2*1024**3
RESERVE=5*1024**3
REPORT_RESERVATION=64*1024**2
def resource(additional=0):
    OUT.mkdir(parents=True,exist_ok=True);used=sum(x.stat().st_size for x in OUT.rglob('*') if x.is_file());free=shutil.disk_usage(OUT).free
    assert used+additional<=CAP and free-additional>=RESERVE,'Keep all evidence; registered resource limit reached'
    return dict(bytes=used,free=free,cap=CAP,reserve=RESERVE)
def identity():
    info=previous.identity();subprocess.run(['git','-C',str(ROOT),'merge-base','--is-ancestor',PARENT,'HEAD'],check=True)
    old='native/tests/fixtures/sol_workbench_law_001.json';assert (ROOT/old).read_bytes()==p.git('show',PARENT+':'+old)
    names=[FIXTURE,'godot/tests/test_sol_workbench_order.gd','godot/tests/test_sol_workbench_order_adapter.gd',
           'tools/sol281/workbench_order_common.py','tools/sol281/workbench_order_live.py','tools/sol281/workbench_order_reduce.py',
           'tools/sol281/test_workbench_order_reduce.py','tools/sol281/workbench_reduce.py','tools/sol281/reduce_structure_cut.py',
           'tools/sol281/structure_cut.py','native/tests/fixtures/sol_mass_initialization_002.json',
           'godot/tests/test_sol_workbench_law.gd','godot/scripts/solid_workbench_session.gd','godot/scripts/workbench_physics_bridge.gd']
    return dict(**info,ordering_parent=PARENT,ordering_registration_sha256=p.sha(ROOT/FIXTURE),experiment_inputs={n:p.sha(ROOT/n) for n in names})
