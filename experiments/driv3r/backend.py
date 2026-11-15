"""Pinned, resident CPU System One backend; it has no native painting authority.

The public decision API is deliberately separate from generative completions.
Every request is retained, including refusal/timeout/cancellation. Cancelling or
timing out retires the owned process so no late answer can be consumed.
"""
from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import math
import os
from pathlib import Path
import queue
import secrets
import socket
import subprocess
import tarfile
import tempfile
import threading
import time
import traceback
import urllib.request
import uuid

from experiments.agent_painter.process import stop_group

PINS = json.loads(Path(__file__).with_name("pins.json").read_text())
MAX_REQUEST_BYTES = 32768
MAX_RESPONSE_BYTES = 262144
MAX_QUESTIONS = 8
MAX_OPTIONS = 32


class BackendRefusal(ValueError):
    """A malformed or unsupported decision never reaches execution."""


def sha256_file(path: str | Path, deadline=None) -> str:
    result = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            if deadline is not None and time.monotonic() >= deadline:
                raise TimeoutError("identity verification exceeded startup deadline")
            result.update(chunk)
    return result.hexdigest()


def _write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n")
    temporary.replace(path)


def _seconds(value: float, maximum: float = 600) -> float:
    if type(value) not in (int, float) or not math.isfinite(value) or not 0 < value <= maximum:
        raise BackendRefusal(f"deadline must be finite and in (0, {maximum}]")
    return float(value)


def _json_bytes(value) -> bytes:
    try:
        return json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode()
    except (ValueError, TypeError, RecursionError) as exc:
        raise BackendRefusal(f"request is not finite JSON: {exc}") from exc


def validate_questions(state: str, questions: dict) -> bytes:
    """Stage A admits text state and ordinary single-choice questions only.

    b11960 silently ignores the unsupported ``multiple`` flag; reject it here.
    Named questions see the same state, never one another's computed answers.
    """
    if type(state) is not str or not state.strip():
        raise BackendRefusal("state must be nonempty text")
    if type(questions) is not dict or not 1 <= len(questions) <= MAX_QUESTIONS:
        raise BackendRefusal("questions must be a bounded nonempty mapping")
    for name, question in questions.items():
        if type(name) is not str or not name or len(name) > 128:
            raise BackendRefusal("invalid question identifier")
        if type(question) is not dict or set(question) - {"type", "instructions", "criteria"}:
            raise BackendRefusal("unsupported question fields (including multiple choice)")
        if question.get("type") != "choice":
            raise BackendRefusal("Stage A adapter supports single choice only")
        instructions = question.get("instructions")
        if type(instructions) is not str or not instructions.strip() or len(instructions) > 4096:
            raise BackendRefusal("invalid question instructions")
        criteria = question.get("criteria")
        if type(criteria) is not dict or not 2 <= len(criteria) <= MAX_OPTIONS:
            raise BackendRefusal("choice needs 2 to 32 explicit candidates")
        for key, description in criteria.items():
            if type(key) is not str or not key or len(key) > 128:
                raise BackendRefusal("invalid candidate identifier")
            if type(description) is not str or not description.strip() or len(description) > 4096:
                raise BackendRefusal("candidate descriptions must be bounded nonempty text")
    encoded = _json_bytes({"state": state, "questions": questions})
    if len(encoded) > MAX_REQUEST_BYTES:
        raise BackendRefusal("decision input exceeds bounded local observation capacity")
    return encoded


def _number(value) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def _identity(pin, supplied):
    """A supplied manifest adds measurements; it cannot replace committed pins."""
    supplied = supplied or {}
    if type(supplied) is not dict:
        raise BackendRefusal("identity must be a mapping")
    for name, expected in pin.items():
        if name in supplied and supplied[name] != expected:
            raise BackendRefusal(f"supplied identity changes pinned {name}")
    return dict(pin, **{k: v for k, v in supplied.items() if k not in pin})


