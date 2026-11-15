"""Offline transport/lifecycle regressions; fixtures are NOT d1 inference."""
import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import tarfile
import threading
import time
import unittest
from unittest.mock import patch

from experiments.driv3r.backend import (PINS, BackendRefusal, ResidentDecisionBackend,
                                       _child_environment, _response_json, _install_bundle,
                                       parse_choice_response, validate_questions)
from experiments.driv3r.inference_smoke import is_pinned_capacity_refusal


QUESTION = {"move": {"type": "choice", "instructions": "Choose a movement.",
                     "criteria": {"UP": "Move up", "DOWN": "Move down"}}}
ANSWER = {"answers": {"move": {"type": "choice", "choice": "UP", "confidence": 0.8,
                              "probabilities": {"UP": 0.8, "DOWN": 0.2}}},
          "usage": {"input_tokens": 12, "output_tokens": 0}}

# Explicitly synthetic HTTP server; never admitted as actual model evidence.
FAKE_SERVER = r'''#!/usr/bin/env python3
import http.server,json,sys,time
args=sys.argv[1:]
port=int(args[args.index('--port')+1]);alias=args[args.index('--alias')+1]
key=open(args[args.index('--api-key-file')+1]).read().strip()
model=open(args[args.index('-m')+1]).read()
if model=='hang-startup':time.sleep(60)
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def reply(self,body,status=200):
  payload=json.dumps(body).encode();self.send_response(status);self.send_header('Content-Length',str(len(payload)));self.end_headers();self.wfile.write(payload)
 def do_GET(self):
  if self.path=='/health':self.reply({'status':'ok'});return
  if self.headers.get('Authorization')!='Bearer '+key:self.reply({'error':'bad key'},401);return
  self.reply({'data':[{'id':alias}]})
 def do_POST(self):
  data=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  if not data.get('questions'):self.reply({'error':'missing questions'},400);return
  if data.get('state')=='slow':time.sleep(3)
  answers={}
  for name,q in data['questions'].items():
   keys=list(q['criteria']);probs={k:0.2/(len(keys)-1) for k in keys};probs[keys[0]]=0.8
   answers[name]={'type':'choice','choice':keys[0],'probabilities':probs,'confidence':0.8}
  self.reply({'answers':answers,'usage':{'input_tokens':12,'output_tokens':0}})
http.server.HTTPServer(('127.0.0.1',port),Handler).serve_forever()
'''


