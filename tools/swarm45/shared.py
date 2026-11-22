"""Reuse the donor's bounded process and evidence validators without retagging it."""
from __future__ import annotations

import importlib.util
from pathlib import Path

import runtime_custody as custody


def load(name: str, relative: str):
    spec = importlib.util.spec_from_file_location(name, custody.ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


legacy = load("swarm45_shared_graphical_validators", "tools/swarm005/qualify_workbench.py")


def ui_report_errors(report: dict, mode: str, example: str, source: str, cli_sha: str,
                     test_sha: str, platform: str) -> list[str]:
    # The immutable donor validator remains Windows-only. This new integration
    # applies the same source/receipt/plane assertions to its separately named
    # Linux gate, then enforces the actual requested OS and graphical display.
    errors = legacy.ui_report_errors(report, mode, example, source, cli_sha, test_sha)
    errors = [message for message in errors if message != "actual Windows graphical execution is required"]
    if report.get("platform") != {"windows": "Windows", "linux": "Linux"}[platform]:
        errors.append("UI report did not execute on the requested target OS")
    if report.get("display") in (None, "", "headless"):
        errors.append("UI report did not use an actual graphical display")
    return errors


def package_identity(directory: Path, receipt: dict) -> dict:
    manifest = legacy.read_report(directory / "candidate-manifest.json")
    custody.require(manifest.get("programme") == custody.PROGRAMME and manifest.get("draft_hold") is True,
                    "Package is not the mainline integration evaluator")
    custody.require(manifest.get("source_commit") == receipt["source_commit"]
                    and manifest.get("source_tree") == receipt["source_tree"], "Package source identity changed")
    custody.require(manifest.get("owner_visual_acceptance") == "pending", "Package must not claim owner acceptance")
    custody.verify_inventory(directory, manifest.get("files_sha256"))
    custody.require(legacy.read_report(directory / custody.NAME) == receipt, "Packaged runtime custody changed")
    return manifest


def verify_project(project: Path, receipt: dict) -> None:
    # Include scenes, settings, shaders, authoring inputs and tests, not just the
    # visible panel. Runtime paths are separately verified against built bytes.
    for name, digest in receipt["build_inputs_sha256"].items():
        if name.startswith("godot/"):
            candidate = project / Path(name).relative_to("godot")
            custody.require(custody.canonical(candidate) == digest, "Project input changed: " + name)
    extension = project / "addons/cybersand_native/bin" / receipt["extension"]
    custody.require(custody.sha(extension) == receipt["files"][receipt["extension"]]["sha256"],
                    "Project is not running the source-built adapter")


def verify_engine(engine: Path) -> str:
    import subprocess
    version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
    custody.require(version == legacy.VERSION, "Godot pin mismatch: " + version)
    return version
