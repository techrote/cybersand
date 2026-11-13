"""No model downloads or native simulation: local bridge protocol and refusal guards."""
import argparse
import hashlib
from http.server import ThreadingHTTPServer
import http.client
import json
from pathlib import Path
import socket
import sys
import tempfile
import threading
import time
import unittest

from local_art_bridge import (BridgeRefusal, MODEL_ALIAS, _peer_disconnected, _run_owned_inference,
                              checked_art_result, make_handler, parse_workbench_request)

SYSTEM = ('Return ONLY a JSON array. Coordinates are LOCAL: top-left is (0,0), never add a world offset. '
          'XYWH=[0,0,96,96]. Allowed materials=[58]. Use compact rectangles, discs and lines. '
          'Enabled shapes: ["rectangle","disc","line","polyline","polygon"]. '
          'Use only the current work area above, even when previous turns used a different area. '
          'Selected drawing material: 58. Use it for drawing. Return [] when finished.')


def packet(prompt="roots", system=SYSTEM):
    return {"model": MODEL_ALIAS, "stream": False, "max_tokens": 8192,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": prompt}]}


class ContractTests(unittest.TestCase):
    def test_capture(self):
        r = parse_workbench_request(packet(), MODEL_ALIAS)
        self.assertEqual((r["prompt"], r["width"], r["height"], r["material"]), ("roots", 96, 96, 58))
        self.assertIn("polyline", r["enabled"])

    def test_fail_closed(self):
        attempts = [
            dict(packet(), model="other"), dict(packet(), stream=True),
            dict(packet(), messages=[packet()["messages"][-1]]),
            dict(packet(), messages=packet()["messages"] + [{"role": "assistant", "content": "[]"}]),
            packet(prompt=[{"type": "image_url", "image_url": "data:x"}]),
            packet(prompt="roots\nContinue revising the current artwork."),
            packet(system=SYSTEM.replace("[0,0,96,96]", "[999,0,96,96]")),
            packet(system=SYSTEM.replace("Allowed materials=[58]", "Allowed materials=[12]")),
            packet(system=SYSTEM.replace("Selected drawing material: 58", "Selected drawing material: 12")),
            packet(system=SYSTEM.replace("Coordinates are LOCAL:", "World coordinates")),
            dict(packet(), max_tokens=10),
        ]
        for item in attempts:
            with self.subTest(item=item):
                with self.assertRaises(BridgeRefusal):
                    parse_workbench_request(item, MODEL_ALIAS)

    def test_receipt_bind_and_disabled_ops(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            ops = [{"shape": "rectangle", "x0": 1, "y0": 1, "x1": 4, "y1": 4, "material": 58}]
            src = folder / "art_batch.json"
            src.write_text(json.dumps(ops))
            digest = hashlib.sha256(src.read_bytes()).hexdigest()
            receipt = {"accepted": True, "eos_emitted": True, "prompt": "roots",
                       "seed": 73, "adapter_sha256": "adapter",
                       "model_id": "LiquidAI/LFM2.5-350M", "native_execution": False,
                       "width": 96, "height": 96,
                       "material": 58, "compiler_sha256": "compiler", "art_batch_sha256": digest}
            (folder / "receipt.json").write_text(json.dumps(receipt))
            req = parse_workbench_request(packet(), MODEL_ALIAS)
            content, _ = checked_art_result(folder, req, "compiler")
            self.assertEqual(json.loads(content), ops)
            full_content, _ = checked_art_result(folder, req, "compiler",
                                                  expected_seed=73, expected_adapter_sha256="adapter")
            self.assertEqual(json.loads(full_content), ops)
            for key, forged in [("prompt", "different prompt"), ("seed", 74),
                                ("adapter_sha256", "other"), ("model_id", "other"),
                                ("native_execution", True)]:
                with self.subTest(forged_field=key):
                    valid = receipt[key]
                    receipt[key] = forged
                    (folder / "receipt.json").write_text(json.dumps(receipt))
                    with self.assertRaises(BridgeRefusal):
                        checked_art_result(folder, req, "compiler",
                                           expected_seed=73, expected_adapter_sha256="adapter")
                    receipt[key] = valid
                    (folder / "receipt.json").write_text(json.dumps(receipt))
            with self.assertRaises(BridgeRefusal):
                checked_art_result(folder, dict(req, enabled=frozenset({"disc"})), "compiler")
            receipt["eos_emitted"] = False
            (folder / "receipt.json").write_text(json.dumps(receipt))
            with self.assertRaises(BridgeRefusal):
                checked_art_result(folder, req, "compiler")
            receipt["eos_emitted"] = True
            (folder / "receipt.json").write_text(json.dumps(receipt))
            src.write_text("[]")
            with self.assertRaises(BridgeRefusal):
                checked_art_result(folder, req, "compiler")


    def test_peer_disconnection_detected_without_consuming_request_bytes(self):
        client, server = socket.socketpair()
        try:
            self.assertFalse(_peer_disconnected(server))
            client.sendall(b"X")
            self.assertFalse(_peer_disconnected(server))
            self.assertEqual(server.recv(1), b"X")  # MSG_PEEK did not consume.
            client.close()
            for _ in range(30):
                if _peer_disconnected(server):
                    break
                time.sleep(0.01)
            self.assertTrue(_peer_disconnected(server))
        finally:
            client.close()
            server.close()

    def test_cancel_stops_inference_subprocess_and_preserves_no_art_result(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            started, finished = root / "started", root / "finished"
            script = ("import pathlib,sys,time;"
                      "pathlib.Path(sys.argv[1]).write_text('started');"
                      "time.sleep(15);"
                      "pathlib.Path(sys.argv[2]).write_text('finished')")
            command = [sys.executable, "-c", script, str(started), str(finished)]
            stop = threading.Event()
            outcome = []
            def run():
                with (root / "process.log").open("wb") as log:
                    try:
                        outcome.append(_run_owned_inference(command, log, 8.0,
                                                            cancellation_probe=stop.is_set))
                    except BridgeRefusal as exc:
                        outcome.append(str(exc))
            worker = threading.Thread(target=run, daemon=True)
            worker.start()
            for _ in range(100):
                if started.exists():
                    break
                time.sleep(0.02)
            self.assertTrue(started.exists(), "child never started")
            stop.set()
            worker.join(4)
            self.assertFalse(worker.is_alive(), "canceled local inference still owns the job")
            self.assertEqual(len(outcome), 1)
            self.assertIn("canceled", outcome[0])
            self.assertFalse(finished.exists(), "stale child published after cancellation")

    def test_inference_whole_process_deadline(self):
        with tempfile.TemporaryDirectory() as tmp:
            with (Path(tmp) / "process.log").open("wb") as log:
                with self.assertRaisesRegex(BridgeRefusal, "deadline exceeded"):
                    _run_owned_inference([sys.executable, "-c", "import time;time.sleep(10)"],
                                         log, 0.2)


    def test_http_end_to_end_and_refusal(self):
        hits = []
        def runner(_config, request):
            hits.append(request)
            return '[{"shape":"disc","x":20,"y":20,"radius":4,"material":58}]', {"output_tokens": 28}
        cfg = argparse.Namespace(adapter_sha256="adapter", compiler_sha256="compiler")
        server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(cfg, runner))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            def call(obj):
                conn = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=5)
                conn.request("POST", "/v1/chat/completions", body=json.dumps(obj), headers={"Content-Type": "application/json"})
                response = conn.getresponse()
                out = response.status, json.loads(response.read())
                conn.close()
                return out
            status, response = call(packet("crystals"))
            self.assertEqual(status, 200)
            self.assertEqual(json.loads(response["choices"][0]["message"]["content"])[0]["shape"], "disc")
            self.assertEqual(hits[0]["prompt"], "crystals")
            self.assertFalse(response["wb_art_slm"]["native_executed"])
            status, _ = call(packet(system=SYSTEM.replace("[0,0,96,96]", "[0,0,4096,4096]")))
            self.assertEqual(status, 422)
            self.assertEqual(len(hits), 1)
        finally:
            server.shutdown(); server.server_close(); thread.join(2)


if __name__ == "__main__":
    unittest.main()