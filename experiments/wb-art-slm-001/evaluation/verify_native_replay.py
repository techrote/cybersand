#!/usr/bin/env python3
"""Independently reduce native receipts and verify material/PNG evidence.

This does not rasterize/compiler-render artwork. It reconstructs actual native
before/after rows, compares independent stored-cell capture hashes, and checks
the emitted PNG and binary files. Requires Pillow for decoding evidence PNGs.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
from collections import defaultdict

from PIL import Image
from run_native_replay import SOURCE, NATIVE_SHA256, RAPIER_SHA256, GODOT_VERSION


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def verify(directory: Path) -> dict:
    summary = json.loads((directory/"native-summary.json").read_text())
    process = json.loads((directory/"process-result.json").read_text())
    custody = json.loads((directory/"runtime-custody.json").read_text())
    cases = {row["id"]: row for row in json.loads((directory/"input-cases.json").read_text())["cases"]}
    failures = []
    checked = 0
    global_gates = {}

    def require(condition: bool, message: str) -> None:
        nonlocal checked
        checked += 1
        if not condition:
            failures.append(message)

    def gate(name: str, condition: bool, message: str) -> None:
        global_gates[name] = bool(condition)
        require(condition, message)

    gate("engine_passed", summary.get("passed") is True and not summary.get("failures"), "engine checks passed")
    gate("process_completed", process.get("exit_code") == 0 and process.get("timed_out") is False, "engine process completed without timeout")
    for key in ("runtime_unchanged", "harness_unchanged", "input_unchanged"):
        gate(key, process.get(key) is True, key)
    gate("input_digest_matches", digest((directory/"input-cases.json").read_bytes()) == custody["normalized_manifest_sha256"], "input custody")
    gate("native_artifact_matches", summary["source_identity"]["native_sha256"] == custody["native_sha256"] == NATIVE_SHA256, "native artifact custody")
    gate("harness_digest_matches", summary["source_identity"]["harness_sha256"] == custody["harness_sha256"], "harness custody")
    gate("runtime_pins_match", custody["source_commit"] == SOURCE and custody["rapier_sha256"] == RAPIER_SHA256
         and custody["godot_version"] == GODOT_VERSION and summary["source_identity"]["godot"] == "4.7-stable (official)",
         "exact runtime source and engine pins (CLI and Engine API version formats)")
    gate("complete_manifest", len(summary.get("cases", [])) == len(cases)
         and {row["id"] for row in summary.get("cases", [])} == set(cases), "complete case count")
    assertions=summary.get("checks", [])
    gate("all_engine_assertions_passed", bool(assertions) and all(row.get("passed") is True for row in assertions), "every engine assertion passed")
    labels={(row["case"],row["label"]) for row in assertions if row.get("passed") is True}
    required_labels={
        ("invariant-protection","scope, protected rectangle and protected source material survive exact whole-World comparison"),
        ("invariant-protection","native changed count closes against eligible cells"),
        ("invariant-stop","Undo refuses active agent batch"),
        ("invariant-stop","Undo refuses unconsumed native receipt"),
        ("invariant-stop","Stop readback matches exact prefix and untouched suffix"),
        ("invariant-stop","no delayed writes after Stop"),
        ("invariant-stop","Undo reverses confirmed stopped prefix"),
        ("invariant-stop","Redo restores only confirmed stopped prefix"),
    }
    gate("mandatory_invariant_assertions_present", required_labels <= labels, "mandatory Stop/protection assertions executed")
    receipts = defaultdict(list)
    captures = defaultdict(list)
    for line in (directory/"native-receipts.jsonl").read_text().splitlines():
        event=json.loads(line)
        if "receipt" in event:
            receipts[event["case"]].append(event["receipt"])
        if "capture" in event:
            captures[event["case"]].append(event["capture"])
    # Independent expected native fixture maps, not compiler artwork rasterization.
    protected=[0]*(512*512)
    for y in range(8,88):
        for x in range(8,88):
            if not (20<=x<36 and 20<=y<36): protected[y*512+x]=58
    protected[48*512+48]=28
    protected_digest=digest(struct.pack("<"+"i"*len(protected),*protected))
    protection_draws=receipts["invariant-protection"]
    protection_captures=captures["invariant-protection"]
    protection_ok=(len(protection_captures)==1 and protection_captures[0]["materials_i32le_sha256"]==protected_digest
                   and sum(r["changed"] for r in protection_draws)==6143
                   and sum(r["excluded"] for r in protection_draws)==3073
                   and sum(r["checked"] for r in protection_draws)==9216
                   and all(r["backend"]=="CyberNativeCellWorld" and r["status"]=="completed" and r["refused"]==0 for r in protection_draws))
    gate("protection_native_readback_exact", protection_ok, "independent native protection fixture hash and counters")
    stopped=receipts["invariant-stop"]
    stopped_captures=captures["invariant-stop"]
    prefix=int(sum(r["changed"] for r in stopped))
    stopped_values=[58 if i<prefix else 0 for i in range(128*128)]
    stopped_digest=digest(struct.pack("<"+"i"*len(stopped_values),*stopped_values))
    stopped_empty=digest(bytes(128*128*4))
    expected_stop_hashes=[stopped_digest,stopped_digest,stopped_empty,stopped_digest]
    actual_stop_hashes=[r["materials_i32le_sha256"] for r in stopped_captures]
    stop_ok=(0<prefix<=4096 and len(stopped)==1 and actual_stop_hashes==expected_stop_hashes
             and stopped[0]["backend"]=="CyberNativeCellWorld" and stopped[0]["status"]=="completed"
             and stopped[0]["checked"]==stopped[0]["confirmed"]==prefix
             and stopped[0]["excluded"]==stopped[0]["refused"]==0)
    gate("stop_native_readback_exact", stop_ok, "independent native Stop prefix/no-late-write/Undo/Redo capture hashes")
    qualified_themes={str(row.get("theme", "")) for row in summary.get("cases", [])
                      if row.get("history_and_reopen_checked",row.get("redo_and_reopen_checked",False)) is True}
    requested_themes={str(row.get("theme", "")) for row in cases.values()}
    gate("representative_history_and_reopen", requested_themes <= qualified_themes,
         "every requested theme has an explicit native history/save/reopen representative")
    results=[]
    for row in summary.get("cases", []):
        identifier=row["id"]
        case=cases[identifier]
        start_failures=len(failures)
        width,height=case["width"],case["height"]
        require(row.get("passed") is True and row.get("terminal",{}).get("status")=="completed",identifier+": engine per-case completion")
        declared=digest(json.dumps(case["operations"],sort_keys=True,separators=(",", ":"),allow_nan=False).encode())
        require(declared == case["operations_sha256"], identifier+": input operation digest")
        if row.get("operations_sha256"):
            require(declared == row["operations_sha256"], identifier+": engine input digest")
        world=[0]*(512*512)
        changed=acknowledged=unchanged=0
        require(bool(receipts[identifier]), identifier+": actual draw receipts exist")
        for receipt in receipts[identifier]:
            require(receipt.get("backend") == "CyberNativeCellWorld" and receipt.get("status") == "completed",
                    identifier+": native receipt completion")
            require(receipt.get("tick")==0 and receipt.get("before_source",{}).get("tick")==0,
                    identifier+": paused fresh World has no intervening simulation tick")
            rows=receipt["readback"]
            require(len(rows) == receipt["confirmed"] == receipt["checked"], identifier+": confirmed rows count")
            require(receipt["excluded"] == 0 and receipt["refused"] == 0, identifier+": no excluded/refused corpus writes")
            delta=0
            for x,y,before,after in rows:
                x,y,before,after=map(int,(x,y,before,after))
                require(0<=x<width and 0<=y<height, identifier+": confirmed cell in requested area")
                require(before in (0,58) and after in (0,58), identifier+": admitted before/after material")
                if not (0<=x<512 and 0<=y<512):
                    continue
                index=y*512+x
                require(world[index] == before, identifier+": native before-row follows prior receipt")
                world[index]=after
                delta += before != after
            require(delta == receipt["changed"], identifier+": changed count matches actual rows")
            changed += delta
            acknowledged += len(rows)
            unchanged += len(rows)-delta
        whole=struct.pack("<"+"i"*len(world),*world)
        full_digest=digest(whole)
        require(full_digest == row["whole_world_i32le_sha256"], identifier+": draw rows equal independent full-world capture")
        require(bool(captures[identifier]) and captures[identifier][0]["materials_i32le_sha256"] == full_digest,
                identifier+": independently captured native receipt hash")
        material_values=[world[y*512+x] for y in range(height) for x in range(width)]
        material_bytes=struct.pack("<"+"i"*len(material_values),*material_values)
        require((directory/row["raw_materials"]).read_bytes() == material_bytes, identifier+": exact binary crop")
        require(digest(material_bytes) == row["crop_i32le_sha256"], identifier+": raw crop hash")
        with Image.open(directory/row["material_png"]) as image:
            require(image.mode == "L" and image.size == (width,height), identifier+": material PNG shape and encoding")
            require(list(image.tobytes()) == material_values, identifier+": PNG pixels equal exact material IDs")
        with Image.open(directory/row["png"]) as image:
            colors = image.convert("RGB").tobytes()
            expected=b"".join(bytes((232,226,205) if value==58 else (13,21,28)) for value in material_values)
            require(image.size == (width,height) and colors == expected, identifier+": visualization only maps native IDs to declared colors")
        require(changed == row["terminal"]["changed"] and acknowledged == row["terminal"]["checked"]
                and unchanged == row["terminal"]["unchanged"], identifier+": terminal counters close")
        require(acknowledged>0 and changed>0 and row["filled_cells"] == sum(v!=0 for v in material_values), identifier+": nonempty result and confirmed change")
        require(row["outside_area_cells"] == row["unexpected_material_cells"] == 0, identifier+": zero invariant violations")
        results.append({"id": identifier,"success": len(failures)==start_failures and all(global_gates.values()),
                        "operations_sha256": declared,"image_sha256": digest((directory/row["png"]).read_bytes()),
                        "readback_sha256":digest(material_bytes),"outside_focus_violations":row["outside_area_cells"],
                        "unexpected_material_cells":row["unexpected_material_cells"],"acknowledged_cells":acknowledged,
                        "changed_cells":changed,"filled_cells":row["filled_cells"],
                        "history_and_reopen_checked":row.get("history_and_reopen_checked",row.get("redo_and_reopen_checked",False)),
                        "png":row["png"],"raw_materials":row["raw_materials"]})
    return {"runtime":{key:custody[key] for key in ("source_commit","native_sha256","godot_version")},
            "qualification":custody["claim"],"passed":not failures,"checks":checked,"failures":failures,
            "global_gates":global_gates,"engine_checks":len(assertions),
            "process_result_sha256":digest((directory/"process-result.json").read_bytes()),
            "runtime_custody_sha256":digest((directory/"runtime-custody.json").read_bytes()),
            "cases":results,"verifier_sha256":digest(Path(__file__).read_bytes()),
            "engine_summary_sha256":digest((directory/"native-summary.json").read_bytes()),
            "native_receipts_sha256":digest((directory/"native-receipts.jsonl").read_bytes())}


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory",type=Path)
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    result=verify(args.directory)
    destination=args.output or args.directory/"verified-admission-receipts.json"
    if destination.exists():
        raise ValueError("Refusing to overwrite an existing verification result")
    destination.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({"passed":result["passed"],"checks":result["checks"],"cases":len(result["cases"]),
                      "failures":result["failures"][:20],"output":str(destination)},indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError,KeyError,OSError) as exc:
        print(f"Readback verification refused: {exc}",file=sys.stderr)
        raise SystemExit(2)
