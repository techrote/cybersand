#!/usr/bin/env python3
"""Temporary source preparation only. Never advance PR #304 or main.

Apply the previously prepared eight-path repair to its exact original source,
then expose seven source paths on an isolated branch. The workflow overlay and
PR ref advance remain separate, expected-head guarded connector operations.
This helper and its preparation files must not enter the repair commit.
"""
from __future__ import annotations

import ast
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

BASE = "4f21f97c97c7dc344e026c85900d820006cdb308"
BASE_TREE = "10786b2fa4de0f8cc671d79cfc85e666bb8e5aeb"
PR_REF = "refs/heads/codex/play-busy001c-rendered-20261029"
CANDIDATE_REF = "refs/heads/work/pr304-cleanup-source-20261103"
WORKFLOW = ".github/workflows/play-busy001b-host.yml"
FROZEN = {
    "tools/ci/play_busy001c_process.py": "75903478871309ad3992a7e2866c6ec3b1079c83",
    "tools/ci/run_play_busy001c_render.py": "388cd594d531d9e8cb9b354fcd832ceabfa7f018",
    "godot/tests/play_busy001c_render.gd": "2a89180b4dc9163e296d100487e05a96a0f4f709",
    WORKFLOW: "662e0ced66f546239f4983f38965b79f83fcc1b9",
    "docs/audits/2026-10-29-play-busy001c-rendered-hold.md": "8f8b32a56321b803a9e8aa36a1fa35d9bd987a46",
    "docs/systems/player-control-playground.md": "30376519574f7c511eb2099daa780161fb3834fd",
}
NEW = {
    "tools/ci/test_play_busy001c_windows_cleanup.py": "fd59496b3833b4afa40d0822296c62e3bfcc6601",
    "tools/ci/test_play_busy001c_cleanup_receipt.py": "3f18246d646923504327353722aa0593101d8461",
}
FRAGMENTS = {
    "pr304-cleanup-core.patch": "70b657b07c658a6cbdb12bd533601457e3cd0b27",
    "pr304-cleanup-palette.txt": "e1c573f47f9e89e8f2fe2c0cbe92a739b7e8dab0",
    "pr304-cleanup-controls.yml": "8ed582b7951e3866d15e8a5ea01766c8c777251a",
    "pr304-cleanup-audit.md": "bc176af7621bc1490260bcc091a27561c4382847",
    "pr304-cleanup-canonical.md": "b959751db676df260fcbb34259cbc4f428c00689",
}
REPAIRED_CORE = {
    "tools/ci/play_busy001c_process.py": "e6bb9d8e59f0c139c7268d948658f8eea9fab42d",
    "tools/ci/run_play_busy001c_render.py": "045c362ea802df6760d345b60f50b73f66b94372",
}
HERE = Path(__file__).resolve().parent
OUT = Path(os.environ["RUNNER_TEMP"]) / "pr304-preparation"
PATHS = sorted([*FROZEN, *NEW])


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def git(*arguments, input=None):
    return subprocess.run(["git", *arguments], input=input, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          check=True, timeout=180).stdout.strip()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def replace_once(text, before, after):
    require(text.count(before) == 1, "Replacement anchor is missing or ambiguous: " + repr(before))
    return text.replace(before, after, 1)


