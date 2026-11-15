"""Exercise actual workflow selectors and bounded download retry behavior."""

from fnmatch import fnmatchcase
import os
from pathlib import Path
import re
import shlex
import shutil
import socket
import socketserver
import struct
import subprocess
import tempfile
import threading
import unittest

import execution_policy


SOURCE = (execution_policy.ROOT / ".github/workflows/gdextension.yml").read_text(encoding="utf-8")
RUN_ID = "43742182904"
# Observed shard 11: the older attempt has the higher artifact ID.
OLD_ID, CURRENT_ID = 14174380870, 14174033548


def workflow_steps():
    jobs = list(re.finditer(r"^  ([\w-]+):\n", SOURCE, re.M))
    for index, job in enumerate(jobs):
        block = SOURCE[job.end():jobs[index + 1].start() if index + 1 < len(jobs) else len(SOURCE)]
        steps = list(re.finditer(r"^      - name: (.+)\n", block, re.M))
        for number, step in enumerate(steps):
            body = block[step.end():steps[number + 1].start() if number + 1 < len(steps) else len(block)]
            yield job[1], step[1], body


def artifact_steps():
    result = []
    for job, label, body in workflow_steps():
        action = re.search(r"^        uses: actions/(upload|download)-artifact@", body, re.M)
        if action:
            selector = re.search(r"^          (name|pattern): (.+)$", body, re.M)
            if not selector:
                raise ValueError(f"Artifact action has no explicit selector: {job}/{label}")
            result.append({"job": job, "label": label, "action": action[1],
                           "field": selector[1], "template": selector[2].strip("'\"")})
    return result


def expand(template, attempt, shard=11):
    values = {"github.run_id": RUN_ID, "github.run_attempt": str(attempt), "matrix.shard": str(shard)}
    return re.sub(r"\$\{\{\s*(.*?)\s*\}\}", lambda match: values[match[1]], template)


def latest_then_match(rows, selector):
    # Model the pinned artifact client's ordering, including the observed bad
    # ordering across attempts. The workflow must not depend on increasing IDs.
    latest = {}
    for row in sorted(rows, key=lambda row: row["id"], reverse=True):
        latest.setdefault(row["name"], row)
    return [row for name, row in latest.items() if fnmatchcase(name, selector)]


class ArtifactAttemptTests(unittest.TestCase):
    def test_observed_reversed_ids_reproduce_old_bug_and_current_scope_is_exact(self):
        steps = artifact_steps()
        producer = next(row for row in steps if row["job"] == "linux-regression" and row["action"] == "upload")
        consumer = next(row for row in steps if row["job"] == "linux-regression-gate" and row["field"] == "pattern")
        for legacy in (True, False):
            upload, download = producer["template"], consumer["template"]
            if legacy:
                upload = upload.replace("-${{ github.run_attempt }}", "")
                download = download.replace("-${{ github.run_attempt }}", "")
            rows = [{"id": artifact_id, "name": expand(upload, attempt), "attempt": attempt}
                    for artifact_id, attempt in ((OLD_ID, 1), (CURRENT_ID, 2))]
            selected = latest_then_match(rows, expand(download, 2))
            self.assertEqual(len(selected), 1)
            self.assertEqual(selected[0]["id"], OLD_ID if legacy else CURRENT_ID)
            self.assertEqual(selected[0]["attempt"], 1 if legacy else 2)

    def test_every_producer_and_consumer_isolated_from_previous_attempt(self):
        steps = artifact_steps()
        rows = []
        for producer in (row for row in steps if row["action"] == "upload"):
            for shard in ([0, 11] if "matrix.shard" in producer["template"] else [0]):
                old_name, current_name = (expand(producer["template"], attempt, shard) for attempt in (1, 2))
                self.assertNotEqual(old_name, current_name, producer["label"])
                for attempt, name in ((1, old_name), (2, current_name)):
                    rows.append({"id": (20_000_000_000 if attempt == 1 else 10_000_000_000) + len(rows),
                                 "name": name, "attempt": attempt, "producer": producer["job"]})
        self.assertEqual(len({row["name"] for row in rows}), len(rows))
        for consumer in (row for row in steps if row["action"] == "download"):
            with self.subTest(job=consumer["job"], step=consumer["label"]):
                selector = expand(consumer["template"], 2)
                expected = [row for row in rows if row["attempt"] == 2 and fnmatchcase(row["name"], selector)]
                selected = latest_then_match(rows, selector)
                self.assertTrue(expected, "Consumer must match an actual current-attempt producer")
                self.assertEqual({row["id"] for row in selected}, {row["id"] for row in expected})
                self.assertTrue(all(row["attempt"] == 2 for row in selected))
                if consumer["label"] == "Fetch existing per-platform Godot test evidence":
                    self.assertEqual({row["producer"] for row in selected}, {"linux-regression", "windows-regression"})

    def test_missing_current_artifact_never_falls_back_to_an_older_attempt(self):
        steps = artifact_steps()
        old_rows = [{"id": OLD_ID + index, "name": expand(row["template"], 1)}
                    for index, row in enumerate(steps) if row["action"] == "upload"]
        for consumer in (row for row in steps if row["action"] == "download"):
            with self.subTest(step=consumer["label"]):
                self.assertEqual(latest_then_match(old_rows, expand(consumer["template"], 2)), [])


