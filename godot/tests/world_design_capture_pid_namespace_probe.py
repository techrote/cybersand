#!/usr/bin/env python3
"""Real Linux different-PID-namespace live-owner recovery adversary.

Launch a graphical Godot publisher on a host worker, then submit the exact
attempt token using Godot in a separate Docker PID namespace with a deliberately
identical HOSTNAME and an identical shared absolute output path. Reject claim
takeover. This is distinct from the synthetic namespace-record negative.
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


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, obj: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf8")


def wait_for_log(proc: subprocess.Popen, path: Path, phrase: str, timeout: int) -> bool:
    end = time.monotonic() + timeout
    while time.monotonic() < end and proc.poll() is None:
        if path.is_file() and phrase in path.read_text(encoding="utf8", errors="replace"):
            return True
        time.sleep(.20)
    return False


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", required=True)
    ap.add_argument("--evidence", type=Path, required=True)
    args = ap.parse_args()
    E = args.evidence.resolve()
    E.mkdir(parents=True, exist_ok=True)
    (E / "logs").mkdir(exist_ok=True)
    godot = Path(args.godot).resolve()
    repo = Path.cwd().resolve()
    source_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    checks: list[dict] = []
    problems: list[str] = []

    def check(cond: bool, name: str, detail: object = None) -> None:
        checks.append({"name": name, "pass": bool(cond), "detail": detail})
        if not cond:
            problems.append(name)

    owner: subprocess.Popen | None = None
    owner_stream = None
    try:
        if sys.platform != "linux":
            raise RuntimeError("real namespace probe requires Linux")
        if not shutil.which("docker"):
            raise RuntimeError("Docker unavailable — cross-namespace execution NOT qualified")
        subprocess.run(["docker", "info", "--format", "{{.ServerVersion}}"],
                       check=True, capture_output=True, timeout=20)
        fixture = {
            "schema_id": "cybersand.world-feature-pack.proposal",
            "schema_version": 1,
            "features": [{
                "id": "witness", "size": [16, 16],
                "rectangles": [[0, 0, 16, 16, 43]],
                "variants": []
            }],
            "scene": {
                "size": [48, 32], "rectangles": [[0, 28, 48, 4, 40]],
                "placements": [{"feature": "witness", "x": 5, "y": 6, "variant": None}]
            }
        }
        pack = E / "fixtures" / "pack.json"
        write(pack, fixture)
        target = E / "adversarial" / "namespace-live-owner"
        claim = Path(str(target) + ".world-capture-claim")
        host_name = os.environ.get("HOSTNAME") or subprocess.check_output(["hostname"], text=True).strip()
        host_namespace = os.readlink("/proc/self/ns/pid")
        host_boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
        environment = os.environ.copy()
        environment.update(CYBERSAND_CAPTURE_FAULT_INJECTION="1",
                           CYBERSAND_SOURCE_REVISION=source_sha)
        base = [
            str(godot), "--verbose", "--rendering-method", "gl_compatibility",
            "--rendering-driver", "opengl3", "--path", "godot",
            "--script", "res://tools/capture_world_design_pack.gd", "--",
            "--pack=" + str(pack), "--output=" + str(target),
            "--mode=combined", "--scale=1", "--time=1.37", "--glow=on",
        ]
        log = E / "logs" / "namespace-host-owner.log"
        owner_stream = log.open("wb")
        owner = subprocess.Popen(base + [
            "--test-pause-phase=prepared",
            "--test-pause-before-publication-ms=30000",
        ], env=environment, stdout=owner_stream, stderr=subprocess.STDOUT)
        paused = wait_for_log(owner, log, "test pause phase=prepared", 110)
        check(paused and owner.poll() is None, "real-host-publisher-paused",
              {"paused": paused, "exit": owner.poll()})
        if paused and owner.poll() is None:
            tx_file = claim / "transaction.json"
            tx = json.loads(tx_file.read_text()) if tx_file.exists() else {}
            token = str(tx.get("attempt_id", ""))
            check(bool(token) and tx.get("schema") == 3 and
                  tx.get("owner_process_started") and
                  tx.get("owner_host") == "Linux:" + host_boot + ":" + host_namespace,
                  "host-owner-identity-genuine", tx)
            if token:
                # Docker deliberately uses the *same* hostname string and
                # *identical absolute paths* to exclude lexical alias rejection.
                docker_prefix = [
                    "docker", "run", "--rm", "--pid=private",
                    "--hostname", host_name, "-e", "HOSTNAME=" + host_name,
                    "-e", "CYBERSAND_CAPTURE_FAULT_INJECTION=1",
                    "--user", str(os.getuid()) + ":" + str(os.getgid()),
                    "--volume", str(repo) + ":" + str(repo) + ":ro",
                    "--volume", str(E) + ":" + str(E) + ":rw",
                    "--volume", str(godot.parent) + ":" + str(godot.parent) + ":ro",
                    "--workdir", str(repo),
                    "ubuntu:24.04",
                ]
                # Prove the container sees a genuinely different PID namespace.
                ns_cmd = docker_prefix + ["readlink", "/proc/self/ns/pid"]
                ns = subprocess.run(ns_cmd, capture_output=True, text=True, timeout=90)
                container_namespace = ns.stdout.strip()
                check(ns.returncode == 0 and container_namespace.startswith("pid:[") and
                      container_namespace != host_namespace,
                      "genuine-different-pid-namespace",
                      {"host_namespace": host_namespace,
                       "container_namespace": container_namespace,
                       "command_exit": ns.returncode,
                       "stderr": ns.stderr[-600:]})
                owner_identity = tx.get("owner_host")
                check(host_name == environment.get("HOSTNAME", host_name),
                      "hostname-collision-configured",
                      {"supplied_hostname": host_name, "host_identity": owner_identity})
                if ns.returncode == 0 and container_namespace != host_namespace:
                    # The output path and pack path are bind-mounted at their
                    # exact host absolute names. Detection must occur before
                    # headless renderer selection or any transaction mutation.
                    foreign_cmd = docker_prefix + [
                        str(godot), "--headless", "--path", str(repo / "godot"),
                        "--script", "res://tools/capture_world_design_pack.gd", "--",
                        "--pack=" + str(pack), "--output=" + str(target),
                        "--mode=combined", "--scale=1",
                        "--recover-claim=" + token,
                        "--test-pause-phase=prepared",
                        "--test-pause-before-publication-ms=15000",
                    ]
                    evidence = E / "logs" / "namespace-foreign-recovery.log"
                    start_hash = sha(tx_file)
                    try:
                        with evidence.open("wb") as stream:
                            foreign = subprocess.run(
                                foreign_cmd, stdout=stream, stderr=subprocess.STDOUT,
                                env=environment, timeout=45, check=False)
                        exit_code = foreign.returncode
                    except subprocess.TimeoutExpired:
                        exit_code = 124
                    out = evidence.read_text(encoding="utf8", errors="replace")
                    check(exit_code == 5 and
                          "owner host or output identity cannot be verified" in out and
                          owner.poll() is None,
                          "actual-foreign-namespace-token-denied",
                          {"exit": exit_code, "log_tail": out[-1100:]})
                    check(claim.is_dir() and tx_file.is_file() and
                          sha(tx_file) == start_hash and
                          not Path(str(target) + ".world-capture-recovered-" + token).exists() and
                          not (target / "capture-manifest.json").exists(),
                          "foreign-namespace-no-claim-or-output-mutation")
    except Exception as exc:
        check(False, "probe-execution-error", repr(exc))
    finally:
        if owner is not None:
            if owner.poll() is None:
                owner.kill()
            owner.wait(timeout=20)
        if owner_stream is not None:
            owner_stream.close()
        write(E / "namespace-checks.json", checks)
        summary = {
            "source_sha": source_sha, "platform": "linux",
            "adversary": "real separate Docker PID namespace, colliding hostname, same volume/paths",
            "checks": len(checks), "failures": problems,
            "qualified": not problems,
        }
        write(E / "namespace-summary.json", summary)
        print("WORLD_CAPTURE_PID_NAMESPACE_PROBE", json.dumps(summary, sort_keys=True))
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
