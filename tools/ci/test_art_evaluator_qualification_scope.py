"""Fail-closed boundaries for reusing the fixed Art application qualification.

All API responses and ZIPs are synthetic. No network or Godot process is used.
"""
from __future__ import annotations

import copy
from contextlib import ExitStack, redirect_stdout
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError
import warnings
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import art_evaluator_qualification_scope as scope
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_art_workbench_final as package_tool


BASELINE_HEAD = "981a740828decbeac04d5a14511d0222095de0a9"
BASELINE_TREE = "9e37f6c4113e51b7aa9969bd7f3cc726405467bf"
RUN_ID = 45482969231
ARTIFACT_DIGESTS = {
    "linux": "4b0d1a3f318580f5a3224e4687c4362e2b49a11b893e862c90b7741dff490940",
    "windows": "9c9664683bd492522521a1e05ad0cfab1d6ad400e0ddc2010453073494b0f63d",
}


def run_record() -> dict:
    return {
        "id": RUN_ID,
        "head_sha": BASELINE_HEAD,
        "repository": {"full_name": "techrote/cybersand"},
        "path": ".github/workflows/art-session-logging.yml",
        "status": "completed",
        "conclusion": "failure",
    }


def job_record(platform: str) -> dict:
    expected = scope.PLATFORMS[platform]
    steps = [{"name": name, "status": "completed", "conclusion": "success"}
             for name in expected["application_steps"]]
    if platform == "windows":
        steps.extend([
            {"name": "Package exact source with retained Windows runtime",
             "status": "completed", "conclusion": "failure"},
            {"name": "Exercise actual delivered launcher from an extracted installation",
             "status": "completed", "conclusion": "skipped"},
        ])
    return {
        "id": expected["job_id"], "run_id": RUN_ID, "head_sha": BASELINE_HEAD,
        "name": expected["job_name"], "status": "completed",
        "conclusion": "success" if platform == "linux" else "failure", "steps": steps,
    }


def artifact_record(platform: str) -> dict:
    expected = scope.PLATFORMS[platform]
    return {
        "id": expected["artifact_id"], "name": expected["artifact_name"],
        "digest": "sha256:" + expected["artifact_sha256"], "expired": False,
        "workflow_run": {"id": RUN_ID, "head_sha": BASELINE_HEAD},
        "size_in_bytes": 1234,
    }


def artifact_members(platform: str) -> dict[str, bytes]:
    """Small receipt-only ZIP, with no real response body or private profile."""
    expected = scope.PLATFORMS[platform]
    members = {}
    for group, (checks, cases) in scope.expected_groups(platform).items():
        report = {
            "checks": checks, "cases": [{"case": "synthetic", "frames": {"max_usec": 1000}}
                                        for _ in range(cases)],
            "failures": [], "unavailable": [],
            "godot": "4.7-stable (official)", "os": expected["os"],
            "display": expected["display"] if "-displayed-" in group else "headless",
            "completion_phase": "completed",
        }
        if group.endswith(("process-exit", "request-exit")):
            report["completion_phase"] = "process_exit_requested_before_tree_teardown"
            report["process_exit"] = {"exit_code": 0, "preparation_active_at_request": True,
                                      "pending_jobs_at_request": 1, "seconds_after_request": 0.01}
        bodies = [{"fixture": fixture, "complete_redacted_body": True, "bytes": 1024,
                   "sha256": "a" * 64}
                  for fixture in sorted(scope.BODY_FIXTURES.get(group.split("-", 3)[-1], set()))]
        conversations = []
        if group.endswith("conversation-apply"):
            conversations = [{"bytes": 16769024,
                              "sha256": "ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a",
                              "complete_changed_conversation": True, "model_requests": 0}]
        records = {
            "provenance.json": {
                "source": {"head": BASELINE_HEAD, "tree": BASELINE_TREE, "changed_paths": [],
                           "diff_sha256": hashlib.sha256(b"").hexdigest()},
                "godot": {"sha256": expected["godot_sha256"]},
                "native": {"sha256": expected["native_sha256"]},
                "harness": {"sha256": scope.HARNESS_SHA256},
                "driver": {"sha256": scope.DRIVER_SHA256},
            },
            "execution.json": {"exit_code": 0, "timed_out": False},
            "report.json": report,
            "audit-verification.json": {"credential_redacted": True, "archives": 1,
                                        "complete_bodies": bodies, "complete_conversations": conversations},
        }
        for name, record in records.items():
            members[group + "/" + name] = json.dumps(record, sort_keys=True).encode()
    refresh_hashes(members)
    return members


