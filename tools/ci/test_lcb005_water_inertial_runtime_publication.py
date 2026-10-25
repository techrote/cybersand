#!/usr/bin/env python3
"""Unarmed Water-IN profile guards; original005/001 profiles remain independent."""
import argparse
import copy
from importlib.util import module_from_spec, spec_from_file_location
import sys
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import lcb001_shared_contract_runtime_publication as historical
import lcb005_inertial_runtime_publication as brine
import lcb005_water_inertial_runtime_publication as profile
from test_lcb001_shared_contract_runtime_publication import SUCCESS_LOGS

subject = profile.engine
BRANCH = "codex/lcb005-water-inertial"
WORKFLOW = ".github/workflows/lcb005-water-inertial-runtime-publication.yml"
ADDED = {
    "test_lcb_pressure_optimization": (
        "LCB_PRESSURE_OPTIMIZATION",
        {"native_variants": True, "readback_encoding": True, "exact_parity": True,
         "gas_invalidation": True, "cold_restore": True, "default_preservation": True}),
    "test_lcb_inertial_adapter": (
        "LCB_INERTIAL_ADAPTER",
        {"oracle_parameters": True, "instance_readback": True, "radius_transaction": True,
         "mixed_workers": True, "cyps_continuation": True, "default_preservation": True}),
}


def summary(name, sections):
    return ADDED[name][0] + ": 100 assertions; 0 failures; completed=" + json.dumps(sections) + "\n"


def water_proof():
    proof = {"schema":profile.SCHEMA, "assertions":385, "failures":0,
             "cohorts":[], "restores":[], "coherence":[],
             "refusals":{"rows":[{"code":"normalization_required", "material":3, "unchanged_session":True} for _ in range(3)],
                         "tick_before":0, "tick_after":1}}
    for bits in (3, 8):
        physical = f"{100 + bits:016x}"
        for workers in (1, 4):
            proof["cohorts"].append({"mass_bits":bits, "workers":workers, "family":"inertial_cellular_v1",
                "policy_hash":"a" * 64, "radius":3, "hash_version":3, "tick1_motion":True,
                "initial_content_hash":"0000000000000001", "final_content_hash":"0000000000000002", "physical_hash":physical, "completed_ticks":20,
                "censuses":[{"tick":tick, "count":144, "full":True, "quantity":144*((1<<bits)-1)} for tick in (0,10,20)]})
            proof["coherence"].append({"mass_bits":bits, "workers":workers, "initial":7,
                "observed":list(range(6,-1,-1)), "completed_ticks":7, "vertical_before_expiry":True,
                "retained_motion":True, "count":1, "full":True, "quantity":(1<<bits)-1})
        proof["restores"].append({"mass_bits":bits, "source_workers":1, "format_version":3,
            "saved_bytes":512, "source_hash":physical, "restored_hash":physical,
            "continuation":[{"tick":tick, "source_hash":f"{200+tick+bits:016x}", "restored_hash":f"{200+tick+bits:016x}"} for tick in range(21,26)]})
    return proof


def water_line(proof=None):
    return "WATER_INERTIAL_POLICY_PROOF: " + json.dumps(water_proof() if proof is None else proof) + "\n"


class ProfileTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.git("init", "--quiet")
        self.git("config", "user.name", "LCB union publisher fixture")
        self.git("config", "user.email", "lcb-fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        for relative in (subject.REQUEST, subject.EVIDENCE, *(
                "godot/tests/" + name + ".gd" for name in subject.CASE_MARKERS)):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(dict(subject.REQUEST_VALUE, request_sequence=1))
                            if relative == subject.REQUEST else "fixture\n", encoding="utf-8")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Fixture")
        self.source = self.git("rev-parse", "HEAD").strip()
        patch = mock.patch.object(subject, "ROOT", self.root)
        patch.start(); self.addCleanup(patch.stop)
        patch = mock.patch.dict(os.environ, {
            "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + BRANCH,
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/" + WORKFLOW + "@refs/heads/" + BRANCH,
            "GITHUB_SHA": self.source, "GITHUB_RUN_ID": "123456", "GITHUB_RUN_ATTEMPT": "1",
        })
        patch.start(); self.addCleanup(patch.stop)
        self.report = {"results": [], "log_sha256": {}}
        logs = {"import": "import complete\n", **SUCCESS_LOGS,
                **{name: summary(name, sections) for name, (_, sections) in ADDED.items()}}
        logs["test_liquid_solver_policy"] += water_line()
        for name, output in logs.items():
            self.log(name, output)
            self.report["results"].append({"name": name, "status": "passed", "returncode": 0,
                "diagnostic_error": False, "launch_error": None, "skip_messages": []})

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True,
                                       stderr=subprocess.PIPE)

    def log(self, name, output):
        path = self.root / (name + ".log")
        path.write_bytes(output.encode())
        self.report["log_sha256"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()

    def test_profile_is_isolated_and_binds_its_own_artifact_prefix(self):
        self.assertEqual(historical.BRANCH, "codex/lcb001-shared-contract")
        self.assertEqual(historical.BUNDLE_PREFIX, "lcb001-shared-contract-runtime")
        self.assertEqual(set(historical.CASE_MARKERS), set(SUCCESS_LOGS))
        self.assertEqual(subject.BUNDLE_PREFIX, "lcb005-water-inertial-runtime")
        self.assertEqual(subject.WORKFLOW, WORKFLOW)
        self.assertEqual(subject.BRANCH, BRANCH)

    def test_exact_source_context_and_request(self):
        self.assertEqual(subject.context(self.source)["source_commit"], self.source)
        subject.require_publication_request(self.source)

    def test_other_repository_branch_event_workflow_source_or_attempt_refuse(self):
        for key, value in {
            "GITHUB_REPOSITORY": "other/cybersand", "GITHUB_REF": "refs/heads/codex/lcb002-pressure-variants",
            "GITHUB_EVENT_NAME": "pull_request", "GITHUB_SHA": "f" * 40, "GITHUB_RUN_ATTEMPT": "0",
            "GITHUB_WORKFLOW_REF": "techrote/cybersand/.github/workflows/lcb001-shared-contract-runtime-publication.yml@refs/heads/" + BRANCH,
        }.items():
            with self.subTest(key=key), mock.patch.dict(os.environ, {key: value}):
                with self.assertRaises(RuntimeError): subject.context(self.source)

    def test_unarmed_request_refuses_before_remote_or_build(self):
        (self.root / subject.REQUEST).unlink()
        with mock.patch.object(subject, "git", wraps=subject.git) as git:
            with self.assertRaisesRegex(RuntimeError, "Missing explicit"):
                subject.check_source(argparse.Namespace(source_sha=self.source))
            self.assertFalse(any(call.args[0] == "ls-remote" for call in git.call_args_list))

    def test_request_cannot_borrow_historical_or_partial_scope(self):
        for request in (dict(historical.REQUEST_VALUE, request_sequence=1),
                        dict(brine.engine.REQUEST_VALUE, request_sequence=3),
                        dict(subject.REQUEST_VALUE, scope="inertial-only", request_sequence=1),
                        dict(subject.REQUEST_VALUE, request_sequence=True),
                        dict(subject.REQUEST_VALUE, request_sequence=0),
                        dict(subject.REQUEST_VALUE, request_sequence=1, extra=True)):
            path = self.root / subject.REQUEST; path.write_text(json.dumps(request), encoding="utf-8")
            self.git("add", "."); self.git("commit", "--quiet", "--allow-empty", "-m", "Wrong request")
            with self.assertRaisesRegex(RuntimeError, "Invalid shared-contract publish request"):
                subject.require_publication_request(self.git("rev-parse", "HEAD").strip())

    def test_in_only_and_pressure_only_sources_cannot_arm(self):
        for name in ADDED:
            path = self.root / "godot/tests" / (name + ".gd")
            path.unlink()
            with self.assertRaisesRegex(RuntimeError, "regression is not implemented"):
                subject.require_publication_request(self.source)
            path.write_text("fixture\n", encoding="utf-8")

    def test_all_fourteen_cases_and_twelve_new_sections_pass(self):
        self.assertEqual(profile.OPTIMIZATION_SECTIONS, ADDED["test_lcb_pressure_optimization"][1])
        self.assertEqual(profile.INERTIAL_SECTIONS, ADDED["test_lcb_inertial_adapter"][1])
        self.assertEqual(list(subject.CASE_MARKERS), [*SUCCESS_LOGS, *ADDED])
        subject.verify_case_results(self.root, self.report)

    def test_each_missing_case_log_or_changed_digest_refuses(self):
        for name in ADDED:
            original = self.report["results"]
            self.report["results"] = [row for row in original if row["name"] != name]
            with self.assertRaisesRegex(RuntimeError, "Incomplete focused case coverage"):
                subject.verify_case_results(self.root, self.report)
            self.report["results"] = original
            (self.root / (name + ".log")).write_text("changed\n", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "Execution log digest mismatch"):
                subject.verify_case_results(self.root, self.report)
            self.log(name, summary(name, ADDED[name][1]))

    def test_each_section_requires_actual_boolean_true_and_exact_keys(self):
        for name, (_, expected) in ADDED.items():
            variants = [{key: value for key, value in expected.items() if key != omitted} for omitted in expected]
            variants += [dict(expected, **{key: value}) for key in expected for value in (False, 1, "true")]
            variants += [[], "done", dict(expected, extra=True)]
            for sections in variants:
                with self.subTest(name=name, sections=sections):
                    self.log(name, summary(name, sections))
                    with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)
            self.log(name, summary(name, expected))

    def test_zero_failed_duplicate_malformed_skip_and_error_summaries_refuse(self):
        for name, (_, sections) in ADDED.items():
            original = summary(name, sections)
            for output in (original.replace("100 assertions", "0 assertions"),
                           original.replace("0 failures", "1 failures"), original + original,
                           original.replace(json.dumps(sections), "{broken}"),
                           original + "SKIP missing native arm\n", original + "ERROR: native fault\n"):
                with self.subTest(name=name, output=output):
                    self.log(name, output)
                    with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)
            self.log(name, original)

    def test_new_cases_preserve_flags_and_every_existing_deadline(self):
        discovered = {name: subject.runner.Case(name, ("--script", "res://tests/" + name + ".gd"), 180, 5.0)
                      for name in subject.CASE_MARKERS}
        cases = subject.focused_cases(discovered)
        self.assertEqual([case.name for case in cases], ["import", *subject.CASE_MARKERS])
        for case in cases[1:]:
            self.assertEqual(case.flags, discovered[case.name].flags)
            self.assertEqual(case.timeout, 360 if case.name in ADDED else historical.CASE_TIMEOUTS.get(case.name, 180))
        self.assertEqual(cases[0].timeout, 240)
        del discovered["test_lcb_pressure_optimization"]
        with self.assertRaisesRegex(RuntimeError, "Required focused regression is missing"):
            subject.focused_cases(discovered)

    def test_required_profile_and_oracle_inputs_are_bound(self):
        for path in (WORKFLOW, subject.REQUEST, "tools/ci/lcb005_water_inertial_runtime_publication.py",
                     "tools/ci/test_lcb005_water_inertial_runtime_publication.py",
                     "godot/tests/fixtures/lcb/inertial-adapter-parameters.json"):
            self.assertIn(path, subject.BUILD_EXACT)


