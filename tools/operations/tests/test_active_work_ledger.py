"""Adversarial coordination claims, using synthetic evidence and no network.

The fixture preserves all 24 seed IDs but does not assert real GitHub results.
CLI outputs stay in disposable temporary directories outside the repository.
"""
from __future__ import annotations

from copy import deepcopy
from datetime import datetime
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml

TOOL = Path(__file__).resolve().parents[1] / "active_work_ledger.py"
sys.path.insert(0, str(TOOL.parent))
import active_work_ledger as ledger

FIXTURE = Path(__file__).parent / "fixtures/seed_template.yaml"
NOW = "2026-11-04T15:30:00Z"
HEAD, TREE, MAIN = "a" * 40, "b" * 40, "c" * 40


class NoAliases(yaml.SafeDumper):
    def ignore_aliases(self, data):
        return True


def dump(data):
    return yaml.dump(data, Dumper=NoAliases, sort_keys=False, allow_unicode=True)


def fresh():
    data = ledger.load_ledger(FIXTURE)
    first = data["workstreams"][0]
    for index, key in enumerate(data["seed_ids"][1:], 2):
        row = deepcopy(first)
        row.update(id=key, title=key, scope="Independent planned scope " + key,
                   programme="synthetic", priority=index, prs=[], primary_pr=None,
                   delivery_stage="queued", stage_evidence=[], agent_activity="not_started",
                   activity_evidence=[], source_confidence="planning_only", qualification=[])
        row["ownership"].update(branch=None, role="planned")
        data["workstreams"].append(row)
    return data


def stream(data, key="IN361-ADMISSION"):
    return next(x for x in data["workstreams"] if x["id"] == key)


def evidence(data, key="E-SAMPLE"):
    return next(x for x in data["evidence"] if x["id"] == key)


def add_evidence(data, key, **changes):
    row = deepcopy(evidence(data))
    row.update(id=key, **changes)
    data["evidence"].append(row)
    return row


def add_pr(data, number, lane, base_ref="main"):
    pr = deepcopy(data["pull_requests"][0])
    pr.update(number=number, url=f"https://github.com/techrote/cybersand/pull/{number}",
              title="Synthetic second PR", head_ref=f"docs/pr-{number}",
              head_sha=f"{number:040x}", head_tree=f"{number + 1:040x}",
              base_ref=base_ref, evidence=f"PR{number}")
    ev = deepcopy(evidence(data, "PR379"))
    ev.update(id=pr["evidence"], subject_pr=number, url=pr["url"],
              source_sha=pr["head_sha"], source_tree=pr["head_tree"])
    data["evidence"].append(ev)
    data["pull_requests"].append(pr)
    row = stream(data, lane)
    row.update(prs=[number], primary_pr=number, delivery_stage="implementation_draft",
               stage_evidence=[ev["id"]], agent_activity="published_progress_session_unknown",
               activity_evidence=[ev["id"]], source_confidence="verified_metadata")
    row["ownership"].update(branch=pr["head_ref"], role="implementation")
    data["open_pr_inventory"].append({
        "pr": number, "classification": "active_relevant", "rationale": "Synthetic detailed artifact.",
        "evidence": ev["id"], "observed_at": NOW, "workstreams": [lane],
    })
    inv = data["snapshot"]["inventory"]
    inv["observed_open_count"] += 1
    inv["pages"][0]["count"] += 1
    return pr


def ready(data):
    row = stream(data)
    row["delivery_stage"] = "ready_owner_gate"
    data["pull_requests"][0]["draft"] = False
    row["qualification"] = row["qualification"][:1]
    row["qualification"][0]["required_for_ready"] = True
    evidence(data)["authority"] = "verified"
    add_evidence(data, "REVIEW", kind="independent_review", authority="verified",
                 scope="Independent bounded source review", platforms=["source"])
    row["review_disposition"] = {
        "status": "pass", "evidence": ["REVIEW"], "source_sha": HEAD, "source_tree": TREE,
        "summary": "Synthetic independent exact-head review, not implementation self-review.",
    }
    return row


def grant(data, **changes):
    row = stream(data)
    add_evidence(data, "APPROVAL", kind="owner_decision", authority="verified", actor="techrote",
                 decision="approve_merge", result=None, scope=None, platforms=[], **changes)
    row["merge_approval"] = {"status": "granted", "evidence": ["APPROVAL"],
                             "head_sha": HEAD, "head_tree": TREE}
    return row


def merged(data):
    row = stream(data)
    pr = data["pull_requests"][0]
    pr.update(state="closed", merged=True, merged_at=NOW, merge_commit_sha=MAIN)
    evidence(data, "PR379")["kind"] = "github_merge"
    row["delivery_stage"] = "integrated"
    data["open_pr_inventory"] = []
    data["snapshot"]["inventory"].update(observed_open_count=0)
    data["snapshot"]["inventory"]["pages"] = data["snapshot"]["inventory"]["pages"][:1]
    data["snapshot"]["inventory"]["pages"][0]["count"] = 0
    return row


