"""Focused contract tests for the extracted linker evidence auditor."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import extracted_linker_audit as audit


class Fixture:
    def __init__(self, root: Path):
        self.root = root
        self.installation = root / "install"
        self.output = root / "output"
        self.installation.mkdir()
        self.output.mkdir()
        self.source = self.installation / "source"
        self.cxx = self.installation / "dependencies/cxx"
        self._files: dict[str, str] = {}
        self.source_file = self.source / "tools/material_catalogue/lab.py"
        self.source_file.parent.mkdir(parents=True)
        self.source_bytes = b"int source;\r\n"
        self.source_file.write_bytes(self.source_bytes)
        self._files["source/tools/material_catalogue/lab.py"] = hashlib.sha256(self.source_bytes).hexdigest()
        ci = self.source / "tools/ci"
        ci.mkdir(parents=True)
        self._add("source/tools/ci/portable_lld.py", b"# verified pinned reader\n")
        self._add("source/tools/ci/portable_compiler_utf8.py", b"# verified GNU reader\n")
        self.compiler_bytes = b"verified g++ fixture"
        self._add("dependencies/cxx/bin/g++.exe", self.compiler_bytes)
        self.compiler_marker_bytes = b'{"schema":"compiler-marker"}\n'
        self._add("dependencies/cxx/CYBERSAND-COMPILER-UTF8.json", self.compiler_marker_bytes)
        self.linker_marker_bytes = b'{"schema":"linker-marker"}\n'
        self._add("dependencies/cxx/CYBERSAND-PORTABLE-LINKER.json", self.linker_marker_bytes)
        self.lld_bytes = b"verified lld fixture"
        self._add("dependencies/cxx/bin/ld.lld.exe", self.lld_bytes)
        self.license_bytes = b"LLVM-MinGW license notice\n"
        self._add("dependencies/cxx/licenses/llvm-mingw/LICENSE.TXT", self.license_bytes)
        compiler_hash = hashlib.sha256(self.compiler_bytes).hexdigest()
        self.compiler_proof = {
            "schema": "cybersand.portable-compiler-utf8-v1", "status": "verified",
            "receipt_sha256": "1" * 64,
            "binaries": {"bin/g++.exe": {"sha256": compiler_hash}},
        }
        self.lld_proof = {
            "schema": "cybersand.portable-linker-v1", "status": "verified",
            "receipt_sha256": "2" * 64,
            "source": {"lld_version": "LLD 23.1.0", "archive_sha256": "3" * 64},
            "gnu_compiler_binding": {"compiler_receipt_sha256": self.compiler_proof["receipt_sha256"],
                                      "driver_prepared_sha256": compiler_hash,
                                      "driver_relative_path": "bin/g++.exe"},
            "files": {
                "bin/ld.lld.exe": {"bytes": len(self.lld_bytes),
                                   "sha256": hashlib.sha256(self.lld_bytes).hexdigest()},
                "licenses/llvm-mingw/LICENSE.TXT": {"bytes": len(self.license_bytes),
                                                      "sha256": hashlib.sha256(self.license_bytes).hexdigest()},
            },
        }
        self.manifest = {
            "schema": "pubpres-mainline-windows-evaluator-v1",
            "source_commit": "a" * 40,
            "source_tree": "b" * 40,
            "files_sha256": self._files,
            "offline_authoring": {
                "tools": {"compiler": {"path": "cxx/bin/g++.exe", "sha256": compiler_hash,
                                         "version": "g++.exe (MinGW) 14.2.0\nCopyright"}},
                "compiler_utf8": self.compiler_proof,
                "portable_lld": self.lld_proof,
            },
        }
        self.world = self._world_receipt()

    def _add(self, relative: str, content: bytes) -> None:
        path = self.installation.joinpath(*relative.split("/"))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        self._files[relative] = hashlib.sha256(content).hexdigest()

    def _world_receipt(self) -> dict:
        hashes = {"tools/material_catalogue/lab.py": hashlib.sha256(
            self.source_bytes.replace(b"\r\n", b"\n")).hexdigest()}
        identity = {"git_head": self.manifest["source_commit"], "lf_sha256": hashes,
                    "digest": audit.object_digest(hashes), "qualification": "fixture"}
        compiler = str(self.cxx / "bin/g++.exe")
        build = {"argv": [compiler, "-std=c++20", "-O0", "-fuse-ld=lld", "-I", "$STAGED_FIXTURE"],
                 "native_executable_sha256": "d" * 64}
        return {"schema_id": "cybersand.material-lab.world-receipt", "schema_version": 1,
                "runtime_active": False, "checks": {"reference_qualification": True,
                                                       "candidate_qualification": True},
                "reference": {"ok": True}, "candidate": {"ok": True},
                "compiler": "g++.exe", "compiler_version": "g++.exe (MinGW) 14.2.0",
                "source_identity": identity, "source_identity_after": identity["digest"],
                "reference_build": dict(build), "candidate_build": dict(build),
                "scenario": {"first": 2, "second": 3, "seed": 17, "ticks": 120, "workers": 1}}

    def tool_loader(self, _installation: Path):
        class Compiler:
            @staticmethod
            def verify(_root, *, execute=False):
                self.assert_flag = execute
                return fixture.compiler_proof

        class Linker:
            @staticmethod
            def verify(_root, *, execute=False):
                self.assert_lld_execute = execute
                return fixture.lld_proof

        return Compiler, Linker

    def write_world_snapshot(self) -> Path:
        path = self.output / "portable-lab-source-snapshot.json"
        path.write_bytes(audit.canonical_json(self.world["source_identity"]))
        return path

    def write_manifest(self) -> Path:
        path = self.installation / audit.MANIFEST
        path.write_bytes(audit.canonical_json(self.manifest))
        return path

    def write_complete_outputs(self) -> None:
        self.write_manifest()
        snapshot = self.write_world_snapshot()
        log = self.output / "lab/original/material-lab-author/process.log"
        log.parent.mkdir(parents=True)
        outer = {"complete": True, "errors": [], "candidate_world_receipt": self.world}
        log.write_text(audit.MARKER + json.dumps(outer, separators=(",", ":")) + "\n", encoding="utf-8")
        log_hash = audit.sha_file(log)
        author = log.parent
        (author / "process.json").write_bytes(audit.canonical_json(
            {"status": "passed", "exit_code": 0, "log_sha256": log_hash}))
        lab_root = self.output / "lab/original"
        integration = {
            "schema": "ramcache-strata-integration-v1", "status": "passed", "completed": True,
            "mode": "lab", "platform": "win32",
            "source_identity": {"source_commit": self.manifest["source_commit"],
                                "source_tree": self.manifest["source_tree"]},
            "cases": [{"label": "material-lab-author", "status": "passed", "exit_code": 0,
                       "log_sha256": log_hash}],
            "files_sha256": {"material-lab-author/process.log": log_hash},
        }
        (lab_root / "integration.json").write_bytes(audit.canonical_json(integration))
        cross_feature_path = self.output / "lab/pubpres-mainline-qualification.json"
        cross_feature_path.parent.mkdir(parents=True, exist_ok=True)
        cross_feature = {
            "schema": "pubpres-mainline-cross-feature-v1", "status": "passed", "mode": "lab",
            "platform": "windows", "source": {"source_commit": self.manifest["source_commit"],
                                                   "source_tree": self.manifest["source_tree"]},
            "original_report_sha256": audit.sha_file(lab_root / "integration.json"),
        }
        cross_feature_path.write_bytes(audit.canonical_json(cross_feature))
        manifest_path = self.installation / audit.MANIFEST
        extracted = {
            "schema": "pubpres-mainline-extracted-evaluator-v1", "status": "passed",
            "source_commit": self.manifest["source_commit"], "source_tree": self.manifest["source_tree"],
            "manifest_sha256": audit.sha_file(manifest_path),
            "extracted_modes": {"lab": {"record_sha256": audit.sha_file(cross_feature_path)}},
        }
        (self.output / "extracted-verification.json").write_bytes(audit.canonical_json(extracted))


class ExtractedLinkerAuditTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.fixture = Fixture(Path(self.temporary.name))
        self.fixture.write_world_snapshot()

    def test_accepts_exact_bundled_compiler_and_lld_world_receipt(self):
        result = audit.validate_world_receipt(
            {"complete": True, "errors": [], "candidate_world_receipt": self.fixture.world},
            self.fixture.installation, self.fixture.manifest,
            self.fixture.output / "portable-lab-source-snapshot.json")
        self.assertEqual(result["source_snapshot"]["git_head"], "a" * 40)
        self.assertEqual(result["reference_build"]["linker"], "lld")
        self.assertEqual(result["candidate_build"]["linker"], "lld")
        self.assertFalse(result["process_level_linker_child_observed"])

    def test_refuses_missing_or_conflicting_linker_selection(self):
        for flags in ([], ["-fuse-ld=bfd"], ["-fuse-ld=lld", "-fuse-ld=bfd"]):
            with self.subTest(flags=flags):
                world = json.loads(json.dumps(self.fixture.world))
                world["reference_build"]["argv"] = [world["reference_build"]["argv"][0], *flags]
                with self.assertRaises(audit.AuditError):
                    audit.validate_world_receipt(
                        {"complete": True, "errors": [], "candidate_world_receipt": world},
                        self.fixture.installation, self.fixture.manifest,
                        self.fixture.output / "portable-lab-source-snapshot.json")

    def test_refuses_program_search_override_or_foreign_compiler(self):
        for change in ("-Boutside/bin", "foreign-g++.exe"):
            with self.subTest(change=change):
                world = json.loads(json.dumps(self.fixture.world))
                if change.startswith("-B"):
                    world["candidate_build"]["argv"].append(change)
                else:
                    world["candidate_build"]["argv"][0] = change
                with self.assertRaises(audit.AuditError):
                    audit.validate_world_receipt(
                        {"complete": True, "errors": [], "candidate_world_receipt": world},
                        self.fixture.installation, self.fixture.manifest,
                        self.fixture.output / "portable-lab-source-snapshot.json")

    def test_refuses_mutated_source_snapshot_file(self):
        self.fixture.source_file.write_bytes(b"changed source\n")
        with self.assertRaises(audit.AuditError):
            audit.validate_world_receipt(
                {"complete": True, "errors": [], "candidate_world_receipt": self.fixture.world},
                self.fixture.installation, self.fixture.manifest,
                self.fixture.output / "portable-lab-source-snapshot.json")

    def test_verifies_marker_proofs_against_packaged_files(self):
        fixture = self.fixture
        class Compiler:
            @staticmethod
            def verify(root, *, execute=False):
                self.assertFalse(execute)
                return fixture.compiler_proof
        class Linker:
            @staticmethod
            def verify(root, *, execute=False):
                self.assertTrue(execute)
                return fixture.lld_proof
        result = audit.verify_linker_bundle(fixture.installation, fixture.manifest,
                                            load_tools=lambda _root: (Compiler, Linker))
        self.assertEqual(result["lld_version"], "LLD 23.1.0")
        self.assertEqual(result["lld_files_checked"], 2)
        self.assertEqual(result["licensed_files_checked"], 1)
        self.assertEqual(result["compiler_executables_checked"], 1)

    def test_refuses_mutated_lld_or_foreign_marker_proof(self):
        fixture = self.fixture
        class Compiler:
            @staticmethod
            def verify(root, *, execute=False):
                return fixture.compiler_proof
        class Linker:
            @staticmethod
            def verify(root, *, execute=False):
                changed = json.loads(json.dumps(fixture.lld_proof))
                changed["source"]["archive_sha256"] = "9" * 64
                return changed
        with self.assertRaises(audit.AuditError):
            audit.verify_linker_bundle(fixture.installation, fixture.manifest,
                                       load_tools=lambda _root: (Compiler, Linker))
        class PinnedLinker:
            @staticmethod
            def verify(root, *, execute=False):
                return fixture.lld_proof
        (fixture.cxx / "bin/ld.lld.exe").write_bytes(b"tampered")
        with self.assertRaises(audit.AuditError):
            audit.verify_linker_bundle(fixture.installation, fixture.manifest,
                                       load_tools=lambda _root: (Compiler, PinnedLinker))

    def test_complete_audit_uses_raw_log_and_exact_nested_layout(self):
        self.fixture.write_complete_outputs()
        fixture = self.fixture
        class Compiler:
            @staticmethod
            def verify(_root, *, execute=False):
                return fixture.compiler_proof
        class Linker:
            @staticmethod
            def verify(_root, *, execute=False):
                return fixture.lld_proof
        old_loader = audit._load_portable_tools
        audit._load_portable_tools = lambda _root: (Compiler, Linker)
        try:
            result = audit.audit(fixture.installation, fixture.output)
        finally:
            audit._load_portable_tools = old_loader
        self.assertEqual(result["status"], "passed")
        self.assertTrue((fixture.output / "extracted-linker-audit.json").is_file())

    def test_complete_audit_refuses_pending_extraction_record(self):
        self.fixture.write_complete_outputs()
        record_path = self.fixture.output / "extracted-verification.json"
        record = json.loads(record_path.read_bytes())
        record["status"] = "running"
        record_path.write_bytes(audit.canonical_json(record))
        with self.assertRaises(audit.AuditError):
            audit.audit(self.fixture.installation, self.fixture.output)


if __name__ == "__main__":
    unittest.main()
