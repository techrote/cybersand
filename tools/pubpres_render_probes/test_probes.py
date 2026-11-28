#!/usr/bin/env python3
"""Focused controls for isolated probe custody, original oracle and ownership."""
from __future__ import annotations
import ast
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
import zipfile
from unittest.mock import patch

import run_probes as probes

ROOT = Path(__file__).resolve().parents[2]
PROJECTS = Path(__file__).with_name("projects")


class ProbeContracts(unittest.TestCase):
    def test_windows_uses_direct_engine_pid_hash_and_verifies_both_archive_members(self):
        # This is archive/identity validation, not a Windows execution claim.
        names = probes.ARCHIVES["windows"][3]
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            data = {names[0]: b"direct pinned engine", names[1]: b"console launcher"}
            archive = directory / "pinned.zip"
            with zipfile.ZipFile(archive, "w") as output:
                for name, content in data.items():
                    output.writestr(name, content)
                    (directory / name).write_bytes(content)
            expected = probes.digest(archive, "sha512")
            probes.write_json(directory / "ENGINE.json", {"version": probes.VERSION, "archive": archive.name,
                "algorithm": "sha512", "digest": expected,
                "files_sha256": {name: probes.sha(content) for name, content in data.items()}})
            with patch.dict(probes.ARCHIVES, {"windows": (archive.name, "sha512", expected, names)}):
                engine = probes.verify_engine(directory / names[0], "windows")
                self.assertEqual(engine["sha256"], probes.sha(data[names[0]]))
                self.assertEqual(engine["executable"], str(directory / names[0]))
                with self.assertRaisesRegex(ValueError, "console launcher"):
                    probes.verify_engine(directory / names[1], "windows")
                (directory / names[1]).write_bytes(b"tampered launcher")
                with self.assertRaisesRegex(ValueError, "Extracted engine"):
                    probes.verify_engine(directory / names[0], "windows")

    def test_finite_platform_matrices_preserve_windows_separate_negatives(self):
        linux, windows = probes.matrix("linux"), probes.matrix("windows")
        self.assertEqual((len(linux), len(windows)), (8, 6))
        for arms in (linux, windows):
            self.assertEqual(len({a["id"] for a in arms}), len(arms))
            material = [a for a in arms if a["project"] == "material"]
            self.assertEqual([(a["thread"], a["slots"]) for a in material],
                             [("safe", 2), ("safe", 3), ("separate", 2), ("separate", 1)])
        self.assertEqual([a["thread"] for a in windows if a["project"] == "font"], ["safe", "separate"])
        self.assertEqual(probes.CHILD_SECONDS, 60)

    def test_frozen_copies_and_manifest_are_exact_a707(self):
        manifest = json.loads((PROJECTS / "material/copied-source-manifest.json").read_text())
        self.assertEqual({m["path"]: m["sha256"] for m in manifest}, probes.FROZEN_INPUTS)
        self.assertTrue(all(m["source_commit"] == probes.FROZEN_SOURCE for m in manifest))
        for name, expected in probes.FROZEN_INPUTS.items():
            self.assertEqual(probes.digest(PROJECTS / "material" / name), expected)
        actual = {p.relative_to(PROJECTS / kind).as_posix() for kind in probes.PROJECT_FILES
                  for p in (PROJECTS / kind).rglob("*") if p.is_file() and ".godot" not in p.parts}
        self.assertFalse(any(name.endswith((".gdextension", ".dll", ".so", ".wasm")) for name in actual))

    def test_first_read_oracle_stays_identical_and_precedes_diagnostics(self):
        original = (PROJECTS / "material/tests/test_material_staging_reachability.gd").read_text()
        diagnostic = (PROJECTS / "material/tests/diagnose_queued_material.gd").read_text()
        start = original.index("\tvar a: Image = owner.current.get_image()")
        end = original.index("\treturn {", start)
        first_oracle = original[start:end]
        self.assertIn(first_oracle, diagnostic)
        self.assertLess(diagnostic.index(first_oracle), diagnostic.index("var immediate_repeat:"))
        # Inheritance keeps the original source-poisoning tape, queue gate and
        # burst byte comparisons; there is no alternative publication loop.
        self.assertTrue(diagnostic.startswith('extends "res://tests/test_material_staging_reachability.gd"'))
        self.assertNotIn("func _queued_history_case(", diagnostic)
        self.assertNotIn("RenderingServer.force_draw", diagnostic)

    def test_archive_pins_match_existing_repository_pins_without_ci_import(self):
        lock = json.loads((ROOT / "third_party/godot-runtime.lock.json").read_text())
        self.assertEqual(probes.ARCHIVES["linux"][2], lock["editor"]["sha256"])
        tree = ast.parse((ROOT / "tools/ci/run_windows_godot_regressions.py").read_text())
        value = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                     and any(isinstance(t, ast.Name) and t.id == "GODOT_SHA512" for t in n.targets))
        self.assertEqual(probes.ARCHIVES["windows"][2], value)

    def test_failed_arm_is_retained_and_all_later_arms_execute(self):
        arms = probes.matrix("windows")
        called = []
        def invoke(arm):
            called.append(arm["id"])
            if len(called) == 2:
                raise ValueError("retained startup failure")
            return {"id": arm["id"], "attempted": True, "passed": len(called) != 3,
                    "errors": ["pixel oracle"] if len(called) == 3 else [], "terminal": None}
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "SUMMARY.json"
            result = probes.run_matrix(arms, invoke, target, {"acceptance": "NONE"})
            self.assertEqual(called, [a["id"] for a in arms])
            self.assertTrue(result["matrix_finished"])
            self.assertTrue(result["all_arms_attempted"])
            self.assertFalse(result["all_passed"])
            self.assertIn("retained startup failure", result["arms"][1]["errors"][0])
            self.assertEqual(json.loads(target.read_text()), result)

    def test_uncertain_ownership_is_terminal_but_remaining_arms_are_recorded(self):
        from process_owner import OwnershipFailure
        called = []
        def invoke(arm):
            called.append(arm["id"])
            raise OwnershipFailure("deliberate uncertain cleanup")
        with tempfile.TemporaryDirectory() as temporary:
            result = probes.run_matrix(probes.matrix("linux"), invoke, Path(temporary) / "summary.json", {})
            self.assertEqual(len(called), 1)
            self.assertEqual(len(result["arms"]), 8)
            self.assertFalse(result["all_arms_attempted"])
            self.assertTrue(all(not a["attempted"] for a in result["arms"][1:]))
            self.assertIn("OwnershipFailure", result["terminal"])

    def font_receipt(self):
        arm = probes.matrix("linux")[0]
        hashes = {name: probes.digest(PROJECTS / "font" / name) for name in probes.PROJECT_FILES["font"]}
        receipt = {"schema": "pubpres-isolated-font-probe-v1", "pid": 123, "source_commit": "a" * 40,
                   "nonce": "n", "engine_sha256": "e" * 64, "engine": {"hash": probes.ENGINE_COMMIT},
                   "platform": "Linux", "display": "X11", "driver": "opengl3", "render_thread_inline": True,
                   "native_independent": True, "loaded_extensions": [], "project_sha256": hashes["project.godot"],
                   "script_sha256": hashes["font_probe.gd"], "mode": "text", "font_mipmaps": False,
                   "requested_thread": "safe", "draws": 64, "glyph_calls": 6016, "errors": [],
                   "framebuffer_size": [1024, 640], "framebuffer_sha256": "b" * 64}
        return arm, hashes, receipt

    def test_success_receipt_requires_pid_source_engine_script_and_no_extension(self):
        arm, hashes, receipt = self.font_receipt()
        def errors(value):
            return probes.receipt_errors(value, {"pid": 123}, arm, "a" * 40, "n", "e" * 64, hashes, "linux")
        self.assertEqual(errors(receipt), [])
        for key, changed in (("pid", 124), ("source_commit", "b" * 40), ("nonce", "other"),
                             ("engine_sha256", "0" * 64), ("script_sha256", "0" * 64),
                             ("loaded_extensions", ["res://bad.gdextension"]), ("display", "headless"),
                             ("render_thread_inline", False), ("draws", 63)):
            with self.subTest(field=key):
                bad = dict(receipt, **{key: changed})
                self.assertTrue(errors(bad))

    def test_later_exact_pixels_cannot_override_first_read_failure(self):
        arm = next(a for a in probes.matrix("linux") if a["project"] == "material")
        hashes = {name: probes.digest(PROJECTS / "material" / name) for name in probes.PROJECT_FILES["material"]}
        _, _, font = self.font_receipt()
        receipt = {**font, "schema": "pubpres-queued-material-diagnostic-v1",
                   "project_sha256": hashes["project.godot"], "checks": 100, "failures": [],
                   "source_files": {"publisher": hashes["scripts/blit_material_publisher.gd"],
                      "shader": hashes["shaders/material_publication_blit.gdshader"],
                      "original_fixture": hashes["tests/test_material_staging_reachability.gd"],
                      "diagnostic": hashes[arm["script"]]},
                   "queued_observations": [{"channels": 1, "slots": 2, "policy": "reachable",
                       "queued_publications": 30, "verified": True, "current_sha256": "wrong",
                       "previous_sha256": "previous", "expected_current_sha256": "correct",
                       "expected_previous_sha256": "previous", "separate": False, "render_gate_completed": False}],
                   "diagnostics": [{"first_current": {"sha256": "wrong"}, "first_previous": {"sha256": "previous"},
                       "later_current_exact": True, "later_previous_exact": True}]}
        errors = probes.receipt_errors(receipt, {"pid": 123}, arm, "a" * 40, "n", "e" * 64, hashes, "linux")
        self.assertIn("Original first-read current/previous byte oracle failed", errors)

    def test_display_cleanup_validates_independently_of_expected_negative_child(self):
        display = {"schema": "pubpres-owned-display-v1", "server_reaped": True,
                   "server_tree_closed": True, "forced_server_kill": False, "unexpected_server_members": False,
                   "server_returncode": -15, "server_alive_before_requested_shutdown": True,
                   "application_timeout": False, "failure": None, "application_returncode": 1, "returncode": 1}
        self.assertTrue(probes.validate_display(display, 1))
        self.assertFalse(probes.validate_display(display, 0))
        for field, value in (("server_reaped", False), ("unexpected_server_members", True),
                             ("forced_server_kill", True), ("server_alive_before_requested_shutdown", False)):
            self.assertFalse(probes.validate_display(dict(display, **{field: value}), 1))

    def invoke_child(self, folder, body, timeout=2):
        request = {"command": [sys.executable, "-c", body], "source_commit": "a" * 40,
                   "nonce": "process-control", "engine_sha256": probes.digest(Path(sys.executable))}
        path = folder / "request.json"
        probes.write_json(path, request)
        with patch.object(probes, "CHILD_SECONDS", timeout):
            code = probes.run_child(path)
        return code, json.loads((folder / "process.json").read_text())

    def test_actual_clean_and_nonzero_children_keep_pid_exit_and_logs(self):
        for expected in (0, 7):
            with self.subTest(code=expected), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                code, receipt = self.invoke_child(folder, "import os,sys;print(os.getpid(),flush=True);sys.exit(" + str(expected) + ")")
                self.assertEqual(code, int(expected != 0))
                self.assertEqual(receipt["returncode"], expected)
                self.assertEqual(int((folder / "stdout.log").read_text().strip()), receipt["pid"])
                self.assertTrue(receipt["cleanup_complete"])
                self.assertFalse(receipt["surviving_children_at_exit"])
                self.assertFalse(receipt["timed_out"])

    def test_timeout_retires_detached_child_before_late_write(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            marker = folder / "late"
            child = "import time,pathlib;time.sleep(1.6);pathlib.Path(" + repr(str(marker)) + ").write_text('bad')"
            detach = ",creationflags=subprocess.CREATE_NEW_PROCESS_GROUP" if os.name == "nt" else ",start_new_session=True"
            body = "import subprocess,sys,time;subprocess.Popen([sys.executable,'-c'," + repr(child) + "]" + detach + ");time.sleep(20)"
            code, receipt = self.invoke_child(folder, body, timeout=1)
            self.assertEqual(code, 1)
            self.assertTrue(receipt["timed_out"])
            self.assertTrue(receipt["cleanup_complete"])
            time.sleep(0.8)
            self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
