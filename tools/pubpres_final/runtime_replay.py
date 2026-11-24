#!/usr/bin/env python3
"""Read-only native artifact custody on an explicitly recorded target platform.

The frozen runtime admission function is unchanged. This separate offline
reader derives its exact body with only the three host-platform selections
replaced by an explicit recorded target, plus its function signature and error
label. It never loads a library or supplies execution/qualification credit.
"""
from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_playability"))
import run_campaign as frozen

FROZEN_FILE = ROOT / "tools/pubpres_playability/run_campaign.py"
FROZEN_FILE_SHA256 = "8cc11d567101c518d13776781aa0e644546b6c69b1535e9669a103fdf05dfd84"
FROZEN_FUNCTION_SHA256 = "d3105e0376bdff5929625c55a7dcbe6962f4d6cf3e38326807baff411357ca69"


def derive(raw: bytes) -> str:
    if hashlib.sha256(raw).hexdigest() != FROZEN_FILE_SHA256:
        raise ValueError("Frozen native runtime admission file differs")
    text = raw.decode("utf-8")
    matches = [node for node in ast.parse(text).body
               if isinstance(node, ast.FunctionDef) and node.name == "verify_experimental_runtime"]
    if len(matches) != 1:
        raise ValueError("Frozen native runtime admission function is not unique")
    original = ast.get_source_segment(text, matches[0])
    if hashlib.sha256(original.encode()).hexdigest() != FROZEN_FUNCTION_SHA256:
        raise ValueError("Frozen native runtime admission body differs")
    edits = {
        "def verify_experimental_runtime(root, source, folder):":
            (1, "def verify_recorded_runtime(root, source, folder, *, target_platform):"),
        'os.name == "nt"': (3, 'target_platform == "windows"'),
        "Native build platform differs from executing host":
            (1, "Native build platform differs from explicitly recorded target"),
    }
    for old, (count, new) in edits.items():
        if original.count(old) != count:
            raise ValueError("Offline target-platform derivation drifted: " + old)
        original = original.replace(old, new)
    return original + "\n"


def identity() -> dict:
    derived = derive(FROZEN_FILE.read_bytes())
    return {
        "frozen_file_sha256": FROZEN_FILE_SHA256,
        "frozen_function_sha256": FROZEN_FUNCTION_SHA256,
        "derived_function_sha256": hashlib.sha256(derived.encode()).hexdigest(),
        "changes": "Explicit recorded target replaces exactly three execution-host platform selections; signature and error label identify offline replay. Every source/tree, native closure, binary, build log, toolchain and dependency predicate is retained.",
        "scope": "Read-only artifact custody. No binary execution, runtime admission on this host, historical workflow rewrite or new gameplay qualification.",
    }


def verify_recorded_runtime(root: Path, source: dict, folder: Path, *, target_platform: str) -> dict:
    if target_platform not in ("linux", "windows"):
        raise ValueError("Explicit recorded Linux or Windows target required")
    if Path(frozen.__file__).resolve() != FROZEN_FILE:
        raise ValueError("Frozen runtime module came from another path")
    derived = derive(FROZEN_FILE.read_bytes())
    namespace = dict(vars(frozen))
    # Only exact, SHA-pinned repository source is compiled here. The platform
    # remains an ordinary validated function argument, never interpolated code.
    exec(compile(derived, str(Path(__file__)) + ":recorded-platform", "exec"), namespace)
    return namespace["verify_recorded_runtime"](root, source, folder, target_platform=target_platform)
