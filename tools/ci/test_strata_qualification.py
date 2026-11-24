#!/usr/bin/env python3
"""Adverse controls for Strata's source/evidence acceptance boundary."""
from copy import deepcopy
import unittest
import qualify_strata_workbench as gate


def witness():
    identity = {"world_generation": 17, "physical_epoch": 8, "worker_id": 991,
                "actor_session_id": 221, "actor_body_ids": [1871, 1872]}
    return {"schema": "strata-workbench-execution-v1", "completed": True,
            "failures": [], "checks": 81, "scene": "industrial-assembly", "phase": "install",
            "source_revision": "a"*40, "display_server": "Windows", "rendering_method": "gl_compatibility",
            "ordinary_workbench": True, "plane_native_hashes": {s: "b"*64 for s in ("play", "scripted", "effects", "background")},
            "world_count": {"play_borrowed": 1, "decorative_owned": 3},
            "save": {"sha256": "c"*64, "path": "isolated/setup-test.json"},
            "transitions": [{"before": deepcopy(identity), "after": deepcopy(identity)} for _ in range(12)],
            "edit_readback": {"target_after": 58, "material": 58, "play_hash_before": "d"*64, "play_hash_after": "d"*64},
            "refusals": {k: True for k in ("locked", "hidden", "outside", "invalid_document", "stale_generation")},
            "undo_redo": {"undo_native": True, "redo_native": True},
            "transforms": {"samples": 48, "max_error": 0.00005},
            "cost_samples": [{"mode": m} for m in ("disabled", "flat", "stack")]}


class Acceptance(unittest.TestCase):
    def check(self, data):
        gate.validate_result(data, "industrial-assembly", "install", "a"*40)

    def test_positive_complete_shape(self):
        self.check(witness())

    def test_reject_contradictory_evidence(self):
        changes = {
            "failed": lambda d: d.update(failures=["bad native readback"]),
            "incomplete": lambda d: d.update(completed=False),
            "wrong_source": lambda d: d.update(source_revision="e"*40),
            "wrong_scene": lambda d: d.update(scene="cavern"),
            "headless": lambda d: d.update(display_server="headless"),
            "standalone": lambda d: d.update(ordinary_workbench=False),
            "missing_plane": lambda d: d["plane_native_hashes"].pop("effects"),
            "bad_native_digest": lambda d: d["plane_native_hashes"].update(play="author-json-not-native"),
            "duplicate_play": lambda d: d["world_count"].update(play_borrowed=2),
            "invalid_save": lambda d: d["save"].update(sha256="bad"),
            "no_transitions": lambda d: d.update(transitions=[]),
            "world_replaced": lambda d: d["transitions"][5]["after"].update(world_generation=18),
            "actor_replaced": lambda d: d["transitions"][5]["after"].update(actor_session_id=222),
            "bodies_replaced": lambda d: d["transitions"][5]["after"].update(actor_body_ids=[1872, 1891]),
            "no_actual_owner": lambda d: d["transitions"][0]["before"].update(worker_id=0),
            "wrong_edit_target": lambda d: d["edit_readback"].update(target_after=0),
            "play_mutated": lambda d: d["edit_readback"].update(play_hash_after="f"*64),
            "empty_edit_proof": lambda d: d.update(edit_readback={}),
            "hidden_edited": lambda d: d["refusals"].update(hidden=False),
            "locked_edited": lambda d: d["refusals"].update(locked=False),
            "stale_adopted": lambda d: d["refusals"].update(stale_generation=False),
            "invalid_adopted": lambda d: d["refusals"].update(invalid_document=False),
            "undo_unproved": lambda d: d["undo_redo"].update(undo_native=False),
            "transform_drift": lambda d: d["transforms"].update(max_error=2.0),
            "undersampled": lambda d: d["transforms"].update(samples=1),
            "no_cost": lambda d: d.update(cost_samples=[]),
        }
        for name, mutate in changes.items():
            with self.subTest(name=name):
                data = witness(); mutate(data)
                with self.assertRaises((RuntimeError, KeyError, TypeError)): self.check(data)

    def test_reopen_requires_independent_process_route(self):
        data = witness(); data.update(phase="reopen", fresh_process_reopen=True)
        gate.validate_result(data, "industrial-assembly", "reopen", "a"*40)
        data["fresh_process_reopen"] = False
        with self.assertRaises(RuntimeError): gate.validate_result(data, "industrial-assembly", "reopen", "a"*40)


if __name__ == "__main__":
    unittest.main()