class ChoiceContracts(unittest.TestCase):
    def test_capacity_error_requires_exact_pinned_semantics(self):
        record = {"status":"model_failure", "http_status":500, "raw_response":{"error":{
            "code":500, "type":"server_error", "message":"input (6078 tokens) is too large to process. increase the physical batch size (current batch size: 2048)"}}}
        self.assertTrue(is_pinned_capacity_refusal(record, 2048))
        variants = []
        for field, value in [("code",400), ("type","out_of_memory"), ("message","generic internal error"),
                             ("message","input (100 tokens) is too large to process. increase the physical batch size (current batch size: 2048)")]:
            changed = copy.deepcopy(record)
            changed["raw_response"]["error"][field] = value
            variants.append(changed)
        changed = copy.deepcopy(record)
        changed["raw_response"]["answers"] = ANSWER["answers"]
        variants.append(changed)
        changed = copy.deepcopy(record)
        changed["http_status"] = 400
        variants.append(changed)
        for changed in variants:
            self.assertFalse(is_pinned_capacity_refusal(changed, 2048))
        self.assertFalse(is_pinned_capacity_refusal(record, 4096))

    def test_identifier_mapping_survives_reordering(self):
        result = parse_choice_response(ANSWER, "move", ["DOWN", "UP"])
        self.assertEqual(result["candidate_id"], "UP")

    def test_rejects_invalid_or_ambiguous_answers(self):
        variants = []
        for field, value in [("choice", "execute_shell"), ("confidence", float("nan")),
                             ("confidence", True), ("confidence", 0.3),
                             ("probabilities", {"UP": 1.0}),
                             ("probabilities", {"UP": 0.8, "DOWN": 0.3}),
                             ("probabilities", {"UP": 0.2, "DOWN": 0.8})]:
            raw = copy.deepcopy(ANSWER)
            raw["answers"]["move"][field] = value
            variants.append(raw)
        raw = copy.deepcopy(ANSWER)
        raw["usage"]["output_tokens"] = 1
        variants.append(raw)
        for raw in variants:
            with self.subTest(raw=raw), self.assertRaises(BackendRefusal):
                parse_choice_response(raw, "move", ["UP", "DOWN"])

    def test_unsupported_multiple_and_extra_fields_refused(self):
        for field, value in [("multiple", True), ("coordinates", [0, 0])]:
            q = copy.deepcopy(QUESTION)
            q["move"][field] = value
            with self.assertRaises(BackendRefusal):
                validate_questions("state", q)

    def test_bounded_nonempty_questions(self):
        for state, questions in [("", QUESTION), ("x"*40000, QUESTION), ("state", {}),
                                 ("state", {"move": {"type":"choice", "instructions":"x", "criteria":{"UP":"up"}}})]:
            with self.subTest(state=state[:50]), self.assertRaises(BackendRefusal):
                validate_questions(state, questions)

    def test_duplicate_or_nonfinite_raw_keys_refused(self):
        for payload in ['{"answers":{},"answers":{}}', '{"p":NaN}']:
            with self.assertRaises(ValueError):
                _response_json(payload)

    def test_inherited_loader_configuration_is_not_forwarded(self):
        with patch.dict(os.environ, {"LD_PRELOAD":"evil.so", "GGML_BACKEND_PATH":"evil.so",
                                     "LLAMA_ARG_MODEL":"different.gguf", "LD_LIBRARY_PATH":"/outside"}):
            env = _child_environment(Path("/verified/bundle"), 2)
        self.assertNotIn("LD_PRELOAD", env)
        self.assertNotIn("GGML_BACKEND_PATH", env)
        self.assertNotIn("LLAMA_ARG_MODEL", env)
        self.assertEqual(env["LD_LIBRARY_PATH"], "/verified/bundle")

    def test_existing_bundle_is_read_only_and_dirty_bundle_is_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root/"llama-fixture"
            bundle.mkdir()
            library = bundle/"library.so"
            library.write_bytes(b"original pinned library")
            pin = {"tag":"fixture", "files": {library.name:hashlib.sha256(library.read_bytes()).hexdigest()}}
            before = library.stat()
            # A nonexistent archive is intentional: valid cache admission must
            # not even open/extract it, much less truncate a loaded library.
            actual, reused = _install_bundle(root/"not-opened.tar.gz", root, pin)
            self.assertEqual(actual, bundle)
            self.assertTrue(reused)
            self.assertEqual(before.st_mtime_ns, library.stat().st_mtime_ns)
            self.assertEqual(before.st_ino, library.stat().st_ino)
            library.write_bytes(b"dirty")
            with self.assertRaises(BackendRefusal):
                _install_bundle(root/"not-opened.tar.gz", root, pin)
            self.assertEqual(library.read_bytes(), b"dirty")

    def test_fresh_bundle_is_verified_before_publication(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            donor = root/"donor"
            donor.mkdir()
            (donor/"library.so").write_bytes(b"official archive fixture")
            archive = root/"runtime.tar.gz"
            with tarfile.open(archive, "w:gz") as stream:
                stream.add(donor, arcname="llama-fixture")
            pin = {"tag":"fixture", "files":{"library.so":hashlib.sha256((donor/"library.so").read_bytes()).hexdigest()}}
            directory, reused = _install_bundle(archive, root, pin)
            self.assertFalse(reused)
            self.assertEqual((directory/"library.so").read_bytes(), b"official archive fixture")


@unittest.skipUnless(os.name == "posix", "POSIX child ownership only")
class ResidentLifecycle(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root/"runtime").mkdir()
        self.binary = self.root / "runtime" / "fake-server"
        self.binary.write_text(FAKE_SERVER)
        self.binary.chmod(0o755)
        self.model = self.root / "fixture-model"
        self.model.write_text("synthetic-offline-fixture")
        self.backends = []
        self.pin_patch = patch.dict(PINS, {"model": {}, "runtime": {}}, clear=True)
        self.pin_patch.start()

    def tearDown(self):
        for backend in self.backends:
            backend.close()
        self.pin_patch.stop()
        self.temp.cleanup()

    def backend(self, **kwargs):
        model_identity = {"kind":"synthetic_test_fixture", "sha256": hashlib.sha256(self.model.read_bytes()).hexdigest(),
                          "bytes": self.model.stat().st_size}
        binary_sha = hashlib.sha256(self.binary.read_bytes()).hexdigest()
        backend_identity = {"kind":"synthetic_test_fixture", "binary_sha256": binary_sha,
                            "files": {self.binary.name: binary_sha}}
        PINS["model"], PINS["runtime"] = model_identity, backend_identity
        backend = ResidentDecisionBackend(self.binary, self.model, self.root/str(len(self.backends)),
            model_identity=model_identity, backend_identity=backend_identity, startup_seconds=2, **kwargs)
        self.backends.append(backend)
        return backend

    def test_resident_repeated_requests_and_raw_refusal(self):
        with self.backend() as backend:
            first = backend.decide("fixture one", QUESTION, 1)
            second = backend.decide("fixture two", QUESTION, 1)
            malformed = backend.probe_raw({"state":"no questions"}, 1)
            self.assertEqual(first["status"], "ok")
            self.assertEqual(second["status"], "ok")
            self.assertEqual(first["pid"], second["pid"])
            self.assertEqual(first["raw_response"], ANSWER)
            self.assertEqual(malformed["http_status"], 400)
            self.assertEqual(malformed["status"], "model_failure")
            for record in [first, second, malformed]:
                self.assertTrue(Path(record["evidence_path"]).is_file())
        self.assertTrue(backend.shutdown_record["process_reaped"])
        with self.assertRaises(ProcessLookupError):
            os.kill(backend.pid, 0)

    def test_timeout_retires_and_rejects_late_decision(self):
        with self.backend() as backend:
            result = backend.decide("slow", QUESTION, 0.1)
            self.assertEqual(result["status"], "timeout")
            self.assertLess(result["latency_seconds"], 2)
            self.assertEqual(backend.decide("late", QUESTION, 1)["status"], "model_failure")
            self.assertTrue(backend.shutdown_record["process_reaped"])

    def test_cancellation_during_outstanding_request(self):
        event = threading.Event()
        with self.backend() as backend:
            timer = threading.Timer(0.1, event.set)
            timer.start()
            try:
                result = backend.decide("slow", QUESTION, 2, event)
            finally:
                timer.join()
            self.assertEqual(result["status"], "cancelled")
            self.assertTrue(backend.shutdown_record["process_reaped"])
            self.assertFalse(result["transport_worker_alive"])

    def test_pre_cancel_sends_no_request(self):
        event = threading.Event()
        event.set()
        with self.backend() as backend:
            result = backend.decide("fixture", QUESTION, 1, event)
            self.assertEqual(result["status"], "cancelled")
            self.assertNotIn("http_status", result)

    def test_malformed_input_refuses_without_launch(self):
        backend = self.backend()
        result = backend.decide("state", {}, 1)
        self.assertEqual(result["status"], "invalid_request")
        self.assertIsNone(backend.process)

    def test_model_pin_mismatch_refuses_before_spawn(self):
        backend = self.backend()
        self.model.write_text("modified model")
        with self.assertRaises(BackendRefusal):
            backend.start()
        self.assertIsNone(backend.process)

    def test_supplied_manifest_cannot_weaken_model_or_runtime_pin(self):
        backend = self.backend()
        for key in ("model", "runtime"):
            identity = copy.deepcopy(PINS[key])
            identity["sha256" if key == "model" else "binary_sha256"] = "0"*64
            kwargs = {"model_identity" if key == "model" else "backend_identity": identity}
            with self.assertRaises(BackendRefusal):
                ResidentDecisionBackend(self.binary, self.model, self.root/"invalid", **kwargs)
        self.assertIsNone(backend.process)

    def test_unexpected_runtime_library_refuses_before_spawn(self):
        backend = self.backend()
        (self.binary.parent/"libggml-injected.so").write_text("foreign")
        with self.assertRaises(BackendRefusal):
            backend.start()
        self.assertIsNone(backend.process)

    def test_modified_runtime_dependency_refuses_before_spawn(self):
        backend = self.backend()
        self.binary.write_text(FAKE_SERVER+"\n# changed executable\n")
        with self.assertRaises(BackendRefusal):
            backend.start()
        self.assertIsNone(backend.process)

    def test_modified_bundled_library_refuses_before_spawn(self):
        self.backend()  # establish explicitly synthetic pins for this offline test
        library = self.binary.parent/"libggml-test.so"
        library.write_bytes(b"original offline fixture")
        PINS["runtime"]["files"][library.name] = hashlib.sha256(library.read_bytes()).hexdigest()
        backend = ResidentDecisionBackend(self.binary, self.model, self.root/"library-change")
        self.backends.append(backend)
        library.write_bytes(b"changed offline fixture")
        with self.assertRaises(BackendRefusal):
            backend.start()
        self.assertIsNone(backend.process)

    def test_failed_startup_has_bounded_cleanup(self):
        self.model.write_text("hang-startup")
        backend = self.backend()
        backend.startup_seconds = 0.15
        start = time.monotonic()
        with self.assertRaises(TimeoutError):
            backend.start()
        self.assertLess(time.monotonic()-start, 2)
        self.assertTrue(backend.shutdown_record["process_reaped"])
        self.assertEqual(backend.startup_record["status"], "model_failure")


if __name__ == "__main__":
    unittest.main()
