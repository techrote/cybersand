"""Fixed <=16-cell RedBrick -> Sand/Rust tangent; existing native granular law."""
import argparse
import sys
from pathlib import Path
import workbench_brush_cut as b

p=b.p;f=b.f
f.OUT=p.ROOT/'build/workbench-small-debris'
f.PROFILE='native/tests/fixtures/workbench_small_debris_001.json'
f.PARENT='b140265d1a2ef2fd76787f8048dbcc5e9fa545ac'
base_identity=b.identity
def identity():
    return dict(**base_identity(),debris_runner_sha256=p.sha(__file__),
        debris_native_test_sha256=p.sha(p.ROOT/'native/tests/workbench_small_debris_cases.inc'),
        debris_godot_test_sha256=p.sha(p.ROOT/'godot/tests/test_workbench_small_debris.gd'))
b.identity=identity;f.identity=identity

if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('mode',choices=['build','native','hosts']);parser.add_argument('--run',required=True);parser.add_argument('--build-run',default='runtimes-001');args=parser.parse_args()
    assert Path(args.run).name==args.run
    f.resource(256*1024**2)
    if args.mode=='build':p.OUT=f.OUT;p.identity=identity;sys.exit(p.build(args.run))
    if args.mode=='native':sys.exit(f.native(args.run))
    sys.exit(b.hosts(args.run,args.build_run,['test_workbench_small_debris','test_workbench_brush_cuts','test_workbench_freed']))