def shared_pr(data):
    first = stream(data)
    second = stream(data, "SOL364-B")
    second.update(prs=[379], primary_pr=379, scope="Distinct source-safe contact follow-up",
                  delivery_stage="implementation_draft", source_confidence="verified_metadata",
                  stage_evidence=["PR379"], agent_activity="published_progress_session_unknown",
                  activity_evidence=["PR379"])
    second["ownership"].update(branch="docs/example", role="evidence")
    data["open_pr_inventory"][0]["workstreams"].append("SOL364-B")
    return first, second


def physical_no_go(data):
    """Concrete #347-shaped CPU-versus-physical negative control."""
    first = stream(data)
    first.update(prs=[], primary_pr=None, delivery_stage="queued", stage_evidence=[],
                 agent_activity="not_started", activity_evidence=[], qualification=[],
                 source_confidence="planning_only")
    first["ownership"].update(branch=None, role="planned")
    pr = data["pull_requests"][0]
    pr.update(number=347, title="Synthetic SOL347 physical NO-GO",
              url="https://github.com/techrote/cybersand/pull/347",
              head_ref="sol-detach-001-current-main", evidence="PR347")
    ev = evidence(data, "PR379")
    ev.update(id="PR347", subject_pr=347, url=pr["url"])
    ev = evidence(data)
    ev.update(subject_pr=347, scope="24 CPU cost groups", authority="verified")
    row = stream(data, "SOL364-CONTACT")
    row.update(prs=[347], primary_pr=347, delivery_stage="no_go", stage_evidence=["PR347", "PHYS-FAIL"],
               agent_activity="published_progress_session_unknown", activity_evidence=["PR347"],
               source_confidence="mixed")
    row["ownership"].update(branch=pr["head_ref"], role="implementation")
    add_evidence(data, "PHYS-FAIL", subject_pr=347, result="fail",
                 scope="stationary Sand clearance", authority="verified", platforms=["linux", "windows"])
    row["qualification"] = [
        {"id": "cpu", "scope": "24 CPU cost groups", "result": "pass", "platforms": ["linux"],
         "source_sha": HEAD, "source_tree": TREE, "binding": "exact_head", "evidence": ["E-SAMPLE"],
         "required_for_ready": True, "runtime": "Synthetic native CPU fixtures", "limitations": "CPU only."},
        {"id": "physical", "scope": "stationary Sand clearance", "result": "fail", "platforms": ["linux", "windows"],
         "source_sha": HEAD, "source_tree": TREE, "binding": "exact_head", "evidence": ["PHYS-FAIL"],
         "required_for_ready": True, "runtime": "Synthetic Rapier hosts", "limitations": "Stationary penetration persists."},
    ]
    row["blockers"] = [{"id": "penetration", "kind": "physical", "summary": "Stationary Sand remains embedded.",
                        "evidence": ["PHYS-FAIL"], "resolved": False}]
    data["open_pr_inventory"][0].update(pr=347, classification="held_no_go", evidence="PR347",
                                       workstreams=["SOL364-CONTACT"])
    data["change_log"][0]["evidence"] = ["PR347"]
    return row


class FixtureCase(unittest.TestCase):
    def setUp(self):
        self.data = fresh()
        self.row = stream(self.data)

    def valid(self, data=None):
        result = ledger.validate(self.data if data is None else data)
        self.assertTrue(result.ok, "\n".join(result.errors))
        return result

    def rejects(self, code, data=None):
        result = ledger.validate(self.data if data is None else data)
        self.assertFalse(result.ok, "unexpected acceptance")
        self.assertTrue(any(f"[{code}]" in e for e in result.errors), "\n".join(result.errors))
        return result


