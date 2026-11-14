"""Explicitly allowlisted source-checked M3 native history/cursor extension.

Retains the original NativeSession request transport, exact World readback,
source identities and Stop/cleanup; only selects the M3 GDScript subclass
and provides bounded, host-only logical cursor/PAINT Undo requests.
"""
from __future__ import annotations
from pathlib import Path

from experiments.driv3r.native import NativeError, NativeSession

HISTORY_HARNESS = "res://tests/run_driv3r_m3_history.gd"


class HistorySession(NativeSession):
    def __init__(self, repo_root, godot, output_dir, source_sha, *,
                 timeout=60.0, startup_timeout=180.0, runtime_manifest=None):
        super().__init__(
            repo_root, godot, output_dir, source_sha,
            timeout=timeout, startup_timeout=startup_timeout,
            runtime_manifest=runtime_manifest,
            graphical=False, harness_script=HISTORY_HARNESS,
        )

    def _command(self, kind: str, payload: dict, *, precondition: dict | None = None) -> dict:
        if kind not in ("m3_cursor_move", "m3_branch_save",
                        "m3_branch_relocate", "m3_undo"):
            raise NativeError("Unknown M3 command")
        observation = precondition if precondition is not None else self.latest_observation
        if not isinstance(observation, dict) or not all(
                isinstance(observation.get(key), int) for key in ("generation", "revision", "tick")):
            raise NativeError("M3 requires fresh native observation source fence")
        result = self._request(kind, {
            "expected_generation": observation["generation"],
            "expected_revision": observation["revision"],
            "expected_tick": observation["tick"],
            "m3_payload": payload,
        }, timeout=30)
        if result.get("status") == "completed":
            receipt = result.get("receipt")
            if not isinstance(receipt, dict) or not receipt.get("readback_matches"):
                raise NativeError("M3 native command missing matched readback")
            if kind != "m3_undo" and receipt.get("actual_changed_cells") != 0:
                raise NativeError("M3 brush-up logical command changed native material")
            if kind == "m3_undo":
                history = result.get("history_receipt")
                if not isinstance(history, dict) or (
                        history.get("action") != "undo" or
                        history.get("status") != "completed" or
                        history.get("changed") != 1 or
                        not history.get("recorded") or
                        result.get("receipt", {}).get("actual_changed_cells") != 1):
                    raise NativeError("M3 real Undo lacks exact one-cell PAINT completion receipt")
        return result

    def cursor_move(self, start: list[int], end: list[int], *, precondition=None) -> dict:
        return self._command("m3_cursor_move",
                             {"from":start,"to":end,"brush_lifted":True},
                             precondition=precondition)

    def save_branch(self, name: str, cursor: list[int], *, precondition=None) -> dict:
        return self._command("m3_branch_save",
                             {"name":name,"cursor":cursor,"brush_lifted":True},
                             precondition=precondition)

    def relocate_branch(self, name: str, cursor: list[int], *, precondition=None) -> dict:
        return self._command("m3_branch_relocate",
                             {"name":name,"from":cursor,"brush_lifted":True},
                             precondition=precondition)

    def undo(self, *, precondition=None) -> dict:
        return self._command("m3_undo",
                             {"history_action":"undo","brush_lifted":True},
                             precondition=precondition)
