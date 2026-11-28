#!/usr/bin/env python3
import copy
import json
import unittest

import run_font_qualification as qualifier


class FontQualificationTests(unittest.TestCase):
    def setUp(self):
        self.process = {"timed_out": False, "surviving_children_at_exit": False, "interruption": None,
                        "observed_application_pid": 42, "wrapper_pid": 42, "exit_code": 0}
        self.build = {"upstream_commit": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88", "build_name": "cybersand_egl_handoff"}
        self.engine = {"major": 4, "minor": 7, "patch": 0, "status": "stable", "hash": self.build["upstream_commit"], "build": self.build["build_name"]}
        self.data = {"schema": "pubpres-isolated-font-probe-v1", "source_commit": "a" * 40, "nonce": "nonce", "pid": 42,
                     "engine_sha256": "b" * 64, "engine": self.engine, "script_sha256": qualifier.FONT_HASHES["font_probe.gd"],
                     "project_sha256": qualifier.FONT_HASHES["project.godot"], "native_independent": True, "loaded_extensions": [],
                     "mode": "text", "font_mipmaps": False, "errors": [], "draws": 64, "glyph_calls": 6016,
                     "framebuffer_size": [1024, 640], "framebuffer_sha256": "c" * 64, "platform": "Windows", "display": "Windows",
                     "driver": "opengl3_angle", "adapter": "actual synthetic adapter for gate test", "requested_thread": "safe", "render_thread_inline": True}

    def validate(self, data=None, process=None):
        qualifier.validate_font(data or self.data, process or self.process, source="a" * 40, nonce="nonce", thread="safe",
                                build=self.build, engine_sha="b" * 64)

    def test_actual_font_work_engine_process_owner_and_graphical_admission(self):
        self.validate()
        for key, value in (("draws", 63), ("glyph_calls", 6015), ("font_mipmaps", True), ("render_thread_inline", False),
                           ("loaded_extensions", ["native"]), ("pid", 99), ("engine_sha256", "d" * 64), ("display", "headless")):
            data = copy.deepcopy(self.data)
            data[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): self.validate(data=data)

    def test_only_exact_initialized_cowdata_crash_is_admitted_as_negative(self):
        process = {**self.process, "exit_code": -2147483645}
        started = "ISOLATED_FONT_PROBE_SCRIPT_STARTED " + json.dumps({"pid": 42, "engine": self.engine}) + "\n"
        crash = "ERROR: Index p_index = 0 is out of bounds (size() = 0).\n at: CowData<unsigned char>::get (core/templates/cowdata.h:197)\n"
        qualifier.validate_retained_cowdata_negative(process, started + crash, receipt_exists=False, build=self.build)
        for text, exists in ((crash, False), (started + "Error initializing GLAD", False), (started + crash, True),
                             (started + crash.replace("p_index = 0", "p_index = 1"), False), (started + crash + "SCRIPT ERROR:", False),
                             (started + crash + "ERROR: unrelated native failure\n", False),
                             (started + crash + "FATAL: another problem\n", False)):
            with self.subTest(text=text), self.assertRaises(ValueError):
                qualifier.validate_retained_cowdata_negative(process, text, receipt_exists=exists, build=self.build)
        with self.assertRaises(ValueError):
            qualifier.validate_retained_cowdata_negative({**process, "timed_out": True}, started + crash, receipt_exists=False, build=self.build)

    def test_process_record_cannot_move_between_sources_engines_owners_or_scripts(self):
        expected = {"source": "a" * 40, "engine": "C:\\payload\\bin\\godot.windows.editor.x86_64.exe",
                    "project": "C:\\evidence\\font-projects\\original-separate", "thread": "separate", "script": "res://font_probe.gd"}
        process = {**self.process, "source_commit": expected["source"], "command": qualifier.graphical_command(
            expected["engine"], expected["project"], expected["thread"], expected["script"])}
        qualifier.validate_process_command(process, **expected)
        for field, value in (("source", "d" * 40), ("engine", "C:\\other\\godot.exe"), ("thread", "safe"),
                             ("project", "C:\\other-project"), ("script", "res://" + qualifier.OBSERVER)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                qualifier.validate_process_command(process, **{**expected, field: value})
        altered = copy.deepcopy(process)
        altered["command"][altered["command"].index("opengl3_angle")] = "opengl3"
        with self.assertRaises(ValueError): qualifier.validate_process_command(altered, **expected)

    def arms(self, old_pass=False):
        return [{"engine": role, "render_thread": thread, "passed": old_pass or (role, thread) != ("original", "separate"),
                 "admissible_negative": not old_pass and (role, thread) == ("original", "separate"), "receipt": copy.deepcopy(self.data)}
                for role, thread in (("original", "safe"), ("original", "separate"), ("repaired", "safe"), ("repaired", "separate"))]

    def test_retained_failure_is_not_relabelled_as_all_arms_pass(self):
        result = qualifier.validate_font_cohort(self.arms())
        self.assertTrue(result["passed"])
        self.assertTrue(result["retained_negative_observed"])
        self.assertFalse(result["all_font_arms_passed"])
        self.assertTrue(qualifier.validate_font_cohort(self.arms(old_pass=True))["all_font_arms_passed"])

    def test_any_repaired_pixel_adapter_failure_or_missing_control_fails_gate(self):
        for key, value in (("framebuffer_sha256", "d" * 64), ("adapter", "another adapter")):
            arms = self.arms()
            arms[3]["receipt"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): qualifier.validate_font_cohort(arms)
        arms = self.arms()
        arms[3]["passed"] = False
        arms[3]["admissible_negative"] = True
        with self.assertRaises(ValueError): qualifier.validate_font_cohort(arms)
        with self.assertRaises(ValueError): qualifier.validate_font_cohort(self.arms()[:-1])
        arms = self.arms()
        arms[1]["admissible_negative"] = False
        with self.assertRaises(ValueError): qualifier.validate_font_cohort(arms)

    def test_registration_has_no_skip_startup_or_font_work_relaxation(self):
        value = qualifier.registration()
        self.assertEqual(value["startup_order"], ["safe", "separate"])
        self.assertEqual(value["startup_scene"], "wave512")
        self.assertEqual(value["draws"] * 94, value["glyph_calls"])

    def test_new_candidate_startup_requires_actual_material_deadline_off(self):
        status = {"schema": "pubpres-material-deadline-v1", "requested_hz": 0, "interval_usec": 0,
                  "enabled": False, "pending_count": 0, "accepted_uploads": 0, "physical_credit": False}
        qualifier.validate_deadline_off(status)
        for changed in (None, {}, {**status, "requested_hz": 30}, {**status, "enabled": True},
                        {**status, "pending_count": 1}, {**status, "accepted_uploads": 1}, {**status, "enabled": 0}):
            with self.subTest(value=changed), self.assertRaises(ValueError): qualifier.validate_deadline_off(changed)


if __name__ == "__main__":
    unittest.main()
