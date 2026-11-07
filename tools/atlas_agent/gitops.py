"""Git identity, patch export/scope checking and compare-and-swap branch publication.

Default runner output is a local patch. ``publish_patch`` is a separate, explicit
step that: re-checks the upstream HEAD against the SHA the patch was made from,
refuses lane-foreign or non-modification changes, refuses protected or existing
branch names, never force-pushes and never touches the base branch.
"""
from __future__ import annotations

import difflib
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from .errors import ConfigError, SourceChanged
from .sandbox import glob_to_regex

PROTECTED_BRANCH = re.compile(r"^(main|master|HEAD|design/.*|release/.*|tools/.*|claude/.*)$")
SHA40 = re.compile(r"^[0-9a-f]{40}$")
BRANCH_PREFIX = "atlas-agent/"


def git(args: list[str], cwd: Path, timeout: float = 60, check: bool = True) -> subprocess.CompletedProcess:
    env = {k: v for k, v in os.environ.items() if k in ("PATH", "SYSTEMROOT", "SystemRoot", "HOME", "USERPROFILE",
                                                          "TEMP", "TMP", "APPDATA", "LOCALAPPDATA")}
    env.update({"GIT_TERMINAL_PROMPT": "0", "GIT_OPTIONAL_LOCKS": "0", "LC_ALL": "C"})
    done = subprocess.run(["git", *args], cwd=str(cwd), capture_output=True, text=True, encoding="utf-8",
                          errors="replace", timeout=timeout, env=env)
    if check and done.returncode != 0:
        raise SourceChanged(f"git {' '.join(args[:3])} failed: {done.stderr.strip()[:300]}", "git_command_failed")
    return done


def repo_identity(path: Path) -> dict:
    """HEAD and cleanliness of the checkout containing ``path`` (or nulls when not a repo)."""
    probe = git(["rev-parse", "--show-toplevel"], path, check=False)
    if probe.returncode != 0:
        return {"repository_head": None, "toplevel": None, "dirty": None, "dirty_paths": []}
    top = Path(probe.stdout.strip())
    head = git(["rev-parse", "HEAD"], top, check=False).stdout.strip() or None
    rel = os.path.relpath(path, top).replace("\\", "/")
    status = git(["status", "--porcelain", "--", rel if rel != "." else "."], top, check=False).stdout
    dirty = [line[3:] for line in status.splitlines() if line.strip()]
    return {"repository_head": head, "toplevel": str(top), "dirty": bool(dirty), "dirty_paths": dirty[:20]}


def check_expected_sha(expected: str | None, actual: str | None) -> None:
    if expected is None:
        return
    if not SHA40.fullmatch(expected):
        raise ConfigError("expected source SHA must be 40 lowercase hex characters", "invalid_source_sha")
    if actual is None:
        raise SourceChanged("an expected source SHA was given but the source has no Git HEAD", "source_not_git")
    if actual != expected:
        raise SourceChanged(f"source HEAD {actual[:12]} differs from the expected {expected[:12]}; refusing to run "
                            "against unreviewed upstream state", "source_sha_mismatch")


# --------------------------------------------------------------------------- patches

def unified_patch(rel: str, before: bytes, after: bytes) -> str:
    """git-apply compatible diff of one modified text file."""
    a = before.decode("utf-8").splitlines(keepends=True)
    b = after.decode("utf-8").splitlines(keepends=True)

    def terminated(lines: list[str]) -> list[str]:
        if lines and not lines[-1].endswith("\n"):
            return lines[:-1] + [lines[-1] + "\n\\ No newline at end of file\n"]
        return lines

    body = "".join(difflib.unified_diff(terminated(a), terminated(b), f"a/{rel}", f"b/{rel}", n=3))
    return f"diff --git a/{rel} b/{rel}\n{body}" if body else ""


_DIFF_HEADER = re.compile(r"^diff --git a/(\S+) b/(\S+)$")


