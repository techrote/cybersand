#!/usr/bin/env python3
"""Source-bound RAMCACHE/Strata integration regression and independent reader.

This is a registered integration subset, not a relabelled historical full
campaign. The original RAMCACHE 30-sample/crash campaign and Strata 9-scene
performance measurements remain separate. Every selected original assertion is
retained with an explicit bounded per-case deadline; quick unit budgets are
tighter than their donor campaign. Mainline Native/GDExtension remain separate.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import math
import ntpath
import os
from pathlib import Path
import posixpath
import re
import subprocess
import sys
import time
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import qualify_strata3_workbench as optics
import qualify_strata2_workbench as strata
import strata_process_metrics as metrics
import verify_ramcache_strata_goblin_storage as goblin_reader

custody = strata.custody
require, sha, write_json = custody.require, custody.sha, custody.write_json
REQUEST = "tools/ci/ramcache-strata-integration-request.json"
WORKFLOW = ".github/workflows/ramcache-strata-integration.yml"
MODES = ("ramcache", "strata", "shared")
# The extracted portable Lab subset does not replace any of the six source gates.
RUN_MODES = (*MODES, "lab")
LAB_LABELS = ("material-lab-author", "material-lab-reopen")
LAB_DEADLINE_SECONDS = 1800
LAB_CAPTURE_MAX_FPS = 1
EXTRA_INPUTS = (REQUEST, WORKFLOW, "tools/ci/ramcache_strata_qualification.py",
                "tools/package_ramcache_strata.py", "tools/ci/test_ramcache_strata_qualification.py",
                "tools/package_gen006_persistent_areas.py", "tools/ci/check_windows_package_modules.ps1",
                "tools/ci/strata3_cold_launcher.py",
                "tools/ci/verify_ramcache_strata_goblin_storage.py",
                "tools/ci/test_verify_ramcache_strata_goblin_storage.py",
                "tools/ci/ramcache_strata_lab_package.py",
                "tools/ci/test_ramcache_strata_lab_package.py",
                "tools/package_materials_lab_candidate.py",
                "tools/ci/mat_workbench_runtime_publication.py",
                "tools/ci/strata_generated_imports.py",
                "tools/ci/run_art_collaborative_gates.py",
                "tools/package_art_workbench_final.py", "tools/package_art_collaborative.py")
ANCHORS = {
    "accepted_main": "7a15691a7c537d07ff10a1bc4da9d46491c0b9d6",
    "ramcache_head": "af45bfb332f9822780db9304779ff0cdf55661df",
    "strata_head": "d37fea86dbed2d9ae4b22e59c676d98f525c1ea8",
    "excluded_objectshard_head": "1ec3f214662f7d5a0a38ff727b684c15b41c067b",
}
# These are source-owned tests, run with an actual display on both hosts.
# Integer-failure and list-failure records are handled explicitly by the reader.
SHARED = (
    ("test_workbench_wave_render", "WORKBENCH_WAVE_RENDER ", 600),
    ("test_workbench_actor_composition_native", "Workbench actor composition native:", 600),
    ("test_ambient_default_off_integration", "AMBIENT_DEFAULT_OFF ", 600),
    ("test_material_audition", "MATERIAL_AUDITION_RESULT ", 600),
    ("test_art_collaborative_native", "ART_COLLABORATIVE_NATIVE_RESULT ", 1800),
    ("test_art_architecture_workbench", "ART_ARCHITECTURE_WORKBENCH_RESULT ", 600),
    ("test_architecture_stage_native", "ARCHITECTURE_STAGE_NATIVE:", 600),
    ("test_goblin_contract", "GOBLIN_CONTRACT_RESULT ", 180),
    ("test_goblin_policies", "GOBLIN_POLICY_UNIT ", 180),
    ("test_workbench_reciprocal_runtime", "SWARM45_RUNTIME ", 180),
    ("test_workbench_reciprocal_controller", "SWARM004_CONTROLLER ", 300),
    ("swarm006_reciprocal_input", "SWARM006_INPUT_INTEGRITY ", 180),
    ("test_workbench_file_transaction", "FILE_TRANSACTION_RESULT ", 180),
)
RAMCACHE_UNITS = (
    ("test_persistent_area_cache", "GEN006_RAMCACHE_CACHE ", 180),
    ("test_persistent_area_clock", "GEN006_CLOCK ", 180),
    ("test_persistent_area_writeback", "GEN006_RAMCACHE_WRITEBACK ", 180),
    ("test_persistent_area_metadata_bounds", "GEN006_RAMCACHE_METADATA_BOUNDS ", 180),
    ("test_persistent_area_native_bridge", "GEN006_NATIVE_BRIDGE ", 300),
    ("test_persistent_area_residency_native", "GEN006_NATIVE_RESIDENCY_RESULT ", 300),
)
STRATA_NATIVE = (
    ("test_strata2_mounted_failures", "STRATA2_MOUNTED_FAILURES ", 600),
    ("test_strata2_workflow", "STRATA2_WORKFLOW ", 600),
    ("test_strata2_actor_route", "STRATA2_ACTOR_ROUTE ", 600),
)
HEX64 = re.compile(r"[0-9a-f]{64}")


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def validate_request(value: dict) -> dict:
    keys = {"schema", "sequence", "mission", *ANCHORS, "optional_optics_90_percent_gate",
            "classic_remains_default", "purpose"}
    require(isinstance(value, dict) and set(value) == keys
            and value["schema"] == "ramcache-strata-integration-request-v1"
            and value["mission"] == "RAMCACHE-STRATA-INTEGRATION-001"
            and type(value["sequence"]) is int and value["sequence"] > 0
            and all(value[k] == v for k, v in ANCHORS.items())
            and value["optional_optics_90_percent_gate"] == "owner-waived-2026-11-28"
            and value["classic_remains_default"] is True
            and isinstance(value["purpose"], str) and value["purpose"],
            "Unregistered integration request or changed owner acceptance boundary")
    return value


def identity() -> dict:
    result = optics.identity()
    for name in EXTRA_INPUTS:
        # EXTRA_INPUTS are explicitly registered text, including an eol=crlf
        # PowerShell helper. Binary art/runtime custody never uses this path.
        data = normalized_text((ROOT / name).read_bytes())
        require(data == custody.git("show", "HEAD:" + name), "Uncommitted integration input: " + name)
        result["source_inputs_sha256"][name] = hashlib.sha256(data).hexdigest()
    return result


def normalized_text(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n")


def native_reuse() -> dict:
    """Authenticate unchanged native inputs and the actual published pointers.

    A documentation/host integration does not become a new native build. Both
    retained original build identities remain explicit and unchanged.
    """
    current_paths = custody.windows.native_input_paths(ROOT)
    records = {}
    for platform in ("linux", "win32"):
        record = strata.retained_runtime_manifest(platform)
        suffix = ".linux" if platform == "linux" else ""
        path = "godot/addons/cybersand_native/runtime-provenance" + suffix + ".json"
        original = json.loads(custody.git("show", ANCHORS["ramcache_head"] + ":" + path))
        require(read(ROOT / path) == original, "Published native provenance was rewritten during host integration")
        require(set(record["native_source_inputs"]) == current_paths and len(current_paths) == 114,
                "Native input inventory changed; a source-matched rebuild is required")
        require(record["native_source_inputs"] == original["source_inputs"],
                "Native inputs differ from owner-qualified RAMCACHE")
        for name, digest in record["native_source_inputs"].items():
            require(sha(ROOT / name) == digest, "Changed native build input: " + name)
        require(record["cybersand_runtime"]["sha256"] == original["sha256"]
                and record["cybersand_runtime"]["size"] == original["size"]
                and record["runtime_source_commit"] == original["source_commit"]
                and record["runtime_build_commit"] == original["build_commit"],
                "An unqualified runtime replaced the accepted RAMCACHE publication")
        records[platform] = record
    require(records["linux"]["native_source_inputs"] == records["win32"]["native_source_inputs"],
            "Linux/Windows native input ledgers disagree")
    return {"disposition": "reuse-unchanged-published-native-inputs", "native_input_count": 114,
            "platforms": records}


def admission() -> dict:
    request = validate_request(read(ROOT / REQUEST))
    source = identity()
    for key in ("accepted_main", "ramcache_head", "strata_head"):
        outcome = subprocess.run(["git", "merge-base", "--is-ancestor", request[key], source["source_commit"]],
                                 cwd=ROOT, timeout=30, check=False)
        require(outcome.returncode == 0, "Integrated source does not retain " + key)
    # A missing excluded object is an admission failure, not evidence of exclusion.
    custody.git("cat-file", "-e", request["excluded_objectshard_head"] + "^{commit}")
    outcome = subprocess.run(["git", "merge-base", "--is-ancestor", request["excluded_objectshard_head"],
                              source["source_commit"]], cwd=ROOT, timeout=30, check=False)
    require(outcome.returncode == 1, "ObjectShard M4 is included or ancestry could not be proved")
    production = custody.git("ls-tree", "-r", "--name-only", "HEAD", "--", "native", "godot").decode().splitlines()
    require(not any(re.search(r"object[_-]?shard", name, re.I) for name in production),
            "Excluded ObjectShard production file found")
    return {"schema": "ramcache-strata-admission-v1", "request": request,
            "source_identity": source, "native_reuse": native_reuse(),
            "excluded_objectshard_ancestor": False,
            "qualification_scope": "Focused integration regression; broad Native/GDExtension gates remain separate",
            "performance_policy": {"classic_default": True, "optional_profile_original_target": 0.9,
                                   "optional_profile_target_disposition": request["optional_optics_90_percent_gate"],
                                   "new_performance_benchmark_claimed": False}}


def marker(text: str, prefix: str) -> str:
    found = [line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)]
    require(len(found) == 1, "Missing or duplicate completion marker: " + prefix)
    return found[0].strip()


def validate_marker(text: str, prefix: str) -> dict:
    value = marker(text, prefix)
    if value.startswith("{"):
        result = json.loads(value)
        failures = result.get("failures")
        require(failures == [] or type(failures) is int and failures == 0,
                "Original completion contains failed assertions: " + prefix)
        checks = result.get("checks", result.get("assertions"))
        require(type(checks) is int and checks > 0, "Completion has no actual assertions: " + prefix)
        require(result.get("completed", True) is True, "Completion is explicitly incomplete")
        return result
    # Retain original native/legacy terminal formats without accepting mere presence.
    require(re.search(r"(?:failures=0(?:\D|$)|\b0 failures\b)", value)
            and re.search(r"(?:checks[=: ]+[1-9][0-9]*|[1-9][0-9]* checks|assertions[=: ]+[1-9][0-9]*)", value),
            "Original numeric completion is incomplete or failing: " + prefix)
    return {"terminal": value}


def validate_ramcache_pair(folder: Path, cases: dict[str, dict]) -> dict:
    pids = []
    for phase in ("write", "reopen"):
        original = read(folder / ("workbench-" + phase + ".json"))
        cache = read(folder / ("ramcache-" + phase + ".json"))
        require(original.get("mode") == phase and original.get("graphical") is True
                and original.get("failures") == [] and type(original.get("assertions")) is int
                and original["assertions"] > 0 and cache.get("schema") == "gen006-ramcache-workbench-v1"
                and cache.get("mode") == phase and cache.get("graphical") is True
                and cache.get("failures") == [] and type(cache.get("checks")) is int and cache["checks"] > 0
                and type(cache.get("process_id")) is int and cache["process_id"] > 0
                and cache["process_id"] == original.get("process_id"), "Incomplete RAMCACHE native receipt")
        row = cases["ramcache-" + phase]
        text = (folder.parent / row["label"] / "process.log").read_text(encoding="utf-8")
        done = validate_marker(text, "GEN006_RAMCACHE ")
        parent = validate_marker(text, "PERSISTENT_AREAS_WORKBENCH ")
        require(done.get("pid") == parent.get("pid") == cache["process_id"]
                and done.get("mode") == parent.get("mode") == phase
                and done.get("graphical") is parent.get("graphical") is True
                and done.get("checks") == cache["checks"] + 1
                and done.get("hot_samples") == len(cache.get("hot_samples", []))
                and done.get("warm_samples") == len(cache.get("warm_samples", [])),
                "Original RAMCACHE completion contradicts its written native receipts")
        strata.verify_resource_receipt(folder.parent, row, cache["process_id"])
        if phase == "write":
            require(len(cache["hot_samples"]) == len(cache["warm_samples"]) == 3
                    and cache.get("evidence", {}).get("cache_io", {}).get("prefetch_hits", 0) >= 1
                    and cache.get("evidence", {}).get("cache_io", {}).get("background_publications", 0) >= 1,
                    "RAMCACHE travel, background publication or preparation did not execute")
        pids.append(cache["process_id"])
    require(pids[0] != pids[1], "RAMCACHE reopening reused the writer process")
    return {"engine_process_ids": pids, "fresh_process_reopen": True,
            "timing_samples": 3, "timing_scope": "functional smoke; not the retained 30-sample performance campaign"}


def evidence_files(folder: Path) -> dict:
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob("*"))
            if p.is_file() and p != folder / "integration.json"}


def expected_labels(mode: str) -> set[str]:
    if mode == "ramcache":
        return {"import", *[r[0] for r in RAMCACHE_UNITS], "ramcache-write", "ramcache-reopen", "exit-fault",
                "cache-off-write", "cache-off-reopen"}
    if mode == "strata":
        return {"import", "optical-smoke", *[r[0] for r in STRATA_NATIVE], "optical-motion",
                "boundaries-write", "boundaries-reopen", "preference-install", "preference-reopen"}
    if mode == "lab":
        return {"import", *LAB_LABELS}
    require(mode == "shared", "Unknown integration mode")
    return {"import", *[r[0] for r in SHARED], "goblin-storage", "gentek-write", "gentek-reopen", *LAB_LABELS}


def validate_process(report: dict, row: dict, original: dict, text: str) -> None:
    require({k: v for k, v in row.items() if k not in ("label", "completion")} == original,
            "Process receipt differs from original record")
    require(row.get("status") == "passed" and row.get("exit_code") == 0
            and not custody.ERRORS.search(text) and not row.get("cleanup_error"), "Failed/erroring original process")
    require([line for line in text.splitlines() if line.startswith("Godot Engine v")] ==
            ["Godot Engine v" + report["godot"]["version"] + " - https://godotengine.org"],
            "Original process log lacks its unique pinned engine identity")
    label = row["label"]
    deadlines = {name: seconds for name, _, seconds in (*SHARED, *RAMCACHE_UNITS, *STRATA_NATIVE)}
    deadlines.update({"import": 600, "ramcache-write": 900, "ramcache-reopen": 900, "exit-fault": 300,
                      "cache-off-write": 420, "cache-off-reopen": 420, "optical-motion": 600,
                      "boundaries-write": 600, "boundaries-reopen": 600,
                      "preference-install": 600, "preference-reopen": 600, "gentek-write": 600, "gentek-reopen": 600})
    deadlines.update({label: LAB_DEADLINE_SECONDS for label in LAB_LABELS})
    require(row.get("timeout_seconds") == deadlines[label] and type(row.get("seconds")) in (int, float)
            and math.isfinite(row["seconds"]) and 0 <= row["seconds"] <= deadlines[label] + 15,
            "Actual process changed its registered deadline or reported an invalid duration")
    expected = [report["godot"]["path"], "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                "--rendering-driver", "opengl3", "--path", report["project"]["path"]]
    join = ntpath.join if report["platform"] == "win32" else posixpath.join
    if label == "import":
        expected += ["--headless", "--editor", "--quit"]
    else:
        script = ("test_material_lab_workbench_integration" if label in LAB_LABELS else
                  "test_persistent_area_ramcache" if label.startswith("ramcache-") else
                  "test_persistent_areas_workbench" if label.startswith("cache-off-") or label == "exit-fault" else
                  "test_ramcache_strata_boundaries" if label.startswith("boundaries-") else
                  "test_strata_owner_preference" if label.startswith("preference-") else
                  "test_workbench_generator_installed" if label.startswith("gentek-") else label)
        if label in LAB_LABELS:
            expected += ["--max-fps", str(LAB_CAPTURE_MAX_FPS)]
        expected += ["--script", optics.HARNESS if label == "optical-motion" else "res://tests/" + script + ".gd"]
        if label == "exit-fault":
            data = join(report["output_root"], "exit-data")
            expected += ["--", "--persistent-profile=" + join(data, "profile"), "--persistent-evidence=" + data,
                         "--persistent-test-mode=exit_fault", "--persistent-start-paused", "--persistent-cache-off",
                         "--persistent-require-graphics"]
        for prefix, directory in (("ramcache-", "ramcache-data"), ("cache-off-", "cache-off-data"), ("boundaries-", "boundary-data")):
            if label.startswith(prefix):
                data = join(report["output_root"], directory)
                expected += ["--", "--persistent-profile=" + join(data, "profile"), "--persistent-evidence=" + data,
                             "--persistent-test-mode=" + label.removeprefix(prefix), "--persistent-test-workers=1",
                             "--persistent-start-paused", "--persistent-require-graphics"]
                if prefix == "ramcache-":
                    expected += ["--ramcache-hot-samples=3", "--ramcache-warm-samples=3"]
                elif prefix == "cache-off-":
                    expected += ["--persistent-cache-off"]
    require(row.get("command") == expected, "Executed command differs from registered source, flags or display: " + label)


def validate_project_record(report: dict, source: dict) -> None:
    optics.validate_loaded_project_record(report, source)


def validate_preference_completion(result: dict, text: str) -> None:
    # The inherited real host fixture prints these four terminal fields; its
    # detailed native witnesses remain in the separate original JSON receipt.
    require(validate_marker(text, "STRATA_WORKBENCH ") ==
            {key: result.get(key) for key in ("checks", "failures", "scene", "phase")},
            "Owner-preference disk evidence differs from its actual completion")


def require_external_output(output: Path, project: Path) -> None:
    require(not output.is_relative_to(ROOT) and not output.is_relative_to(project.parent),
            "Qualification evidence/userdata must be outside source custody")


def validate_lab_pair(folder: Path, report: dict, rows: dict) -> None:
    # Reuse the original combined authoring reader, including source/native
    # script hashes and actual framebuffer evidence; retain its assertion set.
    import mat_workbench_runtime_publication as original_lab
    require(original_lab.COMBINED_GRAPHICAL_MAX_FPS == LAB_CAPTURE_MAX_FPS,
            "Established combined Lab capture contract changed")
    pids = []
    native_sha = report["runtime"]["cybersand_runtime"]["sha256"]
    for phase in ("author", "reopen"):
        label = "material-lab-" + phase
        location = folder / label
        text = (location / "process.log").read_text(encoding="utf-8")
        receipt = original_lab.verify_combined_case(location, "process", ROOT / "godot", 1, phase,
            platform="windows" if report["platform"] == "win32" else "linux", native_sha=native_sha)
        require(receipt == validate_marker(text, "MAT_WB_EVIDENCE ") and receipt.get("errors") == []
                and receipt.get("complete") is True and receipt.get("native_material_witnesses"),
                "Original Lab native authoring/reopen receipt is incomplete")
        require(marker(text, "MAT_WB_INTEGRATION ") ==
                "checks=" + str(receipt["checks"]) + " failures=0 complete=true",
                "Lab terminal contradicts its original detailed receipt")
        if phase == "author":
            world = receipt.get("candidate_world_receipt", {})
            require(world.get("schema_id") == "cybersand.material-lab.world-receipt"
                    and world.get("runtime_active") is False
                    and world.get("candidate", {}).get("world_simulation") is True
                    and world["candidate"].get("descriptor_readback", {}).get("density") == 500
                    and all(world.get(backend, {}).get("checks", {}).get(gate) is True
                        for backend in ("reference", "candidate")
                        for gate in ("deterministic_repeat", "worker_1_4_equal", "persistence_checkpoint",
                                     "persistence_replay", "quantity_balanced"))
                    and world["candidate"]["final"]["target_below_reservoir"] <
                        world["reference"]["final"]["target_below_reservoir"],
                    "Actual source-authored native candidate comparison did not pass")
        pids.append(rows[label]["pid"])
    require(pids[0] != pids[1], "Lab saved authoring did not reopen in a fresh observed process")


def verify(folder: Path, expected: dict | None = None) -> dict:
    folder = folder.resolve(strict=True)
    report = read(folder / "integration.json")
    require(report.get("schema") == "ramcache-strata-integration-v1" and report.get("status") == "passed"
            and report.get("completed") is True and report.get("input_custody") == "passed"
            and report.get("platform") in ("linux", "win32") and report.get("mode") in RUN_MODES,
            "Incomplete or failed integration campaign")
    source = report.get("source_identity")
    require(source == (expected or identity()) and source.get("local_delta") == [],
            "Campaign differs from exact committed integration source")
    require(report.get("native_reuse") == native_reuse()
            and report.get("runtime") == strata.retained_runtime_manifest(report["platform"]),
            "Executed runtime differs from source-matched retained publication")
    require(report.get("godot", {}).get("sha256") == strata.GODOT_SHA256[report["platform"]]
            and report["godot"].get("version") == custody.windows.GODOT_VERSION
            and isinstance(report["godot"].get("path"), str) and report["godot"]["path"],
            "Execution lacks the exact pinned actual engine")
    validate_project_record(report, source)
    require(report.get("files_sha256") == evidence_files(folder), "Original integration evidence changed")
    cases = report.get("cases", [])
    require(len(cases) == len(expected_labels(report["mode"]))
            and {r.get("label") for r in cases} == expected_labels(report["mode"]),
            "Integration coverage missing, duplicated or unregistered")
    rows = {r["label"]: r for r in cases}
    for row in cases:
        require(row.get("status") == "passed" and row.get("exit_code") == 0,
                "Original integration process did not pass")
        if row.get("kind") == "original-optics-campaign":
            require(row["label"] == "optical-smoke" and row.get("campaign_sha256") == sha(folder / "optics/campaign.json"),
                    "Original optical child campaign changed")
            continue
        if row.get("kind") == "original-goblin-campaign":
            require(row["label"] == "goblin-storage" and row.get("campaign_sha256") == sha(folder / "goblin-storage-evidence/report.json"),
                    "Original Goblin child campaign changed")
            continue
        location = folder / row["label"]
        process = read(location / "process.json")
        require(row.get("log_sha256") == sha(location / "process.log"), "Original integration log changed")
        validate_process(report, row, process, (location / "process.log").read_text(encoding="utf-8"))
        strata.verify_resource_receipt(folder, row)
    if report["mode"] == "ramcache":
        require(report.get("ramcache_pair") == validate_ramcache_pair(folder / "ramcache-data", rows),
                "RAMCACHE pair summary differs from original receipts")
        for name, prefix, _ in RAMCACHE_UNITS:
            validate_marker((folder / name / "process.log").read_text(), prefix)
        exit_receipt = read(folder / "exit-data/workbench-exit_fault.json")
        require(exit_receipt.get("mode") == "exit_fault" and exit_receipt.get("graphical") is True
                and exit_receipt.get("failures") == [] and exit_receipt.get("assertions", 0) >= 16,
                "Actual failed Save/Menu refusal and recovery did not pass")
        strata.verify_resource_receipt(folder, rows["exit-fault"], exit_receipt.get("process_id"))
        disabled_pids = []
        for phase in ("write", "reopen"):
            original = read(folder / ("cache-off-data/workbench-" + phase + ".json"))
            done = validate_marker((folder / ("cache-off-" + phase) / "process.log").read_text(), "PERSISTENT_AREAS_WORKBENCH ")
            require(original.get("graphical") is True and original.get("mode") == phase and original.get("failures") == []
                    and original.get("assertions", 0) > 0 and done.get("graphical") is True and done.get("mode") == phase
                    and done.get("pid") == original.get("process_id")
                    and done.get("checks") == original.get("assertions") + 1,
                    "Cache-disabled native travel/save/reopen failed")
            strata.verify_resource_receipt(folder, rows["cache-off-" + phase], original["process_id"])
            disabled_pids.append(original["process_id"])
        require(disabled_pids[0] != disabled_pids[1], "Cache-disabled reopening reused writer process")
    elif report["mode"] == "strata":
        optics.verify_campaign(folder / "optics", optics.identity(), full=False)
        for name, prefix, _ in STRATA_NATIVE:
            validate_marker((folder / name / "process.log").read_text(), prefix)
            if name in strata.NATIVE_REPORTS:
                result = read(folder / name / "result.json")
                strata.validate_native_report(result, name, source["source_commit"])
                strata.verify_resource_receipt(folder, rows[name], result["process_id"])
        result = read(folder / "optical-motion/result.json")
        optics.validate_result(result, "optics-readability-challenge", "motion", source["source_commit"])
        strata.verify_resource_receipt(folder, rows["optical-motion"], result["process_id"])
        pids = []
        for phase in ("write", "reopen"):
            boundary = validate_marker((folder / ("boundaries-" + phase) / "process.log").read_text(),
                                       "RAMCACHE_STRATA_BOUNDARIES ")
            original = read(folder / ("boundary-data/workbench-" + phase + ".json"))
            require(boundary.get("mode") == phase and boundary.get("graphical") is True
                    and boundary.get("schema") == "ramcache-strata-boundaries-v1"
                    and boundary.get("completed") is True and boundary.get("source_revision") == source["source_commit"]
                    and original.get("graphical") is True and original.get("failures") == []
                    and original.get("assertions", 0) > 0
                    and boundary.get("process_id") == original.get("process_id"),
                    "Persistent-area/Strata boundary did not complete in the observed process")
            require(boundary == read(folder / ("boundary-data/ramcache-strata-boundaries-" + phase + ".json")),
                    "Boundary terminal differs from its original receipt")
            witness = boundary.get("witness", {})
            require(witness.get("native_world_count") == witness.get("pending_native_world_count") == 0
                    and witness.get("has_document") is False and witness.get("authoring_unchanged") is True
                    and witness.get("manifest_unchanged") is True
                    and all(witness.get("native_before", {}).get(key) == witness.get("native_after", {}).get(key)
                            for key in ("generation", "revision", "tick", "authoring_generation")),
                    "Refused Strata entry changed the persistent native owner or authored state")
            strata.verify_resource_receipt(folder, rows["boundaries-" + phase], original["process_id"])
            pids.append(original["process_id"])
        require(pids[0] != pids[1], "Boundary reopening reused the writer")
        saved = None
        pids = []
        for phase in ("install", "reopen"):
            result = read(folder / ("preference-" + phase) / "result.json")
            validate_preference_completion(result, (folder / ("preference-" + phase) / "process.log").read_text())
            require(result.get("schema") == "ramcache-strata-owner-preference-v1"
                    and result.get("phase") == phase and result.get("source_revision") == source["source_commit"]
                    and result.get("graphical") is True and result.get("completed") is True
                    and result.get("failures") == [] and result.get("checks", 0) > 0
                    and result.get("preference", {}).get("profile") == "diorama"
                    and result["preference"].get("planes", {}).get("scripted", {}).get("depth") == 1.3
                    and result.get("quality") == "low" and HEX64.fullmatch(str(result.get("save_sha256", ""))),
                    "Diorama1.3 preference and quality separation failed")
            if phase == "install":
                witnesses = result.get("native_edit_witnesses", [])
                require(isinstance(witnesses, list) and len(witnesses) == 2
                        and [item.get("plane") for item in witnesses] == ["scripted", "play"],
                        "Missing actual decorative and physical paint/erase witnesses under Diorama")
                for item in witnesses:
                    require(item.get("point") == [120, 100] and type(item.get("native_before")) is int
                            and item.get("native_brush") == (131 if item["native_before"] != 131 else 58)
                            and item.get("native_erase") == 0 and item.get("native_restored") == item["native_before"]
                            and HEX64.fullmatch(str(item.get("before_sha256", "")))
                            and item.get("before_sha256") == item.get("restored_sha256"),
                            "Diorama native paint/erase/Undo did not restore the complete plane")
            if saved is not None:
                require(result["save_sha256"] == saved, "Fresh process changed authored scene bytes")
                require(result.get("inspection") == {"bypass": False, "clarity": False, "wipe": 1.0, "focus_override": ""},
                        "Temporary inspection state leaked into scene persistence")
            saved = result["save_sha256"]
            strata.verify_resource_receipt(folder, rows["preference-" + phase], result["process_id"])
            pids.append(result["process_id"])
        require(pids[0] != pids[1], "Owner preference did not reopen in a fresh process")
    elif report["mode"] == "shared":
        for name, prefix, _ in SHARED:
            validate_marker((folder / name / "process.log").read_text(), prefix)
        require(rows["gentek-write"]["pid"] != rows["gentek-reopen"]["pid"], "Gentek must reopen in a fresh process")
        for label in ("gentek-write", "gentek-reopen"):
            validate_marker((folder / label / "process.log").read_text(), "WB_GENERATOR_INSTALLED ")
        goblin_reader.verify_storage_evidence(folder / "goblin-storage-evidence",
            expected_source=source["source_commit"], platform=report["platform"],
            engine_path=report["godot"]["path"], project_path=report["project"]["path"],
            engine_sha256=report["godot"]["sha256"], engine_version=report["godot"]["version"],
            expected_inputs={path: sha(ROOT / path) for path in goblin_reader.INPUTS})
        name = "swarm006_reciprocal_input"
        witness = read(folder / name / "input-integrity.json")
        require(witness == validate_marker((folder / name / "process.log").read_text(), "SWARM006_INPUT_INTEGRITY ")
                and witness.get("completed") is True and len(witness.get("cases", {})) == 7
                and witness.get("display") in (("Windows",) if report["platform"] == "win32" else ("X11", "Wayland"))
                and witness.get("test_sha256") == source["source_inputs_sha256"]["godot/tests/" + name + ".gd"],
                "Actual seven-case native SWARM input witness is incomplete or changed")
        host_platform = "windows" if report["platform"] == "win32" else "linux"
        binding = read(ROOT / ("godot/tools/swarm004-runtime." + host_platform + ".json"))
        join = ntpath.join if report["platform"] == "win32" else posixpath.join
        native = witness.get("native_source", {})
        normalize = (lambda path: ntpath.normcase(ntpath.normpath(path))) if host_platform == "windows" else posixpath.normpath
        expected_path = join(report["project"]["path"], "tools",
                             "gentek_reciprocal.exe" if host_platform == "windows" else "gentek_reciprocal")
        require({k: v for k, v in native.items() if k != "path"} ==
                    {"ok": True, "source": binding["source"], "sha256": binding["sha256"]}
                and isinstance(native.get("path"), str) and normalize(native["path"]) == normalize(expected_path),
                "Input integrity exercised a different native reciprocal generator")
        for stage, digest in witness.get("native_planes_sha256", {}).items():
            require(sha(folder / name / (stage + ".le16")) == digest, "Captured native input plane changed")
        for records in witness.get("native_records_sha256", {}).values():
            for filename, digest in records.items():
                require(sha(folder / name / filename) == digest, "Actual generator request/result bytes changed")
    if report["mode"] in ("shared", "lab"):
        validate_lab_pair(folder, report, rows)
    return report


def run(args) -> int:
    output = args.output.resolve()
    require_external_output(output, args.project.resolve(strict=True))
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "ramcache-strata-integration-v1", "mode": args.mode, "platform": sys.platform,
              "status": "running", "completed": False, "cases": [], "physical_gpu_acceptance": False,
              "output_root": str(output)}
    source = runtime = loaded = assets = None
    start = time.monotonic()
    try:
        admitted = admission()
        source, reuse = admitted["source_identity"], admitted["native_reuse"]
        runtime = custody.verify_runtime_identity()
        project = args.project.resolve(strict=True)
        loaded = custody.project_identity(project, source, runtime)
        assets = strata.project_assets_identity(project, source)
        godot = args.godot.resolve(strict=True)
        require(sys.platform in strata.GODOT_SHA256 and sha(godot) == strata.GODOT_SHA256[sys.platform],
                "Exact official pinned Godot is required")
        version = subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip()
        require(version == custody.windows.GODOT_VERSION, "Godot version differs from retained pin")
        report.update(source_identity=source, native_reuse=reuse, runtime=runtime,
                      godot={"path": str(godot), "version": version, "sha256": sha(godot)},
                      project={"path": str(project), "inputs_sha256": loaded, "assets_sha256": assets},
                      performance_policy=admitted["performance_policy"], run_id=os.environ.get("GITHUB_RUN_ID", ""),
                      run_attempt=os.environ.get("GITHUB_RUN_ATTEMPT", ""))
        base = [str(godot), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                "--rendering-driver", "opengl3", "--path", str(project)]
        rows = {}

        def execute(label, command, env=None, timeout=600, prefix=None):
            environment = custody.case_environment(output / "userdata" / label) if env is None else env
            environment.update(CYBERSAND_SOURCE_REVISION=source["source_commit"], GITHUB_SHA=source["source_commit"],
                               GODOT_SILENCE_ROOT_WARNING="1")
            for key in ("CYBERSAND_SWARM004_CLI", "CYBERSAND_SWARM004_SOURCE", "CYBERSAND_SWARM004_SHA256"):
                environment.pop(key, None)
            metrics.MAX_SAMPLES = int(timeout / metrics.SAMPLE_SECONDS) + 3
            row = metrics.execute(command, output / label, environment, timeout, maximum_timeout=timeout)
            row["label"] = label
            report["cases"].append(row)
            rows[label] = row
            write_json(output / "integration.json", report)
            require(row["status"] == "passed", row.get("error", "Integration process failed"))
            if prefix:
                row["completion"] = validate_marker((output / label / "process.log").read_text(encoding="utf-8"), prefix)
            print("RAMCACHE_STRATA_CASE", args.mode, label, row["seconds"], flush=True)
            return row

        execute("import", base + ["--headless", "--editor", "--quit"])
        if args.mode == "ramcache":
            for name, prefix, timeout in RAMCACHE_UNITS:
                execute(name, base + ["--script", "res://tests/" + name + ".gd"], timeout=timeout, prefix=prefix)
            data = output / "ramcache-data"
            data.mkdir()
            env = custody.case_environment(output / "userdata/ramcache-pair")
            for phase in ("write", "reopen"):
                execute("ramcache-" + phase, base + ["--script", "res://tests/test_persistent_area_ramcache.gd", "--",
                    "--persistent-profile=" + str(data / "profile"), "--persistent-evidence=" + str(data),
                    "--persistent-test-mode=" + phase, "--persistent-test-workers=1", "--persistent-start-paused",
                    "--persistent-require-graphics", "--ramcache-hot-samples=3", "--ramcache-warm-samples=3"], env,
                    timeout=900, prefix="GEN006_RAMCACHE ")
            report["ramcache_pair"] = validate_ramcache_pair(data, rows)
            data = output / "cache-off-data"
            data.mkdir()
            env = custody.case_environment(output / "userdata/cache-off-pair")
            for phase in ("write", "reopen"):
                execute("cache-off-" + phase, base + ["--script", "res://tests/test_persistent_areas_workbench.gd", "--",
                    "--persistent-profile=" + str(data / "profile"), "--persistent-evidence=" + str(data),
                    "--persistent-test-mode=" + phase, "--persistent-test-workers=1", "--persistent-start-paused",
                    "--persistent-require-graphics", "--persistent-cache-off"], env, timeout=420,
                    prefix="PERSISTENT_AREAS_WORKBENCH ")
            data = output / "exit-data"
            data.mkdir()
            execute("exit-fault", base + ["--script", "res://tests/test_persistent_areas_workbench.gd", "--",
                "--persistent-profile=" + str(data / "profile"), "--persistent-evidence=" + str(data),
                "--persistent-test-mode=exit_fault", "--persistent-start-paused", "--persistent-cache-off",
                "--persistent-require-graphics"], timeout=300, prefix="PERSISTENT_AREAS_WORKBENCH ")
        elif args.mode == "strata":
            # Original smoke contains all 11 profiles, configuration/UI/renderer
            # regressions and actual authored save/fresh-process reopen.
            # Invoke the existing bounded child runner directly. A second Python
            # process wrapper would obscure Windows child ownership on timeout.
            code = optics.run_campaign(SimpleNamespace(output=output / "optics", suite="smoke",
                allow_source_delta=False, project=project, godot=godot))
            row = {"label": "optical-smoke", "kind": "original-optics-campaign", "exit_code": code,
                   "status": "passed" if code == 0 else "failed", "campaign_sha256": sha(output / "optics/campaign.json")}
            report["cases"].append(row)
            require(code == 0, "Original optical campaign failed")
            for name, prefix, timeout in STRATA_NATIVE:
                env = custody.case_environment(output / "userdata" / name)
                env.update(STRATA_EVIDENCE=str(output / name), STRATA_REPORT=str(output / name / "result.json"))
                execute(name, base + ["--script", "res://tests/" + name + ".gd"], env, timeout, prefix)
            env = custody.case_environment(output / "userdata/optical-motion")
            env.update(STRATA_SCENE="optics-readability-challenge", STRATA_PHASE="motion",
                       STRATA_EVIDENCE=str(output / "optical-motion"), STRATA_REPORT=str(output / "optical-motion/result.json"))
            execute("optical-motion", base + ["--script", optics.HARNESS], env)
            data = output / "boundary-data"
            data.mkdir()
            env = custody.case_environment(output / "userdata/boundary-pair")
            for phase in ("write", "reopen"):
                execute("boundaries-" + phase, base + ["--script", "res://tests/test_ramcache_strata_boundaries.gd", "--",
                    "--persistent-profile=" + str(data / "profile"), "--persistent-evidence=" + str(data),
                    "--persistent-test-mode=" + phase, "--persistent-test-workers=1", "--persistent-start-paused",
                    "--persistent-require-graphics"], env, prefix="RAMCACHE_STRATA_BOUNDARIES ")
            env = custody.case_environment(output / "userdata/preference-pair")
            for phase in ("install", "reopen"):
                location = output / ("preference-" + phase)
                execute("preference-" + phase, base + ["--script", "res://tests/test_strata_owner_preference.gd"],
                    dict(env, STRATA_PHASE=phase, STRATA_EVIDENCE=str(location), STRATA_REPORT=str(location / "result.json")))
        elif args.mode == "shared":
            for name, prefix, timeout in SHARED:
                env = custody.case_environment(output / "userdata" / name)
                env.update(CYBERSAND_TEST_ARTIFACT_DIR=str(output / name), MAT_AUDITION_EVIDENCE_DIR=str(output / name))
                if name == "swarm006_reciprocal_input":
                    env["SWARM004_UI_EVIDENCE"] = str(output / name)
                execute(name, base + ["--script", "res://tests/" + name + ".gd"], env, timeout, prefix)
            import run_goblin_storage_qualification as goblin
            old_argv = sys.argv
            location = output / "goblin-storage"
            location.mkdir()
            try:
                sys.argv = ["run_goblin_storage_qualification.py", "--godot", str(godot), "--project", str(project),
                            "--evidence", str(output / "goblin-storage-evidence")]
                with (location / "process.log").open("w", encoding="utf-8") as log, contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
                    code = goblin.main()
            finally:
                sys.argv = old_argv
            row = {"label": "goblin-storage", "kind": "original-goblin-campaign", "exit_code": code,
                   "status": "passed" if code == 0 else "failed", "campaign_sha256": sha(output / "goblin-storage-evidence/report.json")}
            report["cases"].append(row)
            require(code == 0, "Original Goblin storage campaign failed")
            env = custody.case_environment(output / "userdata/gentek-pair")
            env.update(WB_GENERATOR_REQUIRE_GRAPHICS="1", WB_GENERATOR_SCREENSHOTS=str(output / "gentek-captures"))
            for phase in ("write", "reopen"):
                execute("gentek-" + phase, base + ["--script", "res://tests/test_workbench_generator_installed.gd"],
                        dict(env, WB_GENERATOR_REOPEN="1" if phase == "reopen" else "0"), timeout=600,
                        prefix="WB_GENERATOR_INSTALLED ")
        if args.mode in ("shared", "lab"):
            # Preserve the accepted combined Lab contract: isolated external
            # userdata, actual native compilation/comparison, unchanged 1800 s
            # watchdog and 1 FPS diagnostic capture, then a fresh process.
            env = custody.case_environment(output / "userdata/material-lab-pair")
            for phase in ("author", "reopen"):
                label = "material-lab-" + phase
                location = output / label
                execute(label, base + ["--max-fps", str(LAB_CAPTURE_MAX_FPS), "--script",
                    "res://tests/test_material_lab_workbench_integration.gd"],
                    dict(env, ART_UNDO_WORKERS="1", MAT_WB_REOPEN="1" if phase == "reopen" else "0",
                         MAT_WB_SCREENSHOTS=str(location / "process-frames")),
                    timeout=LAB_DEADLINE_SECONDS, prefix="MAT_WB_EVIDENCE ")
        report["status"] = "passed"
    except Exception as error:
        report.update(status="failed", error=str(error))
        print("RAMCACHE_STRATA_FAILED", args.mode, str(error), file=sys.stderr, flush=True)
    finally:
        if source is not None:
            try:
                require(identity() == source, "Integration source changed during execution")
                require(custody.verify_runtime_identity() == runtime, "Native runtime changed during execution")
                if loaded is not None:
                    require(custody.project_identity(project, source, runtime) == loaded, "Loaded project changed")
                    require(strata.project_assets_identity(project, source) == assets, "Loaded binary art changed")
                report["input_custody"] = "passed"
            except Exception as error:
                report.update(status="failed", input_custody="failed", custody_error=str(error))
        report.update(completed=True, elapsed_seconds=round(time.monotonic() - start, 3))
        report["files_sha256"] = evidence_files(output)
        write_json(output / "integration.json", report)
    if report["status"] == "passed":
        try:
            verify(output, source)
            report["independent_verification"] = "passed"
        except Exception as error:
            report.update(status="failed", independent_verification="failed", independent_verification_error=str(error))
        write_json(output / "integration.json", report)
    print(json.dumps({"status": report["status"], "mode": args.mode, "platform": sys.platform,
                      "source": source.get("source_commit") if source else None}), flush=True)
    return int(report["status"] != "passed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    admit = commands.add_parser("admit")
    admit.add_argument("--output", type=Path, required=True)
    campaign = commands.add_parser("run")
    campaign.add_argument("--mode", choices=RUN_MODES, required=True)
    campaign.add_argument("--godot", type=Path, required=True)
    campaign.add_argument("--project", type=Path, default=ROOT / "godot")
    campaign.add_argument("--output", type=Path, required=True)
    check = commands.add_parser("verify")
    check.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.command == "run":
        return run(args)
    if args.command == "admit":
        result = admission()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        write_json(args.output, result)
    else:
        result = verify(args.output)
    print(json.dumps({"status": "passed", "source": result["source_identity"]["source_commit"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
