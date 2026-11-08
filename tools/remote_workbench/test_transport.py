#!/usr/bin/env python3
"""Pure transport regressions using the real HTTP server and a separate client process.

These tests do not claim native/Godot qualification. They exercise authentication,
idempotency, reconnect, session fencing, Stop queueing, stream integrity and the
remote authorization boundary without starting a simulation.
"""
from __future__ import annotations

import json
import hashlib
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import serve

CLIENT = HERE / "client.py"


class TransportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        authorization = self.root / "authorization.json"
        self.auth = authorization
        authorization.write_text(json.dumps({
            "version": 1,
            "task_id": "transport-test",
            "extent": [512, 512],
            "scope": {"x": 0, "y": 0, "width": 64, "height": 64},
            "protected": [],
            "allowed_materials": [0, 58],
            "start_edits": [],
            "camera_origin": [0, 0],
        }), encoding="utf-8")
        self.session = serve.Session(
            self.root / "session", authorization, Path(sys.executable),
            xvfb=False, max_seconds=600, spawn=False,
        )
        self.session.phase = "ready"
        self.session.native_generation = 71
        self.token = "T" * 48
        self.token_file = self.root / "token"
        self.token_file.write_text(self.token + "\n", encoding="utf-8")
        os.chmod(self.token_file, 0o600)
        self.server = serve.BoundedServer(
            ("127.0.0.1", 0), self.token.encode(), self.session
        )
        self.thread = threading.Thread(
            target=self.server.serve_forever, daemon=True
        )
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temporary.cleanup()

    def client(self, *args: str, token_file: Path | None = None,
               base: str | None = None) -> tuple[int, dict]:
        process = subprocess.run(
            [
                sys.executable, str(CLIENT),
                "--base", base or self.base,
                "--token-file", str(token_file or self.token_file),
                "--deadline", "2",
                *args,
            ],
            capture_output=True, text=True, timeout=10, check=False,
        )
        try:
            payload = json.loads(process.stdout)
        except (ValueError, TypeError):
            payload = {"raw": process.stdout, "stderr": process.stderr}
        return process.returncode, payload

    def ingest(self, *, seq: int, tool: str = "observe",
               status: str = "observed") -> None:
        frame = {"status": "none"}
        if (tool == "observe" and status == "observed") or (
                tool == "step" and status == "completed"):
            frame = {
                "status": "original_post_draw",
                "path": f"frames/{seq:03d}-{tool}.png",
                "sha256": "0" * 64,
            }
        self.session.ingest({
            "version": 1,
            "type": "tool_result",
            "seq": seq,
            "tool": tool,
            "status": status,
            "result": {
                "status": status,
                "identity": {"generation": 71, "completed_tick": 0},
            },
            "frame": frame,
            "completed_native_ticks_total": 0,
        })

    def test_external_client_auth_duplicate_and_reconnect(self) -> None:
        wrong = self.root / "wrong-token"
        wrong.write_text("B" * 48 + "\n", encoding="utf-8")
        os.chmod(wrong, 0o600)
        code, payload = self.client("session", token_file=wrong)
        self.assertNotEqual(code, 0)
        self.assertEqual(payload["error"], "bearer_authentication_required")

        code, payload = self.client("session")
        self.assertEqual(code, 0)
        session_id = payload["session_id"]
        request_id = "req-duplicate01"

        code, payload = self.client(
            "call", "observe", "--session", session_id,
            "--request-id", request_id, "--args", "{}", "--no-wait",
        )
        self.assertEqual(code, 0)
        self.assertEqual(payload["state"], "pending")
        before = self.session.commands.read_bytes()

        code, payload = self.client(
            "call", "observe", "--session", session_id,
            "--request-id", request_id, "--args", "{}", "--no-wait",
        )
        self.assertEqual(code, 0)
        self.assertEqual(self.session.commands.read_bytes(), before)

        code, payload = self.client(
            "call", "observe", "--session", session_id,
            "--request-id", request_id,
            "--args", '{"detail":"different"}', "--no-wait",
        )
        self.assertNotEqual(code, 0)
        self.assertEqual(
            payload["error"], "idempotency_key_reused_with_different_command"
        )

        self.ingest(seq=1)
        code, payload = self.client("request", request_id)
        self.assertEqual(code, 0)
        self.assertEqual(payload["state"], "complete")

    def test_stop_can_queue_behind_outstanding_operation(self) -> None:
        session_id = self.session.id
        code, _ = self.client(
            "call", "observe", "--session", session_id,
            "--request-id", "req-pending001", "--args", "{}", "--no-wait",
        )
        self.assertEqual(code, 0)
        code, payload = self.client(
            "call", "stop", "--session", session_id,
            "--request-id", "req-stop00001", "--args", "{}", "--no-wait",
        )
        self.assertEqual(code, 0)
        self.assertEqual(payload["state"], "pending")
        lines = self.session.commands.read_text(encoding="utf-8").splitlines()
        self.assertEqual([json.loads(line)["tool"] for line in lines],
                         ["observe", "stop"])

        self.ingest(seq=1)
        self.session.ingest({
            "version": 1,
            "type": "tool_result",
            "seq": 2,
            "tool": "stop",
            "status": "stopped",
            "result": {"status": "stopped"},
            "frame": {"status": "none"},
            "completed_native_ticks_total": 0,
        })
        self.assertEqual(self.session.phase, "retiring")

    def test_stream_integrity_failure_is_truthful(self) -> None:
        self.session.commands.write_text("tampered\n", encoding="utf-8")
        code, payload = self.client(
            "call", "observe", "--session", self.session.id,
            "--request-id", "req-integrity1", "--args", "{}", "--no-wait",
        )
        self.assertNotEqual(code, 0)
        self.assertIn(payload.get("error"), {
            "command_stream_integrity_lost", "session_not_accepting_commands",
        })
        self.assertEqual(self.session.phase, "unconfirmed")

    def test_deadline_admission_and_total_state_limit_are_truthful(self) -> None:
        # No new work is admitted when the remaining session cannot contain the
        # complete policy-derived request deadline. Stop remains separately usable.
        self.session.started = (
            time.monotonic()
            - (self.session.max_seconds - self.session.request_deadline_seconds + 1)
        )
        code, payload = self.client(
            "call", "observe", "--session", self.session.id,
            "--request-id", "req-deadline01", "--args", "{}", "--no-wait",
        )
        self.assertNotEqual(code, 0)
        self.assertEqual(
            payload["error"], "session_deadline_too_close_for_new_operation"
        )
        self.assertTrue(payload["stop_required"])

        # Reset time, then force the transport's complete-state accounting over
        # its bounded ceiling. This is a transport refusal, not native evidence.
        self.session.started = time.monotonic()
        self.session.evidence_limit_bytes = 1024
        self.session.state_hard_limit_bytes = 2048
        evidence = self.session.evidence
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "synthetic-capacity.dat").write_bytes(b"x" * 1100)
        code, payload = self.client(
            "call", "observe", "--session", self.session.id,
            "--request-id", "req-capacity01", "--args", "{}", "--no-wait",
        )
        self.assertNotEqual(code, 0)
        self.assertEqual(payload["error"], "bounded_session_capacity_reached")
        self.assertTrue(payload["stop_required"])

    def test_external_login_redirect_and_html_are_not_api_success(self) -> None:
        class FakeGithubLogin(BaseHTTPRequestHandler):
            attempts = []
            mode = "redirect"

            def log_message(self, *args):
                return

            def do_GET(self):
                self.__class__.attempts.append(self.path)
                if self.__class__.mode == "redirect":
                    self.send_response(302)
                    self.send_header("Location", "http://127.0.0.1:%d/stolen-token"
                                     % self.server.server_port)
                    self.end_headers()
                else:
                    message = b"<html>Sign in to GitHub</html>"
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html")
                    self.send_header("Content-Length", str(len(message)))
                    self.end_headers()
                    self.wfile.write(message)

        other = ThreadingHTTPServer(("127.0.0.1", 0), FakeGithubLogin)
        background = threading.Thread(target=other.serve_forever, daemon=True)
        background.start()
        try:
            external = "http://127.0.0.1:%d" % other.server_port
            code, result = self.client("session", base=external)
            self.assertNotEqual(code, 0)
            self.assertEqual(result["error"], "unexpected_redirect_not_workbench_api")
            self.assertEqual(FakeGithubLogin.attempts, ["/v1/session"])
            FakeGithubLogin.mode = "html"
            code, result = self.client("session", base=external)
            self.assertNotEqual(code, 0)
            self.assertEqual(result["error"],
                             "unexpected_content_type_not_workbench_api")
            self.assertEqual(FakeGithubLogin.attempts,
                             ["/v1/session", "/v1/session"])
        finally:
            other.shutdown()
            other.server_close()
            background.join(timeout=3)

    def test_client_never_sends_token_to_unapproved_remote_origin(self) -> None:
        for bad in ("https://other.example:8765",
                    "https://example-8765.app.github.dev",
                    "http://user:password@127.0.0.1:8765",
                    "http://127.0.0.1:8765/prefix",
                    "http://127.0.0.2:8765"):
            code, result = self.client("session", base=bad)
            self.assertNotEqual(code, 0)
            self.assertEqual(result["error"],
                             "client_requires_loopback_gh_codespace_port_tunnel")

    def test_bad_native_receipt_is_not_an_acknowledged_edit(self) -> None:
        code, result = self.client(
            "call", "apply_edit", "--session", self.session.id,
            "--request-id", "req-apply-001", "--args",
            '{"proposal_id":"native-proposal-stale"}', "--no-wait",
        )
        self.assertEqual(code, 0)
        self.session.ingest({
            "version": 1, "type": "tool_result", "seq": 1, "tool": "observe",
            "status": "applied", "result": {"status": "applied"},
            "completed_native_ticks_total": 0, "frame": {"status": "none"},
        })
        self.assertEqual(self.session.phase, "unconfirmed")
        self.assertEqual(self.session.failure, "native_receipt_tool_or_status_mismatch")

    def test_original_frame_sha256_is_checked_against_native_receipt(self) -> None:
        file = self.session.evidence / "frames" / "001-observe.png"
        file.parent.mkdir(parents=True)
        original = b"\x89PNG\r\n\x1a\n" + b"retained-original-test"
        file.write_bytes(original)
        self.session.frames.add(file.name)
        self.session.frame_digests[file.name] = hashlib.sha256(original).hexdigest()
        self.assertEqual(self.session.frame(file.name), original)
        file.write_bytes(original + b"tampered")
        self.assertIsNone(self.session.frame(file.name))
        self.assertEqual(self.session.failure, "original_frame_integrity_lost")
        self.assertEqual(self.session.phase, "unconfirmed")

    def test_stale_generation_fence_and_duplicate_mutation_envelope(self) -> None:
        code, first = self.client(
            "call", "apply_edit", "--session", self.session.id,
            "--request-id", "req-apply-dupe",
            "--args", '{"proposal_id":"old-proposal"}', "--no-wait",
        )
        self.assertEqual(code, 0)
        original_stream = self.session.commands.read_bytes()
        code, again = self.client(
            "call", "apply_edit", "--session", self.session.id,
            "--request-id", "req-apply-dupe",
            "--args", '{"proposal_id":"old-proposal"}', "--no-wait",
        )
        self.assertEqual(code, 0)
        self.assertEqual(first["seq"], again["seq"])
        self.assertEqual(original_stream, self.session.commands.read_bytes())
        self.session.id = "restarted-session-new-world"
        code, rejected = self.client(
            "call", "apply_edit", "--session", first["session_id"],
            "--request-id", "req-stale-after-restart",
            "--args", '{"proposal_id":"old-proposal"}', "--no-wait",
        )
        self.assertNotEqual(code, 0)
        self.assertEqual(rejected["error"], "stale_or_wrong_session")

    def test_native_refusal_returns_nonzero_to_external_agent(self) -> None:
        code, reply = self.client(
            "call", "apply_edit", "--session", self.session.id,
            "--request-id", "req-native-refusal",
            "--args", '{"proposal_id":"stale-proposal"}', "--no-wait",
        )
        self.assertEqual(code, 0)
        self.session.ingest({
            "version": 1, "type": "tool_result", "seq": reply["seq"],
            "tool": "apply_edit", "status": "refused",
            "result": {"status": "refused", "reason": "stale_revision"},
            "frame": {"status": "none"}, "completed_native_ticks_total": 0,
        })
        code, result = self.client("request", "req-native-refusal")
        self.assertNotEqual(code, 0)
        self.assertEqual(result["receipt"]["status"], "refused")
        self.assertEqual(result["receipt"]["result"]["reason"], "stale_revision")

    def test_malformed_tool_type_is_client_refusal_not_server_exception(self) -> None:
        request = Request(
            self.base + "/v1/commands",
            data=json.dumps({
                "session_id": self.session.id,
                "request_id": "req-malformed-tool",
                "tool": {"object": "unhashable"},
                "args": {},
            }).encode("utf-8"),
            headers={"Authorization": "Bearer " + self.token,
                     "Content-Type": "application/json"},
            method="POST",
        )
        with self.assertRaises(HTTPError) as caught:
            urlopen(request, timeout=2)
        self.assertEqual(caught.exception.code, 400)
        self.assertEqual(self.session.commands.read_bytes(), b"")

    def test_port_conflict_fails_before_upstream_launcher_spawn(self) -> None:
        occupied = ThreadingHTTPServer(("127.0.0.1", 0), BaseHTTPRequestHandler)
        state_root = self.root / "port-conflict-state"
        try:
            process = subprocess.run(
                [
                    sys.executable, str(HERE / "serve.py"),
                    "--godot", sys.executable,
                    "--authorization", str(self.auth),
                    "--token-file", str(self.token_file),
                    "--state-root", str(state_root),
                    "--seconds", "600",
                    "--bind", "127.0.0.1",
                    "--port", str(occupied.server_port),
                ],
                capture_output=True, text=True, timeout=10, check=False,
            )
            self.assertNotEqual(process.returncode, 0)
            sessions = list(state_root.glob("session-*"))
            self.assertEqual(len(sessions), 1)
            self.assertFalse(
                (sessions[0] / "supervisor.log").exists(),
                "port bind failure spawned upstream launcher before ingress",
            )
        finally:
            occupied.server_close()

    def test_non_object_native_jsonl_line_is_fatal(self) -> None:
        self.session.evidence.mkdir(parents=True, exist_ok=True)
        (self.session.evidence / "results.jsonl").write_text(
            "[]\n", encoding="utf-8"
        )
        self.session._read_receipts()
        self.assertEqual(self.session.phase, "unconfirmed")
        self.assertEqual(self.session.failure, "malformed_native_receipt")

    def test_successful_observe_requires_original_frame_identity(self) -> None:
        code, pending = self.client(
            "call", "observe", "--session", self.session.id,
            "--request-id", "req-frame-required", "--args", "{}", "--no-wait",
        )
        self.assertEqual(code, 0)
        self.session.ingest({
            "version": 1,
            "type": "tool_result",
            "seq": pending["seq"],
            "tool": "observe",
            "status": "observed",
            "result": {
                "status": "observed",
                "identity": {"generation": 71, "completed_tick": 0},
            },
            "frame": {"status": "none"},
            "completed_native_ticks_total": 0,
        })
        self.assertEqual(self.session.phase, "unconfirmed")
        self.assertEqual(
            self.session.failure,
            "successful_native_receipt_missing_original_frame_identity",
        )
        self.assertEqual(
            self.session.requests["req-frame-required"]["state"], "pending"
        )

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux /proc custody")
    def test_verified_host_custody_reaps_orphaned_child_group(self) -> None:
        if not hasattr(self.session.run_contract, "linux_start_ticks"):
            self.skipTest("final corrected #545 custody seam not yet composed")
        launcher = subprocess.Popen(
            [sys.executable, "-c", "pass"], start_new_session=True
        )
        launcher.wait(timeout=5)
        child = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(60)"],
            start_new_session=True,
        )
        try:
            ticks = self.session.run_contract.linux_start_ticks(child.pid)
            self.assertIsInstance(ticks, int)
            self.session.proc = launcher
            self.session.evidence.mkdir(parents=True, exist_ok=True)
            (self.session.evidence / "launcher-identity.json").write_text(
                json.dumps({"session_id": "owner-session-custody"}) + "\n",
                encoding="utf-8",
            )
            (self.session.evidence / "launcher-process.json").write_text(
                json.dumps({
                    "version": 1,
                    "session_id": "owner-session-custody",
                    "launcher_pid": launcher.pid,
                    "child_pid": child.pid,
                    "owned_process_group": child.pid,
                    "group_leader_start_ticks": ticks,
                    "state": "running",
                    "host_only": True,
                }) + "\n",
                encoding="utf-8",
            )
            self.assertTrue(
                self.session._recover_owned_child_group_if_needed("test_orphan")
            )
            child.wait(timeout=5)
            self.assertEqual(
                self.session.custody_recovery["state"],
                "recovered_orphaned_owned_group",
            )
            self.assertTrue(
                self.session.custody_recovery["owned_processes_exited"]
            )
        finally:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=5)

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux /proc custody")
    def test_custody_start_time_mismatch_never_signals_process_group(self) -> None:
        if not hasattr(self.session.run_contract, "linux_start_ticks"):
            self.skipTest("final corrected #545 custody seam not yet composed")
        launcher = subprocess.Popen(
            [sys.executable, "-c", "pass"], start_new_session=True
        )
        launcher.wait(timeout=5)
        child = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(60)"],
            start_new_session=True,
        )
        try:
            ticks = self.session.run_contract.linux_start_ticks(child.pid)
            self.assertIsInstance(ticks, int)
            self.session.proc = launcher
            self.session.evidence.mkdir(parents=True, exist_ok=True)
            (self.session.evidence / "launcher-identity.json").write_text(
                json.dumps({"session_id": "owner-session-mismatch"}) + "\n",
                encoding="utf-8",
            )
            (self.session.evidence / "launcher-process.json").write_text(
                json.dumps({
                    "version": 1,
                    "session_id": "owner-session-mismatch",
                    "launcher_pid": launcher.pid,
                    "child_pid": child.pid,
                    "owned_process_group": child.pid,
                    "group_leader_start_ticks": ticks + 1,
                    "state": "running",
                    "host_only": True,
                }) + "\n",
                encoding="utf-8",
            )
            self.assertFalse(
                self.session._recover_owned_child_group_if_needed(
                    "test_identity_mismatch"
                )
            )
            self.assertIsNone(child.poll())
            self.assertEqual(
                self.session.custody_recovery["state"],
                "unconfirmed_process_identity_mismatch",
            )
        finally:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=5)

    def test_restart_preflight_blocks_unconfirmed_prior_launched_session(self) -> None:
        root = self.root / "restart-block"
        old = root / "session-old"
        evidence = old / "evidence"
        evidence.mkdir(parents=True)
        (old / "supervisor.log").write_bytes(b"launcher-started\n")
        with self.assertRaisesRegex(
                RuntimeError, "prior_session_cleanup_unconfirmed"):
            serve.reconcile_prior_sessions(root)

    def test_restart_preflight_accepts_prelaunch_and_terminal_remnants(self) -> None:
        root = self.root / "restart-clean"
        prelaunch = root / "session-prelaunch"
        prelaunch.mkdir(parents=True)
        (prelaunch / "commands.jsonl").write_text("", encoding="utf-8")
        terminal = root / "session-terminal"
        evidence = terminal / "evidence"
        evidence.mkdir(parents=True)
        (terminal / "supervisor.log").write_bytes(b"finished\n")
        (evidence / "cleanup-result.json").write_text(
            json.dumps({"owned_processes_exited": True}) + "\n",
            encoding="utf-8",
        )
        summary = serve.reconcile_prior_sessions(root)
        self.assertEqual(summary["scanned"], 2)
        self.assertEqual(summary["already_terminal_or_prelaunch"], 2)
        self.assertEqual(summary["recovered_owned_groups"], 0)

    def test_host_only_custody_pid_is_never_exposed_to_agent_status(self) -> None:
        self.session.custody_recovery = {
            "state": "recovered_orphaned_owned_group",
            "session_id": "secret-host-owner-session",
            "launcher_pid": 90821,
            "owned_process_group": 90822,
            "group_leader_start_ticks": 198001,
            "owned_processes_exited": True,
        }
        code, status = self.client("session")
        self.assertEqual(code, 0)
        serialized = json.dumps(status)
        for private in ("secret-host-owner-session", "90821", "90822",
                        "198001", "owned_process_group",
                        "group_leader_start_ticks"):
            self.assertNotIn(private, serialized)
        self.assertEqual(status["custody_recovery"]["state"],
                         "recovered_orphaned_owned_group")
        self.assertTrue(status["custody_recovery"]["owned_processes_exited"])

    def test_authorization_not_exposed_and_stale_session_refused(self) -> None:
        request = Request(
            self.base + "/v1/authorization",
            headers={"Authorization": "Bearer " + self.token},
        )
        with self.assertRaises(HTTPError) as caught:
            urlopen(request, timeout=2)
        self.assertEqual(caught.exception.code, 404)

        old_session = self.session.id
        self.session.id = "new-session-12345678"
        code, payload = self.client(
            "call", "observe", "--session", old_session,
            "--request-id", "req-stale0001", "--args", "{}", "--no-wait",
        )
        self.assertNotEqual(code, 0)
        self.assertEqual(payload["error"], "stale_or_wrong_session")


if __name__ == "__main__":
    unittest.main(verbosity=2)
