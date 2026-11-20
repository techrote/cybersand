#!/usr/bin/env python3
"""Publish only a source-qualified 80-Gentek Linux/Windows candidate.

The established publisher retains Git input ledgers, dependency pins, branch
leases, Git LFS custody and four-path staging. This isolated wrapper adds the
complete native catalogue/gallery and ordinary Workbench author/reopen gates.
It does not alter the historical GEN-007 publisher or grant merge authority.
"""
from __future__ import annotations

import argparse
import hashlib
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import re
import shutil
import sys

_spec = spec_from_file_location("_gentek80_architecture_publisher",
                              Path(__file__).with_name("gen007_architectural_runtime_publication.py"))
base = module_from_spec(_spec)
_spec.loader.exec_module(base)
engine = base.engine
engine.BRANCH = "integration/gentek-80-001"
engine.WORKFLOW = ".github/workflows/gentek80-qualification.yml"
engine.REQUEST = "tools/ci/gentek80_publish_request.json"
engine.EVIDENCE = "docs/research/gentek-80-integration-001.md"
engine.BUNDLE_PREFIX = "gentek80-validated"
PUBLIC_GALLERY_MANIFEST = "docs/images/gentek80-integration/gallery-manifest.json"
engine.REQUEST_VALUE = {
    "schema": "gentek80-runtime-publish-request-v1",
    "family": "gen007-architectural-generator",
    "variant": "72-repaired-classic-plus-eight-showcases",
    "scope": "linux-windows-80-gentek-graphical-workbench-gallery-flatten-owner-package",
    "intent": "publish-source-matched-runtimes",
}
engine.BUILD_EXACT = set(engine.BUILD_EXACT) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/gentek80_runtime_publication.py",
    "tools/ci/test_gentek80_runtime_publication.py",
    "tools/ci/build_gentek80_runtime.py",
    "tools/ci/run_gentek80_native.py",
    "tools/ci/execution_policy.py",
    "tools/ci/run_timed_command.py",
    "godot/tools/qualify_gentek80_workbench.gd",
    "godot/tools/capture_gentek80.gd",
    "tools/architecture/gentek80_campaign.py",
    "tools/architecture/gentek80_workbench.py",
    "tools/architecture/check_gentek80_workbench_receipt.py",
    "tools/architecture/gentek80_repair_comparison.py",
    "tools/architecture/test_gentek80_campaign.py",
    "docs/operations/gentek80-evaluation.md",
    "tools/architecture/compiler_cache.py",
    "tools/architecture/test_compiler_cache.py",
    "tools/architecture/compare_interlaced_compilers.py",
    "tools/architecture/test_compare_interlaced_compilers.py",
    "tools/architecture/render_interlaced_viaduct.py",
    "tools/architecture/interlaced_viaduct_export.cpp",
    "tools/architecture/qualify_interlaced.py",
    "tools/architecture/test_qualify_interlaced.py",
    "tools/architecture/classic_repair_comparison.py",
    "tools/architecture/test_classic_repair_comparison.py",
    "docs/images/gentek-80/classic-review-repair-oracle.json",
    PUBLIC_GALLERY_MANIFEST,
}
engine.CASE_MARKERS = dict(engine.CASE_MARKERS,
    test_architectural_generator=r"ARCHITECTURE_RESULTS phase=native checks=[1-9][0-9]* failures=0 complete=true",
    test_architectural_generator_ui=r"ARCHITECTURAL_UI checks=[1-9][0-9]* failures=0")
