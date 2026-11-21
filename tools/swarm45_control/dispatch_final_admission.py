#!/usr/bin/env python3
"""Dispatch only the five existing final admission workflows for PR715.

This lives on a separate CI control branch. It never commits, pushes, changes
PR state, or accepts physical-owner qualification. All API writes are the five
fixed workflow-dispatch endpoints, after an exact published-source lease.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

REPO = "techrote/cybersand"
PREFIX = "/repos/" + REPO
PROGRAMME = "GENTEK-SWARM-004-005-MAINLINE"
CONTROL_BRANCH = "ci/swarm45-final-admission-dispatch-20261121"
CONTROL_BASE = "10fe808ac7f6a4b9c07f7d168763b41957359e57"
TARGET_BRANCH = "integration/swarm004-005-mainline-20261121"
ACCEPTED_MAIN = "846fe0533b3170e7b01f690518da49fc40cc24d1"
PR = 715
REQUEST = ".github/swarm45-final-admission-request.json"
WORKFLOW = ".github/workflows/swarm45-final-admission-dispatch.yml"
QUALIFIER = ".github/workflows/swarm45-mainline-qualification.yml"
PUBLISHER = ".github/workflows/swarm45-runtime-publication.yml"
PUBLICATION_REQUEST = ".github/swarm45-runtime-publication-request.json"
WORKFLOWS = ("documentation.yml", "native.yml", "gdextension.yml",
             "palette-shader-qualification.yml", "play-desktop-packet.yml")
RUNTIMES = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
}
PROVENANCE = {"linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
              "windows": "godot/addons/cybersand_native/runtime-provenance.json"}
CLIS = {"linux": "godot/tools/gentek_reciprocal", "windows": "godot/tools/gentek_reciprocal.exe"}
BINDINGS = {os_name: "godot/tools/swarm004-runtime." + os_name + ".json" for os_name in RUNTIMES}
PATHS = sorted([*RUNTIMES.values(), *PROVENANCE.values(), *CLIS.values(), *BINDINGS.values()])
KEYS = {"schema", "programme", "action", "request_id", "expected_parent_sha", "target_sha",
        "qualification_source_sha", "qualification_run_id", "qualification_run_attempt",
        "publication_request_sha", "publication_run_id", "publication_run_attempt"}
SHA = re.compile(r"[0-9a-f]{40}")
SHA256 = re.compile(r"[0-9a-f]{64}")
REQUEST_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,95}")
ROOT = Path(__file__).resolve().parents[2]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def unique_object(pairs: list[tuple]) -> dict:
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + str(key))
        result[key] = value
    return result


def decode(payload: bytes) -> dict:
    result = json.loads(payload, object_pairs_hook=unique_object)
    require(isinstance(result, dict), "Expected a JSON object")
    return result


def git(*arguments: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *arguments], timeout=90)


def text(*arguments: str) -> str:
    return git(*arguments).decode().strip()


def ancestor(parent: str, child: str) -> bool:
    return subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", parent, child],
                          check=False, timeout=45).returncode == 0


def commit(value: object) -> str:
    require(isinstance(value, str) and SHA.fullmatch(value) is not None, "Expected a complete lowercase commit SHA")
    require(text("rev-parse", "--verify", value + "^{commit}") == value, "Missing exact commit object")
    return value


def blob(revision: str, name: str) -> bytes:
    return git("show", revision + ":" + name)


def changed(parent: str, child: str) -> list[str]:
    return sorted(text("diff", "--name-only", "--no-renames", parent, child, "--").splitlines())


def api(path: str, payload: dict | None = None) -> tuple[int, dict]:
    """The only write surface is a fixed dispatch endpoint and fixed ref."""
    require(path.startswith(PREFIX + "/") and ".." not in path, "Unexpected API repository")
    data = None
    method = "GET"
    if payload is not None:
        require(path in {PREFIX + "/actions/workflows/" + name + "/dispatches" for name in WORKFLOWS}
                and payload == {"ref": TARGET_BRANCH}, "API write is outside the fixed dispatch contract")
        data = json.dumps(payload).encode()
        method = "POST"
    request = urllib.request.Request("https://api.github.com" + path, data=data, method=method, headers={
        "Authorization": "Bearer " + os.environ["GH_TOKEN"], "Accept": "application/vnd.github+json",
        "Content-Type": "application/json", "X-GitHub-Api-Version": "2022-11-28"})
    with urllib.request.urlopen(request, timeout=40) as response:
        status = response.status
        content = response.read(16 * 1024 * 1024 + 1)
    require(len(content) <= 16 * 1024 * 1024, "API response exceeded its bounded budget")
    return status, decode(content) if content else {}


def get(path: str) -> dict:
    status, result = api(PREFIX + path)
    require(status == 200, "Read-only GitHub query failed")
    return result


def request_value(payload: bytes) -> dict:
    require(0 < len(payload) <= 4096, "Request exceeds its finite budget")
    value = decode(payload)
    require(set(value) == KEYS and type(value["schema"]) is int and value["schema"] == 1
            and value["programme"] == PROGRAMME and value["action"] == "dispatch-final-admission",
            "Wrong final-admission request schema or scope")
    require(isinstance(value["request_id"], str) and REQUEST_ID.fullmatch(value["request_id"]) is not None,
            "Invalid explicit request id")
    for key in ("expected_parent_sha", "target_sha", "qualification_source_sha", "publication_request_sha"):
        require(isinstance(value[key], str) and SHA.fullmatch(value[key]) is not None, "Invalid " + key)
    for key in ("qualification_run_id", "qualification_run_attempt", "publication_run_id", "publication_run_attempt"):
        require(isinstance(value[key], str) and re.fullmatch(r"[1-9][0-9]{0,19}", value[key]) is not None,
                "Invalid positive decimal " + key)
    return value


def current_request() -> dict:
    require(os.environ.get("GITHUB_REPOSITORY") == REPO
            and os.environ.get("GITHUB_REF") == "refs/heads/" + CONTROL_BRANCH
            and os.environ.get("GITHUB_EVENT_NAME") == "push"
            and os.environ.get("GITHUB_WORKFLOW_REF") == REPO + "/" + WORKFLOW + "@refs/heads/" + CONTROL_BRANCH
            and os.environ.get("GITHUB_RUN_ATTEMPT") == "1",
            "Wrong control context; reruns require a fresh explicit request")
    execution = commit(os.environ.get("GITHUB_SHA"))
    require(text("rev-parse", "HEAD") == execution, "Control checkout differs from event source")
    event_path = Path(os.environ["GITHUB_EVENT_PATH"])
    require(event_path.stat().st_size <= 4 * 1024 * 1024, "Oversized push event")
    event = decode(event_path.read_bytes())
    require(event.get("ref") == "refs/heads/" + CONTROL_BRANCH and event.get("after") == execution
            and event.get("created") is False and event.get("deleted") is False and event.get("forced") is False,
            "Control requires an ordinary existing-branch request push")
    entry = text("ls-tree", execution, "--", REQUEST).split()
    require(len(entry) == 4 and entry[:2] == ["100644", "blob"] and entry[3] == REQUEST,
            "Request must be a committed regular file")
    payload = blob(execution, REQUEST)
    value = request_value(payload)
    parent = commit(value["expected_parent_sha"])
    require(text("show", "--no-patch", "--format=%P", execution).split() == [parent]
            and event.get("before") == parent and changed(parent, execution) == [REQUEST],
            "Control execution must contain only the explicit request with its exact parent lease")
    require(ancestor(CONTROL_BASE, parent), "Control branch left its reviewed integration base")
    return {**value, "execution_sha": execution, "request_sha256": hashlib.sha256(payload).hexdigest()}


def lease(value: dict) -> dict:
    for name, expected in ((TARGET_BRANCH, value["target_sha"]), ("main", ACCEPTED_MAIN),
                           (CONTROL_BRANCH, value["execution_sha"])):
        ref = get("/git/ref/heads/" + name)
        require(ref.get("ref") == "refs/heads/" + name and ref.get("object", {}).get("sha") == expected,
                "Remote branch lease changed: " + name)
    pr = get("/pulls/" + str(PR))
    require(pr.get("number") == PR and pr.get("state") == "open" and pr.get("draft") is True
            and pr.get("merged") is False, "PR715 must remain open and Draft")
    require(pr.get("base", {}).get("ref") == "main" and pr.get("base", {}).get("sha") == ACCEPTED_MAIN
            and pr.get("base", {}).get("repo", {}).get("full_name") == REPO
            and pr.get("head", {}).get("ref") == TARGET_BRANCH
            and pr.get("head", {}).get("sha") == value["target_sha"]
            and pr.get("head", {}).get("repo", {}).get("full_name") == REPO,
            "PR715 target, original main, repository or published head changed")
    return {"number": PR, "draft": True, "head": value["target_sha"], "base": ACCEPTED_MAIN}


def successful_run(value: dict, kind: str, path: str, source: str) -> dict:
    run = get("/actions/runs/" + value[kind + "_run_id"])
    require(str(run.get("id")) == value[kind + "_run_id"]
            and str(run.get("run_attempt")) == value[kind + "_run_attempt"]
            and run.get("head_sha") == source and run.get("head_branch") == TARGET_BRANCH
            and run.get("status") == "completed" and run.get("conclusion") == "success"
            and run.get("event") in (("push",) if kind == "publication" else ("push", "workflow_dispatch"))
            and run.get("repository", {}).get("full_name") == REPO
            and run.get("head_repository", {}).get("full_name") == REPO,
            "Requested " + kind + " run/attempt is not the completed successful exact-source execution")
    workflow = get("/actions/workflows/" + str(run.get("workflow_id", "")))
    require(workflow.get("path") == path and workflow.get("id") == run.get("workflow_id"),
            "Requested run is from a different workflow")
    return {"id": run["id"], "attempt": run["run_attempt"], "head_sha": source,
            "workflow_id": run["workflow_id"], "url": run["html_url"], "conclusion": "success"}


def source_chain(value: dict) -> dict:
    source, target, request = (commit(value[name]) for name in
                               ("qualification_source_sha", "target_sha", "publication_request_sha"))
    require(ancestor(ACCEPTED_MAIN, source) and ancestor(CONTROL_BASE, source), "Qualified source left accepted ancestry")
    require(text("show", "--no-patch", "--format=%P", target).split() == [request]
            and changed(request, target) == PATHS, "Published commit must change exactly eight runtime paths")
    require(text("show", "--no-patch", "--format=%s", target)
            == "build(swarm45): publish qualified mainline evaluation runtimes", "Unexpected publication commit identity")
    require(ancestor(source, request), "Qualified source is not the publication request ancestor")
    revisions = text("rev-list", "--max-count=17", source + ".." + request).splitlines()
    require(0 < len(revisions) <= 16, "Publication request ancestry exceeded its finite scope")
    for revision in revisions:
        parents = text("show", "--no-patch", "--format=%P", revision).split()
        require(len(parents) == 1 and changed(parents[0], revision) == [PUBLICATION_REQUEST],
                "Source changed after qualification; only explicit publication-request commits are admitted")
    published = decode(blob(request, PUBLICATION_REQUEST))
    require(published.get("schema") == 1 and published.get("programme") == PROGRAMME
            and published.get("action") == "publish-runtime"
            and published.get("qualification_source_sha") == source
            and published.get("qualification_run_id") == value["qualification_run_id"]
            and published.get("qualification_run_attempt") == value["qualification_run_attempt"]
            and isinstance(published.get("publication_artifact_id"), str)
            and re.fullmatch(r"[1-9][0-9]{0,19}", published["publication_artifact_id"]) is not None,
            "Committed publisher request does not name the admitted original qualification")
    for name in WORKFLOWS:
        path = ".github/workflows/" + name
        require(blob(target, path) == blob(CONTROL_BASE, path), "An existing final-admission workflow changed: " + name)
    require(blob(target, PUBLISHER) == blob(CONTROL_BASE, PUBLISHER), "Reviewed publisher workflow changed")
    return {"source": source, "source_tree": text("rev-parse", source + "^{tree}"), "published": target,
            "publication_request": request, "request_only_commits": revisions,
            "artifact_id": published["publication_artifact_id"]}


def validate_plan(plan: dict, value: dict, chain: dict) -> dict:
    context = {"repository": REPO, "branch": TARGET_BRANCH, "workflow": QUALIFIER,
               "run_id": value["qualification_run_id"], "run_attempt": value["qualification_run_attempt"],
               "workflow_run": "https://github.com/" + REPO + "/actions/runs/" + value["qualification_run_id"]}
    require(plan.get("schema") == 1 and plan.get("programme") == PROGRAMME
            and plan.get("source_commit") == chain["source"] and plan.get("source_tree") == chain["source_tree"]
            and plan.get("build_context") == context and plan.get("branch") == TARGET_BRANCH
            and plan.get("permitted_tracked_paths") == PATHS
            and plan.get("ready_or_merge_authorized") is False and plan.get("owner_visual_acceptance") == "pending",
            "Qualified publication plan changed original build/source, owner status or eight-path scope")
    require(set(plan.get("files_sha256", {})) == set(PATHS)
            and all(isinstance(digest, str) and SHA256.fullmatch(digest) is not None
                    for digest in plan["files_sha256"].values()), "Incomplete publication file hashes")
    return context


def validate_binding(binding: dict, platform: str, context: dict, chain: dict) -> None:
    require(binding.get("schema") == 1 and binding.get("programme") == PROGRAMME
            and binding.get("platform") == platform and binding.get("artifact") == CLIS[platform]
            and binding.get("source") == chain["source"] and binding.get("source_commit") == chain["source"]
            and binding.get("build_commit") == chain["source"] and binding.get("source_tree") == chain["source_tree"]
            and binding.get("build_context") == context and binding.get("draft_hold") is True
            and binding.get("owner_visual_acceptance") == "pending",
            "CLI binding changed original source, platform, run or Draft/HOLD status")


def inventory_at(revision: str, ledger: dict) -> None:
    require(isinstance(ledger, dict) and 0 < len(ledger) <= 10000, "Missing or oversized source ledger")
    names = sorted(ledger)
    for name in names:
        require(isinstance(name, str) and not PurePosixPath(name).is_absolute()
                and all(part not in ("", ".", "..") for part in name.split("/"))
                and "\n" not in name and "\r" not in name and "\0" not in name
                and isinstance(ledger[name], str) and SHA256.fullmatch(ledger[name]) is not None,
                "Invalid source ledger path or hash")
    process = subprocess.run(["git", "-C", str(ROOT), "cat-file", "--batch"], check=True,
                             input="".join(revision + ":" + name + "\n" for name in names).encode(),
                             stdout=subprocess.PIPE, timeout=90)
    data, cursor = process.stdout, 0
    for name in names:
        end = data.index(b"\n", cursor)
        header = data[cursor:end].split()
        require(len(header) == 3 and header[1] == b"blob" and header[2].isdigit(), "Source ledger object is not a blob")
        size = int(header[2])
        cursor = end + 1
        payload = data[cursor:cursor + size]
        require(len(payload) == size and data[cursor + size:cursor + size + 1] == b"\n"
                and hashlib.sha256(payload.replace(b"\r\n", b"\n")).hexdigest() == ledger[name],
                "Original compiled source ledger differs at " + name)
        cursor += size + 1
    require(cursor == len(data), "Unexpected source ledger batch output")


def publication_bytes(value: dict, chain: dict, destination: Path) -> dict:
    page = get("/actions/runs/" + value["qualification_run_id"] + "/artifacts?per_page=100")
    require(page.get("total_count", 101) <= 100, "Unexpectedly broad qualification artifact set")
    name = ("swarm45-runtime-publication-candidate-" + chain["source"] + "-"
            + value["qualification_run_id"] + "-" + value["qualification_run_attempt"])
    selected = [item for item in page.get("artifacts", []) if item.get("name") == name]
    require(len(selected) == 1 and str(selected[0].get("id")) == chain["artifact_id"], "Exact publication artifact is absent or ambiguous")
    artifact = selected[0]
    producer = artifact.get("workflow_run", {})
    require(artifact.get("expired") is False and type(artifact.get("size_in_bytes")) is int
            and 0 < artifact["size_in_bytes"] <= 128 * 1024 * 1024
            and str(producer.get("id")) == value["qualification_run_id"] and producer.get("head_sha") == chain["source"]
            and re.fullmatch(r"sha256:[0-9a-f]{64}", artifact.get("digest", "")) is not None,
            "Publication artifact producer, size or immutable digest changed")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("xb") as stream:
        subprocess.run(["gh", "api", "repos/" + REPO + "/actions/artifacts/" + chain["artifact_id"] + "/zip"],
                       check=True, stdout=stream, timeout=120)
    require(destination.stat().st_size == artifact["size_in_bytes"]
            and "sha256:" + hashlib.sha256(destination.read_bytes()).hexdigest() == artifact["digest"],
            "Immutable publication artifact bytes changed")
    with zipfile.ZipFile(destination) as archive:
        entries = [item for item in archive.infolist() if not item.is_dir()]
        require(len(entries) == 9 and {item.filename for item in entries} == {*PATHS, "publication-plan.json"}
                and sum(item.file_size for item in entries) <= 128 * 1024 * 1024
                and all((item.external_attr >> 16) & 0o170000 != 0o120000 for item in entries),
                "Publication archive exceeds the admitted nine-file payload")
        require(archive.getinfo("publication-plan.json").file_size <= 1024 * 1024, "Oversized publication plan")
        plan = decode(archive.read("publication-plan.json"))
        context = validate_plan(plan, value, chain)
        binaries = {*RUNTIMES.values(), *CLIS.values()}
        for path in PATHS:
            payload = archive.read(path)
            require(hashlib.sha256(payload).hexdigest() == plan["files_sha256"][path], "Qualified artifact file hash changed")
            current = blob(chain["published"], path)
            if path in binaries:
                expected = ("version https://git-lfs.github.com/spec/v1\noid sha256:" + plan["files_sha256"][path]
                            + "\nsize " + str(len(payload)) + "\n").encode()
                require(current == expected, "Published Git LFS pointer differs from the exact qualified bytes")
            else:
                require(current == payload, "Published runtime manifest differs from the immutable qualified payload")
            mode = text("ls-tree", chain["published"], "--", path).split()[0]
            require(mode == ("100755" if path == CLIS["linux"] else "100644"), "Published runtime Git mode changed")
        manifests = {platform: decode(archive.read(PROVENANCE[platform])) for platform in RUNTIMES}
        bindings = {platform: decode(archive.read(BINDINGS[platform])) for platform in RUNTIMES}
        for platform, manifest in manifests.items():
            require(manifest.get("schema_version") == 1
                    and manifest.get("kind") == "source-matched-swarm45-mainline-evaluation-candidate"
                    and manifest.get("source_commit") == chain["source"] and manifest.get("build_commit") == chain["source"]
                    and manifest.get("source_tree") == chain["source_tree"] and manifest.get("artifact") == RUNTIMES[platform]
                    and manifest.get("sha256") == plan["files_sha256"][RUNTIMES[platform]]
                    and manifest.get("size") == archive.getinfo(RUNTIMES[platform]).file_size
                    and manifest.get("workflow_run") == context["workflow_run"]
                    and manifest.get("build_attempt") == context["run_attempt"]
                    and manifest.get("owner_visual_acceptance") == "pending"
                    and manifest.get("reciprocal_programme_acceptance") is False,
                    "Published adapter changed original source/build/run or owner status")
            binding = bindings[platform]
            validate_binding(binding, platform, context, chain)
            require(binding.get("sha256") == plan["files_sha256"][CLIS[platform]]
                    and binding.get("bytes") == archive.getinfo(CLIS[platform]).file_size
                    and binding.get("native_definition_sha256") == manifest.get("native_definition_sha256"),
                    "Published CLI bytes or native definition changed")
        for key in ("source_inputs", "build_inputs", "native_definition_sha256"):
            require(manifests["linux"].get(key) == manifests["windows"].get(key), "Platform source ledgers differ")
        require(bindings["linux"].get("native_definition_inputs_sha256")
                == bindings["windows"].get("native_definition_inputs_sha256"), "Platform native definition ledgers differ")
        combined = {}
        for ledger in (manifests["linux"]["source_inputs"], manifests["linux"]["build_inputs"],
                       bindings["linux"]["native_definition_inputs_sha256"]):
            require(isinstance(ledger, dict), "Missing compiled source ledger")
            for path, digest in ledger.items():
                require(path not in combined or combined[path] == digest, "Conflicting compiled source hash")
                combined[path] = digest
        for revision in (chain["source"], chain["published"]):
            inventory_at(revision, combined)
    return {"id": artifact["id"], "name": name, "digest": artifact["digest"],
            "bytes": artifact["size_in_bytes"], "exact_published_paths": PATHS,
            "source_equivalent": True, "original_build_identity_retained": True}


def runs(name: str, value: dict) -> list[dict]:
    require(name in WORKFLOWS, "Unsupported final workflow")
    query = urllib.parse.urlencode({"branch": TARGET_BRANCH, "event": "workflow_dispatch",
                                    "head_sha": value["target_sha"], "per_page": 100})
    page = get("/actions/workflows/" + name + "/runs?" + query)
    require(page.get("total_count", 101) <= 100, "Unbounded final-admission run history")
    result = []
    for row in page.get("workflow_runs", []):
        require(row.get("head_sha") == value["target_sha"] and row.get("head_branch") == TARGET_BRANCH
                and row.get("event") == "workflow_dispatch" and row.get("repository", {}).get("full_name") == REPO
                and row.get("head_repository", {}).get("full_name") == REPO,
                "Workflow run query returned a different source/repository")
        result.append(row)
    return result


def run_identity(row: dict) -> dict:
    return {key: row.get(key) for key in ("id", "run_attempt", "head_sha", "head_branch", "event",
                                        "workflow_id", "status", "conclusion", "html_url", "created_at")}


def write_report(path: Path, report: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def dispatch(output: Path) -> None:
    report = {"schema": 1, "programme": PROGRAMME, "control_branch": CONTROL_BRANCH,
              "target_branch": TARGET_BRANCH, "permitted_workflows": list(WORKFLOWS), "dispatches": [],
              "admission_result": "pending", "owner_visual_acceptance": "pending",
              "ready_or_merge_authorized": False, "source_branch_mutated": False, "complete": False}
    write_report(output, report)
    try:
        value = current_request()
        report["request"] = value
        report["pr_lease"] = lease(value)
        chain = source_chain(value)
        report["source_chain"] = chain
        report["qualification"] = successful_run(value, "qualification", QUALIFIER, chain["source"])
        report["publication"] = successful_run(value, "publication", PUBLISHER, chain["publication_request"])
        report["published_payload"] = publication_bytes(value, chain, output.with_suffix(".publication.zip"))
        # These five fixed workflow definitions are unchanged from the reviewed
        # integration base. No arbitrary workflow names or inputs reach the API.
        workflows = {}
        for name in WORKFLOWS:
            workflow = get("/actions/workflows/" + name)
            require(workflow.get("path") == ".github/workflows/" + name and workflow.get("state") == "active",
                    "Final workflow is missing, disabled or changed")
            workflows[name] = workflow["id"]
        write_report(output, report)
        pending = []
        for name in WORKFLOWS:
            lease(value)
            prior = runs(name, value)
            eligible = [row for row in prior if row.get("status") != "completed" or row.get("conclusion") == "success"]
            require(len(eligible) <= 1, "Multiple equivalent active/success runs already exist: " + name)
            if eligible:
                require(eligible[0].get("workflow_id") == workflows[name], "Existing workflow identity changed")
                report["dispatches"].append({"workflow": name, "action": "existing; no dispatch sent",
                                             "run": run_identity(eligible[0])})
                write_report(output, report)
                continue
            before = {row["id"] for row in prior}
            started = datetime.now(timezone.utc).isoformat()
            status, _ = api(PREFIX + "/actions/workflows/" + name + "/dispatches", {"ref": TARGET_BRANCH})
            require(status == 204, "Dispatch was not accepted with HTTP204: " + name)
            row = {"workflow": name, "action": "dispatch accepted", "http_status": status,
                   "accepted_at": started, "expected_head_sha": value["target_sha"], "run": None}
            report["dispatches"].append(row)
            write_report(output, report)
            lease(value)
            pending.append((name, before, row))
        # Bounded visibility check, not a wait for expensive admission to finish.
        # A branch movement or ambiguous run cannot be reported as confirmation.
        deadline = time.monotonic() + 75
        while pending:
            for name, before, row in list(pending):
                matches = [candidate for candidate in runs(name, value) if candidate["id"] not in before]
                require(len(matches) <= 1, "Ambiguous new dispatch executions: " + name)
                if matches:
                    require(matches[0].get("workflow_id") == workflows[name], "Dispatched workflow identity changed")
                    row["run"] = run_identity(matches[0])
                    pending.remove((name, before, row))
                    write_report(output, report)
            if not pending:
                break
            require(time.monotonic() < deadline, "Accepted dispatch has no confirmed exact-head execution yet")
            time.sleep(5)
        lease(value)
        report["complete"] = True
        report["admission_result"] = "pending; exact-head executions confirmed, their results must be reviewed"
    except Exception as error:
        report["error"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        write_report(output, report)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    dispatch(arguments.output.resolve())


if __name__ == "__main__":
    main()