class StructureTests(FixtureCase):
    def test_complete_seed_roundtrip(self):
        self.assertEqual(24, len(self.data["seed_ids"]))
        self.assertEqual(24, len(self.data["workstreams"]))
        self.valid()
        decoded = ledger.loads_ledger(dump(self.data))
        self.assertEqual(self.data, decoded)
        self.assertEqual(ledger.render(self.data), ledger.render(decoded))

    def test_duplicate_workstream(self):
        self.data["workstreams"].append(deepcopy(self.row))
        self.rejects("duplicate_id")

    def test_unknown_stage_and_invalid_shapes(self):
        for value in ["running", "finished", "READY", [], {}, None, True, ""]:
            with self.subTest(value=value):
                data = fresh()
                stream(data)["delivery_stage"] = value
                self.rejects("enum", data)

    def test_duplicate_evidence(self):
        self.data["evidence"].append(deepcopy(self.data["evidence"][0]))
        self.rejects("duplicate_evidence")

    def test_duplicate_coverage(self):
        self.data["open_pr_inventory"].append(deepcopy(self.data["open_pr_inventory"][0]))
        self.rejects("duplicate_coverage")

    def test_coverage_missing_open_pr(self):
        self.data["open_pr_inventory"] = []
        self.rejects("coverage_complete")

    def test_index_without_classification(self):
        del self.data["open_pr_inventory"][0]["classification"]
        self.rejects("missing")

    def test_coverage_count_mismatch(self):
        self.data["snapshot"]["inventory"]["observed_open_count"] = 2
        self.rejects("inventory_count")

    def test_terminal_pagination_required(self):
        self.data["snapshot"]["inventory"]["pages"].pop()
        self.rejects("pagination")

    def test_pagination_gap(self):
        self.data["snapshot"]["inventory"]["pages"][1]["page"] = 3
        self.rejects("pagination")

    def test_wrong_pagination_source(self):
        self.data["snapshot"]["inventory"]["pages"][0]["url"] = "https://api.github.com/repos/techrote/cybersand/pulls?state=closed&per_page=100&page=1"
        self.rejects("pagination")

    def test_exhaustion_not_guessed(self):
        self.data["snapshot"]["inventory"]["exhaustive"] = False
        self.rejects("pagination")

    def test_seed_retention_is_not_optional(self):
        self.data["workstreams"].pop()
        self.rejects("seed_coverage")

    def test_merged_pr_not_open_inventory(self):
        merged(self.data)
        self.data["open_pr_inventory"] = fresh()["open_pr_inventory"]
        self.rejects("coverage_state")

    def test_lane_missing_from_pr_index(self):
        self.data["open_pr_inventory"][0]["workstreams"] = []
        self.rejects("coverage_lane")

    def test_unreferenced_pr(self):
        self.row["prs"].append(500)
        self.rejects("pr_ref")

    def test_change_log_covers_all_lanes(self):
        self.data["change_log"][0]["workstreams"].pop()
        self.rejects("change_coverage")

    def test_missing_or_unsafe_evidence_links(self):
        for value in ["", None, "javascript:alert(1)", "https://user:secret@github.com/x", "https://github.com/a\nb"]:
            with self.subTest(value=value):
                data = fresh()
                evidence(data)["url"] = value
                self.assertFalse(ledger.validate(data).ok)

    def test_future_observation_rejected(self):
        self.data["evidence"][0]["observed_at"] = "2027-01-01T00:00:00Z"
        self.rejects("future_observation")

    def test_boolean_is_not_an_integer(self):
        self.data["snapshot"]["inventory"]["observed_open_count"] = True
        self.rejects("type")

    def test_unknown_safety_field_not_ignored(self):
        self.row["merge_approval"]["approved"] = True
        self.rejects("unknown_field")


class DependencyTests(FixtureCase):
    def test_missing_dependency(self):
        self.row["dependencies"] = [{"id": "ABSENT", "type": "hard", "reason": "Missing prerequisite."}]
        self.rejects("dependency_ref")

    def test_self_dependency(self):
        self.row["dependencies"] = [{"id": self.row["id"], "type": "coordination", "reason": "Self dependency."}]
        self.rejects("self_dependency")

    def test_hard_cycles(self):
        for kind in ["hard", "hard_for_implementation", "hard_for_integration", "stacked"]:
            with self.subTest(kind=kind):
                data = fresh()
                stream(data)["dependencies"] = [{"id": "IN361-DRAIN", "type": kind, "reason": "Cycle arm."}]
                stream(data, "IN361-DRAIN")["dependencies"] = [{"id": "IN361-ADMISSION", "type": kind, "reason": "Cycle return."}]
                self.rejects("dependency_cycle", data)

    def test_coordination_cycles_are_not_integration_cycles(self):
        for kind in ["coordination", "source_conflict"]:
            data = fresh()
            stream(data)["dependencies"] = [{"id": "IN361-DRAIN", "type": kind, "reason": "Shared source."}]
            stream(data, "IN361-DRAIN")["dependencies"] = [{"id": "IN361-ADMISSION", "type": kind, "reason": "Reciprocal warning."}]
            self.valid(data)

    def test_real_stack_requires_ordered_edge(self):
        add_pr(self.data, 383, "IN361-DRAIN", "docs/example")
        self.rejects("stack_missing")
        stream(self.data, "IN361-DRAIN")["dependencies"] = [
            {"id": "IN361-ADMISSION", "type": "stacked", "reason": "PR383 targets PR379 branch."}]
        self.valid()

    def test_wrong_stack_base(self):
        add_pr(self.data, 383, "IN361-DRAIN")
        stream(self.data, "IN361-DRAIN")["dependencies"] = [
            {"id": "IN361-ADMISSION", "type": "stacked", "reason": "Claim does not match actual main target."}]
        self.rejects("stack_order")

    def test_ready_cannot_bypass_prerequisite(self):
        ready(self.data)
        self.row["dependencies"] = [{"id": "MAT353-A", "type": "hard_for_integration", "reason": "Required foundation."}]
        self.rejects("dependency_gate")

    def test_invalid_dependency_kind(self):
        self.row["dependencies"] = [{"id": "IN361-DRAIN", "type": "probably", "reason": "Ambiguous ordering."}]
        self.rejects("enum")


