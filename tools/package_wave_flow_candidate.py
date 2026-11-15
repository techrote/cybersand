#!/usr/bin/env python3
"""Assemble and independently execute the source-matched Wave Flow Windows ZIP.

The existing desktop packager owns engine, native, LFS and VC runtime custody.
This adapter supplies the Wave Flow launcher and a complete payload manifest.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/ci"))
import wave_mt_runtime_publication as publication


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files(root: Path) -> dict[str, str]:
    return {path.relative_to(root).as_posix(): sha(path)
            for path in sorted(root.rglob("*"))
            if path.is_file() and path != root / "candidate-manifest.json"}


def build(args) -> None:
    command = [sys.executable, str(ROOT / "tools/package_explore001_candidate.py"),
               "--engine", str(args.engine), "--engine-notices", str(args.engine_notices),
               "--native-candidate", str(args.native_candidate),
               "--vc-runtime", str(args.vc_runtime), "--output", str(args.output),
               "--readme", "docs/operations/wave-flow-evaluation.md"]
    subprocess.run(command, cwd=ROOT, check=True, timeout=600)
    path = args.output / "candidate-manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    console = args.engine.with_name(args.engine.stem + "_console.exe").name
    launcher = (
        '@echo off\ncd /d "%~dp0"\n'
        f'set "CYBERSAND_SOURCE_REVISION={manifest["source_commit"]}"\n'
        f'"%~dp0{console}" --headless --path "%~dp0godot" --editor --quit\n'
        'if errorlevel 1 (\n'
        '  if not "%~1"=="--headless" pause\n'
        '  exit /b 1\n)\n'
        f'"%~dp0{console}" --path "%~dp0godot" %* -- --wave-flow\n'
        'set "wave_exit=%errorlevel%"\n'
        'if not "%wave_exit%"=="0" if not "%~1"=="--headless" pause\n'
        'exit /b %wave_exit%\n'
    )
    (args.output / "Test It.cmd").write_text(launcher, encoding="utf-8", newline="\r\n")
    manifest.update(purpose="Experimental Wave Flow Windows evaluation; merge requires owner approval",
                    launcher="Test It.cmd", files_sha256=files(args.output))
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(path)


def verify(package: Path) -> dict:
    path = package / "candidate-manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    publication.engine.require(manifest.get("launcher") == "Test It.cmd",
                               "Wrong evaluation launcher")
    publication.engine.require(manifest.get("files_sha256") == files(package),
                               "Extracted evaluation payload differs from its SHA-256 manifest")
    publication.engine.require(sha(package / publication.engine.RUNTIMES["windows"])
                               == manifest.get("native_sha256"), "Evaluation native runtime changed")
    return manifest


def verify_original_payload(package: Path, manifest: dict, manifest_sha256: str) -> None:
    publication.engine.require(sha(package / "candidate-manifest.json") == manifest_sha256,
                               "Package manifest changed during qualification")
    # Import creates new .godot cache/UID files. Recheck every original payload
    # byte without admitting those generated files as trusted delivered inputs.
    for name, digest in manifest["files_sha256"].items():
        publication.engine.require(sha(package / name) == digest,
                                   "Packaged input changed during execution: " + name)


def qualify(args) -> None:
    publication.engine.require(sys.platform == "win32", "Windows package must execute on Windows")
    package, output = args.package.resolve(), args.output.resolve()
    manifest = verify(package)
    expected = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    publication.engine.require(manifest.get("source_commit") == expected,
                               "Evaluation source differs from qualification checkout")
    output.mkdir(parents=True, exist_ok=False)
    godot = package / "Godot_v4.7-stable_win64_console.exe"
    runner = publication.engine.runner
    runner.ROOT = package
    ordinary_command = runner.case_command

    def package_command(binary, case, platform=sys.platform):
        if case.name == "launcher":
            # The shared runner retains process-tree cleanup, telemetry and the
            # full watchdog. Its cwd is the extracted package, so CMD exercises
            # the delivered launcher including its own import and error path.
            return ["cmd.exe", "/d", "/c", "call", "Test It.cmd",
                    "--headless", "--quit-after", "120"]
        return ordinary_command(binary, case, platform)

    runner.case_command = package_command
    policy = runner.execution_policy
    cases = [
        runner.Case("import", ("--editor", "--quit"), policy.watchdog_seconds("godot_import_seconds"), 3),
        runner.Case("test_wave_flow", ("--script", "res://tests/test_wave_flow.gd"),
                    policy.watchdog_seconds("complex_fixture_seconds"), 60),
        runner.Case("launcher", (),
                    policy.watchdog_seconds("ordinary_case_seconds"), 10),
    ]
    report = {"schema": "wave-flow-windows-package-execution-v1", "source_commit": expected,
              "native_sha256": manifest["native_sha256"], "manifest_sha256": sha(package / "candidate-manifest.json"),
              "status": "running", "cases": []}
    for case in cases:
        result, failed = runner.run_case(str(godot), case, output,
                                         "preflight" if case.name == "import" else "case")
        report["cases"].append(result)
        (output / "qualification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        publication.engine.require(not failed and result.get("skip_messages") == [],
                                   "Extracted evaluation execution failed: " + case.name)
        if case.name == "test_wave_flow":
            publication.verify_wave_summary((output / "test_wave_flow.log").read_text(encoding="utf-8"))
        if case.name == "launcher":
            publication.engine.require("WAVE_FLOW_EVALUATION_READY" in (output / "launcher.log").read_text(encoding="utf-8"),
                                       "Launcher did not construct the Wave Flow evaluation")
    report["status"] = "passed"
    verify_original_payload(package, manifest, report["manifest_sha256"])
    report["payload_unchanged"] = True
    report["log_sha256"] = {path.name: sha(path) for path in output.glob("*.log")}
    (output / "qualification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("build")
    for name in ("engine", "engine-notices", "native-candidate", "vc-runtime", "output"):
        create.add_argument("--" + name, type=Path, required=True)
    check = commands.add_parser("qualify")
    check.add_argument("--package", type=Path, required=True)
    check.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    {"build": build, "qualify": qualify}[args.command](args)


if __name__ == "__main__":
    main()
