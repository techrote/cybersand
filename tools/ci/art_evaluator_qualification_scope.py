#!/usr/bin/env python3
"""Reuse fixed Art application evidence only across reviewed packaging changes.

The prior Windows job failed at packaging. Its successful application step and
immutable evidence are reusable; that overall failure is never called success.
Every successor still needs a fresh package, extracted launcher and module check.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import zipfile

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = "techrote/cybersand"
BASELINE_HEAD = "981a740828decbeac04d5a14511d0222095de0a9"
BASELINE_TREE = "9e37f6c4113e51b7aa9969bd7f3cc726405467bf"
RUN_ID = 45482969231
SCHEMA = "art-evaluator-application-qualification-v1"
WORKFLOW = ".github/workflows/art-session-logging.yml"
ALLOWED_PATHS = frozenset({
    WORKFLOW,
    "tools/package_art_workbench_final.py",
    "tools/ci/test_art_evaluator_packaging.py",
    "tools/ci/art_evaluator_qualification_scope.py",
    "tools/ci/test_art_evaluator_qualification_scope.py",
    "docs/operations/art-workbench-final-evaluation.md",
    "docs/audits/2026-11-24-art-workbench-final/README.md",
})
HARNESS_SHA256 = "3e100d226071b2e61707f4a0e399a84dcfcbb7283f90ae724669654b44b4757e"
DRIVER_SHA256 = "c9e0d7bb724ae684e2508517cf8da323ea5623388635fccef101351425f480bb"
EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()
CHANGED_CONVERSATION_SHA256 = "ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a"
PROTECTED_TREE_IDS = {
    "godot": "781c07b1ff47bda3ff569ff23f0dfcb1e55e10a2",
    "native": "e6946f5c5d47eddd6118696b124470737cdd385e",
    "examples": "a1a1118e18ebfa579143c4d259a75604e08d6cbc",
    "third_party": "01a8de3cd15508c37d2949aedf81a6364e2c8b32",
}
COMMON_STEPS = ("Checkout exact source", "Materialize source-matched native runtime",
                "Authenticate official Godot 4.7")
PACKAGE_STEP = "Package exact source with retained Windows runtime"
INSTALLED_STEP = "Exercise actual delivered launcher from an extracted installation"
PLATFORMS = {
    "linux": {
        "job_id": 138760715387, "artifact_id": 14962717516,
        "artifact_sha256": "4b0d1a3f318580f5a3224e4687c4362e2b49a11b893e862c90b7741dff490940",
        "artifact_name": "art-workbench-linux-" + BASELINE_HEAD,
        "job_name": "Linux 4.7 native and displayed Art Workbench",
        "application_steps": COMMON_STEPS + ("Import exact project", "Execute session isolation and native regressions",
                                               "Exercise displayed Godot UI and native authoring"),
        "overall_conclusion": "success",
        "godot_sha256": "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75",
        "native_sha256": "a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7",
        "display": "X11", "os": "Linux",
    },
    "windows": {
        "job_id": 138760714899, "artifact_id": 14964552939,
        "artifact_sha256": "9c9664683bd492522521a1e05ad0cfab1d6ad400e0ddc2010453073494b0f63d",
        "artifact_name": "art-workbench-windows-evidence-" + BASELINE_HEAD,
        "job_name": "Windows 4.7 displayed Art and installed evaluator",
        "application_steps": COMMON_STEPS + ("Import and execute fresh user-data Workbench tests",),
        "overall_conclusion": "failure",
        "godot_sha256": "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c",
        "native_sha256": "668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e",
        "display": "Windows", "os": "Windows",
    },
}
BODY_FIXTURES = {
    "network": {"fixture-large", "fixture-large-envelope-error", "fixture-large-error",
                "fixture-malicious-usage", "fixture-near-limit", "fixture-secret-boundary"},
    "preparation": {"fixture-large-assistant", "fixture-preparation-hide"},
}
MAX_ARCHIVE_BYTES = 32 * 1024 * 1024
MAX_JSON_BYTES = 2 * 1024 * 1024


class QualificationError(ValueError):
    """An intentionally safe diagnostic, containing no response URL or token."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise QualificationError(message)


