#!/usr/bin/env python3
"""Read-only, UNARMED Git/LFS preflight for draft Cybersand PR #290."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
REPO = "techrote/cybersand"
PREP = "prep/render-copy290-publisher-20261029"
FEATURE = "claude/render-copy-per-run"
FROZEN_HEAD = "ddf812f34c533f654f1488b9115eb0256305a288"
WORLD_BLOB = "a6afd8cad4264ac2eca0362d14711158e3606760"
TEST_BLOB = "5613d2166c71fa49fd2b8f65e8caa93857b5d65f"
WORLD_DIGEST = "b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1"
TEST_DIGEST = "cfb54f5cc58388f1581bd367d3a19a7ff3d260583028980606c6b0e6fda7a69d"
REQUEST = "tools/ci/render_copy290_publish_request.json"
NEW = frozenset({
    "tools/ci/render_copy290_publication_preflight.py",
    "tools/ci/test_render_copy290_publication_preflight.py",
    "docs/audits/2026-10-29-render-copy290-publisher-preflight.md",
    ".github/workflows/render-copy290-publisher-preflight.yml",
})
RETAINED = {
    "linux": ("godot/addons/cybersand_native/runtime-provenance.linux.json",
              "6908dec74dfda8e95ed83326d321637efdd3bb28",
              "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
              "496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6",
              4222304),
    "windows": ("godot/addons/cybersand_native/runtime-provenance.json",
                "0b8eb7213a83cb22f1169579412f3f4fb4aa87b9",
                "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
                "e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb",
                4825088),
}
SOURCE_DRIFT = frozenset({"native/src/world.cpp"})
BUILD_DRIFT = frozenset({
    ".gitattributes", "native/tests/test_world.cpp",
    ".github/workflows/play-auto002-runtime-publication.yml",
    "tools/ci/play_auto002_publish_request.json",
    "tools/ci/play_auto002_runtime_publication.py",
    "tools/ci/test_play_auto002_runtime_publication.py",
})
SUFFIX = frozenset({".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"})


def require(value, message):
    if not value:
        raise RuntimeError(message)


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=60)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def context(env):
    require(env.get("GITHUB_REPOSITORY") == REPO, "Wrong repository")
    event = env.get("GITHUB_EVENT_NAME")
    if event == "push":
        require(env.get("GITHUB_REF") == "refs/heads/" + PREP, "Wrong preparation branch")
    elif event == "pull_request":
        require(env.get("GITHUB_HEAD_REF") == PREP and
                env.get("GITHUB_BASE_REF") == FEATURE, "Wrong PR head/base")
        require(env.get("RENDER_COPY290_HEAD_REPO") == REPO,
                "PR head must originate in the authorized repository")
    else:
        raise RuntimeError("Unapproved workflow event")



def source_lease(env, head):
    """Reject event/check-out identity drift before inspecting any source or LFS."""
    expected = env.get("RENDER_COPY290_EVENT_SHA", "")
    require(re.fullmatch(r"[0-9a-f]{40}", expected) is not None
            and head == expected, "Checked-out head does not match the event source SHA")


def paths_ok(paths):
    require(paths == NEW, "Unexpected prep delta: " + repr(sorted(paths ^ NEW)))


def no_request(tracked, on_disk):
    require(not tracked and not on_disk, "A publisher request is forbidden in unarmed prep")


def pointer_ok(raw, sha, size):
    match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\n"
                         rb"oid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", raw)
    require(match is not None and match[1].decode() == sha and
            int(match[2]) == size, "Historic LFS pointer changed")


def drift_ok(native, source, build, actual):
    require(len(native) == 80 and len(source) == 80 and set(source) == native,
            "Native source inventory changed")
    require(len(build) == 549, "Historical build-input ledger changed")
    require({p for p, sha in source.items() if actual.get(p) != sha} == SOURCE_DRIFT,
            "Unexpected source-input drift")
    require({p for p, sha in build.items() if actual.get(p) != sha} == BUILD_DRIFT,
            "Unexpected historical build-input drift")



# Pure, UNARMED future-publisher receipt contract. No write path uses this.
HOST_CASES = ("godot_import", "test_render_world_generation",
              "test_render_patch_handoff_regression")
HOST_TARGETS = {"linux": ("ubuntu-24.04", "gcc-13"),
                "windows": ("windows-2022", "llvm-mingw-20260826-ucrt")}
HOST_MARKERS = {
    "godot_import": r"Godot Engine v4\.7\.",
    "test_render_world_generation": r"(?m)^RENDER_WORLD_GENERATION: 23 assertions, 0 failures$",
    "test_render_patch_handoff_regression": r"(?m)^Render patch handoff regression passed$",
}


def _unique_evidence(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON evidence field: " + key)
        result[key] = value
    return result


def _host_binary(data, platform):
    require(type(data) is bytes and len(data) >= 4096, "Missing or truncated host runtime")
    if platform == "linux":
        require(data[:6] == b"\x7fELF\x02\x01"
                and data[16:18] == b"\x03\x00"  # ET_DYN, not ET_EXEC
                and data[18:20] == b"\x3e\x00",
                "Not a Linux ELF64 x86_64 shared object")
    else:
        offset = int.from_bytes(data[60:64], "little")
        require(data[:2] == b"MZ" and 64 <= offset <= len(data) - 26
                and data[offset:offset + 6] == b"PE\x00\x00\x64\x86"
                and data[offset + 24:offset + 26] == b"\x0b\x02"  # PE32+
                and int.from_bytes(data[offset + 22:offset + 24], "little")
                & 0x2000 != 0,  # IMAGE_FILE_DLL
                "Not a Windows PE32+ x86_64 DLL")


def verify_host_receipts(bundles, source, tree, expected_run_id, expected_run_attempt):
    """Verify original byte evidence from BOTH target hosts, never publish."""
    require(type(bundles) is dict and set(bundles) == set(HOST_TARGETS),
            "Both distinct Linux and Windows receipts are mandatory")
    require(all(type(x) is str and re.fullmatch(r"[0-9a-f]{40}", x)
                for x in (source, tree)), "Untrusted or malformed source/tree identity")
    require(type(expected_run_id) is int and expected_run_id > 0
            and type(expected_run_attempt) is int and expected_run_attempt > 0,
            "Missing trusted Actions run/attempt identity")
    run = None
    for platform, (runner, toolchain) in HOST_TARGETS.items():
        bundle = bundles[platform]
        require(type(bundle) is dict and set(bundle) == {"report", "runtime", "logs"},
                "Malformed host evidence bundle")
        raw = bundle["report"]
        require(type(raw) is bytes and 0 < len(raw) <= 65536, "Invalid raw JSON receipt")
        try:
            report = json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_evidence,
                                parse_constant=lambda v: (_ for _ in ()).throw(
                                    RuntimeError("Nonfinite JSON evidence: " + v)))
        except (ValueError, UnicodeError, TypeError) as exc:
            raise RuntimeError("Malformed host JSON") from exc
        keys = {"schema", "platform", "source_sha", "source_tree", "run_id",
                "run_attempt", "runner", "toolchain", "godot_version",
                "godot_cpp_commit", "scons_version", "runtime_sha256",
                "runtime_size", "cases"}
        require(type(report) is dict and set(report) == keys,
                "Host receipt has missing or extra fields")
        require(report["schema"] == "render-copy290-host-evidence-v1"
                and report["platform"] == platform
                and report["source_sha"] == source and report["source_tree"] == tree
                and report["runner"] == runner and report["toolchain"] == toolchain
                and report["godot_version"] == "4.7.stable.official.5b4e0cb0f"
                and report["godot_cpp_commit"] == "101ae38034304346a46ea9ea84ae156d3e860496"
                and report["scons_version"] == "4.10.1",
                "Host platform, source or pinned toolchain differs")
        require(type(report["run_id"]) is int and report["run_id"] > 0
                and type(report["run_attempt"]) is int and report["run_attempt"] > 0,
                "Bad Actions run identity")
        identity = (report["run_id"], report["run_attempt"])
        require(identity == (expected_run_id, expected_run_attempt),
                "Host receipt does not match independently pinned Actions run/attempt")
        require(run is None or run == identity, "Mixed host runs or attempts")
        run = identity
        binary = bundle["runtime"]
        _host_binary(binary, platform)
        require(type(report["runtime_size"]) is int and len(binary) == report["runtime_size"]
                and digest(binary) == report["runtime_sha256"],
                "Runtime original bytes do not match receipt")
        logs, cases = bundle["logs"], report["cases"]
        require(type(logs) is dict and set(logs) == set(HOST_CASES)
                and type(cases) is list and len(cases) == len(HOST_CASES),
                "Incomplete host case/log inventory")
        for name, row in zip(HOST_CASES, cases):
            require(type(row) is dict and set(row) ==
                    {"name", "status", "exit_code", "timed_out", "log_sha256"},
                    "Host case row is malformed")
            log = logs[name]
            require(type(log) is bytes and 0 < len(log) <= 8_000_000
                    and row["name"] == name and row["status"] == "passed"
                    and type(row["exit_code"]) is int and row["exit_code"] == 0
                    and row["timed_out"] is False and digest(log) == row["log_sha256"],
                    "Case failed or original log bytes differ: " + name)
            try:
                output = log.decode("utf-8").replace("\r\n", "\n")
            except UnicodeError as exc:
                raise RuntimeError("Non-UTF8 case log") from exc
            # Runtime diagnostics may be indented, timestamped or appear after
            # a positive marker. Never anchor the failure scan to column zero.
            forbidden = re.search(
                r"(?i)(?:SCRIPT ERROR:|ERROR:|SKIP(?:PED)?\b|"
                r"TIMEOUT\b|LAUNCH ERROR:|REGRESSION_WATCHDOG\b|"
                r"Traceback \(most recent call last\)|FATAL:|"
                r"\[fail\]|\bFAIL(?:ED|URE)?\b|"
                r"\bSegmentation fault\b|\bAborted \(core dumped\)|"
                r"\bPANIC:)",
                output)
            require(re.search(HOST_MARKERS[name], output) is not None
                    and forbidden is None,
                    "Missing positive marker or hidden error/skip: " + name)
    return True



# Proposed read-only future-publisher contract. Authenticate expected_digests,
# source/tree, run ID and attempt independently from GitHub. Merely passing
# self-asserted metadata is not provenance or authority to publish.
HOST_ARCHIVE_RUNTIME = {
    "linux": "runtime/libcybersand_native.linux.x86_64.so",
    "windows": "runtime/cybersand_native.windows.x86_64.dll",
}


def verify_host_artifact_archives(archives, expected_digests, source, tree,
                                  expected_run_id, expected_run_attempt):
    """Read exact paired ZIP bytes and verify their external digests and contents."""
    require(type(archives) is dict and set(archives) == set(HOST_TARGETS)
            and type(expected_digests) is dict
            and set(expected_digests) == set(HOST_TARGETS),
            "Two distinct platform archives and external digests are required")
    bundles = {}
    for platform in HOST_TARGETS:
        raw, expected = archives[platform], expected_digests[platform]
        require(type(raw) is bytes and 0 < len(raw) <= 96 * 1024 * 1024,
                "Missing or oversized original Actions archive: " + platform)
        require(type(expected) is str and
                re.fullmatch(r"sha256:[0-9a-f]{64}", expected) is not None
                and digest(raw) == expected[7:],
                "Original Actions ZIP does not match external artifact digest: " + platform)
        names = {"host-evidence.json", HOST_ARCHIVE_RUNTIME[platform]}
        names.update("logs/" + case + ".log" for case in HOST_CASES)
        bounds = {"host-evidence.json": 65536,
                  HOST_ARCHIVE_RUNTIME[platform]: 64 * 1024 * 1024}
        bounds.update({"logs/" + case + ".log": 8_000_000 for case in HOST_CASES})
        try:
            with zipfile.ZipFile(io.BytesIO(raw), "r") as archive:
                infos = archive.infolist()
                actual_names = [info.filename for info in infos]
                require(len(actual_names) == len(names) and
                        set(actual_names) == names,
                        "ZIP has missing, duplicate, extra or unsafe paths: " + platform)
                require(all(info.file_size > 0 and
                            info.file_size <= bounds[info.filename] and
                            info.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                            and not (info.flag_bits & 1) and
                            ((info.external_attr >> 16) & 0o170000)
                            in (0, 0o100000) for info in infos),
                        "Unsafe or oversized ZIP member: " + platform)
                parts = {info.filename: archive.read(info) for info in infos}
                require(all((zlib.crc32(parts[info.filename]) & 0xffffffff) == info.CRC
                            for info in infos), "ZIP member CRC mismatch: " + platform)
        except (zipfile.BadZipFile, zipfile.LargeZipFile, EOFError,
                OSError, ValueError, zlib.error) as exc:
            raise RuntimeError("Unreadable original Actions ZIP: " + platform) from exc
        bundles[platform] = {
            "report": parts["host-evidence.json"],
            "runtime": parts[HOST_ARCHIVE_RUNTIME[platform]],
            "logs": {case: parts["logs/" + case + ".log"] for case in HOST_CASES},
        }
    return verify_host_receipts(bundles, source, tree,
                                expected_run_id, expected_run_attempt)



# Pure GitHub Actions metadata custody boundary for a FUTURE, owner-authorized
# read-only producer. The caller must fetch this data independently from GitHub's
# REST API, not from the candidate ZIP or a build-generated receipt.
ACTIONS_HOST_JOBS = {
    "linux-host": ("Build exact-source Linux GDExtension",
                   "Execute exact-source Godot 4.7 render tests"),
    "windows-build": ("Build and stage exact Windows GDExtension",),
    "windows-host": ("Execute actual Windows Godot native render tests",),
}
ACTIONS_ARTIFACT_PREFIX = "render-copy290-host-evidence-"
ACTIONS_RUNNER_LABELS = {"linux-host": ["ubuntu-24.04"],
                         "windows-build": ["ubuntu-24.04"],
                         "windows-host": ["windows-2022"]}
REPOSITORY_ID = 1350077435


def verify_actions_custody(run, jobs, artifacts, source_sha, run_id, attempt,
                           branch, workflow_path):
    """Bind independently obtained REST metadata to the future paired ZIPs.

    This returns external artifact digests ONLY. No build, download or publish
    happens here, and self-supplied REST-looking JSON is not authenticated.
    """
    require(type(source_sha) is str and
            re.fullmatch(r"[0-9a-f]{40}", source_sha) is not None
            and type(run_id) is int and run_id > 0
            and type(attempt) is int and attempt > 0
            and type(branch) is str and bool(branch)
            and type(workflow_path) is str
            and workflow_path.startswith(".github/workflows/")
            and workflow_path.endswith(".yml"),
            "Malformed externally pinned Actions source/run/branch/workflow")
    require(type(run) is dict and type(jobs) is list and
            type(artifacts) is list, "Malformed Actions metadata")
    repo, head_repo = run.get("repository"), run.get("head_repository")
    require(type(repo) is dict and type(head_repo) is dict
            and repo.get("full_name") == REPO and head_repo.get("full_name") == REPO
            and type(repo.get("id")) is int and repo["id"] == REPOSITORY_ID
            and type(head_repo.get("id")) is int
            and head_repo["id"] == REPOSITORY_ID,
            "Actions run belongs to another repository or fork")
    require(type(run.get("id")) is int and run["id"] == run_id
            and type(run.get("run_attempt")) is int
            and run["run_attempt"] == attempt
            and run.get("head_sha") == source_sha
            and run.get("head_branch") == branch
            and run.get("path") == workflow_path
            and run.get("event") == "push"
            and run.get("status") == "completed"
            and run.get("conclusion") == "success",
            "Actions run source, identity, workflow or final outcome differs")
    require(len(jobs) == len(ACTIONS_HOST_JOBS)
            and {j.get("name") for j in jobs if type(j) is dict}
            == set(ACTIONS_HOST_JOBS), "Incomplete or duplicate host jobs")
    job_ids = set()
    for job in jobs:
        name = job["name"]
        require(type(job.get("id")) is int and job["id"] > 0
                and job["id"] not in job_ids
                and type(job.get("run_id")) is int and job["run_id"] == run_id
                and type(job.get("run_attempt")) is int
                and job["run_attempt"] == attempt
                and job.get("head_sha") == source_sha
                and job.get("head_branch") == branch
                and job.get("labels") == ACTIONS_RUNNER_LABELS[name]
                and job.get("runner_group_name") == "GitHub Actions"
                and type(job.get("runner_id")) is int and job["runner_id"] > 0
                and type(job.get("runner_name")) is str
                and job["runner_name"].startswith("GitHub Actions ")
                and job.get("status") == "completed"
                and job.get("conclusion") == "success"
                and type(job.get("steps")) is list,
                "Host job identity or outcome differs: " + name)
        job_ids.add(job["id"])
        steps = job["steps"]
        for required_step in ACTIONS_HOST_JOBS[name]:
            matches = [s for s in steps if type(s) is dict
                       and s.get("name") == required_step]
            require(len(matches) == 1 and
                    matches[0].get("status") == "completed" and
                    matches[0].get("conclusion") == "success",
                    "Missing or nonpassing source/host step: " + required_step)
        require(all(type(s) is dict and s.get("conclusion") == "success"
                    for s in steps),
                "Host job includes a failed, skipped or cancelled step: " + name)
    expected_names = {
        p: ACTIONS_ARTIFACT_PREFIX + p + "-" + str(run_id)
        for p in HOST_TARGETS
    }
    found = {}
    for artifact in artifacts:
        require(type(artifact) is dict, "Malformed Actions artifact")
        name = artifact.get("name")
        if not isinstance(name, str) or not name.startswith(ACTIONS_ARTIFACT_PREFIX):
            continue  # Unrelated build-transfer artifacts are not publisher inputs.
        require(name in expected_names.values()
                and name not in found, "Unexpected or duplicate host artifact")
        arun = artifact.get("workflow_run")
        require(type(arun) is dict
                and type(artifact.get("id")) is int and artifact["id"] > 0
                and type(artifact.get("size_in_bytes")) is int
                and 0 < artifact["size_in_bytes"] <= 96 * 1024 * 1024
                and artifact.get("expired") is False
                and type(artifact.get("digest")) is str
                and re.fullmatch(r"sha256:[0-9a-f]{64}",
                                 artifact["digest"]) is not None
                and arun.get("id") == run_id
                and arun.get("head_sha") == source_sha
                and arun.get("head_branch") == branch
                and type(arun.get("repository_id")) is int
                and arun["repository_id"] == REPOSITORY_ID
                and type(arun.get("head_repository_id")) is int
                and arun["head_repository_id"] == REPOSITORY_ID,
                "Host artifact metadata does not bind to the pinned run")
        found[name] = artifact["digest"]
    require(set(found) == set(expected_names.values()),
            "Both original, unexpired host artifacts are required")
    return {p: found[name] for p, name in expected_names.items()}


def check():
    context(dict(os.environ))
    head = git("rev-parse", "HEAD").decode().strip()
    source_lease(os.environ, head)
    subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor",
                    FROZEN_HEAD, head], check=True, timeout=30)
    paths_ok(set(git("diff", "--name-only", FROZEN_HEAD, "HEAD").decode().splitlines()))
    paths = set(git("ls-tree", "-r", "--name-only", "HEAD").decode().splitlines())
    no_request(REQUEST in paths, (ROOT / REQUEST).exists())
    for path, blob, sha in [
        ("native/src/world.cpp", WORLD_BLOB, WORLD_DIGEST),
        ("native/tests/test_world.cpp", TEST_BLOB, TEST_DIGEST),
    ]:
        require(git("rev-parse", "HEAD:" + path).decode().strip() == blob
                and digest(git("show", "HEAD:" + path)) == sha,
                "Corrected executable or test source mutated: " + path)
    native = {p for p in paths if p.startswith(("native/include/", "native/src/",
                                                "godot/native_extension/"))
              and Path(p).suffix in SUFFIX}
    for platform, (manifest_path, blob, runtime, sha, size) in RETAINED.items():
        require(git("rev-parse", "HEAD:" + manifest_path).decode().strip() == blob,
                "Historical " + platform + " manifest changed")
        manifest = json.loads(git("show", "HEAD:" + manifest_path))
        require(manifest["source_commit"] == "d7e35aa3897ffa0bde422ece98226c551588040e"
                and manifest["artifact"] == runtime and manifest["sha256"] == sha
                and manifest["size"] == size, "Historical manifest identity changed")
        pointer_ok(git("show", "HEAD:" + runtime), sha, size)
        source, build = manifest["source_inputs"], manifest["build_inputs"]
        inputs = (set(source) | set(build)) & paths
        current = {p: digest(git("show", "HEAD:" + p)) for p in inputs}
        drift_ok(native, source, build, current)
    require(not git("status", "--porcelain", "--untracked-files=no").strip(),
            "Dirty tracked preparation checkout")
    print("RENDER_COPY290_PREFLIGHT PASS: source/oracle frozen, historical LFS unchanged, request absent")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check-unarmed"])
    parser.parse_args()
    check()


if __name__ == "__main__":
    main()
