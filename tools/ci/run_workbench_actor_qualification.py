#!/usr/bin/env python3
"""Bounded, exact-source WB-ACTOR-COMPOSE-001 platform qualification.

The ordinary regression runner owns process watchdogs and diagnostic rejection.
This selector adds candidate custody, a focused complete case list, a fresh
process authored-save readback, and optional actual Workbench framebuffer proof.
Its explicit publish command prepares four candidate paths only; it never
commits, pushes, promotes a PR, dispatches inference, or changes accepted main.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import ntpath
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
import zlib

import execution_policy
import native_candidate_identity
import run_godot_regressions as runner

ROOT = Path(__file__).resolve().parents[2]
VERSION = "4.7.stable.official.5b4e0cb0f"
NATIVE = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
}
PROVENANCE = {
    "linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
    "windows": "godot/addons/cybersand_native/runtime-provenance.json",
}
RAPIER = {
    "linux": "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so",
    "windows": "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
}
CASES = (
    "test_workbench_actor_catalog",
    "test_workbench_actor_composition_session",
    "test_workbench_actor_composition_native",
    "test_workbench_actor_equipment_extent",
    "test_workbench_actor_composition",
    "test_prepared_physical_owner",
    "test_workbench_fleet_session",
    "test_workbench_input",
    "test_workbench_pilot_ui",
    "test_workbench_physics_play",
    "test_workbench_hard_placement",
    "test_workbench_failure_recovery",
    "test_workbench_material_baseline",
    "test_workbench_flatten",
    "test_workbench_combined_authoring",
    "test_paint_editor_generated_workbench",
    "test_paint_editor_workbench",
    "test_material_lab_workbench_integration",
    "test_physical_actor_session",
    "test_physical_actor_effect_cancellation",
    "test_physical_actor_script",
    "test_physical_usable_lifecycle",
    "test_physical_usable_script",
    "test_physical_usables_admission",
)
SANDBOX_CASES = (
    "test_ambient_group_transaction",
    "test_ambient_living_group_integration",
    "test_material_audition_ambient_integration",
    "test_workbench_actor_sandbox",
    "test_workbench_actor_configuration",
    "test_workbench_actor_configuration_native",
    "test_workbench_actor_manipulation",
    "test_workbench_actor_interaction",
    "test_workbench_actor_capacity",
    "test_workbench_actor_topology",
    "test_act004_body_capacity",
    "test_physical_actor_effects",
    "test_physical_actor_effect_admission",
    "test_physical_usables_runtime",
    "test_physical_usable_equipment",
)
SANDBOX_RECEIPTS = {
    "test_ambient_group_transaction": "AMBIENT_GROUP ",
    "test_ambient_living_group_integration": "AMBIENT_LIVING_GROUP_INTEGRATION ",
    "test_material_audition_ambient_integration": "MATERIAL_AMBIENT_INTEGRATION ",
    "test_workbench_actor_sandbox": "WB_ACTOR_SANDBOX ",
    "test_workbench_actor_configuration": "WB_ACTOR_CONFIGURATION ",
    "test_workbench_actor_configuration_native": "WB_ACTOR_CONFIGURATION_NATIVE ",
    "test_workbench_actor_manipulation": "WB_ACTOR_MANIPULATION_RESULT ",
    "test_workbench_actor_interaction": "WB_ACTOR_SANDBOX_INTERACTION ",
    "test_workbench_actor_interaction_reopen": "WB_ACTOR_SANDBOX_INTERACTION ",
    "test_workbench_actor_capacity": "WB_ACTOR_CAPACITY ",
    "test_workbench_actor_topology": "WB_ACTOR_TOPOLOGY ",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def source() -> dict:
    commit, tree, inputs = native_candidate_identity.source(ROOT)
    return {"source_commit": commit, "source_tree": tree, "source_inputs": inputs}


def project_inputs() -> dict:
    """Canonical LF source; exclude engine imports and candidate runtime bytes."""
    names = subprocess.check_output([
        "git", "ls-files", "-z", "--", "godot/scripts", "godot/tests", "godot/main.tscn",
        "godot/project.godot", "godot/shaders", "godot/examples", "godot/authoring",
        "godot/third_party", "examples/worldgen",
        "godot/addons/cybersand_native/cybersand_native.gdextension",
        "godot/addons/godot-rapier2d/godot-rapier2d.gdextension",
        "godot/addons/godot-rapier2d/runtime-provenance.linux.json",
        "godot/addons/godot-rapier2d/runtime-provenance.windows.json",
        "tools/ci", "tools/swarm45/qualify_combined_workbench.py", "tools/swarm45/shared.py",
        "tools/swarm45/runtime_custody.py", "tools/swarm006/qualify_workbench.py",
        "godot/tools/swarm004-runtime.linux.json", "godot/tools/swarm004-runtime.windows.json",
        "tools/package_explore001_candidate.py", "tools/requirements-build.txt",
        "tools/build_pinned_godot_cpp.sh", "tools/build_native_extension.sh",
        "tools/build_native_extension_windows.sh", "tools/check_linux_runtime_floor.sh",
        "tools/toolchains",
        "native/tests", "Makefile",
        "materials/catalogue", "tools/material_catalogue", "tools/lcb",
        "docs/reference/liquid-solver-capability-matrix.json",
        "docs/reference/liquid-policy-wire-vectors.json",
        "docs/reference/water-normalization-vectors.json",
        "docs/reference/liquid-run-receipt-vectors.json",
        "docs/operations/workbench-actor-composition.md",
        "third_party", ".github/workflows/workbench-actor-composition.yml",
        ".github/workflows/workbench-actor-sandbox.yml",
    ], cwd=ROOT).decode().split("\0")
    result = {}
    for name in sorted(filter(None, names)):
        canonical = subprocess.check_output(["git", "show", "HEAD:" + name], cwd=ROOT)
        actual = (ROOT / name).read_bytes().replace(b"\r\n", b"\n")
        if canonical.replace(b"\r\n", b"\n") != actual:
            raise ValueError("Uncommitted qualification input: " + name)
        result[name] = hashlib.sha256(actual).hexdigest()
    return result


def record(args) -> None:
    binary = args.binary.resolve(strict=True)
    prefix = b"MZ" if args.platform == "windows" else b"\x7fELF"
    if not binary.read_bytes().startswith(prefix):
        raise ValueError("Candidate binary has the wrong platform format")
    args.output.mkdir(parents=True, exist_ok=True)
    destination = args.output / Path(NATIVE[args.platform]).name
    if binary != destination.resolve():
        shutil.copyfile(binary, destination)
    current_source = source()
    build_ledger = None
    if args.build_ledger:
        build_ledger = json.loads(args.build_ledger.read_text(encoding="utf-8"))
        if (build_ledger.get("source_inputs") != current_source["source_inputs"]
                or build_ledger.get("sha256") != digest(destination)
                or build_ledger.get("size") != destination.stat().st_size
                or build_ledger.get("build_succeeded") is not True):
            raise ValueError("Pre-checkpoint build ledger does not match committed native inputs and runtime")
    identity = {
        "schema": 1, "kind": "workbench-actor-native-candidate", "platform": args.platform,
        **current_source, "build_inputs": project_inputs(), "artifact": NATIVE[args.platform],
        "sha256": digest(destination), "size": destination.stat().st_size,
        "toolchain": args.toolchain.read_text(encoding="utf-8") if args.toolchain else "",
        "pre_checkpoint_build_ledger": build_ledger,
        "execution": "not yet qualified; consume target-platform result separately",
    }
    write(args.output / "actor-candidate.json", identity)
    print(json.dumps({key: identity[key] for key in ("platform", "source_commit", "sha256", "size")}))


def candidate(directory: Path, platform: str) -> dict:
    manifest = json.loads((directory / "actor-candidate.json").read_text(encoding="utf-8"))
    expected = source()
    if (manifest.get("schema") != 1 or manifest.get("kind") != "workbench-actor-native-candidate"
            or manifest.get("platform") != platform or manifest.get("artifact") != NATIVE[platform]
            or any(manifest.get(key) != value for key, value in expected.items())
            or manifest.get("build_inputs") != project_inputs()):
        raise ValueError("Candidate source, platform or complete qualification input mismatch")
    binary = directory / Path(NATIVE[platform]).name
    if digest(binary) != manifest.get("sha256") or binary.stat().st_size != manifest.get("size"):
        raise ValueError("Candidate runtime bytes changed")
    return manifest


def install(args) -> None:
    manifest = candidate(args.candidate, args.platform)
    shutil.copyfile(args.candidate / Path(NATIVE[args.platform]).name, ROOT / NATIVE[args.platform])
    print("Installed source-matched candidate", manifest["sha256"])


def publish(args) -> None:
    """Stage only four candidate paths; never commit, push, promote or merge."""
    branch = subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT, text=True).strip()
    if branch != "feat/workbench-actor-composition-589":
        raise ValueError("Actor runtime staging is confined to its authorized Draft/HOLD branch")
    candidates = {platform: candidate(getattr(args, platform), platform) for platform in NATIVE}
    installed_qualification = None
    if bool(args.windows_installed_report) != bool(args.windows_modules_report):
        raise ValueError("Installed Windows gameplay and module reports must be supplied together")
    if args.windows_installed_report:
        installed = json.loads(args.windows_installed_report.read_text(encoding="utf-8"))
        modules = json.loads(args.windows_modules_report.read_text(encoding="utf-8-sig"))
        required = {"import", "test_workbench_actor_composition",
                    "test_workbench_actor_composition_reopen", "actor_workshop_render"}
        names = {row.get("name") for row in installed.get("results", [])}
        if (installed.get("status") != "passed" or installed.get("completed") is not True
                or installed.get("candidate") != candidates["windows"]
                or not required.issubset(names)
                or installed.get("graphical_capture", {}).get("status") != "passed"
                or not installed.get("installed_package")
                or modules.get("status") != "passed"
                or modules.get("source_commit") != candidates["windows"]["source_commit"]
                or modules.get("source_tree") != candidates["windows"]["source_tree"]
                or modules.get("executable", {}).get("status") != "verified"
                or len(modules.get("modules", [])) != 3
                or any(row.get("status") != "verified" for row in modules.get("modules", []))):
            raise ValueError("Installed Windows package or actual module qualification is incomplete")
        installed_qualification = {
            "status": "passed", "gameplay_report_sha256": digest(args.windows_installed_report),
            "module_report_sha256": digest(args.windows_modules_report),
            "scope": "Fresh non-checkout installation, graphical Save/Load, actual Workbench frames and app-local DLL resolution.",
        }
    prepared = {}
    for platform, manifest in candidates.items():
        path = ROOT / PROVENANCE[platform]
        previous = json.loads(path.read_text(encoding="utf-8"))
        report_path = getattr(args, platform + "_report")
        qualification = {"status": "pending", "platform": platform,
                         "scope": "Source/build custody only; target-platform gameplay and graphical qualification pending."}
        if report_path:
            report = json.loads(report_path.read_text(encoding="utf-8"))
            names = {row.get("name") for row in report.get("results", [])}
            expected = set(CASES) | {"import", "test_workbench_actor_composition_reopen",
                                     "actor_workshop_render", "actor_composition_performance"}
            if (report.get("status") != "passed" or report.get("completed") is not True
                    or report.get("candidate") != manifest or not expected.issubset(names)
                    or report.get("graphical_capture", {}).get("status") != "passed"):
                raise ValueError("Cannot publish a passing runtime claim from incomplete or different-source evidence")
            qualification = {"status": "passed", "platform": platform,
                             "report_sha256": digest(report_path), "cases": sorted(names),
                             "graphical_capture": report.get("graphical_capture", {}),
                             "scope": "Recorded automated coupled gameplay; owner playfeel and full release gates remain separate."}
        prepared[platform] = {
            "schema_version": 1, "kind": "source-matched-workbench-actor-evaluation-candidate",
            "artifact": NATIVE[platform], "sha256": manifest["sha256"], "size": manifest["size"],
            "source_commit": manifest["source_commit"], "build_commit": manifest["source_commit"],
            "source_tree": manifest["source_tree"], "platform": platform + " x86_64",
            "status": "evaluation-candidate-" + qualification["status"],
            "source_input_hash_kind": "sha256-canonical-lf",
            "source_inputs": manifest["source_inputs"], "build_inputs": manifest["build_inputs"],
            "godot_version": VERSION, "godot_cpp_commit": "101ae38034304346a46ea9ea84ae156d3e860496",
            "toolchain": manifest["toolchain"], "pre_checkpoint_build_ledger": manifest.get("pre_checkpoint_build_ledger"),
            "validated_platform": platform + " x86_64; " + qualification["status"],
            "qualification": qualification,
            "installed_package_qualification": installed_qualification if platform == "windows" else None,
            "workflow_run": os.environ.get("GITHUB_RUN_ID", "local-unpublished"),
            "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "local-unpublished"),
            "acceptance": "Draft/HOLD evaluation candidate. No merge, production release or owner playfeel acceptance is claimed.",
            "supersedes": {"build_commit": previous.get("build_commit"), "sha256": previous.get("sha256"),
                           "scope": "Previous accepted runtime remains recoverable from Git/LFS history."},
        }
    # Complete source/custody validation for both platforms before staging any
    # tracked byte. These four destinations are the complete mutation surface.
    for platform, manifest in prepared.items():
        binary = ROOT / NATIVE[platform]
        temporary = binary.with_suffix(binary.suffix + ".actor-candidate")
        shutil.copyfile(getattr(args, platform) / binary.name, temporary)
        temporary.replace(binary)
        write(ROOT / PROVENANCE[platform], manifest)
    print(json.dumps({"staged": [NATIVE[p] for p in NATIVE] + [PROVENANCE[p] for p in NATIVE],
                      "source_commit": candidates["linux"]["source_commit"], "state": "Draft/HOLD"}))


SANDBOX_BRANCH = "integration/actor-compose-final-001-20261123"
SWARM_BRANCH = "integration/swarm004-005-006-unified-20261122"
SANDBOX_CAPTURE_FILES = {
    "01-living-mixed-workshop.png", "02-running-controllers.png", "03-physics-configuration.png",
    "04-paused-assembly-preview.png", "05-live-physical-grab.png", "06-barrel-crowd-64.png",
    "07-capacity-64.png", "08-mechanical-chaos.png", "09-mechanical-diagnostics.png",
}


def evidence_file(directory: Path, name: str) -> Path:
    """Receipts may refer only to retained files inside their own artifact."""
    if not isinstance(name, str) or not name or "\\" in name:
        raise ValueError("Invalid evidence path")
    relative = PurePosixPath(name)
    path = (directory / name).resolve()
    if relative.is_absolute() or ".." in relative.parts or not path.is_relative_to(directory.resolve()) or not path.is_file():
        raise ValueError("Missing or escaping evidence file: " + name)
    return path


def framebuffer_hash(path: Path, window: list) -> str:
    """Decode the bounded PNG stream, including chunk CRCs and complete rows."""
    data = path.read_bytes()
    if (not isinstance(window, list) or len(window) != 2
            or any(type(value) is not int or not 1 <= value <= 8192 for value in window)
            or data[:8] != b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Invalid framebuffer dimensions or PNG signature")
    cursor, expanded, expected, stride = 8, 0, 0, 0
    header, pixels, ended = False, False, False
    decoder = zlib.decompressobj()
    while cursor < len(data):
        if cursor + 12 > len(data):
            raise ValueError("Truncated framebuffer chunk")
        size = int.from_bytes(data[cursor:cursor + 4], "big")
        kind = data[cursor + 4:cursor + 8]
        payload = data[cursor + 8:cursor + 8 + size]
        checksum = data[cursor + 8 + size:cursor + 12 + size]
        if len(checksum) != 4 or zlib.crc32(kind + payload) != int.from_bytes(checksum, "big"):
            raise ValueError("Framebuffer chunk CRC mismatch")
        if not header and kind != b"IHDR":
            raise ValueError("Framebuffer has no initial header")
        if kind == b"IHDR":
            width, height = int.from_bytes(payload[:4], "big"), int.from_bytes(payload[4:8], "big")
            # Godot's stretch viewport can differ from the requested Window
            # size. Authenticate actual pixel dimensions from IHDR instead.
            if (header or len(payload) != 13 or not 1 <= width <= 8192 or not 1 <= height <= 8192
                    or payload[8] != 8 or payload[9] not in (2, 6) or payload[10:] != b"\0\0\0"):
                raise ValueError("Invalid actual framebuffer header")
            header = True
            stride = 1 + width * (3 if payload[9] == 2 else 4)
            expected = height * stride
        elif kind == b"IDAT":
            pixels = True
            pending = payload
            while pending:
                block = decoder.decompress(pending, 1024 * 1024)
                if any(block[index] > 4 for index in range((-expanded) % stride, len(block), stride)):
                    raise ValueError("Invalid framebuffer row filter")
                expanded += len(block)
                if expanded > expected or decoder.unused_data:
                    raise ValueError("Framebuffer decompression exceeds its declared image")
                pending = decoder.unconsumed_tail
        elif kind == b"IEND":
            if size or not pixels or not decoder.eof or expanded != expected or cursor + 12 != len(data):
                raise ValueError("Framebuffer did not decode a complete image")
            ended = True
        cursor += size + 12
    if not ended:
        raise ValueError("Framebuffer is missing its terminal image chunk")
    return hashlib.sha256(data).hexdigest()


def sandbox_capture(report: dict, directory: Path, key: str, filename: str, minimum: int) -> dict:
    path = evidence_file(directory, "frames/" + filename)
    capture = json.loads(path.read_text(encoding="utf-8"))
    images = capture.get("images", [])
    if (capture != report.get(key) or capture.get("status") != "passed" or capture.get("failure")
            or capture.get("display") in (None, "", "headless") or len(images) < minimum):
        raise ValueError("Missing complete actual graphical capture: " + filename)
    hashes = {}
    for row in images:
        name = row.get("file")
        image = evidence_file(directory, "frames/" + str(name))
        if name in hashes or not str(name).endswith(".png"):
            raise ValueError("Absent, duplicate or invalid framebuffer: " + str(name))
        hashes[name] = framebuffer_hash(image, capture.get("window"))
    case_name = "actor_sandbox_render" if key == "sandbox_graphical_capture" else "actor_workshop_render"
    prefix = "WB_ACTOR_SANDBOX_CAPTURE " if key == "sandbox_graphical_capture" else "WB_ACTOR_CAPTURE "
    process = next(row for row in report["results"] if row["name"] == case_name)
    log = evidence_file(directory, process["log"]).read_text(encoding="utf-8", errors="replace")
    records = [json.loads(line.removeprefix(prefix)) for line in log.splitlines() if line.startswith(prefix)]
    if records != [capture]:
        raise ValueError("Graphical receipt differs from its completed process log")
    if key == "sandbox_graphical_capture":
        if not SANDBOX_CAPTURE_FILES.issubset(hashes):
            raise ValueError("Sandbox graphical scenarios are incomplete")
        crowd = next(row for row in images if row["file"] == "06-barrel-crowd-64.png")
        if (any(type(crowd.get(key)) is not int or not 0 <= crowd[key] < 2**63
                for key in ("actors", "actual_bodies", "native_tick", "rapier_tick"))
                or crowd.get("actors") != 64 or crowd.get("actual_bodies") != 64
                or crowd.get("native_tick", 0) < 1 or crowd.get("rapier_tick", 0) < 1):
            raise ValueError("Graphical 64-barrel capture lacks real bodies or owner progression")
    return {"receipt_sha256": digest(path), "images_sha256": hashes, "receipt": capture}


def sandbox_capacity(receipt: dict) -> list[dict]:
    rows = receipt.get("rows", [])
    required = {(family, count) for family in ("barrels", "mixed", "articulated") for count in (16, 32, 64)}
    seen = set()
    for row in rows:
        counters = ("actors", "bodies", "proxies", "joints", "native_ticks", "rapier_ticks",
                    "native_registered_bodies", "native_registered_proxies", "equipment_owner_actors",
                    "equipment_prepared_actors", "equipment_worker_frame_tick", "equipment_accepted_actors")
        if (any(type(row.get(key)) is not int or not 0 <= row[key] < 2**63 for key in counters)
                or any(type(value) is float and not math.isfinite(value) for value in row.values())):
            raise ValueError("Capacity counters must be finite integers and measurements finite")
        identity = (row.get("family"), row.get("actors"))
        counts = (row.get("actors"), row.get("bodies"), row.get("proxies"), row.get("joints"))
        if (identity in seen or identity[0] not in ("barrels", "mixed", "articulated")
                or any(type(value) is not int or value < 0 for value in counts)
                or not 0 < counts[0] <= counts[1] <= counts[2] <= 4096
                or row.get("passed") is not True or row.get("native_ticks", 0) < 30
                or row.get("rapier_ticks", 0) < 30
                or row.get("native_registered_bodies") != counts[1]
                or row.get("native_registered_proxies") != counts[2]):
            raise ValueError("Incomplete or inconsistent real native/Rapier capacity row")
        expected = {"barrels": (counts[0], counts[0], 0),
                    "mixed": (counts[0] * 7 // 2, counts[0] * 7 // 2, counts[0] * 3),
                    "articulated": (counts[0] * 5, counts[0] * 5, counts[0] * 5)}[identity[0]]
        equipped = {"barrels": 0, "mixed": counts[0] * 5 // 8, "articulated": counts[0]}[identity[0]]
        if (counts[0] % 8 or counts[1:] != expected or row.get("headless") is not False
                or row.get("equipment_owner_actors") != equipped or row.get("equipment_prepared_actors") != equipped
                or row.get("equipment_worker_frame_tick", 0) < 1 or row.get("equipment_last_error") != ""
                or (equipped and row.get("equipment_accepted_actors", 0) < 1)):
            raise ValueError("Capacity row does not exercise its physical workload")
        seen.add(identity)
    if not required.issubset(seen):
        raise ValueError("Missing mandatory 16/32/64 physical capacity workload")
    return rows


def sandbox_process(row: dict, platform: str) -> None:
    command = row.get("command", [])
    engine = "Godot_v4.7-stable_win64_console.exe" if platform == "windows" else "Godot_v4.7-stable_linux.x86_64"
    if (not isinstance(command, list) or not command or any(not isinstance(value, str) for value in command)
            or ntpath.basename(command[0]) != engine or command.count("--path") != 1
            or command.index("--path") + 1 >= len(command)
            or (row["requires_display"] and "--headless" in command)):
        raise ValueError("Process receipt does not execute the pinned required engine")
    if row["name"] == "import":
        if "--script" in command or "--editor" not in command or "--quit" not in command:
            raise ValueError("Import receipt does not execute project import")
        return
    script = {"actor_workshop_render": "capture_workbench_actor_workshop",
              "actor_sandbox_render": "capture_workbench_actor_sandbox",
              "actor_composition_performance": "measure_workbench_actor_composition"}.get(
                  row["name"], row["name"].removesuffix("_reopen"))
    if (command.count("--script") != 1 or command.index("--script") + 1 >= len(command)
            or command[command.index("--script") + 1] != "res://tests/" + script + ".gd"):
        raise ValueError("Process receipt does not execute its required source fixture")


def sandbox_reopen(name: str, receipt: dict) -> None:
    required = {"test_workbench_actor_composition_reopen": {"fresh-process reopened cast moves": 60},
                "test_workbench_actor_interaction_reopen": {
                    "fresh saved composition remains physically playable": 12,
                    "fresh64-barrel composition progresses both owners": 12}}.get(name, {})
    for label, ticks in required.items():
        phases = [row for row in receipt.get("phases", []) if row.get("label") == label]
        if (len(phases) != 1 or phases[0].get("passed") is not True
                or any(type(phases[0].get(key)) is not int for key in ("requested_rapier_ticks", "native_ticks", "rapier_ticks"))
                or phases[0]["requested_rapier_ticks"] != ticks or phases[0]["native_ticks"] < ticks - 1
                or phases[0]["rapier_ticks"] < ticks):
            raise ValueError("Fresh-process authored reopen was not executed: " + label)


def sandbox_footer(name: str, output: str) -> None:
    """Authenticate each source-owned terminal record, including older fixtures."""
    contracts = json.loads(Path(__file__).with_name("workbench_actor_sandbox_receipts.json").read_text())
    if name == "actor_composition_performance":
        return  # Its existing completion() contract requires all twelve rows.
    if name not in contracts:
        raise ValueError("No complete sandbox process contract for " + name)
    contract = contracts[name]
    if contract["kind"] == "import":
        if sum(line.startswith(contract["required_engine_banner"]) for line in output.splitlines()) != 1:
            raise ValueError("Missing pinned engine import banner")
    elif contract["kind"] == "literal":
        if any(output.splitlines().count(line) != 1 for line in contract["required_lines"]):
            raise ValueError("Missing completed native fixture: " + name)
    elif contract["kind"] == "regex":
        matches = list(re.finditer(contract["pattern"], output, re.MULTILINE))
        if (len(matches) != 1 or int(matches[0][contract["positive_integer_capture"]]) <= 0
                or any(int(matches[0][int(group)]) < minimum for group, minimum in contract.get("minimum_capture", {}).items())):
            raise ValueError("Missing completed assertion footer: " + name)
    else:
        prefix = contract["prefix"]
        records = [json.loads(line.removeprefix(prefix)) for line in output.splitlines() if line.startswith(prefix)]
        if len(records) != 1 or not isinstance(records[0], dict):
            raise ValueError("Missing unique completed assertion record: " + name)
        record = records[0]
        counter = record.get(contract.get("positive_integer"))
        if (any(type(record.get(key)) is not type(value) or record.get(key) != value
                for key, value in contract.get("equal", {}).items())
                or ("positive_integer" in contract and (type(counter) is not int or counter <= 0))
                or any(not isinstance(record.get(key), list) or len(record[key]) < minimum
                       for key, minimum in contract.get("minimum_array", {}).items())
                or (contract.get("display_non_headless") and record.get("display") in (None, "", "headless"))):
            raise ValueError("Incomplete assertions or native execution: " + name)


def sandbox_report(path: Path, manifest: dict, *, installed: bool = False) -> tuple[dict, dict]:
    report = json.loads(path.read_text(encoding="utf-8"))
    required = (set(SANDBOX_CASES) | {"import", "test_workbench_actor_composition",
                "test_workbench_actor_composition_reopen", "test_workbench_actor_interaction_reopen",
                "actor_workshop_render", "actor_sandbox_render"})
    if not installed:
        required |= set(CASES)
    results = report.get("results", [])
    names = [row.get("name") for row in results]
    rapier = json.loads((ROOT / ("godot/addons/godot-rapier2d/runtime-provenance."
                                 + manifest["platform"] + ".json")).read_text(encoding="utf-8"))
    if (report.get("status") != "passed" or report.get("completed") is not True
            or report.get("candidate") != manifest or report.get("platform") != manifest["platform"]
            or report.get("godot_version") != VERSION or report.get("rapier_sha256") != rapier["sha256"]
            or len(names) != len(set(names)) or not required.issubset(names)
            or not set(names).issubset(required | {"actor_composition_performance"})
            or report.get("executed_cases") != len(results)
            or bool(report.get("installed_package")) != installed
            or report.get("userdata", {}).get("retained") is not True
            or report.get("userdata", {}).get("temporary_directory_removed") is not True):
        raise ValueError("Incomplete or different-source sandbox qualification: " + str(path))
    graphical = {"test_workbench_actor_capacity", "test_workbench_actor_interaction",
                 "test_workbench_actor_interaction_reopen", "test_workbench_actor_configuration_native",
                 "actor_workshop_render", "actor_sandbox_render"}
    if installed:
        graphical |= {"test_workbench_actor_composition", "test_workbench_actor_composition_reopen"}
    capacity_rows = []
    for row in results:
        if (row.get("status") != "passed" or row.get("natural_completion") is not True
                or type(row.get("returncode")) is not int or row["returncode"] != 0
                or row.get("diagnostic_error") is not False or row.get("skip_messages") != []
                or row.get("launch_error") or row.get("capture_error") or row.get("timeout_kind")
                or (row["name"] in graphical and row.get("requires_display") is not True)):
            raise ValueError("Failed, skipped or nongraphical sandbox case: " + str(row.get("name")))
        sandbox_process(row, manifest["platform"])
        log = evidence_file(path.parent, row.get("log"))
        if digest(log) != row.get("log_sha256"):
            raise ValueError("Qualification log no longer matches its process receipt")
        output = log.read_text(encoding="utf-8", errors="replace")
        if (runner.case_diagnostic_error(row["name"], output, row["returncode"])
                or any(re.search(r"\bskipped\b|^\s*SKIP\b", line, re.IGNORECASE) for line in output.splitlines())):
            raise ValueError("Original qualification log contains a diagnostic or skipped case")
        sandbox_footer(row["name"], output)
        checked = dict(row)
        completion(runner.Case(row["name"], (), 1, 1), checked, path.parent)
        for key in ("assertion_receipt", "assertions", "models", "measurement_receipt"):
            if checked.get(key) != row.get(key):
                raise ValueError("Qualification assertion differs from the original process log")
        assertion = checked.get("assertion_receipt", {})
        if (row["requires_display"] and row["name"] in ("test_workbench_actor_composition",
                "test_workbench_actor_composition_reopen", "test_workbench_actor_interaction",
                "test_workbench_actor_interaction_reopen") and assertion.get("headless") is not False):
            raise ValueError("A required graphical fixture ran headless")
        sandbox_reopen(row["name"], assertion)
        if row["name"] == "test_workbench_actor_capacity":
            capacity_rows = sandbox_capacity(checked["assertion_receipt"])
    captures = {
        "workshop": sandbox_capture(report, path.parent, "graphical_capture", "workshop.json", 4),
        "sandbox": sandbox_capture(report, path.parent, "sandbox_graphical_capture", "sandbox.json", 9),
    }
    return report, {"status": "passed", "platform": manifest["platform"], "report_sha256": digest(path),
                    "cases": names, "capacity_rows": capacity_rows, "graphical_captures": captures,
                    "scope": "Complete source-matched automated sandbox campaign; owner hardware and playfeel remain unaccepted."}


def sandbox_package(args, manifest: dict, installed: dict) -> dict:
    extraction = json.loads(args.windows_extraction_report.read_text(encoding="utf-8-sig"))
    modules = json.loads(args.windows_modules_report.read_text(encoding="utf-8-sig"))
    package = installed["installed_package"]
    if (extraction.get("status") != "passed" or extraction.get("source_commit") != manifest["source_commit"]
            or extraction.get("sha256") != digest(args.windows_package)
            or extraction.get("archive") != args.windows_package.name
            or extraction.get("installed_report") != "installed-windows/qualification.json"
            or extraction.get("modules_report") != "installed-windows/runtime-modules.json"
            or package.get("source_commit") != manifest["source_commit"]
            or package.get("source_tree") != manifest["source_tree"]
            or package.get("native_sha256") != manifest["sha256"] or package.get("godot_version") != VERSION
            or package.get("files_sha256", {}).get(NATIVE["windows"]) != manifest["sha256"]
            or package.get("files_sha256", {}).get(RAPIER["windows"]) != installed["rapier_sha256"]):
        raise ValueError("Delivered ZIP or extraction proof differs from the tested Windows candidate")
    included_pins = {"third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
                     "third_party/rapier-bvh-build.lock.json", "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch",
                     "docs/operations/workbench-actor-composition.md"}
    with zipfile.ZipFile(args.windows_package) as archive:
        names = archive.namelist()
        files = {name for name in names if not name.endswith("/")}
        if (len(names) != len({name.casefold() for name in names})
                or files != set(package["files_sha256"]) | {"candidate-manifest.json"}
                or json.loads(archive.read("candidate-manifest.json")) != package):
            raise ValueError("Delivered ZIP manifest or member identity is inconsistent")
        for entry in archive.infolist():
            name = entry.filename
            if (PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts or "\\" in name
                    or str(PurePosixPath(name)) != name.rstrip("/")
                    or any(":" in part or part.endswith((".", " ")) for part in PurePosixPath(name).parts)
                    or (entry.external_attr >> 16) & 0o170000 == 0o120000):
                raise ValueError("Unsafe package member")
        for name, expected in package["files_sha256"].items():
            checksum = hashlib.sha256()
            with archive.open(name) as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    checksum.update(block)
            if checksum.hexdigest() != expected:
                raise ValueError("Delivered ZIP payload differs from its extraction: " + name)
        # Package payload hashes authenticate exact delivered bytes. The source
        # ledger deliberately uses canonical LF (see project_inputs), including
        # UID text that Windows Git can archive with CRLF. Compare like contracts
        # only after every raw ZIP payload has passed its independent hash check.
        windows_binding = "godot/tools/swarm004-runtime.windows.json"
        linux_binding = "godot/tools/swarm004-runtime.linux.json"
        if files & {linux_binding, "godot/tools/gentek_reciprocal"}:
            raise ValueError("Windows package contains a Linux reciprocal runtime")
        for name, expected in manifest["build_inputs"].items():
            if name == linux_binding:
                continue
            if name.startswith(("godot/", "examples/worldgen/")) or name in included_pins:
                if name not in package["files_sha256"]:
                    raise ValueError("Delivered project is missing qualified source input: " + name)
                canonical = archive.read(name).replace(b"\r\n", b"\n")
                if hashlib.sha256(canonical).hexdigest() != expected:
                    raise ValueError("Delivered project differs from qualified source input: " + name)
        if windows_binding in manifest["build_inputs"]:
            binding = json.loads(archive.read(windows_binding))
            cli = "godot/tools/gentek_reciprocal.exe"
            if (binding.get("platform") != "windows" or binding.get("artifact") != cli
                    or cli not in files or package["files_sha256"][cli] != binding.get("sha256")
                    or archive.getinfo(cli).file_size != binding.get("bytes")):
                raise ValueError("Windows reciprocal CLI differs from its qualified source binding")
    expected_modules = {"vcruntime140.dll", NATIVE["windows"], RAPIER["windows"]}
    records = modules.get("modules", [])
    if (modules.get("status") != "passed" or modules.get("source_commit") != manifest["source_commit"]
            or modules.get("source_tree") != manifest["source_tree"] or len(records) != 3
            or {row.get("relative_path") for row in records} != expected_modules
            or modules.get("cleanup", {}).get("terminated_owned_process") is not True
            or modules.get("cleanup", {}).get("environment_restored") is not True
            or modules.get("error") or modules.get("cleanup", {}).get("error")):
        raise ValueError("Actual installed Windows module or teardown proof is incomplete")
    records = [*records, modules.get("executable", {})]
    if records[-1].get("relative_path") != "Godot_v4.7-stable_win64.exe":
        raise ValueError("Installed Windows engine proof is absent")
    for row in records:
        name = row.get("relative_path")
        expected = package["files_sha256"].get(name)
        expected_path = ntpath.normcase(ntpath.normpath(ntpath.join(modules.get("package", ""), str(name))))
        if (not expected or row.get("status") != "verified"
                or any(row.get(key) != expected for key in ("expected_sha256", "packaged_sha256", "observed_sha256"))
                or any(ntpath.normcase(ntpath.normpath(row.get(key, ""))) != expected_path
                       for key in ("expected_path", "observed_path"))):
            raise ValueError("Loaded Windows module is not the source-matched app-local payload")
    package_root = ntpath.normcase(ntpath.normpath(modules.get("package", "")))
    for row in installed["results"]:
        command = row.get("command", [])
        if (not command or ntpath.dirname(ntpath.normcase(ntpath.normpath(command[0]))) != package_root
                or "--path" not in command
                or command.index("--path") + 1 >= len(command)
                or ntpath.normcase(ntpath.normpath(command[command.index("--path") + 1])) != ntpath.join(package_root, "godot")):
            raise ValueError("Installed qualification did not execute the extracted package")
    return {"status": "passed", "archive": args.windows_package.name, "sha256": digest(args.windows_package),
            "gameplay_report_sha256": digest(args.windows_installed_report),
            "module_report_sha256": digest(args.windows_modules_report),
            "extraction_report_sha256": digest(args.windows_extraction_report),
            "scope": "Exact delivered ZIP, fresh extraction, full sandbox reopens/captures and actual app-local DLLs. Hosted Windows/ANGLE is not owner Windows 11/NVIDIA acceptance."}


def publish_sandbox(args) -> None:
    """Fail closed, then stage only the two qualified runtimes and provenance."""
    branch = subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT, text=True).strip()
    if branch not in (SANDBOX_BRANCH, SWARM_BRANCH):
        raise ValueError("Sandbox runtime staging is confined to its dedicated Draft/HOLD branch")
    candidates = {platform: candidate(getattr(args, platform), platform) for platform in NATIVE}
    qualifications = {}
    for platform, manifest in candidates.items():
        _, qualifications[platform] = sandbox_report(getattr(args, platform + "_report"), manifest)
    if branch == SWARM_BRANCH:
        for platform, evidence in (("linux", args.linux_report.parent.parent / "swarm-linux"),
                                   ("windows", args.windows_installed_report.parent.parent / "swarm-windows-installed")):
            witness_path = evidence / "combined-reciprocal.json"
            witness = json.loads(witness_path.read_bytes())
            binding = json.loads((ROOT / "godot/tools" / ("swarm004-runtime." + platform + ".json")).read_bytes())
            if (witness.get("passed") is not True or witness.get("source") != candidates[platform]["source_commit"]
                    or witness.get("tree") != candidates[platform]["source_tree"] or witness.get("platform") != platform
                    or witness.get("native_sha256") != candidates[platform]["sha256"]
                    or witness.get("generator", {}).get("sha256") != binding["sha256"]
                    or witness.get("generator", {}).get("source") != binding["source"]
                    or witness.get("persistence", {}).get("passed") is not True):
                raise ValueError("Missing combined reciprocal Workbench execution on " + platform)
            qualifications[platform]["reciprocal_execution_sha256"] = digest(witness_path)
    installed, installed_evidence = sandbox_report(args.windows_installed_report, candidates["windows"], installed=True)
    package = sandbox_package(args, candidates["windows"], installed)
    package["qualification"] = installed_evidence
    if getattr(args, "verify_only", False):
        print(json.dumps({"verified_source": candidates["windows"]["source_commit"],
                          "windows_package_sha256": package["sha256"], "retained_pair": True}))
        return
    prepared = {}
    for platform, manifest in candidates.items():
        previous = json.loads((ROOT / PROVENANCE[platform]).read_text(encoding="utf-8"))
        prepared[platform] = {
            "schema_version": 1, "kind": "source-matched-workbench-actor-sandbox-evaluation-candidate",
            "artifact": NATIVE[platform], "sha256": manifest["sha256"], "size": manifest["size"],
            "source_commit": manifest["source_commit"], "build_commit": manifest["source_commit"],
            "source_tree": manifest["source_tree"], "platform": platform + " x86_64",
            "status": "evaluation-candidate-passed", "source_input_hash_kind": "sha256-canonical-lf",
            "source_inputs": manifest["source_inputs"], "build_inputs": manifest["build_inputs"],
            "godot_version": VERSION, "godot_cpp_commit": "101ae38034304346a46ea9ea84ae156d3e860496",
            "toolchain": manifest["toolchain"], "pre_checkpoint_build_ledger": manifest.get("pre_checkpoint_build_ledger"),
            "validated_platform": platform + " x86_64; passed", "qualification": qualifications[platform],
            "installed_package_qualification": package if platform == "windows" else None,
            "workflow_run": os.environ.get("GITHUB_RUN_ID", "local-unpublished"),
            "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "local-unpublished"),
            "publication_branch": branch,
            "acceptance": "Draft/HOLD evaluation candidate. No merge, release, default promotion or owner playfeel acceptance.",
            "supersedes": {"build_commit": previous.get("build_commit"), "sha256": previous.get("sha256"),
                           "scope": "Previous accepted runtime remains recoverable from Git/LFS history."},
        }
    # Every source, raw process, matrix, framebuffer, package and module check
    # above finishes before the first tracked destination is touched.
    for platform, manifest in prepared.items():
        binary = ROOT / NATIVE[platform]
        temporary = binary.with_suffix(binary.suffix + ".actor-candidate")
        shutil.copyfile(getattr(args, platform) / binary.name, temporary)
        temporary.replace(binary)
        write(ROOT / PROVENANCE[platform], manifest)
    print(json.dumps({"staged": [NATIVE[p] for p in NATIVE] + [PROVENANCE[p] for p in NATIVE],
                      "source_commit": candidates["linux"]["source_commit"], "state": "Draft/HOLD"}))


def completion(case: runner.Case, receipt: dict, output: Path) -> None:
    """A zero engine exit without reaching the fixture's assertions is failure."""
    log = (output / receipt["log"]).read_text(encoding="utf-8", errors="replace")
    if case.name in SANDBOX_RECEIPTS:
        prefix = SANDBOX_RECEIPTS[case.name]
        records = [json.loads(line.removeprefix(prefix)) for line in log.splitlines() if line.startswith(prefix)]
        if len(records) != 1 or records[0].get("failures") != [] or records[0].get("checks", 0) <= 0:
            raise ValueError("Missing complete sandbox assertion receipt: " + case.name)
        if case.name == "test_workbench_actor_capacity":
            required = {(family, count) for family in ("barrels", "mixed", "articulated") for count in (16, 32, 64)}
            rows = records[0].get("rows", [])
            observed = {(row["family"], row["actors"]) for row in rows if row.get("passed")}
            if not required.issubset(observed) or any(row.get("native_ticks", 0) < 30 or row.get("rapier_ticks", 0) < 30 for row in rows):
                raise ValueError("Incomplete real native/Rapier 16/32/64 capacity matrix")
        receipt["assertion_receipt"] = records[0]
    elif case.name in ("test_workbench_actor_composition", "test_workbench_actor_composition_reopen"):
        records = [json.loads(line.removeprefix("WB_ACTOR_COMPOSE "))
                   for line in log.splitlines() if line.startswith("WB_ACTOR_COMPOSE ")]
        if len(records) != 1 or records[0].get("failures") != [] or records[0].get("checks", 0) <= 0:
            raise ValueError("Missing complete ordinary Workbench assertion receipt: " + case.name)
        receipt["assertion_receipt"] = records[0]
    elif case.name in ("test_workbench_actor_composition_session", "test_workbench_actor_composition_native"):
        kind = case.name.rsplit("_", 1)[1]
        match = re.search(r"Workbench actor composition " + kind + r": (\d+) checks, (\d+) failures", log)
        if not match or int(match[1]) <= 0 or int(match[2]) != 0:
            raise ValueError("Missing completed actor " + kind + " assertion receipt")
        receipt["assertions"] = int(match[1])
    elif case.name == "test_prepared_physical_owner":
        match = re.search(r"PREPARED_PHYSICAL_OWNER: (\d+) assertions; (\d+) failures", log)
        if not match or int(match[1]) <= 0 or int(match[2]) != 0:
            raise ValueError("Missing completed prepared-owner assertion receipt")
        receipt["assertions"] = int(match[1])
    elif case.name in ("test_workbench_actor_equipment_extent", "test_physical_actor_effect_cancellation"):
        label = ("Workbench actor equipment extent" if case.name.endswith("extent")
                 else "Physical actor effect cancellation")
        match = re.search(re.escape(label) + r": (\d+) checks, (\d+) failures", log)
        if not match or int(match[1]) <= 0 or int(match[2]) != 0:
            raise ValueError("Missing completed material authority assertion receipt: " + label)
        receipt["assertions"] = int(match[1])
    elif case.name == "test_workbench_actor_catalog":
        match = re.search(r"WB_ACTOR_CATALOG checks=(\d+) failures=(\d+) models=(\d+)", log)
        if not match or int(match[1]) <= 0 or int(match[2]) != 0 or int(match[3]) < 50:
            raise ValueError("Missing completed broad actor catalogue assertion receipt")
        receipt.update(assertions=int(match[1]), models=int(match[3]))
    elif case.name == "actor_composition_performance":
        records = [json.loads(line.removeprefix("WB_ACTOR_PERFORMANCE "))
                   for line in log.splitlines() if line.startswith("WB_ACTOR_PERFORMANCE ")]
        if (len(records) != 1 or records[0].get("failures") != []
                or records[0].get("baseline") is not False or len(records[0].get("rows", [])) != 12):
            raise ValueError("Incomplete small/landscape measured Workbench campaign")
        receipt["measurement_receipt"] = records[0]