def expected_groups(platform: str) -> dict[str, tuple[int, int]]:
    """Exact counts in these fixed artifacts, including conditional observations."""
    groups = {}
    for mode in ("headless", "displayed"):
        counts = {"network": (568 if platform == "windows" and mode == "displayed" else 569, 31),
                  "preparation": (94 if platform == "linux" and mode == "displayed" else 96, 3),
                  "request-preparation": (125, 4), "lifecycle": (92, 2),
                  "conversation-apply": (22 if mode == "headless" else 23, 1)}
        groups.update({f"art-final-{mode}-{name}": value for name, value in counts.items()})
    groups.update({"art-final-process-exit": (11, 0), "art-final-request-exit": (13, 0)})
    return groups


def decide_scope(changed_paths: list[str], *, head: str, tree: str,
                 baseline_ancestor: bool = True) -> dict:
    require(bool(re.fullmatch(r"[0-9a-f]{40}", head)), "Invalid candidate commit identity")
    require(bool(re.fullmatch(r"[0-9a-f]{40}", tree)), "Invalid candidate tree identity")
    paths = sorted(set(changed_paths))
    outside = [path for path in paths if path not in ALLOWED_PATHS]
    eligible = baseline_ancestor and not outside
    return {
        "schema": SCHEMA, "candidate_source_commit": head, "candidate_source_tree": tree,
        "reuse": False, "mode": "scope_only" if eligible else "full_required",
        "eligible_pending_proof": eligible,
        "application_source_commit": None, "application_source_tree": None,
        "baseline": {"source_commit": BASELINE_HEAD, "source_tree": BASELINE_TREE, "run_id": RUN_ID,
                     "repository": REPOSITORY},
        "baseline_ancestor": baseline_ancestor, "changed_paths": paths,
        "outside_packaging_allowlist": outside,
        "reason": ("Packaging-only scope; prior application proof is still required" if eligible else
                   "Application or other protected source changed" if outside else
                   "Pinned application baseline is not an ancestor"),
        "package_acceptance": "Not established by this proof; fresh build, extracted launcher and module checks remain required",
    }


def _git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=root, text=True,
                                   stderr=subprocess.DEVNULL, timeout=60).strip()


def inspect_scope(root: Path) -> dict:
    head, tree = _git(root, "rev-parse", "HEAD"), _git(root, "rev-parse", "HEAD^{tree}")
    ancestry = subprocess.run(["git", "merge-base", "--is-ancestor", BASELINE_HEAD, head],
                              cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
    if ancestry.returncode != 0:
        return decide_scope([], head=head, tree=tree, baseline_ancestor=False)
    require(_git(root, "rev-parse", BASELINE_HEAD + "^{tree}") == BASELINE_TREE,
            "Pinned baseline tree mismatch")
    # No rename similarity heuristic: both sides of a move must be allowed.
    # Preserve whitespace in filenames. Stripping this NUL-delimited output
    # could turn an unknown leading-space filename into an allowed path.
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", "--no-renames", "-z", BASELINE_HEAD, head],
        cwd=root, text=True, stderr=subprocess.DEVNULL, timeout=60)
    result = decide_scope([p for p in changed.split("\0") if p], head=head, tree=tree)
    if result["eligible_pending_proof"]:
        require(not _git(root, "status", "--porcelain=v1", "--untracked-files=no"),
                "Commit tracked changes before reusing application qualification")
        # Only generated reports under this literal root directory are exempt.
        # A root Python file or a new local action can shadow an imported tool,
        # so reject other untracked paths even outside established source roots.
        status = subprocess.check_output(
            ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
            cwd=root, text=True, stderr=subprocess.DEVNULL, timeout=60)
        require(all(line.startswith("?? evidence/") for line in status.split("\0") if line),
                "Commit or remove untracked inputs before reusing application qualification")
        protected = ("godot", "native", "examples", "third_party")
        trees = {path: _git(root, "rev-parse", head + ":" + path) for path in protected}
        require(all(oid == _git(root, "rev-parse", BASELINE_HEAD + ":" + path)
                    for path, oid in trees.items()), "Protected application trees differ")
        result["protected_tree_ids"] = trees
        result["all_other_paths_unchanged"] = True
        result["tracked_tree_clean"] = True
        result["source_inputs_clean"] = True
    return result


