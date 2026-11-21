#!/usr/bin/env python3
"""Execute multi-translation-unit regressions for gallery compiler cache reuse.

The wrapper fixtures deliberately advertise identical compiler --version output
but generate different native values. This exposes driver-path/content reuse
that a version-string-only test misses. Set GENTEK_TEST_COMPILER_A/B to also run
the real GCC 13/GCC 14 switch (both are required; missing tools are a real skip).
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

import compiler_cache as cache


class CompilerCacheTests(unittest.TestCase):
    def setUp(self) -> None:
        self.compiler = shutil.which("g++")
        if self.compiler is None:
            self.skipTest("g++ is required for executable compiler-cache regressions")
        self.temporary = tempfile.TemporaryDirectory(prefix="gentek-compiler-cache-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "native/src").mkdir(parents=True)
        (self.root / "native/include").mkdir()
        (self.root / "tools/architecture").mkdir(parents=True)
        self.component = "native/src/component.cpp"
        self.exporter = "tools/architecture/fixture_export.cpp"
        (self.root / self.component).write_text(
            "#ifndef BUILD_VALUE\n#define BUILD_VALUE __GNUC__\n#endif\n"
            "int component() { return BUILD_VALUE; }\n")
        (self.root / self.exporter).write_text(
            "#include <iostream>\n#ifndef BUILD_VALUE\n#define BUILD_VALUE __GNUC__\n#endif\n"
            "int component();\nint main() { std::cout << component() << ',' << BUILD_VALUE << '\\n'; }\n")
        self.output = self.root / "evidence"

    def ledger(self) -> dict[str, str]:
        return {path: cache.sha((self.root / path).read_bytes())
                for path in (self.component, self.exporter)}

    def build(self, compiler: str, *, skip: bool = False,
              ledger: dict[str, str] | None = None) -> tuple[Path, dict]:
        return cache.build_exporter(root=self.root, output=self.output,
            ledger=self.ledger() if ledger is None else ledger,
            compiler=compiler, skip=skip, generation_sources=["component.cpp"],
            exporter=self.exporter)

    def run_value(self, binary: Path) -> str:
        return subprocess.check_output([str(binary)], text=True).strip()

    def wrapper(self, name: str, value: int) -> str:
        if os.name == "nt":
            self.skipTest("POSIX wrapper mutation fixture; real compiler switch is platform-neutral")
        path = self.root / name
        path.write_text("#!/bin/sh\nexec " + shlex.quote(self.compiler) +
                        f" -DBUILD_VALUE={value} \"$@\"\n")
        path.chmod(0o755)
        return str(path)

    def test_switch_recompiles_both_units_and_no_build_cannot_change_compiler(self) -> None:
        first, second = self.wrapper("compiler-a", 13), self.wrapper("compiler-b", 14)
        old_binary, old_record = self.build(first)
        self.assertEqual(self.run_value(old_binary), "13,13")
        with self.assertRaisesRegex(RuntimeError, "requested compiler identity"):
            self.build(second, skip=True)
        new_binary, new_record = self.build(second)
        self.assertEqual(self.run_value(new_binary), "14,14")
        self.assertNotEqual(old_binary, new_binary)
        # The version-only check would have admitted this deliberately identical
        # --version output; the recorded driver identities are different.
        self.assertEqual(old_record["compiler"], new_record["compiler"])
        self.assertNotEqual(old_record["compiler_identity"], new_record["compiler_identity"])
        self.assertEqual(self.build(first, skip=True)[0], old_binary)
        self.assertEqual(self.run_value(self.build(second, skip=True)[0]), "14,14")

    def test_same_path_same_version_changed_driver_is_rejected(self) -> None:
        compiler = self.wrapper("mutable-compiler", 13)
        self.build(compiler)
        self.wrapper("mutable-compiler", 14)
        with self.assertRaisesRegex(RuntimeError, "requested compiler identity"):
            self.build(compiler, skip=True)
        self.assertEqual(self.run_value(self.build(compiler)[0]), "14,14")

    def test_tampered_executable_is_rejected(self) -> None:
        binary, _ = self.build(self.compiler)
        binary.write_bytes(binary.read_bytes() + b"invalid cache alteration")
        with self.assertRaisesRegex(RuntimeError, "executable hash"):
            self.build(self.compiler, skip=True)

    def test_tampered_compiler_receipt_is_rejected(self) -> None:
        binary, record = self.build(self.compiler)
        record["compiler_identity"]["driver"]["sha256"] = "0" * 64
        (binary.parent / "build-identity.json").write_text(json.dumps(record))
        with self.assertRaisesRegex(RuntimeError, "compiler identity"):
            self.build(self.compiler, skip=True)

    def test_source_change_and_stale_ledger_are_both_rejected(self) -> None:
        old_ledger = self.ledger()
        self.build(self.compiler)
        (self.root / self.component).write_text("int component() { return 123; }\n")
        with self.assertRaisesRegex(RuntimeError, "source inputs changed"):
            self.build(self.compiler, skip=True, ledger=old_ledger)
        with self.assertRaisesRegex(RuntimeError, "current source inputs"):
            self.build(self.compiler, skip=True)

    def test_failed_fresh_build_preserves_previous_cache(self) -> None:
        binary, _ = self.build(self.compiler)
        before = binary.read_bytes()
        (self.root / self.component).write_text("this deliberately fails C++ compilation\n")
        with self.assertRaisesRegex(RuntimeError, "compilation failed"):
            self.build(self.compiler)
        self.assertEqual(binary.read_bytes(), before)

    def test_real_gcc13_gcc14_switch(self) -> None:
        first = os.environ.get("GENTEK_TEST_COMPILER_A", "g++-13")
        second = os.environ.get("GENTEK_TEST_COMPILER_B", "g++-14")
        if cache._resolve_program(first, self.root) is None or cache._resolve_program(second, self.root) is None:
            self.skipTest("both GCC 13 and GCC 14 are required for real cross-compiler execution")
        first_binary, first_record = self.build(first)
        self.assertEqual(self.run_value(first_binary), "13,13")
        with self.assertRaisesRegex(RuntimeError, "requested compiler identity"):
            self.build(second, skip=True)
        second_binary, second_record = self.build(second)
        self.assertEqual(self.run_value(second_binary), "14,14")
        self.assertNotEqual(first_record["compiler_identity"], second_record["compiler_identity"])
        self.assertEqual(self.run_value(self.build(first, skip=True)[0]), "13,13")
        self.assertEqual(self.run_value(self.build(second, skip=True)[0]), "14,14")


if __name__ == "__main__":
    unittest.main(verbosity=2)
