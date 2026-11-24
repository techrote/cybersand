#!/usr/bin/env python3
"""Attach this source's completed native architecture outputs to its evaluator.

This supplements the existing exact-source package manifest; it does not build a
runtime, alter a receipt, or turn imported evidence into live native authority.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

from verify_collaborative_evidence import verify as verify_collaborative


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bundle(evidence: Path, package: Path, require_collaborative: bool = False) -> dict:
    evidence, package = evidence.resolve(), package.resolve()
    report_path = evidence / "qualification.json"
    manifest_path = package / "candidate-manifest.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if (report.get("status") != "passed" or not report.get("architecture_m3_m5")
            or report.get("development_dirty_allowed") or report.get("actual_model_calls") != 0
            or report.get("platform") != "win32" or not report.get("graphical")):
        raise ValueError("Only completed clean Windows graphical architecture qualification can supply evaluator evidence")
    if report.get("source_commit") != manifest.get("source_commit"):
        raise ValueError("Architecture evidence and evaluator source commits differ")
    if not report.get("results") or any(row.get("status") != "passed" for row in report["results"]):
        raise ValueError("Qualification has missing or failed process results")
    native_name = "addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
    if report.get("source_files_sha256", {}).get(native_name) != manifest.get("native_sha256"):
        raise ValueError("Architecture evidence and evaluator native runtime differ")
    collaborative = bool(report.get("collaborative_m6_m7"))
    if require_collaborative and not collaborative:
        raise ValueError("This evaluator requires the completed M6/M7 campaign")
    collaborative_custody = {}
    if collaborative:
        reference = report.get("collaborative_evidence", {})
        if (reference.get("path") != "architecture/collaborative/custody.json"
                or reference.get("native_active_core_capacity") != 1024 or reference.get("cropped_route_worlds") is not False):
            raise ValueError("Incomplete default-runtime collaborative qualification reference")
        custody_path = evidence / reference["path"]
        if not custody_path.is_file() or sha(custody_path) != reference.get("sha256"):
            raise ValueError("Collaborative custody report changed")
        retained = json.loads(custody_path.read_bytes())
        recomputed = verify_collaborative(evidence / "architecture/collaborative",
                                         report["source_commit"], manifest["native_sha256"])
        if retained != recomputed:
            raise ValueError("Collaborative reports/captures no longer match their completed custody gate")
        engine_name = "Godot_v4.7-stable_win64_console.exe"
        if report.get("godot_executable_sha256") != manifest.get("files_sha256", {}).get(engine_name):
            raise ValueError("Delivered Godot executable differs from the qualified engine")
        collaborative_custody = {"sha256": reference["sha256"], "counts": retained["counts"],
                                  "native_active_core_capacity": 1024, "cropped_route_worlds": False}
    # Verify every original payload file before extending its manifest. Never
    # adopt an altered executable or source file into a newly computed checksum.
    for name, expected in manifest["files_sha256"].items():
        target = package / name
        if not target.resolve().is_relative_to(package) or not target.is_file() or sha(target) != expected:
            raise ValueError("Existing evaluator file changed: " + name)
    source = evidence / "architecture"
    destination = package / "architecture-evidence"
    if not source.is_dir() or destination.exists():
        raise ValueError("Expected a fresh evaluator and completed architecture output directory")
    files = sorted(path for path in source.rglob("*") if path.is_file())
    if not files or len(files) > 4096 or sum(path.stat().st_size for path in files) > 256 * 1024 * 1024:
        raise ValueError("Architecture evidence exceeds its bounded payload envelope or is empty")
    if any(path.is_symlink() or not path.resolve().is_relative_to(source) for path in files):
        raise ValueError("Architecture evidence may not link outside its source directory")
    copied = {}
    for path in files:
        target = destination / path.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        copied[target.relative_to(package).as_posix()] = sha(target)
    provenance = {
        "schema": "cybersand.architecture-evaluator-evidence.v1",
        "source_commit": report["source_commit"], "native_sha256": manifest["native_sha256"],
        "qualification_sha256": sha(report_path), "platform": "win32", "graphical": True,
        "physical_owner_acceptance": "pending", "actual_model_calls": 0,
        "collaborative_m6_m7": collaborative, "collaborative_custody": collaborative_custody,
        "scope": "Retained completed native outputs and source-bound rendered evidence. Imported modules and receipts are historical until fresh native observation.",
        "files_sha256": copied,
    }
    target = destination / "evidence-provenance.json"
    target.write_text(json.dumps(provenance, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    copied[target.relative_to(package).as_posix()] = sha(target)
    target = destination / "source-qualification.json"
    shutil.copyfile(report_path, target)
    copied[target.relative_to(package).as_posix()] = sha(target)
    manifest["files_sha256"].update(copied)
    manifest["architecture_evidence"] = {
        "source_commit": report["source_commit"], "qualification_sha256": sha(report_path),
        "files": len(copied), "directory": "architecture-evidence",
        "collaborative_m6_m7": collaborative, "collaborative_custody": collaborative_custody,
        "scope": "Generated evidence supplements committed source; no native qualification is inferred from import.",
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest["architecture_evidence"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--collaborative", action="store_true", help="Require exact completed M6/M7 evidence before packaging")
    args = parser.parse_args()
    print(json.dumps(bundle(args.evidence, args.package, args.collaborative), indent=2))


if __name__ == "__main__":
    main()