engine.EXECUTION_SCOPE = (
    "Exact-source Linux/Windows full architectural, legacy-material and graphical "
    "style-card/author/reopen/multistyle gates; 80 distinct Genteks with 520 native "
    "PNG captures, 240 input refusals and 80 independent-process replays; ordinary "
    "graphical Workbench selection/generation/edit/save/reopen for all 80; graphical "
    "512x512 GEN-008 Flatten recovery; independently extracted Windows owner-package "
    "architecture, Flatten and all-80 Workbench replay; all 80 fresh defaults "
    "match the committed public gallery's exact rendering inputs and native/pixel hashes."
)
FULL_PHASES = base.FULL_PHASES
OWNER_PHASES = base.OWNER_PHASES
COUNTS = dict(base.COUNTS)
WORKBENCH_PHASES = ("import", "author", "reopen", "source-stability")
COMMON_PROFILES = {"default", "seed-1701", "compact", "tall", "material-controls", "large-1024"}
SHOWCASE_PROFILES = {"windows-off", "doors-off", "signed-origin", "thin", "heavy"}
REJECTION_PROFILES = {"room-outside-bounds", "door-does-not-fit", "reserved-material-10"}
FLATTEN_SCRIPTS = {
    "scripts/main.gd", "scripts/shared_workbench.gd", "scripts/simulation_worker.gd",
    "scripts/microscenario_host.gd", "scripts/workbench_setup.gd",
    "scripts/workbench_material_baseline.gd", "scripts/workbench_generated_map.gd",
    "scripts/workbench_paint_editor_history.gd", "scripts/workbench_paint_editor_controller.gd",
    "scripts/workbench_paint_editor_executor.gd", "scripts/art_batch_executor.gd",
    "tests/test_workbench_flatten.gd", "tests/test_workbench_material_baseline.gd",
    "tests/flatten_save_fault_child.gd",
}
FLATTEN_OWNER_SCRIPT = "tests/test_workbench_flatten_owner_failure.gd"
FLATTEN_RESULTS = ("flatten-import", "standalone-format-adversarial",
                   "side-512-workers-1-author", "side-512-workers-1-reopen",
                   "owner-failure-author", "owner-failure-reopen")
engine.BUILD_EXACT |= {"godot/" + name for name in FLATTEN_SCRIPTS | {FLATTEN_OWNER_SCRIPT}}
GALLERY_FILES = {
    "gallery_identity": "campaign-identity.json",
    "gallery_campaign": "native-campaign.json",
    "gallery_reload": "process-reload.json",
    "gallery_catalogue": "catalogue.json",
    "gallery_pixels": "pixel-and-connectivity-verification.json",
    "gallery_build": "runtime-build-ledger.json",
    "gallery_reference": "reference-gallery.json",
    "gallery_comparison": "reference-gallery-comparison.json",
}
RECEIPTS = {**base.RECEIPTS, "workbench": "gentek80-workbench-qualification.json",
            "package_workbench": "gentek80-package-workbench-qualification.json",
            "flatten_results": "gentek80-flatten-results.json",
            "package_flatten_results": "gentek80-package-flatten-results.json",
            **{name: "gentek80-" + filename for name, filename in GALLERY_FILES.items()}}


def read_json(path: Path) -> dict:
    try:
        result = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError, UnicodeError) as error:
        raise RuntimeError("Missing or malformed publication receipt: " + str(path)) from error
    engine.require(isinstance(result, dict), "Invalid publication receipt: " + str(path))
    return result


def exact_int(value: object, expected: int) -> bool:
    return type(value) is int and value == expected


def positive_int(value: object, minimum: int = 1) -> bool:
    return type(value) is int and minimum <= value <= 10_000_000


def hash_value(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def rows(value: object, message: str) -> list[dict]:
    engine.require(isinstance(value, list) and all(isinstance(row, dict) for row in value), message)
    return value


def read_flatten_results(path: Path) -> list[dict]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError, UnicodeError) as error:
        raise RuntimeError("Missing or malformed Flatten process receipts: " + str(path)) from error
    return rows(value, "Flatten process receipts must be a list of execution records")


