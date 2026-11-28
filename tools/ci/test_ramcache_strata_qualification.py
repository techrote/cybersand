#!/usr/bin/env python3
"""Adverse controls for integrated source, evidence and portable delivery readers."""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from types import SimpleNamespace
import zipfile

import ramcache_strata_qualification as q
import package_ramcache_strata as package
from test_strata3_cold_launcher import execution


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def process_fixture(platform="linux", label="cache-off-write"):
    engine = r"D:\bundle\Godot_console.exe" if platform == "win32" else "/bundle/Godot"
    project = r"D:\bundle\godot" if platform == "win32" else "/bundle/godot"
    output = r"D:\evidence" if platform == "win32" else "/evidence"
    join = q.ntpath.join if platform == "win32" else q.posixpath.join
    data = join(output, "cache-off-data")
    report = {"godot": {"path": engine, "version": q.custody.windows.GODOT_VERSION},
              "platform": platform, "project": {"path": project}, "output_root": output}
    command = [engine, "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
               "--rendering-driver", "opengl3", "--path", project,
               "--script", "res://tests/test_persistent_areas_workbench.gd", "--",
               "--persistent-profile=" + join(data, "profile"), "--persistent-evidence=" + data,
               "--persistent-test-mode=write", "--persistent-test-workers=1", "--persistent-start-paused",
               "--persistent-require-graphics", "--persistent-cache-off"]
    original = {"command": command, "status": "passed", "exit_code": 0, "timeout_seconds": 420,
                "seconds": 60.5, "pid": 1234}
    row = dict(original, label=label)
    text = "Godot Engine v" + report["godot"]["version"] + " - https://godotengine.org\n"
    return report, row, original, text


