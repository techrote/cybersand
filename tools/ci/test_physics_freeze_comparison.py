"""Adversarial gates for source-matched Workbench physics comparisons.

These tests use small synthetic records to exercise qualification boundaries;
they make no claim about application throughput or physical GPU acceptance.
"""
from copy import deepcopy
import hashlib
import io
import json
import os
from pathlib import Path, PureWindowsPath
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import run_physics_freeze_comparison as subject


def digest(body):
    return hashlib.sha256(body).hexdigest()


def completion(step, slots=(0, 1)):
    return {
        "type": "event", "event": "rapier_step", "step": step,
        "time_usec": step * 100_000, "start_usec": step * 100_000 - 2_000,
        "native_tick_used": step - 1, "epoch": 1, "session": 2,
        "world_generation": 3, "hard_surface_shapes": 17,
        "pending_hard_chunks": 0, "input_tape_index": step // 30,
        "fixed_delta": 1 / 60, "simulation_time_sec": step / 60,
        "native_response": {
            "accepted": True, "refusal": "",
            "bodies": [{"id": slot + 1, "sample": step, "age": 0,
                        "refusal": ""} for slot in slots],
        },
        "bodies": [{"slot": slot, "instance_id": slot + 1,
                    "xy": [step / 16, 200 + slot], "angle": step / 1024,
                    "velocity": [1.25, -0.5]} for slot in slots],
    }


def completions(count=3, first=1):
    return [completion(step) for step in range(first, first + count)]


def compare(left, right, required_steps=3):
    return subject.exact_common_states(subject.physical_states(left),
                                       subject.physical_states(right),
                                       required_steps=required_steps)


class PhysicalEquivalenceTests(unittest.TestCase):
    def test_identical_states_match_by_completed_step_and_slot(self):
        result = compare(completions(), list(reversed(completions())))
        self.assertTrue(result["exact"])
        self.assertEqual(result["common_step_bodies"], 6)
        self.assertEqual(result["step_range"], [1, 3])
        self.assertEqual(result["differences"], [])

    def test_elapsed_time_and_callback_observations_are_not_physical_state(self):
        control, candidate = completions(), completions()
        for event in candidate:
            event.update(time_usec=event["time_usec"] * 2,
                         start_usec=event["start_usec"] * 2,
                         observed_usec=987654, solver_usec=876,
                         physics_publication_usec=765, process_frame=654)
        self.assertTrue(compare(control, candidate)["exact"])

    def test_extra_capture_end_completion_does_not_shorten_required_prefix(self):
        result = compare(completions(3), completions(4))
        self.assertTrue(result["exact"])
        self.assertEqual(result["step_range"], [1, 3])
        self.assertEqual(result["control_step_bodies"], 6)
        self.assertEqual(result["candidate_step_bodies"], 8)

    def test_default_qualification_requires_all_144_tape_steps(self):
        full = subject.physical_states(completions(144))
        for length in (1, 2, 60, 120, 143):
            with self.subTest(recorded_steps=length), self.assertRaises(RuntimeError):
                subject.exact_common_states(full,
                                            subject.physical_states(completions(length)))
        self.assertTrue(subject.exact_common_states(
            full, subject.physical_states(completions(145)))["exact"])

    def test_matching_but_late_start_cannot_hide_initial_completions(self):
        with self.assertRaises(RuntimeError):
            compare(completions(3, first=2), completions(3, first=2))

    def test_different_starting_steps_are_rejected(self):
        with self.assertRaises(RuntimeError):
            compare(completions(), completions(3, first=2))

    def test_missing_intermediate_step_is_rejected_in_either_arm(self):
        full = completions(4)
        missing = [full[0], *full[2:]]
        for left, right in ((full, missing), (missing, full)):
            with self.subTest(missing_control=left is missing), self.assertRaises(RuntimeError):
                compare(left, right)

    def test_empty_capture_is_rejected(self):
        with self.assertRaises(RuntimeError):
            compare([], completions())

    def test_duplicate_completion_is_rejected(self):
        events = completions()
        with self.assertRaisesRegex(RuntimeError, "Duplicate"):
            subject.physical_states([*events, deepcopy(events[1])])

    def test_duplicate_actor_slot_within_one_completion_is_rejected(self):
        event = completion(1)
        event["bodies"].append(deepcopy(event["bodies"][0]))
        with self.assertRaisesRegex(RuntimeError, "Duplicate"):
            subject.physical_states([event])

    def test_missing_or_replaced_actor_slot_cannot_hide_in_key_intersection(self):
        for slots in ((0,), (0, 2), (0, 1, 2)):
            candidate = completions()
            candidate[1] = completion(2, slots=slots)
            with self.subTest(slots=slots), self.assertRaises(RuntimeError):
                compare(completions(), candidate)

    def test_actor_identity_and_each_recorded_physical_value_are_compared(self):
        for key, value in (("instance_id", 99), ("xy", [12, 34]),
                           ("velocity", [3, -4]), ("angle", 0.125)):
            candidate = completions()
            candidate[1]["bodies"][0][key] = value
            with self.subTest(field=key):
                result = compare(completions(), candidate)
                self.assertFalse(result["exact"])
                self.assertEqual([(r["step"], r["slot"]) for r in result["differences"]], [(2, 0)])

    def test_required_native_and_terrain_associations_are_compared(self):
        changes = {
            "native_tick_used": 98, "epoch": 98, "session": 98,
            "world_generation": 98, "hard_surface_shapes": 98,
            "pending_hard_chunks": 1, "input_tape_index": 98,
            "fixed_delta": 1 / 120, "simulation_time_sec": 99,
            "native_response": {"accepted": False, "refusal": "age", "bodies": []},
            "native_sample_serial": 98, "sample_serial": 98,
        }
        for key, value in changes.items():
            candidate = completions()
            candidate[1][key] = value
            with self.subTest(field=key):
                self.assertFalse(compare(completions(), candidate)["exact"])

    def test_nested_feedback_age_and_sample_association_are_compared(self):
        for key, value in (("age", 2), ("sample", 99), ("id", 99), ("refusal", "epoch")):
            candidate = completions()
            candidate[1]["native_response"]["bodies"][0][key] = value
            with self.subTest(field=key):
                self.assertFalse(compare(completions(), candidate)["exact"])

    def test_equally_incomplete_associations_cannot_certify_equivalence(self):
        required = ("native_tick_used", "epoch", "session", "world_generation",
                    "native_response", "hard_surface_shapes", "pending_hard_chunks",
                    "input_tape_index", "fixed_delta", "simulation_time_sec")
        for key in required:
            events = completions()
            for event in events:
                del event[key]
            with self.subTest(field=key), self.assertRaises(RuntimeError):
                compare(events, deepcopy(events))

    def test_equally_incomplete_bodies_cannot_certify_equivalence(self):
        for key in ("slot", "instance_id", "xy", "angle", "velocity"):
            events = completions()
            for event in events:
                for body in event["bodies"]:
                    del body[key]
            with self.subTest(field=key), self.assertRaises(RuntimeError):
                compare(events, deepcopy(events))