class AuthorityTests(FixtureCase):
    def test_unbacked_integrated(self):
        self.row["delivery_stage"] = "integrated"
        self.rejects("integration_authority")

    def test_verified_merge_is_integrated_without_invented_approval(self):
        row = merged(self.data)
        self.valid()
        self.assertEqual("not_recorded", row["merge_approval"]["status"])

    def test_ready_is_not_approval(self):
        row = ready(self.data)
        self.valid()
        self.assertEqual("not_recorded", row["merge_approval"]["status"])

    def test_ready_without_independent_review(self):
        self.row["delivery_stage"] = "ready_owner_gate"
        self.rejects("ready_review")

    def test_self_review_cannot_be_independent_pass(self):
        ready(self.data)
        evidence(self.data, "REVIEW")["kind"] = "analysis"
        self.rejects("review_authority")

    def test_same_source_review_for_another_pr_is_not_acceptance(self):
        ready(self.data)
        evidence(self.data, "REVIEW")["subject_pr"] = 383
        self.rejects("review_authority")

    def test_conditional_review_is_not_pass(self):
        ready(self.data)
        self.row["review_disposition"]["status"] = "conditional"
        self.rejects("ready_review")

    def test_reported_execution_is_not_verified_readiness(self):
        ready(self.data)
        evidence(self.data)["authority"] = "reported"
        self.rejects("ready_gates")

    def test_verified_linux_cannot_promote_reported_windows_to_ready(self):
        ready(self.data)
        q = self.row["qualification"][0]
        add_evidence(self.data, "WINDOWS-REPORTED", authority="reported", platforms=["windows"])
        q["evidence"].append("WINDOWS-REPORTED")
        q["platforms"].append("windows")
        self.rejects("ready_platform_scope")
        # Both scoped results may be retained as mixed-authority qualification;
        # they simply cannot establish verified readiness.
        self.row["delivery_stage"] = "implementation_draft"
        self.valid()

    def test_issue_cannot_be_closed_by_unrelated_pr_metadata(self):
        self.row["issues"] = [{
            "number": 361, "url": "https://github.com/techrote/cybersand/issues/361",
            "state": "closed", "evidence": "PR379",
        }]
        self.rejects("issue_authority")

    def test_merged_child_does_not_close_its_verified_open_parent(self):
        merged(self.data)
        self.data["evidence"].append({
            "id": "ISSUE361", "kind": "github_metadata", "url": "https://github.com/techrote/cybersand/issues/361",
            "observed_at": NOW, "summary": "Synthetic verified open parent.", "authority": "verified",
            "subject_issue": 361, "issue_state": "open",
        })
        self.row["issues"] = [{
            "number": 361, "url": "https://github.com/techrote/cybersand/issues/361",
            "state": "open", "evidence": "ISSUE361",
        }]
        self.valid()
        self.row["issues"][0]["state"] = "closed"
        self.rejects("issue_authority")

    def test_draft_does_not_become_ready_from_passes(self):
        ready(self.data)
        self.data["pull_requests"][0]["draft"] = True
        self.rejects("ready_metadata")

    def test_merge_conflict_blocks_ready(self):
        ready(self.data)
        self.data["pull_requests"][0]["mergeable"] = False
        self.rejects("ready_metadata")

    def test_old_base_blocks_ready(self):
        ready(self.data)
        self.data["pull_requests"][0]["base_sha"] = "f" * 40
        self.rejects("ready_base")

    def test_no_required_gates_is_not_ready(self):
        ready(self.data)
        self.row["qualification"][0]["required_for_ready"] = False
        self.rejects("ready_gates")

    def test_approval_requires_reference(self):
        self.row["merge_approval"].update(status="granted", head_sha=HEAD, head_tree=TREE)
        self.rejects("approval_authority")

    def test_explicit_owner_approval_positive(self):
        grant(self.data)
        self.valid()

    def test_recommendation_is_not_owner_approval(self):
        grant(self.data)
        evidence(self.data, "APPROVAL")["decision"] = "recommend_merge"
        self.rejects("approval_authority")

    def test_checkpoint_choice_is_not_merge_approval(self):
        grant(self.data)
        evidence(self.data, "APPROVAL")["decision"] = "accept_schema_refusal"
        self.rejects("approval_authority")

    def test_nonowner_cannot_grant_owner_merge(self):
        grant(self.data)
        evidence(self.data, "APPROVAL")["actor"] = "implementation-agent"
        self.rejects("approval_authority")

    def test_other_pr_approval_cannot_transfer(self):
        grant(self.data)
        evidence(self.data, "APPROVAL")["subject_pr"] = 383
        self.rejects("approval_authority")

    def test_earlier_head_approval_cannot_transfer(self):
        grant(self.data)
        evidence(self.data, "APPROVAL")["source_sha"] = "f" * 40
        self.rejects("source_mismatch")

    def test_no_phantom_approval_reference(self):
        self.row["merge_approval"]["head_sha"] = HEAD
        self.rejects("approval_authority")

    def test_not_started_cannot_be_published_from_a_user_report(self):
        row = stream(self.data, "PLAY262-MAPS")
        add_evidence(self.data, "USER", kind="user_report", authority="user_reported", result=None,
                     scope=None, platforms=[], source_sha=None, source_tree=None, subject_pr=None)
        row.update(delivery_stage="implementation_draft", stage_evidence=["USER"], source_confidence="user_reported",
                   agent_activity="user_reported_started", activity_evidence=["USER"])
        self.rejects("delivery_authority")

    def test_changing_confidence_cannot_manufacture_a_published_artifact(self):
        row = stream(self.data, "PLAY262-MAPS")
        add_evidence(self.data, "USER", kind="user_report", authority="user_reported", result=None,
                     scope=None, platforms=[], source_sha=None, source_tree=None, subject_pr=None)
        row.update(delivery_stage="implementation_draft", stage_evidence=["USER"], source_confidence="mixed")
        self.rejects("delivery_authority")


