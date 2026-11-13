#!/usr/bin/env python3
"""Adverse evidence controls against a completed genuine native replay packet.

Mutated copies remain temporary and are never submitted as runtime evidence.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import shutil
import tempfile

from PIL import Image

from run_native_replay import read_cases
from verify_native_replay import verify


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    baseline=verify(args.fixture)
    if not baseline["passed"]:
        raise ValueError("Adverse tests require a genuinely passing native evidence fixture")
    results=[{"control":"unaltered genuine packet accepted","passed":True}]

    def mutation(name, edit, expected_fragment):
        with tempfile.TemporaryDirectory(prefix="slm-native-adverse-") as temporary:
            destination=Path(temporary)/"packet"
            shutil.copytree(args.fixture,destination,ignore=shutil.ignore_patterns("profile","*admission-receipts.json"))
            edit(destination)
            result=verify(destination)
            ok=not result["passed"] and any(expected_fragment in item for item in result["failures"])
            results.append({"control":name,"passed":ok,"detected_failures":result["failures"][:3]})

    def rewrite(path, fn):
        obj=json.loads(path.read_text());fn(obj);path.write_text(json.dumps(obj))

    def alter_binary(directory):
        summary=json.loads((directory/"native-summary.json").read_text())
        path=directory/summary["cases"][0]["raw_materials"]
        data=bytearray(path.read_bytes());data[0]^=1;path.write_bytes(data)

    def alter_png(directory):
        summary=json.loads((directory/"native-summary.json").read_text())
        path=directory/summary["cases"][0]["material_png"]
        with Image.open(path) as opened:
            image=opened.copy()
        image.putpixel((0,0),1);image.save(path)

    def alter_before(directory):
        path=directory/"native-receipts.jsonl"
        rows=[json.loads(line) for line in path.read_text().splitlines()]
        for row in rows:
            if row["case"] in {c["id"] for c in baseline["cases"]} and row.get("receipt",{}).get("readback"):
                row["receipt"]["readback"][0][2]=58
                break
        path.write_text("\n".join(json.dumps(row) for row in rows)+"\n")

    mutation("corrupt raw native crop refused",alter_binary,"exact binary crop")
    mutation("corrupt material PNG refused",alter_png,"PNG pixels equal exact material IDs")
    mutation("native before-row inconsistency refused",alter_before,"native before-row follows prior receipt")
    mutation("nonzero out-of-scope count refused",lambda d:rewrite(d/"native-summary.json",lambda x:x["cases"][0].update(outside_area_cells=1)),"zero invariant violations")
    mutation("failed engine process refused",lambda d:rewrite(d/"process-result.json",lambda x:x.update(exit_code=1)),"engine process completed")
    mutation("missing case refused",lambda d:rewrite(d/"native-summary.json",lambda x:x["cases"].pop()),"complete case count")
    mutation("harness custody mismatch refused",lambda d:rewrite(d/"runtime-custody.json",lambda x:x.update(harness_sha256="0"*64)),"harness custody")
    mutation("native custody mismatch refused",lambda d:rewrite(d/"runtime-custody.json",lambda x:x.update(native_sha256="0"*64)),"native artifact custody")
    mutation("false engine assertion refused despite summary pass",lambda d:rewrite(d/"native-summary.json",lambda x:x["checks"][0].update(passed=False)),"every engine assertion passed")
    mutation("post-run input change refused",lambda d:rewrite(d/"process-result.json",lambda x:x.update(input_unchanged=False)),"input_unchanged")
    def alter_probe_capture(directory, probe):
        path=directory/"native-receipts.jsonl"
        rows=[json.loads(line) for line in path.read_text().splitlines()]
        for row in rows:
            if row["case"]==probe and "capture" in row:
                row["capture"]["materials_i32le_sha256"]="0"*64
                break
        path.write_text("\n".join(json.dumps(row) for row in rows)+"\n")
    mutation("corrupt protection witness refused",lambda d:alter_probe_capture(d,"invariant-protection"),"independent native protection fixture")
    mutation("corrupt Stop witness refused",lambda d:alter_probe_capture(d,"invariant-stop"),"independent native Stop prefix")
    with tempfile.TemporaryDirectory(prefix="slm-input-adverse-") as temporary:
        input_path=Path(temporary)/"cases.json"
        value=json.loads((args.fixture/"input-cases.json").read_text())
        value["cases"][0]["operations_sha256"]="0"*64
        input_path.write_text(json.dumps(value))
        refused=False
        try: read_cases(input_path)
        except ValueError as error: refused="digest" in str(error)
        results.append({"control":"incorrect operation digest refused before engine starts","passed":refused})
    report={"passed":all(result["passed"] for result in results),"controls":results,
            "fixture":str(args.fixture.resolve()),"actual_native_execution":False,
            "scope":"Independent reducer adverse controls on temporary copies of genuine native output"}
    if args.output.exists(): raise ValueError("Refusing to overwrite prior adverse-test evidence")
    args.output.write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))
    return 0 if report["passed"] else 1


if __name__=="__main__":
    raise SystemExit(main())