def patch_targets(patch: str) -> list[str]:
    """Modified file paths named by a patch; raises on anything but plain modifications."""
    targets: list[str] = []
    for line in patch.splitlines():
        match = _DIFF_HEADER.match(line)
        if match:
            if match.group(1) != match.group(2):
                raise SourceChanged("rename in patch rejected", "patch_not_modification")
            targets.append(match.group(1))
        elif line.startswith(("new file mode", "deleted file mode", "rename ", "copy ", "old mode", "new mode",
                              "GIT binary patch", "Binary files")):
            raise SourceChanged(f"unsupported patch operation rejected: {line[:40]}", "patch_not_modification")
    for target in targets:
        if target.startswith("/") or ".." in target.split("/"):
            raise SourceChanged(f"unsafe patch path rejected: {target}", "patch_path_unsafe")
    return targets


def check_patch_scope(patch: str, write_globs: list[str]) -> list[str]:
    allowed = [glob_to_regex(g) for g in write_globs]
    targets = patch_targets(patch)
    if not targets:
        raise SourceChanged("patch changes nothing", "patch_empty")
    for target in targets:
        if not any(p.match(target) for p in allowed):
            raise SourceChanged(f"patch touches {target}, outside the lane's assigned files", "lane_ownership_violation")
    return targets


# -------------------------------------------------------------------------- publish

def publish_patch(repo: Path, patch_path: Path, expected_head: str, branch: str, write_globs: list[str],
                  remote: str | None = None, base_ref: str = "HEAD", push: bool = False,
                  message: str = "atlas-agent: bounded Atlas source revision") -> dict:
    """Commit the patch to a NEW disposable branch based on exactly ``expected_head``."""
    if not SHA40.fullmatch(expected_head or ""):
        raise ConfigError("expected head must be a 40-hex SHA", "invalid_source_sha")
    if not branch.startswith(BRANCH_PREFIX) or PROTECTED_BRANCH.match(branch) or ".." in branch \
            or not re.fullmatch(r"atlas-agent/[A-Za-z0-9._/-]{1,80}", branch):
        raise SourceChanged(f"branch {branch!r} must be a new '{BRANCH_PREFIX}*' branch", "branch_not_disposable")
    patch = patch_path.read_text(encoding="utf-8")
    targets = check_patch_scope(patch, write_globs)

    head = git(["rev-parse", base_ref], repo).stdout.strip()
    if head != expected_head:
        raise SourceChanged(f"upstream HEAD moved ({head[:12]} != {expected_head[:12]}); another writer committed "
                            "first, nothing was overwritten", "upstream_head_changed")
    if remote:
        listed = git(["ls-remote", remote, "refs/heads/*"], repo, timeout=120).stdout
        names = {line.split("\t")[1]: line.split("\t")[0] for line in listed.splitlines() if "\t" in line}
        if f"refs/heads/{branch}" in names:
            raise SourceChanged(f"remote branch {branch} already exists; refusing to overwrite", "branch_exists")
    if git(["rev-parse", "--verify", "--quiet", f"refs/heads/{branch}"], repo, check=False).returncode == 0:
        raise SourceChanged(f"local branch {branch} already exists; refusing to overwrite", "branch_exists")

    work = Path(tempfile.mkdtemp(prefix="atlas-agent-publish-"))
    try:
        git(["worktree", "add", "--detach", str(work / "wt"), expected_head], repo)
        tree = work / "wt"
        git(["apply", "--check", "--whitespace=nowarn", str(patch_path)], tree)
        git(["apply", "--whitespace=nowarn", str(patch_path)], tree)
        changed = sorted(git(["diff", "--name-only"], tree).stdout.split())
        if changed != sorted(targets):
            raise SourceChanged("applied changes differ from the patch's declared targets", "patch_scope_mismatch")
        git(["add", "--", *targets], tree)
        git(["-c", "user.name=atlas-agent", "-c", "user.email=atlas-agent@users.noreply.github.com",
             "commit", "-q", "-m", message], tree)
        commit = git(["rev-parse", "HEAD"], tree).stdout.strip()
        git(["branch", branch, commit], repo)
    finally:
        git(["worktree", "remove", "--force", str(work / "wt")], repo, check=False)
        shutil.rmtree(work, ignore_errors=True)
    result = {"branch": branch, "commit": commit, "base": expected_head, "files": targets, "pushed": False}
    if push:
        if not remote:
            raise ConfigError("--push requires --remote", "remote_required")
        git(["push", remote, f"{commit}:refs/heads/{branch}"], repo, timeout=180)  # new ref only, never forced
        result["pushed"] = True
    return result
