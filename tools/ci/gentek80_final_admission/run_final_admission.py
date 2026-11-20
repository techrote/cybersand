#!/usr/bin/env python3
"""Execute unchanged candidate runners under a retained-runtime custody boundary."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

import package_retained_gentek80 as package
import retained_runtime_admission as admission


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def run(command: list[str], candidate: Path, output: Path, final_sha: str) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    began = time.monotonic()
    receipt = {"command": command, "cwd": str(candidate), "status": "running",
               "source_commit": final_sha, "timeout_seconds": 9000}
    environment = dict(os.environ, CYBERSAND_SOURCE_REVISION=final_sha)
    # GITHUB_SHA remains the actual auxiliary orchestration commit.
    log = output / "runner.log"
    try:
        with log.open("w", encoding="utf-8") as stream:
            child = subprocess.run(command, cwd=candidate, env=environment,
                                   stdout=stream, stderr=subprocess.STDOUT, timeout=9000)
        receipt.update(returncode=child.returncode,
                       status="passed" if child.returncode == 0 else "failed")
        package.require(child.returncode == 0, "Unmodified runner failed; see " + str(log))
    except Exception as error:
        receipt.update(status="failed", error=str(error))
        raise
    finally:
        receipt["elapsed_seconds"] = time.monotonic() - began
        receipt["log_sha256"] = package.sha(log)
        package.write_json(output / "outer-process.json", receipt)
    return receipt


def protected_after(directory: Path, manifest: dict) -> dict:
    """Only generated editor/import/UID metadata may change in the test copy."""
    original = manifest["files_sha256"]
    generated, metadata_changes = {}, {}
    for name, expected in original.items():
        path = directory / name
        package.require(path.is_file() and not path.is_symlink(), "Package file removed: " + name)
        actual = package.sha(path)
        if actual != expected:
            package.require(name.startswith("godot/") and name.endswith((".import", ".uid")),
                            "Protected package file changed during execution: " + name)
            metadata_changes[name] = {"before": expected, "after": actual}
    for path in directory.rglob("*"):
        package.require(not path.is_symlink(), "Test extraction contains a symlink")
        if not path.is_file():
            continue
        name = path.relative_to(directory).as_posix()
        if name not in original and name != package.MANIFEST:
            package.require(name.startswith("godot/.godot/") or
                            (name.startswith("godot/") and name.endswith((".import", ".uid"))),
                            "Unexpected file added to test extraction: " + name)
            generated[name] = package.sha(path)
    return {"protected_files": len(original), "permitted_metadata_changes": metadata_changes,
            "generated_metadata_sha256": generated}


def process_binding(rows: list[dict], output: Path, project: Path, engine: Path,
                    *, flatten: bool = False) -> dict:
    """Bind unchanged original process receipts to the actual package paths."""
    hashes = {}
    for row in rows:
        if row.get("case") == "source-stability":
            continue
        label = row.get("label") if flatten else row.get("case")
        package.safe_relative(label)
        command = row.get("command", [])
        package.require(isinstance(command, list) and command and
                        Path(command[0]).resolve() == engine.resolve() and
                        command.count("--path") == 1 and
                        Path(command[command.index("--path") + 1]).resolve() == project.resolve(),
                        "Process used another engine or project: " + label)
        if flatten:
            package.require(Path(row["engine_executable"]).resolve() == engine.resolve() and
                            row["engine_executable_sha256"] == package.sha(engine),
                            "Flatten measured another engine: " + label)
        else:
            original = output / (label + "-process.json")
            package.require(read(original) == row, "Original process receipt differs: " + label)
            hashes[original.name] = package.sha(original)
        log = output / (label + ".log")
        package.require(log.is_file(), "Missing original process log: " + label)
        if not flatten:
            package.require(package.sha(log) == row["log_sha256"], "Process log hash mismatch: " + label)
        hashes[log.name] = package.sha(log)
    return hashes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--mode", choices=("checkout-workbench", "owner", "flatten", "package-workbench"), required=True)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--assembly", type=Path)
    parser.add_argument("--assets-archive", type=Path)
    parser.add_argument("--extraction", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    config, candidate, bundle = read(args.config), args.candidate.resolve(), args.bundle.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    final_sha, final_tree, built_sha = config["published_source"], config["published_tree"], config["built_source"]
    result = {"schema": "gentek80-final-execution-v1", "status": "running", "mode": args.mode,
              "platform": args.platform, "application_source_commit": final_sha,
              "application_source_tree": final_tree, "native_build_commit": built_sha,
              "orchestration_commit": os.environ.get("GITHUB_SHA"),
              "orchestration_run": os.environ.get("GITHUB_RUN_ID"),
              "orchestration_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
              "configuration_sha256": package.sha(args.config)}
    def verify(**kwargs):
        return admission.verify(candidate, bundle, args.platform, built_sha, final_sha, final_tree,
                                config["original_run_id"], config["original_run_attempt"], **kwargs)
    try:
        before = verify()
        result.update(before=before, native_sha256=before["runtime"]["sha256"])
        publisher = admission.load_publisher(candidate)
        manifest = None
        if args.mode == "checkout-workbench":
            package.require(args.godot is not None, "Checkout execution requires a pinned engine")
            project, engine = candidate / "godot", args.godot.resolve()
        else:
            package.require(args.platform == "windows" and args.archive and args.assembly and
                            args.assets_archive and args.extraction, "Package execution requires exact ZIP custody")
            assembly = read(args.assembly)
            package.require(assembly.get("schema") == "gentek80-final-package-assembly-v1" and
                            assembly.get("status") == "packaged-not-executed" and
                            assembly.get("application_source_commit") == final_sha and
                            assembly.get("application_source_tree") == final_tree and
                            assembly.get("native_build_commit") == built_sha and
                            assembly.get("native_sha256") == before["runtime"]["sha256"] and
                            assembly.get("asset_package_sha256") == config["windows_asset_zip_sha256"] and
                            assembly.get("orchestration_commit") == os.environ.get("GITHUB_SHA") and
                            assembly.get("orchestration_run") == os.environ.get("GITHUB_RUN_ID"),
                            "Package assembly receipt belongs to another execution")
            directory = args.extraction.resolve()
            package.extract_pristine(args.archive, directory, assembly["archive_sha256"])
            manifest = package.verify_package(candidate, directory, final_sha=final_sha, final_tree=final_tree,
                         built_sha=built_sha, native_sha=before["runtime"]["sha256"],
                         assets_sha256=config["windows_asset_zip_sha256"],
                         bundle=bundle, assets_archive=args.assets_archive)
            result.update(archive_sha256=assembly["archive_sha256"], archive_bytes=args.archive.stat().st_size,
                          package_manifest_sha256=package.sha(directory / package.MANIFEST),
                          assembly_receipt_sha256=package.sha(args.assembly))
            project, engine = directory / "godot", directory / package.CONSOLE
        package.require(project.is_dir() and engine.is_file(), "Project or engine is missing")
        engine_hashes = {str(engine): package.sha(engine)}
        if args.platform == "windows":
            gui = engine.with_name(engine.name.removesuffix("_console.exe") + ".exe")
            package.require(gui != engine and gui.is_file(), "Windows GUI engine sibling is missing")
            engine_hashes[str(gui)] = package.sha(gui)
        version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
        package.require(version == package.VERSION, "Godot engine version pin mismatch")
        phase_output = output / "execution"
        if args.mode in ("checkout-workbench", "package-workbench"):
            command = [sys.executable, str(candidate / "tools/architecture/gentek80_workbench.py"),
                       "--godot", str(engine), "--project", str(project), "--output", str(phase_output), "--graphical"]
            if manifest:
                command += ["--package", str(directory)]
        elif args.mode == "owner":
            command = [sys.executable, str(candidate / "tools/architecture/qualify.py"),
                       "--godot", str(engine), "--project", str(project), "--output", str(phase_output),
                       "--suite", "owner", "--graphical"]
        else:
            # --package names a different, source-built-only legacy schema.
            # The strict retained-package preflight above replaces only that
            # path/identity adapter; every actual Flatten case is unchanged.
            command = [sys.executable, str(candidate / "tools/ci/run_flatten_qualification.py"),
                       "--godot", str(engine), "--project", str(project),
                       "--evidence", str(phase_output), "--cases", "512x1"]
        result["process"] = run(command, candidate, output, final_sha)
        report = read(phase_output / "qualification.json")
        hashes = {"qualification.json": package.sha(phase_output / "qualification.json")}
        if args.mode in ("checkout-workbench", "package-workbench"):
            after = verify(workbench=phase_output)
            hashes.update(after["final_workbench"]["receipt_sha256"])
            hashes.update(process_binding(report["results"], phase_output, project, engine))
        elif args.mode == "owner":
            publisher.validate_architecture(report, final_sha, before["runtime"]["sha256"], owner=True)
            identity = read(phase_output / "source-runtime-identity.json")
            publisher.base.validate_source(identity, final_sha, before["runtime"]["sha256"],
                                           final_tree, before["input_ledgers"]["source_inputs"])
            scripts = {p.relative_to(project).as_posix(): package.sha(p) for p in project.rglob("*.gd")
                       if ".godot" not in p.relative_to(project).parts}
            package.require(identity["project_scripts_sha256"] == scripts, "Owner script identity mismatch")
            hashes["source-runtime-identity.json"] = package.sha(phase_output / "source-runtime-identity.json")
            hashes.update(process_binding(report["cases"], phase_output, project, engine))
            after = verify()
        else:
            publisher.base.validate_flatten(report)
            rows = read(phase_output / "results.json")
            publisher.validate_flatten_results(rows, before["runtime"]["sha256"], "windows",
                                               before["input_ledgers"]["build_inputs"])
            storage = phase_output / "storage-faults.json"
            package.require(package.sha(storage) == report["storage_faults"]["report_sha256"],
                            "Original Flatten storage-fault receipt changed")
            hashes.update(process_binding(rows, phase_output, project, gui, flatten=True))
            hashes.update({name: package.sha(phase_output / name) for name in ("results.json", "storage-faults.json")})
            result["flatten_identity_binding"] = {
                "scope": "Unmodified results carry actual script/runtime hashes, not a commit SHA; this receipt binds those bytes to verified final Git inputs and packaged paths.",
                "source_commit": final_sha, "source_tree": final_tree,
                "script_sha256": {name: before["input_ledgers"]["build_inputs"]["godot/" + name]
                                  for name in sorted(publisher.FLATTEN_SCRIPTS | {publisher.FLATTEN_OWNER_SCRIPT})}}
            after = verify()
        package.require(all(package.sha(Path(path)) == digest for path, digest in engine_hashes.items()),
                        "Godot engine changed during execution")
        if manifest:
            result["extracted_copy_postcheck"] = protected_after(directory, manifest)
            package.require(package.sha(directory / package.MANIFEST) == result["package_manifest_sha256"] and
                            package.sha(args.archive) == result["archive_sha256"] and
                            package.sha(args.assets_archive) == config["windows_asset_zip_sha256"],
                            "Original package/manifest/assets changed during execution")
        framebuffers = {path.relative_to(phase_output).as_posix(): package.sha(path)
                        for path in sorted(phase_output.rglob("*.png"))}
        package.require(bool(framebuffers) and all((phase_output / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
                                                  for name in framebuffers), "Actual framebuffer PNG evidence is absent")
        result.update(status="passed", after=after, engine_files_sha256=engine_hashes,
                      godot_version=version, original_execution_receipts_sha256=hashes,
                      framebuffer_png_sha256=framebuffers,
                      project=str(project), executed_source_commit=final_sha,
                      executed_source_tree=final_tree)
    except Exception as error:
        result.update(status="failed", error=str(error))
        raise
    finally:
        package.write_json(output / "admission.json", result)
        print(json.dumps({key: result.get(key) for key in ("status", "mode", "platform", "error")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
