#!/usr/bin/env python3
"""Adverse controls for Strata's source/evidence acceptance boundary."""
from copy import deepcopy
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
import qualify_strata_workbench as gate
import package_strata_workbench as package


def witness():
    identity = {"world_generation": 17, "physical_epoch": 8, "worker_id": "-9223371958320626182",
                "actor_session_id": "221", "actor_body_ids": ["1871", "1872"]}
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


class ArchivedGeneratorProfiles(unittest.TestCase):
    def test_actual_source_profiles_and_adverse_copies(self):
        # Use the real canonical recipes and nested style/schema assets from
        # the committed source. The established stager defines the contract;
        # this catches disagreement between staging and independent admission.
        archive = subprocess.check_output(["git", "archive", "HEAD", "--", "examples/worldgen"], cwd=package.ROOT)
        with tempfile.TemporaryDirectory(prefix="Strata archived profiles ") as temporary:
            folder = Path(temporary)
            originals = set()
            with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
                for member in tree:
                    if not member.isfile():
                        continue
                    path = folder / member.name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(tree.extractfile(member).read())
                    originals.add(member.name)
            profiles = package.stage_generator_profiles(folder)
            record = {"generator_profiles_sha256":profiles}
            names = package.payload(folder)
            package.verify_generator_profiles(folder, record, originals, names)
            self.assertIn("gen007-deepworks.json", profiles)
            self.assertIn("gen007-qualification.json", profiles)
            for retained in ("architectural/habitation-arcology.style.json", "schemas/semantic-planes-v1.schema.json"):
                self.assertIn("examples/worldgen/" + retained, names)
                self.assertNotIn(Path(retained).name, profiles)
            missing_record = deepcopy(record)
            missing_record["generator_profiles_sha256"].pop("gen007-deepworks.json")
            with self.assertRaises(RuntimeError):
                package.verify_generator_profiles(folder, missing_record, originals, names)
            copied_name = "godot/authoring/worldgen/gen007-deepworks.json"
            missing_copy = dict(names)
            missing_copy.pop(copied_name)
            with self.assertRaises(RuntimeError):
                package.verify_generator_profiles(folder, record, originals, missing_copy)
            copied = folder / copied_name
            copied.write_bytes(copied.read_bytes() + b"\n")
            with self.assertRaises(RuntimeError):
                package.verify_generator_profiles(folder, record, originals, package.payload(folder))


if __name__ == "__main__":
    unittest.main()
