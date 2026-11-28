#!/usr/bin/env python3
"""Metadata/adversarial tests only; synthetic PEs never qualify a runtime."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("playability_package", HERE / "package_windows.py")
package = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(package)


def put(root, name, data):
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data.encode() if isinstance(data, str) else data)
    return path


def pe(marker):
    data = bytearray(512)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3c, 128)
    data[128:134] = b"PE\0\0\x64\x86"
    data[256:256+len(marker)] = marker.encode()
    return bytes(data)


def save(root, record):
    record["files_sha256"] = package.file_hashes(root)
    record["file_count"] = len(record["files_sha256"])
    package.write_json(root / package.MANIFEST, record)
    put(root, package.MANIFEST + ".sha256", f"{package.digest(root / package.MANIFEST)}  {package.MANIFEST}\n")


def fixture(root, completion=False):
    """Distinct source closures/DLLs with one shared synthetic toolchain."""
    put(root, package.BUILD_DRIVER, "synthetic build driver\n")
    for name in package.dependency_custody.DRIVER_FILES[1:]:
        put(root, str(Path(package.BUILD_DRIVER).parent / name), "synthetic driver module " + name + "\n")
    drivers = {name: package.digest(root / Path(package.BUILD_DRIVER).parent / name)
               for name in package.dependency_custody.DRIVER_FILES}
    toolchain = {"godot_cpp_commit": package.dependency_custody.REVISION, "godot_cpp_library_sha256": "e"*64,
                 "compiler_command": "synthetic-c++", "compiler_version": "fixture-only",
                 "toolchain_drift_allowed": False}
    sources = {}
    source_keys = ("M", "I", "C", "D") if completion else ("M", "I", "C")
    for index, key in enumerate(source_keys, 1):
        prefix = "sources/" + key
        put(root, prefix + "/godot/addons/godot-rapier2d/Radial2D.svg.import",
            '[remap]\nimporter="texture"\n[params]\ncompress/mode=0\n')
        inputs = {}
        for name in ("native/include/world.hpp", "native/src/world.cpp", "godot/native_extension/bridge.cpp"):
            path = put(root, prefix + "/" + name, key + "/" + name + "\n")
            inputs[name] = package.canonical_digest(path.read_bytes())
        if key == "C":
            name = "native/include/candidate_only.hpp"
            inputs[name] = package.canonical_digest(put(root, prefix + "/" + name, "extra candidate closure\n").read_bytes())
        build_script = "tools/build_native_extension_windows.sh"
        put(root, prefix + "/" + build_script, "synthetic script " + key + "\n")
        dll = put(root, prefix + "/" + package.NATIVE, pe(key))
        log = put(root, prefix + "/provenance/build.log", "synthetic complete " + key + "\n")
        source, tree = str(index)*40, str(index+3)*40
        if completion and key in package.COMPLETION_REFERENCES:
            pinned = package.COMPLETION_REFERENCES[key]
            source, tree = pinned["source_commit"], pinned["source_tree"]
        dependency_log = put(root, prefix + "/provenance/GODOT-CPP-BUILD.log", "synthetic dependency build\n")
        dependency_script = put(root, prefix + "/provenance/GODOT-CPP-BUILD.sh", "synthetic dependency builder\n")
        dependency_helper = put(root, prefix + "/provenance/GODOT-CPP-CXX.sh", "synthetic dependency helper\n")
        dependency = {"schema": "pubpres-godot-cpp-dependency-v1", "platform": "windows",
                      "source_commit": toolchain["godot_cpp_commit"], "source_tree": "a"*40,
                      "builder_commit": "3"*40, "library_sha256": toolchain["godot_cpp_library_sha256"],
                      "builder_inputs_sha256": {"tools/build_pinned_godot_cpp.sh": package.digest(dependency_script),
                                                "tools/toolchains/g++": package.digest(dependency_helper)},
                      "source_inputs_sha256": {name: "b"*64 for name in sorted(package.dependency_custody.REQUIRED)},
                      "build_log_sha256": package.digest(dependency_log), "build_script_sha256": package.digest(dependency_script),
                      "command": "Pinned godot-cpp windows build command: synthetic fixture"}
        dependency_path = root / prefix / "provenance/GODOT-CPP-DEPENDENCY.json"
        package.write_json(dependency_path, dependency)
        toolchain["godot_cpp_dependency_sha256"] = package.digest(dependency_path)
        native = {"schema": "pubpres-playability-native-build-v1", "platform": "windows", "source_commit": source,
                  "source_tree": tree, "runtime_file": Path(package.NATIVE).name, "runtime_sha256": package.digest(dll),
                  "runtime_bytes": dll.stat().st_size, "source_inputs_sha256": inputs, "build_script": build_script,
                  "build_script_sha256": package.canonical_digest((root / prefix / build_script).read_bytes()),
                  "log_sha256": package.digest(log), "driver_sha256": package.digest(root / package.BUILD_DRIVER),
                  "driver_inputs_sha256": drivers,
                  "returncode": 0, "production_runtime_promotion": False, **toolchain}
        receipt = prefix + "/provenance/" + package.RUNTIME_RECEIPT
        package.write_json(root / receipt, native)
        rapier_dll = put(root, prefix + "/" + package.RAPIER, pe("retained Rapier"))
        rapier_input = "third_party/rapier-runtime.lock.json"
        rapier_inputs = {rapier_input: package.canonical_digest(put(root, prefix + "/" + rapier_input, "rapier lock\n").read_bytes())}
        package.write_json(root / prefix / package.RAPIER_RECEIPT,
                           {"artifact": package.RAPIER, "sha256": package.digest(rapier_dll),
                            "size": rapier_dll.stat().st_size, "source_inputs": rapier_inputs})
        package.write_json(root / prefix / package.NATIVE_RECEIPT,
                           {"source_commit": source, "sha256": native["runtime_sha256"], "source_inputs": inputs,
                            "build_receipt": receipt, "build_receipt_sha256": package.digest(root / receipt),
                            "production_runtime_promotion": False})
        sources[key] = {"source_commit": source, "source_tree": tree, "root": prefix, "project": prefix + "/godot",
                        "native": {"path": prefix + "/" + package.NATIVE, "sha256": native["runtime_sha256"],
                                   "bytes": native["runtime_bytes"], "receipt": receipt,
                                   "receipt_sha256": package.digest(root / receipt), "source_input_count": len(inputs)},
                        "rapier": {"path": prefix + "/" + package.RAPIER, "sha256": package.digest(rapier_dll),
                                   "bytes": rapier_dll.stat().st_size, "receipt": prefix + "/" + package.RAPIER_RECEIPT},
                        "toolchain": copy.deepcopy(toolchain), "features": package.source_features(key)}
    engine = {"version": package.GODOT_VERSION, "archive_sha512": package.GODOT_SHA512}
    for label, name in (("gui", package.GUI), ("console", package.CONSOLE)):
        engine[label] = {"path": name, "sha256": package.digest(put(root, name, pe(label)))}
    vc = {name: package.digest(put(root, name, pe("vc") if name.endswith(".dll") else "synthetic license\n")) for name in package.VC_FILES}
    package.write_json(root / "vc-runtime-provenance.json", {"schema": 1, "files_sha256": vc, "authenticode": {"status": "Valid"}})
    engine["vc_runtime_sha256"] = vc["vcruntime140.dll"]
    observer = put(root, "sources/C/godot/tests/observer.gd", "extends SceneTree\n")
    campaign = package.LEGACY_REGISTRATION
    (root / campaign).parent.mkdir(parents=True)
    package.write_json(root / campaign, {"schema": "pubpres-playability-campaign-v3",
                      "source_commits": {"main": sources["M"]["source_commit"], "integration": sources["I"]["source_commit"]},
                      "overlay_sha256": {"tests/observer.gd": package.digest(observer)}})
    put(root, package.TOOLS + "/Start-PUBPRES-Playability.ps1", "# synthetic owner launcher\n")
    put(root, package.TOOLS + "/owner_start.gd", "extends SceneTree\n")
    candidate = sources["C"]["source_commit"]
    mission = package.COMPLETION_MISSION if completion else package.LEGACY_MISSION
    if completion:
        source_root = HERE.parents[1]
        predecessor = source_root / package.LEGACY_REGISTRATION
        put(root, package.LEGACY_REGISTRATION, predecessor.read_bytes())
        for name in json.loads(predecessor.read_bytes())["overlay_sha256"]:
            put(root, "sources/C/godot/" + name, (source_root / "godot" / name).read_bytes())
        campaign = package.COMPLETION_REGISTRATION
        put(root, campaign, (source_root / campaign).read_bytes())
        put(root, package.OWNER_COMMAND, package.owner_command(candidate))
        put(root, package.OWNER_RESULTS_COMMAND, package.owner_results_command(candidate))
        put(root, package.OWNER_RESULTS_COLLECTOR, "# synthetic result collector\n")
        put(root, package.OWNER_ACCEPTANCE_SOURCE, "# Synthetic acceptance instructions\n")
        put(root, package.OWNER_ACCEPTANCE, (root / package.OWNER_ACCEPTANCE_SOURCE).read_bytes())
    record = {"schema": package.COMPLETION_SCHEMA if completion else package.SCHEMA,
              "mission": mission, "candidate_commit": candidate, "sources": sources, "engine": engine,
              "package_filename": "CyberSand-" + mission + "-" + candidate[:12] + "-Windows.zip",
              "campaign": campaign, "campaign_sha256": package.digest(root / campaign),
              "owner_launcher": package.TOOLS + "/Start-PUBPRES-Playability.ps1", "owner_observer": package.TOOLS + "/owner_start.gd",
              "physical_acceptance": "HOLD", "production_defaults_changed": False,
              "experimental_defaults": {"staging_pools": "eager", "render_thread": "safe", "wave_column_tiles": False, "same_frame_continuation": "off"}}
    if completion:
        record["owner_command"] = package.OWNER_COMMAND
        record["owner_material"] = "full"
        record["owner_results_command"] = package.OWNER_RESULTS_COMMAND
        record["owner_results_collector"] = package.OWNER_RESULTS_COLLECTOR
        record["owner_acceptance"] = package.OWNER_ACCEPTANCE
    save(root, record)
    return record


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.manifest = fixture(self.root)
        self.candidate = self.manifest["candidate_commit"]

    def tearDown(self):
        self.temp.cleanup()

    def check_bad(self, pattern):
        with self.assertRaisesRegex(ValueError, pattern):
            package.verify(self.root, self.candidate)

    def native(self, key):
        path = self.root / self.manifest["sources"][key]["native"]["receipt"]
        return path, json.loads(path.read_text())

    def rewrite_native(self, key, receipt):
        source = self.manifest["sources"][key]
        path = self.root / source["native"]["receipt"]
        package.write_json(path, receipt)
        source["native"]["receipt_sha256"] = package.digest(path)
        save(self.root, self.manifest)

    def test_distinct_native_source_closures_are_valid(self):
        verified = package.verify(self.root, self.candidate)
        self.assertEqual([verified["sources"][k]["native"]["source_input_count"] for k in ("M", "I", "C")], [3, 3, 4])
        self.assertEqual(len({verified["sources"][k]["native"]["sha256"] for k in ("M", "I", "C")}), 3)

    def test_corrupted_dll_is_rejected(self):
        put(self.root, self.manifest["sources"]["C"]["native"]["path"], pe("corrupt"))
        self.check_bad("Changed package file")

    def test_unexpected_stale_file_is_rejected(self):
        put(self.root, "old-evaluator.txt", "stale")
        self.check_bad("unexpected files")

    def test_changed_import_descriptor_is_rejected(self):
        put(self.root, "sources/C/godot/addons/godot-rapier2d/Radial2D.svg.import",
            '[remap]\nimporter="texture"\n[params]\ncompress/mode=1\n')
        self.check_bad("Changed package file")

    def test_nested_manifest_name_is_not_exempt(self):
        put(self.root, "unlisted/" + package.MANIFEST, "shadow")
        self.check_bad("unexpected files")

    def test_directory_symlink_cannot_expand_inventory(self):
        target = self.root / "sources/C"
        try:
            (self.root / "linked-source").symlink_to(target, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("Host does not permit creating symlinks")
        self.check_bad("links/reparse")

    def test_wrong_expected_source_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "candidate/schema"):
            package.verify(self.root, "9"*40)

    def test_cross_source_dll_path_is_rejected(self):
        self.manifest["sources"]["M"]["native"] = copy.deepcopy(self.manifest["sources"]["C"]["native"])
        save(self.root, self.manifest)
        self.check_bad("path substitution")

    def test_cross_source_receipt_is_rejected_after_rehash(self):
        _, receipt = self.native("C")
        self.rewrite_native("M", receipt)
        self.check_bad("receipt substitution")

    def test_unlisted_native_input_is_rejected_after_rehash(self):
        put(self.root, "sources/C/native/src/extra.cpp", "unlisted")
        save(self.root, self.manifest)
        self.check_bad("closure set differs")

    def test_omitted_existing_native_input_is_rejected_after_rehash(self):
        _, receipt = self.native("C")
        receipt["source_inputs_sha256"].pop("native/include/candidate_only.hpp")
        self.manifest["sources"]["C"]["native"]["source_input_count"] -= 1
        self.rewrite_native("C", receipt)
        self.check_bad("closure set differs")

    def test_changed_native_input_is_rejected_after_rehash(self):
        put(self.root, "sources/M/native/src/world.cpp", "changed")
        save(self.root, self.manifest)
        self.check_bad("native source differs")

    def test_changed_build_log_is_rejected_after_rehash(self):
        put(self.root, "sources/I/provenance/build.log", "wrong log")
        save(self.root, self.manifest)
        self.check_bad("build log differs")

    def test_changed_build_driver_is_rejected_after_rehash(self):
        put(self.root, package.BUILD_DRIVER, "wrong driver")
        save(self.root, self.manifest)
        self.check_bad("build driver differs")

    def test_promoted_runtime_is_rejected_after_rehash(self):
        _, receipt = self.native("C")
        receipt["production_runtime_promotion"] = True
        self.rewrite_native("C", receipt)
        self.check_bad("promotion")

    def test_toolchain_mismatch_is_rejected_after_rehash(self):
        self.manifest["sources"]["I"]["toolchain"]["compiler_command"] = "different"
        save(self.root, self.manifest)
        self.check_bad("Toolchain receipt")

    def test_changed_rapier_source_is_rejected_after_rehash(self):
        put(self.root, "sources/C/third_party/rapier-runtime.lock.json", "different")
        save(self.root, self.manifest)
        self.check_bad("Rapier source differs")

    def test_stale_runtime_observation_provenance_is_rejected_after_rehash(self):
        path = self.root / "sources/C" / package.NATIVE_RECEIPT
        record = json.loads(path.read_text())
        record["source_commit"] = "0"*40
        package.write_json(path, record)
        save(self.root, self.manifest)
        self.check_bad("stale or misleading")

    def test_rejected_wave_feature_is_rejected_after_rehash(self):
        self.manifest["sources"]["C"]["features"]["wave_column_tiles"] = True
        save(self.root, self.manifest)
        self.check_bad("feature advertisement")

    def test_historical_source_cannot_claim_new_continuation(self):
        self.manifest["sources"]["M"]["features"]["same_frame_continuation"] = True
        save(self.root, self.manifest)
        self.check_bad("feature advertisement")

    def test_new_continuation_cannot_be_a_package_default(self):
        self.manifest["experimental_defaults"]["same_frame_continuation"] = "on"
        save(self.root, self.manifest)
        self.check_bad("defaults or owner hold")

    def test_v1_package_is_not_reinterpreted_as_v2(self):
        self.manifest["schema"] = "pubpres-playability-windows-v1"
        save(self.root, self.manifest)
        self.check_bad("candidate/schema")

    def test_wrong_historical_package_name_is_rejected(self):
        self.manifest["package_filename"] = "CyberSand-SWARM005-Windows.zip"
        save(self.root, self.manifest)
        self.check_bad("evaluator filename")

    def test_engine_entrypoint_substitution_is_rejected(self):
        self.manifest["engine"]["gui"]["path"] = package.CONSOLE
        save(self.root, self.manifest)
        self.check_bad("Pinned engine")

    def test_changed_observer_registration_is_rejected(self):
        put(self.root, "sources/C/godot/tests/observer.gd", "changed observer")
        save(self.root, self.manifest)
        self.check_bad("observer overlay differs")

    def test_non_x64_binary_is_rejected(self):
        path = put(self.root, "not-x64.dll", b"wrong")
        with self.assertRaisesRegex(ValueError, "Not a Windows PE"):
            package.pe_x64(path)

    def test_windows_safe_paths(self):
        self.assertEqual(str(package.safe_name("directory with spaces/source.gd")), "directory with spaces/source.gd")
        for name in ("../bad", "/bad", "a//b", "a/./b", "a\\b", "x:y", "a/CON.txt", "a/lpt1", "a/trailing.", "a/trailing ", "a\x00b"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                package.safe_name(name)

    def test_canonical_lf_source_hashes_match(self):
        self.assertEqual(package.canonical_digest(b"a\r\nb\r\n"), package.canonical_digest(b"a\nb\n"))


class SourceArchiveTests(unittest.TestCase):
    def test_windows_git_eol_settings_preserve_reopen_source_bytes(self):
        # Exercise Git itself: the historical M/I source has no .import rule,
        # while the candidate carries the explicit portable source attribute.
        # The owner can reopen all three exported projects without weakening
        # any hash check or normalizing a possibly altered run after import.
        historical = b"* text=auto\n*.ps1 text eol=crlf\n"
        current = (HERE.parents[1] / ".gitattributes").read_bytes()
        for label, attributes in (("historical", historical), ("candidate", current)):
            with self.subTest(source=label), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary) / "repository"
                root.mkdir()
                def git(*arguments):
                    return subprocess.check_output(["git", "-C", str(root), *arguments], stderr=subprocess.PIPE)
                git("init", "-q", "--initial-branch=fixture")
                git("config", "core.autocrlf", "false")
                put(root, ".gitattributes", attributes)
                descriptor = b'[remap]\nimporter="texture"\n[params]\ncompress/mode=0\n'
                name = "godot/addons/godot-rapier2d/Radial2D.svg.import"
                put(root, name, descriptor)
                put(root, "launch.ps1", b"# explicit source attribute\n")
                binary = b"\x00binary\r\n\xff"
                put(root, "asset.bin", binary)
                git("add", ".")
                git("-c", "user.name=PUBPRES archive regression", "-c",
                    "user.email=archive-test@example.invalid", "commit", "-qm", "fixture")
                source = git("rev-parse", "HEAD").decode().strip()
                git("config", "core.autocrlf", "true")
                git("config", "core.eol", "crlf")
                output = Path(temporary) / "archive"
                output.mkdir()
                package.archive_source(root, source, output, [name, "launch.ps1", "asset.bin"])
                self.assertEqual((output / name).read_bytes(), descriptor)
                self.assertEqual((output / "launch.ps1").read_bytes(), b"# explicit source attribute\r\n")
                self.assertEqual((output / "asset.bin").read_bytes(), binary)


class CompletionPackageTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.manifest = fixture(self.root, completion=True)
        self.candidate = self.manifest["candidate_commit"]
        mock_engine_pins = {record["path"]: record["sha256"]
                            for record in (self.manifest["engine"]["gui"], self.manifest["engine"]["console"])}
        patch = mock.patch.object(package, "GODOT_EXECUTABLE_SHA256", mock_engine_pins)
        patch.start()
        self.addCleanup(patch.stop)

    def verify(self):
        return package.verify(self.root, self.candidate)

    def test_all_four_sources_and_the_exact_owner_command(self):
        record = self.verify()
        self.assertEqual(set(record["sources"]), {"M", "I", "D", "C"})
        command = (self.root / package.OWNER_COMMAND).read_bytes()
        self.assertIn(b"-Action Open -OwnerProfile", command)
        self.assertIn(self.candidate.encode("ascii"), command)
        collector = (self.root / package.OWNER_RESULTS_COMMAND).read_bytes()
        self.assertIn(b"-PackageRoot", collector)
        self.assertIn(self.candidate.encode("ascii"), collector)

    def test_missing_donor_fails_even_with_valid_file_inventory(self):
        shutil.rmtree(self.root / "sources/D")
        self.manifest["sources"].pop("D")
        save(self.root, self.manifest)
        with self.assertRaisesRegex(ValueError, "Missing independent source projects"):
            self.verify()

    def test_changed_owner_command_fails_after_rehash(self):
        put(self.root, package.OWNER_COMMAND, "@echo off\r\nexit /b 0\r\n")
        save(self.root, self.manifest)
        with self.assertRaisesRegex(ValueError, "Owner Windows command differs"):
            self.verify()

    def test_changed_results_command_or_acceptance_fails_after_rehash(self):
        for name in (package.OWNER_RESULTS_COMMAND, package.OWNER_ACCEPTANCE):
            with self.subTest(name=name):
                previous = (self.root / name).read_bytes()
                put(self.root, name, "changed\n")
                save(self.root, self.manifest)
                with self.assertRaisesRegex(ValueError, "Owner acceptance or result collection entrypoint differs"):
                    self.verify()
                put(self.root, name, previous)
                save(self.root, self.manifest)

    def test_changed_pinned_engine_fails_after_rehash(self):
        path = put(self.root, package.GUI, pe("another engine"))
        self.manifest["engine"]["gui"]["sha256"] = package.digest(path)
        save(self.root, self.manifest)
        with self.assertRaisesRegex(ValueError, "engine bytes differ from pin"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
