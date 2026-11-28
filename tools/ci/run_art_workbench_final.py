"""Keyless Art Workbench failure/lifecycle matrix using the real Godot host.

Only loopback sockets are opened. Every Godot invocation receives a new isolated
profile; the fixture never reads an owner's provider settings or contacts a
model service. --graphical exercises rendered, embedded Godot windows with
InputEventMouseButton routing. That is not a physical Windows/NVIDIA mouse test.
"""
from __future__ import annotations

import argparse
import hashlib
import http.server
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
MARKER = "ART_WORKBENCH_FINAL_RESULT "
ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")
CANARY = "art-fixture-private-key::2026-QA"
MAX_RESPONSE = 16 * 1024 * 1024
# Software-rendered Windows evidence measured about five process frames per
# second. Each bounded HTTPRequest body read needs a frame; these process
# ceilings cover all existing native readback/lifecycle work as well as larger
# fixture transport budgets. Application frame and complete-body gates remain
# independent and unchanged.
DEFAULT_WATCHDOG_SECONDS = 300
GRAPHICAL_WATCHDOG_SECONDS = {"network":600, "preparation":900, "all":2400}
MODELS = {"fixture-valid", "fixture-invalid", "fixture-delayed", "fixture-delayed-draw",
          "fixture-drop", "fixture-timeout", "fixture-secret-boundary", "fixture-malformed",
          "fixture-oversized", "fixture-large", "fixture-large-error", "fixture-large-envelope-error",
          "fixture-draw", "fixture-bad-drawing", "fixture-context", "fixture-near-limit", "fixture-malicious-usage", "fixture-blackhole-stop",
          "fixture-blackhole-timeout", "fixture-blackhole-shutdown", "fixture-large-assistant",
          "fixture-preparation-hide", "fixture-preparation-stop", "fixture-preparation-world",
          "fixture-preparation-shutdown", "fixture-preparation-exit", "fixture-outgoing-visible",
          "fixture-outgoing-hide", "fixture-outgoing-stop", "fixture-outgoing-near-limit",
          "fixture-outgoing-world", "fixture-outgoing-shutdown", "fixture-outgoing-exit"}


