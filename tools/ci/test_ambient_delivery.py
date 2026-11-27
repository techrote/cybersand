#!/usr/bin/env python3
"""Independent refusal tests for AMBIENT-001 source and delivery custody.

These small temporary-file fixtures execute no Godot process, native World,
publisher or external operation. They test the real verifier entry points;
successful fixture admission is not gameplay or platform qualification.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import qualify_ambient as runner
import package_ambient_evaluator as package


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class AmbientDeliveryCustody(unittest.TestCase):
    def test_only_opposite_reciprocal_binding_may_be_absent_in_windows_package(self) -> None:
        import qualify_workbench_landscapes as landscapes
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory) / "godot"
            (project / "tools").mkdir(parents=True)
            cli = b"fixture executable"
            relative = "tools/gentek_reciprocal.exe"
            (project / relative).write_bytes(cli)
            host = "tools/swarm004-runtime.windows.json"
            other = "tools/swarm004-runtime.linux.json"
            data = json.dumps({"platform":"windows", "artifact":"godot/" + relative, "bytes":len(cli), "sha256":digest(cli)}).encode()
            (project / host).write_bytes(data)
            identity = {"source_inputs_sha256":{"godot/" + host:digest(data), "godot/" + other:digest(b"linux")}}
            (project / "world.dll").write_bytes(b"world")
            (project / "rapier.dll").write_bytes(b"rapier")
            runtime = {name + "_runtime":{"path":"godot/" + file + ".dll","sha256":digest(file.encode())}
                       for name, file in (("cybersand","world"), ("rapier","rapier"))}
            self.assertEqual(landscapes.project_identity(project, identity, runtime)[relative], digest(cli))
            with mock.patch.object(landscapes, "ROOT", project.parent), self.assertRaisesRegex(RuntimeError, other):
                landscapes.project_identity(project, identity, runtime)
            (project / relative).write_bytes(b"x" * len(cli))
            with self.assertRaisesRegex(RuntimeError, "generator differs"):
                landscapes.project_identity(project, identity, runtime)
            (project / host).unlink()
            with self.assertRaisesRegex(RuntimeError, host):
                landscapes.project_identity(project, identity, runtime)


    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="ambient-delivery-test-")
        self.folder = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write(self, relative: str, data: str | bytes) -> Path:
        path = self.folder / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data.encode() if isinstance(data, str) else data)
        return path

    def log(self, value: str) -> Path:
        return self.write("terminal.log", value)

    @staticmethod
    def terminal(name: str, checks: int = 3, failures: int = 0) -> str:
        if name in runner.TERMINALS:
            return runner.TERMINALS[name] + " " + json.dumps({"checks": checks, "failures": failures})
        values = {
            "workbench": f"AMBIENT_WORKBENCH checks={checks} failures={failures} phases=3",
            "legacy_catalog": f"WB_ACTOR_CATALOG checks={checks} failures={failures} models=59 prepared_workshop_bodies=13",
            "legacy_session": f"Workbench actor composition session: {checks} checks, {failures} failures",
            "legacy_physical": f"Physical actor session: {checks} assertions, {failures} failures",
            "examples": f"AMBIENT_EXAMPLES checks={checks} failures={failures} cases=5",
        }
        return values[name]

    def test_every_scoped_case_has_a_positive_unique_completion_contract(self) -> None:
        for name, _script, _arguments in runner.CASES:
            with self.subTest(case=name):
                self.assertEqual(runner.completion(name, self.log("Godot fixture\n" + self.terminal(name) + "\n")),
                                 {"checks": 3, "failures": 0})

    def test_missing_and_repeated_terminals_are_refused(self) -> None:
        for name, _script, _arguments in runner.CASES:
            for value in ("Godot exited without completing assertions\n",
                          self.terminal(name) + "\n" + self.terminal(name) + "\n"):
                with self.subTest(case=name, log=value[:60]), self.assertRaises(RuntimeError):
                    runner.completion(name, self.log(value))

    def test_nonzero_failures_and_zero_checks_are_refused(self) -> None:
        for name, _script, _arguments in runner.CASES:
            for checks, failures in ((3, 1), (0, 0)):
                with self.subTest(case=name, checks=checks, failures=failures), self.assertRaises(RuntimeError):
                    runner.completion(name, self.log(self.terminal(name, checks, failures)))

    def test_typed_json_results_do_not_accept_boolean_success_counts(self) -> None:
        for result in ({"checks": True, "failures": []}, {"checks": 3, "failures": False},
                       {"checks": 3, "failures": ["an assertion failed"]}):
            with self.subTest(result=result), self.assertRaises(RuntimeError):
                runner.completion("engine", self.log("AMBIENT_ENGINE_RESULT " + json.dumps(result)))

    def test_ansi_decoration_is_not_a_missing_terminal(self) -> None:
        line = "\x1b[92m" + self.terminal("clock") + "\x1b[0m\n"
        self.assertEqual(runner.completion("clock", self.log(line)), {"checks": 3, "failures": 0})

    def test_preservation_skip_cannot_count_as_complete_owner_execution(self) -> None:
        line = "SKIP WB_ACTOR_COMPOSE: existing user data\n" + self.terminal("legacy_composition")
        with self.assertRaisesRegex(RuntimeError, "skipped"):
            runner.completion("legacy_composition", self.log(line))

    def qualification_fixture(self) -> dict:
        qualification = {"cases": []}
        for name in ("import", "perception"):
            text = "Godot import complete\n" if name == "import" else self.terminal(name) + "\n"
            log = self.write(name + "/process.log", text)
            receipt = {"command": ["fixture-godot", "--headless"], "timeout_seconds": 30,
                       "status": "passed", "pid": 123, "exit_code": 0, "seconds": 0.01,
                       "log_sha256": digest(log.read_bytes())}
            process = self.write(name + "/process.json", json.dumps(receipt, sort_keys=True) + "\n")
            row = {**receipt, "process_sha256": digest(process.read_bytes())}
            if name == "import":
                qualification["import"] = row
            else:
                detail = self.write(name + "/report.json", json.dumps({"checks": 3, "failures": []}) + "\n")
                row.update({"name": name, "script": "test_ambient_perception",
                            "completion": {"checks": 3, "failures": 0}, "checks": 3,
                            "report_sha256": digest(detail.read_bytes())})
                qualification["cases"].append(row)
        return qualification

    def test_original_qualification_receipts_are_admitted(self) -> None:
        package.verify_qualification(self.folder, self.qualification_fixture())

    def test_changed_log_is_refused_even_with_successful_summary(self) -> None:
        qualification = self.qualification_fixture()
        self.write("perception/process.log", self.terminal("perception", 800, 0) + "\n")
        with self.assertRaises(RuntimeError):
            package.verify_qualification(self.folder, qualification)

    def test_changed_process_receipt_is_refused(self) -> None:
        qualification = self.qualification_fixture()
        path = self.folder / "perception/process.json"
        receipt = json.loads(path.read_text())
        receipt["exit_code"] = 77
        path.write_text(json.dumps(receipt))
        with self.assertRaises(RuntimeError):
            package.verify_qualification(self.folder, qualification)

    def test_truncated_process_receipt_cannot_pass_vacuous_key_comparison(self) -> None:
        qualification = self.qualification_fixture()
        self.write("perception/process.json", "{}\n")
        with self.assertRaises(RuntimeError):
            package.verify_qualification(self.folder, qualification)

    def test_changed_report_is_refused(self) -> None:
        qualification = self.qualification_fixture()
        self.write("perception/report.json", json.dumps({"checks": 900, "failures": []}))
        with self.assertRaises(RuntimeError):
            package.verify_qualification(self.folder, qualification)

    def test_original_nonzero_process_exit_is_refused(self) -> None:
        qualification = self.qualification_fixture()
        qualification["cases"][0]["exit_code"] = 1
        with self.assertRaises(RuntimeError):
            package.verify_qualification(self.folder, qualification)

    def graphical_fixture(self) -> tuple[dict, dict]:
        qualification = self.qualification_fixture()
        qualification["cases"] = []
        identity = {"source_commit": "fixture-only", "source_tree": "fixture-tree",
                    "source_inputs_sha256": {}, "local_delta": []}
        qualification.update({**identity, "schema_version": 1, "kind": "ambient-001-qualification",
                              "status": "passed", "input_custody": "passed", "headless": False})
        log = self.write("graphical/process.log", "AMBIENT_CAPTURE fixture receipt\n")
        receipt = {"command": ["fixture-godot", "--script", "capture-fixture.gd"], "timeout_seconds": 30,
                   "status": "passed", "pid": 124, "exit_code": 0, "seconds": 0.02,
                   "log_sha256": digest(log.read_bytes())}
        process = self.write("graphical/process.json", json.dumps(receipt, sort_keys=True) + "\n")
        examples = ["ambient-oil-water", "ambient-ledge-walkway", "ambient-industrial-yard",
                    "ambient-settlement", "ambient-flight"]
        filenames = [name + "-" + stage + ".png" for name in examples for stage in ("authored", "playing")]
        filenames += ["ambient-oil-water-overlay.png", "ambient-behaviour-profile-editor.png"]
        captures = []
        images = {}
        for name in filenames:
            path = self.write("captures/" + name, b"\x89PNG\r\n\x1a\nfixture, not rendered gameplay")
            images[name] = digest(path.read_bytes())
            captures.append({"path": str(path), "caption": "synthetic custody fixture",
                             "native_tick": 120, "physical_tick": 120, "paused": name.endswith("-authored.png"),
                             "material_display": {"generation": 1, "render_serial": 2, "revision": 3},
                             "rendered_actor_frame": {"available": True, "mode": "matched uploaded material",
                                                      "session": "fixture-session", "epoch": 1,
                                                      "sample_tick": 120, "tick": 120,
                                                      "revision": 3, "world_generation": 1}})
        report = {"schema": "ambient-graphical-evidence/v1", "failures": [], "display": "fixture-display",
                  "renderer": "fixture renderer", "renderer_vendor": "fixture vendor",
                  "rendering_method": "gl_compatibility",
                  "rendering_driver": "opengl3_angle" if sys.platform == "win32" else "opengl3",
                  "source_revision": identity["source_commit"],
                  "engine_sha256": runner.GODOT_WINDOWS_GUI_SHA256 if sys.platform == "win32" else runner.GODOT_LINUX_SHA256,
                  "phases": [{"example": name, "requested_physical_ticks": 120, "physical_ticks": 120,
                              "native_ticks": 119, "passed": True} for name in examples], "captures": captures}
        detail = self.write("captures/capture-report.json", json.dumps(report) + "\n")
        qualification["graphical"] = {"process": {**receipt, "process_sha256": digest(process.read_bytes())},
                                      "report_sha256": digest(detail.read_bytes()), "images_sha256": images,
                                      "display": report["display"], "renderer": report["renderer"]}
        self.write("qualification.json", json.dumps(qualification))
        return identity, qualification

    def test_original_graphical_receipt_with_summary_digest_is_admitted(self) -> None:
        identity, qualification = self.graphical_fixture()
        self.assertEqual(package.verify_graphical(self.folder, identity), qualification)

    def test_changed_graphical_receipt_is_refused(self) -> None:
        identity, _qualification = self.graphical_fixture()
        self.write("graphical/process.json", "{}\n")
        with self.assertRaises(RuntimeError):
            package.verify_graphical(self.folder, identity)

    def test_changed_captured_image_is_refused(self) -> None:
        identity, _qualification = self.graphical_fixture()
        self.write("captures/ambient-flight-playing.png", b"different purported capture")
        with self.assertRaises(RuntimeError):
            package.verify_graphical(self.folder, identity)

    def capture_report_fixture(self) -> dict:
        self.graphical_fixture()
        return json.loads((self.folder / "captures/capture-report.json").read_text())

    def test_complete_capture_inventory_is_admitted(self) -> None:
        report = self.capture_report_fixture()
        images = runner.validate_capture_report(self.folder / "captures", report)
        self.assertEqual(set(images), {Path(row["path"]).name for row in report["captures"]})
        self.assertEqual(len(images), 12)

    def test_missing_or_duplicate_example_phase_is_refused(self) -> None:
        valid = self.capture_report_fixture()
        for duplicate in (False, True):
            report = copy.deepcopy(valid)
            if duplicate:
                report["phases"][-1] = copy.deepcopy(report["phases"][0])
            else:
                report["phases"].pop()
            with self.subTest(duplicate=duplicate), self.assertRaises(RuntimeError):
                runner.validate_capture_report(self.folder / "captures", report)

    def test_incomplete_native_or_physical_capture_progress_is_refused(self) -> None:
        valid = self.capture_report_fixture()
        for field, value in (("native_ticks", 118), ("physical_ticks", 119), ("passed", False)):
            report = copy.deepcopy(valid)
            report["phases"][0][field] = value
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                runner.validate_capture_report(self.folder / "captures", report)

    def test_missing_or_duplicate_named_capture_is_refused(self) -> None:
        valid = self.capture_report_fixture()
        for duplicate in (False, True):
            report = copy.deepcopy(valid)
            if duplicate:
                report["captures"][-1] = copy.deepcopy(report["captures"][0])
            else:
                report["captures"].pop()
            with self.subTest(duplicate=duplicate), self.assertRaises(RuntimeError):
                runner.validate_capture_report(self.folder / "captures", report)

    def test_headless_or_missing_renderer_cannot_supply_graphical_evidence(self) -> None:
        valid = self.capture_report_fixture()
        for field, value in (("display", "headless"), ("display", ""), ("display", None), ("renderer", "")):
            report = copy.deepcopy(valid)
            report[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(RuntimeError):
                runner.validate_capture_report(self.folder / "captures", report)

    def test_named_png_outside_capture_directory_is_refused(self) -> None:
        report = self.capture_report_fixture()
        filename = Path(report["captures"][0]["path"]).name
        outside = self.write("outside/" + filename, b"\x89PNG\r\n\x1a\nwrong directory")
        report["captures"][0]["path"] = str(outside)
        with self.assertRaises(RuntimeError):
            runner.validate_capture_report(self.folder / "captures", report)

    def test_named_capture_with_invalid_png_signature_is_refused(self) -> None:
        report = self.capture_report_fixture()
        Path(report["captures"][0]["path"]).write_bytes(b"purported image without a PNG signature")
        with self.assertRaises(RuntimeError):
            runner.validate_capture_report(self.folder / "captures", report)

    def test_missing_or_mismatched_display_publication_identity_is_refused(self) -> None:
        valid = self.capture_report_fixture()
        mutations = (("material_display", "generation", None), ("material_display", "render_serial", -1),
                     ("material_display", "revision", None), ("rendered_actor_frame", "available", None),
                     ("rendered_actor_frame", "mode", ""), ("rendered_actor_frame", "epoch", -1),
                     ("rendered_actor_frame", "world_generation", 99), ("rendered_actor_frame", "revision", 99))
        for group, key, value in mutations:
            report = copy.deepcopy(valid)
            if value is None:
                report["captures"][0][group].pop(key)
            else:
                report["captures"][0][group][key] = value
            with self.subTest(group=group, key=key), self.assertRaises(RuntimeError):
                runner.validate_capture_report(self.folder / "captures", report)

    def test_explicit_unavailable_displayed_frame_does_not_claim_a_matched_frame(self) -> None:
        report = self.capture_report_fixture()
        report["captures"][0]["rendered_actor_frame"] = {
            "available": False, "mode": "current physical fallback; no matched frame available"}
        self.assertEqual(len(runner.validate_capture_report(self.folder / "captures", report)), 12)

    def test_capture_call_checks_expected_source_engine_and_backend(self) -> None:
        identity, qualification = self.graphical_fixture()
        receipt = json.loads((self.folder / "graphical/process.json").read_text())
        with mock.patch.object(runner, "execute", return_value=copy.deepcopy(receipt)):
            result = runner.capture(self.folder / "fixture-godot", self.folder / "godot", self.folder, identity)
        self.assertEqual(result["images_sha256"], qualification["graphical"]["images_sha256"])
        self.assertFalse(result["owner_playfeel_accepted"])

    def test_wrong_or_missing_graphical_source_engine_and_backend_are_refused(self) -> None:
        identity, _qualification = self.graphical_fixture()
        receipt = json.loads((self.folder / "graphical/process.json").read_text())
        detail = self.folder / "captures/capture-report.json"
        valid = json.loads(detail.read_text())
        for key, value in (("source_revision", None), ("source_revision", "unqualified-source"),
                           ("engine_sha256", None), ("engine_sha256", "unqualified-engine"),
                           ("rendering_method", "unqualified-method"), ("rendering_driver", "unqualified-driver")):
            report = copy.deepcopy(valid)
            if value is None:
                report.pop(key)
            else:
                report[key] = value
            detail.write_text(json.dumps(report))
            with self.subTest(field=key, value=value), \
                 mock.patch.object(runner, "execute", return_value=copy.deepcopy(receipt)), \
                 self.assertRaises(RuntimeError):
                runner.capture(self.folder / "fixture-godot", self.folder / "godot", self.folder, identity)

    def package_fixture(self) -> dict:
        files = {"godot/project.godot": "; fixture project\n",
                 "godot/scripts/main.gd": "extends Node\n",
                 "godot/shaders/depth_composite.gdshader": "shader_type canvas_item;\n",
                 "godot/icon.svg": '<svg xmlns="http://www.w3.org/2000/svg"/>\n',
                 "Open Workbench.cmd": "@echo off\n"}
        hashes = {}
        for relative, value in files.items():
            path = self.write(relative, value)
            hashes[relative] = digest(path.read_bytes())
        manifest = {"schema_version": 1, "kind": "ambient-001-owner-evaluation",
                    "source_commit": "fixture-only", "files_sha256": hashes}
        self.write("evaluation-manifest.json", json.dumps(manifest))
        return manifest

    def test_pristine_original_package_is_admitted(self) -> None:
        manifest = self.package_fixture()
        self.assertEqual(package.verify_package(self.folder, pristine=True), manifest)

    def test_pristine_unexpected_file_is_refused(self) -> None:
        self.package_fixture()
        self.write("unexpected.txt", "not in authenticated payload")
        with self.assertRaisesRegex(RuntimeError, "unexpected"):
            package.verify_package(self.folder, pristine=True)

    def test_postlaunch_executable_project_script_is_refused(self) -> None:
        self.package_fixture()
        self.write("godot/scripts/extra.gd", "extends Node\n")
        with self.assertRaisesRegex(RuntimeError, "Unexpected"):
            package.verify_package(self.folder)

    def test_postlaunch_original_input_changes_are_refused(self) -> None:
        self.package_fixture()
        self.write("godot/scripts/main.gd", "extends Node2D\n")
        with self.assertRaisesRegex(RuntimeError, "changed"):
            package.verify_package(self.folder)

    def test_postlaunch_uid_for_original_shader_is_admitted(self) -> None:
        manifest = self.package_fixture()
        self.write("godot/shaders/depth_composite.gdshader.uid", "uid://fixture-shader\n")
        self.assertEqual(package.verify_package(self.folder), manifest)

    def test_pristine_shader_uid_sidecar_is_refused(self) -> None:
        self.package_fixture()
        self.write("godot/shaders/depth_composite.gdshader.uid", "uid://fixture-shader\n")
        with self.assertRaisesRegex(RuntimeError, "unexpected"):
            package.verify_package(self.folder, pristine=True)

    def test_postlaunch_shader_uid_requires_manifested_original(self) -> None:
        self.package_fixture()
        self.write("godot/shaders/unknown.gdshader.uid", "uid://fixture-unknown\n")
        with self.assertRaisesRegex(RuntimeError, "Unexpected"):
            package.verify_package(self.folder)

    def test_postlaunch_injected_shader_and_uid_are_refused(self) -> None:
        self.package_fixture()
        self.write("godot/shaders/unknown.gdshader", "shader_type canvas_item;\n")
        self.write("godot/shaders/unknown.gdshader.uid", "uid://fixture-unknown\n")
        with self.assertRaisesRegex(RuntimeError, "Unexpected"):
            package.verify_package(self.folder)

    def test_postlaunch_original_shader_mutation_with_uid_is_refused(self) -> None:
        self.package_fixture()
        self.write("godot/shaders/depth_composite.gdshader", "shader_type canvas_item;\nrender_mode unshaded;\n")
        self.write("godot/shaders/depth_composite.gdshader.uid", "uid://fixture-shader\n")
        with self.assertRaisesRegex(RuntimeError, "changed"):
            package.verify_package(self.folder)

    def test_postlaunch_uid_for_other_original_asset_type_is_refused(self) -> None:
        self.package_fixture()
        self.write("godot/icon.svg.uid", "uid://fixture-icon\n")
        with self.assertRaisesRegex(RuntimeError, "Unexpected"):
            package.verify_package(self.folder)

    def test_postlaunch_expected_import_metadata_and_authored_data_are_allowed(self) -> None:
        manifest = self.package_fixture()
        sidecar, reviewed_digest = next(iter(package.REGENERATED_RAPIER_IMPORTS.items()))
        asset = self.write(sidecar.removesuffix(".import"), "original fixture image bytes")
        manifest["files_sha256"][sidecar.removesuffix(".import")] = digest(asset.read_bytes())
        manifest["regenerated_imports_omitted"] = {sidecar: reviewed_digest}
        self.write("evaluation-manifest.json", json.dumps(manifest))
        self.write("godot/.godot/imported/icon.ctex", b"fixture-import-cache")
        self.write("godot/scripts/main.gd.uid", "uid://fixture-only\n")
        self.write(sidecar, "[remap]\nimporter=\"svg\"\n")
        self.write("userdata/roaming/workbench/setup-owner.json", "{}\n")
        self.assertEqual(package.verify_package(self.folder), manifest)

    def test_unreviewed_import_exemption_is_refused(self) -> None:
        manifest = self.package_fixture()
        manifest["regenerated_imports_omitted"] = {"godot/icon.svg.import": "unreviewed hash"}
        self.write("evaluation-manifest.json", json.dumps(manifest))
        with self.assertRaisesRegex(RuntimeError, "Unreviewed"):
            package.verify_package(self.folder)

    def test_postlaunch_import_metadata_requires_an_original_asset(self) -> None:
        self.package_fixture()
        self.write("godot/unrecorded.svg.import", "[remap]\n")
        with self.assertRaisesRegex(RuntimeError, "Unexpected"):
            package.verify_package(self.folder)

    def test_unauthenticated_godot_executable_is_refused(self) -> None:
        binary = self.write("fixture-godot.exe", b"not an authenticated Godot executable")
        with self.assertRaisesRegex(RuntimeError, "authenticated official pin"):
            runner.engine_identity(binary)

    def test_explicit_new_json_is_hashed_and_dirty_source_refused(self) -> None:
        original = {}
        for relative in runner.OWN_INPUTS:
            original[relative] = b"fixture committed input\n"
            self.write(relative, original[relative])
        profile = "godot/data/ambient/profiles.json"
        changed = b'[{"fixture":"changed authored profile"}]\n'
        self.write(profile, changed)
        baseline = {"source_commit": "fixture-only", "source_tree": "fixture-tree",
                    "source_inputs_sha256": {}, "local_delta": []}
        with mock.patch.object(runner, "ROOT", self.folder), \
             mock.patch.object(runner, "host_source_identity", side_effect=lambda **_: copy.deepcopy(baseline)), \
             mock.patch.object(runner, "git", side_effect=lambda _show, path: original[path.removeprefix("HEAD:")]):
            admitted = runner.source_identity(allow_delta=True)
            self.assertEqual(admitted["source_inputs_sha256"].get(profile), digest(changed))
            self.assertIn(profile, admitted["local_delta"])
            with self.assertRaisesRegex(RuntimeError, "Commit all execution inputs"):
                runner.source_identity()


if __name__ == "__main__":
    unittest.main(verbosity=2)
