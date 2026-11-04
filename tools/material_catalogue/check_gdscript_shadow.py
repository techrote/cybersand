#!/usr/bin/env python3
"""Optional actual-Godot readback of a shadow, using an authenticated editor.

No downloads, project imports, native extension loads or World ticks. The
archive must match the repository pin and the executable must match its member.
Expected metadata is the independently compiled native oracle's snapshot.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import zipfile

import compatibility
from check_native_parity import _report_output, _write_report, compare, file_fact, read_json

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_VERSION = "4.7.stable.official.5b4e0cb0f"
RECEIPT_PATHS = {
    "tool_sources": (
        "tools/material_catalogue/native_oracle.cpp",
        "tools/material_catalogue/check_native_parity.py",
        "tools/material_catalogue/compatibility.py",
    ),
    "inputs": (
        "materials/catalogue/catalogue.json",
        "materials/catalogue/generated/catalogue.shadow.hpp",
        "materials/catalogue/generated/catalogue_shadow.gd",
        "materials/catalogue/generated/inspection.json",
        "materials/catalogue/compatibility-lock.json",
    ),
}
SCRIPT = '''extends SceneTree
const Candidate = preload("res://catalogue_shadow.gd")

func _initialize() -> void:
    var expected = JSON.parse_string(FileAccess.get_file_as_string("res://native.json"))
    var observed = JSON.parse_string(JSON.stringify(Candidate.NATIVE_FACTS))
    if expected == null or observed != expected:
        push_error("Complete shadow readback differs from compiled native snapshot")
        quit(1)
        return
    if Candidate.PRODUCTION_AUTHORITY or Candidate.BACKEND != "native" or Candidate.SCOPE != "current-shadow":
        push_error("Shadow metadata misrepresents its authority or backend")
        quit(1)
        return
    print("MAT353A_GDSCRIPT_PASS")
    quit(0)
'''


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_native_receipt(receipt: dict, protected: dict, root: Path = ROOT) -> None:
    if not isinstance(receipt, dict):
        raise ValueError("native receipt must be an object")
    compare("cybersand.material-catalogue.native-parity", receipt.get("schema_id"), "native receipt schema")
    compare(1, receipt.get("schema_version"), "native receipt version")
    compare("PASS", receipt.get("status"), "native receipt status")
    compare(compatibility.BASELINE, receipt.get("source_commit"), "native receipt baseline")
    compare(protected, receipt.get("protected_sources"), "native receipt protected sources")
    compare(True, receipt.get("native_authored_compiled_shadow_facts_equal"), "native receipt complete fact equality")
    for flag in ("world_executed", "physics_qualification", "production_cutover"):
        compare(False, receipt.get(flag), f"native receipt {flag}")
    for group, required in RECEIPT_PATHS.items():
        rows = receipt.get(group)
        if not isinstance(rows, list) or len(rows) != len(required):
            raise ValueError(f"native receipt {group}: expected complete {len(required)}-path custody inventory")
        paths = []
        for row in rows:
            if not isinstance(row, dict) or type(row.get("path")) is not str:
                raise ValueError(f"native receipt {group}: missing canonical source path")
            paths.append(row["path"])
        if len(set(paths)) != len(paths) or set(paths) != set(required):
            raise ValueError(f"native receipt {group}: missing, extra or duplicate custody path")
        for row in rows:
            path = (root / row["path"]).resolve()
            if not path.is_relative_to(root):
                raise ValueError("Godot shadow proof requires repository-bound native receipt inputs")
            compare(row, file_fact(path, root), f"native receipt {group}/{row['path']}")


def verify(godot: Path, archive: Path, snapshot: Path, native_report: Path) -> dict:
    tool_sha = digest(Path(__file__).read_bytes())
    protected = compatibility.check(ROOT)
    receipt_bytes = native_report.read_bytes()
    receipt = read_json(receipt_bytes.decode("utf-8"), str(native_report))
    validate_native_receipt(receipt, protected)
    pin = json.loads((ROOT / "third_party/godot-runtime.lock.json").read_text())["editor"]
    if archive.stat().st_size != pin["size"]:
        raise ValueError("editor archive size differs from repository pin")
    archive_bytes = archive.read_bytes()
    if digest(archive_bytes) != pin["sha256"]:
        raise ValueError("editor archive SHA-256 differs from repository pin")
    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as zipped:
        expected_name = pin["filename"].removesuffix(".zip")
        if zipped.namelist() != [expected_name]:
            raise ValueError("editor archive inventory differs from pinned single executable")
        binary_sha = digest(zipped.read(expected_name))
    if digest(godot.read_bytes()) != binary_sha:
        raise ValueError("editor executable differs from authenticated archive member")
    environment = {**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1"}
    version = subprocess.run([str(godot.resolve()), "--version"], check=True,
                             text=True, capture_output=True, env=environment, timeout=30)
    if version.stdout.strip() != EXPECTED_VERSION:
        raise ValueError(f"unexpected editor version {version.stdout.strip()!r}")
    native_bytes = snapshot.read_bytes()
    compare(receipt.get("snapshot_sha256"), digest(native_bytes), "compiled native snapshot SHA-256")
    native = json.loads(native_bytes)
    if set(native) != {"identity", "materials", "capabilities", "appearance", "interactions"}:
        raise ValueError("expected a complete native-oracle snapshot, not compiler inspection metadata")
    candidate = (ROOT / "materials/catalogue/generated/catalogue_shadow.gd").read_bytes()
    with tempfile.TemporaryDirectory(prefix="mat353-godot-readback-") as directory:
        project = Path(directory)
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="MAT353A metadata readback"\n')
        (project / "check.gd").write_text(SCRIPT, encoding="utf-8")
        (project / "native.json").write_bytes(native_bytes)
        (project / "catalogue_shadow.gd").write_bytes(candidate)
        started = time.perf_counter()
        result = subprocess.run([str(godot.resolve()), "--headless", "--path", directory,
                                 "--script", "res://check.gd"], cwd=directory,
                                text=True, capture_output=True, env=environment, timeout=60)
        seconds = time.perf_counter() - started
        if result.returncode or result.stdout.splitlines().count("MAT353A_GDSCRIPT_PASS") != 1:
            raise ValueError(f"Godot metadata readback failed ({result.returncode}):\n{result.stdout}\n{result.stderr}")
        if "SCRIPT ERROR" in result.stderr or "ERROR:" in result.stderr:
            raise ValueError(f"Godot emitted errors despite success marker: {result.stderr}")
    compare(protected, compatibility.check(ROOT), "post-Godot source custody")
    validate_native_receipt(receipt, protected)
    compare(digest(receipt_bytes), digest(native_report.read_bytes()), "post-Godot receipt custody")
    compare(digest(candidate), digest((ROOT / "materials/catalogue/generated/catalogue_shadow.gd").read_bytes()),
            "post-Godot candidate custody")
    compare(tool_sha, digest(Path(__file__).read_bytes()), "post-Godot checker custody")
    return {"status": "PASS", "godot_version": EXPECTED_VERSION,
            "checker_sha256": tool_sha,
            "editor_archive_sha256": pin["sha256"], "editor_executable_sha256": binary_sha,
            "candidate_gdscript_sha256": digest(candidate), "native_snapshot_sha256": digest(native_bytes),
            "native_parity_report_sha256": digest(receipt_bytes),
            "material_rows": len(native["materials"]), "capability_rows": len(native["capabilities"]),
            "readback_seconds": round(seconds, 6), "backend": "native-metadata-shadow",
            "production_project_loaded": False, "world_executed": False,
            "fallback_physics_qualified": False, "pixels_qualified": False}


def report_output(path: Path, inputs: tuple[Path, ...]) -> Path:
    """Protect every explicit editor/receipt input before and after readback."""
    try:
        destination = path.resolve()
        for source in inputs:
            source = source.resolve()
            if destination == source or (
                destination.exists() and source.exists() and destination.samefile(source)
            ):
                raise ValueError(f"report output must not overwrite an input: {source}")
    except RuntimeError as error:
        raise ValueError(f"report or input path cannot be resolved: {error}") from error
    # Reuse the native tool's repository/build fence and fixed-source guards.
    return _report_output(path, ROOT)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--native-snapshot", type=Path, required=True)
    parser.add_argument("--native-report", type=Path, required=True,
                        help="successful source-matched check_native_parity.py report")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        inputs = (args.godot, args.archive, args.native_snapshot, args.native_report)
        if args.output:
            report_output(args.output, inputs)
        report = verify(args.godot, args.archive, args.native_snapshot, args.native_report)
        rendered = json.dumps(report, sort_keys=True, indent=2) + "\n"
        if args.output:
            # Resolve the original output again: a file or parent alias may
            # have appeared during verification. The external inputs are not
            # known to the native writer, so retain this additional fence.
            _write_report(report_output(args.output, inputs), rendered, ROOT)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        print(f"GDScript shadow check: {error}", file=sys.stderr)
        return 1
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
