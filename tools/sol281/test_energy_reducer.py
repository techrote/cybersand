#!/usr/bin/env python3
"""Adversarial admission tests over a retained SOL-ENERGY-001 raw report."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import tempfile

spec=importlib.util.spec_from_file_location("reducer",Path(__file__).with_name("reduce_energy_precision.py"))
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("report",type=Path);args=parser.parse_args()
    original=json.loads(args.report.read_text(encoding="utf-8"));r.audit(args.report)
    def drop_trace(d):
        for arm in ["baseline-trace","scalar64-trace"]:d["records"][0]["traces"][arm]=[]
    def rename_grid(d):d["records"][0]["name"]=d["records"][0]["name"].replace("0.000001","0.000002")
    def drop_ranges(d):del d["ranges"]
    def drop_final(d):d["records"][0]["traces"]["scalar64-trace"].pop()
    def break_chain(d):d["records"][0]["traces"]["scalar64-trace"][1]["before_v"]=d["records"][1]["input"]["velocity"]
    def corrupt_impulse(d):
        record=next(record for record in d["records"] if record["results"]["scalar64"]["impulses"])
        for arm in ["scalar64","scalar64-trace"]:record["results"][arm]["impulses"][0]["impulse"]=record["input"]["velocity"]
    def alter_grid_input(d):d["records"][0]["input"]["omega"]=d["records"][1]["input"]["velocity"]["x"]
    def missing_control(d):d["records"][-1]["name"]="unregistered-control"
    mutations=[drop_trace,rename_grid,drop_ranges,drop_final,break_chain,corrupt_impulse,alter_grid_input,missing_control]
    with tempfile.TemporaryDirectory(prefix="sol-energy-reducer-") as directory:
        path=Path(directory)/"mutated.json"
        for mutate in mutations:
            data=copy.deepcopy(original);mutate(data);path.write_text(json.dumps(data),encoding="utf-8")
            try:r.audit(path)
            except (AssertionError,KeyError):pass
            else:raise AssertionError("Corrupt evidence admitted: "+mutate.__name__)
    print(json.dumps(dict(valid_report="PASS",rejected_mutations=[m.__name__ for m in mutations],checks=1+len(mutations))))

if __name__=="__main__":main()
