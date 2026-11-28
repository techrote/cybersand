#!/usr/bin/env python3
"""Adverse controls for integrated source, evidence and portable delivery readers."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock
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
        ordinary = package.base.launcher_text(source)
        shortcut = package.persistent_launcher(source)
        self.assertEqual(shortcut.replace("-- --persistent-areas\n", "-- --workbench\n"), ordinary)
        self.assertIn('set "APPDATA=%~dp0userdata\\roaming"', shortcut)
        self.assertNotIn("--persistent-profile", shortcut)
        for altered in (ordinary.replace("-- --workbench\n", "-- --other\n"), ordinary * 2):
            with mock.patch.object(package.base, "launcher_text", return_value=altered):
                self.reject(lambda: package.persistent_launcher(source))

    def test_persistent_cmd_readiness_and_original_observation_hashes(self):
        values, source = self.launcher()
        values[0]["command"] = package.cold.command_line(values[0]["executable"], values[0]["cwd"], persistent=True)
        values[3] = values[3].split("STRATA_WORKBENCH_LAUNCH_ADMITTED ")[0] + "PERSISTENT_AREAS_READY " + json.dumps(
            {"session": "a" * 32, "area": "a", "revision": 2}) + "\n"
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


if __name__ == "__main__":
    unittest.main()
