#!/usr/bin/env python3
"""Authenticated, bounded HTTP ingress for the existing Godot JSONL workbench.

One process, one World, one append-only file. This does NOT implement native
edits, mutate World storage, call models, or restore evolved simulation state.
"""
from __future__ import annotations

import argparse
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import re
import secrets
import signal
import subprocess
import sys
import threading
import time
from urllib.parse import unquote, urlsplit

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
TOOLS = frozenset(("observe", "prepare_edit", "apply_edit", "step", "stop"))
ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,80}$")
FRAME_PATTERN = re.compile(r"^\d{3}-(observe|step)\.png$")
MAX_REQUEST = 65536
MAX_COMMAND_BYTES = 262144
MAX_COMMANDS = 96
MAX_FRAME_BYTES = 8388608
MAX_FRAMES = 48
STATE_OVERHEAD_RESERVE_BYTES = 8 * 1024 * 1024
STOP_QUEUE_RESERVE_SECONDS = 30
STOP_GRACE_SECONDS = 30
KILL_GRACE_SECONDS = 5
TERMINAL_STATUS_GRACE_SECONDS = 5


def token_from_file(path: Path) -> bytes:
    if not path.is_file() or path.is_symlink():
        raise ValueError("Token must be a regular, non-symlink file")
    stat = path.stat()
    if stat.st_uid != os.getuid() or stat.st_mode & 0o077:
        raise ValueError("Token file must be owned by this user and mode 0600")
    value = path.read_bytes().strip()
    if not 32 <= len(value) <= 256 or any(c <= 32 or c > 126 for c in value):
        raise ValueError("Token must be 32-256 printable, non-whitespace bytes")
    return value


def operation_request_deadline_seconds() -> int:
    """Consume the repository execution policy rather than inventing a timeout."""
    policy_path = ROOT / "godot/tests/support/ci_execution_policy.json"
    policy = json.loads(policy_path.read_text(encoding="utf-8"))
    value = float(policy["watchdogs"]["operation_seconds"])
    scale_text = os.environ.get("CYBERSAND_CI_WATCHDOG_SCALE", "").strip()
    scale = 1.0 if not scale_text else float(scale_text)
    scaled = value * scale
    if (not math.isfinite(scaled) or scaled <= 0.0 or scaled > 1200.0
            or not math.isfinite(scale) or scale < 1.0):
        raise ValueError("Invalid effective workbench operation watchdog")
    return math.ceil(scaled) + 30


def _read_json_object(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError, TypeError):
        return {}


def recover_host_custody(run_contract, identity: dict, custody: dict,
                         reason: str, expected_launcher_pid: int | None = None
                         ) -> tuple[bool, dict]:
    """Retire only an exact source-fenced child PGID from #545 host evidence."""
    if not all(hasattr(run_contract, name) for name in (
            "linux_start_ticks", "group_exists",
            "TERM_GRACE_SECONDS", "KILL_GRACE_SECONDS")):
        return False, {
            "state": "unconfirmed_upstream_custody_contract_unavailable",
            "reason": reason,
        }
    expected_session = identity.get("session_id")
    launcher_pid = custody.get("launcher_pid")
    child_pid = custody.get("child_pid")
    pgid = custody.get("owned_process_group")
    start_ticks = custody.get("group_leader_start_ticks")
    valid = (
        custody.get("version") == 1
        and custody.get("host_only") is True
        and isinstance(expected_session, str) and expected_session
        and custody.get("session_id") == expected_session
        and type(launcher_pid) is int and launcher_pid > 1
        and (expected_launcher_pid is None
             or launcher_pid == expected_launcher_pid)
        and type(child_pid) is int and child_pid > 1
        and type(pgid) is int and pgid == child_pid
        and type(start_ticks) is int and start_ticks > 0
    )
    if not valid:
        return False, {
            "state": "unconfirmed_missing_or_invalid_custody",
            "reason": reason,
        }

    if not run_contract.group_exists(pgid):
        return True, {
            "state": "no_surviving_owned_group",
            "reason": reason,
            "session_id": expected_session,
            "owned_process_group": pgid,
        }

    current_ticks = run_contract.linux_start_ticks(pgid)
    try:
        current_pgid = os.getpgid(pgid)
    except (ProcessLookupError, PermissionError):
        current_pgid = None
    if current_ticks != start_ticks or current_pgid != pgid:
        return False, {
            "state": "unconfirmed_process_identity_mismatch",
            "reason": reason,
            "session_id": expected_session,
            "owned_process_group": pgid,
        }

    sent_term = sent_kill = False
    try:
        os.killpg(pgid, signal.SIGTERM)
        sent_term = True
    except ProcessLookupError:
        pass
    deadline = time.monotonic() + run_contract.TERM_GRACE_SECONDS
    while time.monotonic() < deadline and run_contract.group_exists(pgid):
        time.sleep(0.05)
    if run_contract.group_exists(pgid):
        try:
            os.killpg(pgid, signal.SIGKILL)
            sent_kill = True
        except ProcessLookupError:
            pass
        deadline = time.monotonic() + run_contract.KILL_GRACE_SECONDS
        while time.monotonic() < deadline and run_contract.group_exists(pgid):
            time.sleep(0.05)
    exited = not run_contract.group_exists(pgid)
    return exited, {
        "state": "recovered_orphaned_owned_group" if exited
                 else "cleanup_failed",
        "reason": reason,
        "session_id": expected_session,
        "owned_process_group": pgid,
        "sent_sigterm": sent_term,
        "sent_sigkill": sent_kill,
        "owned_processes_exited": exited,
    }