def validate_run(run: dict) -> dict:
    require(run.get("id") == RUN_ID and run.get("head_sha") == BASELINE_HEAD,
            "Prior run identity mismatch")
    require(run.get("repository", {}).get("full_name") == REPOSITORY and run.get("path") == WORKFLOW,
            "Prior repository or workflow mismatch")
    require(run.get("status") == "completed" and run.get("conclusion") == "failure",
            "Prior overall run must retain its completed packaging failure")
    return {"id": RUN_ID, "head_sha": BASELINE_HEAD, "repository": REPOSITORY,
            "workflow": WORKFLOW, "status": "completed", "overall_conclusion": "failure"}


def validate_job(platform: str, job: dict) -> dict:
    expected = PLATFORMS[platform]
    require(job.get("id") == expected["job_id"] and job.get("run_id") == RUN_ID and
            job.get("head_sha") == BASELINE_HEAD and job.get("name") == expected["job_name"],
            platform + " prior job identity mismatch")
    require(job.get("status") == "completed" and job.get("conclusion") == expected["overall_conclusion"],
            platform + " prior overall job conclusion mismatch")
    steps = job.get("steps", [])
    require(isinstance(steps, list), platform + " missing job steps")

    def step(name: str, conclusion: str) -> dict:
        rows = [row for row in steps if isinstance(row, dict) and row.get("name") == name]
        require(len(rows) == 1 and rows[0].get("status") == "completed" and
                rows[0].get("conclusion") == conclusion, platform + " missing, ambiguous or failed required step: " + name)
        return {"name": name, "conclusion": conclusion}

    application = [step(name, "success") for name in expected["application_steps"]]
    result = {"id": expected["job_id"], "run_id": RUN_ID, "head_sha": BASELINE_HEAD,
              "overall_conclusion": expected["overall_conclusion"], "application_steps": application}
    if platform == "windows":
        result["retained_package_failure"] = step(PACKAGE_STEP, "failure")
        result["installed_evaluator_not_reached"] = step(INSTALLED_STEP, "skipped")
    return result


def validate_artifact_metadata(platform: str, artifact: dict) -> dict:
    expected = PLATFORMS[platform]
    require(artifact.get("id") == expected["artifact_id"] and artifact.get("name") == expected["artifact_name"],
            platform + " artifact identity mismatch")
    require(artifact.get("expired") is False and artifact.get("digest") == "sha256:" + expected["artifact_sha256"],
            platform + " artifact expired or digest mismatch")
    origin = artifact.get("workflow_run", {})
    require(origin.get("id") == RUN_ID and origin.get("head_sha") == BASELINE_HEAD,
            platform + " artifact workflow identity mismatch")
    size = artifact.get("size_in_bytes")
    require(type(size) is int and 0 < size <= MAX_ARCHIVE_BYTES, platform + " artifact size invalid")
    return {"id": expected["artifact_id"], "name": expected["artifact_name"], "run_id": RUN_ID,
            "head_sha": BASELINE_HEAD, "sha256": expected["artifact_sha256"], "size_in_bytes": size}


