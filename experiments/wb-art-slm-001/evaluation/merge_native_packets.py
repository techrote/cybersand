#!/usr/bin/env python3
"""Merge fully verified disjoint native packets without weakening global gates."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path


def merge(paths: list[Path]) -> dict:
    runtime=None
    cases=[]
    seen=set()
    packets=[]
    for path in paths:
        report=json.loads(path.read_text())
        gates=report.get("global_gates",{})
        if report.get("passed") is not True or not gates or not all(value is True for value in gates.values()):
            raise ValueError(f"Packet is not globally qualified: {path}")
        if runtime is None: runtime=report["runtime"]
        elif runtime!=report["runtime"]: raise ValueError("Different runtime identities cannot be silently merged")
        for original in report["cases"]:
            row=dict(original)
            if row["id"] in seen: raise ValueError(f"Duplicate case: {row['id']}")
            seen.add(row["id"])
            if row.get("success") is not True or row.get("outside_focus_violations")!=0 or row.get("unexpected_material_cells")!=0:
                raise ValueError(f"Unqualified native case: {row['id']}")
            if row.get("acknowledged_cells",0)<=0 or not row.get("operations_sha256") or not row.get("image_sha256") or not row.get("readback_sha256"):
                raise ValueError(f"Incomplete native witness: {row['id']}")
            row["source_packet"]=str(path.parent.resolve())
            cases.append(row)
        packets.append({"receipt":str(path.resolve()),"receipt_sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
                        "passed":True,"global_gates":gates,"engine_checks":report["engine_checks"],
                        "independent_checks":report["checks"],"cases":len(report["cases"])})
    return {"schema_version":1,"passed":True,"runtime":runtime,
            "qualification":"Pinned Linux headless native-material pilot; no current-main, Windows, graphical or human acceptance",
            "global_gates":{"all_source_packets_verified":True,"all_runtime_identities_equal":True,
                            "all_case_ids_unique":True,"all_cases_positive_and_zero_violations":True},
            "packets":packets,"cases":cases}


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packets",nargs="+",type=Path)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    if args.output.exists(): raise ValueError("Refusing to overwrite existing merged evidence")
    result=merge(args.packets)
    args.output.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({"passed":True,"cases":len(result["cases"]),"packets":len(result["packets"]),"output":str(args.output)},indent=2))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
