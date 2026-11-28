#!/usr/bin/env python3
"""Fresh mechanism comparison after the lost temporary-runner checkpoint.

Runs the production provider with only its per-read byte bound varied. Every
arm has a fresh profile, real loopback HTTP, complete redacted native-audit
verification, scoped Stop and an oversized-response refusal. No World, UI or
model creativity claim follows from these headless mechanism measurements.
"""
from __future__ import annotations

import argparse
import hashlib
import http.server
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    "godot/scripts/art_provider.gd", "godot/scripts/art_response_preparation.gd",
    "godot/scripts/art_redaction.gd", "godot/scripts/art_traffic_archive.gd",
    "godot/addons/cybersand_native/cybersand_native.gdextension",
)
NATIVE = "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
NATIVE_SHA = "a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7"
GODOT_SHA = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
FIXTURE = "tools/fixtures/art_transport_pump_recovered.gd"
KEY = "synthetic-pump-fixture-credential-never-a-real-provider-key"
MARKER = "ART_PUMP_RECOVERED_RESULT "


def sha(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(part)
    return value.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def hardware() -> dict:
    memory = {}
    path = Path("/proc/meminfo")
    if path.exists():
        for line in path.read_text().splitlines():
            key, _, value = line.partition(":")
            if key in ("MemTotal", "MemAvailable", "SwapTotal", "SwapFree"):
                memory[key] = value.strip()
    cpu = ""
    path = Path("/proc/cpuinfo")
    if path.exists():
        cpu = next((line.partition(":")[2].strip() for line in path.read_text().splitlines()
                    if line.startswith("model name")), "")
    return {"platform": platform.platform(), "python": platform.python_version(),
            "cpu_model": cpu, "logical_cpu_count": os.cpu_count(), "memory": memory}


def arm(args: argparse.Namespace, output: Path, fps: int, chunk_kib: int,
        payload: bytes, text_bytes: bytes, inventory: dict) -> dict:
    output.mkdir()
    project = output / "project"
    project.mkdir()
    for name in SOURCES:
        target = project / name.removeprefix("godot/")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
    provider = project / "scripts/art_provider.gd"
    source = provider.read_text(encoding="utf-8")
    source, changes = re.subn(r"request\.download_chunk_size = (?:64|256)\*1024",
                             f"request.download_chunk_size = {chunk_kib}*1024", source)
    if changes != 1:
        raise ValueError("Exactly one known production chunk setting is required")
    provider.write_text(source, encoding="utf-8")
    shutil.copyfile(ROOT / FIXTURE, project / "art_transport_pump_recovered.gd")
    native = project / NATIVE.removeprefix("godot/")
    native.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.native, native)
    (project / ".godot").mkdir()
    (project / ".godot/extension_list.cfg").write_text("res://addons/cybersand_native/cybersand_native.gdextension\n")
    (project / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Art Pump Recovered Fixture"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    profile = output / "profile"
    profile.mkdir()
    ready = output / "actual-stalled-socket.json"
    release = threading.Event()
    requests: list[dict] = []

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *_args: object) -> None:
            pass

        def do_POST(self) -> None:
            self.connection.settimeout(90)
            size = int(self.headers.get("Content-Length", "0"))
            if size < 0 or size > 2 * 1024 * 1024:
                self.send_error(413)
                return
            request = json.loads(self.rfile.read(size))
            kind = request["messages"][-1]["content"]
            row = {"kind": kind, "request_bytes": size,
                   "authorization_matches_synthetic_key": self.headers.get("Authorization") == "Bearer " + KEY,
                   "received_monotonic_ns": time.monotonic_ns()}
            requests.append(row)
            if kind == "stalled":
                write_json(ready, {"accepted_socket": True, "response_headers_sent": False})
                release.wait(90)
                self.close_connection = True
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("X-Fixture-Credential", KEY)
            self.send_header("Content-Length", str(len(payload) if kind == "success" else 16 * 1024 * 1024 + 1))
            self.send_header("Connection", "close")
            self.end_headers()
            if kind == "success":
                row["write_begin_monotonic_ns"] = time.monotonic_ns()
                try:
                    self.wfile.write(payload)
                    self.wfile.flush()
                    row["written_bytes"] = len(payload)
                except (BrokenPipeError, ConnectionResetError, TimeoutError) as error:
                    row["write_error"] = type(error).__name__
                row["write_end_monotonic_ns"] = time.monotonic_ns()
            self.close_connection = True

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    env = os.environ.copy()
    env.update({"XDG_DATA_HOME": str(profile), "XDG_CONFIG_HOME": str(profile),
                "ART_PUMP_ENDPOINT": f"http://127.0.0.1:{server.server_port}/v1",
                "ART_PUMP_KEY": KEY, "ART_PUMP_FPS": str(fps),
                "ART_PUMP_CHUNK": str(chunk_kib * 1024),
                "ART_PUMP_TEXT_BYTES": str(len(text_bytes)),
                "ART_PUMP_TEXT_SHA256": hashlib.sha256(text_bytes).hexdigest(),
                "ART_PUMP_RESPONSE_BYTES": str(len(payload)),
                "ART_PUMP_STALL_READY": str(ready),
                "CYBERSAND_SOURCE_REVISION": args.source_revision})
    command = [str(args.godot), "--headless", "--audio-driver", "Dummy", "--path", str(project),
               "--script", "res://art_transport_pump_recovered.gd"]
    result = {"fps": fps, "chunk_kib": chunk_kib, "model_calls": 0,
              "provider_sha256": sha(provider), "fixture_sha256": sha(ROOT / FIXTURE),
              "hardware_before": hardware(), "command": command,
              "source_files_sha256": inventory, "timeout": False}
    started = time.monotonic()
    log = output / "process.log"
    try:
        with log.open("wb") as stream:
            try:
                process = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=args.timeout)
                result["returncode"] = process.returncode
            except subprocess.TimeoutExpired:
                result.update(returncode=None, timeout=True)
    finally:
        release.set()
        server.shutdown()
        server.server_close()
        worker.join(timeout=2)
    result.update(wall_seconds=time.monotonic() - started, hardware_after=hardware(),
                  server_requests=requests, log_sha256=sha(log))
    text = log.read_text(encoding="utf-8", errors="replace")
    lines = [line[len(MARKER):] for line in text.splitlines() if line.startswith(MARKER)]
    if len(lines) == 1:
        result["fixture"] = json.loads(lines[0])
    fixture = result.get("fixture", {})
    result["passed"] = (result["returncode"] == 0 and not result["timeout"]
                        and len(lines) == 1 and type(fixture.get("checks")) is int
                        and fixture["checks"] >= 24 and fixture.get("failures") == []
                        and fixture.get("provider_sha256") == result["provider_sha256"]
                        and fixture.get("fixture_sha256") == result["fixture_sha256"]
                        and fixture.get("model_calls") == 0 and fixture.get("native_worlds") == 0
                        and fixture.get("source_revision") == args.source_revision
                        and len(requests) == 3 and [r["kind"] for r in requests] == ["success", "stalled", "oversize"]
                        and all(r["authorization_matches_synthetic_key"] for r in requests)
                        and not any(token in text for token in ("ERROR:", "Parse Error:", "Failed to load script")))
    write_json(output / "result.json", result)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--native", type=Path, required=True)
    parser.add_argument("--source-revision", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--fps", type=int, nargs="+", default=[60, 5])
    parser.add_argument("--chunks-kib", type=int, nargs="+", default=[64, 256])
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()
    args.godot = args.godot.resolve()
    args.native = args.native.resolve()
    args.output = args.output.resolve()
    if args.output.exists() or not re.fullmatch(r"[0-9a-f]{40}", args.source_revision):
        parser.error("Use a fresh output directory and an exact source commit")
    if any(fps not in range(1, 241) for fps in args.fps) or any(n not in (64, 256) for n in args.chunks_kib):
        parser.error("Frame cap must be 1..240 and read chunks exactly 64 or 256 KiB")
    if sha(args.godot) != GODOT_SHA or sha(args.native) != NATIVE_SHA:
        parser.error("Pinned Godot 4.7 and source-matched native audit library required")
    args.output.mkdir(parents=True)
    message = "BEGIN: reconstructed deterministic provider mechanism.\n" + "A" * (4 * 1024 * 1024 - 4096) + "\nEND: complete admitted response."
    text_bytes = message.encode()
    payload = json.dumps({"choices": [{"message": {"content": message}, "finish_reason": "stop"}],
                          "model": "deterministic-pump-fixture", "usage": {"prompt_tokens": 1, "completion_tokens": 1}},
                         separators=(",", ":")).encode()
    inventory = {name: sha(ROOT / name) for name in (*SOURCES, FIXTURE)}
    summary = {"format": "cybersand-art-pump-reconstructed-comparison-v1", "source_revision": args.source_revision,
               "scope": "Reconstructed headless mechanism; no native World, displayed UI or model inference.",
               "previous_lost_runner_recovered": False, "model_calls": 0,
               "runner_sha256": sha(Path(__file__)), "godot_sha256": sha(args.godot),
               "native_sha256": sha(args.native), "source_files_sha256": inventory,
               "response_bytes": len(payload), "response_sha256": hashlib.sha256(payload).hexdigest(),
               "assistant_bytes": len(text_bytes), "assistant_sha256": hashlib.sha256(text_bytes).hexdigest(),
               "arms": []}
    write_json(args.output / "comparison.json", summary)
    for fps in args.fps:
        for chunk in args.chunks_kib:
            outcome = arm(args, args.output / f"fps-{fps}-chunk-{chunk}", fps, chunk, payload, text_bytes, inventory)
            summary["arms"].append(outcome)
            write_json(args.output / "comparison.json", summary)
            print(json.dumps({"fps": fps, "chunk_kib": chunk, "passed": outcome["passed"],
                              "returncode": outcome["returncode"], "wall_seconds": outcome["wall_seconds"]}), flush=True)
            if not outcome["passed"]:
                raise SystemExit(1)
    summary["source_unchanged"] = inventory == {name: sha(ROOT / name) for name in inventory}
    summary["passed"] = summary["source_unchanged"] and all(item["passed"] for item in summary["arms"])
    write_json(args.output / "comparison.json", summary)
    raise SystemExit(0 if summary["passed"] else 1)


if __name__ == "__main__":
    main()