class WorkflowTests(unittest.TestCase):
    def test_workflow_has_an_unarmed_path_and_only_branch_bound_execution(self):
        text = (historical.ROOT / WORKFLOW).read_text(encoding="utf-8")
        self.assertIn("branches: [" + BRANCH + "]", text)
        self.assertIn("echo 'armed=false'", text)
        self.assertNotIn("workflow_dispatch:", text)
        self.assertIn("needs.admission.outputs.armed == 'true'", text)
        self.assertIn("runs-on: windows-2022", text)
        self.assertIn("runs-on: ubuntu-24.04", text)
        self.assertIn("timeout-minutes: 55", text)
        self.assertIn("timeout-minutes: 25", text)

    def test_workflow_preserves_exact_parent_four_paths_and_atomic_branch_lease(self):
        text = (historical.ROOT / WORKFLOW).read_text(encoding="utf-8")
        self.assertEqual(text.count("contents: write"), 1)
        self.assertIn('test "$(git rev-list --parents -n 1 HEAD)" = "$(git rev-parse HEAD) $GITHUB_SHA"', text)
        self.assertIn('git push --force-with-lease="refs/heads/' + BRANCH + ':$GITHUB_SHA" origin HEAD:refs/heads/' + BRANCH, text)
        self.assertIn('check-index --source-sha "$GITHUB_SHA"', text)
        allowed = [*subject.RUNTIMES.values(), *subject.MANIFESTS.values()]
        self.assertIn("git add -- " + " ".join(allowed), text)
        self.assertIn("test_lcb001_shared_contract_runtime_publication.py", text)
        self.assertIn("test_lcb005_inertial_runtime_publication.py", text)

    def test_retained_job_deadlines_pins_process_commands_and_branch_lease(self):
        import re
        text=(historical.ROOT/WORKFLOW).read_text(encoding="utf-8")
        old=(historical.ROOT/brine.engine.WORKFLOW).read_text(encoding="utf-8")
        for expression in (r"timeout-minutes: [0-9]+",r"uses: [^\n]+",r"runs-on: [^\n]+",r"timeout [0-9]+m [^\n]+"):
            self.assertEqual(re.findall(expression,text),re.findall(expression,old))
        self.assertEqual(len(re.findall(r"^  [a-z][a-z-]*:$",text.split("\njobs:\n",1)[1],re.M)),6)
        self.assertNotIn("tools/ci/lcb005_inertial_publish_request.json",text)
        for command in ("check-source","record","test","stage","check-index"):
            for line in text.splitlines():
                if "_runtime_publication.py "+command in line:
                    self.assertIn("lcb005_water_inertial_runtime_publication.py "+command,line)
        self.assertIn("github.base_ref == 'codex/lcb005-inertial'",text)
        self.assertIn("group: lcb005-water-inertial-runtime-publication-",text)


