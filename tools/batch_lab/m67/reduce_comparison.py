#!/usr/bin/env python3
"""Independently audit registered M6/M7 native comparison files without mutation.

Uses the established native-receipt boundary, then scalar material-plane geometry.
No score equates painted area, components or empty space with architectural quality.
"""
from __future__ import annotations
import argparse
import base64
from collections import Counter, defaultdict, deque
import hashlib
import json
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from evaluate import checked_readback  # established Batch custody validator

ARMS = ("hand_typed", "procedural_structure", "random_fitting_modules", "reference_guided", "retrieval_guided")
SEEDS = (47017, 47051)
REGISTRATION_SHA = "1dbdb552dfcbb7f6e81fdd7807ea77aca4384eca523293ababb007b0664ef34f"
CATALOGUE_RECIPE_SHA = "f3c9c09dbff564e8830a785e9d6a3b87111dd47c2afa15327882486843d917e2"
CATALOGUE_EXPORT_SHA = "f47321fa74664d2cd16ee6624e7814751182fb08be20aa2fe58715ad29f16fd8"
MAX_BYTES = 64 * 1024 * 1024


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical(value):
    if isinstance(value, float) and value.is_integer():
        return int(value)
    if isinstance(value, list):
        return [canonical(x) for x in value]
    if isinstance(value, dict):
        return {k: canonical(v) for k, v in value.items()}
    return value


