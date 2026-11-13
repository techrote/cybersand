"""Protocol-only fixtures; these do not claim neural inference or native drawing."""
import copy
import hashlib
import http.client
import json
from pathlib import Path
import sys
import tempfile
import threading
import types
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bridge
from compiler import compile_program


def packet():
    return {"model": bridge.ALIAS, "stream": False, "messages": [
        {"role": "system", "content": "Coordinates are LOCAL: XYWH=[0,0,96,96]. Allowed materials=[0,58].\nEnabled shapes: [\"rectangle\"]. Use only the current work area above.\nSelected drawing material: 58."},
        {"role": "user", "content": "Draw a vent panel with fasteners."}]}


class BridgeTests(unittest.TestCase):
    def test_captured_host_fields_win_over_earlier_editable_guidance(self):
        p = packet()
        p["messages"][0]["content"] = "XYWH=[0,0,512,512]. Allowed materials=[1]. Selected drawing material: 1. " + p["messages"][0]["content"]
        self.assertEqual(bridge.parse_request(p), {"prompt": "Draw a vent panel with fasteners.", "width": 96, "height": 96, "material": 58})

    def test_reject_missing_permission_wrong_alias_and_nontext_context(self):
        for mutate in [lambda p: p.update(model="other"),
                       lambda p: p.update(stream=True),
                       lambda p: p["messages"].append({"role": "assistant", "content": "history"}),
                       lambda p: p["messages"][1].update(content=[{"type": "image"}]),
                       lambda p: p["messages"][0].update(content=p["messages"][0]["content"].replace("[0,58]", "[0]")),
                       lambda p: p["messages"][0].update(content=p["messages"][0]["content"].replace("96,96", "32,32")),
                       lambda p: p["messages"][0].update(content=p["messages"][0]["content"].replace("rectangle", "disc"))]:
            p = packet(); mutate(p)
            with self.subTest(p=p), self.assertRaises(bridge.BridgeRefusal):
                bridge.parse_request(p)

    def test_recompile_and_full_receipt_binding(self):
        program = {"version": 2, "family": "greebles", "components": [
            {"kind": "panel", "box": [10,10,36,36], "detail": "vent", "density": 2, "border": 1, "fasteners": True}],
            "requirements": {"negative_space_min_percent": 20}, "variation": 1}
        config = types.SimpleNamespace(seed=17, model_id="synthetic-test-model", model_revision="a"*40, adapter_sha256="b"*64)
        request = bridge.parse_request(packet())
        receipt = {**request, "seed": 17, "model_id": config.model_id, "model_revision": config.model_revision,
                   "adapter_sha256": config.adapter_sha256, "compiler_sha256": bridge.file_sha(Path(bridge.__file__).with_name("compiler.py")),
                   "accepted": True, "eos_emitted": True, "eos_terminated": True, "native_execution": False}
        operations = compile_program(program, seed=17)["operations"]
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            (folder/"completion.txt").write_text(json.dumps(program))
            (folder/"art_batch.json").write_text(json.dumps(operations))
            (folder/"receipt.json").write_text(json.dumps(receipt))
            content, _ = bridge.checked_result(folder, request, config)
            self.assertEqual(json.loads(content), operations)
            for field, wrong in [("seed", 73), ("prompt", "different"), ("eos_emitted", False), ("eos_terminated", False),
                                 ("model_revision", "c"*40), ("native_execution", True), ("material", 1)]:
                forged = {**receipt, field: wrong}
                (folder/"receipt.json").write_text(json.dumps(forged))
                with self.subTest(field=field), self.assertRaises(bridge.BridgeRefusal):
                    bridge.checked_result(folder, request, config)
            (folder/"receipt.json").write_text(json.dumps(receipt))
            changed = copy.deepcopy(operations); changed[0]["x0"] += 1
            (folder/"art_batch.json").write_text(json.dumps(changed))
            with self.assertRaises(bridge.BridgeRefusal):
                bridge.checked_result(folder, request, config)

    def test_http_returns_only_proposal_and_refuses_browser_origin(self):
        seen = []
        def fixture(config, request, *, canceled):
            seen.append(request)
            self.assertFalse(canceled())
            return '[{"shape":"rectangle","material":58}]', {}
        stop = threading.Event()
        server = bridge.ThreadingHTTPServer(("127.0.0.1",0), bridge.handler(None, stop, fixture))
        thread = threading.Thread(target=server.serve_forever); thread.start()
        try:
            conn = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=5)
            conn.request("POST", "/v1/chat/completions", json.dumps(packet()), {"Content-Type":"application/json"})
            response = conn.getresponse(); body = json.loads(response.read())
            self.assertEqual(response.status, 200)
            self.assertIs(body["native_execution"], False)
            conn.close()
            conn = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=5)
            conn.request("POST", "/v1/chat/completions", json.dumps(packet()), {"Origin":"https://example.invalid"})
            self.assertEqual(conn.getresponse().status, 403)
            conn.close()
            self.assertEqual(len(seen),1)
        finally:
            stop.set(); server.shutdown(); server.server_close(); thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
