"""Adverse controls for source-byte, backend and publication compatibility."""
from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

import compatibility as guard


class CompatibilityGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = guard.retained_sources()
        cls.lock = guard.build_lock(cls.sources)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mat-auth-compat-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for relative, data in self.sources.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.lock_path = self.root / guard.LOCK
        self.lock_path.parent.mkdir(parents=True, exist_ok=True)
        self.write_lock(self.lock)

    def write_lock(self, value):
        self.lock_path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

    def check(self):
        return guard.check(self.root)

    def reject(self, expression):
        with self.assertRaisesRegex(guard.CompatibilityError, expression):
            self.check()

    def test_current_source_passes_without_writing(self):
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns)
                  for p in self.root.rglob("*") if p.is_file()}
        result = self.check()
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["protected_sources"], 27)
        self.assertFalse(result["production_cutover"])
        self.assertFalse(result["runtime_execution"])
        self.assertEqual(before, {p: (p.read_bytes(), p.stat().st_mtime_ns)
                                  for p in self.root.rglob("*") if p.is_file()})

    def test_formatting_only_header_change_is_not_value_parity(self):
        path = self.root / guard.CATALOGUE_SOURCES[0]
        path.write_bytes(b"// harmless-looking generated banner\n" + path.read_bytes())
        self.reject("material.hpp: LF source-byte drift")

    def test_crlf_normalization_matches_existing_identity_contract(self):
        for name in guard.CATALOGUE_SOURCES:
            path = self.root / name
            path.write_bytes(guard.lf(path.read_bytes()).replace(b"\n", b"\r\n"))
        self.assertEqual(self.check()["catalogue_digest"], self.lock["catalogue_digest"])

    def test_changed_source_and_refreshed_hash_cannot_rebaseline(self):
        value = copy.deepcopy(self.lock)
        name = guard.CATALOGUE_SOURCES[1]
        path = self.root / name
        path.write_bytes(path.read_bytes() + b"\n// generated row reordering\n")
        for entry in value["source_locks"]:
            if entry["path"] == name:
                entry["lf_sha256"] = guard.sha(path.read_bytes())
        value["catalogue_digest"] = guard.catalogue_digest(
            {p: (self.root / p).read_bytes() for p in guard.CATALOGUE_SOURCES})
        self.write_lock(value)
        self.reject("/source_locks: differs from immutable")

    def test_missing_protected_consumer_is_not_skipped(self):
        (self.root / "native/src/world_quantity.inc").unlink()
        self.reject("world_quantity.inc: required legacy consumer unavailable")

    def test_dropped_lock_entry_is_rejected(self):
        value = copy.deepcopy(self.lock)
        value["source_locks"].pop()
        self.write_lock(value)
        self.reject("/source_locks: differs from immutable")

    def test_renamed_baseline_is_rejected(self):
        value = copy.deepcopy(self.lock)
        value["source_commit"] = "f" * 40
        self.write_lock(value)
        self.reject("/source_commit: expected retained")

    def test_schema_boolean_cannot_alias_integer(self):
        value = copy.deepcopy(self.lock)
        value["schema_version"] = True
        self.write_lock(value)
        self.reject("/schema_version: supported version is integer 1")

    def test_duplicate_json_keys_fail(self):
        text = self.lock_path.read_text()
        self.lock_path.write_text(text.replace('"schema_version": 1,',
                                               '"schema_version": 1, "schema_version": 1,'))
        self.reject("duplicate JSON key")

    def test_unknown_top_level_field_fails(self):
        value = copy.deepcopy(self.lock)
        value["accept_new_identity"] = True
        self.write_lock(value)
        self.reject("expected exactly")

    def test_nonfinite_lock_fails(self):
        self.lock_path.write_text(self.lock_path.read_text().replace('"schema_version": 1',
                                                                    '"schema_version": NaN'))
        self.reject("non-finite JSON value")

    def test_fallback_density_is_not_normalized_to_native(self):
        path = self.root / "godot/scripts/cell_world.gd"
        before = path.read_bytes()
        self.assertIn(b"\t\tSLUSH:\n\t\t\treturn 1100", before)
        path.write_bytes(before.replace(b"\t\tSLUSH:\n\t\t\treturn 1100",
                                        b"\t\tSLUSH:\n\t\t\treturn 1080"))
        self.reject("cell_world.gd: LF source-byte drift")

    def test_fallback_fact_cannot_claim_native_density(self):
        value = copy.deepcopy(self.lock)
        value["fallback_source_facts"]["density_by_byte_id"][21] = 1080
        value["fallback_source_facts"]["slush_density"] = 1080
        self.write_lock(value)
        self.reject("/fallback_source_facts: differs from immutable")

    def test_fallback_boolean_is_not_an_id(self):
        value = copy.deepcopy(self.lock)
        value["fallback_source_facts"]["identity_constants"]["WALL"] = True
        self.write_lock(value)
        self.reject("/fallback_source_facts: differs from immutable")

    def test_policy_vector_drift_is_not_regenerated_away(self):
        path = self.root / "docs/reference/liquid-policy-wire-vectors.json"
        path.write_bytes(path.read_bytes() + b" ")
        self.reject("liquid-policy-wire-vectors.json: LF source-byte drift")

    def test_world_state_or_wake_change_requires_separate_admission(self):
        path = self.root / "native/src/world.cpp"
        path.write_bytes(path.read_bytes() + b"\n// changed endpoint or wake authority\n")
        self.reject("world.cpp: LF source-byte drift")

    def test_new_native_consumer_cannot_import_shadow(self):
        path = self.root / "native/src/accidental_cutover.cpp"
        path.write_text('#include "materials/catalogue/generated/catalogue_shadow.hpp"\n')
        self.reject("accidental_cutover.cpp: production/native test imports shadow output")

    def test_new_godot_consumer_cannot_load_shadow(self):
        path = self.root / "godot/scripts/accidental_cutover.gd"
        path.write_text('const Bad = preload("res://catalogue_shadow.gd")\n')
        self.reject("accidental_cutover.gd: production/native test imports shadow output")

    def test_basename_only_candidate_include_is_refused(self):
        path = self.root / "native/src/accidental_cutover.cpp"
        path.write_text('#include "catalogue.shadow.hpp"\n')
        self.reject("accidental_cutover.cpp: production/native test imports shadow output")

    def test_native_include_fragments_and_cpp_suffixes_are_protected(self):
        for suffix in (".inc", ".cc", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".c"):
            with self.subTest(suffix=suffix):
                path = self.root / ("native/src/accidental_cutover" + suffix)
                path.write_text('#include "materials/catalogue/generated/catalogue.shadow.hpp"\n')
                self.reject("accidental_cutover.*: production/native test imports shadow output")
                path.unlink()

    def test_experimental_id_claim_cannot_be_relabelled_production(self):
        value = copy.deepcopy(self.lock)
        value["experimental_claims"]["status"] = "production"
        self.write_lock(value)
        self.reject("/experimental_claims: differs from immutable")

    def test_source_observed_backend_facts_are_exact(self):
        facts = guard.fallback_facts(self.sources)
        self.assertEqual(len(facts["identity_constants"]), 131)
        self.assertEqual(len(facts["density_by_byte_id"]), 256)
        self.assertEqual(facts["slush_density"], 1100)
        self.assertEqual(facts["density_by_byte_id"][12], 0)  # Native Acid differs.
        self.assertEqual(len(facts["hard_surface_ids"]), 101)
        self.assertNotIn(132, facts["hard_surface_ids"])
        self.assertEqual(facts["granular_support_ids"], [2, 13, 14, 19, 23, 25, 26, 27, 29])
        self.assertEqual(len(facts["base_rgba8"]), 132)


if __name__ == "__main__":
    unittest.main()