class QualificationTests(FixtureCase):
    def test_pass_without_source(self):
        self.row["qualification"][0]["source_sha"] = None
        self.rejects("source_identity")

    def test_pass_without_tree(self):
        self.row["qualification"][0]["source_tree"] = None
        self.rejects("source_identity")

    def test_pass_without_evidence(self):
        self.row["qualification"][0]["evidence"] = []
        self.rejects("result_authority")

    def test_pass_cannot_be_reattached_to_another_sha(self):
        self.row["qualification"][0]["source_sha"] = "f" * 40
        self.rejects("source_mismatch")

    def test_historical_pass_retains_its_source(self):
        self.data["pull_requests"][0]["head_sha"] = "f" * 40
        evidence(self.data, "PR379")["source_sha"] = "f" * 40
        self.row["qualification"][0]["binding"] = "historical"
        self.valid()
        self.assertEqual(HEAD, self.row["qualification"][0]["source_sha"])

    def test_historical_pass_cannot_qualify_ready(self):
        ready(self.data)
        self.row["qualification"][0]["binding"] = "historical"
        self.rejects("ready_source")

    def test_platform_overclaim(self):
        self.row["qualification"][0]["platforms"].append("windows")
        self.rejects("platform_scope")

    def test_scope_overclaim(self):
        self.row["qualification"][0]["scope"] = "All runtime, device and gameplay gates"
        self.rejects("result_scope")

    def test_analysis_is_not_an_executed_pass(self):
        ready(self.data)
        evidence(self.data)["kind"] = "analysis"
        self.rejects("result_authority")

    def test_pass_cannot_claim_unexecuted_runtime(self):
        for value in ["not executed", "not_run", "UNKNOWN", "unavailable", "n/a"]:
            with self.subTest(value=value):
                data = fresh()
                stream(data)["qualification"][0]["runtime"] = value
                self.rejects("runtime_identity", data)

    def test_skipped_workflow_not_pass(self):
        evidence(self.data)["result"] = "skipped"
        self.rejects("result_authority")

    def test_unknown_and_not_run_cannot_borrow_pass(self):
        for result in ["unknown", "not_run"]:
            data = fresh()
            stream(data)["qualification"][0]["result"] = result
            self.rejects("result_scope", data)

    def test_all_six_results_survive_rendering(self):
        self.row["qualification"] = []
        for i, result in enumerate(["pass", "fail", "skipped", "not_run", "inapplicable", "unknown"]):
            has_source = result in {"pass", "fail", "skipped"}
            q = {"id": f"gate-{i}", "scope": f"Scope {i}", "result": result, "platforms": ["linux"],
                 "source_sha": HEAD if has_source else None, "source_tree": TREE if has_source else None,
                 "binding": "exact_head" if has_source else "not_applicable", "evidence": [],
                 "required_for_ready": False, "runtime": "Synthetic fixture",
                 "limitations": "Explicit result; no promotion to runtime acceptance."}
            if result in {"pass", "fail", "skipped", "inapplicable"}:
                key = f"OUTCOME-{i}"
                add_evidence(self.data, key, result=result, scope=q["scope"], authority="verified",
                             kind="analysis" if result == "inapplicable" else "source_receipt",
                             source_sha=q["source_sha"], source_tree=q["source_tree"])
                q["evidence"] = [key]
            self.row["qualification"].append(q)
        self.valid()
        text = ledger.render(self.data)
        for result in ["PASS", "FAIL", "SKIPPED", "NOT_RUN", "INAPPLICABLE", "UNKNOWN"]:
            self.assertIn(f"**{result}**", text)

    def test_inapplicable_requires_evidenced_rationale(self):
        q = self.row["qualification"][1]
        q.update(result="inapplicable", limitations=" ")
        self.rejects("result_authority")

    def test_synthetic_merge_needs_explicit_equivalence(self):
        q = self.row["qualification"][0]
        q.update(source_sha="e" * 40, binding="tree_equivalent")
        evidence(self.data)["source_sha"] = q["source_sha"]
        self.rejects("tree_equivalence")

    def test_verified_tree_equivalence(self):
        q = self.row["qualification"][0]
        q.update(source_sha="e" * 40, binding="tree_equivalent")
        evidence(self.data)["source_sha"] = q["source_sha"]
        proof = add_evidence(self.data, "EQ", kind="tree_equivalence", authority="verified", result=None,
                             scope=None, platforms=[], source_sha=None, source_tree=None,
                             equivalence={"tested_sha": q["source_sha"], "tested_tree": TREE,
                                          "head_sha": HEAD, "head_tree": TREE, "base_sha": MAIN,
                                          "parents": [MAIN, HEAD], "verified": True})
        q["evidence"].append("EQ")
        self.valid()
        proof["equivalence"]["parents"].reverse()
        self.rejects("tree_equivalence")

    def test_equal_name_does_not_prove_equal_tree(self):
        q = self.row["qualification"][0]
        q.update(source_sha="e" * 40, binding="tree_equivalent")
        evidence(self.data)["source_sha"] = q["source_sha"]
        add_evidence(self.data, "EQ", kind="tree_equivalence", authority="verified", result=None,
                     scope=None, platforms=[], source_sha=None, source_tree=None,
                     equivalence={"tested_sha": q["source_sha"], "tested_tree": "f" * 40,
                                  "head_sha": HEAD, "head_tree": TREE, "base_sha": MAIN,
                                  "parents": [MAIN, HEAD], "verified": True})
        q["evidence"].append("EQ")
        self.rejects("tree_equivalence")

    def test_physical_347_no_go_survives_cpu_pass(self):
        row = physical_no_go(self.data)
        self.valid()
        rendered = ledger.render(self.data)
        self.assertIn("24 CPU cost groups", rendered)
        self.assertIn("**FAIL**", rendered)
        self.assertEqual("no_go", row["delivery_stage"])
        row["delivery_stage"] = "ready_owner_gate"
        self.rejects("physical_no_go")

    def test_no_go_cannot_hide_its_blocker(self):
        row = physical_no_go(self.data)
        row["blockers"] = []
        self.rejects("no_go_authority")


