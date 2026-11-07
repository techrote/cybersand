"""Registered single interior core plus native Sand; same contact law and caps."""
import argparse
import sys
from pathlib import Path
import workbench_brush_cut as b

p=b.p;f=b.f
f.OUT=p.ROOT/'build/workbench-rectangle-core'
f.PROFILE='native/tests/fixtures/workbench_rectangle_core_001.json'
f.PARENT='53d642b8b0c7b773318ed1660a657d38e9ec6800'
base_identity=b.identity

def identity():
    return dict(**base_identity(),rectangle_runner_sha256=p.sha(__file__),
        rectangle_native_test_sha256=p.sha(p.ROOT/'native/tests/workbench_rectangle_core_cases.inc'),
        rectangle_host_test_sha256=p.sha(p.ROOT/'godot/tests/test_workbench_rectangle_core.gd'))
b.identity=identity;f.identity=identity

if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('mode',choices=['build','native','hosts']);parser.add_argument('--run',required=True);parser.add_argument('--build-run',default='runtimes-001');a=parser.parse_args()
    assert Path(a.run).name==a.run
    f.resource(256*1024**2)
    if a.mode=='build':p.OUT=f.OUT;p.identity=identity;sys.exit(p.build(a.run))
    if a.mode=='native':sys.exit(f.native(a.run))
    sys.exit(b.hosts(a.run,a.build_run,['test_workbench_rectangle_core','test_workbench_small_debris','test_workbench_brush_cuts','test_workbench_freed'],['test_workbench_rectangle_core_lifecycle']))
