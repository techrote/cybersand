#!/usr/bin/env python3
"""Execute the complete current headless suite on Windows with the retained DLL."""

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time
import zipfile

import run_godot_regressions as runner

ROOT = runner.ROOT
PROVENANCE = "godot/addons/cybersand_native/runtime-provenance.json"
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
RAPIER_SHA256 = "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
GODOT_SHA512 = (
    "41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e"
    "6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9"
)
INPUT_SCOPES = (
    "godot", "native/include", "native/src", "tools/ci/run_godot_regressions.py",
    "tools/ci/run_windows_godot_regressions.py", "tools/ci/godot_timeout_diagnostics.py",
    "tools/ci/godot_process_monitor.py", "tools/ci/physical_progress_watchdog.py",
    ".github/workflows/gdextension.yml",
    "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
    "third_party/rapier-bvh-build.lock.json", "third_party/patches",
    "tools/ci/build_rapier_bvh_candidate.py", ".github/workflows/rapier-bvh-build.yml",
)
RAPIER_IMPORT_DESCRIPTORS = frozenset({
    "godot/addons/godot-rapier2d/Radial2D.svg.import",
    "godot/addons/godot-rapier2d/icons/Fluid2D.svg.import",
    "godot/addons/godot-rapier2d/icons/StateManager2D.svg.import",
    "godot/addons/godot-rapier2d/logo_square_2d.png.import",
})


def git(root: Path, *arguments: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *arguments], timeout=60)


def native_input_paths(root: Path) -> set[str]:
    suffixes = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
    return {
        path.relative_to(root).as_posix()
        for directory in ("native/include", "native/src", "godot/native_extension")
        for path in (root / directory).rglob("*")
        if path.is_file() and path.suffix in suffixes
    }


def verify_retained_runtime(root: Path, *, rapier_build: Path | None = None) -> dict:
    """Reject stale native inputs, unmaterialized LFS pointers and changed bytes."""
    manifest_bytes = (root / PROVENANCE).read_bytes()
    if manifest_bytes != git(root, "show", "HEAD:" + PROVENANCE):
        raise RuntimeError("Runtime provenance differs from the tested Git commit")
    manifest = json.loads(manifest_bytes)
    if manifest.get("schema_version") != 1 or manifest.get("artifact") != NATIVE:
        raise RuntimeError("Unexpected Windows runtime provenance schema or artifact")
    expected_paths = native_input_paths(root)
    if not expected_paths or set(manifest["source_inputs"]) != expected_paths:
        raise RuntimeError("Runtime provenance must cover every current native source/header exactly")
    for relative, expected in manifest["source_inputs"].items():
        data = (root / relative).read_bytes().replace(b"\r\n", b"\n")
        if hashlib.sha256(data).hexdigest() != expected:
            raise RuntimeError("Retained Windows runtime requires rebuild for source input: " + relative)

    candidate = None
    if rapier_build is not None:
        from rapier_candidate_identity import verify
        candidate = verify(root, rapier_build)
        if candidate["platform"] != "windows":
            raise RuntimeError("Expected a Windows Rapier candidate")
    else:
        from check_repository import verify_rapier_overrides
        rapier_lock = json.loads((root / "godot/third_party/rapier2d.lock.json").read_text(encoding="utf-8"))
        errors = verify_rapier_overrides(root, rapier_lock)
        if errors:
            raise RuntimeError("Selected Rapier runtime provenance failed: " + "; ".join(errors))
    identities = {}
    for relative in (NATIVE, RAPIER):
        pointer = git(root, "show", "HEAD:" + relative)
        match = re.fullmatch(
            rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n",
            pointer,
        )
        if match is None:
            raise RuntimeError("Runtime is not a canonical committed LFS pointer: " + relative)
        path = root / relative
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        expected_hash = candidate["artifacts"][path.name] if candidate and relative == RAPIER else match[1].decode()
        expected_size = len(data) if candidate and relative == RAPIER else int(match[2])
        if not data.startswith(b"MZ") or digest != expected_hash or len(data) != expected_size:
            raise RuntimeError("Materialized Windows runtime differs from committed LFS bytes: " + relative)
        identities[relative] = {"path": relative, "sha256": digest, "size": len(data)}
    if identities[NATIVE]["sha256"] != manifest["sha256"] or identities[NATIVE]["size"] != manifest["size"]:
        raise RuntimeError("Retained Windows DLL differs from its runtime provenance")
    if candidate is None and identities[RAPIER]["sha256"] != RAPIER_SHA256:
        raise RuntimeError("Windows Rapier differs from the pinned selected runtime")
    return {
        "runtime_source_commit": manifest["source_commit"],
        "runtime_build_commit": manifest["build_commit"],
        "runtime_provenance": {"path": PROVENANCE, "sha256": runner.sha256(root / PROVENANCE)},
        "native_source_inputs": manifest["source_inputs"],
        "cybersand_runtime": identities[NATIVE],
        "rapier_runtime": identities[RAPIER],
    }


