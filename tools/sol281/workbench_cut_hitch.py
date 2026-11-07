"""Fixed cut-hitch comparison; unchanged compiled inputs and material authority."""
import argparse
import json
from pathlib import Path
import sys
import workbench_brush_cut as b

p=b.p;f=b.f
f.OUT=p.ROOT/'build/workbench-cut-hitch'
f.PROFILE='native/tests/fixtures/workbench_cut_hitch_001.json'
f.PARENT='55cbc8199dee01b670536d1c6721bb82c92f0622'
base_identity=b.identity

def identity():
    return dict(**base_identity(),hitch_runner_sha256=p.sha(__file__),
        hitch_test_sha256=p.sha(p.ROOT/'godot/tests/test_workbench_cut_hitch.gd'))
b.identity=identity;f.identity=identity

def reuse():
    prior=p.ROOT/'build/workbench-rectangle-core/runtimes-001/receipt.json'
    receipt=json.loads(prior.read_text());info=identity()
    assert receipt['post_source_equality']
    assert receipt['identity']['source_inputs']==info['source_inputs']
    assert receipt['identity']['material_inputs']==info['material_inputs']
    for row in receipt['platforms'].values(): assert p.sha(p.ROOT/row['output'])==row['sha256']
    receipt['scope']='Reuse unchanged binaries after all108 compiled/build input hashes and material inventory match; no rebuild'
    receipt['original_build_identity']=receipt['identity']
    receipt['reuse_of_receipt_sha256']=p.sha(prior);receipt['identity']=info
    p.write(f.OUT/'unchanged-runtimes/receipt.json',receipt)

if __name__=='__main__':
    parser=argparse.ArgumentParser(__doc__)
    parser.add_argument('--run',required=True);parser.add_argument('--full',action='store_true');a=parser.parse_args()
    assert Path(a.run).name==a.run
    f.resource(256*1024**2);reuse()
    scripts=['test_workbench_cut_hitch']
    if a.full: scripts+=['test_workbench_rectangle_core','test_workbench_small_debris','test_workbench_brush_cuts','test_workbench_freed']
    sys.exit(b.hosts(a.run,'unchanged-runtimes',scripts,['test_workbench_rectangle_core_lifecycle']))
