"""Fail closed before publishing source-qualified Actor native LFS objects.

An unchanged Git LFS pointer is legal only when its indexed pointer,
actual candidate runtime bytes, size and fresh source-bound provenance agree.
The allow-list applies to changed *paths*, not unverified binary omissions.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

BINARIES = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
}
PROVENANCE = {
    "linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
    "windows": "godot/addons/cybersand_native/runtime-provenance.json",
}
ALLOWED = frozenset(BINARIES.values()) | frozenset(PROVENANCE.values())
ACTOR_BRANCH = "integration/actor-compose-final-001-20261123"
SWARM_BRANCH = "integration/swarm004-005-006-unified-20261122"
POINTER = re.compile(rb"version https://git-lfs.github.com/spec/v1\n"
                     rb"oid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n")


class PublicationRejected(ValueError):
    pass


def verify(changed: set[str], staged: dict[str, bytes],
           runtimes: dict[str, bytes], *, source: str, source_tree: str,
           branch: str, run_id: str, attempt: str) -> dict:
    """Check all four runtime identities for each permitted staged-path combination."""
    mandatory = set(PROVENANCE.values())
    if not mandatory <= changed or changed - ALLOWED:
        raise PublicationRejected("Expected both changed provenance paths and no unrelated staged paths")
    return verify_pair(changed, staged, runtimes, source, source_tree, branch, run_id, attempt)


def verify_pair(changed, staged, runtimes, source, source_tree, branch, run_id, attempt):
    if not re.fullmatch(r"[0-9a-f]{40}", source) or not re.fullmatch(r"[0-9a-f]{40}", source_tree):
        raise PublicationRejected("Missing exact qualified source identity")
    results = {}
    for platform in BINARIES:
        binary_path, provenance_path = BINARIES[platform], PROVENANCE[platform]
        try:
            record = json.loads(staged[provenance_path])
            pointer = POINTER.fullmatch(staged[binary_path])
            actual = runtimes[binary_path]
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
            raise PublicationRejected("Missing or malformed indexed runtime identity: " + platform) from exc
        if pointer is None or not isinstance(record, dict):
            raise PublicationRejected("Non-LFS pointer or invalid provenance: " + platform)
        digest = hashlib.sha256(actual).hexdigest()
        expected_digest = pointer.group(1).decode("ascii")
        expected_size = int(pointer.group(2))
        if digest != expected_digest or len(actual) != expected_size:
            raise PublicationRejected("Actual runtime differs from indexed Git LFS object: " + platform)
        if record.get("artifact") != binary_path or record.get("sha256") != digest or record.get("size") != len(actual):
            raise PublicationRejected("Source-bound provenance differs from candidate bytes: " + platform)
        for key, value in (
            ("source_commit", source), ("build_commit", source),
            ("source_tree", source_tree), ("publication_branch", branch),
            ("workflow_run", run_id), ("workflow_attempt", attempt),
            ("status", "evaluation-candidate-passed"),
        ):
            if str(record.get(key)) != value:
                raise PublicationRejected("Invalid provenance " + key + ": " + platform)
        qualification = record.get("qualification")
        if not isinstance(qualification, dict) or qualification.get("status") != "passed":
            raise PublicationRejected("Missing exact-source qualification: " + platform)
        if not isinstance(record.get("build_inputs"), dict) or not record["build_inputs"]:
            raise PublicationRejected("Missing native build inputs: " + platform)
        if not isinstance(record.get("source_inputs"), dict) or not record["source_inputs"]:
            raise PublicationRejected("Missing native source inputs: " + platform)
        if platform == "windows":
            package = record.get("installed_package_qualification")
            if not isinstance(package, dict) or package.get("status") != "passed":
                raise PublicationRejected("No verified extracted Windows evaluator")
        results[platform] = {
            "pointer_changed": binary_path in changed,
            "sha256": digest, "size": len(actual), "source_commit": source,
        }
    return results


def git(*args: str) -> bytes:
    return subprocess.check_output(("git", *args))


def reusable_pair() -> bool:
    """Retain this producer's qualified runtime pair across application-only changes."""
    from native_candidate_identity import source as native_source

    branch = git("branch", "--show-current").decode().strip()
    if branch not in (ACTOR_BRANCH, SWARM_BRANCH):
        return False
    root = Path.cwd()
    head, _, inputs = native_source(root)
    indexed = {name: git("show", "HEAD:" + name) for name in ALLOWED}
    records = [json.loads(indexed[name]) for name in PROVENANCE.values()]
    if any(record.get("source_inputs") != inputs for record in records):
        return False
    if branch == SWARM_BRANCH and any(not re.fullmatch(r"[0-9a-f]{64}",
            str(record.get("qualification", {}).get("reciprocal_execution_sha256", ""))) for record in records):
        return False
    previous = records[0]["build_commit"]
    if not re.fullmatch(r"[0-9a-f]{40}", previous):
        return False
    publishers = {".github/workflows/workbench-actor-sandbox.yml": b"\n  publish:\n",
                  "tools/ci/run_workbench_actor_qualification.py": b"\ndef publish_sandbox(args) -> None:\n"}
    changed = git("diff", "--name-only", previous, head).decode().splitlines()
    for path in changed:
        if path in ALLOWED or (path.startswith("docs/") and path.endswith(".md")):
            continue
        if path.startswith("godot/") and path.endswith(".gd"):
            continue
        if path in ("tools/package_ambient_evaluator.py", "tools/package_ambient_living_evaluator.py",
                    "tools/package_art_workbench_final.py", "tools/ci/test_swarm_package.py",
                    ".github/workflows/art-session-logging.yml",
                    "docs/reference/retrieval-questions-ambient-001.json",
                    "tools/ci/check_actor_publication_stage.py", "tools/ci/test_actor_publication_stage.py",
                    "tools/ci/test_workbench_actor_publication.py"):
            continue
        if path in publishers:
            # Protect the native producers and source transport. The current
            # platform/extraction jobs and same-run evidence reducer still run.
            old = git("show", previous + ":" + path).partition(publishers[path])
            now = git("show", head + ":" + path).partition(publishers[path])
            if old[1] and old[:2] == now[:2]:
                continue
        if path == "tools/package_explore001_candidate.py":
            old = git("show", previous + ":" + path)
            now = git("show", head + ":" + path)
            # The evaluator's archive staging does not participate in compilation.
            start, end = b"\ndef stage_project_archive(", b"\ndef main():"
            if (start in old and end in old and start in now and end in now
                    and old.partition(start)[0] == now.partition(start)[0]
                    and old.partition(end)[2] == now.partition(end)[2]):
                continue
        if path == ".github/workflows/gdextension.yml":
            old = git("show", previous + ":" + path)
            with_draft_push = f"    branches: [main, codex/wb-art-paint-integrated-20261111, {SWARM_BRANCH}]\n".encode()
            main_push = b"    branches: [main, codex/wb-art-paint-integrated-20261111]\n"
            if old.count(with_draft_push) == 1 and old.replace(with_draft_push, main_push) == git("show", head + ":" + path):
                continue
        return False
    runtimes = {name: (root / name).read_bytes() for name in BINARIES.values()}
    try:
        verify_pair(set(), indexed, runtimes, previous, git("rev-parse", previous + "^{tree}").decode().strip(),
                    branch, str(records[0]["workflow_run"]),
                    str(records[0]["workflow_attempt"]))
    except (PublicationRejected, KeyError):
        return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--branch", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--attempt", required=True)
    args = parser.parse_args()
    head = git("rev-parse", "HEAD").decode().strip()
    if head != args.source:
        raise PublicationRejected("Checkout HEAD differs from the qualified source")
    if git("branch", "--show-current").decode().strip() != args.branch:
        raise PublicationRejected("Publication is not on the dedicated Draft/HOLD branch")
    tree = git("rev-parse", args.source + "^{tree}").decode().strip()
    changed = set(git("diff", "--cached", "--name-only").decode().splitlines())
    indexed = {name: git("show", ":" + name) for name in ALLOWED}
    for platform, name in BINARIES.items():
        if name not in changed and indexed[name] != git("show", "HEAD:" + name):
            raise PublicationRejected("Unchanged LFS index does not match source parent: " + platform)
    runtimes = {name: Path(name).read_bytes() for name in BINARIES.values()}
    results = verify(changed, indexed, runtimes, source=args.source, source_tree=tree,
                     branch=args.branch, run_id=args.run_id, attempt=args.attempt)
    print(json.dumps({"result": "passed", "qualified_source": head,
                      "changed_paths": sorted(changed), "runtimes": results}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