def validate_flatten_results(value: list[dict], native_hash: str, platform: str, build_inputs: dict) -> None:
    """Bind the inherited Flatten execution to this runtime and committed scripts."""
    value = rows(value, "Malformed Flatten process receipts")
    engine.require([row.get("label") for row in value] == list(FLATTEN_RESULTS),
                   "Flatten import, adversarial, author/reopen or failed-owner recovery is missing")
    engine.require(all(row.get("status") == "passed" and exact_int(row.get("exit_code"), 0)
                       and positive_int(row.get("pid")) and hash_value(row.get("engine_executable_sha256"))
                       for row in value), "Flatten contains a failed or unmeasured process")
    engine.require(len({row["engine_executable_sha256"] for row in value}) == 1,
                   "Flatten processes used different Godot engine bytes")
    completions = []
    for row in value[2:]:
        completion = row.get("completion")
        owner = row["label"].startswith("owner-failure-")
        phase = "reopen" if row["label"].endswith("-reopen") else "author"
        engine.require(isinstance(completion, dict) and completion.get("completed") is True
                       and completion.get("failures") == [] and completion.get("phase") == phase
                       and positive_int(completion.get("checks"))
                       and exact_int(completion.get("pid"), row["pid"])
                       and isinstance(completion.get("process_instance"), str)
                       and bool(completion["process_instance"])
                       and exact_int(completion.get("side"), 512)
                       and exact_int(completion.get("canonical_bytes"), 512 * 512 * 2),
                       "Flatten process did not complete its native phase")
        engine.require((owner and completion.get("schema") == "gen008-flatten-owner-failure-v1")
                       or (not owner and exact_int(completion.get("workers"), 1)),
                       "Wrong Flatten native case or failed-owner receipt")
        identity = completion.get("source_identity")
        scripts = FLATTEN_SCRIPTS | ({FLATTEN_OWNER_SCRIPT} if owner else set())
        engine.require(isinstance(identity, dict) and identity.get("native_sha256") == native_hash
                       and identity.get("os") == ("Windows" if platform == "windows" else "Linux")
                       and isinstance(identity.get("display"), str) and bool(identity["display"])
                       and identity["display"].lower() != "headless"
                       and all(hash_value(build_inputs.get("godot/" + name))
                               and identity.get(name) == build_inputs["godot/" + name] for name in scripts),
                       "Flatten is not graphical on the target OS or names stale runtime/script inputs")
        completions.append(completion)
    for author, reopen in (completions[:2], completions[2:]):
        engine.require(author["pid"] != reopen["pid"]
                       and author["process_instance"] != reopen["process_instance"]
                       and author["source_identity"] == reopen["source_identity"],
                       "Flatten reopen did not use an independent source-matched process")
    owner_author, owner_reopen = completions[2:]
    engine.require(all(hash_value(owner_author.get(key)) and owner_author[key] == owner_reopen.get(key)
                       for key in ("expected_plane_sha256", "saved_baseline_sha256", "saved_file_sha256"))
                   and owner_reopen.get("reconstructed_plane_sha256") == owner_author["expected_plane_sha256"],
                   "Flatten failed-owner recovery did not reconstruct the saved material baseline")


def validate_architecture(value: dict, source: str, native_hash: str, *, owner: bool = False) -> None:
    engine.require(exact_int(value.get("schema"), 1) and value.get("passed") is True
                   and exact_int(value.get("failures"), 0) and value.get("graphical_requested") is True
                   and value.get("source_commit") == source and value.get("runtime_sha256") == native_hash,
                   "Architecture execution is not complete, graphical or source/runtime matched")
    cases = rows(value.get("cases"), "Malformed architectural phase receipts")
    phases = OWNER_PHASES if owner else FULL_PHASES
    engine.require([row.get("case") for row in cases] == list(phases)
                   and all(row.get("passed") is True for row in cases),
                   "Architecture native, UI, legacy, owner or source-stability phase missing/failed")
    for row in cases:
        phase = row["case"]
        if phase in COUNTS:
            completion = row.get("completion")
            engine.require(isinstance(completion, list) and len(completion) == 1
                           and isinstance(completion[0], str) and completion[0].isdecimal()
                           and int(COUNTS[phase]) <= int(completion[0]) <= 10_000_000,
                           "Architectural assertion count is missing or below its retained gate: " + phase)
        if phase == "ui":
            completion = row.get("completion")
            match = re.fullmatch(r"ARCHITECTURAL_UI checks=([0-9]+) failures=0", completion[0]) \
                if isinstance(completion, list) and len(completion) == 1 and isinstance(completion[0], str) else None
            engine.require(match is not None and 56 <= int(match[1]) <= 10_000_000,
                           "Graphical style-card completion marker is missing or incomplete")


