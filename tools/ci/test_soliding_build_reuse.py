#!/usr/bin/env python3
"""Actual Make/compiler regressions for local soliding object reuse.

Small synthetic translation units exercise invalidation and failure behavior;
they do not replace the complete production soliding scientific suites.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_soliding_build_inventory as inventory
import native_build_configuration as configuration


class SolidingInventoryTests(unittest.TestCase):
    def test_exact_original_expanded_source_flags_and_eight_test_order(self):
        report = inventory.check()
        for family in report["families"].values():
            self.assertEqual(len(family["objects"]), 6)
            self.assertEqual(len(family["expanded_original_commands"]), 8)
            self.assertEqual(len(family["ordered_tests"]), 8)
            self.assertEqual(family["eliminated_translation_unit_compilations"], 30)

    def test_missing_source_flag_profile_or_test_cannot_pass(self):
        run = subprocess.run(["make", "--dry-run", "--always-make", f"CXX={inventory.COMPILER}",
                              "soliding-sanitize"], cwd=inventory.ROOT, capture_output=True, text=True, check=True)
        for before, after in ((" -fsanitize=address,undefined", ""),
                              ("soliding-objects/sanitized", "soliding-objects/normal"),
                              ("./build/test_settled_regions_sanitized", ""),
                              ("native/src/world.cpp", "native/src/unregistered.cpp")):
            with self.subTest(change=before), self.assertRaises(ValueError):
                inventory.inspect(run.stdout.replace(before, after), True)

    def test_configuration_replace_failure_preserves_previous_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "configuration.json"
            configuration.update(path, {"before": 1})
            before = path.read_bytes()
            with patch.object(configuration.os, "replace", side_effect=OSError("injected interruption")):
                with self.assertRaises(OSError):
                    configuration.update(path, {"after": 2})
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(list(path.parent.iterdir()), [path])


@unittest.skipUnless(shutil.which("g++"), "GNU C++ required for actual compiler invalidation controls")
class SolidingMakeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="soliding-reuse-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copy2(inventory.ROOT / "Makefile", self.root / "Makefile")
        (self.root / "tools/ci").mkdir(parents=True)
        shutil.copy2(inventory.ROOT / "tools/ci/native_build_configuration.py",
                     self.root / "tools/ci/native_build_configuration.py")
        (self.root / "native/src").mkdir(parents=True)
        (self.root / "native/include/cybersand").mkdir(parents=True)
        (self.root / "native/tests").mkdir(parents=True)
        self.header = self.root / "native/include/cybersand/reuse_fixture.hpp"
        self.header.write_text("#pragma once\ninline constexpr int fixture_value = 0;\n")
        for name in inventory.CORE:
            (self.root / f"native/src/{name}.cpp").write_text(
                '#include "cybersand/reuse_fixture.hpp"\nint fixture_' + name + '() { return fixture_value; }\n')
        for name in inventory.TESTS:
            (self.root / f"native/tests/test_{name}.cpp").write_text(
                "int fixture_world();\nint main() { return fixture_world(); }\n")
        self.log = self.root / "compiler.jsonl"
        self.compiler = self.root / "compiler.py"
        self.compiler.write_text('''import json, os, pathlib, signal, sys
args = sys.argv[1:]
with open(os.environ["REUSE_COMPILER_LOG"], "a") as stream:
    stream.write(json.dumps(args) + "\\n")
if "--version" in args and os.environ.get("REUSE_IDENTITY_FAIL"):
    raise SystemExit(19)
if "-c" in args and os.environ.get("REUSE_COMPILE_FAIL"):
    pathlib.Path(args[args.index("-o") + 1]).write_bytes(b"incomplete object")
    if os.environ["REUSE_COMPILE_FAIL"] == "signal":
        os.kill(os.getpid(), signal.SIGTERM)
    raise SystemExit(19)
os.execv(''' + repr(str(Path(shutil.which("g++")).resolve())) + ''', [''' + repr(shutil.which("g++")) + ''', *args])
''')
        self.env = os.environ.copy()
        for name in ("MAKEFLAGS", "MFLAGS", "CXX", "CYBERSAND_BUILD_CXX", "CYBERSAND_BUILD_FLAGS"):
            self.env.pop(name, None)
        self.env.update(CXX=f"{shlex.quote(sys.executable)} {shlex.quote(str(self.compiler))}",
                        REUSE_COMPILER_LOG=str(self.log))
        self.target = "build/test_settled_discovery"

    def run_make(self, *arguments, extra_env=None):
        env = {**self.env, **(extra_env or {})}
        offset = len(self.records())
        result = subprocess.run(["make", "--no-print-directory", *arguments], cwd=self.root,
                                env=env, text=True, capture_output=True, timeout=60)
        return result, self.records()[offset:]

    def records(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def compile_sources(self, records):
        return [row[row.index("-c") + 1] for row in records if "-c" in row]

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_same_config_compiles_six_core_sources_once_across_six_binaries(self):
        targets = [f"build/test_{name}" for name in inventory.TESTS if name not in inventory.HEADER_ONLY]
        result, records = self.run_make(*targets)
        self.assert_success(result)
        self.assertEqual(self.compile_sources(records), [f"native/src/{name}.cpp" for name in inventory.CORE])
        self.assertEqual(sum("-o" in row and "-c" not in row for row in records), 6)
        result, records = self.run_make(*targets)
        self.assert_success(result)
        self.assertFalse(any("-o" in row for row in records))
        for target in targets:
            self.assertEqual(subprocess.run([str(self.root / target)], cwd=self.root).returncode, 0)

    def test_changed_flags_and_compiler_bytes_each_invalidate_all_objects(self):
        self.assert_success(self.run_make(self.target)[0])
        flags = "DEBUG_FLAGS=-O0 -g3 -DREUSE_CHANGED_CONFIGURATION=1"
        result, records = self.run_make(flags, self.target)
        self.assert_success(result)
        self.assertEqual(len(self.compile_sources(records)), 6)
        with self.compiler.open("a") as stream:
            stream.write("# changed compiler wrapper identity\n")
        result, records = self.run_make(flags, self.target)
        self.assert_success(result)
        self.assertEqual(len(self.compile_sources(records)), 6)

    def test_changed_source_and_header_invalidate_their_objects(self):
        self.assert_success(self.run_make(self.target)[0])
        source = self.root / "native/src/world.cpp"
        before = source.stat()
        with source.open("a") as stream:
            stream.write("// changed source with preserved timestamp\n")
        os.utime(source, ns=(before.st_atime_ns, before.st_mtime_ns))
        result, records = self.run_make(self.target)
        self.assert_success(result)
        self.assertEqual(len(self.compile_sources(records)), 6)
        before = self.header.stat()
        with self.header.open("a") as stream:
            stream.write("// changed header with preserved timestamp\n")
        os.utime(self.header, ns=(before.st_atime_ns, before.st_mtime_ns))
        result, records = self.run_make(self.target)
        self.assert_success(result)
        self.assertEqual(len(self.compile_sources(records)), 6)

    def test_deleted_required_header_blocks_previously_built_binary(self):
        self.assert_success(self.run_make(self.target)[0])
        self.header.unlink()
        result, records = self.run_make(self.target)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.compile_sources(records))

    def test_normal_and_sanitized_profiles_never_alias(self):
        self.assert_success(self.run_make(self.target)[0])
        normal = self.root / "build/soliding-objects/normal/world.o"
        before = (normal.stat().st_mtime_ns, hashlib.sha256(normal.read_bytes()).hexdigest())
        result, records = self.run_make(self.target + "_sanitized")
        self.assert_success(result)
        self.assertEqual(len(self.compile_sources(records)), 6)
        self.assertTrue(all("-fsanitize=address,undefined" in row for row in records if "-c" in row))
        self.assertEqual(before, (normal.stat().st_mtime_ns, hashlib.sha256(normal.read_bytes()).hexdigest()))
        self.assertTrue((self.root / "build/soliding-objects/sanitized/world.o").exists())

    def test_missing_object_rebuilds_and_corrupt_object_fails_link(self):
        self.assert_success(self.run_make(self.target)[0])
        obj = self.root / "build/soliding-objects/normal/world.o"
        obj.unlink()
        result, records = self.run_make(self.target)
        self.assert_success(result)
        self.assertEqual(self.compile_sources(records), ["native/src/world.cpp"])
        obj.write_bytes(b"incomplete object")
        result, records = self.run_make(self.target)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.compile_sources(records))

    def test_failed_or_terminated_compile_cannot_publish_a_partial_object(self):
        for mode in ("exit", "signal"):
            with self.subTest(mode=mode):
                result, _ = self.run_make(self.target, extra_env={"REUSE_COMPILE_FAIL": mode})
                self.assertNotEqual(result.returncode, 0)
                directory = self.root / "build/soliding-objects/normal"
                self.assertFalse((directory / "world.o").exists())
                self.assertFalse(list(directory.glob("*.tmp.*")))
        self.assert_success(self.run_make(self.target)[0])
        obj = self.root / "build/soliding-objects/normal/world.o"
        before = obj.read_bytes()
        with (self.root / "native/src/world.cpp").open("a") as stream:
            stream.write("// source changed after a successful build\n")
        result, _ = self.run_make(self.target, extra_env={"REUSE_COMPILE_FAIL": "exit"})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(obj.read_bytes(), before)
        result, records = self.run_make(self.target)
        self.assert_success(result)
        self.assertEqual(len(self.compile_sources(records)), 6)

    def test_failed_identity_query_blocks_existing_outputs(self):
        self.assert_success(self.run_make(self.target)[0])
        result, records = self.run_make(self.target, extra_env={"REUSE_IDENTITY_FAIL": "1"})
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any("-o" in row for row in records))

    def test_make_dry_run_never_queries_or_executes_compiler(self):
        result, records = self.run_make("--dry-run", "--always-make", self.target)
        self.assert_success(result)
        self.assertFalse(records)
        self.assertFalse((self.root / "build").exists())


if __name__ == "__main__":
    unittest.main()
