"""One source-qualified MAT354 H1 proposal, never an adoption or refresh API.

The legacy lock remains independently authenticated by compatibility.py. This
module admits exactly one additional world.cpp identity from the immutable
source-only commit below. The sidecar is compared with facts derived from Git;
editing its expected hashes cannot create another accepted source. All other
protected files must still equal the historical authority.

This checks source custody and the declared delta's bounds. It cannot attest
semantic correctness, performance, runtime execution or independent approval.
Those remain separate gates on the resulting candidate, not fields that a
caller can mark approved here.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess

BASELINE = "0fd4af5987e77db4da3e37c757cf2c0917ae9e15"
SOURCE_PARENT = "751edc0b495dc85484ad5509a7c95f863651c76b"
SOURCE_COMMIT = "16533ff81c561677308665357eb1d0d5f65e85bc"
SOURCE_TREE = "c0545655f190f0c9e990010873d24b1e702385a5"
WORLD = "native/src/world.cpp"
OLD_WORLD_SHA256 = "b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1"
NEW_WORLD_SHA256 = "df0bb080084972c49ca400b7bfc6504f7ec27fa474112bc2bd56abe5d3d21539"
RECORD = Path("materials/catalogue/h1-source-transition.json")
LEGACY_LOCK = "materials/catalogue/compatibility-lock.json"
TRANSITION_ID = "mat354-h1-cooling-deadline-v1"
HELPER_START = b"\nvoid World::schedule_pending_reaction_wake("
HELPER_END = b"\nbool World::update_cell("


class TransitionError(ValueError):
    """An absent or mismatched authority; no source or receipt is rewritten."""


def lf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n")


def sha(data: bytes) -> str:
    return hashlib.sha256(lf(data)).hexdigest()


def _git(repository: Path, *args: str) -> bytes:
    try:
        return subprocess.run(
            ["git", "--no-replace-objects", "-C", str(repository), *args],
            check=True, capture_output=True, timeout=30,
        ).stdout
    except (OSError, subprocess.SubprocessError) as exc:
        raise TransitionError(
            f"cannot authenticate H1 Git authority ({' '.join(args)}); "
            f"complete retained history required: {exc}"
        ) from exc


def _blob(repository: Path, commit: str, path: str) -> tuple[str, bytes]:
    entry = _git(repository, "ls-tree", "-z", commit, "--", path)
    parts = entry.rstrip(b"\0").split(b"\t")
    if len(parts) != 2 or parts[1] != path.encode("utf-8"):
        raise TransitionError(f"{commit}:{path}: missing or ambiguous Git source")
    fields = parts[0].split()
    if len(fields) != 3 or fields[:2] != [b"100644", b"blob"]:
        raise TransitionError(f"{commit}:{path}: expected an ordinary 100644 source blob")
    blob_id = fields[2].decode("ascii")
    data = _git(repository, "cat-file", "blob", blob_id)
    actual = hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()
    if actual != blob_id:
        raise TransitionError(f"{commit}:{path}: Git blob content identity mismatch")
    return blob_id, data


def _helper_parts(data: bytes) -> tuple[bytes, bytes, bytes]:
    data = lf(data)
    if data.count(HELPER_START) != 1 or data.count(HELPER_END) != 1:
        raise TransitionError("H1 source scope: missing or ambiguous helper boundaries")
    start, end = data.index(HELPER_START), data.index(HELPER_END)
    if end <= start:
        raise TransitionError("H1 source scope: reversed helper boundaries")
    return data[:start], data[start:end], data[end:]


def scoped_delta(before: bytes, after: bytes) -> dict:
    old_prefix, old_helper, old_suffix = _helper_parts(before)
    new_prefix, new_helper, new_suffix = _helper_parts(after)
    if old_prefix != new_prefix or old_suffix != new_suffix:
        raise TransitionError("H1 source scope: bytes outside schedule_pending_reaction_wake changed")
    if old_helper == new_helper:
        raise TransitionError("H1 source scope: missing cooling-deadline delta")
    return {"function": "World::schedule_pending_reaction_wake",
            "outside_function_unchanged": True,
            "historical_function_lf_sha256": sha(old_helper),
            "successor_function_lf_sha256": sha(new_helper)}


def expected_record(repository: Path, baseline: dict[str, bytes], roles: dict[str, str]) -> dict:
    """Derive the single pinned proposal from retained objects, without writing.

    The exact source commit and parent are code-owned review anchors. There is
    no caller-supplied commit, branch, allowlist, approval flag or refresh mode.
    """
    if len(roles) != 27 or set(baseline) != set(roles) or WORLD not in roles:
        raise TransitionError("H1 requires the complete 27-source historical authority")
    if sha(baseline[WORLD]) != OLD_WORLD_SHA256:
        raise TransitionError("H1 historical world.cpp identity differs from the admitted baseline")
    commit = _git(repository, "cat-file", "commit", SOURCE_COMMIT)
    actual_commit = hashlib.sha1(b"commit " + str(len(commit)).encode("ascii") + b"\0" + commit).hexdigest()
    if actual_commit != SOURCE_COMMIT:
        raise TransitionError("H1 source commit content identity mismatch")
    headers = commit.split(b"\n\n", 1)[0].splitlines()
    parents = [line[7:].decode("ascii") for line in headers if line.startswith(b"parent ")]
    trees = [line[5:].decode("ascii") for line in headers if line.startswith(b"tree ")]
    if parents != [SOURCE_PARENT] or trees != [SOURCE_TREE]:
        raise TransitionError("H1 source commit has an unexpected parent or tree")
    _git(repository, "merge-base", "--is-ancestor", BASELINE, SOURCE_PARENT)
    changed = _git(repository, "diff-tree", "--no-commit-id", "--name-only", "--no-renames",
                   "-r", "-z", SOURCE_PARENT, SOURCE_COMMIT)
    if changed != WORLD.encode("ascii") + b"\0":
        raise TransitionError("H1 anchor must be a source-only commit changing exactly native/src/world.cpp")

    old_blob, before = _blob(repository, SOURCE_PARENT, WORLD)
    new_blob, after = _blob(repository, SOURCE_COMMIT, WORLD)
    if lf(before) != lf(baseline[WORLD]) or sha(before) != OLD_WORLD_SHA256:
        raise TransitionError("H1 parent world.cpp does not equal the original legacy authority")
    if sha(after) != NEW_WORLD_SHA256:
        raise TransitionError("H1 successor world.cpp does not equal the pinned proposal")
    scope = scoped_delta(before, after)
    for name in sorted(roles):
        if name == WORLD:
            continue
        _, old = _blob(repository, SOURCE_PARENT, name)
        _, new = _blob(repository, SOURCE_COMMIT, name)
        if lf(old) != lf(baseline[name]) or lf(new) != lf(baseline[name]):
            raise TransitionError(f"{name}: H1 cannot transition another protected source")
    lock_blob, lock_bytes = _blob(repository, SOURCE_PARENT, LEGACY_LOCK)
    _, successor_lock = _blob(repository, SOURCE_COMMIT, LEGACY_LOCK)
    if lock_bytes != successor_lock:
        raise TransitionError("H1 must preserve the historical compatibility lock")
    # Bind exact source bytes without depending on Git's display-diff format,
    # user diff configuration, hunk heuristics, color or platform line endings.
    delta = hashlib.sha256(b"mat354-h1-source-delta-v1\0")
    for value in (WORLD.encode("ascii"), lf(before), lf(after)):
        delta.update(len(value).to_bytes(8, "little") + value)
    return {
        "schema_version": 1,
        "transition_id": TRANSITION_ID,
        "disposition": "proposed-source-identity-not-runtime-adoption",
        "historical_baseline": BASELINE,
        "historical_lock": {"path": LEGACY_LOCK, "git_blob": lock_blob,
                            "lf_sha256": sha(lock_bytes)},
        "source_parent": SOURCE_PARENT,
        "source_commit": SOURCE_COMMIT,
        "source_tree": SOURCE_TREE,
        "source_delta_paths": [WORLD],
        "source_delta_encoding": "mat354-h1-source-delta-v1",
        "source_delta_sha256": delta.hexdigest(),
        "source": {"path": WORLD,
                   "historical_git_blob": old_blob, "historical_lf_sha256": sha(before),
                   "successor_git_blob": new_blob, "successor_lf_sha256": sha(after)},
        "scope": scope,
        "protected_sources": 27,
        "unchanged_protected_sources": 26,
        "runtime_adoption_authorized": False,
    }


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise TransitionError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def read_record(path: Path) -> dict:
    try:
        data = path.read_bytes()
        if len(data) > 32768:
            raise TransitionError("H1 record exceeds the bounded 32 KiB schema")
        value = json.loads(data.decode("utf-8"), object_pairs_hook=_unique_object,
                           parse_constant=lambda token: (_ for _ in ()).throw(
                               TransitionError(f"non-finite JSON value {token}")))
    except (OSError, UnicodeError, ValueError) as exc:
        raise TransitionError(f"{path}: {exc}") from exc
    if not isinstance(value, dict):
        raise TransitionError(f"{path}: expected a source transition object")
    return value


def check_transition(root: Path, repository: Path, baseline: dict[str, bytes],
                     roles: dict[str, str], lock_path: Path) -> dict | None:
    path = root / RECORD
    if not path.exists():
        # Only the historical guard remains eligible without a receipt. The
        # caller must still compare world.cpp with its original locked digest.
        return None
    actual = read_record(path)
    expected = expected_record(repository, baseline, roles)
    if set(actual) != set(expected):
        raise TransitionError(f"{path}: expected exactly the pinned H1 record fields")
    for key in expected:
        if json.dumps(actual[key], sort_keys=True, allow_nan=False) != json.dumps(
                expected[key], sort_keys=True, allow_nan=False):
            raise TransitionError(f"{path}: /{key}: differs from immutable H1 source authority")
    try:
        current_lock = lock_path.read_bytes()
    except OSError as exc:
        raise TransitionError(f"H1 historical lock unavailable: {exc}") from exc
    if sha(current_lock) != expected["historical_lock"]["lf_sha256"]:
        raise TransitionError("H1 historical lock LF bytes differ; preserve the original lock")
    return expected
