#!/usr/bin/env python3
"""Qualify source-bound Windows graphical controls, recovery and persistence.

The source checkout and a pristine extracted owner ZIP are separate runs. A
successful child exit alone never passes: completed UI assertions, exact native
material readback, original screenshots and source custody are all required.
Automated qualification leaves owner visual and reciprocal research acceptance
pending. Linux/headless preflights cannot satisfy this Windows-only runner.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import signal
import struct
import subprocess
import sys
import time
import zlib

import runtime_custody as custody

VERSION = "4.7.stable.official.5b4e0cb0f"
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|(?m:^ERROR:)|Failed to load script|GDExtension library not found|ObjectDB instances leaked")
CAPTURES = ("native-preview.png", "native-applied.png", "native-undone.png", "native-saved.png", "native-reopened.png")
EXAMPLES = {
    "transaction": {"seed": 605, "shared_ownership": True, "clutter": 0.15,
                    "scope": "retained known605 zero-joint authoring transaction regression"},
    "reciprocal": {"seed": 4099, "shared_ownership": False, "clutter": 0.0,
                   "scope": "known4099 fixed-territory reciprocal authoring; offer causality separately controlled"},
    "swarm005_irregular": {"seed": 605, "shared_ownership": True, "clutter": 0.25,
                          "scope": "SWARM005 V3 192x112 shared-owner real GUI Apply/Undo/Save/reopen"},
    "swarm005_viaduct": {"seed": 605, "shared_ownership": True, "clutter": 0.15,
                        "negative": True,
                        "scope": "SWARM005 V3 192x112 shared-owner blocked preview and disabled Apply"},
    "swarm006_industrial_off": {"seed": 605, "shared_ownership": True, "clutter": 0.0,
                                "profile": "industrial", "evaluate": True, "recovery": False,
                                "scope": "Industrial605 V3 control in a blank synthetic2048x2048 World; not the owner's existing World"},
    "swarm006_industrial_on": {"seed": 605, "shared_ownership": True, "clutter": 0.0,
                               "profile": "industrial", "evaluate": True, "recovery": True,
                               "scope": "Industrial605 V4 recovery in the same blank synthetic World"},
    "swarm006_viaduct_on": {"seed": 605, "shared_ownership": True, "clutter": 0.15,
                            "profile": "viaduct_like", "evaluate": True, "recovery": True,
                            "scope": "Viaduct605 V4 recovery; retain negative native outcome if blocked"},
    "swarm006_irregular_on": {"seed": 605, "shared_ownership": True, "clutter": 0.25,
                              "profile": "irregular_megastructure", "evaluate": True, "recovery": True,
                              "scope": "Irregular605 V4 recovery with native-authorized Apply only"},
    "swarm006_irregular_square_on": {"seed": 605, "shared_ownership": True, "clutter": 0.25,
                                     "profile": "irregular_megastructure", "evaluate": True, "recovery": True,
                                     "size": [128, 128],
                                     "scope": "Irregular605 128x128 V4 synthetic comparison; not the owner's previous4889-cell World"},
}
PROFILE_DIRECTORIES = (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"),
                       ("APPDATA", "roaming"), ("LOCALAPPDATA", "local"))
UI_SCRIPT = "tests/test_workbench_swarm006_ui.gd"
SHA256 = re.compile(r"[0-9a-f]{64}\Z")


def expected_recipe(example: str) -> dict:
    selected = EXAMPLES[example]
    profile = selected.get("profile", "irregular_megastructure" if example == "swarm005_irregular" else "viaduct_like")
    parameters = {"variation": 0.65, "irregularity": 0.05, "clutter": selected["clutter"],
                  "destruction": 0.0, "branching": 0.55, "environment_affinity": 0.25, "cohesion": 0.35}
    if profile == "industrial":
        parameters.update(irregularity=0.15, branching=0.75, environment_affinity=1.0, cohesion=0.15)
    elif profile == "irregular_megastructure":
        parameters.update(irregularity=0.95, branching=1.0, environment_affinity=0.7, cohesion=0.2)
    wide = example.startswith(("swarm005_", "swarm006_"))
    recipe = {"size": selected.get("size", [192, 112] if wide else [128, 96]),
              "origin": [0, 0], "seed": selected["seed"], "rounds": 2,
              "shared_extent": 13, "orientation": -1,
              "profile": profile, "layout": "left_right" if wide else "centered_frame_rectangle",
              "border": 4, "optional": True,
              "shared_ownership": selected["shared_ownership"], "activation": [[64, 48]],
              "gentek_parameters": {"frame": parameters.copy(), "mosaic": parameters.copy()}}
    if wide:
        recipe.update(compact_native_termination=True, supported_native_receptors=True)
    if selected.get("evaluate"):
        recipe.update(negotiated_recovery=selected["recovery"], world_extent=[2048, 2048])
    return recipe


def isolated_environment(parent: dict[str, str], directory: Path, example: str) -> dict[str, str]:
    """A create/reopen pair shares only its own fresh profile and evidence."""
    directory.mkdir(parents=True, exist_ok=True)
    env = parent.copy()
    for key, suffix in PROFILE_DIRECTORIES:
        target = directory / "profile" / suffix
        target.mkdir(parents=True, exist_ok=True)
        env[key] = str(target)
    env.pop("SWARM004_UI_SEED", None)
    env.pop("SWARM004_UI_MODE", None)
    env.update(SWARM004_UI_EXAMPLE=example, SWARM004_UI_EVIDENCE=str(directory), SWARM004_REQUIRE_GRAPHICS="1")
    return env


def positive_integer(value: object) -> bool:
    # Godot's JSON reader restores integral numbers as doubles on reopen.
    return type(value) in (int, float) and 0 < value <= 9007199254740991 and int(value) == value


def nonnegative_integer(value: object) -> bool:
    return type(value) in (int, float) and 0 <= value <= 9007199254740991 and int(value) == value


def object_dict(value: object) -> dict:
    return value if isinstance(value, dict) else {}


def assertion_errors(report: object) -> list[str]:
    if not isinstance(report, dict):
        return ["missing or malformed completion report"]
    errors = []
    if report.get("completed") is not True or report.get("failures") != [] or not positive_integer(report.get("checks")):
        errors.append("assertion sequence did not complete without failures")
    return errors


def marker_errors(log: Path, marker: str, mechanical: bool = False) -> list[str]:
    try:
        reports = [json.loads(line.removeprefix(marker)) for line in log.read_text(encoding="utf-8", errors="replace").splitlines()
                   if line.startswith(marker)]
    except (OSError, ValueError):
        return ["missing or malformed " + marker.strip() + " marker"]
    if len(reports) != 1:
        return ["expected exactly one " + marker.strip() + " marker"]
    errors = assertion_errors(reports[0])
    if mechanical and object_dict(reports[0]).get("reciprocal_acceptance") is not False:
        errors.append("mechanical fixture must not claim reciprocal acceptance")
    return errors


def read_report(path: Path) -> dict:
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
        return report if isinstance(report, dict) else {}
    except (OSError, ValueError):
        return {}


def ui_report_errors(report: dict, mode: str, example: str, source: str, cli_sha: str, test_sha: str) -> list[str]:
    errors = assertion_errors(report)
    if report.get("schema") != 2 or report.get("mode") != mode or report.get("example") != example:
        errors.append("wrong UI report schema, mode or fixed example")
    if report.get("platform") != "Windows" or report.get("display") in (None, "", "headless"):
        errors.append("actual Windows graphical execution is required")
    if report.get("engine") != "4.7-stable (official)" or report.get("test_sha256") != test_sha:
        errors.append("UI report does not bind the pinned engine and exact test source")
    if not positive_integer(report.get("process_id")):
        errors.append("UI process identity is missing")
    if report.get("owner_visual_acceptance") != "pending" or report.get("reciprocal_programme_acceptance") is not False:
        errors.append("automated UI checks must leave owner visual and programme acceptance pending")
    if mode == "lifecycle":
        return errors
    evaluation = bool(EXAMPLES[example].get("evaluate"))
    if (mode == "blocked") != (example == "swarm005_viaduct") or (mode == "evaluate" and not evaluation):
        errors.append("blocked owner style is neither substituted nor treated as positive")
    refusals = object_dict(report.get("transport_refusals"))
    if mode in ("create", "evaluate"):
        required = ["preexisting_job_directory"]
        if report.get("native_can_apply") is True:
            required += ["failed_child_positive"]
            if evaluation:
                required += ["changed_world_source", "corrupted_saved_evidence"]
        if any(refusals.get(key) is not True for key in required):
            errors.append("required stale-source, evidence or child Apply refusal gate did not pass")
    native = object_dict(report.get("native_source"))
    if native.get("source") != source or native.get("sha256") != cli_sha:
        errors.append("native report is not bound to the attested source and generator")

    if report.get("native_recipe") != expected_recipe(example):
        errors.append("native recipe differs from the fixed declared example")
    witness = object_dict(report.get("reciprocal_witness"))
    if evaluation:
        if mode not in ("evaluate", "reopen"):
            errors.append("recovery examples require an honest native evaluation, then reopen only after Apply")
        if report.get("native_can_apply") is not True and report.get("native_can_apply") is not False:
            errors.append("recovery example omits native Apply authority")
        for key in ("joint_count", "obligation_count", "foreign_joined", "unresolved"):
            if not nonnegative_integer(witness.get(key)):
                errors.append("recovery witness lacks bounded native counts: " + key)
        if report.get("joint_count") != witness.get("joint_count") or report.get("obligation_count") != witness.get("obligation_count"):
            errors.append("native document and recovery witness disagree")
        if report.get("reciprocal_witness_passed") is not False:
            errors.append("recovery geometry must not be relabeled the independently controlled4099 witness")
        if report.get("native_can_apply") is False:
            if (mode != "evaluate" or report.get("native_status") not in ("blocked", "unsat", "exhausted", "oscillation")
                    or report.get("applied") is not False or report.get("native_receipt") != {}):
                errors.append("unsuccessful native recovery must retain a disabled Apply and no installation receipt")
            return errors
    if mode == "blocked":
        witness = object_dict(report.get("reciprocal_witness"))
        if (report.get("native_status") != "blocked" or report.get("native_can_apply") is not False
                or witness.get("unresolved", 0) < 1 or report.get("joint_count") != witness.get("joint_count")
                or report.get("obligation_count") != witness.get("obligation_count")):
            errors.append("V3 Viaduct negative must remain Blocked with actual unresolved obligations and no Apply")
        return errors
    if report.get("native_status") != "complete" or report.get("native_can_apply") is not True:
        errors.append("native composition did not independently authorize Apply")
    receipt = object_dict(report.get("native_receipt"))
    proposal = report.get("proposal_sha256", "")
    if not isinstance(proposal, str) or not SHA256.fullmatch(proposal) or receipt.get("proposal_sha256") != proposal:
        errors.append("retained native acknowledgement is not bound to its proposal")
    if receipt.get("operation") != "build" or not positive_integer(receipt.get("changed_cells")):
        errors.append("retained native Apply acknowledgement is missing")
    if example == "reciprocal":
        if (report.get("reciprocal_witness_passed") is not True or witness.get("both_footprints_changed") is not True
                or not positive_integer(witness.get("frame_occupied_changes"))
                or not positive_integer(witness.get("mosaic_occupied_changes"))
                or not positive_integer(witness.get("joint_count")) or not positive_integer(witness.get("obligation_count"))
                or type(witness.get("unresolved")) is not int or witness.get("unresolved") != 0 or witness.get("all_foreign_closed") is not True
                or witness.get("foreign_joined") != witness.get("obligation_count")):
            errors.append("reciprocal example lacks both occupied revisions, joints or full foreign closure")
    elif evaluation:
        if witness.get("unresolved") != 0 or witness.get("all_foreign_closed") is not True or witness.get("foreign_joined") != witness.get("obligation_count"):
            errors.append("native-authorized recovery must account for every frozen foreign obligation")
        if mode == "evaluate" and report.get("applied") is not True:
            errors.append("successful native evaluation did not exercise actual Apply")
    elif (witness.get("joint_count") != 0 or witness.get("obligation_count") != 0
          or report.get("reciprocal_witness_passed") is not False):
        errors.append("known605 transaction must remain the separate zero-joint regression")
    if report.get("joint_count") != witness.get("joint_count") or report.get("obligation_count") != witness.get("obligation_count"):
        errors.append("native document and derived witness disagree")
    return errors


def original_png(path: Path, minimum: int = 512) -> bool:
    """Require a complete full-window PNG, not a signature-only placeholder."""
    if not path.is_file():
        return False
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return False
    offset, saw_image = 8, False
    while offset + 12 <= len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        end = offset + size + 12
        if end > len(data):
            return False
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 4:end - 4]
        if zlib.crc32(chunk) & 0xffffffff != struct.unpack(">I", data[end - 4:end])[0]:
            return False
        if offset == 8 and (kind != b"IHDR" or size != 13 or min(struct.unpack(">II", data[offset + 8:offset + 16])) < minimum):
            return False
        if kind == b"IDAT" and size > 0:
            saw_image = True
        if kind == b"IEND":
            return size == 0 and end == len(data) and saw_image
        offset = end
    return False


def native_evidence_errors(directory: Path, report: dict, regenerated: bool) -> list[str]:
    """Keep complete native records, including blocked and exhausted proposals."""
    errors = []
    evidence = object_dict(report.get("native_evidence_sha256"))
    required = ("initial", "regenerated") if regenerated else ("initial",)
    planes = []
    for stage in required:
        hashes = object_dict(evidence.get(stage))
        names = {stage+'-'+suffix for suffix in ('request.txt', 'result.json', 'native-pixels.png', 'material.le16')}
        if hashes.keys() != names:
            errors.append('missing complete native artifact inventory: '+stage)
            continue
        valid = True
        for name, digest in hashes.items():
            path = directory/name
            if not isinstance(digest, str) or not SHA256.fullmatch(digest) or not path.is_file() or custody.native.sha(path) != digest:
                errors.append('native evidence bytes changed: '+name);valid = False
        if not valid:
            continue
        if not original_png(directory/(stage+'-native-pixels.png'), 1):
            errors.append('missing actual native crop PNG: '+stage)
        value = read_report(directory/(stage+'-result.json'))
        cells = value.get('cells')
        if (value.get('source') != object_dict(report.get('native_source')).get('source')
                or value.get('can_apply') is not report.get('native_can_apply')
                or not isinstance(cells, list) or any(type(cell) is not int or not 0 <= cell <= 65535 for cell in cells)):
            errors.append('native raw output does not bind this source/result: '+stage)
            continue
        plane = b''.join(cell.to_bytes(2, 'little') for cell in cells)
        if (directory/(stage+'-material.le16')).read_bytes() != plane:
            errors.append('retained crop material plane differs from raw native cells: '+stage)
        planes.append(plane)
    if regenerated and len(planes) == 2 and planes[0] != planes[1]:
        errors.append('same-source native regeneration changed the exact material plane')
    return errors


def world_plane_errors(directory: Path, report: dict, stages: tuple[str, ...]) -> list[str]:
    errors = []
    extent = object_dict(report.get('native_recipe')).get('world_extent', [512, 512])
    if extent not in ([512, 512], [2048, 2048]):
        return ['invalid captured native World extent']
    hashes = object_dict(report.get('native_planes_sha256'))
    for stage in stages:
        path = directory/(stage+'-native.le16')
        if (not path.is_file() or path.stat().st_size != extent[0]*extent[1]*2
                or custody.native.sha(path) != hashes.get(stage)):
            errors.append('missing/changed full native World readback: '+stage)
    return errors


def example_evidence(directory: Path, reports: dict[str, dict]) -> dict:
    """Validate persistence using independent process reports and entire planes."""
    errors: list[str] = []
    create, reopen = reports.get("create", reports.get("evaluate", {})), reports.get("reopen", {})
    errors.extend(native_evidence_errors(directory, create, True))
    errors.extend(world_plane_errors(directory, create, ("baseline", "preview", "applied", "undone", "regenerated", "saved")))
    errors.extend(world_plane_errors(directory, reopen, ("reopened",)))
    if not create or not reopen or create.get("process_id") == reopen.get("process_id"):
        errors.append("create and reopen require distinct completed OS processes")
    for key in ("native_recipe", "proposal_sha256", "native_receipt", "reciprocal_witness"):
        if key not in create or create.get(key) != reopen.get(key):
            errors.append("fresh-process evidence changed: " + key)
    plane = directory / "expected-native.le16"
    plane_sha = custody.native.sha(plane) if plane.is_file() else None
    extent = object_dict(create.get("native_recipe")).get("world_extent", [512, 512])
    if extent not in ([512, 512], [2048, 2048]) or not plane.is_file() or plane.stat().st_size != extent[0] * extent[1] * 2:
        errors.append("missing complete declared native material plane")
    before = object_dict(create.get("native_planes_sha256"))
    after = object_dict(reopen.get("native_planes_sha256"))
    if (not plane_sha or any(before.get(stage) != plane_sha for stage in ("expected", "applied", "regenerated", "saved"))
            or any(after.get(stage) != plane_sha for stage in ("expected", "reopened"))):
        errors.append("complete native Apply, regeneration, Save and reopen planes do not agree")
    baseline = before.get("baseline", "")
    if (not isinstance(baseline, str) or not SHA256.fullmatch(baseline) or baseline == plane_sha
            or before.get("preview") != baseline or before.get("undone") != baseline):
        errors.append("preview or Undo did not retain the complete distinct baseline")
    screenshots = {}
    for name in CAPTURES:
        path = directory / name
        if not original_png(path):
            errors.append("missing original full-window PNG: " + name)
        else:
            screenshots[name] = custody.native.sha(path)
    return {"passed": not errors, "validation_errors": errors, "native_plane_sha256": plane_sha,
            "screenshots_sha256": screenshots, "process_ids": {mode: report.get("process_id") for mode, report in reports.items()},
            "recipe": create.get("native_recipe"), "reciprocal_witness": create.get("reciprocal_witness")}



def blocked_evidence(directory: Path, report: dict) -> dict:
    """A negative graphical preview is not a saved-map or Apply qualification."""
    errors = []
    errors.extend(native_evidence_errors(directory, report, False))
    errors.extend(world_plane_errors(directory, report, ("baseline", "preview")))
    planes = object_dict(report.get("native_planes_sha256"))
    baseline = planes.get("baseline")
    if not isinstance(baseline, str) or not SHA256.fullmatch(baseline) or planes.get("preview") != baseline:
        errors.append("blocked preview did not preserve the independent original native World")
    screenshots = {}
    for name in ("native-preview.png", "native-unresolved.png"):
        path = directory / name
        if not original_png(path):
            errors.append("missing original negative-example screenshot: " + name)
        else:
            screenshots[name] = custody.native.sha(path)
    return {"passed": not errors, "validation_errors": errors, "native_plane_sha256": baseline,
            "screenshots_sha256": screenshots, "process_ids": {report.get("mode", "blocked"): report.get("process_id")},
            "recipe": report.get("native_recipe"), "reciprocal_witness": report.get("reciprocal_witness"),
            "blocked_negative": True, "applied": False}


def package_identity(directory: Path, source: str) -> dict:
    # The graphical consumer applies the same whole-package integrity contract
    # as the source-bound owner launcher, including every launch-critical file.
    from seal_owner import validate_package
    return validate_package(directory, source)


def terminate_tree(child: subprocess.Popen) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(child.pid), "/T", "/F"], check=False, capture_output=True, timeout=20)
    else:
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    child.wait(timeout=20)


def execute(name: str, command: list[str], env: dict[str, str], output: Path, timeout: int) -> dict:
    began = time.monotonic()
    log = output / (name + ".log")
    timed_out = False
    with log.open("w", encoding="utf-8") as stream:
        child = subprocess.Popen(command, env=env, cwd=custody.ROOT, stdout=stream,
                                 stderr=subprocess.STDOUT, start_new_session=os.name != "nt")
        try:
            while child.poll() is None:
                if time.monotonic() - began > timeout:
                    timed_out = True
                    terminate_tree(child)
                    break
                time.sleep(0.05)
            code = child.wait(timeout=20)
        finally:
            if child.poll() is None:
                terminate_tree(child)
    text = log.read_text(encoding="utf-8", errors="replace")
    result = {"case": name, "command": command, "process_id": child.pid, "returncode": code,
              "timed_out": timed_out, "wall_seconds": time.monotonic() - began,
              "log_sha256": custody.native.sha(log), "passed": code == 0 and not timed_out and not ERRORS.search(text)}
    (output / (name + "-process.json")).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if not result["passed"]:
        print("\n".join(text.splitlines()[-100:]), file=sys.stderr)
    return result


def validate_result(result: dict, errors: list[str], output: Path) -> dict:
    result["validation_errors"] = errors
    result["passed"] = bool(result["passed"] and not errors)
    (output / (result["case"] + "-process.json")).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--native-candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seed", type=int, choices=(605,), default=605,
                        help="legacy transaction seed605 only; the reciprocal example is always fixed4099")
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("This automated qualification runner requires actual Windows graphical execution")
    project, output, engine = args.project.resolve(), args.output.resolve(), args.godot.resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError("Qualification evidence destination must be empty")
    output.mkdir(parents=True, exist_ok=True)
    receipt = custody.verify(args.native_candidate)
    subprocess.run(["git", "diff", "--exit-code", "HEAD", "--", "godot/scripts", "godot/tests"],
                   cwd=custody.ROOT, check=True, timeout=60)
    script_names = subprocess.check_output(["git", "ls-files", "--", "godot/scripts", "godot/tests"],
                                          cwd=custody.ROOT, text=True, timeout=60).splitlines()
    for name in script_names:
        if Path(name).suffix == ".gd":
            candidate = project / Path(name).relative_to("godot")
            if candidate.read_bytes().replace(b"\r\n", b"\n") != (custody.ROOT / name).read_bytes().replace(b"\r\n", b"\n"):
                raise ValueError("Interactive script differs from the exact source checkout: " + name)
    version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
    if version != VERSION:
        raise ValueError("Godot pin mismatch: " + version)
    runtime_path = project / "addons/cybersand_native/bin" / ("cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so")
    if os.name == "nt" and custody.native.sha(runtime_path) != receipt["extension_sha256"]:
        raise ValueError("Interactive project does not use the attested native adapter")
    package = package_identity(args.package.resolve(), receipt["source_commit"]) if args.package else None
    if package and project != args.package.resolve() / "godot":
        raise ValueError("Pristine package qualification must execute that package's own Godot project")
    if package and custody.native.sha(project / "tools" / custody.CLI) != receipt["files"][custody.CLI]["sha256"]:
        raise ValueError("Packaged reciprocal generator differs from the source-built candidate")
    identity = {"schema": 2, "source_commit": receipt["source_commit"], "source_tree": receipt["source_tree"],
                "platform": sys.platform, "godot_version": version, "godot_sha256": custody.native.sha(engine),
                "native_adapter_sha256": custody.native.sha(runtime_path), "reciprocal": receipt,
                "graphical_required": True, "package": bool(package),
                "fixed_examples": {example: expected_recipe(example) for example in EXAMPLES},
                "scripts_sha256": {path.relative_to(project).as_posix(): custody.native.sha(path)
                                   for path in sorted(project.rglob("*.gd")) if ".godot" not in path.parts}}
    (output / "source-runtime-identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    env = os.environ.copy()
    env["CYBERSAND_SOURCE_REVISION"] = receipt["source_commit"]
    for key in ("CYBERSAND_SWARM004_CLI", "CYBERSAND_SWARM004_SOURCE", "CYBERSAND_SWARM004_SHA256"):
        env.pop(key, None)
    if not package:
        env.update(CYBERSAND_SWARM004_CLI=str((args.native_candidate / custody.CLI).resolve()),
                   CYBERSAND_SWARM004_SOURCE=receipt["source_commit"],
                   CYBERSAND_SWARM004_SHA256=receipt["files"][custody.CLI]["sha256"])
    base = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
    display = ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle"]
    headless = output / "headless"
    headless_env = isolated_environment(env, headless, "transaction")
    results = [execute("import", [*base, "--headless", "--editor", "--quit"], headless_env, headless, 180)]
    if results[-1]["passed"]:
        adapter_env = headless_env.copy()
        adapter_env["WB_AUTHORING_PATCH_REPORT"] = str(headless / "native-adapter.json")
        result = execute("native-adapter", [*base, "--headless", "--script", "res://tests/test_workbench_authoring_patch.gd"], adapter_env, headless, 180)
        report = read_report(headless / "native-adapter.json")
        errors = assertion_errors(report)
        if report.get("passed") is not True:
            errors.append("native adapter assertions did not pass")
        results.append(validate_result(result, errors, headless))
    for name, script, marker, timeout in (
            ("protocol", "test_workbench_reciprocal_protocol.gd", "SWARM004_PROTOCOL ", 60),
            ("controller-mechanical", "test_workbench_reciprocal_controller.gd", "SWARM004_CONTROLLER ", 90),
            ("controls-native", "test_workbench_reciprocal_controls.gd", "SWARM004_CONTROLS ", 90)):
        if not results[-1]["passed"]:
            break
        result = execute(name, [*base, "--headless", "--script", "res://tests/" + script], headless_env, headless, timeout)
        results.append(validate_result(result, marker_errors(headless / (name + ".log"), marker, name == "controller-mechanical"), headless))
    examples = {}
    lifecycle_passed = False
    if all(result["passed"] for result in results):
        test_sha = custody.native.sha(project / UI_SCRIPT)
        cli_sha = receipt["files"][custody.CLI]["sha256"]
        for example, definition in EXAMPLES.items():
            directory = output / example
            example_env = isolated_environment(env, directory, example)
            reports = {}
            example_results = []
            modes = ["blocked"] if definition.get("negative") else (["evaluate"] if definition.get("evaluate") else ["create", "reopen"])
            for mode in modes:
                mode_env = dict(example_env, SWARM004_UI_MODE=mode)
                result = execute(mode, [*base, *display, "--script", "res://" + UI_SCRIPT], mode_env, directory, 420)
                report = read_report(directory / (mode + ".json"))
                errors = ui_report_errors(report, mode, example, receipt["source_commit"], cli_sha, test_sha)
                result["example"] = example
                result["report_sha256"] = custody.native.sha(directory / (mode + ".json")) if report else None
                results.append(validate_result(result, errors, directory))
                example_results.append(result)
                reports[mode] = report
                if not result["passed"]:
                    break
                if mode == "evaluate" and report.get("native_can_apply") is True:
                    modes.append("reopen")
            if definition.get("negative") or (definition.get("evaluate") and reports.get("evaluate", {}).get("native_can_apply") is False):
                record = blocked_evidence(directory, reports.get("blocked", reports.get("evaluate", {})))
            else:
                record = example_evidence(directory, reports)
            examples[example] = {"scope": definition["scope"], **record}
            primary = reports.get("create", reports.get("evaluate", reports.get("blocked", {})))
            examples[example]["native_outcome"] = {key: primary.get(key) for key in (
                "native_status", "native_reason", "native_stop_reason", "native_can_apply", "material_count",
                "joint_count", "obligation_count", "reciprocal_witness", "native_work", "native_evidence_sha256")}
            examples[example]["passed"] = bool(record["passed"] and len(reports) == len(modes)
                                               and all(result["passed"] for result in example_results))
        directory = output / "lifecycle"
        lifecycle_env = isolated_environment(env, directory, "transaction")
        lifecycle_env.update(SWARM004_UI_MODE="lifecycle",
                             CYBERSAND_SWARM004_CLI=str((args.native_candidate / custody.FIXTURE).resolve()),
                             CYBERSAND_SWARM004_SOURCE="lifecycle-fixture-no-assembly",
                             CYBERSAND_SWARM004_SHA256=receipt["files"][custody.FIXTURE]["sha256"])
        result = execute("lifecycle", [*base, *display, "--script", "res://" + UI_SCRIPT], lifecycle_env, directory, 300)
        report = read_report(directory / "lifecycle.json")
        result = validate_result(result, ui_report_errors(report, "lifecycle", "transaction", receipt["source_commit"], cli_sha, test_sha), directory)
        lifecycle_passed = result["passed"]
        results.append(result)
    complete = (set(examples) == set(EXAMPLES) and all(record["passed"] for record in examples.values())
                and lifecycle_passed and all(result["passed"] for result in results))
    summary = {"schema": 2, "source_commit": receipt["source_commit"], "platform": sys.platform,
               "graphical": True, "package": bool(package), "passed": bool(complete),
               "graphical_scope": "four retained SWARM004/005 controls, five recorded SWARM006 2048x2048 blank-world synthetic evaluations, Apply/Undo/Save/reopen only when native-authorized, and child lifecycle; source and pristine package independently",
               "windows_automated_authoring_qualification": bool(complete),
               "owner_visual_acceptance": "pending",
               "reciprocal_programme_acceptance": False,
               "examples": examples, "lifecycle_passed": lifecycle_passed, "results": results}
    (output / "qualification.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: summary[key] for key in ("source_commit", "platform", "graphical", "package", "passed", "windows_automated_authoring_qualification", "owner_visual_acceptance")}))
    return 0 if complete else 1


if __name__ == "__main__":
    raise SystemExit(main())
