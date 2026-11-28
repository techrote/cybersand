"""Artificial evidence controls, not discovered CyberSand defects."""
import copy
import unittest

import minimize
import verify_transcript as evidence


def tape(actions, *, injected=True):
    result = {"schema": evidence.SCHEMA, "header": {"fixture_id": "construction", "fixture_version": 1,
              "initial_scene_identity": "artificial-fixture-only", "policy": "CONTROL", "seed": 13,
              "budget": 64, "evidence_kind": "unit_fixture", "provenance": {
                  "source_commit": "1" * 40, "source_tree": "2" * 40, "godot_sha256": "3" * 64,
                  "native_sha256": "4" * 64, "rapier_sha256": "5" * 64}}, "steps": [], "summary": {"termination": "completed"}}
    native = {"generation": 4, "revision": 5, "tick": 0, "failed": False}
    state = {"native": native, "paused": True, "material": 2, "actors": [], "pilot_actor": 0}
    armed = False
    for index, action in enumerate(actions):
        before, after = copy.deepcopy(state), copy.deepcopy(state)
        assertions, interval = [{"id": "native_world_healthy", "status": "pass", "kind": "gameplay", "expected": False, "actual": False}], {}
        if action["id"] == "pause":
            interval = {"start_tick": 0, "end_tick": 0, "observed_frames": 3}
        elif action["id"] == "select_material":
            after["material"] = action["args"]["material"]
            armed = after["material"] == 58
        elif action["id"] == "panel":
            broken = injected and armed and action["args"]["open"]
            after["details_open"] = not action["args"]["open"] if broken else action["args"]["open"]
            assertions = [{"id": "panel_state", "kind": "gameplay", "status": "fail" if broken else "pass",
                           "expected": action["args"]["open"], "actual": after["details_open"]}]
        result["steps"].append({"index": index, "action": copy.deepcopy(action), "before": before, "after": after,
                                "admission": {"accepted": True}, "native_receipt": {}, "status": "completed",
                                "classification": "game_observation", "duration_usec": 10, "error": "",
                                "capture_before": {}, "capture_after": {}, "interval": interval,
                                "assertions": assertions, "observation_sha256": "a" * 64, "semantic_sha256": "b" * 64})
        state = after
    # Artificial controls follow the same terminal distinction as the game.
    result["summary"]["termination"] = "assertion_failure" if any(item["status"] == "fail" for row in result["steps"] for item in row["assertions"]) else "budget_complete"
    result["summary"] = evidence.summarize(result)
    return result


ACTIONS = [{"id": "pause", "args": {}}, {"id": "select_material", "args": {"material": 58}},
           {"id": "pause", "args": {}}, {"id": "panel", "args": {"panel": "details", "open": True}}]


