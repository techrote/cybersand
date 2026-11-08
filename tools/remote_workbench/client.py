#!/usr/bin/env python3
"""Bounded external client for the authenticated CyberSand workbench service.

Mutating POSTs are never retried automatically. If transport fails after a POST
may have reached the service, the stable request_id is returned so a reconnect
can query or safely resubmit the identical idempotent command.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import stat
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener

PNG_HEADER = b"\x89PNG\r\n\x1a\n"
TOOLS = ("observe", "prepare_edit", "apply_edit", "step", "stop")
OWNER_SUCCESS = {"observe": "observed", "prepare_edit": "proposed",
                 "apply_edit": "applied", "step": "completed", "stop": "stopped"}
MAX_RESPONSE_BYTES = 10 * 1024 * 1024


class NeverRedirect(HTTPRedirectHandler):
    """Never forward a bearer credential to a GitHub login or other origin."""

    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


# Local gh port forwarding speaks directly to loopback. Never honor HTTP_PROXY
# for a request that carries this workbench service's bearer credential.
OPENER = build_opener(ProxyHandler({}), NeverRedirect())


def validate_base(base: str) -> str:
    """Only the authenticated CLI port tunnel is a supported external path."""
    try:
        value = urlsplit(base)
        valid = (value.scheme == "http"
                 and value.hostname in ("localhost", "127.0.0.1", "::1")
                 and value.port is not None and 1 <= value.port <= 65535
                 and not value.username and not value.password
                 and value.path in ("", "/") and not value.query
                 and not value.fragment)
    except ValueError:
        valid = False
    if not valid:
        raise ValueError("client_requires_loopback_gh_codespace_port_tunnel")
    return base.rstrip("/")


def read_token(path: Path) -> str:
    if not path.is_file() or path.is_symlink():
        raise ValueError("token_file_not_regular")
    info = path.stat()
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
        raise ValueError("token_file_must_be_owned_by_user_and_mode_0600")
    value = path.read_text(encoding="utf-8").strip()
    encoded = value.encode("utf-8")
    if not 32 <= len(encoded) <= 256 or any(c <= 32 or c > 126 for c in encoded):
        raise ValueError("invalid_token_bytes")
    return value


def api(base: str, token: str, method: str, path: str, *,
        body: dict | None = None, timeout: float = 10.0) -> tuple[int, object]:
    data = None
    headers = {"Authorization": "Bearer " + token, "Accept": "application/json"}
    if body is not None:
        data = json.dumps(body, separators=(",", ":"), ensure_ascii=True).encode()
        headers["Content-Type"] = "application/json"
    request = Request(validate_base(base) + path, data=data, headers=headers, method=method)
    try:
        with OPENER.open(request, timeout=timeout) as response:
            raw = response.read(MAX_RESPONSE_BYTES + 1)
            if len(raw) > MAX_RESPONSE_BYTES:
                raise ValueError("response_over_client_capacity")
            media_type = response.headers.get_content_type()
            if media_type == "image/png":
                return response.status, raw
            if media_type != "application/json":
                return 502, {"error": "unexpected_content_type_not_workbench_api",
                             "upstream_status": response.status}
            try:
                return response.status, json.loads(raw or b"{}")
            except (ValueError, UnicodeError):
                return 502, {"error": "invalid_api_json_response",
                             "upstream_status": response.status}
    except HTTPError as error:
        if 300 <= error.code < 400:
            return error.code, {"error": "unexpected_redirect_not_workbench_api"}
        raw = error.read(MAX_RESPONSE_BYTES + 1)
        if len(raw) > MAX_RESPONSE_BYTES:
            return error.code, {"error": "response_over_client_capacity"}
        try:
            payload = json.loads(raw)
        except (ValueError, UnicodeError):
            payload = {"error": "http_error", "status": error.code}
        return error.code, payload


def acknowledged_success(code: int, payload: object) -> bool:
    if code != 200 or not isinstance(payload, dict):
        return False
    receipt = payload.get("receipt")
    return (payload.get("state") == "complete" and isinstance(receipt, dict)
            and receipt.get("status") == OWNER_SUCCESS.get(receipt.get("tool")))


def wait_request(base: str, token: str, request_id: str,
                 deadline: float, http_timeout: float) -> tuple[int, dict]:
    end = time.monotonic() + deadline
    last: dict | None = None
    while True:
        if time.monotonic() >= end:
            return 124, {
                "error": "client_wait_deadline",
                "request_id": request_id,
                "last": last,
            }
        try:
            code, payload = api(
                base, token, "GET", "/v1/requests/" + quote(request_id, safe=""),
                timeout=http_timeout,
            )
        except (URLError, TimeoutError, OSError) as error:
            last = {"error": "status_poll_connection_error",
                    "detail": type(error).__name__}
            time.sleep(0.2)
            continue
        if not isinstance(payload, dict):
            return 1, {"error": "non_object_request_status"}
        last = payload
        if code != 202:
            return code, payload
        time.sleep(0.15)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:8765")
    parser.add_argument("--token-file", type=Path, required=True)
    parser.add_argument("--http-timeout", type=float, default=10.0)
    parser.add_argument("--deadline", type=float, default=330.0)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("session")
    request_parser = commands.add_parser("request")
    request_parser.add_argument("request_id")
    frame_parser = commands.add_parser("frame")
    frame_parser.add_argument("name")
    frame_parser.add_argument("--output", type=Path, required=True)
    frame_parser.add_argument("--sha256", help="Expected native frame SHA-256")
    call = commands.add_parser("call")
    call.add_argument("tool", choices=TOOLS)
    call.add_argument("--args", default="{}")
    call.add_argument("--session")
    call.add_argument("--request-id")
    call.add_argument("--no-wait", action="store_true")
    args = parser.parse_args(argv)
    if not 0.5 <= args.http_timeout <= 60.0 or not 1.0 <= args.deadline <= 360.0:
        parser.error("bounded timeout/deadline violated")

    try:
        args.base = validate_base(args.base)
        token = read_token(args.token_file)
    except ValueError as error:
        print(json.dumps({"error": str(error)}, sort_keys=True))
        return 2

    try:
        if args.command == "session":
            code, payload = api(args.base, token, "GET", "/v1/session",
                                timeout=args.http_timeout)
            print(json.dumps(payload, sort_keys=True))
            return 0 if code == 200 else 1

        if args.command == "request":
            code, payload = wait_request(
                args.base, token, args.request_id, args.deadline, args.http_timeout
            )
            print(json.dumps(payload, sort_keys=True))
            return 0 if acknowledged_success(code, payload) else 1

        if args.command == "frame":
            code, payload = api(
                args.base, token, "GET",
                "/v1/frames/" + quote(args.name, safe=""),
                timeout=args.http_timeout,
            )
            if (code != 200 or not isinstance(payload, (bytes, bytearray))
                    or not payload.startswith(PNG_HEADER)):
                print(json.dumps(
                    payload if isinstance(payload, dict) else {"error": "invalid_frame"},
                    sort_keys=True,
                ))
                return 1
            digest = hashlib.sha256(payload).hexdigest()
            if args.sha256 is not None and digest != args.sha256.lower():
                print(json.dumps({"error": "frame_sha256_mismatch", "actual_sha256": digest},
                                 sort_keys=True))
                return 1
            args.output.parent.mkdir(parents=True, exist_ok=True)
            fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as stream:
                stream.write(payload)
            print(json.dumps({"path": str(args.output), "bytes": len(payload),
                              "sha256": digest},
                             sort_keys=True))
            return 0

        tool_args = json.loads(args.args)
        if not isinstance(tool_args, dict):
            raise ValueError("--args must decode to object")
        request_id = args.request_id or ("req-" + secrets.token_hex(12))
        session_id = args.session
        if session_id is None:
            code, snapshot = api(args.base, token, "GET", "/v1/session",
                                 timeout=args.http_timeout)
            if code != 200 or not isinstance(snapshot, dict):
                print(json.dumps(snapshot, sort_keys=True))
                return 1
            session_id = snapshot.get("session_id")

        document = {
            "session_id": session_id,
            "request_id": request_id,
            "tool": args.tool,
            "args": tool_args,
        }
        try:
            code, payload = api(
                args.base, token, "POST", "/v1/commands",
                body=document, timeout=args.http_timeout,
            )
        except (URLError, TimeoutError, OSError) as error:
            print(json.dumps({
                "error": "submission_outcome_unknown",
                "request_id": request_id,
                "session_id": session_id,
                "detail": type(error).__name__,
                "recovery": (
                    "reconnect and query this request_id; if unknown, resubmit "
                    "the identical command with the same request_id"
                ),
            }, sort_keys=True))
            return 3
        if code not in (200, 202) or not isinstance(payload, dict):
            print(json.dumps(payload, sort_keys=True))
            return 1
        if args.no_wait or code == 200:
            print(json.dumps(payload, sort_keys=True))
            return (0 if (code == 202 and payload.get("state") == "pending")
                    or acknowledged_success(code, payload) else 1)
        code, payload = wait_request(
            args.base, token, request_id, args.deadline, args.http_timeout
        )
        print(json.dumps(payload, sort_keys=True))
        return 0 if acknowledged_success(code, payload) else 1
    except (ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"error": "client_argument_error", "detail": str(error)},
                         sort_keys=True))
        return 2
    except (URLError, TimeoutError, OSError) as error:
        print(json.dumps({"error": "connection_error",
                          "detail": type(error).__name__}, sort_keys=True))
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