def validate_workbench(value: dict, source: str, native_hash: str, platform: str) -> list[str]:
    engine.require(value.get("schema") == "gentek80-workbench-qualification-v1"
                   and value.get("passed") is True and exact_int(value.get("failures"), 0)
                   and value.get("source_commit") == source and value.get("runtime_sha256") == native_hash
                   and value.get("graphical_requested") is True and value.get("platform") == platform
                   and exact_int(value.get("smoke"), 0) and value.get("independent_processes") is True
                   and value.get("material_and_recipe_replay") is True,
                   "All-80 Workbench is not graphical, passing or source/runtime/platform matched")
    results = rows(value.get("results"), "Malformed Workbench results")
    engine.require([row.get("case") for row in results] == list(WORKBENCH_PHASES)
                   and all(row.get("passed") is True for row in results),
                   "Workbench import, author, reopen or source stability missing/failed")
    for row in results[:-1]:
        engine.require(exact_int(row.get("returncode"), 0) and row.get("timed_out") is False,
                       "Workbench process failed or timed out")
    phases = []
    for name in ("author", "reopen"):
        phase = value.get(name)
        engine.require(isinstance(phase, dict)
                       and phase.get("schema") == "gentek80-workbench-phase-v1"
                       and phase.get("phase") == name and phase.get("completed") is True
                       and phase.get("source_commit") == source
                       and exact_int(phase.get("styles"), 80) and exact_int(phase.get("failures"), 0)
                       and positive_int(phase.get("checks")) and positive_int(phase.get("process_id"))
                       and isinstance(phase.get("display"), str) and bool(phase["display"])
                       and phase["display"].lower() != "headless",
                       "Workbench phase lacks all 80 completed styles: " + name)
        ids = phase.get("catalogue_ids")
        engine.require(isinstance(ids, list) and len(ids) == 80
                       and all(isinstance(entry, str) and bool(entry) for entry in ids)
                       and len(set(ids)) == 80, "Workbench catalogue identities are missing or duplicated")
        evidence = rows(phase.get("cases"), "Missing per-style Workbench execution receipts")
        evidence = [row for row in evidence if row.get("case") == "gentek80-" + name]
        engine.require(len(evidence) == 80
                       and all(row.get("preset_id") in ids and hash_value(row.get("source_sha256"))
                               and hash_value(row.get("recipe_sha256")) for row in evidence)
                       and len({row["preset_id"] for row in evidence}) == 80,
                       "Workbench did not execute each style exactly once")
        phases.append(phase)
    engine.require(phases[0]["process_id"] != phases[1]["process_id"]
                   and phases[0]["catalogue_ids"] == phases[1]["catalogue_ids"],
                   "Workbench reopen is not an independent process with the same complete catalogue")
    captured = {row["preset_id"]: (row["source_sha256"], row["recipe_sha256"])
                for row in phases[0]["cases"] if row.get("case") == "gentek80-author"}
    reloaded = {row["preset_id"]: (row["source_sha256"], row["recipe_sha256"])
                for row in phases[1]["cases"] if row.get("case") == "gentek80-reopen"}
    engine.require(captured == reloaded, "Workbench material/recipe reconstruction diverged in the new process")
    return phases[0]["catalogue_ids"]


