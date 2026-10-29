#!/usr/bin/env python3
"""PR #290: explicit owner-requested, source-leased four-path LFS publisher.

UNARMED by default. check-unarmed and its tests are read-only. This helper
never calls git push; a separately permissioned GitHub Actions job owns the
four-path commit and exact-source force-with-lease.

A request is a NEW, single-parent commit modifying ONLY REQUEST, descended
from a reviewed publisher source. The prior source must be authorized by an
actual GitHub issue comment written by owner techrote, fetched via authenticated
GitHub REST. The comment must identify that parent and request sequence.
A self-asserted request file or synthetic fixture does not grant permission.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "ci"))
from render_copy290_publication_preflight import (  # noqa: E402
    verify_host_receipts, verify_host_artifact_archives, HOST_TARGETS,
)
from run_windows_godot_regressions import native_input_paths  # noqa: E402

REPO = "techrote/cybersand"
OWNER = "techrote"
BRANCH = "publish/render-copy290-runtime-20261029"
BASE = "c6accb68370405a4b0f30302e0f9d18a911b090b"
EXE_SOURCE = "60915dc86631271ea8661377a3458149adda9361"
WORLD_BLOB = "a6afd8cad4264ac2eca0362d14711158e3606760"
TEST_BLOB = "5613d2166c71fa49fd2b8f65e8caa93857b5d65f"
WF = ".github/workflows/render-copy290-runtime-publication.yml"
HELPER = "tools/ci/render_copy290_runtime_publication.py"
TEST = "tools/ci/test_render_copy290_runtime_publication.py"
AUDIT = "docs/audits/2026-10-29-render-copy290-runtime-publisher.md"
REQUEST = "tools/ci/render_copy290_publish_request.json"
PREP_DELTA = {WF, HELPER, TEST, AUDIT}
OUTPUT = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
}
MANIFEST = {
    "linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
    "windows": "godot/addons/cybersand_native/runtime-provenance.json",
}
FOUR = set(OUTPUT.values()) | set(MANIFEST.values())
GODOT_CPP = "101ae38034304346a46ea9ea84ae156d3e860496"
BUILD_REQUIRED = {
    "Makefile", ".gitattributes", ".github/workflows/gdextension.yml",
    WF, HELPER, TEST, AUDIT, REQUEST,
    ".github/workflows/render-copy290-host-producer.yml",
    "tools/ci/render_copy290_publication_preflight.py",
    "tools/ci/test_render_copy290_publication_preflight.py",
    "tools/build_native_extension.sh", "tools/build_native_extension_windows.sh",
    "tools/build_pinned_godot_cpp.sh", "tools/requirements-build.txt",
    "tools/ci/run_godot_regressions.py", "tools/ci/run_windows_godot_regressions.py",
    "tools/ci/godot_timeout_diagnostics.py", "tools/ci/godot_process_monitor.py",
    "third_party/native-toolchain.lock.json", "third_party/godot-runtime.lock.json",
    "godot/third_party/rapier2d.lock.json", "godot/project.godot",
    "godot/addons/cybersand_native/cybersand_native.gdextension",
}
PRODUCER_JOBS = {"linux-host", "windows-build", "windows-host"}
SUFFIX = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx",
          ".inc", ".inl", ".tpp"}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    # Textual command identity helper; Git's trailing line feed is not data.
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=90).strip()


def git_raw(*args):
    # Committed manifests and LFS pointer payloads require byte-exact newlines.
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=90)


def repo_identity(source):
    require(re.fullmatch(r"[0-9a-f]{40}", source) is not None, "Invalid source SHA")
    require(git("rev-parse", "HEAD").decode() == source, "Checkout differs from frozen source")
    require(os.getenv("GITHUB_REPOSITORY") == REPO and
            os.getenv("GITHUB_EVENT_NAME") == "push" and
            os.getenv("GITHUB_REF") == "refs/heads/" + BRANCH and
            os.getenv("GITHUB_SHA") == source and
            os.getenv("GITHUB_WORKFLOW_REF") ==
                REPO + "/" + WF + "@refs/heads/" + BRANCH,
            "Invalid Actions repository/branch/workflow/event/source")
    require(git("merge-base", BASE, source).decode() == BASE,
            "Source not descendant of reviewed host-producer base")
    for path, blob in (("native/src/world.cpp", WORLD_BLOB),
                       ("native/tests/test_world.cpp", TEST_BLOB)):
        require(git("rev-parse", source + ":" + path).decode() == blob,
                "Native/oracle frozen SHA changed: " + path)
    return {"source_commit": source,
            "source_tree": git("rev-parse", source + "^{tree}").decode(),
            "build_commit": source,
            "workflow_run": "https://github.com/techrote/cybersand/actions/runs/" +
                            os.getenv("GITHUB_RUN_ID", ""),
            "workflow_attempt": os.getenv("GITHUB_RUN_ATTEMPT", "")}


def lease(source):
    expected = source + "\trefs/heads/" + BRANCH
    actual = git("ls-remote", "--exit-code", "origin", "refs/heads/" + BRANCH).decode()
    require(actual == expected, "Publication branch changed since source freeze")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + key)
        result[key] = value
    return result


def validate_request(request, comment, parent, source, changed):
    expected = {"schema", "intent", "request_sequence", "authorized_parent_sha",
                "owner_comment_id", "owner_comment_sha256", "outputs"}
    require(type(request) is dict and set(request) == expected,
            "Missing or extra publication request fields")
    require(request["schema"] == "render-copy290-publish-request-v1" and
            request["intent"] == "publish-source-matched-four-path-runtimes" and
            type(request["request_sequence"]) is int and
            request["request_sequence"] > 0 and
            type(request["owner_comment_id"]) is int and
            request["owner_comment_id"] > 0 and
            request["authorized_parent_sha"] == parent and
            set(request["outputs"]) == FOUR and
            type(request["outputs"]) is list and len(request["outputs"]) == 4 and
            all(type(x) is str for x in request["outputs"]) and
            changed == {REQUEST} and
            re.fullmatch(r"[0-9a-f]{64}", request["owner_comment_sha256"]) is not None,
            "Unapproved request, paths, parent, sequence or lease")
    expected_body = ("AUTHORIZE render-copy290 four-path LFS publication\n" +
                     "parent=" + parent + "\n" +
                     "sequence=" + str(request["request_sequence"]) + "\n" +
                     "scope=source-matched-linux-windows-development-runtimes")
    require(type(comment) is dict and
            comment.get("user", {}).get("login") == OWNER and
            comment.get("author_association") == "OWNER" and
            comment.get("issue_url") ==
                "https://api.github.com/repos/techrote/cybersand/issues/290" and
            comment.get("body") == expected_body and
            sha(expected_body.encode()) == request["owner_comment_sha256"] and
            request["owner_comment_id"] == comment.get("id"),
            "Missing matching explicit owner GitHub authorization")
    require(source != parent, "Request cannot authorize its own parent")
    return True


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        old = urllib.parse.urlparse(req.full_url).hostname
        parsed = urllib.parse.urlparse(newurl)
        require(parsed.scheme == "https", "Non-HTTPS Actions ZIP redirect")
        if parsed.hostname != old:
            host = parsed.hostname or ""
            require(host.endswith(".blob.core.windows.net") or
                    host.endswith(".actions.githubusercontent.com") or
                    host.endswith(".githubusercontent.com"),
                    "Unexpected artifact redirect host")
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected is not None and parsed.hostname != old:
            for key in list(redirected.headers):
                if key.lower() in ("authorization", "proxy-authorization"):
                    redirected.remove_header(key)
        return redirected


def rest(path, *, binary=False):
    token = os.getenv("GITHUB_TOKEN", "")
    require(bool(token), "Missing authenticated GitHub Actions token")
    url = "https://api.github.com/repos/" + REPO + "/" + path
    headers = {"Authorization": "Bearer " + token,
               "Accept": "application/vnd.github+json",
               "X-GitHub-Api-Version": "2022-11-28",
               "User-Agent": "cybersand-render-copy290-publisher"}
    opener = urllib.request.build_opener(SafeRedirect())
    with opener.open(urllib.request.Request(url, headers=headers), timeout=120) as response:
        data = response.read(128 * 1024 * 1024 + 1)
    require(len(data) <= 128 * 1024 * 1024, "Oversize REST/artifact response")
    return data if binary else json.loads(data)


def request_status(source, *, require_armed=False, remote=True):
    meta = repo_identity(source)
    files = set(git("diff", "--name-only", BASE, source).decode().splitlines())
    present = (ROOT / REQUEST).exists()
    if not present:
        require(not require_armed and files == PREP_DELTA,
                "Unarmed publisher has unexpected files or was asked to publish")
        require(REQUEST not in git("ls-tree", "-r", "--name-only", source).decode().splitlines(),
                "Untracked request mismatch")
        return None
    require(files == PREP_DELTA | {REQUEST}, "Publisher source has unrelated changes")
    parent_line = git("rev-list", "--parents", "-n", "1", source).decode().split()
    require(len(parent_line) == 2 and parent_line[0] == source,
            "Request must be a single-parent commit")
    parent = parent_line[1]
    require(git("diff", "--name-only", parent, source).decode().splitlines() == [REQUEST],
            "Request must be the sole changed file in authorization commit")
    require(git_raw("show", source + ":" + REQUEST) ==
            (ROOT / REQUEST).read_bytes().replace(b"\r\n", b"\n"),
            "Request on disk differs from checked-out committed source")
    data = json.loads((ROOT / REQUEST).read_bytes(), object_pairs_hook=unique_object)
    comment = rest("issues/comments/" + str(data.get("owner_comment_id", "")))
    validate_request(data, comment, parent, source, {REQUEST})
    if remote:
        lease(source)
    return {"source": meta, "request": data, "comment": comment["html_url"]}


def source_ledgers(source, *, armed=True):
    # Pin both exact committed Git bytes and source-sensitive build inputs.
    native = set(native_input_paths(ROOT))
    objects = {}
    tracked = set()
    raw = git("ls-tree", "-rz", "--full-tree", source)
    for part in raw.split(b"\0"):
        if not part:
            continue
        metadata, filename = part.split(b"\t", 1)
        mode, kind, oid = metadata.split()
        path = filename.decode("utf-8")
        if (path.startswith(("native/include/", "native/src/", "godot/native_extension/"))
                and Path(path).suffix in SUFFIX):
            tracked.add(path)
        selected = (path in native or path in BUILD_REQUIRED or
                    path.startswith(("native/tests/", "examples/worldgen/",
                                     "godot/tests/fixtures/")) or
                    (path.startswith("godot/") and
                     Path(path).suffix in {".gd", ".tscn", ".tres", ".gdshader"}))
        if selected:
            require(mode in (b"100644", b"100755") and kind == b"blob",
                    "Unexpected Git input mode/type: " + path)
            objects[path] = oid
    require(native == tracked and len(native) == 80 and
            (BUILD_REQUIRED if armed else BUILD_REQUIRED - {REQUEST}).issubset(objects),
            "Incomplete native/build source inventory")
    blob_bytes = subprocess.check_output(["git", "-C", str(ROOT), "cat-file", "--batch"],
                                         input=b"".join(oid + b"\n" for oid in objects.values()),
                                         timeout=120)
    offset = 0
    hashes = {}
    for path, oid in objects.items():
        end = blob_bytes.index(b"\n", offset)
        name, kind, size_raw = blob_bytes[offset:end].split()
        size = int(size_raw)
        blob = blob_bytes[end + 1:end + 1 + size]
        require(name == oid and kind == b"blob" and len(blob) == size,
                "Corrupted Git batch blob: " + path + " expected=" + repr(oid) +
                " got=" + repr(name) + " kind=" + repr(kind) +
                " declared=" + str(size) + " received=" + str(len(blob)))
        offset = end + size + 2
        present = ROOT / path
        require(present.is_file() and not present.is_symlink() and
                present.read_bytes().replace(b"\r\n", b"\n") == blob,
                "Actual build input differs from frozen Git object: " + path)
        hashes[path] = sha(blob)
    require(offset == len(blob_bytes), "Unaccounted trailing raw Git objects")
    return {"source_inputs": {k: hashes[k] for k in sorted(native)},
            "build_inputs": {k: hashes[k] for k in sorted(hashes) if k not in native}}


def runtime_kind(data, platform):
    require(type(data) is bytes and 4096 < len(data) < 64 * 1024 * 1024,
            "Invalid native runtime length")
    if platform == "linux":
        require(data[:6] == b"\x7fELF\x02\x01" and data[16:20] == b"\x03\x00\x3e\x00",
                "Expected ELF64 x86_64 ET_DYN")
    else:
        require(data[:2] == b"MZ" and len(data) >= 64, "Invalid Windows DLL")
        pos = int.from_bytes(data[60:64], "little")
        require(64 <= pos <= len(data) - 26 and
                data[pos:pos + 6] == b"PE\0\0\x64\x86" and
                data[pos + 24:pos + 26] == b"\x0b\x02" and
                int.from_bytes(data[pos + 22:pos + 24], "little") & 0x2000,
                "Expected PE32+ x86_64 DLL")


def manifest(platform, source, runtime_bytes, report, ledgers, zip_digest,
             build=None, authorization=None):
    runtime_kind(runtime_bytes, platform)
    # Preserve *actual* archived compiler/build-input identities, not only a
    # self-described toolchain string in the host JSON.
    build = build or {}
    compiler = build.get("compiler-version.txt", b"synthetic qualification").decode(
        "utf-8", "replace").splitlines()[0].strip()
    require(0 < len(compiler) <= 256, "Invalid retained compiler identity")
    result = dict(repo_identity(source), **ledgers)
    result.update({"schema_version": 1, "platform": platform,
                   "source_input_hash_kind":
                       "SHA-256 of canonical Git blob bytes; CRLF working files normalize to LF",
                   "artifact": OUTPUT[platform], "sha256": sha(runtime_bytes),
                   "size": len(runtime_bytes), "status": "validated-development-runtime",
                   "build_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
                   "validated_platform": platform.title() +
                       " x86_64 Godot 4.7 actual GitHub-hosted headless execution",
                   "evidence": AUDIT,
                   "toolchain": report["toolchain"] + "; compiler=" + compiler +
                       "; godot-cpp=" + GODOT_CPP + "; SCons=4.10.1",
                   "validation_output": "Actions " + os.environ["GITHUB_RUN_ID"] +
                       "/render-copy290-host-evidence-" + platform,
                   "validation_sha256": zip_digest,
                   "acceptance": "Source-matched import and 23/23 render-world + render-patch-handoff passed; full ready-PR/TSan/Web and manual acceptance separate",
                   "other_platforms": "Only Linux/Windows headless rendering was tested; not browser/desktop GPU FPS"})
    for key, evidence in (("build_log_sha256", "native-build.txt"),
                          ("godot_cpp_build_log_sha256", "godot-cpp-build.txt"),
                          ("selected_materialized_input_sha256",
                           "selected-build-inputs.sha256")):
        if evidence in build:
            result[key] = sha(build[evidence])
    if authorization is not None:
        result.update({"owner_authorization_comment": authorization["comment"],
                       "publication_request_sequence":
                           authorization["request"]["request_sequence"],
                       "authorized_pre_request_parent":
                           authorization["request"]["authorized_parent_sha"]})
    return result


def check_index(source):
    repo_identity(source)
    staged = set(git("diff", "--cached", "--name-only", "-z").decode().split("\0")) - {""}
    require(staged == FOUR, "Publication must stage exactly two runtimes and two manifests")
    for platform in HOST_TARGETS:
        path = OUTPUT[platform]
        manifest_path = MANIFEST[platform]
        manifest = json.loads((ROOT / manifest_path).read_text(encoding="utf-8"))
        require(manifest["source_commit"] == source and
                manifest["status"] == "validated-development-runtime" and
                manifest["artifact"] == path, "Staged runtime manifest is stale")
        staged_pointer = git_raw("show", ":" + path)
        expect = ("version https://git-lfs.github.com/spec/v1\n" +
                  "oid sha256:" + manifest["sha256"] + "\n" +
                  "size " + str(manifest["size"]) + "\n").encode()
        require(staged_pointer == expect, "Staged runtime is not matching Git LFS pointer")
        require(sha((ROOT / path).read_bytes()) == manifest["sha256"] and
                (ROOT / path).stat().st_size == manifest["size"],
                "Materialized runtime differs from staged pointer")
        require(git_raw("show", ":" + manifest_path) == (ROOT / manifest_path).read_bytes(),
                "Staged provenance differs from working file")
        for rel in (path, manifest_path):
            entry = git("ls-files", "--stage", "--", rel).decode().splitlines()
            require(len(entry) == 1 and entry[0].startswith("100644 ") and
                    entry[0].endswith(" 0\t" + rel),
                    "LFS publication path not staged as a regular file")
    return True



def original_members(raw, required, label):
    require(type(raw) is bytes and 0 < len(raw) <= 96 * 1024 * 1024,
            "Missing or oversized original ZIP: " + label)
    with zipfile.ZipFile(io.BytesIO(raw)) as bundle:
        members = bundle.infolist()
        names = [x.filename for x in members]
        require(len(names) == len(set(names)) and set(required).issubset(names),
                "Duplicate or missing build proof: " + label)
        require(all(not x.is_dir() and not (x.flag_bits & 1) and
                    x.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                    and x.file_size < 64 * 1024 * 1024 and
                    not x.filename.startswith("/") and
                    ".." not in Path(x.filename).parts and
                    "\\" not in x.filename for x in members),
                "Unsafe host/build ZIP entry: " + label)
        require(bundle.testzip() is None, "Original Actions ZIP CRC differs: " + label)
        return {name: bundle.read(name) for name in names}


def selected_hashes(raw):
    rows = {}
    for line in raw.decode("utf-8").splitlines():
        pair = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        require(pair is not None, "Invalid source/build input hash line")
        path = pair[2]
        require(path not in rows and path and ".." not in Path(path).parts and
                not path.startswith("/") and "\\" not in path,
                "Duplicate/unsafe materialized build-input path")
        rows[path] = pair[1]
    require(len(rows) == 86, "Missing original 86 input custody hash rows")
    return rows


def authenticated_producer_artifacts(source):
    """Read *this* current, in-progress workflow run via GitHub API.

    The publish job cannot require whole-workflow success while it is itself
    executing. It requires all three *already completed* host jobs and the
    request-guard job to be successful, with exact GitHub-hosted identity.
    """
    run_id = int(os.environ["GITHUB_RUN_ID"])
    attempt = int(os.environ["GITHUB_RUN_ATTEMPT"])
    run = rest("actions/runs/" + str(run_id))
    require(run.get("head_sha") == source and
            run.get("head_branch") == BRANCH and
            run.get("repository", {}).get("full_name") == REPO and
            run.get("head_repository", {}).get("full_name") == REPO and
            run.get("run_attempt") == attempt and
            run.get("event") == "push" and
            run.get("path") == WF and
            run.get("status") == "in_progress",
            "Current Actions publication run is not the authorized build")
    jobs_page = rest("actions/runs/" + str(run_id) + "/jobs?per_page=100")
    jobs = jobs_page["jobs"]
    names = ["request-gate", "linux-host", "windows-build", "windows-host"]
    require(len(jobs) <= 8 and all(sum(job.get("name") == name for job in jobs) == 1
                                   for name in names),
            "Incomplete or duplicate producer/authorization jobs")
    for name in names:
        job = next(x for x in jobs if x.get("name") == name)
        platform = "windows-2022" if name == "windows-host" else "ubuntu-24.04"
        require(job.get("run_id") == run_id and
                job.get("run_attempt") == attempt and
                job.get("head_sha") == source and
                job.get("head_branch") == BRANCH and
                job.get("labels") == [platform] and
                job.get("runner_group_name") == "GitHub Actions" and
                str(job.get("runner_name", "")).startswith("GitHub Actions ") and
                job.get("status") == "completed" and
                job.get("conclusion") == "success" and
                all(step.get("conclusion") == "success"
                    for step in job.get("steps", [])),
                "Untrusted, missing, skipped or failed producer job: " + name)
    artifacts = rest("actions/runs/" + str(run_id) + "/artifacts?per_page=100")
    names = {
        "linux-host": "render-copy290-host-evidence-linux-" + str(run_id),
        "windows-host": "render-copy290-host-evidence-windows-" + str(run_id),
        "linux-build": "render-copy290-linux-build-" + source,
        "windows-build": "render-copy-290-windows-dll-" + source,
    }
    by_name = {x["name"]: x for x in artifacts["artifacts"]}
    require(artifacts["total_count"] == 4 and set(by_name) == set(names.values()),
            "Publisher received incomplete or unexpected original artifact set")
    raw = {}
    digests = {}
    for role, name in names.items():
        entry = by_name[name]
        require(entry.get("expired") is False and
                type(entry.get("id")) is int and entry["id"] > 0 and
                type(entry.get("size_in_bytes")) is int and
                0 < entry["size_in_bytes"] < 96 * 1024 * 1024 and
                type(entry.get("digest")) is str and
                re.fullmatch(r"sha256:[0-9a-f]{64}", entry["digest"]) and
                entry.get("workflow_run", {}).get("id") == run_id and
                entry["workflow_run"].get("head_sha") == source and
                entry["workflow_run"].get("head_branch") == BRANCH,
                "Original Actions artifact not source-bound: " + role)
        zip_bytes = rest("actions/artifacts/" + str(entry["id"]) + "/zip",
                         binary=True)
        require(sha(zip_bytes) == entry["digest"][7:],
                "Original artifact ZIP bytes disagree with independent GitHub digest")
        raw[role] = zip_bytes
        digests[role] = entry["digest"]
    require(verify_host_artifact_archives(
        {"linux": raw["linux-host"], "windows": raw["windows-host"]},
        {"linux": digests["linux-host"], "windows": digests["windows-host"]},
        source, git("rev-parse", source + "^{tree}").decode(),
        run_id, attempt), "Original Linux/Windows host receipts are incomplete")
    return raw, digests


def stage(source):
    authorization = request_status(source, require_armed=True)
    raw, outer_digests = authenticated_producer_artifacts(source)
    require(set(outer_digests) == {"linux-host", "windows-host",
                                 "linux-build", "windows-build"},
            "Incomplete publisher custody")
    builds = {
        "linux": original_members(
            raw["linux-build"],
            {"source.txt", "tree.txt", "tracked-git-inputs.json",
             "selected-build-inputs.sha256", "post-build-input-check.txt",
             "post-host-input-check.txt", "runtime.sha256",
             "compiler-version.txt", "scons-version.txt", "godot-cpp-commit.txt",
             "native-build.txt", "godot-cpp-build.txt"},
            "linux"),
        "windows": original_members(
            raw["windows-build"],
            {"source.txt", "tree.txt", "tracked-git-inputs.json",
             "selected-build-inputs.sha256", "post-build-input-check.txt",
             "runtime.sha256", "compiler-version.txt",
             "scons-version.txt", "godot-cpp-commit.txt", "native-build.txt",
             "godot-cpp-build.txt", "cybersand_native.windows.x86_64.dll"},
            "windows"),
    }
    maps = [json.loads(builds[p]["tracked-git-inputs.json"],
                       object_pairs_hook=unique_object) for p in ("linux", "windows")]
    require(maps[0] == maps[1] and maps[0]["source_sha"] == source and
            maps[0]["source_tree"] == git("rev-parse", source + "^{tree}").decode() and
            len(maps[0]["inputs"]) == maps[0]["input_count"],
            "Original two-host complete tracked-Git source custody differs")
    selected = [selected_hashes(builds[p]["selected-build-inputs.sha256"])
                for p in ("linux", "windows")]
    require(selected[0] == selected[1] and all(
        maps[0]["inputs"].get(path) == digest
        for path, digest in selected[0].items()),
        "Materialized build inputs differ across hosts or source blobs")
    for platform in ("linux", "windows"):
        build = builds[platform]
        require(build["source.txt"].decode().strip() == source and
                build["tree.txt"].decode().strip() ==
                    git("rev-parse", source + "^{tree}").decode() and
                build["godot-cpp-commit.txt"].decode().strip() == GODOT_CPP and
                "4.10.1" in build["scons-version.txt"].decode(),
                "Source or pinned build/toolchain mismatch: " + platform)
        for label in ("post-build-input-check.txt",
                      "post-host-input-check.txt" if platform == "linux"
                      else "post-build-input-check.txt"):
            output = build[label].decode().splitlines()
            require(len(output) == 86 and
                    set(output) == {name + ": OK" for name in selected[0]},
                    "Build/input changed before actual Godot execution: " +
                    platform + "/" + label)
    ledgers = source_ledgers(source)
    require(all(maps[0]["inputs"].get(p) == hash_value
                for kind in ("source_inputs", "build_inputs")
                for p, hash_value in ledgers[kind].items()),
            "Full publisher source/build inputs differ from original hosted source")
    # Guard stage index and working-tree before any mutation. The same check is
    # repeated after staging and again immediately before the exact lease push.
    require(not git("diff", "--name-only") and not git("diff", "--cached",
            "--name-only"), "Dirty publisher source/index before staging")
    report = {}
    for platform in ("linux", "windows"):
        original_members_map = original_members(
            raw[platform + "-host"],
            {"host-evidence.json", "runtime/" +
                Path(OUTPUT[platform]).name,
             "logs/godot_import.log",
             "logs/test_render_world_generation.log",
             "logs/test_render_patch_handoff_regression.log"},
            platform + "-host")
        blob = original_members_map["runtime/" + Path(OUTPUT[platform]).name]
        host = json.loads(original_members_map["host-evidence.json"],
                          object_pairs_hook=unique_object)
        require(host["source_sha"] == source and
                host["source_tree"] ==
                  git("rev-parse", source + "^{tree}").decode() and
                host["runtime_sha256"] == sha(blob) and
                host["runtime_size"] == len(blob) and
                builds[platform]["runtime.sha256"].decode().split()[0]
                    == sha(blob),
                "Host-loaded binary differs from independently built source")
        if platform == "windows":
            require(sha(builds["windows"]["cybersand_native.windows.x86_64.dll"])
                    == sha(blob), "Actual Windows DLL differs from independent build")
        runtime_kind(blob, platform)
        report[platform] = {"runtime": blob, "receipt": host}
    import json as _json
    for platform in ("linux", "windows"):
        target = ROOT / OUTPUT[platform]
        require(not target.is_symlink(), "LFS output destination is a symlink")
        target.write_bytes(report[platform]["runtime"])
        record = manifest(platform, source, report[platform]["runtime"],
                          report[platform]["receipt"], ledgers,
                          outer_digests[platform + "-host"][7:],
                          builds[platform], authorization)
        original = ROOT / MANIFEST[platform]
        require(not original.is_symlink(), "Manifest destination is symlink")
        original.write_text(_json.dumps(record, indent=2, sort_keys=True) + "\n",
                            encoding="utf-8")
    subprocess.run(["git", "add", "--", *sorted(FOUR)], cwd=ROOT,
                   check=True, timeout=60)
    check_index(source)
    print("RENDER_COPY290_PUBLISHER STAGED FOUR SOURCE-MATCHED LFS PATHS — NOT PUSHED")

def main():
    p = argparse.ArgumentParser()
    p.add_argument("command", choices=("check-unarmed", "check-source", "stage", "check-index"))
    p.add_argument("--source-sha", required=True)
    args = p.parse_args()
    if args.command == "check-unarmed":
        require(request_status(args.source_sha) is None, "Publisher unexpectedly armed")
        ledgers = source_ledgers(args.source_sha, armed=False)
        print("RENDER_COPY290_UNARMED_LEDGER", len(ledgers["source_inputs"]),
              len(ledgers["build_inputs"]))
        print("RENDER_COPY290_PUBLISHER UNARMED PASS")
    elif args.command == "check-source":
        require(request_status(args.source_sha, require_armed=True) is not None,
                "Missing approved source-bound publisher request")
        print("RENDER_COPY290_PUBLISHER REQUEST/LEASE PASS")
    elif args.command == "stage":
        stage(args.source_sha)
    else:
        request_status(args.source_sha, require_armed=True)
        check_index(args.source_sha)
        print("RENDER_COPY290_PUBLISHER EXACT FOUR-PATH STAGED INDEX PASS")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("RENDER_COPY290_PUBLISHER REFUSED: " + str(error), file=sys.stderr)
        raise
