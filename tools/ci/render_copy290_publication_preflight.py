#!/usr/bin/env python3
"""Read-only, UNARMED Git/LFS preflight for draft Cybersand PR #290."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REPO = "techrote/cybersand"
PREP = "prep/render-copy290-publisher-20261029"
FEATURE = "claude/render-copy-per-run"
FROZEN_HEAD = "f551e8064a7d01ceb554774afb5c61e71e715c63"
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
