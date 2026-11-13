"""Independently verify actual native receipts, raw cells and original PNGs.

Salvages #567's receipt-chain reducer; new checks bind the new compiler, each
actual operation in order, fresh-World replay and family structural invariants.
No image is generated here, and a compiler plan never counts as native evidence.
"""
from __future__ import annotations

import hashlib
import json
import re
import struct
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from compiler import compile_program, rasterize_operations, verify_structure
if __package__:
    from .runtime import canonical, digest, GODOT_VERSION
else:
    from runtime import canonical, digest, GODOT_VERSION

WORLD_SIDE = 512
FOREGROUND = bytes((232, 226, 205))
BACKGROUND = bytes((13, 21, 28))


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def safe_path(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or not relative or Path(relative).is_absolute():
        raise ValueError("Evidence path must be relative")
    result = (root / relative).resolve()
    if not result.is_relative_to(root.resolve()) or not result.is_file():
        raise ValueError("Evidence file missing or outside packet: " + relative)
    return result


def material_bytes(values: list[int]) -> bytes:
    return struct.pack("<" + "i" * len(values), *values)


def capture_matches(rows: list[dict], expected_hash: str, region: list[int], source: dict | None = None) -> bool:
    if len(rows) != 1:
        return False
    row = rows[0]
    return (row.get("backend") == "CyberNativeCellWorld" and row.get("kind") == "capture"
            and row.get("status") == row.get("termination") == "completed"
            and row.get("tick") == 0 and row.get("applied") == row.get("changed") == 0
            and row.get("region_xywh") == region
            and row.get("checked") == row.get("requested_cells") == region[2] * region[3]
            and row.get("materials_i32le_sha256") == expected_hash
            and (source is None or all(row.get(key) == source.get(key) for key in ("generation", "revision", "tick"))))


def verified_receipt_file(directory: Path, identifier: str, expected: dict) -> Path:
    path = safe_path(directory, identifier + ".receipt.json")
    if load(path) != expected:
        raise ValueError("Per-case receipt file differs from independently verified engine summary")
    return path


def operation_points(operations: list[dict]):
    """Independent exact sequence for the foundation's rectangle/pixel ABI."""
    work = 0
    for op in operations:
        material = op["material"]
        if type(material) is not int or material not in (0, 58):
            raise ValueError("Pilot material outside host-owned Empty/Hard Wall palette")
        if op["shape"] == "rectangle":
            for y in range(op["y0"], op["y1"] + 1):
                for x in range(op["x0"], op["x1"] + 1):
                    work += 1
                    if work > 100000:
                        raise ValueError("Native verifier work budget exceeded")
                    yield x, y, material
        elif op["shape"] == "pixels":
            for x, y in op["points"]:
                work += 1
                if work > 100000:
                    raise ValueError("Native verifier work budget exceeded")
                yield x, y, material
        else:
            raise ValueError("New operation shape requires a versioned independent receipt verifier")


def reduce_receipts(receipts: list[dict], operations: list[dict], width: int, height: int) -> tuple[list[int], dict]:
    """Reconstruct exclusively from actual native before/after application rows."""
    if not receipts:
        raise ValueError("No actual native draw receipts")
    expected = iter(operation_points(operations))
    world = [0] * (WORLD_SIDE * WORLD_SIDE)
    totals = {key: 0 for key in ("checked", "changed", "unchanged", "excluded", "refused")}
    previous_source = None
    for receipt in receipts:
        if receipt.get("backend") != "CyberNativeCellWorld" or receipt.get("status") != "completed":
            raise ValueError("Native receipt backend/completion invalid")
        for key in ("requested", "confirmed", "checked", "changed", "unchanged", "excluded", "refused",
                    "generation", "revision", "tick"):
            if type(receipt.get(key)) is not int or receipt[key] < 0:
                raise ValueError("Native counter/source fields must be nonnegative integers")
        before_source = receipt.get("before_source", {})
        if (set(before_source) != {"generation", "revision", "tick"}
                or any(type(value) is not int or value < 0 for value in before_source.values())
                or receipt["generation"] != before_source["generation"]
                or receipt["revision"] < before_source["revision"]):
            raise ValueError("Native before/after source identity invalid")
        if receipt.get("tick") != 0 or before_source.get("tick") != 0:
            raise ValueError("Paused fixture received a simulation tick")
        if previous_source is not None and before_source != previous_source:
            raise ValueError("Native generation/revision chain is broken")
        previous_source = {key: receipt.get(key) for key in ("generation", "revision", "tick")}
        rows = receipt.get("readback")
        if not isinstance(rows, list) or not 0 < len(rows) <= 4096:
            raise ValueError("Missing or oversized native application rows")
        if not (len(rows) == receipt.get("requested") == receipt.get("confirmed") == receipt.get("checked")):
            raise ValueError("Native requested/confirmed/checked count mismatch")
        if receipt.get("excluded") != 0 or receipt.get("refused") != 0:
            raise ValueError("Positive corpus contains excluded/refused writes")
        changed = 0
        for row in rows:
            if not isinstance(row, list) or len(row) != 4 or any(type(x) is not int for x in row):
                raise ValueError("Native application row must contain four integers")
            x, y, before, after = row
            if not (0 <= x < width and 0 <= y < height):
                raise ValueError("Applied cell outside host focus")
            if before not in (0, 58) or after not in (0, 58):
                raise ValueError("Applied material outside host palette")
            if next(expected, None) != (x, y, after):
                raise ValueError("Native applied cells differ from exact operation sequence")
            index = y * WORLD_SIDE + x
            if world[index] != before:
                raise ValueError("Native before-material disagrees with prior receipt chain")
            world[index] = after
            changed += before != after
        if receipt.get("changed") != changed or receipt.get("unchanged") != len(rows) - changed:
            raise ValueError("Native changed/unchanged counts disagree with rows")
        for key in totals:
            totals[key] += receipt[key]
    if next(expected, None) is not None:
        raise ValueError("Native receipt chain omits requested cells")
    return world, totals


def verify(directory: Path) -> dict:
    summary = load(directory / "native-summary.json")
    process = load(directory / "process-result.json")
    custody = load(directory / "runtime-custody.json")
    document = load(directory / "input-cases.json")
    candidates = load(directory / "candidates.json")
    cases = {row["id"]: row for row in document["cases"]}
    examples = {row["id"]: row for row in candidates["examples"]}
    failures, global_gates, results = [], {}, []
    checks = 0

    def require(condition, message):
        nonlocal checks
        checks += 1
        if not condition:
            failures.append(message)

    def gate(name, condition):
        global_gates[name] = bool(condition)
        require(condition, name)

    gate("engine_passed", summary.get("passed") is True and not summary.get("failures"))
    gate("process_completed", process.get("exit_code") == 0 and process.get("timed_out") is False)
    for key in ("runtime_unchanged", "harness_unchanged", "input_unchanged"):
        gate(key, process.get(key) is True)
    gate("input_custody", digest(directory / "input-cases.json") == custody.get("input_manifest_sha256"))
    gate("candidate_custody", digest(directory / "candidates.json") == custody.get("candidates_sha256"))
    identity = summary.get("source_identity", {})
    gate("native_custody", identity.get("native_sha256") == custody.get("native_sha256")
         and bool(re.fullmatch(r"[a-f0-9]{64}", str(custody.get("native_sha256", "")))))
    gate("harness_custody", identity.get("harness_sha256") == custody.get("harness_sha256"))
    gate("runtime_pins", identity.get("rapier_sha256") == custody.get("rapier_sha256")
         and identity.get("source_sha") == custody.get("source_sha")
         and custody.get("godot_version") == GODOT_VERSION
         and identity.get("godot") == "4.7-stable (official)")
    summary_rows = summary.get("cases", [])
    gate("complete_case_manifest", len(cases) == len(document["cases"]) == len(examples)
         and set(cases) == set(examples) == {row["id"] for row in summary_rows}
         and len(summary_rows) == len(cases))
    assertions = summary.get("checks", [])
    gate("all_engine_assertions", bool(assertions) and all(row.get("passed") is True for row in assertions))
    labels = {(row["case"], row["label"]) for row in assertions if row.get("passed") is True}
    required = {
        ("invariant-protection", "host rejects a destination material outside enabled palette"),
        ("invariant-protection", "scope, protected rectangle and protected source material survive exact whole-World comparison"),
        ("invariant-protection", "native changed count closes against eligible cells"),
        ("invariant-stop", "Undo refuses active agent batch"),
        ("invariant-stop", "Undo refuses unconsumed native receipt"),
        ("invariant-stop", "Stop readback matches exact prefix and untouched suffix"),
        ("invariant-stop", "no delayed writes after Stop"),
        ("invariant-stop", "retired epoch cannot submit a late native write"),
        ("invariant-stop", "Undo reverses confirmed stopped prefix"),
        ("invariant-stop", "Redo restores only confirmed stopped prefix"),
    }
    gate("safety_probes_executed", required <= labels)
    receipts, captures = defaultdict(list), defaultdict(list)
    for line in (directory / "native-receipts.jsonl").read_text().splitlines():
        event = json.loads(line)
        key = (event["case"], event["phase"])
        if "receipt" in event:
            receipts[key].append(event["receipt"])
        if "capture" in event:
            captures[key].append(event["capture"])

    # Independent expected states for host safety, separate from compiler geometry.
    protected = [0] * (WORLD_SIDE * WORLD_SIDE)
    for y in range(8, 88):
        for x in range(8, 88):
            if not (20 <= x < 36 and 20 <= y < 36):
                protected[y * WORLD_SIDE + x] = 58
    protected[48 * WORLD_SIDE + 48] = 28
    protection_draws = receipts[("invariant-protection", "initial")]
    protection_captures = captures[("invariant-protection", "initial")]
    gate("protection_native_readback_exact", capture_matches(protection_captures,
         hashlib.sha256(material_bytes(protected)).hexdigest(), [0, 0, WORLD_SIDE, WORLD_SIDE])
         and sum(row["changed"] for row in protection_draws) == 6143
         and sum(row["excluded"] for row in protection_draws) == 3073
         and sum(row["checked"] for row in protection_draws) == 9216
         and all(row["backend"] == "CyberNativeCellWorld" and row["status"] == "completed" and row["refused"] == 0 for row in protection_draws))
    stopped = receipts[("invariant-stop", "initial")]
    prefix = sum(row["changed"] for row in stopped)
    stopped_hash = hashlib.sha256(material_bytes([58 if i < prefix else 0 for i in range(128 * 128)])).hexdigest()
    empty_hash = hashlib.sha256(bytes(128 * 128 * 4)).hexdigest()
    gate("stop_native_readback_exact", 0 < prefix <= 4096 and len(stopped) == 1
         and len(captures[("invariant-stop", "initial")]) == 4
         and all(capture_matches([capture], expected, [20, 20, 128, 128]) for capture, expected in zip(
             captures[("invariant-stop", "initial")], [stopped_hash, stopped_hash, empty_hash, stopped_hash]))
         and stopped[0]["backend"] == "CyberNativeCellWorld" and stopped[0]["status"] == "completed"
         and stopped[0]["checked"] == stopped[0]["confirmed"] == prefix
         and stopped[0]["excluded"] == stopped[0]["refused"] == 0)
    history_families = {row["family"] for row in summary_rows if row.get("history_and_reopen_checked") is True}
    gate("representative_history_and_reopen", {row["family"] for row in cases.values()} <= history_families)

    for row in summary_rows:
        identifier = row["id"]
        before = len(failures)
        case_result = {"id": identifier, "success": False}
        try:
            case, example = cases[identifier], examples[identifier]
            width, height = case["width"], case["height"]
            receipt_path = verified_receipt_file(directory, identifier, row)
            compiled = compile_program(example["program"], seed=example["seed"])
            require(compiled == example["compiled"], identifier + ": compiled program changed")
            require(compiled["operations"] == case["operations"], identifier + ": operations differ from compiled program")
            program_hash = hashlib.sha256(canonical(example["program"])).hexdigest()
            operation_hash = hashlib.sha256(canonical(case["operations"])).hexdigest()
            require(program_hash == case["program_sha256"] == row["program_sha256"], identifier + ": program digest")
            require(operation_hash == case["operations_sha256"] == row["operations_sha256"], identifier + ": operation digest")
            require(row.get("passed") is True and row["terminal"].get("status") == "completed", identifier + ": native completion")
            world, totals = reduce_receipts(receipts[(identifier, "initial")], case["operations"], width, height)
            full_hash = hashlib.sha256(material_bytes(world)).hexdigest()
            require(full_hash == row["whole_world_i32le_sha256"], identifier + ": independent full-world capture")
            initial_captures = captures[(identifier, "initial")]
            require(capture_matches(initial_captures, full_hash, [0, 0, WORLD_SIDE, WORLD_SIDE],
                                    receipts[(identifier, "initial")][-1]), identifier + ": initial native capture")
            replay_world, replay_totals = reduce_receipts(receipts[(identifier, "replay")], case["operations"], width, height)
            replay_captures = captures[(identifier, "replay")]
            require(replay_world == world and row.get("deterministic_replay_checked") is True
                    and row["replay_world_i32le_sha256"] == full_hash
                    and capture_matches(replay_captures, full_hash, [0, 0, WORLD_SIDE, WORLD_SIDE],
                                        receipts[(identifier, "replay")][-1]),
                    identifier + ": independent fresh-World deterministic replay")
            require(receipts[(identifier, "initial")][0]["generation"] != receipts[(identifier, "replay")][0]["generation"],
                    identifier + ": replay actually uses a new native World")
            for key in totals:
                require(totals[key] == row["terminal"].get(key) and replay_totals[key] == row["replay_terminal"].get(key),
                        identifier + ": " + key + " terminal counters")
            values = [world[y * WORLD_SIDE + x] for y in range(height) for x in range(width)]
            raw = material_bytes(values)
            raw_path = safe_path(directory, row["raw_materials"])
            png_path = safe_path(directory, row["png"])
            material_png = safe_path(directory, row["material_png"])
            require(raw_path.read_bytes() == raw and digest(raw_path) == row["crop_i32le_sha256"], identifier + ": exact captured binary crop")
            with Image.open(material_png) as image:
                require(image.mode == "L" and image.size == (width, height) and list(image.tobytes()) == values,
                        identifier + ": material PNG equals native IDs")
            with Image.open(png_path) as image:
                expected_colors = b"".join(FOREGROUND if value == 58 else BACKGROUND for value in values)
                require(image.size == (width, height) and image.convert("RGB").tobytes() == expected_colors,
                        identifier + ": original PNG maps native IDs to declared palette")
            require(values == rasterize_operations(case["operations"]), identifier + ": actual cells equal compiled geometry")
            metrics = verify_structure(compiled, values)
            require(metrics.get("passed") is True, identifier + ": native family structure " + str(metrics.get("errors", [])))
            require(totals["changed"] > 0 and row["filled_cells"] == sum(value != 0 for value in values)
                    and row["outside_area_cells"] == row["unexpected_material_cells"] == 0,
                    identifier + ": nonempty safe native drawing")
            if row.get("history_and_reopen_checked"):
                for phase, expected_hash in (("undo", hashlib.sha256(bytes(WORLD_SIDE * WORLD_SIDE * 4)).hexdigest()),
                                             ("redo", full_hash), ("reopen", full_hash)):
                    evidence = captures[(identifier, phase)]
                    require(capture_matches(evidence, expected_hash, [0, 0, WORLD_SIDE, WORLD_SIDE]),
                            identifier + ": independent " + phase + " native capture")
                require(bool(safe_path(directory, identifier + ".setup.json").read_bytes()), identifier + ": actual saved construction")
            case_result.update({
                "success": len(failures) == before and all(global_gates.values()),
                "family": example["family"], "split": example["split"], "seed": example["seed"],
                "program_sha256": program_hash, "operations_sha256": operation_hash,
                "image_sha256": digest(png_path), "readback_sha256": digest(raw_path),
                "receipt_sha256": digest(receipt_path),
                "affected_cells": totals["changed"], "acknowledged_cells": totals["checked"],
                "filled_cells": row["filled_cells"], "png": row["png"], "raw_materials": row["raw_materials"],
                "receipt": identifier + ".receipt.json", "structure": metrics,
                "deterministic_replay": True, "history_and_reopen_checked": row.get("history_and_reopen_checked", False),
            })
        except (ValueError, KeyError, OSError, TypeError, struct.error) as error:
            require(False, identifier + ": " + str(error))
        case_result["failures"] = failures[before:]
        results.append(case_result)
    return {
        "schema_version": 1, "passed": not failures, "checks": checks, "failures": failures,
        "global_gates": global_gates, "engine_checks": len(assertions), "cases": results,
        "source_sha": custody["source_sha"], "runtime_sha256": custody["native_sha256"],
        "qualification": custody["claim"], "development_only": custody.get("development_only", False),
        "compiler_sha256": digest(Path(__file__).resolve().parents[1] / "compiler.py"),
        "verifier_sha256": digest(Path(__file__)), "runtime_custody_sha256": digest(directory / "runtime-custody.json"),
        "engine_summary_sha256": digest(directory / "native-summary.json"),
        "native_receipts_sha256": digest(directory / "native-receipts.jsonl"),
        "process_result_sha256": digest(directory / "process-result.json"),
    }


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    result = verify(args.directory)
    target = args.directory / "native-verification.json"
    target.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: result[key] for key in ("passed", "checks", "failures")}, indent=2))
    raise SystemExit(0 if result["passed"] else 1)
