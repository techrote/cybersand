"""Adversarial identity/custody tests for the one admitted H1 source proposal."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import compatibility as guard
import h1_transition as h1


class H1TransitionGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = guard.retained_sources()
        cls.record = h1.expected_record(guard.ROOT, cls.baseline, guard.SOURCE_ROLES)
        _, cls.successor = h1._blob(guard.ROOT, h1.SOURCE_COMMIT, h1.WORLD)
        _, cls.legacy_lock = h1._blob(guard.ROOT, h1.SOURCE_PARENT, h1.LEGACY_LOCK)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mat354-h1-identity-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name, data in self.baseline.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.lock = self.root / guard.LOCK
        self.lock.parent.mkdir(parents=True, exist_ok=True)
        self.lock.write_bytes(self.legacy_lock)
        (self.root / h1.WORLD).write_bytes(self.successor)
        self.record_path = self.root / h1.RECORD
        self.write_record(self.record)

    def write_record(self, value):
        self.record_path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def check(self):
        return guard.check(self.root)

    def reject(self, expression):
        with self.assertRaisesRegex(guard.CompatibilityError, expression):
            self.check()

    def test_exact_successor_source_passes_without_adoption_or_writes(self):
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns)
                  for p in self.root.rglob("*") if p.is_file()}
        result = self.check()
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["protected_sources"], 27)
        self.assertEqual(result["source_authority"], h1.TRANSITION_ID)
        self.assertEqual(result["source_transition"], self.record)
        self.assertFalse(result["source_transition"]["runtime_adoption_authorized"])
        self.assertFalse(result["production_cutover"])
        self.assertFalse(result["runtime_execution"])
        self.assertEqual(before, {p: (p.read_bytes(), p.stat().st_mtime_ns)
                                  for p in self.root.rglob("*") if p.is_file()})

    def test_original_historical_authority_still_passes(self):
        (self.root / h1.WORLD).write_bytes(self.baseline[h1.WORLD])
        self.record_path.unlink()
        result = self.check()
        self.assertEqual(result["source_authority"], "historical-legacy")
        self.assertIsNone(result["source_transition"])
        self.assertEqual(result["baseline"], guard.BASELINE)
        self.assertEqual(result["catalogue_digest"], guard.build_lock(self.baseline)["catalogue_digest"])

    def test_successor_without_receipt_cannot_fall_back_to_legacy(self):
        self.record_path.unlink()
        self.reject("world.cpp: LF source-byte drift")

    def test_historical_world_with_successor_receipt_is_mixed_authority(self):
        (self.root / h1.WORLD).write_bytes(self.baseline[h1.WORLD])
        self.reject("world.cpp: LF source-byte drift")

    def test_changed_world_and_refreshed_record_cannot_admit_a_new_identity(self):
        path = self.root / h1.WORLD
        path.write_bytes(path.read_bytes() + b"\n// unadmitted change\n")
        value = copy.deepcopy(self.record)
        value["source"]["successor_lf_sha256"] = h1.sha(path.read_bytes())
        self.write_record(value)
        self.reject("/source: differs from immutable H1 source authority")

    def test_changed_world_with_original_receipt_fails(self):
        path = self.root / h1.WORLD
        path.write_bytes(path.read_bytes().replace(b"180U", b"179U"))
        self.reject("world.cpp: LF source-byte drift")

    def test_stale_successor_digest_fails(self):
        value = copy.deepcopy(self.record)
        value["source"]["successor_lf_sha256"] = h1.OLD_WORLD_SHA256
        self.write_record(value)
        self.reject("/source: differs from immutable H1 source authority")

    def test_wrong_source_path_is_not_an_exemption(self):
        value = copy.deepcopy(self.record)
        value["source"]["path"] = "native/src/world_quantity.inc"
        self.write_record(value)
        self.reject("/source: differs from immutable H1 source authority")

    def test_source_commit_parent_tree_and_patch_are_each_pinned(self):
        for field in ("source_commit", "source_parent", "source_tree", "source_delta_sha256"):
            with self.subTest(field=field):
                value = copy.deepcopy(self.record)
                value[field] = "f" * len(value[field])
                self.write_record(value)
                self.reject(f"/{field}: differs from immutable H1 source authority")

    def test_old_blob_and_hash_cannot_be_relabelled(self):
        for field in ("historical_git_blob", "historical_lf_sha256"):
            with self.subTest(field=field):
                value = copy.deepcopy(self.record)
                value["source"][field] = "f" * len(value["source"][field])
                self.write_record(value)
                self.reject("/source: differs from immutable H1 source authority")

    def test_unadmitted_protected_file_still_fails(self):
        path = self.root / "native/src/world_quantity.inc"
        path.write_bytes(path.read_bytes() + b"\n// unrelated quantity change\n")
        self.reject("world_quantity.inc: LF source-byte drift")

    def test_second_transition_path_cannot_be_added(self):
        value = copy.deepcopy(self.record)
        value["source_delta_paths"].append("native/src/world_quantity.inc")
        self.write_record(value)
        self.reject("/source_delta_paths: differs from immutable H1 source authority")

    def test_historical_lock_cannot_be_refreshed(self):
        value = json.loads(self.lock.read_text())
        for item in value["source_locks"]:
            if item["path"] == h1.WORLD:
                item["lf_sha256"] = h1.NEW_WORLD_SHA256
        self.lock.write_text(json.dumps(value))
        self.reject("/source_locks: differs from immutable")

    def test_historical_lock_bytes_remain_frozen_for_successor(self):
        self.lock.write_bytes(self.lock.read_bytes() + b"\n")
        self.reject("historical lock LF bytes differ")

    def test_crlf_has_the_existing_lf_identity(self):
        path = self.root / h1.WORLD
        path.write_bytes(h1.lf(path.read_bytes()).replace(b"\n", b"\r\n"))
        self.lock.write_bytes(h1.lf(self.lock.read_bytes()).replace(b"\n", b"\r\n"))
        self.assertEqual(self.check()["source_authority"], h1.TRANSITION_ID)

    def test_missing_current_source_is_not_skipped(self):
        (self.root / h1.WORLD).unlink()
        self.reject("world.cpp: required legacy consumer unavailable")

    def test_unexpected_production_import_remains_forbidden(self):
        path = self.root / "native/src/unreviewed.cpp"
        path.write_text('#include "materials/catalogue/generated/catalogue.shadow.hpp"\n')
        self.reject("production/native test imports shadow output")

    def test_missing_git_history_is_a_real_failure(self):
        missing = self.root / "missing-history"
        missing.mkdir()
        subprocess.run(["git", "init", "--quiet", str(missing)], check=True, capture_output=True)
        with self.assertRaisesRegex(h1.TransitionError, "complete retained history required"):
            h1.check_transition(self.root, missing, self.baseline, guard.SOURCE_ROLES, self.lock)
        with self.assertRaisesRegex(guard.CompatibilityError, "complete retained Git history required"):
            guard.check(self.root, baseline_repository=missing)

    def test_receipt_cannot_claim_adoption(self):
        value = copy.deepcopy(self.record)
        value["runtime_adoption_authorized"] = True
        self.write_record(value)
        self.reject("/runtime_adoption_authorized: differs from immutable H1")

    def test_unknown_key_and_boolean_schema_are_rejected(self):
        value = copy.deepcopy(self.record)
        value["allow_any_hash"] = True
        self.write_record(value)
        self.reject("expected exactly the pinned H1 record fields")
        value = copy.deepcopy(self.record)
        value["schema_version"] = True
        self.write_record(value)
        self.reject("/schema_version: differs from immutable H1")

    def test_duplicate_nonfinite_and_corrupt_json_are_rejected(self):
        original = self.record_path.read_text()
        for changed, error in (
                (original.replace('"schema_version": 1,', '"schema_version": 1, "schema_version": 1,'), "duplicate JSON key"),
                (original.replace('"schema_version": 1,', '"schema_version": NaN,'), "non-finite JSON value"),
                ("{", "Expecting property name")):
            with self.subTest(error=error):
                self.record_path.write_text(changed)
                self.reject(error)

    def test_scope_check_rejects_unrelated_kernel_or_epoch_edits(self):
        before = self.baseline[h1.WORLD]
        for changed in (b"// header mutation\n" + self.successor,
                        self.successor + b"\n// tail mutation\n",
                        self.successor.replace(b"if (transient_obstacle_at(x, y) != 0U) return false;",
                                               b"if (false) return false;")):
            with self.subTest(size=len(changed)):
                with self.assertRaisesRegex(h1.TransitionError, "bytes outside schedule_pending_reaction_wake changed"):
                    h1.scoped_delta(before, changed)

    def test_scope_check_rejects_missing_duplicate_and_unchanged_helpers(self):
        before = self.baseline[h1.WORLD]
        for changed, error in ((self.successor.replace(h1.HELPER_START, b"\nvoid absent("), "boundaries"),
                               (self.successor + h1.HELPER_END, "boundaries"),
                               (before, "missing cooling-deadline delta")):
            with self.subTest(error=error):
                with self.assertRaisesRegex(h1.TransitionError, error):
                    h1.scoped_delta(before, changed)


if __name__ == "__main__":
    unittest.main()
