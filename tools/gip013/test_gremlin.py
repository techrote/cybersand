"""Self-qualification of GIP-013's *reference-model* harness and independent oracle."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import threading
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import gremlin


class GremlinTests(unittest.TestCase):
    def test_control_contracts(self):
        run = gremlin.choose_sequence("CONTROL", 13, len(gremlin.CONTROL_SEQUENCE))
        self.assertEqual([], run["failure"])
        self.assertEqual(len(gremlin.CONTROL_SEQUENCE), len(run["receipts"]))
        refusal = run["receipts"][7]
        self.assertFalse(refusal["result"]["accepted"])
        self.assertEqual(refusal["before"]["staged"], refusal["after"]["staged"])
        self.assertEqual(refusal["before"]["capacity"], refusal["after"]["capacity"])
        self.assertEqual(1, run["receipts"][0]["after"]["pilot"])
        self.assertEqual(1, run["receipts"][5]["after"]["pilot"])

    def test_seed_and_receipts_are_deterministic(self):
        a = gremlin.choose_sequence("CHAOS", 13, 100)
        b = gremlin.choose_sequence("CHAOS", 13, 100)
        self.assertEqual([x["fingerprint"] for x in a["receipts"]],
                         [x["fingerprint"] for x in b["receipts"]])
        self.assertEqual(a["pairs"], b["pairs"])
        self.assertEqual([], a["failure"])
        self.assertGreater(a["unique_pairs"], 25)
        self.assertEqual(0, a["sprocket_actions"])

    def test_illegal_action_refuses_without_mutation(self):
        world = gremlin.ContractWorld()
        before = world.snapshot()
        result = world.apply({"kind": "shell", "command": "rm -rf ~/"})
        self.assertEqual({"accepted": False, "reason": "illegal_action"}, result)
        self.assertEqual(before, world.snapshot())

    def test_rejected_apply_contained_and_shrunk(self):
        run = gremlin.choose_sequence("CONTROL", 13, 100, "rejected_apply_clears_stage")
        self.assertEqual(["rejected_apply_lost_staged"], run["failure"])
        self.assertEqual(8, len(run["receipts"]))
        self.assertTrue(all(not r["violations"] for r in run["receipts"][:-1]))
        seq, attempts = gremlin.shrink("CONTROL", 13,
                [r["action"] for r in run["receipts"]], run["failure"],
                fault="rejected_apply_clears_stage")
        self.assertEqual([{"kind": "stage_capacity", "actors": 1}, {"kind": "apply_capacity"}], seq)
        self.assertGreater(attempts, 0)

    def test_other_injected_faults(self):
        cases = [
            ("inspect_transfers_pilot", "inspection_transferred_pilot"),
            ("cancel_leaks_grab", "stale_grab_authority"),
            ("duplicate_body", "duplicate_body_identity"),
        ]
        for fault, expected in cases:
            with self.subTest(fault=fault):
                run = gremlin.choose_sequence("CONTROL", 13, 19, fault=fault)
                self.assertIn(expected, run["failure"])

    def test_invalid_sprocket_endpoint_rejected(self):
        for url in ("https://evil.example/v1/chat/completions", "http://evil.example/v1/chat/completions",
                    "http://localhost:8080/other", "file:///tmp/steal"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                gremlin.Sprocket(url, "test")

    def test_local_sprocket_proposal_is_selected_but_not_trusted(self):
        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                payload = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                assert payload["model"] == "mock-gguf"
                body = json.dumps({"choices": [{"message": {"content": '{"choice": 1}'}}]}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            sprocket = gremlin.Sprocket(f"http://127.0.0.1:{server.server_port}/v1/chat/completions", "mock-gguf")
            choice, error = sprocket.propose(gremlin.ContractWorld().snapshot(), gremlin.ContractWorld().legal())
            self.assertIsNone(error)
            self.assertEqual({"kind": "tick", "count": 3}, choice)
            fresh = gremlin.Sprocket(f"http://127.0.0.1:{server.server_port}/v1/chat/completions", "mock-gguf")
            run = gremlin.choose_sequence("SPROCKET", 13, 4, sprocket=fresh)
            self.assertEqual(3, run["sprocket_actions"])
            self.assertEqual(1, run["seeded_fallback_actions"])
            self.assertEqual([], run["failure"])
        finally:
            server.shutdown()
            server.server_close()
            thread.join(3)

    def test_campaign_watchdog_contains(self):
        run = gremlin.choose_sequence("CHAOS", 13, 100, max_seconds=0)
        self.assertEqual(["runner_watchdog_timeout"], run["failure"])
        self.assertEqual(1, len(run["receipts"]))

    def test_unavailable_sprocket_falls_back(self):
        sprocket = gremlin.Sprocket("http://127.0.0.1:1/v1/chat/completions", "unavailable", timeout=0.1)
        run = gremlin.choose_sequence("SPROCKET", 13, 12, sprocket=sprocket)
        self.assertEqual(0, run["sprocket_actions"])
        self.assertEqual(12, run["seeded_fallback_actions"])
        self.assertEqual(12, len(run["receipts"]))
        self.assertTrue(sprocket.disabled)
        self.assertEqual([], run["failure"])

    def test_cli_replay_and_protected_output(self):
        script = Path(gremlin.__file__)
        with tempfile.TemporaryDirectory(prefix="gip013-unit-") as temp:
            root = Path(temp)
            first = root / "first"
            args = [sys.executable, str(script), "--mode", "control", "--out", str(first),
                    "--inject-fault", "rejected_apply_clears_stage", "--expect-violation"]
            a = subprocess.run(args, capture_output=True, text=True, timeout=15)
            self.assertEqual(0, a.returncode, a.stderr)
            self.assertTrue((first / "control" / "minimized.json").exists())
            replay = root / "replayed"
            b = subprocess.run([sys.executable, str(script), "--replay",
                  str(first / "control" / "transcript.json"), "--out", str(replay)],
                  capture_output=True, text=True, timeout=15)
            self.assertEqual(0, b.returncode, b.stdout + b.stderr)
            self.assertTrue(json.loads(b.stdout)["replay_matches"])
            self.assertEqual(["rejected_apply_lost_staged"],
                             json.loads((replay / "control" / "summary.json").read_text())["failure"])
            c = subprocess.run(args, capture_output=True, text=True, timeout=15)
            self.assertNotEqual(0, c.returncode, "Evidence directories must never be overwritten")


if __name__ == "__main__":
    unittest.main()
