#!/usr/bin/env python3
"""Source-specific live qualification for the remote workbench transport.

This is a trusted qualification driver, not an agent API. Every workbench command
is sent through a fresh client.py subprocess over HTTP. It retains transcripts,
original PNG downloads and the upstream run.py evidence without retaining tokens.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CLIENT = HERE / "client.py"
SERVER = HERE / "serve.py"

sys.path.insert(0, str(HERE))
import verify

TOOLS = ("observe", "prepare_edit", "apply_edit", "step", "stop")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def native_result(payload: dict) -> dict:
    receipt = payload.get("receipt")
    require(isinstance(receipt, dict), "missing tool receipt")
    result = receipt.get("result")
    require(isinstance(result, dict), "missing native result")
    return result


def generation_of(result: dict) -> int | None:
    identity = result.get("identity", {})
    if not isinstance(identity, dict):
        return None
    value = identity.get("world_generation", identity.get("generation"))
    return int(value) if isinstance(value, (int, float)) else None


def changed_pixels(first: Path, second: Path) -> int:
    w1, h1, p1 = verify.decode_png(first)
    w2, h2, p2 = verify.decode_png(second)
    require((w1, h1) == (w2, h2), "frame dimensions changed unexpectedly")
    require(len(p1) == len(p2) and w1 > 0 and h1 > 0, "frame payload mismatch")
    bpp = len(p1) // (w1 * h1)
    require(bpp in (3, 4), "unexpected decoded PNG bytes-per-pixel")
    return sum(
        p1[i:i + bpp] != p2[i:i + bpp]
        for i in range(0, len(p1), bpp)
    )


class Driver:
    def __init__(self, output: Path, token_file: Path, wrong_token_file: Path,
                 port: int, client_deadline: float):
        self.output = output
        self.token_file = token_file
        self.wrong_token_file = wrong_token_file
        self.port = port
        self.base = f"http://127.0.0.1:{port}"
        self.client_deadline = client_deadline
        self.transcripts: list[dict] = []
        self.counter = 0

    def run_client(self, label: str, *args: str, wrong_token: bool = False,
                   record: bool = True) -> tuple[int, dict]:
        token = self.wrong_token_file if wrong_token else self.token_file
        argv = [
            sys.executable, str(CLIENT),
            "--base", self.base,
            "--token-file", str(token),
            "--http-timeout", "10",
            "--deadline", str(self.client_deadline),
            *args,
        ]
        proc = subprocess.run(
            argv, cwd=ROOT, capture_output=True, text=True,
            timeout=self.client_deadline + 20, check=False,
        )
        try:
            payload = json.loads(proc.stdout)
        except (ValueError, TypeError):
            payload = {
                "error": "client_non_json_output",
                "stdout": proc.stdout[-2000:],
                "stderr": proc.stderr[-2000:],
            }
        if record:
            self.counter += 1
            self.transcripts.append({
                "index": self.counter,
                "label": label,
                "client_arguments": list(args),
                "returncode": proc.returncode,
                "payload": payload,
                "stderr": proc.stderr[-2000:],
            })
        return proc.returncode, payload

    def wait_ready(self, process: subprocess.Popen, deadline: float = 300.0) -> dict:
        until = time.monotonic() + deadline
        last: dict = {}
        while time.monotonic() < until:
            require(process.poll() is None, "service exited before ready")
            code, payload = self.run_client("startup-poll", "session", record=False)
            if code == 0 and isinstance(payload, dict):
                last = payload
                if payload.get("phase") == "ready":
                    self.transcripts.append({
                        "index": self.counter + 1,
                        "label": "session-ready",
                        "client_arguments": ["session"],
                        "returncode": 0,
                        "payload": payload,
                        "stderr": "",
                    })
                    self.counter += 1
                    return payload
                if payload.get("phase") == "unconfirmed":
                    raise AssertionError("service became unconfirmed during startup")
            time.sleep(0.2)
        raise AssertionError(f"service ready deadline; last={last}")

    def wait_terminal(self, process: subprocess.Popen, deadline: float = 45.0) -> dict:
        until = time.monotonic() + deadline
        last: dict = {}
        while time.monotonic() < until:
            if process.poll() is not None:
                break
            code, payload = self.run_client("terminal-poll", "session", record=False)
            if code == 0 and isinstance(payload, dict):
                last = payload
                if payload.get("phase") in ("stopped", "unconfirmed"):
                    self.counter += 1
                    self.transcripts.append({
                        "index": self.counter,
                        "label": "session-terminal",
                        "client_arguments": ["session"],
                        "returncode": 0,
                        "payload": payload,
                        "stderr": "",
                    })
                    return payload
            time.sleep(0.1)
        require(last.get("phase") == "stopped",
                f"terminal service status unavailable: {last}")
        return last

    def call(self, label: str, tool: str, session_id: str, request_id: str,
             args: dict, *, no_wait: bool = False) -> dict:
        require(tool in TOOLS, "unknown tool")
        command = [
            "call", tool, "--session", session_id,
            "--request-id", request_id,
            "--args", json.dumps(args, separators=(",", ":"), ensure_ascii=True),
        ]
        if no_wait:
            command.append("--no-wait")
        code, payload = self.run_client(label, *command)
        require(code == 0, f"{label} client failed: {payload}")
        return payload

    def request(self, label: str, request_id: str) -> dict:
        code, payload = self.run_client(label, "request", request_id)
        require(code == 0, f"{label} request failed: {payload}")
        return payload

    def frame(self, label: str, name: str, expected_sha256: str,
              destination: Path) -> Path:
        require(
            isinstance(expected_sha256, str) and len(expected_sha256) == 64,
            f"{label} lacks receipt frame SHA-256",
        )
        code, payload = self.run_client(
            label, "frame", name, "--output", str(destination),
            "--sha256", expected_sha256,
        )
        require(code == 0 and destination.is_file(), f"{label} frame failed: {payload}")
        require(destination.read_bytes().startswith(verify.PNG_HEADER),
                f"{label} is not an original PNG")
        return destination


def start_service(driver: Driver, godot: Path, authorization: Path,
                  state_root: Path, session_seconds: int,
                  display_mode: str, log_path: Path) -> tuple[subprocess.Popen, object]:
    log = log_path.open("wb")
    argv = [
        sys.executable, str(SERVER),
        "--godot", str(godot),
        "--authorization", str(authorization),
        "--token-file", str(driver.token_file),
        "--state-root", str(state_root),
        "--seconds", str(session_seconds),
        "--bind", "127.0.0.1",
        "--port", str(driver.port),
    ]
    if display_mode == "xvfb":
        argv.append("--xvfb")
    env = {
        k: v for k, v in os.environ.items()
        if not (k.upper().endswith(("_TOKEN", "_KEY", "_SECRET", "_PASSWORD"))
                or k.upper().startswith(("GITHUB_", "GH_", "OPENAI_")))
    }
    process = subprocess.Popen(
        argv, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    return process, log


def cleanup_service(driver: Driver, process: subprocess.Popen, label: str) -> None:
    """Best-effort native retirement before any supervisor signal escalation."""
    if process.poll() is not None:
        return
    try:
        code, snapshot = driver.run_client(label + "-status", "session", record=False)
        if code == 0 and isinstance(snapshot, dict):
            phase = snapshot.get("phase")
            sid = snapshot.get("session_id")
            if (isinstance(sid, str) and phase in ("ready", "stopping")
                    and not snapshot.get("stop_request_id")):
                driver.run_client(
                    label + "-stop",
                    "call", "stop", "--session", sid,
                    "--request-id", "qualifier-cleanup-" + secrets.token_hex(6),
                    "--args", "{}", "--no-wait",
                    record=False,
                )
        try:
            process.wait(timeout=45)
            return
        except subprocess.TimeoutExpired:
            pass
    except Exception:
        pass
    # serve.py converts SIGTERM into session.close(), which queues/awaits native
    # Stop and delegates child-group reaping to corrected upstream run.py.
    process.terminate()
    try:
        process.wait(timeout=60)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=10)


def session_directories(state_root: Path) -> set[Path]:
    if not state_root.is_dir():
        return set()
    return {
        p.resolve()
        for p in state_root.iterdir()
        if p.is_dir() and p.name.startswith("session-")
    }


def locate_new_owner_evidence(state_root: Path, before: set[Path]) -> Path:
    created = session_directories(state_root) - before
    require(len(created) == 1, f"expected one new service session under {state_root}")
    evidence = next(iter(created)) / "evidence"
    require(evidence.is_dir(), "upstream evidence directory missing")
    return evidence


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--authorization", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--port", type=int, default=18765)
    parser.add_argument("--session-seconds", type=int, default=1200)
    parser.add_argument("--client-deadline", type=float, default=330.0)
    parser.add_argument("--display-mode", choices=("xvfb", "existing"), default="xvfb")
    args = parser.parse_args(argv)
    if not 1024 <= args.port <= 65534:
        parser.error("--port must leave a second local port available")
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error("--output must be empty")
    output.mkdir(parents=True, exist_ok=True)
    frames = output / "client-frames"
    frames.mkdir()
    authorization = args.authorization.resolve(strict=True)
    godot = args.godot.resolve(strict=True)

    result: dict = {
        "schema_version": 1,
        "source_commit": git("rev-parse", "HEAD"),
        "source_tree": git("rev-parse", "HEAD^{tree}"),
        "display_mode": args.display_mode,
        "paid_model_calls": 0,
        "codespaces_connectivity": "not_tested_by_local_qualifier",
        "sessions": [],
        "checks": {},
    }

    with tempfile.TemporaryDirectory(prefix="cybersand-wb-auth-") as temporary:
        secrets_dir = Path(temporary)
        token = secrets.token_urlsafe(48)
        token_file = secrets_dir / "token"
        wrong_token_file = secrets_dir / "wrong"
        token_file.write_text(token + "\n", encoding="utf-8")
        wrong_token_file.write_text(secrets.token_urlsafe(48) + "\n", encoding="utf-8")
        os.chmod(token_file, 0o600)
        os.chmod(wrong_token_file, 0o600)

        first = Driver(output, token_file, wrong_token_file,
                       args.port, args.client_deadline)
        service_state = output / "service-state"
        before_one = session_directories(service_state)
        service_one, log_one = start_service(
            first, godot, authorization, service_state, args.session_seconds,
            args.display_mode, output / "service-one.log",
        )
        try:
            ready = first.wait_ready(service_one)
            sid = ready["session_id"]
            require(ready.get("native_generation") is not None,
                    "ready session lacks native generation")

            bad_code, bad = first.run_client(
                "external-wrong-bearer", "session", wrong_token=True
            )
            require(bad_code != 0 and bad.get("error") == "bearer_authentication_required",
                    "wrong bearer did not fail at application boundary")

            initial = first.call(
                "observe-initial", "observe", sid, "req-observe-0001",
                {"region": {"x": 28, "y": 28, "width": 8, "height": 8},
                 "detail": "cells"},
            )
            initial_native = native_result(initial)
            require(initial_native.get("status") == "observed", "initial observe failed")
            initial_frame_name = initial["receipt"]["frame"]["path"].removeprefix("frames/")
            initial_frame = first.frame(
                "frame-initial", initial_frame_name,
                initial["receipt"]["frame"]["sha256"], frames / "initial.png"
            )

            prepared = first.call(
                "prepare-first-edit", "prepare_edit", sid, "req-prepare-0001",
                {
                    "observation_id": initial_native["observation_id"],
                    "operations": [{
                        "shape": "rectangle", "x0": 30, "y0": 30,
                        "x1": 32, "y1": 32, "material": 58,
                    }],
                },
            )
            prepared_native = native_result(prepared)
            require(prepared_native.get("status") == "proposed", "first prepare failed")
            proposal_one = prepared_native["proposal_id"]

            applied = first.call(
                "apply-first-edit", "apply_edit", sid, "req-apply-000001",
                {"proposal_id": proposal_one},
            )
            applied_native = native_result(applied)
            require(applied_native.get("status") == "applied", "first apply failed")
            before_dup = first.run_client("session-before-duplicate", "session")[1]
            duplicate = first.call(
                "duplicate-apply-same-id", "apply_edit", sid, "req-apply-000001",
                {"proposal_id": proposal_one},
            )
            after_dup = first.run_client("session-after-duplicate", "session")[1]
            require(duplicate.get("receipt") == applied.get("receipt"),
                    "duplicate request did not replay immutable receipt")
            require(before_dup.get("commands_submitted") == after_dup.get("commands_submitted"),
                    "duplicate request appended a second mutation command")

            # Exit the submitting client immediately, then reconnect in a new
            # process and recover the acknowledged result by request ID.
            reconnect_submit = first.call(
                "disconnect-after-submit", "observe", sid, "req-reconnect01",
                {"region": {"x": 28, "y": 28, "width": 8, "height": 8},
                 "detail": "cells"},
                no_wait=True,
            )
            require(reconnect_submit.get("state") == "pending",
                    "no-wait reconnect control was not pending at disconnect")
            post_edit = first.request("reconnect-query", "req-reconnect01")
            post_native = native_result(post_edit)
            require(post_native.get("status") == "observed",
                    "reconnected request did not obtain native observation")
            post_frame_name = post_edit["receipt"]["frame"]["path"].removeprefix("frames/")
            post_frame = first.frame(
                "frame-post-edit", post_frame_name,
                post_edit["receipt"]["frame"]["sha256"], frames / "post-edit.png"
            )
            changed_after_edit = changed_pixels(initial_frame, post_frame)
            require(changed_after_edit > 0, "native edit produced no framebuffer change")
            walls = post_native.get("native_counts", {})
            wall_count = int(walls.get("58", walls.get(58, 0)))
            require(wall_count == 9, f"expected nine Hard Wall cells, got {wall_count}")

            revised = first.call(
                "prepare-revision", "prepare_edit", sid, "req-prepare-0002",
                {
                    "observation_id": post_native["observation_id"],
                    "operations": [{
                        "shape": "rectangle", "x0": 31, "y0": 31,
                        "x1": 31, "y1": 31, "material": 0,
                    }],
                },
            )
            revised_native = native_result(revised)
            require(revised_native.get("status") == "proposed", "revision prepare failed")
            proposal_two = revised_native["proposal_id"]
            applied_two = first.call(
                "apply-revision", "apply_edit", sid, "req-apply-000002",
                {"proposal_id": proposal_two},
            )
            require(native_result(applied_two).get("status") == "applied",
                    "revision apply failed")

            revised_observe = first.call(
                "observe-revision", "observe", sid, "req-observe-0002",
                {"region": {"x": 28, "y": 28, "width": 8, "height": 8},
                 "detail": "cells"},
            )
            revised_obs_native = native_result(revised_observe)
            revised_frame_name = revised_observe["receipt"]["frame"]["path"].removeprefix("frames/")
            revised_frame = first.frame(
                "frame-revision", revised_frame_name,
                revised_observe["receipt"]["frame"]["sha256"], frames / "revision.png"
            )
            changed_after_revision = changed_pixels(post_frame, revised_frame)
            require(changed_after_revision > 0, "revision produced no framebuffer change")
            revised_counts = revised_obs_native.get("native_counts", {})
            revised_walls = int(revised_counts.get("58", revised_counts.get(58, 0)))
            require(revised_walls == 8,
                    f"revision did not leave eight Hard Wall cells: {revised_walls}")

            step = first.call(
                "step-and-inspect", "step", sid, "req-step-000001", {"ticks": 4}
            )
            step_native = native_result(step)
            require(step_native.get("status") == "completed"
                    and int(step_native.get("completed", -1)) == 4,
                    "four-tick native Step failed")
            step_frame_name = step["receipt"]["frame"]["path"].removeprefix("frames/")
            step_frame = first.frame(
                "frame-step", step_frame_name,
                step["receipt"]["frame"]["sha256"], frames / "step.png"
            )
            verify.decode_png(step_frame)

            generations = {
                generation_of(initial_native),
                generation_of(post_native),
                generation_of(revised_obs_native),
            }
            nested = step_native.get("observation", {})
            if isinstance(nested, dict):
                generations.add(generation_of(nested))
            generations.discard(None)
            require(len(generations) == 1, f"World generation changed in session: {generations}")

            stopped = first.call(
                "stop-first-session", "stop", sid, "req-stop-000001", {}
            )
            require(native_result(stopped).get("status") == "stopped",
                    "native Stop was not acknowledged")
            terminal = first.wait_terminal(service_one)
            require(terminal.get("phase") == "stopped",
                    f"first service terminal state is not stopped: {terminal}")
        finally:
            cleanup_service(first, service_one, "first-cleanup")
            log_one.close()

        evidence_one = locate_new_owner_evidence(service_state, before_one)
        launcher_one = json.loads((evidence_one / "launcher-identity.json").read_text())
        manifest_one = json.loads((evidence_one / "manifest.json").read_text())
        require(launcher_one.get("source_commit") == result["source_commit"],
                "first owner source commit drift")
        require(manifest_one.get("result") == "passed"
                and manifest_one.get("stopped") is True,
                "first owner manifest did not pass verified Stop")
        result["sessions"].append({
            "name": "iterative",
            "transport_session_id": sid,
            "owner_session_id": launcher_one.get("session_id"),
            "native_generation": ready.get("native_generation"),
            "owner_manifest": str(evidence_one / "manifest.json"),
            "runtime_hashes": launcher_one.get("runtime_hashes"),
        })
        result["checks"].update({
            "wrong_bearer_401": True,
            "duplicate_no_second_command": True,
            "disconnect_reconnect_by_request_id": True,
            "same_world_generation": list(generations)[0],
            "first_edit_changed_pixels": changed_after_edit,
            "revision_changed_pixels": changed_after_revision,
            "first_edit_hard_walls": wall_count,
            "revision_hard_walls": revised_walls,
            "step_completed_ticks": 4,
            "first_stop_verified": True,
        })
        (output / "client-transcripts-one.json").write_text(
            json.dumps(first.transcripts, indent=2) + "\n", encoding="utf-8"
        )

        # Restart: fresh transport and native World. Old wrapper session is
        # rejected before dispatch; an old proposal presented under the new
        # session reaches the fresh native owner and must still be refused.
        second = Driver(output, token_file, wrong_token_file,
                        args.port, args.client_deadline)
        before_two = session_directories(service_state)
        service_two, log_two = start_service(
            second, godot, authorization, service_state, args.session_seconds,
            args.display_mode, output / "service-two.log",
        )
        try:
            ready_two = second.wait_ready(service_two)
            sid_two = ready_two["session_id"]
            require(sid_two != sid, "service restart reused transport session ID")
            require(
                ready_two.get("generation_id") != ready.get("generation_id"),
                "service restart reused composite generation identity",
            )
            prior = ready_two.get("prior_session_recovery", {})
            require(
                isinstance(prior, dict) and int(prior.get("scanned", 0)) >= 1,
                "replacement service did not reconcile the prior state root",
            )

            stale_code, stale_session = second.run_client(
                "old-session-refused",
                "call", "observe", "--session", sid,
                "--request-id", "req-oldsession1", "--args", "{}",
                "--no-wait",
            )
            require(stale_code != 0
                    and stale_session.get("error") == "stale_or_wrong_session",
                    "fresh service accepted an old session ID")

            old_code, old_proposal = second.run_client(
                "old-proposal-refused",
                "call", "apply_edit", "--session", sid_two,
                "--request-id", "req-oldproposal",
                "--args", json.dumps(
                    {"proposal_id": proposal_two},
                    separators=(",", ":"), ensure_ascii=True,
                ),
            )
            require(old_code != 0, "native refusal was exposed as client success")
            old_native = native_result(old_proposal)
            require(old_native.get("status") == "refused",
                    "fresh native owner accepted old proposal")

            second_observe = second.call(
                "restart-observe", "observe", sid_two, "req-restartobs",
                {"region": {"x": 28, "y": 28, "width": 8, "height": 8},
                 "detail": "cells"},
            )
            require(native_result(second_observe).get("status") == "observed",
                    "fresh session observe failed")

            outstanding = second.call(
                "outstanding-step-submit", "step", sid_two, "req-step-pending",
                {"ticks": 120}, no_wait=True,
            )
            require(outstanding.get("state") == "pending",
                    "outstanding Step was not pending when client returned")
            stop_pending = second.call(
                "stop-during-outstanding", "stop", sid_two, "req-stop-pending",
                {}, no_wait=True,
            )
            require(stop_pending.get("state") == "pending",
                    "Stop was not truthfully queued pending owner execution")

            completed_step = second.request("outstanding-step-result", "req-step-pending")
            completed_stop = second.request("outstanding-stop-result", "req-stop-pending")
            step_two_native = native_result(completed_step)
            stop_two_native = native_result(completed_stop)
            require(step_two_native.get("status") in ("completed", "stopped"),
                    f"outstanding Step has unexpected owner outcome: {step_two_native}")
            require(stop_two_native.get("status") == "stopped",
                    "queued Stop lacked native acknowledgment")
            terminal_two = second.wait_terminal(service_two)
            require(terminal_two.get("phase") == "stopped",
                    f"restart terminal state is not stopped: {terminal_two}")
        finally:
            cleanup_service(second, service_two, "second-cleanup")
            log_two.close()

        evidence_two = locate_new_owner_evidence(service_state, before_two)
        launcher_two = json.loads((evidence_two / "launcher-identity.json").read_text())
        manifest_two = json.loads((evidence_two / "manifest.json").read_text())
        require(launcher_two.get("source_commit") == result["source_commit"],
                "restart owner source commit drift")
        require(manifest_two.get("result") == "passed"
                and manifest_two.get("stopped") is True,
                "restart owner manifest did not pass verified Stop")
        require(launcher_two.get("session_id") != launcher_one.get("session_id"),
                "upstream launcher reused owner session identity across restart")
        result["sessions"].append({
            "name": "restart-and-outstanding-stop",
            "transport_session_id": sid_two,
            "owner_session_id": launcher_two.get("session_id"),
            "native_generation": ready_two.get("native_generation"),
            "owner_manifest": str(evidence_two / "manifest.json"),
            "runtime_hashes": launcher_two.get("runtime_hashes"),
        })
        result["checks"].update({
            "restart_new_transport_session": True,
            "restart_new_composite_generation": True,
            "restart_prior_state_reconciled": True,
            "restart_new_owner_session": True,
            "old_session_refused": True,
            "old_proposal_refused": True,
            "stop_queued_while_step_pending": True,
            "outstanding_step_owner_status": step_two_native.get("status"),
            "second_stop_verified": True,
        })
        (output / "client-transcripts-two.json").write_text(
            json.dumps(second.transcripts, indent=2) + "\n", encoding="utf-8"
        )

    # Token files have been destroyed at this point. Retain only non-secret
    # source/runtime/evidence identities and original client-downloaded PNGs.
    artifacts = {}
    for path in sorted(output.rglob("*")):
        if path.is_file() and path.name not in ("qualification.json",):
            artifacts[str(path.relative_to(output))] = {
                "bytes": path.stat().st_size,
                "sha256": digest(path),
            }
    result["artifacts"] = artifacts
    result["result"] = "passed"
    (output / "qualification.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({
        "result": "passed",
        "source_commit": result["source_commit"],
        "same_world_generation": result["checks"]["same_world_generation"],
        "first_edit_changed_pixels": result["checks"]["first_edit_changed_pixels"],
        "revision_changed_pixels": result["checks"]["revision_changed_pixels"],
        "sessions": len(result["sessions"]),
        "output": str(output),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