def reconcile_prior_sessions(root: Path) -> dict:
    """Prevent a replacement supervisor from overlapping an older native World."""
    import run

    summary = {
        "scanned": 0,
        "already_terminal_or_prelaunch": 0,
        "recovered_owned_groups": 0,
    }
    for folder in sorted(root.glob("session-*")):
        if not folder.is_dir() or folder.is_symlink():
            continue
        summary["scanned"] += 1
        # bind-before-spawn can leave a directory with commands.jsonl only.
        if not (folder / "supervisor.log").exists():
            summary["already_terminal_or_prelaunch"] += 1
            continue
        evidence = folder / "evidence"
        cleanup = _read_json_object(evidence / "cleanup-result.json")
        custody = _read_json_object(evidence / "launcher-process.json")
        identity = _read_json_object(evidence / "launcher-identity.json")
        if not custody:
            if cleanup.get("owned_processes_exited") is True:
                summary["already_terminal_or_prelaunch"] += 1
                continue
            raise RuntimeError("prior_session_cleanup_unconfirmed")
        if (custody.get("state") == "cleaned"
                and cleanup.get("owned_processes_exited") is True):
            summary["already_terminal_or_prelaunch"] += 1
            continue
        ok, recovered = recover_host_custody(
            run, identity, custody, "replacement_service_start"
        )
        if not ok:
            raise RuntimeError(
                "prior_session_cleanup_unconfirmed:" + recovered.get(
                    "state", "unknown"
                )
            )
        if recovered.get("state") == "recovered_orphaned_owned_group":
            summary["recovered_owned_groups"] += 1
        else:
            summary["already_terminal_or_prelaunch"] += 1
    return summary


