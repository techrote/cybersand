"""Reproduce M4's renamed-ledger defect without claiming synthetic gameplay."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import qualify_workbench as qualifier
import reciprocal_windows_package as reciprocal
import verify_workbench_package as verifier


class DeliveredProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / "Workbench (1)"
        self.root.mkdir()
        self.source = {verifier.RETAINED_PROVENANCE: b'{"old_retained_runtime": "reference only"}\n',
                       "godot/scripts/main.gd": b"# synthetic committed script\n",
                       "godot/project.godot": b"; synthetic project\n"}
        self.expected = {}
        for name, value in self.source.items():
            shipped = verifier.RETAINED_REFERENCE if name == verifier.RETAINED_PROVENANCE else name
            path = self.root / shipped
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(value)
            self.expected[name] = verifier.digest(path)
        self.engine = self.root / "Godot_v4.7-stable_win64_console.exe"
        self.engine.write_bytes(b"synthetic engine identity; never executed")
        self.manifest = {"godot": {"console_sha256": verifier.digest(self.engine)}}

    def test_old_blanket_path_loop_reproduces_original_zero_case_failure(self):
        # Original qualifier's exact assumption. Packaging intentionally moved
        # this old ledger; inventing a second active ledger is the wrong repair.
        with self.assertRaises(FileNotFoundError):
            for relative in self.expected:
                verifier.digest(self.root / relative)
        self.assertFalse((self.root / verifier.RETAINED_PROVENANCE).exists())
        locations = verifier.verify_committed_godot_inputs(self.root, self.expected)
        self.assertEqual(locations[verifier.RETAINED_PROVENANCE], verifier.RETAINED_REFERENCE)

    def test_relocated_roots_spaces_parentheses_unicode_and_nested(self):
        for name in ("Workbench evaluation with spaces", "Workbench (2)", "Workbench_日本語_é", "nested/new root/Workbench"):
            with self.subTest(name=name):
                relocated = self.base / name
                shutil.copytree(self.root, relocated)
                locations = verifier.verify_committed_godot_inputs(relocated, self.expected)
                self.assertEqual(set(locations), set(self.expected))
                selected = qualifier.verify_packaged_engine(relocated, relocated / self.engine.name, self.manifest)
                self.assertTrue(selected.is_relative_to(relocated.resolve()))

    def test_missing_reference_cannot_fall_back_to_a_checkout_or_old_filename(self):
        (self.root / verifier.RETAINED_REFERENCE).unlink()
        with self.assertRaisesRegex(ValueError, "Missing or external"):
            verifier.verify_committed_godot_inputs(self.root, self.expected)
        (self.root / verifier.RETAINED_PROVENANCE).write_bytes(self.source[verifier.RETAINED_PROVENANCE])
        with self.assertRaisesRegex(ValueError, "Active retained runtime provenance"):
            verifier.verify_committed_godot_inputs(self.root, self.expected)

    def test_incorrect_stale_and_tampered_reference_remain_failures(self):
        path = self.root / verifier.RETAINED_REFERENCE
        for content in (b'{}', b'{"old_retained_runtime": "a different historical source"}\n', path.read_bytes() + b"tamper"):
            with self.subTest(content=content):
                path.write_bytes(content)
                with self.assertRaisesRegex(ValueError, "Packaged Godot source differs"):
                    verifier.verify_committed_godot_inputs(self.root, self.expected)

    def test_other_json_and_scripts_do_not_receive_a_provenance_exception(self):
        for relative in ("godot/scripts/main.gd", "godot/another-provenance.json"):
            path = self.root / relative
            path.write_bytes(b"committed bytes")
            expected = {**self.expected, relative: verifier.digest(path)}
            path.write_bytes(b"changed bytes")
            with self.assertRaisesRegex(ValueError, "Packaged Godot source differs"):
                verifier.verify_committed_godot_inputs(self.root, expected)

    def test_missing_source_ledger_and_external_reference_are_refused(self):
        expected = {p: d for p, d in self.expected.items() if p != verifier.RETAINED_PROVENANCE}
        with self.assertRaisesRegex(ValueError, "absent from source custody"):
            verifier.verify_committed_godot_inputs(self.root, expected)
        path = self.root / verifier.RETAINED_REFERENCE
        external = self.base / "external-reference.json"
        external.write_bytes(path.read_bytes())
        path.unlink()
        try:
            path.symlink_to(external)
        except OSError:
            self.skipTest("Host does not permit symlink fixtures")
        with self.assertRaisesRegex(ValueError, "Missing or external"):
            verifier.verify_committed_godot_inputs(self.root, self.expected)

    def test_external_engine_is_refused_even_when_its_bytes_match(self):
        external = self.base / self.engine.name
        external.write_bytes(self.engine.read_bytes())
        with self.assertRaisesRegex(ValueError, "shipped console engine"):
            qualifier.verify_packaged_engine(self.root, external, self.manifest)
        self.engine.write_bytes(b"tampered package engine")
        with self.assertRaisesRegex(ValueError, "shipped console engine"):
            qualifier.verify_packaged_engine(self.root, self.engine, self.manifest)

    def test_real_qualifier_preflight_reaches_case_execution_with_renamed_ledger(self):
        # Only orchestration is exercised. Neither the synthetic engine nor a
        # DLL executes, and this failed fixture report is not platform evidence.
        source, tree, native_inputs = "1" * 40, "2" * 40, {"native/src/example.cpp": "3" * 64}
        manifest = {**self.manifest, "source_commit": source, "source_tree": tree,
                    "native": {"source_inputs": native_inputs}}
        (self.root / verifier.MANIFEST).write_text(json.dumps(manifest))
        cli = b"fixture executable"
        binding = json.dumps({"platform": "windows", "artifact": reciprocal.WINDOWS_CLI,
                              "bytes": len(cli), "sha256": hashlib.sha256(cli).hexdigest()}).encode()
        (self.root / reciprocal.WINDOWS_CLI).parent.mkdir(parents=True, exist_ok=True)
        (self.root / reciprocal.WINDOWS_CLI).write_bytes(cli)
        (self.root / reciprocal.WINDOWS_BINDING).write_bytes(binding)
        native_path, rapier_path = self.root / "native.dll", self.root / "rapier.dll"
        native_path.write_bytes(b"synthetic native identity")
        rapier_path.write_bytes(b"synthetic Rapier identity")
        args = argparse.Namespace(output=self.base / "fixture-report", expected_source_sha=source,
                                  package=self.root, godot=self.engine, native_candidate=None,
                                  native_receipt=None, render=False, regressions=False, profile=False)
        with patch.object(qualifier.sys, "platform", "win32"), \
                patch.object(qualifier.native, "source", return_value=(source, tree, native_inputs)), \
                patch.object(qualifier, "committed_inputs", return_value=self.expected), \
                patch.object(reciprocal, "committed_binding", return_value=binding), \
                patch.object(verifier, "verify", return_value=manifest), \
                patch.object(qualifier.runner, "runtime_paths", return_value=(native_path, rapier_path)), \
                patch.dict(qualifier.RAPIER_HASHES, {"win32": verifier.digest(rapier_path)}), \
                patch.object(qualifier.subprocess, "check_output", return_value=qualifier.VERSION), \
                patch.object(qualifier, "run_observed_case", side_effect=RuntimeError("fixture stops before engine execution")) as run:
            report = qualifier.qualify(args)
        self.assertEqual(report["failures"], ["fixture stops before engine execution"])
        self.assertEqual(len(run.call_args_list), 1)
        self.assertEqual(run.call_args.args[1], str(self.engine.resolve()))
        self.assertEqual(report["packaged_godot_input_locations"][verifier.RETAINED_PROVENANCE], verifier.RETAINED_REFERENCE)


class CandidateLedgerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name, content in ((verifier.NATIVE, b"MZ synthetic PE fixture, never executed"),
                              ("native/src/example.cpp", b"// synthetic committed source\n")):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        native_file = self.root / verifier.NATIVE
        inputs = {"native/src/example.cpp": verifier.digest(self.root / "native/src/example.cpp")}
        self.candidate = {"schema_version": 1, "kind": "source-built-windows-candidate", "artifact": verifier.NATIVE,
                          "source_commit": "1" * 40, "build_commit": "1" * 40, "source_tree": "2" * 40,
                          "sha256": verifier.digest(native_file), "size": native_file.stat().st_size,
                          "source_inputs": inputs}
        self.manifest = {"source_commit": "1" * 40, "source_tree": "2" * 40,
                         "native": {"source_inputs": inputs},
                         "files_sha256": {verifier.NATIVE: verifier.digest(native_file), **inputs}}
        self.write()

    def write(self, delta=None):
        (self.root / verifier.CANDIDATE_PROVENANCE).write_text(json.dumps({**self.candidate, **(delta or {})}))

    def test_complete_synthetic_candidate_contract(self):
        verifier.verify_candidate(self.root, self.manifest)

    def test_wrong_schema_kind_artifact_size_or_retained_manifest_are_refused(self):
        for delta in ({"schema_version": True}, {"schema_version": 2}, {"kind": "retained-runtime"},
                      {"artifact": "external.dll"}, {"size": True}, {"size": 1}):
            with self.subTest(delta=delta):
                self.write(delta)
                with self.assertRaisesRegex(ValueError, "provenance contract mismatch"):
                    verifier.verify_candidate(self.root, self.manifest)

    def test_stale_source_tree_build_and_native_digest_are_refused(self):
        for key in ("source_commit", "source_tree", "build_commit", "sha256"):
            with self.subTest(key=key):
                self.write({key: "9" * (64 if key == "sha256" else 40)})
                with self.assertRaises(ValueError):
                    verifier.verify_candidate(self.root, self.manifest)

    def test_missing_provenance_source_drift_and_non_pe_are_refused(self):
        (self.root / verifier.CANDIDATE_PROVENANCE).unlink()
        with self.assertRaisesRegex(ValueError, "Missing or external"):
            verifier.verify_candidate(self.root, self.manifest)
        self.write()
        source = self.root / "native/src/example.cpp"
        source.write_bytes(b"changed source")
        with self.assertRaisesRegex(ValueError, "Native source differs"):
            verifier.verify_candidate(self.root, self.manifest)
        binary = self.root / verifier.NATIVE
        binary.write_bytes(b"NO" + binary.read_bytes()[2:])
        with self.assertRaisesRegex(ValueError, "Windows PE runtime"):
            verifier.verify_candidate(self.root, self.manifest)


if __name__ == "__main__":
    unittest.main()
