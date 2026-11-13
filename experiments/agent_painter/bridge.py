#!/usr/bin/env python3
"""Opt-in loopback provider for strict new painter proposals; no native writes.

Adapted from #567 integration/local_art_bridge.py. The current LM Studio-mode
host captures local focus, material and enabled shapes. This bridge independently
recompiles raw model JSON and refuses any mismatch, cancellation or missing EOS.
The normal Workbench executor still owns actual permissions, Stop and history.
"""
from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
import os
from pathlib import Path
import re
import select
import socket
import sys
import tempfile
import threading

from compiler import canonical_json, compile_program, parse_program
from process import ProcessRefusal, run_owned
from training.common import strict_json, verify_checkpoint

ALIAS = "cybersand-agent-painter-v2"
MAX_BODY = 16384


class BridgeRefusal(ValueError):
    pass


def file_sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def host_array(text: str, key: str):
    matches = list(re.finditer(r"(?:^|[.\s])" + re.escape(key) + r"\s*[:=]\s*(\[[^\]]*\])", text))
    if not matches:
        raise BridgeRefusal("Missing captured host field: " + key)
    # Current Art panel appends trusted capture after editable guidance.
    return strict_json(matches[-1].group(1))


def parse_request(packet):
    if type(packet) is not dict or packet.get("model") != ALIAS or packet.get("stream") is not False:
        raise BridgeRefusal("Select the painter alias with streaming off")
    messages = packet.get("messages")
    if type(messages) is not list or len(messages) != 2 or any(type(x) is not dict for x in messages):
        raise BridgeRefusal("Use text-only LM Studio mode, Context None, Turns 1")
    system, user = messages
    if system.get("role") != "system" or user.get("role") != "user":
        raise BridgeRefusal("Invalid roles")
    instructions, prompt = system.get("content"), user.get("content")
    if type(instructions) is not str or type(prompt) is not str or not 1 <= len(prompt.strip()) <= 2048:
        raise BridgeRefusal("A bounded text request is required; Image must be off")
    if "Coordinates are LOCAL:" not in instructions or "Use only the current work area above" not in instructions:
        raise BridgeRefusal("Current captured local-coordinate contract missing")
    area = host_array(instructions, "XYWH")
    allowed = host_array(instructions, "Allowed materials")
    enabled = host_array(instructions, "Enabled shapes")
    selected = list(re.finditer(r"Selected drawing material:\s*(\d+)", instructions))
    if (type(area) is not list or len(area) != 4 or any(type(v) is not int for v in area)
            or area[:2] != [0, 0] or any(not 96 <= v <= 512 for v in area[2:])):
        raise BridgeRefusal("Painter focus must be local XYWH and between 96 and 512 cells")
    if (not selected or int(selected[-1].group(1)) != 58 or type(allowed) is not list
            or any(type(v) is not int for v in allowed) or 58 not in allowed):
        raise BridgeRefusal("This pilot requires host-enabled Hard Wall material 58")
    if type(enabled) is not list or any(type(v) is not str for v in enabled) or "rectangle" not in enabled:
        raise BridgeRefusal("Host must enable rectangle operations")
    return {"prompt": prompt, "width": area[2], "height": area[3], "material": 58}


def checked_result(directory: Path, request: dict, config):
    receipt = strict_json((directory / "receipt.json").read_text(encoding="utf-8"))
    expected = {**request, "seed": config.seed, "model_id": config.model_id,
                "model_revision": config.model_revision, "adapter_sha256": config.adapter_sha256,
                "compiler_sha256": file_sha(Path(__file__).with_name("compiler.py")),
                "native_execution": False, "accepted": True, "eos_emitted": True,
                "eos_terminated": True}
    if any(type(receipt.get(k)) is not type(v) or receipt[k] != v for k, v in expected.items()):
        raise BridgeRefusal("Inference receipt differs from captured request/model/compiler or did not emit EOS")
    program = parse_program((directory / "completion.txt").read_text(encoding="utf-8"))
    compiled = compile_program(program, seed=config.seed,
                               focus=(0, 0, request["width"], request["height"]), material=58,
                               allowed_materials=(58,), max_operations=512, max_cell_work=100000)
    output = strict_json((directory / "art_batch.json").read_text(encoding="utf-8"))
    if output != compiled["operations"]:
        raise BridgeRefusal("Raw model program and returned geometry disagree")
    return canonical_json(output), receipt


