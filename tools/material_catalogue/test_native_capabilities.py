"""Compiler/output and actual C++ controls for the scoped capability consumer."""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import tempfile
import unittest

import compiler
import lab
import native_capabilities as capabilities


class NativeCapabilitiesTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mat-capability-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.source = self.directory / "catalogue.json"
        self.output = self.directory / "material_capabilities.hpp"
        self.value = json.loads(capabilities.SOURCE.read_text(encoding="utf-8"))

    def write(self, value=None):
        self.source.write_bytes(compiler.canonical_json(self.value if value is None else value))
        return self.source

    def synthetic(self):
        value = copy.deepcopy(self.value)
        value["scope"] = "isolated-synthetic"
        native = value["native"]
        native["identity"]["allocated_slots"] = 133
        material = dict(native["materials"][2], id=132, name="synthetic-powder")
        native["materials"].append(material)
        native["capabilities"][132] = dict(native["capabilities"][2], id=132,
                                            hard_surface=False, pair_participant=False)
        return value

    def test_current_output_is_deterministic_and_readonly_check_preserves_mtime(self):
        source = self.write()
        self.assertTrue(capabilities.generate(source, self.output))
        before = self.output.read_bytes(), self.output.stat().st_mtime_ns
        self.assertFalse(capabilities.generate(source, self.output, check=True))
        for field in ("materials", "capabilities", "appearance"):
            self.value["native"][field].reverse()
        self.write()
        self.assertFalse(capabilities.generate(source, self.output, check=True))
        self.assertEqual(before, (self.output.read_bytes(), self.output.stat().st_mtime_ns))

    def test_actual_cpp_has_all_byte_capabilities_and_no_synthetic_hard_inheritance(self):
        source = self.write(self.synthetic())
        capabilities.generate(source, self.output, isolated=True)
        probe = self.directory / "probe.cpp"
        probe.write_text(
            '#include "material_capabilities.hpp"\n#include <iostream>\n'
            'int main(){namespace c=cybersand::material_capability_catalogue;'
            'static_assert(!c::hard_surface(132)); static_assert(c::granular_support(132));'
            'static_assert(sizeof(c::kHardSurface)+sizeof(c::kGranularSupport)==64);'
            'for(unsigned id=0;id<256;++id){auto material=static_cast<std::uint8_t>(id);'
            'std::cout << c::hard_surface(material)'
            ' << c::granular_support(material) << "\\n";}}\n', encoding="utf-8")
        executable = self.directory / ("probe.exe" if os.name == "nt" else "probe")
        cxx, msvc = lab._toolchain()
        if msvc:
            command = [cxx, "/nologo", "/std:c++20", "/EHsc", "/W4", "/WX", str(probe),
                       "/Fe:" + str(executable), "/Fo:" + str(self.directory / "probe.obj")]
        else:
            command = [cxx, "-std=c++20", "-Wall", "-Wextra", "-Werror", str(probe),
                       "-o", str(executable)]
        lab._run(command, self.directory, 30)
        observed = lab._run([str(executable)], self.directory, 10).stdout.splitlines()
        rows = self.synthetic()["native"]["capabilities"]
        self.assertEqual(observed, [f"{int(row['hard_surface'])}{int(row['granular_support'])}" for row in rows])
        self.assertEqual(observed[10], "00")
        self.assertEqual(observed[132], "01")
        self.assertEqual(observed[133:], ["00"] * 123)

    def test_synthetic_cannot_write_production_output(self):
        source = self.write(self.synthetic())
        before = capabilities.OUTPUT.read_bytes()
        with self.assertRaisesRegex(compiler.CatalogueError, "isolated output must be external"):
            capabilities.generate(source, capabilities.OUTPUT, isolated=True)
        self.assertEqual(before, capabilities.OUTPUT.read_bytes())

    def test_external_source_cannot_replace_the_production_consumer(self):
        source = self.write()
        with self.assertRaisesRegex(compiler.CatalogueError, "only the canonical production catalogue"):
            capabilities.generate(source, capabilities.OUTPUT)

    def test_bad_capability_type_and_reserved_bits_refuse_without_publishing(self):
        for material, field, value in ((2, "hard_surface", 1), (10, "hard_surface", True),
                                       (132, "granular_support", True)):
            with self.subTest(material=material, field=field):
                candidate = copy.deepcopy(self.value)
                candidate["native"]["capabilities"][material][field] = value
                source = self.write(candidate)
                self.output.write_bytes(b"retained output\n")
                with self.assertRaises(compiler.CatalogueError):
                    capabilities.generate(source, self.output)
                self.assertEqual(self.output.read_bytes(), b"retained output\n")

    def test_duplicate_ids_and_unknown_capabilities_are_rejected(self):
        for attack in ("id", "unknown"):
            value = copy.deepcopy(self.value)
            if attack == "id":
                value["native"]["capabilities"][2]["id"] = 3
            else:
                value["native"]["capabilities"][2]["implicit_hard_range"] = True
            with self.assertRaises(compiler.CatalogueError):
                capabilities.generate(self.write(value), self.output)
            self.assertFalse(self.output.exists())

    def test_missing_or_poisoned_header_check_never_rewrites(self):
        source = self.write()
        with self.assertRaises(compiler.DriftError):
            capabilities.generate(source, self.output, check=True)
        self.assertFalse(self.output.exists())
        self.output.write_bytes(b"poison\n")
        before = self.output.stat().st_mtime_ns
        with self.assertRaises(compiler.DriftError):
            capabilities.generate(source, self.output, check=True)
        self.assertEqual((self.output.read_bytes(), self.output.stat().st_mtime_ns), (b"poison\n", before))

    def test_source_and_output_alias_is_rejected(self):
        source = self.write()
        before = source.read_bytes()
        with self.assertRaisesRegex(compiler.CatalogueError, "must not overwrite"):
            capabilities.generate(source, source)
        self.assertEqual(source.read_bytes(), before)

    def test_symlink_output_is_rejected(self):
        source = self.write()
        target = self.directory / "retained.hpp"
        target.write_bytes(b"retained\n")
        try:
            self.output.symlink_to(target)
        except OSError as error:
            self.skipTest(f"platform cannot create fixture symlink: {error}")
        with self.assertRaisesRegex(compiler.CatalogueError, "symbolic link"):
            capabilities.generate(source, self.output)
        self.assertEqual(target.read_bytes(), b"retained\n")


if __name__ == "__main__":
    unittest.main()
