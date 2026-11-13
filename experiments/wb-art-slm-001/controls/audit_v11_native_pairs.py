"""Audit 32 executed v1/v1.1 coral native cases, refusing incomplete receipts.

Reads real native material bytes, never compiler-rendered projections. The
standard independent native verifier must first pass every global gate.
The result is not a graphical, Windows, or human-aesthetic acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

GATES = frozenset((
    "engine_passed", "process_completed", "runtime_unchanged", "harness_unchanged",
    "input_unchanged", "input_digest_matches", "native_artifact_matches",
    "harness_digest_matches", "runtime_pins_match", "complete_manifest",
    "all_engine_assertions_passed", "mandatory_invariant_assertions_present",
    "protection_native_readback_exact", "stop_native_readback_exact",
    "representative_history_and_reopen",
))


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def analyze(pairs_path: Path, native: Path, *, source_sha: str, native_sha: str):
    """Return per-case spatial metrics only after exact native receipt admission."""
    require(re.fullmatch(r"[0-9a-f]{40}", source_sha), "source SHA must be pinned")
    require(re.fullmatch(r"[0-9a-f]{64}", native_sha), "native SHA must be pinned")
    pairs = read(pairs_path)
    require(pairs.get("required_native_history_mode") == "each", "all cases need history each")
    require(pairs.get("purpose") == "not-yet-executed-v1-v11-coral-native-pair", "wrong paired fixture")
    require(pairs.get("parent_compiler_sha256") ==
            "a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb",
            "historical v1 compiler identity changed")
    require(pairs.get("candidate_compiler_version") == "wb-art-slm-001/1.1.0-coral-spread",
            "unqualified candidate compiler identity")
    cases = pairs.get("cases")
    aliases = pairs.get("aliases")
    require(isinstance(cases, list) and len(cases) == 32, "expected exactly 32 cases")
    require(isinstance(aliases, dict) and len(aliases) == 16, "expected 16 original aliases")
    by_id = {c["id"]: c for c in cases}
    require(len(by_id) == 32, "duplicate expected case IDs")
    verified = read(native / "verified-admission-receipts.json")
    require(verified.get("passed") is True and not verified.get("failures"), "native verifier failed")
    gates = verified.get("global_gates")
    require(isinstance(gates, dict) and set(gates) == GATES and all(v is True for v in gates.values()),
            "native global gates incomplete or failed")
    require(verified.get("runtime", {}).get("source_commit") == source_sha and
            verified["runtime"].get("native_sha256") == native_sha, "native source/ABI mismatch")
    for filename, field in (("process-result.json", "process_result_sha256"),
                            ("runtime-custody.json", "runtime_custody_sha256"),
                            ("native-summary.json", "engine_summary_sha256"),
                            ("native-receipts.jsonl", "native_receipts_sha256")):
        require(digest((native / filename).read_bytes()) == verified.get(field),
                f"verified receipt custody changed: {filename}")
    custody = read(native / "runtime-custody.json")
    require(custody.get("source_commit") == source_sha and custody.get("native_sha256") == native_sha,
            "runtime custody and pinned source disagree")
    normal = read(native / "input-cases.json").get("cases")
    require(isinstance(normal, list) and len(normal) == 32 and normal == cases,
            "executed native inputs differ from frozen pair manifest")
    require(digest((native / "input-cases.json").read_bytes()) == custody.get("normalized_manifest_sha256"),
            "input custody digest disagrees")
    proc = read(native / "process-result.json")
    require(proc.get("exit_code") == 0 and proc.get("timed_out") is False and
            all(proc.get(k) is True for k in ("input_unchanged", "harness_unchanged", "runtime_unchanged")),
            "process not completed with unchanged custody")
    summary = read(native / "native-summary.json")
    require(summary.get("passed") is True and summary.get("cases_completed") == 32 and
            summary.get("cases_requested") == 32, "native run not complete")
    actual = {c["id"]: c for c in summary.get("cases", [])}
    receipts = {c["id"]: c for c in verified.get("cases", [])}
    require(len(actual) == len(receipts) == 32 and set(actual) == set(receipts) == set(by_id),
            "engine/verifier/native case identifiers differ")
    metrics = {}
    for case_id, expected in by_id.items():
        require(re.fullmatch(r"c1[01]-coral-v[0-7]-s(?:17|73)", case_id) and len(case_id) <= 38,
                "fixture ID exceeds Workbench save budget")
        require(expected.get("width") == expected.get("height") == 96 and expected.get("theme") == "coral",
                "unexpected dimensions or theme in frozen pair")
        match = re.fullmatch(r"c1[01]-coral-v([0-7])-s(17|73)", case_id)
        require(match is not None and expected.get("seed") == int(match.group(2)),
                "native case seed differs from ID")
        ops = expected["operations"]
        require(isinstance(ops, list) and ops and all(op.get("material") == 58 for op in ops),
                "unexpected material or empty operation plan")
        ops_hash = digest(json.dumps(ops, sort_keys=True, separators=(",", ":"), allow_nan=False).encode())
        require(expected.get("operations_sha256") == ops_hash, "manifest operations not bound")
        engine, receipt = actual[case_id], receipts[case_id]
        require(engine.get("passed") is True and receipt.get("success") is True and
                engine.get("terminal", {}).get("status") == "completed", "incomplete native case")
        require(engine.get("operations_sha256") == receipt.get("operations_sha256") == ops_hash and
                engine.get("program_sha256") == expected.get("program_sha256"),
                "executed program/operations differ")
        require(engine.get("history_and_reopen_checked") is True and
                receipt.get("history_and_reopen_checked") is True, "Undo/Redo/save/reopen not checked per case")
        require(receipt.get("outside_focus_violations") == receipt.get("unexpected_material_cells") == 0 and
                receipt.get("changed_cells", 0) > 0 and receipt.get("acknowledged_cells", 0) > 0,
                "native material/protection violation or zero work")
        require(receipt["raw_materials"] == f"{case_id}.materials.i32le" and
                receipt["png"] == f"{case_id}.png",
                "native output path not a canonical local basename")
        raw = native / receipt["raw_materials"]
        png = native / receipt["png"]
        values = raw.read_bytes()
        require(len(values) == 96 * 96 * 4 and
                digest(values) == receipt.get("readback_sha256") == engine.get("crop_i32le_sha256"),
                "stored native material readback mismatch")
        image = png.read_bytes()
        require(len(image) < 1_000_000 and digest(image) == receipt.get("image_sha256"),
                "native visualization changed")
        rows = struct.unpack("<9216i", values)
        require(set(rows) <= {0, 58}, "unexpected native stored material")
        thirds = [sum(v == 58 for v in rows[k*3072:(k+1)*3072]) for k in range(3)]
        filled = sum(thirds)
        require(filled == engine.get("filled_cells") == receipt.get("filled_cells") and filled > 0,
                "native filled-cell count disagrees")
        metrics[case_id] = {"top_middle_bottom_cells": thirds,
                            "filled_cells": filled, "top_fraction": round(thirds[0] / filled, 6),
                            "readback_sha256": digest(values), "image_sha256": digest(image)}
    comparisons = []
    for parent_id, alias in sorted(aliases.items()):
        match = re.fullmatch(r"reference-coral-v([0-7])-s(17|73)", parent_id)
        require(match is not None, "invalid original ID alias")
        require(set(alias) == {"c10", "c11"}, "missing compiler pair")
        v, seed = map(int, match.groups())
        before, after = f"c10-coral-v{v}-s{seed}", f"c11-coral-v{v}-s{seed}"
        require(alias["c10"]["case_id"] == before and alias["c11"]["case_id"] == after,
                "alias was remapped")
        require(alias["c10"]["operations_sha256"] == by_id[before]["operations_sha256"] and
                alias["c11"]["operations_sha256"] == by_id[after]["operations_sha256"],
                "compiler operation identity changed")
        require(alias["c10"]["compiler_version"] == "wb-art-slm-001/1.0.0" and
                alias["c11"]["compiler_version"] == pairs.get("candidate_compiler_version"),
                "compiler version identities differ")
        require(by_id[before]["program_sha256"] == by_id[after]["program_sha256"] and
                by_id[before]["seed"] == by_id[after]["seed"], "paired program/seed differs")
        require(by_id[before]["operations_sha256"] != by_id[after]["operations_sha256"],
                "candidate generated no geometry difference")
        b, a = metrics[before], metrics[after]
        comparisons.append({"original_id": parent_id, "v1_case_id": before, "v11_case_id": after,
                            "v1_top_fraction": b["top_fraction"], "v11_top_fraction": a["top_fraction"],
                            "v11_minus_v1_top_fraction": round(a["top_fraction"] - b["top_fraction"], 6),
                            "v1_cells": b["filled_cells"], "v11_cells": a["filled_cells"]})
    require(len(comparisons) == 16, "pair count incomplete")
    return {"status": "verified-native-material-pairs-not-visual-acceptance", "source": source_sha,
            "native_sha256": native_sha, "manifest_sha256": digest(pairs_path.read_bytes()),
            "verified_receipts_sha256": digest((native / "verified-admission-receipts.json").read_bytes()),
            "cases": metrics, "comparisons": comparisons,
            "mean_v1_top_fraction": round(sum(c["v1_top_fraction"] for c in comparisons)/16, 6),
            "mean_v11_top_fraction": round(sum(c["v11_top_fraction"] for c in comparisons)/16, 6),
            "native_cases": 32, "native_pairs": 16, "human_accepted": False, "windows_qualified": False}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--pairs", type=Path, required=True)
    p.add_argument("--native", type=Path, required=True)
    p.add_argument("--source-sha", required=True)
    p.add_argument("--native-sha", required=True)
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()
    result = analyze(args.pairs, args.native, source_sha=args.source_sha, native_sha=args.native_sha)
    with args.out.open("x", encoding="utf-8") as out:
        json.dump(result, out, indent=2, sort_keys=True)
        out.write("\n")
    print(json.dumps({"native_pairs": result["native_pairs"],
                      "mean_v1_top_fraction": result["mean_v1_top_fraction"],
                      "mean_v11_top_fraction": result["mean_v11_top_fraction"],
                      "human_accepted": False}))


if __name__ == "__main__":
    main()
