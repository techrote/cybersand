#!/usr/bin/env python3
"""Opt-in loopback Chat Completions bridge: strict SLM program -> Art operations.

Not a substitute for CyberSand's native authorization, receipts, Stop or history.
Only a single text-only LM Studio-mode Art turn is supported. The model cannot
choose focus, material, seed or budgets. A rejected proposal returns no batch.
"""
from __future__ import annotations

import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import threading
import time

MODEL_ALIAS = "wb-art-slm-001-lfm350-step400"
ADAPTER_SHA256 = "02b9263e543eb464e6b58f1f74960c98d5aec4ec117baddfcf22b4d5dd4c84b2"
MAX_BODY = 16384
BATCH_SHAPES = frozenset({"rectangle", "line", "polyline", "polygon", "disc"})


class BridgeRefusal(ValueError):
    pass


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _json_field(instructions: str, key: str):
    match = re.search(r"(?:^|[.\s])" + re.escape(key) + r"\s*[:=]\s*(\[[^\]]*\])", instructions)
    if not match:
        raise BridgeRefusal("missing captured host field: " + key)
    try:
        return json.loads(match.group(1))
    except json.JSONDecodeError as exc:
        raise BridgeRefusal("invalid captured host field: " + key) from exc


def parse_workbench_request(packet: object, alias: str) -> dict:
    if not isinstance(packet, dict) or packet.get("model") != alias or packet.get("stream") is not False:
        raise BridgeRefusal("wrong model or unsupported streaming request")
    messages = packet.get("messages")
    if not isinstance(messages, list) or len(messages) != 2:
        raise BridgeRefusal("single-turn text-only LM Studio mode required; select Context None and Turns 1")
    if any(not isinstance(m, dict) for m in messages):
        raise BridgeRefusal("malformed message")
    system, user = messages
    if system.get("role") != "system" or user.get("role") != "user":
        raise BridgeRefusal("unexpected chat roles")
    instructions, prompt = system.get("content"), user.get("content")
    if not isinstance(instructions, str) or not isinstance(prompt, str) or not 1 <= len(prompt.strip()) <= 2048:
        raise BridgeRefusal("text-only prompt of at most 2048 characters required; Image must be off")
    if "Continue revising the current artwork." in prompt:
        raise BridgeRefusal("automatic multi-turn continuation is not supported")
    if "Coordinates are LOCAL:" not in instructions or "Use only the current work area above" not in instructions:
        raise BridgeRefusal("LM Studio local-coordinate host contract missing")
    xywh = _json_field(instructions, "XYWH")
    if (not isinstance(xywh, list) or len(xywh) != 4 or any(type(n) is not int for n in xywh)
            or xywh[:2] != [0, 0] or not (16 <= xywh[2] <= 512 and 16 <= xywh[3] <= 512)):
        raise BridgeRefusal("unsupported local focus size or origin")
    allowed = _json_field(instructions, "Allowed materials")
    tools = _json_field(instructions, "Enabled shapes")
    selected = re.search(r"Selected drawing material:\s*(\d+)", instructions)
    if not selected:
        raise BridgeRefusal("missing host-selected material")
    material = int(selected.group(1))
    if (type(allowed) is not list or any(type(x) is not int for x in allowed)
            or material not in (0, 58) or material not in allowed or not set(allowed) <= {0, 58}):
        raise BridgeRefusal("unverified material permission")
    if type(tools) is not list or any(type(x) is not str for x in tools):
        raise BridgeRefusal("invalid enabled-tools list")
    tokens = packet.get("max_tokens")
    if type(tokens) is not int or not 256 <= tokens <= 65536:
        raise BridgeRefusal("unsupported Art response token setting")
    return {"prompt": prompt, "width": xywh[2], "height": xywh[3], "material": material,
            "enabled": frozenset(tools)}