def _response_json(text):
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError(f"duplicate response key: {key}")
            value[key] = item
        return value

    def nonfinite(_):
        raise ValueError("nonfinite JSON")

    return json.loads(text, object_pairs_hook=unique, parse_constant=nonfinite)


def _child_environment(bundle, threads):
    # Do not inherit LD_PRELOAD, GGML_BACKEND_PATH, LLAMA_ARG_* or tool/MCP
    # configuration. Bundled backends search the trusted executable/cwd paths.
    return {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8", "TZ": "UTC", "LD_LIBRARY_PATH": str(bundle),
            "OMP_NUM_THREADS": str(threads)}


def _loaded_dependencies(pid, bundle, expected, deadline=None):
    loaded = {}
    for line in Path(f"/proc/{pid}/maps").read_text().splitlines():
        parts = line.split(None, 5)
        if len(parts) != 6 or not parts[5].startswith("/") or ".so" not in parts[5]:
            continue
        path = Path(parts[5])
        resolved = path.resolve()
        if str(resolved) in loaded:
            continue
        digest = sha256_file(resolved, deadline)
        if resolved.parent == bundle:
            if digest != expected.get(resolved.name):
                raise BackendRefusal("loaded bundled dependency does not match committed runtime pins")
        elif resolved.name.startswith(("libllama", "libggml", "libmtmd")):
            raise BackendRefusal("runtime loaded an unpinned external model library")
        loaded[str(resolved)] = digest
    return loaded


def _verify_bundle(directory: Path, expected: dict, deadline=None):
    """Read-only admission. Never rewrite libraries that another process may map."""
    actual = {p.name: p for p in directory.iterdir()}
    if set(actual) != set(expected):
        raise BackendRefusal("runtime bundle contains missing or unexpected files")
    for name, expected_sha in expected.items():
        path = actual[name]
        if not path.is_file() or path.resolve().parent != directory.resolve():
            raise BackendRefusal("runtime dependency escapes pinned bundle")
        if sha256_file(path, deadline) != expected_sha:
            raise BackendRefusal(f"runtime dependency bytes differ: {name}")


def _install_bundle(archive: Path, root: Path, runtime: dict, deadline=None):
    """Reuse exact existing bytes, or atomically publish a fresh verified bundle."""
    directory = root / f"llama-{runtime['tag']}"
    if directory.exists():
        _verify_bundle(directory, runtime["files"], deadline)
        return directory, True
    with tempfile.TemporaryDirectory(prefix="driv3r-extract-", dir=root) as stage:
        with tarfile.open(archive, "r:gz") as bundle:
            bundle.extractall(stage, filter="data")
        candidate = Path(stage) / directory.name
        _verify_bundle(candidate, runtime["files"], deadline)
        if directory.exists():
            # A concurrent acquisition may have published an exact bundle.
            _verify_bundle(directory, runtime["files"], deadline)
            return directory, True
        candidate.rename(directory)
    return directory, False


def parse_choice_response(raw: dict, question_id: str, candidate_ids) -> dict:
    """Validate a typed answer by identifiers, independent of display ordering."""
    ids = tuple(candidate_ids)
    if len(ids) < 2 or len(set(ids)) != len(ids) or any(type(i) is not str or not i for i in ids):
        raise BackendRefusal("invalid original candidate set")
    if type(raw) is not dict or type(raw.get("answers")) is not dict:
        raise BackendRefusal("missing named typed answers")
    usage = raw.get("usage")
    if type(usage) is not dict or type(usage.get("input_tokens")) is not int or usage["input_tokens"] <= 0:
        raise BackendRefusal("missing valid decision input-token usage")
    if type(usage.get("output_tokens")) is not int or usage["output_tokens"] != 0:
        raise BackendRefusal("System One must not generate completion tokens")
    answer = raw["answers"].get(question_id)
    if type(answer) is not dict or answer.get("type") != "choice":
        raise BackendRefusal("missing named choice answer")
    chosen, probs = answer.get("choice"), answer.get("probabilities")
    if type(chosen) is not str or chosen not in ids:
        raise BackendRefusal("unknown chosen candidate")
    if type(probs) is not dict or set(probs) != set(ids):
        raise BackendRefusal("distribution does not exactly match the candidate set")
    if any(not _number(p) or not 0 <= p <= 1 for p in probs.values()):
        raise BackendRefusal("invalid candidate probabilities")
    if abs(math.fsum(probs.values()) - 1) > 1e-5:
        raise BackendRefusal("candidate probabilities do not sum to one")
    confidence = answer.get("confidence")
    if not _number(confidence) or not 0 <= confidence <= 1:
        raise BackendRefusal("missing or invalid confidence")
    if abs(confidence - probs[chosen]) > 1e-5 or max(probs.values()) - probs[chosen] > 1e-7:
        raise BackendRefusal("choice/confidence does not match d1 argmax semantics")
    return {"candidate_id": chosen, "probabilities": dict(probs), "confidence": confidence}


