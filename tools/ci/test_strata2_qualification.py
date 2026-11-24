#!/usr/bin/env python3
"""Adverse controls for Strata's source/evidence acceptance boundary."""
from copy import deepcopy
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
import qualify_strata2_workbench as gate
import package_strata2_workbench as package


def predecessor_shape():
    identity = {"world_generation": 17, "physical_epoch": 8, "worker_id": "-9223371958320626182",
                "actor_session_id": "221", "actor_body_ids": ["1871", "1872"]}
    return {"schema": "strata2-workbench-execution-v1", "completed": True,
            "failures": [], "checks": 81, "scene": "orbital-terminal", "phase": "install",
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


def successor_fields(data):
    """Explicitly synthetic verifier fixtures, never execution evidence."""
    owner = deepcopy(data["transitions"][0]["before"])
    owner.update(native_tick=0, rapier_tick=0)
    after = dict(owner, native_tick=30, rapier_tick=60)
    phases = {name: {"phase_seconds": 1.0} for name in ("scripted", "effects", "background")}
    data.update(diagnostic_headless=False, document_version=2, authored_settings_sha256="f" * 64,
                admission_target_ms=45000, admission_elapsed_ms=400, admission_target_met=True,
                cost_samples=[{"mode": mode, "atmosphere_enabled": animated,
                               "native_snapshots_during_sample": 0, "decorative_uploads_during_sample": 0}
                              for mode, animated in (("disabled", False), ("flat", False), ("stack", False), ("stack", True))],
                atmosphere={"visual_difference": {"changed_samples": 20}, "solo_leakage": {"changed_samples": 0},
                            "native_hashes_before": deepcopy(data["plane_native_hashes"]),
                            "native_hashes_after": deepcopy(data["plane_native_hashes"]), "native_capture_delta": 0,
                            "paused_before": deepcopy(phases), "paused_after": deepcopy(phases),
                            "hidden_before": deepcopy(phases), "hidden_after": deepcopy(phases),
                            "moving_before": deepcopy(phases),
                            "moving_after": {name: {"phase_seconds": 2.0} for name in phases}},
                route_probe={"completed_rapier_ticks": 60, "completed_native_ticks": 30, "forward_cells": 8.0,
                             "before": owner, "after": after, "samples": [{"rapier_tick": 60}]})
    return data


def witness():
    return successor_fields(predecessor_shape())


def native_witness(label, source="a" * 40):
    owner = deepcopy(witness()["transitions"][0]["before"])
    result = {"completed": True, "failures": [], "checks": 64, "source_revision": source}
    if label == "test_strata2_mounted_failures":
        result.update(schema="strata2-mounted-failures-v1",
                      partial={"receipt": {"status": "partial", "applied": 1}, "native_before": [0, 0],
                               "native_after": [131, 0], "quarantined": True, "authored_retained": True},
                      committed_stale_view={"returned_committed": True, "native_after": 131,
                                            "receipt": {"ok": True, "published": False}, "revision_before": 1,
                                            "revision_after": 2, "copied_pixels_retained": True},
                      failed_play_ack={"serial": 3, "instance_id": "-9223371958320626181", "pending_native_worlds": 0,
                                       "previous_document_retained": True, "before": owner, "after": deepcopy(owner)},
                      play_hash_before="c" * 64, play_hash_after="c" * 64)
    else:
        result.update(schema="strata2-workflow-v1", input_sha256="d" * 64, play_hash_original="a" * 64,
                      play_hash_imported="b" * 64, play_hash_restored="a" * 64,
                      provenance={"records": [{"scope": "synthetic verifier fixture"}]},
                      play_identity_before=owner, play_identity_after=deepcopy(owner))
    return result


class Acceptance(unittest.TestCase):
    def check(self, data):
        gate.validate_result(data, "orbital-terminal", "install", "a"*40)

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
            "legacy_document": lambda d: d.update(document_version=1),
            "hidden_diagnostic": lambda d: d.update(diagnostic_headless=True),
            "missing_settings": lambda d: d.pop("authored_settings_sha256"),
            "changed_admission_target": lambda d: d.update(admission_target_ms=90000),
            "concealed_admission_miss": lambda d: d.update(admission_elapsed_ms=87000),
            "no_animation_control": lambda d: d["cost_samples"].pop(),
            "recurring_native_capture": lambda d: d["cost_samples"][-1].update(native_snapshots_during_sample=1),
            "recurring_upload": lambda d: d["cost_samples"][-1].update(decorative_uploads_during_sample=1),
            "no_visible_atmosphere": lambda d: d["atmosphere"]["visual_difference"].update(changed_samples=0),
            "solo_effect_leak": lambda d: d["atmosphere"]["solo_leakage"].update(changed_samples=1),
            "atmosphere_mutates_native": lambda d: d["atmosphere"]["native_hashes_after"].update(play="e"*64),
            "hidden_clock_advances": lambda d: d["atmosphere"]["hidden_after"]["effects"].update(phase_seconds=2),
            "pause_clock_advances": lambda d: d["atmosphere"]["paused_after"]["effects"].update(phase_seconds=2),
            "no_native_route_ticks": lambda d: d["route_probe"].update(completed_native_ticks=0),
            "no_actual_route_progress": lambda d: d["route_probe"].update(forward_cells=0),
            "route_replaces_world": lambda d: d["route_probe"]["after"].update(world_generation=123),
            "claimed_ticks_disagree": lambda d: d["route_probe"].update(completed_rapier_ticks=61),
            "visible_animation_stopped": lambda d: d["atmosphere"].update(moving_after=deepcopy(d["atmosphere"]["moving_before"])),
        }
        for name, mutate in changes.items():
            with self.subTest(name=name):
                data = witness(); mutate(data)
                with self.assertRaises((RuntimeError, KeyError, TypeError)): self.check(data)

    def test_honest_admission_overrun_is_retained(self):
        data = witness(); data.update(admission_elapsed_ms=87000, admission_target_met=False)
        self.check(data)

    def test_native_fault_and_import_adverse_controls(self):
        for label in gate.NATIVE_REPORTS:
            gate.validate_native_report(native_witness(label), label, "a"*40)
        controls = [
            ("test_strata2_mounted_failures", lambda d: d["partial"].update(native_after=[131,131])),
            ("test_strata2_mounted_failures", lambda d: d["committed_stale_view"].update(returned_committed=False)),
            ("test_strata2_mounted_failures", lambda d: d["failed_play_ack"].update(pending_native_worlds=3)),
            ("test_strata2_workflow", lambda d: d.update(play_hash_imported=d["play_hash_original"])),
            ("test_strata2_workflow", lambda d: d["provenance"].update(records=[])),
        ]
        for label, mutate in controls:
            data = native_witness(label); mutate(data)
            with self.assertRaises((RuntimeError, KeyError, TypeError)):
                gate.validate_native_report(data, label, "a"*40)

    def test_reopen_requires_independent_process_route(self):
        data = witness(); data.update(phase="reopen", fresh_process_reopen=True)
        gate.validate_result(data, "orbital-terminal", "reopen", "a"*40)
        data["fresh_process_reopen"] = False
        with self.assertRaises(RuntimeError): gate.validate_result(data, "orbital-terminal", "reopen", "a"*40)


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
