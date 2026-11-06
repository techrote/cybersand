#!/usr/bin/env python3
"""Real-process R1-D archival and namespace-identity adversary.

The Linux namespace-mismatch fixture is an executable fail-closed control, NOT
proof of actual hidepid/PID namespace confinement on a hosted runner.
All processes invoke genuine graphical Godot. Historical tests are untouched.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def wait_marker(proc: subprocess.Popen, log: Path, marker: str, seconds: int = 100) -> bool:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if marker in (log.read_text(errors="replace") if log.exists() else ""):
            return proc.poll() is None
        if proc.poll() is not None:
            return False
        time.sleep(.1)
    return False


def stop(proc):
    if proc is not None and proc.poll() is None:
        proc.kill()
        proc.wait(timeout=15)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", type=Path, required=True)
    ap.add_argument("--platform", choices=["linux", "windows"], required=True)
    ap.add_argument("--evidence", type=Path, required=True)
    a = ap.parse_args()
    e = a.evidence.resolve()
    e.mkdir(parents=True, exist_ok=True)
    (e / "logs").mkdir(exist_ok=True)
    fixture = e.parent / "fixtures" / "r1d-pack.json"
    fixture.parent.mkdir(parents=True, exist_ok=True)
    fixture.write_text(json.dumps({
        "schema_id": "cybersand.world-feature-pack.proposal",
        "schema_version": 1,
        "features": [{"id": "witness", "size": [16, 16],
                      "rectangles": [[0, 0, 16, 16, 43]], "variants": []}],
        "scene": {"size": [48, 32], "rectangles": [[0, 28, 48, 4, 40]],
                  "placements": [{"feature": "witness", "x": 5, "y": 6, "variant": None}]}
    }), encoding="utf-8")
    env = os.environ.copy()
    env["CYBERSAND_CAPTURE_FAULT_INJECTION"] = "1"
    env["CYBERSAND_SOURCE_REVISION"] = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], text=True).strip()
    if a.platform == "linux":
        env.update(LIBGL_ALWAYS_SOFTWARE="1", GALLIUM_DRIVER="llvmpipe",
                   LP_NUM_THREADS="2", GALLIVM_PERF="nopt")
    driver = "opengl3_angle" if a.platform == "windows" else "opengl3"
    engine = [str(a.godot.resolve()), "--verbose", "--rendering-method",
              "gl_compatibility", "--rendering-driver", driver,
              "--path", "godot", "--script",
              "res://tools/capture_world_design_pack.gd", "--"]
    checks, processes = [], []

    def check(name, ok, detail=None):
        checks.append({"name": name, "pass": bool(ok), "detail": detail})

    def args_for(out, *extra):
        return engine + ["--pack=" + str(fixture), "--output=" + str(out),
                         "--mode=combined", "--scale=1", "--time=1.37",
                         "--glow=on", "--require-verified-source=on", *extra]

    def spawn(label, out, *extra):
        cmd = args_for(out, *extra)
        log = e / "logs" / (label + ".log")
        stream = log.open("wb")
        proc = subprocess.Popen(cmd, stdout=stream, stderr=subprocess.STDOUT, env=env)
        processes.append({"name": label, "command": cmd, "log": str(log),
                          "pid": proc.pid})
        return proc, stream, log

    def run(label, out, *extra, timeout=150):
        cmd = args_for(out, *extra)
        log = e / "logs" / (label + ".log")
        try:
            with log.open("wb") as stream:
                rc = subprocess.run(cmd, stdout=stream, stderr=subprocess.STDOUT,
                                    env=env, timeout=timeout, check=False).returncode
        except subprocess.TimeoutExpired:
            rc = 124
        processes.append({"name": label, "command": cmd,
                          "log": str(log), "exit": rc})
        return rc

    def dead_owner(label, out):
        p, stream, log = spawn(label, out, "--test-pause-before-publication-ms=30000",
                                "--test-pause-phase=prepared")
        try:
            ready = wait_marker(p, log, "test pause phase=prepared")
            check(label + "-prepared", ready)
            txpath = Path(str(out) + ".world-capture-claim") / "transaction.json"
            tx = json.loads(txpath.read_text()) if txpath.exists() else {}
            check(label + "-schema3", tx.get("schema") == 3, tx)
            token = str(tx.get("attempt_id", ""))
            return token, txpath, tx
        finally:
            stop(p)
            stream.close()

    def sentinel(path):
        path.mkdir(parents=True, exist_ok=False)
        needle = path / "unrelated-sentinel.bin"
        needle.write_bytes(b"unrelated-object-no-clobber\x00\xff")
        return sha(needle), needle

    # Two recoverers attempt the SAME valid stale token concurrently. Only
    # one can reserve the archive and later acquire the fixed claim.
    out = e / "two-recoverers"
    token, txpath, _ = dead_owner("concurrent-dead-owner", out)
    if token:
        p1, f1, l1 = spawn("recoverer-one", out, "--recover-claim=" + token,
                           "--test-pause-before-archive-ms=1500",
                           "--test-pause-archive-phase=recovery")
        p2, f2, l2 = spawn("recoverer-two", out, "--recover-claim=" + token,
                           "--test-pause-before-archive-ms=1500",
                           "--test-pause-archive-phase=recovery")
        try:
            rc1 = p1.wait(timeout=160)
            rc2 = p2.wait(timeout=160)
            check("two-recoverers-at-most-one-success",
                  sorted([rc1 == 0, rc2 == 0]) == [False, True],
                  [rc1, rc2])
            archive = Path(str(out) + ".world-capture-recovered-" + token)
            check("two-recoverers-original-archive-intact",
                  (archive / "claim" / "transaction.json").is_file())
            manifest = out / "capture-manifest.json"
            check("two-recoverers-one-authoritative-commit",
                  manifest.is_file() and json.loads(manifest.read_text()).get("success") is True)
        except subprocess.TimeoutExpired:
            check("two-recoverers-completed", False)
        finally:
            stop(p1); stop(p2)
            f1.close(); f2.close()

    # Recovery collision inserted AFTER positive owner-death validation
    # and immediately BEFORE atomic archive reservation.
    out = e / "recovery-race"
    token, txpath, tx = dead_owner("recovery-race-dead-owner", out)
    if token:
        before = sha(txpath)
        p, stream, log = spawn("recovery-race", out, "--recover-claim=" + token,
                               "--test-pause-before-archive-ms=4000",
                               "--test-pause-archive-phase=recovery")
        archive = Path(str(out) + ".world-capture-recovered-" + token)
        try:
            ready = wait_marker(p, log, "test pause archive phase=recovery")
            check("recovery-race-pause", ready)
            if ready:
                digest, needle = sentinel(archive)
                rc = p.wait(timeout=160)
                check("recovery-race-refused", rc == 5, rc)
                check("recovery-race-sentinel-preserved", sha(needle) == digest)
                check("recovery-race-claim-preserved",
                      txpath.is_file() and sha(txpath) == before)
                check("recovery-race-no-commit", not (out / "capture-manifest.json").exists())
        finally:
            stop(p)
            stream.close()

    # Post-commit release collision. The previous committed root manifest
    # must survive a release error, and the claim stays recoverable.
    out = e / "release-race"
    p, stream, log = spawn("release-race", out,
                           "--test-pause-before-archive-ms=4000",
                           "--test-pause-archive-phase=release")
    try:
        ready = wait_marker(p, log, "test pause archive phase=release", 140)
        check("release-race-pause", ready)
        if ready:
            txpath = Path(str(out) + ".world-capture-claim") / "transaction.json"
            tx = json.loads(txpath.read_text())
            archive = Path(str(out) + ".world-capture-released-" + str(tx["attempt_id"]))
            digest, needle = sentinel(archive)
            rc = p.wait(timeout=160)
            check("release-race-nonzero", rc == 5, rc)
            check("release-race-sentinel-preserved", sha(needle) == digest)
            check("release-race-recoverable-claim", txpath.is_file() and
                  json.loads(txpath.read_text()).get("requires_recovery") is True)
            manifest = out / "capture-manifest.json"
            check("release-race-preserves-committed-manifest", manifest.is_file()
                  and json.loads(manifest.read_text()).get("success") is True)
    finally:
        stop(p)
        stream.close()

    # Different PID namespace token, real LIVE Godot owner, real recovery
    # process. Editing the token is explicitly a negative fixture; this is
    # NOT falsely reported as a restricted-procfs namespace mount test.
    if a.platform == "linux":
        out = e / "namespace-mismatch"
        p, stream, log = spawn("namespace-owner", out,
                               "--test-pause-before-publication-ms=30000",
                               "--test-pause-phase=prepared")
        try:
            ready = wait_marker(p, log, "test pause phase=prepared")
            check("namespace-owner-live", ready)
            if ready:
                txpath = Path(str(out) + ".world-capture-claim") / "transaction.json"
                tx = json.loads(txpath.read_text())
                token = tx["attempt_id"]
                tx["owner_pid_namespace"] = "pid:[incompatible-namespace]"
                txpath.write_text(json.dumps(tx), encoding="utf-8")
                before = sha(txpath)
                rc = run("namespace-mismatch-recovery", out, "--recover-claim=" + token)
                check("namespace-mismatch-refused", rc == 5)
                check("namespace-mismatch-claim-byte-identical", sha(txpath) == before)
                check("namespace-mismatch-owner-still-live", p.poll() is None)
                check("namespace-mismatch-no-archive",
                      not Path(str(out) + ".world-capture-recovered-" + token).exists())
        finally:
            stop(p)
            stream.close()

    (e / "checks.json").write_text(json.dumps(checks, indent=2), encoding="utf-8")
    (e / "processes.json").write_text(json.dumps(processes, indent=2), encoding="utf-8")
    summary = {"platform": a.platform, "source_sha": env["CYBERSAND_SOURCE_REVISION"],
               "checks": len(checks), "failed": [x["name"] for x in checks if not x["pass"]],
               "godot_sha256": sha(a.godot.resolve()), "driver": driver,
               "namespace_restriction_directly_exercised": False}
    (e / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print("R1D_ADVERSARY", json.dumps(summary, sort_keys=True), flush=True)
    return int(bool(summary["failed"]))


if __name__ == "__main__":
    sys.exit(main())