class Session:
    """Single-source native receipt tracker. A timed-out request is NOT retried."""

    def __init__(self, state_dir: Path, authorization: Path, godot: Path,
                 *, xvfb: bool, max_seconds: int = 1740, spawn: bool = True):
        import run  # existing trusted runner: native/LFS provenance + Xvfb

        run.validate_authorization(authorization)
        self.run_contract = run
        self.request_deadline_seconds = operation_request_deadline_seconds()
        self.cleanup_reserve_seconds = int(run.SESSION_CLEANUP_RESERVE_SECONDS)
        self.evidence_limit_bytes = int(run.DEFAULT_EVIDENCE_LIMIT_BYTES)
        minimum_session = self.request_deadline_seconds + STOP_QUEUE_RESERVE_SECONDS
        maximum_session = int(run.SESSION_TIMEOUT_MAX) - self.cleanup_reserve_seconds
        if not minimum_session <= max_seconds <= maximum_session:
            raise ValueError(
                "Session duration must leave one complete operation and launcher "
                f"cleanup reserve ({minimum_session}-{maximum_session} seconds)"
            )
        self.launcher_timeout_seconds = max_seconds + self.cleanup_reserve_seconds
        self.state_hard_limit_bytes = (
            self.evidence_limit_bytes + STATE_OVERHEAD_RESERVE_BYTES
        )
        self.id = secrets.token_hex(16)
        self.state_dir = state_dir.resolve()
        self.state_dir.mkdir(mode=0o700, parents=True, exist_ok=False)
        os.chmod(self.state_dir, 0o700)
        self.evidence = self.state_dir / "evidence"
        self.commands = self.state_dir / "commands.jsonl"
        fd = os.open(self.commands, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(fd)
        self.authorization = authorization.resolve(strict=True)
        self.godot = godot.resolve()
        self.xvfb = xvfb
        self.max_seconds = max_seconds
        self.started = time.monotonic()
        self.lock = threading.RLock()
        self.ready = threading.Event()
        self.phase = "starting"
        self.native_generation = None
        self.last_identity: dict = {}
        self.total_ticks = 0
        self.requests: dict[str, dict] = {}
        self.by_seq: dict[int, str] = {}
        self.pending = None
        self.stop_id = None
        self.frames: set[str] = set()
        self.frame_digests: dict[str, str] = {}
        self.command_bytes = 0
        self.command_hasher = hashlib.sha256()
        self.last_evidence_bytes = 0
        self.offset = 0
        self.partial = b""
        self.next_seq = 1
        self.proc = None
        self.failure = None
        self.custody_recovery: dict = {"state": "not_checked"}
        self.prior_session_recovery: dict = {
            "scanned": 0,
            "already_terminal_or_prelaunch": 0,
            "recovered_owned_groups": 0,
        }
        if spawn:
            self.start()

    def start(self) -> None:
        if self.proc is not None:
            raise RuntimeError("session_already_started")
        self.started = time.monotonic()
        self._start()
        self.monitor = threading.Thread(target=self._monitor, daemon=True)
        self.monitor.start()

    def _start(self) -> None:
        log = (self.state_dir / "supervisor.log").open("wb")
        argv = [
            sys.executable, str(HERE / "run.py"), "--live",
            "--godot", str(self.godot),
            "--authorization", str(self.authorization),
            "--commands", str(self.commands),
            "--evidence", str(self.evidence),
            "--timeout", str(self.launcher_timeout_seconds),
            "--evidence-limit-bytes", str(self.evidence_limit_bytes),
        ]
        if self.xvfb:
            argv.append("--xvfb")
        # The engine requires no GitHub/OpenAI secrets; do not propagate them.
        env = {k: v for k, v in os.environ.items()
               if not (k.upper().endswith(("_TOKEN", "_KEY", "_SECRET", "_PASSWORD"))
                       or k.upper().startswith(("GITHUB_", "GH_", "OPENAI_")))}
        try:
            self.proc = subprocess.Popen(
                argv, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
                start_new_session=True,
            )
        finally:
            log.close()

    def _read_receipts(self) -> None:
        path = self.evidence / "results.jsonl"
        if not path.is_file():
            return
        with path.open("rb") as stream:
            stream.seek(self.offset)
            chunk = stream.read(4 * 1024 * 1024)
            self.offset += len(chunk)
        if not chunk:
            return
        self.partial += chunk
        if len(self.partial) > 4 * 1024 * 1024:
            with self.lock:
                self.failure = "native_receipt_over_capacity"
                self.phase = "unconfirmed"
            return
        while b"\n" in self.partial:
            line, self.partial = self.partial.split(b"\n", 1)
            try:
                event = json.loads(line)
                if not isinstance(event, dict):
                    raise ValueError("native receipt must be an object")
                self.ingest(event)
            except (UnicodeError, ValueError, TypeError):
                with self.lock:
                    self.failure = "malformed_native_receipt"
                    self.phase = "unconfirmed"
                return

    def _monitor(self) -> None:
        while True:
            self._read_receipts()
            with self.lock:
                age = time.monotonic() - self.started
                self.last_evidence_bytes = self._state_size()
                if self.last_evidence_bytes > self.state_hard_limit_bytes:
                    self.phase = "unconfirmed"
                    self.failure = "session_state_hard_limit_exceeded"
                # The owner watchdog is a per-command bound; an overdue
                # native operation is unknown, never treated as a failed/no-op
                # that the client may safely retry as a new mutation.
                for record in self.requests.values():
                    if (record["state"] == "pending" and record["tool"] != "stop"
                            and age - record["submitted_at_seconds"]
                            > self.request_deadline_seconds):
                        self.phase = "unconfirmed"
                        self.failure = "native_operation_deadline_exceeded"
                remaining = self.max_seconds - age
                if (remaining <= STOP_QUEUE_RESERVE_SECONDS
                        and self.phase == "ready" and not self.stop_id):
                    self._queue_stop_locked("host-deadline-stop")
                if age >= self.max_seconds and self.phase not in (
                        "stopped", "unconfirmed", "retiring"):
                    self.phase = "unconfirmed"
                    self.failure = "session_deadline_reached_before_retirement"
                if self.proc.poll() is not None:
                    self._read_receipts()
                    if not self._recover_owned_child_group_if_needed(
                            "launcher_exited"):
                        self.failure = (
                            self.failure
                            or "owned_child_cleanup_unconfirmed"
                        )
                    self._finish_locked()
                    return
            time.sleep(0.06)

    def _finish_locked(self) -> None:
        manifest_path = self.evidence / "manifest.json"
        manifest = {}
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            pass
        if (not self.failure and not self.partial and self.stop_id
                and self.requests[self.stop_id].get("receipt", {})
                .get("status") == "stopped" and manifest.get("stopped") is True
                and manifest.get("result") == "passed"
                and all(r["state"] == "complete" for r in self.requests.values())
                and self.proc.returncode == 0):
            self.phase = "stopped"
        else:
            self.phase = "unconfirmed"
            self.failure = self.failure or "process_exited_without_verified_retirement"
        for record in self.requests.values():
            if record["state"] == "pending":
                record["state"] = "unconfirmed"
                record["reason"] = "native_exit_without_matching_receipt"
        self.ready.set()

    def ingest(self, event: dict) -> None:
        """Only complete native JSONL lines enter here. Also testable in isolation."""
        with self.lock:
            if not isinstance(event, dict) or event.get("version") != 1:
                self.failure = "native_protocol_version_mismatch"
                self.phase = "unconfirmed"
                return
            if event.get("type") == "authorization":
                if event.get("status") == "authorized" and self.phase == "starting":
                    self.native_generation = event.get("result", {}).get("generation")
                    self.phase = "ready"
                else:
                    self.failure = "native_authorization_refused"
                    self.phase = "unconfirmed"
                self.ready.set()
                return
            if event.get("type") != "tool_result":
                return
            rid = self.by_seq.get(event.get("seq"))
            if rid is None:
                self.failure = "unmatched_native_receipt"
                self.phase = "unconfirmed"
                return
            record = self.requests[rid]
            if (event.get("tool") != record["tool"]
                    or not isinstance(event.get("result"), dict)
                    or event.get("status") != event["result"].get("status")):
                self.failure = "native_receipt_tool_or_status_mismatch"
                self.phase = "unconfirmed"
                return
            ticks = event.get("completed_native_ticks_total")
            if (type(ticks) is not int or not self.total_ticks <= ticks <= 480):
                self.failure = "native_receipt_tick_accounting_invalid"
                self.phase = "unconfirmed"
                return
            if record["state"] != "pending":
                self.failure = "duplicate_native_receipt"
                self.phase = "unconfirmed"
                return
            frame = event.get("frame", {})
            name = frame.get("path", "") if isinstance(frame, dict) else ""
            successful_frame_required = (
                (event.get("tool") == "observe" and event.get("status") == "observed")
                or (event.get("tool") == "step" and event.get("status") == "completed")
            )
            valid_original_frame = (
                isinstance(frame, dict)
                and frame.get("status") == "original_post_draw"
                and isinstance(name, str) and name.startswith("frames/")
                and FRAME_PATTERN.fullmatch(name.removeprefix("frames/"))
                and isinstance(frame.get("sha256"), str)
                and re.fullmatch(r"[0-9a-f]{64}", frame["sha256"]) is not None
            )
            if successful_frame_required and not valid_original_frame:
                self.failure = "successful_native_receipt_missing_original_frame_identity"
                self.phase = "unconfirmed"
                return
            if valid_original_frame:
                filename = name.removeprefix("frames/")
                if filename in self.frame_digests:
                    self.failure = "duplicate_original_frame_name"
                    self.phase = "unconfirmed"
                    return
                self.frames.add(filename)
                self.frame_digests[filename] = frame["sha256"]
            record["receipt"] = event
            record["state"] = "complete"
            record["finished_at_seconds"] = round(time.monotonic() - self.started, 3)
            owner_result = event.get("result", {})
            identity = owner_result.get("identity", {})
            if event.get("tool") == "step":
                identity = owner_result.get("observation", {}).get("identity", identity)
            if isinstance(identity, dict) and identity:
                self.last_identity = identity
            self.total_ticks = ticks
            if self.pending == rid:
                self.pending = None
            if event.get("tool") == "stop":
                if event.get("status") == "stopped":
                    self.phase = "retiring"
                else:
                    self.phase = "unconfirmed"
                    self.failure = "native_stop_not_acknowledged"

    def _command_stream_intact_locked(self) -> bool:
        try:
            content = self.commands.read_bytes()
        except OSError:
            self.phase = "unconfirmed"
            self.failure = "command_stream_unreadable"
            return False
        if (len(content) != self.command_bytes
                or hashlib.sha256(content).hexdigest()
                != self.command_hasher.hexdigest()):
            self.phase = "unconfirmed"
            self.failure = "command_stream_integrity_lost"
            return False
        return True

    def _append_command_locked(self, raw: bytes) -> bool:
        if not self._command_stream_intact_locked():
            return False
        try:
            with self.commands.open("ab") as stream:
                stream.write(raw)
                stream.flush()
                os.fsync(stream.fileno())
        except OSError:
            self.phase = "unconfirmed"
            self.failure = "command_stream_append_failed"
            return False
        self.command_hasher.update(raw)
        self.command_bytes += len(raw)
        return True

    def _queue_stop_locked(self, rid: str) -> bool:
        if self.stop_id or self.phase in ("stopped", "unconfirmed", "retiring"):
            return False
        command = {"version": 1, "seq": self.next_seq, "tool": "stop", "args": {}}
        raw = (json.dumps(command, separators=(",", ":"), ensure_ascii=True) + "\n").encode()
        if self.next_seq > MAX_COMMANDS or self.command_bytes + len(raw) > MAX_COMMAND_BYTES:
            self.phase = "unconfirmed"
            self.failure = "stop_cannot_be_enqueued_after_capacity"
            return False
        self.requests[rid] = {
            "id": rid, "fingerprint": None, "seq": self.next_seq,
            "state": "pending", "receipt": None, "tool": "stop",
            "submitted_at_seconds": round(time.monotonic() - self.started, 3),
        }
        self.by_seq[self.next_seq] = rid
        self.next_seq += 1
        self.stop_id = rid
        self.phase = "stopping"
        if not self._append_command_locked(raw):
            self.requests.pop(rid, None)
            self.by_seq.pop(self.next_seq - 1, None)
            self.stop_id = None
            return False
        return True

    def submit(self, document: dict) -> tuple[int, dict]:
        if not isinstance(document, dict) or set(document) != {
                "session_id", "request_id", "tool", "args"}:
            return 400, {"error": "invalid_request_envelope"}
        sid, rid, tool, args = (
            document["session_id"], document["request_id"],
            document["tool"], document["args"],
        )
        if not isinstance(sid, str) or sid != self.id:
            return 409, {"error": "stale_or_wrong_session"}
        if not isinstance(rid, str) or not ID_PATTERN.fullmatch(rid):
            return 400, {"error": "invalid_request_id"}
        if not isinstance(tool, str) or tool not in TOOLS or not isinstance(args, dict):
            return 400, {"error": "unsupported_tool_or_arguments"}
        if tool == "stop" and args:
            return 400, {"error": "stop_has_no_arguments"}
        fingerprint = hashlib.sha256(
            json.dumps({"tool": tool, "args": args}, sort_keys=True,
                       separators=(",", ":"), ensure_ascii=True).encode()
        ).hexdigest()
        with self.lock:
            if rid in self.requests:
                record = self.requests[rid]
                if record["fingerprint"] != fingerprint:
                    return 409, {"error": "idempotency_key_reused_with_different_command"}
                return self._describe_request_locked(rid)
            if self.phase not in ("ready", "stopping"):
                return 409, {"error": "session_not_accepting_commands", "phase": self.phase}
            if self.stop_id:
                return 409, {"error": "stop_already_queued"}
            if tool != "stop" and self.pending is not None:
                return 409, {"error": "operation_in_flight", "request_id": self.pending}
            remaining = self.max_seconds - (time.monotonic() - self.started)
            if tool != "stop" and remaining < self.request_deadline_seconds:
                return 429, {
                    "error": "session_deadline_too_close_for_new_operation",
                    "remaining_seconds": max(0, round(remaining, 2)),
                    "required_seconds": self.request_deadline_seconds,
                    "stop_required": True,
                }
            if tool != "stop" and (len(self.requests) >= MAX_COMMANDS - 1
                    or len(self.frames) >= MAX_FRAMES or
                    self._state_size() >= self.evidence_limit_bytes):
                return 429, {"error": "bounded_session_capacity_reached", "stop_required": True}
            command = {"version": 1, "seq": self.next_seq, "tool": tool, "args": args}
            raw = (json.dumps(command, separators=(",", ":"), ensure_ascii=True) + "\n").encode()
            if self.next_seq > MAX_COMMANDS or self.command_bytes + len(raw) > MAX_COMMAND_BYTES:
                return 429, {"error": "command_stream_capacity_reached", "stop_required": True}
            if tool == "stop":
                if not self._queue_stop_locked(rid):
                    return 503, {"error": self.failure or "stop_enqueue_failed"}
                self.requests[rid]["fingerprint"] = fingerprint
            else:
                self.requests[rid] = {
                    "id": rid, "fingerprint": fingerprint, "seq": self.next_seq,
                    "state": "pending", "receipt": None, "tool": tool,
                    "submitted_at_seconds": round(time.monotonic() - self.started, 3),
                }
                self.by_seq[self.next_seq] = rid
                self.next_seq += 1
                self.pending = rid
                if not self._append_command_locked(raw):
                    self.requests.pop(rid, None)
                    self.by_seq.pop(self.next_seq - 1, None)
                    self.pending = None
                    return 503, {"error": self.failure or "command_enqueue_failed"}
            return self._describe_request_locked(rid)

    def _state_size(self) -> int:
        total = 0
        if self.state_dir.is_dir():
            for file in self.state_dir.rglob("*"):
                if file.is_symlink() or not file.is_file():
                    continue
                try:
                    total += file.stat().st_size
                except OSError:
                    continue
                if total > self.state_hard_limit_bytes:
                    break
        self.last_evidence_bytes = total
        return total

    def _describe_request_locked(self, rid: str) -> tuple[int, dict]:
        record = self.requests[rid]
        status = 202 if record["state"] == "pending" else 200
        age = round(time.monotonic() - self.started, 3)
        return status, {
            "session_id": self.id, "request_id": rid, "seq": record["seq"],
            "state": record["state"], "receipt": record.get("receipt"),
            "reason": record.get("reason"), "session_phase": self.phase,
            "submitted_at_seconds": record.get("submitted_at_seconds"),
            "session_elapsed_seconds": age,
        }

    def request(self, rid: str) -> tuple[int, dict]:
        with self.lock:
            if rid not in self.requests:
                return 404, {"error": "unknown_request_id"}
            return self._describe_request_locked(rid)

    def _owner_health(self) -> dict:
        path = self.evidence / "session-health.json"
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
            return value if isinstance(value, dict) else {}
        except (OSError, ValueError, TypeError):
            return {}

    def snapshot(self) -> dict:
        with self.lock:
            return {
                "protocol": 1, "session_id": self.id,
                "generation_id": (self.id + ":" + str(self.native_generation)
                                  if self.native_generation is not None else None),
                "native_generation": self.native_generation,
                "phase": self.phase, "native_identity": self.last_identity,
                "completed_native_ticks_total": self.total_ticks,
                "commands_submitted": len(self.requests),
                "pending_request_id": self.pending, "stop_request_id": self.stop_id,
                "elapsed_seconds": round(time.monotonic() - self.started, 2),
                "remaining_seconds": max(0, round(self.max_seconds -
                                                 (time.monotonic() - self.started))),
                "request_deadline_seconds": self.request_deadline_seconds,
                "launcher_timeout_seconds": self.launcher_timeout_seconds,
                "launcher_cleanup_reserve_seconds": self.cleanup_reserve_seconds,
                "command_stream_bytes": self.command_bytes,
                "retained_frames": len(self.frames),
                "state_bytes": self._state_size(),
                "upstream_evidence_limit_bytes": self.evidence_limit_bytes,
                "state_hard_limit_bytes": self.state_hard_limit_bytes,
                "process_alive": bool(self.proc and self.proc.poll() is None),
                "owner_health": self._owner_health(),
                # Never send trusted launcher session/PID/PGID/start-tick
                # custody records through the model-visible HTTP status API.
                "custody_recovery": {
                    "state": self.custody_recovery.get("state", "not_checked"),
                    "owned_processes_exited": (
                        self.custody_recovery.get("owned_processes_exited")
                        if type(self.custody_recovery.get("owned_processes_exited"))
                        is bool else None
                    ),
                },
                "prior_session_recovery": self.prior_session_recovery.copy(),
                "failure": self.failure,
                "recovery": "none; restart creates a fresh World",
            }

    def frame(self, name: str) -> bytes | None:
        with self.lock:
            if not FRAME_PATTERN.fullmatch(name) or name not in self.frames:
                return None
            path = self.evidence / "frames" / name
            if (path.is_symlink() or not path.is_file()
                    or path.stat().st_size > MAX_FRAME_BYTES):
                return None
            data = path.read_bytes()
            if (not data.startswith(b"\x89PNG\r\n\x1a\n")
                    or hashlib.sha256(data).hexdigest() != self.frame_digests[name]):
                self.failure = "original_frame_integrity_lost"
                self.phase = "unconfirmed"
                return None
            return data

    def _read_host_json(self, name: str) -> dict:
        try:
            value = json.loads(
                (self.evidence / name).read_text(encoding="utf-8")
            )
            return value if isinstance(value, dict) else {}
        except (OSError, ValueError, TypeError):
            return {}

    def _recover_owned_child_group_if_needed(self, reason: str) -> bool:
        if self.proc is None:
            self.custody_recovery = {
                "state": "no_launcher", "reason": reason,
            }
            return True
        if self.proc.poll() is None:
            self.custody_recovery = {
                "state": "launcher_alive", "reason": reason,
            }
            return True
        ok, report = recover_host_custody(
            self.run_contract,
            self._read_host_json("launcher-identity.json"),
            self._read_host_json("launcher-process.json"),
            reason,
            expected_launcher_pid=self.proc.pid,
        )
        self.custody_recovery = report
        return ok

    def _process_group_alive(self) -> bool:
        if self.proc is None:
            return False
        try:
            os.killpg(self.proc.pid, 0)
            return True
        except ProcessLookupError:
            return False
        except PermissionError:
            return True

    def _terminate_launcher_group(self) -> None:
        """Signal run.py, then give its own child-cleanup contract time to finish."""
        if not self._process_group_alive():
            return
        try:
            os.killpg(self.proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        deadline = time.monotonic() + self.cleanup_reserve_seconds
        while time.monotonic() < deadline and self._process_group_alive():
            time.sleep(0.05)
        if self._process_group_alive():
            try:
                os.killpg(self.proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            deadline = time.monotonic() + KILL_GRACE_SECONDS
            while time.monotonic() < deadline and self._process_group_alive():
                time.sleep(0.05)

    def close(self) -> None:
        with self.lock:
            if self.proc and self.proc.poll() is None and not self.stop_id:
                self._queue_stop_locked("host-shutdown-stop")
        if self.proc:
            if self.proc.poll() is None:
                try:
                    self.proc.wait(timeout=STOP_GRACE_SECONDS)
                except subprocess.TimeoutExpired:
                    pass
            self._read_receipts()
            if self._process_group_alive():
                with self.lock:
                    self.phase = "unconfirmed"
                    self.failure = (
                        self.failure
                        or "forced_termination_native_retirement_unconfirmed"
                    )
                self._terminate_launcher_group()
            if self.proc.poll() is not None:
                with self.lock:
                    if not self._recover_owned_child_group_if_needed(
                            "service_close"):
                        self.phase = "unconfirmed"
                        self.failure = (
                            self.failure or "owned_child_cleanup_unconfirmed"
                        )
            if hasattr(self, "monitor"):
                self.monitor.join(timeout=1)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    server_version = "CyberSandWorkBench/1"

    def log_message(self, fmt: str, *args) -> None:
        # Do not log paths, tokens, headers, query strings or native receipts.
        return

    def _json(self, code: int, value: dict) -> None:
        payload = json.dumps(value, separators=(",", ":"), ensure_ascii=True).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(payload)

    def _authorized(self) -> bool:
        raw = self.headers.get("Authorization", "")
        expected = self.server.token
        if not raw.startswith("Bearer ") or not hmac.compare_digest(
                raw[7:].encode("utf-8"), expected):
            self._json(401, {"error": "bearer_authentication_required"})
            return False
        return True

    def do_GET(self) -> None:
        if not self._authorized():
            return
        path = urlsplit(self.path).path
        if path == "/v1/session":
            self._json(200, self.server.session.snapshot())
        elif path.startswith("/v1/requests/"):
            rid = unquote(path[len("/v1/requests/"):])
            if not ID_PATTERN.fullmatch(rid):
                self._json(400, {"error": "invalid_request_id"})
                return
            code, answer = self.server.session.request(rid)
            self._json(code, answer)
        elif path.startswith("/v1/frames/"):
            name = unquote(path[len("/v1/frames/"):])
            content = self.server.session.frame(name)
            if content is None:
                self._json(404, {"error": "unknown_or_unavailable_original_png"})
                return
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(content)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(content)
        else:
            self._json(404, {"error": "unknown_endpoint"})

    def do_POST(self) -> None:
        if not self._authorized():
            return
        if urlsplit(self.path).path != "/v1/commands":
            self._json(404, {"error": "unknown_endpoint"})
            return
        try:
            size = int(self.headers.get("Content-Length", "-1"))
        except ValueError:
            size = -1
        if not 2 <= size <= MAX_REQUEST:
            self._json(413, {"error": "invalid_or_oversized_request"})
            return
        try:
            def reject_non_json_number(value: str):
                raise ValueError("Non-JSON numeric token")
            data = json.loads(self.rfile.read(size), parse_constant=reject_non_json_number)
        except (ValueError, UnicodeError, RecursionError):
            self._json(400, {"error": "invalid_json"})
            return
        code, value = self.server.session.submit(data)
        self._json(code, value)


class BoundedServer(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 8

    def __init__(self, address, token: bytes, session: Session):
        self.token = token
        self.session = session
        self.slots = threading.BoundedSemaphore(8)
        super().__init__(address, Handler)

    def process_request(self, request, client_address) -> None:
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except BaseException:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address) -> None:
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--authorization", type=Path, required=True)
    parser.add_argument("--token-file", type=Path, required=True)
    parser.add_argument("--state-root", type=Path, required=True)
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--xvfb", action="store_true")
    parser.add_argument("--seconds", type=int, default=1740)
    args = parser.parse_args()
    if args.bind != "127.0.0.1":
        parser.error("bind must be 127.0.0.1; use authenticated gh port forwarding")
    if not 1024 <= args.port <= 65535:
        parser.error("port outside [1024,65535]")
    token = token_from_file(args.token_file)
    root = args.state_root.expanduser().resolve()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(root, 0o700)
    try:
        prior_recovery = reconcile_prior_sessions(root)
    except RuntimeError as error:
        print(json.dumps({
            "error": "prior_session_cleanup_unconfirmed",
            "detail": str(error),
        }, sort_keys=True), flush=True)
        return 2
    session = Session(root / ("session-" + secrets.token_hex(12)),
                      args.authorization, args.godot, xvfb=args.xvfb,
                      max_seconds=args.seconds, spawn=False)
    session.prior_session_recovery = prior_recovery
    shutdown_requested = False

    def request_shutdown(_signum, _frame) -> None:
        nonlocal shutdown_requested
        shutdown_requested = True

    previous_handlers = {
        signum: signal.signal(signum, request_shutdown)
        for signum in (signal.SIGINT, signal.SIGTERM)
    }
    try:
        # Bind the private ingress before starting run.py/Godot. A port conflict
        # must never leave a native session running with no reachable supervisor.
        with BoundedServer((args.bind, args.port), token, session) as server:
            server.timeout = 1
            session.start()
            print("REMOTE_WB_HTTP_LISTENING port=%d session_id=%s phase=%s (no credentials logged)"
                  % (args.port, session.id, session.phase), flush=True)
            try:
                while (not shutdown_requested
                       and session.phase not in ("stopped", "unconfirmed")):
                    server.handle_request()
                if not shutdown_requested:
                    # Preserve a brief read-only window after the owner has
                    # reached a verified terminal state. submit() already
                    # refuses both phases.
                    terminal_deadline = (
                        time.monotonic() + TERMINAL_STATUS_GRACE_SECONDS
                    )
                    server.timeout = 0.25
                    while time.monotonic() < terminal_deadline:
                        server.handle_request()
            finally:
                # SIGINT/SIGTERM, including container/Codespace stop, enters the
                # same bounded native Stop/launcher cleanup path as normal exit.
                session.close()
                print("REMOTE_WB_HTTP_FINAL " + json.dumps(session.snapshot()),
                      flush=True)
    finally:
        for signum, handler in previous_handlers.items():
            signal.signal(signum, handler)
    return 0 if session.phase == "stopped" else 1


if __name__ == "__main__":
    raise SystemExit(main())