def _resources(pid: int | None) -> dict:
    """Actual Linux process counters, not estimates from accelerator benchmarks."""
    if pid is None:
        return {}
    try:
        values = {}
        for line in Path(f"/proc/{pid}/status").read_text().splitlines():
            key, _, value = line.partition(":")
            if key in ("VmRSS", "VmHWM", "Threads"):
                values[key] = int(value.strip().split()[0])
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        ticks = os.sysconf("SC_CLK_TCK")
        values["cpu_user_seconds"] = int(fields[11]) / ticks
        values["cpu_system_seconds"] = int(fields[12]) / ticks
        return values
    except (OSError, ValueError, IndexError):
        return {}


class ResidentDecisionBackend:
    """One POSIX process, one outstanding request, explicit retirement on failure."""

    def __init__(self, binary, model, evidence_dir, *, model_identity=None,
                 backend_identity=None, threads=2, startup_seconds=120,
                 ctx_size=4096, batch_size=2048, port=None):
        self.binary, self.model = Path(binary).resolve(), Path(model).resolve()
        self.evidence_dir = Path(evidence_dir).resolve()
        self.model_identity = _identity(PINS["model"], model_identity)
        self.backend_identity = _identity(PINS["runtime"], backend_identity)
        if type(threads) is not int or not 1 <= threads <= 32:
            raise BackendRefusal("CPU threads must be in 1..32")
        if type(batch_size) is not int or not 256 <= batch_size <= 8192:
            raise BackendRefusal("batch size outside qualified text bounds")
        if type(ctx_size) is not int or not batch_size <= ctx_size <= 16384:
            raise BackendRefusal("context size outside qualified bounds")
        if port is not None and (type(port) is not int or not 1024 <= port <= 65535):
            raise BackendRefusal("invalid loopback port")
        self.threads, self.ctx_size, self.batch_size = threads, ctx_size, batch_size
        self.startup_seconds, self.port = _seconds(startup_seconds), port
        self.process = None
        self.pid = None
        self._log = None
        self._secret_dir = None
        self._key = None
        self._retired = False
        self._lock = threading.Lock()
        self._record_lock = threading.Lock()
        self._sequence = 0
        self.session_id = uuid.uuid4().hex
        self.startup_record = None
        self.shutdown_record = None

    def __enter__(self):
        return self.start()

    def __exit__(self, exc_type, exc, tb):
        self.close()

    def _http(self, method, path, payload, seconds):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=seconds)
        try:
            headers = {"Content-Type": "application/json", "Authorization": f"Bearer {self._key}"}
            connection.request(method, path, body=payload, headers=headers)
            response = connection.getresponse()
            raw = response.read(MAX_RESPONSE_BYTES + 1)
            if len(raw) > MAX_RESPONSE_BYTES:
                raise BackendRefusal("backend response exceeds maximum bytes")
            raw_text = raw.decode("utf-8", errors="strict")
            try:
                body = _response_json(raw_text)
            except (ValueError, json.JSONDecodeError) as exc:
                return {"http_status": response.status, "raw_text": raw_text, "raw_response": None,
                        "error": f"non-JSON backend response: {exc}"}
            return {"http_status": response.status, "raw_text": raw_text, "raw_response": body}
        finally:
            connection.close()

    def start(self):
        if os.name != "posix":
            raise BackendRefusal("resident process-tree ownership is qualified only on POSIX")
        if self._retired:
            raise BackendRefusal("retired inference instances cannot restart")
        if self.process is not None:
            if self.process.poll() is None:
                return self
            raise BackendRefusal("resident inference process already exited")
        self.evidence_dir.mkdir(parents=True, exist_ok=True)
        start = time.monotonic()
        deadline = start + self.startup_seconds
        record = {"session_id": self.session_id, "status": "starting", "model_identity": self.model_identity,
                  "backend_identity": self.backend_identity, "threads": self.threads,
                  "context_tokens": self.ctx_size, "batch_tokens": self.batch_size}
        try:
            if not self.binary.is_file() or not os.access(self.binary, os.X_OK) or not self.model.is_file():
                raise BackendRefusal("runtime/model paths must be existing local files")
            if self.model.stat().st_size != self.model_identity["bytes"]:
                raise BackendRefusal("model size does not match the pinned identity")
            model_sha = sha256_file(self.model, deadline)
            if model_sha != self.model_identity.get("sha256"):
                raise BackendRefusal("model bytes do not match the pinned identity")
            binary_sha = sha256_file(self.binary, deadline)
            if self.backend_identity["binary_sha256"] != binary_sha:
                raise BackendRefusal("runtime bytes do not match the pinned identity")
            expected_files = self.backend_identity["files"]
            _verify_bundle(self.binary.parent, expected_files, deadline)
            if self.port is None:
                with socket.socket() as reservation:
                    reservation.bind(("127.0.0.1", 0))
                    self.port = reservation.getsockname()[1]
            self._secret_dir = tempfile.TemporaryDirectory(prefix="driv3r-auth-")
            keyfile = Path(self._secret_dir.name) / "api-key"
            self._key = secrets.token_hex(32)
            keyfile.write_text(self._key + "\n")
            keyfile.chmod(0o600)
            command = [str(self.binary), "-m", str(self.model), "--host", "127.0.0.1",
                       "--port", str(self.port), "--api-key-file", str(keyfile),
                       "--alias", f"driv3r-{self.session_id}", "-t", str(self.threads),
                       "-tb", str(self.threads), "-ngl", "0", "-np", "1", "-c", str(self.ctx_size),
                       "-b", str(self.batch_size), "-ub", str(self.batch_size),
                       "--no-mmproj", "--timeout", "120", "--metrics"]
            record["command"] = command
            self._log = (self.evidence_dir / f"{self.session_id}-server.log").open("xb")
            spawned = time.monotonic()
            self.process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=self._log,
                                            stderr=subprocess.STDOUT, start_new_session=True,
                                            cwd=self.binary.parent,
                                            env=_child_environment(self.binary.parent, self.threads))
            self.pid = self.process.pid
            record["pid"] = self.pid
            last_error = None
            while time.monotonic() < deadline:
                if self.process.poll() is not None:
                    raise BackendRefusal(f"model process exited with {self.process.returncode}")
                try:
                    health = self._http("GET", "/health", None, min(0.5, max(0.01, deadline-time.monotonic())))
                    if health["http_status"] == 200:
                        models = self._http("GET", "/v1/models", None, min(1.0, max(0.01, deadline-time.monotonic())))
                        if models["http_status"] != 200:
                            raise BackendRefusal("resident instance authentication failed")
                        identities = models.get("raw_response", {}).get("data", [])
                        if not any(m.get("id") == f"driv3r-{self.session_id}" for m in identities):
                            raise BackendRefusal("resident instance identity mismatch")
                        record.update({"status": "ok", "health": health, "models": models,
                                       "load_seconds": time.monotonic()-spawned, "resources": _resources(self.pid)})
                        record["loaded_dependency_sha256"] = _loaded_dependencies(
                            self.pid, self.binary.parent, expected_files, deadline)
                        record["child_environment"] = _child_environment(self.binary.parent, self.threads)
                        break
                except (OSError, http.client.HTTPException) as exc:
                    last_error = str(exc)
                time.sleep(min(0.05, max(0, deadline-time.monotonic())))
            else:
                raise TimeoutError(f"model startup deadline exceeded; last connection: {last_error}")
        except Exception as exc:
            record.update({"status": "model_failure", "error": f"{type(exc).__name__}: {exc}",
                           "resources": _resources(self.pid)})
            self.close()
            raise
        finally:
            record["elapsed_seconds"] = time.monotonic()-start
            self.startup_record = record
            _write_json(self.evidence_dir / f"{self.session_id}-startup.json", record)
        return self

    def decide(self, state, questions, timeout_seconds=60, cancel_event=None) -> dict:
        request = {"state": state, "questions": questions}
        try:
            payload = validate_questions(state, questions)
            seconds = _seconds(timeout_seconds)
        except BackendRefusal as exc:
            record = self._base_record(request)
            record.update({"status": "invalid_request", "error": str(exc), "latency_seconds": 0.0})
            # Non-JSON input cannot be serialized; retain its explicit rejected representation.
            try:
                _json_bytes(request)
            except BackendRefusal:
                record["request"] = {"rejected_python_repr": repr(request)[:MAX_REQUEST_BYTES]}
            return self._retain(record)
        return self._request(request, payload, seconds, cancel_event, validate=True)

    def probe_raw(self, request: dict, timeout_seconds=30, cancel_event=None) -> dict:
        """Qualification-only malformed-request probe; never grants execution authority."""
        payload = _json_bytes(request)
        if len(payload) > MAX_REQUEST_BYTES:
            raise BackendRefusal("probe exceeds bounded request capacity")
        return self._request(request, payload, _seconds(timeout_seconds), cancel_event, validate=False)

    def _base_record(self, request):
        return {"session_id": self.session_id, "pid": self.pid, "request": request,
                "raw_response": None, "model_identity": dict(self.model_identity),
                "backend_identity": dict(self.backend_identity)}

    def _retain(self, record):
        self.evidence_dir.mkdir(parents=True, exist_ok=True)
        with self._record_lock:
            self._sequence += 1
            record["request_sequence"] = self._sequence
            path = self.evidence_dir / f"{self.session_id}-request-{self._sequence:04d}.json"
            record["evidence_path"] = str(path)
            _write_json(path, record)
        return record

    def _request(self, request, payload, seconds, cancel_event, validate):
        record = self._base_record(request)
        started = time.monotonic()
        record["resources_before"] = _resources(self.pid)
        if not self._lock.acquire(blocking=False):
            record.update({"status": "model_failure", "error": "another decision is outstanding", "latency_seconds": 0.0})
            return self._retain(record)
        worker = None
        try:
            if cancel_event is not None and cancel_event.is_set():
                record.update({"status": "cancelled", "error": "cancelled before submission"})
                self.close()
            elif self._retired or self.process is None or self.process.poll() is not None:
                record.update({"status": "model_failure", "error": "no live resident instance"})
            else:
                result_queue = queue.Queue(maxsize=1)

                def invoke():
                    try:
                        result_queue.put(self._http("POST", "/v1/systemone", payload, seconds))
                    except (TimeoutError, socket.timeout) as exc:
                        result_queue.put({"error": f"{type(exc).__name__}: {exc}", "raw_response": None,
                                          "transport_timeout": True})
                    except Exception as exc:
                        result_queue.put({"error": f"{type(exc).__name__}: {exc}", "raw_response": None})

                worker = threading.Thread(target=invoke, name=f"driv3r-http-{self.session_id}", daemon=True)
                worker.start()
                deadline = started + seconds
                while True:
                    if cancel_event is not None and cancel_event.is_set():
                        record.update({"status": "cancelled", "error": "cancelled during outstanding decision"})
                        self.close()
                        break
                    if time.monotonic() >= deadline:
                        record.update({"status": "timeout", "error": "decision deadline exceeded"})
                        self.close()
                        break
                    try:
                        result = result_queue.get(timeout=min(0.025, max(0.001, deadline-time.monotonic())))
                    except queue.Empty:
                        continue
                    record.update(result)
                    if result.get("transport_timeout"):
                        record.update({"status": "timeout", "error": "transport decision deadline exceeded"})
                        self.close()
                    elif result.get("http_status") != 200 or result.get("error"):
                        record.update({"status": "model_failure", "error": result.get("error", "backend refused request")})
                    else:
                        if validate:
                            raw = result.get("raw_response")
                            if type(raw) is not dict or type(raw.get("answers")) is not dict or set(raw["answers"]) != set(request["questions"]):
                                raise BackendRefusal("response does not exactly match named questions")
                            record["parsed_answers"] = {
                                name: parse_choice_response(raw, name, question["criteria"])
                                for name, question in request["questions"].items()}
                        record["status"] = "ok"
                    break
                # A cancellation/timeout record may retain an arrived response as
                # discarded evidence, never as a valid decision.
                if record.get("status") in ("cancelled", "timeout"):
                    worker.join(timeout=1)
                    try:
                        record["discarded_transport_result"] = result_queue.get_nowait()
                    except queue.Empty:
                        pass
        except Exception as exc:
            record.update({"status": "model_failure", "error": f"{type(exc).__name__}: {exc}"})
        finally:
            if record.get("status") == "ok" and cancel_event is not None and cancel_event.is_set():
                record["status"] = "cancelled"
                record["error"] = "cancelled before decision release"
                self.close()
            record["latency_seconds"] = time.monotonic()-started
            record["resources_after"] = _resources(self.pid)
            if worker is not None:
                record["transport_worker_alive"] = worker.is_alive()
            self._lock.release()
        return self._retain(record)

    def close(self):
        if self._retired:
            return
        started = time.monotonic()
        record = {"session_id": self.session_id, "pid": self.pid, "resources": _resources(self.pid)}
        self._retired = True
        try:
            if self.process is not None:
                stop_group(self.process)
                record["returncode"] = self.process.returncode
                record["process_reaped"] = self.process.poll() is not None
            else:
                record["process_reaped"] = True
        finally:
            if self._log is not None:
                self._log.close()
            if self._secret_dir is not None:
                self._secret_dir.cleanup()
            self._key = None
            record["elapsed_seconds"] = time.monotonic()-started
            self.shutdown_record = record
            self.evidence_dir.mkdir(parents=True, exist_ok=True)
            _write_json(self.evidence_dir / f"{self.session_id}-shutdown.json", record)