class WaterProofTests(ProfileTests):
    # Avoid inheriting/re-running all repository guard methods; use its isolated
    # setup/helpers only, and explicitly load just this class's proof methods.
    def _reject(self, proof):
        self.log("test_liquid_solver_policy", SUCCESS_LOGS["test_liquid_solver_policy"] + water_line(proof))
        with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_water_proof_is_required_and_cannot_borrow_old_policy_summary(self):
        self.log("test_liquid_solver_policy", SUCCESS_LOGS["test_liquid_solver_policy"])
        with self.assertRaisesRegex(RuntimeError, "Water IN proof"):
            subject.verify_case_results(self.root, self.report)
        for body in (water_line()+water_line(), "WATER_INERTIAL_POLICY_PROOF: {broken}\n",
                     water_line().replace('"schema":', '"schema":"duplicate", "schema":', 1)):
            self.log("test_liquid_solver_policy", SUCCESS_LOGS["test_liquid_solver_policy"]+body)
            with self.assertRaises(RuntimeError): subject.verify_case_results(self.root, self.report)

    def test_every_proof_object_field_is_required(self):
        original = water_proof()
        paths = [()] + [(name,index) for name in ("cohorts","restores","coherence") for index in range(len(original[name]))]
        paths += [("refusals",)] + [("refusals","rows",index) for index in range(3)]
        paths += [("cohorts",index,"censuses",census) for index in range(4) for census in range(3)]
        paths += [("restores",index,"continuation",tick) for index in range(2) for tick in range(5)]
        for path in paths:
            value = original
            for key in path:value=value[key]
            for removed in value:
                proof=copy.deepcopy(original);target=proof
                for key in path:target=target[key]
                del target[removed]
                with self.subTest(path=path, removed=removed):self._reject(proof)

    def test_boolean_integer_scope_motion_and_quantity_cannot_be_noops(self):
        original=water_proof()
        changes=[(("assertions",),0),(("assertions",),True),(("assertions",),386),(("failures",),True),
                 (("failures",),1),(("schema",),"brine-only"),(("extra",),True)]
        for index in range(4):
            changes += [(("cohorts",index,key),value) for key,value in (
                ("mass_bits",True),("workers",True),("family","freemass_v1"),("radius",2),("hash_version",2),
                ("tick1_motion",False),("tick1_motion",1),("completed_ticks",0),("policy_hash","0"),
                ("initial_content_hash","not-a-hash"),("physical_hash",str(2**64)))]
            changes += [(("cohorts",index,"censuses",j,key),value) for j in range(3) for key,value in
                        (("count",143),("quantity",0),("full",1),("tick",True))]
            changes += [(("coherence",index,key),value) for key,value in (
                ("observed",[6,5,4,3,2,1,False]),("retained_motion",1),("vertical_before_expiry",False),
                ("completed_ticks",6),("full",False),("quantity",0))]
        for index in range(2):
            changes += [(("restores",index,key),value) for key,value in (
                ("source_workers",4),("format_version",2),("saved_bytes",True),("restored_hash","999"))]
            changes += [(("restores",index,"continuation",j,"restored_hash"),"999") for j in range(5)]
        changes += [(("refusals","rows",i,key),value) for i in range(3) for key,value in
                    (("code","accepted"),("material",True),("unchanged_session",1))]
        changes += [(("refusals","tick_after"),0)]
        for path,value in changes:
            proof=copy.deepcopy(original);target=proof
            for key in path[:-1]:target=target[key]
            target[path[-1]]=value
            with self.subTest(path=path,value=value):self._reject(proof)

    def test_each_matrix_must_be_complete_unique_and_have_real_parity(self):
        for name in ("cohorts","restores","coherence"):
            for mutation in (lambda rows:rows[:-1],lambda rows:rows+[rows[0]],lambda rows:[rows[0]]*len(rows)):
                proof=water_proof();proof[name]=mutation(proof[name]);self._reject(proof)
        for bits in (3,8):
            proof=water_proof();row=next(row for row in proof["cohorts"] if row["mass_bits"]==bits and row["workers"]==4)
            row["physical_hash"]="999";self._reject(proof)
        for path in (("cohorts",0,"censuses"),("restores",0,"continuation")):
            proof=water_proof();target=proof
            for key in path[:-1]:target=target[key]
            target[path[-1]]=target[path[-1]][:-1];self._reject(proof)

    def test_old_request_presence_cannot_arm_the_absent_water_request(self):
        (self.root/subject.REQUEST).unlink()
        path=self.root/brine.engine.REQUEST;path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(dict(brine.engine.REQUEST_VALUE,request_sequence=3)))
        with mock.patch.object(subject,"git",wraps=subject.git) as git:
            with self.assertRaisesRegex(RuntimeError,"Missing explicit"):subject.check_source(argparse.Namespace(source_sha=self.source))
            self.assertFalse(any(call.args[0]=="ls-remote" for call in git.call_args_list))

    def test_changed_remote_lease_refuses_without_changing_the_local_source(self):
        remote_directory=tempfile.TemporaryDirectory(prefix="water-publish-remote-")
        self.addCleanup(remote_directory.cleanup)
        remote=Path(remote_directory.name)/"remote.git"
        subprocess.run(["git","clone","--quiet","--bare",str(self.root),str(remote)],check=True,capture_output=True)
        remote_git=["git","--git-dir",str(remote)]
        subprocess.run([*remote_git,"update-ref","refs/heads/"+BRANCH,self.source],check=True)
        self.git("remote","add","origin",str(remote));subject.check_source(argparse.Namespace(source_sha=self.source))
        changed=subprocess.check_output([*remote_git,"-c","user.name=Water fixture","-c","user.email=fixture@example.invalid",
            "commit-tree",self.source+"^{tree}","-p",self.source],input=b"Concurrent change\n").decode().strip()
        subprocess.run([*remote_git,"update-ref","refs/heads/"+BRANCH,changed],check=True)
        with self.assertRaisesRegex(RuntimeError,"Feature branch changed"):subject.check_source(argparse.Namespace(source_sha=self.source))
        self.assertEqual(self.git("rev-parse","HEAD").strip(),self.source)

    def test_own_bundle_prefix_and_scope_are_mandatory(self):
        expected=subject.BUNDLE_PREFIX+"-windows-123456/validation.json"
        (self.root/"validation.json").write_text(json.dumps({"scope":subject.EXECUTION_SCOPE}))
        with mock.patch.object(profile,"_verify_union_bundle",return_value={"validation_output":expected}):
            self.assertEqual(subject.verify_bundle(self.root,"windows",self.source,True)["validation_output"],expected)
        for value in (brine.engine.BUNDLE_PREFIX+"-windows-123456/validation.json",expected.replace("123456","999")):
            with mock.patch.object(profile,"_verify_union_bundle",return_value={"validation_output":value}):
                with self.assertRaisesRegex(RuntimeError,"prefix differs"):subject.verify_bundle(self.root,"windows",self.source,True)
        (self.root/"validation.json").write_text(json.dumps({"scope":brine.engine.EXECUTION_SCOPE}))
        with mock.patch.object(profile,"_verify_union_bundle",return_value={"validation_output":expected}):
            with self.assertRaisesRegex(RuntimeError,"scope differs"):subject.verify_bundle(self.root,"windows",self.source,True)


