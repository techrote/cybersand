"""Runner-side watchdog: remains runnable when Godot's main thread is stuck."""

import json
import math
import re

CASES = frozenset({"test_physical_actor_arena", "test_physical_actor_rigs", "test_physical_usable_course"})
SNAPSHOT_IDLE_SECONDS = 30.0
FAIL_IDLE_SECONDS = 45.0


class ProgressWatchdog:
    def __init__(self, name: str, started: float):
        if not math.isfinite(started):
            raise ValueError("Watchdog start must be finite monotonic time")
        self.name = name
        self.enabled = name in CASES
        self.last_change = started
        self.marker = None
        self._identity = None

    def observe(self, output: str, now: float) -> None:
        if not math.isfinite(now):
            raise ValueError("Watchdog observation must be finite monotonic time")
        marker = self._last_progress(output)
        # Timestamps alone are not main-thread progress. The fixture helper's
        # sequence/steps or actual #233 phase/rig/tick must change.
        identity = {key: value for key, value in marker.items() if key != "elapsed_ms"} if marker else None
        if identity is not None and identity != self._identity:
            self.marker = marker
            self._identity = identity
            self.last_change = max(self.last_change, now)

    def _last_progress(self, output: str) -> dict | None:
        for line in reversed(output.splitlines()):
            if line.startswith("CYBERSAND_PROGRESS "):
                try:
                    marker = json.loads(line.removeprefix("CYBERSAND_PROGRESS "))
                except ValueError:
                    continue
                if (isinstance(marker, dict) and isinstance(marker.get("phase"), str)
                        and marker["phase"] and marker.get("case", self.name) in ("", self.name)):
                    return marker
            elif line.startswith("REGRESSION_PROGRESS "):
                fields = dict(re.findall(r"\b(case|phase|rig|model|tick)=([^\s]+)", line))
                if fields.get("case") == self.name and fields.get("phase"):
                    return {**fields, "raw": line}
        return None

    def idle_seconds(self, now: float) -> float:
        return max(0.0, now - self.last_change)

    def capture_due(self, now: float) -> bool:
        return self.enabled and self.idle_seconds(now) >= SNAPSHOT_IDLE_SECONDS

    def expired(self, now: float) -> bool:
        return self.enabled and self.idle_seconds(now) >= FAIL_IDLE_SECONDS
