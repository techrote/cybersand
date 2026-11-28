#!/usr/bin/env python3
"""One new ordinary Sand-lodging witness against the already qualified 5f ZIP."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import os
import re
from pathlib import Path
import secrets
import sys

DIRECTORY = Path(__file__).resolve().parent
HELPERS = {
    "review_delivery_45530425519.py": "3cc6a1ba9b6fcd78b65a8ba1ed031d5907ee1299",
    "run_windows_owner_witnesses.py": "6731c1b513481ae94c77e7453c586b36bb004ea4",
}
for filename, expected in HELPERS.items():
    raw = (DIRECTORY / filename).read_bytes()
    actual = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
    if actual != expected:
        raise ValueError("Previously qualified custody/process helper changed: " + filename)
spec = importlib.util.spec_from_file_location("objectshard_owner_witnesses", DIRECTORY / "run_windows_owner_witnesses.py")
witness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(witness)
audit = witness.audit
need, save, file_digest = audit.need, audit.save, audit.file_digest
SOURCE, TREE = audit.SOURCE, audit.TREE
PRIOR_AUDIT_SOURCE = "21333f8a0eb15620ecf22ce4c1b3df09fa83fc51"
PRIOR_AUDIT_RUN = 45537943367
SUMMARY_SHA = "d77dcbc86157b4d5eea39817c2edbb4d7f5f73662becbeef5e0fca3d66d2b499"
SCHEMA = "objectshard-m4-ordinary-sand-lodging-v1"
OBSERVER = DIRECTORY / "external-sand-lodging" / "observe_sand_lodging.gd"


def integer_point(value: object) -> list[int]:
    if isinstance(value, str):
        match = re.fullmatch(r"\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)", value)
        need(match is not None, "Mounted integer brush point has an invalid representation")
        return [int(match[1]), int(match[2])]
    need(isinstance(value, list) and len(value) == 2
         and all(type(item) is int for item in value), "Mounted brush point is not an integer pair")
    return value


def verify_result(receipt: dict, nonce: str, raw_root: Path, package: Path, observer_sha: str,
                  user_root: Path, output: Path) -> dict:
    need(receipt["schema"] == SCHEMA and receipt["nonce"] == nonce and receipt["source_commit"] == SOURCE
         and type(receipt["checks"]) is int and receipt["checks"] > 0 and receipt["failures"] == [],
         "Sand witness is not the exact successful new source/nonce result")
    e = receipt["evidence"]
    required = {"identity", "authored_input", "mounted_actions", "mounted_strokes", "supported_inventory",
                "before_inventory", "painted_inventory", "after_inventory", "inventory_witnesses",
                "native_before", "native_painted", "intake_native", "native_after", "final_native",
                "physical_before", "physical_painted", "physical_after", "detached", "natural_rest",
                "pocket", "display_coherence", "census_mismatches"}
    need(required <= set(e), "Sand observer lacks complete authored/physical/cargo records")
    identity = e["identity"]
    need(identity["platform"] == "Windows" and identity["display_driver"] == "headless"
         and identity["source_commit"] == SOURCE and identity["source_tree"] == TREE
         and identity["native_sha256"] == audit.DLL_SHA and identity["rapier_sha256"] == audit.RAPIER_SHA
         and identity["observer_sha256"] == observer_sha
         and identity["manifest_sha256"] == file_digest(package / witness.MANIFEST),
         "Actual Sand engine/native/observer/package identity differs")
    engine = Path(identity["engine_path"]).resolve()
    need(engine in {(package / witness.GUI).resolve(), (package / witness.CONSOLE).resolve()}
         and identity["engine_sha256"] == file_digest(engine), "Sand actual engine is outside verified package")
    witness.coherent(e["display_coherence"])

    authored = e["authored_input"]
    authored_path = Path(authored["path"]).resolve()
    need(authored["label"] == "m4-recovery-sand-pocket"
         and authored_path.name == "setup-m4-recovery-sand-pocket.json"
         and authored_path.is_relative_to(user_root.resolve()) and authored_path.is_file(),
         "The ordinary authored pocket is not in this process's fresh user-data directory")
    authored_raw = authored_path.read_bytes()
    setup = json.loads(authored_raw)
    edits = [[0, 464, 512, 48, 1], [0, 0, 3, 512, 1], [509, 0, 3, 512, 1],
             [240, 440, 3, 6, 7], [246, 440, 3, 6, 7], [240, 446, 9, 3, 7], [243, 449, 3, 15, 1]]
    expected = {"version": 2, "extent": [512, 512], "actors": [], "next_id": 1, "selected": 0,
                "edits": edits, "response": "LA-SELECTIVE", "normalize": False, "rule_radius": 2,
                "source": [], "material": 2, "brush": 2, "fire": False}
    need(len(authored_raw) <= 1024 * 1024 and audit.digest(authored_raw) == authored["sha256"]
         and setup == authored["setup"] and set(setup) == witness.SETUP_KEYS
         and all(setup[key] == value for key, value in expected.items())
         and isinstance(setup["liquid_policy"], list)
         and all(type(value) is int for value in setup["liquid_policy"]),
         "Original named authored bytes differ from the complete reviewed starting recipe")
    saved = output / "authored-saves" / authored_path.name
    saved.parent.mkdir(exist_ok=True)
    saved.write_bytes(authored_raw)

    labels = ("supported", "before", "painted", "after")
    raw_inventories = [e[label + "_inventory"] for label in labels]
    need(e["inventory_witnesses"] == raw_inventories and e["census_mismatches"] == [],
         "Sand raw inventory witness copies differ or report a conservation failure")
    inventories = {label: witness.inventory(value, raw_root) for label, value in zip(labels, raw_inventories)}
    supported, before, painted, after = (inventories[label] for label in labels)
    need(supported["owner_ids"] == [], "The starting pocket must remain static and boundary-supported")
    natives = [e[key] for key in ("native_before", "native_painted", "intake_native", "native_after", "final_native")]
    n0, np, intake, n1, final = natives
    owner = n0["id"]
    incarnation = {"id": owner, "generation": n0["generation"], "body_generation": n0["body_generation"]}
    need(type(owner) is int and owner > 0 and all(type(incarnation[key]) is int and incarnation[key] > 0
         for key in ("generation", "body_generation")), "Invalid native pocket incarnation")
    need(all(inv["owner_ids"] == [owner] and inv["owner_incarnations"] == [incarnation]
         for inv in (before, painted, after)), "Raw cargo carriers do not join the one exact native incarnation")
    need(all(all(native[key] == incarnation[key] for key in incarnation) for native in natives),
         "Automatic Sand transfer replaced the native owner incarnation")
    world_generation = supported["source"]["world_generation"]
    need(all(inv["source"]["world_generation"] == world_generation for inv in inventories.values()),
         "A World replacement separated the four material witnesses")
    for label, native in (("before", n0), ("painted", np), ("after", n1)):
        source = inventories[label]["source"]
        need(all(source[key] == native[key] for key in ("world_generation", "world_revision", "publication_sequence"))
             and source["tick"] == native["frame_tick"], "Raw census and immutable native frame differ: " + label)

    width, height = n0["width"], n0["height"]
    need(type(width) is int and type(height) is int and width > 0 and height > 0
         and all(native["width"] == width and native["height"] == height for native in natives),
         "Cargo intake changed the surviving source lattice")
    records = {}
    grids = {label: witness.raw_record(e[label + "_inventory"]["raw_grid"], raw_root, records) for label in labels}
    carriers = {label: witness.raw_record(e[label + "_inventory"]["owned_inventory"][0]["materials"],
                                          raw_root, records) for label in ("before", "painted", "after")}
    need(all(len(materials) == width * height for materials in carriers.values()),
         "Raw carrier size does not match the actual native source lattice")
    expected_grid = bytearray(512 * 512)
    for x, y, w, h, material in edits:
        for row in range(y, y + h):
            expected_grid[row * 512 + x:row * 512 + x + w] = bytes([material]) * w
    need(grids["supported"] == expected_grid, "Supported raw World differs from the authored complete native grid")
    erased_points = [[x, y] for y in range(449, 464) for x in range(243, 246)]
    for x, y in erased_points:
        expected_grid[y * 512 + x] = 0
    for index, material in enumerate(expected_grid):
        if material == 7:
            expected_grid[index] = 0
    need(grids["before"] == expected_grid and carriers["before"].count(7) == 63
         and all(material in (0, 7) for material in carriers["before"]),
         "Detachment failed exact World debit or intact 63-Wood ownership")

    pocket = e["pocket"]
    left, right, row = pocket["left"], pocket["right"], pocket["row"]
    need(pocket["owner"] == owner and pocket["generation"] == incarnation["generation"]
         and pocket["body_generation"] == incarnation["body_generation"]
         and pocket["width"] == width and pocket["height"] == height
         and pocket["geometry_revision"] == n0["geometry_revision"]
         and all(type(value) is int for value in (left, right, row))
         and 1 <= left < right < width and right - left == 3 and 1 <= row < height - 1
         and pocket["cell"] == row * width + left + 1
         and pocket["local_center"] == [left + 1.5, row + .5],
         "Observed pocket is not the same three-cell aperture in the native source lattice")
    wood = carriers["before"]
    need(wood[row * width + left - 1] == wood[row * width + right] == 7
         and all(wood[(row + 1) * width + x] == 7 for x in range(left, right))
         and all(wood[y * width + x] == 0 for y in range(row + 1) for x in range(left, right)),
         "Raw owned lattice does not contain the documented empty upward-open aperture")
    angle = n0["rotation"]
    lx, ly = pocket["local_center"]
    center = [n0["position_x"] + math.cos(angle) * lx - math.sin(angle) * ly,
              n0["position_y"] + math.sin(angle) * lx + math.cos(angle) * ly]
    need(all(math.isfinite(value) for value in center) and math.dist(center, pocket["world_center"]) < .001,
         "Pocket world position does not follow the actual native pose")
    drop = [math.floor(center[0]), math.floor(center[1]) - 6]
    need(pocket["drop"] == drop and all(type(value) is int and 0 <= value < 512 for value in drop),
         "Sand brush point is not six native cells above the actual aperture")

    strokes = e["mounted_strokes"]
    need(len(strokes) == 2, "The ordinary witness must contain exactly support erase and one Sand paint")
    for stroke, label, tool, material, points in (
        (strokes[0], "remove45pedestalWallcells", "Eraser", 0, erased_points),
        (strokes[1], "paintoneSandcell", "Brush", 2, [drop]),
    ):
        need(stroke["label"] == label and stroke["tool"] == tool and stroke["radius"] == 0
             and stroke["material"] == material and [integer_point(point) for point in stroke["points"]] == points
             and stroke["receipt"]["status"] == "completed" and stroke["receipt"]["applied"] == len(points)
             and stroke["before_tick"] == stroke["after_tick"]
             and stroke["before_physical_steps"] == stroke["after_physical_steps"],
             "Mounted precise brush lacks exact cells, completed native receipt or paused clock fence: " + label)
    captions = [action["caption"] for action in e["mounted_actions"]]
    need(captions[0] == "Load start" and len(captions) >= 5
         and all(caption == "Play / Pause [P]" for caption in captions[1:])
         and all(action["node_path"] for action in e["mounted_actions"]),
         "Authored fixture or lifecycle bypassed mounted ordinary controls")
    paint = strokes[1]
    p0, pp, p1 = (e[key] for key in ("physical_before", "physical_painted", "physical_after"))
    need(strokes[0]["before_tick"] == supported["source"]["tick"]
         and paint["before_tick"] == n0["frame_tick"] == np["frame_tick"]
         and paint["before_physical_steps"] == p0["physical_step"] == pp["physical_step"]
         and p0["bridge_step"] == pp["bridge_step"] and p0["paused"] is pp["paused"] is True,
         "Paused Sand paint or raw inspection advanced native or actual Rapier time")
    drop_index = drop[1] * 512 + drop[0]
    need(expected_grid[drop_index] == 0, "Sand was painted over a nonempty World cell")
    expected_grid[drop_index] = 2
    need(grids["painted"] == expected_grid and carriers["painted"] == carriers["before"],
         "One paused Sand paint changed anything besides its exact empty static World cell")
    expected_grid[drop_index] = 0
    need(grids["after"] == expected_grid, "Automatic native Sand ingress did not debit the exact World grain")

    detached, rest = e["detached"], e["natural_rest"]
    need(type(p0["rid"]) is int and p0["rid"] > 0 and all(
         sample["owner"] == owner and sample["generation"] == incarnation["generation"]
         and sample["body_generation"] == incarnation["body_generation"] and sample["rid"] == p0["rid"]
         and sample["shape_count"] > 0 for sample in (detached, rest, p0, pp, p1)),
         "The actual Rapier RID/incarnation or live collider changed across cargo intake")
    need(detached["paused"] is rest["paused"] is False and rest["sleeping"] is True
         and rest["physical_step"] > detached["physical_step"] and rest["bridge_step"] > detached["bridge_step"]
         and rest["native_tick"] >= detached["native_tick"] + 8 and rest["y"] > detached["y"] + 1
         and math.hypot(rest["vx"], rest["vy"]) < .05 and abs(rest["angular_velocity"]) < .01
         and abs(rest["rotation"]) < .05,
         "The pocket did not naturally fall and reach actual upright sleeping Rapier rest during Play")
    need(all(native["wood_cells"] == 63 and native["cargo_cells"] == 0 and native["sand_cells"] == []
             and native["sand_ingested"] == 0 and abs(native["mass"] - 63) < .001 for native in (n0, np))
         and n0["geometry_revision"] == np["geometry_revision"]
         and abs(p0["mass"] - 63) < .001 and abs(pp["mass"] - 63) < .001,
         "The resting/painted pocket already contained cargo or lost native/physical Wood mass")
    need(intake["frame_tick"] > np["frame_tick"] and n1["frame_tick"] >= intake["frame_tick"]
         and final["frame_tick"] == n1["frame_tick"] and p1["native_tick"] == n1["frame_tick"]
         and p1["physical_step"] > pp["physical_step"] and p1["paused"] is True,
         "Positive ingress was not observed after real resumed native/physical progression")
    cargo = n1["sand_cells"]
    need(len(cargo) == 1 and type(cargo[0]["cell"]) is int
         and 0 <= cargo[0]["cell"] < width * height and cargo[0]["role"] == 3
         and type(cargo[0]["incarnation"]) is int and cargo[0]["incarnation"] > 0,
         "The new Sand material is not one valid native Cargo cell")
    cell = cargo[0]["cell"]
    need(cell // width == row and left <= cell % width < right,
         "Actual cargo is outside the observed three-cell pocket")
    for native in (intake, n1, final):
        need(native["sand_ingested"] - n0["sand_ingested"] == 1 and native["cargo_cells"] == 1
             and native["wood_cells"] == 63 and len(native["sand_cells"]) == 1
             and all(native["sand_cells"][0][key] == cargo[0][key] for key in ("cell", "role", "incarnation"))
             and abs(native["mass"] - 64) < .001,
             "Immutable ingress/current native frames do not preserve one source-bound Cargo credit")
    expected_owned = bytearray(carriers["before"])
    need(expected_owned[cell] == 0, "Sand cargo replaced a preexisting structural material")
    expected_owned[cell] = 2
    need(carriers["after"] == expected_owned, "Complete raw owner lattice differs from exactly one Cargo cell credit")
    need(n1["geometry_revision"] > n0["geometry_revision"]
         and n1["geometry_revision"] == n1["applied_physics_revision"] == p1["geometry_revision"]
         and final["geometry_revision"] == n1["geometry_revision"]
         and final["applied_physics_revision"] == n1["geometry_revision"]
         and n1["geometry_pending"] is final["geometry_pending"] is False and abs(p1["mass"] - 64) < .001,
         "Actual native/physical geometry acknowledgement did not install the 63+1 material mass")

    need(supported["total_material_counts"][7] == before["total_material_counts"][7] == 63
         and supported["total_material_counts"][2] == before["total_material_counts"][2] == 0
         and painted["raw_world_material_counts"][2] == painted["total_material_counts"][2] == 1
         and after["raw_world_material_counts"][2] == 0 and after["total_material_counts"][2] == 1,
         "Stored Sand, owned cargo and complete material totals differ")
    for material in range(1, 256):
        need(before["total_material_counts"][material] == supported["total_material_counts"][material] - (45 if material == 1 else 0)
             and painted["total_material_counts"][material] == before["total_material_counts"][material] + (1 if material == 2 else 0)
             and after["total_material_counts"][material] == painted["total_material_counts"][material],
             "Independent all-material conservation failed for material " + str(material))
    return {"checks": receipt["checks"], "inventories": inventories, "mounted_actions": captions,
            "authored_input": {"original_path": str(authored_path), "retained_path": str(saved),
                              "bytes": len(authored_raw), "sha256": audit.digest(authored_raw), "setup": setup},
            "native_incarnation": incarnation, "actual_rid": p0["rid"], "cargo_cell": cargo[0],
            "natural_fall_native_ticks": rest["native_tick"] - detached["native_tick"],
            "natural_fall_physical_steps": rest["physical_step"] - detached["physical_step"],
            "ingress_native_ticks": n1["frame_tick"] - np["frame_tick"],
            "erased_wall_cells": 45, "painted_sand_cells": 1, "owned_sand_cells": 1,
            "all_255_materials_reconciled": True, "native_and_actual_mass_before": 63,
            "native_and_actual_mass_after": 64, "geometry_revision": n1["geometry_revision"]}


def run(args: argparse.Namespace) -> dict:
    need(sys.platform == "win32", "The integration-positive witness requires actual Windows")
    args.output.mkdir(parents=True, exist_ok=True)
    need(file_digest(args.audit_summary) == SUMMARY_SHA, "Original independent archive audit summary changed")
    previous = json.loads(args.audit_summary.read_bytes())
    need(previous["status"] == "passed" and previous["application_source"] == SOURCE
         and previous["application_tree"] == TREE and previous["qualification_run"] == audit.RUN
         and previous["qualification_attempt"] == 1 and previous["audit_source"] == PRIOR_AUDIT_SOURCE
         and previous["audit_run"] == PRIOR_AUDIT_RUN and previous["audit_attempt"] == 1,
         "Original evidence reuse is not the exact successful 5f archive audit")
    prior_raw = audit.api(f"/repos/{audit.REPO}/actions/runs/{PRIOR_AUDIT_RUN}")
    prior = json.loads(prior_raw)
    need(prior["head_sha"] == PRIOR_AUDIT_SOURCE and prior["run_attempt"] == 1
         and prior["status"] == "completed" and prior["conclusion"] == "success",
         "The previous independent audit and owner witnesses are not terminal PASS")
    save(args.output / "prior-audit-run.json", prior)
    _, _, _, selected = audit.metadata(args.output)
    args.work.mkdir(parents=True, exist_ok=False)
    outer, inner = args.work / "original-evaluator-artifact.zip", args.work / audit.INNER_NAME
    custody = audit.raw_artifact(selected["workbench-evaluator"], outer)
    need(custody == previous["artifacts"]["workbench-evaluator"], "Original evaluator artifact identity differs")
    audit.extract_inner(outer, inner)
    need(inner.stat().st_size == previous["principal_evaluator"]["bytes"]
         and file_digest(inner) == previous["principal_evaluator"]["sha256"],
         "New witness would execute different principal ZIP bytes")
    package = args.work / "Pristine Sand Workbench (1)"
    baseline = witness.extract_package(inner, package)
    save(args.output / "immutable-before.json", baseline)
    external = args.output / "external-inputs"
    external.mkdir()
    repo = DIRECTORY.parents[2]
    raw = audit.git(repo, "show", os.environ["GITHUB_SHA"] + ":" + OBSERVER.relative_to(repo).as_posix())
    need(audit.digest(raw) == args.observer_sha256, "Reviewed Sand observer bytes differ")
    observer = external / OBSERVER.name
    observer.write_bytes(raw)
    for source in (Path(__file__), *(DIRECTORY / name for name in HELPERS)):
        (external / source.name).write_bytes(source.read_bytes())
    env = dict(os.environ)
    for key in ("GITHUB_TOKEN", "GH_TOKEN"):
        env.pop(key, None)
    for directory in ("Roaming", "Local"):
        (args.work / "fresh-user-data" / directory).mkdir(parents=True)
    env.update(CYBERSAND_SOURCE_REVISION=SOURCE, CYBERSAND_PACKAGE_MANIFEST=str(package / witness.MANIFEST),
               APPDATA=str(args.work / "fresh-user-data" / "Roaming"),
               LOCALAPPDATA=str(args.work / "fresh-user-data" / "Local"))
    raw_root = args.output / "sand-raw"
    raw_root.mkdir()
    env["CYBERSAND_TEST_ARTIFACT_DIR"] = str(raw_root)
    engine = str(package / witness.CONSOLE)
    common = [engine, "--headless", "--path", str(package / "godot")]
    nonce, receipt_path = secrets.token_hex(24), args.output / "sand-receipt.json"
    try:
        _, imported = witness.process([*common, "--editor", "--quit"], "import", env, package, args.output, 1200)
        receipt, executed = witness.process(
            [*common, "--script", str(observer), "--", "--objectshard-m4-workbench",
             "--nonce=" + nonce, "--output=" + str(receipt_path)],
            "sand", env, package, args.output, 300, receipt_path=receipt_path, schema=SCHEMA)
        reviewed = verify_result(receipt, nonce, raw_root, package, args.observer_sha256,
                                 args.work / "fresh-user-data", args.output)
    finally:
        after = witness.immutable(package, allow_generated=True)
        need(after["manifest_sha256"] == baseline["manifest_sha256"]
             and after["payload_files"] == baseline["payload_files"], "Immutable package changed during new Sand witness")
        save(args.output / "immutable-after.json", after)
    summary = {"schema": "objectshard-m4-ordinary-sand-lodging-independent-review-v1", "status": "passed",
               "application_source": SOURCE, "application_tree": TREE, "qualification_run": audit.RUN,
               "original_independent_audit_run": PRIOR_AUDIT_RUN, "original_summary_sha256": SUMMARY_SHA,
               "new_witness_source": os.environ["GITHUB_SHA"], "new_witness_run": int(os.environ["GITHUB_RUN_ID"]),
               "new_witness_attempt": int(os.environ["GITHUB_RUN_ATTEMPT"]),
               "principal_evaluator": previous["principal_evaluator"], "original_evaluator_artifact": custody,
               "helper_git_blobs": HELPERS, "observer_sha256": args.observer_sha256,
               "runner_sha256": file_digest(Path(__file__)), "nonce": nonce,
               "import": witness.compact_process("import", imported, args.output),
               "process": witness.compact_process("sand", executed, args.output),
               "receipt": {"bytes": receipt_path.stat().st_size, "sha256": file_digest(receipt_path)},
               "independent_review": reviewed, "immutable_payload_unchanged": True,
               "scope": "One new headless Windows ordinary Sand-positive witness; identical prior-qualified package. "
                        "No native build, archived full matrix or owner/cut witness was rerun.",
               "physical_owner_acceptance": "HOLD"}
    save(args.output / "summary.json", summary)
    for filename in ("summary.json", "sand-receipt.json"):
        audit.emit_original_bytes("OBJECTSHARD_M4_ORIGINAL_JSON", {
            "filename": filename, "application_source": SOURCE, "qualification_run": audit.RUN},
            (args.output / filename).read_bytes())
    print("OBJECTSHARD_M4_ORDINARY_SAND_REVIEW " + json.dumps({
        "status": "passed", "source": SOURCE, "checks": receipt["checks"],
        "immutable_payload_unchanged": True, "physical_owner_acceptance": "HOLD"}), flush=True)
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("audit-summary", "output", "work"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--observer-sha256", required=True)
    args = parser.parse_args()
    args.audit_summary, args.output, args.work = (p.resolve() for p in (args.audit_summary, args.output, args.work))
    try:
        run(args)
    except Exception as error:
        save(args.output / "runner-failure.json", {"status": "failed", "application_source": SOURCE,
             "error_type": type(error).__name__, "error": str(error), "physical_owner_acceptance": "HOLD"})
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