def verify_artifact(platform: str, archive: Path) -> dict:
    expected = PLATFORMS[platform]
    require(0 < archive.stat().st_size <= MAX_ARCHIVE_BYTES, platform + " archive size invalid")
    with archive.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    require(digest == expected["artifact_sha256"], platform + " downloaded artifact digest mismatch")
    groups = expected_groups(platform)
    result = {"sha256": digest, "groups": {}, "raw_audit_basis":
              "Immutable ZIP digest binds the prior independent full-body/privacy review; raw JSONL is not reparsed here"}
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        require(len(names) == len(set(names)), platform + " ambiguous duplicate ZIP members")
        found = {name.rsplit("/", 1)[0] for name in names if name.startswith("art-final-") and name.endswith("/report.json")}
        require(found == set(groups), platform + " missing or unexpected qualification groups")

        def read(group: str, name: str) -> dict:
            member = group + "/" + name
            require(member in names and bundle.getinfo(member).file_size <= MAX_JSON_BYTES,
                    platform + " missing or oversized qualification receipt")
            value = json.loads(bundle.read(member))
            require(isinstance(value, dict), platform + " invalid qualification receipt")
            return value

        for group, (checks, count) in groups.items():
            provenance, execution = read(group, "provenance.json"), read(group, "execution.json")
            report, audit = read(group, "report.json"), read(group, "audit-verification.json")
            hashes = read(group, "hashes.json")
            required_hashes = {"provenance.json", "execution.json", "report.json", "audit-verification.json"}
            require(required_hashes.issubset(hashes), platform + " incomplete receipt hash manifest")
            for name in required_hashes:
                require(hashlib.sha256(bundle.read(group + "/" + name)).hexdigest() == hashes[name],
                        platform + " receipt hash mismatch")
            require(provenance.get("source") == {"head": BASELINE_HEAD, "tree": BASELINE_TREE,
                    "changed_paths": [], "diff_sha256": EMPTY_SHA256}, platform + " application source is not exact baseline")
            for key, wanted in (("godot", expected["godot_sha256"]), ("native", expected["native_sha256"]),
                                ("harness", HARNESS_SHA256), ("driver", DRIVER_SHA256)):
                require(provenance.get(key, {}).get("sha256") == wanted, platform + " runtime or fixture identity mismatch")
            require(type(execution.get("exit_code")) is int and execution["exit_code"] == 0 and
                    execution.get("timed_out") is False and not execution.get("cleanup_error"),
                    platform + " application process did not complete cleanly")
            require(report.get("checks") == checks and report.get("failures") == [] and
                    report.get("unavailable") == [] and len(report.get("cases", [])) == count,
                    platform + " application assertions incomplete, unavailable or failed")
            require(report.get("godot") == "4.7-stable (official)" and report.get("os") == expected["os"],
                    platform + " report runtime identity mismatch")
            displayed = "-displayed-" in group
            require(report.get("display") == (expected["display"] if displayed else "headless"),
                    platform + " report display tier mismatch")
            exit_group = group.endswith("process-exit") or group.endswith("request-exit")
            phase = "process_exit_requested_before_tree_teardown" if exit_group else "completed"
            require(report.get("completion_phase") == phase, platform + " application receipt is partial")
            for case in report["cases"]:
                require(0 <= case.get("frames", {}).get("max_usec", 2000000) < 2000000,
                        platform + " application frame limit failed")
            if exit_group:
                end = report.get("process_exit", {})
                require(end.get("exit_code") == 0 and end.get("preparation_active_at_request") is True and
                        end.get("pending_jobs_at_request") == 1 and 0 <= end.get("seconds_after_request", 2) < 2,
                        platform + " actual preparation exit was not qualified")
            require(audit.get("credential_redacted") is True and type(audit.get("archives")) is int and
                    audit["archives"] > 0, platform + " audit verification missing")
            bodies, conversations = audit.get("complete_bodies"), audit.get("complete_conversations")
            require(isinstance(bodies, list) and isinstance(conversations, list), platform + " audit receipt incomplete")
            suffix = group.split("-", 3)[-1]
            expected_bodies = BODY_FIXTURES.get(suffix, set())
            require(len(bodies) == len(expected_bodies) and {b.get("fixture") for b in bodies} == expected_bodies and
                    all(b.get("complete_redacted_body") is True and b.get("bytes", 0) > 0 and
                        re.fullmatch(r"[0-9a-f]{64}", b.get("sha256", "")) for b in bodies),
                    platform + " complete-body audit proof missing")
            if group.endswith("conversation-apply"):
                require(conversations == [{"bytes": 16769024, "sha256": CHANGED_CONVERSATION_SHA256,
                        "complete_changed_conversation": True, "model_requests": 0}],
                        platform + " changed full conversation proof missing")
            else:
                require(conversations == [], platform + " unexpected conversation audit proof")
            result["groups"][group] = {"checks": checks, "cases": count, "display": report["display"],
                "source_runtime_and_receipt_hashes_verified": True, "complete_bodies": len(bodies),
                "complete_conversations": len(conversations)}
    return result