class IsolationTests(unittest.TestCase):
    def test_original_profiles_and_shared_runner_are_not_mutated(self):
        self.assertIsNot(subject,brine.engine)
        self.assertIsNot(subject, historical)
        self.assertIs(subject.context.__globals__,subject.__dict__)
        self.assertIs(brine.engine.context.__globals__,brine.engine.__dict__)
        self.assertEqual(brine.engine.BRANCH,"codex/lcb005-inertial")
        self.assertEqual(brine.engine.BUNDLE_PREFIX,"lcb005-inertial-runtime")
        self.assertEqual(historical.BRANCH,"codex/lcb001-shared-contract")
        self.assertIs(subject.runner,brine.engine.runner)
        before=(subject.runner.ROOT,brine.engine.runner.ROOT,subject.windows.ROOT)
        for name,key,value in (("CASE_MARKERS","sentinel","unused"),("CASE_TIMEOUTS","sentinel",1),
                               ("LIQUID_POLICY_SECTIONS","validation",False),("REQUEST_VALUE","scope","unused")):
            own=getattr(subject,name);old=getattr(brine.engine,name).copy();saved=own.get(key,None)
            try:own[key]=value;self.assertEqual(getattr(brine.engine,name),old)
            finally:
                if saved is None:own.pop(key)
                else:own[key]=saved
        self.assertEqual(before,(subject.runner.ROOT,brine.engine.runner.ROOT,subject.windows.ROOT))

    def test_both_import_orders_keep_profile_function_globals_and_identity(self):
        for order in (("lcb005_inertial_runtime_publication","lcb005_water_inertial_runtime_publication"),
                      ("lcb005_water_inertial_runtime_publication","lcb005_inertial_runtime_publication")):
            code="import importlib;modules=[importlib.import_module(n) for n in "+repr(order)+"];old=importlib.import_module('lcb005_inertial_runtime_publication').engine;new=importlib.import_module('lcb005_water_inertial_runtime_publication').engine;assert old is not new;assert old.BRANCH=='codex/lcb005-inertial';assert new.BRANCH=='codex/lcb005-water-inertial';assert old.context.__globals__ is old.__dict__;assert new.context.__globals__ is new.__dict__;assert old.CASE_MARKERS is not new.CASE_MARKERS;assert old.BUILD_EXACT is not new.BUILD_EXACT"
            result=subprocess.run([sys.executable,"-c",code],cwd=Path(__file__).parent,capture_output=True,text=True,timeout=30)
            self.assertEqual(result.returncode,0,result.stderr)


    def test_original_brine_positive_and_adversarial_reports_still_work(self):
        with tempfile.TemporaryDirectory() as name:
            directory=Path(name);report={"results":[],"log_sha256":{}}
            for case,output in {"import":"clean import\n",**SUCCESS_LOGS,
                    **{key:summary(key,sections) for key,(_,sections) in ADDED.items()}}.items():
                path=directory/(case+".log");path.write_bytes(output.encode())
                report["results"].append({"name":case,"status":"passed","returncode":0,
                    "diagnostic_error":False,"launch_error":None,"skip_messages":[]})
                report["log_sha256"][path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            brine.engine.verify_case_results(directory,report)
            shortened=copy.deepcopy(report);shortened["results"].pop()
            with self.assertRaises(RuntimeError):brine.engine.verify_case_results(directory,shortened)
            path=directory/"test_liquid_solver_policy.log"
            path.write_text(SUCCESS_LOGS["test_liquid_solver_policy"].replace('"validation":true','"validation":false'))
            report["log_sha256"][path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            with self.assertRaises(RuntimeError):brine.engine.verify_case_results(directory,report)

    def test_new_build_input_set_and_union_closure_are_private(self):
        self.assertIs(profile._verify_union.__globals__["engine"],subject)
        self.assertIs(brine.verify_case_results.__globals__["engine"],brine.engine)
        before=set(brine.engine.BUILD_EXACT)
        subject.BUILD_EXACT.add("water-only-sentinel")
        try:self.assertEqual(brine.engine.BUILD_EXACT,before)
        finally:subject.BUILD_EXACT.remove("water-only-sentinel")

    def test_original_shared_input_and_four_path_guards_run_on_the_new_engine(self):
        spec=spec_from_file_location("_water_shared_guard_fixture",Path(__file__).with_name("test_lcb001_shared_contract_runtime_publication.py"))
        fixture=module_from_spec(spec);spec.loader.exec_module(fixture)
        fixture.subject=subject;fixture.BRANCH=BRANCH
        fixture.WORKFLOW="techrote/cybersand/"+WORKFLOW+"@refs/heads/"+BRANCH
        fixture.SUCCESS_LOGS={**SUCCESS_LOGS,**{name:summary(name,sections) for name,(_,sections) in ADDED.items()}}
        original=fixture.InputLedgerTests.test_grammar_sources_examples_and_fixture_are_source_bound
        def also_bind_water_inputs(case):
            original(case)
            source=case.git("rev-parse","HEAD").decode().strip()
            for relative in (subject.WORKFLOW,subject.REQUEST,subject.EVIDENCE,
                    "tools/ci/lcb005_water_inertial_runtime_publication.py",
                    "tools/ci/test_lcb005_water_inertial_runtime_publication.py"):
                path=case.root/relative;data=path.read_bytes();path.write_bytes(data+b"changed\n")
                try:
                    with case.assertRaisesRegex(RuntimeError,"Working build/test input differs from source commit"):
                        subject.input_ledgers(source)
                finally:path.write_bytes(data)
        fixture.InputLedgerTests.test_grammar_sources_examples_and_fixture_are_source_bound=also_bind_water_inputs
        suite=unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromTestCase(cls)
            for cls in (fixture.InputLedgerTests,fixture.PublicationIndexTests))
        result=unittest.TestResult();suite.run(result)
        self.assertEqual(result.testsRun,7)
        self.assertEqual(result.errors,[])
        self.assertEqual(result.failures,[])


def load_tests(loader, tests, pattern):
    suite=unittest.TestSuite()
    for cls in (ProfileTests,WorkflowTests,IsolationTests):suite.addTests(loader.loadTestsFromTestCase(cls))
    for name in WaterProofTests.__dict__:
        if name.startswith("test_"):suite.addTest(WaterProofTests(name))
    return suite


if __name__ == "__main__":
    unittest.main()