def prepare_godot(archive: Path) -> tuple[Path, dict]:
    data = archive.read_bytes()
    digest = hashlib.sha512(data).hexdigest()
    if digest != GODOT_SHA512:
        raise RuntimeError("Official Windows Godot archive SHA-512 mismatch")
    directory = archive.with_suffix("")
    with zipfile.ZipFile(archive) as bundle:
        if bundle.testzip() is not None:
            raise RuntimeError("Official Windows Godot ZIP integrity failure")
        bundle.extractall(directory)
    # The pinned official console wrapper owns a non-inherited
    # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE job. Killing it at the shared runner's
    # per-case timeout therefore also terminates its engine process tree.
    binary = directory / "Godot_v4.7-stable_win64_console.exe"
    version = subprocess.check_output([str(binary), "--version"], text=True, timeout=30).strip()
    if version != GODOT_VERSION:
        raise RuntimeError("Windows Godot version mismatch: " + version)
    return binary, {
        "version": version, "archive_size": len(data), "archive_sha512": digest,
        "console_sha256": runner.sha256(binary),
        "runtime_sha256": runner.sha256(directory / "Godot_v4.7-stable_win64.exe"),
    }


def content_digest(root: Path, relative: str) -> str:
    data = (root / relative).read_bytes()
    # Godot re-saves these text descriptors with LF after a CRLF Windows
    # checkout. Every other input, including DLLs and images, stays byte-exact.
    if relative in RAPIER_IMPORT_DESCRIPTORS:
        data = data.replace(b"\r\n", b"\n")
    return hashlib.sha256(data).hexdigest()


def tested_inputs(root: Path) -> dict[str, str]:
    paths = git(root, "ls-files", "-z", "--", *INPUT_SCOPES).decode("utf-8").split("\0")
    # Import may regenerate the portable bootstrap cache; it is not source.
    return {
        relative: content_digest(root, relative)
        for relative in sorted(paths)
        if relative and not relative.startswith("godot/.godot/")
    }


def execute_cases(godot: str, output: Path, report: dict, cases: list[runner.Case]) -> None:
    selected = [case for case in cases if not case.requires_display]
    excluded = [case for case in cases if case.requires_display]
    if not selected or any(count != 1 for count in Counter(case.name for case in cases).values()):
        raise RuntimeError("Windows discovery must contain unique, applicable cases")
    report.update({
        "scope": "Actual Windows headless tests, profiles and scene startup; Linux shards own rendered pixel cases",
        "all_discovered_case_count": len(cases), "applicable_case_count": len(selected),
        "out_of_scope_graphical_cases": [case.name for case in excluded],
        "assigned_cases": [case.name for case in selected],
        "case_plan": [runner.case_dict(case) for case in selected],
    })

    def run(case: runner.Case, role: str) -> bool:
        record, failed = runner.run_case(godot, case, output, role)
        report["results"].append(record)
        report["log_sha256"][record["log"]] = runner.sha256(output / record["log"])
        report["executed_case_count"] = sum(item["role"] == "case" for item in report["results"])
        if failed:
            report["status"] = "failed"
        runner.write_json(output / "windows-execution.json", report)
        return failed

    runner.write_json(output / "windows-execution.json", report)
    if run(runner.Case("import", ("--editor", "--quit"), 240, 3.0), "preflight"):
        return
    # Always finish the applicable scope after a case fails, preserving each
    # original timeout and strict error/skip semantics from the shared runner.
    for case in selected:
        run(case, "case")
    actual = Counter(item["name"] for item in report["results"] if item["role"] == "case")
    if actual != Counter(case.name for case in selected):
        raise RuntimeError("Windows cases were not executed exactly once")
    report["completed"] = True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-archive", required=True, type=Path)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = {
        "status": "running", "completed": False, "results": [], "log_sha256": {},
        "executed_case_count": 0, "errors": [],
        "platform": platform.platform(), "python_version": platform.python_version(),
        "run_id": os.environ.get("GITHUB_RUN_ID"), "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
    }
    started = time.monotonic()
    try:
        if sys.platform != "win32":
            raise RuntimeError("This gate requires actual Windows execution")
        source = git(ROOT, "rev-parse", "HEAD").decode().strip()
        if source != args.expected_source_sha:
            raise RuntimeError("Windows checkout differs from the workflow's tested Git commit")
        report.update({"source_commit": source, "source_tree": git(ROOT, "rev-parse", "HEAD^{tree}").decode().strip()})
        report.update(verify_retained_runtime(ROOT))
        (output / "runtime-provenance.json").write_bytes((ROOT / PROVENANCE).read_bytes())
        git(ROOT, "diff", "--exit-code", "HEAD", "--", *INPUT_SCOPES, ":!godot/.godot")
        report["tested_inputs"] = tested_inputs(ROOT)
        godot, report["godot_identity"] = prepare_godot(args.godot_archive.resolve())
        report["godot_version"] = report["godot_identity"]["version"]
        os.environ["CYBERSAND_SOURCE_REVISION"] = source
        execute_cases(str(godot), output, report, runner.discover_cases())
        after = tested_inputs(ROOT)
        report["source_drift"] = sorted(
            relative for relative in report["tested_inputs"].keys() | after.keys()
            if report["tested_inputs"].get(relative) != after.get(relative)
        )
        if report["source_drift"]:
            raise RuntimeError("Tested source or runtime inputs changed during execution")
        if report["completed"] and all(item["status"] == "passed" for item in report["results"]):
            report["status"] = "passed"
        else:
            report["status"] = "failed"
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        report["status"] = "failed"
        report["errors"].append(str(error))
    report["seconds"] = round(time.monotonic() - started, 3)
    runner.write_json(output / "windows-execution.json", report)
    print("Windows execution:", report["status"], "executed", report["executed_case_count"],
          "/", report.get("applicable_case_count", 0), "applicable cases", flush=True)
    for error in report["errors"]:
        print("ERROR:", error, flush=True)
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
