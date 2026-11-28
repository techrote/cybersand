"""All predecessor adversarial payload gates, plus atomic admission mutations.

The inherited tests execute against the new exact source closure and synthetic
PE receipts. No synthetic receipt is a built or graphically qualified engine.
"""
import copy
import importlib.util
import json
import unittest

import engine_contract as contract
import payload

spec = importlib.util.spec_from_file_location("atomic_frozen_payload_tests",
    contract.ROOT / contract.BOUNDED_DIRECTORY / "test_payload.py")
_previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(_previous)


class PayloadTests(_previous.PayloadTests):
    def setUp(self):
        super().setUp()
        path = self.folder / "engine-source.patch"
        path.write_bytes((contract.ROOT / contract.DIRECTORY / "godot-final-source.patch").read_bytes())
        self.proof["combined_patch"] = payload.file_record(path)
        self.refresh()

    def test_actual_windows_patch_has_exact_same_ordered_edits(self):
        # The old actual Windows font patch is still a frozen input. Its
        # normalized records remain a subset of the new final combined diff.
        old = {row["path"]: row for row in json.loads(payload.normalized_patch(self.windows_patch()))}
        current = {row["path"]: row for row in json.loads(payload.normalized_patch(
            (self.folder / "engine-source.patch").read_bytes()))}
        self.assertTrue(old)
        self.assertTrue(all(current[name] == value for name, value in old.items()))
        self.assertTrue(contract.verify_patch_stack()["complete"])
        self.assertTrue(self.verify()["complete"])

    def test_rehashed_windows_changed_line_coordinate_and_extra_edit_are_refused(self):
        path = self.folder / "engine-source.patch"
        original = path.read_bytes()
        for before, after in ((b"img = tex.image->duplicate();", b"img = tex.image;"),
                              (b"+\tcurrent_window = nullptr;", b"+ current_window = nullptr;"),
                              (b"@@ -350,6 +350,9", b"@@ -351,6 +351,9"),
                              (b"text_server_fb/text_server_fb.cpp", b"text_server_fb/other.cpp")):
            changed = original.replace(before, after, 1)
            self.assertNotEqual(changed, original)
            path.write_bytes(changed); self.proof["combined_patch"] = payload.file_record(path); self.refresh()
            with self.subTest(before=before), self.assertRaises(ValueError): self.verify()

    def test_rehashed_budget_and_manual_barrier_changes_are_refused(self):
        path = self.folder / "engine-source.patch"
        original = path.read_bytes()
        for before, after in ((b"MAX_DEFERRED_TURNS = 4", b"MAX_DEFERRED_TURNS = 8"),
                              (b"pubpres_frame_budget.complete_draw(p_serial);", b"pubpres_frame_budget.complete_draw(p_serial + 1);"),
                              (b"pubpres_frame_budget.consume_render_step(frame_step)", b"frame_step"),
                              (b"pubpres_budget_track && create_thread", b"false && create_thread")):
            changed = original.replace(before, after, 1)
            self.assertNotEqual(changed, original)
            path.write_bytes(changed); self.proof["combined_patch"] = payload.file_record(path); self.refresh()
            with self.subTest(before=before), self.assertRaises(ValueError): self.verify()

    def test_rehashed_atomic_acceptance_and_rejected_time_changes_are_refused(self):
        path = self.folder / "engine-source.patch"
        original = path.read_bytes()
        for before, after in ((b"_pubpres_application_admission(application)", b"true"),
                              (b"pubpres_admission_clock.reject(frame_step)", b"pubpres_admission_clock.reject(0.0)"),
                              (b"String(source) == expected_source", b"true"),
                              (b"int64_t(owner_id) == expected_owner", b"true")):
            changed = original.replace(before, after, 1)
            self.assertNotEqual(changed, original)
            path.write_bytes(changed); self.proof["combined_patch"] = payload.file_record(path); self.refresh()
            with self.subTest(before=before), self.assertRaises(ValueError): self.verify()


if __name__ == "__main__": unittest.main()
