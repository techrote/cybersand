"""Synthetic conformance tests; never classified as native or inference evidence."""
from __future__ import annotations

import copy
import unittest

from jsonschema.exceptions import ValidationError

from verify import ContractError, records_from_examples, validate_bundle


class ContractV1Tests(unittest.TestCase):
    def setUp(self):
        self.rows = copy.deepcopy(records_from_examples())

    def reject(self, change):
        change(self.rows)
        with self.assertRaises((ContractError, ValidationError)):
            validate_bundle(self.rows)

    def test_five_synthetic_types_are_shape_valid(self):
        result = validate_bundle(self.rows)
        self.assertEqual(result["validated"], 5)
        self.assertEqual(result["types"], ["action", "guidance", "observation", "provenance", "reversal"])
        self.assertFalse(result["evidence_bytes_verified"])

    def test_unknown_field_rejected(self):
        self.reject(lambda rows: rows[1].__setitem__("guess_permission", True))

    def test_protocol_version_is_fenced(self):
        self.reject(lambda rows: rows[2].__setitem__("protocol", "cybersand.driv3r.d-common/2"))

    def test_guidance_never_grants_native_permissions(self):
        self.reject(lambda rows: rows[0].__setitem__("native_material_authority", True))

    def test_guidance_u16_extent_required(self):
        self.reject(lambda rows: rows[0]["values"].__setitem__("bytes", 127))

    def test_hysteresis_requires_reentry_above_exit(self):
        self.reject(lambda rows: rows[0]["hysteresis"].__setitem__("reenter_at_or_above", 12000))

    def test_stale_action_world_rejected(self):
        self.reject(lambda rows: rows[2]["world_precondition"].__setitem__("revision", 8))

    def test_action_cannot_claim_native_receipt_while_candidate(self):
        self.reject(lambda rows: rows[2].__setitem__("native_receipt_ref", "receipt-does-not-exist"))

    def test_guidance_ref_must_exist(self):
        self.reject(lambda rows: rows[1].__setitem__("guidance_ref", "guide-unknown"))

    def test_cursor_only_backtrack_cannot_erase(self):
        self.reject(lambda rows: rows[3].__setitem__("actual_material_cells_changed", 1))

    def test_cursor_only_reversal_preserves_hash(self):
        self.reject(lambda rows: rows[3]["after_world"].__setitem__("world_material_sha256", "9" * 64))

    def test_reversal_does_not_fake_material_undo(self):
        self.reject(lambda rows: rows[3].__setitem__("preserve_material_edits", False))

    def test_applied_true_undo_requires_receipt(self):
        def alter(rows):
            rows[3]["mechanism"] = "UNDO_MATERIAL_EDIT"
            rows[3]["preserve_material_edits"] = False
        self.reject(alter)

    def test_nonmonotonic_sequences_rejected(self):
        self.reject(lambda rows: rows[2].__setitem__("sequence", 0))

    def test_no_paint_action_must_lift_brush(self):
        self.reject(lambda rows: rows[2].__setitem__("brush_state", "erase"))

    def test_native_crop_material_extent_checked(self):
        self.reject(lambda rows: rows[1]["local_material"].__setitem__("bytes", 100))


if __name__ == "__main__":
    unittest.main()
