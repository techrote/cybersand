#!/usr/bin/env python3
"""Bind real dual-composition Workbench outputs to the exact-source owner ZIP.

Only the same CI run's successful graphical native author and fresh-process
reopen is admitted. Copy original JSON bytes, never synthesize examples or
silently substitute evidence. This helper is final-Gentek-specific, so the
shared EXPLORE and Wave packaging workflows remain unchanged.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

PROFILE = Path("profile/roaming/Godot/app_userdata/Cyber Sand Reference Sandbox")
DEST = Path("examples/gentek80-final")
NAMES = ("gentek80-five-showcase-a", "gentek80-five-showcase-b-negative")
MODULES = (
    ("cathedral_megaframe", "seeded_typology_megablock", "megatruss_station",
     "interlaced_viaduct", "suspended_arcology"),
    ("metabolist_spine", "rosework_gatehouse", "interlock_brutalism",
     "cathedral_megaframe", "megatruss_station"),
)
SHARES = ([30, 25, 20, 15, 10], [20, 20, 20, 20, 20])
README = """# Qualified 80-Gentek example projects and starting maps

These original JSON files were copied byte-for-byte from the same exact-source
Windows graphical Workbench campaign that produced this package. The complete
source, native, file and process identities appear in candidate-manifest.json
under gentek80_acceptance_examples. No extra simulated content was generated.

- *.project.json: five-active-advanced-Gentek editable projects with equal
  and unequal shares, one signed origin, varied geometry/materials/doors/windows
  and deterioration. In the ordinary Architectural Generator choose Load
  and select the project file from this directory.
- setup-*.json: two named authored Workbench starting maps, NOT evolved physics.
  After launching the checked owner evaluator once, copy the maps (without
  changing their setup- filenames) into the current isolated owner profile's
  Roaming/Godot/app_userdata/Cyber Sand Reference Sandbox/workbench directory.
  The checked launcher reports the source/native-keyed profile. Never replace
  an existing map without deliberately backing it up. Relaunch and Load the
  corresponding named starting maps.

