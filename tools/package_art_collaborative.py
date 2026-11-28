#!/usr/bin/env python3
"""Package the collaborative Art successor using the qualified Art custody recipe.

The predecessor manifest/launcher/native-runtime/import gates remain in force.
This wrapper requires fresh headless and displayed collaborative receipts at
the exact package source. It never reuses the predecessor application verdict.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
import posixpath
import sys
import zipfile
import shutil
import subprocess
from urllib.parse import unquote, urlsplit

import package_art_workbench_final as retained

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/ci"))
from run_art_collaborative_gates import TESTS, parse_case_output, validate_receipt

PROGRAMME = "ART-WORKBENCH-COLLABORATIVE-002"
GUIDE = "docs/operations/art-workbench-collaborative-evaluation.md"
QUALIFICATION_DIR = "qualification"
PACKAGED_TOOLS = ("tools/package_art_collaborative.py", "tools/ci/run_art_collaborative_gates.py",
                  "tools/ci/strata_generated_imports.py")


SCENARIO_IDS = (
    "industrial_repair", "structural_facade", "scifi_interior", "revised_arcology",
    "protected_courtyard", "palette_foundry", "stopped_workshop", "staged_megaframe", "xeno_vault",
)
EXAMPLE_SUFFIXES = (
    "before-native.png", "after-native.png", "before-workbench.png", "after-workbench.png",
    "editable-setup.json", "result.json", "original-native-receipts.json", "direct-original-native-receipts.json",
)
EXAMPLE_DIRECTORY = "examples/art-collaborative-evaluated"
MAX_EXAMPLE_FILE_BYTES = 16 * 1024 * 1024
MAX_EXAMPLE_TOTAL_BYTES = 256 * 1024 * 1024


def expected_setup_labels() -> dict:
    return {f"art02-{name}": f"{index:02d}-{name}-editable-setup.json"
            for index, name in enumerate(SCENARIO_IDS)}


def validate_packaged_examples(identity: dict, displayed: dict) -> None:
    """Require the complete displayed cohort, including nonmissing SHA identities."""
    examples = identity.get("creative_examples", {})
    if (examples.get("scenario_ids") != list(SCENARIO_IDS)
            or type(examples.get("model_calls")) is not int or examples["model_calls"] != 0):
        raise ValueError("Native example cohort identity differs")
    if examples.get("setup_labels") != expected_setup_labels():
        raise ValueError("Native example named-start mapping differs")
    if examples.get("source_receipt") != QUALIFICATION_DIR + "/collaborative-displayed.json":
        raise ValueError("Native example displayed source receipt differs")
    native_case = next(case for case in displayed["cases"] if case["name"] == "test_art_collaborative_native")
    hashes = native_case.get("artifacts_sha256", {})
    manifest = identity.get("files_sha256", {})
    if not isinstance(hashes, dict) or not isinstance(manifest, dict):
        raise ValueError("Native example artifact identities must be explicit dictionaries")
    names = [f"{index:02d}-{name}-{suffix}" for index, name in enumerate(SCENARIO_IDS) for suffix in EXAMPLE_SUFFIXES]
    names.append("creative-native-summary.json")
    expected = {}
    for name in names:
        digest = hashes.get(name)
        relative = EXAMPLE_DIRECTORY + "/" + name
        if not isinstance(digest, str) or re.fullmatch(r"[0-9a-f]{64}", digest) is None:
            raise ValueError("Required displayed native example hash is absent or invalid: " + name)
        if relative not in manifest or manifest[relative] != digest:
            raise ValueError("Required native example is absent from the immutable manifest: " + name)
        expected[relative] = digest
    if examples.get("original_files_sha256") != expected:
        raise ValueError("Native example files are not bound to displayed original evidence")


def stage_example_artifacts(output: Path, receipt_path: Path, displayed: dict) -> dict:
    """Copy only the declared synthetic-fixture native results, never a profile."""
    case = next(item for item in displayed["cases"] if item["name"] == "test_art_collaborative_native")
    source_dir = receipt_path.parent / "test_art_collaborative_native"
    hashes = case.get("artifacts_sha256", {})
    names = [f"{index:02d}-{name}-{suffix}"
             for index, name in enumerate(SCENARIO_IDS) for suffix in EXAMPLE_SUFFIXES]
    names.append("creative-native-summary.json")
    target_dir = output / EXAMPLE_DIRECTORY
    target_dir.mkdir(parents=True)
    total = 0
    verified = {}
    for name in names:
        source = source_dir / name
        if source.is_symlink() or not source.is_file() or source.stat().st_size > MAX_EXAMPLE_FILE_BYTES:
            raise ValueError("Required bounded native example is missing or unsafe: " + name)
        total += source.stat().st_size
        if total > MAX_EXAMPLE_TOTAL_BYTES:
            raise ValueError("Native example cohort exceeds its package budget")
        actual = retained.sha(source)
        if hashes.get(name) != actual:
            raise ValueError("Native example differs from the displayed qualification receipt: " + name)
        if source.suffix == ".png":
            with source.open("rb") as stream:
                if stream.read(8) != b"\x89PNG\r\n\x1a\n":
                    raise ValueError("Native example image is not a PNG: " + name)
        else:
            if not isinstance(json.loads(source.read_text(encoding="utf-8")), (dict, list)):
                raise ValueError("Native example JSON has no object/array document: " + name)
        shutil.copyfile(source, target_dir / name)
        verified[EXAMPLE_DIRECTORY + "/" + name] = actual
    labels = expected_setup_labels()
    lines = [
        "@echo off", "setlocal",
        'set "ART_EXAMPLE_DEST=%~dp0profile\\Godot\\app_userdata\\Cyber Sand Reference Sandbox\\workbench"',
        'if not exist "%ART_EXAMPLE_DEST%" mkdir "%ART_EXAMPLE_DEST%"',
        "if errorlevel 1 exit /b 1",
    ]
    for label, name in labels.items():
        lines += [
            'if not exist "%ART_EXAMPLE_DEST%\\setup-' + label + '.json" copy /b "%~dp0examples\\art-collaborative-evaluated\\' + name + '" "%ART_EXAMPLE_DEST%\\setup-' + label + '.json" >nul',
            "if errorlevel 1 exit /b 1",
        ]
    lines += ["echo Evaluated starts installed without replacing existing saved starts.",
              "echo In Workbench, enter one of these names and click Load start:"]
    lines += ["echo " + label for label in labels]
    lines += ["exit /b 0"]
    (output / "Install evaluated starts.cmd").write_bytes(("\r\n".join(lines) + "\r\n").encode("utf-8"))
    readme = (
        "# Evaluated native examples\n\n"
        "These are exact deterministic-fixture outputs from the displayed Windows "
        "qualification of this package source. They are editable ordinary Setup-v2 "
        "authored starts, not runtime continuation or model-generated creative evidence.\n\n"
        "Close the Workbench, double-click **Install evaluated starts.cmd**, open "
        "**Open Workbench.cmd**, enter a name below in Workbench's setup-name field, "
        "then click **Load start**. Existing saved starts of the same name are preserved.\n\n"
        + "\n".join("- " + label for label in labels)
        + "\n\nEach later start includes the earlier atlas constructions. "
        "The per-case result identifies its focus region. Native PNGs encode actual "
        "material observations; Workbench PNGs are actual rendered framebuffers. "
        "Native receipts record acknowledged work, including partial/refused outcomes. "
        "The paired direct controls are deterministic fixed-geometry comparisons, "
        "not evidence of a causal retrieval or real-model creativity improvement.\n"
    )
    (target_dir / "READ-ME.md").write_text(readme, encoding="utf-8")
    return {"kind": "actual native deterministic fixture outputs", "model_calls": 0,
            "scenario_ids": list(SCENARIO_IDS), "setup_labels": labels,
            "original_files_sha256": verified, "original_bytes": total,
            "source_receipt": "qualification/collaborative-displayed.json"}


def verify_installed_examples(output: Path, identity: dict) -> dict:
    directory = output / "profile/Godot/app_userdata/Cyber Sand Reference Sandbox/workbench"
    checked = {}
    for label, filename in identity["creative_examples"]["setup_labels"].items():
        source = output / EXAMPLE_DIRECTORY / filename
        destination = directory / ("setup-" + label + ".json")
        if not destination.is_file() or retained.sha(destination) != retained.sha(source):
            raise ValueError("Actual evaluated-starts CMD did not install the exact named setup: " + label)
        checked[label] = retained.sha(destination)
    return {"actual_installer": True, "package_local_only": True, "setups_sha256": checked}


def receipt(path: Path, commit: str, tree: str, graphical: bool, check_logs: bool = True) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    validate_receipt(value, commit=commit, tree=tree, platform_name="windows", graphical=graphical)
    if check_logs:
        for case in value["cases"]:
            log = path.parent / case["name"] / "process.log"
            if not log.is_file() or retained.sha(log) != case["log_sha256"]:
                raise ValueError("Complete original case log is missing or changed: " + case["name"])
            original = parse_case_output(log.read_text(encoding="utf-8", errors="replace"), TESTS[case["name"]])
            if original != case["result"]:
                raise ValueError("Original case result differs from qualification receipt: " + case["name"])
    if graphical:
        ui = next(case for case in value["cases"] if case["name"] == "test_art_collaboration_workspace")
        if ui["result"].get("display") in (None, "", "headless"):
            raise ValueError("Displayed collaborative UI did not identify a real display backend")
    return value


def validate_pair(headless: dict, displayed: dict) -> None:
    if headless["runtime"] != displayed["runtime"]:
        raise ValueError("Headless and displayed qualification used different runtime payloads")


def validate_packaged_guide(output: Path, identity: dict) -> None:
    """Keep the shipped guide's Markdown file references inside its immutable payload.

    This checks ordinary inline links and reference definitions without fetching
    online references. Fragment-only links refer to the guide itself. The check
    is deliberately a delivery boundary, not a general Markdown renderer.
    """
    manifest = identity.get("files_sha256", {})
    if identity.get("principal_guide") != GUIDE or GUIDE not in manifest:
        raise ValueError("The immutable collaborative owner guide is absent")
    guide = output / GUIDE
    if guide.is_symlink() or not guide.is_file() or retained.sha(guide) != manifest[GUIDE]:
        raise ValueError("The collaborative owner guide differs from its manifest")
    text = guide.read_text(encoding="utf-8")
    # Examples inside fenced/inline code are not navigation destinations.
    text = re.sub(r"(?ms)^(`{3,}|~{3,})[^\n]*\n.*?^\1[ \t]*(?:\n|$)", "", text)
    text = re.sub(r"`+[^`]*`+", "", text)
    inline = re.findall(r"!?\[[^\]]*\]\(\s*(?:<([^>\n]+)>|([^\s)]+))(?:\s+[\"'][^\n]*?[\"'])?\s*\)", text)
    definitions = re.findall(r"(?m)^ {0,3}\[([^\]\n]+)\]:\s*(?:<([^>\n]+)>|(\S+))", text)
    defined = {label.strip().casefold() for label, _, _ in definitions}
    for label, reference in re.findall(r"!?\[([^\]\n]+)\]\[([^\]\n]*)\]", text):
        if (reference or label).strip().casefold() not in defined:
            raise ValueError("The owner guide has an undefined Markdown reference: " + (reference or label))
    destinations = [angle or bare for angle, bare in inline]
    destinations += [angle or bare for _, angle, bare in definitions]
    for destination in destinations:
        parsed = urlsplit(destination)
        if parsed.scheme:
            if parsed.scheme != "https" or not parsed.netloc:
                raise ValueError("The owner guide has an unsupported online reference: " + destination)
            continue
        if parsed.netloc or "\\" in destination:
            raise ValueError("The owner guide has an unsafe file reference: " + destination)
        if not parsed.path:
            continue
        path = unquote(parsed.path)
        if "\\" in path:
            raise ValueError("The owner guide has an unsafe file reference: " + destination)
        relative = posixpath.normpath(posixpath.join(posixpath.dirname(GUIDE), path))
        if path.startswith("/") or relative == ".." or relative.startswith("../"):
            raise ValueError("The owner guide references a file outside the package: " + destination)
        target = output / relative
        if (relative not in manifest or not target.resolve().is_relative_to(output.resolve())
                or target.is_symlink() or not target.is_file()
                or retained.sha(target) != manifest[relative]):
            raise ValueError("The owner guide references an absent immutable payload: " + destination)


def build(args: argparse.Namespace) -> dict:
    source, tree = retained.git("rev-parse", "HEAD"), retained.git("rev-parse", "HEAD^{tree}")
    if args.qualification_source is None:
        raise ValueError("Fresh source qualification decision is required")
    proof = retained.qualification_source(args.qualification_source, source, tree)
    if proof is None or proof.get("mode") != "full_required" or proof.get("reuse") is not False:
        raise ValueError("Collaborative application changes require fresh full qualification")
    headless = receipt(args.headless_receipt, source, tree, False)
    displayed = receipt(args.displayed_receipt, source, tree, True)
    validate_pair(headless, displayed)
    old_guide = retained.GUIDE
    retained.GUIDE = GUIDE
    try:
        identity = retained.build(args)
    finally:
        retained.GUIDE = old_guide
    output = args.output.resolve()
    # Include the exact committed successor recipe and its evidence validator.
    for relative in PACKAGED_TOOLS:
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(__import__("subprocess").check_output(
            ["git", "show", "HEAD:" + relative], cwd=ROOT, timeout=60))
    qualification_dir = output / QUALIFICATION_DIR
    qualification_dir.mkdir()
    for name, value in (("collaborative-headless.json", headless), ("collaborative-displayed.json", displayed)):
        (qualification_dir / name).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    native_paths = [retained.NATIVE, retained.retained.RAPIER]
    for relative in native_paths:
        if headless["runtime"]["payloads"].get(relative) != retained.sha(output / relative):
            raise ValueError("Qualified native/Rapier payload differs from the delivered payload: " + relative)
    if headless["runtime"].get("provenance_sha256") != retained.sha(output / "godot/addons/cybersand_native/runtime-provenance.json"):
        raise ValueError("Qualified native provenance differs from the delivered source record")
    console = output / "Godot_v4.7-stable_win64_console.exe"
    if headless["runtime"]["godot_sha256"] != retained.sha(console):
        raise ValueError("Qualified Godot differs from delivered console engine")
    creative_examples = stage_example_artifacts(output, args.displayed_receipt, displayed)
    identity.update(programme=PROGRAMME, creative_examples=creative_examples,
        collaborative_qualification={
            "kind": "fresh source-exact deterministic fixture application",
            "source_commit": source, "source_tree": tree, "model_calls": 0,
            "headless": QUALIFICATION_DIR + "/collaborative-headless.json",
            "displayed": QUALIFICATION_DIR + "/collaborative-displayed.json",
            "required_cases": sorted(TESTS), "predecessor_matrix": "separately required workflow stage",
            "physical_owner_acceptance": "pending",
        },
        principal_guide=GUIDE,
        automatic_model_requests=False,
        status="Draft/HOLD")
    identity["files_sha256"] = {
        path.relative_to(output).as_posix(): retained.sha(path)
        for path in sorted(output.rglob("*"))
        if path.is_file() and path.name != retained.MANIFEST
    }
    (output / retained.MANIFEST).write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    verify(output)
    return identity


def verify(output: Path) -> dict:
    identity = retained.verify(output)
    if identity.get("programme") != PROGRAMME or identity.get("status") != "Draft/HOLD":
        raise ValueError("This is not the collaborative Draft/HOLD evaluator")
    validate_packaged_guide(output, identity)
    scope = identity.get("collaborative_qualification", {})
    if scope.get("source_commit") != identity["source_commit"] or scope.get("source_tree") != identity["source_tree"]:
        raise ValueError("Collaborative qualification is not source-bound")
    if type(scope.get("model_calls")) is not int or scope["model_calls"] != 0 or scope.get("required_cases") != sorted(TESTS):
        raise ValueError("Collaborative qualification scope differs")
    values = []
    for name, graphical in (("headless", False), ("displayed", True)):
        relative = QUALIFICATION_DIR + "/collaborative-" + name + ".json"
        if scope.get(name) != relative or relative not in identity["files_sha256"]:
            raise ValueError("Immutable qualification receipt is absent")
        values.append(receipt(output / relative, identity["source_commit"], identity["source_tree"],
                              graphical, check_logs=False))
    validate_pair(*values)
    validate_packaged_examples(identity, values[1])
    for relative in (retained.NATIVE, retained.retained.RAPIER):
        if values[0]["runtime"]["payloads"].get(relative) != retained.sha(output / relative):
            raise ValueError("Delivered runtime differs from application qualification")
    if values[0]["runtime"].get("provenance_sha256") != retained.sha(output / "godot/addons/cybersand_native/runtime-provenance.json"):
        raise ValueError("Delivered native provenance differs from application qualification")
    if values[0]["runtime"]["godot_sha256"] != retained.sha(output / "Godot_v4.7-stable_win64_console.exe"):
        raise ValueError("Delivered Godot differs from application qualification")
    return identity


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "verify", "smoke", "zip"])
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--engine-notices", type=Path)
    parser.add_argument("--vc-runtime", type=Path)
    parser.add_argument("--qualification-source", type=Path)
    parser.add_argument("--headless-receipt", type=Path)
    parser.add_argument("--displayed-receipt", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    args = parser.parse_args()
    if args.command == "build":
        if not all((args.engine, args.engine_notices, args.vc_runtime, args.qualification_source,
                    args.headless_receipt, args.displayed_receipt)):
            parser.error("build requires engine, notices, VC runtime, source decision and both fresh application receipts")
        build(args)
    elif args.command == "smoke":
        if args.evidence is None:
            parser.error("smoke requires evidence")
        verify(args.output)
        retained.smoke(args)
        with (args.evidence / "installed-examples.log").open("w", encoding="utf-8") as stream:
            subprocess.run(["cmd.exe", "/d", "/c", str(args.output.resolve() / "Install evaluated starts.cmd")],
                           cwd=args.output, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=30)
        identity = verify(args.output)
        result = verify_installed_examples(args.output, identity)
        (args.evidence / "installed-examples.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    elif args.command == "zip":
        identity = verify(args.output)
        destination = args.output.with_suffix(".zip")
        with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for relative in sorted([*identity["files_sha256"], retained.MANIFEST]):
                archive.write(args.output / relative, args.output.name + "/" + relative)
        destination.with_suffix(".zip.sha256").write_text(retained.sha(destination) + "  " + destination.name + "\n")
    else:
        verify(args.output)
    print(json.dumps({"status": "passed", "programme": PROGRAMME, "command": args.command, "output": str(args.output)}))


if __name__ == "__main__":
    main()
