"""Monitor a child without relying on Godot's blocked main loop or GDScript VM."""

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

import godot_timeout_diagnostics as diagnostics
from physical_progress_watchdog import ProgressWatchdog

POLL_SECONDS = 0.1
CAPTURE_SECONDS = 30.0
LOG_TAIL_BYTES = 256 * 1024


def _output_tail(path: Path) -> str:
    try:
        with path.open("rb") as handle:
            handle.seek(0, os.SEEK_END)
            handle.seek(max(0, handle.tell() - LOG_TAIL_BYTES))
            return handle.read(LOG_TAIL_BYTES).decode("utf-8", errors="replace")
    except OSError:
        return ""


class _Capture:
    """A separate process keeps diagnostic commands off the watchdog's clock."""

    def __init__(self, pid: int, output: Path, context: dict):
        self.output = output
        self.error = None
        self.started = time.perf_counter()
        output.mkdir(parents=True, exist_ok=True)
        (output / "context.json").write_text(json.dumps(context, indent=2) + "\n", encoding="utf-8")
        self.log = (output / "capture.log").open("w", encoding="utf-8")
        options = ({"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
                   if sys.platform == "win32" else {"start_new_session": True})
        try:
            self.child = subprocess.Popen(
                [sys.executable, str(Path(diagnostics.__file__).resolve()), "--pid", str(pid), "--output", str(output.resolve())],
                stdout=self.log, stderr=subprocess.STDOUT, **options,
            )
        except BaseException:
            self.log.close()
            raise
        self.closed = False
        try:
            self._state("running")
        except OSError:
            diagnostics.stop_process_tree(self.child)
            self.log.close()
            raise

    def _state(self, status: str):
        (self.output / "capture-state.json").write_text(json.dumps({
            "status": status, "capture_pid": self.child.pid,
            "capture_limit_seconds": CAPTURE_SECONDS,
            "elapsed_seconds": round(time.perf_counter() - self.started, 3),
            "returncode": self.child.poll(), "error": self.error,
        }, indent=2) + "\n", encoding="utf-8")

    def poll(self, now: float) -> None:
        if not self.closed:
            if self.child.poll() is not None:
                self.close()
            elif now - self.started >= CAPTURE_SECONDS:
                self.close("total diagnostic capture limit reached")

    def close(self, reason: str | None = None) -> None:
        if self.closed:
            return
        if self.child.poll() is None:
            self.error = reason or "diagnostic capture interrupted when engine exited"
            # Diagnostic commands own separate sessions so they can independently
            # clean descendants. Their recorded PIDs allow outer cancellation too.
            if sys.platform != "win32":
                for path in self.output.glob("*.command.json"):
                    try:
                        state = json.loads(path.read_text(encoding="utf-8"))
                        if state.get("active"):
                            os.killpg(state["pid"], signal.SIGKILL)
                    except (OSError, ValueError, KeyError):
                        pass
            diagnostics.stop_process_tree(self.child)
        elif self.child.returncode != 0:
            self.error = f"diagnostic process exit={self.child.returncode}; inspect capture.log"
        elif not (self.output / "snapshot.json").is_file():
            self.error = "diagnostic process exited without snapshot.json"
        self.log.close()
        text = _output_tail(self.output / "capture.log")
        (self.output / "capture.log").write_text(text, encoding="utf-8")
        self.closed = True
        self._state("incomplete" if self.error else "completed")


def wait(child: subprocess.Popen, name: str, timeout: float, started: float,
         log_path: Path, diagnostic_path: Path, *, capture_factory=None,
         on_timeout=None) -> tuple[bool, str | None, str | None]:
    watchdog = ProgressWatchdog(name, started)
    deadline = started + timeout
    capture_at = deadline - min(30.0, timeout * 0.2)
    captured = False
    capture = None
    capture_error = None
    timed_out, timeout_kind = False, None
    factory = capture_factory or _Capture
    try:
        while child.poll() is None:
            now = time.perf_counter()
            output = _output_tail(log_path) if watchdog.enabled else ""
            watchdog.observe(output, now)
            # Decide limits independently of any diagnostic process or debugger.
            if now >= deadline:
                timed_out, timeout_kind = True, "case_deadline"
                break
            if watchdog.expired(now):
                print(f"{name}: progress watchdog expired after {watchdog.idle_seconds(now):.3f}s "
                      f"without a new marker; last_progress={watchdog.marker}", flush=True)
                timed_out, timeout_kind = True, "progress_watchdog"
                break
            if capture is not None:
                capture.poll(now)
            if not captured and (now >= capture_at or watchdog.capture_due(now)):
                if not output:
                    output = _output_tail(log_path)
                context = {"case": name, "pid": child.pid, "elapsed_seconds": now - started,
                           "captured_unix_seconds": time.time(), "last_progress": diagnostics.last_progress(output)}
                print(f"{name}: elapsed={now - started:.3f}s pid={child.pid} "
                      f"last_progress={context['last_progress']}\n" + output[-8192:], flush=True)
                try:
                    capture = factory(child.pid, diagnostic_path, context)
                except Exception as error:
                    capture_error = f"{type(error).__name__}: {error}"
                    print(f"Diagnostic capture failed for {name}: {capture_error}", flush=True)
                captured = True
            interval = min(POLL_SECONDS, max(0.001, deadline - now))
            if not captured:
                interval = min(interval, max(0.001, capture_at - now))
            try:
                child.wait(timeout=interval)
            except subprocess.TimeoutExpired:
                pass
    finally:
        if timed_out and on_timeout is not None:
            on_timeout(time.perf_counter())
        if capture is not None:
            try:
                capture.close("engine timeout reached before diagnostic capture completed" if timed_out else None)
                capture_error = capture.error or capture_error
            except Exception as error:
                capture_error = f"{type(error).__name__}: {error}"
    return timed_out, timeout_kind, capture_error
