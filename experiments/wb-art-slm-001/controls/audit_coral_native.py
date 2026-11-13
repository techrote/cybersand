"""Verify and quantify frozen native v1 coral readbacks (not candidate execution)."""
import argparse
import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path

SOURCE = "90719c72b9fcf90593fb7878354051ad601b47fd"
NATIVE = "3a8b0b2cd04f09054426842f978e2421aad4016aae03dec91ed527ff50b953cd"
TEACHER_ZIP = "2381736839bfca8ad6b4563a1c77698140438ef39ee8f0a6529f23cae4f1f62b"
REQUIRED_GATES = frozenset(("engine_passed", "process_completed", "runtime_unchanged",
    "harness_unchanged", "input_unchanged", "input_digest_matches", "native_artifact_matches",
    "harness_digest_matches", "runtime_pins_match", "complete_manifest", "all_engine_assertions_passed",
    "mandatory_invariant_assertions_present", "protection_native_readback_exact",
    "stop_native_readback_exact", "representative_history_and_reopen"))


def sha(data):
    return hashlib.sha256(data).hexdigest()


def analyze(path):
    if sha(path.read_bytes()) != TEACHER_ZIP:
        raise ValueError("recovered native teacher ZIP does not match frozen SHA-256")
    selected = {}
    with zipfile.ZipFile(path) as z:
        for name in sorted(z.namelist()):
            if not re.fullmatch(r"native_full_\d+/verified-admission-receipts.json", name):
                continue
            folder = name.rsplit("/", 1)[0] + "/"
            verified = json.loads(z.read(name))
            gates = verified.get("global_gates", {})
            if (verified.get("passed") is not True or verified.get("failures") or
                    set(gates) != REQUIRED_GATES or not all(gates.values()) or
                    verified["runtime"].get("source_commit") != SOURCE or
                    verified["runtime"].get("native_sha256") != NATIVE):
                raise ValueError(f"unqualified native evidence packet: {folder}")
            summary = json.loads(z.read(folder + "native-summary.json"))
            by_id = {c["id"]: c for c in summary["cases"]}
            if not summary.get("passed") or len(by_id) != len(verified["cases"]):
                raise ValueError("missing or duplicate original native summary")
            for case in verified["cases"]:
                cid = case["id"]
                if not re.fullmatch(r"coral-v[0-7]-m0-s(?:17|73)", cid):
                    continue
                if cid in selected or case.get("success") is not True or case["outside_focus_violations"] or case["unexpected_material_cells"] or case["acknowledged_cells"] <= 0:
                    raise ValueError(f"invalid or duplicate native case: {cid}")
                original = by_id[cid]
                if original["operations_sha256"] != case["operations_sha256"] or (original["width"], original["height"]) != (96, 96):
                    raise ValueError(f"original operation/size mismatch: {cid}")
                raw_name = folder + case["raw_materials"]
                image_name = folder + case["png"]
                if z.getinfo(raw_name).file_size != 96*96*4 or z.getinfo(image_name).file_size > 1000000:
                    raise ValueError(f"unexpected native evidence size: {cid}")
                raw, image = z.read(raw_name), z.read(image_name)
                if sha(raw) != case["readback_sha256"] or sha(image) != case["image_sha256"]:
                    raise ValueError(f"altered original native image/readback: {cid}")
                cells = struct.unpack("<9216i", raw)
                if not set(cells) <= {0, 58}:
                    raise ValueError(f"unexpected stored native material: {cid}")
                thirds = [sum(v == 58 for v in cells[i*3072:(i+1)*3072]) for i in range(3)]
                filled = sum(thirds)
                if filled <= 0 or filled != case["filled_cells"]:
                    raise ValueError(f"native receipt and readback disagree: {cid}")
                selected[cid] = {"case_id": cid, "operation_sha256": case["operations_sha256"],
                    "readback_sha256": sha(raw), "top_middle_bottom": thirds,
                    "top_fraction": round(thirds[0]/filled, 6),
                    "vertical_coverage": round(sum(any(cells[y*96+x] == 58 for x in range(96))
                        for y in range(96))/96, 6)}
    expected = {f"coral-v{v}-m0-s{s}" for v in range(8) for s in (17, 73)}
    if set(selected) != expected:
        raise ValueError("incomplete native coral v1 pair baseline")
    return {"type": "historical-native-v1-only", "source": SOURCE, "native_sha256": NATIVE,
        "teacher_zip_sha256": TEACHER_ZIP, "cases": [selected[c] for c in sorted(selected)],
        "case_count": 16, "mean_top_fraction": round(sum(c["top_fraction"] for c in selected.values())/16, 6),
        "nonborder_single_layer_top_empty": sum(selected[f"coral-v{v}-m0-s{s}"]["top_fraction"] == 0
            for v in (0, 1, 2) for s in (17, 73)),
        "candidate_native_executed": False, "human_acceptance": False}


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--teacher-zip", required=True, type=Path)
    p.add_argument("--out", required=True, type=Path)
    a = p.parse_args()
    result = analyze(a.teacher_zip)
    with a.out.open("x") as f:
        json.dump(result, f, indent=2, sort_keys=True)
        f.write("\n")
    print(json.dumps({"cases": result["case_count"],
        "mean_top_fraction": result["mean_top_fraction"],
        "nonborder_single_layer_top_empty": result["nonborder_single_layer_top_empty"]}))
