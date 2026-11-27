#!/usr/bin/env python3
"""Reproduce raw-evidence newline rules in owned temporary Git repositories."""
from pathlib import Path
import hashlib
import json
import os
import subprocess

BASE = Path(__file__).resolve().parent
inventory = json.loads((BASE / "inventory.json").read_text())
inputs = {x["path"]: Path(x["local"]).read_bytes() for x in inventory["text_crlf"]}
json_paths = sorted(path for path in inputs if path.endswith(".json"))
assert len(json_paths) == 5
original_attributes = (BASE / "remote.gitattributes").read_bytes()
original_ignore = (BASE / "remote.gitignore").read_bytes()
candidate_path = "docs/research/ambient-002/evidence/windows-50c6-complete/.gitattributes"
candidate_attributes = (BASE / "candidate.nested.gitattributes").read_bytes()
assert hashlib.sha256(candidate_attributes).hexdigest() == "c917a3b073599024392b1ad76883a48671b64225c46e8ecdd0248a1a280dcc53"

def blob_id(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()

def scenario(autocrlf):
    repo = BASE / ("isolated-git-nested-final-" + autocrlf)
    repo.mkdir(exist_ok=False)
    commands = []

    def git(*args, input=None, allowed=(0,)):
        proc = subprocess.run(["git", "-C", str(repo), *args], input=input, capture_output=True)
        result = {"args": list(args), "returncode": proc.returncode,
                  "stdout": proc.stdout.decode(errors="replace"),
                  "stderr": proc.stderr.decode(errors="replace")}
        commands.append(result)
        (BASE / ("commands-nested-" + autocrlf + ".json")).write_text(json.dumps(commands, indent=2) + "\n")
        if proc.returncode not in allowed:
            raise RuntimeError(result)
        return result

    def out(*args, **kwargs):
        # Preserve the leading porcelain column; only remove terminal newlines.
        return git(*args, **kwargs)["stdout"].rstrip("\n")

    git("init", "-q")
    git("config", "user.name", "AMBIENT evidence diagnostic")
    git("config", "user.email", "ambient-diagnostic@invalid")
    git("config", "core.autocrlf", autocrlf)
    git("config", "commit.gpgsign", "false")
    files = {".gitattributes": original_attributes, ".gitignore": original_ignore, **inputs}
    blobs = {}
    for path, data in files.items():
        sha = out("hash-object", "-w", "--stdin", input=data)
        assert sha == blob_id(data)
        blobs[path] = sha
        git("update-index", "--add", "--cacheinfo", "100644", sha, path)
    tree = out("write-tree")
    commit = out("commit-tree", tree, input=b"Isolated original evidence checkout\n")
    git("reset", "--hard", commit)
    status_initial = out("status", "--porcelain=v1", "--untracked-files=all")
    initial_parent_attributes = (repo / ".gitattributes").read_bytes()
    initial_parent_ignore = (repo / ".gitignore").read_bytes()

    def force_refresh():
        # Change only filesystem timestamps, ensuring stat-cache shortcuts cannot
        # hide the content comparison. No evidence byte is rewritten.
        for path in inputs:
            target = repo / path
            stat = target.stat()
            os.utime(target, ns=(stat.st_atime_ns, stat.st_mtime_ns + 1_000_000_000))
        refresh = git("update-index", "--really-refresh", allowed=(0, 1))
        diff = out("diff", "--name-only", "--")
        status = out("status", "--porcelain=v1", "--untracked-files=all")
        return {"refresh_returncode": refresh["returncode"], "refresh_stdout": refresh["stdout"],
                "diff_paths": diff.splitlines(), "porcelain": status,
                "dirty_paths": [line[3:] for line in status.splitlines()]}

    original = force_refresh()
    assert original["dirty_paths"] == json_paths
    assert original["diff_paths"] == json_paths
    assert original["refresh_returncode"] == 1
    assert all((repo / path).read_bytes() == data for path, data in inputs.items())
    (repo / candidate_path).write_bytes(candidate_attributes)
    git("add", candidate_path)
    git("commit", "-m", "Isolated exact-path raw-evidence attribute exceptions")
    fixed = force_refresh()
    assert fixed["refresh_returncode"] == 0 and not fixed["porcelain"] and not fixed["diff_paths"]
    changed = out("diff", "HEAD~1", "HEAD", "--name-only").splitlines()
    assert changed == [candidate_path]
    assert (repo / ".gitattributes").read_bytes() == initial_parent_attributes
    assert out("rev-parse", "HEAD:.gitattributes") == blobs[".gitattributes"]
    assert (repo / ".gitignore").read_bytes() == initial_parent_ignore
    assert out("rev-parse", "HEAD:.gitignore") == blobs[".gitignore"]
    unchanged = []
    for path, data in inputs.items():
        actual = (repo / path).read_bytes()
        committed = out("rev-parse", "HEAD:" + path)
        assert actual == data and committed == blobs[path] == blob_id(actual)
        unchanged.append({"path": path, "blob": committed, "sha256": hashlib.sha256(actual).hexdigest(),
                          "bytes": len(actual), "crlf": actual.count(b"\r\n")})
    attr_check = out("check-attr", "text", "eol", "whitespace", "--", *json_paths)
    patch = out("diff", "HEAD~1", "HEAD", "--", candidate_path) + "\n"
    (BASE / ("commands-nested-" + autocrlf + ".json")).write_text(json.dumps(commands, indent=2) + "\n")
    (BASE / "candidate-nested-attributes.patch").write_text(patch)
    return {"core_autocrlf": autocrlf, "git_version": out("--version"),
            "initial_porcelain": status_initial, "parent_blobs_unchanged": True,
            "parent_checkout_bytes_unchanged_by_candidate": True,
            "parent_checkout_crlf": {"gitattributes": initial_parent_attributes.count(b"\r\n"),
                                     "gitignore": initial_parent_ignore.count(b"\r\n")},
            "original_forced_refresh": original,
            "candidate_forced_refresh": fixed, "candidate_changed_paths": changed,
            "candidate_attributes": attr_check, "original_evidence_preserved": unchanged}

report = {"scope": "isolated Git checkout diagnostic; no application, workflow or clean-tree-guard change",
          "source_head": "62a05adf12dfddb744a1e043c2bb4581c7b334e7",
          "gitattributes_blob": blob_id(original_attributes), "gitignore_blob": blob_id(original_ignore),
          "candidate_paths": json_paths, "candidate_attribute_path": candidate_path,
          "candidate_attribute_blob": blob_id(candidate_attributes),
          "candidate_attribute_sha256": hashlib.sha256(candidate_attributes).hexdigest(),
          "scenarios": [scenario("false"), scenario("true")],
          "passed": True}
report["reader_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
(BASE / "reproduction-nested.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"passed": report["passed"], "source_head": report["source_head"],
                  "scenarios": [{"core_autocrlf": x["core_autocrlf"],
                    "before_dirty_paths": x["original_forced_refresh"]["dirty_paths"],
                    "after_status": x["candidate_forced_refresh"]["porcelain"],
                    "changed_paths": x["candidate_changed_paths"]} for x in report["scenarios"]]}, indent=2))
