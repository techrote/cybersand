#!/usr/bin/env python3
"""Fail-closed compiler comparison tests with explicitly synthetic artifacts."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

import compare_interlaced_compilers as subject


def save(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


class InterlacedComparisonGuards(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.directories = [self.root / "gcc13", self.root / "gcc14"]
        self.source = {"commit": "a" * 40, "tree": "b" * 40, "index_sha256": "c" * 64,
                       "inputs": {"native/src/fixture.cpp": "d" * 64,
                                  "tools/architecture/compiler_cache.py": "e" * 64},
                       "uncommitted_source_paths": []}
        for major, directory in zip((13, 14), self.directories):
            directory.mkdir()
            driver = self.root / f"synthetic-driver-{major}"
            driver.write_text(f"Synthetic compiler {major} fixture; never executed.\n")
            version = f"g++-{major} (synthetic test fixture) {major}.3.0"
            identity = {"version": version, "driver": {"path": str(driver), "realpath": str(driver.resolve()),
                        "sha256": subject.sha(driver)}, "tools": {}}
            request = {"schema": subject.CACHE_SCHEMA, "compiler_identity": identity,
                       "flags": subject.FLAGS,
                       "compile_sources": ["native/src/" + name for name in subject.GENERATION_SOURCES] + [subject.EXPORTER],
                       "builder_sha256": self.source["inputs"]["tools/architecture/compiler_cache.py"],
                       "source_input_sha256": subject.digest(self.source["inputs"])}
            cached = self.root / "build/architecture-exporters/interlaced_viaduct_export" / subject.digest(request)
            cached.mkdir(parents=True)
            binary = cached / "interlaced_viaduct_export"
            binary.write_text(f"Synthetic executable {major} fixture; never executed.\n")
            build = dict(request, build_key=subject.digest(request), compiler=version,
                         inputs=self.source["inputs"], executable_sha256=subject.sha(binary),
                         build_mode="fresh direct compilation; no shared object reuse")
            save(cached / "build-identity.json", build)
            cases = []
            for index, parameters in enumerate(subject.campaign(271828, 80, 64, 3)):
                name = parameters["name"]
                raw = directory / (name + ".cells")
                raw.write_bytes(bytes([index + 1]) * (parameters["extent"][0] * parameters["extent"][1]))
                png = directory / (name + ".png")
                png.write_bytes(b"Synthetic PNG bytes, not native evidence: " + name.encode())
                cases.append(dict(parameters, material_sha256=subject.sha(raw), png_sha256=subject.sha(png),
                                  fingerprint=hashlib.sha256(name.encode()).hexdigest()[:16],
                                  receipts=[{"synthetic": name}]))
            save(directory / "manifest.json", {"source": dict(self.source, input_sha256=subject.digest(self.source["inputs"]),
                 parent_commit=subject.PARENT, original_showcase_parent_commit=subject.ORIGINAL_SHOWCASE_PARENT,
                 identity_captured_before_render=True, identity_unchanged_after_render=True),
                 "build": build, "render_count": 26, "cases": cases})
            save(directory / "layer-checks.json", {"status": "pass", "seeds": 32, "assertions": 207491})

    def compare(self) -> dict:
        return subject.compare(*self.directories, self.source, root=self.root)

    def test_complete_distinct_compiler_campaigns_match(self):
        report = self.compare()
        self.assertEqual(report["status"], "pass")
        self.assertEqual(report["cases_compared"], 26)
        self.assertEqual(report["material_byte_matches"], 26)
        self.assertEqual(report["png_byte_matches"], 26)
        self.assertTrue(all(case["matches"]["chunk_receipts"] for case in report["cases"]))

    def test_partial_source_compiler_and_receipt_substitution_fail(self):
        path = self.directories[1] / "manifest.json"
        original = subject.read(path)
        mutations = [lambda value: value["source"].update(commit="f" * 40),
                     lambda value: value["source"].update(identity_unchanged_after_render=False),
                     lambda value: value.update(render_count=25),
                     lambda value: value["cases"].pop(),
                     lambda value: value["cases"][0].update(name=value["cases"][1]["name"]),
                     lambda value: value["cases"][0].update(seed=42),
                     lambda value: value["cases"][0].update(fingerprint="0" * 16),
                     lambda value: value["cases"][0].update(receipts=[]),
                     lambda value: value["build"]["compiler_identity"].update(version="g++-13 (wrong compiler) 13.3.0"),
                     lambda value: value["build"].update(build_key="0" * 64)]
        for index, mutate in enumerate(mutations):
            with self.subTest(mutation=index):
                candidate = copy.deepcopy(original)
                mutate(candidate)
                save(path, candidate)
                self.assertEqual(self.compare()["status"], "fail")
        save(path, original)

    def test_rehashed_native_and_png_mutations_still_diverge(self):
        manifest_path = self.directories[1] / "manifest.json"
        original = subject.read(manifest_path)
        name = original["cases"][0]["name"]
        for suffix, hash_key in (("cells", "material_sha256"), ("png", "png_sha256")):
            with self.subTest(artifact=suffix):
                path = self.directories[1] / (name + "." + suffix)
                before = path.read_bytes()
                path.write_bytes(bytes([before[0] ^ 1]) + before[1:])
                candidate = copy.deepcopy(original)
                candidate["cases"][0][hash_key] = subject.sha(path)
                save(manifest_path, candidate)
                report = self.compare()
                self.assertEqual(report["status"], "fail")
                self.assertEqual(report["cases_compared"], 26)
                self.assertTrue(any("mismatch" in failure for failure in report["failures"]))
                path.write_bytes(before)
                save(manifest_path, original)

    def test_changed_driver_or_cached_executable_is_refused(self):
        build = subject.read(self.directories[1] / "manifest.json")["build"]
        binary = self.root / "build/architecture-exporters/interlaced_viaduct_export" / build["build_key"] / "interlaced_viaduct_export"
        for path in (Path(build["compiler_identity"]["driver"]["path"]), binary):
            with self.subTest(artifact=path.name):
                original = path.read_bytes()
                path.write_bytes(original + b"substitution")
                self.assertEqual(self.compare()["status"], "fail")
                path.write_bytes(original)

    def test_missing_campaign_retains_failed_cli_receipt(self):
        output = self.root / "failed-comparison.json"
        arguments = ["compare_interlaced_compilers.py", "--gcc13", str(self.root / "missing"),
                     "--gcc14", str(self.directories[1]), "--source-sha", self.source["commit"],
                     "--output", str(output)]
        with mock.patch.object(sys, "argv", arguments), mock.patch.object(subject, "source_boundary", return_value=self.source):
            self.assertEqual(subject.main(), 1)
        report = subject.read(output)
        self.assertEqual(report["status"], "fail")
        self.assertEqual(report["source_commit"], self.source["commit"])
        self.assertTrue(report["failures"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
