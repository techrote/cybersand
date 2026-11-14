"""Offline evidence refusals plus opt-in actual Godot/native RPC regressions.

Set DRIV3R_NATIVE_GODOT and DRIV3R_NATIVE_OUTPUT to run the real suite; ordinary
offline runs make no claim that the deliberately skipped native suite passed.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import threading
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from experiments.driv3r.native import NativeError, NativeSession, verify_observation


def run_native_regressions(repo_root, godot, output_dir, source_sha, runtime_manifest=None) -> dict:
    output_dir = Path(output_dir)
    checks = []
    def check(label, passed, **details):
        row = {"label": label, "passed": bool(passed), **details}
        checks.append(row)
        (output_dir / "checks.json").write_text(json.dumps(checks, indent=2) + "\n")
        if not passed:
            raise AssertionError(label)
    with NativeSession(repo_root, godot, output_dir, source_sha, runtime_manifest=runtime_manifest) as native:
        initial = native.reset()["observation"]
        check("fixture uses authoritative protected material", initial["materials"][20 * 96 + 8] == 28)
        def action(x=12, y=25, material=58, state=None, operations=None, budget=1, cancel_event=None):
            o = state or native.latest_observation
            return native.apply(operations or [{"shape": "rectangle", "x0": x, "y0": y,
                                                "x1": x, "y1": y, "material": material}],
                                expected_generation=o["generation"], expected_revision=o["revision"],
                                expected_tick=o["tick"], action_id="native-regression", cell_budget=budget,
                                cancel_event=cancel_event)
        first = action()
        check("real first native cell", first["status"] == "completed" and first["receipt"]["actual_changed_cells"] == 1)
        second = action(y=26)
        check("same persistent World second native cell", second["status"] == "completed"
              and second["receipt"]["actual_changed_cells"] == 1
              and second["observation"]["world_id"] == initial["world_id"])
        for label, result in [
            ("stale revision", action(y=27, state=initial)),
            ("unauthorized material", action(y=27, material=28)),
            ("out of focus", action(x=96)),
            ("malformed action", action(operations=[{"shape":"rectangle","x0":12,"y0":27,"x1":12,"y1":27,"material":58,"override":True}])),
            ("cell budget", action(operations=[{"shape":"rectangle","x0":12,"y0":27,"x1":14,"y1":27,"material":58}]))
        ]:
            check(label + " refused without mutation", result["status"] == "refused"
                  and result["receipt"]["actual_changed_cells"] == 0
                  and result["receipt"]["before_world_sha256"] == result["receipt"]["after_world_sha256"])
        # JSON can carry numbers far beyond native int/Vector2i capacity.
        # A refusal must be structured; it must not crash, overflow or mutate.
        for label, operations in [
            ("huge positive pixel X", [{"shape":"pixels","material":58,"points":[[1e200, 25]]}]),
            ("huge negative pixel Y", [{"shape":"pixels","material":58,"points":[[12, -1e200]]}]),
            ("large finite pixel X", [{"shape":"pixels","material":58,"points":[[2147483648, 25]]}]),
            ("huge rectangle X", [{"shape":"rectangle","material":58,"x0":12,"x1":1e200,"y0":25,"y1":25}]),
        ]:
            before = native.latest_observation
            response = action(operations=operations)
            after = response.get("observation", {})
            check(label + " refused before integer conversion without mutation",
                  response.get("status") == "refused" and
                  response.get("receipt", {}).get("actual_changed_cells") == 0 and
                  after.get("world_material_sha256") == before.get("world_material_sha256") and
                  after.get("generation") == before.get("generation") and
                  after.get("revision") == before.get("revision") and
                  after.get("tick") == before.get("tick"))
        no_frame = native.frame()
        check("headless framebuffer refused", no_frame.get("status") == "refused")
        protected = action(x=8, y=20)
        check("protected material native no-op", protected["status"] == "completed"
              and protected["receipt"]["actual_changed_cells"] == 0
              and protected["receipt"]["terminal"]["excluded"] == 1
              and protected["observation"]["materials"][20 * 96 + 8] == 28)
        guard = action(x=40, y=40)
        check("protected rectangle native no-op", guard["status"] == "completed"
              and guard["receipt"]["actual_changed_cells"] == 0
              and guard["receipt"]["terminal"]["excluded"] == 1)
        before = native.latest_observation["world_material_sha256"]
        expired = native._request("observe", {"expires_unix": time.time() - 10})
        after = native.observe()["observation"]["world_material_sha256"]
        check("expired request refused with unchanged native state", expired["status"] == "refused" and before == after)
        stopped = native.stop("qualification STOP")
        late = action(y=27)
        check("explicit STOP retires native epoch", stopped["status"] == "stopped" and stopped["observation"]["retired"])
        check("late action after STOP has zero native changes", late["status"] == "refused" and late["receipt"]["actual_changed_cells"] == 0)
        resumed = native.reset()["observation"]
        check("explicit new episode has distinct generation", resumed["generation"] > initial["generation"]
              and resumed["world_material_sha256"] == initial["world_material_sha256"])
        cancel = threading.Event()
        cancel.set()
        cancelled = action(cancel_event=cancel)
        check("cancelled decision cannot paint", cancelled["status"] == "refused" and cancelled["receipt"]["actual_changed_cells"] == 0)
        native.reset()
        next_id = native._sequence + 1
        pending_path = output_dir / f"request-{next_id:06d}.json"
        pending_cancel = threading.Event()
        def cancel_pending():
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline and not pending_path.exists():
                time.sleep(0.001)
            pending_cancel.set()
        thread = threading.Thread(target=cancel_pending)
        thread.start()
        outstanding = action(cancel_event=pending_cancel)
        thread.join(timeout=1)
        after_cancel = native.observe()
        check("cancellation while RPC outstanding retires without unintended cells",
              pending_cancel.is_set() and after_cancel["observation"]["retired"]
              and outstanding["receipt"]["actual_changed_cells"] == 0
              and after_cancel["observation"]["world_material_sha256"] == initial["world_material_sha256"],
              status=outstanding["status"])
        native.reset()
        malformed = native._request("apply", {"operations": "not an array"})
        check("native malformed request refused", malformed["status"] == "refused"
              and malformed["receipt"]["actual_changed_cells"] == 0)
        # Freeze only this owned child so cancellation is certainly delivered
        # after reset publication and before Godot can dispatch it. Previously
        # native reset erased this new marker and silently replaced the World.
        marked = action()["observation"]
        pending_path = output_dir / f"request-{native._sequence + 1:06d}.json"
        reset_cancel = threading.Event()
        reset_result, reset_errors = {}, []
        def request_cancelled_reset():
            try:
                reset_result.update(native.reset(timeout=20, cancel_event=reset_cancel))
            except Exception as exc:
                reset_errors.append(f"{type(exc).__name__}: {exc}")
        reset_thread = threading.Thread(target=request_cancelled_reset)
        os.kill(native.process.pid, signal.SIGSTOP)
        try:
            reset_thread.start()
            deadline = time.monotonic() + 5
            while not pending_path.exists() and time.monotonic() < deadline:
                time.sleep(0.005)
            if not pending_path.exists():
                raise AssertionError("Reset race control did not publish its request")
            reset_cancel.set()
            while not (output_dir / "cancel").exists() and time.monotonic() < deadline:
                time.sleep(0.005)
            if not (output_dir / "cancel").exists():
                raise AssertionError("Reset race control did not publish cancellation")
        finally:
            os.kill(native.process.pid, signal.SIGCONT)
            reset_thread.join(timeout=30)
        after_reset_cancel = reset_result.get("observation", {})
        check("reset cancellation after publication preserves native generation and materials",
              not reset_thread.is_alive() and not reset_errors and reset_cancel.is_set()
              and reset_result.get("status") == "cancelled" and reset_result.get("reset_admitted") is False
              and after_reset_cancel.get("retired") is True
              and after_reset_cancel.get("generation") == marked["generation"]
              and after_reset_cancel.get("world_material_sha256") == marked["world_material_sha256"]
              and (output_dir / "cancel").exists(),
              status=reset_result.get("status"), reset_admitted=reset_result.get("reset_admitted"),
              before_generation=marked["generation"], after_generation=after_reset_cancel.get("generation"),
              before_world_sha256=marked["world_material_sha256"],
              after_world_sha256=after_reset_cancel.get("world_material_sha256"), errors=reset_errors)
        recovered = native.reset()
        check("explicit new reset after cancellation creates a fresh native epoch",
              recovered["status"] == "completed" and recovered["reset_admitted"] is True
              and recovered["observation"]["generation"] > marked["generation"]
              and recovered["observation"]["retired"] is False
              and recovered["observation"]["world_material_sha256"] == initial["world_material_sha256"])
        final = native.observe()["observation"]
        check("negative suite retains exact fixture", final["world_material_sha256"] == initial["world_material_sha256"])
    cleanup = json.loads((output_dir / "cleanup.json").read_text())
    check("Godot process and descendants cleaned", cleanup["graceful"] and cleanup["exit_code"] == 0)
    result = {"schema_version": 1, "passed": all(row["passed"] for row in checks),
              "checks": checks, "source_sha": source_sha,
              "development_only": runtime_manifest is None,
              "claim": "actual Workbench Art/native material receipts; no neural inference in this control suite"}
    (output_dir / "native-regressions.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


class NativeEvidenceTests(unittest.TestCase):
    def test_out_of_band_cancel_is_serialized_with_reset_publication(self):
        """A cancellation contending with old-marker removal survives publication."""
        with tempfile.TemporaryDirectory() as tmp:
            native = NativeSession(tmp, "/unused/godot", Path(tmp) / "rpc", "a" * 40)
            native.output.mkdir()
            native.process = SimpleNamespace(poll=lambda: None)
            native.cancel()
            marker = native.output / "cancel"
            attempted, completed = threading.Event(), threading.Event()
            def cancel_at_clear():
                attempted.set()
                native.cancel()
                completed.set()
            contender = threading.Thread(target=cancel_at_clear)
            original_unlink = Path.unlink
            def controlled_unlink(path, *args, **kwargs):
                if path == marker:
                    contender.start()
                    self.assertTrue(attempted.wait(timeout=1))
                    self.assertFalse(completed.wait(timeout=0.05),
                                     "Out-of-band cancellation must wait until reset publication")
                return original_unlink(path, *args, **kwargs)
            with patch.object(Path, "unlink", controlled_unlink), patch.object(native, "_wait_file", return_value={
                    "protocol_version":1, "request_id":1, "status":"cancelled"}):
                native.reset()
            contender.join(timeout=1)
            self.assertFalse(contender.is_alive())
            self.assertTrue(completed.is_set())
            self.assertTrue(marker.exists())
            self.assertTrue((native.output / "request-000001.json").exists())

    def test_reset_rechecks_event_after_clearing_previous_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            native = NativeSession(tmp, "/unused/godot", Path(tmp) / "rpc", "a" * 40)
            native.output.mkdir()
            native.process = SimpleNamespace(poll=lambda: None)
            native.cancel()
            marker = native.output / "cancel"
            cancel = threading.Event()
            original_unlink = Path.unlink
            def cancel_during_clear(path, *args, **kwargs):
                if path == marker:
                    cancel.set()
                return original_unlink(path, *args, **kwargs)
            with patch.object(Path, "unlink", cancel_during_clear), patch.object(native, "_wait_file", return_value={
                    "protocol_version":1, "request_id":1, "status":"cancelled"}):
                native.reset(cancel_event=cancel)
            self.assertTrue(marker.exists(), "A newly cancelled reset must publish with its fence intact")

    def test_godot_harness_indentation_stays_tab_consistent(self):
        root = Path(__file__).resolve().parents[3]
        harness = (root / "godot/tests/run_driv3r_stage_a.gd").read_text(encoding="utf-8")
        leading_spaces = [i for i, line in enumerate(harness.splitlines(), 1)
                          if line.startswith(" ")]
        self.assertEqual(leading_spaces, [], "GDScript mixed indentation causes native parser refusal")
        self.assertIn("func framebuffer()", harness)
        self.assertIn("func bounded_integer(", harness)
        self.assertIn("int(edit[4]) not in [28, 58]", harness)

    def test_unsafe_paths_refused_before_file_read(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(NativeError, "Unsafe native evidence path"):
                verify_observation(Path(tmp), {"width":96, "height":96, "focus":[0,0,96,96],
                                             "allowed_materials":[58], "material_path":"../secret"})

    def test_missing_native_dimensions_refused(self):
        with self.assertRaisesRegex(NativeError, "dimensions"):
            verify_observation(Path("."), {})

    def test_unbounded_deadlines_refused(self):
        for timeout in [0, -1, float("inf"), float("nan"), 111]:
            with self.subTest(timeout=timeout), self.assertRaises(NativeError):
                NativeSession(".", "/does/not/exist", "/does/not/exist", "a" * 40, timeout=timeout)

    def test_short_source_identity_refused(self):
        with self.assertRaises(NativeError):
            NativeSession(".", "/does/not/exist", "/does/not/exist", "short")

    @unittest.skipUnless(os.getenv("DRIV3R_NATIVE_GODOT"), "opt-in real Godot/native suite not requested")
    def test_actual_native(self):
        root = Path(__file__).resolve().parents[3]
        sha = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
        output = os.environ["DRIV3R_NATIVE_OUTPUT"]
        result = run_native_regressions(root, os.environ["DRIV3R_NATIVE_GODOT"], output, sha,
                                        os.environ.get("DRIV3R_NATIVE_MANIFEST"))
        self.assertTrue(result["passed"])


if __name__ == "__main__":
    unittest.main()
