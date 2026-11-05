#!/usr/bin/env python3
"""Portable independent audit of the committed raw chamber counterexample."""
import argparse
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("chamber",Path(__file__).with_name("sol_chamber_reduce.py"))
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("packet",type=Path);args=parser.parse_args()
    index=json.loads((args.packet/"reference-payload-index.json").read_text(encoding="utf-8"))
    def portable_payload(meta):
        path=(args.packet/index[meta["path"]]).resolve()
        assert path.is_relative_to(args.packet.resolve()),"Payload escapes packet"
        value=c.r.tuples(path)
        assert value["sha256"]==meta["sha256"] and value["bytes"]==meta["bytes"]
        return value
    # Only file resolution is adapted. Original report bytes/hashes stay intact;
    # this does not instantiate a World or grant imported-mask ownership.
    c.payload=portable_payload
    profile=json.loads((ROOT/"godot/tests/fixtures/sol_chamber/registration.json").read_text(encoding="utf-8"))
    result=c.report(args.packet/"raw-reference-closed-driven-selective.json",profile)
    assert result["valid_initial_geometry"] and result["complete_episode"] and result["material_count_conservation"] and result["exact_tuple_multiset_conservation"]
    assert result["maximum_observed_sand_area"]>1e-6 and result["maximum_observed_sand_depth"]>2e-5
    print(json.dumps({k:result[k] for k in ["id","source","raw_sha256","valid_initial_geometry","complete_episode","material_count_conservation","exact_tuple_multiset_conservation","maximum_observed_sand_area","maximum_observed_sand_depth"]},indent=2))

if __name__=="__main__":main()
