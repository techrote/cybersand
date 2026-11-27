"""Isolate pinned Architecture readers with current Art's real owned HTTP route.

Never edits either source checkout or imports the counterpart branch. The result
is a proposal/correlation fixture, not combined native or package acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
PIN = "17c6b5b35049b7b2541c2deeea23c02fd1e2fc5d"
PRELOAD = re.compile(rb'(?:preload|load)\s*\(\s*["\']res://([^"\']+)["\']\s*\)')
MARKER = "ART_ARCHITECTURE_HANDOFF_RESULT "
ERROR = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(repo: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(repo), *args], env=dict(os.environ, GIT_NO_LAZY_FETCH="1"))


def pinned(repo: Path, ref: str, path: str) -> bytes:
    data = git(repo, "show", f"{ref}:{path}")
    if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
        digest = re.search(rb"oid sha256:([0-9a-f]{64})", data)
        materialized = (repo / path).read_bytes()
        if not digest or sha(materialized) != digest[1].decode():
            raise RuntimeError(f"Pinned input is not hash-matched materialized LFS: {path}")
        return materialized
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--architecture-repository", required=True, type=Path)
    parser.add_argument("--architecture-ref", default=PIN)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    repo = args.architecture_repository.resolve()
    ref = git(repo, "rev-parse", "--verify", args.architecture_ref + "^{commit}").decode().strip()
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError("Use a fresh empty evidence directory; original observations are immutable.")
    project = output / "project"
    project.mkdir(parents=True)
    inputs: dict[str, dict[str, str | int]] = {}
    overrides = {
        "scripts/art_provider.gd": ROOT / "godot/scripts/art_provider.gd",
        "scripts/art_proposal_transport.gd": ROOT / "godot/scripts/art_proposal_transport.gd",
        "scripts/art_response_preparation.gd": ROOT / "godot/scripts/art_response_preparation.gd",
        "scripts/art_redaction.gd": ROOT / "godot/scripts/art_redaction.gd",
        "scripts/art_traffic_archive.gd": ROOT / "godot/scripts/art_traffic_archive.gd",
        "tests/probe_art_architecture_handoff.gd": ROOT / "tools/fixtures/art_architecture_handoff.gd",
    }

    def write(path: str, data: bytes, owner: str) -> None:
        destination = project / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        inputs[path] = {"owner": owner, "sha256": sha(data), "bytes": len(data)}

    pending = ["tests/probe_art_architecture_handoff.gd"]
    while pending:
        path = pending.pop()
        if path in inputs:
            continue
        if path in overrides:
            data = overrides[path].read_bytes()
            owner = "current-art-source"
        else:
            data = pinned(repo, ref, "godot/" + path)
            owner = "architecture-" + ref
        write(path, data, owner)
        if path.endswith(".gd"):
            pending += [match.decode() for match in PRELOAD.findall(data) if match.decode() not in inputs]
    # The Architecture retriever reads versioned JSON using FileAccess. Copy the
    # exact pinned data subtree, never a moving file from its worktree.
    paths = git(repo, "ls-tree", "-r", "--name-only", ref, "--", "godot/data/batch_lab").decode().splitlines()
    for path in paths:
        write(path.removeprefix("godot/"), pinned(repo, ref, path), "architecture-" + ref)
    extension = "addons/cybersand_native/cybersand_native.gdextension"
    binary = "addons/cybersand_native/bin/" + ("cybersand_native.windows.x86_64.dll" if sys.platform == "win32" else "libcybersand_native.linux.x86_64.so")
    for path in (extension, binary):
        data = (ROOT / "godot" / path).read_bytes()
        committed = git(ROOT, "show", "HEAD:godot/" + path)
        if committed.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
            digest = re.search(rb"oid sha256:([0-9a-f]{64})", committed)
            if not digest or sha(data) != digest[1].decode():
                raise RuntimeError(f"Art runtime is not the committed LFS payload: {path}")
        elif data != committed:
            raise RuntimeError(f"Runtime descriptor differs from current source: {path}")
        write(path, data, "current-art-runtime")
    write(".godot/extension_list.cfg", ("res://" + extension + "\n").encode(), "probe-project")
    write("project.godot", b'config_version=5\n[application]\nconfig/name="ArtArchitectureOwnerHandoff"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', "probe-project")
    manifest = {"format": "cybersand-art-architecture-handoff-inputs-v1", "architecture_commit": ref,
                "architecture_tree": git(repo, "rev-parse", ref + "^{tree}").decode().strip(),
                "art_commit": git(ROOT, "rev-parse", "HEAD").decode().strip(),
                "art_working_delta": git(ROOT, "status", "--porcelain=v1", "--untracked-files=normal").decode().splitlines(),
                "runner_sha256": sha(Path(__file__).read_bytes()),
                "godot_sha256": sha(args.godot.resolve().read_bytes()), "inputs": inputs}
    (output / "inputs.json").write_text(json.dumps(manifest, indent=2) + "\n")
    command = [str(args.godot.resolve()), "--headless", "--audio-driver", "Dummy", "--path", str(project), "--script", "res://tests/probe_art_architecture_handoff.gd"]
    profile = output / "profile"
    environment = dict(os.environ, XDG_DATA_HOME=str(profile), APPDATA=str(profile))
    began = time.monotonic()
    returncode = None
    timed_out = False
    with (output / "probe.log").open("w", encoding="utf-8") as log:
        try:
            result = subprocess.run(command, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=180, check=False)
            returncode = result.returncode
        except subprocess.TimeoutExpired:
            timed_out = True
    raw = (output / "probe.log").read_bytes()
    text = raw.decode("utf-8", errors="replace")
    malformed_receipt = False
    try:
        receipts = [json.loads(line[len(MARKER):]) for line in text.splitlines() if line.startswith(MARKER)]
    except json.JSONDecodeError:
        receipts = []
        malformed_receipt = True
    receipt = receipts[-1] if len(receipts) == 1 else {}
    identities_match = isinstance(receipt, dict) and all(receipt.get(key) == inputs[path]["sha256"] for key, path in (
        ("provider_sha256", "scripts/art_provider.gd"),
        ("adapter_sha256", "scripts/art_proposal_transport.gd"),
        ("architecture_bridge_sha256", "scripts/batch_lab/architecture_proposal_bridge.gd")))
    passed = returncode == 0 and not timed_out and not malformed_receipt and not ERROR.search(text) \
        and identities_match and bool(receipt) and receipt.get("checks", 0) >= 30 \
        and receipt.get("failures") == [] and receipt.get("actual_http_exchanges", 0) >= 3 \
        and receipt.get("ordinary_completions") == 0 and receipt.get("native_writes") == 0 and receipt.get("model_calls") == 0
    record = {"passed": passed, "returncode": returncode, "timed_out": timed_out,
              "malformed_receipt": malformed_receipt, "receipt_source_hashes_match": identities_match,
              "duration_seconds": time.monotonic()-began,
              "command": command, "architecture_commit": ref, "art_commit": manifest["art_commit"],
              "inputs_sha256": sha((output / "inputs.json").read_bytes()), "log_sha256": sha(raw), "receipt": receipt,
              "scope": "Actual owner/bridge/typed-parser handoff with local deterministic HTTP and copied inspection fixture. No combined native or package acceptance."}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
