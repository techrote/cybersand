#!/usr/bin/env python3
"""Pure build admission/orchestration guards; no native physics compilation."""
import argparse
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import tarfile
import unittest
from unittest.mock import Mock, patch

import build_science_consumer as b


class Depfiles(unittest.TestCase):
    def test_continuations_spaces_hash_and_dollar(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ("source.cpp", "space header.hpp", "hash#name.hpp", "dollar$name.hpp"):
                (root / name).write_bytes(b"fixture")
            actual = b.dep_paths("obj.o: source.cpp \\\n space\\ header.hpp hash\\#name.hpp dollar$$name.hpp\n", root)
            self.assertEqual(actual, sorted(["source.cpp", "space header.hpp", "hash#name.hpp", "dollar$name.hpp"]))

    def test_missing_empty_escaping_and_truncated_refuse(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "root"
            root.mkdir()
            (root.parent / "outside.hpp").write_bytes(b"outside")
            for value in ("missing separator", "obj.o:", "obj.o: missing.hpp", "obj.o: ../outside.hpp", "obj.o: broken\\"):
                with self.subTest(value=value), self.assertRaises(ValueError):
                    b.dep_paths(value, root)


class Orchestration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = (Path(self.temp.name) / "source").resolve()
        self.root.mkdir()
        self.addCleanup(patch.stopall)
        patch.object(b, "ROOT", self.root).start()
        for name in (*b.SOURCES, "native/include/space header.hpp", "tools/lcb/build_science_consumer.py", "third_party/native-toolchain.lock.json"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())
        self.compiler = Path(self.temp.name) / "compiler.bin"
        self.compiler.write_bytes(b"pure compiler identity fixture")
        self.args = argparse.Namespace(compiler=self.compiler, target="linux", out=Path(self.temp.name) / "output", toolchain_root=None, toolchain_archive=None)
        patch.object(b.sys, "platform", "linux").start()
        patch.object(b.subprocess, "check_output", return_value=b"test-source-head\n").start()
        patch.object(b, "selected_toolchain", return_value={"compiler_sha256": b.sha(self.compiler), "build_host": "synthetic-pure-test", "target": "linux"}).start()
        patch.object(b, "linux_libraries", return_value={"files": {}, "scope": "pure loader identity fixture"}).start()
        self.commands = []

    def fake_command(self, argv, out, name, timeout):
        self.commands.append((argv, name, timeout))
        output = Path(argv[argv.index("-o") + 1])
        if "-c" in argv:
            source = argv[argv.index("-c") + 1]
            output.write_bytes(("object " + source).encode())
            Path(argv[argv.index("-MF") + 1]).write_text("obj.o: " + source + " native/include/space\\ header.hpp\n", encoding="utf8")
        else:
            output.write_bytes(b"pure executable fixture, not actual machine code")
        return {"returncode": 0, "command": argv, "timeout_seconds": timeout, "scope": "mock compiler orchestration, no physics execution"}

    def test_all_five_tus_complete_union_flags_and_flat_receipt(self):
        with patch.object(b, "command", side_effect=self.fake_command):
            b.build(self.args)
        receipt = json.loads((self.args.out / "build-receipt.json").read_text(encoding="utf8"))
        self.assertEqual(len(self.commands), 6)
        self.assertEqual(len(receipt["compile_records"]), 5)
        self.assertEqual(set(receipt["source_inputs"]), set(b.SOURCES) | {"native/include/space header.hpp"})
        self.assertEqual(receipt["flags"], list(b.FLAGS))
        self.assertIn("-O3", receipt["flags"])
        self.assertIn("-DNDEBUG", receipt["flags"])
        self.assertIn("-flto", receipt["flags"])
        self.assertNotIn("objects", receipt)  # No ambiguous second source container.
        self.assertEqual(receipt["compiler_sha256"], b.sha(self.args.out / "compiler.bin"))
        self.assertTrue(receipt["complete_source_fences_held"])

    def test_failed_compile_preserves_partial_without_success(self):
        def fail(argv, out, name, timeout):
            if name == "compile-1":
                raise ValueError("synthetic compiler failure")
            return self.fake_command(argv, out, name, timeout)
        with patch.object(b, "command", side_effect=fail), self.assertRaisesRegex(ValueError, "synthetic compiler failure"):
            b.build(self.args)
        self.assertTrue((self.args.out / "objects/0.o").exists())
        self.assertTrue((self.args.out / "FAILURE.json").exists())
        self.assertFalse((self.args.out / "build-receipt.json").exists())

    def test_bundle_bytes_source_target_and_file_set_are_exact(self):
        with patch.object(b, "command", side_effect=self.fake_command):
            b.build(self.args)
        self.assertEqual(b.verify_bundle(self.args.out, "test-source-head", "linux")["status"], "verified")
        with self.assertRaisesRegex(ValueError, "source/target"):
            b.verify_bundle(self.args.out, "other-source-head", "linux")
        with self.assertRaisesRegex(ValueError, "source/target"):
            b.verify_bundle(self.args.out, "test-source-head", "windows")
        extra = self.args.out / "unrecorded"
        extra.write_bytes(b"extra")
        with self.assertRaisesRegex(ValueError, "file set"):
            b.verify_bundle(self.args.out, "test-source-head", "linux")
        extra.unlink()
        binary = self.args.out / "lcb_science"
        binary.write_bytes(binary.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "byte mismatch"):
            b.verify_bundle(self.args.out, "test-source-head", "linux")

    def test_missing_actual_tu_in_depfile_refuses(self):
        def omitted(argv, out, name, timeout):
            result = self.fake_command(argv, out, name, timeout)
            if name == "compile-0":
                Path(argv[argv.index("-MF") + 1]).write_text("obj.o: native/include/space\\ header.hpp\n")
            return result
        with patch.object(b, "command", side_effect=omitted), self.assertRaisesRegex(ValueError, "omits actual TU"):
            b.build(self.args)
        self.assertFalse((self.args.out / "build-receipt.json").exists())

    def test_source_change_and_missing_tu_dep_refuse(self):
        def changed(argv, out, name, timeout):
            result = self.fake_command(argv, out, name, timeout)
            if name == "compile-0":
                (self.root / "native/include/space header.hpp").write_bytes(b"changed")
            return result
        with patch.object(b, "command", side_effect=changed), self.assertRaisesRegex(ValueError, "changed dependency"):
            b.build(self.args)
        self.assertFalse((self.args.out / "build-receipt.json").exists())

    def test_existing_or_in_checkout_output_refuses_without_overwrite(self):
        self.args.out.mkdir()
        sentinel = self.args.out / "sentinel"
        sentinel.write_bytes(b"keep")
        with self.assertRaisesRegex(ValueError, "new external"):
            b.build(self.args)
        self.assertEqual(sentinel.read_bytes(), b"keep")
        self.args.out = self.root / "build"
        with self.assertRaisesRegex(ValueError, "new external"):
            b.build(self.args)


class ProcessFailure(unittest.TestCase):
    def test_actual_nonzero_tiny_child_retains_both_streams_and_metadata(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(b, "ROOT", Path(tmp)):
            out = Path(tmp)
            with self.assertRaisesRegex(ValueError, "build command failed"):
                b.command([sys.executable, "-c", "import sys;print('partial');print('failure',file=sys.stderr);sys.exit(7)"], out, "tiny", 10)
            record = json.loads((out / "tiny.json").read_text(encoding="utf8"))
            self.assertEqual(record["returncode"], 7)
            self.assertEqual((out / "tiny.stdout").read_text().strip(), "partial")
            self.assertEqual((out / "tiny.stderr").read_text().strip(), "failure")

    def test_timeout_metadata_is_not_a_fabricated_process_exit(self):
        process = Mock(pid=123)
        process.wait.side_effect = [subprocess.TimeoutExpired(["fixture"], 1), -9]
        with tempfile.TemporaryDirectory() as tmp, patch.object(b, "ROOT", Path(tmp)), \
                patch.object(b.sys, "platform", "linux"), patch.object(b.subprocess, "Popen", return_value=process), \
                patch.object(b.os, "killpg", create=True) as killpg, patch.object(b.signal, "SIGKILL", 9, create=True):
            with self.assertRaises(ValueError):
                b.command(["fixture"], Path(tmp), "timeout", 1)
            record = json.loads((Path(tmp) / "timeout.json").read_text(encoding="utf8"))
            self.assertIsNone(record["returncode"])
            self.assertTrue(record["timed_out"])
            killpg.assert_called_once_with(123, b.signal.SIGKILL)


class CrossArchive(unittest.TestCase):
    def test_exact_archive_member_and_changed_extraction_refusal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "source"
            (root / "third_party").mkdir(parents=True)
            tool = Path(tmp) / "tool"
            (tool / "bin").mkdir(parents=True)
            compiler = tool / "bin/clang-real"
            compiler.write_bytes(b"synthetic Linux-host compiler identity")
            archive = Path(tmp) / "tool.tar.xz"
            with tarfile.open(archive, "w:xz") as tar:
                info = tarfile.TarInfo("pinned/bin/clang-real")
                data = compiler.read_bytes()
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
            pin = {"name": "llvm-mingw", "sha256": b.sha(archive), "size": archive.stat().st_size}
            (root / "third_party/native-toolchain.lock.json").write_text(json.dumps({"artifacts": [pin]}))
            args = argparse.Namespace(compiler=compiler, target="windows", toolchain_archive=archive, toolchain_root=tool)
            def identity(argv, out, name, timeout):
                (out / (name + ".stdout")).write_text("clang version 23.1.0\n" if name == "compiler-version" else "x86_64-w64-windows-gnu\n")
                return {"scope": "pure synthetic identity command"}
            out = Path(tmp) / "proof"
            out.mkdir()
            with patch.object(b, "ROOT", root), patch.object(b, "command", side_effect=identity):
                binding = b.selected_toolchain(args, out)
                self.assertEqual(binding["archive_sha256"], pin["sha256"])
                self.assertEqual(binding["compiler_archive_member"], "pinned/bin/clang-real")
                self.assertIs(binding["compiler_execution_in_target_job"], False)
                compiler.write_bytes(b"changed extraction")
                with self.assertRaisesRegex(ValueError, "differs from pinned archive member"):
                    b.selected_toolchain(args, out)


class LinuxToolchain(unittest.TestCase):
    def test_linux_target_executes_its_host_compiler_and_records_linker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "source"
            (root / "third_party").mkdir(parents=True)
            compiler = Path(tmp) / "compiler"
            linker = Path(tmp) / "linker"
            compiler.write_bytes(b"pure GNU compiler file identity")
            linker.write_bytes(b"pure GNU linker file identity")
            (root / "third_party/native-toolchain.lock.json").write_text(json.dumps({"artifacts": [{"name": "GNU C++", "version": "13.3.0 (synthetic fixture)"}]}), encoding="utf8")
            args = argparse.Namespace(compiler=compiler, target="linux", toolchain_archive=None, toolchain_root=None)
            def identity(argv, out, name, timeout):
                values = {"compiler-version": "g++ 13.3.0\n", "compiler-machine": "x86_64-linux-gnu\n", "linker-path": str(linker) + "\n", "linker-version": "GNU ld 2.42\n"}
                (out / (name + ".stdout")).write_text(values[name], encoding="utf8")
                return {"scope": "pure synthetic identity command"}
            with patch.object(b, "ROOT", root), patch.object(b, "command", side_effect=identity):
                binding = b.selected_toolchain(args, Path(tmp))
            self.assertIs(binding["compiler_execution_in_target_job"], True)
            self.assertEqual(binding["linker"]["sha256"], b.sha(linker))


class LinuxLibraries(unittest.TestCase):
    def test_actual_paths_and_unresolved_or_unrecognized_dependency_refusal(self):
        with tempfile.TemporaryDirectory() as tmp:
            library = Path(tmp) / "libfixture.so"
            library.write_bytes(b"pure library identity fixture")
            text = "linux-vdso.so.1 (0x123)\nlibfixture.so => " + str(library) + " (0x456)\n"
            # Posix paths are the actual Linux-host input. This portable pure
            # test uses its own absolute host path without inventing ELF work.
            self.assertEqual(b.linux_library_paths(text), [library.resolve()])
            for value in ("libfixture.so => not found\n", "statically linked\n", "linux-vdso.so.1 (0x123)\n"):
                with self.subTest(value=value), self.assertRaises(ValueError):
                    b.linux_library_paths(value)


class CheckoutRestoration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "source"
        self.root.mkdir()
        self.bundle = Path(self.temp.name) / "bundle"
        self.bundle.mkdir()
        self.proof = Path(self.temp.name) / "repair"
        self.addCleanup(patch.stopall)
        patch.object(b, "ROOT", self.root).start()
        self.git("init", "-q")
        self.git("config", "core.autocrlf", "false")
        (self.root / ".gitattributes").write_bytes(b"* text=auto\n*.cpp text eol=lf\n")
        self.names = (*b.SOURCES, "native/src/fixture.inc")
        for name in self.names:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"pure source fixture\nsecond line\n")
        self.git("add", ".")
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "fixture")
        self.head = self.git("rev-parse", "HEAD").decode().strip()
        self.sources = {name: b.sha(self.root / name) for name in self.names}
        (self.bundle / "lcb_science.exe").write_bytes(b"MZ pure executable fixture")
        (self.bundle / "compiler.bin").write_bytes(b"pure driver identity fixture")
        self.receipt = {"schema": "lcb-science-consumer-build-v1", "source_commit": self.head,
                        "toolchain": {"target": "windows"}, "complete_source_fences_held": True,
                        "source_inputs": self.sources, "exe_sha256": b.sha(self.bundle / "lcb_science.exe"),
                        "compiler_sha256": b.sha(self.bundle / "compiler.bin")}
        self.reseal()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True, timeout=30).stdout

    def reseal(self):
        (self.bundle / "source-map.json").write_text(json.dumps(self.sources), encoding="utf8")
        (self.bundle / "build-receipt.json").write_text(json.dumps(self.receipt), encoding="utf8")
        manifest = {p.name: b.sha(p) for p in self.bundle.iterdir() if p.is_file() and p.name != "bundle-sha256.json"}
        (self.bundle / "bundle-sha256.json").write_text(json.dumps(manifest), encoding="utf8")

    def test_actual_git_crlf_restore_then_unchanged_raw_map_verification(self):
        self.git("config", "core.autocrlf", "true")
        inc = self.root / "native/src/fixture.inc"
        inc.write_bytes(inc.read_bytes().replace(b"\n", b"\r\n"))
        self.assertIn(b"\r\n", (self.root / "native/src/fixture.inc").read_bytes())
        with self.assertRaisesRegex(ValueError, "actual target checkout source mismatch"):
            b.verify_bundle(self.bundle, self.head, "windows")
        unrelated = self.root / "unrelated.txt"
        unrelated.write_bytes(b"unchanged unrelated CRLF\r\n")
        b.restore_compiled_checkout(self.bundle, self.head, "windows", self.proof)
        self.assertEqual(b.verify_bundle(self.bundle, self.head, "windows")["status"], "verified")
        self.assertNotIn(b"\r\n", (self.root / "native/src/fixture.inc").read_bytes())
        self.assertEqual(unrelated.read_bytes(), b"unchanged unrelated CRLF\r\n")
        proof = json.loads((self.proof / "CHECKOUT-RECEIPT.json").read_text(encoding="utf8"))
        self.assertEqual(proof["after_raw_sha256"], self.sources)
        old = proof["before"]["native/src/fixture.inc"]
        self.assertNotEqual(old["raw_sha256"], old["git_blob_content_sha256"])
        self.assertEqual(old["canonical_lf_sha256"], old["git_blob_content_sha256"])

    def test_non_native_path_and_changed_git_source_refuse_before_restore(self):
        self.sources["outside.md"] = "0" * 64
        self.reseal()
        with self.assertRaisesRegex(ValueError, "only compiled Native text"):
            b.restore_compiled_checkout(self.bundle, self.head, "windows", self.proof)
        self.assertFalse(self.proof.exists())
        del self.sources["outside.md"]
        self.sources["native/src/fixture.inc"] = "0" * 64
        self.reseal()
        with self.assertRaisesRegex(ValueError, "differs from actual Git blob"):
            b.restore_compiled_checkout(self.bundle, self.head, "windows", self.proof)
        self.assertFalse(self.proof.exists())


if __name__ == "__main__":
    unittest.main()
