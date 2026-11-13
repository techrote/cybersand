#!/usr/bin/env python3
"""Add Flatten acceptance to the existing complete MAT/Workbench Windows package.

The original packager keeps its source history, runtime, licence, offline
toolchain and installed-regression gates. This private composition additionally
requires the source-qualified Flatten bundle and executes the delivered feature.
"""
from __future__ import annotations

import argparse
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent / "ci"))
import gen008_flatten_runtime_publication as publication
import run_flatten_qualification as flatten_runner

_spec = spec_from_file_location("_gen008_private_workbench_packager",
                               Path(__file__).with_name("package_mat_workbench_candidate.py"))
workbench = module_from_spec(_spec)
_spec.loader.exec_module(workbench)
workbench.publication = publication
workbench.engine = publication.engine
workbench.lab.publication = publication
workbench.lab.engine = publication.engine
engine = publication.engine
MANIFEST = workbench.MANIFEST
SCOPE = "GEN-008-FLAT-001 + accepted MAT-AUTH and Shared Workbench"


def verify(package: Path) -> dict:
    identity = workbench.verify(package)
    engine.require(identity.get("flatten_scope") == SCOPE,
                   "Standalone evaluation lacks its Flatten source/acceptance identity")
    source = package / "source"
    for path in (*publication.SOURCE_PATHS,publication.OWNER_FAILURE_SCRIPT):
        engine.require((source / "godot" / path).is_file(), "Delivered Flatten source is missing: " + path)
    report = package / "qualification/flatten.json"
    engine.require(report.is_file() and identity.get("flatten_qualification_sha256") == engine.runner.sha256(report),
                   "Delivered Flatten qualification changed or is missing")
    return identity


def build(args) -> Path:
    package = workbench.build(args)
    identity = workbench.verify(package)
    with (package / "README.txt").open("a", encoding="utf-8") as stream:
        stream.write(
            "\nFlatten / Bake History acceptance (#548):\n"
            "1. Generate or paint a complex map and place an actor.\n"
            "2. Play the simulation until material placement changes.\n"
            "3. Click Flatten / Bake History and confirm. Tick, motion and actors continue.\n"
            "4. Pause and paint/erase again; try Undo/Redo for those new edits.\n"
            "5. Save named start, completely exit Godot, then launch again and Load that name.\n"
            "6. Check the flattened layout plus acknowledged edits, then keep authoring.\n\n"
            "Flatten discards earlier construction and Undo/Redo history. It does not Save.\n"
            "The saved baseline uses exactly two little-endian bytes per material ID.\n"
            "A later Load starts normal initial physics; it is not a simulation checkpoint.\n"
            "Later simulation changes enter the saved baseline only after another explicit Flatten.\n"
            "Original native/graphical/scale/fresh-process/RSS evidence is in qualification/flatten/.\n"
            "Automated Windows graphical tests are separate from acceptance on your own PC.\n")
    identity.update(flatten_scope=SCOPE,
                    flatten_qualification_sha256=engine.runner.sha256(package / "qualification/flatten.json"),
                    files_sha256=workbench.lab.file_map(package))
    (package / MANIFEST).write_bytes(workbench.lab.canonical(identity))
    verify(package)
    return package


def smoke(package: Path, evidence: Path) -> dict:
    identity = verify(package)
    # Keep the complete installed predecessor suite, then prove Flatten using
    # another disposable copy with only the delivered engine and dependencies.
    workbench.smoke(package, evidence / "retained-workbench")
    report = {"schema": "gen008-flatten-package-execution-v1", "source_commit": identity["source_commit"],
              "native_sha256": identity["native_sha256"], "completed": False, "status": "running"}
    target = evidence / "flatten-package-execution.json"
    engine.write_json(target, report)
    try:
        with tempfile.TemporaryDirectory(prefix="CyberSand Flatten Evaluation ") as temporary:
            candidate = Path(temporary) / "evaluation"
            shutil.copytree(package, candidate)
            environment = workbench.lab.dependency_environment(candidate)
            old_environment = dict(os.environ)
            try:
                os.environ.update(environment)
                output = evidence / "flatten"
                storage_faults = flatten_runner.flatten(argparse.Namespace(
                    godot=candidate / "Godot_v4.7-stable_win64_console.exe",
                    project=candidate / "source/godot", evidence=output,
                    package=None, headless=False, cases=publication.CASES))
                engine.write_json(output / "qualification.json", {
                    "status": "passed", "cases": [list(case) for case in publication.CASES], "graphical": True,
                    "storage_faults": storage_faults})
                publication.verify_flatten_cases(output, "windows", identity["native_sha256"], candidate / "source/godot")
            finally:
                os.environ.clear()
                os.environ.update(old_environment)
        verify(package)
        report.update(status="passed", completed=True)
    except Exception as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        report["files_sha256"] = {path.relative_to(evidence).as_posix(): engine.runner.sha256(path)
                                  for path in sorted(evidence.rglob("*")) if path.is_file() and path != target}
        engine.write_json(target, report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "verify", "smoke"])
    parser.add_argument("--source-sha")
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--godot-archive", type=Path)
    parser.add_argument("--engine-notices", type=Path)
    parser.add_argument("--vc-runtime", type=Path)
    parser.add_argument("--python-root", type=Path, default=Path(sys.base_prefix))
    parser.add_argument("--git-root", type=Path, default=Path(r"C:\Program Files\Git"))
    parser.add_argument("--compiler-root", type=Path, default=Path(r"C:\mingw64"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    args = parser.parse_args()
    if args.command == "build":
        if any(value is None for value in (args.source_sha, args.bundle, args.godot_archive, args.engine_notices, args.vc_runtime)):
            parser.error("Build requires source, qualified bundle, Godot archive/notices and verified VC runtime")
        build(args)
    elif args.command == "smoke":
        if args.evidence is None: parser.error("Smoke evidence directory is required")
        smoke(args.output, args.evidence)
    else:
        verify(args.output)
    print(json.dumps({"status": "passed", "command": args.command, "output": str(args.output)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