def verify_package(directory: Path, manifest: dict) -> dict:
    """Qualify the portable bytes, without a development checkout or imports."""
    if (directory / ".git").exists():
        raise ValueError("Installed qualification must run outside a Git checkout")
    package = json.loads((directory / "candidate-manifest.json").read_text(encoding="utf-8"))
    if (package.get("source_commit") != manifest["source_commit"]
            or package.get("source_tree") != manifest["source_tree"]
            or package.get("native_sha256") != manifest["sha256"]):
        raise ValueError("Portable package source/runtime differs from this candidate")
    for name, expected in package["files_sha256"].items():
        path = (directory / name).resolve()
        if not path.is_relative_to(directory) or digest(path) != expected:
            raise ValueError("Portable package payload differs: " + name)
    return package


def campaign_userdata(project_root: Path) -> tempfile.TemporaryDirectory:
    """Keep authoring subprocess output outside both source and installation."""
    directory = tempfile.TemporaryDirectory(prefix="cybersand-actor-qualification-")
    path = Path(directory.name).resolve()
    if path.is_relative_to(ROOT.resolve()) or path.is_relative_to(project_root.resolve()):
        directory.cleanup()
        raise ValueError("Qualification temporary userdata must be outside source and installed package")
    return directory


def test(args) -> int:
    platform = "windows" if sys.platform == "win32" else "linux"
    manifest = candidate(args.candidate, platform)
    project_root = args.package.resolve() if args.package else ROOT
    package = verify_package(project_root, manifest) if args.package else None
    runtime = project_root / NATIVE[platform]
    if digest(runtime) != manifest["sha256"]:
        raise ValueError("Installed runtime is not the declared candidate")
    rapier_provenance = json.loads((ROOT / ("godot/addons/godot-rapier2d/runtime-provenance."
                                                        + platform + ".json")).read_text())
    if digest(project_root / RAPIER[platform]) != rapier_provenance["sha256"]:
        raise ValueError("Rapier does not match the retained cooperative-BVH pin")
    version = subprocess.check_output([str(args.godot), "--version"], text=True, timeout=30).strip()
    if version != VERSION:
        raise ValueError("Godot version differs from the pin: " + version)
    if args.output.exists():
        raise ValueError("Qualification output must be a new directory")
    args.output.mkdir(parents=True)
    before = project_inputs()
    report = {"schema": 1, "status": "running", "platform": platform,
              "candidate": manifest, "godot_version": version,
              "rapier_sha256": digest(project_root / RAPIER[platform]), "results": [],
              "installed_package": package}
    available = {case.name: case for case in runner.discover_cases()}
    requested = args.cases.split(",") if args.cases else (
        ["test_workbench_actor_composition"] if args.package else list(CASES))
    if args.sandbox and not args.cases:
        requested += list(SANDBOX_CASES)
    if not requested or len(requested) != len(set(requested)) or any(name not in available for name in requested):
        raise ValueError("Required actor regression is absent or duplicated")
    cases = [runner.Case("import", ("--editor", "--quit"),
                        execution_policy.watchdog_seconds("godot_import_seconds"), 3)]
    for name in requested:
        case = available[name]
        if name == "test_workbench_actor_capacity":
            case = runner.Case(case.name, case.flags, execution_policy.complex_process_seconds(), case.weight, args.graphical)
        if args.graphical and name in ("test_workbench_actor_interaction", "test_workbench_actor_configuration_native"):
            case = runner.Case(case.name, case.flags, execution_policy.complex_process_seconds(), case.weight, True)
        if name == "test_workbench_actor_composition" and args.package:
            case = runner.Case(case.name, case.flags, case.timeout, case.weight, True)
        cases.append(case)
        if name == "test_workbench_actor_composition":
            cases.append(runner.Case(case.name + "_reopen", case.flags, case.timeout,
                                     case.weight, case.requires_display))
        if name == "test_workbench_actor_interaction":
            cases.append(runner.Case(case.name + "_reopen", case.flags, case.timeout,
                                     case.weight, case.requires_display))
    if args.graphical:
        cases.append(runner.Case("actor_workshop_render",
                     ("--script", "res://tests/capture_workbench_actor_workshop.gd"),
                     execution_policy.watchdog_seconds("graphical_case_seconds"), 30, True))
        if args.sandbox:
            cases.append(runner.Case("actor_sandbox_render",
                         ("--script", "res://tests/capture_workbench_actor_sandbox.gd"),
                         execution_policy.complex_process_seconds(), 60, True))
    if args.measure:
        cases.append(runner.Case("actor_composition_performance",
                     ("--script", "res://tests/measure_workbench_actor_composition.gd"),
                     execution_policy.complex_process_seconds(), 120, args.graphical))
    userdata_owner = campaign_userdata(project_root)
    userdata = Path(userdata_owner.name).resolve()
    report["userdata"] = {"execution_directory": str(userdata),
                          "retained_directory": "userdata", "retained": False,
                          "scope": "One external directory shared across the campaign and fresh-process reopen."}
    try:
        env = dict(os.environ)
        env["XDG_DATA_HOME"] = str(userdata)
        env["APPDATA"] = env["XDG_DATA_HOME"]
        env["CYBERSAND_SOURCE_REVISION"] = manifest["source_commit"]
        env["WB_ACTOR_CAPTURE_DIR"] = str((args.output / "frames").resolve())
        env["WB_ACTOR_PERFORMANCE_OUTPUT"] = str((args.output / "performance.json").resolve())
        env["WB_ACTOR_MEASURE_MS"] = "3000"
        env.pop("WB_ACTOR_BASELINE", None)
        env["CYBERSAND_ACTOR_COMPOSITION_NAME"] = "actor-composition-" + manifest["source_commit"][:12]
        env["CYBERSAND_ACTOR_SANDBOX_NAME"] = "actor-sandbox-" + manifest["source_commit"][:12]
        env.pop("CYBERSAND_ACTOR_SANDBOX_REOPEN", None)
        env["CYBERSAND_ACTOR_CAPACITY_REPORT"] = str((args.output / "sandbox-capacity.json").resolve())
        env.pop("CYBERSAND_ACTOR_COMPOSITION_REOPEN", None)
        env.pop("CYBERSAND_ACTOR_COMPOSITION_CAPTURE", None)
        # Reuse the established watchdog and diagnostics, changing only the
        # application root when exercising the committed portable installation.
        runner.ROOT = project_root
        for case in cases:
            if platform == "windows" and case.requires_display:
                case = runner.Case(case.name, (*case.flags, "--rendering-driver", "opengl3_angle"),
                                   case.timeout, case.weight, True)
            case_env = dict(env)
            if case.name in ("test_workbench_actor_composition", "test_workbench_actor_composition_reopen"):
                reopen = case.name.endswith("_reopen")
                case_env["CYBERSAND_ACTOR_COMPOSITION_REOPEN"] = "1" if reopen else "0"
                case_env["CYBERSAND_ACTOR_COMPOSITION_REPORT"] = str(
                    (args.output / ("reopen.json" if reopen else "authored.json")).resolve())
                if case.requires_display:
                    case_env["CYBERSAND_ACTOR_COMPOSITION_CAPTURE"] = str(
                        (args.output / ("reopen-frames" if reopen else "authored-frames")).resolve())
            if case.name in ("test_workbench_actor_interaction", "test_workbench_actor_interaction_reopen"):
                reopen = case.name.endswith("_reopen")
                case_env["CYBERSAND_ACTOR_SANDBOX_REOPEN"] = "1" if reopen else "0"
                if case.requires_display:
                    case_env["CYBERSAND_ACTOR_COMPOSITION_CAPTURE"] = str(
                        (args.output / ("sandbox-reopen-frames" if reopen else "sandbox-frames")).resolve())
            receipt, failed = runner.run_case(str(args.godot.resolve()), case, args.output, "case", env=case_env)
            report["results"].append(receipt)
            write(args.output / "qualification.json", report)
            if failed:
                raise RuntimeError("Required actor qualification failed: " + case.name)
            completion(case, receipt, args.output)
        if project_inputs() != before or digest(runtime) != manifest["sha256"]:
            raise RuntimeError("Qualification inputs changed during execution")
        if args.graphical:
            capture = json.loads((args.output / "frames/workshop.json").read_text())
            if capture.get("status") != "passed" or len(capture.get("images", [])) < 3:
                raise ValueError("Actual Workbench capture receipt is absent/incomplete")
            report["graphical_capture"] = capture
            if args.sandbox:
                sandbox = json.loads((args.output / "frames/sandbox.json").read_text())
                if sandbox.get("status") != "passed" or len(sandbox.get("images", [])) < 9:
                    raise ValueError("Actual sandbox demos/configuration/manipulation capture is incomplete")
                report["sandbox_graphical_capture"] = sandbox
        report.update(status="passed", completed=True, executed_cases=len(cases))
        return 0
    except Exception as error:
        report.update(status="failed", completed=False, error=str(error))
        raise
    finally:
        runner.ROOT = ROOT
        # The process owner has retired the last child before evidence is copied
        # into the checkout. The Materials Lab source-write guard stays intact.
        try:
            shutil.copytree(userdata, args.output / "userdata")
            report["userdata"]["retained"] = True
        except Exception as error:
            report.update(status="failed", completed=False)
            report["userdata"]["retention_error"] = str(error)
            raise
        finally:
            try:
                userdata_owner.cleanup()
                report["userdata"]["temporary_directory_removed"] = True
            except Exception as error:
                report.update(status="failed", completed=False)
                report["userdata"]["cleanup_error"] = str(error)
                raise
            finally:
                write(args.output / "qualification.json", report)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("record")
    build.add_argument("--platform", choices=NATIVE, required=True)
    build.add_argument("--binary", type=Path, required=True)
    build.add_argument("--output", type=Path, required=True)
    build.add_argument("--toolchain", type=Path)
    build.add_argument("--build-ledger", type=Path,
                       help="Verify native inputs of an already-built pre-checkpoint local candidate")
    stage = commands.add_parser("install")
    stage.add_argument("--platform", choices=NATIVE, required=True)
    stage.add_argument("--candidate", type=Path, required=True)
    publication = commands.add_parser("publish")
    publication.add_argument("--linux", type=Path, required=True)
    publication.add_argument("--windows", type=Path, required=True)
    publication.add_argument("--linux-report", type=Path)
    publication.add_argument("--windows-report", type=Path)
    publication.add_argument("--windows-installed-report", type=Path)
    publication.add_argument("--windows-modules-report", type=Path)
    sandbox_publication = commands.add_parser("publish-sandbox",
        help="Stage only fully qualified WB-ACTOR-COMPOSE-002R runtimes on its dedicated Draft/HOLD branch")
    sandbox_publication.add_argument("--verify-only", action="store_true",
                                     help="Verify all same-run evidence without replacing the retained runtime pair")
    for name in ("linux", "windows", "linux-report", "windows-report", "windows-installed-report",
                 "windows-modules-report", "windows-extraction-report", "windows-package"):
        sandbox_publication.add_argument("--" + name, type=Path, required=True)
    run = commands.add_parser("test")
    run.add_argument("--godot", type=Path, required=True)
    run.add_argument("--candidate", type=Path, required=True)
    run.add_argument("--output", type=Path, required=True)
    run.add_argument("--cases", help="Comma-separated focused selection; omission executes complete registered set")
    run.add_argument("--graphical", action="store_true")
    run.add_argument("--sandbox", action="store_true",
                     help="Add continuous-play manipulation, unified configuration and real 16/32/64+ capacity qualification")
    run.add_argument("--measure", action="store_true",
                     help="Measure 12 actual owner workloads on 1024x512 and 2048x1024 canvases")
    run.add_argument("--package", type=Path,
                     help="Validate and run a portable Windows installation outside Git")
    args = parser.parse_args()
    if args.command == "record": record(args)
    elif args.command == "install": install(args)
    elif args.command == "publish": publish(args)
    elif args.command == "publish-sandbox": publish_sandbox(args)
    else: return test(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
