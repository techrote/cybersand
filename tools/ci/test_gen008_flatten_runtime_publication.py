#!/usr/bin/env python3
"""Publication admission negatives; synthetic fixtures never claim execution."""
from __future__ import annotations

import copy
import inspect
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import gen008_flatten_runtime_publication as subject
import mat_workbench_runtime_publication as original

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_gen008_flatten_candidate as package
import package_mat_workbench_candidate as original_package


class PublicationIdentity(unittest.TestCase):
    def test_private_profile_retains_the_entire_four_path_lease_engine(self):
        self.assertIsNot(subject.workbench, original)
        self.assertIsNot(subject.engine, original.engine)
        self.assertEqual(original.engine.BRANCH, "codex/mat-auth-workbench-integration-20261112")
        self.assertEqual(subject.engine.BRANCH, "feat/gen008-flatten-material-baseline")
        for name in ("context", "check_source", "check_index", "require_publication_request", "input_ledgers", "stage"):
            self.assertEqual(inspect.getsource(getattr(subject.engine, name)),
                             inspect.getsource(getattr(original.engine, name)))
        self.assertEqual(subject.engine.RUNTIMES, original.engine.RUNTIMES)
        self.assertEqual(subject.engine.MANIFESTS, original.engine.MANIFESTS)
        self.assertEqual(subject.engine.CASE_MARKERS, original.engine.CASE_MARKERS)
        self.assertEqual(subject.workbench.regression_labels(), original.regression_labels())
        self.assertEqual(subject.workbench.lab.DISPATCH_WORKFLOWS,
                         ("documentation.yml", "native.yml", "gdextension.yml", "palette-shader-qualification.yml"))
        self.assertNotIn(original.engine.REQUEST, subject.engine.BUILD_EXACT)
        self.assertNotIn(original.engine.WORKFLOW, subject.engine.BUILD_EXACT)
        for path in (subject.engine.WORKFLOW, subject.engine.REQUEST, subject.engine.EVIDENCE,
                     "tools/ci/run_flatten_qualification.py", "tools/package_gen008_flatten_candidate.py"):
            self.assertIn(path, subject.engine.BUILD_EXACT)

    def test_foreign_repository_event_branch_workflow_or_source_refuses(self):
        source = "a"*40
        env = {"GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
               "GITHUB_REF": "refs/heads/"+subject.engine.BRANCH, "GITHUB_SHA": source,
               "GITHUB_WORKFLOW_REF": "techrote/cybersand/"+subject.engine.WORKFLOW+"@refs/heads/"+subject.engine.BRANCH,
               "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "1"}
        with patch.object(subject.engine, "git", return_value=source.encode()):
            with patch.dict(os.environ, env, clear=True):
                self.assertEqual(subject.engine.context(source)["source_commit"], source)
            for key, value in (("GITHUB_REPOSITORY", "other/cybersand"), ("GITHUB_EVENT_NAME", "pull_request"),
                               ("GITHUB_REF", "refs/heads/main"), ("GITHUB_REF", "refs/heads/"+original.engine.BRANCH),
                               ("GITHUB_SHA", "b"*40), ("GITHUB_RUN_ATTEMPT", "0"),
                               ("GITHUB_WORKFLOW_REF", env["GITHUB_WORKFLOW_REF"].replace(subject.engine.WORKFLOW, original.engine.WORKFLOW))):
                with self.subTest(key=key, value=value), patch.dict(os.environ, env | {key: value}, clear=True):
                    with self.assertRaises(RuntimeError): subject.engine.context(source)

    def test_request_must_explicitly_bind_this_feature_and_positive_sequence(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for relative in (subject.engine.REQUEST, subject.engine.EVIDENCE, subject.engine.PRESSURE_CASE,
                             *["godot/tests/"+name+".gd" for name in subject.engine.CASE_MARKERS]):
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture", encoding="utf-8")
            requests = [dict(original.engine.REQUEST_VALUE, request_sequence=1),
                        dict(subject.engine.REQUEST_VALUE, request_sequence=0),
                        dict(subject.engine.REQUEST_VALUE, request_sequence=True),
                        dict(subject.engine.REQUEST_VALUE, request_sequence=1, extra=True),
                        dict(subject.engine.REQUEST_VALUE, request_sequence=1, scope="format-only")]
            with patch.object(subject.engine, "ROOT", root):
                for index, request in enumerate([dict(subject.engine.REQUEST_VALUE, request_sequence=1), *requests]):
                    raw = (json.dumps(request)+"\n").encode()
                    (root / subject.engine.REQUEST).write_bytes(raw)
                    with patch.object(subject.engine, "git", return_value=raw):
                        if index == 0:
                            subject.engine.require_publication_request("a"*40)
                        else:
                            with self.assertRaises(RuntimeError): subject.engine.require_publication_request("a"*40)

    def test_package_privately_rebinds_complete_predecessor_not_global_owner(self):
        self.assertIsNot(package.workbench, original_package)
        self.assertIs(package.workbench.publication, subject)
        self.assertIs(package.workbench.lab.publication, subject)
        self.assertIs(original_package.publication, original)
        self.assertIn("workbench.smoke(package", inspect.getsource(package.smoke))
        self.assertIn("verify_flatten_cases", inspect.getsource(package.smoke))


class FlattenReceiptAdmission(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        self.native = "d"*64
        self.records = []
        self.storage_fixture()
        for index, label in enumerate(subject.flatten_labels()):
            record = {"label": label, "status": "passed", "exit_code": 0,
                      "sampled_peak_rss_bytes": 1024, "os_peak_rss_bytes": 2048}
            if index < 2:
                self.log(label, "import succeeded\n" if index == 0 else "WORKBENCH_MATERIAL_BASELINE checks=90 failures=0\n")
            else:
                side, workers, phase = label.split("-")[1], label.split("-")[3], label.split("-")[4]
                side, workers = int(side), int(workers)
                identity = {"native_sha256": self.native, "os": "Linux", "display": "X11",
                            "godot": subject.workbench.GODOT_DISPLAY_VERSION}
                identity.update({path: subject.engine.runner.sha256(subject.engine.ROOT / "godot" / path)
                                 for path in subject.SOURCE_PATHS})
                phases = {name: True for name in ("startup", "generate", "construction", "simulation", "flatten_paused",
                    "flatten_playing", "post_flatten_history", "save", "complete", "failure_atomicity", "reopen", "continued_authoring")}
                labels = (["before-simulation", "simulation-derived-materials", "after-flatten",
                           "post-flatten-edits-before-later-simulation", "later-simulation-excluded-from-save"]
                          if phase == "author" else ["fresh-process-reconstructed-plane"])
                hashes = ["a", "b", "b", "b", "c"]
                witnesses = [{"label": name, "bytes": side*side*2, "sha256": hashes[i]*64,
                              "generation": 7, "native_generation": 5, "tick": 12, "revision": 34}
                             for i, name in enumerate(labels)]
                record["completion"] = {"checks": 100, "failures": [], "completed": True, "phase": phase,
                    "side": side, "workers": workers, "canonical_bytes": side*side*2, "source_identity": identity,
                    "phases": phases, "native_material_witnesses": witnesses, "process_instance": f"{index:032x}"}
                self.log(label, "FLATTEN_RESULT "+json.dumps(record["completion"])+"\n")
                frames = self.directory / (label+"-frames")
                frames.mkdir()
                for name in (["flatten-identical-live-world.png", "flatten-explicitly-saved.png"]
                             if phase == "author" else ["flatten-reopened-and-continued.png"]):
                    (frames / name).write_bytes(b"\x89PNG\r\n\x1a\nfixture")
            self.records.append(record)
        self.save_records()

    def storage_fixture(self):
        directory = self.directory / "storage-faults"
        directory.mkdir()
        report = {"schema": "gen008-flatten-storage-faults-v1", "platform": "linux",
                  "status": "passed", "completed": True, "cases": []}
        for kind in ("partial-write", "process-termination"):
            row = {"kind": kind, "prior_sha256": "1"*64, "after_sha256": "1"*64, "retry_ok": True,
                   "retry_sha256": "2"*64, "attempted_plane_bytes": 524288, "file_size_limit_bytes": 65536,
                   "exit_code": -25 if kind == "process-termination" else 0,
                   "explicit_refusal": kind == "partial-write",
                   "partial_temporary_bytes": [65536] if kind == "process-termination" else []}
            if kind == "process-termination": row["signal"] = 25
            report["cases"].append(row)
            for phase in ("prepare", "recover", "refusal"):
                receipt = {"checks": 3, "failures": [], "phase": phase,
                           "error": "injected storage fault" if phase == "refusal" else "",
                           "prior_sha256": "1"*64, "after_sha256": "2"*64 if phase == "recover" else "1"*64}
                text = ("FLATTEN_STORAGE_WRITING {}\n" if phase == "refusal" and kind == "process-termination"
                        else "FLATTEN_STORAGE_RESULT "+json.dumps(receipt)+"\n")
                (directory / f"{kind}-{phase}.log").write_text(text, encoding="utf-8")
        self.write("storage-faults.json", report)
        self.storage_summary()

    def storage_summary(self):
        self.write("qualification.json", {"status": "passed", "cases": [list(c) for c in subject.CASES],
                   "graphical": True, "storage_faults": {"status": "passed", "report_sha256":
                   subject.engine.runner.sha256(self.directory / "storage-faults.json")}})

    def tearDown(self):
        self.temporary.cleanup()

    def write(self, name, data):
        (self.directory / name).write_text(json.dumps(data), encoding="utf-8")

    def log(self, label, text):
        (self.directory / (label+".log")).write_text(text, encoding="utf-8")

    def save_records(self):
        self.write("results.json", self.records)

    def update_receipt(self, index):
        self.log(self.records[index]["label"], "FLATTEN_RESULT "+json.dumps(self.records[index]["completion"])+"\n")
        self.save_records()

    def verify(self):
        return subject.verify_flatten_cases(self.directory, "linux", self.native, subject.engine.ROOT / "godot")

    def test_complete_registered_receipt_fixture_is_admitted(self):
        self.assertEqual(len(self.verify()), 10)

    def test_partial_reordered_failed_or_missing_original_log_refuses(self):
        original_records = copy.deepcopy(self.records)
        for mutation in ("missing", "reorder", "failed", "log"):
            with self.subTest(mutation=mutation):
                self.records = copy.deepcopy(original_records)
                if mutation == "missing": self.records.pop()
                if mutation == "reorder": self.records.reverse()
                if mutation == "failed": self.records[-1]["exit_code"] = 1
                if mutation == "log": (self.directory / (self.records[-1]["label"]+".log")).unlink()
                self.save_records()
                with self.assertRaises(RuntimeError): self.verify()

    def test_headless_or_partial_scale_summary_refuses(self):
        for summary in ({"status": "passed", "cases": [list(c) for c in subject.CASES], "graphical": False},
                        {"status": "passed", "cases": [[512, 1]], "graphical": True}):
            self.write("qualification.json", summary)
            with self.assertRaises(RuntimeError): self.verify()

    def test_wrong_platform_runtime_or_script_refuses(self):
        original_receipt = copy.deepcopy(self.records[2]["completion"])
        for key, value in (("os", "Windows"), ("display", "headless"), ("native_sha256", "e"*64),
                           ("godot", "4.6"), (subject.SOURCE_PATHS[0], "f"*64)):
            with self.subTest(key=key):
                self.records[2]["completion"] = copy.deepcopy(original_receipt)
                self.records[2]["completion"]["source_identity"][key] = value
                self.update_receipt(2)
                with self.assertRaises(RuntimeError): self.verify()

    def test_cannot_publish_renderer_only_or_changed_world_witnesses(self):
        original_receipt = copy.deepcopy(self.records[2]["completion"])
        for mutation in ("missing", "material", "tick", "generation", "simulation"):
            with self.subTest(mutation=mutation):
                self.records[2]["completion"] = copy.deepcopy(original_receipt)
                witnesses = self.records[2]["completion"]["native_material_witnesses"]
                if mutation == "missing": witnesses.pop(2)
                if mutation == "material": witnesses[2]["sha256"] = "f"*64
                if mutation in ("tick", "generation"): witnesses[2][mutation] += 1
                if mutation == "simulation": witnesses[0]["sha256"] = witnesses[1]["sha256"]
                self.update_receipt(2)
                with self.assertRaises(RuntimeError): self.verify()

    def test_same_process_reopen_missing_graphics_or_memory_refuses(self):
        previous = self.records[3]["completion"]["process_instance"]
        self.records[3]["completion"]["process_instance"] = self.records[2]["completion"]["process_instance"]
        self.update_receipt(3)
        with self.assertRaises(RuntimeError): self.verify()
        self.records[3]["completion"]["process_instance"] = previous
        self.update_receipt(3)
        self.records[2]["sampled_peak_rss_bytes"] = 0
        self.save_records()
        with self.assertRaises(RuntimeError): self.verify()
        self.records[2]["sampled_peak_rss_bytes"] = 1024
        self.save_records()
        (self.directory / (self.records[2]["label"]+"-frames") / "flatten-identical-live-world.png").unlink()
        with self.assertRaises(RuntimeError): self.verify()

    def test_original_workbench_bundle_alone_cannot_satisfy_new_publication(self):
        with patch.object(subject, "_verify_workbench_bundle", return_value={"sha256": self.native}):
            with self.assertRaises(FileNotFoundError):
                subject.verify_materials_bundle(self.directory, "linux", "a"*40)

    def test_storage_faults_cannot_omit_actual_partial_write_or_successful_retry(self):
        report = json.loads((self.directory / "storage-faults.json").read_text())
        for mutation in ("missing", "old-save", "retry", "not-partial", "not-terminated", "no-refusal"):
            with self.subTest(mutation=mutation):
                altered = copy.deepcopy(report)
                if mutation == "missing": altered["cases"].pop()
                if mutation == "old-save": altered["cases"][0]["after_sha256"] = "3"*64
                if mutation == "retry": altered["cases"][0]["retry_ok"] = False
                if mutation == "not-partial": altered["cases"][1]["partial_temporary_bytes"] = [0]
                if mutation == "not-terminated": altered["cases"][1]["exit_code"] = 0
                if mutation == "no-refusal": altered["cases"][0]["explicit_refusal"] = False
                self.write("storage-faults.json", altered)
                self.storage_summary()
                with self.assertRaises(RuntimeError): self.verify()


if __name__ == "__main__":
    unittest.main()