def refresh_hashes(members: dict[str, bytes]) -> None:
    for group in {name.rsplit("/", 1)[0] for name in members}:
        hashes = {name.rsplit("/", 1)[1]: hashlib.sha256(data).hexdigest()
                  for name, data in members.items()
                  if name.startswith(group + "/") and not name.endswith("/hashes.json")}
        members[group + "/hashes.json"] = json.dumps(hashes, sort_keys=True).encode()


def mutate_record(members: dict[str, bytes], name: str, change) -> None:
    record = json.loads(members[name]); change(record)
    members[name] = json.dumps(record, sort_keys=True).encode()


def write_zip(path: Path, members: dict[str, bytes], duplicate: str | None = None) -> str:
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(members.items()):
            archive.writestr(name, data)
        if duplicate is not None:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                archive.writestr(duplicate, members[duplicate])
    return hashlib.sha256(path.read_bytes()).hexdigest()


class FakeAPI:
    def __init__(self, archives: dict[str, Path]):
        self.archives = archives
        self.calls = []
        prefix = "/repos/techrote/cybersand/actions"
        self.records = {f"{prefix}/runs/{RUN_ID}": run_record()}
        for platform, expected in scope.PLATFORMS.items():
            self.records[f"{prefix}/jobs/{expected['job_id']}"] = job_record(platform)
            metadata = artifact_record(platform)
            metadata["size_in_bytes"] = archives[platform].stat().st_size
            self.records[f"{prefix}/artifacts/{expected['artifact_id']}"] = metadata

    def json(self, path: str) -> dict:
        self.calls.append(path)
        if path not in self.records:
            raise ValueError("Synthetic API proof is missing")
        return copy.deepcopy(self.records[path])

    def download(self, platform: str, destination: Path) -> None:
        self.calls.append("download:" + platform)
        shutil.copyfile(self.archives[platform], destination)


class QualificationScope(unittest.TestCase):
    def test_trust_anchor_is_the_retained_981_run(self):
        self.assertEqual(scope.BASELINE_HEAD, BASELINE_HEAD)
        self.assertEqual(scope.BASELINE_TREE, BASELINE_TREE)
        self.assertEqual(scope.RUN_ID, RUN_ID)
        for platform, digest in ARTIFACT_DIGESTS.items():
            self.assertEqual(scope.PLATFORMS[platform]["artifact_sha256"], digest)

    def test_workflow_only_change_is_eligible_but_is_not_proof(self):
        decision = scope.decide_scope(
            [".github/workflows/art-session-logging.yml"],
            head="1" * 40, tree="2" * 40, baseline_ancestor=True)
        self.assertFalse(decision.get("reuse", False))
        self.assertTrue(decision["eligible_pending_proof"])

    def test_application_native_and_unknown_changes_never_reuse(self):
        for path in (
            "godot/scripts/art_provider.gd", "godot/project.godot",
            "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
            "godot/tests/test_art_panel_ui.gd", "examples/worldgen/custom.json",
            "tools/unknown_dependency.py", "docs/unknown-guide.md",
            ".github/workflows/art-session-logging.yml.extra",
        ):
            with self.subTest(path=path):
                decision = scope.decide_scope(
                    [path], head="1" * 40, tree="2" * 40, baseline_ancestor=True)
                self.assertFalse(decision.get("reuse", False))
                self.assertFalse(decision.get("eligible_pending_proof", False))

    def test_validated_history_cannot_be_replaced_by_unrelated_ancestry(self):
        try:
            decision = scope.decide_scope(
                [".github/workflows/art-session-logging.yml"],
                head="1" * 40, tree="2" * 40, baseline_ancestor=False)
        except ValueError:
            return
        self.assertFalse(decision.get("reuse", False))
        self.assertFalse(decision.get("eligible_pending_proof", False))


