#!/usr/bin/env python3
"""Fence the reviewed reporting-only successors of qualified application 30660.

Every other source change selects the complete application campaign. Reused
results keep their original source labels; they are never relabelled as reruns.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BASE = "30660f7da126eec95a2df8c5b432a4fa05a49a86"
REPORTING_ATTEMPT = "5a34cf35c12f40e9aa13513188908e7d3765730f"
RUN = 43779233966
ARTIFACT = 14188373052
ARTIFACT_SHA = "6c95e19d08aa208a3812bcb1c93ad3c098d6d7f10a538bac46add44d21d29474"
FIXED_RUNNER_SHA = "aecdb1bad35b6d0b54d794fd1e3322a3f6d66f90e5b5e4b4417e03dcf372a266"
ALLOWED = {
    "Run-Test-It.ps1", ".github/workflows/pose-trace-qualification.yml",
    "tools/ci/qualify_test_it_reporting.py", "tools/ci/test_test_it_physics_reducer.py",
    "docs/audits/2026-11-15-workbench-physics-freezes.md",
    "docs/operations/engine-lab-pose-tracing.md",
    "docs/operations/camera-stack-coherence-acceptance.md",
    "docs/reference/status-and-roadmap.md", "docs/README.md",
    "docs/operations/cybersand-codex-development-handover.md",
}
REPLAY_FOLLOWUP_ALLOWED = {
    "tools/ci/qualify_test_it_reporting.py", "tools/ci/test_test_it_physics_reducer.py",
    "docs/audits/2026-11-15-workbench-physics-freezes.md",
    "docs/operations/engine-lab-pose-tracing.md",
}


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def scope(force_full=False):
    source = git("rev-parse", "HEAD").decode().strip()
    parents = git("show", "-s", "--format=%P", source).decode().strip().split()
    changes = git("diff", "--name-only", BASE, source).decode().splitlines()
    incremental = git("diff", "--name-only", REPORTING_ATTEMPT, source).decode().splitlines()
    # The first attempt is retained as a failed CI checkpoint: its fresh capture
    # exposed a one-decimal-unit floating-point comparison boundary. Its only
    # permitted successor repairs that CI harness and documents the failure.
    # No arbitrary descendant can enter this reuse profile.
    reporting_lineage = parents == [BASE] or (
        parents == [REPORTING_ATTEMPT]
        and git("show", "-s", "--format=%P", REPORTING_ATTEMPT).decode().strip() == BASE
        and bool(incremental) and set(incremental).issubset(REPLAY_FOLLOWUP_ALLOWED)
        and "tools/ci/test_test_it_physics_reducer.py" in incremental)
    runner = git("show", source + ":Run-Test-It.ps1").replace(b"\r\n", b"\n")
    runner_sha = hashlib.sha256(runner).hexdigest()
    trees = {name: {"qualified": git("rev-parse", BASE + ":" + name).decode().strip(),
                    "candidate": git("rev-parse", source + ":" + name).decode().strip()}
             for name in ("godot", "native", "third_party")}
    same_trees = all(row["qualified"] == row["candidate"] for row in trees.values())
    reporting_only = (not force_full and reporting_lineage and bool(changes)
                      and set(changes).issubset(ALLOWED) and "Run-Test-It.ps1" in changes
                      and runner_sha == FIXED_RUNNER_SHA and same_trees)
    return {"source": source, "qualified_source": BASE, "parents": parents,
            "report_only": reporting_only, "force_full": force_full,
            "reviewed_reporting_lineage": reporting_lineage,
            "changes_since_reporting_attempt": incremental,
            "changed_paths": changes, "runner_normalized_sha256": runner_sha,
            "application_trees": trees, "application_trees_identical": same_trees,
            "qualified_run": RUN,
            "qualification_profile": "report replay plus installed Quick" if reporting_only
                                     else "complete application campaign"}


def output(path, **values):
    if path:
        with Path(path).open("a", encoding="utf-8") as stream:
            for name, value in values.items():
                need("\n" not in str(value) and "\r" not in str(value), "Unsafe output value")
                stream.write(name + "=" + str(value) + "\n")


class GitHubRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        need(urllib.parse.urlparse(newurl).scheme == "https", "Non-HTTPS artifact redirect")
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected and urllib.parse.urlparse(req.full_url).netloc != urllib.parse.urlparse(newurl).netloc:
            redirected.remove_header("Authorization")
        return redirected


def acquire(args):
    proof = scope()
    need(proof["report_only"], "Source is not a reviewed reporting-only successor")
    token = os.environ.get("GH_TOKEN", "")
    need(token, "Actions read token unavailable")
    opener = urllib.request.build_opener(GitHubRedirect())

    def request(path):
        req = urllib.request.Request("https://api.github.com/repos/techrote/cybersand/" + path,
            headers={"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
                     "X-GitHub-Api-Version": "2022-11-28"})
        return opener.open(req, timeout=180)

    with request("actions/runs/" + str(RUN)) as response:
        run = json.load(response)
    need(run["head_sha"] == BASE and run["status"] == "completed" and run["conclusion"] == "success",
         "Retained full qualification source/result differs")
    with request("actions/artifacts/" + str(ARTIFACT)) as response:
        artifact = json.load(response)
    need(artifact["workflow_run"]["id"] == RUN and artifact["workflow_run"]["head_sha"] == BASE
         and artifact["digest"] == "sha256:" + ARTIFACT_SHA and not artifact["expired"],
         "Retained artifact identity differs or has expired; use force_full")
    args.output.mkdir(parents=True, exist_ok=True)
    archive = Path(os.environ["RUNNER_TEMP"]) / ("qualified-report-evidence-" + str(ARTIFACT) + ".zip")
    with request("actions/artifacts/" + str(ARTIFACT) + "/zip") as response, archive.open("wb") as stream:
        shutil.copyfileobj(response, stream, length=1024 * 1024)
    need(digest(archive) == ARTIFACT_SHA, "Retained artifact checksum differs")
    extracted = args.output / "retained-windows"
    extracted.mkdir(exist_ok=False)
    with zipfile.ZipFile(archive) as bundle:
        need(bundle.testzip() is None, "Retained artifact CRC failure")
        for name in bundle.namelist():
            path = PurePosixPath(name)
            need(not path.is_absolute() and ".." not in path.parts and "\\" not in name,
                 "Unsafe retained artifact path")
        bundle.extractall(extracted)
    installed = read(extracted / "installed/summary.json")
    need(installed["source_commit"] == BASE and installed["complete"] and not installed["failures"]
         and len(installed["cases"]) == 37, "Retained installed campaign differs")
    for case in installed["cases"]:
        need(case["passed"] and case["exit"] == 0
             and digest(extracted / "installed" / (case["name"] + ".log")) == case["log_sha256"],
             "Retained installed case/log differs")
    roots = list((extracted / "Test-It-Results").glob("*/summary.json"))
    need(len(roots) == 1, "Ambiguous retained Test It run")
    summary = read(roots[0])
    need(summary["source"] == BASE and summary["complete"] and summary["status"] == "passed"
         and not summary["failures"] and not summary["errors"]
         and len(summary["cases"]) == 16 and len(summary["pairs"]) == 8,
         "Retained Test It completion differs")
    baseline = args.output / "baseline-Run-Test-It.ps1"
    baseline.write_bytes(git("show", BASE + ":Run-Test-It.ps1"))
    proof.update({"qualified_windows_artifact": ARTIFACT, "artifact_sha256": ARTIFACT_SHA,
                  "reused_installed_cases": 37, "retained_flight_arms": 16,
                  "retained_summary_sha256": digest(roots[0]),
                  "replay_root": str(roots[0].parent.resolve()),
                  "meaning": "Full application evidence remains labelled 30660. Exact identical application trees permit reuse; the changed reporting code requires new Windows5.1 replay and installed Quick qualification.",
                  "physical_acceptance": "HOLD"})
    write(args.output / "source-reuse.json", proof)
    output(args.github_output, replay_root=roots[0].parent.resolve().as_posix())
    print(json.dumps({key: proof[key] for key in ("source", "qualified_source", "report_only",
          "application_trees_identical", "reused_installed_cases", "retained_flight_arms")}))


def negative(args):
    report = read(args.report)
    failures = report.get("failures", [])
    need(args.exit_code == 1 and report["complete"] and not report["passed"] and failures,
         "Old runner did not reproduce the expected completed negative")
    need(len(report["fixtures"]) == 4 and len(report["traces"]) == 16,
         "Old runner negative omitted fixtures/traces")
    need(report["powershell"]["version"].startswith("5.1.") and
         report["powershell"]["edition"] == "Desktop", "Old negative was not Windows5.1")
    need(all(".largest_active_gaps" in row.get("path", "") and "error" not in row for row in failures),
         "Old runner failed outside the registered witness-ranking defect")
    need(all(not row["passed"] for row in report["traces"]), "Expected all16 original witness defects")
    print(json.dumps({"expected_negative": True, "mismatches": len(failures),
                      "old_source": BASE, "only_field": "largest_active_gaps"}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    classify = commands.add_parser("scope")
    classify.add_argument("--force-full", choices=("true", "false"), default="false")
    classify.add_argument("--github-output", type=Path)
    classify.add_argument("--output", type=Path)
    fetch = commands.add_parser("fetch")
    fetch.add_argument("--output", type=Path, required=True)
    fetch.add_argument("--github-output", type=Path)
    check = commands.add_parser("check-negative")
    check.add_argument("--report", type=Path, required=True)
    check.add_argument("--exit-code", type=int, required=True)
    args = parser.parse_args()
    if args.command == "scope":
        proof = scope(args.force_full == "true")
        if args.output:
            write(args.output, proof)
        output(args.github_output, report_only=str(proof["report_only"]).lower())
        print(json.dumps(proof))
    elif args.command == "fetch":
        acquire(args)
    else:
        negative(args)


if __name__ == "__main__":
    main()
