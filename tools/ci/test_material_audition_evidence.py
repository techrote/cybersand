#!/usr/bin/env python3
"""Adversarial custody controls; these fixtures are not native effect evidence."""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run_material_audition_qualification as subject
import package_material_audition_candidate as package


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="material-audition-evidence-test-")
        self.root = Path(self.temporary.name) / "source"
        self.root.mkdir()
        self.git("init", "-q")
        # Fixture construction and verification must use the same Git authority.
        # Windows' global autocrlf plus write_text's native CRLF otherwise make
        # this freshly committed synthetic repository dirty to the isolated guard.
        self.git("config", "--local", "core.autocrlf", "false")
        for relative in ("native/include/example.hpp", "native/src/example.cpp",
                         "godot/native_extension/example.cpp", "godot/scripts/example.gd",
                         "godot/tests/example.gd", "godot/feature_launcher.tscn",
                         "godot/shaders/example.gdshader", "godot/addons/example/example.gdextension",
                         "examples/worldgen/example.json",
                         "godot/addons/example/example.svg.import", "godot/addons/example/LICENSE",
                         "tools/web/example.mjs", "tools/example.patch", "tools/toolchains/g++",
                         "tools/package_materials_lab_candidate.py", "tools/ci/run_material_audition_qualification.py"):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"source fixture\n")
        self.git("add", ".")
        self.commit()
        self.runtime = Path(self.temporary.name) / "fixture-runtime.so"
        self.runtime.write_bytes(b"\x7fELFcustody fixture, never executed as a runtime")
        self.candidate = Path(self.temporary.name) / "candidate"
        self.identity = subject.record(self.root, "linux", self.runtime, self.candidate)

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *args):
        return subject.git(self.root, *args)

    def commit(self):
        return self.git("-c", "user.name=CustodyFixture", "-c", "user.email=fixture@example.invalid",
                        "commit", "-qm", "fixture")

    def rewrite_manifest(self, **updates):
        changed = copy.deepcopy(self.identity)
        changed.update(updates)
        subject.write(self.candidate / subject.MANIFEST, changed)

    def test_source_bound_candidate_roundtrip_does_not_claim_execution(self):
        restored = subject.verify(self.root, self.candidate, "linux")
        self.assertEqual(restored, self.identity)
        self.assertEqual(restored["status"], "built-not-executed")
        self.assertEqual(restored["source_commit"], self.git("rev-parse", "HEAD").decode().strip())
        self.assertIn("godot/scripts/example.gd", restored["execution_inputs"])

    def test_checkout_text_line_endings_preserve_cross_platform_source_identity(self):
        # Reproduce Git's Windows text materialization without weakening its
        # tracked-content check or normalizing executable/binary resources.
        self.git("config", "core.autocrlf", "true")
        for relative in self.identity["execution_inputs"]:
            path = self.root / relative
            path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
        self.assertEqual(subject.verify(self.root, self.candidate), self.identity)

    def test_existing_candidate_is_not_overwritten(self):
        before = (self.candidate / subject.MANIFEST).read_bytes()
        with self.assertRaisesRegex(ValueError, "immutable"):
            subject.record(self.root, "linux", self.runtime, self.candidate)
        self.assertEqual((self.candidate / subject.MANIFEST).read_bytes(), before)

    def test_actual_runtime_byte_change_refused(self):
        runtime = self.candidate / Path(subject.RUNTIMES["linux"]).name
        runtime.write_bytes(runtime.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "runtime bytes"):
            subject.verify(self.root, self.candidate)

    def test_wrong_platform_refused(self):
        with self.assertRaisesRegex(ValueError, "platform mismatch"):
            subject.verify(self.root, self.candidate, "windows")
        with self.assertRaisesRegex(ValueError, "declared platform"):
            subject.record(self.root, "windows", self.runtime, Path(self.temporary.name) / "wrong")

    def test_changed_source_commit_refused_even_with_equivalent_native_files(self):
        (self.root / "readme.txt").write_text("next source checkpoint")
        self.git("add", "readme.txt")
        self.commit()
        with self.assertRaisesRegex(ValueError, "source inputs"):
            subject.verify(self.root, self.candidate)

    def test_modified_host_script_refuses_before_receipt(self):
        (self.root / "godot/scripts/example.gd").write_text("dirty host")
        with self.assertRaises(subprocess.CalledProcessError):
            subject.verify(self.root, self.candidate)

    def test_modified_qualification_runner_refuses_before_receipt(self):
        (self.root / "tools/ci/run_material_audition_qualification.py").write_text("dirty runner")
        with self.assertRaises(subprocess.CalledProcessError):
            subject.source_identity(self.root)

    def test_dirty_entry_loader_shader_and_imported_helper_refused(self):
        for relative in ("godot/feature_launcher.tscn","godot/shaders/example.gdshader",
                         "godot/addons/example/example.gdextension","tools/package_materials_lab_candidate.py"):
            path = self.root / relative
            before = path.read_bytes()
            path.write_text("different execution authority\n")
            with self.subTest(relative=relative), self.assertRaises(subprocess.CalledProcessError):
                subject.verify(self.root,self.candidate)
            path.write_bytes(before)

    def test_relocated_source_custody_does_not_mutate_git_index(self):
        copied = Path(self.temporary.name) / "relocated source with spaces"
        shutil.copytree(self.root,copied)
        before = (copied / ".git/index").read_bytes()
        self.assertEqual(subject.verify(copied,self.candidate),self.identity)
        self.assertEqual(subject.verify(copied,self.candidate),self.identity)
        self.assertEqual((copied / ".git/index").read_bytes(),before)

    def test_untracked_host_implementation_refused(self):
        (self.root / "godot/scripts/extra.gd").write_text("untracked host")
        with self.assertRaisesRegex(ValueError, "Untracked implementation"):
            subject.verify(self.root, self.candidate)

    def test_godot_generated_resource_uid_sidecars_do_not_change_source(self):
        for relative in ("godot/scripts/example.gd", "godot/shaders/example.gdshader",
                         "godot/addons/example/example.gdextension"):
            (self.root / (relative + ".uid")).write_text("uid://generatedbygodot\n")
        self.assertEqual(subject.verify(self.root, self.candidate), self.identity)
        (self.root / "godot/scripts/unknown.uid").write_text("not a generated script sidecar\n")
        with self.assertRaisesRegex(ValueError, "Untracked implementation"):
            subject.verify(self.root, self.candidate)

    def test_generated_uid_exception_requires_tracked_resource_companion(self):
        for relative in ("godot/scripts/orphan.gd.uid", "godot/shaders/orphan.gdshader.uid",
                         "godot/addons/example/orphan.gdextension.uid"):
            path = self.root / relative
            path.write_text("uid://orphan\n")
            with self.subTest(relative=relative), self.assertRaisesRegex(ValueError, "Untracked implementation"):
                subject.verify(self.root, self.candidate)
            path.unlink()

    def test_generator_profile_source_is_bound_without_staged_duplicates(self):
        self.assertIn("examples/worldgen/example.json", self.identity["execution_inputs"])
        (self.root / "examples/worldgen/example.json").write_text("changed recipe")
        with self.assertRaises(subprocess.CalledProcessError):
            subject.verify(self.root, self.candidate)

    def test_manifest_artifact_path_cannot_escape_candidate(self):
        self.rewrite_manifest(artifact="../../other-runtime.so")
        with self.assertRaisesRegex(ValueError, "artifact path"):
            subject.verify(self.root, self.candidate)

    def test_manifest_source_inventory_tampering_refused(self):
        altered = copy.deepcopy(self.identity["native_inputs"])
        altered["native/src/example.cpp"] = "0" * 64
        self.rewrite_manifest(native_inputs=altered)
        with self.assertRaisesRegex(ValueError, "source inputs"):
            subject.verify(self.root, self.candidate)

    def test_frozen_toolchain_receipt_checked(self):
        toolchain = Path(self.temporary.name) / "compiler.txt"
        toolchain.write_text("compiler fixture")
        directory = Path(self.temporary.name) / "with-toolchain"
        subject.record(self.root, "linux", self.runtime, directory, toolchain)
        (directory / "toolchain.txt").write_text("different compiler")
        with self.assertRaisesRegex(ValueError, "toolchain receipt"):
            subject.verify(self.root, directory)

    def test_completion_requires_unique_explicit_nonzero_success(self):
        valid = 'RESULT {"checks":3,"failures":0,"status":"passed"}\n'
        self.assertEqual(subject.completion(valid, "RESULT")["checks"], 3)
        for text in ("", valid + valid, 'RESULT {"checks":0,"failures":0}',
                     'RESULT {"checks":true,"failures":0}', 'RESULT {"checks":3,"failures":false}',
                     'RESULT {"checks":3,"failures":1}', 'RESULT {"checks":3,"failures":0,"status":"running"}'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                subject.completion(text, "RESULT")

    def test_existing_native_summary_formats_are_supported(self):
        for value in ("3 assertions; 0 failures; artifacts=path", "3 assertions, 0 failures; readback", "3 checks, 0 failures"):
            self.assertEqual(subject.completion("RESULT " + value, "RESULT")["checks"], 3)

    def test_mounted_lab_receipt_is_distinct_from_full_isolated_ui_suite(self):
        marker = dict(subject.CASES)["test_material_lab_ui"]
        self.assertEqual(marker, "MATERIAL_LAB_WORKBENCH_MOUNT:")
        self.assertEqual(subject.completion(marker + " 24 assertions; 0 failures",marker)["checks"],24)
        with self.assertRaises(ValueError):
            subject.completion("MATERIAL_LAB_UI: 24 assertions; 0 failures",marker)

    def test_nonzero_process_preserves_original_failure_receipt(self):
        log = Path(self.temporary.name) / "nonzero.log"
        with self.assertRaisesRegex(ValueError, "Process failed"):
            subject.run_process([sys.executable, "-c", "print('RESULT {\"checks\":2,\"failures\":0}');raise SystemExit(7)"],
                                log, dict(os.environ), 30, "RESULT")
        receipt = json.loads(log.with_suffix(".receipt.json").read_text())
        self.assertEqual(receipt["exit_code"], 7)
        self.assertEqual(receipt["status"], "failed")
        self.assertEqual(receipt["log_sha256"], subject.sha(log))

    def test_parse_error_refused_despite_success_exit_and_marker(self):
        log = Path(self.temporary.name) / "parse-error.log"
        with self.assertRaisesRegex(ValueError, "Process failed"):
            subject.run_process([sys.executable, "-c", "print('SCRIPT ERROR: fixture');print('RESULT {\"checks\":2,\"failures\":0}')"],
                                log, dict(os.environ), 30, "RESULT")

    def test_timeout_kills_own_process_and_retains_failure(self):
        log = Path(self.temporary.name) / "timeout.log"
        with self.assertRaises(subprocess.TimeoutExpired):
            subject.run_process([sys.executable, "-c", "import time;print('started',flush=True);time.sleep(30)"],
                                log, dict(os.environ), 1)
        receipt = json.loads(log.with_suffix(".receipt.json").read_text())
        self.assertEqual(receipt["status"], "failed")
        self.assertNotEqual(receipt["exit_code"], 0)
        self.assertIn("started", log.read_text())

    def test_launcher_preserves_portable_tools_and_ordinary_workbench(self):
        text = package.launcher("a" * 40).decode()
        self.assertIn('-- --workbench', text)
        self.assertIn('set "GIT_DIR="', text)
        self.assertIn('set "PYTHONPATH="', text)
        self.assertIn('dependencies\\cxx\\bin', text)
        self.assertIn('opengl3_angle', text)
        self.assertNotIn('res://materials_lab.tscn', text)
        self.assertIn('res://materials_lab.tscn', package.launcher("a" * 40, laboratory=True).decode())

    def test_file_inventory_refuses_external_links(self):
        if os.name == "nt":
            self.skipTest("Windows symlink privileges differ; package verification still enforces the invariant")
        directory = Path(self.temporary.name) / "links"
        directory.mkdir()
        (directory / "external").symlink_to(self.runtime)
        with self.assertRaisesRegex(ValueError, "symlinks"):
            package.files(directory)

    def test_empty_or_missing_target_os_evidence_never_qualifies_package(self):
        directory = Path(self.temporary.name) / "empty-evidence"
        directory.mkdir()
        manifest=copy.deepcopy(self.identity)
        manifest.update(platform="windows",artifact=subject.RUNTIMES["windows"])
        result = {"schema": "cybersand.material-audition.execution", "status": "passed",
                  "platform": "windows", "graphical": True, "cases": [], "files_sha256": {},
                  "godot_version":subject.VERSION,"godot_sha256":"1"*64,
                  "candidate_sha256":__import__("hashlib").sha256(subject.canonical(manifest)).hexdigest(),
                  **{key: self.identity[key] for key in ("source_commit", "source_tree", "native_sha256")}}
        subject.write(directory / "execution.json", result)
        with self.assertRaisesRegex(ValueError, "omitted"):
            package.verified_execution(directory, manifest, graphical=True)
        result["platform"] = "linux"
        subject.write(directory / "execution.json", result)
        with self.assertRaisesRegex(ValueError, "Windows execution"):
            package.verified_execution(directory, manifest, graphical=True)

    def evidence_fixture(self):
        """Structurally complete synthetic guard fixture; no process is run."""
        directory = Path(self.temporary.name) / "synthetic evidence"
        directory.mkdir()
        (directory / "frames").mkdir()
        manifest = copy.deepcopy(self.identity)
        manifest.update(platform="windows",artifact=subject.RUNTIMES["windows"])
        marker = {"checks":3,"failures":0,"status":"passed","display":"synthetic-fixture",
                  "frames":[],"native_witnesses":[{"kind":kind} for kind in
                    ("density","viscosity","reaction","owner-adversaries","ordinary-workbench","ordinary-demo")]}
        def chunk(name,data):
            return struct.pack(">I",len(data))+name+data+struct.pack(">I",zlib.crc32(name+data))
        width,height=400,300
        png=b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,2,0,0,0))
        png+=chunk(b"IDAT",zlib.compress((b"\0"+b"\x80\x90\xa0"*width)*height))+chunk(b"IEND",b"")
        for name in ("current-scene-density","current-scene-1000x650","current-scene-1280x720",
                     "density-sorter","viscosity-channel","reaction-contact","industrial-loop"):
            path=directory / "frames" / (name+".png")
            path.write_bytes(png)
            marker["frames"].append({"name":name,"file":path.name,"width":width,"height":height,"sha256":subject.sha(path)})
        subject.write(directory / "frames/native-readback.json",marker)
        report={"schema":"cybersand.material-audition.execution","status":"passed","platform":"windows",
                "graphical":True,"godot_version":subject.VERSION,"godot_sha256":"1"*64,
                "candidate_sha256":__import__("hashlib").sha256(subject.canonical(manifest)).hexdigest(),"cases":[],
                **{key:manifest[key] for key in ("source_commit","source_tree","native_sha256")}}
        for name,prefix in (("import",None),*subject.CASES):
            completion=marker if name=="test_material_audition" else {"checks":3,"failures":0,"status":"passed"}
            log=directory / (name+".log")
            log.write_text("synthetic custody fixture; never executed\n"+(prefix+" "+json.dumps(completion)+"\n" if prefix else ""))
            receipt={"command":["synthetic-never-executed"],"timeout_seconds":1,"status":"passed","process_id":1,
                     "exit_code":0,"elapsed_seconds":0.1,"log_sha256":subject.sha(log)}
            if prefix: receipt["completion"]=completion
            subject.write(directory / (name+".receipt.json"),receipt)
            report["cases"].append({"name":name,**receipt})
        self.refresh_inventory(directory,report)
        return directory,manifest,report

    def refresh_inventory(self,directory,report):
        report["files_sha256"]={path.relative_to(directory).as_posix():subject.sha(path)
                                  for path in directory.rglob("*") if path.is_file() and path.name!="execution.json"}
        subject.write(directory / "execution.json",report)

    def test_structurally_complete_fixture_validates_without_execution_claim(self):
        directory,manifest,report=self.evidence_fixture()
        self.assertEqual(package.verified_execution(directory,manifest,graphical=True),report)

    def test_failed_original_process_cannot_be_promoted_by_summary(self):
        directory,manifest,report=self.evidence_fixture()
        path=directory / "test_material_audition.receipt.json"
        receipt=json.loads(path.read_text())
        receipt.update(status="failed",exit_code=7)
        subject.write(path,receipt)
        self.refresh_inventory(directory,report)
        with self.assertRaisesRegex(ValueError,"Original process receipt disagrees"):
            package.verified_execution(directory,manifest,graphical=True)

    def test_script_error_refused_even_when_all_hashes_and_summaries_match(self):
        directory,manifest,report=self.evidence_fixture()
        log=directory / "test_material_audition.log"
        log.write_text("SCRIPT ERROR: synthetic adversary\n"+log.read_text())
        case=next(case for case in report["cases"] if case["name"]=="test_material_audition")
        case["log_sha256"]=subject.sha(log)
        subject.write(directory / "test_material_audition.receipt.json",{key:value for key,value in case.items() if key!="name"})
        self.refresh_inventory(directory,report)
        with self.assertRaisesRegex(ValueError,"script errors"):
            package.verified_execution(directory,manifest,graphical=True)

    def test_wrong_engine_or_candidate_identity_refused(self):
        directory,manifest,report=self.evidence_fixture()
        for key in ("godot_version","candidate_sha256"):
            old=report[key]
            report[key]="wrong"
            self.refresh_inventory(directory,report)
            with self.subTest(key=key),self.assertRaises(ValueError):
                package.verified_execution(directory,manifest,graphical=True)
            report[key]=old
        self.refresh_inventory(directory,report)
        with self.assertRaisesRegex(ValueError,"engine byte identity"):
            package.verified_execution(directory,manifest,graphical=True,godot_digest="2"*64)

    def test_missing_frame_or_native_readback_cannot_claim_graphical_success(self):
        directory,manifest,report=self.evidence_fixture()
        raw=directory / "frames/native-readback.json"
        raw.unlink()
        self.refresh_inventory(directory,report)
        with self.assertRaisesRegex(ValueError,"native graphical readback"):
            package.verified_execution(directory,manifest,graphical=True)

    def test_headless_completion_cannot_claim_graphical_success(self):
        directory,manifest,report=self.evidence_fixture()
        case=next(case for case in report["cases"] if case["name"]=="test_material_audition")
        case["completion"]["display"]="headless"
        log=directory / "test_material_audition.log"
        log.write_text("MATERIAL_AUDITION_RESULT "+json.dumps(case["completion"])+"\n")
        case["log_sha256"]=subject.sha(log)
        subject.write(directory / "test_material_audition.receipt.json",{key:value for key,value in case.items() if key!="name"})
        subject.write(directory / "frames/native-readback.json",case["completion"])
        self.refresh_inventory(directory,report)
        with self.assertRaisesRegex(ValueError,"headless display"):
            package.verified_execution(directory,manifest,graphical=True)


if __name__ == "__main__":
    unittest.main()