def disconnected(peer):
    try:
        ready, _, _ = select.select([peer], [], [], 0)
        return bool(ready) and peer.recv(1, socket.MSG_PEEK) == b""
    except (OSError, ValueError):
        return True


def infer(config, request, *, canceled):
    folder = Path(tempfile.mkdtemp(prefix="request-", dir=config.evidence))
    target = folder / "inference"
    command = [sys.executable, str(Path(__file__).parent / "training/infer.py"),
               "--model", str(config.model), "--checkpoint", str(config.checkpoint),
               "--prompt=" + request["prompt"], "--output", str(target), "--seed", str(config.seed),
               "--width", str(request["width"]), "--height", str(request["height"]),
               "--material", "58"]
    with (folder / "process.log").open("wb") as log:
        code = run_owned(command, log, config.seconds, canceled=canceled)
    if code or canceled():
        raise BridgeRefusal("Inference failed or was canceled; no Art proposal")
    return checked_result(target, request, config)


def handler(config, stop, runner=infer):
    lease = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def setup(self):
            super().setup()
            self.connection.settimeout(15)

        def reply(self, status, body):
            payload = canonical_json(body).encode()
            try:
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
            except (BrokenPipeError, ConnectionResetError, socket.timeout):
                pass

        def do_GET(self):
            if self.path == "/v1/models":
                self.reply(200, {"object": "list", "data": [{"id": ALIAS, "object": "model"}]})
            else:
                self.reply(404, {"error": "Unknown route"})

        def do_POST(self):
            if self.path != "/v1/chat/completions" or self.headers.get("Origin"):
                self.reply(403, {"error": "Native loopback client required"})
                return
            length = self.headers.get("Content-Length", "")
            if not length.isdecimal() or not 1 <= int(length) <= MAX_BODY:
                self.reply(413, {"error": "Invalid/excessive request body"})
                return
            try:
                request = parse_request(strict_json(self.rfile.read(int(length)).decode("utf-8")))
                if not lease.acquire(blocking=False):
                    self.reply(429, {"error": "One inference request at a time"})
                    return
                try:
                    canceled = lambda: stop.is_set() or disconnected(self.connection)
                    content, _receipt = runner(config, request, canceled=canceled)
                    if canceled():
                        raise BridgeRefusal("Stopped before response; discarded proposal")
                finally:
                    lease.release()
                self.reply(200, {"id": "painter-proposal", "object": "chat.completion", "model": ALIAS,
                                 "choices": [{"index": 0, "message": {"role": "assistant", "content": content},
                                              "finish_reason": "stop"}], "native_execution": False})
            except (ValueError, ProcessRefusal, OSError, KeyError, TypeError) as error:
                self.reply(422, {"error": str(error)})

    return Handler


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--model", type=Path, required=True)
    p.add_argument("--checkpoint", type=Path, required=True)
    p.add_argument("--evidence", type=Path, required=True)
    p.add_argument("--seed", type=int, required=True)
    p.add_argument("--seconds", type=int, default=150)
    p.add_argument("--port", type=int, default=8127)
    args = p.parse_args()
    if os.name != "posix" or not 0 <= args.seed < 2**32 or not 1 <= args.seconds <= 150 or not 1024 <= args.port <= 65535:
        p.error("POSIX host, bounded seed/deadline and unprivileged port required")
    receipt = verify_checkpoint(args.checkpoint)
    # The saved run config binds exact official model revision and compiler.
    model_receipt = strict_json((args.model / "download_receipt.json").read_text(encoding="utf-8"))
    args.model_id, args.model_revision = model_receipt["model_id"], model_receipt["revision"]
    args.adapter_sha256 = file_sha(args.checkpoint / "adapter/adapter_model.safetensors")
    args.evidence.mkdir(parents=True, exist_ok=True)
    stop = threading.Event()
    http = ThreadingHTTPServer(("127.0.0.1", args.port), handler(args, stop))
    http.daemon_threads = False
    print(f"Opt-in painter proposal bridge: http://127.0.0.1:{args.port}/v1", flush=True)
    try:
        http.serve_forever(poll_interval=0.1)
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        http.server_close()


if __name__ == "__main__":
    main()
