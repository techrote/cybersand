#!/usr/bin/env python3
"""Dispatch only the unchanged complete repository gates for an exact Draft head.

An explicit request-only push leases this branch and names the fixed workflows.
This script neither changes source nor treats dispatched/queued runs as passes.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request

import runtime_custody as custody
import run_request

REQUEST = ".github/swarm456-broad-request.json"
WORKFLOW = ".github/workflows/swarm456-broad-validation.yml"
WORKFLOWS = ("documentation.yml", "native.yml", "gdextension.yml")
KEYS = {"schema", "qualification_programme", "action", "request_id", "expected_parent_sha", "workflows"}


def verify_request(root: Path, execution: str, event: dict) -> dict:
    run_request.commit(root, execution)
    custody.require(run_request.git(root, "rev-parse", "HEAD").decode().strip() == execution
                    and event.get("ref") == "refs/heads/" + custody.BRANCH and event.get("after") == execution
                    and event.get("created") is False and event.get("deleted") is False and event.get("forced") is False,
                    "Broad qualification requires an ordinary exact-branch request push")
    entry = run_request.git(root, "ls-tree", execution, "--", REQUEST).decode().split()
    custody.require(len(entry) == 4 and entry[:2] == ["100644", "blob"] and entry[3] == REQUEST,
                    "Broad qualification request must be a committed regular file")
    payload = run_request.git(root, "cat-file", "blob", entry[2])
    custody.require(0 < len(payload) <= 4096, "Broad request exceeds its finite budget")
    value = json.loads(payload, object_pairs_hook=run_request.unique_object)
    custody.require(isinstance(value, dict) and set(value) == KEYS and type(value["schema"]) is int
                    and value["schema"] == 1 and value["qualification_programme"] == custody.QUALIFICATION_PROGRAMME
                    and value["action"] == "qualify-full-regressions" and value["workflows"] == list(WORKFLOWS)
                    and isinstance(value["request_id"], str) and run_request.REQUEST_ID.fullmatch(value["request_id"]),
                    "Broad request changed its action, scope or fixed workflow allowlist")
    parent = run_request.commit(root, value["expected_parent_sha"])
    custody.require(run_request.git(root, "show", "--no-patch", "--format=%P", execution).decode().split() == [parent]
                    and event.get("before") == parent and run_request.changed(root, parent, execution) == [REQUEST],
                    "Broad request lease changed or includes source/runtime edits")
    custody.require(run_request.ancestor(root, run_request.ACCEPTED_MAIN, execution)
                    and all(run_request.ancestor(root, donor, execution) for donor in run_request.DONORS.values()),
                    "Broad request left accepted-main and donor ancestry")
    return {**value, "execution_sha": execution, "source_tree": run_request.git(root, "rev-parse", execution + "^{tree}").decode().strip()}


def api(path: str, body: dict | None = None) -> dict:
    custody.require(path.startswith("/repos/techrote/cybersand/actions/workflows/") and ".." not in path,
                    "Broad dispatcher API scope changed")
    request = urllib.request.Request("https://api.github.com" + path, method="POST" if body is not None else "GET",
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": "Bearer " + os.environ["GH_TOKEN"], "Accept": "application/vnd.github+json",
                 "Content-Type": "application/json", "X-GitHub-Api-Version": "2022-11-28"})
    with urllib.request.urlopen(request, timeout=45) as response:
        data = response.read()
        return json.loads(data) if data else {}


def live_lease(execution: str) -> None:
    remote = custody.git(custody.ROOT, "ls-remote", "--exit-code", "origin", "refs/heads/" + custody.BRANCH)
    custody.require(remote == execution + "\trefs/heads/" + custody.BRANCH, "Branch advanced; broad dispatch lease refused")


def matching_runs(workflow: str, execution: str) -> list[dict]:
    query = urllib.parse.urlencode({"event": "workflow_dispatch", "branch": custody.BRANCH, "head_sha": execution, "per_page": 100})
    page = api("/repos/techrote/cybersand/actions/workflows/" + workflow + "/runs?" + query)
    custody.require(page.get("total_count", 101) <= 100, "Unexpectedly broad manual run inventory")
    return [row for row in page.get("workflow_runs", []) if row.get("head_sha") == execution
            and row.get("head_branch") == custody.BRANCH and row.get("event") == "workflow_dispatch"
            and row.get("path") == ".github/workflows/" + workflow
            and row.get("repository", {}).get("full_name") == "techrote/cybersand"
            and row.get("head_repository", {}).get("full_name") == "techrote/cybersand"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    custody.require(os.environ.get("GITHUB_REPOSITORY") == "techrote/cybersand"
                    and os.environ.get("GITHUB_EVENT_NAME") == "push"
                    and os.environ.get("GITHUB_REF") == "refs/heads/" + custody.BRANCH
                    and os.environ.get("GITHUB_WORKFLOW_REF") == "techrote/cybersand/" + WORKFLOW + "@refs/heads/" + custody.BRANCH,
                    "Wrong broad-dispatch execution context")
    path = Path(os.environ["GITHUB_EVENT_PATH"])
    custody.require(path.stat().st_size <= 4 * 1024 * 1024, "Oversized push event")
    event = json.loads(path.read_bytes(), object_pairs_hook=run_request.unique_object)
    execution = os.environ.get("GITHUB_SHA", "")
    request = verify_request(custody.ROOT, execution, event)
    # Both source-bound LFS pointer/binding pairs must already be published.
    subprocess.run(["python3", "tools/ci/check_swarm_runtime.py"], cwd=custody.ROOT, check=True, timeout=60)
    live_lease(execution)
    before = {name: {row["id"] for row in matching_runs(name, execution)} for name in WORKFLOWS}
    record = {"request": request, "dispatched": [], "runs": {}, "qualification_passed": False,
              "status": "dispatching", "ready_or_merge_authorized": False, "owner_visual_acceptance": "pending"}
    custody.write_json(args.output, record)
    for name in WORKFLOWS:
        live_lease(execution)
        api("/repos/techrote/cybersand/actions/workflows/" + name + "/dispatches", {"ref": custody.BRANCH})
        record["dispatched"].append(name)
        custody.write_json(args.output, record)
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline and len(record["runs"]) != len(WORKFLOWS):
        live_lease(execution)
        for name in WORKFLOWS:
            if name in record["runs"]:
                continue
            fresh = [row for row in matching_runs(name, execution) if row["id"] not in before[name]]
            custody.require(len(fresh) <= 1, "Ambiguous competing manual workflow runs: " + name)
            if fresh:
                record["runs"][name] = {key: fresh[0].get(key) for key in
                    ("id", "run_attempt", "head_sha", "head_branch", "path", "status", "conclusion", "html_url")}
                custody.write_json(args.output, record)
        if len(record["runs"]) != len(WORKFLOWS):
            time.sleep(5)
    custody.require(len(record["runs"]) == len(WORKFLOWS), "One or more dispatched workflows did not expose an exact-source run")
    live_lease(execution)
    record["status"] = "dispatched-and-source-bound; completion must be reviewed separately"
    custody.write_json(args.output, record)
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    main()
