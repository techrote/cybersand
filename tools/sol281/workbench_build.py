"""Reuse pinned host build entrypoints with the new composition custody premise."""
import argparse
import structure_cut as p
import workbench_common as w
if __name__=='__main__':
    ap=argparse.ArgumentParser(__doc__);ap.add_argument('--run',required=True);a=ap.parse_args()
    assert w.Path(a.run).name==a.run
    w.resource();p.OUT=w.OUT;p.identity=w.identity
    raise SystemExit(p.build(a.run))
