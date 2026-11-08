#!/usr/bin/env python3
"""Offline adapter/real-MCP-wire regressions. The upstream World is synthetic.
Native/real-render acceptance is a SEPARATE gate; see qualify_native.py.
"""
from __future__ import annotations
import base64
import hashlib
from http.server import ThreadingHTTPServer
import importlib.util
import json
from pathlib import Path
import secrets
import sys
import tempfile
import threading
import types
import unittest
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

DIR = Path(__file__).resolve().parent
PNG = bytes.fromhex("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000b49444154789c636000020000050001a5f645400000000049454e44ae426082")
DIGEST = hashlib.sha256(PNG).hexdigest()

class SyntheticWorkbench:
    def __init__(self):
        self.sid = "transport-session-test"
        self.phase = "ready"
        self.seq = 0
        self.ticks = 0
        self.revision = 0
        self.wall_count = 0
        self.post_count = 0
        self.records = {}
        self.lost_after_submission = False
        self.corrupt_png = False

    def api(self, base, token, method, path, *, body=None, timeout=10):
        assert base.startswith("http://127.0.0.1:") and token == "W" * 48
        if method == "GET" and path == "/v1/session":
            return 200, {"session_id": self.sid, "phase": self.phase,
                         "generation_id": self.sid + ":3", "native_generation": 3,
                         "completed_native_ticks_total": self.ticks,
                         "commands_submitted": self.post_count}
        if method == "GET" and path.startswith("/v1/requests/"):
            key = path.rsplit("/", 1)[-1]
            return (200, self.records[key]) if key in self.records else (404, {"error":"unknown_request_id"})
        if method == "GET" and path.startswith("/v1/frames/"):
            return 200, PNG + (b"bad" if self.corrupt_png else b"")
        if method != "POST" or path != "/v1/commands":
            return 404, {"error": "unknown_route"}
        rid = body["request_id"]
        if rid in self.records:
            return 200, self.records[rid]
        if body["session_id"] != self.sid or self.phase != "ready":
            return 409, {"error": "stale_or_wrong_session"}
        self.post_count += 1
        self.seq += 1
        name, args = body["tool"], body["args"]
        status = {"observe":"observed", "prepare_edit":"proposed", "apply_edit":"applied",
                  "step":"completed", "stop":"stopped"}[name]
        if name == "prepare_edit":
            result = {"status": status, "proposal_id": "proposal-" + str(self.revision),
                      "identity": {"world_generation":3,"revision":self.revision}}
        elif name == "observe":
            result = {"status": status, "observation_id": "observation-" + str(self.seq),
                      "native_counts": {"58":self.wall_count},
                      "identity": {"world_generation":3,"revision":self.revision}}
        elif name == "apply_edit":
            if args["proposal_id"] != "proposal-" + str(self.revision):
                status = "refused"
                result = {"status": status, "reason": "stale_proposal"}
            else:
                self.wall_count += 9 if self.wall_count == 0 else -1
                self.revision += 1
                result = {"status": status, "readback": {"confirmed_writes": 9},
                          "identity_after": {"world_generation":3,"revision":self.revision}}
        elif name == "step":
            self.ticks += args["ticks"]
            result = {"status": status, "completed": args["ticks"],
                      "observation":{"identity":{"world_generation":3,"tick":self.ticks}}}
        else:
            self.phase = "stopped"
            result = {"status":status}
        receipt = {"version": 1, "seq":self.seq, "tool": name,
                   "status":status,"result":result,
                   "completed_native_ticks_total":self.ticks}
        if name in ("observe", "step"):
            receipt["frame"] = {"status":"original_post_draw",
                                "path": f"frames/{self.seq:03d}-{name}.png",
                                "sha256":DIGEST, "native_render_mapping":{"world_generation":3}}
        response = {"session_id":self.sid, "request_id":rid, "seq":self.seq,
                    "state":"complete", "receipt":receipt}
        self.records[rid] = response
        if self.lost_after_submission:
            self.lost_after_submission = False
            raise URLError("simulated response lost after native execution")
        return 200, response

class AdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workbench = SyntheticWorkbench()
        shim = types.ModuleType("client")
        shim.validate_base = lambda url: url if url.startswith("http://127.0.0.1:") else (_ for _ in ()).throw(ValueError("nonloopback"))
        shim.read_token = lambda p: p.read_text().strip()
        shim.OWNER_SUCCESS = {"observe":"observed","prepare_edit":"proposed",
                              "apply_edit":"applied","step":"completed","stop":"stopped"}
        shim.api = lambda *a, **kw: cls.workbench.api(*a,**kw)
        shim.wait_request = lambda base,token,rid,deadline,timeout: cls.workbench.api(base,token,"GET","/v1/requests/"+rid)
        sys.modules["client"] = shim
        spec = importlib.util.spec_from_file_location("cybersand_mcp", DIR/"adapter.py")
        mod = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = mod
        spec.loader.exec_module(mod)
        cls.mod = mod

    def setUp(self):
        self.workbench = SyntheticWorkbench()
        type(self).workbench = self.workbench
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.wb_token = root / "workbench-token"
        self.wb_token.write_text("W"*48)
        self.adapter = self.mod.WorkbenchAdapter("http://127.0.0.1:8765",self.wb_token)
        self.server = self.mod.MCPServer(("127.0.0.1",0),self.adapter,"M"*48)
        self.thread = threading.Thread(target=self.server.serve_forever,daemon=True)
        self.thread.start()
        self.addCleanup(self.close_server)
        self.url = f"http://127.0.0.1:{self.server.server_port}/mcp"

    def close_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)

    def raw(self, doc, token="M"*48, headers=None):
        data = json.dumps(doc).encode()
        req = Request(self.url,data=data,headers={"Authorization":"Bearer "+token,
                      "Content-Type":"application/json", "Accept":"application/json, text/event-stream",
                      **(headers or {})},method="POST")
        try:
            with urlopen(req,timeout=3) as resp:
                return resp.status, json.load(resp)
        except HTTPError as exc:
            return exc.code, json.loads(exc.read())

    def mcp(self,name,args=None):
        code,doc = self.raw({"jsonrpc":"2.0","method":"tools/call",
                             "id":secrets.randbelow(1000000),
                             "params":{"name":name,"arguments":args or {}}})
        self.assertEqual(code,200)
        return doc["result"]

    def test_discovery_and_authentication(self):
        code,resp=self.raw({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}})
        self.assertEqual(code,200)
        self.assertEqual(resp["result"]["serverInfo"]["name"],"cybersand-workbench")
        code,resp=self.raw({"jsonrpc":"2.0","id":2,"method":"tools/list"})
        self.assertEqual(code,200)
        self.assertEqual({t["name"] for t in resp["result"]["tools"]},self.mod.TOOL_NAMES)
        for tool in resp["result"]["tools"]:
            self.assertNotIn("base",tool["inputSchema"]["properties"])
            self.assertNotIn("token_file",tool["inputSchema"]["properties"])
        code,resp=self.raw({"jsonrpc":"2.0","id":3,"method":"tools/list"},token="X"*48)
        self.assertEqual(code,401)
        code,resp=self.raw({"jsonrpc":"2.0","id":4,"method":"tools/list"},headers={"Origin":"http://evil.example"})
        self.assertEqual(code,403)
        code,resp=self.raw({"jsonrpc":"2.0","id":4,"method":"tools/list"},headers={"Host":"evil.example:80"})
        self.assertEqual(code,403)

    def test_native_style_sequence_original_image_and_stop(self):
        status=self.mcp("session_status")
        self.assertTrue(status["structuredContent"]["ok"])
        observation=self.mcp("observe",{"region":{"x":28,"y":28,"width":8,"height":8}})
        self.assertFalse(observation["isError"])
        images=[c for c in observation["content"] if c["type"]=="image"]
        self.assertEqual(len(images),1)
        self.assertEqual(base64.b64decode(images[0]["data"]),PNG)
        self.assertEqual(observation["structuredContent"]["original_png_sha256"],DIGEST)
        native=observation["structuredContent"]["envelope"]["receipt"]["result"]
        proposed=self.mcp("prepare_edit",{"observation_id":native["observation_id"],
                           "operations":[{"shape":"rectangle","x0":30,"y0":30,"x1":32,"y1":32,"material":58}]})
        proposal=proposed["structuredContent"]["envelope"]["receipt"]["result"]["proposal_id"]
        applied=self.mcp("apply_edit",{"proposal_id":proposal,"request_id":"req-apply-123456"})
        self.assertFalse(applied["isError"])
        count=self.workbench.post_count
        again=self.mcp("apply_edit",{"proposal_id":proposal,"request_id":"req-apply-123456"})
        self.assertEqual(self.workbench.post_count,count)
        self.assertEqual(again["structuredContent"]["envelope"],applied["structuredContent"]["envelope"])
        self.assertTrue(self.mcp("step",{"ticks":4})["content"][-1]["type"]=="image")
        stopped=self.mcp("stop")
        self.assertFalse(stopped["isError"])
        self.assertTrue(self.mcp("apply_edit",{"proposal_id":proposal})["isError"])
        self.assertEqual(self.workbench.ticks,4)

    def test_uncertain_post_recovery_no_replay(self):
        self.workbench.lost_after_submission=True
        first=self.mcp("observe",{"request_id":"req-loss-123456"})
        self.assertFalse(first["isError"])
        self.assertEqual(self.workbench.post_count,1)
        second=self.mcp("observe",{"request_id":"req-loss-123456"})
        self.assertEqual(self.workbench.post_count,1)
        self.assertEqual(first["structuredContent"]["envelope"], second["structuredContent"]["envelope"])
        self.assertTrue(self.mcp("step",{"ticks":2,"request_id":"req-loss-123456"})["isError"])

    def test_stale_proposal_and_image_corruption(self):
        stale=self.mcp("apply_edit",{"proposal_id":"proposal-old"})
        self.assertTrue(stale["isError"])
        self.assertEqual(stale["structuredContent"]["error"],"native_refused_or_unconfirmed")
        self.workbench.corrupt_png=True
        image=self.mcp("observe")
        self.assertTrue(image["isError"])
        self.assertFalse(any(b["type"]=="image" for b in image["content"]))

    def test_invalid_args_and_restart(self):
        bad=[("step",{"ticks":True}), ("step",{"ticks":121}),
             ("observe",{"region":{"x":0,"y":0,"width":100,"height":100}}),
             ("prepare_edit",{"observation_id":"x","operations":[{"shape":"disc","x":0,"y":0,"radius":37,"material":58}]}),
             ("apply_edit",{"proposal_id":"x", "url":"http://evil.invalid"}),
             ("stop",{"authorization":"self"})]
        for name,args in bad:
            with self.subTest(name=name,args=args):
                self.assertTrue(self.mcp(name,args)["isError"])
        self.assertEqual(self.workbench.post_count,0)
        self.mcp("session_status")
        self.workbench.sid = "new-session"
        changed=self.mcp("session_status")
        self.assertTrue(changed["isError"])
        self.assertEqual(changed["structuredContent"]["error"],"upstream_session_changed_restart_adapter")
        self.assertTrue(self.mcp("observe")["isError"])
        self.assertEqual(self.workbench.post_count,0)

if __name__ == "__main__":
    unittest.main(verbosity=2)