def canonical_bytes(value) -> bytes:
    return json.dumps(canonical(value), sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()


def exact_file(root: Path, relative: str, expected: str | None = None) -> bytes:
    if not isinstance(relative, str) or not relative:
        raise ValueError("Missing relative evidence path")
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file() or path.stat().st_size > MAX_BYTES:
        raise ValueError("Evidence path escapes archive, is missing or exceeds bounds")
    raw = path.read_bytes()
    if expected is not None and sha(raw) != expected:
        raise ValueError(f"Evidence SHA-256 mismatch: {relative}")
    return raw


def plane(raw: bytes, width: int, height: int) -> list[int]:
    if len(raw) != width * height * 2:
        raise ValueError("Native plane byte count differs from exact LE16 extent")
    return list(struct.unpack(f"<{width*height}H", raw))


def rect_points(raw, width: int, height: int):
    if not isinstance(raw, list) or len(raw) != 4 or any(type(n) is not int for n in raw):
        raise ValueError("Invalid integer rectangle")
    x, y, w, h = raw
    if min(x, y) < 0 or min(w, h) < 1 or x+w > width or y+h > height:
        raise ValueError("Rectangle escapes native extent")
    return (yy*width+xx for yy in range(y, y+h) for xx in range(x, x+w))


def components(cells: list[int], width: int, height: int) -> list[int]:
    # Stone13 is the protected diagnostic marker, not constructed architecture.
    unseen = {i for i, material in enumerate(cells) if material not in (0, 13)}
    sizes = []
    while unseen:
        seed = unseen.pop()
        queue = [seed]
        count = 0
        while queue:
            point = queue.pop()
            count += 1
            x, y = point % width, point // width
            for neighbor in ((point-1 if x else -1), (point+1 if x+1 < width else -1), (point-width if y else -1), (point+width if y+1 < height else -1)):
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    queue.append(neighbor)
        sizes.append(count)
    return sorted(sizes, reverse=True)


def replay_edits(before: list[int], edits: list, width: int, height: int) -> list[int]:
    if not isinstance(edits, list) or len(edits) > width*height:
        raise ValueError("Accepted native edit history exceeds finite extent")
    result = before.copy()
    for edit in edits:
        if not isinstance(edit, list) or len(edit) != 5 or type(edit[4]) is not int or not 0 <= edit[4] <= 65535:
            raise ValueError("Malformed accepted native material edit")
        for point in rect_points(edit[:4], width, height):
            result[point] = edit[4]
    return result


def native_totals(receipts: list, *, allow_excluded: bool = False) -> dict:
    """Count already validated receipts; catalogue construction may overlap paint.

    Excluded cells are explicitly unmodified native checks. Only the catalogue
    source recipes permit these repeated occupied intersections; registered
    comparison programs are normalized unique writes and keep the strict fence.
    """
    totals = {key: sum(r[key] for r in receipts) for key in ("checked", "changed", "excluded", "refused")}
    if totals["checked"] > 65536:
        raise ValueError("Native attempt exceeds registered apparatus capacity")
    if totals["refused"] or (totals["excluded"] and not allow_excluded):
        raise ValueError("Retained native application contains disallowed excluded/refused cells")
    return {**totals, "receipt_chunks": len(receipts)}


def audit_native(root: Path, path: str, digest: str, expected_source: str, expected_result: str, source_revision: str, *, allow_excluded: bool = False):
    record = json.loads(exact_file(root, path, digest))
    config, before, after, before_raw, after_raw, acknowledged = checked_readback(record)
    width, height = config["extent"]
    if sha(before_raw) != expected_source or sha(after_raw) != expected_result:
        raise ValueError("Native record material planes differ from case evidence")
    if record["provenance"].get("source_revision") != source_revision:
        raise ValueError("Native record is bound to another application source")
    if replay_edits(before, record.get("accepted_edits"), width, height) != after:
        raise ValueError("Native accepted-edit replay does not reproduce full readback")
    counters = native_totals(record["receipts"], allow_excluded=allow_excluded)
    return record, {**counters, "acknowledged_changes": acknowledged}


def contacts_on_plane(row: dict, cells: list[int], width: int, height: int):
    expected = row["brief"].get("relations", [])
    if not expected:
        return {"applicable": True, "satisfied": True, "required_relations": 0, "occupied_contact_cells": 0}
    if row["arm"] not in ("retrieval_guided", "random_fitting_modules"):
        return {"applicable": False, "satisfied": None, "required_relations": len(expected), "scope": "Raw typed/procedural strategies expose no authored module role/tag contract; this is a tool-capability difference, not fabricated contact evidence."}
    result = row.get("module_contact_result", {})
    if not row["native_attempted"] or not result.get("ok"):
        return {"applicable": True, "satisfied": False, "required_relations": len(expected), "occupied_contact_cells": 0}
    contacts = result.get("contacts", [])
    count = 0
    for relation in expected:
        matched = [c for c in contacts if {str(c.get("a", {}).get("instance")), str(c.get("b", {}).get("instance"))} == {relation["a"], relation["b"]}]
        if not matched:
            return {"applicable": True, "satisfied": False, "required_relations": len(expected), "occupied_contact_cells": count}
        contact = matched[0]
        aa, bb = contact["a_cells"], contact["b_cells"]
        if len(aa) != len(bb) or not aa or len(aa) != contact["cell_count"]:
            raise ValueError("Projected connection evidence has inconsistent spans")
        for a, b in zip(aa, bb):
            if len(a) != 2 or len(b) != 2 or abs(a[0]-b[0])+abs(a[1]-b[1]) != 1:
                raise ValueError("Connection evidence contains nonadjacent contact points")
            for x, y in (a, b):
                if not (0 <= x < width and 0 <= y < height) or not cells[y*width+x]:
                    raise ValueError("Actual native readback does not occupy a declared contact face")
        count += len(aa)
    return {"applicable": True, "satisfied": True, "required_relations": len(expected), "occupied_contact_cells": count, "scope": "Actual occupied adjacent cells plus compiler-admitted authored module contracts, not physical support or fluid-flow evidence."}


def source_clearance_audit(brief: dict, source: list[int], width: int, height: int) -> dict:
    """Expose impossible input contracts without silently changing denominators.

    This registration preserves all occupied source cells. Any originally
    occupied required-empty cell is therefore an immutable brief conflict,
    even if an additive proposal would otherwise satisfy all of its slots.
    """
    allowed = set()
    for slot in brief["slots"]:
        allowed.update(rect_points(slot["region"], width, height))
    blocked = set()
    rectangles = []
    for rect in brief.get("required_empty_regions", []):
        occupied = {i for i in rect_points(rect, width, height) if source[i] != 0}
        blocked.update(occupied)
        if occupied:
            rectangles.append({"region": rect, "source_occupied_cells": len(occupied), "outside_write_slots": len(occupied-allowed)})
    return {"immutable_source_clearance_conflict": bool(blocked), "source_occupied_clearance_cells": len(blocked),
            "outside_write_slots": len(blocked-allowed), "conflicting_rectangles": rectangles,
            "scope": "Original frozen source and brief retained; these are input-contract conflicts, not selector or native-execution failures."}


def reduce_manifest(path: Path) -> dict:
    raw = path.read_bytes()
    if len(raw) > MAX_BYTES:
        raise ValueError("Comparison manifest exceeds retained capacity")
    manifest = json.loads(raw)
    if manifest.get("format") != "cybersand-m67-composition-native-comparison-v1" or manifest.get("registration_sha256") != REGISTRATION_SHA:
        raise ValueError("Unknown comparison or altered registration")
    if manifest.get("catalogue_recipe_sha256") != CATALOGUE_RECIPE_SHA:
        raise ValueError("Comparison catalogue recipes or metadata changed after held-out reveal")
    if "frozen_catalogue_sha256" in manifest and manifest["frozen_catalogue_sha256"] != CATALOGUE_EXPORT_SHA:
        raise ValueError("Comparison uses an unidentified frozen catalogue export")
    root = path.parent
    source_revision = manifest["source_revision"]
    cases = manifest.get("cases")
    if not isinstance(cases, list) or len(cases) != 60 or manifest.get("model_calls") != 0:
        raise ValueError("Registered sixty-case deterministic population is incomplete")
    seen = set()
    groups = defaultdict(list)
    rows = []
    failures = []
    native_observations = []
    for source in manifest.get("source_observations", []):
        record = json.loads(exact_file(root, source["record_path"], source["record_sha256"]))
        before_sha = sha(base64.b64decode(record["source_materials_base64"], validate=True))
        _, counters = audit_native(root, source["record_path"], source["record_sha256"], before_sha, source["source_sha256"], source_revision)
        exact_file(root, source["source_plane_path"], source["source_sha256"])
        native_observations.append({"kind": "shared-native-source", "id": source["brief_id"], **counters})
    for module in manifest.get("module_observations", []):
        record = json.loads(exact_file(root, module["record_path"], module["record_sha256"]))
        before_sha = sha(base64.b64decode(record["source_materials_base64"], validate=True))
        _, counters = audit_native(root, module["record_path"], module["record_sha256"], before_sha, record["material_sha256"], source_revision, allow_excluded=True)
        if record["state"] != "completed":
            raise ValueError("Catalogue source lacks a completed native construction")
        exported = json.loads(exact_file(root, "modules/"+module["id"]+".json"))
        declared_hash = exported.pop("content_sha256")
        if sha(canonical_bytes(exported)) != declared_hash or declared_hash != module["module_sha256"]:
            raise ValueError("Exported module content does not match its exact selected identity")
        geometry = base64.b64decode(exported["geometry"]["cells_base64"], validate=True)
        if sha(geometry) != module["geometry_sha256"] or sha(geometry) != exported["geometry"]["sha256"]:
            raise ValueError("Native module geometry digest differs from exported bytes")
        material = base64.b64decode(record["material_cells_base64"], validate=True)
        rw, rh = record["result_extent"]
        x, y, w, h = exported["provenance"]["harvest"]["source_region"]
        list(rect_points([x, y, w, h], rw, rh))
        crop = b"".join(material[((y+row)*rw+x)*2:((y+row)*rw+x+w)*2] for row in range(h))
        if crop != geometry or exported["extent"] != [w, h]:
            raise ValueError("Exported module is not the exact cropped authoritative native source")
        native_observations.append({"kind": "current-process-module-source", "id": module["id"], **counters})
    if len(native_observations) != 46:
        raise ValueError("Expected forty actual module sources and six actual shared source baselines")
    for case in cases:
        identity = (case["brief_id"], case["arm"], case["seed"])
        if identity in seen or case["arm"] not in ARMS or case["seed"] not in SEEDS:
            raise ValueError("Duplicate or unregistered case identity")
        seen.add(identity)
        width, height = case["extent"]
        if (width, height) != (256, 192):
            raise ValueError("Matched canvas changed")
        source_raw = exact_file(root, case["source_plane_path"], case["source_sha256"])
        result_raw = exact_file(root, case["result_plane_path"], case["result_sha256"])
        before, after = plane(source_raw, width, height), plane(result_raw, width, height)
        program = json.loads(exact_file(root, case["program_path"], case["program_sha256"]))
        if sha(canonical_bytes(case["brief"])) != case["brief_sha256"]:
            raise ValueError("Retained brief was altered after proposal")
        if program.get("query") and sha(canonical_bytes(program["query"])) != case["query_sha256"]:
            raise ValueError("Retained query identity differs from exact tool input")
        counts = {"checked": 0, "changed": 0, "excluded": 0, "refused": 0, "receipt_chunks": 0}
        if case["native_attempted"]:
            record, counts = audit_native(root, case["raw_native_record_path"], case["raw_native_record_sha256"], case["source_sha256"], case["result_sha256"], source_revision)
            if counts["checked"] > 32768 or record["state"] != case["status"]:
                raise ValueError("Native status or registered resource ceiling differs")
            if case["status"] == "completed" and case["result_sha256"] != case["projected_sha256"]:
                raise ValueError("Completed actual plane differs from approved apparatus projection")
        elif case["status"] != "refused-before-native" or after != before or case["raw_native_record_path"]:
            raise ValueError("Unexecuted proposal masquerades as native output")
        for field in ("checked", "changed"):
            if counts[field] != case["actual_counts"][field]:
                raise ValueError("Case reported resource count differs from native receipts")
        allowed = set()
        for slot in case["brief"]["slots"]:
            allowed.update(rect_points(slot["region"], width, height))
        changed = {i for i, (a, b) in enumerate(zip(before, after)) if a != b}
        outside = len(changed-allowed)
        protected = any(before[i] != after[i] for i in rect_points([2, 2, 4, 4], width, height))
        source_modified = sum(before[i] != 0 and before[i] != after[i] for i in range(len(before)))
        blocked = sum(after[i] != 0 for rect in case["brief"].get("required_empty_regions", []) for i in rect_points(rect, width, height))
        invalid_materials = sorted(set(after)-{0, 7, 13, 28, 58})
        contact = contacts_on_plane(case, after, width, height)
        input_contract = source_clearance_audit(case["brief"], before, width, height)
        completed = case["native_attempted"] and case["status"] == "completed"
        safe = not (outside or protected or source_modified or invalid_materials)
        if not safe or (completed and blocked):
            failures.append({"case_id": case["case_id"], "reason": "Actual material/protection/clearance contract failed"})
        sizes = components(after, width, height)
        row = {"case_id": case["case_id"], "cohort": case["cohort"], "brief_id": case["brief_id"], "arm": case["arm"], "seed": case["seed"],
               "status": case["status"], "native_completion": completed, "native_attempted": case["native_attempted"], "reason": case["compile_reason"],
               "material_and_protection_safe": safe, "outside_slot_changes": outside, "source_occupied_changes": source_modified,
               "clearance_blocked_cells": blocked, "required_clearances_empty": blocked == 0, "declared_contacts": contact,
               "input_contract_audit": input_contract,
               "actual_counts": counts, "net_changed_cells": len(changed), "empty_fraction": after.count(0)/len(after),
               "occupied_face_components": len(sizes), "occupied_component_sizes": sizes, "result_sha256": case["result_sha256"],
               "source_sha256": case["source_sha256"], "module_ids": case["module_ids"], "reference_ids": case["reference_ids"], "elapsed_usec": case["elapsed_usec"]}
        rows.append(row)
        groups[(case["brief_id"], case["seed"])].append(row)
    if len(groups) != 12 or any(len(rows) != 5 or len({r["source_sha256"] for r in rows}) != 1 for rows in groups.values()):
        raise ValueError("Matched source/arm/seed blocks are incomplete")
    arm_summary = []
    for cohort in ("development", "held_out"):
        for arm in ARMS:
            cohort_rows = [r for r in rows if r["cohort"] == cohort and r["arm"] == arm]
            complete = [r for r in cohort_rows if r["native_completion"]]
            arm_summary.append({"cohort": cohort, "arm": arm, "proposals": len(cohort_rows), "completed": len(complete),
                                "refused_before_native": sum(not r["native_attempted"] for r in cohort_rows),
                                "proposals_with_immutable_source_clearance_conflict": sum(r["input_contract_audit"]["immutable_source_clearance_conflict"] for r in cohort_rows),
                                "checked_cells_total": sum(r["actual_counts"]["checked"] for r in cohort_rows),
                                "changed_cells_total": sum(r["actual_counts"]["changed"] for r in cohort_rows),
                                "unique_completed_geometry_hashes": len({r["result_sha256"] for r in complete}),
                                "unique_selected_module_ids": sorted({m for r in cohort_rows for m in r["module_ids"]}),
                                "completed_with_empty_required_clearances": sum(r["required_clearances_empty"] for r in complete),
                                "completed_with_applicable_satisfied_contacts": sum(r["declared_contacts"]["satisfied"] is True for r in complete)})
    return {"format": "cybersand-m67-independent-comparison-review-v1", "passed": not failures, "manifest_sha256": sha(raw), "source_revision": source_revision,
            "registration_sha256": REGISTRATION_SHA, "development_core_capacity": manifest["development_core_capacity"],
            "native_observations": native_observations, "case_count": len(rows), "native_completed": sum(r["native_completion"] for r in rows),
            "pre_native_refusals": sum(not r["native_attempted"] for r in rows), "failures": failures, "arm_summary": arm_summary, "cases": rows,
            "brief_input_contracts": [{"brief_id": key, **next(r["input_contract_audit"] for r in rows if r["brief_id"] == key)} for key in sorted({r["brief_id"] for r in rows})],
            "distinct_output_blocks": [{"brief_id": key[0], "seed": key[1], "completed_distinct_plane_hashes": len({r["result_sha256"] for r in values if r["native_completion"]}),
                                        "all_proposals_distinct_results_including_refusal_source": len({r["result_sha256"] for r in values})} for key, values in sorted(groups.items())],
            "model_calls": 0, "limitations": ["Held-out authored briefs; historical corpus and module vocabulary were already known, so no unseen-artwork or blind-human preference conclusion.",
            "Raw typed/procedural arms lack authored module role/tag contracts. Missing contract evidence is not silently counted as proven connector failure or success.",
            "Refusals remain in the fixed denominator. Geometry summaries of unchanged refused sources do not count as successful construction.",
            "One independently frozen brief contains an immutable source/required-clearance contradiction; its ten proposals remain in the denominator and are classified separately from selector failures.",
            "Passed means the evidence custody and material/protection audit passed, not that every proposed construction completed or has architectural quality.",
            "Connected cells, empty regions and native completion are not actor traversal, physical stability, fluid operation or aesthetic acceptance.",
            "Tool capabilities and geometry differ across arms; native work is measured rather than equated with architectural quality."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = reduce_manifest(args.manifest)
    text = json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2)+"\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    else:
        print(text, end="")
    return 0 if result["passed"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