def checked_art_result(output: Path, request: dict, expected_compiler_sha256: str) -> tuple[str, dict]:
    receipt = json.loads((output / "receipt.json").read_text(encoding="utf-8"))
    if receipt.get("accepted") is not True or receipt.get("eos_emitted") is not True:
        raise BridgeRefusal("model completion rejected or unterminated")
    for field in ("width", "height", "material"):
        if receipt.get(field) != request[field]:
            raise BridgeRefusal("inference receipt differs from captured host " + field)
    if receipt.get("compiler_sha256") != expected_compiler_sha256:
        raise BridgeRefusal("inference/compiler source mismatch")
    if receipt.get("art_batch_sha256") != digest(output / "art_batch.json"):
        raise BridgeRefusal("compiled Art operations differ from recorded receipt")
    data = json.loads((output / "art_batch.json").read_text(encoding="utf-8"))
    if (not isinstance(data, list) or not data or len(data) > 2048
            or any(not isinstance(op, dict) or op.get("shape") not in BATCH_SHAPES
                   or op.get("shape") not in request["enabled"] or op.get("material") != request["material"]
                   for op in data)):
        raise BridgeRefusal("empty, unrecognized, unauthorized or disabled compiled operation")
    # The compiler owns geometry and budget admission; the native Workbench owns
    # authoritative cell permissions and must revalidate all operations.
    return json.dumps(data, separators=(",", ":"), allow_nan=False), receipt


def run_inference(config: argparse.Namespace, request: dict) -> tuple[str, dict]:
    folder = Path(tempfile.mkdtemp(prefix="request-", dir=config.evidence_dir))
    output = folder / "inference"
    command = [sys.executable, str(config.infer), "--model", str(config.model_dir),
               "--adapter", str(config.adapter_dir), "--compiler", str(config.compiler),
               "--prompt", request["prompt"], "--seed", str(config.seed),
               "--width", str(request["width"]), "--height", str(request["height"]),
               "--material", str(request["material"]), "--max-shapes", str(config.max_shapes),
               "--max-estimated-cells", str(config.max_estimated_cells),
               "--threads", str(config.threads), "--device", config.device,
               "--output", str(output)]
    # Do not use a shell. A timed-out model cannot subsequently publish a batch.
    with (folder / "process.log").open("wb") as log:
        try:
            result = subprocess.run(command, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=config.deadline_seconds, check=False)
        except subprocess.TimeoutExpired as exc:
            raise BridgeRefusal("local inference deadline exceeded; no Art batch returned") from exc
    if result.returncode:
        raise BridgeRefusal("inference rejected or failed (exit %d); original output in %s" % (result.returncode, folder))
    return checked_art_result(output, request, config.compiler_sha256)


def make_handler(config: argparse.Namespace, runner=run_inference):
    single_job = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        server_version = "WB-ART-SLM-001/1"

        def send_json(self, code: int, obj: dict):
            data = json.dumps(obj, separators=(",", ":"), allow_nan=False).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            try:
                self.wfile.write(data)
            except (BrokenPipeError, ConnectionResetError):
                pass  # Stop/closed Workbench request must never trigger an Art retry.

        def do_GET(self):
            if self.path == "/v1/models":
                self.send_json(200, {"object": "list", "data": [{"id": MODEL_ALIAS, "object": "model"}]})
            elif self.path == "/healthz":
                self.send_json(200, {"ok": True, "model": MODEL_ALIAS, "native_qualified": False})
            else:
                self.send_json(404, {"error": {"message": "unknown route"}})

        def do_POST(self):
            if self.path != "/v1/chat/completions":
                self.send_json(404, {"error": {"message": "unknown route"}})
                return
            length = self.headers.get("Content-Length", "")
            if not length.isdecimal() or not 1 <= int(length) <= MAX_BODY:
                self.send_json(413, {"error": {"message": "invalid or excessive request body"}})
                return
            try:
                packet = json.loads(self.rfile.read(int(length)))
                request = parse_workbench_request(packet, MODEL_ALIAS)
                if not single_job.acquire(blocking=False):
                    self.send_json(429, {"error": {"message": "one local model inference at a time"}})
                    return
                try:
                    content, receipt = runner(config, request)
                finally:
                    single_job.release()
                self.send_json(200, {"id": "wb-art-slm-001", "object": "chat.completion",
                                     "model": MODEL_ALIAS, "choices": [{"index": 0,
                                      "message": {"role": "assistant", "content": content},
                                      "finish_reason": "stop"}],
                                     "wb_art_slm": {"adapter_sha256": config.adapter_sha256,
                                                    "compiler_sha256": config.compiler_sha256,
                                                    "inference_output_tokens": receipt.get("output_tokens"),
                                                    "native_executed": False}})
            except (BridgeRefusal, json.JSONDecodeError, FileNotFoundError, KeyError, TypeError) as exc:
                self.send_json(422, {"error": {"message": str(exc)}})
            except Exception as exc:
                self.send_json(500, {"error": {"message": "local bridge failure: " + type(exc).__name__}})

    return Handler