class ReadbackControls(unittest.TestCase):
    def test_positive_and_deliberate_negative_are_explicit_unit_fixtures(self):
        for injected in (False, True):
            with self.subTest(injected=injected):
                result = evidence.verify(tape(ACTIONS, injected=injected))
                self.assertTrue(result["valid"], result)
                self.assertEqual(result["evidence_kind"], "unit_fixture")
                self.assertEqual(len(result["independent_failures"]), int(injected))

    def test_unreported_raw_failure_cannot_be_hidden_by_pass_label(self):
        value = tape(ACTIONS)
        value["steps"][-1]["assertions"][0]["status"] = "pass"
        value["summary"] = evidence.summarize(value)
        result = evidence.verify(value)
        self.assertFalse(result["valid"])
        self.assertEqual(result["unreported_failures"][0]["id"], "panel_state")

    def test_completed_edit_receipt_must_identify_actual_publication(self):
        # Artificial dictionaries test the reader, never an observed game defect.
        row = tape([{"id": "pause", "args": {}}], injected=False)["steps"][0]
        row["action"] = {"id": "brush", "args": {"x": 20, "y": 20, "radius": 0}}
        row["after"]["native"]["revision"] = 6
        for key, revision, materials in (("capture_before", 5, [0]), ("capture_after", 6, [2])):
            row[key] = {"region": [20, 20, 1, 1], "materials": materials, "native_receipt": {
                "kind": "capture", "status": "completed", "backend": "CyberNativeCellWorld",
                "generation": 4, "observed_generation": 4, "revision": revision, "tick": 0,
                "region": [20, 20, 1, 1]}}
        row["native_receipt"] = {"kind": "edit", "status": "completed", "backend": "CyberNativeCellWorld",
            "generation": 4, "observed_generation": 4, "revision": 6, "tick": 0, "applied": 1, "changed": 1}
        self.assertEqual(evidence.independent_failures({"steps": [row]}), [])
        for key, value, assertion in (("kind", "capture", "native_edit_completed"),
                                      ("revision", 5, "native_edit_source_identity"),
                                      ("observed_generation", 3, "native_edit_source_identity")):
            bad = copy.deepcopy(row)
            bad["native_receipt"][key] = value
            self.assertIn(assertion, {item["id"] for item in evidence.independent_failures({"steps": [bad]})})

    def test_body_protection_na_requires_exact_capture_and_saved_observation(self):
        # Explicitly artificial positive/negative controls, not application findings.
        save = tape([{"id": "save_layout", "args": {}}], injected=False)["steps"][0]
        save["after"].update(authored_digest="artificial-layout", actor_ids=[1], actors=[{"id": 1, "observed": True}])
        save["before"] = copy.deepcopy(save["after"])
        source = dict(save["after"]["native"], paused=True)
        capture = {"region": [0, 0, 512, 512], "admission": {"status": "queued", "operation_id": 17},
            "source_before": copy.deepcopy(source), "source_after": copy.deepcopy(source), "error": "artificial body protection",
            "native_receipt": {"kind": "capture", "status": "refused", "backend": "CyberNativeCellWorld",
                "operation_id": 17, "generation": 4, "observed_generation": 4, "revision": 5, "tick": 0,
                "region": [0, 0, 512, 512], "applied": 0, "changed": 0,
                "reason": "Move or remove the body before editing or copying its covered cells."}}
        save["persistence_capture"] = copy.deepcopy(capture)
        save["persistence"] = {"read_authored_digest": "artificial-layout", "saved_native_tick": 0,
            "native_material_equality_applicable": False, "native_material_equality_reason": "native_body_protection"}
        reopen = copy.deepcopy(save)
        reopen.update(index=1, action={"id": "reopen_layout", "args": {}})
        reopen["persistence"]["saved_capture"] = copy.deepcopy(capture)
        self.assertEqual(evidence.independent_failures({"steps": [save, reopen]}), [])
        for mutate in (lambda r: r["persistence_capture"].update(native_receipt={}),
                       lambda r: r["persistence_capture"]["native_receipt"].update(reason="unrelated refusal"),
                       lambda r: r["after"].update(actors=[], actor_ids=[]),
                       lambda r: r["persistence_capture"]["source_after"].update(revision=99),
                       lambda r: r["persistence"].update(native_material_equality_reason="invented")):
            bad = copy.deepcopy(reopen)
            mutate(bad)
            self.assertTrue(evidence.independent_failures({"steps": [save, bad]}))
        completed_capture = copy.deepcopy(capture)
        del completed_capture["error"]
        completed_capture["native_receipt"].update(status="completed", reason="")
        completed_capture.update(count=512 * 512, material_sha256="a" * 64)
        save["persistence_capture"] = copy.deepcopy(completed_capture)
        save["persistence"].update(material_sha256="a" * 64, native_material_equality_applicable=True, native_material_equality_reason="available")
        reopen["persistence_capture"] = copy.deepcopy(completed_capture)
        reopen["persistence"].update(saved_capture=copy.deepcopy(completed_capture), saved_material_sha256="a" * 64,
            reopened_material_sha256="a" * 64, native_material_equality_applicable=True, native_material_equality_reason="available")
        self.assertEqual(evidence.independent_failures({"steps": [save, reopen]}), [])
        reopen["persistence_capture"]["material_sha256"] = "b" * 64
        self.assertIn("reopen_material_capture_identity", {item["id"] for item in evidence.independent_failures({"steps": [save, reopen]})})

    def test_forged_counts_and_missing_source_fail(self):
        original = tape(ACTIONS)
        for key in ("source_commit", "source_tree", "godot_sha256", "native_sha256", "rapier_sha256"):
            value = copy.deepcopy(original)
            del value["header"]["provenance"][key]
            self.assertFalse(evidence.verify(value)["valid"], key)
        value = copy.deepcopy(original)
        value["summary"]["completed_actions"] = 500
        self.assertFalse(evidence.verify(value)["valid"])

    def test_malformed_nested_types_do_not_raise(self):
        original = tape(ACTIONS)
        for key in ("action", "before", "after", "native_receipt", "admission", "assertions", "interval", "status", "capture_before", "persistence", "persistence_capture"):
            for wrong in (None, [], "wrong", 1, True):
                with self.subTest(key=key, wrong=wrong):
                    value = copy.deepcopy(original)
                    value["steps"][0][key] = wrong
                    self.assertFalse(evidence.verify(value)["valid"])
        value = copy.deepcopy(original)
        value["header"]["fixture_id"] = []
        self.assertFalse(evidence.verify(value)["valid"])

    def test_finite_vocabulary_and_ranges(self):
        valid = [{"id": "brush", "args": {"x": 8, "y": 503, "radius": 4}},
                 {"id": "rectangle", "args": {"x0": 8, "y0": 8, "x1": 71, "y1": 71}},
                 {"id": "actor_place", "args": {"model": "kestrel", "x": 32, "y": 224}},
                 {"id": "actor_pilot", "args": {"actor_id": 8}},
                 {"id": "actor_reset", "args": {}}, {"id": "single_step", "args": {}}]
        for action in valid:
            self.assertIsNone(evidence.action_error(action))
            bad = copy.deepcopy(action)
            bad["args"]["path"] = "outside-vocabulary"
            self.assertIsNotNone(evidence.action_error(bad))
        for bad in ({"id": "brush", "args": {"x": True, "y": 20, "radius": 1}},
                    {"id": "brush", "args": {"x": 7, "y": 20, "radius": 1}},
                    {"id": "actor_place", "args": {"model": "unknown", "x": 32, "y": 224}},
                    {"id": "wait_ticks", "args": {}}, {"id": "arbitrary", "args": {}}):
            self.assertIsNotNone(evidence.action_error(bad))

    def test_all_attempts_preserved_in_coverage(self):
        value = tape(ACTIONS, injected=False)
        row = value["steps"][1]
        row["status"], row["classification"] = "refused", "not_applicable"
        value["summary"] = evidence.summarize(value)
        result = evidence.verify(value)
        self.assertTrue(result["valid"], result)
        self.assertEqual(result["summary"]["attempted_actions"], 4)
        self.assertEqual(result["summary"]["completed_actions"], 3)
        self.assertEqual(result["summary"]["classification_counts"]["not_applicable"], 1)
        self.assertNotIn("pause -> pause", result["summary"]["completed_adjacent_pairs"])