def emit(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def verify_checkout():
    require(git("rev-parse", "HEAD") == BASE, "Frozen PR source changed")
    require(git("rev-parse", "HEAD^{tree}") == BASE_TREE, "Frozen source tree changed")
    require(git("remote", "get-url", "origin") in (
        "https://github.com/techrote/cybersand", "https://github.com/techrote/cybersand.git"),
        "Unexpected repository origin")


def apply():
    OUT.mkdir(parents=True, exist_ok=True)
    verify_checkout()
    require(not git("status", "--porcelain"), "Source checkout is not clean")
    for name, expected in FROZEN.items():
        require(blob(Path(name).read_bytes()) == expected, "Original file identity differs: " + name)
    for name, expected in FRAGMENTS.items():
        require(blob((HERE / name).read_bytes()) == expected, "Prepared fragment identity differs: " + name)
    for name, expected in NEW.items():
        require(not Path(name).exists(), "New test already exists: " + name)
        require(blob((HERE / Path(name).name).read_bytes()) == expected, "Prepared test differs: " + name)

    patch = str(HERE / "pr304-cleanup-core.patch")
    git("apply", "--check", patch)
    git("apply", patch)
    for name, expected in REPAIRED_CORE.items():
        require(blob(Path(name).read_bytes()) == expected, "Repaired core does not match tested bundle: " + name)

    path = Path("godot/tests/play_busy001c_render.gd")
    text = path.read_text(encoding="utf-8")
    text = replace_once(text, "\troot.add_child(desktop)\n\tawait process_frame\n",
                        "\troot.add_child(desktop)\n" + (HERE / "pr304-cleanup-palette.txt").read_text(encoding="utf-8") + "\tawait process_frame\n")
    text = replace_once(text, '\tprogress("worker_started")\n',
                        '\tprogress("worker_started", {"palette":startup_palette})\n')
    path.write_text(text, encoding="utf-8")

    path = Path(WORKFLOW)
    text = path.read_text(encoding="utf-8")
    text = replace_once(text, "  workflow_dispatch:\n", "  workflow_dispatch:\n    inputs:\n      full_host:\n        description: \"Explicitly run the original build/host campaign; #304 defaults to controls only\"\n        required: false\n        type: boolean\n        default: false\n")
    guard = "    if: ${{ (github.event_name == 'push' && github.ref_name == 'codex/play-busy001a-pool-20261029') || (github.event_name == 'workflow_dispatch' && inputs.full_host) }}\n"
    for name in ("linux-real-host", "windows-build", "windows-real-host"):
        text = replace_once(text, f"  {name}:\n", f"  {name}:\n" + guard)
    text += (HERE / "pr304-cleanup-controls.yml").read_text(encoding="utf-8")
    path.write_text(text, encoding="utf-8")

    path = Path("docs/audits/2026-10-29-play-busy001c-rendered-hold.md")
    path.write_text(path.read_text(encoding="utf-8") + (HERE / "pr304-cleanup-audit.md").read_text(encoding="utf-8"), encoding="utf-8")
    path = Path("docs/systems/player-control-playground.md")
    text = replace_once(path.read_text(encoding="utf-8"), "last-reviewed: 2026-11-02\n", "last-reviewed: 2026-11-03\n")
    path.write_text(text + (HERE / "pr304-cleanup-canonical.md").read_text(encoding="utf-8"), encoding="utf-8")
    for name in NEW:
        Path(name).write_bytes((HERE / Path(name).name).read_bytes())
    for name in [*REPAIRED_CORE, *NEW]:
        ast.parse(Path(name).read_text(encoding="utf-8"), filename=name)
    git("add", "--", *PATHS)
    require(git("diff", "--cached", "--name-only").splitlines() == PATHS, "Candidate changed-path inventory differs")
    git("diff", "--cached", "--check")
    full_tree = git("write-tree")
    record = {"base": BASE, "base_tree": BASE_TREE, "full_tree": full_tree,
              "scope": "source preparation; no new graphical or Windows qualification",
              "paths": PATHS, "files": {name: {"blob": blob(Path(name).read_bytes()),
                  "sha256": hashlib.sha256(Path(name).read_bytes()).hexdigest(),
                  "bytes": Path(name).stat().st_size} for name in PATHS}}
    emit("prepared.json", record)
    (OUT / "workflow.yml").write_bytes(Path(WORKFLOW).read_bytes())
    with (OUT / "repair.patch").open("wb") as output:
        subprocess.run(["git", "diff", "--cached", "--binary"], stdout=output, check=True, timeout=30)
    subprocess.run(["git", "archive", "--format=tar.gz", "-o", str(OUT / "candidate-eight-paths.tar.gz"), full_tree, "--", *PATHS], check=True, timeout=60)
    print(json.dumps(record, indent=2))


def publish_source_only():
    verify_checkout()
    record = json.loads((OUT / "prepared.json").read_text(encoding="utf-8"))
    require(git("write-tree") == record["full_tree"], "Staged candidate changed during validation")
    require(not git("diff", "--name-only"), "Tracked source changed during validation")
    for name, value in record["files"].items():
        require(blob(Path(name).read_bytes()) == value["blob"], "Candidate bytes changed: " + name)
    remote = git("ls-remote", "origin", PR_REF).split()
    require(remote and remote[0] == BASE, "PR #304 moved; do not publish stale candidate")
    require(not git("ls-remote", "origin", CANDIDATE_REF), "Candidate branch already exists; refuse overwrite")
    # Do not ask GITHUB_TOKEN to change a workflow. The connector overlays this
    # one already-validated workflow blob later and checks the complete tree.
    git("update-index", "--cacheinfo", "100644", FROZEN[WORKFLOW], WORKFLOW)
    source_tree = git("write-tree")
    candidate = git("-c", "user.name=github-actions[bot]", "-c",
                    "user.email=41898282+github-actions[bot]@users.noreply.github.com",
                    "commit-tree", source_tree, "-p", BASE,
                    input="test(play): prepare Windows cleanup source objects without workflow publication\n\nIsolated seven-path preparation only. PR #304 and main remain unchanged. The final eight-path tree requires the separately validated controls-only workflow overlay. No graphical acceptance is claimed.\n")
    git("push", "--porcelain", "origin", candidate + ":" + CANDIDATE_REF)
    record.update(candidate_commit=candidate, source_tree=source_tree,
                  candidate_ref=CANDIDATE_REF, workflow_overlay_required=True,
                  pr304_advanced=False, main_modified=False)
    emit("publication.json", record)
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    if sys.argv[1:] == ["apply"]:
        apply()
    elif sys.argv[1:] == ["publish-source-only"]:
        publish_source_only()
    else:
        raise SystemExit("Expected apply or publish-source-only")