def validate_completed_decision(proof: dict, candidate_commit: str, candidate_tree: str) -> dict:
    """Validate a completed proof again against this checkout, without network.

    The workflow supplies its own scope-job artifact. This validates the full
    fixed receipt structure and recomputes local equivalence; a reuse boolean or
    arbitrary nonempty application identity never authorizes a package claim.
    It does not assert that packaging itself has passed.
    """
    require(isinstance(proof, dict) and proof.get("schema") == SCHEMA,
            "Unexpected application qualification schema")
    require(not proof.get("offline_scope_only"), "Offline scope-only decision is not a completed qualification decision")
    require(proof.get("candidate_source_commit") == candidate_commit and
            proof.get("candidate_source_tree") == candidate_tree,
            "Application qualification does not match current package source")
    local = inspect_scope(ROOT)
    require(local["candidate_source_commit"] == candidate_commit and local["candidate_source_tree"] == candidate_tree,
            "Package identities differ from the actual checkout")
    for key in ("baseline", "baseline_ancestor", "changed_paths", "outside_packaging_allowlist"):
        require(key in proof and proof[key] == local[key], "Application qualification scope mismatch: " + key)
    mode = proof.get("mode")
    require(mode in ("reuse_verified", "full_required"), "Application qualification decision is not completed")
    if mode == "full_required":
        require(local["mode"] == "full_required" and proof.get("reuse") is False and
                proof.get("eligible_pending_proof") is False and
                proof.get("application_source_commit") is None and proof.get("application_source_tree") is None,
                "Full qualification decision falsely claims reused application acceptance")
        return proof
    require(local["eligible_pending_proof"] is True and proof.get("reuse") is True and
            proof.get("eligible_pending_proof") is False and
            proof.get("application_source_commit") == BASELINE_HEAD and
            proof.get("application_source_tree") == BASELINE_TREE,
            "Reused application identity or eligibility is invalid")
    require(proof.get("protected_tree_ids") == local.get("protected_tree_ids") == PROTECTED_TREE_IDS,
            "Protected application tree proof is missing or changed")
    for key in ("all_other_paths_unchanged", "tracked_tree_clean", "source_inputs_clean"):
        require(proof.get(key) is True and local.get(key) is True,
                "Application qualification lacks a clean unchanged source proof")
    expected_run = {"id": RUN_ID, "head_sha": BASELINE_HEAD, "repository": REPOSITORY,
                    "workflow": WORKFLOW, "status": "completed", "overall_conclusion": "failure"}
    require(proof.get("prior_run") == expected_run, "Fixed prior run proof is missing or changed")
    platforms = proof.get("platforms")
    require(isinstance(platforms, dict) and set(platforms) == set(PLATFORMS),
            "Both fixed platform proofs are required")
    for platform, expected in PLATFORMS.items():
        evidence = platforms[platform]
        require(isinstance(evidence, dict), "Invalid platform proof")
        expected_job = {"id": expected["job_id"], "run_id": RUN_ID, "head_sha": BASELINE_HEAD,
                        "overall_conclusion": expected["overall_conclusion"], "application_steps": [
                            {"name": name, "conclusion": "success"} for name in expected["application_steps"]]}
        if platform == "windows":
            expected_job.update(retained_package_failure={"name": PACKAGE_STEP, "conclusion": "failure"},
                                installed_evaluator_not_reached={"name": INSTALLED_STEP, "conclusion": "skipped"})
        require(evidence.get("job") == expected_job, platform + " completed application step proof is missing or changed")
        artifact = evidence.get("artifact")
        require(isinstance(artifact, dict), platform + " artifact proof is missing")
        checked_artifact = validate_artifact_metadata(platform, {
            "id": artifact.get("id"), "name": artifact.get("name"), "expired": False,
            "digest": "sha256:" + str(artifact.get("sha256", "")), "size_in_bytes": artifact.get("size_in_bytes"),
            "workflow_run": {"id": artifact.get("run_id"), "head_sha": artifact.get("head_sha")}})
        require(checked_artifact == artifact, platform + " artifact proof is incomplete")
        receipts = evidence.get("application_receipts")
        require(isinstance(receipts, dict) and receipts.get("sha256") == expected["artifact_sha256"],
                platform + " downloaded proof digest is missing or changed")
        groups = receipts.get("groups")
        require(isinstance(groups, dict) and set(groups) == set(expected_groups(platform)),
                platform + " complete qualification group proof is missing")
        for group, (checks, count) in expected_groups(platform).items():
            row = groups[group]
            suffix = group.split("-", 3)[-1]
            expected_row = {"checks": checks, "cases": count,
                            "display": expected["display"] if "-displayed-" in group else "headless",
                            "source_runtime_and_receipt_hashes_verified": True,
                            "complete_bodies": len(BODY_FIXTURES.get(suffix, set())),
                            "complete_conversations": int(group.endswith("conversation-apply"))}
            require(isinstance(row, dict) and row.get("source_runtime_and_receipt_hashes_verified") is True and
                    row == expected_row, platform + " successful qualification group proof is missing or changed")
    return proof


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class GitHubClient:
    """An authenticated API opener and a separate, token-free object opener."""
    def __init__(self, token: str):
        require(bool(token), "Read-only GitHub token is required for prior qualification proof")
        self.token = token
        self.api_opener = build_opener(_NoRedirect())
        self.object_opener = build_opener(_NoRedirect())

    def _api(self, path: str):
        require(path.startswith(f"/repos/{REPOSITORY}/actions/") and "?" not in path and "#" not in path,
                "Unexpected qualification API route")
        request = Request("https://api.github.com" + path, headers={
            "Authorization": "Bearer " + self.token, "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "CyberSand-Art-qualification"})
        return self.api_opener.open(request, timeout=60)

    def json(self, path: str) -> dict:
        try:
            with self._api(path) as response:
                data = response.read(MAX_JSON_BYTES + 1)
            require(len(data) <= MAX_JSON_BYTES, "Prior API response exceeds receipt limit")
            value = json.loads(data)
            require(isinstance(value, dict), "Prior API receipt is not an object")
            return value
        except (HTTPError, URLError, OSError):
            # Network exception strings may contain signed URLs. Never emit them.
            raise QualificationError("Prior qualification API request failed") from None

    @staticmethod
    def _object_location(location: str) -> str:
        parsed = urlsplit(location)
        host = parsed.hostname or ""
        require(parsed.scheme == "https" and parsed.port in (None, 443) and not parsed.username and
                not parsed.password and not parsed.fragment and
                any(host.endswith(suffix) for suffix in (".blob.core.windows.net", ".actions.githubusercontent.com",
                                                         ".githubusercontent.com", ".amazonaws.com")),
                "Artifact redirect origin is not an approved HTTPS object host")
        return location

    def download(self, platform: str, destination: Path) -> None:
        path = f"/repos/{REPOSITORY}/actions/artifacts/{PLATFORMS[platform]['artifact_id']}/zip"
        try:
            try:
                response = self._api(path)
            except HTTPError as error:
                require(error.code in (301, 302, 303, 307, 308), "Artifact API download failed")
                location = error.headers.get("Location", "")
                error.close()
                response = None
            if response is None:
                for _ in range(4):
                    location = self._object_location(location)
                    try:
                        # Construct a NEW request: no token, API headers or Referer.
                        response = self.object_opener.open(Request(location, headers={
                            "User-Agent": "CyberSand-Art-qualification"}), timeout=60)
                        break
                    except HTTPError as error:
                        require(error.code in (301, 302, 303, 307, 308), "Artifact object download failed")
                        location = error.headers.get("Location", "")
                        error.close()
                require(response is not None, "Artifact redirect limit exceeded")
            with response, destination.open("wb") as stream:
                size = 0
                while chunk := response.read(1024 * 1024):
                    size += len(chunk)
                    require(size <= MAX_ARCHIVE_BYTES, "Artifact download exceeds bound")
                    stream.write(chunk)
        except (HTTPError, URLError, OSError):
            raise QualificationError("Prior artifact download failed") from None


def qualify(root: Path, output: Path, *, check_scope_only: bool = False, api_client=None) -> dict:
    result = inspect_scope(root)
    if result["eligible_pending_proof"] and not check_scope_only:
        client = api_client if api_client is not None else GitHubClient(os.environ.get("GITHUB_TOKEN", ""))
        prefix = f"/repos/{REPOSITORY}/actions"
        result["prior_run"] = validate_run(client.json(f"{prefix}/runs/{RUN_ID}"))
        result["platforms"] = {}
        with tempfile.TemporaryDirectory(prefix="art-qualification-proof-") as temporary:
            for platform, expected in PLATFORMS.items():
                job = validate_job(platform, client.json(f"{prefix}/jobs/{expected['job_id']}"))
                metadata = validate_artifact_metadata(platform, client.json(f"{prefix}/artifacts/{expected['artifact_id']}"))
                archive = Path(temporary) / (platform + ".zip")
                client.download(platform, archive)
                require(archive.stat().st_size == metadata["size_in_bytes"], platform + " artifact size differs from API metadata")
                proof = verify_artifact(platform, archive)
                result["platforms"][platform] = {"job": job, "artifact": metadata, "application_receipts": proof}
        result.update(reuse=True, mode="reuse_verified", eligible_pending_proof=False,
                      application_source_commit=BASELINE_HEAD, application_source_tree=BASELINE_TREE,
                      reason="Protected application source is unchanged and both fixed prior application proofs verified")
    elif check_scope_only:
        result["offline_scope_only"] = True
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check-scope-only", action="store_true")
    args = parser.parse_args()
    try:
        result = qualify(args.root.resolve(), args.output.resolve(), check_scope_only=args.check_scope_only)
    except Exception as error:
        # Do not serialize unexpected network/git exception strings or URLs.
        message = str(error) if isinstance(error, QualificationError) else type(error).__name__
        if "http" in message.lower() or "?" in message or "\n" in message:
            message = type(error).__name__
        result = {"schema": SCHEMA, "mode": "failed", "reuse": False, "reason": message,
                  "application_source_commit": None, "application_source_tree": None}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result))
        return 1
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as stream:
            stream.write("reuse=" + str(result["reuse"]).lower() + "\n")
    print(json.dumps({key: result[key] for key in ("mode", "reuse", "candidate_source_commit", "candidate_source_tree")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
