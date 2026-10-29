#!/usr/bin/env python3
"""Read-only external GitHub Actions custody reducer for Cybersand PR #298.

Run only against frozen original producer run 40943327168 on the dedicated
verification-only branch. Never produce, stage, upload or publish LFS runtimes.
GitHub REST is authenticated by Actions' read-only GITHUB_TOKEN; the producer
cannot supply or alter its own trusted run/job/artifact envelope.
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
import tarfile
import urllib.request
import urllib.parse
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "ci"))
from render_copy290_publication_preflight import (  # noqa: E402
    verify_actions_custody,
    verify_host_artifact_archives,
)

REPO = "techrote/cybersand"
PARENT = "c6accb68370405a4b0f30302e0f9d18a911b090b"
BRANCH = "verify/render-copy290-live-custody-integrated-20261029"
PRODUCER_BRANCH = "verify/render-copy290-host-producer-20261029"
WORKFLOW_PATH = ".github/workflows/render-copy290-host-producer.yml"
RUN_ID = 40945893162
ATTEMPT = 1
EXPECTED_RUNTIME_SOURCE = "60915dc86631271ea8661377a3458149adda9361"
EXPECTED_BLOBS = {
    "native/src/world.cpp": "a6afd8cad4264ac2eca0362d14711158e3606760",
    "native/tests/test_world.cpp": "5613d2166c71fa49fd2b8f65e8caa93857b5d65f",
}
ALLOWED_DELTA = {
    ".github/workflows/render-copy290-live-custody.yml",
    "tools/ci/render_copy290_live_custody.py",
}
ORIGINAL_ARTIFACT_IDS = {
    "linux-host": 12928489443,
    "windows-host": 12928933019,
    "linux-build": 12928514222,
    "windows-build": 12929921671,
}
ORIGINAL_ARTIFACT_DIGESTS = {
    "linux-host": "83ceb7c56260e732f3e6a5021caede7636ad9909836060048751ba9e11d5e60a",
    "windows-host": "374f58056ba3e31516bda9c8f7ba8e2816f1bfefbb3abdd44be9f8309ad7ac4b",
    "linux-build": "926f788dda17fbc35a0758141b9a657fe77690fab8a71ff8803087326c0f2772",
    "windows-build": "eed0ba6f8dd3121a7c01c56b5680d2eaa5a6b58c767b44789753d7f0e9adb009",
}
BUILD_FILES = {
    "linux-build": {
        "source.txt", "tree.txt", "tracked-git-inputs.json", "selected-build-inputs.sha256",
        "post-build-input-check.txt", "post-host-input-check.txt",
        "runtime.sha256", "compiler-version.txt", "scons-version.txt",
        "godot-cpp-commit.txt", "native-build.txt", "godot-cpp-build.txt",
        "import.txt", "render-world.txt", "render-patches.txt",
    },
    "windows-build": {
        "source.txt", "tree.txt", "tracked-git-inputs.json", "selected-build-inputs.sha256",
        "post-build-input-check.txt", "runtime.sha256", "compiler-version.txt",
        "scons-version.txt", "godot-cpp-commit.txt", "native-build.txt",
        "godot-cpp-build.txt", "cybersand_native.windows.x86_64.dll",
    },
}


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def preflight():
    head = git("rev-parse", "HEAD")
    require(os.getenv("GITHUB_REPOSITORY") == REPO, "Untrusted repository")
    require(os.getenv("GITHUB_REF") == "refs/heads/" + BRANCH, "Wrong verification branch")
    require(head == os.getenv("GITHUB_SHA"), "Checkout differs from event SHA")
    require(git("merge-base", PARENT, head) == PARENT, "Not descended from reviewed producer")
    require(set(git("diff", "--name-only", PARENT, head).splitlines()) == ALLOWED_DELTA,
            "Unapproved additional files in verification branch")
    for path, expected in EXPECTED_BLOBS.items():
        require(git("rev-parse", PARENT + ":" + path) == expected, "Changed frozen executable: " + path)
        require(git("rev-parse", "HEAD:" + path) == expected, "Verification source diverged: " + path)
    return {
        "verification_head": head, "producer_source": PARENT,
        "producer_tree": git("rev-parse", PARENT + "^{tree}"),
        "executable_source": EXPECTED_RUNTIME_SOURCE,
        "source_blobs": EXPECTED_BLOBS,
    }


class ArtifactRedirect(urllib.request.HTTPRedirectHandler):
    """Never send the GitHub API token to the signed artifact-storage host."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        old_host = urllib.parse.urlparse(req.full_url).hostname or ""
        parsed = urllib.parse.urlparse(newurl)
        require(parsed.scheme == "https", "Refusing non-HTTPS artifact redirect")
        if parsed.hostname != old_host:
            host = parsed.hostname or ""
            require(host.endswith(".blob.core.windows.net")
                    or host.endswith(".actions.githubusercontent.com")
                    or host.endswith(".githubusercontent.com"),
                    "Unexpected external artifact-storage redirect host")
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected is not None and parsed.hostname != old_host:
            for key in list(redirected.headers):
                if key.lower() in ("authorization", "proxy-authorization"):
                    redirected.remove_header(key)
        return redirected


