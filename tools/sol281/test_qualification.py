#!/usr/bin/env python3
"""Adverse controls for the scoped qualification reader; no physics claims."""
import argparse
import copy
from contextlib import redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import run_qualification as q


def payload(spec, platform="Linux"):
    result = {"checks": spec.checks or 200, "failures": [], "platform": platform}
    if spec.workers:
        result["workers"] = spec.workers
    if spec.name == "lifecycle":
        result["actual_host_replacement_cycles"] = 20
    if spec.script == "test_solid_detachment_displacement":
        result["checks"] = 292
        result["cases"] = 17
    if spec.script == "test_solid_detachment_populated":
        result["conservative_displacement"] = "--baseline" not in spec.flags
        result["surroundings"] = next(x.split("=", 1)[1] for x in spec.flags if x.startswith("--surroundings="))
    return result


def structured_result(spec, footer):
    result = copy.deepcopy(footer)
    if spec.script == "test_solid_detachment_displacement":
        path = q.ROOT / "godot/tests/fixtures/sol281/conservative_contacts.json"
        fixtures = json.loads(path.read_text(encoding="utf-8"))["fixtures"]
        result.update(schema="cybersand.sol281.conservative-displacement-replay.v1",
                      fixture_sha256=q.digest(path), cases=[{
                          "id": fixture["id"], "failure_count": 0,
                          "expected_accepted": fixture["expected_accepted"],
                          "outcome": "Applied" if fixture["expected_accepted"] else "GeometryBlocked",
                          "moved_cells": fixture["expected_minimum_moves"],
                          "path": fixture.get("expected_path", []),
                          "geometry_clear": fixture["expected_accepted"],
                          "before_sha256": "a" * 64,
                          "after_sha256": ("b" if fixture["expected_accepted"] else "a") * 64,
                      } for fixture in fixtures])
    return result