class ResetHandler(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.settimeout(5)
        self.request.recv(8192)
        self.server.requests += 1
        if self.server.requests <= self.server.resets:
            linger = struct.pack("hh" if os.name == "nt" else "ii", 1, 0)
            self.request.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, linger)
            self.request.close()
            return
        body = self.server.payload
        self.request.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: " + str(len(body)).encode()
                             + b"\r\nConnection: close\r\n\r\n" + body)


class DownloadRetryTests(unittest.TestCase):
    def setUp(self):
        self.downloads = [(job, body) for job, _label, body in workflow_steps()
                          if '"$GODOT_URL"' in body and " curl " in body]
        self.assertEqual({job for job, _body in self.downloads}, {"art-graphical-smoke", "linux-regression"})
        self.curl = shutil.which("curl")
        self.assertIsNotNone(self.curl, "The hosted download control requires curl")

    def command(self, body, directory, url):
        line = next(line for line in body.splitlines() if " curl " in line)
        arguments = shlex.split(line.split(" curl ", 1)[1])
        seconds = str(int(execution_policy.watchdog_seconds("dependency_prepare_seconds")))
        return [self.curl, *[part.replace("$RUNNER_TEMP", str(directory)).replace("$GODOT_URL", url)
                            .replace("$godot_download_seconds", seconds) for part in arguments]]

    def exercise(self, resets):
        with tempfile.TemporaryDirectory() as temporary, socketserver.TCPServer(("127.0.0.1", 0), ResetHandler) as server:
            server.requests, server.resets, server.payload = 0, resets, b"pinned runtime transport control\n"
            thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True)
            thread.start()
            try:
                url = f"http://127.0.0.1:{server.server_address[1]}/godot.zip"
                command = self.command(self.downloads[0][1], Path(temporary), url)
                # Both actual Linux download sites must run the same policy.
                self.assertEqual(command, self.command(self.downloads[1][1], Path(temporary), url))
                result = subprocess.run(command, capture_output=True, timeout=30,
                                        env={**os.environ, "NO_PROXY": "127.0.0.1"})
                payload_path = Path(temporary) / "godot.zip"
                return result, server.requests, payload_path.read_bytes() if payload_path.exists() else b"", server.payload
            finally:
                server.shutdown()
                thread.join(timeout=5)
                self.assertFalse(thread.is_alive())

    def test_connection_reset_is_retried_and_complete_bytes_are_downloaded(self):
        result, requests, downloaded, expected = self.exercise(1)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(requests, 2)
        self.assertEqual(downloaded, expected)

    def test_permanent_transport_failure_exhausts_bounded_retries(self):
        result, requests, _downloaded, _expected = self.exercise(100)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(requests, 4, "One initial request and three ordinary retries")

    def test_existing_outer_watchdog_and_digest_pin_are_still_required(self):
        for job, body in self.downloads:
            with self.subTest(job=job):
                self.assertIn('godot_download_seconds="$(python3 tools/ci/execution_policy.py seconds dependency_prepare_seconds)"', body)
                self.assertIn('timeout "$godot_download_seconds" curl ', body)
                self.assertIn('--retry-max-time "$godot_download_seconds"', body)
                self.assertIn('echo "$GODOT_SHA256  $RUNNER_TEMP/godot.zip" | sha256sum --check --strict', body)


if __name__ == "__main__":
    unittest.main()
