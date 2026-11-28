#!/usr/bin/env python3
"""Guard an explicitly requested, leased eight-path runtime publication.

The qualification artifact is produced by the separate read-only workflow.
This helper never changes the original build identity or old publisher fences.
Git LFS staging, commit and the single fenced push remain visible in the new
publication workflow; neither Ready nor merge is an available operation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.request
import zipfile

import runtime_custody as custody
import run_request
from publication_candidate import BINDINGS, CLIS, PATHS, PROVENANCE, RUNTIMES

REQUEST = ".github/swarm456-runtime-publication-request.json"
WORKFLOW = ".github/workflows/swarm456-runtime-publication.yml"
KEYS = {"schema", "programme", "action", "request_id", "expected_parent_sha", "qualification_source_sha",
        "qualification_run_id", "qualification_run_attempt", "publication_artifact_id"}


def api(path: str) -> dict:
    custody.require(path.startswith("/repos/techrote/cybersand/") and ".." not in path, "Unexpected API scope")
    request = urllib.request.Request("https://api.github.com" + path, headers={
        "Authorization": "Bearer " + os.environ["GH_TOKEN"], "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.load(response)


def verify_request(root: Path, execution: str, event: dict) -> dict:
    run_request.commit(root, execution)
    custody.require(run_request.git(root, "rev-parse", "HEAD").decode().strip() == execution, "Publisher checkout differs from event head")
    custody.require(event.get("ref") == "refs/heads/" + custody.BRANCH and event.get("after") == execution
                    and event.get("created") is False and event.get("deleted") is False and event.get("forced") is False,
                    "Publisher requires an ordinary exact-branch request push")
    entry = run_request.git(root, "ls-tree", execution, "--", REQUEST).decode().split()
    custody.require(len(entry) == 4 and entry[0] == "100644" and entry[1] == "blob" and entry[3] == REQUEST,
                    "Publisher needs a committed regular request file")
    payload = run_request.git(root, "cat-file", "blob", entry[2])
    custody.require(0 < len(payload) <= 4096, "Publication request exceeds its finite budget")
    value = json.loads(payload, object_pairs_hook=run_request.unique_object)
    custody.require(isinstance(value, dict) and set(value) == KEYS and type(value["schema"]) is int
                    and value["schema"] == 1 and value["programme"] == custody.PROGRAMME
                    and value["action"] == "publish-runtime", "Invalid publication request contract")
    custody.require(isinstance(value["request_id"], str) and run_request.REQUEST_ID.fullmatch(value["request_id"]) is not None,
                    "Invalid explicit publication request id")
    for key in ("qualification_run_id", "qualification_run_attempt", "publication_artifact_id"):
        custody.require(isinstance(value[key], str) and value[key].isdecimal() and int(value[key]) > 0,
                        "Publication request needs a positive decimal " + key)
    parent = run_request.commit(root, value["expected_parent_sha"])
    source = run_request.commit(root, value["qualification_source_sha"])
    custody.require(run_request.git(root, "show", "--no-patch", "--format=%P", execution).decode().split() == [parent]
                    and event.get("before") == parent, "Publication request parent/branch lease changed")
    custody.require(run_request.ancestor(root, source, parent), "Qualified source is not the publication-request ancestor")
    revisions = run_request.git(root, "rev-list", "--max-count=17", source + ".." + execution).decode().splitlines()
    custody.require(0 < len(revisions) <= 16, "Publication request history exceeds its bounded ancestry")
    for revision in revisions:
        parents = run_request.git(root, "show", "--no-patch", "--format=%P", revision).decode().split()
        custody.require(len(parents) == 1 and run_request.changed(root, parents[0], revision) == [REQUEST],
                        "Source changed after qualification; only explicit publication-request commits are admitted")
    custody.require(run_request.ancestor(root, run_request.ACCEPTED_MAIN, execution)
                    and all(run_request.ancestor(root, donor, execution) for donor in run_request.DONORS.values()), "Publication left accepted-main/donor ancestry")
    return {**value, "execution_sha": execution, "request_sha256": hashlib.sha256(payload).hexdigest(),
            "request_only_commits": revisions}


def validate_run(request: dict, run: dict, workflow: dict, artifacts: list[dict]) -> dict:
    custody.require(str(run.get("id")) == request["qualification_run_id"]
                    and str(run.get("run_attempt")) == request["qualification_run_attempt"]
                    and run.get("head_sha") == request["qualification_source_sha"]
                    and run.get("head_branch") == custody.BRANCH and run.get("event") in ("push", "workflow_dispatch")
                    and run.get("status") == "completed" and run.get("conclusion") == "success",
                    "Requested qualification run/attempt is incomplete, failed or different-source")
    custody.require(run.get("repository", {}).get("full_name") == "techrote/cybersand"
                    and run.get("head_repository", {}).get("full_name") == "techrote/cybersand"
                    and workflow.get("path") == custody.WORKFLOW and str(workflow.get("id")) == str(run.get("workflow_id")),
                    "Qualification workflow/repository custody changed")
    name = "swarm456-runtime-publication-candidate-" + request["qualification_source_sha"] + "-" + request["qualification_run_id"] + "-" + request["qualification_run_attempt"]
    selected = [item for item in artifacts if item.get("name") == name]
    custody.require(len(selected) == 1 and str(selected[0].get("id")) == request["publication_artifact_id"]
                    and selected[0].get("expired") is False and selected[0].get("size_in_bytes", 0) > 0,
                    "Publication artifact is absent, expired, duplicated or different")
    producer = selected[0].get("workflow_run", {})
    custody.require(str(producer.get("id")) == request["qualification_run_id"]
                    and producer.get("head_sha") == request["qualification_source_sha"], "Artifact producer source/run mismatch")
    custody.require(re.fullmatch(r"sha256:[0-9a-f]{64}", selected[0].get("digest", "")) is not None,
                    "Immutable artifact SHA-256 is missing")
    return selected[0]


def current_request() -> dict:
    custody.require(os.environ.get("GITHUB_REPOSITORY") == "techrote/cybersand"
                    and os.environ.get("GITHUB_REF") == "refs/heads/" + custody.BRANCH
                    and os.environ.get("GITHUB_EVENT_NAME") == "push"
                    and os.environ.get("GITHUB_WORKFLOW_REF") == "techrote/cybersand/" + WORKFLOW + "@refs/heads/" + custody.BRANCH,
                    "Wrong publication execution context")
    event_path = Path(os.environ["GITHUB_EVENT_PATH"])
    custody.require(event_path.stat().st_size <= 4 * 1024 * 1024, "Oversized push event")
    event = json.loads(event_path.read_bytes(), object_pairs_hook=run_request.unique_object)
    value = verify_request(custody.ROOT, os.environ.get("GITHUB_SHA", ""), event)
    remote = custody.git(custody.ROOT, "ls-remote", "--exit-code", "origin", "refs/heads/" + custody.BRANCH)
    custody.require(remote == value["execution_sha"] + "\trefs/heads/" + custody.BRANCH, "Branch advanced; publication lease refused")
    return value


def gate(output: Path) -> None:
    value = current_request()
    run = api("/repos/techrote/cybersand/actions/runs/" + value["qualification_run_id"])
    workflow = api("/repos/techrote/cybersand/actions/workflows/" + str(run.get("workflow_id", "")))
    page = api("/repos/techrote/cybersand/actions/runs/" + value["qualification_run_id"] + "/artifacts?per_page=100")
    custody.require(page.get("total_count", 101) <= 100, "Unexpectedly broad qualification artifact set")
    artifact = validate_run(value, run, workflow, page.get("artifacts", []))
    custody.write_json(output, {"request": value, "run": run, "artifact": artifact})
    with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as stream:
        stream.write("run_id=" + value["qualification_run_id"] + "\n")
        stream.write("artifact_name=" + artifact["name"] + "\n")
    print(json.dumps({"source": value["qualification_source_sha"], "artifact_id": artifact["id"], "branch": custody.BRANCH}))


def verify_bundle(bundle: Path, request: dict) -> dict:
    plan = json.loads((bundle / "publication-plan.json").read_text(encoding="utf-8"))
    context = {"repository": "techrote/cybersand", "branch": custody.BRANCH, "workflow": custody.WORKFLOW,
               "run_id": request["qualification_run_id"], "run_attempt": request["qualification_run_attempt"],
               "workflow_run": "https://github.com/techrote/cybersand/actions/runs/" + request["qualification_run_id"]}
    source = request["qualification_source_sha"]
    source_tree = custody.git(custody.ROOT, "rev-parse", source + "^{tree}")
    custody.require(plan.get("schema") == 1 and plan.get("programme") == custody.PROGRAMME
                    and plan.get("qualification_programme") == custody.QUALIFICATION_PROGRAMME
                    and plan.get("source_commit") == source and plan.get("source_tree") == source_tree
                    and plan.get("build_context") == context and plan.get("branch") == custody.BRANCH
                    and plan.get("permitted_tracked_paths") == PATHS
                    and plan.get("ready_or_merge_authorized") is False and plan.get("owner_visual_acceptance") == "pending",
                    "Publication plan changed source, branch, run or scope")
    custody.require(set(plan.get("files_sha256", {})) == set(PATHS)
                    and set(custody.inventory(bundle)) == {*PATHS, "publication-plan.json"}, "Publication payload exceeds eight allowed paths")
    custody.verify_inventory(bundle, plan["files_sha256"])
    current = custody.source()
    for platform in RUNTIMES:
        manifest = json.loads((bundle / PROVENANCE[platform]).read_text(encoding="utf-8"))
        runtime = bundle / RUNTIMES[platform]
        custody.require(manifest.get("schema_version") == 1
                        and manifest.get("kind") == "source-matched-swarm45-mainline-evaluation-candidate"
                        and manifest.get("qualification_programme") == custody.QUALIFICATION_PROGRAMME
                        and manifest.get("source_commit") == source and manifest.get("build_commit") == source
                        and manifest.get("source_tree") == source_tree and manifest.get("artifact") == RUNTIMES[platform]
                        and manifest.get("source_inputs") == current["extension_inputs_sha256"]
                        and manifest.get("build_inputs") == current["build_inputs_sha256"]
                        and manifest.get("native_definition_sha256") == current["native_definition_sha256"]
                        and manifest.get("sha256") == custody.sha(runtime) and manifest.get("size") == runtime.stat().st_size
                        and custody.binary_format(runtime, platform), "Runtime/source equivalence or original build identity changed")
        custody.require(manifest.get("workflow_run") == context["workflow_run"]
                        and manifest.get("build_attempt") == context["run_attempt"]
                        and manifest.get("owner_visual_acceptance") == "pending"
                        and manifest.get("reciprocal_programme_acceptance") is False, "Runtime qualification or owner status changed")
        binding = json.loads((bundle / BINDINGS[platform]).read_text(encoding="utf-8"))
        cli = bundle / CLIS[platform]
        custody.require(binding.get("schema") == 1 and binding.get("programme") == custody.PROGRAMME
                        and binding.get("qualification_programme") == custody.QUALIFICATION_PROGRAMME
                        and binding.get("platform") == platform and binding.get("source") == source
                        and binding.get("artifact") == CLIS[platform]
                        and binding.get("source_commit") == source and binding.get("build_commit") == source
                        and binding.get("source_tree") == source_tree and binding.get("build_context") == context
                        and binding.get("native_definition_sha256") == current["native_definition_sha256"]
                        and binding.get("native_definition_inputs_sha256") == current["native_definition_inputs_sha256"]
                        and binding.get("sha256") == custody.sha(cli) and binding.get("bytes") == cli.stat().st_size
                        and binding.get("owner_visual_acceptance") == "pending" and binding.get("draft_hold") is True
                        and custody.binary_format(cli, platform), "Ordinary-checkout CLI/source binding changed")
    return plan


def download(gate_path: Path, output: Path) -> None:
    admitted = json.loads(gate_path.read_text(encoding="utf-8"))
    custody.require(admitted.get("request") == current_request(), "Download request lease changed")
    artifact = admitted["artifact"]
    custody.require(not output.exists() and 0 < artifact["size_in_bytes"] <= 128 * 1024 * 1024,
                    "Artifact destination or download budget refused")
    archive = output.with_suffix(".zip")
    archive.parent.mkdir(parents=True, exist_ok=True)
    with archive.open("xb") as stream:
        subprocess.run(["gh", "api", "repos/techrote/cybersand/actions/artifacts/" + str(artifact["id"]) + "/zip"],
                       check=True, stdout=stream, timeout=180)
    custody.require(archive.stat().st_size == artifact["size_in_bytes"]
                    and "sha256:" + custody.sha(archive) == artifact["digest"], "Immutable artifact archive digest/size changed")
    with zipfile.ZipFile(archive) as zipped:
        members = [item for item in zipped.infolist() if not item.is_dir()]
        custody.require(len(members) == 9 and {item.filename for item in members} == {*PATHS, "publication-plan.json"}
                        and sum(item.file_size for item in members) <= 128 * 1024 * 1024,
                        "Archive exceeds the nine-file publication payload")
        output.mkdir()
        for item in members:
            custody.require((item.external_attr >> 16) & 0o170000 != 0o120000, "Publication archive symlink refused")
            target = output / item.filename
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(zipped.read(item))
    verify_bundle(output, admitted["request"])


def stage(bundle: Path, gate_path: Path) -> None:
    value = current_request()
    admitted = json.loads(gate_path.read_text(encoding="utf-8"))
    custody.require(admitted.get("request") == value, "Request changed since artifact admission")
    # Check the live run again: a later rerun must not silently inherit an older
    # successful attempt or consume its artifact under a fresh attempt number.
    run = api("/repos/techrote/cybersand/actions/runs/" + value["qualification_run_id"])
    custody.require(run.get("conclusion") == "success" and str(run.get("run_attempt")) == value["qualification_run_attempt"],
                    "Qualification attempt changed after artifact admission")
    verify_bundle(bundle, value)
    for name in PATHS:
        target = custody.ROOT / name
        custody.require(not target.is_symlink(), "Runtime publication destination is a symlink")
    for name in PATHS:
        shutil.copyfile(bundle / name, custody.ROOT / name)
    (custody.ROOT / CLIS["linux"]).chmod(0o755)
    print("Staged exactly eight verified runtime paths; original source/build identities retained")


def verify_staged_payload(root: Path, bundle: Path, files_sha256: dict) -> dict:
    """Verify all eight index entries, including qualified byte-identical paths.

    Git omits unchanged files from a staged diff. Admission therefore depends on
    the complete verified payload, not on making each runtime appear changed.
    An omitted genuinely changed file, unrelated edit or substituted payload is
    still refused before publication.
    """
    custody.require(set(files_sha256) == set(PATHS), "Publication inventory must contain exactly eight paths")
    changed = [name.decode() for name in run_request.git(root, "diff", "--cached", "--name-only", "--no-renames", "-z").split(b"\0") if name]
    custody.require(bool(changed) and set(changed).issubset(PATHS),
                    "Staged publication is empty or exceeds the eight allowed paths")
    binaries = {*RUNTIMES.values(), *CLIS.values()}
    for path in PATHS:
        original, installed = bundle / path, root / path
        custody.require(original.is_file() and not original.is_symlink()
                        and installed.is_file() and not installed.is_symlink()
                        and custody.sha(original) == files_sha256[path]
                        and custody.sha(installed) == files_sha256[path],
                        "Materialized publication differs from qualified bytes: " + path)
        expected = original.read_bytes()
        if path in binaries:
            expected = ("version https://git-lfs.github.com/spec/v1\noid sha256:" + files_sha256[path]
                        + "\nsize " + str(original.stat().st_size) + "\n").encode()
        custody.require(run_request.git(root, "show", ":" + path) == expected,
                        "Staged publication differs from qualified bytes: " + path)
        mode = custody.git(root, "ls-files", "--stage", "--", path).split()[0]
        custody.require(mode == ("100755" if path == CLIS["linux"] else "100644"),
                        "Published runtime path has an unexpected Git mode: " + path)
    return {"permitted_paths": PATHS, "changed_paths": sorted(changed),
            "unchanged_byte_identical_paths": sorted(set(PATHS) - set(changed))}


def check_index(bundle: Path) -> None:
    request = current_request()
    plan = verify_bundle(bundle, request)
    result = verify_staged_payload(custody.ROOT, bundle, plan["files_sha256"])
    custody.git(custody.ROOT, "diff", "--exit-code", "--", *PATHS)
    print(json.dumps(result, sort_keys=True))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    admission = commands.add_parser("gate")
    admission.add_argument("--output", type=Path, required=True)
    stage_parser = commands.add_parser("stage")
    stage_parser.add_argument("--bundle", type=Path, required=True)
    stage_parser.add_argument("--gate", type=Path, required=True)
    fetch_parser = commands.add_parser("download")
    fetch_parser.add_argument("--gate", type=Path, required=True)
    fetch_parser.add_argument("--output", type=Path, required=True)
    index_parser = commands.add_parser("check-index")
    index_parser.add_argument("--bundle", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "gate":
        gate(args.output)
    elif args.command == "stage":
        stage(args.bundle, args.gate)
    elif args.command == "download":
        download(args.gate, args.output)
    else:
        check_index(args.bundle)


if __name__ == "__main__":
    main()
