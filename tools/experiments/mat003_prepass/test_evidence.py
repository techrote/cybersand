#!/usr/bin/env python3
"""Failure-contract tests; fabricated fixtures here are NOT experiment results."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from verify import checked_path, validate_result, verify_directory

REGISTRATION = json.loads(Path(__file__).with_name("registration.json").read_text())


def fixture():
    """Minimal shape-valid test data, never published as an observed run."""
    arms = []
    for spec in REGISTRATION["arms"]:
        rep, bits = spec["representation"], spec["logical_bits"]
        size = bits // 8 if rep == "packed" else (16 if rep in ("padded", "aligned") else 8)
        record_bytes = 5 + (bits - 64) // 8
        raw = bytes(record_bytes * 64)
        digest = 14695981039346656037
        for byte in raw:
            digest = ((digest ^ byte) * 1099511628211) & ((1 << 64) - 1)
        arms.append({"id": spec["id"], "logical_bits": bits, "epoch_bits": spec["epoch_bits"],
                     "representation": rep, "checks": 1,
                     "size_bytes": size, "stride_bytes": size, "align_bytes": 1 if rep == "packed" else 8,
                     "tail_stride_bytes": (bits - 64) // 8,
                     "base_array_bytes": size * 64, "descriptor_bytes": 72 if rep == "split" else 0,
                     "allocated_tail_bytes": 64 * (bits - 64) // 8 if rep == "split" else 0,
                     "tail_capacity_bytes": 64 * (bits - 64) // 8 if rep == "split" else 0,
                     "tail_offset_bytes": 8 if rep in ("aligned", "packed") else 0,
                     "natural_clear_count": 514 if spec["epoch_bits"] == 8 else 2,
                     "natural_first_clear": 256 if spec["epoch_bits"] == 8 else 65536,
                     "natural_last_clear": 131071,
                     "record_bytes": record_bytes, "record_count": 64,
                     "width_only_record_bytes": 5, "width_only_record_count": 64,
                     "width_only_records_hex": bytes(320).hex(),
                     "width_only_semantic_digest": "f05e74aa1eda9c25",
                     "semantic_digest": f"{digest:016x}", "semantic_records_hex": raw.hex()})
    return {"schema_version": 1, "status": "passed", "scope": "synthetic-storage-only",
            "natural_epoch_ticks": 131080, "natural_epoch16_clear_ticks": [65536, 131071],
            "checks": 1, "arms": arms, "world_qualification": False, "timing_qualification": False,
            "semantic_digest_algorithm": "fnv1a64-le"}


class ResultContracts(unittest.TestCase):
    def test_all_registered_arms_accepted(self):
        self.assertEqual(validate_result(fixture(), REGISTRATION), [])

    def test_incomplete_and_duplicate_matrix_rejected(self):
        for mutation in (lambda a: a.pop(), lambda a: a.append(copy.deepcopy(a[0]))):
            result = fixture(); mutation(result["arms"])
            self.assertTrue(validate_result(result, REGISTRATION))

    def test_unexpected_or_malformed_arm_rejected(self):
        for value in ("unregistered-arm", [], None):
            result = fixture(); result["arms"][0]["id"] = value
            self.assertTrue(validate_result(result, REGISTRATION))

    def test_natural_rollover_is_required(self):
        for field, value in (("natural_epoch_ticks", 2048), ("natural_epoch16_clear_ticks", [65536]),
                             ("natural_epoch16_clear_ticks", [65535, 131070])):
            result = fixture(); result[field] = value
            self.assertTrue(validate_result(result, REGISTRATION))

    def test_truncated_state_a_record_rejected(self):
        result = fixture(); result["arms"][0]["record_bytes"] = 4
        self.assertTrue(validate_result(result, REGISTRATION))

    def test_lossless_bytes_must_match_digest(self):
        result = fixture(); result["arms"][0]["semantic_records_hex"] = "01" + result["arms"][0]["semantic_records_hex"][2:]
        self.assertTrue(validate_result(result, REGISTRATION))

    def test_digest_disagreement_rejected(self):
        result = fixture(); result["arms"][0]["semantic_digest"] = "1234567890abcdef"
        self.assertTrue(validate_result(result, REGISTRATION))

    def test_padding_cannot_impersonate_packed_capacity(self):
        result = fixture()
        next(a for a in result["arms"] if a["id"] == "C72-E8-packed")["size_bytes"] = 16
        self.assertTrue(validate_result(result, REGISTRATION))

    def test_split_tail_accounting_required(self):
        result = fixture()
        del next(a for a in result["arms"] if a["id"] == "C80-E16-split")["tail_stride_bytes"]
        self.assertTrue(validate_result(result, REGISTRATION))

    def test_skip_or_engine_scope_cannot_pass(self):
        for field, value in (("status", "skipped"), ("checks", 0), ("checks", True), ("scope", "World-accepted")):
            result = fixture(); result[field] = value
            self.assertTrue(validate_result(result, REGISTRATION))

    def test_bad_json_shape_rejected(self):
        self.assertTrue(validate_result([], REGISTRATION))

    def test_path_escape_rejected(self):
        for name in ("../run.json", "/etc/passwd"):
            with self.assertRaises(ValueError):
                checked_path(Path("/tmp/example"), name)


class ArtifactContracts(unittest.TestCase):
    def test_missing_artifact_and_hash_tamper_are_failures(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            data = b"original fixture"
            (root / "run.json").write_text(json.dumps({
                "schema_version": 1, "status": "passed", "scope": "synthetic-storage-only",
                "files": {"evidence.txt": {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}}
            }))
            self.assertEqual(verify_directory(root)["status"], "failed")
            (root / "evidence.txt").write_bytes(b"tampered fixture")
            errors = verify_directory(root)["errors"]
            self.assertTrue(any("artifact identity mismatch" in e for e in errors))

    def test_failed_collector_cannot_be_relabelled_by_results(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "run.json").write_text(json.dumps({"schema_version": 1, "status": "failed",
                                                      "scope": "synthetic-storage-only", "files": {}}))
            self.assertIn("collector did not complete successfully", verify_directory(root)["errors"])


if __name__ == "__main__":
    unittest.main()
