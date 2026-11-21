#!/usr/bin/env python3
"""Permission and custody refusal controls; no real API calls or dispatches."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import dispatch_final_admission as control


def request():
    return {"schema": 1, "programme": control.PROGRAMME, "action": "dispatch-final-admission",
            "request_id": "reviewed-final-head-1", "expected_parent_sha": "1" * 40,
            "target_sha": "2" * 40, "qualification_source_sha": "3" * 40,
            "qualification_run_id": "123", "qualification_run_attempt": "1",
            "publication_request_sha": "4" * 40, "publication_run_id": "124", "publication_run_attempt": "1"}


def context():
    return {"repository": control.REPO, "branch": control.TARGET_BRANCH, "workflow": control.QUALIFIER,
            "run_id": "123", "run_attempt": "1", "workflow_run": "https://github.com/techrote/cybersand/actions/runs/123"}


def chain():
    return {"source": "3" * 40, "source_tree": "5" * 40, "published": "2" * 40,
            "publication_request": "4" * 40, "artifact_id": "200"}


def run(name="native.yml", run_id=500):
    return {"id": run_id, "workflow_id": 77 + control.WORKFLOWS.index(name), "run_attempt": 1,
            "head_sha": "2" * 40, "head_branch": control.TARGET_BRANCH, "event": "workflow_dispatch",
            "repository": {"full_name": control.REPO}, "head_repository": {"full_name": control.REPO},
            "status": "queued", "conclusion": None, "html_url": "https://github.com/techrote/cybersand/actions/runs/" + str(run_id)}


class RequestTests(unittest.TestCase):
    def test_strict_contract_refuses_extra_workflow_ref_repository_inputs(self):
        original = request()
        self.assertEqual(control.request_value(json.dumps(original).encode()), original)
        for key in ("workflow", "ref", "repository", "owner", "inputs", "ready"):
            value = {**original, key: "unreviewed"}
            with self.subTest(key=key), self.assertRaises(ValueError):
                control.request_value(json.dumps(value).encode())

    def test_duplicate_keys_false_schema_partial_sha_and_nondecimal_id_refused(self):
        with self.assertRaises(ValueError):
            control.request_value(b'{"schema":1,"schema":1}')
        for key, bad in (("schema", True), ("target_sha", "3" * 7), ("qualification_run_id", "../456"),
                         ("publication_run_attempt", "0"), ("request_id", "contains\nnewline")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                control.request_value(json.dumps({**request(), key: bad}).encode())

    def test_api_write_allowlist_refuses_arbitrary_endpoints_refs_and_inputs(self):
        cases = [(control.PREFIX + "/pulls/715", {"state": "closed"}),
                 (control.PREFIX + "/git/refs/heads/main", {"sha": "2" * 40}),
                 (control.PREFIX + "/actions/workflows/unreviewed.yml/dispatches", {"ref": control.TARGET_BRANCH}),
                 (control.PREFIX + "/actions/workflows/native.yml/dispatches", {"ref": "main"}),
                 (control.PREFIX + "/actions/workflows/gdextension.yml/dispatches",
                  {"ref": control.TARGET_BRANCH, "inputs": {"physical_actor_stress": "true"}})]
        with mock.patch.object(control.urllib.request, "urlopen") as network:
            for path, payload in cases:
                with self.subTest(path=path, payload=payload), self.assertRaises(ValueError):
                    control.api(path, payload)
            network.assert_not_called()


class ProvenanceTests(unittest.TestCase):
    def test_plan_refuses_retag_scope_and_owner_status(self):
        plan = {"schema": 1, "programme": control.PROGRAMME, "source_commit": "3" * 40,
                "source_tree": "5" * 40, "build_context": context(), "branch": control.TARGET_BRANCH,
                "permitted_tracked_paths": control.PATHS, "ready_or_merge_authorized": False,
                "owner_visual_acceptance": "pending", "files_sha256": {name: "a" * 64 for name in control.PATHS}}
        self.assertEqual(control.validate_plan(plan, request(), chain()), context())
        for key, bad in (("source_commit", "2" * 40), ("owner_visual_acceptance", "passed"),
                         ("ready_or_merge_authorized", True), ("permitted_tracked_paths", control.PATHS[:-1]),
                         ("files_sha256", {**plan["files_sha256"], "extra": "a" * 64})):
            with self.subTest(key=key), self.assertRaises(ValueError):
                control.validate_plan({**plan, key: bad}, request(), chain())

    def test_binding_retains_original_build_and_pending_owner(self):
        binding = {"schema": 1, "programme": control.PROGRAMME, "platform": "linux",
                   "artifact": control.CLIS["linux"], "source": "3" * 40, "source_commit": "3" * 40,
                   "build_commit": "3" * 40, "source_tree": "5" * 40, "build_context": context(),
                   "draft_hold": True, "owner_visual_acceptance": "pending"}
        control.validate_binding(binding, "linux", context(), chain())
        for key, bad in (("build_commit", "2" * 40), ("platform", "windows"), ("draft_hold", False),
                         ("owner_visual_acceptance", "passed"), ("build_context", {**context(), "run_attempt": "2"})):
            with self.subTest(key=key), self.assertRaises(ValueError):
                control.validate_binding({**binding, key: bad}, "linux", context(), chain())

    def test_live_lease_rejects_ready_pr_wrong_head_and_advanced_main(self):
        value = {**request(), "execution_sha": "6" * 40}
        refs = {control.TARGET_BRANCH: value["target_sha"], "main": control.ACCEPTED_MAIN,
                control.CONTROL_BRANCH: value["execution_sha"]}
        pr = {"number": 715, "state": "open", "draft": True, "merged": False,
              "base": {"ref": "main", "sha": control.ACCEPTED_MAIN, "repo": {"full_name": control.REPO}},
              "head": {"ref": control.TARGET_BRANCH, "sha": value["target_sha"], "repo": {"full_name": control.REPO}}}
        def fake(path):
            if path == "/pulls/715":
                return pr
            name = path.removeprefix("/git/ref/heads/")
            return {"ref": "refs/heads/" + name, "object": {"sha": refs[name]}}
        with mock.patch.object(control, "get", side_effect=fake):
            control.lease(value)
            pr["draft"] = False
            with self.assertRaises(ValueError):
                control.lease(value)
            pr["draft"] = True
            pr["head"]["sha"] = "7" * 40
            with self.assertRaises(ValueError):
                control.lease(value)
            pr["head"]["sha"] = value["target_sha"]
            refs["main"] = "8" * 40
            with self.assertRaises(ValueError):
                control.lease(value)

    def test_completed_run_refuses_old_attempt_failed_run_wrong_head_or_workflow(self):
        original = {"id": 123, "run_attempt": 1, "head_sha": "3" * 40, "head_branch": control.TARGET_BRANCH,
                    "status": "completed", "conclusion": "success", "event": "push", "workflow_id": 77,
                    "repository": {"full_name": control.REPO}, "head_repository": {"full_name": control.REPO},
                    "html_url": "https://github.com/techrote/cybersand/actions/runs/123"}
        for key, bad in ((None, None), ("run_attempt", 2), ("head_sha", "2" * 40),
                         ("conclusion", "failure"), ("event", "pull_request"), ("head_branch", "main")):
            row = copy.deepcopy(original)
            if key:
                row[key] = bad
            def fake(path):
                return row if path == "/actions/runs/123" else {"id": 77, "path": control.QUALIFIER}
            with mock.patch.object(control, "get", side_effect=fake):
                if key is None:
                    control.successful_run(request(), "qualification", control.QUALIFIER, "3" * 40)
                else:
                    with self.subTest(key=key), self.assertRaises(ValueError):
                        control.successful_run(request(), "qualification", control.QUALIFIER, "3" * 40)
        with mock.patch.object(control, "get", side_effect=[original, {"id": 77, "path": "wrong.yml"}]):
            with self.assertRaises(ValueError):
                control.successful_run(request(), "qualification", control.QUALIFIER, "3" * 40)

    def test_run_query_refuses_wrong_source_instead_of_accepting_branch_only(self):
        valid = run()
        with mock.patch.object(control, "get", return_value={"total_count": 1, "workflow_runs": [valid]}):
            self.assertEqual(len(control.runs("native.yml", request())), 1)
        with mock.patch.object(control, "get", return_value={"total_count": 1, "workflow_runs": [{**valid, "head_sha": "9" * 40}]}):
            with self.assertRaises(ValueError):
                control.runs("native.yml", request())


class DispatchTests(unittest.TestCase):
    def exercise(self, already_running=False, move_before_second=False, ambiguous=False):
        value = {**request(), "execution_sha": "6" * 40}
        posted = []
        lease_calls = []
        def fake_lease(_value):
            lease_calls.append(len(posted))
            if move_before_second and len(posted) == 1:
                raise ValueError("Remote branch lease changed")
            return {"draft": True}
        def fake_get(path):
            name = path.rsplit("/", 1)[-1]
            return {"id": 77 + control.WORKFLOWS.index(name), "path": ".github/workflows/" + name, "state": "active"}
        def fake_runs(name, _value):
            if already_running and name == "native.yml":
                return [run(name, 499)]
            if name in posted:
                return [run(name, 500 + control.WORKFLOWS.index(name))] + ([run(name, 600)] if ambiguous else [])
            return []
        def fake_api(path, payload):
            name = path.split("/")[-2]
            self.assertIn(name, control.WORKFLOWS)
            self.assertEqual(payload, {"ref": control.TARGET_BRANCH})
            posted.append(name)
            return 204, {}
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "receipt.json"
            with mock.patch.object(control, "current_request", return_value=value), \
                 mock.patch.object(control, "lease", side_effect=fake_lease), \
                 mock.patch.object(control, "source_chain", return_value=chain()), \
                 mock.patch.object(control, "successful_run", return_value={"conclusion": "success"}), \
                 mock.patch.object(control, "publication_bytes", return_value={"source_equivalent": True}), \
                 mock.patch.object(control, "get", side_effect=fake_get), \
                 mock.patch.object(control, "runs", side_effect=fake_runs), \
                 mock.patch.object(control, "api", side_effect=fake_api):
                if move_before_second or ambiguous:
                    with self.assertRaises(ValueError):
                        control.dispatch(output)
                else:
                    control.dispatch(output)
            result = json.loads(output.read_text())
        return posted, result, lease_calls

    def test_only_five_fixed_posts_exact_head_confirmation_never_claims_admission(self):
        posted, result, leases = self.exercise()
        self.assertEqual(posted, list(control.WORKFLOWS))
        self.assertTrue(result["complete"])
        self.assertEqual(len(result["dispatches"]), 5)
        self.assertTrue(all(item["http_status"] == 204 and item["run"]["head_sha"] == "2" * 40 for item in result["dispatches"]))
        self.assertTrue(result["admission_result"].startswith("pending"))
        self.assertFalse(result["ready_or_merge_authorized"])
        self.assertFalse(result["source_branch_mutated"])
        self.assertEqual(result["owner_visual_acceptance"], "pending")
        self.assertGreaterEqual(len(leases), 12)

    def test_existing_exact_head_run_is_recorded_without_duplicate_dispatch(self):
        posted, result, _ = self.exercise(already_running=True)
        self.assertNotIn("native.yml", posted)
        self.assertEqual(len(posted), 4)
        retained = next(item for item in result["dispatches"] if item["workflow"] == "native.yml")
        self.assertEqual(retained["action"], "existing; no dispatch sent")
        self.assertEqual(retained["run"]["id"], 499)

    def test_remote_movement_stops_further_posts_and_retains_partial_receipt(self):
        posted, result, _ = self.exercise(move_before_second=True)
        self.assertEqual(posted, [control.WORKFLOWS[0]])
        self.assertFalse(result["complete"])
        self.assertEqual(result["dispatches"][0]["http_status"], 204)
        self.assertIn("Remote branch lease changed", result["error"])

    def test_ambiguous_runs_fail_instead_of_claiming_exact_execution(self):
        _, result, _ = self.exercise(ambiguous=True)
        self.assertFalse(result["complete"])
        self.assertIn("Ambiguous new dispatch executions", result["error"])


if __name__ == "__main__":
    unittest.main()