def _download(url, destination: Path, expected_sha, expected_bytes, deadline, evidence: Path):
    started = time.monotonic()
    record = {"url": url, "destination": str(destination), "expected_sha256": expected_sha,
              "expected_bytes": expected_bytes, "cache_hit": False}
    part = destination.with_name(destination.name + "." + uuid.uuid4().hex + ".part")
    try:
        if destination.is_file() and destination.stat().st_size == expected_bytes and sha256_file(destination) == expected_sha:
            record["cache_hit"] = True
        else:
            with urllib.request.urlopen(url, timeout=min(30, max(0.01, deadline-time.monotonic()))) as response, part.open("xb") as out:
                size = 0
                while True:
                    if time.monotonic() >= deadline:
                        raise TimeoutError("model/runtime acquisition deadline exceeded")
                    chunk = response.read(8 * 1024 * 1024)
                    if not chunk:
                        break
                    size += len(chunk)
                    if size > expected_bytes:
                        raise BackendRefusal("download exceeds pinned size")
                    out.write(chunk)
            if part.stat().st_size != expected_bytes or sha256_file(part) != expected_sha:
                raise BackendRefusal("download does not match pinned size/hash")
            part.replace(destination)
        record.update({"status": "PASS", "sha256": sha256_file(destination), "bytes": destination.stat().st_size})
    except Exception as exc:
        record.update({"status": "FAIL", "error": f"{type(exc).__name__}: {exc}",
                       "partial_path": str(part) if part.exists() else None})
        raise
    finally:
        record["elapsed_seconds"] = time.monotonic()-started
        _write_json(evidence / f"{destination.name}-{uuid.uuid4().hex}-acquisition.json", record)
    return record