class ActivityAndOwnershipTests(FixtureCase):
    def test_historical_artifact_does_not_become_running_chat(self):
        self.row["delivery_stage"] = "historical"
        self.row["agent_activity"] = "running"
        self.rejects("enum")

    def test_pr_not_a_user_started_chat_claim(self):
        self.row.update(agent_activity="user_reported_started", activity_evidence=["PR379"])
        self.rejects("activity_authority")

    def test_another_lane_pr_does_not_establish_published_activity(self):
        row = stream(self.data, "PLAY262-MAPS")
        row.update(agent_activity="published_progress_session_unknown", activity_evidence=["PR379"])
        self.rejects("activity_authority")

    def test_merged_pr_not_a_stop_report(self):
        merged(self.data)
        self.row["agent_activity"] = "explicitly_stopped"
        self.rejects("activity_authority")

    def test_start_report_cannot_establish_an_explicit_stop(self):
        add_evidence(self.data, "START", kind="user_report", authority="user_reported",
                     decision="started", result=None, scope=None, platforms=[])
        self.row.update(agent_activity="explicitly_stopped", activity_evidence=["START"])
        self.rejects("activity_authority")
        evidence(self.data, "START")["decision"] = "stopped"
        self.valid()

    def test_started_status_requires_explicit_report_disposition(self):
        add_evidence(self.data, "REPORT", kind="user_report", authority="user_reported",
                     decision=None, result=None, scope=None, platforms=[])
        self.row.update(agent_activity="user_reported_started", activity_evidence=["REPORT"])
        self.rejects("activity_authority")
        evidence(self.data, "REPORT")["decision"] = "started"
        self.valid()

    def test_distinct_lanes_can_share_a_pr(self):
        shared_pr(self.data)
        self.valid()

    def test_shared_one_writer_is_not_duplicate_ownership(self):
        first, second = shared_pr(self.data)
        add_evidence(self.data, "CUSTODY", kind="ownership", authority="reported", result=None,
                     scope=None, platforms=[], actor="named-writer", decision="sole_writer")
        for row in [first, second]:
            row["ownership"].update(status="claimed", writer_id="named-writer", owner_group="SOL347-owner",
                                    evidence=["CUSTODY"])
        self.valid()
        second["ownership"]["writer_id"] = "competing-writer"
        self.rejects("duplicate_writer")

    def test_same_writer_duplicate_scope_is_rejected(self):
        first, second = shared_pr(self.data)
        add_evidence(self.data, "CUSTODY", kind="ownership", result=None, scope=None, platforms=[])
        for row in [first, second]:
            row["ownership"].update(status="claimed", writer_id="named-writer", owner_group="one",
                                    evidence=["CUSTODY"])
        second["scope"] = first["scope"]
        self.rejects("duplicate_scope")

    def test_ownership_claim_needs_handover(self):
        self.row["ownership"].update(status="claimed", writer_id="writer", owner_group="group")
        self.rejects("ownership_authority")

    def test_collision_must_hold(self):
        add_evidence(self.data, "COLLISION", kind="ownership", result=None, scope=None, platforms=[])
        self.row["ownership"].update(status="collision", evidence=["COLLISION"])
        self.rejects("ownership_collision")
        self.row["delivery_stage"] = "coordination_hold"
        self.valid()


