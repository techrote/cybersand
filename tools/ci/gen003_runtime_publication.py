#!/usr/bin/env python3
"""Record, exercise and verify the scoped GEN-003 runtime publication bundles.

This helper never pushes. The branch-limited workflow owns the final exact-head,
four-path, fast-forward publication. Existing full acceptance gates stay separate.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zipfile

import run_godot_regressions as runner
import run_windows_godot_regressions as windows

ROOT = runner.ROOT
BRANCH = "feat/gen003-typed-spatial-fields"
EVIDENCE = "docs/audits/2026-10-20-gen003-typed-fields.md"
WORKFLOW = ".github/workflows/gen003-runtime-publication.yml"
GODOT_VERSION = windows.GODOT_VERSION
# Keep the exact official archive pin shared with gdextension.yml.
GODOT_LINUX_SHA256 = "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c"
RUNTIMES = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": windows.NATIVE,
}
MANIFESTS = {
    "linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
    "windows": windows.PROVENANCE,
}
RAPIER = {
    "linux": (
        "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so",
        "147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831",
    ),
    "windows": (windows.RAPIER, windows.RAPIER_SHA256),
}
CASE_MARKERS = {
    "test_worldgen_workbench": r"WORLDGEN_WORKBENCH: [1-9][0-9]* assertions; 0 failures",
    "test_worldgen_fields": r"WORLDGEN_FIELDS: [1-9][0-9]* assertions; 0 failures",
    "test_worldgen_typed": r"GEN-003 typed adapter and workbench: [1-9][0-9]* assertions; 0 failures",
    "test_render_world_generation": r"RENDER_WORLD_GENERATION: [1-9][0-9]* assertions, 0 failures",
}
BUILD_EXACT = {
    "Makefile", ".gitattributes", WORKFLOW, ".github/workflows/gdextension.yml",
    "tools/build_native_extension.sh", "tools/build_native_extension_windows.sh",
    "tools/build_pinned_godot_cpp.sh", "tools/requirements-build.txt",
    "tools/toolchains/g++", "tools/check_linux_runtime_floor.sh",
    "tools/verify_pinned_source_tree.py", "tools/ci/gen003_runtime_publication.py",
    "tools/ci/run_godot_regressions.py", "tools/ci/run_windows_godot_regressions.py",
    "third_party/native-toolchain.lock.json", "third_party/godot-runtime.lock.json",
    "godot/third_party/rapier2d.lock.json", "godot/project.godot",
    "godot/addons/cybersand_native/cybersand_native.gdextension",
    "godot/addons/godot-rapier2d/godot-rapier2d.gdextension",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def git(*arguments: str) -> bytes:
    return windows.git(ROOT, *arguments)


def context(source: str) -> dict:
    require(re.fullmatch(r"[0-9a-f]{40}", source) is not None, "Expected full source SHA")
    require(git("rev-parse", "HEAD").decode().strip() == source, "Checkout is not the built source SHA")
    require(os.environ.get("GITHUB_REPOSITORY") == "techrote/cybersand", "Unexpected repository")
    require(os.environ.get("GITHUB_REF") == "refs/heads/" + BRANCH, "Publisher is limited to the GEN-003 branch")
    require(os.environ.get("GITHUB_SHA") == source, "Workflow source differs from built source")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    attempt = os.environ.get("GITHUB_RUN_ATTEMPT", "")
    require(run_id.isdecimal() and attempt.isdecimal() and int(attempt) > 0, "Missing workflow identity")
    return {
        "source_commit": source,
        "source_tree": git("rev-parse", source + "^{tree}").decode().strip(),
        "build_commit": source,
        "workflow_run": "https://github.com/techrote/cybersand/actions/runs/" + run_id,
        "workflow_attempt": attempt,
    }


def input_ledgers(source: str) -> dict:
    """Hash Git blobs, and require the actual build/test files to match them."""
    native = windows.native_input_paths(ROOT)
    tracked_native = set()
    objects = {}
    for entry in git("ls-tree", "-rz", "--full-tree", source).split(b"\0"):
        if not entry:
            continue
        metadata, raw_path = entry.split(b"\t", 1)
        mode, kind, oid = metadata.split()
        path = raw_path.decode("utf-8")
        if path.startswith(("native/include/", "native/src/", "godot/native_extension/")) and Path(path).suffix in {
            ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp",
        }:
            tracked_native.add(path)
        build = path in BUILD_EXACT or path.startswith(("native/tests/", "examples/worldgen/")) or (
            path.startswith("godot/") and Path(path).suffix in {".gd", ".tscn", ".tres", ".gdshader"}
        )
        if path in native or build:
            require(kind == b"blob" and mode in (b"100644", b"100755"), "Non-file build input: " + path)
            objects[path] = oid
    require(native and native == tracked_native and native.issubset(objects), "Untracked or missing native input")
    require(BUILD_EXACT.issubset(objects), "Missing required build input")
    payload = subprocess.check_output(
        ["git", "-C", str(ROOT), "cat-file", "--batch"],
        input=b"".join(oid + b"\n" for oid in objects.values()), timeout=60,
    )
    hashes = {}
    offset = 0
    for path, oid in objects.items():
        end = payload.index(b"\n", offset)
        actual_oid, kind, raw_size = payload[offset:end].split()
        size = int(raw_size)
        data = payload[end + 1:end + 1 + size]
        require(actual_oid == oid and kind == b"blob" and len(data) == size, "Invalid Git blob response")
        offset = end + size + 2
        working = ROOT / path
        require(not working.is_symlink() and working.read_bytes().replace(b"\r\n", b"\n") == data,
                "Working build/test input differs from source commit: " + path)
        hashes[path] = hashlib.sha256(data).hexdigest()
    return {
        "source_inputs": {path: hashes[path] for path in sorted(native)},
        "build_inputs": {path: digest for path, digest in sorted(hashes.items()) if path not in native},
    }


def runtime_identity(path: Path, platform: str) -> dict:
    with path.open("rb") as handle:
        header = handle.read(64)
        require(len(header) == 64, "Runtime is missing or truncated")
        if platform == "linux":
            require(header[:6] == b"\x7fELF\x02\x01" and header[16:20] == b"\x03\x00\x3e\x00",
                    "Expected a Linux x86_64 ELF shared object")
        else:
            require(header[:2] == b"MZ", "Expected a materialized Windows DLL")
            handle.seek(struct.unpack_from("<I", header, 60)[0])
            pe = handle.read(26)
            require(len(pe) == 26 and pe[:6] == b"PE\0\0\x64\x86" and pe[24:26] == b"\x0b\x02"
                    and struct.unpack_from("<H", pe, 22)[0] & 0x2000, "Expected a Windows x86_64 PE32+ DLL")
    return {"artifact": RUNTIMES[platform], "sha256": runner.sha256(path), "size": path.stat().st_size}


def manifest_path(directory: Path, platform: str) -> Path:
    return directory / Path(MANIFESTS[platform]).name


def verify_bundle(directory: Path, platform: str, source: str, validated: bool) -> dict:
    manifest = json.loads(manifest_path(directory, platform).read_text(encoding="utf-8"))
    expected = context(source) | input_ledgers(source)
    expected.pop("workflow_attempt")
    expected.update(runtime_identity(directory / Path(RUNTIMES[platform]).name, platform))
    expected.update({"schema_version": 1, "platform": platform, "evidence": EVIDENCE})
    for key, value in expected.items():
        require(manifest.get(key) == value, "Runtime provenance mismatch: " + key)
    for key in ("workflow_attempt", "build_attempt"):
        value = manifest.get(key, "")
        require(isinstance(value, str) and value.isdecimal() and 0 < int(value) <= int(os.environ["GITHUB_RUN_ATTEMPT"]),
                "Unexpected provenance attempt: " + key)
    require(bool(manifest.get("toolchain")), "Missing build toolchain record")
    if not validated:
        require(manifest.get("status") == "built-not-executed", "Expected an unvalidated build bundle")
        return manifest
    require(manifest.get("status") == "validated-development-runtime", "Runtime execution did not pass")
    report_path = directory / "validation.json"
    require(runner.sha256(report_path) == manifest.get("validation_sha256"), "Execution report digest mismatch")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    require(report.get("status") == "passed" and report.get("completed") is True, "Incomplete execution evidence")
    require(report.get("source_commit") == source and report.get("platform") == platform
            and report.get("runtime") == {key: manifest[key] for key in ("artifact", "sha256", "size")},
            "Execution evidence does not identify the published runtime")
    require(report.get("godot", {}).get("version") == GODOT_VERSION, "Unpinned validation engine")
    archive_key = "archive_sha256" if platform == "linux" else "archive_sha512"
    archive_hash = GODOT_LINUX_SHA256 if platform == "linux" else windows.GODOT_SHA512
    require(report["godot"].get(archive_key) == archive_hash and report.get("rapier_sha256") == RAPIER[platform][1],
            "Unpinned validation engine archive or Rapier runtime")
    records = report.get("results", [])
    require([item.get("name") for item in records] == ["import", *CASE_MARKERS], "Incomplete focused case coverage")
    for record in records:
        name = record["name"]
        require(record.get("status") == "passed" and record.get("returncode") == 0
                and record.get("diagnostic_error") is False and record.get("launch_error") is None
                and record.get("skip_messages") == [], "Non-passing execution record: " + name)
        log_path = directory / (name + ".log")
        require(report.get("log_sha256", {}).get(log_path.name) == runner.sha256(log_path), "Execution log digest mismatch")
        if name in CASE_MARKERS:
            require(re.search(CASE_MARKERS[name], log_path.read_text(encoding="utf-8")) is not None,
                    "Missing successful assertion summary: " + name)
    return manifest


def record_build(args: argparse.Namespace) -> None:
    manifest = context(args.source_sha) | input_ledgers(args.source_sha)
    manifest.update(runtime_identity(args.runtime, args.platform))
    manifest.update({
        "schema_version": 1, "platform": args.platform, "status": "built-not-executed",
        "source_input_hash_kind": "SHA-256 of canonical Git blob bytes; CRLF working files normalize to LF",
        "build_attempt": manifest["workflow_attempt"], "evidence": EVIDENCE,
        "toolchain": args.toolchain.read_text(encoding="utf-8").strip(),
    })
    args.bundle.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.runtime, args.bundle / Path(RUNTIMES[args.platform]).name)
    runner.write_json(manifest_path(args.bundle, args.platform), manifest)


def execute(args: argparse.Namespace) -> None:
    require((args.platform == "windows" and sys.platform == "win32") or
            (args.platform == "linux" and sys.platform.startswith("linux")), "Actual target-OS execution is required")
    manifest = verify_bundle(args.bundle, args.platform, args.source_sha, validated=False)
    shutil.copyfile(args.bundle / Path(RUNTIMES[args.platform]).name, ROOT / RUNTIMES[args.platform])
    rapier_path, rapier_hash = RAPIER[args.platform]
    require(runner.sha256(ROOT / rapier_path) == rapier_hash, "Rapier runtime differs from its pin")
    if args.platform == "windows":
        godot, godot_identity = windows.prepare_godot(args.godot_archive)
    else:
        require(runner.sha256(args.godot_archive) == GODOT_LINUX_SHA256, "Linux Godot archive hash mismatch")
        directory = args.godot_archive.with_suffix("")
        with zipfile.ZipFile(args.godot_archive) as bundle:
            require(bundle.testzip() is None, "Linux Godot ZIP integrity failure")
            bundle.extractall(directory)
        godot = directory / "Godot_v4.7-stable_linux.x86_64"
        godot.chmod(0o755)
        version = subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip()
        require(version == GODOT_VERSION, "Linux Godot version mismatch")
        godot_identity = {"version": version, "archive_sha256": GODOT_LINUX_SHA256, "runtime_sha256": runner.sha256(godot)}
        subprocess.run(["bash", "tools/check_linux_runtime_floor.sh"], cwd=ROOT, check=True, timeout=60)
    discovered = {case.name: case for case in runner.discover_cases()}
    require(set(CASE_MARKERS).issubset(discovered), "Required focused regression is missing")
    cases = [runner.Case("import", ("--editor", "--quit"), 240, 3.0)] + [discovered[name] for name in CASE_MARKERS]
    require(not any(case.requires_display for case in cases), "Focused publisher requires headless cases")
    report = {
        "schema_version": 1, "source_commit": args.source_sha, "platform": args.platform,
        "runtime": runtime_identity(ROOT / RUNTIMES[args.platform], args.platform),
        "godot": godot_identity, "rapier_sha256": rapier_hash, "status": "running",
        "completed": False, "results": [], "log_sha256": {},
        "scope": "Import plus focused GEN-001/002/003 worldgen headless cases; full ready-PR CI is separate",
    }
    report_path = args.bundle / "validation.json"
    runner.write_json(report_path, report)
    for case in cases:
        result, failed = runner.run_case(str(godot), case, args.bundle, "preflight" if case.name == "import" else "case")
        log = args.bundle / (case.name + ".log")
        if case.name in CASE_MARKERS and re.search(CASE_MARKERS[case.name], log.read_text(encoding="utf-8")) is None:
            result["status"] = "failed"
            failed = True
        report["results"].append(result)
        report["log_sha256"][log.name] = runner.sha256(log)
        if failed:
            report["status"] = "failed"
        runner.write_json(report_path, report)
        if failed and case.name == "import":
            break
    require(report["status"] != "failed", "Focused runtime regression failed; no validated manifest was written")
    require(runtime_identity(ROOT / RUNTIMES[args.platform], args.platform) == report["runtime"], "Runtime changed during execution")
    require(input_ledgers(args.source_sha) == {key: manifest[key] for key in ("source_inputs", "build_inputs")},
            "Build/test inputs changed during execution")
    report.update({"completed": True, "status": "passed"})
    runner.write_json(report_path, report)
    manifest.update({
        "status": "validated-development-runtime", "workflow_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
        "validated_platform": args.platform.title() + " x86_64 Godot 4.7 (actual GitHub-hosted headless execution)",
        "acceptance": "This exact source-matched runtime passed import and all four focused legacy and typed worldgen cases, with no skips or errors. Full ready-for-review CI remains a separate required gate.",
        "validation_output": "gen003-runtime-" + args.platform + "-" + os.environ["GITHUB_RUN_ID"] + "/validation.json",
        "validation_sha256": runner.sha256(report_path),
        "other_platforms": "This publisher claims only its recorded target-OS headless scope. It does not establish graphical pixel, browser/WebAssembly, owner visual, target-PC or GPU acceptance.",
    })
    runner.write_json(manifest_path(args.bundle, args.platform), manifest)
    verify_bundle(args.bundle, args.platform, args.source_sha, validated=True)


def stage(args: argparse.Namespace) -> None:
    bundles = {"linux": args.linux_bundle, "windows": args.windows_bundle}
    manifests = {platform: verify_bundle(directory, platform, args.source_sha, validated=True)
                 for platform, directory in bundles.items()}
    for key in ("source_commit", "source_tree", "source_inputs", "build_inputs"):
        require(manifests["linux"][key] == manifests["windows"][key], "Linux and Windows inputs differ: " + key)
    for platform, directory in bundles.items():
        for path in (RUNTIMES[platform], MANIFESTS[platform]):
            shutil.copyfile(directory / Path(path).name, ROOT / path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("record", "test", "stage"):
        command = commands.add_parser(name)
        command.add_argument("--source-sha", required=True)
        if name != "stage":
            command.add_argument("--platform", choices=RUNTIMES, required=True)
            command.add_argument("--bundle", type=Path, required=True)
        if name == "record":
            command.add_argument("--runtime", type=Path, required=True)
            command.add_argument("--toolchain", type=Path, required=True)
        elif name == "test":
            command.add_argument("--godot-archive", type=Path, required=True)
        else:
            command.add_argument("--linux-bundle", type=Path, required=True)
            command.add_argument("--windows-bundle", type=Path, required=True)
    args = parser.parse_args()
    {"record": record_build, "test": execute, "stage": stage}[args.command](args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
