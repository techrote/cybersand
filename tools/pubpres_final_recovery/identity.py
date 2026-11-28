"""Additive source custody for recovery apparatus; frozen readers stay exact."""
from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/pubpres_final"))
from run_comparison import driver_identity as original_driver_identity
from results import need


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def driver_identity():
    result = original_driver_identity()
    scopes = ("tools/pubpres_final_recovery", "tools/pubpres_recovery_engine", "tools/pubpres_final_frame_budget", "tools/pubpres_recovery_windows")
    names = subprocess.check_output(["git", "-C", str(ROOT), "ls-tree", "-r", "--name-only",
                                     "HEAD", "--", *scopes], text=True).splitlines()
    observed = {path.relative_to(ROOT).as_posix() for scope in scopes for path in (ROOT / scope).rglob("*")
                if path.is_file() and "__pycache__" not in path.parts}
    need(observed == set(names) and names, "Recovery/engine driver has uncommitted or missing inputs")
    for name in names:
        raw = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + name])
        need((ROOT / name).read_bytes() == raw, "Recovery/engine driver differs from committed bytes: " + name)
        result["files_sha256"][name] = hashlib.sha256(raw).hexdigest()
    return result