class TraceReductionTests(unittest.TestCase):
    def write_trace(self, path, physical, native_ticks=None):
        if native_ticks is None:
            native_ticks = list(range(len(physical)))
        events = [{"type": "event", "event": "native_tick", "tick_index": tick,
                   "start_usec": (index + 1) * 100_000 - 20_000,
                   "completed_usec": (index + 1) * 100_000 - 10_000}
                  for index, tick in enumerate(native_ticks)]
        records = [{"type": "header", "schema": "cybersand-pose-trace-v1",
                    "settings": {"source_commit": "test-source"}},
                   *events, *physical,
                   {"type": "summary", "frames": 0, "dropped": 0,
                    "events_dropped": 0, "worker_events_dropped": 0}]
        path.write_text("\n".join(map(json.dumps, records)) + "\n", encoding="utf-8")

    def test_rate_uses_recorded_completion_time_not_configured_fps(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "trace.jsonl"
            self.write_trace(path, completions())
            report, states = subject.reduction(path)
        self.assertEqual(report["rates_hz"]["rapier"], 10)
        self.assertEqual(report["rates_hz"]["native"], 10)
        self.assertEqual(report["physics"]["active_gaps_at_least_100ms"], 2)
        self.assertEqual(len(states), 6)

    def test_missing_or_duplicate_rapier_events_fail_before_reduction(self):
        cases = ([completion(1), completion(3)],
                 [completion(1), completion(2), completion(2), completion(3)])
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "trace.jsonl"
            for events in cases:
                self.write_trace(path, events)
                with self.subTest(steps=[e["step"] for e in events]), self.assertRaises(RuntimeError):
                    subject.reduction(path)

    def test_missing_or_duplicate_native_events_fail_before_reduction(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "trace.jsonl"
            for ticks in ([0, 2], [0, 1, 1, 2]):
                self.write_trace(path, completions(), ticks)
                with self.subTest(ticks=ticks), self.assertRaises(RuntimeError):
                    subject.reduction(path)

    def test_empty_body_duplicate_cannot_bypass_completion_validation(self):
        events = completions()
        duplicate = deepcopy(events[1])
        duplicate["bodies"] = []
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "trace.jsonl"
            self.write_trace(path, [*events, duplicate])
            with self.assertRaises(RuntimeError):
                subject.reduction(path)


class ProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.project = self.base / "project"
        self.project.mkdir()
        self.source = "a" * 40
        platform = "windows" if os.name == "nt" else "linux"
        native_manifest = "runtime-provenance.json" if os.name == "nt" else "runtime-provenance.linux.json"
        self.manifest_paths = ["addons/cybersand_native/" + native_manifest,
                               "addons/godot-rapier2d/runtime-provenance." + platform + ".json"]
        self.canonical = {
            "godot/project.godot": b"[application]\nconfig/name=\"fixture\"\n",
            "godot/scripts/main.gd": b"extends Node\n",
            "godot/shaders/material.gdshader": b"shader_type canvas_item;\n",
            "godot/addons/native.gdextension": b"[configuration]\ncompatibility_minimum=\"4.7\"\n",
            "godot/settings.cfg": b"[runtime]\nenabled=true\n",
            "native/src/world.cpp": b"int fixture_world = 1;\n",
            "third_party/patches/rapier.patch": b"fixture-patch\n",
            "examples/worldgen/fixture.json": b'{"seed":17}\n',
        }
        self.payloads = {}
        self.manifests = []
        for index, relative in enumerate(self.manifest_paths):
            artifact = (Path(relative).parent / "bin" / ("fixture" + str(index) + ".bin")).as_posix()
            payload = ("binary-" + str(index)).encode()
            source_input = ("native/src/world.cpp", "third_party/patches/rapier.patch")[index]
            manifest = {"artifact": "godot/" + artifact, "sha256": digest(payload),
                        "source_inputs": {source_input: digest(self.canonical[source_input])}}
            self.manifests.append(manifest)
            self.canonical["godot/" + relative] = (json.dumps(manifest) + "\n").encode()
            self.canonical["godot/" + artifact] = b"Git LFS pointer placeholder\n"
            self.payloads[artifact] = payload
        for name, body in self.canonical.items():
            if name.startswith("godot/"):
                self.save(name.removeprefix("godot/"), body)
        for relative, payload in self.payloads.items():
            self.save(relative, payload)
        git_patch = patch.object(subject, "git", side_effect=self.fake_git)
        self.addCleanup(git_patch.stop)
        git_patch.start()

    def save(self, relative, body):
        path = self.project / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)

    def fake_git(self, *args):
        if args[0] == "ls-tree":
            return ("\n".join(sorted(name for name in self.canonical if name.startswith("godot/"))) + "\n").encode()
        if args[0] == "show":
            source, name = args[1].split(":", 1)
            self.assertEqual(source, self.source)
            return self.canonical[name]
        if args[0] == "archive":
            self.assertEqual(args[1], self.source)
            stream = io.BytesIO()
            with tarfile.open(fileobj=stream, mode="w") as archive:
                for name, body in self.canonical.items():
                    if name.startswith("godot/"):
                        member = tarfile.TarInfo(name)
                        member.size = len(body)
                        archive.addfile(member, io.BytesIO(body))
            return stream.getvalue()
        self.fail("Unexpected Git operation: " + repr(args))

    def test_exact_source_accepts_crlf_and_ignores_generated_import_cache(self):
        self.save("scripts/main.gd", b"extends Node\r\n")
        self.save(".godot/imported/cache.gd", b"generated cache\n")
        ledger = subject.verify_candidate_project(self.source, self.project)
        self.assertEqual(ledger["scripts/main.gd"], digest(b"extends Node\n"))
        self.assertIn("addons/native.gdextension", ledger)
        self.assertIn("settings.cfg", ledger)
        self.assertNotIn(".godot/imported/cache.gd", ledger)

    def test_missing_tracked_source_is_rejected(self):
        (self.project / "scripts/main.gd").unlink()
        with self.assertRaises(RuntimeError):
            subject.verify_candidate_project(self.source, self.project)

    def test_git_relative_names_use_portable_separators_on_windows(self):
        # Git emits '/' even on Windows; compare those keys to the project's
        # POSIX-normalized inventory instead of host-dependent str(Path(...)).
        with patch.object(subject, "Path", PureWindowsPath):
            ledger = subject.verify_candidate_project(self.source, self.project)
        self.assertIn("scripts/main.gd", ledger)
        self.assertIn("addons/native.gdextension", ledger)

    def test_tracked_script_shader_extension_and_config_drift_are_rejected(self):
        for relative in ("scripts/main.gd", "shaders/material.gdshader",
                         "addons/native.gdextension", "settings.cfg"):
            original = (self.project / relative).read_bytes()
            self.save(relative, b"substituted runtime input\n")
            with self.subTest(path=relative), self.assertRaises(RuntimeError):
                subject.verify_candidate_project(self.source, self.project)
            self.save(relative, original)

    def test_untracked_executable_or_config_is_rejected(self):
        for relative in ("rogue.gd", "rogue.gdextension", "rogue.cfg"):
            self.save(relative, b"untracked input\n")
            with self.subTest(path=relative), self.assertRaises(RuntimeError):
                subject.verify_candidate_project(self.source, self.project)
            (self.project / relative).unlink()

    def test_packaged_generator_copy_requires_exact_canonical_source(self):
        self.save("authoring/worldgen/fixture.json", b'{"seed":17}\r\n')
        subject.verify_candidate_project(self.source, self.project)
        self.save("authoring/worldgen/fixture.json", b'{"seed":18}\n')
        with self.assertRaises(RuntimeError):
            subject.verify_candidate_project(self.source, self.project)

    def test_arbitrary_json_extra_is_not_a_generator_copy(self):
        self.save("settings.json", b'{"seed":17}\n')
        with self.assertRaises(RuntimeError):
            subject.verify_candidate_project(self.source, self.project)

    def test_runtime_source_and_payload_identity_are_both_verified(self):
        self.canonical["native/src/world.cpp"] = b"int fixture_world = 1;\r\n"
        identities = subject.verify_runtime_project(self.source, self.project)
        self.assertEqual(len(identities), 2)
        self.assertEqual({row["sha256"] for row in identities},
                         {digest(payload) for payload in self.payloads.values()})
        self.assertTrue(all(row["source_inputs"] == 1 for row in identities))

    def test_native_source_drift_cannot_reuse_stale_manifest(self):
        self.canonical["native/src/world.cpp"] = b"int fixture_world = 2;\n"
        with self.assertRaises(RuntimeError):
            subject.verify_runtime_project(self.source, self.project)

    def test_rapier_patch_drift_cannot_reuse_stale_manifest(self):
        self.canonical["third_party/patches/rapier.patch"] = b"different patch\n"
        with self.assertRaises(RuntimeError):
            subject.verify_runtime_project(self.source, self.project)

    def test_substituted_binary_is_rejected_for_each_runtime(self):
        for relative, original in self.payloads.items():
            self.save(relative, b"substituted binary")
            with self.subTest(artifact=relative), self.assertRaises(RuntimeError):
                subject.verify_runtime_project(self.source, self.project)
            self.save(relative, original)

    def test_missing_runtime_manifest_is_rejected(self):
        (self.project / self.manifest_paths[0]).unlink()
        with self.assertRaises((RuntimeError, OSError)):
            subject.verify_runtime_project(self.source, self.project)

    def test_empty_runtime_source_ledger_is_rejected(self):
        manifest = deepcopy(self.manifests[0])
        manifest["source_inputs"] = {}
        self.save(self.manifest_paths[0], json.dumps(manifest).encode())
        with self.assertRaises(RuntimeError):
            subject.verify_runtime_project(self.source, self.project)

    def test_control_extract_copies_only_verified_runtime_payloads(self):
        project, identities = subject.source_project(self.source, self.base / "control", self.project)
        self.assertEqual(len(identities), 2)
        for relative, payload in self.payloads.items():
            self.assertEqual((project / relative).read_bytes(), payload)

    def test_control_extract_rejects_source_and_binary_substitution(self):
        artifact = next(iter(self.payloads))
        self.save(artifact, b"substituted runtime")
        with self.assertRaises(RuntimeError):
            subject.source_project(self.source, self.base / "bad-binary", self.project)
        self.save(artifact, self.payloads[artifact])
        self.canonical["native/src/world.cpp"] = b"different native source\n"
        with self.assertRaises(RuntimeError):
            subject.source_project(self.source, self.base / "bad-source", self.project)

    def test_control_extract_rejects_empty_runtime_source_ledger(self):
        manifest = deepcopy(self.manifests[0])
        manifest["source_inputs"] = {}
        self.canonical["godot/" + self.manifest_paths[0]] = json.dumps(manifest).encode()
        with self.assertRaises(RuntimeError):
            subject.source_project(self.source, self.base / "empty-ledger", self.project)


if __name__ == "__main__":
    unittest.main()