def rest(path, *, binary=False):
    token = os.getenv("GITHUB_TOKEN", "")
    require(bool(token), "Missing authenticated GitHub Actions token")
    url = "https://api.github.com/repos/" + REPO + "/" + path
    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "cybersand-render-copy290-readonly-custody",
    }
    # Authenticated API metadata is fetched from api.github.com. The GitHub
    # artifact endpoint redirects to a signed, *unauthenticated* blob URL;
    # never forward credentials to that cross-host redirect.
    opener = urllib.request.build_opener(ArtifactRedirect())
    with opener.open(urllib.request.Request(url, headers=headers), timeout=120) as reply:
        data = reply.read(120 * 1024 * 1024 + 1)
        require(len(data) <= 120 * 1024 * 1024, "API response exceeded hard byte cap")
    return data if binary else json.loads(data)


def artifact_members(raw, expected, role):
    require(type(raw) is bytes and len(raw) <= 96 * 1024 * 1024, "Oversized artifact " + role)
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        infos = z.infolist()
        names = [x.filename for x in infos]
        require(len(infos) == len(expected) and set(names) == expected,
                "Wrong build-archive members: " + role)
        require(z.testzip() is None, "Original build-archive CRC error: " + role)
        require(all(not x.is_dir() and x.file_size <= 64 * 1024 * 1024 and
                    x.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                    and not (x.flag_bits & 1) for x in infos),
                "Unsafe build-archive member: " + role)
        return {x.filename: z.read(x) for x in infos}