def acquire(runtime_dir, evidence_dir, timeout_seconds=1200) -> dict:
    """Acquire only the exact official Q8 checkpoint and pinned official CPU build."""
    seconds = _seconds(timeout_seconds, 1800)
    start = time.monotonic()
    root, evidence = Path(runtime_dir).resolve(), Path(evidence_dir).resolve()
    root.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True, exist_ok=True)
    model, runtime = dict(PINS["model"]), dict(PINS["runtime"])
    model_path = root / model["filename"]
    model_url = f"https://huggingface.co/{model['repository']}/resolve/{model['revision']}/{model['filename']}"
    model_record = _download(model_url, model_path, model["sha256"], model["bytes"], start+seconds, evidence)
    archive = root / runtime["archive"]
    runtime_url = f"https://github.com/{runtime['repository']}/releases/download/{runtime['tag']}/{runtime['archive']}"
    runtime_record = _download(runtime_url, archive, runtime["archive_sha256"], runtime["archive_bytes"], start+seconds, evidence)
    directory, reused = _install_bundle(archive, root, runtime, start+seconds)
    runtime_record["existing_bundle_reused_without_write"] = reused
    binary = directory / "llama-server"
    runtime["binary_sha256"] = sha256_file(binary)
    runtime["files"] = {str(p.relative_to(binary.parent)): sha256_file(p)
                        for p in sorted(binary.parent.iterdir()) if p.is_file()}
    _identity(PINS["runtime"], runtime)
    # Licence is retained with model acquisition rather than vendoring weights.
    license_url = f"https://huggingface.co/{model['repository']}/resolve/{model['revision']}/LICENSE"
    with urllib.request.urlopen(license_url, timeout=min(30, max(0.01, start+seconds-time.monotonic()))) as response:
        license_bytes = response.read(65537)
    if len(license_bytes) > 65536:
        raise BackendRefusal("unexpected oversized model licence")
    license_path = root / "MODEL-LICENSE.txt"
    license_path.write_bytes(license_bytes)
    model["license_sha256"] = hashlib.sha256(license_bytes).hexdigest()
    if model["license_sha256"] != PINS["model"]["license_sha256"] or len(license_bytes) != PINS["model"]["license_bytes"]:
        raise BackendRefusal("model licence differs from pinned official revision")
    manifest = {"schema_version": 1, "binary": str(binary), "model": str(model_path),
                "model_identity": model, "backend_identity": runtime,
                "model_acquisition": model_record, "runtime_acquisition": runtime_record,
                "elapsed_seconds": time.monotonic()-start}
    _write_json(root / "runtime-manifest.json", manifest)
    _write_json(evidence / "runtime-manifest.json", manifest)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    download = sub.add_parser("acquire", help="Fetch pinned official Q8 and CPU runtime")
    download.add_argument("--runtime-dir", required=True)
    download.add_argument("--evidence", required=True)
    download.add_argument("--timeout-seconds", type=float, default=1200)
    args = parser.parse_args()
    try:
        manifest = acquire(args.runtime_dir, args.evidence, args.timeout_seconds)
    except Exception as exc:
        _write_json(Path(args.evidence)/f"acquisition-failure-{uuid.uuid4().hex}.json",
                    {"status":"FAIL", "error":f"{type(exc).__name__}: {exc}", "traceback":traceback.format_exc()})
        raise
    print(json.dumps({"status": "PASS", "manifest": str(Path(args.runtime_dir).resolve()/"runtime-manifest.json"),
                      "binary": manifest["binary"], "model": manifest["model"]}))


if __name__ == "__main__":
    main()
