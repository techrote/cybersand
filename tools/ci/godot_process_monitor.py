"""Monitor a child without relying on Godot's blocked main loop or GDScript VM."""

from pathlib import Path
import json
import subprocess
import time

import godot_timeout_diagnostics as diagnostics
from physical_progress_watchdog import ProgressWatchdog

POLL_SECONDS = 1.0


def wait(child: subprocess.Popen, name: str, timeout: float, started: float,
         log_path: Path, diagnostic_path: Path) -> tuple[bool, str | None, str | None]:
    watchdog = ProgressWatchdog(name, started)
    deadline = started + timeout
    capture_at = deadline - min(30.0, timeout * 0.2)
    captured = False
    capture_error = None
    while child.poll() is None:
        now = time.perf_counter()
        output = log_path.read_text(encoding="utf-8", errors="replace") if watchdog.enabled else ""
        watchdog.observe(output, now)
        if not captured and (now >= capture_at or watchdog.capture_due(now)):
            if not output:
                output = log_path.read_text(encoding="utf-8", errors="replace")
            print(f"{name}: elapsed={now - started:.3f}s pid={child.pid} "
                  f"last_progress={diagnostics.last_progress(output)}\n" + output[-8192:], flush=True)
            try:
                diagnostics.snapshot(child.pid, diagnostic_path)
                if diagnostic_path.is_dir():
                    (diagnostic_path / "context.json").write_text(json.dumps({
                        "case": name, "elapsed_seconds": now - started,
                        "captured_unix_seconds": time.time(),
                        "last_progress": diagnostics.last_progress(output),
                    }, indent=2) + "\n", encoding="utf-8")
            except Exception as error:
                capture_error = str(error)
                print(f"Diagnostic capture failed for {name}: {error}", flush=True)
            captured = True
            # Reobserve after debugger detach before deciding to fail. A bounded
            # capture must not itself hide resumed fixture progress.
            continue
        if now >= deadline:
            return True, "case_deadline", capture_error
        if watchdog.expired(now):
            print(f"{name}: progress watchdog expired after {watchdog.idle_seconds(now):.3f}s "
                  f"without a new marker; last_progress={watchdog.marker}", flush=True)
            return True, "progress_watchdog", capture_error
        interval = min(POLL_SECONDS, max(0.001, deadline - now))
        if not captured:
            interval = min(interval, max(0.001, capture_at - now))
        try:
            child.wait(timeout=interval)
        except subprocess.TimeoutExpired:
            pass
    return False, None, capture_error
