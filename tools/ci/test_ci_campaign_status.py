#!/usr/bin/env python3
"""Adversarial coordination contracts; no live GitHub requests or workflows."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import ci_campaign_status as status

SOURCE, OTHER = "a" * 40, "b" * 40


def run(number=10, state="in_progress", conclusion=None, attempt=1):
    return {"id": number, "run_attempt": attempt, "head_sha": SOURCE,
            "head_branch": "candidate", "name": "full qualification", "event": "push",
            "status": state, "conclusion": conclusion,
            "repository": {"full_name": "techrote/cybersand"}}


def job(number=100, state="in_progress", conclusion=None, runner=1):
    return {"id": number, "run_id": 10, "run_attempt": 1, "head_sha": SOURCE,
            "name": f"job {number}", "status": state, "conclusion": conclusion,
            "runner_id": runner, "labels": ["ubuntu-24.04"],
            "created_at": "2026-11-24T10:00:00Z",
            "started_at": "2026-11-24T10:01:00Z" if state not in {"queued", "pending", "waiting", "requested"} else None,
            "completed_at": "2026-11-24T10:02:00Z" if state == "completed" else None}


def snapshot(jobs=None, value=None):
    value = value or run()
    jobs = jobs if jobs is not None else [job()]
    queries = [{"status": state, "pages": [{"total_count": int(state == value["status"]),
        "workflow_runs": [copy.deepcopy(value)] if state == value["status"] else []}]} for state in status.ACTIVE_STATUSES]
    return {"schema": status.SNAPSHOT_SCHEMA, "repository": "techrote/cybersand",
        "collection_started_at": "2026-11-24T10:03:00Z", "collection_finished_at": "2026-11-24T10:04:00Z",
        "run_queries": queries, "runs": [{"run": copy.deepcopy(value), "run_after": copy.deepcopy(value),
        "job_pages": [{"total_count": len(jobs), "jobs": jobs}]}], "errors": []}


def ledger(kind="frozen_source", required=None):
    return {"schema": status.LEDGER_SCHEMA, "repository": "techrote/cybersand",
        "declared_capacity": {"value": 40, "authority": "owner-report-only"},
        "campaigns": [{"key": "request-1", "kind": kind, "programme": "#706", "owner": "CI lane",
            "branch": "candidate", "trigger_sha": SOURCE, "source_sha": OTHER, "source_tree": "c" * 40,
            "current_head_sha": "d" * 40, "human_gate": "owner-decision-required",
            "publication_gate": "unavailable-authenticated-publication",
            "runs": [{"run_id": 10, "attempt": 1, "required_jobs": required if required is not None else ["job 100"]}]}]}


class CoordinationContracts(unittest.TestCase):
    def test_runner_assignment_count_is_repository_lower_bound(self):
        jobs = [job(100), job(101, runner=1), job(102, runner=None), job(103, "queued", runner=None)]
        report = status.summarize(snapshot(jobs), ledger())
        self.assertEqual(report["status"], "observed")
        self.assertEqual(report["pressure"]["assigned_runner_ids_observed"], 1)
        self.assertEqual(report["pressure"]["in_progress_jobs"], 3)
        self.assertEqual(report["pressure"]["in_progress_without_verified_assignment"], 1)
        self.assertEqual(report["pressure"]["waiting_jobs"], 1)
        self.assertIn("unverified", report["pressure"]["account_capacity"])
        self.assertNotIn("utilisation", report["pressure"])

    def test_waiting_states_and_terminal_failures_are_preserved(self):
        states = ["queued", "waiting", "pending", "requested"]
        jobs = [job(100+i, s, runner=None) for i, s in enumerate(states)]
        for i, conclusion in enumerate(["failure", "cancelled", "timed_out", "action_required", "skipped", "neutral"]):
            jobs.append(job(110+i, "completed", conclusion))
        report = status.summarize(snapshot(jobs))
        self.assertEqual(report["pressure"]["waiting_states"], dict.fromkeys(states, 1))
        observed = {j["state"] for j in report["runs"][0]["jobs"]}
        self.assertTrue(set(states + ["failure", "cancelled", "timed_out", "action_required", "skipped", "neutral"]) <= observed)
        skipped = next(j for j in report["runs"][0]["jobs"] if j["state"] == "skipped")
        self.assertIsNone(skipped["completed_execution_seconds"])

    def test_successful_workflow_with_missing_or_skipped_required_jobs_is_blocked(self):
        for jobs in ([job(100, "completed", "skipped")], []):
            report = status.summarize(snapshot(jobs, run(state="completed", conclusion="success")), ledger())
            request = report["campaigns"][0]["requests"][0]
            self.assertEqual(request["metadata_gate"], "incomplete-or-blocked")
            self.assertIn("not-established", request["qualification"])

    def test_success_is_metadata_only_and_tested_source_may_differ_from_pr_head(self):
        report = status.summarize(snapshot([job(100, "completed", "success")], run(state="completed", conclusion="success")), ledger())
        request = report["campaigns"][0]["requests"][0]
        self.assertEqual(request["metadata_gate"], "reported-success")
        self.assertEqual(report["campaigns"][0]["source_sha"], OTHER)
        self.assertIn("requires", request["evidence_reuse"])
        self.assertIn("none", report["qualification"])

    def test_frozen_source_is_not_superseded_by_new_branch_head(self):
        value = run()
        value["event"] = "pull_request"
        for kind, expected in (("frozen_source", False), ("manual", False), ("ordinary_pr", True)):
            result = status.summarize(snapshot(value=value), ledger(kind))
            self.assertEqual(result["campaigns"][0]["requests"][0]["superseded_by_registered_pr_head"], expected)
        value["event"] = "push"
        result = status.summarize(snapshot(value=value), ledger("ordinary_pr"))
        self.assertFalse(result["campaigns"][0]["requests"][0]["superseded_by_registered_pr_head"])

    def test_stale_trigger_and_wrong_branch_cannot_match_request(self):
        for key, value in (("head_sha", OTHER), ("head_branch", "other")):
            data = snapshot([job(100, "completed", "success")], run(state="completed", conclusion="success"))
            data["runs"][0]["run"][key] = value
            data["runs"][0]["run_after"][key] = value
            if key == "head_sha":
                data["runs"][0]["job_pages"][0]["jobs"][0][key] = value
            result = status.summarize(data, ledger())
            self.assertEqual(result["campaigns"][0]["requests"][0]["metadata_gate"], "incomplete-or-blocked")

    def test_unregistered_required_jobs_cannot_turn_green(self):
        data = snapshot([job(100, "completed", "success")], run(state="completed", conclusion="success"))
        result = status.summarize(data, ledger(required=[]))
        self.assertIn("required job inventory unregistered", result["campaigns"][0]["requests"][0]["reasons"])

    def test_job_source_run_attempt_mismatch_refused(self):
        for key, value in (("head_sha", OTHER), ("run_id", 11), ("run_attempt", 2)):
            data = snapshot()
            data["runs"][0]["job_pages"][0]["jobs"][0][key] = value
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "source/run/attempt"):
                status.summarize(data)

    def test_duplicate_run_or_wrong_repository_refused(self):
        data = snapshot()
        data["runs"].append(copy.deepcopy(data["runs"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            status.summarize(data)
        data = snapshot()
        data["runs"][0]["run"]["repository"]["full_name"] = "other/repo"
        with self.assertRaisesRegex(ValueError, "different repository"):
            status.summarize(data)

    def test_partial_and_duplicate_job_pages_remain_partial(self):
        for kind in ("truncated", "duplicate", "changed_total"):
            data = snapshot()
            pages = data["runs"][0]["job_pages"]
            if kind == "truncated":
                pages[0]["total_count"] = 2
            elif kind == "duplicate":
                pages[0]["jobs"].append(copy.deepcopy(pages[0]["jobs"][0]))
                pages[0]["total_count"] = 2
            else:
                pages.append({"total_count": 2, "jobs": []})
            result = status.summarize(data)
            self.assertEqual(result["status"], "partial")
            self.assertFalse(result["runs"][0]["complete_job_inventory"])

    def test_status_list_race_and_unobserved_listed_run_remain_partial(self):
        data = snapshot()
        data["run_queries"][0]["pages"][0]["total_count"] = 2
        self.assertEqual(status.summarize(data)["status"], "partial")
        data = snapshot()
        data["run_queries"][0]["pages"][0]["workflow_runs"].append(run(11))
        data["run_queries"][0]["pages"][0]["total_count"] = 2
        result = status.summarize(data)
        self.assertTrue(any("no job inventory: 11" in p for p in result["problems"]))

    def test_run_changes_before_or_after_jobs_remain_nonatomic(self):
        for field in ("status", "run_attempt", "head_sha"):
            data = snapshot()
            data["runs"][0]["run_after"][field] = {"status": "completed", "run_attempt": 2, "head_sha": OTHER}[field]
            result = status.summarize(data)
            self.assertEqual(result["status"], "partial")
            self.assertTrue(any("changed during" in p for p in result["problems"]))
        data = snapshot()
        data["run_queries"][0]["pages"][0]["workflow_runs"][0]["run_attempt"] = 2
        self.assertEqual(status.summarize(data)["status"], "partial")

    def test_missing_recheck_or_active_status_query_remains_partial(self):
        data = snapshot()
        del data["runs"][0]["run_after"]
        self.assertEqual(status.summarize(data)["status"], "partial")
        data = snapshot()
        data["run_queries"].pop()
        self.assertEqual(status.summarize(data)["status"], "partial")

    def test_invalid_clocks_do_not_invent_durations_or_assignments(self):
        for value in (None, "2026-11-24T10:01:00", "2026-11-24T11:00:00Z"):
            data = snapshot()
            data["runs"][0]["job_pages"][0]["jobs"][0]["started_at"] = value
            result = status.summarize(data)
            self.assertIsNone(result["runs"][0]["jobs"][0]["running_age_seconds"])
            self.assertEqual(result["pressure"]["assigned_runner_ids_observed"], 0)

    def test_ambiguous_required_name_does_not_pass(self):
        jobs = [job(100, "completed", "success"), job(101, "completed", "success")]
        jobs[1]["name"] = jobs[0]["name"]
        result = status.summarize(snapshot(jobs, run(state="completed", conclusion="success")), ledger())
        self.assertEqual(result["campaigns"][0]["requests"][0]["required_jobs"][0]["state"], "ambiguous")

    def test_duplicate_or_illformed_ledger_refused(self):
        for mutate in (lambda x: x["campaigns"].append(copy.deepcopy(x["campaigns"][0])),
                       lambda x: x["campaigns"][0]["runs"][0].update(attempt=True),
                       lambda x: x["campaigns"][0]["runs"][0].update(required_jobs=["test", "test"]),
                       lambda x: x.update(repository="other/repo")):
            data = ledger()
            mutate(data)
            with self.assertRaises(ValueError):
                status.summarize(snapshot(), data)

    def test_artifact_metadata_never_qualifies_receipts(self):
        data = snapshot()
        data["runs"][0]["artifact_pages"] = [{"total_count": 1, "artifacts": [{"id": 3,
            "name": "passed-forged-report", "expired": False, "digest": "sha256:" + "f" * 64}]}]
        result = status.summarize(data, ledger())
        self.assertIn("metadata-only", result["runs"][0]["evidence_verification"])
        self.assertIn("requires", result["campaigns"][0]["requests"][0]["evidence_reuse"])

    def test_json_duplicate_and_nonfinite_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.json"
            for raw in ('{"run_id": 1, "run_id": 2}', '{"value": NaN}'):
                path.write_text(raw)
                with self.assertRaises(ValueError):
                    status.read_json(path)

    def test_superseded_success_is_visible_and_cannot_satisfy_current_request(self):
        value = run(state="completed", conclusion="success")
        value["event"] = "pull_request"
        report = status.summarize(snapshot([job(100, "completed", "success")], value), ledger("ordinary_pr"))
        request = report["campaigns"][0]["requests"][0]
        self.assertTrue(request["superseded_by_registered_pr_head"])
        self.assertEqual(request["metadata_gate"], "incomplete-or-blocked")
        self.assertIn("superseded", status.render_markdown(report))
        self.assertEqual(report["runs"][0]["jobs"][0]["state"], "success")

    def test_future_completed_clock_and_completed_run_with_live_job_are_partial(self):
        data = snapshot([job(100, "completed", "success")], run(state="completed", conclusion="success"))
        data["runs"][0]["job_pages"][0]["jobs"][0]["completed_at"] = "2026-11-24T11:00:00Z"
        report = status.summarize(data, ledger())
        self.assertEqual(report["status"], "partial")
        self.assertEqual(report["campaigns"][0]["requests"][0]["metadata_gate"], "incomplete-or-blocked")
        self.assertEqual(status.summarize(snapshot(value=run(state="completed", conclusion="success")))["status"], "partial")

    def test_status_query_contradiction_is_partial(self):
        data = snapshot()
        for value in (data["run_queries"][0]["pages"][0]["workflow_runs"][0], data["runs"][0]["run"], data["runs"][0]["run_after"]):
            value.update(status="completed", conclusion="success")
        data["runs"][0]["job_pages"][0]["jobs"] = [job(100, "completed", "success")]
        result = status.summarize(data)
        self.assertEqual(result["status"], "partial")
        self.assertTrue(any("status differs from its query" in p for p in result["problems"]))

    def test_malformed_page_rows_refuse_cleanly(self):
        for row in (None, [], {"id": True}):
            data = snapshot()
            data["runs"][0]["job_pages"][0]["jobs"] = [row]
            with self.assertRaisesRegex(ValueError, "malformed page or row"):
                status.summarize(data)

    def test_malformed_envelopes_refuse_cleanly(self):
        for data in ([], None, "not a snapshot"):
            with self.assertRaises(ValueError):
                status.summarize(data)
        for mutate in (lambda x: x["run_queries"].append(None),
                       lambda x: x["runs"].append(None),
                       lambda x: x["runs"][0].update(run_after=[]),
                       lambda x: x["runs"][0]["run"].update(repository="other/repo")):
            data = snapshot()
            mutate(data)
            with self.assertRaises(ValueError):
                status.summarize(data)

    def test_collector_bounded_and_all_requests_get_only(self):
        paths = []
        def get(endpoint):
            paths.append(endpoint)
            if "?status=" in endpoint:
                which = endpoint.split("status=")[1].split("&")[0]
                return {"total_count": 2 if which == "in_progress" else 0,
                        "workflow_runs": [run(), run(11)] if which == "in_progress" else []}
            if "/jobs?" in endpoint:
                return {"total_count": 1, "jobs": [job()]}
            return run()
        with patch.object(status, "utc_now", return_value="2026-11-24T10:04:00Z"):
            data = status.collect("techrote/cybersand", max_runs=1, get=get, ledger=ledger())
        self.assertEqual(len(paths), 8)
        self.assertEqual(len(data["runs"]), 1)
        self.assertIn("run detail bound reached; inventory partial", data["errors"])
        self.assertEqual(status.summarize(data, ledger())["status"], "partial")
        with patch.object(status.subprocess, "run") as fake:
            fake.return_value.returncode = 0
            fake.return_value.stdout = b'{}'
            status.gh_get("repos/techrote/cybersand/actions/runs")
            self.assertEqual(fake.call_args.args[0], ["gh", "api", "--method", "GET", "repos/techrote/cybersand/actions/runs"])
            self.assertNotIn("shell", fake.call_args.kwargs)

    def test_collector_auth_failure_preserves_empty_partial_report(self):
        def unavailable(_):
            raise RuntimeError("unavailable")
        result = status.summarize(status.collect("techrote/cybersand", get=unavailable))
        self.assertEqual(result["status"], "partial")
        self.assertEqual(result["pressure"]["assigned_runner_ids_observed"], 0)

    def test_summary_does_not_export_runner_names_or_signed_urls(self):
        data = snapshot()
        data["runs"][0]["job_pages"][0]["jobs"][0].update(runner_name="private-host-name", html_url="https://example.com/?token=secret")
        result = status.summarize(data)
        rendered = json.dumps(result) + status.render_markdown(result)
        self.assertNotIn("private-host-name", rendered)
        self.assertNotIn("token=secret", rendered)

    def test_cli_pins_consumed_snapshot_and_ledger_when_paths_are_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            source, requests, output = (Path(directory) / name for name in ("snapshot.json", "ledger.json", "report.json"))
            source_pin = status.write_json(source, snapshot())
            ledger_pin = status.write_json(requests, ledger())
            original = status.summarize
            def replace_then_summarize(data, campaign):
                replacement = snapshot()
                replacement["runs"][0]["run"]["name"] = "replacement-workflow"
                status.write_json(source, replacement)
                replacement_ledger = ledger()
                replacement_ledger["campaigns"][0]["programme"] = "replacement-programme"
                status.write_json(requests, replacement_ledger)
                return original(data, campaign)
            argv = ["status", "--snapshot", str(source), "--ledger", str(requests), "--output", str(output)]
            with patch("sys.argv", argv), patch.object(status, "summarize", side_effect=replace_then_summarize), patch("builtins.print"):
                self.assertEqual(status.main(), 0)
            result = status.read_json(output)
            self.assertEqual(result["runs"][0]["workflow"], "full qualification")
            self.assertEqual(result["campaigns"][0]["programme"], "#706")
            self.assertEqual(result["snapshot_sha256"], source_pin)
            self.assertEqual(result["ledger_sha256"], ledger_pin)
            self.assertNotEqual(source_pin, hashlib.sha256(source.read_bytes()).hexdigest())
            self.assertNotEqual(ledger_pin, hashlib.sha256(requests.read_bytes()).hexdigest())

    def test_collect_pins_exact_written_snapshot_before_path_replacement(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = (Path(directory) / name for name in ("snapshot.json", "report.json"))
            original = status.summarize
            pins = []
            def replace_then_summarize(data, campaign):
                pins.append(hashlib.sha256(source.read_bytes()).hexdigest())
                source.write_bytes(b'{"replacement":true}\n')
                return original(data, campaign)
            argv = ["status", "--collect", "--raw-output", str(source), "--output", str(output)]
            with patch("sys.argv", argv), patch.object(status, "collect", return_value=snapshot()), patch.object(status, "summarize", side_effect=replace_then_summarize), patch("builtins.print"):
                self.assertEqual(status.main(), 0)
            result = status.read_json(output)
            self.assertEqual(result["runs"][0]["workflow"], "full qualification")
            self.assertEqual(result["snapshot_sha256"], pins[0])
            self.assertNotEqual(pins[0], hashlib.sha256(source.read_bytes()).hexdigest())


if __name__ == "__main__":
    unittest.main()
