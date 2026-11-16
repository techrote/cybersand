"""Authenticate one intentional refusal corpus without relaxing global errors."""
from __future__ import annotations

import hashlib
import importlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "test_render_upload_577_refusal.gd"
MARKER = "RENDER_UPLOAD_577_REFUSAL "

# The aggregate restores the native/Rapier artifacts, not the original editor.
# This executable digest is from the independently authenticated official ZIP
# pinned by third_party/godot-runtime.lock.json. Changing either release or
# archive must refuse retained admission until the new executable is qualified.
LINUX_GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
LINUX_GODOT_ARCHIVE = "Godot_v4.7-stable_linux.x86_64.zip"
LINUX_GODOT_ARCHIVE_SHA256 = "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c"
LINUX_GODOT_EXECUTABLE_SHA256 = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
LINUX_GODOT_SOURCE_HASH = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"


def _existing_verifier():
    # Reuse the dedicated graphical gate's fixed diagnostic list and corpus
    # validator. The temporary import path is restored even if import fails.
    previous = list(sys.path)
    try:
        sys.path.insert(0, str(ROOT / "tools/render_upload_577"))
        verifier = importlib.import_module("run_regressions")
    finally:
        sys.path[:] = previous
    if Path(verifier.__file__).resolve() != ROOT / "tools/render_upload_577/run_regressions.py":
        raise ValueError("Refusal verifier came from another source tree")
    return verifier


def _verified_receipt(output: str) -> dict:
    verifier = _existing_verifier()
    process_verifier = importlib.import_module("run_campaign")
    if Path(process_verifier.__file__).resolve() != ROOT / "tools/render_upload_577/run_campaign.py":
        raise ValueError("Process verifier came from another source tree")
    process_verifier.validate_process_errors(output, verifier.REFUSAL_ERRORS)
    errors = [line.strip() for line in output.splitlines() if "ERROR:" in line]
    if errors != list(verifier.REFUSAL_ERRORS):
        raise ValueError("Intentional refusal diagnostics are missing, reordered or unexpected")
    markers = [line for line in output.splitlines() if MARKER.rstrip() in line]
    if len(markers) != 1 or not markers[0].startswith(MARKER):
        raise ValueError("Expected exactly one canonical completed refusal receipt")
    data = json.loads(markers[0].removeprefix(MARKER))
    if not isinstance(data, dict) or data.get("ok") is not True or data.get("failures") != []:
        raise ValueError("Refusal fixture did not pass")
    verifier.verify_independent_result("main-refusal", SCRIPT, data)
    return data


def _verify_context(data: dict, engine: Path, engine_sha256: str, source: str) -> None:
    context = data.get("context", {})
    if (not isinstance(context, dict) or re.fullmatch(r"[0-9a-f]{40}", source) is None
            or context.get("source_revision") != source
            or context.get("display_server") not in {"X11", "Wayland", "Windows"}
            or context.get("backend") not in {"opengl3", "opengl3_angle"}
            or context.get("fixture") != "res://tests/" + SCRIPT
            or context.get("fixture_sha256") != hashlib.sha256((ROOT / "godot/tests" / SCRIPT).read_bytes()).hexdigest()
            or context.get("engine_sha256") != engine_sha256
            or Path(context.get("engine_path", "")).resolve() != engine):
        raise ValueError("Refusal receipt is not bound to this source, runtime and actual graphical execution")


def verify(output: str, godot: str, source: str) -> dict:
    data = _verified_receipt(output)
    engine = Path(shutil.which(godot) or godot).resolve()
    _verify_context(data, engine, hashlib.sha256(engine.read_bytes()).hexdigest(), source)
    return data


def verify_retained(output: str, receipt: dict, *, source: str,
                    engine_path: str, godot_version: str) -> dict:
    """Re-read the original corpus without trusting its runtime hash as authority.

    The aggregate verifies the original row, command, file paths and seals before
    calling this function. Only the pinned Linux editor can use this offline
    entry point; live verification still hashes the executable it actually ran.
    """
    data = _verified_receipt(output)
    if json.dumps(data, sort_keys=True, allow_nan=False) != json.dumps(receipt, sort_keys=True, allow_nan=False):
        raise ValueError("Retained refusal receipt differs from the original log")
    lock = json.loads((ROOT / "third_party/godot-runtime.lock.json").read_text(encoding="utf-8"))
    editor = lock.get("editor", {}) if isinstance(lock, dict) else None
    if (not isinstance(editor, dict) or godot_version != LINUX_GODOT_VERSION
            or lock.get("godot_version") != LINUX_GODOT_VERSION
            or lock.get("platform") != "linux" or lock.get("architecture") != "x86_64"
            or editor.get("filename") != LINUX_GODOT_ARCHIVE
            or editor.get("sha256") != LINUX_GODOT_ARCHIVE_SHA256):
        raise ValueError("Retained refusal editor does not match the independently pinned Linux release")
    if not isinstance(engine_path, str) or not engine_path:
        raise ValueError("Retained refusal command has no original editor path")
    original = PurePosixPath(engine_path)
    if (not original.is_absolute() or ".." in original.parts
            or original.name != LINUX_GODOT_ARCHIVE.removesuffix(".zip")):
        raise ValueError("Retained refusal command does not select the pinned Linux editor")
    _verify_context(data, Path(engine_path).resolve(), LINUX_GODOT_EXECUTABLE_SHA256, source)
    context = data["context"]
    version = context.get("godot", {})
    if (context.get("platform") != "Linux" or context.get("display_server") not in {"X11", "Wayland"}
            or context.get("backend") != "opengl3" or not isinstance(version, dict)
            or any(type(version.get(key)) is not type(value) or version.get(key) != value for key, value in {
                "major": 4, "minor": 7, "patch": 0, "status": "stable", "build": "official",
                "hash": LINUX_GODOT_SOURCE_HASH}.items())):
        raise ValueError("Retained refusal context is not the pinned actual Linux graphical execution")
    return data
