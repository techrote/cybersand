#!/usr/bin/env python3
"""Offline source-history, dependency isolation and package-custody controls.

Graphical fixtures below test receipt admission, not native or UI acceptance.
The actual Windows smoke command must execute the unmocked Godot cases.
"""
import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_materials_lab_candidate as subject


class PackageTests(unittest.TestCase):
    def command(self, root, *args):
        return subprocess.check_output(["git", "-C", str(root), *args],
                                       env=subject.clean_git_environment(), stderr=subprocess.PIPE)

    def test_fresh_history_preserves_commits_without_machine_configuration_or_untracked_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "original"
            root.mkdir()
            self.command(root, "init")
            (root / ".gitattributes").write_bytes(b"source.txt text eol=lf\nretained-crlf.txt -text\n")
            (root / "source.txt").write_bytes(b"baseline\n")
            (root / "retained-crlf.txt").write_bytes(b"literal CRLF history\r\n")
            self.command(root, "add", ".gitattributes", "source.txt", "retained-crlf.txt")
            self.command(root, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-m", "baseline")
            first = self.command(root, "rev-parse", "HEAD").decode().strip()
            (root / "source.txt").write_bytes(b"candidate\n")
            self.command(root, "add", "source.txt")
            self.command(root, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-m", "candidate")
            head = self.command(root, "rev-parse", "HEAD").decode().strip()
            self.command(root, "remote", "add", "origin", "https://example.invalid/private-checkout")
            self.command(root, "config", "credential.helper", "fixture-private-helper")
            (root / ".git/hooks/private-marker").write_text("private machine data")
            (root / "untracked-private.txt").write_text("must not ship")
            template = Path(temporary) / "machine-template"
            template.mkdir()
            (template / "private-template-marker").write_text("private template data")
            destination = Path(temporary) / "delivery/source"
            with patch.dict(os.environ, {"GIT_TEMPLATE_DIR": str(template), "GIT_CONFIG_COUNT": "1",
                                        "GIT_CONFIG_KEY_0": "credential.helper", "GIT_CONFIG_VALUE_0": "injected-private-helper"}):
                identity = subject.clean_source_repository(root, head, destination)
            self.assertEqual(identity["source_commit"], head)
            self.assertGreater(identity["bundle_bytes"], 0)
            self.assertEqual(self.command(destination, "show", first + ":source.txt"), b"baseline\n")
            self.assertEqual(self.command(destination, "show", first + ":retained-crlf.txt"), b"literal CRLF history\r\n")
            self.assertEqual((destination / "retained-crlf.txt").read_bytes(), b"literal CRLF history\r\n")
            self.assertEqual(self.command(destination, "merge-base", "--is-ancestor", first, head), b"")
            self.assertEqual((destination / "source.txt").read_text(), "candidate\n")
            self.assertEqual(self.command(destination, "remote"), b"")
            self.assertFalse((destination / "untracked-private.txt").exists())
            self.assertFalse((destination / ".git/hooks/private-marker").exists())
            self.assertFalse((destination / ".git/private-template-marker").exists())
            configuration = (destination / ".git/config").read_text()
            self.assertNotIn("private-checkout", configuration)
            self.assertNotIn("fixture-private-helper", configuration)
            self.assertNotIn("injected-private-helper", configuration)
            with self.assertRaisesRegex(RuntimeError, "overwrite"):
                subject.clean_source_repository(root, head, destination)

    def test_dependency_environment_does_not_find_host_authoring_tools_or_user_python(self):
        with patch.dict(os.environ, {"PATH": "host-secret-tools", "PYTHONPATH": "private-imports",
                                     "PYTHONHOME": "private-python", "GIT_DIR": "other-repository",
                                     "GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "core.hooksPath",
                                     "GIT_CONFIG_VALUE_0": "private-hooks", "GIT_TEMPLATE_DIR": "private-template"}):
            environment = subject.dependency_environment(Path("evaluation"))
        self.assertNotIn("host-secret-tools", environment["PATH"])
        self.assertNotIn("PYTHONPATH", environment)
        self.assertNotIn("PYTHONHOME", environment)
        self.assertNotIn("GIT_DIR", environment)
        self.assertNotIn("GIT_CONFIG_COUNT", environment)
        self.assertNotIn("GIT_CONFIG_KEY_0", environment)
        self.assertNotIn("GIT_CONFIG_VALUE_0", environment)
        self.assertNotIn("GIT_TEMPLATE_DIR", environment)
        self.assertEqual(environment["PYTHONNOUSERSITE"], "1")
        self.assertIn("dependencies", environment["CYBERSAND_LAB_CXX"])

    def test_python_packaging_keeps_stdlib_not_installed_packages_or_caches(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, out = Path(temporary) / "python", Path(temporary) / "copied"
            for name in ("python.exe", "python312.dll", "LICENSE.txt", "Lib/json/__init__.py",
                         "Lib/site-packages/private_package.py", "Lib/json/__pycache__/private.pyc", "DLLs/_hashlib.pyd"):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"fixture")
            subject.copy_python(root, out)
            self.assertTrue((out / "LICENSE.txt").is_file())
            self.assertTrue((out / "Lib/json/__init__.py").is_file())
            self.assertTrue((out / "DLLs/_hashlib.pyd").is_file())
            self.assertFalse((out / "Lib/site-packages").exists())
            self.assertFalse((out / "Lib/json/__pycache__").exists())

    def python_fixture(self, directory):
        root = directory / "python"
        for name in ("python.exe", "python312.dll", "LICENSE.txt", "Lib/json/__init__.py", "DLLs/_hashlib.pyd"):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(("fixture: " + name).encode())
        return root

    def test_python_packaging_materializes_internal_executable_aliases(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            root = self.python_fixture(directory)
            (root / "python3.exe").symlink_to("python.exe")
            (root / "python3.12.exe").symlink_to("python3.exe")
            destination = directory / "portable python"
            subject.copy_python(root, destination)
            for name in ("python.exe", "python3.exe", "python3.12.exe"):
                self.assertFalse((destination / name).is_symlink())
                self.assertEqual(subject.sha(destination / name), subject.sha(root / "python.exe"))
            self.assertFalse(any(path.is_symlink() for path in destination.rglob("*")))

    def test_python_packaging_refuses_external_broken_and_directory_aliases(self):
        for mode in ("external", "broken", "directory", "stdlib_directory"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary)
                root = self.python_fixture(directory)
                if mode == "external":
                    external = directory / "external.exe"
                    external.write_bytes(b"not part of the Python installation")
                    (root / "python3.exe").symlink_to(external)
                elif mode == "broken":
                    (root / "python3.exe").symlink_to("absent.exe")
                elif mode == "directory":
                    (root / "python3.exe").symlink_to("Lib", target_is_directory=True)
                else:
                    (root / "Lib").rename(root / "stdlib")
                    (root / "Lib").symlink_to("stdlib", target_is_directory=True)
                with self.assertRaisesRegex(RuntimeError, "Python runtime file|real dependency directory"):
                    subject.copy_python(root, directory / "rejected")

    def fixture(self, root):
        runtime = root / "source" / subject.engine.RUNTIMES["windows"]
        runtime.parent.mkdir(parents=True)
        runtime.write_bytes(b"native fixture bytes")
        manifest = {"schema": "cybersand-materials-lab-evaluation-v1", "platform": "windows",
                    "source_commit": "a" * 40, "native_sha256": subject.sha(runtime), "runtime_active_candidates": False}
        native_manifest = root / "source" / subject.engine.MANIFESTS["windows"]
        native_manifest.write_bytes(subject.canonical({"sha256": manifest["native_sha256"],
            "source_commit": manifest["source_commit"], "status": "validated-development-runtime"}))
        manifest["files_sha256"] = subject.file_map(root)
        (root / subject.MANIFEST).write_bytes(subject.canonical(manifest))
        return manifest, runtime

    def test_complete_package_map_refuses_addition_loss_or_runtime_drift(self):
        for mode in ("positive", "extra", "missing", "changed", "native_binding", "active"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                manifest, runtime = self.fixture(root)
                if mode == "extra": (root / "unrecorded.exe").write_bytes(b"unknown")
                if mode == "missing": runtime.unlink()
                if mode == "changed": runtime.write_bytes(b"changed")
                if mode == "native_binding":
                    manifest["native_sha256"] = "0" * 64
                    (root / subject.MANIFEST).write_bytes(subject.canonical(manifest))
                if mode == "active":
                    manifest["runtime_active_candidates"] = True
                    (root / subject.MANIFEST).write_bytes(subject.canonical(manifest))
                if mode == "positive": self.assertEqual(subject.verify_package(root)["source_commit"], "a" * 40)
                else:
                    with self.assertRaises(RuntimeError): subject.verify_package(root)

    def contact_fixture(self, root):
        package, evidence = root / "disposable package", root / "original evidence"
        package.mkdir()
        identity, runtime = self.fixture(package)
        capture = evidence / subject.CONTACT_DIRECTORY
        capture.mkdir(parents=True)
        owner_sources = {"scripts/microscenario_identity.gd", "scripts/microscenario_host.gd", "scripts/cell_world.gd"}
        for relative in subject.CONTACT_SOURCES | owner_sources:
            path = package / "source/godot" / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(("original source fixture: " + relative + "\n").encode("utf-8"))
        for name in ("Godot_v4.7-stable_win64_console.exe", "Godot_v4.7-stable_win64.exe"):
            (package / name).write_bytes(b"MZ receipt fixture, not an executable")
        identity["files_sha256"] = subject.file_map(package)
        (package / subject.MANIFEST).write_bytes(subject.canonical(identity))
        source_map = {path: subject.sha(package / "source/godot" / path) for path in subject.CONTACT_SOURCES}
        native_path = "res://" + Path(subject.engine.RUNTIMES["windows"]).relative_to("godot").as_posix()
        native = {"tick": 0, "state_hash": "0123456789abcdef", "content_hash": "fedcba9876543210"}
        definition = "b" * 64
        contact = {"schema_id": "cybersand.material-lab.contact", "schema_version": 1,
                   "ok": True, "reaction_executed": False, "world_eligibility": "unresolved", "blockers": [],
                   "completed_tick": 0, "definition_hash": definition, "supplied_roll": 0}
        for endpoint, material, x, state_a in (("source", 23, 220, 0), ("target", 3, 221, 173)):
            contact[endpoint] = {"schema_id": "cybersand.material-lab.cell", "schema_version": 1,
                                 "ok": True, "read_only": True, "material": material, "visible_material": material,
                                 "x": x, "y": 130, "state_a": state_a, "state_b": 0, "completed_tick": 0,
                                 "transient_body_id": 0, "stored_temperature_available": True, "stored_temperature_raw": 200}
        contact["resolver"] = {"ok": True, "matched": True, "selected": True, "outcome": "selected_reaction",
                               "source": 23, "target": 3, "source_product": 24, "target_product": 24,
                               "probability_roll": 0, "probability_threshold": 255,
                               "probability_numerator": 256, "probability_denominator": 256}
        owner = {"schema_version": 2, "material_lab_schema_version": 1, "ok": True, "failed": False,
                 "platform": "Windows", "backend": "native-phased", "completed_tick": 0, "worker_count": 1,
                 "definition_hash": definition, "native": native,
                 "readback": {"ok": True, "backend": "native World / existing MicroScenario host", "native": native,
                              "completed_tick": 0, "workers": 1, "definition_hash": definition},
                 "runtime_identity": {"platform": "Windows", "native_path": native_path,
                                      "native_sha256": identity["native_sha256"],
                                      "material_lab_experiment_sha256": source_map["scripts/material_lab_experiment.gd"],
                                      "script_sha256": {path: subject.sha(package / "source/godot" / path) for path in owner_sources}}}
        readback = {"contact": contact, "owner": owner}
        (capture / subject.CONTACT_IMAGE).write_bytes(base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6GkAAAAASUVORK5CYII="))
        (capture / subject.CONTACT_READBACK).write_bytes(subject.canonical(readback))
        manifest = {"schema_id": "cybersand.material-lab.contact-capture", "schema_version": 1,
                    "platform": "Windows", "display": "Windows", "rendering_method": "gl_compatibility",
                    "renderer": "receipt fixture / ANGLE", "assertions": 123, "failures": 0,
                    "engine": {"major": 4, "minor": 7, "patch": 0, "status": "stable", "build": "official",
                               "hash": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"},
                    "image_sha256": subject.sha(capture / subject.CONTACT_IMAGE), "viewport": [1, 1],
                    "readback_sha256": subject.sha(capture / subject.CONTACT_READBACK), "source_sha256": source_map,
                    "native_library_path": native_path, "native_library_sha256": identity["native_sha256"]}
        (capture / subject.CONTACT_MANIFEST).write_bytes(subject.canonical(manifest))
        log = evidence / (subject.CONTACT_CASE + ".log")
        log.write_bytes(b"MATERIAL_LAB_DIAGNOSTICS: 123 assertions; 0 failures\n")
        with subject.runner_root(package / "source"):
            command = subject.engine.runner.case_command(str(package / "Godot_v4.7-stable_win64_console.exe"),
                                                        subject.smoke_cases(evidence)[-1], "win32")
        result = {"name": subject.CONTACT_CASE, "status": "passed", "returncode": 0, "natural_completion": True,
                  "requires_display": True, "skip_messages": [], "diagnostic_error": False, "launch_error": None,
                  "capture_error": None, "command": command, "log_sha256": subject.sha(log)}
        return package, evidence, capture, identity, result, manifest, readback, runtime

    def test_package_smoke_adds_real_angle_case_without_replacing_authoring_cases(self):
        with tempfile.TemporaryDirectory() as temporary:
            evidence = Path(temporary) / "fresh evidence"
            cases = subject.smoke_cases(evidence)
            self.assertEqual([case.name for case in cases],
                             ["import", "test_material_lab_ui", "test_material_lab_world", subject.CONTACT_CASE])
            self.assertEqual([case.requires_display for case in cases], [False, False, False, True])
            for case in cases[:-1]:
                self.assertNotIn("--max-fps", subject.engine.runner.case_command("bundled-console.exe", case, "win32"))
            command = subject.engine.runner.case_command("bundled-console.exe", cases[-1], "win32")
            self.assertNotIn("--headless", command)
            self.assertEqual(command.count("--max-fps"), 1)
            self.assertEqual(command[command.index("--max-fps") + 1], "15")
            self.assertLess(command.index("--max-fps"), command.index("--"))
            self.assertEqual(command[command.index("--rendering-driver") + 1], "opengl3_angle")
            self.assertIn("--capture-output=" + str((evidence / subject.CONTACT_DIRECTORY).resolve()), command)
            self.assertFalse((evidence / subject.CONTACT_DIRECTORY).exists())

    def test_original_graphical_contact_receipt_admission(self):
        with tempfile.TemporaryDirectory() as temporary:
            package, evidence, _, identity, result, _, _, _ = self.contact_fixture(Path(temporary))
            admitted = subject.verify_contact_capture(package, evidence, result, identity)
            self.assertEqual(admitted["status"], "passed")
            self.assertEqual(admitted["assertions"], 123)
            self.assertEqual(admitted["native_sha256"], identity["native_sha256"])
            self.assertIn("not an executed reaction", admitted["scope"])

    def test_graphical_contact_refuses_headless_or_incomplete_process_and_marker(self):
        for mode in ("headless_command", "display_flag", "early_exit", "skip", "wrong_executable", "missing_marker", "duplicate_marker", "log_drift",
                     "missing_fps", "unbounded_fps", "duplicate_fps", "user_argument_fps"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                package, evidence, _, identity, result, _, _, _ = self.contact_fixture(Path(temporary))
                log = evidence / (subject.CONTACT_CASE + ".log")
                if mode == "headless_command": result["command"].append("--headless")
                if mode == "display_flag": result["requires_display"] = False
                if mode == "early_exit": result["natural_completion"] = False
                if mode == "skip": result["skip_messages"] = ["SKIP fixture"]
                if mode == "wrong_executable": result["command"][0] = "host-installed-godot.exe"
                if mode in ("missing_fps", "unbounded_fps", "user_argument_fps"):
                    index = result["command"].index("--max-fps")
                    if mode == "missing_fps": del result["command"][index:index + 2]
                    if mode == "unbounded_fps": result["command"][index + 1] = "0"
                    if mode == "user_argument_fps": result["command"].insert(index, "--")
                if mode == "duplicate_fps": result["command"].extend(("--max-fps", "0"))
                if mode == "missing_marker": log.write_bytes(b"clean exit without assertions\n")
                if mode == "duplicate_marker": log.write_bytes(log.read_bytes() * 2)
                if mode == "log_drift": log.write_bytes(log.read_bytes() + b"changed\n")
                if mode in {"missing_marker", "duplicate_marker"}: result["log_sha256"] = subject.sha(log)
                with self.assertRaises(RuntimeError): subject.verify_contact_capture(package, evidence, result, identity)

    def test_graphical_contact_refuses_missing_or_changed_original_artifacts(self):
        for mode in ("missing_manifest", "missing_readback", "missing_image", "readback_drift", "image_drift", "viewport"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                package, evidence, capture, identity, result, manifest, _, _ = self.contact_fixture(Path(temporary))
                if mode.startswith("missing_"):
                    name = {"missing_manifest": subject.CONTACT_MANIFEST, "missing_readback": subject.CONTACT_READBACK,
                            "missing_image": subject.CONTACT_IMAGE}[mode]
                    (capture / name).unlink()
                if mode == "readback_drift":
                    (capture / subject.CONTACT_READBACK).write_bytes((capture / subject.CONTACT_READBACK).read_bytes() + b" ")
                if mode == "image_drift":
                    (capture / subject.CONTACT_IMAGE).write_bytes((capture / subject.CONTACT_IMAGE).read_bytes() + b"changed")
                if mode == "viewport":
                    manifest["viewport"] = [1680, 1050]
                    (capture / subject.CONTACT_MANIFEST).write_bytes(subject.canonical(manifest))
                with self.assertRaises(RuntimeError): subject.verify_contact_capture(package, evidence, result, identity)

    def test_graphical_contact_requires_original_source_engine_and_native_library(self):
        for mode in ("missing_source", "changed_source", "source_digest", "extra_source", "native_drift", "forged_native", "engine_drift"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                package, evidence, capture, identity, result, manifest, readback, runtime = self.contact_fixture(Path(temporary))
                if mode == "missing_source": manifest["source_sha256"].pop("scripts/material_lab_panel.gd")
                if mode == "changed_source": (package / "source/godot/scripts/material_lab_panel.gd").write_bytes(b"changed")
                if mode == "source_digest": manifest["source_sha256"]["scripts/material_lab_panel.gd"] = "0" * 64
                if mode == "extra_source": manifest["source_sha256"]["../unexpected.gd"] = "0" * 64
                if mode in {"native_drift", "forged_native"}: runtime.write_bytes(b"different native runtime")
                if mode == "forged_native":
                    manifest["native_library_sha256"] = subject.sha(runtime)
                    readback["owner"]["runtime_identity"]["native_sha256"] = subject.sha(runtime)
                    (capture / subject.CONTACT_READBACK).write_bytes(subject.canonical(readback))
                    manifest["readback_sha256"] = subject.sha(capture / subject.CONTACT_READBACK)
                if mode == "engine_drift": (package / "Godot_v4.7-stable_win64.exe").write_bytes(b"different engine")
                (capture / subject.CONTACT_MANIFEST).write_bytes(subject.canonical(manifest))
                with self.assertRaises(RuntimeError): subject.verify_contact_capture(package, evidence, result, identity)

    def test_graphical_contact_refuses_rehashed_wrong_owner_and_native_facts(self):
        for mode in ("headless_display", "linux_capture", "wrong_renderer", "engine_version", "owner_failed", "fallback_owner",
                     "native_tick", "definition", "owner_runtime", "owner_sources", "executed_reaction", "stored_state", "resolver_roll"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                package, evidence, capture, identity, result, manifest, readback, _ = self.contact_fixture(Path(temporary))
                if mode == "headless_display": manifest["display"] = "headless"
                if mode == "linux_capture": manifest["platform"] = "Linux"
                if mode == "wrong_renderer": manifest["rendering_method"] = "dummy"
                if mode == "engine_version": manifest["engine"]["minor"] = 6
                if mode == "owner_failed": readback["owner"]["failed"] = True
                if mode == "fallback_owner": readback["owner"]["backend"] = "gdscript"
                if mode == "native_tick": readback["owner"]["native"]["tick"] = 1
                if mode == "definition": readback["owner"]["definition_hash"] = "c" * 64
                if mode == "owner_runtime": readback["owner"]["runtime_identity"]["native_sha256"] = "0" * 64
                if mode == "owner_sources": readback["owner"]["runtime_identity"]["script_sha256"] = {}
                if mode == "executed_reaction": readback["contact"]["reaction_executed"] = True
                if mode == "stored_state": readback["contact"]["target"]["state_a"] = 255
                if mode == "resolver_roll": readback["contact"]["resolver"]["probability_roll"] = 1
                (capture / subject.CONTACT_READBACK).write_bytes(subject.canonical(readback))
                manifest["readback_sha256"] = subject.sha(capture / subject.CONTACT_READBACK)
                (capture / subject.CONTACT_MANIFEST).write_bytes(subject.canonical(manifest))
                with self.assertRaises(RuntimeError): subject.verify_contact_capture(package, evidence, result, identity)

    def test_smoke_inventory_binds_nested_capture_and_readback_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            _, evidence, _, _, _, _, _, _ = self.contact_fixture(Path(temporary))
            report = evidence / "package-execution.json"
            report.write_bytes(b"not self-hashed")
            nested = evidence / "nested" / "package-execution.json"
            nested.parent.mkdir()
            nested.write_bytes(b"independent nested evidence")
            inventory = subject.smoke_evidence_files(evidence)
            self.assertNotIn("package-execution.json", inventory)
            self.assertIn("nested/package-execution.json", inventory)
            for name in (subject.CONTACT_MANIFEST, subject.CONTACT_READBACK, subject.CONTACT_IMAGE):
                relative = subject.CONTACT_DIRECTORY + "/" + name
                self.assertEqual(inventory[relative], subject.sha(evidence / relative))

    @unittest.skipUnless(os.name == "posix", "Portable symlink-copy negative is qualified on POSIX")
    def test_external_dependency_symlink_is_never_followed_into_delivery(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "private").write_text("do not copy")
            source = root / "dependency"
            source.mkdir()
            (source / "external").symlink_to(root / "private")
            with self.assertRaisesRegex(RuntimeError, "symlink"):
                subject.copy_portable_tree(source, root / "output")
            self.assertFalse((root / "output").exists())


if __name__ == "__main__":
    unittest.main()
