#!/usr/bin/env python3
"""GEN-007 branch-only source-matched Linux/Windows native publisher.

Reuse the existing Git input, toolchain, Git LFS, source lease and four-path
custody checks. Admit only real target-OS graphical architecture, Flatten and
Windows extracted-package qualification. Never merge, and never bypass gates.
"""
from __future__ import annotations
import argparse
import hashlib
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import shutil
import sys

_spec = spec_from_file_location(
    "_gen007_private_runtime_engine",
    Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"),
)
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
engine.BRANCH = "feat/gen007-architectural-generator-ab"
engine.WORKFLOW = ".github/workflows/architectural-generator-qualification.yml"
engine.REQUEST = "tools/ci/gen007_architectural_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-14-architectural-generator-local.md"
engine.PRESSURE_CASE = "godot/tests/test_architectural_generator.gd"
engine.BUNDLE_PREFIX = "architecture-validated"
engine.REQUEST_VALUE = {
    "schema": "gen007-architecture-runtime-publish-request-v1",
    "family": "gen007-architectural-generator",
    "variant": "v1-v2-thirteen-presets-five-style-cards",
    "scope": "linux-windows-native-graphical-multistyle-flatten-owner-package",
    "intent": "publish-source-matched-runtimes",
}
engine.CASE_MARKERS = {
    "test_architectural_generator": r"ARCHITECTURE_RESULTS phase=native checks=812 failures=0 complete=true",
    "test_architectural_generator_ui": r"ARCHITECTURAL_UI checks=56 failures=0",
    "test_architectural_project_contract": r"ARCHITECTURAL_PROJECT_CONTRACT checks=[1-9][0-9]* failures=0",
    "test_workbench_edit_ordering": r'EDIT_ORDER_RESULT .*"failures":0',
}
engine.BUILD_EXACT = set(engine.BUILD_EXACT) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/gen007_architectural_runtime_publication.py",
    "tools/ci/test_gen007_architectural_runtime_publication.py",
    "tools/ci/native_candidate_identity.py",
    "tools/architecture/qualify.py",
    "tools/ci/run_flatten_qualification.py",
    "tools/package_explore001_candidate.py",
    "docs/operations/architectural-generator-playtest.md",
}
engine.EXECUTION_SCOPE = (
    "Exact-source architectural native tests, 56 graphical style-card checks, "
    "73/22 author-reopen, five/sparse-style 79/31, edit ordering and legacy "
    "receipts, graphical 512x512 GEN-008 Flatten recovery on both OSes, plus "
    "independently extracted Windows owner-package architecture/Flatten replay."
)
FULL_PHASES = (
    "import", "project-contract", "native", "ui", "author", "reopen",
    "multistyle-author", "multistyle-reopen", "worldgen_workbench",
    "worldgen_fields", "worldgen_typed", "worldgen_grammar",
    "worldgen_planes", "gen007_workbench", "gen007_inspection",
    "workbench_canvas", "workbench_edit_ordering", "legacy-materials",
    "legacy-material-equivalence", "legacy-cross-platform-material-equivalence",
    "source-stability",
)
OWNER_PHASES = ("import", "author", "reopen", "multistyle-author",
                "multistyle-reopen", "source-stability")
COUNTS = {"native": "812", "author": "73", "reopen": "22",
          "multistyle-author": "79", "multistyle-reopen": "31"}
RECEIPTS = {
    "architecture": "gen007-architecture-qualification.json",
    "identity": "gen007-architecture-source-identity.json",
    "flatten": "gen007-flatten-qualification.json",
    "package": "gen007-package-qualification.json",
    "package_flatten": "gen007-package-flatten-qualification.json",
}


def read_json(path: Path) -> dict:
    result = json.loads(path.read_text(encoding="utf-8"))
    engine.require(isinstance(result, dict), "Invalid publication receipt: " + str(path))
    return result


def validate_architecture(value: dict, source: str, native_hash: str,
                          *, owner: bool = False) -> None:
    phases = OWNER_PHASES if owner else FULL_PHASES
    engine.require(value.get("schema") == 1 and value.get("passed") is True
                   and value.get("failures") == 0
                   and value.get("graphical_requested") is True
                   and value.get("source_commit") == source
                   and value.get("runtime_sha256") == native_hash,
                   "Architecture execution is not complete, graphical or source/runtime matched")
    rows = value.get("cases")
    engine.require(isinstance(rows, list)
                   and [row.get("case") for row in rows] == list(phases)
                   and all(row.get("passed") is True for row in rows),
                   "Architecture native, UI, legacy, owner or source-stability phase missing/failed")
    for row in rows:
        name = row["case"]
        if name in COUNTS:
            engine.require(row.get("completion") == [COUNTS[name]],
                           "Architectural phase has wrong exact assertion count: " + name)
        if name == "ui":
            engine.require(row.get("completion") == ["ARCHITECTURAL_UI checks=56 failures=0"],
                           "All 56 fifth-card UI assertions must execute")


def validate_flatten(value: dict) -> None:
    engine.require(value.get("status") == "passed" and value.get("graphical") is True
                   and value.get("cases") == [[512, 1]]
                   and isinstance(value.get("storage_faults"), dict)
                   and value["storage_faults"].get("status") == "passed",
                   "Graphical GEN-008 native owner/reopen and failure recovery did not pass")