This is hosted Windows evidence, not physical NVIDIA/Windows 11 owner approval.
Disconnected decorative regions may require manual traversability assessment.
"""


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(2 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def verify_original_frames(evidence: Path, record: dict) -> None:
    frames = record.get("original_frames", [])
    if len(frames) < 4:
        raise ValueError("Four original graphical evidence frames required")
    for frame in frames:
        name = frame.get("name", "")
        if not re.fullmatch(r"[A-Za-z0-9_.-]+\.png", name):
            raise ValueError("Unsafe or missing original frame name")
        path = evidence / name
        if not path.is_file() or file_digest(path) != frame.get("sha256"):
            raise ValueError("Original graphical evidence digest mismatch: " + name)


def stage(candidate: Path, evidence: Path, source: str) -> dict:
    if not re.fullmatch(r"[0-9a-f]{40}", source):
        raise ValueError("Expected source must be an exact lowercase Git SHA")
    candidate, evidence = candidate.resolve(strict=True), evidence.resolve(strict=True)
    manifest_path, receipt_path = candidate / "candidate-manifest.json", evidence / "qualification.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    receipt_bytes = receipt_path.read_bytes()
    record = json.loads(receipt_bytes)
    if manifest.get("schema") != 1 or manifest.get("source_commit") != source:
        raise ValueError("Source-exact candidate manifest mismatch")
    if record.get("schema") != "gentek80-five-showcase-source-exact-v1" or record.get("source_commit") != source:
        raise ValueError("Source-exact graphical Workbench qualification missing")
    if record.get("source_tree") != manifest.get("source_tree"):
        raise ValueError("Qualifying source tree differs from packaged source tree")
    if not all(record.get(k) is True for k in (
        "passed", "graphical", "independent_processes", "matched_project_material_recipe"
    )):
        raise ValueError("Must pass native graphical author and fresh-process reopen")
    verify_original_frames(evidence, record)
    original = {p.relative_to(candidate).as_posix(): file_digest(p)
                for p in candidate.rglob("*") if p.is_file() and p != manifest_path}
    if original != manifest.get("files_sha256"):
        raise ValueError("Pre-example candidate has missing, modified or unlisted files")
    if (candidate / DEST).exists():
        raise ValueError("Examples directory already exists; refusing overwrite")
    author, reopen = record.get("author", {}), record.get("reopen", {})
    if not author.get("process_id") or not reopen.get("process_id") or author["process_id"] == reopen["process_id"]:
        raise ValueError("Author and reopen must have distinct real process IDs")
    matched = []
    for phase, entry in (("author", author), ("reopen", reopen)):
        if (entry.get("schema") != "gentek80-five-showcase-workbench-v1"
                or entry.get("phase") != phase or entry.get("complete") is not True
                or entry.get("failures") != 0):
            raise ValueError("Incomplete native phase: " + phase)
        cases = [c for c in entry.get("cases", []) if c.get("case") == "five-showcase-" + phase]
        if len(cases) != 2 or [x.get("name") for x in cases] != list(NAMES):
            raise ValueError("Two named five-active-showcase cases required in " + phase)
        for i, x in enumerate(cases):
            if (x.get("source_commit") != source or x.get("active_slots") != 5
                    or x.get("modules") != list(MODULES[i])
                    or x.get("shares") != SHARES[i]
                    or x.get("native_receipts", 0) < 1):
                raise ValueError("Wrong source/native five-style case: " + x.get("name", "?"))
        matched.append(cases)

    staged: dict[str, bytes] = {}
    identities: list[dict] = []
    for i, name in enumerate(NAMES):
        a, b = matched[0][i], matched[1][i]
        keys = ("project_file_sha256", "project_sha256", "source_sha256",
                "recipe_sha256", "seed", "origin", "shares", "modules", "configurations")
        if any(a.get(key) != b.get(key) for key in keys):
            raise ValueError("Project/material identity changed across fresh process: " + name)
        project_path = evidence / PROFILE / (name + ".json")
        map_path = evidence / PROFILE / "workbench" / ("setup-" + name + ".json")
        project_bytes, map_bytes = project_path.read_bytes(), map_path.read_bytes()
        if digest(project_bytes) != a["project_file_sha256"]:
            raise ValueError("Editable project hash differs from native receipt: " + name)
        project, saved_map = json.loads(project_bytes), json.loads(map_bytes)
        if (project.get("format") != "cybersand.architectural-project"
                or project.get("seed") != a["seed"] or project.get("origin") != a["origin"]
                or [x.get("preset", {}).get("module") for x in project.get("styles", [])] != a["modules"]
                or [x.get("share") for x in project.get("styles", [])] != a["shares"]):
            raise ValueError("Editable project parameters differ from receipt: " + name)
        generation = saved_map.get("generation", {})
        if (saved_map.get("format") != "cybersand-generated-start-v1"
                or generation.get("sha256") != a["source_sha256"]
                or generation.get("recipe_sha256") != a["recipe_sha256"]
                or generation.get("origin") != a["origin"]):
            raise ValueError("Starting map source/native recipe differs from receipt: " + name)
        if saved_map.get("starting_setup", {}).get("edits") != [[101, 99, 2, 58], [111, 99, 2, 0]]:
            raise ValueError("Starting map original paint/erase is missing or out-of-order: " + name)
        pkey = (DEST / (name + ".project.json")).as_posix()
        mkey = (DEST / ("setup-" + name + ".json")).as_posix()
        staged[pkey], staged[mkey] = project_bytes, map_bytes
        identities.append({
            "name": name, "project_sha256": digest(project_bytes), "map_sha256": digest(map_bytes),
            "native_material_sha256": a["source_sha256"], "recipe_sha256": a["recipe_sha256"],
            "seed": a["seed"], "origin": a["origin"], "module_ids": a["modules"], "shares": a["shares"]
        })
    staged[(DEST / "README.md").as_posix()] = README.encode("utf-8")

    # Publish only after every artifact was authenticated against the original
    # native and graphical receipt; the ZIP is produced only if this step passes.
    (candidate / DEST).mkdir(parents=True, exist_ok=False)
    for rel, body in staged.items():
        (candidate / rel).write_bytes(body)
        manifest["files_sha256"][rel] = digest(body)
    manifest["gentek80_acceptance_examples"] = {
        "schema": "gentek80-exact-source-example-archive-v1",
        "qualification_receipt_sha256": digest(receipt_bytes),
        "qualification_source_commit": source,
        "qualification_source_tree": record["source_tree"],
        "qualification_original_rendered_frames": len(record["original_frames"]),
        "author_process_id": author["process_id"], "reopen_process_id": reopen["process_id"],
        "generated_example_files_sha256": {path: digest(data) for path, data in staged.items()},
        "examples": identities,
        "authored_starts_not_evolved_physics": True,
        "qualification_native_sha256": record["runtime_sha256"],
        "package_native_sha256": manifest["native_sha256"]
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    actual = {p.relative_to(candidate).as_posix(): file_digest(p)
              for p in candidate.rglob("*") if p.is_file() and p != manifest_path}
    if actual != manifest["files_sha256"]:
        raise ValueError("Complete payload manifest failed after staging")
    return {"source_commit": source, "examples": len(identities),
            "files": len(actual), "qualification_receipt_sha256": digest(receipt_bytes),
            "candidate_manifest_sha256": file_digest(manifest_path), "verified": True}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--source", required=True)
    args = parser.parse_args()
    print(json.dumps(stage(args.candidate, args.evidence, args.source), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