class SerializationAndCliTests(FixtureCase):
    def test_strict_yaml_negative_controls(self):
        cases = [
            "x: 1\nx: 2\n", "x: {y: 1, y: 2}\n", "x: &a [1]\ny: *a\n",
            "x: !!python/object/apply:os.system ['false']\n", "x: !!str 123\n",
            "x: [unterminated\n", "1: value\n", "x: 1\n---\ny: 2\n",
        ]
        for text in cases:
            with self.subTest(text=text):
                with self.assertRaises(ledger.LedgerError):
                    ledger.loads_ledger(text)

    def test_oversized_input_is_bounded(self):
        with self.assertRaises(ledger.LedgerError):
            ledger.loads_ledger(" " * (ledger.MAX_BYTES + 1))

    def test_deep_yaml_is_bounded(self):
        with self.assertRaises(ledger.LedgerError):
            ledger.loads_ledger("x: " + "[" * 50 + "1" + "]" * 50)

    def test_staleness_warns_without_mutating_status_or_render(self):
        before = deepcopy(self.data)
        first = ledger.render(self.data)
        result = ledger.validate(self.data, "2026-11-08T15:30:00Z")
        self.assertTrue(result.ok, result.errors)
        self.assertTrue(result.warnings)
        self.assertEqual(before, self.data)
        self.assertEqual(first, ledger.render(self.data))

    def test_bad_staleness_timestamp_is_diagnostic(self):
        self.assertFalse(ledger.validate(self.data, "yesterday").ok)
        self.assertFalse(ledger.validate(self.data, "2026-11-01T00:00:00Z").ok)

    def test_default_has_no_network_or_current_clock(self):
        class NoClock(datetime):
            @classmethod
            def now(cls, *args, **kwargs):
                raise AssertionError("wall-clock read")

            @classmethod
            def utcnow(cls):
                raise AssertionError("wall-clock read")

        with patch.object(ledger, "datetime", NoClock), patch.object(
                socket, "create_connection", side_effect=AssertionError("network call")):
            self.valid()
            ledger.render(self.data)

    def test_repeated_render_is_byte_identical(self):
        first = ledger.render(self.data)
        for _ in range(3):
            self.assertEqual(first, ledger.render(self.data))
        self.assertTrue(first.endswith("\n"))
        self.assertNotIn("\r", first)

    def test_stable_entity_order(self):
        first = ledger.render(self.data)
        for key in ["workstreams", "evidence", "pull_requests", "open_pr_inventory", "change_log"]:
            self.data[key].reverse()
        self.assertEqual(first, ledger.render(self.data))

    def test_markdown_injection_is_escaped(self):
        self.row["title"] = "Pipe | <script>bad</script> [x](javascript:bad)\n## Forged"
        text = ledger.render(self.data)
        self.assertIn(r"Pipe \| &lt;script&gt;bad&lt;/script&gt;", text)
        self.assertNotIn("<script>", text)
        self.assertNotIn("\n## Forged", text)
        self.assertNotIn("[x](javascript:bad)", text)
        self.assertNotIn("](https://github.com/x)(bad)", ledger.link("x", "https://github.com/x)(bad)"))

    def test_invalid_ledger_never_renders(self):
        self.row["delivery_stage"] = "finished"
        with self.assertRaises(ledger.LedgerError):
            ledger.render(self.data)

    def test_cli_roundtrip_and_check_are_nonmutating(self):
        with tempfile.TemporaryDirectory(prefix="active-ledger-test-") as tmp:
            inp, out = Path(tmp) / "ledger.yaml", Path(tmp) / "dashboard.md"
            inp.write_text(dump(self.data), encoding="utf-8")

            def run(command, *args):
                return subprocess.run([sys.executable, str(TOOL), command, "--ledger", str(inp),
                                       "--output", str(out), *args], cwd=tmp, capture_output=True, text=True)

            self.assertEqual(0, run("validate").returncode)
            self.assertEqual(0, run("render").returncode)
            before, mtime = out.read_bytes(), out.stat().st_mtime_ns
            self.assertEqual(0, run("check").returncode)
            self.assertEqual(before, out.read_bytes())
            self.assertEqual(mtime, out.stat().st_mtime_ns)
            out.write_bytes(before + b"unauthorized hand edit\n")
            tampered, mtime = out.read_bytes(), out.stat().st_mtime_ns
            self.assertEqual(1, run("check").returncode)
            self.assertEqual(tampered, out.read_bytes())
            self.assertEqual(mtime, out.stat().st_mtime_ns)
            self.assertEqual(0, run("render").returncode)
            self.assertEqual(before, out.read_bytes())
            self.assertEqual(0, run("summary").returncode)
            self.assertEqual(2, run("render", "--as-of", NOW).returncode)

    def test_cli_malformed_yaml_returns_error_without_traceback(self):
        with tempfile.TemporaryDirectory(prefix="active-ledger-test-") as tmp:
            path = Path(tmp) / "bad.yaml"
            path.write_text("x: [unterminated\n")
            result = subprocess.run([sys.executable, str(TOOL), "validate", "--ledger", str(path)],
                                    capture_output=True, text=True)
            self.assertEqual(1, result.returncode)
            self.assertNotIn("Traceback", result.stderr)

    def test_canonical_output_cannot_overwrite_yaml(self):
        with tempfile.TemporaryDirectory(prefix="active-ledger-test-") as tmp:
            inp = Path(tmp) / "ledger.yaml"
            inp.write_text(dump(self.data), encoding="utf-8")
            before = inp.read_bytes()
            result = subprocess.run([sys.executable, str(TOOL), "render", "--ledger", str(inp), "--output", str(inp)],
                                    capture_output=True, text=True)
            self.assertEqual(1, result.returncode)
            self.assertEqual(before, inp.read_bytes())

    def test_malformed_container_shapes_report_errors(self):
        for field in ["snapshot", "evidence", "pull_requests", "open_pr_inventory", "workstreams", "change_log"]:
            for value in [None, True, "wrong"]:
                with self.subTest(field=field, value=value):
                    data = fresh()
                    data[field] = value
                    self.assertFalse(ledger.validate(data).ok)

    def test_invalid_nested_types_produce_diagnostics_not_tracebacks(self):
        # Sweep real safety-field paths in positive, ready, physical and stack
        # fixtures; this catches unhashable enums before the CLI can crash.
        fixtures = [fresh() for _ in range(4)]
        ready(fixtures[1])
        physical_no_go(fixtures[2])
        add_pr(fixtures[3], 383, "IN361-DRAIN", "docs/example")
        stream(fixtures[3], "IN361-DRAIN")["dependencies"] = [
            {"id": "IN361-ADMISSION", "type": "stacked", "reason": "Declared actual stack."}]
        for fixture in fixtures:
            paths = []

            def collect(obj, path):
                if isinstance(obj, dict):
                    for key, value in obj.items():
                        paths.append(path + [key])
                        collect(value, path + [key])
                elif isinstance(obj, list):
                    for i, value in enumerate(obj[:1]):
                        collect(value, path + [i])

            collect(fixture, [])
            for path in paths:
                for value in [None, True, "bad", [], {}]:
                    with self.subTest(path=path, value=value):
                        data = deepcopy(fixture)
                        at = data
                        for key in path[:-1]:
                            at = at[key]
                        at[path[-1]] = value
                        result = ledger.validate(data)
                        self.assertIsInstance(result, ledger.ValidationResult)


if __name__ == "__main__":
    unittest.main()
