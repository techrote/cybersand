#!/usr/bin/env python3
"""Actual Godot process-level adversarial qualification for live claim recovery.

Runs a first capture paused AFTER staging/preparation, presents its exact claim
token to a second live process, and requires the second to refuse takeover.
After hard-killing the first process, demonstrates an explicitly authorised
recovery and validates actual framebuffer, RG8 and committed generation hashes.

No mocks, no headless success, no source edits. All process logs remain evidence.
Expected to FAIL on implementations that allow an active claim to be archived
merely because a matching recovery token was supplied.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import time


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def text_log(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""


def wait_for_marker(proc: subprocess.Popen, log: Path, marker: str, seconds: int) -> bool:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if marker in text_log(log):
            return True
        if proc.poll() is not None:
            return marker in text_log(log)
        time.sleep(0.15)
    return marker in text_log(log)


def force_stop(proc: subprocess.Popen | None) -> int | None:
    if proc is None:
        return None
    if proc.poll() is None:
        proc.kill()  # SIGKILL (Linux) / TerminateProcess (Windows)
    try:
        return proc.wait(timeout=15)
    except subprocess.TimeoutExpired:
        proc.kill()
        return proc.wait(timeout=15)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()

    evidence = args.evidence.resolve()
    (evidence / "logs").mkdir(parents=True, exist_ok=True)
    (evidence / "fixtures").mkdir(parents=True, exist_ok=True)
    (evidence / "adversarial").mkdir(parents=True, exist_ok=True)
    godot = args.godot.resolve()
    source_sha = subprocess.check_output(
        ["git", "rev-parse", "--verify", "HEAD"], text=True
    ).strip()
    rendering_driver = "opengl3_angle" if args.platform == "windows" else "opengl3"
    environment = os.environ.copy()
    environment["CYBERSAND_SOURCE_REVISION"] = source_sha
    environment["CYBERSAND_CAPTURE_FAULT_INJECTION"] = "1"
    if args.platform == "linux":
        environment.update(
            LIBGL_ALWAYS_SOFTWARE="1", GALLIUM_DRIVER="llvmpipe",
            LP_NUM_THREADS="2", GALLIVM_PERF="nopt"
        )

    checks: list[dict] = []
    processes: list[dict] = []
    errors: list[str] = []

    def check(condition: bool, name: str, detail: object = None) -> bool:
        passed = bool(condition)
        checks.append({"name": name, "pass": passed, "detail": detail})
        if not passed:
            errors.append(name)
        return passed

    fixture = {
        "schema_id": "cybersand.world-feature-pack.proposal",
        "schema_version": 1,
        "features": [
            {"id": "witness", "size": [16, 16],
             "rectangles": [[0, 0, 16, 16, 43]], "variants": []}
        ],
        "scene": {
            "size": [48, 32],
            "rectangles": [[0, 28, 48, 4, 40]],
            "placements": [
                {"feature": "witness", "x": 5, "y": 6, "variant": None}
            ],
        },
    }
    pack_path = evidence / "fixtures" / "pack.json"
    write_json(pack_path, fixture)
    output = evidence / "adversarial" / "live-recovery"
    claim = Path(str(output) + ".world-capture-claim")
    engine = [str(godot), "--verbose", "--rendering-method", "gl_compatibility",
              "--rendering-driver", rendering_driver,
              "--path", "godot",
              "--script", "res://tools/capture_world_design_pack.gd", "--"]
    base_options = [
        "--pack=" + str(pack_path), "--output=" + str(output),
        "--mode=combined", "--scale=1", "--time=1.37", "--glow=on",
        "--require-verified-source=on",
    ]
    pause_options = [
        "--test-pause-before-publication-ms=30000",
        "--test-pause-phase=prepared",
    ]
    first_cmd = engine + base_options + pause_options
    second_cmd: list[str] = []
    recovery_cmd: list[str] = []
    first_log = evidence / "logs" / "live-owner.log"
    second_log = evidence / "logs" / "live-token-recovery.log"
    recovery_log = evidence / "logs" / "dead-owner-recovery.log"
    first: subprocess.Popen | None = None
    second: subprocess.Popen | None = None
    first_stream = None
    second_stream = None
    token = ""
    denied = False
    original_identity: dict = {}

    identity = {
        "source_sha": source_sha,
        "platform": args.platform,
        "invoked_godot": str(godot),
        "invoked_godot_sha256": sha256(godot),
        "rendering_driver_requested": rendering_driver,
        "fixture_sha256": sha256(pack_path),
        "scenario": "live owner plus exact known recovery token",
        "no_production_edits": True,
    }
    write_json(evidence / "identity.json", identity)

    try:
        check(godot.is_file(), "real-godot-file-present", str(godot))
        first_stream = first_log.open("wb")
        first = subprocess.Popen(
            first_cmd, stdout=first_stream, stderr=subprocess.STDOUT, env=environment
        )
        first_paused = wait_for_marker(
            first, first_log, "test pause phase=prepared", 110
        )
        check(first_paused and first.poll() is None, "owner-live-at-prepared-pause",
              {"marker": first_paused, "exit": first.poll()})

        if first_paused and first.poll() is None:
            transaction_path = claim / "transaction.json"
            transaction = json.loads(transaction_path.read_text()) if transaction_path.exists() else {}
            token = str(transaction.get("attempt_id", ""))
            original_identity = transaction
            check(transaction.get("schema") == 3 and
                  isinstance(transaction.get("owner_host"), str) and
                  bool(transaction.get("owner_process_started")),
                  "claim-stable-owner-namespace-and-process-start", transaction)
            check(bool(token) and transaction.get("state") == "prepared",
                  "live-claim-transaction-available", transaction)
            check(not (output / "capture-manifest.json").exists(),
                  "live-owner-has-not-committed-success")

            if token:
                second_cmd = engine + base_options + pause_options + [
                    "--recover-claim=" + token
                ]
                second_stream = second_log.open("wb")
                second = subprocess.Popen(
                    second_cmd, stdout=second_stream,
                    stderr=subprocess.STDOUT, env=environment
                )
                # A successful or paused second capture indicates live-claim theft.
                # Do not allow either process to reach publication before inspection.
                second_paused = wait_for_marker(
                    second, second_log, "test pause phase=prepared", 18
                )
                second_code = second.poll()
                second_output = text_log(second_log)
                denied = (
                    not second_paused
                    and second_code == 5
                    and "already claimed" in second_output
                    and first.poll() is None
                )
                check(denied, "live-token-recovery-must-be-denied",
                      {"second_pause_observed": second_paused,
                       "second_exit": second_code,
                       "denial_phrase_observed": "already claimed" in second_output,
                       "first_still_alive": first.poll() is None})
                archived = Path(str(output) + ".world-capture-recovered-" + token)
                check(not archived.exists(), "live-claim-never-archived",
                      {"archived": str(archived)})
                current = json.loads(transaction_path.read_text()) if transaction_path.exists() else {}
                check(claim.is_dir() and current.get("attempt_id") == token,
                      "same-owner-claim-survives-adversarial-recovery", current)
                check(not (output / "capture-manifest.json").exists(),
                      "no-premature-authoritative-commit")
    except Exception as exc:
        check(False, "probe-unhandled-exception", repr(exc))
    finally:
        second_exit = force_stop(second)
        first_exit = force_stop(first)
        if second_stream is not None:
            second_stream.close()
        if first_stream is not None:
            first_stream.close()
        processes.extend([
            {"name": "live-owner", "command": first_cmd,
             "exit_after_hard_kill": first_exit,
             "log": "logs/live-owner.log"},
            {"name": "live-token-recovery", "command": second_cmd,
             "exit_or_hard_kill": second_exit,
             "log": "logs/live-token-recovery.log"},
        ])
        check(first is not None and first_exit not in (None, 0),
              "owner-hard-killed-before-commit", first_exit)

    # A correct refusal leaves a stale claim. An explicitly acknowledged
    # recovery must work only AFTER its original owner has been killed.
    if denied and token and claim.is_dir():
        recovery_cmd = engine + base_options + ["--recover-claim=" + token]
        try:
            with recovery_log.open("wb") as stream:
                completed = subprocess.run(
                    recovery_cmd, stdout=stream, stderr=subprocess.STDOUT,
                    env=environment, timeout=150, check=False
                )
            recovery_code = completed.returncode
        except subprocess.TimeoutExpired:
            recovery_code = 124
            with recovery_log.open("ab") as stream:
                stream.write(b"\nTIMEOUT: recovery did not finish\n")
        except Exception as exc:
            recovery_code = 125
            with recovery_log.open("ab") as stream:
                stream.write(repr(exc).encode("utf-8") + b"\n")
        processes.append({
            "name": "dead-owner-recovery", "command": recovery_cmd,
            "observed_exit": recovery_code,
            "log": "logs/dead-owner-recovery.log",
        })
        check(recovery_code == 0, "dead-owner-explicit-recovery-exit", recovery_code)
        recovery_archive = Path(str(output) + ".world-capture-recovered-" + token)
        check(recovery_archive.is_dir(), "dead-owner-claim-archived",
              str(recovery_archive))
        manifest_path = output / "capture-manifest.json"
        if check(manifest_path.is_file(), "recovered-capture-manifest-present"):
            manifest = json.loads(manifest_path.read_text())
            check(manifest.get("success") is True and
                  manifest.get("status") == "complete" and
                  bool(manifest.get("generation")) and
                  manifest.get("source_identity", {}).get("verified_source_revision") == source_sha,
                  "recovery-commits-truthful-source-matched-generation",
                  {"source_identity": manifest.get("source_identity"),
                   "generation": manifest.get("generation")})
            entries = manifest.get("captures", []) + manifest.get("inputs", [])
            check(len(manifest.get("captures", [])) == 1 and
                  len(manifest.get("inputs", [])) == 1,
                  "recovery-genuine-combined-rg8-and-framebuffer-count",
                  len(entries))
            for entry in entries:
                relative = str(entry.get("file", ""))
                path = (output / relative).resolve()
                inside = path.is_relative_to(output.resolve())
                valid = (inside and path.is_file() and
                         path.stat().st_size == entry.get("bytes") and
                         sha256(path) == entry.get("sha256"))
                check(valid, "committed-generation-entry-sha:" + relative)
                if relative.endswith(".png") and valid:
                    data = path.read_bytes()
                    size = struct.unpack(">II", data[16:24]) if data[:8] == bytes.fromhex("89504e470d0a1a0a") else None
                    check(size == (48, 32),
                          "real-godot-framebuffer-png-dimensions", size)
                if relative.endswith(".rg8") and valid:
                    expected = bytearray(48 * 32 * 2)
                    for y in range(6, 22):
                        for x in range(5, 21):
                            expected[(y * 48 + x) * 2] = 43
                    for y in range(28, 32):
                        for x in range(48):
                            expected[(y * 48 + x) * 2] = 40
                    check(path.read_bytes() == bytes(expected),
                          "independent-exact-rg8-byte-oracle")
    else:
        check(False, "dead-owner-recovery-not-admissible-after-live-token-breach",
              {"denied": denied, "original_token": token})

    # A known attempt token and a matching environment-supplied HOSTNAME are
    # not sufficient recovery proof. Exercise source-verified owner identity
    # mismatches with a real Godot process on both supported platforms.
    stable_host = str(original_identity.get("owner_host", ""))
    for label, schema, host, started in (
        ("legacy-schema-1", 1, stable_host, "1"),
        ("legacy-schema-2", 2, stable_host, "1"),
        ("foreign-host-transaction", 3, "foreign-host-that-is-not-the-runner", "1"),
        ("namespace-collision-transaction", 3, stable_host + "-other-pid-namespace", "1"),
        ("unknown-process-generation", 3, stable_host, ""),
    ):
        fake_output = evidence / "adversarial" / label
        fake_claim = Path(str(fake_output) + ".world-capture-claim")
        fake_token = "12345-67890-123"
        fake_transaction = fake_claim / "transaction.json"
        write_json(fake_transaction, {
            "schema": schema,
            "state": "prepared",
            "attempt_id": fake_token,
            "output_path": str(fake_output).replace("\\", "/"),
            "pack_path": str(pack_path),
            "process_id": 123,
            "owner_host": host,
            "owner_process_started": started,
        })
        prior_sha = sha256(fake_transaction)
        fake_log = evidence / "logs" / (label + ".log")
        fake_cmd = engine + [
            "--pack=" + str(pack_path), "--output=" + str(fake_output),
            "--mode=combined", "--scale=1", "--recover-claim=" + fake_token,
        ]
        try:
            with fake_log.open("wb") as stream:
                finished = subprocess.run(fake_cmd, stdout=stream,
                                          stderr=subprocess.STDOUT,
                                          env=environment, timeout=90, check=False)
            fake_code = finished.returncode
        except subprocess.TimeoutExpired:
            fake_code = 124
            with fake_log.open("ab") as stream:
                stream.write(b"TIMEOUT: invalid recovery did not finish\n")
        processes.append({
            "name": label, "command": fake_cmd, "observed_exit": fake_code,
            "log": str(fake_log.relative_to(evidence).as_posix()),
        })
        check(fake_code == 5, label + "-recovery-refused", fake_code)
        check(fake_claim.is_dir() and fake_transaction.is_file() and
              sha256(fake_transaction) == prior_sha and
              not Path(str(fake_output) + ".world-capture-recovered-" + fake_token).exists() and
              not (fake_output / "capture-manifest.json").exists(),
              label + "-no-claim-mutation")

    # PID reuse is simulated with a real, *currently running unrelated*
    # process's PID and a stale process-start identity. The owner of the old
    # transaction is provably different from this live process generation.
    if stable_host:
        reuse_output = evidence / "adversarial" / "pid-reuse-recovery"
        reuse_claim = Path(str(reuse_output) + ".world-capture-claim")
        unrelated_pid = os.getpid()
        reuse_id = "54321-98765-" + str(unrelated_pid)
        write_json(reuse_claim / "transaction.json", {
            "schema": 3, "state": "prepared", "attempt_id": reuse_id,
            "output_path": str(reuse_output).replace("\\", "/"), "pack_path": str(pack_path),
            "process_id": unrelated_pid, "owner_host": stable_host,
            "owner_process_started": "1",
        })
        reuse_log = evidence / "logs" / "pid-reuse-recovery.log"
        reuse_cmd = engine + [
            "--pack=" + str(pack_path), "--output=" + str(reuse_output),
            "--mode=combined", "--scale=1",
            "--recover-claim=" + reuse_id,
        ]
        with reuse_log.open("wb") as stream:
            try:
                done = subprocess.run(reuse_cmd, stdout=stream,
                                      stderr=subprocess.STDOUT,
                                      env=environment, timeout=120, check=False)
                reuse_code = done.returncode
            except subprocess.TimeoutExpired:
                reuse_code = 124
        processes.append({"name": "pid-reuse-recovery",
                          "command": reuse_cmd, "observed_exit": reuse_code,
                          "log": "logs/pid-reuse-recovery.log"})
        check(reuse_code == 0, "pid-reuse-stale-owner-recovery-exit",
              {"code": reuse_code, "unrelated_process_alive": True,
               "unrelated_pid": unrelated_pid})
        check(Path(str(reuse_output) + ".world-capture-recovered-" + reuse_id).is_dir(),
              "pid-reuse-previous-claim-archived")
        reuse_manifest = reuse_output / "capture-manifest.json"
        check(reuse_manifest.is_file() and
              json.loads(reuse_manifest.read_text()).get("success") is True,
              "pid-reuse-new-generation-committed")
        check(not reuse_claim.exists(), "pid-reuse-new-owner-claim-released")

    # Failed and in-progress staging never becomes an authoritative complete
    # manifest. Do not delete negative artifacts even when this test fails.
    for stage in sorted(output.parent.glob(output.name + ".world-capture-stage-*")):
        check(not (stage / "capture-manifest.json").exists(),
              "no-complete-success-manifest-in-stage:" + stage.name)

    write_json(evidence / "checks.json", checks)
    write_json(evidence / "processes.json", processes)
    summary = {
        "source_sha": source_sha,
        "platform": args.platform,
        "checks": len(checks),
        "failures": errors,
        "qualified": not errors,
        "adversarial_test": "active-claim exact-token recovery rejection",
        "historical_control_run_not_reused": 42224192393,
    }
    write_json(evidence / "summary.json", summary)
    print("WORLD_CAPTURE_LIVE_CLAIM_PROBE", json.dumps(summary, sort_keys=True),
          flush=True)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
