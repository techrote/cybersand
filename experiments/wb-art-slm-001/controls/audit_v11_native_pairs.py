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



def replay_native_rows(native: Path, cases: dict, summary: dict) -> dict:
    """Reconstruct real 512-square native Worlds from original receipt rows.

    A success-shaped verifier JSON is not sufficient evidence of executed
    native work. Readback must form a coherent zero-tick cell transition chain
    and match the independently captured World and stored material crop.
    """
    receipts = {case_id: [] for case_id in cases}
    captures = {case_id: [] for case_id in cases}
    with (native / "native-receipts.jsonl").open(encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, 1):
            require(bool(line.strip()), f"blank native receipt at line {line_no}")
            try:
                event = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"invalid native JSONL at line {line_no}") from exc
            require(isinstance(event, dict), "native receipt event must be an object")
            cid = event.get("case")
            if cid not in cases:
                continue  # Unrelated mandatory Stop/protection invariant events.
            require(("receipt" in event) != ("capture" in event),
                    f"{cid}: ambiguous native event")
            if "receipt" in event:
                receipts[cid].append(event["receipt"])
            else:
                captures[cid].append(event["capture"])
    chains = {}
    for cid, expected in cases.items():
        require(bool(receipts[cid]), f"{cid}: missing raw native draw receipt")
        world = bytearray(512 * 512 * 4)
        checked = changed = unchanged = 0
        for index, receipt in enumerate(receipts[cid]):
            require(isinstance(receipt, dict) and
                    receipt.get("backend") == "CyberNativeCellWorld" and
                    receipt.get("status") == "completed" and
                    receipt.get("tick") == 0 and
                    isinstance(receipt.get("before_source"), dict) and
                    receipt["before_source"].get("tick") == 0,
                    f"{cid}: invalid native backend, epoch or completion at receipt {index}")
            rows = receipt.get("readback")
            require(isinstance(rows, list) and bool(rows) and
                    receipt.get("checked") == receipt.get("confirmed") == len(rows) and
                    receipt.get("excluded") == receipt.get("refused") == 0,
                    f"{cid}: missing, partial or excluded native readback")
            delta = 0
            for row in rows:
                require(isinstance(row, list) and len(row) == 4 and
                        all(type(n) is int for n in row),
                        f"{cid}: malformed native cell row")
                x, y, before, after = row
                require(0 <= x < expected["width"] and
                        0 <= y < expected["height"] and before in (0, 58) and
                        after in (0, 58), f"{cid}: unauthorized native cell")
                position = (y * 512 + x) * 4
                require(struct.unpack_from("<i", world, position)[0] == before,
                        f"{cid}: discontinuous native before-state")
                struct.pack_into("<i", world, position, after)
                delta += before != after
            require(receipt.get("changed") == delta,
                    f"{cid}: native changed count differs from rows")
            checked += len(rows)
            changed += delta
            unchanged += len(rows) - delta
        engine = summary[cid]
        terminal = engine.get("terminal", {})
        require(checked > 0 and changed > 0 and
                terminal.get("checked") == checked and
                terminal.get("changed") == changed and
                terminal.get("unchanged") == unchanged,
                f"{cid}: engine terminal counters differ from raw native receipts")
        whole_sha = digest(world)
        require(engine.get("whole_world_i32le_sha256") == whole_sha,
                f"{cid}: complete native World hash differs from receipt chain")
        # In --history each mode the frozen native harness captures the World
        # after draw, Undo, Redo and save/reopen, in that exact order. A boolean
        # summary flag is not proof that the later World states were checked.
        stages = ("draw", "undo", "redo", "save/reopen")
        expected_hashes = (whole_sha, digest(bytes(512 * 512 * 4)),
                           whole_sha, whole_sha)
        require(len(captures[cid]) == len(stages),
                f"{cid}: missing or extra native history captures")
        for stage, capture, expected_sha in zip(stages, captures[cid], expected_hashes):
            require(isinstance(capture, dict) and
                    capture.get("backend") == "CyberNativeCellWorld" and
                    capture.get("status") == "completed" and
                    capture.get("region_xywh") == [0, 0, 512, 512] and
                    capture.get("materials_i32le_sha256") == expected_sha,
                    f"{cid}: {stage} native history capture differs")
        crop = b"".join(world[y * 512 * 4:(y * 512 + expected["width"]) * 4]
                        for y in range(expected["height"]))
        require(engine.get("raw_materials") == f"{cid}.materials.i32le" and
                (native / engine["raw_materials"]).read_bytes() == crop,
                f"{cid}: stored native crop disagrees with receipt chain")
        require(crop.count(b"\x3a\x00\x00\x00") ==
                engine.get("filled_cells"), f"{cid}: filled-cell count differs")
        chains[cid] = {"native_receipts": len(receipts[cid]),
                       "history_captures": len(captures[cid]),
                       "checked_cells": checked, "changed_cells": changed,
                       "whole_world_sha256": whole_sha}
    return chains


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
    raw_chains = replay_native_rows(native, by_id, actual)
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
                            "readback_sha256": digest(values), "image_sha256": digest(image),
                            "raw_native_chain": raw_chains[case_id]}
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
            "native_cases": 32, "native_pairs": 16, "raw_native_chains_replayed": 32,
            "human_accepted": False, "windows_qualified": False}


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