def identity(path: Path) -> dict:
    return {"path": str(path), "size": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def process_watchdog(group: str, graphical: bool, requested: int | None) -> dict:
    if requested is not None and requested <= 0:
        raise ValueError("--timeout must be a positive number of seconds")
    default = GRAPHICAL_WATCHDOG_SECONDS.get(group, DEFAULT_WATCHDOG_SECONDS) if graphical else DEFAULT_WATCHDOG_SECONDS
    return {"seconds":requested if requested is not None else default,
            "source":"explicit_override" if requested is not None else "finite_group_default",
            "group":group,"graphical":graphical,"ordinary_default_seconds":DEFAULT_WATCHDOG_SECONDS,
            "graphical_group_defaults_seconds":GRAPHICAL_WATCHDOG_SECONDS}


def resource_snapshot() -> dict:
    """Best-effort resource evidence; absence never becomes an OOM diagnosis."""
    result = {}
    if sys.platform == "linux":
        try:
            import resource
            result["max_child_rss_kib"] = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
        except (ImportError, OSError) as error:
            result["max_child_rss_unavailable"] = str(error)
        for name in ("memory.events", "memory.current", "memory.max"):
            try:
                result[name] = (Path("/sys/fs/cgroup") / name).read_text()
            except OSError as error:
                result[name] = {"unavailable": str(error)}
        try:
            result["host_memory"] = [line for line in Path("/proc/meminfo").read_text().splitlines()
                                     if line.startswith(("MemTotal:", "MemAvailable:", "SwapFree:"))]
        except OSError as error:
            result["host_memory"] = {"unavailable": str(error)}
    else:
        result["scope"] = "Linux cgroup/RUSAGE counters unavailable on this platform"
    return result


def git_identity(root: Path) -> dict:
    def git(*args: str) -> str:
        return subprocess.check_output(["git", *args], cwd=root, text=True).strip()
    return {"head": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
            "changed_paths": git("diff", "--name-only").splitlines(),
            "diff_sha256": hashlib.sha256(subprocess.check_output(
                ["git", "diff", "--", "godot/scripts", "godot/tests/run_art_workbench_final.gd",
                 "tools/ci/run_art_workbench_final.py"], cwd=root)).hexdigest()}


class Fixture(http.server.ThreadingHTTPServer):
    daemon_threads = True
    block_on_close = False

    def __init__(self, output: Path):
        super().__init__(("127.0.0.1", 0), Handler)
        self.receipts: list[dict] = []
        self.lock = threading.Lock()
        self.release_blackhole = threading.Event()
        self.accepted_dir = output / "received-requests"
        self.accepted_dir.mkdir()
        self.post_arrival_dir = output / "post-arrivals"
        self.post_arrival_dir.mkdir()
        self.post_arrival_count = 0


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_POST(self):
        if self.client_address[0] != "127.0.0.1":
            self.send_error(403)
            return
        # Record arrival before rejecting oversized, malformed or aborted
        # bodies. These empty markers retain no request content or headers.
        with self.server.lock:
            self.server.post_arrival_count += 1
            (self.server.post_arrival_dir / f"post-arrival-{self.server.post_arrival_count}").touch(exist_ok=False)
        size = int(self.headers.get("Content-Length", "0"))
        if not 0 < size <= 4 * 1024 * 1024 or self.path != "/v1/chat/completions":
            self.send_error(400)
            return
        try:
            request = json.loads(self.rfile.read(size))
            model = request["model"]
            if model not in MODELS:
                self.send_error(400)
                return
            # Never retain prompts, complete headers, endpoint settings or keys.
            receipt = {"model": model, "request_bytes": size,
                       "authorization_canary_matches": self.headers.get("Authorization") == "Bearer " + CANARY}
            with self.server.lock:
                self.server.receipts.append(receipt)
            (self.server.accepted_dir / model).touch()
            if model.startswith("fixture-blackhole-"):
                receipt["outcome"] = "post_received_no_headers_or_body_returned"
                self.server.release_blackhole.wait(60)
                self.close_connection = True
                return
            if model in ("fixture-delayed", "fixture-delayed-draw", "fixture-drop"):
                time.sleep(0.45)
            if model == "fixture-timeout":
                time.sleep(3.0)
            if model == "fixture-drop":
                self.close_connection = True
                receipt["outcome"] = "connected_then_closed_without_http"
                return
            code = 200
            if model in ("fixture-invalid", "fixture-large-error", "fixture-large-envelope-error"):
                code = 404
                padding = 4096 if model == "fixture-invalid" else 1024 * 1024
                if model == "fixture-large-envelope-error":
                    code = 200
                payload = json.dumps({"error": {"message": "Invalid synthetic local model " + "x" * padding}}).encode()
            elif model == "fixture-secret-boundary":
                code = 404
                payload = ("x" * 500 + CANARY + " END-OF-COMPLETE-REDACTED-ERROR").encode()
            elif model == "fixture-malformed":
                payload = b'{"choices": [this is not valid JSON'
            elif model == "fixture-oversized":
                payload = b"x" * (MAX_RESPONSE + 1024)
            else:
                content = "[]"
                if model in ("fixture-draw", "fixture-delayed-draw") or model.startswith("fixture-preparation-"):
                    content = '[{"shape":"rectangle","x0":20,"y0":20,"x1":31,"y1":31,"material":58}]'
                elif model == "fixture-bad-drawing":
                    content = "{broken drawing packet"
                elif model == "fixture-large-assistant":
                    content = "[]" + " " * (MAX_RESPONSE - 4096)
                packet = {"model": "synthetic-loopback-alias", "choices": [{"message": {"content": content}, "finish_reason": "stop"}],
                          "usage": {"prompt_tokens": 20, "completion_tokens": 8}}
                if model in ("fixture-large", "fixture-near-limit") or model.startswith("fixture-preparation-"):
                    packet["diagnostic_padding"] = "x" * (1024 * 1024 if model == "fixture-large" else MAX_RESPONSE - 4096)
                if model == "fixture-near-limit" or model.startswith("fixture-preparation-"):
                    # Harmless prefix mentions prevent a cheap no-match fast
                    # path from becoming the only near-limit qualification.
                    packet["diagnostic_markers"] = "Bearer ! sk- nvapi- https:// token authorization api_key"
                if model == "fixture-malicious-usage":
                    packet["usage"] = {"input_tokens":CANARY,"output_tokens":"x" * (1024 * 1024)}
                payload = json.dumps(packet).encode()
            redacted_payload = payload.replace(CANARY.encode(), b"[redacted]")
            wire_redacted_sha256 = hashlib.sha256(redacted_payload).hexdigest()
            representation = "wire-text"
            if model == "fixture-malicious-usage":
                # This fixture puts a credential inside a decoded JSON value.
                # The provider's structured redactor reserializes that changed
                # object with JSON.stringify; whitespace is no longer wire text.
                # Compare every retained byte with this independently constructed
                # complete object, including the entire 1 MiB usage value.
                redacted_payload = json.dumps(json.loads(redacted_payload), sort_keys=True,
                                              separators=(",", ":")).encode()
                representation = "structured-redaction-json"
            receipt.update(http_code=code, response_bytes=len(payload), response_sha256=hashlib.sha256(payload).hexdigest(),
                           wire_redacted_body_sha256=wire_redacted_sha256,
                           redacted_body_bytes=len(redacted_payload), redacted_body_representation=representation,
                           redacted_body_sha256=hashlib.sha256(redacted_payload).hexdigest())
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(payload)
            receipt["outcome"] = "response_written"
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, OSError):
            if "receipt" in locals():
                receipt["outcome"] = "client_closed"
        except (ValueError, KeyError, TypeError):
            self.send_error(400)


