#!/usr/bin/env python3
"""Admission/custody adversaries and actual same-source native World tests."""
from __future__ import annotations
import copy
import hashlib
import json
import os
import subprocess
from pathlib import Path, PureWindowsPath
import tempfile
import unittest
from unittest import mock
import lab
import world_candidate as world


class WorldCandidateAdmissionTests(unittest.TestCase):
    def test_windows_source_paths_keep_the_complete_native_staging_inventory(self):
        # Emulate Windows relative-path spelling while reading the actual tree.
        # This catches the old backslash keys dropped by _stage's native/ filter
        # without pretending that Linux execution is Windows compilation.
        class WindowsPathView:
            def __init__(self, path):
                self.path = Path(path)

            def __truediv__(self, name):
                return WindowsPathView(self.path.joinpath(*PureWindowsPath(name).parts))

            def __str__(self):
                return str(self.path)

            def rglob(self, pattern):
                return (WindowsPathView(path) for path in self.path.rglob(pattern))

            def is_file(self):
                return self.path.is_file()

            def read_bytes(self):
                return self.path.read_bytes()

            @property
            def suffix(self):
                return self.path.suffix

            def relative_to(self, root):
                return PureWindowsPath(*self.path.relative_to(root.path).parts)

        _, expected = world._source_snapshot()
        with mock.patch.object(world, "ROOT", WindowsPathView(world.ROOT)), \
             mock.patch.object(lab, "_run", return_value=subprocess.CompletedProcess([], 0, "test-head", "")):
            identity, windows = world._source_snapshot()
        self.assertEqual(set(windows), set(expected))
        self.assertEqual(windows, expected)
        self.assertTrue(all("\\" not in name for name in identity["lf_sha256"]))
        self.assertTrue(any(name.startswith("native/src/") and name.endswith(".inc") for name in windows))

    def test_admits_existing_identity_with_supported_consumers(self):
        candidate = lab.create_candidate(2)
        candidate["descriptor"]["density"] = 500
        candidate["descriptor"]["rgba"] = [17, 23, 199, 255]
        normalized, catalogue, scenario = world.admit(candidate)
        self.assertEqual(normalized, candidate)
        self.assertEqual(catalogue["native"]["materials"][2]["density"], 500)
        self.assertEqual(scenario, {"first": 2, "second": 3, "seed": 2, "ticks": 120, "workers": 1})
        candidate = lab.create_candidate(21)
        candidate["descriptor"]["viscosity_index"] = 0
        self.assertEqual(world.admit(candidate)[1]["native"]["materials"][21]["viscosity_index"], 0)

    def test_refuses_synthetic_capability_and_projection_edits(self):
        candidates = [(lab.create_candidate(2, synthetic=True), "/target_id")]
        for key in ("hard_surface", "granular_support"):
            value = lab.create_candidate(2)
            value["capabilities"][key] = not value["capabilities"][key]
            candidates.append((value, "/capabilities/" + key))
        value = lab.create_candidate(2)
        value["appearance"]["visual_state_source"] = 2
        candidates.append((value, "/appearance/visual_state_source"))
        for candidate, pointer in candidates:
            with self.subTest(pointer=pointer), self.assertRaisesRegex(lab.LabError, pointer):
                world.admit(candidate)

    def test_scenario_bounds_types_and_candidate_presence(self):
        candidate = lab.create_candidate(2)
        base = world.admit(candidate)[2]
        cases = [(key, value) for key in ("first", "second") for value in (10, 132, -1, True, "2")]
        cases += [("ticks", value) for value in (0, 601, True, 2.0)]
        cases += [("seed", value) for value in (-1, 0x80000000, False)]
        cases += [("workers", value) for value in (0, 2, 3, 5, True)]
        for key, value in cases:
            with self.subTest(key=key, value=value), self.assertRaises(lab.LabError):
                world.admit(candidate, dict(base, **{key: value}))
        for edited in (dict(base, first=23), dict(base, unknown=True), {"first": 2}):
            with self.assertRaises(lab.LabError):
                world.admit(candidate, edited)

    def test_staging_is_external_exact_and_only_two_tables_change(self):
        identity, sources = world._source_snapshot()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            original = world._stage(root / "reference", sources, lab.baseline(), candidate=False)
            candidate = world._stage(root / "candidate", sources, lab.baseline(), candidate=True)
            self.assertEqual(original["transformations"], [])
            changed = {name for name, value in original["files_sha256"].items()
                       if value != candidate["files_sha256"][name]}
            self.assertEqual(changed, {"native/include/cybersand/material.hpp", "native/include/cybersand/interaction_rules.hpp"})
            self.assertEqual({entry["path"] for entry in candidate["transformations"]}, changed)
            for name in sources:
                if name.startswith("native/"):
                    self.assertEqual((root / "reference" / name).read_bytes(), sources[name])
            self.assertEqual(world._source_snapshot()[0]["digest"], identity["digest"])
            world._verify_stage(root / "candidate", candidate)
            (root / "candidate/native/include/cybersand/material.hpp").write_text("changed")
            with self.assertRaisesRegex(lab.LabError, "staged compiler input changed"):
                world._verify_stage(root / "candidate", candidate)

    def test_compiler_uses_staged_relative_paths_for_windows_and_gcc(self):
        # Python's Windows TEMP can contain a DOS short-name alias which MinGW
        # does not consistently resolve as an absolute compiler input path.
        with tempfile.TemporaryDirectory() as temporary:
            stage = Path(temporary) / "long staged path with spaces" / "reference"
            stage.mkdir(parents=True)
            scenario = {"first": 2, "second": 3, "seed": 2, "ticks": 1, "workers": 1}
            for msvc in (False, True):
                commands = []

                def fake_run(argv, cwd, timeout, **kwargs):
                    self.assertEqual(cwd, stage)
                    commands.append(argv)
                    if len(commands) == 1:
                        suffix = ".exe" if os.name == "nt" else ""
                        (stage / ("lab-world-probe" + suffix)).write_bytes(b"dummy native executable")
                        return subprocess.CompletedProcess(argv, 0, "", "")
                    return subprocess.CompletedProcess(argv, 0, '{"ok": true, "runtime_active": false}', "")

                with mock.patch.object(lab, "_run", side_effect=fake_run):
                    result, receipt = world._build_and_execute(
                        stage, "cl.exe" if msvc else "g++.exe", msvc,
                        scenario, 2, False)
                self.assertTrue(result["ok"])
                self.assertEqual(len(commands), 2)
                compiler = commands[0]
                for source in (world.PROBE, *world.SIMULATION_SOURCES):
                    self.assertIn(source, compiler)
                    self.assertNotIn(str(stage / source), compiler)
                if msvc:
                    self.assertIn("/Inative/include", compiler)
                    self.assertIn("/Igenerated", compiler)
                    self.assertIn("/Fe:lab-world-probe" + (".exe" if os.name == "nt" else ""), compiler)
                else:
                    self.assertIn("native/include", compiler)
                    self.assertIn("generated", compiler)
                    self.assertEqual(compiler[compiler.index("-o") + 1],
                                     "lab-world-probe" + (".exe" if os.name == "nt" else ""))
                self.assertFalse(any(str(stage) in part for part in compiler[1:]))
                self.assertEqual(receipt["native_executable_sha256"],
                                 hashlib.sha256(b"dummy native executable").hexdigest())

    def test_changed_table_shape_refuses_instead_of_guessing(self):
        declaration = "inline constexpr std::array<int, 1> table{{"
        for source in ("", declaration, declaration + "\n}};\n" + declaration + "\n}};"):
            with self.assertRaises(lab.LabError):
                world._replace_table(source, declaration, "replacement", "/table")

    def test_staging_rejects_an_unrecorded_compiler_input(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "input.cpp").write_bytes(b"original")
            manifest = {"files_sha256": {"input.cpp": hashlib.sha256(b"original").hexdigest()}}
            (root / "unrecorded.hpp").write_text("// not captured by the qualification manifest\n")
            with self.assertRaisesRegex(lab.LabError, "unrecorded staged file"):
                world._verify_stage(root, manifest)

    def test_publication_rechecks_the_copied_bytes(self):
        identity, sources = world._source_snapshot()
        candidate = lab.create_candidate(2)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            staging = root / "staging"
            staging.mkdir()
            receipt = {"source_identity": identity}
            for side in ("reference", "candidate"):
                receipt[side + "_stage"] = world._stage(staging / side, sources, lab.baseline(),
                                                       candidate=side == "candidate")
            copy_tree = world.shutil.copytree

            def changed_copy(source, destination, *args, **kwargs):
                result = copy_tree(source, destination, *args, **kwargs)
                if Path(destination).name == "candidate":
                    path = Path(destination) / "native/include/cybersand/material.hpp"
                    path.write_bytes(path.read_bytes() + b"\n// copied bytes changed\n")
                return result

            destination = root / "export"
            with mock.patch.object(world.shutil, "copytree", side_effect=changed_copy), \
                 self.assertRaisesRegex(lab.LabError, "staged compiler input changed"):
                world._publish(staging, destination, receipt, candidate, lab.digest(candidate))
            self.assertFalse(destination.exists())
            self.assertEqual(list(root.glob(".lab-world-publish-*")), [])

    def test_execution_cannot_relabel_a_changed_binary(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            executable = root / ("lab-world-probe.exe" if world.os.name == "nt" else "lab-world-probe")

            def run(command, directory, timeout, **kwargs):
                if command[0] == "review-compiler":
                    executable.write_bytes(b"qualified executable")
                    return subprocess.CompletedProcess(command, 0, "", "")
                executable.write_bytes(b"different executable after execution")
                return subprocess.CompletedProcess(command, 0,
                    json.dumps({"ok": True, "runtime_active": False}), "")

            with mock.patch.object(lab, "_run", side_effect=run), \
                 self.assertRaisesRegex(lab.LabError, "executable changed during execution"):
                world._build_and_execute(root, "review-compiler", False,
                    {"first": 2, "second": 3, "seed": 2, "ticks": 1, "workers": 1}, 2, False)

    def test_extended_effect_staging_is_explicit_and_reference_stays_original(self):
        candidate = lab.create_candidate(23)
        rule = next(row for row in candidate["reactions"] if row["slot"] == 2)
        rule.update(match=1, first_product=24, second_product=23)
        rule["effects"] = {"version": 2, "first": {"kind": "replace_with_defaults"},
                           "second": {"kind": "keep_existing"}}
        normalized, catalogue, _ = world.admit(candidate)
        _, sources = world._source_snapshot()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            reference = world._stage(root / "reference", sources, lab.baseline(), candidate=False)
            authored = world._stage(root / "candidate", sources, catalogue, candidate=True, definition=normalized)
            source = "native/src/world.cpp"
            self.assertEqual((root / "reference" / source).read_bytes(), sources[source])
            self.assertEqual(reference["transformations"], [])
            self.assertNotEqual((root / "candidate" / source).read_bytes(), sources[source])
            self.assertEqual(authored["transformations"][-1]["kind"], "external-endpoint-effects-v2")
            self.assertIn("generated/lab-reaction-effects.hpp", authored["files_sha256"])
            self.assertNotIn("generated/lab-reaction-effects.hpp", reference["files_sha256"])
            world._verify_stage(root / "candidate", authored)

    def test_effect_receipt_requires_matching_compiled_endpoint_readback(self):
        candidate = lab.create_candidate(28)
        rule = next(row for row in candidate["reactions"] if row["slot"] == 9)
        rule.update(match=1, first_product=4, second_product=28)
        rule["effects"] = {"version": 2, "first": {"kind": "replace_with_defaults"},
                           "second": {"kind": "set_state", "state_b": 77}}
        observed = {"endpoint_effects": {"version": 2, "extended_slots": [{"slot": 9,
            "first": {"kind": "replace_with_defaults", "state_b": 0},
            "second": {"kind": "set_state", "state_b": 77}}]}}
        world._verify_effect_readback(observed, candidate)
        for changed in ({}, {"endpoint_effects": {"version": 1, "extended_slots": []}},
                        copy.deepcopy(observed)):
            if changed.get("endpoint_effects", {}).get("version") == 2:
                changed["endpoint_effects"]["extended_slots"][0]["second"]["state_b"] = 76
            with self.assertRaisesRegex(lab.LabError, "compiled endpoint effects"):
                world._verify_effect_readback(changed, candidate)
        world._verify_effect_readback({"endpoint_effects": {"version": 1, "extended_slots": []}}, None)

    def test_custody_precedes_preflight_and_blocks_drift(self):
        candidate = lab.create_candidate(2)
        actual, _ = world._source_snapshot()
        drift = copy.deepcopy(actual)
        drift["digest"] = "0" * 64
        order = []
        def snapshot():
            order.append("snapshot")
            return (actual if len(order) == 1 else drift), {}
        def validate(value):
            order.append("validate")
            return {"digest": lab.digest(value)}
        with mock.patch.object(world, "_source_snapshot", side_effect=snapshot), \
             mock.patch.object(lab, "validate_candidate", side_effect=validate), \
             mock.patch.object(world, "_stage", return_value={"files_sha256": {}}), \
             mock.patch.object(world, "_build_and_execute", return_value=({}, {})), \
             self.assertRaisesRegex(lab.LabError, "source inputs changed"):
            world.compile_world_test(candidate)
        self.assertEqual(order[:2], ["snapshot", "validate"])


class NativeWorldCandidateTests(unittest.TestCase):
    """Real compiled World executions; no mocked acceptance."""
    def assert_native(self, result):
        self.assertEqual(result["state"], "compiled_tested")
        self.assertFalse(result["runtime_active"])
        receipt = result["receipt"]
        self.assertEqual(receipt["source_identity"]["digest"], receipt["source_identity_after"])
        for side in ("reference", "candidate"):
            native = receipt[side]
            self.assertTrue(native["world_simulation"])
            self.assertTrue(all(native["checks"].values()), native["checks"])
            self.assertGreater(native["persistence_bytes"], 0)
            self.assertGreater(native["visited_cells"], 0)
            self.assertEqual(native["final"]["completed_ticks"], receipt["scenario"]["ticks"])
            self.assertEqual(native["worker_1"]["physical_state_hash"], native["worker_4"]["physical_state_hash"])
            self.assertEqual(native["final"]["physical_state_hash"], native["restored"]["physical_state_hash"])
            self.assertEqual(native["final"]["material_cells"][10], 0)
            self.assertEqual(sum(native["final"]["material_cells"][132:]), 0)
            grid = native["final"]["grid"]
            self.assertEqual(sum(row[0] for row in grid["runs"]), 132 * 184)
            self.assertTrue(all(len(row) == 5 and 0 <= row[1] < 132 and row[1] != 10 for row in grid["runs"]))
            self.assertEqual(len(native["palette_rgba"]), 132)
        return receipt

    def test_unchanged_tables_match_untouched_world(self):
        receipt = self.assert_native(world.compile_world_test(lab.create_candidate(2)))
        self.assertTrue(receipt["checks"]["unchanged_candidate_parity"])
        self.assertTrue(receipt["comparison"]["equal"])
        self.assertEqual(receipt["candidate"]["final"]["grid"], receipt["reference"]["final"]["grid"])

    def test_short_static_persistence_uses_complete_physical_owner(self):
        receipt = self.assert_native(world.compile_world_test(lab.create_candidate(35),
            scenario={"first": 35, "second": 3, "seed": 2, "ticks": 1, "workers": 4}))
        self.assertTrue(receipt["comparison"]["equal"])
        # Native restore normalizes coarse quiet bookkeeping, not physical state.
        self.assertFalse(receipt["candidate"]["persistence_checkpoint_legacy_hash_equal"])

    def test_density_changes_movement_and_exports_replayable_sources(self):
        candidate = lab.create_candidate(2)
        candidate["descriptor"]["density"] = 500
        candidate["descriptor"]["rgba"] = [17, 91, 203, 255]
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "world-fixture"
            receipt = self.assert_native(world.compile_world_test(candidate, output_dir=destination))
            self.assertFalse(receipt["comparison"]["equal"])
            self.assertEqual(receipt["candidate"]["descriptor_readback"]["density"], 500)
            self.assertEqual(receipt["candidate"]["descriptor_readback"]["rgba"], [17, 91, 203, 255])
            self.assertLess(receipt["candidate"]["final"]["target_below_reservoir"],
                            receipt["reference"]["final"]["target_below_reservoir"])
            self.assertEqual(receipt["candidate"]["final"]["water_quantity"], receipt["reference"]["final"]["water_quantity"])
            self.assertEqual(lab.import_candidate(destination / "preset.json")["candidate"], candidate)
            self.assertEqual(json.loads((destination / "world-receipt.json").read_text()), receipt)
            for side in ("reference", "candidate"):
                for name, expected in receipt[side + "_stage"]["files_sha256"].items():
                    self.assertEqual(hashlib.sha256((destination / side / name).read_bytes()).hexdigest(), expected)
                self.assertFalse((destination / side / "lab-world-probe").exists())
                self.assertFalse((destination / side / "lab-world-probe.exe").exists())

    def test_pair_products_are_applied_by_world_with_quantity_accounting(self):
        candidate = lab.create_candidate(23)
        rule = next(row for row in candidate["reactions"] if row["slot"] == 2)
        rule["first_product"] = 13
        rule["second_product"] = 13
        receipt = self.assert_native(world.compile_world_test(candidate))
        self.assertFalse(receipt["comparison"]["equal"])
        self.assertGreater(receipt["candidate"]["final"]["quantity_ledger"]["pair_events"][2], 0)
        self.assertGreater(receipt["candidate"]["final"]["material_cells"][13], 0)
        self.assertEqual(receipt["reference"]["final"]["material_cells"][13], 0)
        self.assertGreater(receipt["reference"]["final"]["material_cells"][24], 0)
        self.assertEqual(receipt["candidate"]["final"]["material_cells"][24], 0)


if __name__ == "__main__":
    unittest.main()