def validate_gallery(verified: dict[str, dict], source: str, native_hash: str,
                     tree: str, ledger: dict) -> list[str]:
    identity, campaign = verified["gallery_identity"], verified["gallery_campaign"]
    replay, catalogue = verified["gallery_reload"], verified["gallery_catalogue"]
    pixels, build = verified["gallery_pixels"], verified["gallery_build"]
    boundary, runtime = identity.get("source"), identity.get("runtime")
    engine.require(identity.get("status") == "pass" and exact_int(identity.get("schema"), 1)
                   and identity.get("scope") == "complete 80-Gentek catalogue"
                   and identity.get("source_and_runtime_unchanged") is True
                   and exact_int(identity.get("original_native_pngs"), 520)
                   and exact_int(identity.get("distinct_default_genteks"), 80)
                   and exact_int(identity.get("replayed_default_genteks"), 80)
                   and isinstance(runtime, dict) and runtime.get("sha256") == native_hash
                   and isinstance(boundary, dict) and boundary.get("commit") == source
                   and boundary.get("tree") == tree and boundary.get("uncommitted_source_paths") == [],
                   "Gallery is partial, dirty, failed or source/runtime mismatched")
    engine.require(isinstance(boundary.get("inputs"), dict)
                   and all(boundary["inputs"].get(path) == value for path, value in ledger.items()),
                   "Gallery native source ledger differs from built source")
    engine.require(build.get("schema") == "gentek80-native-build-v1"
                   and exact_int(build.get("returncode"), 0), "Gallery has no successful independent runtime build")
    base.validate_source(build, source, native_hash, tree, ledger)
    processes = rows(identity.get("processes"), "Malformed gallery process records")
    engine.require([row.get("phase") for row in processes] == ["capture", "replay"]
                   and all(exact_int(row.get("returncode"), 0) and row.get("timed_out") is False
                           and row.get("unexpected_diagnostics") == [] and hash_value(row.get("log_sha256"))
                           for row in processes), "Gallery capture/replay process failed or was skipped")
    for value, phase in ((campaign, "capture"), (replay, "replay")):
        engine.require(exact_int(value.get("schema"), 1) and value.get("phase") == phase
                       and value.get("complete") is True and value.get("failures") == []
                       and positive_int(value.get("checks")), "Native gallery phase is incomplete: " + phase)
    presets = rows(catalogue.get("genteks"), "Malformed native/Godot catalogue")
    engine.require(len(presets) == 80, "Gallery catalogue does not contain exactly 80 Genteks")
    modules = [preset.get("module") for preset in presets]
    ids = [preset.get("id") for preset in presets]
    engine.require(all(isinstance(module, str) and module for module in modules)
                   and all(isinstance(preset_id, str) and preset_id for preset_id in ids)
                   and len(set(modules)) == 80 and len(set(ids)) == 80
                   and all(exact_int(preset.get("module_version"), 1) for preset in presets),
                   "Catalogue contains duplicate, orphaned or wrong-version Genteks")
    native = catalogue.get("native")
    native_modules = rows(native.get("modules") if isinstance(native, dict) else None,
                          "Native catalogue identities are missing")
    engine.require(all(isinstance(row.get("id"), str) and positive_int(row.get("version"))
                       for row in native_modules), "Malformed native module/version identity")
    native_pairs = [(row.get("id"), row.get("version")) for row in native_modules]
    engine.require(len(native_pairs) == 91 and len(set(native_pairs)) == 91
                   and all((module, 1) in native_pairs for module in modules),
                   "Native/Godot catalogue equivalence failed")
    cases = rows(campaign.get("cases"), "Malformed native material captures")
    engine.require(len(cases) == 520
                   and all(isinstance(case.get("name"), str) and case.get("status") == "pass" and case.get("module") in modules
                           and exact_int(case.get("module_version"), 1)
                           and hash_value(case.get("material_sha256"))
                           and hash_value(case.get("occupancy_sha256"))
                           and hash_value(case.get("recipe_sha256"))
                           and isinstance(case.get("receipts"), dict) and bool(case["receipts"])
                           for case in cases)
                   and len({case["name"] for case in cases}) == 520,
                   "Missing, duplicate or invalid native PNG capture")
    defaults = {case["module"]: case for case in cases if case.get("profile") == "default"}
    engine.require(len(defaults) == 80
                   and len({case["material_sha256"] for case in defaults.values()}) == 80
                   and len({case["occupancy_sha256"] for case in defaults.values()}) == 80,
                   "All 80 default material and structural identities must be distinct")
    showcase_count = 0
    for module, preset_id in zip(modules, ids):
        family = defaults[module].get("family")
        engine.require(family in ("classic", "showcase"), "Missing Gentek structural family")
        expected = COMMON_PROFILES | (SHOWCASE_PROFILES if family == "showcase" else set())
        group = [case for case in cases if case["module"] == module]
        engine.require(len(group) == len(expected) and {case.get("profile") for case in group} == expected
                       and all(case.get("preset_id") == preset_id and case.get("family") == family for case in group),
                       "Seed/parameter coverage is incomplete for " + module)
        showcase_count += int(family == "showcase")
    engine.require(showcase_count == 8, "Expected 72 CLASSIC and eight showcases")
    rejected = rows(campaign.get("rejections"), "Malformed refusal campaign")
    engine.require(len(rejected) == 240 and all(row.get("status") == "pass"
                   and row.get("expected_refusal") is True and isinstance(row.get("error"), str)
                   and bool(row["error"]) and row.get("module") in modules
                   and isinstance(row.get("profile"), str) and row["profile"] in REJECTION_PROFILES for row in rejected)
                   and {(row.get("module"), row.get("profile")) for row in rejected}
                   == {(module, profile) for module in modules for profile in REJECTION_PROFILES},
                   "Every Gentek must retain all three explicit input refusals")
    reloaded = rows(replay.get("cases"), "Malformed independent-process replay")
    engine.require(len(reloaded) == 80 and all(row.get("module") in modules for row in reloaded)
                   and len({row.get("module") for row in reloaded}) == 80,
                   "Independent process did not replay all 80 defaults")
    for row in reloaded:
        original = defaults.get(row.get("module"))
        engine.require(original is not None and all(row.get(key) == original.get(key)
                       for key in ("name", "material_sha256", "recipe_sha256", "fingerprint", "receipts")),
                       "Independent-process material/recipe/fingerprint/receipt replay diverged")
    verified_pixels = rows(pixels.get("cases"), "Malformed native pixel verification")
    capture_by_name = {case["name"]: case for case in cases}
    engine.require(exact_int(pixels.get("schema"), 1) and len(verified_pixels) == 520
                   and all(isinstance(row.get("name"), str) for row in verified_pixels)
                   and len({row.get("name") for row in verified_pixels}) == 520,
                   "Every original PNG must have native pixel verification")
    for row in verified_pixels:
        original = capture_by_name.get(row.get("name"))
        engine.require(original is not None and row.get("native_pixels_verified") is True
                       and row.get("material_sha256") == original["material_sha256"]
                       and hash_value(row.get("png_sha256")), "Native PNG verification failed or differs from captured cells")
    return ids


