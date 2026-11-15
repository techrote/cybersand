#!/usr/bin/env python3
"""Fail-closed contract checks for the GEN-007 native publisher."""
import copy
import unittest
import gen007_architectural_runtime_publication as subject

def architecture(owner=False):
    phases = subject.OWNER_PHASES if owner else subject.FULL_PHASES
    rows = []
    for phase in phases:
        item = {"case": phase, "passed": True}
        if phase in subject.COUNTS:
            item["completion"] = [subject.COUNTS[phase]]
        if phase == "ui":
            item["completion"] = ["ARCHITECTURAL_UI checks=56 failures=0"]
        rows.append(item)
    return {"schema": 1, "passed": True, "failures": 0,
            "graphical_requested": True, "source_commit": "a"*40,
            "runtime_sha256": "b"*64, "cases": rows}

class Gen007PublicationGuards(unittest.TestCase):
    def test_scope_and_branch(self):
        self.assertEqual(subject.engine.BRANCH, "feat/gen007-architectural-generator-ab")
        self.assertEqual(subject.engine.WORKFLOW, ".github/workflows/architectural-generator-qualification.yml")
        self.assertEqual(subject.engine.REQUEST_VALUE["intent"], "publish-source-matched-runtimes")
        self.assertIn("tools/ci/gen007_architectural_runtime_publication.py", subject.engine.BUILD_EXACT)

    def test_full_and_package_campaigns_are_distinct(self):
        subject.validate_architecture(architecture(), "a"*40, "b"*64)
        subject.validate_architecture(architecture(True), "a"*40, "b"*64, owner=True)
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(architecture(True), "a"*40, "b"*64)

    def test_missing_fifth_card_and_multistyle_reopen_rejected(self):
        candidate = architecture()
        candidate["cases"][3]["completion"] = ["ARCHITECTURAL_UI checks=55 failures=0"]
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(candidate, "a"*40, "b"*64)
        candidate = architecture()
        candidate["cases"] = [c for c in candidate["cases"] if c["case"] != "multistyle-reopen"]
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(candidate, "a"*40, "b"*64)

    def test_stale_binary_or_headless_rejected(self):
        candidate = architecture()
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(candidate, "a"*40, "c"*64)
        candidate["graphical_requested"] = False
        with self.assertRaises(RuntimeError):
            subject.validate_architecture(candidate, "a"*40, "b"*64)

    def test_flatten_failure_and_wrong_cases_rejected(self):
        good = {"status":"passed", "graphical":True, "cases":[[512,1]],
                "storage_faults":{"status":"passed"}}
        subject.validate_flatten(good)
        for changes in ({"graphical":False}, {"cases":[[1024,1]]},
                        {"storage_faults":{"status":"failed"}}, {"status":"running"}):
            case = copy.deepcopy(good)
            case.update(changes)
            with self.assertRaises(RuntimeError):
                subject.validate_flatten(case)

    def test_changed_source_input_and_tree_rejected(self):
        original = {"source_commit":"a"*40, "source_tree":"d"*40,
                    "runtime_sha256":"b"*64,
                    "source_inputs_sha256":{"native/src/one.cpp":"c"*64}}
        subject.validate_source(original, "a"*40, "b"*64, "d"*40,
                                {"native/src/one.cpp":"c"*64})
        for changes in ({"source_tree":"e"*40}, {"runtime_sha256":"e"*64},
                        {"source_inputs_sha256":{}}):
            case = dict(original, **changes)
            with self.assertRaises(RuntimeError):
                subject.validate_source(case, "a"*40, "b"*64, "d"*40,
                                        {"native/src/one.cpp":"c"*64})

if __name__ == "__main__":
    unittest.main()
