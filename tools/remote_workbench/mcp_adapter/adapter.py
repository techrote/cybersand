#!/usr/bin/env python3
"""Model-neutral MCP ingress for #547's loopback-only authenticated client.

Does not create a World, authorize a task, forward arbitrary URLs, or execute code.
The trusted host owns both credentials and its authenticated private GitHub
Codespaces port-forward. See README.md before connecting any model host.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import sys
import threading
from urllib.error import URLError
from urllib.parse import quote, urlsplit

# Import the ACTUAL qualified #547 HTTP client, not a replacement transport.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import client  # noqa: E402

VERSION = "0.1.0"
PROTOCOL = "2025-11-25"
SUPPORTED = ("2025-11-25", "2025-06-18", "2025-03-26")
ID = re.compile(r"^[A-Za-z0-9_-]{8,80}$")
FRAME = re.compile(r"^frames/[0-9]{3}-(?:observe|step)\.png$")
DIGEST = re.compile(r"^[0-9a-f]{64}$")
PNG_HEADER = b"\x89PNG\r\n\x1a\n"
MAX_MCP_REQUEST = 128 * 1024
MAX_LOCAL_REQUESTS = 512
MAX_IMAGE = 6 * 1024 * 1024
MAX_MCP_RESULT = 9 * 1024 * 1024
UPSTREAM_TIMEOUT = 10.0
UPSTREAM_WAIT = 80.0

REGION = {"type": "object", "additionalProperties": False,
          "required": ["x", "y", "width", "height"], "properties": {
              "x": {"type": "integer", "minimum": 0},
              "y": {"type": "integer", "minimum": 0},
              "width": {"type": "integer", "minimum": 1, "maximum": 4096},
              "height": {"type": "integer", "minimum": 1, "maximum": 4096}}}
OP = {"type": "object", "additionalProperties": False,
      "required": ["shape", "material"], "properties": {
          "shape": {"enum": ["rectangle", "line", "disc"]},
          "material": {"type": "integer", "enum": [0, 58]},
          "replace_only_material": {"type": ["integer", "null"], "enum": [0, 58, None]},
          "x": {"type": "integer", "minimum": 0},
          "y": {"type": "integer", "minimum": 0},
          "radius": {"type": "integer", "minimum": 0, "maximum": 36},
          "x0": {"type": "integer", "minimum": 0},
          "y0": {"type": "integer", "minimum": 0},
          "x1": {"type": "integer", "minimum": 0},
          "y1": {"type": "integer", "minimum": 0}}}
REQUEST_ID = {"type": "string", "pattern": ID.pattern, "minLength": 8, "maxLength": 80}

def schema(properties: dict, required=()) -> dict:
    return {"type": "object", "additionalProperties": False,
            "properties": properties, "required": list(required)}

TOOLS = [
    {"name": "session_status", "description": "Read the one existing native World session. Optionally recover an existing request ID using GET only; never replay an uncertain mutation.",
     "inputSchema": schema({"request_id": REQUEST_ID}), "annotations": {"readOnlyHint": True}},
    {"name": "observe", "description": "Inspect actual bounded native material IDs and ORIGINAL post-draw PNG. Never infer material IDs from color.",
     "inputSchema": schema({"region": {"anyOf": [REGION, {"type": "null"}]},
                            "detail": {"enum": ["cells", "counts"]}, "request_id": REQUEST_ID}),
     "annotations": {"readOnlyHint": True}},
    {"name": "prepare_edit", "description": "Prepare one bounded native-validated proposal from a confirmed observation; does not change the World.",
     "inputSchema": schema({"observation_id": {"type": "string", "minLength": 1, "maxLength": 160},
                            "operations": {"type": "array", "items": OP, "minItems": 1, "maxItems": 8},
                            "request_id": REQUEST_ID}, ("observation_id", "operations")),
     "annotations": {"readOnlyHint": False}},
    {"name": "apply_edit", "description": "Apply an existing fenced proposal once, with actual native readback; reusing a request ID never enqueues twice.",
     "inputSchema": schema({"proposal_id": {"type": "string", "minLength": 1, "maxLength": 160},
                            "request_id": REQUEST_ID}, ("proposal_id",)),
     "annotations": {"readOnlyHint": False, "destructiveHint": False}},
    {"name": "step", "description": "Advance the SAME paused native World 1-120 acknowledged ticks and inspect its ORIGINAL post-draw PNG.",
     "inputSchema": schema({"ticks": {"type": "integer", "minimum": 1, "maximum": 120},
                            "request_id": REQUEST_ID}, ("ticks",)),
     "annotations": {"readOnlyHint": False}},
    {"name": "stop", "description": "Queue native Stop and wait for its acknowledgement; may retire the sole World. Pending is NOT stopped.",
     "inputSchema": schema({"request_id": REQUEST_ID}),
     "annotations": {"readOnlyHint": False, "destructiveHint": True}},
]
TOOL_NAMES = {entry["name"] for entry in TOOLS}
MODEL_ACTIONS = TOOL_NAMES - {"session_status"}

def _integer(value: object, low: int = 0, high: int = 2_147_483_647) -> bool:
    return type(value) is int and low <= value <= high


def validate(name: str, args: object) -> dict:
    if name not in TOOL_NAMES or not isinstance(args, dict):
        raise ValueError("unsupported_tool_or_arguments")
    properties = next(t["inputSchema"]["properties"] for t in TOOLS if t["name"] == name)
    if not set(args).issubset(properties):
        raise ValueError("unknown_tool_argument")
    rid = args.get("request_id")
    if rid is not None and (not isinstance(rid, str) or not ID.fullmatch(rid)):
        raise ValueError("invalid_request_id")
    if name == "session_status" or name == "stop":
        return dict(args)
    if name == "observe":
        detail = args.get("detail", "cells")
        if detail not in ("cells", "counts"):
            raise ValueError("invalid_observation_detail")
        region = args.get("region")
        if region is not None:
            if not isinstance(region, dict) or set(region) != {"x", "y", "width", "height"}:
                raise ValueError("invalid_region")
            if not all(_integer(region[k]) for k in ("x", "y")) or not all(
                    _integer(region[k], 1, 4096) for k in ("width", "height")):
                raise ValueError("invalid_region")
            if region["width"] * region["height"] > 4096:
                raise ValueError("observation_over_4096_cells")
        return dict(args)
    if name == "step":
        if not _integer(args.get("ticks"), 1, 120):
            raise ValueError("invalid_step_count")
        return dict(args)
    if name == "apply_edit":
        if not isinstance(args.get("proposal_id"), str) or not 1 <= len(args["proposal_id"]) <= 160:
            raise ValueError("invalid_proposal_id")
        return dict(args)
    if not isinstance(args.get("observation_id"), str) or not 1 <= len(args["observation_id"]) <= 160:
        raise ValueError("invalid_observation_id")
    ops = args.get("operations")
    if not isinstance(ops, list) or not 1 <= len(ops) <= 8:
        raise ValueError("invalid_operation_count")
    for op in ops:
        if not isinstance(op, dict) or not set(op).issubset(OP["properties"]):
            raise ValueError("invalid_operation_fields")
        shape = op.get("shape")
        fields = {"rectangle": ("x0", "y0", "x1", "y1"),
                  "line": ("x0", "y0", "x1", "y1"),
                  "disc": ("x", "y", "radius")}.get(shape)
        if fields is None or set(op) - {"shape", "material", "replace_only_material"} != set(fields):
            raise ValueError("invalid_shape_fields")
        if not _integer(op.get("material")) or op["material"] not in (0, 58):
            raise ValueError("unsupported_material")
        if "replace_only_material" in op and op["replace_only_material"] not in (None, 0, 58):
            raise ValueError("unsupported_filter")
        if not all(_integer(op[k], 0, 36 if k == "radius" else 2_147_483_647) for k in fields):
            raise ValueError("noninteger_or_unbounded_geometry")
    return dict(args)


def _error(reason: str, **details: object) -> tuple[dict, None]:
    return {"ok": False, "error": reason, **details}, None


class WorkbenchAdapter:
    """One adapter -> one immutable upstream session until trusted-host restart."""
    def __init__(self, base: str, token_file: Path):
        self.base = client.validate_base(base)
        self.token = client.read_token(token_file)
        self.bound_session: str | None = None
        self.records: dict[str, str] = {}
        self.mutation_lock = threading.Lock()
        self.state_lock = threading.Lock()

    def _call(self, method: str, path: str, *, body: dict | None = None):
        try:
            return client.api(self.base, self.token, method, path,
                              body=body, timeout=UPSTREAM_TIMEOUT)
        except ValueError as ex:
            # A too-large/malformed upstream reply can occur AFTER native
            # execution. Treat it exactly as an uncertain transport outcome.
            raise OSError("upstream_protocol_or_response_capacity_failure") from ex

    def _identity(self, sid: object) -> bool:
        if not isinstance(sid, str) or not sid:
            return False
        with self.state_lock:
            if self.bound_session is None:
                self.bound_session = sid
            return self.bound_session == sid

    def status(self, request_id: str | None = None) -> tuple[dict, bytes | None]:
        try:
            code, snapshot = self._call("GET", "/v1/session")
        except (URLError, TimeoutError, OSError):
            return _error("upstream_session_unreachable")
        if code != 200 or not isinstance(snapshot, dict):
            return _error("upstream_session_unavailable", upstream_http=code)
        sid = snapshot.get("session_id")
        if not self._identity(sid):
            return _error("upstream_session_changed_restart_adapter", current_phase=snapshot.get("phase"))
        if not request_id:
            return {"ok": True, "session": snapshot}, None
        try:
            code, receipt = self._call("GET", "/v1/requests/" + quote(request_id, safe=""))
        except (URLError, TimeoutError, OSError):
            return _error("request_status_unreachable", request_id=request_id, uncertain=True)
        if code == 404:
            return _error("request_not_found_no_replay", request_id=request_id, uncertain=True)
        if code not in (200, 202) or not isinstance(receipt, dict):
            return _error("upstream_request_status_failed", request_id=request_id, upstream_http=code)
        return self._receipt(receipt, request_id)

    def _receipt(self, envelope: dict, request_id: str) -> tuple[dict, bytes | None]:
        if envelope.get("state") != "complete":
            return {"ok": False, "uncertain": True, "request_id": request_id,
                    "state": envelope.get("state"), "envelope": envelope,
                    "recovery": "session_status(request_id) GET only; never blindly replay"}, None
        receipt = envelope.get("receipt")
        if not isinstance(receipt, dict):
            return _error("missing_native_receipt", request_id=request_id, uncertain=True)
        tool = receipt.get("tool")
        native_status = receipt.get("status")
        if tool not in client.OWNER_SUCCESS or native_status != client.OWNER_SUCCESS[tool]:
            return {"ok": False, "request_id": request_id,
                    "error": "native_refused_or_unconfirmed", "envelope": envelope}, None
        image = None
        if tool in ("observe", "step"):
            frame = receipt.get("frame")
            if not isinstance(frame, dict) or frame.get("status") != "original_post_draw":
                return _error("native_frame_identity_missing", request_id=request_id, uncertain=True)
            path, sha = frame.get("path"), frame.get("sha256")
            if not isinstance(path, str) or not FRAME.fullmatch(path) or not isinstance(sha, str) or not DIGEST.fullmatch(sha):
                return _error("untrusted_native_frame_reference", request_id=request_id)
            try:
                code, image = self._call("GET", "/v1/frames/" + quote(path[7:], safe=""))
            except (URLError, TimeoutError, OSError):
                return _error("native_frame_download_uncertain", request_id=request_id, uncertain=True)
            if (code != 200 or not isinstance(image, bytes) or len(image) > MAX_IMAGE
                    or not image.startswith(PNG_HEADER) or hashlib.sha256(image).hexdigest() != sha):
                return _error("original_png_integrity_failure", request_id=request_id, uncertain=True)
        return {"ok": True, "request_id": request_id, "envelope": envelope,
                "original_png_sha256": (hashlib.sha256(image).hexdigest() if image else None)}, image

    def invoke(self, name: str, raw_args: object) -> tuple[dict, bytes | None]:
        try:
            args = validate(name, raw_args)
        except ValueError as ex:
            return _error(str(ex))
        if name == "session_status":
            return self.status(args.get("request_id"))
        rid = args.pop("request_id", None) or ("req-mcp-" + secrets.token_hex(12))
        fingerprint = hashlib.sha256(json.dumps({"tool": name, "args": args},
                        sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        with self.mutation_lock:
            if rid in self.records:
                if self.records[rid] != fingerprint:
                    return _error("idempotency_key_reused_with_different_command", request_id=rid)
                return self.status(rid)  # GET-only recovery; NO replay on uncertainty.
            state, _ = self.status()
            if not state.get("ok"):
                return state, None
            snapshot = state["session"]
            sid = snapshot.get("session_id")
            if snapshot.get("phase") != "ready" and name != "stop":
                return _error("session_not_ready", phase=snapshot.get("phase"))
            if len(self.records) >= MAX_LOCAL_REQUESTS - 1 and name != "stop":
                return _error("adapter_request_retention_capacity_reached")
            self.records[rid] = fingerprint  # record BEFORE possibly-reaching POST
            try:
                code, response = self._call("POST", "/v1/commands", body={
                    "session_id": sid, "request_id": rid, "tool": name, "args": args})
            except (URLError, TimeoutError, OSError):
                recovered, image = self.status(rid)
                if recovered.get("ok"):
                    return recovered, image
                return _error("submission_outcome_unknown", request_id=rid,
                              uncertain=True, recovery="session_status(request_id) GET; no POST replay")
            if code not in (200, 202) or not isinstance(response, dict):
                return _error("upstream_command_rejected", request_id=rid,
                              upstream_http=code,
                              native_error=(response.get("error") if isinstance(response, dict) else None))
            if code == 202:
                try:
                    code, response = client.wait_request(
                        self.base, self.token, rid, UPSTREAM_WAIT, UPSTREAM_TIMEOUT)
                except (URLError, TimeoutError, OSError):
                    code = 124
                if code not in (200, 202):
                    return self.status(rid)
            if not isinstance(response, dict):
                return _error("invalid_upstream_result", request_id=rid, uncertain=True)
            return self._receipt(response, rid)


def result_to_mcp(data: dict, png: bytes | None) -> dict:
    # Structured receipts and image are separate content blocks: the image is
    # real model-visible MIME data, NOT a filesystem path nor a text base64.
    content = [{"type": "text", "text": json.dumps(data, sort_keys=True, separators=(",", ":"))}]
    if png is not None:
        content.append({"type": "image", "mimeType": "image/png",
                        "data": base64.b64encode(png).decode("ascii")})
    return {"content": content, "structuredContent": data,
            "isError": not data.get("ok", False)}


class MCPServer(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 8

    def __init__(self, address: tuple[str, int], adapter: WorkbenchAdapter, token: str):
        self.adapter = adapter
        self.mcp_token = token
        super().__init__(address, MCPHandler)


class MCPHandler(BaseHTTPRequestHandler):
    server: MCPServer
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        # No request bodies, auth headers, upstream token, or paths in logs.
        return

    def _send(self, code: int, doc: dict | None = None) -> None:
        raw = json.dumps(doc, separators=(",", ":")).encode() if doc is not None else b""
        if len(raw) > MAX_MCP_RESULT:
            code, raw = 507, b'{"error":"mcp_response_capacity_exceeded"}'
        self.send_response(code)
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Connection", "close")
        self.close_connection = True
        self.end_headers()
        if raw:
            self.wfile.write(raw)

    def _authorized(self) -> bool:
        value = self.headers.get("Authorization", "")
        expected = "Bearer " + self.server.mcp_token
        if not hmac.compare_digest(value.encode("utf-8", errors="replace"), expected.encode()):
            self._send(401, {"error": "mcp_bearer_required"})
            return False
        # Local-only origin/Host validation prevents DNS-rebinding ingress.
        origin = self.headers.get("Origin")
        if origin is not None:
            if origin not in (f"http://localhost:{self.server.server_port}",
                              f"http://127.0.0.1:{self.server.server_port}"):
                self._send(403, {"error": "invalid_mcp_origin"})
                return False
        try:
            host = urlsplit("http://" + self.headers.get("Host", "")).hostname
            port = urlsplit("http://" + self.headers.get("Host", "")).port
        except ValueError:
            host, port = None, None
        if host not in ("localhost", "127.0.0.1") or port != self.server.server_port:
            self._send(403, {"error": "invalid_mcp_host"})
            return False
        return True

    def do_GET(self) -> None:
        if not self._authorized():
            return
        self._send(405, {"error": "stateless_mcp_post_only"})

    def do_POST(self) -> None:
        if not self._authorized():
            return
        if self.path != "/mcp":
            self._send(404, {"error": "not_found"})
            return
        if self.headers.get("Content-Type", "").split(";")[0].strip() != "application/json":
            self._send(415, {"error": "mcp_json_required"})
            return
        try:
            length = int(self.headers.get("Content-Length", ""))
        except ValueError:
            self._send(411, {"error": "bounded_content_length_required"})
            return
        if not 0 < length <= MAX_MCP_REQUEST:
            self._send(413, {"error": "mcp_request_over_capacity"})
            return
        try:
            packet = json.loads(self.rfile.read(length))
        except (ValueError, UnicodeError):
            self._send(400, {"error": "invalid_json"})
            return
        if not isinstance(packet, dict) or packet.get("jsonrpc") != "2.0":
            self._send(400, {"error": "invalid_jsonrpc"})
            return
        method = packet.get("method")
        ident = packet.get("id")
        if ident is None:
            if method == "notifications/initialized":
                self._send(202)
            else:
                self._send(400, {"error": "unsupported_notification"})
            return
        if not isinstance(ident, (str, int)) or isinstance(ident, bool) or len(str(ident)) > 80:
            self._send(400, {"error": "invalid_jsonrpc_id"})
            return
        params = packet.get("params") or {}
        answer = {"jsonrpc": "2.0", "id": ident}
        if not isinstance(params, dict):
            answer["error"] = {"code": -32602, "message": "Invalid params"}
        elif method == "initialize":
            requested = params.get("protocolVersion")
            version = requested if requested in SUPPORTED else PROTOCOL
            answer["result"] = {"protocolVersion": version,
                                "capabilities": {"tools": {"listChanged": False}},
                                "serverInfo": {"name": "cybersand-workbench", "version": VERSION}}
        elif method == "ping":
            answer["result"] = {}
        elif method == "tools/list":
            answer["result"] = {"tools": TOOLS}
        elif method == "tools/call":
            name, arguments = params.get("name"), params.get("arguments", {})
            data, png = self.server.adapter.invoke(name, arguments)
            answer["result"] = result_to_mcp(data, png)
        else:
            answer["error"] = {"code": -32601, "message": "Method not found"}
        self._send(200, answer)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:8765")
    parser.add_argument("--workbench-token-file", type=Path, required=True)
    parser.add_argument("--mcp-token-file", type=Path, required=True)
    parser.add_argument("--port", type=int, default=8766)
    args = parser.parse_args(argv)
    if not 1024 <= args.port <= 65535:
        parser.error("port must be 1024-65535")
    if args.workbench_token_file.resolve() == args.mcp_token_file.resolve():
        parser.error("MCP and workbench tokens must be independent")
    try:
        adapter = WorkbenchAdapter(args.base, args.workbench_token_file)
        mcp_token = client.read_token(args.mcp_token_file)
    except (OSError, ValueError) as ex:
        parser.error("invalid trusted-host configuration: " + type(ex).__name__)
    with MCPServer(("127.0.0.1", args.port), adapter, mcp_token) as server:
        server.serve_forever(poll_interval=0.15)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