def validate_reference_gallery(verified: dict[str, dict], source: str, native_hash: str,
                               tree: str, reference_hash: str) -> None:
    """Recompute the public S0/fresh candidate join instead of trusting a pass flag."""
    identity = verified["gallery_identity"]
    reference, comparison = verified["gallery_reference"], verified["gallery_comparison"]
    boundary = identity["source"]
    engine.require(identity.get("reference_gallery_comparison") == GALLERY_FILES["gallery_comparison"],
                   "Gallery did not execute the required public-reference comparison")
    engine.require(reference.get("schema") == "gentek80-public-gallery-v1"
                   and re.fullmatch(r"[0-9a-f]{40}", str(reference.get("source_commit", ""))) is not None
                   and re.fullmatch(r"[0-9a-f]{40}", str(reference.get("source_tree", ""))) is not None
                   and isinstance(boundary.get("inputs"), dict) and bool(boundary["inputs"])
                   and all(isinstance(path, str) and hash_value(value)
                           for path, value in boundary["inputs"].items())
                   and reference.get("rendering_inputs_sha256") == boundary["inputs"],
                   "Public gallery is missing its exact source identity or rendering inputs differ")
    engine.require(comparison.get("schema") == "gentek80-reference-comparison-v1"
                   and comparison.get("status") == "pass" and comparison.get("failures") == []
                   and comparison.get("reference_source_commit") == reference["source_commit"]
                   and comparison.get("reference_source_tree") == reference["source_tree"]
                   and comparison.get("candidate_source_commit") == source
                   and comparison.get("candidate_source_tree") == tree
                   and comparison.get("candidate_runtime_sha256") == native_hash
                   and hash_value(reference_hash)
                   and comparison.get("reference_manifest_sha256") == reference_hash
                   and comparison.get("rendering_inputs_equal") is True
                   and all(exact_int(comparison.get(key), 80)
                           for key in ("reference_defaults", "fresh_defaults", "matched_defaults")),
                   "Public gallery comparison is partial, failed or source/runtime/manifest mismatched")
    public = rows(reference.get("defaults"), "Malformed public gallery defaults")
    compared = rows(comparison.get("cases"), "Malformed public gallery comparison cases")
    captured = [case for case in verified["gallery_campaign"]["cases"] if case.get("profile") == "default"]
    for label, records in (("public", public), ("compared", compared), ("captured", captured)):
        engine.require(len(records) == 80
                       and all(isinstance(row.get("module"), str) and row["module"] for row in records)
                       and len({row["module"] for row in records}) == 80
                       and all(isinstance(row.get("preset_id"), str) and row["preset_id"] for row in records)
                       and len({row["preset_id"] for row in records}) == 80,
                       "Public reference must cover exactly 80 unique module/preset identities: " + label)
    old_by_module = {case["module"]: case for case in public}
    fresh_by_module = {case["module"]: case for case in captured}
    compared_by_module = {case["module"]: case for case in compared}
    pixels_by_name = {case["name"]: case for case in verified["gallery_pixels"]["cases"]}
    engine.require(old_by_module.keys() == fresh_by_module.keys() == compared_by_module.keys(),
                   "Public gallery and fresh native/comparison module identities differ")
    hashes = ("material_sha256", "occupancy_sha256", "recipe_sha256", "project_sha256")
    fields = ("preset_id", "extent", "seed", *hashes)
    for module, previous in old_by_module.items():
        fresh, result = fresh_by_module[module], compared_by_module[module]
        pixels = pixels_by_name.get(fresh.get("name"))
        extent = previous.get("extent")
        png = previous.get("png")
        engine.require(isinstance(extent, list) and len(extent) == 2
                       and all(positive_int(value) for value in extent)
                       and type(previous.get("seed")) is int
                       and isinstance(png, str) and bool(png) and "\\" not in png
                       and not Path(png).is_absolute() and ".." not in Path(png).parts
                       and all(hash_value(previous.get(key)) for key in (*hashes, "rgba_sha256", "png_sha256"))
                       and all(key in fresh and previous[key] == fresh[key] for key in fields)
                       and isinstance(pixels, dict) and pixels.get("native_pixels_verified") is True
                       and pixels.get("module") == module and pixels.get("profile") == "default"
                       and pixels.get("extent") == extent
                       and pixels.get("material_sha256") == fresh["material_sha256"]
                       and pixels.get("rgba_sha256") == previous["rgba_sha256"],
                       "Public gallery native/material/recipe/project/pixel comparison diverged: " + module)
        engine.require(result.get("matches") is True and result.get("preset_id") == fresh["preset_id"]
                       and result.get("material_sha256") == fresh["material_sha256"]
                       and result.get("rgba_sha256") == previous["rgba_sha256"],
                       "Public gallery comparison receipt differs from its recomputed case: " + module)