class ReductionControls(unittest.TestCase):
    def test_actual_callback_required_and_unit_claims_refused_by_default(self):
        with self.assertRaisesRegex(ValueError, "artificial"):
            minimize.minimize(tape(ACTIONS), tape)

    def test_bounded_injected_two_step_reduction(self):
        original = tape(ACTIONS)
        original_copy = copy.deepcopy(original)
        result = minimize.minimize(original, tape, allow_unit_fixture=True, max_attempts=24)
        self.assertEqual(original, original_copy)
        self.assertEqual(result["status"], "reduced")
        self.assertEqual([row["id"] for row in result["actions"]], ["select_material", "panel"])
        self.assertLessEqual(len(result["attempts"]), 24)
        self.assertTrue(all(row["status"] != "pending" for row in result["attempts"]))

    def test_unrepeatable_original_is_retained(self):
        calls = 0
        def alternating(actions):
            nonlocal calls
            calls += 1
            return tape(actions, injected=calls % 2 == 1)
        result = minimize.minimize(tape(ACTIONS), alternating, allow_unit_fixture=True)
        self.assertEqual(result["status"], "original_not_repeatable")
        self.assertEqual(result["actions"], ACTIONS)
        self.assertEqual(len(result["attempts"]), 2)

    def test_wrong_runtime_or_replay_error_cannot_be_reproduction(self):
        def wrong_source(actions):
            value = tape(actions)
            value["header"]["provenance"]["native_sha256"] = "9" * 64
            return value
        result = minimize.minimize(tape(ACTIONS), wrong_source, allow_unit_fixture=True)
        self.assertEqual(result["status"], "original_not_repeatable")
        self.assertEqual(result["attempts"][0]["status"], "source_fixture_runtime_mismatch")
        def error(_):
            raise RuntimeError("artificial replay exception")
        result = minimize.minimize(tape(ACTIONS), error, allow_unit_fixture=True)
        self.assertEqual(result["attempts"][0]["status"], "replay_error")

    def test_probe_budget_is_hard_bound(self):
        result = minimize.minimize(tape(ACTIONS), tape, allow_unit_fixture=True, max_attempts=2)
        self.assertEqual(len(result["attempts"]), 2)
        self.assertEqual(result["status"], "budget_exhausted")
        self.assertEqual(result["actions"], ACTIONS)


if __name__ == "__main__":
    unittest.main()