class LoopbackConditions:
    """Reserved absent listener plus a measured saturated accept backlog.

    The latter exercises a slow TCP connection attempt without remote network,
    DNS or firewall changes. If this kernel cannot establish saturation, its
    case is explicitly unavailable instead of relabeling a delayed HTTP test.
    """
    def __init__(self):
        self.sockets: list[socket.socket] = []
        absent = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        absent.bind(("127.0.0.1", 0))  # Deliberately never listen().
        self.sockets.append(absent)
        self.absent_port = absent.getsockname()[1]
        self.ipv6_absent = False
        try:
            absent6 = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
            absent6.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
            absent6.bind(("::1", self.absent_port))
            self.sockets.append(absent6)
            self.ipv6_absent = True
        except OSError:
            if "absent6" in locals():
                absent6.close()
        stalled = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        stalled.bind(("127.0.0.1", 0))
        stalled.listen(1)
        self.sockets.append(stalled)
        self.stalled_port = stalled.getsockname()[1]
        self.backlog_saturated = False
        self.prefilled = 0
        for _ in range(32):
            client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            client.settimeout(0.1)
            self.sockets.append(client)
            try:
                client.connect(("127.0.0.1", self.stalled_port))
                self.prefilled += 1
            except TimeoutError:
                self.backlog_saturated = True
                break
            except OSError:
                break

    def close(self):
        for sock in self.sockets:
            sock.close()


