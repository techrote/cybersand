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
import run_flatten_qualification as runner

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

    def test_windows_measurement_selects_only_the_pinned_sibling_engine(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory=Path(temporary)
            console=directory/"Godot_v4.7-stable_win64_console.exe"
            engine=directory/"Godot_v4.7-stable_win64.exe"
            console.write_bytes(b"wrapper fixture")
            with self.assertRaises(ValueError): runner.direct_engine(console,"win32")
            engine.write_bytes(b"engine fixture")
            self.assertEqual(runner.direct_engine(console,"win32"),engine)
            self.assertEqual(runner.direct_engine(engine,"win32"),engine)
            self.assertEqual(runner.direct_engine(console,"linux"),console)


class FlattenReceiptAdmission(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        self.native = "d"*64
        self.engine_sha = "e"*64
        self.executable = "/fixture/Godot_v4.7-stable_linux.x86_64"
        self.records = []
        self.storage_fixture()
        for index, label in enumerate(subject.flatten_labels()[:-2]):
            record = {"label": label, "status": "passed", "exit_code": 0,
                      "sampled_peak_rss_bytes": 1024, "os_peak_rss_bytes": 2048,
                      "engine_executable":self.executable,"engine_executable_sha256":self.engine_sha,
                      "measurement_target":"godot-engine-process","command":[self.executable],"pid":100+index}
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
                    "phases": phases, "native_material_witnesses": witnesses, "process_instance": f"{index:032x}",
                    "pid":record["pid"]}
                self.log(label, "FLATTEN_RESULT "+json.dumps(record["completion"])+"\n")
                frames = self.directory / (label+"-frames")
                frames.mkdir()
                for name in (["flatten-identical-live-world.png", "flatten-explicitly-saved.png"]
                             if phase == "author" else ["flatten-reopened-and-continued.png"]):
                    (frames / name).write_bytes(b"\x89PNG\r\n\x1a\nfixture")
            self.records.append(record)
        self.owner_failure_fixture()
        self.save_records()

    def owner_failure_fixture(self):
        identity={"native_sha256":self.native,"os":"Linux","display":"X11",
                  "godot":subject.workbench.GODOT_DISPLAY_VERSION}
        identity.update({path:subject.engine.runner.sha256(subject.engine.ROOT/"godot"/path)
                         for path in (*subject.SOURCE_PATHS,subject.OWNER_FAILURE_SCRIPT)})
        failure={"simulation_failed":True,"tick_failure_count":1,"failed_tick_index":13,
                 "last_tick_error":"active scheduling-core capacity exhausted"}
        owner={"host_instance":100,"worker_instance":-200,"generation":7,"authoring_generation":2,
               "paint_epoch":5,"agent_epoch":6,"tick":12,"revision":20,"failure_snapshot":failure,"has_failed":True,
               "baseline_sha256":"b"*64,"baseline_bytes":524288,"setup_sha256":"8"*64,"history_sha256":"9"*64,
               "undo_entries":3,"redo_entries":0,"physical":{"session":300,"bodies":[[400,500]]}}
        for phase,pid in (("author",1001),("reopen",1002)):
            label="owner-failure-"+phase
            receipt={"schema":"gen008-flatten-owner-failure-v1","phase":phase,"completed":True,
                     "checks":50,"failures":[],"process_instance":f"{pid:032x}","pid":pid,"source_identity":identity,
                     "expected_plane_sha256":"c"*64,"saved_plane_sha256":"c"*64,"saved_baseline_sha256":"b"*64,"saved_file_sha256":"d"*64,
                     "side":512,"canonical_bytes":524288,
                     "failure_count":1,"failure_reason":failure["last_tick_error"]}
            if phase=="author":
                receipt.update(pre_fault_native_plane_sha256="c"*64,failure_snapshot=failure,
                               owner_before_save=owner,owner_after_save=copy.deepcopy(owner),owner_preserved=True,
                               history_entries_before_fault=3,fence_checks={name:True for name in (
                                   "prepared_transaction","native_capture_lease","pending_flatten","pending_manual_edit",
                                   "pending_agent_edit","pending_step","failed_flatten","failed_reset","failed_restore",
                                   "unconfirmed_legacy_recipe")})
            else: receipt.update(reconstructed_plane_sha256="c"*64,continued_authoring=True)
            self.records.append({"label":label,"status":"passed","exit_code":0,"sampled_peak_rss_bytes":1024,
                                 "os_peak_rss_bytes":2048,"completion":receipt,"pid":pid,
                                 "engine_executable":self.executable,"engine_executable_sha256":self.engine_sha,
                                 "measurement_target":"godot-engine-process","command":[self.executable]})
            self.log(label,"FLATTEN_OWNER_FAILURE_RESULT "+json.dumps(receipt)+"\n")

    def storage_fixture(self, platform="linux"):
        directory = self.directory / "storage-faults"
        directory.mkdir(exist_ok=True)
        report = {"schema": "gen008-flatten-storage-faults-v1", "platform": platform,
                  "status": "passed", "completed": True, "cases": []}
        cases = ("locked-target","locked-source") if platform=="windows" else ("partial-write","process-termination")
        for kind in cases:
            prior, replacement = "1"*64, "2"*64
            retained = {}
            if kind == "locked-source":
                snapshots = directory / "locked-source-bytes"
                snapshots.mkdir(exist_ok=True)
                for name, content in (("target-before.bin",b"o"), ("target-after-refusal.bin",b"o"),
                                      ("source-before.bin",b"n"), ("source-after-refusal.bin",b"n"),
                                      ("target-after-retry.bin",b"n")):
                    (snapshots/name).write_bytes(content*525312)
                    retained["locked-source-bytes/"+name] = subject.engine.runner.sha256(snapshots/name)
                prior=retained["locked-source-bytes/target-before.bin"]
                replacement=retained["locked-source-bytes/source-before.bin"]
            row = {"kind": kind, "prior_sha256": prior, "after_sha256": prior, "retry_ok": True,
                   "retry_sha256": replacement, "attempted_plane_bytes": 524288,
                   "exit_code": -25 if kind == "process-termination" else 0,
                   "explicit_refusal": kind != "process-termination",
                   "partial_temporary_bytes": [65536] if kind == "process-termination" else [],
                   "operation": "production-native-replacement" if kind=="locked-source" else "production-baseline-writer"}
            if platform == "linux": row["file_size_limit_bytes"] = 65536
            if kind == "process-termination": row["signal"] = 25
            if kind == "locked-source":
                probes={"schema":"gen008-windows-source-lock-probes-v1","pid":123,
                        "held_source_desired_access":0x80000000,"held_source_share_mode":3}
                for name,path,opened,error in (("source","C:/fixture/setup-old.json.0123456789abcdef.tmp",False,32),
                                               ("target","C:/fixture/setup-old.json",True,0)):
                    probes[name]={"path":path,"desired_access":0x10000,"share_mode":7,"creation_disposition":3,
                                  "flags_and_attributes":0x80,"opened":opened,"win32_error":error}
                (directory/"locked-source-probes.json").write_text(json.dumps(probes),encoding="utf-8")
                row.update(source_sha256_before=replacement,source_sha256_after=replacement,source_size_bytes=525312,
                           target_unlocked=True,locked_source_desired_access=0x80000000,locked_source_share_mode=3,
                           delete_access_probes=probes,
                           retry_used_same_source=True,source_exists_after_retry=False,retained_files_sha256=retained)
            report["cases"].append(row)
            for phase in ("prepare", "recover", "refusal"):
                receipt = {"checks": 3, "failures": [], "phase": phase,
                           "error": "injected storage fault" if phase == "refusal" else "",
                           "prior_sha256": prior, "after_sha256": replacement if phase == "recover" else prior}
                if kind == "locked-source":
                    receipt.update(path="C:/fixture/setup-old.json",source_path="C:/fixture/setup-old.json.0123456789abcdef.tmp",
                                   operation=row["operation"],native_api="CyberDemoBridge.replace_material_baseline_file",
                                   source_sha256_before="" if phase=="prepare" else replacement,
                                   source_sha256_after="" if phase=="recover" else replacement,
                                   source_exists_after=phase!="recover",retry_used_same_source=phase=="recover")
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
        return subject.verify_flatten_cases(self.directory, "linux", self.native, subject.engine.ROOT / "godot",self.engine_sha)

    def test_complete_registered_receipt_fixture_is_admitted(self):
        self.assertEqual(len(self.verify()), 12)

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

    def test_windows_source_lock_requires_original_bytes_and_same_source_retry(self):
        self.storage_fixture("windows")
        self.assertEqual(subject.verify_storage_faults(self.directory,"windows")["status"],"passed")
        for mutation in ("missing-source-case","source-changed","target-locked","delete-sharing","metadata-access",
                         "different-retry","source-not-consumed","different-path","log-source-changed","retained-bytes",
                         "probe-missing","probe-source-open","probe-source-error","probe-target-denied","probe-mutating","probe-original"):
            with self.subTest(mutation=mutation):
                self.storage_fixture("windows")
                report=json.loads((self.directory/"storage-faults.json").read_text())
                row=report["cases"][1]
                if mutation=="missing-source-case": report["cases"].pop()
                if mutation=="source-changed": row["source_sha256_after"]="3"*64
                if mutation=="target-locked": row["target_unlocked"]=False
                if mutation=="delete-sharing": row["locked_source_share_mode"]=7
                if mutation=="metadata-access": row["locked_source_desired_access"]=0
                if mutation=="different-retry": row["retry_used_same_source"]=False
                if mutation=="source-not-consumed": row["source_exists_after_retry"]=True
                if mutation in ("different-path","log-source-changed"):
                    log=self.directory/"storage-faults/locked-source-recover.log"
                    receipt=json.loads(log.read_text().split("FLATTEN_STORAGE_RESULT ")[1])
                    receipt["source_path" if mutation=="different-path" else "source_sha256_before"] = (
                        "C:/fixture/different.tmp" if mutation=="different-path" else "3"*64)
                    log.write_text("FLATTEN_STORAGE_RESULT "+json.dumps(receipt)+"\n")
                if mutation=="retained-bytes":
                    (self.directory/"storage-faults/locked-source-bytes/target-after-refusal.bin").write_bytes(b"lost old save")
                if mutation.startswith("probe-"):
                    probes=row["delete_access_probes"]
                    if mutation=="probe-missing": probes.pop("source")
                    if mutation=="probe-source-open": probes["source"]["opened"]=True
                    if mutation=="probe-source-error": probes["source"]["win32_error"]=5
                    if mutation=="probe-target-denied": probes["target"]["opened"]=False
                    if mutation=="probe-mutating": probes["source"]["flags_and_attributes"]=0x04000000
                    original=copy.deepcopy(probes)
                    if mutation=="probe-original": original["source"]["win32_error"]=0
                    (self.directory/"storage-faults/locked-source-probes.json").write_text(json.dumps(original),encoding="utf-8")
                self.write("storage-faults.json",report)
                with self.assertRaises(RuntimeError): subject.verify_storage_faults(self.directory,"windows")

    def test_windows_memory_must_measure_engine_and_match_native_process_pid(self):
        self.storage_fixture("windows")
        executable="C:/fixture/Godot_v4.7-stable_win64.exe"
        for record in self.records:
            record.update(engine_executable=executable,command=[executable])
            if "completion" in record:
                record["completion"]["source_identity"].update(os="Windows",display="Windows")
        original=copy.deepcopy(self.records)
        for mutation in ("none","wrapper","engine-bytes","measurement-target","missing-pid","native-pid","owner-pid"):
            with self.subTest(mutation=mutation):
                self.records=copy.deepcopy(original)
                record=self.records[2]
                if mutation=="wrapper":
                    record.update(engine_executable=executable.replace(".exe","_console.exe"),
                                  command=[executable.replace(".exe","_console.exe")])
                if mutation=="engine-bytes": record["engine_executable_sha256"]="f"*64
                if mutation=="measurement-target": record["measurement_target"]="console-wrapper"
                if mutation=="missing-pid": record.pop("pid")
                if mutation=="native-pid": record["completion"]["pid"]+=1
                if mutation=="owner-pid": self.records[-1]["completion"]["pid"]+=1
                for record in self.records:
                    if "completion" in record:
                        marker="FLATTEN_OWNER_FAILURE_RESULT" if record["label"].startswith("owner-failure-") else "FLATTEN_RESULT"
                        self.log(record["label"],marker+" "+json.dumps(record["completion"])+"\n")
                self.save_records()
                if mutation=="none":
                    self.assertEqual(len(subject.verify_flatten_cases(self.directory,"windows",self.native,
                        subject.engine.ROOT/"godot",self.engine_sha)),12)
                else:
                    with self.assertRaises(RuntimeError): subject.verify_flatten_cases(self.directory,"windows",self.native,
                        subject.engine.ROOT/"godot",self.engine_sha)

    def test_native_owner_recovery_cannot_be_missing_fake_or_reopen_different_data(self):
        original_records=copy.deepcopy(self.records)
        for mutation in ("missing","wrong-fixture","wrong-source","plane","pre-fault-plane","fake-failure",
                         "wrong-capacity","different-capacity","owner-changed","same-process","same-pid","no-editing",
                         "weakened-fence","unconfirmed-recipe","missing-body","zero-body","epoch-zero","history-lost","saved-plane"):
            with self.subTest(mutation=mutation):
                self.records=copy.deepcopy(original_records)
                author,reopen=self.records[-2]["completion"],self.records[-1]["completion"]
                if mutation=="missing": self.records.pop()
                if mutation=="wrong-fixture": author["source_identity"][subject.OWNER_FAILURE_SCRIPT]="f"*64
                if mutation=="wrong-source": reopen["source_identity"][subject.SOURCE_PATHS[0]]="f"*64
                if mutation=="plane": reopen["reconstructed_plane_sha256"]="e"*64
                if mutation=="pre-fault-plane": author["pre_fault_native_plane_sha256"]="e"*64
                if mutation=="fake-failure": author["failure_snapshot"]={"simulation_failed":True}
                if mutation=="wrong-capacity": author["failure_reason"]="synthetic worker flag"
                if mutation=="different-capacity":
                    author["failure_reason"]=reopen["failure_reason"]="pressure component capacity exhausted"
                    author["failure_snapshot"]["last_tick_error"]=author["failure_reason"]
                    for key in ("owner_before_save","owner_after_save"):
                        author[key]["failure_snapshot"]["last_tick_error"]=author["failure_reason"]
                if mutation=="owner-changed": author["owner_after_save"]["generation"]+=1
                if mutation=="same-process": reopen["process_instance"]=author["process_instance"]
                if mutation=="same-pid": reopen["pid"]=author["pid"]
                if mutation=="no-editing": reopen["continued_authoring"]=False
                if mutation=="weakened-fence": author["fence_checks"]["native_capture_lease"]=False
                if mutation=="unconfirmed-recipe": author["fence_checks"]["unconfirmed_legacy_recipe"]=False
                if mutation in ("missing-body","zero-body","epoch-zero","history-lost"):
                    for key in ("owner_before_save","owner_after_save"):
                        if mutation=="missing-body": author[key]["physical"]["bodies"]=[]
                        if mutation=="zero-body": author[key]["physical"]["bodies"]=[[400,0]]
                        if mutation=="epoch-zero": author[key]["paint_epoch"]=0
                        if mutation=="history-lost": author[key]["undo_entries"]=0
                if mutation=="saved-plane": author["saved_plane_sha256"]="e"*64
                for record in self.records:
                    if record["label"].startswith("owner-failure-"):
                        self.log(record["label"],"FLATTEN_OWNER_FAILURE_RESULT "+json.dumps(record["completion"])+"\n")
                self.save_records()
                with self.assertRaises(RuntimeError): self.verify()


if __name__ == "__main__":
    unittest.main()