def parse_selected(raw):
    entries = {}
    for line in raw.decode("utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        require(match is not None, "Malformed materialized input-hash row")
        digest, path = match.groups()
        require(path not in entries and not path.startswith("/") and
                ".." not in Path(path).parts and "\\\\" not in path,
                "Duplicate/unsafe materialized input path")
        entries[path] = digest
    require(len(entries) == 86, "Expected 86 source-frozen materialized inputs")
    return entries


def post_check(raw, paths, role):
    lines = raw.decode("utf-8").splitlines()
    require(len(lines) == len(paths) and set(lines) == {path + ": OK" for path in paths},
            "Source bytes mutated across " + role)
    return len(lines)


def git_blob_sha_map(commit):
    """Rehash exact committed Git blob objects, not export-subst archive bytes.

    git archive can apply working-tree/export attributes. The producer records
    SHA-256 of raw committed blobs (including literal Git LFS pointers).
    This independent reader enumerates the tree and retrieves each blob from
    one persistent, bounded git cat-file --batch process.
    """
    tree = subprocess.check_output(
        ["git", "-C", str(ROOT), "ls-tree", "-r", "-z", commit])
    records = []
    for entry in tree.split(b"\0"):
        if not entry:
            continue
        metadata, name = entry.split(b"\t", 1)
        mode, kind, oid = metadata.split(b" ")
        require(kind == b"blob", "Unexpected nonblob Git tree object")
        path = name.decode("utf-8", "surrogateescape")
        require(path not in {p for p, _ in records}, "Duplicate tree path")
        records.append((path, oid))
    require(len(records) == 1723, "Unexpected frozen committed-object inventory")
    proc = subprocess.Popen(["git", "-C", str(ROOT), "cat-file", "--batch"],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    result = {}
    try:
        for path, oid in records:
            proc.stdin.write(oid + b"\n")
            proc.stdin.flush()
            header = proc.stdout.readline().rstrip(b"\n").split(b" ")
            require(len(header) == 3 and header[0] == oid and header[1] == b"blob",
                    "Git cat-file returned unexpected object: " + path)
            size = int(header[2])
            require(0 <= size <= 128 * 1024 * 1024,
                    "Oversized raw Git blob: " + path + " (" + str(size) + " bytes)")
            data = proc.stdout.read(size)
            require(len(data) == size and proc.stdout.read(1) == b"\n",
                    "Git cat-file delivered partial blob: " + path)
            result[path] = sha(data)
        proc.stdin.close()
        require(proc.wait(timeout=90) == 0, "Git cat-file batch failed")
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    identity = preflight()
    run = rest("actions/runs/" + str(RUN_ID))
    jobs_response = rest("actions/runs/" + str(RUN_ID) + "/jobs?per_page=100")
    artifact_response = rest("actions/runs/" + str(RUN_ID) + "/artifacts?per_page=100")
    jobs, artifacts = jobs_response["jobs"], artifact_response["artifacts"]
    require(jobs_response["total_count"] == 3 and len(jobs) == 3, "Incomplete GitHub host jobs")
    require(artifact_response["total_count"] == 4 and len(artifacts) == 4,
            "Wrong original GitHub artifact inventory")

    expected_digests = verify_actions_custody(
        run, jobs, artifacts, PARENT, RUN_ID, ATTEMPT, PRODUCER_BRANCH, WORKFLOW_PATH
    )
    by_name = {x["name"]: x for x in artifacts}
    original_zip = {}
    zip_receipts = {}
    for role, artifact_id in ORIGINAL_ARTIFACT_IDS.items():
        # Original artifact ID and full digest both independently pinned, so
        # no old-source substitution, cancelled attempt, expiry or replay.
        found = next((x for x in artifacts if x["id"] == artifact_id), None)
        require(found is not None, "Missing original artifact " + role)
        require(found["digest"] == "sha256:" + ORIGINAL_ARTIFACT_DIGESTS[role],
                "Changed external artifact digest: " + role)
        raw = rest("actions/artifacts/" + str(artifact_id) + "/zip", binary=True)
        require(sha(raw) == ORIGINAL_ARTIFACT_DIGESTS[role],
                "Original Actions ZIP differs from authenticated GitHub digest: " + role)
        original_zip[role] = raw
        zip_receipts[role] = {
            "id": artifact_id, "original_zip_sha256": sha(raw), "bytes": len(raw),
        }

    require(expected_digests == {
        p: "sha256:" + ORIGINAL_ARTIFACT_DIGESTS[p + "-host"]
        for p in ("linux", "windows")
    }, "External Actions custody mismatches the pinned two host archives")
    require(verify_host_artifact_archives(
        {"linux": original_zip["linux-host"], "windows": original_zip["windows-host"]},
        expected_digests, PARENT, identity["producer_tree"], RUN_ID, ATTEMPT
    ), "Original target-host evidence/refusal validation failed")
    builds = {
        role: artifact_members(original_zip[role], BUILD_FILES[role], role)
        for role in BUILD_FILES
    }
    linux, windows = builds["linux-build"], builds["windows-build"]
    manifests = [json.loads(linux["tracked-git-inputs.json"]),
                 json.loads(windows["tracked-git-inputs.json"])]
    require(manifests[0] == manifests[1], "Linux/Windows tracked source ledgers differ")
    tracked = manifests[0]
    require(tracked["schema"] == "render-copy290-tracked-git-inputs-v1"
            and tracked["source_sha"] == PARENT
            and tracked["source_tree"] == identity["producer_tree"]
            and tracked["hash_kind"] == "sha256-of-committed-git-blob (LFS-pointer-not-payload)"
            and tracked["input_count"] == 1723 and len(tracked["inputs"]) == 1723,
            "Malformed or non-source-bound Git custody inventory")
    exact_committed = git_blob_sha_map(PARENT)
    require(exact_committed == tracked["inputs"],
            "Full 1713-file committed-object SHA-256 inventory differs from raw Git blob objects")

    selected = [parse_selected(linux["selected-build-inputs.sha256"]),
                parse_selected(windows["selected-build-inputs.sha256"])]
    require(selected[0] == selected[1], "Cross-host 86 selected input digests differ")
    require(all(tracked["inputs"].get(p) == checksum for p, checksum in selected[0].items()),
            "Selected materialized input differs from authoritative Git object")
    checks = {
        "linux_post_build": post_check(linux["post-build-input-check.txt"], selected[0], "Linux build"),
        "windows_post_build": post_check(windows["post-build-input-check.txt"], selected[1], "Windows build"),
        "linux_post_host": post_check(linux["post-host-input-check.txt"], selected[0], "Linux actual host"),
    }

    host_digests = {}
    for p in ("linux", "windows"):
        raw = original_zip[p + "-host"]
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            members = z.namelist()
            binname = next(s for s in members if s.startswith("runtime/"))
            binary = z.read(binname)
            report = json.loads(z.read("host-evidence.json"))
            require(sha(binary) == report["runtime_sha256"] and
                    len(binary) == report["runtime_size"],
                    "Host loaded runtime identity mismatch: " + p)
            host_digests[p] = {"sha256": sha(binary), "bytes": len(binary)}
    require(sha(windows["cybersand_native.windows.x86_64.dll"]) == host_digests["windows"]["sha256"],
            "Cross-built Windows DLL differs from the real-host tested DLL")
    for p, build in builds.items():
        require(build["source.txt"].decode().strip() == PARENT
                and build["tree.txt"].decode().strip() == identity["producer_tree"]
                and build["godot-cpp-commit.txt"].decode().strip()
                    == "101ae38034304346a46ea9ea84ae156d3e860496"
                and "4.10.1" in build["scons-version.txt"].decode(),
                "Build/toolchain source mismatch: " + p)
        archive_sha = build["runtime.sha256"].decode().split()[0]
        require(archive_sha == host_digests[p.split("-")[0]]["sha256"],
                "Build vs tested host runtime hash mismatch: " + p)

    receipt = {
        "schema": "cybersand.render-copy290-independent-actions-custody.v1",
        "qualified_scope": "read-only producer original source/REST/host/build custody; NOT LFS publication",
        "verification": identity,
        "producer_run": {"id": RUN_ID, "attempt": ATTEMPT,
                         "head_sha": PARENT, "status": run["status"],
                         "conclusion": run["conclusion"],
                         "jobs": sorted(x["name"] for x in jobs)},
        "zip_artifacts": zip_receipts,
        "source_map": {"git_blob_sha256_count": len(exact_committed),
                       "cross_host_maps_equal": True,
                       "authoritative_raw_git_blobs_match": True},
        "selected_materialized": {
            "files": len(selected[0]), "matching_both_hosts_and_git": True,
            "post_check_counts": checks,
        },
        "original_hosts": host_digests,
        "limitations": [
            "Only source-frozen, read-only producer, no owner authorization or write capability",
            "Raw Git objects include LFS pointers, not externally fetched binary payloads",
            "86 selected materialized files do not prove every external build dependency",
            "No four-path LFS append or source-sensitive published-runtime manifest",
            "Draft full ready-head Native/TSan/Godot/scoped gates still required",
            "No interactive GPU/Web performance or SOL281 ejection policy admission",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n",
                           encoding="utf-8")
    print("RENDER_COPY290_EXTERNAL_CUSTODY PASS: 3 jobs, 4 original ZIPs, "
          "1723 Git blobs, 86 selected materialized inputs, 6 host cases — NO PUBLICATION")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("RENDER_COPY290_EXTERNAL_CUSTODY FAILED: " + str(error), file=sys.stderr)
        raise
