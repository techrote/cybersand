#!/usr/bin/env python3
"""Verify/reduce an unpacked full raw packet without original host paths."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("raw_root",type=Path);parser.add_argument("--verify-only",action="store_true");parser.add_argument("--output",type=Path);args=parser.parse_args()
    raw_root=args.raw_root.resolve();manifest=json.loads((ROOT/"docs/audits/sol-chamber-20261105/manifest.json").read_text(encoding="utf-8"))
    for item in manifest["local_raw_files"]:
        path=(raw_root/item["path"]).resolve();assert path.is_relative_to(raw_root)
        assert path.stat().st_size==item["bytes"] and hashlib.sha256(path.read_bytes()).hexdigest()==item["sha256"],item["path"]
    print("verified",len(manifest["local_raw_files"]),"complete local raw identities",flush=True)
    if args.verify_only:return
    spec=importlib.util.spec_from_file_location("chamber",Path(__file__).with_name("sol_chamber_reduce.py"))
    c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c);c.ROOT=raw_root
    def portable_path(value):
        normalized=value.replace("\\","/");marker="/build/sol-chamber/"
        assert marker in normalized,"Payload is outside the declared raw packet"
        result=(raw_root/"build/sol-chamber"/normalized.split(marker,1)[1]).resolve()
        assert result.is_relative_to(raw_root);return result
    c.r.local_path=portable_path
    output=args.output or raw_root/"independent-review-reduction"
    sys.argv=[str(Path(__file__)),str(raw_root/"build/sol-chamber/registered-matrix-corrected"),"--output",str(output)]
    c.main()

if __name__=="__main__":main()
