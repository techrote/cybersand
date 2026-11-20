#!/usr/bin/env python3
"""Exercise real publisher custody with synthetic receipt/runtime fixtures.

These tests prove fail-closed publication, not native execution. The actual
Linux/Windows campaigns must supply their original receipts independently.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import unittest
from unittest import mock

import gen007_architectural_runtime_publication as historical
import gentek80_runtime_publication as subject
import test_gen007_architectural_runtime_publication as original_tests


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def receipt_bytes(value: dict) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def workbench(source: str = "a" * 40, runtime: str = "b" * 64, platform: str = "linux") -> dict:
    ids = ["fixture-" + str(index) for index in range(80)]
    value = {"schema": "gentek80-workbench-qualification-v1", "passed": True, "failures": 0,
             "source_commit": source, "runtime_sha256": runtime, "graphical_requested": True,
             "platform": platform, "smoke": 0, "independent_processes": True,
             "material_and_recipe_replay": True,
             "results": [{"case": phase, "passed": True, "returncode": 0, "timed_out": False}
                         for phase in subject.WORKBENCH_PHASES]}
    for index, phase in enumerate(("author", "reopen")):
        value[phase] = {"schema": "gentek80-workbench-phase-v1", "phase": phase,
                        "source_commit": source, "display": "Windows" if platform == "windows" else "X11",
                        "styles": 80, "failures": 0, "checks": 1200, "completed": True,
                        "process_id": 100 + index, "catalogue_ids": ids,
                        "cases": [{"case": "gentek80-" + phase, "preset_id": preset_id,
                                   "source_sha256": digest(preset_id), "recipe_sha256": digest("recipe" + preset_id)}
                                  for preset_id in ids]}
    return value


def flatten_results(runtime: str = "b" * 64, platform: str = "linux", build_inputs: dict | None = None) -> list[dict]:
    if build_inputs is None:
        build_inputs = {"godot/" + name: digest(name)
                        for name in subject.FLATTEN_SCRIPTS | {subject.FLATTEN_OWNER_SCRIPT}}
    result = []
    for index, label in enumerate(subject.FLATTEN_RESULTS):
        pid = 500 + index
        row = {"label": label, "status": "passed", "exit_code": 0, "pid": pid,
               "engine_executable_sha256": digest("pinned Godot fixture")}
        if index >= 2:
            owner = label.startswith("owner-failure-")
            phase = "reopen" if label.endswith("-reopen") else "author"
            scripts = subject.FLATTEN_SCRIPTS | ({subject.FLATTEN_OWNER_SCRIPT} if owner else set())
            identity = {name: build_inputs["godot/" + name] for name in scripts}
            identity.update(native_sha256=runtime, os="Windows" if platform == "windows" else "Linux",
                            display="Windows" if platform == "windows" else "X11", godot="4.7-stable (official)")
            completion = {"completed": True, "failures": [], "phase": phase, "checks": 100,
                          "pid": pid, "process_instance": digest(str(pid))[:32],
                          "side": 512, "canonical_bytes": 512 * 512 * 2, "source_identity": identity}
            if owner:
                completion.update(schema="gen008-flatten-owner-failure-v1",
                                  expected_plane_sha256=digest("saved plane"),
                                  saved_baseline_sha256=digest("saved baseline"),
                                  saved_file_sha256=digest("saved file"))
                if phase == "reopen":
                    completion["reconstructed_plane_sha256"] = digest("saved plane")
            else:
                completion["workers"] = 1
            row["completion"] = completion
        result.append(row)
    return result


def gallery(source: str = "a" * 40, runtime: str = "b" * 64,
            tree: str = "c" * 40, ledger: dict | None = None) -> dict:
    ledger = {"native/src/fixture.cpp": "d" * 64} if ledger is None else ledger
    presets = [{"id": "fixture-" + str(index), "module": "module_" + str(index), "module_version": 1}
               for index in range(80)]
    cases, rejections = [], []
    for index, preset in enumerate(presets):
        family = "classic" if index < 72 else "showcase"
        profiles = subject.COMMON_PROFILES | (subject.SHOWCASE_PROFILES if family == "showcase" else set())
        for profile in sorted(profiles):
            name = preset["module"] + "--" + profile
            cases.append({"name": name, "module": preset["module"], "preset_id": preset["id"],
                          "module_version": 1,
                          "profile": profile, "family": family, "status": "pass",
                          "extent": [512, 512], "seed": 271828,
                          "material_sha256": digest(name), "occupancy_sha256": digest("occupancy" + name),
                          "recipe_sha256": digest("recipe" + name), "project_sha256": digest("project" + name),
                          "fingerprint": digest(name)[:16],
                          "receipts": {"0,0": digest("receipt" + name)[:16]}})
        rejections += [{"module": preset["module"], "profile": profile, "status": "pass",
                        "expected_refusal": True, "error": "native bounds refusal"}
                       for profile in sorted(subject.REJECTION_PROFILES)]
    defaults = [case for case in cases if case["profile"] == "default"]
    reference = {"schema": "gentek80-public-gallery-v1", "source_commit": "f" * 40,
                 "source_tree": "e" * 40, "rendering_inputs_sha256": copy.deepcopy(ledger),
                 "defaults": [dict(case, png=case["name"] + ".png",
                                   png_sha256=digest("png" + case["name"]),
                                   rgba_sha256=digest("rgba" + case["name"])) for case in defaults]}
    return {
        "gallery_identity": {"schema": 1, "status": "pass", "scope": "complete 80-Gentek catalogue",
            "source_and_runtime_unchanged": True, "original_native_pngs": 520,
            "distinct_default_genteks": 80, "replayed_default_genteks": 80,
            "source": {"commit": source, "tree": tree, "uncommitted_source_paths": [], "inputs": ledger},
            "runtime": {"sha256": runtime},
            "reference_gallery_comparison": "reference-gallery-comparison.json",
            "processes": [{"phase": phase, "returncode": 0, "timed_out": False,
                           "unexpected_diagnostics": [], "log_sha256": digest(phase)} for phase in ("capture", "replay")]},
        "gallery_campaign": {"schema": 1, "phase": "capture", "complete": True, "failures": [],
                              "checks": 5000, "cases": cases, "rejections": rejections},
        "gallery_reload": {"schema": 1, "phase": "replay", "complete": True, "failures": [],
                            "checks": 500, "cases": copy.deepcopy(defaults)},
        "gallery_catalogue": {"genteks": presets, "native": {"modules":
            [{"id": preset["module"], "version": 1} for preset in presets]
            + [{"id": "legacy_" + str(index), "version": 1} for index in range(11)]}},
        "gallery_pixels": {"schema": 1, "cases": [{"name": case["name"], "module": case["module"],
            "profile": case["profile"], "extent": case["extent"], "material_sha256": case["material_sha256"],
            "rgba_sha256": digest("rgba" + case["name"]),
            "png_sha256": digest("png" + case["name"]), "native_pixels_verified": True} for case in cases]},
        "gallery_build": {"schema": "gentek80-native-build-v1", "source_commit": source, "source_tree": tree,
                           "runtime_sha256": runtime, "source_inputs_sha256": ledger, "returncode": 0},
        "gallery_reference": reference,
        "gallery_comparison": {"schema": "gentek80-reference-comparison-v1", "status": "pass", "failures": [],
            "reference_source_commit": reference["source_commit"], "reference_source_tree": reference["source_tree"],
            "candidate_source_commit": source, "candidate_source_tree": tree, "candidate_runtime_sha256": runtime,
            "reference_manifest_sha256": hashlib.sha256(receipt_bytes(reference)).hexdigest(),
            "rendering_inputs_equal": True, "reference_defaults": 80, "fresh_defaults": 80, "matched_defaults": 80,
            "cases": [{"module": case["module"], "preset_id": case["preset_id"], "matches": True,
                       "material_sha256": case["material_sha256"], "rgba_sha256": digest("rgba" + case["name"])}
                      for case in defaults]},
    }


class Gentek80ReceiptGuards(unittest.TestCase):
    def test_new_scope_does_not_mutate_historical_publisher(self):
        self.assertEqual(subject.engine.BRANCH, "integration/gentek-80-001")
        self.assertEqual(subject.engine.WORKFLOW, ".github/workflows/gentek80-qualification.yml")
        self.assertEqual(subject.engine.BUNDLE_PREFIX, "gentek80-validated")
        self.assertEqual(historical.engine.BRANCH, "feat/gen007-architectural-generator-ab")
        for path in ("tools/architecture/gentek80_workbench.py", "tools/architecture/gentek80_campaign.py",
                     "tools/ci/gentek80_runtime_publication.py", "tools/ci/test_gentek80_runtime_publication.py",
                     "tools/architecture/compare_interlaced_compilers.py",
                     "tools/architecture/test_compare_interlaced_compilers.py",
                     subject.PUBLIC_GALLERY_MANIFEST):
            self.assertIn(path, subject.engine.BUILD_EXACT)

    def test_evolved_assertion_counts_keep_all_legacy_phases(self):
        value = original_tests.architecture()
        value["cases"][2]["completion"] = ["2800"]
        value["cases"][3]["completion"] = ["ARCHITECTURAL_UI checks=61 failures=0"]
        subject.validate_architecture(value, "a" * 40, "b" * 64)
        for phase in ("legacy-material-equivalence", "source-stability", "multistyle-reopen"):
            candidate = copy.deepcopy(value)
            candidate["cases"] = [row for row in candidate["cases"] if row["case"] != phase]
            with self.assertRaises(RuntimeError):
                subject.validate_architecture(candidate, "a" * 40, "b" * 64)
        value["cases"][2]["completion"] = ["811"]
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(value, "a" * 40, "b" * 64)

    def test_workbench_requires_independent_full_graphical_material_replay(self):
        subject.validate_workbench(workbench(), "a" * 40, "b" * 64, "linux")
        mutations = [lambda v: v.update(graphical_requested=False), lambda v: v.update(smoke=4),
                     lambda v: v.update(failures=False), lambda v: v.update(runtime_sha256="e" * 64),
                     lambda v: v["reopen"].update(process_id=v["author"]["process_id"]),
                     lambda v: v["author"].update(display="headless"),
                     lambda v: v["author"]["cases"].pop(),
                     lambda v: v["reopen"]["cases"][0].update(source_sha256="e" * 64),
                     lambda v: v["results"].pop()]
        for mutate in mutations:
            value = workbench()
            mutate(value)
            with self.assertRaises(RuntimeError):
                subject.validate_workbench(value, "a" * 40, "b" * 64, "linux")

    def test_flatten_requires_current_runtime_scripts_and_independent_graphical_processes(self):
        ledger = {"godot/" + name: digest(name)
                  for name in subject.FLATTEN_SCRIPTS | {subject.FLATTEN_OWNER_SCRIPT}}
        subject.validate_flatten_results(flatten_results(), "b" * 64, "linux", ledger)
        mutations = [lambda v: v.pop(), lambda v: v[0].update(exit_code=1),
                     lambda v: v[2]["completion"]["source_identity"].update(native_sha256="e" * 64),
                     lambda v: v[2]["completion"]["source_identity"].update({"scripts/main.gd": "e" * 64}),
                     lambda v: v[2]["completion"]["source_identity"].pop("scripts/shared_workbench.gd"),
                     lambda v: v[2]["completion"]["source_identity"].update(display="headless"),
                     lambda v: v[2]["completion"]["source_identity"].update(os="Windows"),
                     lambda v: v[2]["completion"].update(failures=["unreported failure"]),
                     lambda v: v[3]["completion"].update(process_instance=v[2]["completion"]["process_instance"]),
                     lambda v: v[5]["completion"].update(reconstructed_plane_sha256="e" * 64),
                     lambda v: v[2]["completion"].update(pid=9999)]
        for mutate in mutations:
            value = flatten_results()
            mutate(value)
            with self.assertRaises(RuntimeError):
                subject.validate_flatten_results(value, "b" * 64, "linux", ledger)

    def test_gallery_requires_complete_distinct_captures_replay_and_refusals(self):
        baseline = gallery()
        ledger = baseline["gallery_build"]["source_inputs_sha256"]
        subject.validate_gallery(baseline, "a" * 40, "b" * 64, "c" * 40, ledger)
        mutations = [lambda v: v["gallery_identity"].update(scope="subset iteration"),
                     lambda v: v["gallery_identity"]["source"].update(uncommitted_source_paths=["native/src/fixture.cpp"]),
                     lambda v: v["gallery_identity"].update(runtime=[]),
                     lambda v: v["gallery_build"].update(returncode=1),
                     lambda v: v["gallery_campaign"]["cases"].pop(),
                     lambda v: v["gallery_campaign"]["rejections"].pop(),
                     lambda v: v["gallery_catalogue"]["genteks"][0].update(module="module_1"),
                     lambda v: v["gallery_catalogue"]["native"]["modules"].pop(),
                     lambda v: v["gallery_reload"]["cases"][0].update(material_sha256="e" * 64),
                     lambda v: v["gallery_pixels"]["cases"][0].update(native_pixels_verified=False),
                     lambda v: v["gallery_identity"]["processes"][1].update(timed_out=True)]
        for mutate in mutations:
            candidate = copy.deepcopy(baseline)
            mutate(candidate)
            with self.assertRaises(RuntimeError):
                subject.validate_gallery(candidate, "a" * 40, "b" * 64, "c" * 40, ledger)


    def test_public_gallery_recomputes_all_defaults_and_binds_both_sources(self):
        baseline = gallery()
        reference_hash = hashlib.sha256(receipt_bytes(baseline["gallery_reference"])).hexdigest()
        subject.validate_reference_gallery(baseline, "a" * 40, "b" * 64, "c" * 40, reference_hash)
        mutations = [lambda v: v["gallery_identity"].update(reference_gallery_comparison=None),
                     lambda v: v["gallery_reference"].update(source_commit="unknown"),
                     lambda v: v["gallery_reference"].update(rendering_inputs_sha256={}),
                     lambda v: v["gallery_comparison"].update(candidate_source_commit="e" * 40),
                     lambda v: v["gallery_comparison"].update(candidate_source_tree="e" * 40),
                     lambda v: v["gallery_comparison"].update(reference_source_commit="e" * 40),
                     lambda v: v["gallery_comparison"].update(candidate_runtime_sha256="e" * 64),
                     lambda v: v["gallery_comparison"].update(reference_manifest_sha256="e" * 64),
                     lambda v: v["gallery_comparison"].update(matched_defaults=79),
                     lambda v: v["gallery_comparison"].update(failures=["divergence"]),
                     lambda v: v["gallery_comparison"]["cases"].pop(),
                     lambda v: v["gallery_comparison"]["cases"][0].update(matches=False),
                     lambda v: v["gallery_comparison"]["cases"][0].update(material_sha256="e" * 64),
                     lambda v: v["gallery_reference"]["defaults"].pop(),
                     lambda v: v["gallery_reference"]["defaults"][0].update(preset_id="fixture-1"),
                     lambda v: v["gallery_reference"]["defaults"][0].update(material_sha256="e" * 64),
                     lambda v: v["gallery_reference"]["defaults"][0].update(project_sha256="e" * 64),
                     lambda v: v["gallery_reference"]["defaults"][0].update(rgba_sha256="e" * 64),
                     lambda v: v["gallery_pixels"]["cases"][1].update(rgba_sha256="e" * 64)]
        for index, mutate in enumerate(mutations):
            with self.subTest(mutation=index):
                candidate = copy.deepcopy(baseline)
                mutate(candidate)
                with self.assertRaises(RuntimeError):
                    subject.validate_reference_gallery(candidate, "a" * 40, "b" * 64, "c" * 40, reference_hash)


class Gentek80PublicationRoundtrip(unittest.TestCase):
    def setUp(self):
        # Reuse the established real local-Git/lease/runtime-header fixture.
        # Its executable/runtime bytes are deliberately synthetic and labelled.
        patch = mock.patch.object(original_tests, "subject", subject)
        patch.start()
        self.addCleanup(patch.stop)
        self.fixture = original_tests.PublicationRoundtrip(methodName="runTest")
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        # Commit an actual public-gallery manifest before recording any build.
        # This makes receipt substitution cross a real Git/blob trust boundary.
        ledger = subject.engine.input_ledgers(self.fixture.source)["source_inputs"]
        subject.engine.write_json(self.fixture.root / subject.PUBLIC_GALLERY_MANIFEST,
                                  gallery(ledger=ledger)["gallery_reference"])
        self.fixture.git("add", subject.PUBLIC_GALLERY_MANIFEST)
        self.fixture.git("commit", "--quiet", "-m", "Pin public 80-style gallery fixture")
        self.fixture.source = self.fixture.git("rev-parse", "HEAD").decode().strip()
        self.fixture.git("push", "--quiet", "origin", "HEAD:refs/heads/" + subject.engine.BRANCH)
        patch = mock.patch.dict(os.environ, {"GITHUB_SHA": self.fixture.source})
        patch.start()
        self.addCleanup(patch.stop)

    def candidate(self, platform: str):
        args = self.fixture.candidate(platform)
        args.workbench = args.bundle.parent / "workbench"
        args.gallery = args.bundle.parent / "gallery"
        args.package_workbench = args.bundle.parent / "package-workbench"
        for path in (args.workbench, args.gallery, args.package_workbench):
            path.mkdir()
        manifest = subject.read_json(subject.engine.manifest_path(args.bundle, platform))
        value = workbench(self.fixture.source, manifest["sha256"], platform)
        for path in (args.workbench, args.package_workbench):
            subject.engine.write_json(path / "qualification.json", value)
        for path in (args.flatten, args.package_flatten):
            subject.engine.write_json(path / "results.json",
                flatten_results(manifest["sha256"], platform, manifest["build_inputs"]))
        receipts = gallery(self.fixture.source, manifest["sha256"], manifest["source_tree"], manifest["source_inputs"])
        for name, filename in subject.GALLERY_FILES.items():
            subject.engine.write_json(args.gallery / filename, receipts[name])
        return args

    def test_both_target_platforms_accept_verify_and_stage_exact_four_paths(self):
        candidates = {platform: self.candidate(platform) for platform in ("linux", "windows")}
        for args in candidates.values():
            manifest = self.fixture.accept(args)
            self.assertEqual(manifest["status"], "validated-development-runtime")
        subject.engine.stage(argparse.Namespace(source_sha=self.fixture.source,
            linux_bundle=candidates["linux"].bundle, windows_bundle=candidates["windows"].bundle))
        for platform, args in candidates.items():
            self.assertEqual((self.fixture.root / subject.engine.MANIFESTS[platform]).read_bytes(),
                             subject.engine.manifest_path(args.bundle, platform).read_bytes())
            self.assertEqual((self.fixture.root / subject.engine.RUNTIMES[platform]).read_bytes(),
                             (args.bundle / Path(subject.engine.RUNTIMES[platform]).name).read_bytes())

    def test_missing_partial_or_stale_receipt_never_marks_bundle_validated(self):
        args = self.candidate("linux")
        path = args.gallery / "campaign-identity.json"
        receipt = subject.read_json(path)
        receipt["original_native_pngs"] = 32
        subject.engine.write_json(path, receipt)
        with self.assertRaises(RuntimeError):
            self.fixture.accept(args)
        self.assertEqual(subject.read_json(subject.engine.manifest_path(args.bundle, "linux"))["status"], "built-not-executed")
        self.assertFalse((args.bundle / "validation.json").exists())

    def test_original_receipt_tampering_is_detected(self):
        args = self.candidate("linux")
        self.fixture.accept(args)
        path = args.bundle / subject.RECEIPTS["gallery_pixels"]
        path.write_bytes(path.read_bytes() + b"\n")
        with self.assertRaisesRegex(RuntimeError, "missing or modified"):
            subject.engine.verify_bundle(args.bundle, "linux", self.fixture.source, validated=True)

    def test_missing_or_malformed_public_reference_cannot_mark_bundle_validated(self):
        args = self.candidate("linux")
        for name in ("gallery_reference", "gallery_comparison"):
            path = args.gallery / subject.GALLERY_FILES[name]
            original = path.read_bytes()
            for malformed in (None, b"not a JSON receipt\n"):
                with self.subTest(receipt=name, malformed=malformed):
                    if malformed is None:
                        path.unlink()
                    else:
                        path.write_bytes(malformed)
                    with self.assertRaises(RuntimeError):
                        self.fixture.accept(args)
                    self.assertEqual(subject.read_json(subject.engine.manifest_path(args.bundle, "linux"))["status"],
                                     "built-not-executed")
                    self.assertFalse((args.bundle / "validation.json").exists())
                    path.write_bytes(original)

    def test_rehashed_public_reference_cannot_substitute_the_committed_gallery(self):
        args = self.candidate("linux")
        self.fixture.accept(args)
        reference_path = args.bundle / subject.RECEIPTS["gallery_reference"]
        reference = subject.read_json(reference_path)
        reference["source_commit"] = "d" * 40
        subject.engine.write_json(reference_path, reference)
        comparison_path = args.bundle / subject.RECEIPTS["gallery_comparison"]
        comparison = subject.read_json(comparison_path)
        comparison["reference_source_commit"] = reference["source_commit"]
        comparison["reference_manifest_sha256"] = subject.engine.runner.sha256(reference_path)
        subject.engine.write_json(comparison_path, comparison)
        report = subject.read_json(args.bundle / "validation.json")
        for name in ("gallery_reference", "gallery_comparison"):
            report["receipts"][name]["sha256"] = subject.engine.runner.sha256(args.bundle / subject.RECEIPTS[name])
        self.fixture.reseal_report(args, report)
        with self.assertRaisesRegex(RuntimeError, "committed build input"):
            subject.engine.verify_bundle(args.bundle, "linux", self.fixture.source, validated=True)

    def test_rehashed_flatten_receipt_cannot_substitute_an_older_runtime(self):
        args = self.candidate("linux")
        self.fixture.accept(args)
        path = args.bundle / subject.RECEIPTS["flatten_results"]
        results = subject.read_flatten_results(path)
        results[2]["completion"]["source_identity"]["native_sha256"] = "e" * 64
        subject.engine.write_json(path, results)
        report = subject.read_json(args.bundle / "validation.json")
        report["receipts"]["flatten_results"]["sha256"] = subject.engine.runner.sha256(path)
        self.fixture.reseal_report(args, report)
        with self.assertRaisesRegex(RuntimeError, "stale runtime/script"):
            subject.engine.verify_bundle(args.bundle, "linux", self.fixture.source, validated=True)

    def test_rehashed_report_cannot_reduce_scope_or_drop_package_workbench(self):
        args = self.candidate("windows")
        self.fixture.accept(args)
        original = subject.read_json(args.bundle / "validation.json")
        for name in ("scope", "package_workbench", "source_inputs"):
            report = copy.deepcopy(original)
            if name == "scope":
                report["scope"] = "catalogue count only"
            elif name == "source_inputs":
                report["source_inputs"] = {}
            else:
                del report["receipts"][name]
            self.fixture.reseal_report(args, report)
            with self.assertRaises(RuntimeError):
                subject.engine.verify_bundle(args.bundle, "windows", self.fixture.source, validated=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