def validate_source(value: dict, source: str, native_hash: str, tree: str, ledger: dict) -> None:
    engine.require(value.get("source_commit") == source
                   and value.get("source_tree") == tree
                   and value.get("runtime_sha256") == native_hash,
                   "Architecture source identity is not the built runtime")
    inputs = value.get("source_inputs_sha256")
    engine.require(isinstance(inputs, dict) and len(inputs) >= len(ledger)
                   and all(inputs.get(path) == digest for path, digest in ledger.items()),
                   "Architectural native files diverged from the Git input ledger")


def verify_case_results(directory: Path, report: dict) -> None:
    source, platform = report["source_commit"], report["platform"]
    native_hash = report["runtime"]["sha256"]
    receipts = report.get("receipts")
    required = {"architecture", "identity", "flatten"}
    if platform == "windows":
        required |= {"package", "package_flatten"}
    engine.require(isinstance(receipts, dict) and set(receipts) == required,
                   "Missing platform-specific architecture/package execution receipts")
    verified = {}
    for name in sorted(required):
        row = receipts[name]
        original = directory / RECEIPTS[name]
        engine.require(row.get("filename") == RECEIPTS[name]
                       and engine.runner.sha256(original) == row.get("sha256"),
                       "Original execution receipt missing or modified: " + name)
        verified[name] = read_json(original)
    validate_architecture(verified["architecture"], source, native_hash)
    validate_source(verified["identity"], source, native_hash,
                    report["source_tree"], report["source_inputs"])
    validate_flatten(verified["flatten"])
    if platform == "windows":
        validate_architecture(verified["package"], source, native_hash, owner=True)
        validate_flatten(verified["package_flatten"])
    engine.require(report.get("scope") == engine.EXECUTION_SCOPE,
                   "Publication acceptance scope was altered")


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
    if args.platform == "linux":
        archive_hash = engine.runner.sha256(args.godot_archive)
        engine.require(archive_hash == engine.GODOT_LINUX_SHA256,
                       "Linux Godot 4.7 archive pin mismatch")
        godot = {"version": engine.GODOT_VERSION, "archive_sha256": archive_hash}
    else:
        archive_hash = hashlib.sha512(args.godot_archive.read_bytes()).hexdigest()
        engine.require(archive_hash == engine.windows.GODOT_SHA512,
                       "Windows Godot 4.7 archive pin mismatch")
        godot = {"version": engine.GODOT_VERSION, "archive_sha512": archive_hash}
    paths = {
        "architecture": args.qualification / "qualification.json",
        "identity": args.qualification / "source-runtime-identity.json",
        "flatten": args.flatten / "qualification.json",
    }
    if args.platform == "windows":
        engine.require(args.package is not None and args.package_flatten is not None,
                       "Windows acceptance requires independently extracted owner/package replays")
        paths["package"] = args.package / "qualification.json"
        paths["package_flatten"] = args.package_flatten / "qualification.json"
    receipts = {}
    for name, origin in paths.items():
        target = args.bundle / RECEIPTS[name]
        engine.require(origin.is_file() and not origin.is_symlink(),
                       "Original architecture evidence missing: " + str(origin))
        shutil.copyfile(origin, target)
        receipts[name] = {"filename": RECEIPTS[name],
                          "sha256": engine.runner.sha256(target)}
    report = {
        "schema_version": 1, "source_commit": args.source_sha,
        "source_tree": manifest["source_tree"], "platform": args.platform,
        "runtime": {key: manifest[key] for key in ("artifact", "sha256", "size")},
        "godot": godot, "rapier_sha256": rapier_sha,
        "status": "passed", "completed": True, "results": [],
        "scope": engine.EXECUTION_SCOPE, "receipts": receipts,
    }
    verify_case_results(args.bundle, report)
    engine.require(engine.input_ledgers(args.source_sha)
                   == {key: manifest[key] for key in ("source_inputs", "build_inputs")},
                   "Test or build inputs changed between compilation and validation")
    engine.write_json(args.bundle / "validation.json", report)
    manifest.update({
        "status": "validated-development-runtime",
        "workflow_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
        "validated_platform": args.platform.title() + " x86_64 / real graphical Godot 4.7",
        "acceptance": "Source-matched built library passed: " + engine.EXECUTION_SCOPE,
        "validation_output": engine.BUNDLE_PREFIX + "-" + args.platform + "-"
                             + os.environ["GITHUB_RUN_ID"] + "/validation.json",
        "validation_sha256": engine.runner.sha256(args.bundle / "validation.json"),
        "other_platforms": "No human Windows 11/GPU hardware acceptance is asserted.",
    })
    engine.write_json(engine.manifest_path(args.bundle, args.platform), manifest)
    engine.verify_bundle(args.bundle, args.platform, args.source_sha, validated=True)


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "accept":
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("command", choices=("accept",))
        parser.add_argument("--source-sha", required=True)
        parser.add_argument("--platform", choices=("linux", "windows"), required=True)
        parser.add_argument("--bundle", type=Path, required=True)
        parser.add_argument("--qualification", type=Path, required=True)
        parser.add_argument("--flatten", type=Path, required=True)
        parser.add_argument("--package", type=Path)
        parser.add_argument("--package-flatten", type=Path)
        parser.add_argument("--godot-archive", type=Path, required=True)
        accept(parser.parse_args())
        return 0
    return engine.main()


if __name__ == "__main__":
    raise SystemExit(main())
