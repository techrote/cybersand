#!/usr/bin/env python3
"""Reject truthful-looking but stale, relabelled or self-certified GPU receipts."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest

import qualification_oracles as oracle


SOURCE = "a" * 40
ENGINE = "b" * 64
DRIVER = "opengl3"


class QualificationOracles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.project = Path(cls.temporary.name)
        for relative in ("scripts/full_image_ring_publisher.gd", "scripts/main.gd",
                         "tests/support/ci_execution_policy.json", "shaders/material_palette.gdshader",
                         oracle.RING_FIXTURE[6:], oracle.TRANSITION_FIXTURE[6:], oracle.MAIN_FIXTURE[6:]):
            path = cls.project / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("independent-oracle-test:" + relative + "\n", encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def context(self, fixture):
        shader = (self.project / "shaders/material_palette.gdshader").read_bytes()
        return {"schema": "palette-qualification-context-v1", "source_revision": SOURCE,
                "fixture": fixture, "fixture_sha256": oracle.file_digest(self.project / fixture[6:]),
                "engine_sha256": ENGINE, "backend": DRIVER, "display_server": "X11", "platform": "Linux",
                "godot": {"major": 4, "minor": 7}, "process_id": 731,
                "execution_policy": {"ok": True, "schema_version": 1,
                                     "path": "res://tests/support/ci_execution_policy.json",
                                     "sha256": oracle.file_digest(self.project / "tests/support/ci_execution_policy.json")},
                "shader": {"source_path": "res://shaders/material_palette.gdshader",
                           "source_sha256": oracle.digest(shader), "source_file_sha256": oracle.digest(shader),
                           "source_file_bound": True, "source_bound": True, "variant": "full_crossfade",
                           "variant_sha256": oracle.digest(shader)}}

    def common(self, fixture, schema, checks):
        return {"schema": schema, "complete": True, "failures": [], "checks": checks,
                "source": SOURCE, "pid": 731, "driver": DRIVER, "render_thread_inline": True,
                "publisher_sha256": oracle.file_digest(self.project / "scripts/full_image_ring_publisher.gd"),
                "context": self.context(fixture)}

    @staticmethod
    def verified(current, previous):
        return {"current_verified": True, "previous_verified": True,
                "current_sha256": current, "previous_sha256": previous,
                "expected_current_sha256": current, "expected_previous_sha256": previous}

    def ring(self):
        data = self.common(oracle.RING_FIXTURE, "pubpres-full-image-ring-correctness-v1", 475)
        data["engine"] = data["context"]["godot"]
        data["observations"] = []
        for channels in (1, 2):
            for width, height in ((33, 19), (512, 512), (2048, 1024)):
                data["observations"].append({"extent": [width, height], "channels": channels,
                                             "logical_gpu_bytes": 3 * width * height * channels,
                                             "resource_count": 3, "queued_publications": 17,
                                             "separate": False, "render_gate_completed": False,
                                             "histories": self.verified(
                                                 oracle.digest(oracle.queued_plane(width, height, channels, 56)),
                                                 oracle.digest(oracle.queued_plane(width, height, channels, 55)))})
        return data

    def validate_ring(self, data):
        return oracle.ring_result("FULL_IMAGE_RING_RESULT " + json.dumps(data), SOURCE, self.project,
                                  DRIVER, engine_sha256=ENGINE)

    def main_recovery(self):
        data = self.common(oracle.MAIN_FIXTURE, "pubpres-full-image-ring-main-recovery-v1", 32)
        data["main_sha256"] = oracle.file_digest(self.project / "scripts/main.gd")
        data["acks"] = list(range(1, 7))
        data["observations"] = []
        # Build a chronological CPU input ledger, independent of any GPU flags.
        previous = bytes(33 * 19 * 2)
        labels = ["admission1", "admission2", "admission3", "admission4", "refusal-recovery", "post-recovery"]
        for serial, label in enumerate(labels, 1):
            current = bytes((3 + serial, 137 - serial)) * (33 * 19)
            data["observations"].append(dict(label=label, **self.verified(oracle.digest(current), oracle.digest(previous))))
            previous = current
        recreated = copy.deepcopy(data["observations"][-1])
        recreated["label"] = "mode-recreation"
        data["observations"].append(recreated)
        return data

    def validate_main(self, data):
        return oracle.main_recovery_result("FULL_IMAGE_RING_MAIN_RESULT " + json.dumps(data), SOURCE,
                                           self.project, DRIVER, engine_sha256=ENGINE)

    def transition(self):
        data = self.common(oracle.TRANSITION_FIXTURE, "pubpres-full-image-ring-transition-history-v1", 0)
        expected = oracle.transition_expectations()
        data.update(application_main_sha256=oracle.file_digest(self.project / "scripts/main.gd"),
                    frames_checked=180, current_matches=180, previous_matches=180, resource_count=3,
                    full_image_slots=3, case="transition_2048_w1", tape="transition", sparse_entries=15,
                    initial_plane_sha256=expected["initial"], entry_history=copy.deepcopy(expected["entries"]),
                    admissions=[])
        for field, key in (("warmup_history", "warmup"), ("history", "terminal")):
            current, previous = expected[key]
            data[field] = {"current_matches": True, "previous_matches": True,
                           "current_sha256": current, "previous_sha256": previous}
        current, previous, spare = 0, 1, 2
        for sequence in range(210):
            current, previous, spare = spare, current, previous
            if sequence < 30:
                continue
            status = {"requested_mode": "full", "mode": "full", "backend": "full", "fallback_reason": "",
                      "driver": DRIVER, "full_image_slots_requested": "3", "full_image_slots": 3,
                      "full_image_slot_count": 3, "logical_source_format": "RG8", "gpu_storage_format": "RG8",
                      "allocated_logical_gpu_bytes": 3 * 2048 * 2048 * 2, "submitted_bytes": 2048 * 2048 * 2,
                      "texture_ids": [100, 101, 102], "texture_rids": [200, 201, 202], "current_slot": current,
                      "previous_slot": previous, "spare_slot": spare, "upload_slot": current}
            data["admissions"].append({"sequence": sequence, "revision": sequence + 1,
                                        "current_matches": True, "previous_matches": True, "material": status})
        return data

    def validate_transition(self, data):
        path = self.project / "test-transition.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return oracle.transition_result(path, self.project, source=SOURCE, driver=DRIVER, engine_sha256=ENGINE)

    def assert_faults(self, original, validator, faults):
        validator(original)
        for name, corrupt in faults:
            with self.subTest(name=name):
                changed = copy.deepcopy(original)
                corrupt(changed)
                with self.assertRaises((ValueError, KeyError, TypeError)):
                    validator(changed)

    def test_queued_history_requires_independent_bytes_and_live_identity(self):
        self.assert_faults(self.ring(), self.validate_ring, [
            ("self_certified_wrong_current", lambda d: d["observations"][0]["histories"].update(current_sha256="0" * 64, expected_current_sha256="0" * 64)),
            ("lost_previous", lambda d: d["observations"][0]["histories"].update(previous_sha256=d["observations"][0]["histories"]["current_sha256"])),
            ("false_read", lambda d: d["observations"][1]["histories"].update(previous_verified=False)),
            ("missing_case", lambda d: d["observations"].pop()),
            ("duplicate_case", lambda d: d["observations"].__setitem__(0, d["observations"][1])),
            ("short_queue", lambda d: d["observations"][0].update(queued_publications=2)),
            ("hidden_extra_resource", lambda d: d["observations"][0].update(resource_count=4)),
            ("different_allocation", lambda d: d["observations"][0].update(logical_gpu_bytes=1)),
            ("false_queue_owner", lambda d: d["observations"][0].update(separate=True)),
            ("wrong_source", lambda d: d["context"].update(source_revision="c" * 40)),
            ("wrong_fixture", lambda d: d["context"].update(fixture_sha256="c" * 64)),
            ("wrong_engine", lambda d: d["context"].update(engine_sha256="c" * 64)),
            ("headless", lambda d: d["context"].update(display_server="headless")),
            ("requested_is_not_runtime_thread", lambda d: d.update(render_thread_inline=False)),
            ("wrong_publisher", lambda d: d.update(publisher_sha256="c" * 64)),
            ("missing_check", lambda d: d.update(checks=474)),
        ])

    def test_transition_requires_ordered_exact_histories_and_every_slot_admission(self):
        self.assert_faults(self.transition(), self.validate_transition, [
            ("initial_substrate", lambda d: d.update(initial_plane_sha256="0" * 64)),
            ("warmup_previous", lambda d: d["warmup_history"].update(previous_sha256="0" * 64)),
            ("final_stale_previous", lambda d: d["history"].update(previous_sha256=d["history"]["current_sha256"])),
            ("entry_wrong_bytes", lambda d: d["entry_history"][0].update(current_sha256="0" * 64)),
            ("entry_reorder", lambda d: d["entry_history"].reverse()),
            ("entry_omission", lambda d: d["entry_history"].pop()),
            ("admission_omission", lambda d: d["admissions"].pop()),
            ("reused_revision", lambda d: d["admissions"][1].update(revision=31)),
            ("previous_false", lambda d: d["admissions"][50].update(previous_matches=False)),
            ("wrong_slot_rotation", lambda d: d["admissions"][50]["material"].update(current_slot=1, previous_slot=2, spare_slot=0, upload_slot=1)),
            ("aliased_resources", lambda d: d["admissions"][3]["material"].update(texture_rids=[200, 200, 202])),
            ("recreated_resources", lambda d: d["admissions"][-1]["material"].update(texture_ids=[100, 101, 999])),
            ("fallback_hidden", lambda d: d["admissions"][3]["material"].update(fallback_reason="refused")),
            ("shader_not_source_bound", lambda d: d["context"]["shader"].update(source_file_bound=False)),
            ("shader_variant", lambda d: d["context"]["shader"].update(variant_sha256="0" * 64)),
            ("wrong_backend", lambda d: d["context"].update(backend="opengl3_angle")),
        ])

    def test_main_recovery_requires_prior_world_and_fallback_history_and_exact_acks(self):
        self.assert_faults(self.main_recovery(), self.validate_main, [
            ("extra_ack", lambda d: d["acks"].append(6)),
            ("lost_ack", lambda d: d["acks"].pop()),
            ("out_of_order_ack", lambda d: d["acks"].reverse()),
            ("world_replacement_history", lambda d: d["observations"][2].update(previous_sha256="0" * 64, expected_previous_sha256="0" * 64)),
            ("fallback_stale_current", lambda d: d["observations"][4].update(current_sha256=d["observations"][3]["current_sha256"])),
            ("recreation_lost_previous", lambda d: d["observations"][6].update(previous_verified=False)),
            ("missing_recovery", lambda d: d["observations"].pop(4)),
            ("wrong_main_source", lambda d: d.update(main_sha256="0" * 64)),
            ("wrong_policy_source", lambda d: d["context"]["execution_policy"].update(sha256="0" * 64)),
        ])

    def test_duplicate_terminal_cannot_select_a_later_good_receipt(self):
        text = "FULL_IMAGE_RING_RESULT " + json.dumps(self.ring())
        with self.assertRaises(ValueError):
            oracle.ring_result(text + "\n" + text, SOURCE, self.project, DRIVER, engine_sha256=ENGINE)

    def test_negative_refcounted_ids_do_not_weaken_identity_or_rid_checks(self):
        data = self.transition()
        negative = [-9223371955351058792, -9223371955317504358, -9223371955283949924]
        for row in data["admissions"]:
            row["material"]["texture_ids"] = negative.copy()
        self.validate_transition(data)
        for value in (0, -(1 << 63) - 1, 1 << 63, True, -1.5):
            with self.subTest(invalid_object_id=value):
                broken = copy.deepcopy(data)
                broken["admissions"][20]["material"]["texture_ids"][0] = value
                with self.assertRaises(ValueError):
                    self.validate_transition(broken)
        self.assert_faults(data, self.validate_transition, [
            ("negative_id_alias", lambda d: d["admissions"][20]["material"].update(texture_ids=[negative[0], negative[0], negative[2]])),
            ("negative_id_replacement", lambda d: d["admissions"][20]["material"].update(texture_ids=[negative[0], negative[1], -97])),
            ("negative_rid", lambda d: d["admissions"][20]["material"].update(texture_rids=[-1, 201, 202])),
            ("rid_overflow", lambda d: d["admissions"][20]["material"].update(texture_rids=[1 << 63, 201, 202])),
            ("rid_bool", lambda d: d["admissions"][20]["material"].update(texture_rids=[True, 201, 202])),
            ("rid_float", lambda d: d["admissions"][20]["material"].update(texture_rids=[1.5, 201, 202])),
        ])

    def test_reconstruction_retains_sparse_substrate_and_two_channels(self):
        sparse = oracle.transition_plane(38)
        self.assertEqual(sparse[:2], bytes((58, (37 * 37) % 256)))
        offset = (96 * 2048 + 96) * 2
        self.assertEqual(sparse[offset:offset + 2], bytes((3, (38 * 37) % 256)))
        self.assertEqual(sparse[offset - 2:offset], sparse[:2])
        self.assertEqual(oracle.queued_plane(3, 2, 1, 56), bytes((57, 56, 56, 56, 56, 127)))
        self.assertEqual(oracle.queued_plane(3, 2, 2, 56), bytes((57, 17, 56, 141, 56, 141, 56, 141, 56, 141, 127, 58)))


if __name__ == "__main__":
    unittest.main()
