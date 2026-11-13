#!/usr/bin/env python3
"""Request-level, receipt-bound audit of frozen model/native evidence.

No inference, training, compiler repair, drawing or changes to native harness.
A verified native packet is necessary but never makes malformed predictions pass.
"""
from __future__ import annotations
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re
import struct
import statistics


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path):
    return json.loads(path.read_text())


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def strict_completion(raw: str):
    def pairs(items):
        out = {}
        for key, value in items:
            if key in out:
                raise ValueError("duplicate JSON key")
            out[key] = value
        return out
    def bad_constant(value):
        raise ValueError("non-JSON constant " + value)
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=bad_constant)


def build_aliases(original: Path, output: Path, mapping: Path) -> dict:
    """Alias fixture IDs only; preserve model programs, geometry and rejections."""
    if output.exists() or mapping.exists():
        raise FileExistsError("Refusing to overwrite existing alias evidence")
    source = load(original)
    if not isinstance(source, dict) or not isinstance(source.get("cases"), list):
        raise ValueError("Expected exported case manifest")
    cases = source["cases"]
    if not 1 <= len(cases) <= 1024:
        raise ValueError("Native pilot accepts 1–1024 cases")
    original_ids, aliases, records = set(), set(), []
    for index, original_case in enumerate(cases):
        case = dict(original_case)
        old = case.get("id", "")
        theme, seed = case.get("theme"), case.get("seed")
        if not isinstance(old, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", old) or old in original_ids:
            raise ValueError("Original ID missing, unsafe or duplicated")
        if not isinstance(theme, str) or not re.fullmatch(r"[a-z]{1,16}", theme):
            raise ValueError("Theme cannot form inspectable safe alias")
        if type(seed) is not int or not 0 <= seed <= 2**31-1:
            raise ValueError("Invalid host seed")
        new = f"m{index:04d}-{theme}-s{seed}"
        if len(new) > 38 or new in aliases:
            raise ValueError("Alias exceeds Workbench save-name budget or collides")
        if not isinstance(case.get("operations"), list) or not case["operations"]:
            raise ValueError("Missing original compiled operations")
        if hashlib.sha256(canonical(case["operations"]).encode()).hexdigest() != case.get("operations_sha256"):
            raise ValueError("Compiled operation digest differs from source")
        if strict_completion(case["raw_completion"]) != case["program"]:
            raise ValueError("Raw completion differs from compiled program; refusing repair")
        original_ids.add(old)
        aliases.add(new)
        case["id"] = new
        case["original_case_id"] = old
        records.append({"original_case_id": old, "replay_case_id": new,
                        "prediction_id": case["prediction_id"], "seed": seed,
                        "operations_sha256": case["operations_sha256"],
                        "program_sha256": case["program_sha256"]})
        cases[index] = case
    # Preserve source manifest metadata and excluded predictions byte-for-byte as values.
    output.write_text(json.dumps(source, indent=2) + "\n")
    receipt = {"schema_version": 1, "original_manifest_sha256": sha(original),
               "replay_manifest_sha256": sha(output), "cases": records,
               "change_scope": "case IDs only; no new native execution, completion repair or geometry change"}
    mapping.write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt


def audit(prediction_paths: list[Path], original: Path, replay: Path,
          mapping: Path, packet: Path) -> dict:
    predictions = {}
    cohort = {}
    group_ids = defaultdict(set)
    for path in prediction_paths:
        obj = load(path)
        if not isinstance(obj, dict) or not isinstance(obj.get("records"), list):
            raise ValueError(f"Not a prediction record set: {path}")
        for row in obj["records"]:
            rid = row["id"]
            if rid in predictions:
                raise ValueError("Duplicate original request ID: " + rid)
            predictions[rid] = row
            cohort[rid] = path.stem
            group_ids[path.stem].add(row["group_id"])
    if not predictions:
        raise ValueError("No original predictions")
    source, alias_cases, ids = load(original), load(replay)["cases"], load(mapping)
    original_cases = source["cases"]
    original_by_id = {c["id"]: c for c in original_cases}
    alias_by_id = {c["id"]: c for c in alias_cases}
    if len(original_by_id) != len(original_cases) or len(alias_by_id) != len(alias_cases):
        raise ValueError("Duplicate native case IDs")
    if ids.get("original_manifest_sha256") != sha(original):
        raise ValueError("Original exported manifest changed after alias binding")
    custody = load(packet / "runtime-custody.json")
    if custody.get("normalized_manifest_sha256") != sha(packet / "input-cases.json"):
        raise ValueError("Native runner normalized manifest custody failed")
    if replay != packet / "input-cases.json" and ids.get("replay_manifest_sha256") != sha(replay):
        raise ValueError("Pre-run replay manifest no longer matches the alias map")
    entries = ids["cases"]
    if len(entries) != len(alias_cases) or len(entries) != len(original_cases):
        raise ValueError("Alias mapping is incomplete")
    seen_old, seen_alias = set(), set()
    seeds = defaultdict(set)
    by_request = defaultdict(list)
    for item in entries:
        old, new = item["original_case_id"], item["replay_case_id"]
        if old in seen_old or new in seen_alias or old not in original_by_id or new not in alias_by_id:
            raise ValueError("Missing or duplicate alias witness")
        seen_old.add(old); seen_alias.add(new)
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,38}", new):
            raise ValueError("Replay case ID exceeds slm-pilot- save-name budget")
        before, after = original_by_id[old], alias_by_id[new]
        if {**before, "id": new, "original_case_id": old} != after:
            raise ValueError("Alias changes model payload, program or geometry: " + old)
        for k in ("prediction_id", "seed", "operations_sha256", "program_sha256"):
            if item[k] != before[k]:
                raise ValueError("Alias map differs from source: " + k)
        rid = before["prediction_id"]
        if rid not in predictions:
            raise ValueError("Native case has unknown original request: " + rid)
        row = predictions[rid]
        if before["raw_completion"] != row["completion"] or before["theme"] != row["theme"] or before["prompt"] != row["prompt"]:
            raise ValueError("Native case not bound to exact raw request")
        if strict_completion(row["completion"]) != before["program"]:
            raise ValueError("Compiler input differs from raw first-pass prediction")
        if hashlib.sha256(canonical(before["operations"]).encode()).hexdigest() != before["operations_sha256"]:
            raise ValueError("Operation digest mismatch")
        seeds[rid].add(before["seed"])
        by_request[rid].append(new)
    excluded = {r["id"] for r in source["excluded_predictions"]}
    if len(excluded) != len(source["excluded_predictions"]):
        raise ValueError("Duplicate rejected model requests")
    admitted = set(by_request)
    if admitted & excluded or admitted | excluded != set(predictions):
        raise ValueError("Original request denominator not closed")
    for rid, row in predictions.items():
        raw_valid = False
        try:
            raw_valid = isinstance(strict_completion(row["completion"]), dict)
        except (ValueError, TypeError, json.JSONDecodeError):
            pass
        accepted = row.get("first_pass_accepted") is True
        if accepted != (rid in admitted):
            raise ValueError("Manifest hides a first-pass failure or unqualified admission: " + rid)
        if accepted and not (raw_valid and row.get("eos_emitted") is True and row.get("json_valid") is True and row.get("program_valid") is True):
            raise ValueError("Invalid/unterminated reply credited as successful: " + rid)
        if accepted:
            expected = strict_completion(row["expected_completion"])
            observed = strict_completion(row["completion"])
            if row.get("theme_field_correct") is not (observed["theme"] == row["theme"]):
                raise ValueError("Theme field flag contradicts raw completion: " + rid)
            if row.get("primary_motif_correct") is not (observed["layers"][0]["motif"] == expected["layers"][0]["motif"]):
                raise ValueError("Primary motif flag contradicts raw completion: " + rid)
        if accepted and len(seeds[rid]) != len(by_request[rid]):
            raise ValueError("Duplicate host seed does not constitute another native replay")
    seed_sets = {tuple(sorted(v)) for v in seeds.values()}
    if len(seed_sets) != 1:
        raise ValueError("Accepted requests have unmatched host seed coverage")
    # Consume exact independent verification, not the engine's success flag alone.
    verified = load(packet / "verified-admission-receipts.json")
    gates = verified.get("global_gates", {})
    if verified.get("passed") is not True or len(gates) < 15 or not all(v is True for v in gates.values()):
        raise ValueError("Native packet lacks globally passing independent gates")
    actual = load(packet / "input-cases.json")["cases"]
    if actual != alias_cases:
        raise ValueError("Executed native manifest differs from ID-aliased geometry")
    rows = verified["cases"]
    if len(rows) != len(alias_cases) or {r["id"] for r in rows} != set(alias_by_id):
        raise ValueError("Independent native receipt denominator does not close")
    passed_native = set()
    for row in rows:
        case = alias_by_id[row["id"]]
        if row.get("operations_sha256") != case["operations_sha256"]:
            raise ValueError("Native operations digest differs from submitted program")
        if not (row.get("success") is True and row.get("outside_focus_violations") == 0
                and row.get("unexpected_material_cells") == 0 and row.get("acknowledged_cells", 0) > 0):
            continue
        if sha(packet / row["png"]) != row["image_sha256"] or sha(packet / row["raw_materials"]) != row["readback_sha256"]:
            raise ValueError("Native image/readback custody differs from receipt")
        passed_native.add(row["id"])
    # Native pixels quantify occupancy/seed diversity, not theme recognizability.
    geo = defaultdict(list)
    all_pairs = []
    for rid, names in by_request.items():
        group = []
        for name in names:
            case = alias_by_id[name]
            data = (packet / (name + ".materials.i32le")).read_bytes()
            width, height = case["width"], case["height"]
            if len(data) != width * height * 4:
                raise ValueError("Unexpected raw native crop byte size")
            occupied = {i for i, value in enumerate(struct.iter_unpack("<i", data)) if value[0] != 0}
            group.append((case["seed"], occupied, len(occupied) / (width * height)))
        if len(group) == 2 and all(name in passed_native for name in names):
            group.sort(key=lambda item: item[0])
            overlap = len(group[0][1] & group[1][1]) / len(group[0][1] | group[1][1])
            datum = {"prediction_id": rid, "theme": predictions[rid]["theme"], "seed_jaccard": round(overlap, 6),
                     "occupancy": [round(group[0][2], 6), round(group[1][2], 6)]}
            geo[predictions[rid]["theme"]].append(datum)
            all_pairs.append(datum)
    # Native request yield: every required host-seed replay of the original request passes.
    native_pass = {rid for rid, names in by_request.items() if all(n in passed_native for n in names)}
    symbolic = {rid for rid in native_pass if predictions[rid].get("theme_field_correct") is True
                and predictions[rid].get("primary_motif_correct") is True}
    breakdown = {}
    for name in sorted(set(cohort.values())):
        req = {rid for rid in predictions if cohort[rid] == name}
        breakdown[name] = {"original_requests": len(req), "structural_groups": len(group_ids[name]),
                           "first_pass_accepted": len(req & admitted),
                           "native_request_yield": len(req & native_pass),
                           "symbolic_theme_primary_joint": len(req & symbolic)}
    failures = [{"prediction_id": rid, "cohort": cohort[rid], "theme": predictions[rid]["theme"],
                 "failure": "first-pass-invalid" if rid in excluded else
                   "native-replay" if rid not in native_pass else "symbolic-theme-or-motif"}
                for rid in predictions if rid not in symbolic]
    return {"schema_version": 1, "qualification": "Existing pinned Linux headless material pilot; audit does not execute Godot or assess recognition",
            "source_sha256": {"original_native_manifest": sha(original), "aliased_native_manifest": sha(replay),
                              "alias_map": sha(mapping), "independent_native_receipts": sha(packet / "verified-admission-receipts.json"),
                              **{p.name: sha(p) for p in prediction_paths}},
            "native_runtime": verified["runtime"], "native_global_gates": len(gates),
            "alias_pre_run_manifest_recovered": ids.get("replay_manifest_sha256") == sha(replay),
            "request_count": len(predictions), "first_pass_accepted": len(admitted),
            "native_request_yield": len(native_pass), "native_seed_replays": len(rows),
            "native_seed_replays_passed": len(passed_native),
            "symbolic_theme_primary_joint": len(symbolic), "seed_set": list(next(iter(seed_sets))),
            "cohorts": breakdown, "failures": failures,
            "geometry_only_variety": {"pairs": len(all_pairs),
                "mean_seed_jaccard": round(statistics.mean(x["seed_jaccard"] for x in all_pairs), 6) if all_pairs else None,
                "by_theme": {theme: {"requests": len(entries),
                    "median_seed_jaccard": round(statistics.median(e["seed_jaccard"] for e in entries), 6),
                    "median_occupancy": round(statistics.median(d for e in entries for d in e["occupancy"]), 6)}
                    for theme, entries in sorted(geo.items())},
                "interpretation": "Exact material-ID overlap across two host seeds; lower overlap means different geometry, not higher aesthetic quality"},
            "acceptance_targets":
                {"raw_schema_pct": 95, "positive_request_native_yield_pct": 98,
                 "recognition_pct": 80, "zero_host_violations": True},
            "go_no_go": "HOLD", "recognition_assessed": False, "final_split_used": False,
            "new_native_execution": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    alias = sub.add_parser("alias", help="create <=38-char ID-only replay manifest and original ID map")
    alias.add_argument("--original", required=True, type=Path)
    alias.add_argument("--output", required=True, type=Path)
    alias.add_argument("--mapping", required=True, type=Path)
    check = sub.add_parser("audit", help="audit exact model requests against completed native receipt packet")
    check.add_argument("--predictions", required=True, type=Path, nargs="+")
    check.add_argument("--original", required=True, type=Path)
    check.add_argument("--replay", required=True, type=Path)
    check.add_argument("--mapping", required=True, type=Path)
    check.add_argument("--packet", required=True, type=Path)
    check.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.command == "alias":
        result = build_aliases(args.original, args.output, args.mapping)
        print(json.dumps({"aliased_cases": len(result["cases"]), "mapping_sha256": sha(args.mapping)}, indent=2))
    else:
        if args.output.exists():
            raise FileExistsError("Refusing to overwrite completed audit")
        result = audit(args.predictions, args.original, args.replay, args.mapping, args.packet)
        args.output.write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps({k: result[k] for k in ("request_count", "first_pass_accepted", "native_request_yield", "native_seed_replays_passed", "go_no_go")}, indent=2))


if __name__ == "__main__":
    main()
