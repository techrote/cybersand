"""Bounded, keyless invalid-local-model/Art-close reproduction for issue #744.

Uses one loopback-only threaded test server and the actual Workbench/Godot
provider UI. A timeout or crash fails; no cloud request, API key or model load.
"""
from __future__ import annotations

import argparse
from contextlib import ExitStack, contextmanager
import http.server
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
MARKER = "ART_LOCAL_CLOSE_RESULT "
SCRIPT_ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_args):
        return

    def do_POST(self):
        if self.client_address[0] not in ("127.0.0.1", "::1"):
            self.send_error(403)
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if size < 1 or size > 1_000_000 or not self.path.endswith("/chat/completions"):
                self.send_error(400)
                return
            data = json.loads(self.rfile.read(size))
            model = data["model"]
            if not isinstance(model, str):
                self.send_error(400)
                return
            if model == "fixture-invalid-slow":
                time.sleep(0.6)
            if model == "fixture-valid":
                code = 200
                response = {"choices": [{"message": {"content": "[]"}, "finish_reason": "stop"}]}
            else:
                code = 404
                response = {"error": {"type": "invalid_model", "message": "Unknown local model"}}
            payload = json.dumps(response, separators=(",", ":")).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            pass


@contextmanager
def loopback_fixture():
    """Supply the same bounded HTTP fixture to focused and shard runners."""
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}/v1"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--godot", required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--project", type=Path, default=ROOT / "godot")
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if not Path(args.godot).is_file():
        raise SystemExit("Godot executable not found")
    env = dict(os.environ)
    if sys.platform == "win32":
        env["APPDATA"] = str((args.output / "isolated-profile").resolve())
        Path(env["APPDATA"]).mkdir(parents=True, exist_ok=True)
    else:
        env["XDG_DATA_HOME"] = str((args.output / "isolated-profile").resolve())
        Path(env["XDG_DATA_HOME"]).mkdir(parents=True, exist_ok=True)
    command = [args.godot, "--headless", "--path", str(args.project.resolve()),
               "--script", "res://tests/test_art_local_close.gd"]
    log = args.output / "art-close.log"
    with ExitStack() as fixtures:
        env["WB_ART_CLOSE_ENDPOINT"] = fixtures.enter_context(loopback_fixture())
        with log.open("w", encoding="utf-8") as out:
            proc = subprocess.run(command, cwd=ROOT, env=env, stdout=out,
                                  stderr=subprocess.STDOUT, timeout=240, check=False)
        output = log.read_text(encoding="utf-8", errors="replace")
        if proc.returncode != 0 or SCRIPT_ERRORS.search(output):
            raise RuntimeError(f"Art close reproduction failed (exit={proc.returncode}); see {log}\n{output[-7000:]}")
        receipts = [line[len(MARKER):] for line in output.splitlines() if line.startswith(MARKER)]
        if len(receipts) != 1:
            raise RuntimeError("Expected exactly one bounded Art-close receipt")
        report = json.loads(receipts[0])
        if report["failures"] or report["checks"] < 40 or len(report["cases"]) != 9:
            raise RuntimeError(f"Art close check failures/unexecuted cases: {report.get('failures')}")
        for case in report["cases"]:
            if "url" in case["provider"] or "key" in case["provider"]:
                raise RuntimeError("Diagnostic unexpectedly contains endpoint or credential")
        (args.output / "art-close-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Art local close: {report['checks']} checks, {len(report['cases'])} cases, no cloud inference.")


if __name__ == "__main__":
    main()
