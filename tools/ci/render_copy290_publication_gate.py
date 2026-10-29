#!/usr/bin/env python3
"""Fail-closed, UNARMED publication authorization and four-path staging contracts.

This module neither creates an owner request nor fetches credentials, writes LFS
objects, mutates the index, changes refs, or grants authorization. The future
publisher must independently fetch GitHub REST custody, original ZIP bytes,
source/manifest inventories, and the owner comment before calling these guards.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

from render_copy290_publication_preflight import (
    HOST_TARGETS, RETAINED, verify_host_receipts,
)

ROOT = Path(__file__).resolve().parents[2]
REPO = "techrote/cybersand"
OWNER = "techrote"
BRANCH = "prep/render-copy290-lfs-publish-gate-20261029"
BASE = "c6accb68370405a4b0f30302e0f9d18a911b090b"
TREE = "1131600fe9c84ba3b9876784e9ab119bd6ee6b50"
WORLD_BLOB = "a6afd8cad4264ac2eca0362d14711158e3606760"
TEST_BLOB = "5613d2166c71fa49fd2b8f65e8caa93857b5d65f"
RUN_ID = 40945893162
ATTEMPT = 1
REQUEST = "tools/ci/render_copy290_publish_request.json"
INTENT = "publish-only-cybersand-native-linux-windows-lfs"
ARTIFACT_IDS = {"linux": 12928489443, "windows": 12928933019}
ARTIFACT_DIGESTS = {
    "linux": "83ceb7c56260e732f3e6a5021caede7636ad9909836060048751ba9e11d5e60a",
    "windows": "374f58056ba3e31516bda9c8f7ba8e2816f1bfefbb3abdd44be9f8309ad7ac4b",
}
RUNTIME_DIGESTS = {
    "linux": "0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45",
    "windows": "5d07229f0b0bd3008f413cba71a90de540b919dc5a178ba1da649c438bc8b909",
}
RUNTIME = {platform: entry[2] for platform, entry in RETAINED.items()}
MANIFEST = {platform: entry[0] for platform, entry in RETAINED.items()}
ALLOWED_DELTA = frozenset({
    ".github/workflows/render-copy290-publication-gate.yml",
    "tools/ci/render_copy290_publication_gate.py",
    "tools/ci/test_render_copy290_publication_gate.py",
    "tools/ci/render_copy290_live_custody.py",
    "docs/audits/2026-10-29-render-copy290-publication-gate.md",
})
REQUEST_KEYS = frozenset({
    "schema", "intent", "producer_source_sha", "producer_source_tree",
    "producer_run_id", "producer_run_attempt", "artifact_ids",
    "artifact_sha256", "reviewed_writer_sha",
    "destination_branch",
})
MANIFEST_KEYS = frozenset({
    "acceptance", "artifact", "build_attempt", "build_commit",
    "build_inputs", "evidence", "platform", "schema_version", "sha256",
    "size", "source_commit", "source_input_hash_kind", "source_inputs",
    "source_tree", "status", "toolchain", "validated_platform",
    "validation_output", "validation_sha256", "workflow_attempt",
    "workflow_run",
})
BOUNDED_ACCEPTANCE = (
    "Source-matched Linux/Windows Godot 4.7 import, render-world 23/23 "
    "and render-patch handoff only. No full Native/TSan/Godot matrix, "
    "interactive performance, release, or physical-ejection admission."
)
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
HEX64 = re.compile(r"[0-9a-f]{64}\Z")


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise RuntimeError(reason)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def unique_object(pairs: list[tuple[str, object]]) -> dict:
    found = {}
    for key, value in pairs:
        require(key not in found, "Duplicate JSON field: " + key)
        found[key] = value
    return found


def json_object(raw: bytes, *, bound: int = 1_500_000) -> dict:
    require(type(raw) is bytes and 0 < len(raw) <= bound, "Bad JSON byte size/type")
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object,
                           parse_constant=lambda v: (_ for _ in ()).throw(
                               RuntimeError("Nonfinite JSON number: " + v)))
    except (ValueError, UnicodeError, TypeError) as exc:
        raise RuntimeError("Malformed UTF-8 JSON") from exc
    require(type(value) is dict, "Expected top-level JSON object")
    return value


def request_text(request: dict, request_commit_sha: str) -> str:
    """Exact one-purpose owner comment; no free-form 'approval' inference."""
    return (
        "AUTHORIZE Cybersand RENDER-COPY-290 LFS runtime publication\n"
        "request_commit_sha: " + request_commit_sha + "\n"
        "producer_source_sha: " + request["producer_source_sha"] + "\n"
        "producer_source_tree: " + request["producer_source_tree"] + "\n"
        "producer_run_id: " + str(request["producer_run_id"]) + "\n"
        "producer_run_attempt: " + str(request["producer_run_attempt"]) + "\n"
        "linux_artifact_id: " + str(request["artifact_ids"]["linux"]) + "\n"
        "linux_artifact_sha256: " + request["artifact_sha256"]["linux"] + "\n"
        "windows_artifact_id: " + str(request["artifact_ids"]["windows"]) + "\n"
        "windows_artifact_sha256: " + request["artifact_sha256"]["windows"] + "\n"
        "reviewed_writer_sha: " + request["reviewed_writer_sha"] + "\n"
        "destination_branch: " + request["destination_branch"]
    )


def verify_owner_authorization(request_bytes: bytes, comment: dict,
                               reviewed_writer_sha: str,
                               request_commit_sha: str) -> dict:
    """Check externally REST-fetched, *unedited* owner comment plus exact request.

    The caller must authenticate the exact request-only Git commit (a direct
    child of the reviewed writer), independently fetch the owner comment by
    its GitHub-assigned ID after that commit exists, then enforce
    that same commit as the remote branch-head lease before publication. Pure
    refusal rule, not a network call or authorization by the AI executing it.
    """
    request = json_object(request_bytes, bound=16384)
    require(set(request) == REQUEST_KEYS, "Publication request schema/keys differ")
    require(request.get("schema") == "render-copy290-publish-request-v1"
            and request.get("intent") == INTENT
            and request.get("producer_source_sha") == BASE
            and request.get("producer_source_tree") == TREE
            and type(request.get("producer_run_id")) is int
            and request["producer_run_id"] == RUN_ID
            and type(request.get("producer_run_attempt")) is int
            and request["producer_run_attempt"] == ATTEMPT
            and request.get("artifact_ids") == ARTIFACT_IDS
            and request.get("artifact_sha256") == ARTIFACT_DIGESTS
            and request.get("destination_branch") == BRANCH,
            "Request not bound to the frozen original Actions producer")
    require(type(reviewed_writer_sha) is str and HEX40.fullmatch(reviewed_writer_sha)
            and type(request.get("reviewed_writer_sha")) is str
            and request["reviewed_writer_sha"] == reviewed_writer_sha,
            "Request not bound to separately reviewed writer code SHA")
    require(type(request_commit_sha) is str and HEX40.fullmatch(request_commit_sha)
            and request_commit_sha != reviewed_writer_sha,
            "Missing distinct exact request commit SHA")
    # The owner comment is created only AFTER the request SHA exists.
    # Its GitHub-assigned ID must NOT be embedded in the request commit:
    # doing so would make the unedited source-bound authorization impossible.
    # The caller must independently fetch this original comment by REST ID.
    require(type(comment) is dict and type(comment.get("user")) is dict
            and comment["user"].get("login") == OWNER
            and comment.get("author_association") == "OWNER"
            and type(comment.get("id")) is int and comment["id"] > 0
            and comment.get("issue_url") ==
                "https://api.github.com/repos/" + REPO + "/issues/290"
            and comment.get("html_url") ==
                "https://github.com/" + REPO + "/pull/290#issuecomment-" + str(comment["id"]),
            "Owner identity or PR #290 comment custody differs")
    require(type(comment.get("created_at")) is str
            and re.fullmatch(r"20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",
                             comment["created_at"]) is not None
            and comment.get("updated_at") == comment["created_at"],
            "Owner comment is edited or lacks immutable timestamp")
    require(comment.get("body") == request_text(request, request_commit_sha),
            "Owner did not explicitly authorize exact request commit/source/run/ZIPs/writer/branch")
    return request


def verify_four_path_stage(staged: dict, host_bundles: dict,
                           trusted_runtime_digests: dict,
                           independently_verified_ledgers: dict) -> bool:
    """Pure staged-index/manifest refusal; does NOT call git add/LFS/push.

    Caller must authenticate original producer ZIP SHA-256/CRC, GitHub run/jobs,
    full actual Git-tree and materialized build-input maps independently before
    supplying bundles, digests and ledgers. This function cannot establish those
    external trust roots itself.
    """
    required_paths = set(RUNTIME.values()) | set(MANIFEST.values())
    require(type(staged) is dict and set(staged) == required_paths,
            "Atomic publication must change exactly two LFS paths and two manifests")
    require(type(trusted_runtime_digests) is dict
            and set(trusted_runtime_digests) == set(HOST_TARGETS)
            and all(type(d) is str and HEX64.fullmatch(d)
                    for d in trusted_runtime_digests.values()),
            "Missing authenticated, externally pinned host binary digests")
    require(type(independently_verified_ledgers) is dict
            and set(independently_verified_ledgers) == {"source_inputs", "build_inputs"},
            "Missing complete independent source/build inventories")
    native = independently_verified_ledgers["source_inputs"]
    build = independently_verified_ledgers["build_inputs"]
    require(type(native) is dict and len(native) == 80
            and type(build) is dict and len(build) >= 549
            and not (set(native) & set(build))
            and all(type(p) is str and p and type(v) is str
                    and HEX64.fullmatch(v) for x in (native, build) for p, v in x.items()),
            "Malformed source/build ledger (not complete independently verified inputs)")
    require(verify_host_receipts(host_bundles, BASE, TREE, RUN_ID, ATTEMPT),
            "Original dual-host runtime evidence invalid")
    for platform in ("linux", "windows"):
        runtime = host_bundles[platform]["runtime"]
        actual_digest = sha(runtime)
        require(actual_digest == trusted_runtime_digests[platform]
                and actual_digest != RETAINED[platform][3],
                "Runtime not identical to independently admitted new original host bytes")
        for path in (RUNTIME[platform], MANIFEST[platform]):
            value = staged[path]
            require(type(value) is dict and set(value) == {"mode", "blob"}
                    and value["mode"] == "100644" and type(value["blob"]) is bytes,
                    "Not a normal stage-zero regular file: " + path)
        pointer = ("version https://git-lfs.github.com/spec/v1\n"
                   "oid sha256:" + actual_digest + "\n"
                   "size " + str(len(runtime)) + "\n").encode("ascii")
        require(staged[RUNTIME[platform]]["blob"] == pointer,
                "Staged Git LFS pointer differs from original tested host bytes")
        raw_report = host_bundles[platform]["report"]
        manifest = json_object(staged[MANIFEST[platform]]["blob"])
        require(set(manifest) == MANIFEST_KEYS
                and type(manifest["schema_version"]) is int
                and manifest["schema_version"] == 1
                and manifest["platform"] == platform
                and manifest["artifact"] == RUNTIME[platform]
                and manifest["sha256"] == actual_digest
                and type(manifest["size"]) is int
                and manifest["size"] == len(runtime)
                and manifest["source_commit"] == BASE
                and manifest["source_tree"] == TREE
                and manifest["build_commit"] == BASE
                and manifest["status"] == "validated-development-runtime"
                and manifest["workflow_run"] ==
                    "https://github.com/" + REPO + "/actions/runs/" + str(RUN_ID)
                and manifest["workflow_attempt"] == str(ATTEMPT)
                and manifest["build_attempt"] == str(ATTEMPT)
                and manifest["validation_sha256"] == sha(raw_report)
                and manifest["validation_output"] ==
                    "render-copy290-host-evidence-" + platform + "-" + str(RUN_ID)
                    + "/host-evidence.json"
                and manifest["source_inputs"] == native
                and manifest["build_inputs"] == build
                and manifest["acceptance"] == BOUNDED_ACCEPTANCE
                and manifest["source_input_hash_kind"] ==
                    "SHA-256 of committed Git object bytes (LFS pointer, not payload)"
                and manifest["evidence"] ==
                    "docs/audits/2026-10-29-render-copy290-publication-gate.md"
                and manifest["validated_platform"] ==
                    ("Linux" if platform == "linux" else "Windows")
                    + " x86_64 Godot 4.7 (actual headless render host)"
                and type(manifest["toolchain"]) is str
                and (("gcc-13" if platform == "linux" else
                     "llvm-mingw-20260826-ucrt") in manifest["toolchain"]),
                "New " + platform + " provenance does not bind source, original runtime, "
                "actual Godot evidence, complete inputs and bounded acceptance")
    return True


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=60)


def check_unarmed() -> None:
    require(os.environ.get("GITHUB_REPOSITORY") == REPO
            and os.environ.get("GITHUB_EVENT_NAME") == "push"
            and os.environ.get("GITHUB_REF") == "refs/heads/" + BRANCH,
            "Unexpected repository, branch or event for unarmed check")
    head = git("rev-parse", "HEAD").decode().strip()
    require(head == os.environ.get("GITHUB_SHA"), "Checkout differs from event SHA")
    subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor",
                    BASE, head], check=True, timeout=60)
    changed = set(git("diff", "--name-only", BASE, "HEAD").decode().splitlines())
    require(changed == ALLOWED_DELTA, "Unarmed gate changed extra/missing files: "
            + repr(sorted(changed ^ ALLOWED_DELTA)))
    require(REQUEST not in set(git("ls-tree", "-r", "--name-only", "HEAD").decode().splitlines())
            and not (ROOT / REQUEST).exists()
            and not (ROOT / REQUEST).is_symlink(), "No publication request is authorized")
    for path, expected in (("native/src/world.cpp", WORLD_BLOB),
                           ("native/tests/test_world.cpp", TEST_BLOB)):
        require(git("rev-parse", "HEAD:" + path).decode().strip() == expected,
                "Corrected executable/test Git blob changed: " + path)
    for platform, (manifest_path, blob, runtime_path, digest, size) in RETAINED.items():
        require(git("rev-parse", "HEAD:" + manifest_path).decode().strip() == blob,
                "Historical " + platform + " manifest changed")
        pointer = ("version https://git-lfs.github.com/spec/v1\n"
                   "oid sha256:" + digest + "\nsize " + str(size) + "\n").encode()
        require(git("show", "HEAD:" + runtime_path) == pointer,
                "Historical " + platform + " LFS pointer changed")
    require(not git("status", "--porcelain", "--untracked-files=no").strip(),
            "Dirty tracked checkout")
    print("RENDER_COPY290_PUBLICATION_GATE UNARMED PASS: original source, "
          "historical LFS and absent request retained; NO PUBLISHER")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check-unarmed",))
    parser.parse_args()
    check_unarmed()