def verify_complete_audit(profile: Path, cases: list[dict], receipts: list[dict]) -> dict:
    """Independently compare full retained response bodies with fixture digests.

    This runs after Godot exits and does not enter its frame timing. The only
    inputs are this invocation's synthetic profile and loopback receipts.
    """
    archives = sorted(profile.rglob("*.jsonl"))
    body_digests: set[str] = set()
    edited_conversations: set[tuple[int, str]] = set()
    request_events = 0
    for archive in archives:
        with archive.open(encoding="utf-8") as stream:
            for line in stream:
                if CANARY in line:
                    raise RuntimeError("Synthetic credential survived in an audit archive")
                event = json.loads(line)
                data = event.get("data")
                request_events += event.get("kind") == "request"
                if event.get("kind") == "response" and isinstance(data, dict):
                    body = data.get("body", "")
                    body_digests.add(hashlib.sha256(body.encode()).hexdigest())
                if event.get("kind") == "conversation_edited" and isinstance(data, dict):
                    turns = data.get("turns", [])
                    if len(turns) == 1 and turns[0].get("role") == "user" and isinstance(turns[0].get("content"), str):
                        content = turns[0]["content"].encode()
                        edited_conversations.add((len(content), hashlib.sha256(content).hexdigest()))
    checked_models = {"fixture-large", "fixture-large-error", "fixture-large-envelope-error",
                      "fixture-near-limit", "fixture-secret-boundary", "fixture-malicious-usage",
                      "fixture-large-assistant", "fixture-preparation-hide"}
    completed = {case["fixture"] for case in cases if case.get("fixture") in checked_models}
    checks = []
    for model in sorted(completed):
        expected = [receipt for receipt in receipts if receipt["model"] == model and "redacted_body_sha256" in receipt]
        if len(expected) != 1 or expected[0]["redacted_body_sha256"] not in body_digests:
            raise RuntimeError("Missing or incomplete redacted response archive for " + model)
        checks.append({"fixture":model, "complete_redacted_body":True,
                       "bytes":expected[0]["response_bytes"], "sha256":expected[0]["redacted_body_sha256"]})
    conversation_checks = []
    for case in cases:
        if case.get("case") != "loaded-near-cap-edited-apply":
            continue
        expected = (case["context_bytes"], case["expected_sha256"])
        if expected not in edited_conversations or request_events or receipts:
            raise RuntimeError("Changed complete conversation audit is missing or editing dispatched a model request")
        conversation_checks.append({"bytes":expected[0], "sha256":expected[1],
                                    "complete_changed_conversation":True, "model_requests":0})
    return {"archives":len(archives), "credential_redacted":True, "complete_bodies":checks,
            "complete_conversations":conversation_checks,
            "measurement_scope":"post-exit independent verification; excluded from application frame timing"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--group", choices=("all", "no-server", "network", "shutdown", "lifecycle", "conversation-apply", "preparation", "preparation-exit",
                                            "request-preparation", "request-preparation-exit"), default="all")
    parser.add_argument("--timeout", type=int, help="Positive process watchdog seconds; defaults to 300, or graphical network600/preparation900/all2400")
    parser.add_argument("--stall-limit-ms", type=int, default=2000)
    args = parser.parse_args()
    # Reject invalid overrides before creating profiles, sockets or a process.
    try:
        watchdog = process_watchdog(args.group, args.graphical, args.timeout)
    except ValueError as error:
        parser.error(str(error))
    args.timeout = watchdog["seconds"]
    args.godot = args.godot.resolve()
    args.project = args.project.resolve()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    profile = args.output / "isolated-profile"
    if profile.exists():
        raise SystemExit("Choose a new output directory: the isolated profile must not already exist.")
    profile.mkdir()
    fixture = Fixture(args.output)
    conditions = LoopbackConditions()
    threading.Thread(target=fixture.serve_forever, daemon=True).start()
    spec = {"endpoint": f"http://127.0.0.1:{fixture.server_port}/v1",
            "absent_endpoint": f"http://127.0.0.1:{conditions.absent_port}/v1",
            "localhost_absent_endpoint": f"http://localhost:{conditions.absent_port}/v1",
            # Godot 4.7 rejects the three-character shorthand ::1 in its
            # HTTPClient minimum-host-length check. The expanded address is
            # the same reserved loopback listener and reaches actual transport.
            "ipv6_absent_endpoint": f"http://[0:0:0:0:0:0:0:1]:{conditions.absent_port}/v1" if conditions.ipv6_absent else "",
            "ipv6_short_absent_endpoint": f"http://[::1]:{conditions.absent_port}/v1" if conditions.ipv6_absent else "",
            "slow_connect_endpoint": f"http://127.0.0.1:{conditions.stalled_port}/v1" if conditions.backlog_saturated else "",
            "slow_connect_condition": "loopback_accept_backlog_saturated" if conditions.backlog_saturated else "unavailable_on_this_kernel",
            "slow_connect_prefilled_sockets": conditions.prefilled,
            "output": str(args.output), "accepted_dir":str(fixture.accepted_dir),
            "post_arrival_dir":str(fixture.post_arrival_dir),
            "graphical": args.graphical,"group":args.group,
            "process_watchdog":watchdog,
            "stall_limit_usec": args.stall_limit_ms * 1000}
    spec_path = args.output / "fixture-spec.json"
    spec_path.write_text(json.dumps(spec, indent=2) + "\n", encoding="utf-8")
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile / "local"),
               XDG_DATA_HOME=str(profile), XDG_CONFIG_HOME=str(profile / "config"),
               XDG_CACHE_HOME=str(profile / "cache"), WB_ART_FINAL_SPEC=str(spec_path))
    command = [str(args.godot), "--audio-driver", "Dummy"]
    if args.graphical:
        command += ["--rendering-method", "gl_compatibility"]
        command += ["--rendering-driver", "opengl3_angle"] if sys.platform == "win32" else ["--display-driver", "x11"]
    else:
        command += ["--headless"]
    command += ["--path", str(args.project), "--script", "res://tests/run_art_workbench_final.gd"]
    native_name = "cybersand_native.windows.x86_64.dll" if sys.platform == "win32" else "libcybersand_native.linux.x86_64.so"
    provenance = {"source": git_identity(args.project.parent), "godot": identity(args.godot),
                  "native": identity(args.project / "addons/cybersand_native/bin" / native_name),
                  "harness": identity(Path(__file__).resolve()),
                  "driver": identity(args.project / "tests/run_art_workbench_final.gd"),
                  "command": command, "platform": sys.platform,"process_watchdog":watchdog,
                  "interaction": "Godot InputEventMouseButton into embedded windows; no physical mouse/driver acceptance"}
    (args.output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    log = args.output / "godot.log"
    resources = {"before": resource_snapshot()}
    (args.output / "resources.json").write_text(json.dumps(resources, indent=2) + "\n", encoding="utf-8")
    try:
        began = time.monotonic()
        try:
            with log.open("w", encoding="utf-8") as output:
                process = subprocess.Popen(command, env=env, stdout=output, stderr=subprocess.STDOUT)
                try:
                    exit_code = process.wait(timeout=args.timeout)
                except subprocess.TimeoutExpired:
                    # The Windows console executable can own a child GUI
                    # process. Retire that exact tree while its wrapper still
                    # exists; killing only the wrapper loses ownership.
                    cleanup_error = ""
                    try:
                        if sys.platform == "win32":
                            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                           stdout=output, stderr=subprocess.STDOUT, timeout=15, check=False)
                        else:
                            process.kill()
                        process.wait(timeout=15)
                    except (OSError, subprocess.TimeoutExpired) as error:
                        cleanup_error = str(error)
                        try:
                            if process.poll() is None:
                                process.kill()
                                process.wait(timeout=5)
                        except (OSError, subprocess.TimeoutExpired) as fallback_error:
                            cleanup_error += "; wrapper fallback: " + str(fallback_error)
                    execution = {"exit_code":process.poll(),"timed_out":True,
                                 "elapsed_seconds":time.monotonic()-began,"watchdog_seconds":args.timeout,
                                 "cleanup":"owned_process_tree" if sys.platform=="win32" else "owned_process",
                                 "cleanup_error":cleanup_error}
                    (args.output / "execution.json").write_text(json.dumps(execution,indent=2)+"\n",encoding="utf-8")
                    raise
            execution = {"exit_code":exit_code,"timed_out":False,"elapsed_seconds":time.monotonic()-began,
                         "completed_unix_seconds":time.time(),
                         "watchdog_seconds":args.timeout}
        except subprocess.TimeoutExpired:
            raise RuntimeError(f"External watchdog expired after {args.timeout}s; raw failure retained at {log}") from None
        (args.output / "execution.json").write_text(json.dumps(execution,indent=2)+"\n",encoding="utf-8")
        text = log.read_text(encoding="utf-8", errors="replace")
        receipts = [json.loads(line[len(MARKER):]) for line in text.splitlines() if line.startswith(MARKER)]
        if len(receipts) != 1:
            checkpoint_path = args.output / "report-checkpoint.json"
            if not receipts and checkpoint_path.is_file():
                partial = json.loads(checkpoint_path.read_text(encoding="utf-8"))
                partial["execution_incomplete"] = True
                partial["execution"] = execution
                (args.output / "partial-report.json").write_text(json.dumps(partial, indent=2) + "\n", encoding="utf-8")
                try:
                    partial_audit = verify_complete_audit(profile, partial.get("cases", []), fixture.receipts)
                except (AssertionError, RuntimeError, ValueError, OSError) as error:
                    partial_audit = {"verified": False, "error": str(error)}
                (args.output / "partial-audit-verification.json").write_text(json.dumps(partial_audit, indent=2) + "\n", encoding="utf-8")
            raise RuntimeError(f"Missing/duplicate final receipt (exit {exit_code}); inspect {log}")
        report = receipts[0]
        if args.group in ("preparation-exit", "request-preparation-exit"):
            requested = json.loads((args.output / "exit-request.json").read_text(encoding="utf-8"))
            elapsed = execution["completed_unix_seconds"] - requested["requested_unix_seconds"]
            report["process_exit"] = {"exit_code":exit_code,"seconds_after_request":elapsed,
                                      "clock":"same-host wall clock around actual process exit",
                                      "direction":requested.get("direction", "response"),
                                      "preparation_active_at_request":requested["preparation_active"],
                                      "pending_jobs_at_request":requested["pending_jobs"]}
            if not requested["preparation_active"] or not 0 <= elapsed < args.stall_limit_ms / 1000:
                report.setdefault("failures",[]).append("actual process exit during CPU preparation exceeded its bound")
            if requested.get("direction") == "request" and any(receipt.get("model") == "fixture-outgoing-exit" for receipt in fixture.receipts):
                report.setdefault("failures",[]).append("outgoing preparation dispatched HTTP after the process quit request")
            if re.search(r"ObjectDB instances leaked|resources still in use|WorkerThreadPool.*not awaited", text, re.I):
                report.setdefault("failures",[]).append("actual process exit reported retained objects/resources or an unreaped task")
        report["loopback_conditions"] = {key: spec[key] for key in ("slow_connect_condition", "slow_connect_prefilled_sockets")}
        (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        audit = verify_complete_audit(profile, report.get("cases", []), fixture.receipts)
        (args.output / "audit-verification.json").write_text(json.dumps(audit, indent=2) + "\n", encoding="utf-8")
        if exit_code or ERRORS.search(text) or report.get("failures"):
            raise RuntimeError(f"Art matrix failed; retained raw failure at {log}")
        minimums = {"shutdown":(0,12), "preparation-exit":(0,6), "request-preparation-exit":(0,6),
                    "lifecycle":(2,60), "conversation-apply":(1,20), "request-preparation":(4,60),
                    "preparation":(3,60), "no-server":(9,60), "all":(22,100)}
        expected_cases, expected_checks = minimums.get(args.group, (22,60))
        if report.get("checks", 0) < expected_checks or len(report.get("cases", [])) < expected_cases:
            raise RuntimeError("Matrix did not execute all required arms")
        if args.graphical and (report.get("display") == "headless" or not (args.output / "art-window.png").is_file()):
            raise RuntimeError("Graphical fixture omitted rendered framebuffer evidence")
        conversation_capture = args.output / "conversation-before-apply.png"
        if args.graphical and args.group == "conversation-apply" and (
                not conversation_capture.is_file() or conversation_capture.stat().st_size == 0):
            raise RuntimeError("Graphical changed-Apply fixture omitted its actual Conversation framebuffer")
        print(f"Art Workbench: {report['checks']} checks, {len(report['cases'])} cases, failures=0, display={report['display']}")
        return 0
    finally:
        fixture.release_blackhole.set()
        fixture.shutdown()
        fixture.server_close()
        conditions.close()
        resources["after"] = resource_snapshot()
        (args.output / "resources.json").write_text(json.dumps(resources, indent=2) + "\n", encoding="utf-8")
        (args.output / "fixture-receipts.json").write_text(json.dumps(fixture.receipts, indent=2) + "\n", encoding="utf-8")
        (args.output / "fixture-post-arrivals.json").write_text(json.dumps({
            "count":fixture.post_arrival_count,
            "empty_markers":len(list(fixture.post_arrival_dir.iterdir())),
            "scope":"every loopback POST before body, path or JSON validation; no request content retained"
        }, indent=2) + "\n", encoding="utf-8")
        hashes = {str(p.relative_to(args.output)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in args.output.iterdir() if p.is_file() and p.name != "hashes.json"}
        (args.output / "hashes.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
