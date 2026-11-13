#!/usr/bin/env python3
"""Independent bounded POSIX Stop/child-lifetime diagnostic for WB-ART-SLM.

Loads the actual bridge from the combined checkout. Uses no model or native Art.
Detects whether a SIGTERM-resistant descendant continues AFTER cancellation.
Always kills the test process group, and records source/probe provenance.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


def git_blob_sha(path: Path) -> str:
    content = path.read_bytes()
    return hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest()


def load_bridge(path: Path):
    spec = importlib.util.spec_from_file_location("wb_art_slm_bridge_stop_probe", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import bridge under evaluation")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _wait_for(path: Path, seconds: float) -> bool:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if path.exists():
            return True
        time.sleep(.02)
    return path.exists()


def probe(module, *, late_seconds: float = 0.85) -> dict:
    if os.name == "nt":
        raise RuntimeError("POSIX-only process-group diagnostic; Windows remains unqualified")
    with tempfile.TemporaryDirectory(prefix="slm-stop-desc-") as temp:
        root = Path(temp)
        ready, pgid_path, late = root / "child-ready", root / "pgid", root / "late-write"
        # Child ignores TERM AFTER signaling readiness. Parent does not. The
        # durable marker prevents cancellation before the handler is installed.
        grandchild = ("import os,pathlib,signal,sys,time;"
                      "signal.signal(signal.SIGTERM,signal.SIG_IGN);"
                      "pathlib.Path(sys.argv[1]).write_text('ready');"
                      "time.sleep(float(sys.argv[3]));"
                      "pathlib.Path(sys.argv[2]).write_text('late')")
        parent = ("import os,pathlib,subprocess,sys,time;"
                  "p=subprocess.Popen([sys.executable,'-c',sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]]);"
                  "pathlib.Path(sys.argv[5]).write_text(str(os.getpgrp()));"
                  "time.sleep(10)")
        cmd = [sys.executable, "-c", parent, grandchild, str(ready), str(late),
               str(late_seconds), str(pgid_path)]
        outcome = "none"
        pgid = None
        try:
            with (root / "child.log").open("wb") as log:
                try:
                    # Actual bridge owns the new session and cancellation.
                    module._run_owned_inference(
                        cmd, log, deadline_seconds=6.0,
                        cancellation_probe=lambda: ready.exists() and pgid_path.exists())
                    outcome = "unexpected-success"
                except module.BridgeRefusal as exc:
                    outcome = str(exc)
            if pgid_path.exists():
                pgid = int(pgid_path.read_text())
            ready_seen = ready.exists()
            # This is a synthetic file side effect, NOT an Art batch/native write.
            _wait_for(late, late_seconds + .6)
            late_seen = late.exists()
        finally:
            if pgid is None and pgid_path.exists():
                try:
                    pgid = int(pgid_path.read_text())
                except ValueError:
                    pass
            if pgid is not None and pgid != os.getpgrp():
                try:
                    os.killpg(pgid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        return {"ready_seen": ready_seen, "cancel_refusal": "canceled" in outcome,
                "late_descendant_write": late_seen,
                "stop_descendant_invariant_passed": ready_seen and "canceled" in outcome and not late_seen,
                "outcome": outcome,
                "scope": "POSIX synthetic SIGTERM-ignoring inference descendant; no model/native World"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    default = Path(__file__).resolve().parents[1] / "integration" / "local_art_bridge.py"
    parser.add_argument("--bridge", type=Path, default=default)
    parser.add_argument("--expected-git-blob", default="", help="optional exact source Git blob SHA-1")
    parser.add_argument("--out", type=Path, help="write a new JSON evidence file; never overwrite")
    args = parser.parse_args(argv)
    if not args.bridge.is_file():
        parser.error(f"bridge not found: {args.bridge}")
    source_blob = git_blob_sha(args.bridge)
    if args.expected_git_blob and args.expected_git_blob != source_blob:
        parser.error("bridge source identity changed; refusing stale probe result")
    result = {"bridge_file": str(args.bridge), "bridge_git_blob": source_blob,
              "bridge_sha256": hashlib.sha256(args.bridge.read_bytes()).hexdigest(),
              "probe_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              **probe(load_bridge(args.bridge))}
    data = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.out:
        if args.out.exists():
            parser.error("will not overwrite previous evidence")
        args.out.write_text(data, encoding="utf-8")
    print(data, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
