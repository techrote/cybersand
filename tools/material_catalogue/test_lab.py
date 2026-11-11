#!/usr/bin/env python3
"""Materials Lab authoring/preset adversaries and executed native candidates."""

from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import compiler
import lab


class LabTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cybersand-lab-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)

    def refuse(self, candidate, pointer):
        with self.assertRaises((lab.LabError, compiler.CatalogueError)) as caught:
            lab.expand_candidate(candidate)
        self.assertIn(pointer, str(caught.exception))

    def test_all_existing_valid_templates_expand_without_native_identity_changes(self):
        native = lab.baseline()["native"]
        for material_id in range(1, 132):
            if material_id == 10:
                continue
            with self.subTest(material=material_id):
                candidate = lab.create_candidate(material_id)
                normalized, full, changes = lab.expand_candidate(candidate)
                self.assertEqual(normalized["target_id"], material_id)
                self.assertEqual(full["native"], native)
                self.assertEqual(changes, [])

    def test_invalid_template_identity_is_not_coerced(self):
        for material_id in (0, 10, -1, 132, 255, True, 2.0, "2", None):
            with self.subTest(material=repr(material_id)), self.assertRaises(lab.LabError):
                lab.create_candidate(material_id)

    def test_synthetic132_has_explicit_nonhard_capability_and_native_shape(self):
        candidate = lab.create_candidate(2, synthetic=True)
        candidate["descriptor"]["density"] = 1337
        candidate["descriptor"]["rgba"] = [17, 91, 203, 255]
        candidate["capabilities"]["granular_support"] = False
        candidate["appearance"]["visual_state_source"] = 2
        _, full, changes = lab.expand_candidate(candidate)
        self.assertEqual(len(full["native"]["materials"]), 133)
        self.assertEqual(full["native"]["materials"][132]["name"], "synthetic-powder")
        self.assertFalse(full["native"]["capabilities"][132]["hard_surface"])
        self.assertFalse(full["native"]["capabilities"][132]["granular_support"])
        self.assertFalse(full["native"]["capabilities"][132]["pair_participant"])
        self.assertEqual(full["native"]["appearance"][132]["visual_state_source"], 2)
        self.assertEqual(len(changes), 4)

    def test_synthetic_identity_and_hard_surface_are_rejected(self):
        for material_id in (1, 3, 13, 23):
            with self.subTest(material=material_id), self.assertRaises(lab.LabError):
                lab.create_candidate(material_id, synthetic=True)
        candidate = lab.create_candidate(2, synthetic=True)
        candidate["capabilities"]["hard_surface"] = True
        self.refuse(candidate, "/capabilities/hard_surface")
        candidate = lab.create_candidate(2)
        candidate["target_id"] = 133
        self.refuse(candidate, "/target_id")
        candidate["target_id"] = 3
        self.refuse(candidate, "/target_id")

    def test_unknown_and_missing_preset_fields_fail_closed(self):
        candidate = lab.create_candidate(2)
        candidate["hot_reload"] = True
        self.refuse(candidate, "unsupported=['hot_reload']")
        candidate = lab.create_candidate(2)
        del candidate["source_catalogue_sha256"]
        self.refuse(candidate, "source_catalogue_sha256")

    def test_schema_and_source_digest_are_bound(self):
        for version in (0, 2, True, 1.0, "1"):
            candidate = lab.create_candidate(2)
            candidate["schema_version"] = version
            self.refuse(candidate, "/schema_version")
        candidate = lab.create_candidate(2)
        candidate["source_catalogue_sha256"] = "0" * 64
        self.refuse(candidate, "/source_catalogue_sha256")

    def test_name_is_only_a_bounded_display_label(self):
        for name in ("", "  ", "a" * 97, "a\nb", 42, None):
            candidate = lab.create_candidate(2)
            candidate["name"] = name
            self.refuse(candidate, "/name")
        candidate = lab.create_candidate(2)
        candidate["name"] = "  Lush green powder  "
        normalized, full, _ = lab.expand_candidate(candidate)
        self.assertEqual(normalized["name"], "Lush green powder")
        self.assertEqual(full["native"]["materials"][2]["name"], "sand")

    def test_unsupported_parameters_and_state_contracts_are_not_simulated(self):
        for field, value in (("kernel", 18), ("state", 3), ("initial_state_a", 1),
                             ("initial_state_b", 256), ("maximum_write_radius", 2),
                             ("density_motion", 2), ("movable", False), ("valid", False),
                             ("accepts_density_exchange", False), ("lateral_flow", 2),
                             ("name", "renamed-sand"), ("id", 23)):
            candidate = lab.create_candidate(2)
            candidate["descriptor"][field] = value
            self.refuse(candidate, "/descriptor/" + field)
        candidate = lab.create_candidate(2)
        candidate["descriptor"]["thermal_conductivity"] = 10
        self.refuse(candidate, "thermal_conductivity")

    def test_unused_viscosity_is_rejected_but_yielding_descriptor_is_editable(self):
        for material_id in (2, 3, 8, 12, 16):
            candidate = lab.create_candidate(material_id)
            candidate["descriptor"]["viscosity_index"] = 128
            self.refuse(candidate, "/descriptor/viscosity_index")
        for material_id in (20, 21, 24, 30, 32, 33, 36):
            candidate = lab.create_candidate(material_id)
            candidate["descriptor"]["viscosity_index"] = 128
            _, full, _ = lab.expand_candidate(candidate)
            self.assertEqual(full["native"]["materials"][material_id]["viscosity_index"], 128)

    def test_descriptor_and_visual_values_keep_exact_integer_domains(self):
        for density in (-1, 65536, True, 1600.0, "1600"):
            candidate = lab.create_candidate(2)
            candidate["descriptor"]["density"] = density
            self.refuse(candidate, "/density")
        for rgba in ([1, 2, 3], [1, 2, 3, 256], [1, True, 3, 255], [1, 2, 3.0, 255]):
            candidate = lab.create_candidate(2)
            candidate["descriptor"]["rgba"] = rgba
            self.refuse(candidate, "/rgba")
        for visual in (-1, 3, True, 1.0):
            candidate = lab.create_candidate(2)
            candidate["appearance"]["visual_state_source"] = visual
            self.refuse(candidate, "/appearance/visual_state_source")
        for value in (1, "true", None):
            candidate = lab.create_candidate(2)
            candidate["capabilities"]["granular_support"] = value
            self.refuse(candidate, "/capabilities/granular_support")

    def test_duplicate_rule_slot_and_renamed_rule_are_rejected(self):
        candidate = lab.create_candidate(3)
        candidate["reactions"].append(copy.deepcopy(candidate["reactions"][0]))
        self.refuse(candidate, "duplicate reaction slot/key")
        candidate = lab.create_candidate(3)
        candidate["reactions"][0]["rule_id"] = "int.pair.new-key.v1"
        self.refuse(candidate, "/rule_id")

    def test_rule_partners_products_probability_and_state_effects_are_strict(self):
        for field in ("first", "second", "first_product", "second_product"):
            for value in (-1, 10, 132, True, 3.0):
                candidate = lab.create_candidate(3)
                candidate["reactions"][0][field] = value
                self.refuse(candidate, "/reactions/0/" + field)
        for probability in (-1, 256, True, 0.0):
            candidate = lab.create_candidate(3)
            candidate["reactions"][0]["probability"] = probability
            self.refuse(candidate, "/reactions/0/probability")
        for effect in ({"kind": "keep_existing"}, {"kind": "set_state"},
                       {"kind": "replace_with_defaults", "state_a": 256}):
            candidate = lab.create_candidate(3)
            candidate["reactions"][0]["effects"]["first"] = effect
            self.refuse(candidate, "/effects/first")
        candidate = lab.create_candidate(3)
        candidate["reactions"][0]["effects"]["version"] = True
        self.refuse(candidate, "/effects/version")

    def test_reaction_edit_cannot_take_other_material_ownership(self):
        candidate = lab.create_candidate(2)
        candidate["reactions"] = [lab.create_candidate(3)["reactions"][0]]
        self.refuse(candidate, "not owned")
        candidate = lab.create_candidate(3)
        candidate["reactions"][0]["first"] = 2
        candidate["reactions"][0]["second"] = 23
        self.refuse(candidate, "retain this candidate")

    def test_conflicting_pair_overrides_are_rejected_by_canonical_compiler(self):
        candidate = lab.create_candidate(3)
        left, right = candidate["reactions"][:2]
        left["first"], left["second"] = right["first"], right["second"]
        left["match"] = right["match"]
        self.refuse(candidate, "ambiguous pair override")

    def test_reaction_participant_capabilities_are_regenerated(self):
        candidate = lab.create_candidate(3)
        # Replace the Lava/Water pair's Lava input with Sand; Sand has no pair
        # membership in production. No second hand-maintained array is edited.
        candidate["reactions"][0]["first"] = 2
        _, full, _ = lab.expand_candidate(candidate)
        self.assertTrue(full["native"]["capabilities"][2]["pair_participant"])

    def test_deterministic_normalization_and_export_import_round_trip(self):
        candidate = lab.create_candidate(3)
        candidate["name"] = "Zero-threshold quench"
        candidate["reactions"][0]["probability"] = 0
        exported = lab.export_candidate(candidate, self.directory / "preset.json")
        imported = lab.import_candidate(self.directory / "preset.json")
        self.assertEqual(exported["digest"], imported["digest"])
        self.assertEqual(exported["candidate"], imported["candidate"])
        self.assertEqual(imported["state"], "validated_candidate")
        reversed_candidate = copy.deepcopy(candidate)
        reversed_candidate["reactions"].reverse()
        normalized = lab.validate_candidate(reversed_candidate)
        self.assertEqual(exported["digest"], normalized["digest"])
        lab.export_candidate(reversed_candidate, self.directory / "preset2.json")
        self.assertEqual((self.directory / "preset.json").read_bytes(), (self.directory / "preset2.json").read_bytes())

    def test_reusable_example_presets_validate_against_the_same_source(self):
        fixtures = lab.ROOT / "materials/catalogue/fixtures"
        powder = lab.import_candidate(fixtures / "lab-synthetic-powder-v1.json")
        quench = lab.import_candidate(fixtures / "lab-zero-threshold-quench-v1.json")
        self.assertEqual(powder["candidate"]["target_id"], 132)
        self.assertFalse(powder["candidate"]["capabilities"]["hard_surface"])
        self.assertEqual(quench["candidate"]["reactions"][0]["probability"], 0)
        self.assertEqual(powder["candidate"]["source_catalogue_sha256"], quench["candidate"]["source_catalogue_sha256"])

    def test_unexecutable_rule_initiators_are_refused_but_inert_targets_survive(self):
        candidate = lab.create_candidate(3)
        candidate["reactions"][0].update(first=0, second=3, match=0)
        self.refuse(candidate, "active source kernel")
        candidate["reactions"][0].update(first=3, second=0, match=0)
        lab.expand_candidate(candidate)
        # Glass is inert in native source; edit its original Lava/Glass rule.
        candidate = lab.create_candidate(35)
        candidate["reactions"][0].update(first=35, second=1, match=1)
        self.refuse(candidate, "neither partner has an active kernel")
        # Original inert targets and Empty products remain legitimate.
        for template_id in (1, 35, 81, 98):
            lab.expand_candidate(lab.create_candidate(template_id))

    def test_invalid_export_preserves_previous_file(self):
        path = self.directory / "preset.json"
        candidate = lab.create_candidate(2)
        lab.export_candidate(candidate, path)
        before = path.read_bytes(), path.stat().st_mtime_ns
        candidate["descriptor"]["density"] = -1
        with self.assertRaises((lab.LabError, compiler.CatalogueError)):
            lab.export_candidate(candidate, path)
        self.assertEqual(before, (path.read_bytes(), path.stat().st_mtime_ns))

    def test_malformed_imports_and_digest_tampering_do_not_apply(self):
        path = self.directory / "preset.json"
        lab.export_candidate(lab.create_candidate(2), path)
        envelope = json.loads(path.read_text())
        envelope["candidate"]["descriptor"]["density"] = 2222
        path.write_text(json.dumps(envelope))
        with self.assertRaisesRegex(lab.LabError, "/export/digest"):
            lab.import_candidate(path)
        for raw, needle in (("{", "JSON syntax"), ('{"a":1,"a":2}', "duplicate object key"),
                            ('{"x":{"a":1,"a":2}}', "/x/a"), ('{"x":NaN}', "non-finite"),
                            ('{"x":Infinity}', "non-finite")):
            path.write_text(raw)
            with self.subTest(raw=raw), self.assertRaisesRegex(compiler.CatalogueError, needle):
                lab.read_json(path)
        path.write_bytes(b"{" + b" " * lab.MAX_JSON_BYTES)
        with self.assertRaisesRegex(lab.LabError, "exceeds"):
            lab.read_json(path)

    def test_unknown_request_and_output_into_source_repository_are_refused(self):
        for value in ({"op": "install"}, {"op": "create", "template_id": 2, "apply": True},
                      {"op": "validate"}, {}, []):
            with self.subTest(value=value), self.assertRaises(lab.LabError):
                lab.request(value)
        with self.assertRaisesRegex(lab.LabError, "outside the source repository"):
            lab.export_candidate(lab.create_candidate(2), lab.ROOT / "build/forbidden-preset.json")

    def test_cli_strict_file_protocol_returns_actionable_errors(self):
        source, response = self.directory / "request.json", self.directory / "response.json"
        source.write_text('{"op":"create","template_id":10}')
        process = subprocess.run([sys.executable, str(lab.ROOT / "tools/material_catalogue/lab.py"),
                                  "--request", str(source), "--response", str(response)], capture_output=True, text=True, timeout=20)
        self.assertEqual(process.returncode, 1, process.stderr)
        result = json.loads(response.read_text())
        self.assertFalse(result["ok"])
        self.assertFalse(result["runtime_active"])
        self.assertEqual(result["state"], "draft")
        self.assertIn("reserved invalid", result["errors"][0])

    def test_explicit_compiler_validates_one_executable_and_overrides_environment(self):
        candidate = lab.create_candidate(2)
        for value in (None, "", "  ", 4, True, [], "c++\n--version"):
            with self.subTest(cxx=repr(value)), self.assertRaisesRegex(lab.LabError, "/cxx"):
                lab.request({"op": "compile_test", "candidate": candidate, "cxx": value})
        compiler_path, compiler_is_msvc = lab._toolchain()
        with mock.patch.dict(os.environ, {"CYBERSAND_LAB_CXX": "missing-compiler-from-environment"}):
            self.assertEqual(lab._toolchain(compiler_path), (compiler_path, compiler_is_msvc))
            with self.assertRaisesRegex(lab.LabError, "/compiler"):
                lab._toolchain()
        for value in (str(self.directory / "missing compiler"), compiler_path + " --version"):
            with self.subTest(cxx=value), self.assertRaisesRegex(lab.LabError, "explicit selection does not fall back"):
                lab._toolchain(value)

    @unittest.skipIf(os.name == "nt", "The actual spaced-path compiler symlink fixture uses POSIX symlinks; Windows compiler commands require a Windows qualification host")
    def test_explicit_compiler_path_with_spaces_executes_native_candidate(self):
        compiler_path, _ = lab._toolchain()
        folder = self.directory / "Compiler installation with spaces"
        folder.mkdir()
        selected = folder / Path(compiler_path).name
        selected.symlink_to(compiler_path)
        candidate = lab.create_candidate(2, synthetic=True)
        with mock.patch.dict(os.environ, {"CYBERSAND_LAB_CXX": "missing-environment-compiler"}):
            result = lab.request({"op": "compile_test", "candidate": candidate, "cxx": str(selected)})
        self.assertEqual(result["state"], "compiled_tested")
        self.assertEqual(result["receipt"]["observed"]["candidate_material"]["id"], 132)
        self.assertTrue(result["receipt"]["observed"]["production_registry_unchanged"])

    def test_native_generated_powder132_consumes_appearance_and_explicit_capabilities(self):
        candidate = lab.create_candidate(2, synthetic=True)
        candidate["descriptor"]["density"] = 1337
        candidate["descriptor"]["rgba"] = [11, 71, 211, 255]
        candidate["capabilities"]["granular_support"] = False
        result = lab.compile_test(candidate, output_dir=self.directory / "compiled-powder")
        observed = result["receipt"]["observed"]
        self.assertEqual(result["state"], "compiled_tested")
        self.assertEqual(observed["candidate_material"]["id"], 132)
        self.assertEqual(observed["candidate_material"]["density"], 1337)
        self.assertEqual(observed["candidate_material"]["rgba"], [11, 71, 211, 255])
        self.assertFalse(observed["candidate_material"]["hard_surface"])
        self.assertFalse(observed["candidate_material"]["granular_support"])
        self.assertTrue(observed["production_registry_unchanged"])
        self.assertFalse(observed["runtime_active"])
        self.assertFalse(observed["world_simulation"])
        self.assertEqual(observed["diagnostic"]["status"], "no_matching_rule")
        self.assertGreater(observed["checks"], 100000)
        self.assertEqual(result["receipt"]["candidate_digest"], result["digest"])
        self.assertTrue((self.directory / "compiled-powder/generated/catalogue.shadow.hpp").is_file())
        self.assertTrue((self.directory / "compiled-powder/generated/catalogue_shadow.gd").is_file())
        self.assertEqual(lab.import_candidate(self.directory / "compiled-powder/preset.json")["digest"], result["digest"])
        with self.assertRaisesRegex(lab.LabError, "output already exists"):
            lab.compile_test(candidate, output_dir=self.directory / "compiled-powder")

    def test_native_reaction_zero_is_one_in_256_and_one_fails(self):
        candidate = lab.create_candidate(3)
        candidate["reactions"][0]["probability"] = 0
        for roll, status in ((0, "selected"), (1, "failed_probability_roll")):
            result = lab.compile_test(candidate, diagnostic={"source": 8, "target": 3, "roll": roll})
            observed = result["receipt"]["observed"]
            diagnostic = observed["diagnostic"]
            self.assertEqual(diagnostic["status"], status)
            self.assertEqual(diagnostic["successful_rolls_of_256"], 1)
            self.assertEqual(diagnostic["source_product"], 13)
            self.assertEqual(diagnostic["target_product"], 22)
            self.assertEqual(observed["comparison"]["different_outcomes"], 510)
            self.assertFalse(diagnostic["world_writes_executed"])
            self.assertEqual(result["receipt"]["source_identity"]["lf_sha256"]["native/include/cybersand/material.hpp"],
                             hashlib.sha256((lab.ROOT / "native/include/cybersand/material.hpp").read_bytes().replace(b"\r\n", b"\n")).hexdigest())

    def test_native_reaction_reversal_keeps_positional_products(self):
        candidate = lab.create_candidate(3)
        candidate["reactions"][0]["first_product"] = 35
        result = lab.compile_test(candidate, diagnostic={"source": 3, "target": 8, "roll": 255})
        diagnostic = result["receipt"]["observed"]["diagnostic"]
        self.assertEqual(diagnostic["status"], "selected")
        self.assertEqual(diagnostic["source_product"], 22)
        self.assertEqual(diagnostic["target_product"], 35)
        self.assertEqual(diagnostic["endpoint_effect"], "replace_with_defaults")

    def test_native_opposite_ordered_rules_use_the_complete_sparse_set(self):
        candidate = lab.create_candidate(3)
        candidate["reactions"][0].update(first=3, second=2, match=0)
        candidate["reactions"][1].update(first=2, second=3, match=0)
        result = lab.compile_test(candidate, diagnostic={"source": 2, "target": 3, "roll": 0})
        actual = result["receipt"]["observed"]["diagnostic"]
        self.assertEqual(actual["status"], "selected")
        self.assertEqual(actual["rule_slot"], candidate["reactions"][1]["slot"])

    def test_source_drift_during_real_compilation_cannot_publish_a_tested_receipt(self):
        candidate = lab.create_candidate(2)
        before = lab._source_identity()
        after = copy.deepcopy(before)
        after["lf_sha256"]["native/include/cybersand/material.hpp"] = "0" * 64
        after["digest"] = lab.digest(after["lf_sha256"])
        destination = self.directory / "must-not-publish"
        # Fault-inject source custody observations, while retaining the real
        # compiler and native executable. Do not mutate shared production files.
        with mock.patch.object(lab, "_source_identity", side_effect=[before, after]):
            with self.assertRaisesRegex(lab.LabError, "source inputs changed"):
                lab.compile_test(candidate, output_dir=destination)
        self.assertFalse(destination.exists())


if __name__ == "__main__":
    unittest.main()
