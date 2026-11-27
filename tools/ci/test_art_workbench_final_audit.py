"""Complete response custody across wire text and structured JSON redaction."""
import hashlib
import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.request

import run_art_workbench_final as runner


class CompleteResponseAuditTests(unittest.TestCase):
    def test_loopback_receipt_pins_complete_structured_body(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = runner.Fixture(Path(directory))
            thread = threading.Thread(target=fixture.serve_forever, daemon=True)
            thread.start()
            try:
                request = urllib.request.Request(f"http://127.0.0.1:{fixture.server_port}/v1/chat/completions",
                    data=b'{"model":"fixture-malicious-usage"}',
                    headers={"Authorization": "Bearer " + runner.CANARY})
                with urllib.request.urlopen(request, timeout=5) as response:
                    raw = response.read()
                # Independent literal matches the original fixture's complete
                # object after decoded credential redaction, including all padding.
                expected = ('{"choices":[{"finish_reason":"stop","message":{"content":"[]"}}],'
                            '"model":"synthetic-loopback-alias","usage":{"input_tokens":"[redacted]",'
                            '"output_tokens":"' + "x" * (1024 * 1024) + '"}}').encode()
                receipt = fixture.receipts[0]
                self.assertEqual(receipt["response_sha256"], hashlib.sha256(raw).hexdigest())
                self.assertEqual(receipt["redacted_body_sha256"], hashlib.sha256(expected).hexdigest())
                self.assertEqual(receipt["redacted_body_bytes"], len(expected))
                self.assertEqual(receipt["redacted_body_representation"], "structured-redaction-json")
                self.assertNotEqual(receipt["wire_redacted_body_sha256"], receipt["redacted_body_sha256"])
            finally:
                fixture.shutdown()
                fixture.server_close()
                thread.join(timeout=5)

    def verify(self, body, expected, model="fixture-malicious-usage"):
        with tempfile.TemporaryDirectory() as directory:
            profile = Path(directory)
            (profile / "trace.jsonl").write_text(json.dumps({"kind": "response", "data": {"body": body}}) + "\n",
                                               encoding="utf-8")
            receipt = {"model": model, "redacted_body_sha256": hashlib.sha256(expected.encode()).hexdigest(),
                       "response_bytes": len(expected.encode())}
            return runner.verify_complete_audit(profile, [{"fixture": model}], [receipt])

    def test_complete_structured_redaction(self):
        # Literal independent expectation follows the documented JSON.stringify
        # representation; it does not ask the application to calculate its oracle.
        expected = '{"choices":[],"usage":{"input_tokens":"[redacted]","output_tokens":"' + "x" * (1024 * 1024) + '"}}'
        self.assertTrue(self.verify(expected, expected)["complete_bodies"][0]["complete_redacted_body"])
        for changed in (expected[:-1], expected.replace('"output_tokens":"x', '"output_tokens":"y', 1)):
            with self.subTest(kind="truncated" if len(changed) < len(expected) else "changed-value"):
                with self.assertRaisesRegex(RuntimeError, "Missing or incomplete"):
                    self.verify(changed, expected)

    def test_ordinary_wire_spelling_still_exact(self):
        expected = '{ "choices": [], "diagnostic_padding": "x" }'
        self.verify(expected, expected, "fixture-large")
        with self.assertRaisesRegex(RuntimeError, "Missing or incomplete"):
            self.verify('{"choices":[],"diagnostic_padding":"x"}', expected, "fixture-large")

    def test_credential_leak_and_missing_body_refuse(self):
        with self.assertRaisesRegex(RuntimeError, "Synthetic credential"):
            self.verify(runner.CANARY, "[redacted]")
        with self.assertRaisesRegex(RuntimeError, "Missing or incomplete"):
            self.verify("", '{"usage":{"input_tokens":"[redacted]"}}')


if __name__ == "__main__":
    unittest.main()
