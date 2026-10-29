#!/usr/bin/env python3
"""Request-gated runtime publisher for Cybersand RENDER-COPY-290.

The current branch is deliberately UNARMED: the publication request file is absent.
A future request must be a one-file child of a reviewed writer head, and an unedited
OWNER comment on PR #290 must sign that exact request commit. This helper performs
no Git push itself; the branch-scoped workflow owns the final lease-protected push.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

import render_copy290_live_custody as custody
import render_copy290_publication_gate as gate
import render_copy290_publication_preflight as preflight

ROOT = Path(__file__).resolve().parents[2]
REPO = "techrote/cybersand"
BRANCH = "prep/render-copy290-runtime-writer-20261029"
BASE = "d249435d041fd27e0508701e69fd6e7a29a8610a"
REQUEST = gate.REQUEST
WRITER_FILES = frozenset({
    ".github/workflows/render-copy290-runtime-publisher.yml",
    "tools/ci/render_copy290_runtime_publisher.py",
    "tools/ci/test_render_copy290_runtime_publisher.py",
    "docs/audits/2026-10-29-render-copy290-runtime-publisher.md",
})
PUBLICATION_PATHS = frozenset(set(gate.RUNTIME.values()) | set(gate.MANIFEST.values()))
SUFFIX = frozenset({".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx",
                    ".inc", ".inl", ".tpp"})
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
GATE_BRANCH = gate.BRANCH
EXTERNAL_PINS = {
    "godot_linux_sha256": "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c",
    "godot_windows_sha512": "41645a908eb3181d6f2d1201ed7b6f095f6a23aaed8903d5d255277cc8d142814f3e6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9",
    "rapier_linux_sha256": "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a",
    "rapier_windows_sha256": "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7",
    "llvm_mingw_sha256": "cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65",
    "godot_cpp_commit": "101ae38034304346a46ea9ea84ae156d3e860496",
    "scons_version": "4.10.1",
}

# The owner-authentication gate was written for the preceding gate branch.
# The prospective request must instead name this separately reviewed writer branch.
gate.BRANCH = BRANCH


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args, text=False):
    value = subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=120)
    return value.decode() if text else value


def names_between(base, head):
    raw = git("diff", "--name-only", "-z", base, head)
    return {x.decode("utf-8") for x in raw.split(b"\0") if x}


def tracked_paths(commit):
    return {x.decode("utf-8") for x in git("ls-tree", "-r", "--name-only", "-z", commit).split(b"\0") if x}


def writer_shape(writer_sha):
    require(type(writer_sha) is str and HEX40.fullmatch(writer_sha), "Malformed writer SHA")
    subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", BASE, writer_sha],
                   check=True, timeout=60)
    require(names_between(BASE, writer_sha) == WRITER_FILES,
            "Reviewed writer must differ from gate base by exactly four writer-preparation files")
    require(REQUEST not in tracked_paths(writer_sha), "Reviewed writer unexpectedly contains a request")
    for path, expected in (
        ("native/src/world.cpp", gate.WORLD_BLOB),
        ("native/tests/test_world.cpp", gate.TEST_BLOB),
    ):
        require(git("rev-parse", writer_sha + ":" + path, text=True).strip() == expected,
                "Writer changed frozen source: " + path)
    return True


def validate_request(raw, request_sha):
    request = gate.json_object(raw, bound=16384)
    require(set(request) == gate.REQUEST_KEYS, "Publication request schema/keys differ")
    require(request.get("schema") == "render-copy290-publish-request-v1"
            and request.get("intent") == gate.INTENT
            and request.get("producer_source_sha") == gate.BASE
            and request.get("producer_source_tree") == gate.TREE
            and type(request.get("producer_run_id")) is int
            and request["producer_run_id"] == gate.RUN_ID
            and type(request.get("producer_run_attempt")) is int
            and request["producer_run_attempt"] == gate.ATTEMPT
            and request.get("artifact_ids") == gate.ARTIFACT_IDS
            and request.get("artifact_sha256") == gate.ARTIFACT_DIGESTS
            and request.get("destination_branch") == BRANCH
            and type(request.get("reviewed_writer_sha")) is str
            and HEX40.fullmatch(request["reviewed_writer_sha"]),
            "Request is not bound to the frozen producer and writer branch")
    parts = git("rev-list", "--parents", "-n", "1", request_sha, text=True).strip().split()
    require(len(parts) == 2 and parts[0] == request_sha
            and parts[1] == request["reviewed_writer_sha"],
            "Request must be a single-parent direct child of the reviewed writer")
    writer_shape(request["reviewed_writer_sha"])
    require(names_between(request["reviewed_writer_sha"], request_sha) == {REQUEST},
            "Request commit must change exactly the request file")
    committed = git("show", request_sha + ":" + REQUEST)
    require(committed == raw, "On-disk request differs from committed request bytes")
    return request


def source_shape(source_sha):
    require(type(source_sha) is str and HEX40.fullmatch(source_sha), "Malformed source SHA")
    require(git("rev-parse", "HEAD", text=True).strip() == source_sha,
            "Checkout differs from selected source SHA")
    paths = tracked_paths(source_sha)
    if REQUEST not in paths:
        writer_shape(source_sha)
        require(not (ROOT / REQUEST).exists() and not (ROOT / REQUEST).is_symlink(),
                "Unarmed writer has an on-disk request")
        return {"armed_candidate": False, "writer_sha": source_sha, "request": None}
    path = ROOT / REQUEST
    require(path.is_file() and not path.is_symlink(), "Request is not a normal file")
    raw = path.read_bytes()
    request = validate_request(raw, source_sha)
    return {"armed_candidate": True, "writer_sha": request["reviewed_writer_sha"],
            "request": request, "request_bytes": raw}


def context(source_sha):
    require(os.getenv("GITHUB_REPOSITORY") == REPO, "Wrong GitHub repository")
    require(os.getenv("GITHUB_EVENT_NAME") == "push", "Publisher only accepts branch push/rerun context")
    require(os.getenv("GITHUB_REF") == "refs/heads/" + BRANCH, "Wrong publisher branch")
    require(os.getenv("GITHUB_SHA") == source_sha, "Event SHA differs from checkout")


def remote_lease(source_sha):
    remote = git("ls-remote", "--exit-code", "origin", "refs/heads/" + BRANCH,
                 text=True).strip()
    require(remote == source_sha + "\trefs/heads/" + BRANCH,
            "Publisher branch changed after source selection")
    return True


def list_issue_comments():
    comments = []
    for page in range(1, 11):
        batch = custody.rest("issues/290/comments?per_page=100&page=" + str(page))
        require(type(batch) is list, "Malformed GitHub comment response")
        comments.extend(batch)
        if len(batch) < 100:
            return comments
    raise RuntimeError("PR #290 comment pagination exceeded safety bound")


def select_authorization(request_bytes, request, request_sha, comments):
    expected = gate.request_text(request, request_sha)
    accepted = []
    for comment in comments:
        if type(comment) is not dict or comment.get("body") != expected:
            continue
        try:
            gate.verify_owner_authorization(
                request_bytes, comment, request["reviewed_writer_sha"], request_sha)
        except RuntimeError:
            continue
        accepted.append(comment)
    require(len(accepted) <= 1, "Multiple exact owner authorizations found; refuse ambiguity")
    return accepted[0] if accepted else None


def authorization(source_sha, *, required):
    state = source_shape(source_sha)
    if not state["armed_candidate"]:
        if required:
            raise RuntimeError("Publication request is absent")
        return state, None
    comments = list_issue_comments()
    comment = select_authorization(
        state["request_bytes"], state["request"], source_sha, comments)
    if required:
        require(comment is not None, "No exact unedited owner authorization for this request commit")
    return state, comment


def artifact_set():
    run = custody.rest("actions/runs/" + str(gate.RUN_ID))
    jobs_response = custody.rest("actions/runs/" + str(gate.RUN_ID) + "/jobs?per_page=100")
    artifacts_response = custody.rest("actions/runs/" + str(gate.RUN_ID) + "/artifacts?per_page=100")
    jobs = jobs_response["jobs"]
    artifacts = artifacts_response["artifacts"]
    require(jobs_response["total_count"] == 3 and len(jobs) == 3, "Incomplete original producer jobs")
    require(artifacts_response["total_count"] == 4 and len(artifacts) == 4,
            "Original producer artifact inventory changed")
    expected = custody.verify_actions_custody(
        run, jobs, artifacts, gate.BASE, gate.RUN_ID, gate.ATTEMPT,
        custody.PRODUCER_BRANCH, custody.WORKFLOW_PATH)
    raw = {}
    by_id = {a["id"]: a for a in artifacts}
    for role, artifact_id in custody.ORIGINAL_ARTIFACT_IDS.items():
        item = by_id.get(artifact_id)
        require(item is not None and item.get("digest") ==
                "sha256:" + custody.ORIGINAL_ARTIFACT_DIGESTS[role],
                "Original artifact metadata differs: " + role)
        data = custody.rest("actions/artifacts/" + str(artifact_id) + "/zip", binary=True)
        require(sha(data) == custody.ORIGINAL_ARTIFACT_DIGESTS[role],
                "Original artifact ZIP bytes differ: " + role)
        raw[role] = data
    require(expected == {
        p: "sha256:" + custody.ORIGINAL_ARTIFACT_DIGESTS[p + "-host"]
        for p in ("linux", "windows")
    }, "Host artifact digests differ from independently authenticated Actions metadata")
    require(custody.verify_host_artifact_archives(
        {"linux": raw["linux-host"], "windows": raw["windows-host"]},
        expected, gate.BASE, gate.TREE, gate.RUN_ID, gate.ATTEMPT),
        "Original host evidence failed strict ZIP/host verification")
    return run, jobs, artifacts, raw


def host_bundle(raw_zip, platform):
    with zipfile.ZipFile(io.BytesIO(raw_zip)) as archive:
        runtime_name = preflight.HOST_ARCHIVE_RUNTIME[platform]
        return {
            "report": archive.read("host-evidence.json"),
            "runtime": archive.read(runtime_name),
            "logs": {name: archive.read("logs/" + name + ".log")
                     for name in preflight.HOST_CASES},
        }


def full_ledgers():
    committed = custody.git_blob_sha_map(gate.BASE)
    native = {
        p: digest for p, digest in committed.items()
        if p.startswith(("native/include/", "native/src/", "godot/native_extension/"))
        and Path(p).suffix in SUFFIX
    }
    require(len(native) == 80, "Frozen source no longer has the expected 80 native inputs")
    build = {p: digest for p, digest in committed.items() if p not in native}
    require(len(build) >= 549 and not (set(native) & set(build)),
            "Incomplete conservative tracked build/source remainder ledger")
    return {"source_inputs": dict(sorted(native.items())),
            "build_inputs": dict(sorted(build.items()))}, committed


def verify_build_archives(raw, committed):
    builds = {
        role: custody.artifact_members(raw[role], custody.BUILD_FILES[role], role)
        for role in custody.BUILD_FILES
    }
    linux, windows = builds["linux-build"], builds["windows-build"]
    manifests = [json.loads(linux["tracked-git-inputs.json"]),
                 json.loads(windows["tracked-git-inputs.json"])]
    require(manifests[0] == manifests[1], "Cross-host full Git ledgers differ")
    tracked = manifests[0]
    require(tracked.get("schema") == "render-copy290-tracked-git-inputs-v1"
            and tracked.get("source_sha") == gate.BASE
            and tracked.get("source_tree") == gate.TREE
            and tracked.get("input_count") == len(committed)
            and tracked.get("inputs") == committed,
            "Original full tracked-Git ledger differs from independently rehashed Git")
    selected = [custody.parse_selected(linux["selected-build-inputs.sha256"]),
                custody.parse_selected(windows["selected-build-inputs.sha256"])]
    require(selected[0] == selected[1]
            and all(committed.get(p) == d for p, d in selected[0].items()),
            "Original 86 materialized build-input hashes differ across hosts or Git")
    custody.post_check(linux["post-build-input-check.txt"], selected[0], "Linux build")
    custody.post_check(windows["post-build-input-check.txt"], selected[1], "Windows build")
    custody.post_check(linux["post-host-input-check.txt"], selected[0], "Linux host")
    for role, build in builds.items():
        require(build["source.txt"].decode().strip() == gate.BASE
                and build["tree.txt"].decode().strip() == gate.TREE
                and build["godot-cpp-commit.txt"].decode().strip()
                    == EXTERNAL_PINS["godot_cpp_commit"]
                and EXTERNAL_PINS["scons_version"] in build["scons-version.txt"].decode(),
                "Original source/toolchain record differs: " + role)
    workflow = git("show", gate.BASE + ":" + custody.WORKFLOW_PATH)
    for label, value in EXTERNAL_PINS.items():
        if label == "scons_version":
            continue
        require(value.encode() in workflow, "Producer workflow lost external pin: " + label)
    return builds, selected[0]


def manifest(platform, bundle, ledgers):
    binary = bundle["runtime"]
    digest = sha(binary)
    report = bundle["report"]
    return {
        "schema_version": 1,
        "platform": platform,
        "artifact": gate.RUNTIME[platform],
        "sha256": digest,
        "size": len(binary),
        "source_commit": gate.BASE,
        "source_tree": gate.TREE,
        "build_commit": gate.BASE,
        "status": "validated-development-runtime",
        "workflow_run": "https://github.com/" + REPO + "/actions/runs/" + str(gate.RUN_ID),
        "workflow_attempt": str(gate.ATTEMPT),
        "build_attempt": str(gate.ATTEMPT),
        "validation_sha256": sha(report),
        "validation_output": "render-copy290-host-evidence-" + platform + "-"
                             + str(gate.RUN_ID) + "/host-evidence.json",
        "source_inputs": ledgers["source_inputs"],
        "build_inputs": ledgers["build_inputs"],
        "acceptance": gate.BOUNDED_ACCEPTANCE,
        "source_input_hash_kind":
            "SHA-256 of committed Git object bytes (LFS pointer, not payload)",
        "evidence": "docs/audits/2026-10-29-render-copy290-publication-gate.md",
        "validated_platform": ("Linux" if platform == "linux" else "Windows")
                              + " x86_64 Godot 4.7 (actual headless render host)",
        "toolchain": gate.HOST_TARGETS[platform][1],
    }


def canonical_json(value):
    return (json.dumps(value, sort_keys=True, indent=2) + "\n").encode("utf-8")


def staged_preview(host, ledgers):
    staged = {}
    trusted = {}
    manifests = {}
    for platform in ("linux", "windows"):
        binary = host[platform]["runtime"]
        digest = sha(binary)
        trusted[platform] = digest
        pointer = ("version https://git-lfs.github.com/spec/v1\n"
                   "oid sha256:" + digest + "\n"
                   "size " + str(len(binary)) + "\n").encode("ascii")
        staged[gate.RUNTIME[platform]] = {"mode": "100644", "blob": pointer}
        manifests[platform] = manifest(platform, host[platform], ledgers)
        staged[gate.MANIFEST[platform]] = {
            "mode": "100644", "blob": canonical_json(manifests[platform])}
    require(trusted == gate.RUNTIME_DIGESTS, "Original tested runtime digests differ from frozen admission")
    require(gate.verify_four_path_stage(staged, host, trusted, ledgers),
            "Four-path publication stage failed")
    return staged, manifests, trusted



def verify_originals(source_sha, output):
    """Exercise real producer/artifact/provenance reconstruction without authority or writes."""
    context(source_sha)
    state = source_shape(source_sha)
    run, jobs, artifacts, raw = artifact_set()
    host = {platform: host_bundle(raw[platform + "-host"], platform)
            for platform in ("linux", "windows")}
    ledgers, committed = full_ledgers()
    builds, selected = verify_build_archives(raw, committed)
    staged, manifests, trusted = staged_preview(host, ledgers)
    receipt = {
        "schema": "cybersand.render-copy290-writer-real-artifact-dry-run.v1",
        "writer_or_request_head": source_sha,
        "request_present": state["armed_candidate"],
        "producer_run_id": gate.RUN_ID,
        "producer_run_attempt": gate.ATTEMPT,
        "producer_head": gate.BASE,
        "producer_tree": gate.TREE,
        "producer_jobs": sorted(job["name"] for job in jobs),
        "original_artifacts": {
            role: {"id": custody.ORIGINAL_ARTIFACT_IDS[role],
                   "zip_sha256": custody.ORIGINAL_ARTIFACT_DIGESTS[role]}
            for role in sorted(custody.ORIGINAL_ARTIFACT_IDS)
        },
        "runtime_sha256": trusted,
        "full_git_blob_count": len(committed),
        "native_source_inputs": len(ledgers["source_inputs"]),
        "conservative_build_remainder_inputs": len(ledgers["build_inputs"]),
        "selected_materialized_build_inputs": len(selected),
        "external_pins": EXTERNAL_PINS,
        "prospective_pointer_sha256": {
            platform: sha(staged[gate.RUNTIME[platform]]["blob"])
            for platform in ("linux", "windows")
        },
        "prospective_manifest_sha256": {
            platform: sha(staged[gate.MANIFEST[platform]]["blob"])
            for platform in ("linux", "windows")
        },
        "publication_paths": sorted(PUBLICATION_PATHS),
        "qualified_scope": "read-only real-artifact reconstruction and four-path preview; NO OWNER AUTHORITY OR LFS WRITE",
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical_json(receipt))
    print("RENDER_COPY290_PUBLISHER REAL-ARTIFACT DRY-RUN PASS -- NO PUBLICATION")
    return receipt

def materialize(source_sha, output):
    context(source_sha)
    state, comment = authorization(source_sha, required=True)
    require(comment is not None, "Owner authorization disappeared")
    remote_lease(source_sha)
    run, jobs, artifacts, raw = artifact_set()
    host = {p: host_bundle(raw[p + "-host"], p) for p in ("linux", "windows")}
    ledgers, committed = full_ledgers()
    builds, selected = verify_build_archives(raw, committed)
    staged, manifests, trusted = staged_preview(host, ledgers)
    output.mkdir(parents=True, exist_ok=True)
    for platform in ("linux", "windows"):
        (output / Path(gate.RUNTIME[platform]).name).write_bytes(host[platform]["runtime"])
        (output / Path(gate.MANIFEST[platform]).name).write_bytes(
            canonical_json(manifests[platform]))
        evidence = output / ("host-" + platform)
        (evidence / "logs").mkdir(parents=True, exist_ok=True)
        (evidence / "host-evidence.json").write_bytes(host[platform]["report"])
        for name, data in host[platform]["logs"].items():
            (evidence / "logs" / (name + ".log")).write_bytes(data)
    (output / "ledgers.json").write_bytes(canonical_json(ledgers))
    receipt = {
        "schema": "cybersand.render-copy290-publication-prepared.v1",
        "request_commit": source_sha,
        "reviewed_writer_sha": state["writer_sha"],
        "owner_comment_id": comment["id"],
        "owner_comment_url": comment["html_url"],
        "producer_run_id": gate.RUN_ID,
        "producer_run_attempt": gate.ATTEMPT,
        "producer_head": gate.BASE,
        "producer_tree": gate.TREE,
        "producer_jobs": sorted(j["name"] for j in jobs),
        "original_artifacts": {
            role: {"id": custody.ORIGINAL_ARTIFACT_IDS[role],
                   "zip_sha256": custody.ORIGINAL_ARTIFACT_DIGESTS[role]}
            for role in sorted(custody.ORIGINAL_ARTIFACT_IDS)
        },
        "runtime_sha256": trusted,
        "full_git_blob_count": len(committed),
        "native_source_inputs": len(ledgers["source_inputs"]),
        "conservative_build_remainder_inputs": len(ledgers["build_inputs"]),
        "selected_materialized_build_inputs": len(selected),
        "external_pins": EXTERNAL_PINS,
        "publication_paths": sorted(PUBLICATION_PATHS),
        "limitations": [
            "Prepared evidence is not a Git/LFS publication until the write job commits and pushes.",
            "Manual target-PC GPU/Web performance and final ready-head matrices remain separate.",
            "Issue #292 sibling copy overflow and #283 physical ejection NO-GO are separate.",
        ],
    }
    (output / "receipt.json").write_bytes(canonical_json(receipt))
    print("RENDER_COPY290_PUBLISHER MATERIALIZE PASS -- original dual-host bytes and provenance verified")
    return receipt


def load_bundle(directory):
    ledgers = json.loads((directory / "ledgers.json").read_text(encoding="utf-8"))
    host = {}
    for platform in ("linux", "windows"):
        evidence = directory / ("host-" + platform)
        host[platform] = {
            "report": (evidence / "host-evidence.json").read_bytes(),
            "runtime": (directory / Path(gate.RUNTIME[platform]).name).read_bytes(),
            "logs": {name: (evidence / "logs" / (name + ".log")).read_bytes()
                     for name in preflight.HOST_CASES},
        }
    return host, ledgers


def check_index(source_sha, bundle):
    context(source_sha)
    state, comment = authorization(source_sha, required=True)
    require(comment is not None, "Owner authorization disappeared before index check")
    remote_lease(source_sha)
    changed = {x.decode("utf-8") for x in
               git("diff", "--cached", "--name-only", "-z").split(b"\0") if x}
    require(changed == PUBLICATION_PATHS,
            "Staged publication must contain exactly the four runtime/manifest paths")
    staged = {}
    for path in sorted(PUBLICATION_PATHS):
        entries = git("ls-files", "--stage", "--", path, text=True).splitlines()
        require(len(entries) == 1 and entries[0].startswith("100644 ")
                and entries[0].endswith(" 0\t" + path),
                "Publication path is not a regular stage-zero file: " + path)
        staged[path] = {"mode": "100644", "blob": git("show", ":" + path)}
    host, ledgers = load_bundle(bundle)
    trusted = {p: sha(host[p]["runtime"]) for p in host}
    require(gate.verify_four_path_stage(staged, host, trusted, ledgers),
            "Actual Git index failed four-path verification")
    require(not git("diff", "--name-only", "-z").strip(),
            "Unstaged tracked changes exist beside publication index")
    subprocess.run(["git", "-C", str(ROOT), "diff", "--cached", "--check"],
                   check=True, timeout=60)
    print("RENDER_COPY290_PUBLISHER INDEX PASS -- exact four staged paths")
    return state


def post_push(source_sha, published_sha, bundle, output):
    require(type(published_sha) is str and HEX40.fullmatch(published_sha), "Malformed publication SHA")
    parts = git("rev-list", "--parents", "-n", "1", published_sha, text=True).strip().split()
    require(len(parts) == 2 and parts[1] == source_sha,
            "Published commit is not a single direct child of authorized request")
    require(names_between(source_sha, published_sha) == PUBLICATION_PATHS,
            "Published commit does not contain exactly four runtime paths")
    remote = git("ls-remote", "--exit-code", "origin", "refs/heads/" + BRANCH,
                 text=True).strip()
    require(remote == published_sha + "\trefs/heads/" + BRANCH,
            "Remote branch does not identify publication commit")
    receipt = json.loads((bundle / "receipt.json").read_text(encoding="utf-8"))
    receipt["schema"] = "cybersand.render-copy290-publication-final.v1"
    receipt["publication_commit"] = published_sha
    receipt["remote_branch"] = BRANCH
    receipt["remote_ref_verified"] = True
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical_json(receipt))
    print("RENDER_COPY290_PUBLISHER POST-PUSH PASS " + published_sha)


def admission(source_sha):
    context(source_sha)
    state = source_shape(source_sha)
    armed = False
    if state["armed_candidate"]:
        remote_lease(source_sha)
        comments = list_issue_comments()
        comment = select_authorization(
            state["request_bytes"], state["request"], source_sha, comments)
        armed = comment is not None
    output = os.getenv("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as handle:
            handle.write("armed=" + ("true" if armed else "false") + "\n")
    if armed:
        print("RENDER_COPY290_PUBLISHER ARMED: exact request commit and unedited OWNER authorization match")
    elif state["armed_candidate"]:
        print("RENDER_COPY290_PUBLISHER UNARMED: request exists but exact owner authorization is absent; rerun this same SHA only after consent")
    else:
        print("RENDER_COPY290_PUBLISHER UNARMED: publication request absent")
    return armed


def guard(source_sha):
    context(source_sha)
    state = source_shape(source_sha)
    if state["armed_candidate"]:
        remote_lease(source_sha)
        print("RENDER_COPY290_PUBLISHER GUARD PASS: exact request-only child; authorization not inferred")
    else:
        print("RENDER_COPY290_PUBLISHER GUARD PASS: reviewed-writer preparation; request absent")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("guard", "admission", "verify-originals", "materialize", "check-index", "post-push"):
        cmd = sub.add_parser(name)
        cmd.add_argument("--source-sha", required=True)
        if name in ("verify-originals", "materialize"):
            cmd.add_argument("--output", type=Path, required=True)
        if name == "check-index":
            cmd.add_argument("--bundle", type=Path, required=True)
        if name == "post-push":
            cmd.add_argument("--published-sha", required=True)
            cmd.add_argument("--bundle", type=Path, required=True)
            cmd.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "guard":
        guard(args.source_sha)
    elif args.command == "admission":
        admission(args.source_sha)
    elif args.command == "verify-originals":
        verify_originals(args.source_sha, args.output)
    elif args.command == "materialize":
        materialize(args.source_sha, args.output)
    elif args.command == "check-index":
        check_index(args.source_sha, args.bundle)
    else:
        post_push(args.source_sha, args.published_sha, args.bundle, args.output)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print("RENDER_COPY290_PUBLISHER FAILED: " + str(exc), file=sys.stderr)
        raise