def arguments(argv=None) -> argparse.Namespace:
    root = Path(__file__).resolve().parents[1]
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--model-dir", required=True, type=Path, help="Pinned local LFM2.5-350M base")
    p.add_argument("--adapter-dir", required=True, type=Path, help="Verified step-400 adapter directory")
    p.add_argument("--evidence-dir", type=Path, required=True, help="Private directory outside Git")
    p.add_argument("--infer", type=Path, default=root / "training" / "infer.py")
    p.add_argument("--compiler", type=Path, default=root / "controls" / "pattern_compiler.py")
    p.add_argument("--seed", type=int, default=73)
    p.add_argument("--threads", type=int, default=3)
    p.add_argument("--device", choices=["cpu", "cuda", "auto"], default="cpu")
    p.add_argument("--max-shapes", type=int, default=2048)
    p.add_argument("--max-estimated-cells", type=int, default=131072)
    p.add_argument("--deadline-seconds", type=int, default=150)
    p.add_argument("--port", type=int, default=8127)
    args = p.parse_args(argv)
    if not 0 <= args.seed < 2**63 or not 1 <= args.threads <= 16 or not 1 <= args.max_shapes <= 2048:
        p.error("invalid host seed, threads or shape budget")
    if not 1 <= args.max_estimated_cells <= 131072 or not 5 <= args.deadline_seconds <= 150:
        p.error("invalid cell budget or deadline")
    if not 1024 <= args.port <= 65535:
        p.error("choose an unprivileged local port")
    args.infer = args.infer.resolve(strict=True)
    args.compiler = args.compiler.resolve(strict=True)
    args.adapter_dir = args.adapter_dir.resolve(strict=True)
    args.model_dir = args.model_dir.resolve(strict=True)
    args.adapter_sha256 = digest(args.adapter_dir / "adapter_model.safetensors")
    if args.adapter_sha256 != ADAPTER_SHA256:
        p.error("adapter does not match independently executed step-400 candidate")
    contract = json.loads((args.adapter_dir / "inference_contract.json").read_text(encoding="utf-8"))
    args.compiler_sha256 = digest(args.compiler)
    if contract.get("compiler_sha256") != args.compiler_sha256 or contract.get("model_id") != "LiquidAI/LFM2.5-350M":
        p.error("adapter contract/compiler/model mismatch")
    args.evidence_dir = args.evidence_dir.resolve()
    args.evidence_dir.mkdir(parents=True, exist_ok=True)
    return args


def main(argv=None):
    config = arguments(argv)
    http = ThreadingHTTPServer(("127.0.0.1", config.port), make_handler(config))
    print("Local pattern bridge: http://127.0.0.1:%d/v1 (Ctrl+C to stop)" % config.port, flush=True)
    try:
        http.serve_forever(poll_interval=0.2)
    except KeyboardInterrupt:
        pass
    finally:
        http.server_close()


if __name__ == "__main__":
    main()