class PriorRunProof(unittest.TestCase):
    def test_fixed_completed_run_and_both_application_jobs_are_accepted(self):
        scope.validate_run(run_record())
        for platform in ("linux", "windows"):
            scope.validate_job(platform, job_record(platform))
            scope.validate_artifact_metadata(platform, artifact_record(platform))

    def test_wrong_run_source_repository_workflow_or_lifecycle_is_rejected(self):
        replacements = {
            "id": RUN_ID + 1, "head_sha": "0" * 40,
            "repository": {"full_name": "elsewhere/cybersand"},
            "path": ".github/workflows/unrelated.yml", "status": "in_progress",
            "conclusion": "success",
        }
        for field, value in replacements.items():
            with self.subTest(field=field):
                record = run_record(); record[field] = value
                with self.assertRaises(ValueError):
                    scope.validate_run(record)

    def test_windows_job_success_does_not_substitute_for_recorded_partial_result(self):
        record = job_record("windows"); record["conclusion"] = "success"
        with self.assertRaises(ValueError):
            scope.validate_job("windows", record)

    def test_missing_duplicate_or_failed_named_application_step_is_rejected(self):
        for platform in ("linux", "windows"):
            for mutation in ("missing", "duplicate", "failed", "skipped"):
                with self.subTest(platform=platform, mutation=mutation):
                    record = job_record(platform)
                    if mutation == "missing": record["steps"].pop(0)
                    elif mutation == "duplicate": record["steps"].append(copy.deepcopy(record["steps"][0]))
                    else: record["steps"][0]["conclusion"] = mutation
                    with self.assertRaises(ValueError):
                        scope.validate_job(platform, record)

    def test_job_identity_must_match_fixed_run_and_platform(self):
        for field, value in (("id", 1), ("run_id", 2), ("head_sha", "0" * 40),
                             ("name", "another job"), ("status", "queued")):
            with self.subTest(field=field):
                record = job_record("windows"); record[field] = value
                with self.assertRaises(ValueError):
                    scope.validate_job("windows", record)

    def test_missing_expired_or_mismatched_artifact_metadata_is_rejected(self):
        mutations = (
            ("id", 1), ("name", "other-artifact"), ("digest", "sha256:" + "0" * 64),
            ("expired", True), ("workflow_run", {"id": RUN_ID + 1, "head_sha": BASELINE_HEAD}),
            ("workflow_run", {"id": RUN_ID, "head_sha": "0" * 40}),
        )
        for field, value in mutations:
            with self.subTest(field=field, value=value):
                record = artifact_record("windows"); record[field] = value
                with self.assertRaises(ValueError):
                    scope.validate_artifact_metadata("windows", record)
        with self.assertRaises(ValueError):
            scope.validate_artifact_metadata("windows", {})