class QualificationReader(unittest.TestCase):
    def test_complete_inventory_and_parent_budgets(self):
        for cohort in q.COHORTS:
            cases = q.inventory(cohort)
            self.assertEqual(len({x.name for x in cases}), len(cases))
            for case in cases:
                self.assertTrue((q.ROOT / "godot/tests" / (case.script + ".gd")).is_file())
            allowance = (q.policy.aggregate_seconds([q.policy.case_seconds(x.script) for x in cases])
                         + (len(cases) + 1) * q.policy.godot_process_cleanup_seconds()
                         + q.policy.watchdog_seconds("godot_metadata_seconds")
                         + 2 * q.policy.watchdog_seconds("dependency_prepare_seconds"))
            self.assertLessEqual(allowance, q.policy.identity()["watchdogs"]["godot_job_minutes"] * 60)
        self.assertEqual([len(q.inventory(x)) for x in q.COHORTS], [11, 9, 9])

    def test_all_declared_footers_and_worker_policies(self):
        for cohort in q.COHORTS:
            for spec in q.inventory(cohort):
                value = payload(spec)
                line = spec.footer + (" " + json.dumps(value) if spec.structured else "") + "\n"
                self.assertEqual(q.verify_footer(spec, line, "Linux"), value if spec.structured else None)
                with self.assertRaises(RuntimeError):
                    q.verify_footer(spec, line + line, "Linux")
                with self.assertRaises(RuntimeError):
                    q.verify_footer(spec, "", "Linux")
                if spec.structured:
                    with self.assertRaises(RuntimeError):
                        q.verify_footer(spec, line, "Windows")
                    value["failures"] = ["original failure must survive"]
                    with self.assertRaises(RuntimeError):
                        q.verify_footer(spec, spec.footer + " " + json.dumps(value), "Linux")

    def test_truncated_and_mislabelled_inventory_refused(self):
        for cohort in q.COHORTS:
            for spec in q.inventory(cohort):
                if not spec.structured:
                    continue
                fields = {"checks": payload(spec)["checks"] - 1}
                if spec.workers:
                    fields["workers"] = 4 if spec.workers == 1 else 1
                if spec.name == "lifecycle":
                    fields["actual_host_replacement_cycles"] = 19
                if spec.script == "test_solid_detachment_displacement":
                    fields["cases"] = 16
                if spec.script == "test_solid_detachment_populated":
                    fields["surroundings"] = "empty"
                    fields["conservative_displacement"] = "--baseline" in spec.flags
                for key, invalid in fields.items():
                    value = payload(spec)
                    value[key] = invalid
                    with self.assertRaises(RuntimeError, msg=spec.name + ":" + key):
                        q.verify_footer(spec, spec.footer + " " + json.dumps(value), "Linux")

    def test_original_result_required_and_reopened(self):
        spec = q.inventory("contact-w1")[1]
        footer = payload(spec)
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            with self.assertRaises(RuntimeError):
                q.verify_result_file(spec, directory, footer)
            value = structured_result(spec, footer)
            path = directory / (spec.name + ".json")
            q.write_json(path, value)
            self.assertEqual(q.verify_result_file(spec, directory, footer)["sha256"], q.digest(path))
            value["cases"].pop()
            q.write_json(path, value)
            with self.assertRaises(RuntimeError):
                q.verify_result_file(spec, directory, footer)

    def test_replay_case_inventory_and_dispositions_refuse_false_green(self):
        spec = q.inventory("contact-w1")[1]
        footer = payload(spec)
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            path = directory / (spec.name + ".json")
            original = structured_result(spec, footer)
            mutations = []
            for label, field, invalid in (
                ("missing-id", "id", None),
                ("duplicate-id", "id", original["cases"][1]["id"]),
                ("missing-case-assertions", "failure_count", None),
                ("case-failure", "failure_count", 1),
                ("bool-case-assertions", "failure_count", False),
                ("wrong-disposition", "outcome", "Applied"),
                ("quarantined", "outcome", "Quarantined"),
                ("refusal-mutation", "after_sha256", "b" * 64),
            ):
                value = copy.deepcopy(original)
                value["cases"][0][field] = invalid
                mutations.append((label, value))
            value = copy.deepcopy(original)
            value["cases"][0], value["cases"][1] = value["cases"][1], value["cases"][0]
            mutations.append(("reordered", value))
            value = copy.deepcopy(original)
            value["cases"] = [{}] * 17
            mutations.append(("empty-records", value))
            value = copy.deepcopy(original)
            value["fixture_sha256"] = "0" * 64
            mutations.append(("wrong-fixture", value))
            value = copy.deepcopy(original)
            next(case for case in value["cases"] if case["expected_accepted"])["outcome"] = "GeometryBlocked"
            mutations.append(("positive-control-refused", value))
            for label, value in mutations:
                q.write_json(path, value)
                with self.assertRaises(RuntimeError, msg=label):
                    q.verify_result_file(spec, directory, footer)

    def test_tracked_source_byte_mutation_is_refused(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            attributes = root / ".gitattributes"
            attributes.write_bytes(b"*.cpp text eol=lf\n")
            (root / "native").mkdir()
            file = root / "native/fixture.cpp"
            file.write_bytes(b"canonical\n")
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                            "commit", "-qm", "reader fixture"], check=True)
            with patch.object(q, "ROOT", root):
                self.assertEqual(q.source_inputs(), {"native/fixture.cpp": hashlib.sha256(b"canonical\n").hexdigest(),
                    ".gitattributes": hashlib.sha256(attributes.read_bytes()).hexdigest()})
                file.write_bytes(b"uncommitted mutation\n")
                with self.assertRaises(RuntimeError):
                    q.source_inputs()

    def test_only_committed_crlf_conversion_is_admitted_and_raw_identity_is_retained(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            attributes = root / ".gitattributes"
            attributes.write_bytes(b"*.ps1 text eol=crlf\n*.cpp text eol=lf\n")
            (root / "tools").mkdir()
            (root / "native").mkdir()
            script = root / "tools/fixture.ps1"
            native = root / "native/fixture.cpp"
            script.write_bytes(b"first\nsecond\n")
            native.write_bytes(b"exact native source\n")
            subprocess.run(["git", "-C", str(root), "add", "."], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(root), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                            "commit", "-qm", "explicit CRLF checkout fixture"], check=True)
            with patch.object(q, "ROOT", root):
                canonical = q.source_inputs()
                raw_lf = q.checkout_inputs(canonical)
                script.write_bytes(b"first\r\nsecond\r\n")
                self.assertEqual(q.source_inputs(), canonical)
                raw_crlf = q.checkout_inputs(canonical)
                self.assertEqual(set(raw_lf), set(raw_crlf))
                self.assertNotEqual(raw_lf, raw_crlf)
                self.assertEqual(raw_crlf["tools/fixture.ps1"], hashlib.sha256(script.read_bytes()).hexdigest())
                for invalid in (b"first\r\nsecond\n", b"first\r\nchanged\r\n"):
                    script.write_bytes(invalid)
                    with self.assertRaises(RuntimeError):
                        q.source_inputs()
                script.write_bytes(b"first\r\nsecond\r\n")
                native.write_bytes(b"exact native source\r\n")
                with self.assertRaises(RuntimeError):
                    q.source_inputs()
                attributes.write_bytes(b"*.ps1 text eol=crlf\n*.cpp text eol=crlf\n")
                with self.assertRaises(RuntimeError):
                    q.source_inputs()
                attributes.write_bytes(b"*.ps1 text eol=crlf\n*.cpp text eol=lf\n")
                native.write_bytes(b"exact native source\n")
                (root / ".git/info/attributes").write_bytes(b"*.cpp eol=crlf\n")
                with self.assertRaises(RuntimeError):
                    q.source_inputs()

    def test_complete_aggregate_rejects_missing_and_altered_evidence(self):
        source = {"sha": "a" * 40, "tree": "b" * 40}
        with tempfile.TemporaryDirectory() as temp, patch.object(q, "source_identity", return_value=source), \
                patch.object(q, "source_inputs", return_value={"fixture": "identity"}):
            directory = Path(temp)
            first_path = None
            for platform in ("Linux", "Windows"):
                for cohort in q.COHORTS:
                    output = directory / (platform + "-" + cohort)
                    output.mkdir()
                    q.write_json(output / "inputs-before.json", {"fixture": "identity"})
                    q.write_json(output / "inputs-after.json", {"fixture": "identity"})
                    q.write_json(output / "checkout-inputs-before.json", {"fixture": "raw-" + platform})
                    q.write_json(output / "checkout-inputs-after.json", {"fixture": "raw-" + platform})
                    cases = q.inventory(cohort)
                    records = []
                    for spec in cases:
                        readback = payload(spec, platform) if spec.structured else None
                        text = spec.footer + (" " + json.dumps(readback) if spec.structured else "") + "\n"
                        log = output / (spec.name + ".log")
                        log.write_text(text, encoding="utf-8")
                        if spec.script in q.RESULT_FILES:
                            data = structured_result(spec, readback)
                            q.write_json(output / (spec.name + ".json"), data)
                        records.append({"name": spec.name, "status": "passed", "returncode": 0,
                            "natural_completion": True, "skip_messages": [], "readback": readback,
                            "log": log.name, "log_sha256": q.digest(log),
                            "result": q.verify_result_file(spec, output, readback)})
                    report = {"schema": "cybersand.sol281.qualification.v1", "status": "passed", "source": source,
                        "platform": platform, "cohort": cohort, "source_unchanged": True, "errors": [],
                        "checkout_inputs_unchanged": True,
                        "runtime": {"sha256": platform}, "expected_cases": [x.name for x in cases], "records": records}
                    q.write_json(output / "report.json", report)
                    if first_path is None:
                        first_path = output / "report.json"
            args = argparse.Namespace(input=directory, output=directory / "summary.json")
            with redirect_stdout(io.StringIO()):
                self.assertEqual(q.summarize(args), 0)
                # Agreement between all six cohorts is insufficient: the
                # reducer must also authenticate their inventory against HEAD.
                inventories = list(directory.rglob("inputs-before.json")) + list(directory.rglob("inputs-after.json"))
                for inventory in inventories:
                    q.write_json(inventory, {"fixture": "self-consistent-wrong-source"})
                self.assertEqual(q.summarize(args), 1)
                for inventory in inventories:
                    q.write_json(inventory, {"fixture": "identity"})
                self.assertEqual(q.summarize(args), 0)
                raw_after = first_path.parent / "checkout-inputs-after.json"
                raw_original = raw_after.read_bytes()
                q.write_json(raw_after, {"fixture": "changed raw bytes with identical canonical source"})
                self.assertEqual(q.summarize(args), 1)
                raw_after.write_bytes(raw_original)
                self.assertEqual(q.summarize(args), 0)
                original = first_path.read_bytes()
                first_path.unlink()
                self.assertEqual(q.summarize(args), 1)
                first_path.write_bytes(original)
                log = first_path.parent / "motion-w1.log"
                log.write_text(log.read_text() + "unrecorded change\n")
                self.assertEqual(q.summarize(args), 1)


if __name__ == "__main__":
    unittest.main()
