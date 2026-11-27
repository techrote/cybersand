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