class ArchiveProof(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def verify(self, members: dict[str, bytes], platform: str = "windows", *, duplicate=None):
        archive = self.root / (platform + ".zip")
        digest = write_zip(archive, members, duplicate)
        # The synthetic ZIP receives its own test trust anchor. Every other
        # fixed source/runtime/job condition remains the production condition.
        with patch.dict(scope.PLATFORMS[platform], artifact_sha256=digest):
            return scope.verify_artifact(platform, archive)

    def test_complete_small_fixture_proves_twelve_groups_for_each_platform(self):
        for platform in ("linux", "windows"):
            with self.subTest(platform=platform):
                proof = self.verify(artifact_members(platform), platform)
                self.assertEqual(len(proof["groups"]), 12)

    def test_missing_group_receipt_or_duplicate_member_is_rejected(self):
        for mutation in ("group", "receipt", "duplicate"):
            with self.subTest(mutation=mutation):
                members = artifact_members("windows")
                group = "art-final-displayed-network/"
                duplicate = None
                if mutation == "group":
                    members = {k: v for k, v in members.items() if not k.startswith(group)}
                elif mutation == "receipt":
                    del members[group + "audit-verification.json"]
                else:
                    duplicate = group + "report.json"
                with self.assertRaises(ValueError):
                    self.verify(members, duplicate=duplicate)

    def test_changed_inner_proof_fails_even_with_fresh_archive_and_receipt_hashes(self):
        network = "art-final-displayed-network/"
        mutations = [
            ("source head", network + "provenance.json", lambda d: d["source"].update(head="0" * 40)),
            ("source tree", network + "provenance.json", lambda d: d["source"].update(tree="0" * 40)),
            ("dirty source", network + "provenance.json", lambda d: d["source"].update(changed_paths=["godot/project.godot"])),
            ("driver", network + "provenance.json", lambda d: d["driver"].update(sha256="0" * 64)),
            ("native", network + "provenance.json", lambda d: d["native"].update(sha256="0" * 64)),
            ("exit", network + "execution.json", lambda d: d.update(exit_code=1)),
            ("timeout", network + "execution.json", lambda d: d.update(timed_out=True)),
            ("cleanup", network + "execution.json", lambda d: d.update(cleanup_error="synthetic failure")),
            ("assertion", network + "report.json", lambda d: d.update(failures=["synthetic failure"])),
            ("missing checks", network + "report.json", lambda d: d.update(checks=0)),
            ("unavailable", network + "report.json", lambda d: d.update(unavailable=["skipped input"])),
            ("partial", network + "report.json", lambda d: d.update(completion_phase="started")),
            ("slow frame", network + "report.json", lambda d: d["cases"][0]["frames"].update(max_usec=2000000)),
            ("privacy", network + "audit-verification.json", lambda d: d.update(credential_redacted=False)),
            ("incomplete body", network + "audit-verification.json", lambda d: d["complete_bodies"][0].update(complete_redacted_body=False)),
            ("changed conversation", "art-final-displayed-conversation-apply/audit-verification.json",
             lambda d: d["complete_conversations"][0].update(sha256="0" * 64)),
            ("no actual active exit", "art-final-process-exit/report.json",
             lambda d: d["process_exit"].update(preparation_active_at_request=False)),
        ]
        for label, member, change in mutations:
            with self.subTest(boundary=label):
                members = artifact_members("windows")
                mutate_record(members, member, change)
                refresh_hashes(members)
                with self.assertRaises(ValueError):
                    self.verify(members)

    def test_stale_receipt_hash_and_wrong_download_digest_are_rejected(self):
        members = artifact_members("windows")
        mutate_record(members, "art-final-displayed-network/report.json",
                      lambda d: d.update(extra="changed after inventory"))
        with self.assertRaisesRegex(ValueError, "receipt hash"):
            self.verify(members)
        archive = self.root / "wrong-download.zip"
        write_zip(archive, artifact_members("windows"))
        with self.assertRaisesRegex(ValueError, "digest"):
            scope.verify_artifact("windows", archive)


class ProofIntegration(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.archives = {}
        for platform in ("linux", "windows"):
            archive = self.root / (platform + ".zip")
            digest = write_zip(archive, artifact_members(platform))
            self.stack.enter_context(patch.dict(scope.PLATFORMS[platform], artifact_sha256=digest))
            self.archives[platform] = archive
        self.decision = scope.decide_scope(
            [".github/workflows/art-session-logging.yml"], head="1" * 40, tree="2" * 40)
        self.decision.update(protected_tree_ids=dict(scope.PROTECTED_TREE_IDS),
                             all_other_paths_unchanged=True,
                             tracked_tree_clean=True, source_inputs_clean=True)
        self.stack.enter_context(patch.object(
            scope, "inspect_scope", side_effect=lambda _root: copy.deepcopy(self.decision)))

    def test_reuse_requires_both_job_artifact_and_receipt_proofs(self):
        api = FakeAPI(self.archives)
        output = self.root / "proof.json"
        result = scope.qualify(self.root, output, api_client=api)
        self.assertTrue(result["reuse"])
        self.assertEqual(result["mode"], "reuse_verified")
        self.assertEqual(result["application_source_commit"], BASELINE_HEAD)
        self.assertEqual(set(result["platforms"]), {"linux", "windows"})
        self.assertEqual(result["platforms"]["windows"]["job"]["overall_conclusion"], "failure")
        self.assertEqual(json.loads(output.read_text()), result)

    def test_missing_or_mis_sized_download_never_admits_reuse(self):
        for mutation in ("missing metadata", "wrong size", "changed download"):
            with self.subTest(mutation=mutation):
                api = FakeAPI(self.archives)
                key = f"/repos/techrote/cybersand/actions/artifacts/{scope.PLATFORMS['windows']['artifact_id']}"
                if mutation == "missing metadata": del api.records[key]
                elif mutation == "wrong size": api.records[key]["size_in_bytes"] += 1
                else:
                    altered = self.root / "altered.zip"
                    altered.write_bytes(self.archives["windows"].read_bytes() + b"changed")
                    api.archives = {**self.archives, "windows": altered}
                    api.records[key]["size_in_bytes"] = altered.stat().st_size
                output = self.root / (mutation.replace(" ", "-") + ".json")
                with self.assertRaises(ValueError):
                    scope.qualify(self.root, output, api_client=api)
                self.assertFalse(output.exists())

    def test_offline_scope_cli_never_claims_reuse_or_opens_api(self):
        output = self.root / "scope-only.json"
        github_output = self.root / "github-output.txt"
        with patch.object(sys, "argv", ["scope", "--root", str(self.root), "--output", str(output),
                                        "--check-scope-only"]), \
                patch.dict(os.environ, {"GITHUB_OUTPUT": str(github_output)}), \
                patch.object(scope, "GitHubClient", side_effect=AssertionError("No API in offline scope mode")), \
                redirect_stdout(io.StringIO()):
            self.assertEqual(scope.main(), 0)
        result = json.loads(output.read_text())
        self.assertFalse(result["reuse"])
        self.assertTrue(result["eligible_pending_proof"])
        self.assertIsNone(result["application_source_commit"])
        self.assertEqual(github_output.read_text(), "reuse=false\n")

    def test_failed_cli_proof_emits_no_success_output(self):
        output = self.root / "failed-proof.json"
        github_output = self.root / "failed-output.txt"
        with patch.object(sys, "argv", ["scope", "--root", str(self.root), "--output", str(output)]), \
                patch.dict(os.environ, {"GITHUB_OUTPUT": str(github_output)}), \
                patch.object(scope, "GitHubClient", side_effect=ValueError("Missing synthetic proof")), \
                redirect_stdout(io.StringIO()):
            self.assertEqual(scope.main(), 1)
        self.assertFalse(json.loads(output.read_text())["reuse"])
        self.assertFalse(github_output.exists())

    def test_packager_binds_completed_proof_to_current_candidate(self):
        path = self.root / "package-proof.json"
        proof = scope.qualify(self.root, path, api_client=FakeAPI(self.archives))
        self.assertEqual(package_tool.qualification_source(path, "1" * 40, "2" * 40), proof)
        for field, value in (("candidate_source_commit", "0" * 40),
                             ("candidate_source_tree", "0" * 40),
                             ("mode", "scope_only"), ("mode", "failed"),
                             ("reuse", "true"), ("application_source_commit", None)):
            with self.subTest(field=field, value=value):
                bad = copy.deepcopy(proof); bad[field] = value
                path.write_text(json.dumps(bad))
                with self.assertRaises(ValueError):
                    package_tool.qualification_source(path, "1" * 40, "2" * 40)

    def test_packager_rejects_a_forged_completed_reuse_decision(self):
        path = self.root / "forged-proof.json"
        proof = scope.qualify(self.root, path, api_client=FakeAPI(self.archives))
        mutations = (
            ("wrong application head", lambda d: d.update(application_source_commit="0" * 40)),
            ("wrong application tree", lambda d: d.update(application_source_tree="0" * 40)),
            ("missing prior run", lambda d: d.pop("prior_run")),
            ("missing platform", lambda d: d["platforms"].pop("windows")),
            ("missing artifact", lambda d: d["platforms"]["windows"].pop("artifact")),
            ("missing application job proof", lambda d: d["platforms"]["windows"]["job"].pop("application_steps")),
            ("missing group", lambda d: d["platforms"]["windows"]["application_receipts"]["groups"].pop("art-final-displayed-network")),
            ("wrong protected tree", lambda d: d["protected_tree_ids"].update(godot="0" * 40)),
            ("pending scope", lambda d: d.update(eligible_pending_proof=True)),
        )
        for label, mutate in mutations:
            with self.subTest(boundary=label):
                bad = copy.deepcopy(proof); mutate(bad)
                path.write_text(json.dumps(bad))
                with self.assertRaises(ValueError):
                    package_tool.qualification_source(path, "1" * 40, "2" * 40)

    def test_full_required_decision_cannot_claim_reuse_or_hide_eligible_scope(self):
        path = self.root / "full-decision.json"
        full = scope.decide_scope(["godot/scripts/changed.gd"], head="1" * 40, tree="2" * 40)
        path.write_text(json.dumps(full))
        # A supplied full_required decision must match the current local scope.
        with self.assertRaises(ValueError):
            package_tool.qualification_source(path, "1" * 40, "2" * 40)
        with patch.object(scope, "inspect_scope", side_effect=lambda _root: copy.deepcopy(full)):
            self.assertEqual(package_tool.qualification_source(path, "1" * 40, "2" * 40), full)
            for field, value in (("reuse", True), ("application_source_commit", BASELINE_HEAD),
                                 ("offline_scope_only", True)):
                with self.subTest(field=field):
                    forged = copy.deepcopy(full); forged[field] = value
                    path.write_text(json.dumps(forged))
                    with self.assertRaises(ValueError):
                        package_tool.qualification_source(path, "1" * 40, "2" * 40)


class CommittedSourceBoundary(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for directory in ("godot", "native", "examples", "third_party"):
            (self.root / directory).mkdir()
            (self.root / directory / "source.txt").write_text("unchanged application input\n")
        self.workflow = self.root / ".github/workflows/art-session-logging.yml"
        self.workflow.parent.mkdir(parents=True)
        self.workflow.write_text("name: initial\n")
        self.git("init", "-q")
        self.commit()
        head, tree = self.git("rev-parse", "HEAD"), self.git("rev-parse", "HEAD^{tree}")
        self.stack = ExitStack(); self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(scope, "BASELINE_HEAD", head))
        self.stack.enter_context(patch.object(scope, "BASELINE_TREE", tree))
        self.workflow.write_text("name: reviewed packaging-only change\n")
        self.commit()

    def git(self, *args: str) -> str:
        return subprocess.check_output(["git", *args], cwd=self.root, text=True,
                                       stderr=subprocess.DEVNULL).strip()

    def commit(self):
        self.git("add", ".")
        self.git("-c", "user.name=Art fixture", "-c", "user.email=fixture@invalid",
                 "commit", "-qm", "synthetic fixture")

    def test_committed_workflow_only_change_keeps_protected_trees_identical(self):
        decision = scope.inspect_scope(self.root)
        self.assertTrue(decision["eligible_pending_proof"])
        self.assertFalse(decision["reuse"])
        self.assertEqual(set(decision["protected_tree_ids"]), {"godot", "native", "examples", "third_party"})

    def test_untracked_importable_tool_is_not_hidden_by_allowlisted_commit(self):
        path = self.root / "tools/shadow.py"; path.parent.mkdir()
        path.write_text("MUST_NOT_ATTEST = True\n")
        with self.assertRaises(ValueError):
            scope.inspect_scope(self.root)

    def test_generated_evidence_is_allowed_but_importable_root_or_action_shadow_is_not(self):
        evidence = self.root / "evidence/proof.json"; evidence.parent.mkdir()
        evidence.write_text('{"synthetic_generated_evidence": true}\n')
        self.assertTrue(scope.inspect_scope(self.root)["eligible_pending_proof"])
        for relative in ("json.py", ".github/actions/shadow.py"):
            with self.subTest(path=relative):
                path = self.root / relative; path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("MUST_NOT_ATTEST = True\n")
                with self.assertRaises(ValueError):
                    scope.inspect_scope(self.root)
                path.unlink()

    def test_uncommitted_application_change_blocks_eligible_committed_scope(self):
        (self.root / "godot/source.txt").write_text("uncommitted application change\n")
        with self.assertRaises(ValueError):
            scope.inspect_scope(self.root)

    def test_protected_rename_cannot_hide_behind_allowed_destination(self):
        target = self.root / "tools/package_art_workbench_final.py"; target.parent.mkdir()
        (self.root / "godot/source.txt").rename(target)
        self.commit()
        result = scope.inspect_scope(self.root)
        self.assertFalse(result["eligible_pending_proof"])
        self.assertIn("godot/source.txt", result["outside_packaging_allowlist"])

    def test_protected_mode_change_is_an_application_change(self):
        self.git("update-index", "--chmod=+x", "godot/source.txt")
        self.git("-c", "user.name=Art fixture", "-c", "user.email=fixture@invalid",
                 "commit", "-qm", "synthetic mode change")
        result = scope.inspect_scope(self.root)
        self.assertFalse(result["eligible_pending_proof"])
        self.assertIn("godot/source.txt", result["outside_packaging_allowlist"])

    def test_leading_space_in_git_path_does_not_become_an_allowlisted_path(self):
        relative = " .github/workflows/art-session-logging.yml"
        path = self.root / relative; path.parent.mkdir(parents=True)
        path.write_text("unrelated source, not the workflow\n")
        self.commit()
        result = scope.inspect_scope(self.root)
        self.assertFalse(result["eligible_pending_proof"])
        self.assertIn(relative, result["outside_packaging_allowlist"])


class DownloadCredentialBoundary(unittest.TestCase):
    def test_object_redirect_uses_a_new_request_without_api_authorization(self):
        client = scope.GitHubClient("SYNTHETIC-API-TOKEN")
        location = "https://fixture.blob.core.windows.net/artifact.zip?sig=SYNTHETIC"
        client.api_opener = Mock()
        client.api_opener.open.side_effect = HTTPError(
            "https://api.github.com/synthetic", 302, "redirect", {"Location": location}, None)
        client.object_opener = Mock()
        client.object_opener.open.return_value = io.BytesIO(b"synthetic archive bytes")
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "download.zip"
            client.download("windows", target)
            self.assertEqual(target.read_bytes(), b"synthetic archive bytes")
        authenticated = client.api_opener.open.call_args.args[0]
        redirected = client.object_opener.open.call_args.args[0]
        self.assertEqual(authenticated.get_header("Authorization"), "Bearer SYNTHETIC-API-TOKEN")
        self.assertEqual(redirected.full_url, location)
        self.assertIsNone(redirected.get_header("Authorization"))
        self.assertIsNone(redirected.get_header("Referer"))

    def test_insecure_or_unapproved_redirect_is_refused_before_object_access(self):
        for location in ("http://fixture.blob.core.windows.net/archive.zip",
                         "https://untrusted.invalid/archive.zip",
                         "https://user:secret@fixture.blob.core.windows.net/archive.zip"):
            with self.subTest(location=location), tempfile.TemporaryDirectory() as temporary:
                client = scope.GitHubClient("SYNTHETIC-API-TOKEN")
                client.api_opener = Mock()
                client.api_opener.open.side_effect = HTTPError(
                    "https://api.github.com/synthetic", 302, "redirect", {"Location": location}, None)
                client.object_opener = Mock()
                with self.assertRaises(ValueError):
                    client.download("windows", Path(temporary) / "download.zip")
                client.object_opener.open.assert_not_called()


if __name__ == "__main__":
    unittest.main()
