"""Runner-side watchdog: remains runnable when Godot's main thread is stuck."""

from godot_timeout_diagnostics import last_progress

CASES = frozenset({"test_physical_actor_arena", "test_physical_actor_rigs", "test_physical_usable_course"})
SNAPSHOT_IDLE_SECONDS = 30.0
FAIL_IDLE_SECONDS = 45.0


class ProgressWatchdog:
    def __init__(self, name: str, started: float):
        self.enabled = name in CASES
        self.last_change = started
        self.marker = None

    def observe(self, output: str, now: float) -> None:
        marker = last_progress(output)
        if marker is not None and marker != self.marker:
            self.marker = marker
            self.last_change = now

    def idle_seconds(self, now: float) -> float:
        return max(0.0, now - self.last_change)

    def capture_due(self, now: float) -> bool:
        return self.enabled and self.idle_seconds(now) >= SNAPSHOT_IDLE_SECONDS

    def expired(self, now: float) -> bool:
        return self.enabled and self.idle_seconds(now) >= FAIL_IDLE_SECONDS