def verify_case_results(directory: Path, report: dict) -> None:
    source, platform = report["source_commit"], report["platform"]
    native_hash = report["runtime"]["sha256"]
    manifest = read_json(engine.manifest_path(directory, platform))
    engine.require(report.get("source_tree") == manifest.get("source_tree")
                   and isinstance(report.get("source_inputs"), dict) and bool(report["source_inputs"])
                   and report["source_inputs"] == manifest.get("source_inputs"),
                   "Execution source tree/input ledger differs from the built manifest")
    required = {"architecture", "identity", "flatten", "flatten_results", "workbench", *GALLERY_FILES}
    if platform == "windows":
        required |= {"package", "package_flatten", "package_flatten_results", "package_workbench"}
    receipts = report.get("receipts")
    engine.require(isinstance(receipts, dict) and set(receipts) == required,
                   "Missing platform-specific architecture/gallery/Workbench/package execution receipts")
    verified = {}
    for name in sorted(required):
        row, path = receipts[name], directory / RECEIPTS[name]
        engine.require(isinstance(row, dict) and path.is_file() and not path.is_symlink()
                       and row.get("filename") == RECEIPTS[name]
                       and engine.runner.sha256(path) == row.get("sha256"),
                       "Original execution receipt missing or modified: " + name)
        verified[name] = read_flatten_results(path) if name.endswith("flatten_results") else read_json(path)
    validate_architecture(verified["architecture"], source, native_hash)
    base.validate_source(verified["identity"], source, native_hash, report["source_tree"], report["source_inputs"])
    base.validate_flatten(verified["flatten"])
    validate_flatten_results(verified["flatten_results"], native_hash, platform, manifest["build_inputs"])
    workbench_ids = validate_workbench(verified["workbench"], source, native_hash, platform)
    gallery_ids = validate_gallery(verified, source, native_hash, report["source_tree"], report["source_inputs"])
    reference = directory / RECEIPTS["gallery_reference"]
    engine.require(hashlib.sha256(reference.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
                   == manifest["build_inputs"].get(PUBLIC_GALLERY_MANIFEST),
                   "Retained public gallery manifest differs from its committed build input")
    validate_reference_gallery(verified, source, native_hash, report["source_tree"],
                               receipts["gallery_reference"]["sha256"])
    engine.require(set(workbench_ids) == set(gallery_ids), "Workbench and rendered catalogue identities differ")
    if platform == "windows":
        validate_architecture(verified["package"], source, native_hash, owner=True)
        base.validate_flatten(verified["package_flatten"])
        validate_flatten_results(verified["package_flatten_results"], native_hash, platform, manifest["build_inputs"])
        package_ids = validate_workbench(verified["package_workbench"], source, native_hash, platform)
        engine.require(package_ids == workbench_ids, "Packaged Workbench catalogue differs from tested source")
    engine.require(report.get("scope") == engine.EXECUTION_SCOPE, "Publication acceptance scope was altered")


engine.verify_case_results = verify_case_results


def accept(args: argparse.Namespace) -> None:
    engine.require((args.platform == "windows" and sys.platform == "win32")
                   or (args.platform == "linux" and sys.platform.startswith("linux")),
                   "Runtime acceptance must execute on the real target OS")
    engine.check_source(args)
    manifest = engine.verify_bundle(args.bundle, args.platform, args.source_sha, validated=False)
    native = engine.ROOT / engine.RUNTIMES[args.platform]
    engine.require(engine.runtime_identity(native, args.platform)
                   == {key: manifest[key] for key in ("artifact", "sha256", "size")},
                   "Actual qualified library differs from source-built artifact")
    rapier_path, rapier_sha = engine.RAPIER[args.platform]
    engine.require(engine.runner.sha256(engine.ROOT / rapier_path) == rapier_sha,
                   "Target-OS Rapier runtime differs from its pin")
    archive_key = "archive_sha256" if args.platform == "linux" else "archive_sha512"
    archive_hash = engine.runner.sha256(args.godot_archive) if args.platform == "linux" \
        else hashlib.sha512(args.godot_archive.read_bytes()).hexdigest()
    expected_hash = engine.GODOT_LINUX_SHA256 if args.platform == "linux" else engine.windows.GODOT_SHA512
    engine.require(archive_hash == expected_hash, "Godot 4.7 archive pin mismatch")
    paths = {"architecture": args.qualification / "qualification.json",
             "identity": args.qualification / "source-runtime-identity.json",
             "flatten": args.flatten / "qualification.json",
             "flatten_results": args.flatten / "results.json",
             "workbench": args.workbench / "qualification.json",
             **{name: args.gallery / filename for name, filename in GALLERY_FILES.items()}}
    if args.platform == "windows":
        engine.require(args.package is not None and args.package_flatten is not None
                       and args.package_workbench is not None,
                       "Windows acceptance requires independently extracted owner/package replays")
        paths.update(package=args.package / "qualification.json",
                     package_flatten=args.package_flatten / "qualification.json",
                     package_flatten_results=args.package_flatten / "results.json",
                     package_workbench=args.package_workbench / "qualification.json")
    receipts = {}
    for name, origin in paths.items():
        target = args.bundle / RECEIPTS[name]
        engine.require(origin.is_file() and not origin.is_symlink(), "Original execution evidence missing: " + str(origin))
        shutil.copyfile(origin, target)
        receipts[name] = {"filename": RECEIPTS[name], "sha256": engine.runner.sha256(target)}
    report = {"schema_version": 1, "source_commit": args.source_sha,
              "source_tree": manifest["source_tree"], "platform": args.platform,
              "source_inputs": manifest["source_inputs"],
              "runtime": {key: manifest[key] for key in ("artifact", "sha256", "size")},
              "godot": {"version": engine.GODOT_VERSION, archive_key: archive_hash},
              "rapier_sha256": rapier_sha, "status": "passed", "completed": True,
              "results": [], "scope": engine.EXECUTION_SCOPE, "receipts": receipts}
    verify_case_results(args.bundle, report)
    engine.require(engine.input_ledgers(args.source_sha)
                   == {key: manifest[key] for key in ("source_inputs", "build_inputs")},
                   "Test or build inputs changed between compilation and validation")
    engine.write_json(args.bundle / "validation.json", report)
    manifest.update({"status": "validated-development-runtime",
                     "workflow_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
                     "validated_platform": args.platform.title() + " x86_64 / real graphical Godot 4.7",
                     "acceptance": "Source-matched built library passed: " + engine.EXECUTION_SCOPE,
                     "validation_output": engine.BUNDLE_PREFIX + "-" + args.platform + "-"
                                          + os.environ["GITHUB_RUN_ID"] + "/validation.json",
                     "validation_sha256": engine.runner.sha256(args.bundle / "validation.json"),
                     "other_platforms": "No human Windows 11/GPU hardware acceptance is asserted."})
    engine.write_json(engine.manifest_path(args.bundle, args.platform), manifest)
    engine.verify_bundle(args.bundle, args.platform, args.source_sha, validated=True)


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "accept":
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("command", choices=("accept",))
        parser.add_argument("--source-sha", required=True)
        parser.add_argument("--platform", choices=("linux", "windows"), required=True)
        for name in ("bundle", "qualification", "flatten", "workbench", "gallery", "godot-archive"):
            parser.add_argument("--" + name, type=Path, required=True)
        for name in ("package", "package-flatten", "package-workbench"):
            parser.add_argument("--" + name, type=Path)
        accept(parser.parse_args())
        return 0
    return engine.main()


if __name__ == "__main__":
    raise SystemExit(main())