class IntegrationControls(unittest.TestCase):
    def reject(self, call):
        with self.assertRaises((RuntimeError, ValueError, KeyError, TypeError)):
            call()

    def test_request_cannot_widen_acceptance_or_ancestry(self):
        original = q.read(q.ROOT / q.REQUEST)
        q.validate_request(original)
        for key, value in [("classic_remains_default", False), ("sequence", True),
                           ("optional_optics_90_percent_gate", "benchmark-passed"),
                           *[(key, "0" * 40) for key in q.ANCHORS], ("unregistered", True)]:
            with self.subTest(key=key):
                changed = dict(original, **{key: value})
                self.reject(lambda: q.validate_request(changed))

    def test_explicit_text_newline_contract(self):
        working = b"param(\r\n  [string]$Manifest\r\n)\r\n"
        committed = b"param(\n  [string]$Manifest\n)\n"
        self.assertEqual(q.normalized_text(working), committed)
        self.assertEqual(q.normalized_text(committed), committed)
        self.assertNotEqual(q.normalized_text(working + b"changed\r\n"), committed)

    def test_original_markers_require_unique_positive_checks_and_zero_failures(self):
        for value in ({"checks": 10, "failures": []}, {"assertions": 3, "failures": 0},
                      {"checks": 4, "failures": [], "completed": True}):
            q.validate_marker("DONE " + json.dumps(value), "DONE ")
        q.validate_marker("DONE 27 checks, 0 failures", "DONE ")
        for text in ("", 'DONE {"checks":0,"failures":[]}', 'DONE {"checks":2,"failures":["lost"]}',
                     'DONE {"checks":2,"failures":1}', 'DONE {"checks":2,"failures":[],"completed":false}',
                     'DONE {"checks":2,"failures":[]}\nDONE {"checks":2,"failures":[]}',
                     "DONE 1 checks, 2 failures"):
            self.reject(lambda: q.validate_marker(text, "DONE "))

    def test_exact_cross_host_successful_cache_disabled_command(self):
        for platform in ("linux", "win32"):
            with self.subTest(platform=platform):
                q.validate_process(*process_fixture(platform))
                for mutation in ("headless", "wrong-script", "cache-enabled", "wrong-engine", "wrong-profile"):
                    values = list(copy.deepcopy(process_fixture(platform)))
                    command = values[1]["command"]
                    if mutation == "headless":
                        command.insert(1, "--headless")
                    elif mutation == "wrong-script":
                        command[command.index("--script") + 1] = "res://tests/unrelated.gd"
                    elif mutation == "cache-enabled":
                        command.remove("--persistent-cache-off")
                    elif mutation == "wrong-engine":
                        command[0] = "another-engine"
                    else:
                        command[-7] = "--persistent-profile=another-profile"
                    self.reject(lambda: q.validate_process(*values))

    def test_reciprocal_mechanics_and_actual_input_keep_distinct_donor_contexts(self):
        for platform in ("linux", "win32"):
            for label, deadline in (("test_workbench_reciprocal_controller", 90), ("swarm006_reciprocal_input", 180)):
                with self.subTest(platform=platform, label=label):
                    report, row, original, text = process_fixture(platform)
                    base = [report["godot"]["path"], "--audio-driver", "Dummy", "--path", report["project"]["path"]]
                    if label == "test_workbench_reciprocal_controller":
                        base += ["--headless"]
                    else:
                        base += ["--rendering-method", "gl_compatibility", "--max-fps", "60"]
                        base += ["--rendering-driver", "opengl3_angle"] if platform == "win32" else ["--display-driver", "x11"]
                    self.assertEqual(q.process_base(report["godot"]["path"], report["project"]["path"], platform, label), base)
                    command = base + ["--script", "res://tests/" + label + ".gd"]
                    row.update(label=label, command=command, timeout_seconds=deadline)
                    original.update(command=command, timeout_seconds=deadline)
                    q.validate_process(report, row, original, text)
                    for mutation in ("display-context", "deadline", "wrong-script"):
                        changed_row, changed_original = copy.deepcopy((row, original))
                        if mutation == "display-context":
                            if label == "test_workbench_reciprocal_controller":
                                changed_row["command"].remove("--headless")
                            else:
                                changed_row["command"].insert(1, "--headless")
                        elif mutation == "deadline":
                            changed_row["timeout_seconds"] = 300
                        else:
                            changed_row["command"][-1] = "res://tests/unrelated.gd"
                        changed_original.update({key: value for key, value in changed_row.items() if key != "label"})
                        self.reject(lambda: q.validate_process(report, changed_row, changed_original, text))
                    if label == "swarm006_reciprocal_input":
                        for flag in ("--max-fps", "--rendering-driver" if platform == "win32" else "--display-driver"):
                            changed_row, changed_original = copy.deepcopy((row, original))
                            changed_row["command"][changed_row["command"].index(flag) + 1] = "wrong"
                            changed_original["command"] = changed_row["command"]
                            self.reject(lambda: q.validate_process(report, changed_row, changed_original, text))

    def test_original_preference_terminal_matches_its_summary_fields(self):
        summary = {"checks": 128, "failures": [], "scene": "owner-diorama-depth-1-3", "phase": "install"}
        result = dict(summary, schema="ramcache-strata-owner-preference-v1", completed=True,
                      native_edit_witnesses=[{"plane": "play"}], process_id=125)
        text = "STRATA_WORKBENCH " + json.dumps(summary)
        q.validate_preference_completion(result, text)
        for key, value in (("checks", 1), ("scene", "unrelated"), ("phase", "reopen"), ("failures", ["error"])):
            altered = dict(result, **{key: value})
            self.reject(lambda: q.validate_preference_completion(altered, text))

    def test_exact_process_deadline_original_record_and_log_identity(self):
        for key, value in (("timeout_seconds", 900), ("seconds", float("nan")), ("seconds", 500),
                           ("seconds", -1), ("exit_code", 1), ("status", "timeout"),
                           ("cleanup_error", "owned child remains")):
            values = list(copy.deepcopy(process_fixture()))
            values[1][key] = values[2][key] = value
            self.reject(lambda: q.validate_process(*values))
        values = list(copy.deepcopy(process_fixture()))
        values[1]["pid"] = 4321
        self.reject(lambda: q.validate_process(*values))
        for replacement in ("", "Godot Engine v4.6 - https://godotengine.org\n", "SCRIPT ERROR: bad\n"):
            values = list(copy.deepcopy(process_fixture()))
            values[3] = replacement
            self.reject(lambda: q.validate_process(*values))
        values = list(process_fixture())
        values[3] += "ERROR: hidden native failure\n"
        self.reject(lambda: q.validate_process(*values))

    def test_loaded_source_and_portable_generator_custody(self):
        for platform in ("windows", "linux"):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                (root / "godot/tools").mkdir(parents=True)
                cli = "tools/gentek_reciprocal" + (".exe" if platform == "windows" else "")
                host = "tools/swarm004-runtime." + platform + ".json"
                other = "tools/swarm004-runtime." + ("linux" if platform == "windows" else "windows") + ".json"
                binding = {"platform": platform, "artifact": "godot/" + cli, "sha256": "d" * 64}
                raw = json.dumps(binding).encode()
                (root / "godot" / host).write_bytes(raw)
                source = {"source_inputs_sha256": {"godot/main.gd": "a" * 64, "godot/" + host: digest(raw),
                          "godot/" + other: "b" * 64}, "source_assets_sha256": {"godot/art/pixel.png": "c" * 64}}
                runtime = {"cybersand_runtime": {"path": "godot/addons/native." + ("dll" if platform == "windows" else "so"),
                           "sha256": "e" * 64}, "rapier_runtime": {"path": "godot/addons/rapier", "sha256": "f" * 64}}
                inputs = {name.removeprefix("godot/"): value for name, value in source["source_inputs_sha256"].items()}
                inputs.update({value["path"].removeprefix("godot/"): value["sha256"] for value in runtime.values()})
                report = {"runtime": runtime, "project": {"inputs_sha256": inputs, "assets_sha256": {"art/pixel.png": "c" * 64}}}
                with mock.patch.object(q.optics, "ROOT", root):
                    q.validate_project_record(report, source)
                    del inputs[other]
                    self.reject(lambda: q.validate_project_record(report, source))
                    inputs[cli] = "d" * 64
                    q.validate_project_record(report, source)
                    for key in (host, "main.gd", cli):
                        changed = copy.deepcopy(report)
                        changed["project"]["inputs_sha256"].pop(key)
                        self.reject(lambda: q.validate_project_record(changed, source))
                    changed = copy.deepcopy(report)
                    changed["project"]["inputs_sha256"][cli] = "0" * 64
                    self.reject(lambda: q.validate_project_record(changed, source))
                    changed = copy.deepcopy(report)
                    changed["project"]["assets_sha256"]["art/pixel.png"] = "0" * 64
                    self.reject(lambda: q.validate_project_record(changed, source))

    def test_backend_userdata_cannot_be_inside_any_source_repository(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            project = root / "copied-source/godot"
            q.require_external_output(root / "evidence", project)
            self.reject(lambda: q.require_external_output(project / "evidence", project))
            self.reject(lambda: q.require_external_output(project.parent / "userdata", project))
            self.reject(lambda: q.require_external_output(q.ROOT / "build/evidence", project))

    def test_registered_lab_command_retains_donor_capture_and_deadline(self):
        for platform in ("linux", "win32"):
            values = list(process_fixture(platform))
            report, row, original, text = values
            command = row["command"][:row["command"].index("--script")]
            command += ["--max-fps", "1", "--script", "res://tests/test_material_lab_workbench_integration.gd"]
            row.update(label="material-lab-author", command=command, timeout_seconds=1800)
            original.update(command=command, timeout_seconds=1800)
            q.validate_process(*values)
            for mutation in ("headless", "fps", "deadline", "script"):
                changed = copy.deepcopy(values)
                if mutation == "headless":
                    changed[1]["command"].insert(1, "--headless")
                elif mutation == "fps":
                    changed[1]["command"][changed[1]["command"].index("--max-fps") + 1] = "60"
                elif mutation == "deadline":
                    changed[1]["timeout_seconds"] = changed[2]["timeout_seconds"] = 3600
                else:
                    changed[1]["command"][-1] = "res://tests/unrelated.gd"
                self.reject(lambda: q.validate_process(*changed))
        self.assertEqual(q.expected_labels("lab"), {"import", *q.LAB_LABELS})
        self.assertTrue(set(q.LAB_LABELS) <= q.expected_labels("shared"))
        self.assertNotIn("lab", q.MODES)

    def test_original_lab_native_comparison_and_fresh_reopen_are_required(self):
        import mat_workbench_runtime_publication as original_lab
        world = {"schema_id": "cybersand.material-lab.world-receipt", "runtime_active": False,
                 "candidate": {"world_simulation": True, "descriptor_readback": {"density": 500},
                               "final": {"target_below_reservoir": 1}},
                 "reference": {"final": {"target_below_reservoir": 2}}}
        for backend in ("reference", "candidate"):
            world[backend]["checks"] = {key: True for key in ("deterministic_repeat", "worker_1_4_equal",
                "persistence_checkpoint", "persistence_replay", "quantity_balanced")}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report = {"runtime": {"cybersand_runtime": {"sha256": "a" * 64}}, "platform": "win32"}
            rows = {"material-lab-author": {"pid": 100}, "material-lab-reopen": {"pid": 101}}
            originals = {}
            for phase in ("author", "reopen"):
                receipt = {"checks": 97, "failures": 0, "errors": [], "complete": True, "workers": 1,
                    "phase": phase, "native_material_witnesses": [{"sha256": "d" * 64}],
                    "candidate_world_receipt": copy.deepcopy(world) if phase == "author" else {}}
                originals[phase] = receipt
                location = root / ("material-lab-" + phase)
                location.mkdir()
                (location / "process.log").write_text("MAT_WB_EVIDENCE " + json.dumps(receipt) +
                    "\nMAT_WB_INTEGRATION checks=97 failures=0 complete=true\n")
            with mock.patch.object(original_lab, "verify_combined_case", side_effect=lambda *a, **kw: originals[a[4]]):
                q.validate_lab_pair(root, report, rows)
                for backend, gate in (("candidate", "persistence_replay"), ("reference", "worker_1_4_equal")):
                    originals["author"]["candidate_world_receipt"][backend]["checks"][gate] = False
                    self.reject(lambda: q.validate_lab_pair(root, report, rows))
                    originals["author"]["candidate_world_receipt"][backend]["checks"][gate] = True
                rows["material-lab-reopen"]["pid"] = 100
                self.reject(lambda: q.validate_lab_pair(root, report, rows))

    def test_shipped_launcher_uses_only_portable_tools_and_external_userdata(self):
        text = package.launcher_text({"source_commit": "a" * 40})
        self.assertEqual(text.count('%~dp0source\\godot"'), 2)
        self.assertNotIn('%PATH%', text)
        self.assertNotIn('Program Files', text)
        self.assertIn('set "PYTHONPATH="', text)
        self.assertIn('set "GIT_CONFIG_GLOBAL=NUL"', text)
        self.assertIn('set "CYBERSAND_LAB_CXX=%~dp0dependencies\\cxx\\bin\\g++.exe"', text)
        self.assertIn('set "APPDATA=%~dp0userdata\\roaming"', text)
        with mock.patch.object(package.base, "launcher_text", return_value=text.replace("--editor --quit", "--quit")):
            self.reject(lambda: package.launcher_text({"source_commit": "a" * 40}))

    def test_actual_compilation_must_use_the_shipped_compiler_and_source(self):
        root, source = r"D:\Extracted Copy", "a" * 40
        dependencies = {"tools": {"compiler": {"path": "cxx/bin/g++.exe", "version": "g++.exe 14.2\nnotice"}}}
        command = [r"D:\Extracted Copy\dependencies\cxx\bin\g++.exe", "-std=c++20"]
        receipt = {"compiler": "g++.exe", "compiler_version": "g++.exe 14.2",
                   "source_identity": {"git_head": source, "digest": "b" * 64, "lf_sha256": {"native/test.cpp": "c" * 64}},
                   "source_identity_after": "b" * 64}
        for name in ("reference_build", "candidate_build"):
            receipt[name] = {"argv": list(command), "native_executable_sha256": "d" * 64}
        package.validate_portable_compiler(receipt, root, dependencies, source, receipt["source_identity"])
        for mutation in ("developer-tool", "wrong-version", "wrong-source", "changed-source", "wrong-input-map"):
            changed = copy.deepcopy(receipt)
            if mutation == "developer-tool":
                changed["candidate_build"]["argv"][0] = r"C:\mingw64\bin\g++.exe"
            elif mutation == "wrong-version":
                changed["compiler_version"] = "unshipped compiler"
            elif mutation == "wrong-source":
                changed["source_identity"]["git_head"] = "f" * 40
            elif mutation == "wrong-input-map":
                changed["source_identity"]["lf_sha256"] = {"unrelated.cpp": "c" * 64}
            else:
                changed["source_identity_after"] = "0" * 64
            self.reject(lambda: package.validate_portable_compiler(changed, root, dependencies, source, receipt["source_identity"]))

    def archive(self, root, extra="assets/file.txt", corrupt=False):
        files = {"Open Workbench.cmd": b"launcher", "godot/project.godot": b"project", extra: b"payload"}
        manifest = {"files_sha256": {name: digest(data) for name, data in files.items()}}
        if corrupt:
            manifest["files_sha256"][extra] = "0" * 64
        files[package.MANIFEST] = json.dumps(manifest).encode()
        path = root / "evaluator.zip"
        with zipfile.ZipFile(path, "w") as bundle:
            for name, data in files.items():
                bundle.writestr(name, data)
        return path

    def test_actual_archive_payload_custody_and_hostile_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = self.archive(root)
            self.assertEqual(len(package.inspect_archive(path)), 4)
            self.reject(lambda: package.inspect_archive(self.archive(root, corrupt=True)))
            for name in ("../outside", "C:/outside", "assets\\outside", "assets/CON.txt", "assets/trailing.",
                         "godot/.godot/old.bin", "userdata/old-save.json", "OPEN WORKBENCH.CMD"):
                with self.subTest(name=name):
                    path = self.archive(root, name)
                    self.reject(lambda: package.inspect_archive(path))

    def test_archive_accepts_only_exact_committed_bootstrap_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in package.SOURCE_BOOTSTRAP_FILES:
                archive = self.archive(root, name)
                with mock.patch.object(q.custody, "git", return_value=b"payload"):
                    package.inspect_archive(archive)
                with mock.patch.object(q.custody, "git", return_value=b"different committed bootstrap"):
                    self.reject(lambda: package.inspect_archive(archive))
            for name in ("source/godot/.godot/editor/old.cfg", "source/godot/.godot/imported/old.ctex",
                         "source/godot/.godot/script-classes.cfg"):
                self.reject(lambda: package.inspect_archive(self.archive(root, name)))

    def test_archive_refuses_dependency_cache_and_identifies_original_member(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in (
                "dependencies/cxx/opt/lib/python3.12/__pycache__/_weakrefset.cpython-312.pyc",
                "dependencies/git/ucrt64/share/tool/__pycache__/module.cpython-312.pyc",
                "dependencies/python/Lib/json/__pycache__/decoder.cpython-312.pyc",
                "dependencies/cxx/userdata/prior-profile.json",
                "dependencies/cxx/.godot/prior-import.bin",
            ):
                with self.subTest(name=name):
                    # A complete, internally consistent payload manifest cannot
                    # authorize generated state inherited from an offline tool.
                    with self.assertRaises(RuntimeError) as refused:
                        package.inspect_archive(self.archive(root, name))
                    self.assertEqual(str(refused.exception),
                        "Shipped package contains prior generated state or an altered committed bootstrap: " + name)

    def launcher(self):
        values = list(execution())
        source = "1" * 40
        values[3] = values[3].replace(package.cold.APPLICATION, source)
        return values, source

    def test_actual_ordered_cmd_is_bound_to_new_application_without_rewriting_history(self):
        values, source = self.launcher()
        result = package.validate_launcher_execution(*values, source)
        self.assertEqual(result["engine_process_ids"], [12, 14])
        self.assertEqual(result["admission"]["source_revision"], source)
        self.assertNotEqual(package.cold.APPLICATION, source)
        self.reject(lambda: package.validate_launcher_execution(*values, "2" * 40))
        for field, replacement in (("command", "fake.exe --workbench"), ("timed_out", True),
                                   ("timeout_seconds", 600), ("exit_code", 1)):
            bad = copy.deepcopy(values)
            bad[0][field] = replacement
            self.reject(lambda: package.validate_launcher_execution(*bad, source))

    def test_shortcut_and_f2_share_default_profile_and_import_contract(self):
        source = {"source_commit": "1" * 40}
        ordinary = package.launcher_text(source)
        shortcut = package.persistent_launcher(source)
        self.assertEqual(shortcut.replace("-- --persistent-areas\n", "-- --workbench\n"), ordinary)
        self.assertIn('set "APPDATA=%~dp0userdata\\roaming"', shortcut)
        self.assertNotIn("--persistent-profile", shortcut)
        for altered in (ordinary.replace("-- --workbench\n", "-- --other\n"), ordinary * 2):
            with mock.patch.object(package, "launcher_text", return_value=altered):
                self.reject(lambda: package.persistent_launcher(source))

    def persistent_launch(self):
        values, source = self.launcher()
        process = values[0]
        process["command"] = package.cold.command_line(process["executable"], process["cwd"], persistent=True)
        values[3] = values[3].split("STRATA_WORKBENCH_LAUNCH_ADMITTED ")[0] + "PERSISTENT_AREAS_READY " + json.dumps(
            {"session": "a" * 32, "area": "a", "revision": 2}) + "\n"
        ready = package.cold.persistent_readiness(values[3])
        engine = values[1]["rows"][-1]
        process["persistent_close"] = {"schema": "ramcache-strata-persistent-close-v1",
            "readiness": ready["value"], "readiness_line_sha256": ready["line_sha256"],
            "ready_observed_unix_seconds": process["started_unix_seconds"] + 50,
            "posted_unix_seconds": process["started_unix_seconds"] + 51,
            "message": "WM_CLOSE", "message_id": 0x0010, "hwnd": 4242,
            "pid": engine["pid"], "start_id": engine["start_id"], "image_path": engine["image_path"],
            "window_owner_pid": engine["pid"], "visible": True, "posted": True}
        return values, source

    def test_persistent_close_requires_readiness_exact_window_owner_and_live_time(self):
        values, source = self.persistent_launch()
        package.validate_launcher_execution(*values, source, persistent=True)
        self.assertNotIn("--quit-after", values[0]["command"])
        for key, replacement in (("pid", 12), ("start_id", 1), ("window_owner_pid", 999),
                ("hwnd", 0), ("visible", False), ("posted", False), ("message_id", 0x0012),
                ("image_path", r"C:\unrelated\Godot.exe"), ("readiness_line_sha256", "0" * 64),
                ("readiness", {"session": "a" * 32, "area": "b", "revision": 2}),
                ("ready_observed_unix_seconds", values[0]["started_unix_seconds"]),
                ("posted_unix_seconds", values[0]["started_unix_seconds"] + 110)):
            changed = copy.deepcopy(values)
            changed[0]["persistent_close"][key] = replacement
            self.reject(lambda: package.validate_launcher_execution(*changed, source, persistent=True))
        values[0].pop("persistent_close")
        self.reject(lambda: package.validate_launcher_execution(*values, source, persistent=True))

    def test_persistent_readiness_waits_for_complete_unique_native_marker(self):
        good = 'PERSISTENT_AREAS_READY ' + json.dumps({"session": "a" * 32, "area": "a", "revision": 1})
        self.assertIsNone(package.cold.persistent_readiness(good))
        self.assertIsNone(package.cold.persistent_readiness("ordinary unrelated output\n"))
        self.assertEqual(package.cold.persistent_readiness(good + "\n")["value"]["revision"], 1)
        for text in (good + "\n" + good + "\n", 'PERSISTENT_AREAS_READY {}\n',
                     good.replace('"revision": 1', '"revision": 0') + "\n"):
            self.reject(lambda: package.cold.persistent_readiness(text))

    def test_win32_close_only_posts_to_the_held_packaged_engine(self):
        values, _source = self.persistent_launch()
        engine = dict(values[1]["rows"][-1], exited=False)
        ready = package.cold.persistent_readiness(values[3])
        def owner(_hwnd, pointer):
            pointer._obj.value = engine["pid"]
            return 1
        user = SimpleNamespace(GetWindowThreadProcessId=mock.Mock(side_effect=owner),
            IsWindowVisible=mock.Mock(return_value=True), PostMessageW=mock.Mock(return_value=True),
            EnumWindows=mock.Mock(side_effect=lambda callback, argument: callback(4242, argument)))
        reader = SimpleNamespace(final_rows=mock.Mock(return_value=[engine]))
        with mock.patch.object(package.cold.ctypes, "WinDLL", create=True, return_value=user), \
             mock.patch.object(package.cold.ctypes, "WINFUNCTYPE", create=True, return_value=lambda fn: fn):
            result = package.cold.close_persistent_window(values[0]["cwd"], reader, ready, 1800000050.0)
            self.assertEqual(result["pid"], engine["pid"])
            user.PostMessageW.assert_called_once_with(4242, 0x0010, 0, 0)
            user.PostMessageW.reset_mock()
            reader.final_rows.side_effect = [[engine], []]
            self.reject(lambda: package.cold.close_persistent_window(values[0]["cwd"], reader, ready, 1800000050.0))
            user.PostMessageW.assert_not_called()
            reader.final_rows.side_effect = None
            reader.final_rows.return_value = [dict(engine, image_path=r"C:\unrelated\Godot.exe")]
            self.assertIsNone(package.cold.close_persistent_window(values[0]["cwd"], reader, ready, 1800000050.0))
            user.PostMessageW.assert_not_called()

    def test_persistent_cmd_readiness_and_original_observation_hashes(self):
        values, source = self.persistent_launch()
        package.validate_launcher_execution(*values, source, persistent=True)
        self.reject(lambda: package.validate_launcher_execution(*values, source))
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "process.log").write_text(values[3])
            for name, record in (("resources.json", values[2]), ("lifetimes.json", values[1])):
                (root / name).write_text(json.dumps(record))
            for name, key in (("process.log", "log_sha256"), ("resources.json", "resources_sha256"),
                              ("lifetimes.json", "lifetimes_sha256")):
                values[0][key] = package.sha(root / name)
            (root / "process.json").write_text(json.dumps(values[0]))
            package.read_launcher_evidence(root, source, persistent=True)
            for name in ("process.log", "resources.json", "lifetimes.json"):
                original = (root / name).read_bytes()
                (root / name).write_bytes(original + b" ")
                self.reject(lambda: package.read_launcher_evidence(root, source, persistent=True))
                (root / name).write_bytes(original)

    def test_persistent_three_area_manifest_and_native_container_hashes(self):
        def wrap(magic, metadata, native=b""):
            return magic + b"\0" + struct.pack("<III", 1, len(metadata), len(native)) + hashlib.sha256(metadata + native).digest() + metadata + native
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            areas = {}
            for area in ("a", "b", "c"):
                filename = "area-" + area + "-" + "b" * 32 + ".cypa"
                native = b"CYPS" + area.encode() * 64
                data = wrap(b"CYSAREA", b"retained-authoring-envelope", native)
                (root / filename).write_bytes(data)
                areas[area] = {"area_id": area, "extent": [512, 512], "blob": filename,
                               "sha256": digest(data), "native_sha256": digest(native)}
            manifest = {"version": 1, "areas": areas, "active_area": "a", "revision": 2,
                        "session_id": "a" * 32, "profile_id": "gen006-three-areas-v1",
                        "compatibility": "gen006-current-freemass-512-cyps2-v1:" + "f" * 64}
            (root / "current.cypm").write_bytes(wrap(b"CYSPROF", json.dumps(manifest).encode()))
            self.assertEqual(package.read_persistent_profile(root, "f" * 64)["session_id"], "a" * 32)
            self.reject(lambda: package.read_persistent_profile(root, "e" * 64))
            altered = dict(manifest, profile_id="unrelated-profile")
            (root / "current.cypm").write_bytes(wrap(b"CYSPROF", json.dumps(altered).encode()))
            self.reject(lambda: package.read_persistent_profile(root, "f" * 64))
            (root / "current.cypm").write_bytes(wrap(b"CYSPROF", json.dumps(manifest).encode()))
            path = root / areas["c"]["blob"]
            path.write_bytes(path.read_bytes()[:-1] + b"!")
            self.reject(lambda: package.read_persistent_profile(root, "f" * 64))

    def test_cmd_cannot_hide_missing_live_wrong_engine_or_unbounded_child(self):
        for change in ("missing", "live", "wrong-engine", "wrong-parent", "unbounded", "log-error"):
            values, source = self.launcher()
            if change == "missing":
                values[1]["rows"].pop()
            elif change == "live":
                values[1]["rows"][-1]["exited"] = False
            elif change == "wrong-engine":
                values[1]["rows"][-1]["image_path"] = r"C:\Other\Godot.exe"
            elif change == "wrong-parent":
                values[1]["rows"][-1]["parent_pid"] = 999
            elif change == "unbounded":
                values[1]["rows"][0]["exit_filetime_100ns"] += 2000000000
                values[1]["rows"][0]["lifetime_seconds"] += 200
            else:
                values[3] += "SCRIPT ERROR: actual launch failed\n"
            self.reject(lambda: package.validate_launcher_execution(*values, source))


class WindowsVerifierControls(unittest.TestCase):
    def test_windows_powershell_environment_removes_only_module_path(self):
        original = {"PSModulePath": "ps7 first", "PSMODULEPATH": "uppercase", "psmodulepath": "lowercase",
                    "PATH": "actual portable tools", "JAVA_HOME": "", "PSModulePathExtra": "retain this",
                    "SystemRoot": r"C:\Windows"}
        before = dict(original)
        actual = package.windows_powershell_environment(original)
        self.assertEqual(actual, {"PATH": "actual portable tools", "JAVA_HOME": "", "PSModulePathExtra": "retain this",
                                  "SystemRoot": r"C:\Windows"})
        self.assertEqual(original, before)
        self.assertIsNot(actual, original)
        self.assertEqual(package.windows_powershell_environment(actual), actual)

    @unittest.skipUnless(sys.platform == "win32", "Requires actual Windows PowerShell module discovery")
    def test_actual_windows_powershell_child_hashes_and_resolves_observer_commands(self):
        with tempfile.TemporaryDirectory(prefix="ramcache-strata-module-env ") as directory:
            root = Path(directory)
            contents = {"empty.bin": b"", "abc.bin": b"abc", "multiblock.bin": bytes(range(256)) * 8192}
            for name, value in contents.items():
                (root / name).write_bytes(value)
            script = root / "observer command probe.ps1"
            script.write_text(r'''param([string]$Root)
$ErrorActionPreference = 'Stop'
$commands = [ordered]@{}
foreach ($name in @('Get-FileHash', 'Get-Process', 'Start-Process', 'Get-Content', 'ConvertFrom-Json')) {
    $resolved = Get-Command -Name $name -ErrorAction Stop
    $commands[$name] = [string]$resolved.Name
}
$hashes = [ordered]@{}
foreach ($name in @('empty.bin', 'abc.bin', 'multiblock.bin')) {
    $hashes[$name] = (Get-FileHash -LiteralPath (Join-Path $Root $name) -Algorithm SHA256).Hash.ToLowerInvariant()
}
[ordered]@{ version = $PSVersionTable.PSVersion.ToString(); commands = $commands; hashes = $hashes } | ConvertTo-Json -Depth 6
''', encoding="utf-8", newline="\n")
            powershell = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32/WindowsPowerShell/v1.0/powershell.exe"
            original = package.lab.dependency_environment(root)
            environment = package.windows_powershell_environment(original)
            self.assertEqual(environment["PATH"], original["PATH"])
            self.assertFalse(any(key.upper() == "PSMODULEPATH" for key in environment))
            result = subprocess.run([str(powershell), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script),
                                     "-Root", str(root)], cwd=root, env=environment, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout)
            observed = json.loads(result.stdout)
            self.assertTrue(observed["version"].startswith("5.1."))
            self.assertEqual(observed["hashes"], {name: digest(value) for name, value in contents.items()})
            self.assertEqual(observed["hashes"]["empty.bin"], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
            self.assertEqual(observed["hashes"]["abc.bin"], "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
            self.assertEqual(observed["commands"], {name: name for name in
                ("Get-FileHash", "Get-Process", "Start-Process", "Get-Content", "ConvertFrom-Json")})

    @unittest.skipUnless(sys.platform == "win32", "Requires actual Windows PowerShell and portable environment")
    def test_actual_shipped_verifier_accepts_pristine_and_refuses_changed_or_missing_files(self):
        with tempfile.TemporaryDirectory(prefix="ramcache-strata-verifier ") as directory:
            root = Path(directory)
            verifier = root / "Verify Package.ps1"
            verifier.write_text(package.VERIFY_PS1, encoding="utf-8", newline="\n")
            files = {}
            for index in range(100):
                name = "payload/" + str(index).zfill(3) + ".bin"
                path = root / name
                path.parent.mkdir(exist_ok=True)
                data = b"" if index == 0 else bytes((index, 0, 255)) + ("binary fixture " + str(index)).encode()
                path.write_bytes(data)
                files[name] = digest(data)
            files["Verify Package.ps1"] = digest(verifier.read_bytes())
            manifest = {"schema": "ramcache-strata-workbench-evaluation-v1", "source_commit": "a" * 40,
                        "files_sha256": files}
            (root / package.MANIFEST).write_text(json.dumps(manifest), encoding="utf-8")
            powershell = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32/WindowsPowerShell/v1.0/powershell.exe"
            self.assertTrue(powershell.is_file(), "Actual Windows PowerShell is required")
            command = [str(powershell), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(verifier)]
            environment = package.lab.dependency_environment(root)

            def execute():
                return subprocess.run(command, cwd=root, env=environment, stdout=subprocess.PIPE,
                                      stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=30)

            good = execute()
            self.assertEqual(good.returncode, 0, good.stdout)
            self.assertIn("Verified 101 original payload files. Application " + "a" * 40, good.stdout)
            changed = root / "payload/000.bin"
            changed.write_bytes(b"changed after the authoritative manifest was sealed")
            altered = execute()
            self.assertNotEqual(altered.returncode, 0, altered.stdout)
            self.assertIn("Changed payload: payload/000.bin", altered.stdout)
            changed.write_bytes(b"")
            (root / "payload/001.bin").unlink()
            missing = execute()
            self.assertNotEqual(missing.returncode, 0, missing.stdout)
            self.assertIn("Missing payload: payload/001.bin", missing.stdout)


class FixedSourceReuseControls(unittest.TestCase):
    def metadata(self):
        run = {"id": package.QUALIFIED_RUN, "head_sha": package.QUALIFIED_SOURCE,
               "run_attempt": 1, "event": "push", "head_branch": "main",
               "status": "completed", "conclusion": "failure"}
        jobs = []
        for label, pin in package.QUALIFIED_CAMPAIGNS.items():
            platform, mode = label.split("-")
            jobs.append({"id": pin[0], "run_id": package.QUALIFIED_RUN, "run_attempt": 1,
                         "head_sha": package.QUALIFIED_SOURCE, "status": "completed", "conclusion": "success",
                         "name": ("Windows" if platform == "win32" else "Linux") + " graphical " + mode})
        jobs.append({"id": package.QUALIFIED_FAILED_PACKAGE_JOB, "run_id": package.QUALIFIED_RUN,
                     "run_attempt": 1, "head_sha": package.QUALIFIED_SOURCE, "status": "completed", "conclusion": "failure"})
        artifacts = [{**pin, "name": name, "expired": False,
                      "workflow_run": {"id": package.QUALIFIED_RUN, "head_sha": package.QUALIFIED_SOURCE}}
                     for name, pin in package.qualified_artifact_pins().items()]
        return {"run": run, "jobs": {"jobs": jobs}, "artifacts": {"artifacts": artifacts}}

    def test_pinned_successful_lanes_do_not_relabel_failed_overall_run(self):
        original = self.metadata()
        package.authenticate_qualification_metadata(original)
        for section, key, value in (("run", "conclusion", "success"), ("run", "run_attempt", 2),
                                    ("run", "head_sha", "0" * 40), ("run", "event", "pull_request")):
            changed = copy.deepcopy(original)
            changed[section][key] = value
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                package.authenticate_qualification_metadata(changed)
        for change in ("missing-job", "duplicate-job", "wrong-job-id", "failed-lane", "cross-source-job", "hidden-package-failure",
                       "missing-artifact", "duplicate-artifact", "artifact-sha", "artifact-run", "expired-artifact"):
            changed = copy.deepcopy(original)
            jobs, artifacts = changed["jobs"]["jobs"], changed["artifacts"]["artifacts"]
            if change == "missing-job": jobs.pop(0)
            elif change == "duplicate-job": jobs.append(dict(jobs[0]))
            elif change == "wrong-job-id": jobs[0]["id"] += 1
            elif change == "failed-lane": jobs[0]["conclusion"] = "failure"
            elif change == "cross-source-job": jobs[0]["head_sha"] = "0" * 40
            elif change == "hidden-package-failure": jobs[-1]["conclusion"] = "success"
            elif change == "missing-artifact": artifacts.pop(0)
            elif change == "duplicate-artifact": artifacts.append(dict(artifacts[0]))
            elif change == "artifact-sha": artifacts[0]["digest"] = "sha256:" + "0" * 64
            elif change == "artifact-run": artifacts[0]["workflow_run"]["id"] += 1
            else: artifacts[0]["expired"] = True
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                package.authenticate_qualification_metadata(changed)

    def test_original_summary_pins_and_source_fields_are_both_required(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "integration.json"
            source = {"source_commit": package.QUALIFIED_SOURCE}
            original = {"source_identity": source, "run_id": str(package.QUALIFIED_RUN), "run_attempt": "1",
                        "platform": "linux", "mode": "ramcache", "status": "passed", "completed": True,
                        "input_custody": "passed", "independent_verification": "passed"}
            def check(value, pin_original=False):
                path.write_text(json.dumps(value))
                pin = list(package.QUALIFIED_CAMPAIGNS["linux-ramcache"])
                pin[4] = digest(json.dumps(original if pin_original else value).encode())
                with mock.patch.dict(package.QUALIFIED_CAMPAIGNS, {"linux-ramcache": tuple(pin)}):
                    package.validate_qualified_summary(path, "linux-ramcache", source)
            check(original)
            for key, value in (("source_identity", {"source_commit": "0" * 40}),
                               ("run_id", "1"), ("run_attempt", "2"), ("platform", "win32"),
                               ("mode", "shared"), ("status", "failed"), ("completed", False),
                               ("independent_verification", "failed")):
                with self.subTest(key=key), self.assertRaises(RuntimeError):
                    check(dict(original, **{key: value}))
            with self.assertRaises(RuntimeError):
                check(dict(original, forged="unbound extra record"), pin_original=True)

    def test_historical_reader_receipt_requires_old_context_and_all_six_cases(self):
        source = {"source_inputs_sha256": {"tools/ci/ramcache_strata_qualification.py": "a" * 64}}
        proof = {"source_commit": "b" * 40, "qualification_source_identity": source}
        record = {"schema": "ramcache-strata-original-source-replay-v1", "status": "passed",
                  "execution_source": package.QUALIFIED_SOURCE, "execution_tree": package.QUALIFIED_TREE,
                  "applicability_target": proof["source_commit"], "source_workflow_run": package.QUALIFIED_RUN,
                  "source_workflow_attempt": 1, "source_workflow_conclusion": "failure",
                  "source_identity_override_used": False, "executions": {}}
        for label, pin in package.QUALIFIED_CAMPAIGNS.items():
            record["executions"][label] = {
                "command": ["/python", "-B", "/isolated/source/tools/ci/ramcache_strata_qualification.py", "verify", "/original/" + label],
                "reader_git_head": package.QUALIFIED_SOURCE, "reader_git_tree": package.QUALIFIED_TREE,
                "reader_sha256": "a" * 64, "original_summary_sha256": pin[4], "exit_code": 0,
                "stdout": json.dumps({"status": "passed", "source": package.QUALIFIED_SOURCE}),
                "stderr": "", "timeout_seconds": 300, "seconds": 1.0}
        package.validate_qualified_replay(record, proof)
        for key, value in (("source_identity_override_used", True), ("execution_source", "b" * 40),
                           ("applicability_target", package.QUALIFIED_SOURCE), ("source_workflow_conclusion", "success")):
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                package.validate_qualified_replay(dict(record, **{key: value}), proof)
        for key, value in (("reader_git_head", "b" * 40), ("reader_sha256", "c" * 64),
                           ("original_summary_sha256", "c" * 64), ("exit_code", 1), ("timeout_seconds", 600),
                           ("seconds", 301), ("stderr", "actual verification error"),
                           ("stdout", json.dumps({"status": "passed", "source": "b" * 40}))):
            changed = copy.deepcopy(record)
            changed["executions"]["linux-strata"][key] = value
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                package.validate_qualified_replay(changed, proof)
        changed = copy.deepcopy(record)
        changed["executions"].pop("win32-shared")
        with self.assertRaises(RuntimeError): package.validate_qualified_replay(changed, proof)


class PackagingScopeGitControls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ramcache-strata-reuse-scope-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.git("init")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        names = {*package.REUSE_ALLOWED_PATHS, "tools/ci/ramcache_strata_qualification.py",
                 "godot/main.gd", "native/src/world.cpp", "examples/scene.json",
                 "materials/catalogue.json", "third_party/dependency.json"}
        self.input_names = sorted(names)
        for name in names: self.write(name, b"unchanged fixture bytes\n")
        self.asset = "godot/data/asset.png"
        self.write(self.asset, b"\x89PNG\r\nraw artwork\x00")
        self.git("add", ".")
        self.git("commit", "-qm", "qualified application")
        self.qualified = self.git("rev-parse", "HEAD").decode().strip()
        self.qualified_tree = self.git("rev-parse", "HEAD^{tree}").decode().strip()
        self.write("tools/package_ramcache_strata.py", b"corrected package metadata only\n")
        self.git("add", ".")
        self.git("commit", "-qm", "packaging correction")
        self.accepted = self.git("rev-parse", "HEAD").decode().strip()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.PIPE)

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def identity(self):
        return {"source_commit": self.git("rev-parse", "HEAD").decode().strip(),
                "source_tree": self.git("rev-parse", "HEAD^{tree}").decode().strip(), "local_delta": [],
                "source_inputs_sha256": {name: digest(q.normalized_text((self.root / name).read_bytes())) for name in self.input_names},
                "source_assets_sha256": {self.asset: digest((self.root / self.asset).read_bytes())}}

    def proof(self, source=None):
        with mock.patch.multiple(package, ROOT=self.root, QUALIFIED_SOURCE=self.qualified,
                                 QUALIFIED_TREE=self.qualified_tree, QUALIFIED_INPUT_COUNT=len(self.input_names),
                                 QUALIFIED_ASSET_COUNT=1), mock.patch.object(q.custody, "git", side_effect=self.git), \
                mock.patch.object(q, "native_reuse", return_value={"native_input_count": 114}):
            return package.qualification_reuse_proof(self.identity() if source is None else source)

    def test_real_git_proof_preserves_original_ledger_and_exact_protected_trees(self):
        proof = self.proof()
        self.assertEqual(set(proof["changed_paths"]), {"tools/package_ramcache_strata.py"})
        self.assertEqual(proof["qualification_source_identity"]["source_commit"], self.qualified)
        self.assertEqual(proof["source_commit"], self.accepted)
        self.assertEqual(proof["qualification_source_identity"]["source_inputs_sha256"]["tools/package_ramcache_strata.py"],
                         digest(b"unchanged fixture bytes\n"))
        self.assertEqual(set(proof["protected_tree_identities"]), {"godot", "native", "examples", "materials", "third_party"})

    def test_every_product_fixture_native_or_unregistered_git_change_refuses_reuse(self):
        for name in ("godot/main.gd", "native/src/world.cpp", "examples/scene.json", "materials/catalogue.json",
                     "third_party/dependency.json", "tools/ci/ramcache_strata_qualification.py", "tools/unregistered.py",
                     self.asset):
            self.git("reset", "--hard", self.accepted)
            self.write(name, b"unqualified change\n")
            self.git("add", ".")
            self.git("commit", "-qm", "inadmissible change")
            with self.subTest(name=name), self.assertRaises(RuntimeError): self.proof()

    def test_claimed_input_and_asset_hashes_must_match_git(self):
        for field, key in (("source_inputs_sha256", "godot/main.gd"), ("source_assets_sha256", self.asset)):
            source = self.identity()
            source[field][key] = "0" * 64
            with self.subTest(field=field), self.assertRaises(RuntimeError): self.proof(source)
        source = self.identity(); source["source_commit"] = self.qualified
        with self.assertRaises(RuntimeError): self.proof(source)
        source = self.identity(); source["local_delta"] = ["godot/main.gd"]
        with self.assertRaises(RuntimeError): self.proof(source)
        source = self.identity(); source["source_inputs_sha256"].pop("godot/main.gd")
        with self.assertRaises(RuntimeError): self.proof(source)

    def test_allowed_path_deletion_or_mode_change_is_not_a_packaging_modification(self):
        name = "tools/package_ramcache_strata.py"
        self.git("update-index", "--chmod=+x", name)
        self.git("commit", "-qm", "inadmissible mode")
        with self.assertRaises(RuntimeError): self.proof()
        self.git("reset", "--hard", self.accepted)
        self.git("rm", name)
        self.git("commit", "-qm", "inadmissible removal")
        # Supply the previous complete ledger: the whole-tree check must reject
        # the removed path before any source-ledger reconstruction is attempted.
        claimed = {"source_commit": self.git("rev-parse", "HEAD").decode().strip(),
                   "source_tree": self.git("rev-parse", "HEAD^{tree}").decode().strip(), "local_delta": []}
        with self.assertRaises(RuntimeError): self.proof(claimed)


if __name__ == "__main__":
    unittest.main()
