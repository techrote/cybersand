"""Authenticate one intentional refusal corpus without relaxing global errors."""
from __future__ import annotations

import hashlib
import importlib
import json
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "test_render_upload_577_refusal.gd"
MARKER = "RENDER_UPLOAD_577_REFUSAL "


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


def verify(output: str, godot: str, source: str) -> dict:
    verifier = _existing_verifier()
    process_verifier = importlib.import_module("run_campaign")
    if Path(process_verifier.__file__).resolve() != ROOT / "tools/render_upload_577/run_campaign.py":
        raise ValueError("Process verifier came from another source tree")
    process_verifier.validate_process_errors(output, verifier.REFUSAL_ERRORS)
    errors = [line.strip() for line in output.splitlines() if "ERROR:" in line]
    if errors != list(verifier.REFUSAL_ERRORS):
        raise ValueError("Intentional refusal diagnostics are missing, reordered or unexpected")
    records = [line.removeprefix(MARKER) for line in output.splitlines() if line.startswith(MARKER)]
    if len(records) != 1:
        raise ValueError("Expected exactly one completed refusal receipt")
    data = json.loads(records[0])
    if not isinstance(data, dict) or data.get("ok") is not True or data.get("failures") != []:
        raise ValueError("Refusal fixture did not pass")
    verifier.verify_independent_result("main-refusal", SCRIPT, data)
    engine = Path(shutil.which(godot) or godot).resolve()
    context = data.get("context", {})
    if (not isinstance(context, dict) or re.fullmatch(r"[0-9a-f]{40}", source) is None
            or context.get("source_revision") != source
            or context.get("display_server") not in {"X11", "Wayland", "Windows"}
            or context.get("backend") not in {"opengl3", "opengl3_angle"}
            or context.get("fixture") != "res://tests/" + SCRIPT
            or context.get("fixture_sha256") != hashlib.sha256((ROOT / "godot/tests" / SCRIPT).read_bytes()).hexdigest()
            or context.get("engine_sha256") != hashlib.sha256(engine.read_bytes()).hexdigest()
            or Path(context.get("engine_path", "")).resolve() != engine):
        raise ValueError("Refusal receipt is not bound to this source, runtime and actual graphical execution")
    return data
