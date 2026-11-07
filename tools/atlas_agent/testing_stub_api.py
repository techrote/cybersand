"""Loopback HTTP test double for the OpenAI endpoints the runner touches.

TEST SUPPORT ONLY - never imported by the runner. It lets the *real* official SDK
speak HTTP to 127.0.0.1 so retry, usage, header and error handling are exercised
without a chargeable request. A scripted queue decides each ``POST /v1/responses``
reply; every request (path, headers sans nothing hidden, JSON body) is recorded.
"""
from __future__ import annotations

import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def usage(input_tokens: int = 1200, output_tokens: int = 100, cached: int = 0, reasoning: int = 0) -> dict:
    return {"input_tokens": input_tokens, "input_tokens_details": {"cached_tokens": cached},
            "output_tokens": output_tokens, "output_tokens_details": {"reasoning_tokens": reasoning},
            "total_tokens": input_tokens + output_tokens}


def function_call(name: str, arguments: dict | str, call_id: str) -> dict:
    return {"type": "function_call", "id": f"fc_{call_id}", "call_id": call_id, "name": name,
            "arguments": arguments if isinstance(arguments, str) else json.dumps(arguments), "status": "completed"}


def message(text: str) -> dict:
    return {"type": "message", "id": "msg_1", "role": "assistant", "status": "completed",
            "content": [{"type": "output_text", "text": text, "annotations": []}]}


def response_body(output: list, model: str = "gpt-5.4-mini-2026-01-01", status: str = "completed",
                  use: dict | None = None, incomplete: dict | None = None, resp_id: str = "resp_test") -> dict:
    return {"id": resp_id, "object": "response", "created_at": 1_700_000_000, "status": status, "model": model,
            "output": output, "usage": use if use is not None else usage(), "parallel_tool_calls": True,
            "tool_choice": "auto", "tools": [], "error": None, "incomplete_details": incomplete, "metadata": {},
            "temperature": 1.0, "top_p": 1.0, "store": False, "truncation": "disabled", "text": {"format": {"type": "text"}}}


def ok(body: dict, headers: dict | None = None) -> tuple[int, dict, dict]:
    return 200, headers or {}, body


def error(status: int, code: str, message_text: str = "error", headers: dict | None = None) -> tuple[int, dict, dict]:
    return status, headers or {}, {"error": {"message": message_text, "type": code, "code": code, "param": None}}


class StubApi:
    def __init__(self, models: dict[str, tuple[int, dict]] | None = None, costs: dict | None = None):
        self.queue: list = []
        self.requests: list[dict] = []
        self.models = models if models is not None else {}
        self.costs = costs
        self.default = None
        stub = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):  # silence
                pass

            def _send(self, status: int, headers: dict, body: dict):
                payload = json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                for key, value in headers.items():
                    self.send_header(key, value)
                self.end_headers()
                self.wfile.write(payload)

            def do_GET(self):
                stub.requests.append({"method": "GET", "path": self.path, "headers": dict(self.headers), "body": None})
                if self.path.startswith("/v1/models/"):
                    model = self.path.rsplit("/", 1)[1]
                    status, headers = stub.models.get(model, (404, {}))
                    body = {"id": model, "object": "model", "created": 1, "owned_by": "test"} if status == 200 else \
                        {"error": {"message": "no such model", "type": "invalid_request_error", "code": "model_not_found"}}
                    return self._send(status, headers, body)
                if self.path.startswith("/v1/organization/costs"):
                    if stub.costs is None:
                        return self._send(404, {}, {"error": {"message": "n/a", "type": "x", "code": "x"}})
                    return self._send(200, {}, stub.costs)
                self._send(404, {}, {"error": {"message": "unknown", "type": "x", "code": "x"}})

            def do_POST(self):
                length = int(self.headers.get("Content-Length", "0"))
                raw = self.rfile.read(length).decode("utf-8") if length else ""
                try:
                    body = json.loads(raw) if raw else None
                except ValueError:
                    body = None
                stub.requests.append({"method": "POST", "path": self.path, "headers": dict(self.headers), "body": body})
                if self.path != "/v1/responses":
                    return self._send(404, {}, {"error": {"message": "unknown", "type": "x", "code": "x"}})
                step = stub.queue.pop(0) if stub.queue else stub.default
                if step is None:
                    return self._send(500, {}, {"error": {"message": "stub queue empty", "type": "x", "code": "x"}})
                if callable(step):
                    step = step(body)
                self._send(*step)

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    @property
    def base_url(self) -> str:
        return f"http://127.0.0.1:{self.server.server_address[1]}/v1"

    def response_posts(self) -> list[dict]:
        return [r for r in self.requests if r["method"] == "POST"]

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *exc):
        self.server.shutdown()
        self.server.server_close()
