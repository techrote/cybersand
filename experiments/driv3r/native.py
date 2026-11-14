"""Bounded local RPC to one actual mounted Godot/Workbench/native World.

Only the host may call this adapter. Model responses never contain RPC commands.
The independent native session enforces fixed focus, palette, protection, source
freshness and budgets again. Images are native material readbacks, not frames.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import threading
import time
import uuid

from experiments.agent_painter.process import stop_group
from experiments.agent_painter.native.runtime import GODOT_VERSION, RAPIER_PINS

PROTOCOL_VERSION = 1
WORLD_SIZE = 512
FOCUS_SIZE = 96


class NativeError(RuntimeError):
    """A failed or inconsistent native transport; never success evidence."""


def _canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _atomic(path: Path, value: object) -> None:
    content = _canonical(value)
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("xb") as stream:
        stream.write(content)
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


def verify_observation(directory: Path, observation: dict) -> list[int]:
    """Read actual full-world bytes, independently close the crop/hash contract."""
    if not isinstance(observation, dict) or observation.get("width") != 96 or observation.get("height") != 96:
        raise NativeError("Invalid native observation dimensions")
    if observation.get("focus") != [0, 0, 96, 96] or observation.get("allowed_materials") != [58]:
        raise NativeError("Native host authority changed")
    paths: dict[str, Path] = {}
    for key in ("material_path", "world_material_path", "png_path"):
        name = observation.get(key)
        if not isinstance(name, str) or not re.fullmatch(r"readback-[0-9]{6}-(?:after|before)\.(?:materials\.i32le|world\.i32le|png)", name):
            raise NativeError("Unsafe native evidence path")
        paths[key] = directory / name
    full_bytes = paths["world_material_path"].read_bytes()
    crop_bytes = paths["material_path"].read_bytes()
    if len(full_bytes) != 512 * 512 * 4 or len(crop_bytes) != 96 * 96 * 4:
        raise NativeError("Incomplete native material byte count")
    if hashlib.sha256(full_bytes).hexdigest() != observation.get("world_material_sha256"):
        raise NativeError("Full native readback hash mismatch")
    if hashlib.sha256(crop_bytes).hexdigest() != observation.get("material_sha256"):
        raise NativeError("Native crop readback hash mismatch")
    full = list(struct.unpack("<262144i", full_bytes))
    crop = list(struct.unpack("<9216i", crop_bytes))
    expected = [full[y * 512 + x] for y in range(96) for x in range(96)]
    if crop != expected or observation.get("materials") != crop:
        raise NativeError("Returned material grid differs from actual native readback")
    if not paths["png_path"].read_bytes().startswith(b"\x89PNG\r\n\x1a\n"):
        raise NativeError("Native material PNG missing")
    if _digest(paths["png_path"]) != observation.get("png_sha256"):
        raise NativeError("Native PNG integrity mismatch")
    from PIL import Image
    palette = {0: (13, 21, 28), 28: (178, 116, 54), 58: (232, 226, 205)}
    if any(value not in palette for value in crop):
        raise NativeError("Unexpected material in fixture readback")
    with Image.open(paths["png_path"]) as image:
        expected_rgb = bytes(channel for value in crop for channel in palette[value])
        if image.size != (96, 96) or image.convert("RGB").tobytes() != expected_rgb:
            raise NativeError("Native PNG pixels differ from native material readback")
    for key in ("generation", "revision", "tick", "cumulative_changed_cells", "action_count"):
        value = observation.get(key)
        if type(value) not in (int, float) or not math.isfinite(value) or int(value) != value or value < 0:
            raise NativeError("Invalid native state identity: " + key)
        observation[key] = int(value)
    return full


class NativeSession:
    """One owned Godot process with many sequential actions and fresh episodes.

    Default mode is source-compatible diagnostic use. A supplied same-source
    build manifest is verified through #568's unmodified runtime verifier.
    """

    def __init__(self, repo_root: Path | str, godot: Path | str, output_dir: Path | str,
                 source_sha: str, *, timeout: float = 60.0,
                 startup_timeout: float = 180.0, runtime_manifest: Path | str | None = None):
        if os.name != "posix":
            raise NativeError("Stage A persistent native process ownership is POSIX-only")
        if not re.fullmatch(r"[0-9a-f]{40}", source_sha):
            raise NativeError("Full immutable source SHA required")
        if not math.isfinite(timeout) or not 0 < timeout <= 110:
            raise NativeError("RPC timeout must be in (0, 110] seconds")
        if not math.isfinite(startup_timeout) or not 0 < startup_timeout <= 240:
            raise NativeError("Startup timeout must be in (0, 240] seconds")
        self.root = Path(repo_root).resolve()
        self.godot = Path(godot).resolve()
        self.output = Path(output_dir).resolve()
        self.source_sha = source_sha
        self.timeout = timeout
        self.startup_timeout = startup_timeout
        self.runtime_manifest = Path(runtime_manifest).resolve() if runtime_manifest else None
        self.session_id = uuid.uuid4().hex
        self.process: subprocess.Popen | None = None
        self.latest_observation: dict | None = None
        self._log = None
        self._sequence = 0
        self._lock = threading.Lock()
        self._cancel_lock = threading.Lock()
        self._closed = False
        self._poisoned = False
        self._full_materials: list[int] | None = None
        self._identities: dict[Path, str] = {}

    def __enter__(self):
        return self.start()

    def __exit__(self, *_):
        self.close()

    def start(self):
        if self.process is not None or self._closed:
            raise NativeError("Native session cannot be started twice")
        self.output.mkdir(parents=True, exist_ok=False)
        self.output.chmod(0o700)
        version = subprocess.check_output([str(self.godot), "--version"], text=True, timeout=15).strip()
        if version != GODOT_VERSION:
            raise NativeError(f"Expected Godot {GODOT_VERSION}, found {version}")
        actual_sha = subprocess.check_output(["git", "-C", str(self.root), "rev-parse", "HEAD"], text=True, timeout=15).strip()
        if actual_sha != self.source_sha:
            raise NativeError("Native session source SHA differs from checked-out HEAD")
        native = self.root / "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
        if not native.read_bytes().startswith(b"\x7fELF"):
            raise NativeError("Actual materialized native ELF is required")
        rapier_name, rapier_hash = RAPIER_PINS["Linux"]
        rapier = self.root / "godot/addons/godot-rapier2d/bin" / rapier_name
        if _digest(rapier) != rapier_hash:
            raise NativeError("Rapier differs from pinned dependency")
        if self.runtime_manifest:
            from experiments.agent_painter.native.runtime import verify
            runtime = verify(self.root, self.runtime_manifest, self.source_sha, self.godot)
        else:
            from experiments.agent_painter.native.runtime import development_runtime
            runtime = development_runtime(self.root, self.source_sha, self.godot)
        from .stage_b.catalog import catalogs
        _, catalog_hashes = catalogs(self.root)
        runtime.update({"driv3r_harness_sha256": _digest(self.root / "godot/tests/run_driv3r_stage_a.gd"),
                        "driv3r_native_client_sha256": _digest(Path(__file__)),
                        "driv3r_fixture_catalog_sha256": catalog_hashes,
                        "session_id": self.session_id, "parent_pid": os.getpid()})
        self._identities = {path: _digest(path) for path in
                            (self.root / "godot/tests/run_driv3r_stage_a.gd", Path(__file__), native, rapier, self.godot)}
        self._identities.update({self.root / path: sha for path, sha in catalog_hashes.items()})
        _atomic(self.output / "runtime-custody.json", runtime)
        env = os.environ.copy()
        env.update(DRIV3R_NATIVE_DIRECTORY=str(self.output), DRIV3R_NATIVE_SESSION=self.session_id,
                   DRIV3R_SOURCE_SHA=self.source_sha, DRIV3R_PARENT_PID=str(os.getpid()),
                   DRIV3R_FIXTURE_HASHES=json.dumps(catalog_hashes),
                   GODOT_SILENCE_ROOT_WARNING="1")
        # Isolate Workbench settings/save state from all other local sessions.
        user_dir = self.output / "user"
        user_dir.mkdir()
        env["XDG_DATA_HOME"] = str(user_dir)
        env["XDG_CONFIG_HOME"] = str(user_dir)
        self._log = (self.output / "godot.log").open("w", encoding="utf-8")
        command = [str(self.godot), "--headless", "--path", str(self.root / "godot"),
                   "--script", "res://tests/run_driv3r_stage_a.gd"]
        started = time.monotonic()
        self.process = subprocess.Popen(command, env=env, stdin=subprocess.DEVNULL,
                                        stdout=self._log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            ready = self._wait_file(self.output / "ready.json", self.startup_timeout)
            if ready.get("pid") != self.process.pid or ready.get("session_id") != self.session_id \
                    or ready.get("source_sha") != self.source_sha or ready.get("backend") != "CyberNativeCellWorld" \
                    or ready.get("native_sha256") != _digest(native) or ready.get("rapier_sha256") != rapier_hash:
                raise NativeError("Mounted native process identity mismatch")
            _atomic(self.output / "startup.json", {"elapsed_seconds": time.monotonic() - started,
                                                   "command": command, "ready": ready})
        except BaseException:
            self.close(graceful=False)
            raise
        return self

    def _wait_file(self, path: Path, timeout: float, cancel_event=None) -> dict:
        deadline = time.monotonic() + timeout
        cancelled = False
        while time.monotonic() < deadline:
            if cancel_event is not None and cancel_event.is_set() and not cancelled:
                self.cancel()
                cancelled = True
            if path.exists():
                if path.stat().st_size > 4_000_000:
                    raise NativeError("Oversized native reply")
                value = json.loads(path.read_text())
                if not isinstance(value, dict):
                    raise NativeError("Native reply must be an object")
                return value
            if self.process is None or self.process.poll() is not None:
                raise NativeError("Native process exited before acknowledgement")
            time.sleep(0.01)
        self.cancel()
        self._poisoned = True
        raise NativeError("Native acknowledgement timeout; session retired")

    def _request(self, kind: str, fields: dict | None = None, *, timeout: float | None = None,
                 cancel_event=None) -> dict:
        if self._closed or self.process is None or self.process.poll() is not None:
            raise NativeError("Native session is closed")
        if self._poisoned:
            raise NativeError("Timed-out native session cannot admit more requests")
        if not self._lock.acquire(blocking=False):
            raise NativeError("Only one ordered native request may be outstanding")
        try:
            if any(_digest(path) != expected for path, expected in self._identities.items()):
                raise NativeError("Consumed native session source or runtime changed")
            seconds = self.timeout if timeout is None else timeout
            if not math.isfinite(seconds) or not 0 < seconds <= 110:
                raise NativeError("Invalid native request deadline")
            if self._sequence >= 256:
                raise NativeError("Native session request budget exhausted")
            # An explicit new episode may retire the previous episode's Stop,
            # but never a cancellation delivered after this request is published.
            # The separate lock also orders out-of-band cancel() against clearing
            # the old marker; the RPC lock alone cannot protect that boundary.
            with self._cancel_lock:
                if kind == "reset":
                    if cancel_event is not None and cancel_event.is_set():
                        raise NativeError("Cancelled before explicit episode reset")
                    (self.output / "cancel").unlink(missing_ok=True)
                self._sequence += 1
                if cancel_event is not None and cancel_event.is_set():
                    (self.output / "cancel").touch(exist_ok=True)
                request = {"protocol_version": 1, "request_id": self._sequence, "kind": kind,
                           "expires_unix": time.time() + seconds, **(fields or {})}
                if len(_canonical(request)) > 65536:
                    raise NativeError("Request exceeds native transport bound")
                _atomic(self.output / f"request-{self._sequence:06d}.json", request)
            response = self._wait_file(self.output / f"response-{self._sequence:06d}.json", seconds + 5,
                                       cancel_event=cancel_event)
            if response.get("protocol_version") != 1 or response.get("request_id") != self._sequence:
                raise NativeError("Native response is stale or reordered")
            if response.get("fatal"):
                raise NativeError("Native harness failed: " + str(response["fatal"]))
            observation = response.get("observation")
            if observation:
                full = verify_observation(self.output, observation)
                receipt = response.get("receipt", {})
                if self._full_materials is not None and kind != "reset" and "actual_changed_cells" in receipt:
                    changed = sum(a != b for a, b in zip(self._full_materials, full, strict=True))
                    if changed != receipt["actual_changed_cells"]:
                        raise NativeError("Independent full native changed-cell count mismatch")
                    if response["status"] == "refused" and changed:
                        raise NativeError("Refused request changed native cells")
                    if kind == "apply":
                        reconstructed = self._full_materials.copy()
                        changed_from_receipts = 0
                        for native in receipt.get("native_receipts", []):
                            if native.get("backend") != "CyberNativeCellWorld":
                                raise NativeError("Native chunk has wrong backend")
                            changed_from_receipts += native.get("changed", 0)
                            for row in native.get("readback", []):
                                if len(row) != 4 or any(type(v) not in (int, float) or int(v) != v for v in row):
                                    raise NativeError("Invalid native chunk readback")
                                x, y, old, new = map(int, row)
                                if not 0 <= x < 512 or not 0 <= y < 512 or reconstructed[y * 512 + x] != old:
                                    raise NativeError("Native receipt previous cell does not match original readback")
                                reconstructed[y * 512 + x] = new
                        if reconstructed != full or changed_from_receipts != changed:
                            raise NativeError("Actual native receipts do not reconstruct final material bytes")
                self._full_materials = full
                self.latest_observation = observation
            return response
        except BaseException:
            self._poisoned = True
            self.cancel()
            raise
        finally:
            self._lock.release()

    def reset(self, fixture: str = "wall-v1", *, timeout: float | None = None, cancel_event=None) -> dict:
        return self._request("reset", {"fixture": fixture}, timeout=timeout, cancel_event=cancel_event)

    def observe(self, *, timeout: float | None = None, cancel_event=None) -> dict:
        return self._request("observe", timeout=timeout, cancel_event=cancel_event)

    def apply(self, operations: list[dict], *, expected_generation: int,
              expected_revision: int, expected_tick: int, action_id: str,
              cell_budget: int, cancel_event=None, timeout: float | None = None) -> dict:
        return self._request("apply", {"operations": operations, "expected_generation": expected_generation,
                                       "expected_revision": expected_revision, "expected_tick": expected_tick,
                                       "action_id": action_id, "cell_budget": cell_budget},
                             cancel_event=cancel_event, timeout=timeout)

    def cancel(self) -> None:
        """Out-of-band permanent episode fence; does not wait for the RPC lock."""
        with self._cancel_lock:
            if self.output.exists():
                (self.output / "cancel").touch(exist_ok=True)

    def stop(self, reason: str = "host Stop") -> dict:
        # Reason is retained locally; it cannot change the native authorization.
        self.cancel()
        result = self._request("stop")
        _atomic(self.output / f"stop-{self._sequence:06d}.json", {"reason": reason, "response": result})
        return result

    def close(self, *, graceful: bool = True) -> None:
        if self._closed:
            return
        cleanup = {"session_id": self.session_id, "graceful": False, "exit_code": None}
        try:
            if self.process is not None:
                self.cancel()
                if graceful and not self._poisoned and self.process.poll() is None:
                    try:
                        self._request("shutdown", timeout=10)
                        self.process.wait(timeout=10)
                        cleanup["graceful"] = True
                    except (NativeError, subprocess.TimeoutExpired):
                        pass
                stop_group(self.process)
                cleanup["exit_code"] = self.process.returncode
        finally:
            self._closed = True
            if self._log:
                self._log.close()
            if self.output.exists() and not (self.output / "cleanup.json").exists():
                _atomic(self.output / "cleanup.json", cleanup)
