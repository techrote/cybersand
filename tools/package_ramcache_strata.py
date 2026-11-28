#!/usr/bin/env python3
"""Seal, verify and execute the integrated portable Windows Workbench.

Package identity is read independently from Git and every original platform
campaign. Cold CMD observation reuses the retained Strata process observer but
has a separate reader bound to this actual application, never its frozen donor.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import ntpath
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/ci"))
import ramcache_strata_qualification as q
import strata3_cold_launcher as cold
import package_strata2_workbench as base
import ramcache_strata_lab_package as lab
from package_explore001_candidate import verify_vc_runtime
from package_wave_flow_candidate import omit_regenerated_imports, REGENERATED_RAPIER_IMPORTS
from package_workbench_landscape_review import DEPENDENCIES

require, sha, write_json = q.require, q.sha, q.write_json
MANIFEST = "evaluation-manifest.json"
MATERIALIZED = {
    "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
    "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
    "godot/tools/gentek_reciprocal.exe",
}
# Full accepted Lab source/history alone measured 1,049,929,696 bytes on e135.
# Bound the complete offline-tool layout at 4 GiB while retaining 1 GiB/member;
# exact per-component and expanded bytes are recorded from the actual payload.
MAXIMUM_UNCOMPRESSED_BYTES = 4 * 1024**3
SOURCE_BOOTSTRAP_FILES = {"source/godot/.godot/" + name for name in
    (".gdignore", "extension_list.cfg", "global_script_class_cache.cfg")}

# Six actual source lanes passed on N. Its later archive extraction failed before
# Godot because an empty Git refs directory was absent from the files-only ZIP.
# Reuse is fixed to this one immutable campaign and these packaging-only paths;
# it does not turn that failed overall run into a successful release or relabel
# any original source receipt. Actual extracted tests still execute current HEAD.
QUALIFIED_SOURCE = "d414774ddc582cbc03d74e119937665368dc3476"
QUALIFIED_TREE = "7b947640ef8133b8af627782edc15464f6b3e383"
QUALIFIED_RUN = 46105901845
QUALIFIED_ATTEMPT = 1
QUALIFIED_FAILED_PACKAGE_JOB = 140865019088
QUALIFIED_INPUT_COUNT = 1603
QUALIFIED_ASSET_COUNT = 6
REUSE_ALLOWED_PATHS = frozenset({
    "tools/package_ramcache_strata.py", "tools/ci/test_ramcache_strata_qualification.py",
    "tools/ci/ramcache_strata_lab_package.py", "tools/ci/test_ramcache_strata_lab_package.py",
    "tools/ci/ramcache-strata-integration-request.json",
    ".github/workflows/ramcache-strata-integration.yml",
    "docs/operations/ramcache-strata-integration.md",
})
QUALIFIED_CAMPAIGNS = {
    "linux-ramcache": (140858585142, 15247602809, 18344923,
        "7aeb965a34348729856e158a781830310f047e22d5ff9a623e85baf39929be9b",
        "ec65e645ca1f104cd423225428e07f9832d12d7aa33aecd1fb1c0cb84faf8ef7"),
    "linux-strata": (140858585127, 15248076054, 49537048,
        "a1eb99b5778bc66c038b39e64ccb2d5d4b588b5be33e52d30ccde7e204c20d07",
        "99691b124064a0db92652a867dbe1b7d3d3c4aaaca01bce16226c943e6b81af9"),
    "linux-shared": (140858585134, 15247967633, 29757783,
        "2bba66f32dc0888800148a1c44418787c6ef344932d3a06ed5415e07c5567fdb",
        "8ed5b0fa7c29f491fc3f28f4b4211fce4a904f32a5e3194c42b6d5ba258b6d4c"),
    "win32-ramcache": (140858585128, 15248401093, 13206810,
        "98a22a2cdf02c4cb32922a43fc0617b301aac2be1c0876944bdf7b4ad7df95a5",
        "26951cbf375ae141158c4611e77cb7db9cdb6a35f4dbf359a292e62f13fe1480"),
    "win32-strata": (140858585114, 15248406051, 33517211,
        "b8f1a6283c5576061b27185379d197a70f0ba454fbedd16a89e22fbe52d4b247",
        "142419edb21e045b5440050a1dcebf95aa380b70ba555ca2323e43a88a3fc0dd"),
    "win32-shared": (140858585177, 15248312416, 20005499,
        "8741d4e9f035e0ef5189946a30629933301caa6ca15362931f555fb83cffcf8a",
        "a4d6073e68f24b046cd569baa2b4ca35e88c23eb945283468b15587e0fb6a2f0"),
}
QUALIFIED_DEPENDENCIES = (15248128137, 85321005,
    "e067efe59e9eee348759fda823687c1c24d73dd8acaee62a2ebc6f26a465f98f")


def git_entries(commit: str) -> dict:
    entries = {}
    for row in q.custody.git("ls-tree", "-rz", commit).split(b"\0"):
        if row:
            metadata, name = row.split(b"\t", 1)
            entries[name.decode()] = metadata.decode().split()
    return entries


def git_blobs(commit: str, names) -> dict:
    names = sorted(set(names))
    for name in names:
        safe_name(name)
        require("\n" not in name and "\r" not in name, "Unbounded Git input name")
    result = subprocess.run(["git", "-C", str(ROOT), "cat-file", "--batch"],
        input="".join(commit + ":" + name + "\n" for name in names).encode(),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=120)
    stream, blobs = io.BytesIO(result.stdout), {}
    for name in names:
        header = stream.readline().decode().strip().split()
        require(len(header) == 3 and header[1] == "blob" and header[2].isdigit(),
                "Missing immutable Git blob: " + name)
        data = stream.read(int(header[2]))
        require(len(data) == int(header[2]) and stream.read(1) == b"\n"
                and hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest() == header[0],
                "Git blob readback changed: " + name)
        blobs[name] = data
    require(not stream.read(), "Unexpected immutable Git blob output")
    return blobs


def qualification_reuse_proof(source: dict | None = None) -> dict:
    source = q.identity() if source is None else source
    require(source.get("source_commit") == q.custody.git("rev-parse", "HEAD").decode().strip()
            and source.get("source_tree") == q.custody.git("rev-parse", "HEAD^{tree}").decode().strip()
            and source.get("local_delta") == [], "Reuse target is not exact current committed source")
    require(q.custody.git("rev-parse", QUALIFIED_SOURCE + "^{tree}").decode().strip() == QUALIFIED_TREE,
            "Original qualified source tree changed")
    q.custody.git("merge-base", "--is-ancestor", QUALIFIED_SOURCE, "HEAD")
    before, after = git_entries(QUALIFIED_SOURCE), git_entries("HEAD")
    changed = sorted(name for name in set(before) | set(after) if before.get(name) != after.get(name))
    require(set(changed) <= REUSE_ALLOWED_PATHS, "Source reuse includes non-packaging changes: " + ", ".join(changed))
    require(all(name in before and name in after and before[name][:2] == after[name][:2]
                and before[name][0] in ("100644", "100755") and before[name][1] == "blob" for name in changed),
            "Packaging reuse added, removed, linked or changed the mode of a source path")
    inputs, assets = source.get("source_inputs_sha256", {}), source.get("source_assets_sha256", {})
    require(len(inputs) == QUALIFIED_INPUT_COUNT and len(assets) == QUALIFIED_ASSET_COUNT,
            "Qualified source input inventory changed")
    old = git_blobs(QUALIFIED_SOURCE, {*inputs, *assets, *changed})
    current = git_blobs("HEAD", {*inputs, *assets, *changed})
    require(inputs == {name: hashlib.sha256(q.normalized_text(current[name])).hexdigest() for name in inputs}
            and assets == {name: hashlib.sha256(current[name]).hexdigest() for name in assets},
            "Current source ledger differs from immutable Git inputs")
    original = {**source, "source_commit": QUALIFIED_SOURCE, "source_tree": QUALIFIED_TREE,
                "source_inputs_sha256": {name: hashlib.sha256(q.normalized_text(old[name])).hexdigest() for name in inputs},
                "source_assets_sha256": {name: hashlib.sha256(old[name]).hexdigest() for name in assets}}
    require(original["source_assets_sha256"] == assets
            and all(original["source_inputs_sha256"][name] == inputs[name] for name in inputs if name not in REUSE_ALLOWED_PATHS),
            "Functional qualification input or artwork changed")
    trees = {}
    for name in ("godot", "native", "examples", "materials", "third_party"):
        prior = q.custody.git("rev-parse", QUALIFIED_SOURCE + ":" + name).decode().strip()
        require(prior == q.custody.git("rev-parse", "HEAD:" + name).decode().strip(),
                "Protected application tree changed: " + name)
        trees[name] = prior
    return {"schema": "ramcache-strata-packaging-source-reuse-v1", "source_commit": source["source_commit"],
            "source_tree": source["source_tree"], "qualification_source_identity": original,
            "original_run_id": QUALIFIED_RUN, "original_run_attempt": QUALIFIED_ATTEMPT,
            "original_run_conclusion": "failure", "original_source_lanes": "all six passed",
            "allowed_packaging_paths": sorted(REUSE_ALLOWED_PATHS), "protected_tree_identities": trees,
            "changed_paths": {name: {"before_blob": before[name][2], "after_blob": after[name][2],
                "before_sha256": hashlib.sha256(old[name]).hexdigest(),
                "after_sha256": hashlib.sha256(current[name]).hexdigest()} for name in changed},
            "native_reuse": q.native_reuse(), "functional_reader_unchanged": True,
            "fresh_current_installed_required": ["ordinary CMD first", "persistent CMD normal WM_CLOSE and reopen",
                "ramcache", "strata", "lab", "bundled native compilation", "loaded modules", "payload hashes"],
            "scope": "Original N execution receipts retained; only explicit packaging metadata/tools/tests/workflow/runbook changes apply to the current package. No source receipt is relabelled."}


def qualified_artifact_pins() -> dict:
    pins = {"ramcache-strata-" + name + "-" + QUALIFIED_SOURCE + "-1":
            {"id": row[1], "size_in_bytes": row[2], "digest": "sha256:" + row[3]}
            for name, row in QUALIFIED_CAMPAIGNS.items()}
    artifact, size, digest = QUALIFIED_DEPENDENCIES
    pins["ramcache-strata-dependencies-" + QUALIFIED_SOURCE + "-1"] = {
        "id": artifact, "size_in_bytes": size, "digest": "sha256:" + digest}
    return pins


def authenticate_qualification_metadata(metadata: dict) -> None:
    run, jobs, artifacts = (metadata.get(key, {}) for key in ("run", "jobs", "artifacts"))
    require(run.get("id") == QUALIFIED_RUN and run.get("head_sha") == QUALIFIED_SOURCE
            and run.get("run_attempt") == QUALIFIED_ATTEMPT and run.get("event") == "push"
            and run.get("head_branch") == "main" and run.get("status") == "completed"
            and run.get("conclusion") == "failure", "Original failed overall workflow identity changed")
    for label, pin in QUALIFIED_CAMPAIGNS.items():
        platform, mode = label.split("-")
        name = ("Windows" if platform == "win32" else "Linux") + " graphical " + mode
        matches = [row for row in jobs.get("jobs", []) if row.get("id") == pin[0] or row.get("name") == name]
        require(len(matches) == 1, "Missing/duplicate original source lane: " + label)
        row = matches[0]
        require(row.get("id") == pin[0] and row.get("run_id") == QUALIFIED_RUN and row.get("run_attempt") == QUALIFIED_ATTEMPT
                and row.get("head_sha") == QUALIFIED_SOURCE and row.get("status") == "completed"
                and row.get("conclusion") == "success"
                and row.get("name") == name,
                "Original source lane did not pass at N: " + label)
    failed = [row for row in jobs.get("jobs", []) if row.get("id") == QUALIFIED_FAILED_PACKAGE_JOB]
    require(len(failed) == 1 and failed[0].get("status") == "completed" and failed[0].get("conclusion") == "failure"
            and failed[0].get("run_id") == QUALIFIED_RUN and failed[0].get("head_sha") == QUALIFIED_SOURCE
            and failed[0].get("run_attempt") == QUALIFIED_ATTEMPT,
            "Original package failure was omitted or relabelled")
    for name, pin in qualified_artifact_pins().items():
        matches = [row for row in artifacts.get("artifacts", []) if row.get("id") == pin["id"] or row.get("name") == name]
        require(len(matches) == 1, "Missing/duplicate original artifact: " + name)
        row = matches[0]
        require(row.get("name") == name and all(row.get(key) == value for key, value in pin.items())
                and row.get("expired") is False and row.get("workflow_run", {}).get("id") == QUALIFIED_RUN
                and row["workflow_run"].get("head_sha") == QUALIFIED_SOURCE,
                "Original artifact identity differs from its immutable pin: " + name)


def reuse_admission(args) -> dict:
    proof = qualification_reuse_proof()
    if args.metadata is not None:
        metadata = q.read(args.metadata)
    else:
        token = os.environ.get("CYBERSAND_QUALIFICATION_TOKEN", "")
        require(token, "Read-only Actions token required to authenticate original artifact metadata")
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, headers, newurl):
                return None
        opener = urllib.request.build_opener(NoRedirect)
        metadata = {}
        for key, suffix in (("run", ""), ("jobs", "/attempts/1/jobs?per_page=100"),
                            ("artifacts", "/artifacts?per_page=100")):
            request = urllib.request.Request("https://api.github.com/repos/techrote/cybersand/actions/runs/" +
                str(QUALIFIED_RUN) + suffix, headers={"Authorization": "Bearer " + token,
                    "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"})
            with opener.open(request, timeout=60) as response:
                data = response.read(4 * 1024**2 + 1)
            require(len(data) <= 4 * 1024**2, "Unbounded original workflow metadata")
            metadata[key] = json.loads(data)
    authenticate_qualification_metadata(metadata)
    result = {"schema": "ramcache-strata-reuse-admission-v1", "status": "passed",
              "source_commit": proof["source_commit"], "source_tree": proof["source_tree"],
              "proof": proof, "original_workflow_metadata": metadata}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    write_json(args.output, result)
    return result


def validate_qualified_summary(path: Path, label: str, source: dict) -> dict:
    require(label in QUALIFIED_CAMPAIGNS and sha(path) == QUALIFIED_CAMPAIGNS[label][4],
            "Original qualification summary changed: " + label)
    report = q.read(path)
    platform, mode = label.split("-")
    require(report.get("source_identity") == source and source.get("source_commit") == QUALIFIED_SOURCE
            and report.get("run_id") == str(QUALIFIED_RUN) and report.get("run_attempt") == str(QUALIFIED_ATTEMPT)
            and report.get("platform") == platform and report.get("mode") == mode
            and report.get("status") == "passed" and report.get("completed") is True
            and report.get("input_custody") == report.get("independent_verification") == "passed",
            "Original source receipt is incomplete, cross-source or relabelled: " + label)
    return report


def replay_qualified_campaigns(evidence: Path, proof: dict) -> tuple[dict, dict]:
    source = proof["qualification_source_identity"]
    reports, executions = {}, {}
    environment = lab.lab.clean_git_environment()
    environment.update(GIT_LFS_SKIP_SMUDGE="1", PYTHONDONTWRITEBYTECODE="1")
    for key in ("PYTHONHOME", "PYTHONPATH", "PYTHONSTARTUP"):
        environment.pop(key, None)
    # The original Strata reader resolves nested optics.identity() from its own
    # checkout. Execute that unchanged reader at N; never override its identity.
    with tempfile.TemporaryDirectory(prefix="ramcache-strata-qualified-source-") as temporary:
        historical = Path(temporary) / "source"
        subprocess.run(["git", "-C", str(ROOT), "-c", "core.autocrlf=false", "worktree", "add", "--detach",
            str(historical), QUALIFIED_SOURCE], env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            check=True, timeout=300)
        try:
            reader = historical / "tools/ci/ramcache_strata_qualification.py"
            reader_hash = sha(reader)
            require(reader_hash == source["source_inputs_sha256"]["tools/ci/ramcache_strata_qualification.py"]
                    and reader_hash == sha(ROOT / "tools/ci/ramcache_strata_qualification.py"),
                    "Original functional reader changed")
            for label in QUALIFIED_CAMPAIGNS:
                folder = (evidence / label).resolve(strict=True)
                path = folder / "integration.json"
                validate_qualified_summary(path, label, source)
                command = [sys.executable, "-B", str(reader), "verify", str(folder)]
                started = time.monotonic()
                child = subprocess.run(command, cwd=historical, env=environment, stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE, timeout=300)
                require(child.returncode == 0, "Unchanged N reader rejected " + label + ": " +
                        child.stderr.decode("utf-8", errors="replace")[-8192:])
                stdout = child.stdout.decode("utf-8")
                require(not child.stderr and json.loads(stdout) == {"status": "passed", "source": QUALIFIED_SOURCE},
                        "Original reader context/terminal differs: " + label)
                validate_qualified_summary(path, label, source)
                reports[label] = path
                executions[label] = {"command": command, "reader_sha256": reader_hash,
                    "reader_git_head": QUALIFIED_SOURCE, "reader_git_tree": QUALIFIED_TREE,
                    "original_summary_sha256": sha(path), "exit_code": 0, "stdout": stdout,
                    "stderr": "", "seconds": round(time.monotonic() - started, 3), "timeout_seconds": 300}
        finally:
            subprocess.run(["git", "-C", str(ROOT), "worktree", "remove", str(historical)],
                env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=120)
    return reports, {"schema": "ramcache-strata-original-source-replay-v1", "status": "passed",
        "execution_source": QUALIFIED_SOURCE, "execution_tree": QUALIFIED_TREE,
        "applicability_target": proof["source_commit"], "source_workflow_run": QUALIFIED_RUN,
        "source_workflow_attempt": QUALIFIED_ATTEMPT, "source_workflow_conclusion": "failure",
        "executions": executions, "source_identity_override_used": False,
        "scope": "Unmodified N readers replayed all original functional evidence at N; no Godot rerun or receipt relabelling. Actual current-source extracted qualification is separate and mandatory."}


def validate_qualified_replay(record: dict, proof: dict) -> None:
    require(record.get("schema") == "ramcache-strata-original-source-replay-v1" and record.get("status") == "passed"
            and record.get("execution_source") == QUALIFIED_SOURCE and record.get("execution_tree") == QUALIFIED_TREE
            and record.get("applicability_target") == proof["source_commit"]
            and record.get("source_workflow_run") == QUALIFIED_RUN and record.get("source_workflow_attempt") == 1
            and record.get("source_workflow_conclusion") == "failure" and record.get("source_identity_override_used") is False
            and set(record.get("executions", {})) == set(QUALIFIED_CAMPAIGNS), "Incomplete original-source replay")
    reader_hash = proof["qualification_source_identity"]["source_inputs_sha256"]["tools/ci/ramcache_strata_qualification.py"]
    for label, row in record["executions"].items():
        command = row.get("command", [])
        require(isinstance(command, list) and len(command) == 5 and command[1] == "-B" and command[3] == "verify"
                and command[2].replace("\\", "/").endswith("/source/tools/ci/ramcache_strata_qualification.py")
                and command[4].replace("\\", "/").endswith("/" + label)
                and row.get("reader_git_head") == QUALIFIED_SOURCE and row.get("reader_git_tree") == QUALIFIED_TREE
                and row.get("reader_sha256") == reader_hash and row.get("original_summary_sha256") == QUALIFIED_CAMPAIGNS[label][4]
                and row.get("exit_code") == 0 and row.get("stderr") == "" and row.get("timeout_seconds") == 300
                and type(row.get("seconds")) in (int, float) and math.isfinite(row["seconds"]) and 0 <= row["seconds"] <= 300
                and json.loads(row.get("stdout", "")) == {"status": "passed", "source": QUALIFIED_SOURCE},
                "Original reader execution is missing, changed or cross-source: " + label)


def payload(folder: Path) -> dict:
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob("*"))
            if p.is_file() and p != folder / MANIFEST}


def safe_name(name: str) -> str:
    cold.relative(name)
    return name


def launcher_text(source: dict) -> str:
    ordinary = base.launcher_text(source)
    require(ordinary.count('%~dp0godot"') == 2 and ordinary.count('cd /d "%~dp0"\n') == 1,
            "Established portable project/import sequence changed")
    rows = ['set "PYTHONHOME="', 'set "PYTHONPATH="', 'set "PYTHONSTARTUP="',
            'set "PYTHONNOUSERSITE=1"', 'set "PYTHONUTF8=1"']
    rows += ['set "' + key + '="' for key in sorted(lab.lab.GIT_LOCATION)]
    rows += ['set "GIT_CONFIG_NOSYSTEM=1"', 'set "GIT_CONFIG_GLOBAL=NUL"', 'set "GIT_LFS_SKIP_SMUDGE=1"',
             'set "PATH=%~dp0dependencies\\python;%~dp0dependencies\\git\\cmd;%~dp0dependencies\\git\\ucrt64\\bin;%~dp0dependencies\\git\\mingw64\\bin;%~dp0dependencies\\cxx\\bin;%SystemRoot%\\System32;%SystemRoot%"',
             'set "CYBERSAND_LAB_CXX=%~dp0dependencies\\cxx\\bin\\g++.exe"']
    ordinary = ordinary.replace('cd /d "%~dp0"\n', 'cd /d "%~dp0"\n' + "\n".join(rows) + "\n")
    return ordinary.replace('%~dp0godot"', '%~dp0source\\godot"')


def persistent_launcher(source: dict) -> str:
    ordinary = launcher_text(source)
    require(ordinary.count("-- --workbench\n") == 1, "Ordinary portable host argument is ambiguous")
    # Both routes use the application's same default user:// profile. An
    # explicit shortcut-only profile would split the owner's durable areas.
    return ordinary.replace("-- --workbench\n", "-- --persistent-areas\n")


def materialized_identity(name: str) -> dict:
    raw = q.custody.git("show", "HEAD:" + name).decode()
    match = re.fullmatch(r"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", raw)
    require(match is not None, "Runtime is not an exact committed LFS identity")
    return {"sha256": match[1], "size": int(match[2])}


def owner_text(source: dict) -> str:
    return f'''# CyberSand — integrated RAMCACHE and Strata Theatre 003

Application: `{source["source_commit"]}`

Git tree: `{source["source_tree"]}`

Extract this entire ZIP into a short writable folder such as **C:\\CyberSand**,
then double-click **Open Workbench.cmd**. The full source history is included; a short
installation path avoids Windows Explorer path-length limits.
Godot, the source-matched CyberSand extension, Rapier and the SWARM generator are included.
The complete source and compatibility history are in `source`; bundled Python, Git and
MinGW in `dependencies` support Materials Lab authoring and native comparisons offline.
The first opening imports the project and may take longer. Saved profiles and settings
stay in this package's `userdata` folder. Keep that folder when moving your installation.
Use **Verify Package.cmd** to check the original payload hashes with Windows PowerShell.

## Ordinary Workbench and defaults

The normal launcher opens the ordinary Workbench. Strata starts disabled and **Classic**
is the optical default. Classic does not allocate enhanced-optics shader materials.
Persistent-area operation is a separate opt-in host. Existing ordinary authoring,
actors, Water, AMBIENT, Goblin, Materials Lab/Audition, Art, Architecture, Gentek and
SWARM remain available through their established controls. ObjectShard M4 is excluded.

## Persistent areas and RAMCACHE

Double-click **Open Persistent Areas.cmd**, or press **F2** and select **Persistent
areas — experimental three-area Workbench, saved dynamics and bounded catch-up**.
Both routes reopen the same package-local persistent-area profile.
Open **RAM cache…**. Initial settings are 512 MiB, strict durability, background saving
on and prefetch off. To use the owner-accepted optional path, select **Allow travel
before disk saving finishes**, then **Apply cache settings**. For hover preparation,
also select **Prepare likely destinations before travel** and **Apply cache settings**.
Hover a destination to request preparation; travel to it using the area's button. Use **Save all areas**
and wait for durable acknowledgement before closing. Complete shutdown
and reopening retain authored edits and evolved state. Deferred travel remains optional.

The accepted Waterworks delay remains: roughly 3.2 seconds on the owner's previous
Windows/TITAN evaluation, even while paused. This package does not replace catch-up
scheduling. HOT preparation remains bounded to 2 ticks or 5 ms per pass; WARM/COLD to
32 ticks or 100 ms, with automatic prediction considered about once a second.

## Strata and the owner's reproducible preference

In the ordinary Workbench toolbar, open **Strata Theatre…**, then **Scenes**.
Select **Underworks / Reactor Service** and click **Load selected example…**.
In **Optics**, select **Diorama** in the profile dropdown under **Enable optical
processing**. Scroll to **Per-plane composition**, select **Rear architecture**,
and set **Optical depth** to **1.3**. This is a reproducible artistic preference,
not the global default. **Save start** stores authored composition/optics; named
presets store reusable optical configurations. Temporary bypass, Show physical Play,
wipe and inspection focus stay separate. Application quality is a separate preference.

Strata and persistent-area hosting are deliberately separate. Trying Strata in a
persistent-area profile visibly refuses without allocating another World or changing
the current area. Return to the ordinary Workbench to use layered authoring.

## Qualification and accepted limits

The owner accepted the two preceding evaluator builds on Windows 11/NVIDIA TITAN RTX.
The unchanged application passed six original Linux/Windows source campaigns at
`{QUALIFIED_SOURCE}` in run `{QUALIFIED_RUN}`. Their original identities are retained;
that run's later failed packaging check remains recorded. This packaging successor
has a separately verified change boundary and fresh extracted-Windows qualification.
It has not been physically retested on the owner's GPU.

Optional enhanced optics retain their documented cost. The owner's 90% Classic-speed
gate waiver applies only to optional profiles. Original extracted Strata measurements
remain: Deep Focus 80.59%, Architectural 78.26%, Gameplay Clarity 75.68%, Diorama High 73.49%.
Those are historical measurements, not new performance results for this archive.
Classic stays default; correctness, source identity and regression gates are not waived.
Bright-daylight readability and camera rotation retain their previous qualification limits.
Optical actor reveal uses at most eight actor rectangles and scans the first 64
published body parts. Ordinary rendering, labels and physics retain their accepted
capacity; actors outside this bound do not gain the optional assistance.

`evaluation-manifest.json` records the application, original native build source,
exact runtime hashes, six source-campaign identities, package input blobs and every
payload hash. `qualification` contains the source-campaign summaries; full original
execution evidence is retained in the linked workflow artifacts.
The complete combined operating guide is `source/docs/operations/ramcache-strata-integration.md`.
'''


VERIFY_PS1 = r'''$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $root 'evaluation-manifest.json') -Raw | ConvertFrom-Json
if ($manifest.schema -ne 'ramcache-strata-workbench-evaluation-v1') { throw 'Wrong evaluator manifest' }
$count = 0
foreach ($property in $manifest.files_sha256.PSObject.Properties) {
    $name = $property.Name
    if ($name -match '(^/|\\|(^|/)\.\.(/|$)|:)' -or !$name) { throw 'Unsafe manifest path' }
    $path = Join-Path $root $name
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Missing payload: ' + $name) }
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($path)
        $actual = [System.BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        $hasher.Dispose()
    }
    if ($actual -ne $property.Value) {
        throw ('Changed payload: ' + $name)
    }
    $count += 1
}
if ($count -lt 100) { throw 'Incomplete payload inventory' }
Write-Host ('Verified ' + $count + ' original payload files. Application ' + $manifest.source_commit)
'''
VERIFY_CMD = '@echo off\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Verify Package.ps1"\r\npause\r\n'


def windows_powershell_environment(environment: dict[str, str]) -> dict[str, str]:
    # A Python child of pwsh inherits PS7 module paths. Windows PowerShell must
    # reconstruct its own defaults so the unchanged module observer can load
    # its built-in commands; preserve the actual portable application PATH.
    return {key: value for key, value in environment.items() if key.upper() != "PSMODULEPATH"}


def verify(folder: Path, *, pristine=False) -> dict:
    folder = folder.resolve(strict=True)
    record = q.read(folder / MANIFEST)
    source = q.identity()
    runtime = q.strata.retained_runtime_manifest("win32")
    require(record.get("schema") == "ramcache-strata-workbench-evaluation-v1"
            and record.get("source_identity") == source
            and record.get("source_commit") == source["source_commit"] and record.get("source_tree") == source["source_tree"]
            and record.get("runtime") == runtime and record.get("native_reuse") == q.native_reuse()
            and record.get("classic_default") is True and record.get("objectshard_m4_included") is False,
            "Evaluator source/runtime/default identity differs from qualified application")
    materialized = {name: materialized_identity(name) for name in MATERIALIZED}
    require(record.get("materialized_lfs") == materialized
            and record.get("regenerated_imports_sha256") == REGENERATED_RAPIER_IMPORTS,
            "Package native-pointer or regenerated-import inventory changed")
    lab.verify_source(folder / "source", record.get("source_repository", {}),
        expected_source=source["source_commit"], expected_tree=source["source_tree"],
        materialized_lfs=materialized, omitted_files=REGENERATED_RAPIER_IMPORTS,
        git_executable=folder / "dependencies/git/cmd/git.exe" if sys.platform == "win32" else None)
    lab.verify_dependencies(folder / "dependencies", record.get("offline_authoring_dependencies", {}),
                            execute=sys.platform == "win32")
    names = record.get("files_sha256")
    require(isinstance(names, dict) and names and len(names) == len({n.casefold() for n in names}),
            "Missing/ambiguous payload inventory")
    for name, digest in names.items():
        path = folder / safe_name(name)
        require(path.is_file() and not path.is_symlink() and sha(path) == digest, "Changed/missing payload: " + name)
    q.custody.project_identity(folder / "source/godot", source, runtime)
    q.strata.project_assets_identity(folder / "source/godot", source)
    require((folder / "Open Workbench.cmd").read_text(encoding="utf-8") == launcher_text(source),
            "Shipped ordinary launcher changed")
    require((folder / "Open Persistent Areas.cmd").read_text(encoding="utf-8") == persistent_launcher(source),
            "Shipped persistent-area launcher differs from the established source contract")
    require((folder / "Verify Package.ps1").read_text(encoding="utf-8") == VERIFY_PS1
            and (folder / "Verify Package.cmd").read_bytes() == VERIFY_CMD.encode(), "Payload verifier changed")
    require((folder / "READ-ME.md").read_text(encoding="utf-8") == owner_text(source), "Owner guidance differs from source")
    for name, digest in DEPENDENCIES.items():
        require(names.get(name) == digest, "Portable dependency pin changed: " + name)
    verify_vc_runtime(folder)
    require(names.get(cold.GUI) == q.strata.GODOT_GUI_SHA256 and names.get(cold.CONSOLE) == q.strata.GODOT_SHA256["win32"],
            "Portable Godot identity changed")
    required = {*{"source/" + name for name in MATERIALIZED}, "Open Workbench.cmd", "Open Persistent Areas.cmd", "Verify Package.cmd", "Verify Package.ps1", "READ-ME.md",
                "source/godot/scripts/persistent_area_cache.gd", "source/godot/scripts/depth/workbench_strata_controller.gd",
                "source/godot/scripts/depth/workbench_strata_optics_panel.gd", "source/godot/shaders/strata_optical_plane.gdshader",
                "source/tools/material_catalogue/lab.py", "dependencies/python/python.exe",
                "dependencies/git/cmd/git.exe", "dependencies/cxx/bin/g++.exe"}
    require(required <= set(names), "Incomplete integrated owner application")
    proof = qualification_reuse_proof(source)
    require(record.get("qualification_source_identity") == proof["qualification_source_identity"]
            and record.get("qualification_reuse") == proof,
            "Source qualification was relabelled or its packaging-only applicability changed")
    metadata_path = folder / "qualification/original-run-metadata.json"
    replay_path = folder / "qualification/original-source-replay.json"
    require(sha(metadata_path) == record.get("qualification_metadata_sha256")
            and sha(replay_path) == record.get("qualification_replay_sha256"),
            "Original workflow metadata or strict reader replay changed")
    authenticate_qualification_metadata(q.read(metadata_path))
    validate_qualified_replay(q.read(replay_path), proof)
    summaries = record.get("qualification", {})
    require(set(summaries) == {platform + "-" + mode for platform in ("linux", "win32") for mode in q.MODES},
            "Six required source campaigns missing")
    for name, digest in summaries.items():
        path = folder / "qualification" / (name + ".json")
        validate_qualified_summary(path, name, proof["qualification_source_identity"])
        require(sha(path) == digest, "Packaged original source campaign changed")
    components = {component: sum((folder / name).stat().st_size for name in names
                                if name.startswith(component + "/"))
                  for component in ("source", "dependencies", "qualification")}
    components["root_files"] = sum((folder / name).stat().st_size for name in names if "/" not in name)
    require(record.get("component_bytes_before_manifest") == components,
            "Original package component sizes differ from staged inventory")
    if pristine:
        require(payload(folder) == names, "Pristine archive has extra/missing files")
    return record


def build(args):
    admitted = q.admission()
    source = admitted["source_identity"]
    proof = qualification_reuse_proof(source)
    reuse = q.read(args.qualification_admission)
    require(reuse.get("schema") == "ramcache-strata-reuse-admission-v1" and reuse.get("status") == "passed"
            and reuse.get("source_commit") == source["source_commit"]
            and reuse.get("source_tree") == source["source_tree"] and reuse.get("proof") == proof,
            "Packaging-only source evidence reuse was not admitted for this exact target")
    authenticate_qualification_metadata(reuse.get("original_workflow_metadata", {}))
    runtime = q.custody.windows.verify_retained_runtime(ROOT)
    output = args.output.resolve()
    require(not output.exists(), "Refusing to overwrite evaluator output")
    reports, replay = replay_qualified_campaigns(args.evidence, proof)
    validate_qualified_replay(replay, proof)
    dependencies = args.dependencies.resolve(strict=True)
    for name, digest in DEPENDENCIES.items():
        require(sha(dependencies / name) == digest, "Portable dependency mismatch: " + name)
    verify_vc_runtime(dependencies)
    materialized = {name: materialized_identity(name) for name in MATERIALIZED}
    for name, expected in materialized.items():
        require((ROOT / name).stat().st_size == expected["size"] and sha(ROOT / name) == expected["sha256"],
                "Required LFS payload not materialized: " + name)
    output.mkdir(parents=True)
    offline_dependencies = lab.stage_dependencies(output / "dependencies")
    source_repository = lab.stage_source(ROOT, source["source_commit"], output / "source")
    for name in MATERIALIZED:
        shutil.copyfile(ROOT / name, output / "source" / name)
    # The full source includes the canonical examples/worldgen recipes. Duplicating
    # them under godot would create an unnecessary, separately mutable discovery root.
    omitted = omit_regenerated_imports(output / "source")
    require(omitted == REGENERATED_RAPIER_IMPORTS, "Unexpected regenerated import omission")
    for name in [*DEPENDENCIES, "vcruntime140.dll", "vc-runtime-provenance.json"]:
        shutil.copyfile(dependencies / name, output / name)
    (output / "Open Workbench.cmd").write_text(launcher_text(source), encoding="utf-8", newline="\r\n")
    (output / "Open Persistent Areas.cmd").write_text(persistent_launcher(source), encoding="utf-8", newline="\r\n")
    (output / "Verify Package.cmd").write_bytes(VERIFY_CMD.encode())
    (output / "Verify Package.ps1").write_text(VERIFY_PS1, encoding="utf-8", newline="\n")
    (output / "READ-ME.md").write_text(owner_text(source), encoding="utf-8")
    (output / "qualification").mkdir()
    qualification = {}
    for name, path in reports.items():
        target = output / "qualification" / (name + ".json")
        shutil.copyfile(path, target)
        qualification[name] = sha(target)
    metadata_path = output / "qualification/original-run-metadata.json"
    replay_path = output / "qualification/original-source-replay.json"
    write_json(metadata_path, reuse["original_workflow_metadata"])
    write_json(replay_path, replay)
    component_bytes = {name: sum(p.stat().st_size for p in (output / name).rglob("*") if p.is_file())
                       for name in ("source", "dependencies", "qualification")}
    component_bytes["root_files"] = sum(p.stat().st_size for p in output.iterdir() if p.is_file())
    print("RAMCACHE_STRATA_PAYLOAD_BYTES", json.dumps(component_bytes, sort_keys=True), flush=True)
    record = {"schema": "ramcache-strata-workbench-evaluation-v1", "source_identity": source,
              "source_commit": source["source_commit"], "source_tree": source["source_tree"], "runtime": runtime,
              "native_reuse": admitted["native_reuse"], "classic_default": True, "objectshard_m4_included": False,
              "performance_policy": admitted["performance_policy"], "physical_gpu_acceptance_for_this_archive": False,
              "qualification": qualification, "qualification_source_identity": proof["qualification_source_identity"],
              "qualification_reuse": proof, "qualification_metadata_sha256": sha(metadata_path),
              "qualification_replay_sha256": sha(replay_path),
              "component_bytes_before_manifest": component_bytes, "source_repository": source_repository,
              "materialized_lfs": materialized, "offline_authoring_dependencies": offline_dependencies,
              "regenerated_imports_sha256": omitted, "files_sha256": payload(output),
              "workflow_url": "https://github.com/techrote/cybersand/actions/runs/" + os.environ.get("GITHUB_RUN_ID", ""),
              "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "")}
    write_json(output / MANIFEST, record)
    verify(output, pristine=True)
    total = sum(component_bytes.values()) + (output / MANIFEST).stat().st_size
    require(total <= MAXIMUM_UNCOMPRESSED_BYTES and
            max(path.stat().st_size for path in output.rglob("*") if path.is_file()) <= 1024**3,
            "Measured complete portable payload exceeds registered archive bounds: " +
            json.dumps({"total_bytes": total, "components": component_bytes}, sort_keys=True))
    archive_path = args.archive.resolve()
    require(not archive_path.exists(), "Refusing to overwrite archive")
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in sorted(output.rglob("*")):
            if path.is_file():
                bundle.write(path, path.relative_to(output).as_posix())
    # A successful build must already satisfy the same pristine-file boundary
    # that the independently extracted copy will enforce before any launch.
    inspect_archive(archive_path)
    identity = {"filename": archive_path.name, "bytes": archive_path.stat().st_size, "sha256": sha(archive_path),
                "manifest_sha256": sha(output / MANIFEST), "source_commit": source["source_commit"],
                "source_tree": source["source_tree"], "files": len(record["files_sha256"]), "expanded_bytes": total}
    write_json(archive_path.with_suffix(".identity.json"), identity)
    archive_path.with_suffix(".zip.sha256").write_text(identity["sha256"] + "  " + archive_path.name + "\n")
    require(q.identity() == source, "Source changed during packaging")
    return identity


def inspect_archive(archive: Path) -> dict:
    names, folded, total = {}, set(), 0
    with zipfile.ZipFile(archive) as bundle:
        for item in bundle.infolist():
            name = safe_name(item.orig_filename)
            require(name == item.filename and not item.is_dir() and not item.flag_bits & 1
                    and stat.S_IFMT(item.external_attr >> 16) in (0, stat.S_IFREG), "Unsupported ZIP member")
            require(name.casefold() not in folded, "Duplicate/case-colliding ZIP member")
            folded.add(name.casefold())
            total += item.file_size
            require(total <= MAXIMUM_UNCOMPRESSED_BYTES and item.file_size <= 1024**3, "Archive extraction bound exceeded")
            data = bundle.read(item)
            generated = any(part in ("userdata", ".godot", "__pycache__") for part in PurePosixPath(name).parts)
            require(not generated or name in SOURCE_BOOTSTRAP_FILES and
                    data == q.custody.git("show", "HEAD:" + name.removeprefix("source/")),
                    "Shipped package contains prior generated state or an altered committed bootstrap: " + name)
            names[name] = hashlib.sha256(data).hexdigest()
        manifest = json.loads(bundle.read(MANIFEST))
    require(manifest.get("files_sha256") == {k: v for k, v in names.items() if k != MANIFEST},
            "Actual ZIP and complete payload manifest disagree")
    return names


def validate_launcher_log(text: str, source: str, *, persistent=False) -> dict:
    require(not cold.ERRORS.search(text), "Cold launcher log contains an engine/script error")
    headers = [line for line in text.splitlines() if line.startswith("Godot Engine v")]
    require(headers == ["Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org"] * 2,
            "CMD did not run the pinned importer followed by the ordinary application")
    devices = [line for line in text.splitlines() if line.startswith("OpenGL API ")]
    require(len(devices) == 1 and " - Compatibility - Using Device: " in devices[0], "No ordinary graphical backend")
    if persistent:
        value = json.loads(q.marker(text, "PERSISTENT_AREAS_READY "))
        require(set(value) == {"session", "area", "revision"} and value.get("area") in ("a", "b", "c")
                and re.fullmatch(r"[0-9a-f]{32}", str(value.get("session", "")))
                and type(value.get("revision")) is int and value["revision"] > 0,
                "Actual persistent shortcut did not open its durable three-area profile")
        return {"admission": value, "rendering_backend": devices[0],
                "source_identity_scope": "verified exact launcher and package payload; existing readiness marker"}
    value = json.loads(q.marker(text, "STRATA_WORKBENCH_LAUNCH_ADMITTED "))
    require(set(value) == {"source_revision", "workbench_script", "world_generation", "worker_id", "extent", "strata_enabled"}
            and value["source_revision"] == source and value["workbench_script"] == "res://scripts/shared_workbench.gd"
            and cold.integer(value["world_generation"], 1) and isinstance(value["worker_id"], str)
            and cold.ID.fullmatch(value["worker_id"]) and value["extent"] == [2048, 2048]
            and value["strata_enabled"] is False, "Cold CMD did not admit the actual ordinary native Workbench")
    return {"admission": value, "rendering_backend": devices[0]}


def validate_launcher_execution(process, raw_lifetimes, resources, log, source, *, persistent=False):
    # Independent application-parameterized reader of the retained cold observer's
    # original Win32 handles. No frozen Strata donor identity is overwritten.
    require(process.get("schema") == "strata3-cold-process-v1" and process.get("label") == "launcher"
            and process.get("platform") == "win32" and cold.integer(process.get("pid"), 1)
            and process.get("exit_code") == 0 and process.get("timed_out") is False
            and process.get("failure") is None and process.get("cleanup_errors") == []
            and process.get("timeout_seconds") == 180 and cold.number(process.get("wall_seconds"), 0.001)
            and process["wall_seconds"] <= 190 and " " in process.get("cwd", "")
            and ntpath.basename(process.get("executable", "")).lower() == "cmd.exe"
            and process.get("command") == cold.command_line(process["executable"], process["cwd"], persistent=persistent),
            "Wrong, failed or unbounded actual CMD execution")
    require(raw_lifetimes.get("schema") == "strata3-cold-process-lifetimes-v1", "Wrong lifetime schema")
    rows = raw_lifetimes.get("rows")
    require(isinstance(rows, list) and 5 <= len(rows) <= 128, "Missing complete CMD/Godot population")
    identities = set()
    for row in rows:
        key = (row.get("pid"), row.get("start_id"))
        require(cold.integer(key[0], 1) and cold.integer(key[1], 1) and key not in identities
                and row.get("exited") is True and row.get("exit_code") == 0
                and row.get("creation_filetime_100ns") == key[1]
                and cold.integer(row.get("exit_filetime_100ns"), key[1] + 1)
                and cold.number(row.get("final_cpu_seconds")) and cold.number(row.get("lifetime_seconds"), 0.000001)
                and math.isclose(row["lifetime_seconds"], (row["exit_filetime_100ns"] - key[1]) / 10_000_000, abs_tol=1e-9),
                "Process remains live, failed or lacks held-handle timing")
        identities.add(key)
    roots = [r for r in rows if r["pid"] == process["pid"]]
    require(len(roots) == 1 and cold.normalized(roots[0]["image_path"]) == cold.normalized(process["executable"]),
            "Actual CMD identity missing")
    root = roots[0]
    require(cold.number(process.get("started_unix_seconds"), 1)
            and abs(root["start_id"] / 10_000_000 - 11644473600 - process["started_unix_seconds"]) <= 5
            and root["lifetime_seconds"] <= process["wall_seconds"] + 1, "Process clock outside observed launch")
    consoles = sorted((r for r in rows if cold.normalized(r["image_path"]) ==
                       cold.normalized(ntpath.join(process["cwd"], cold.CONSOLE))), key=lambda r: r["start_id"])
    require(len(consoles) == 2 and all(r["parent_pid"] == root["pid"] for r in consoles)
            and root["start_id"] <= consoles[0]["start_id"] < consoles[0]["exit_filetime_100ns"] <= consoles[1]["start_id"]
            < consoles[1]["exit_filetime_100ns"] <= root["exit_filetime_100ns"], "CMD stages are not ordered shipped engines")
    engines = [r for r in rows if cold.normalized(r["image_path"]) == cold.normalized(ntpath.join(process["cwd"], cold.GUI))]
    require(len(engines) >= 2, "Bundled Godot children not observed")
    for console in consoles:
        children = [r for r in engines if r["parent_pid"] == console["pid"]]
        require(len(children) == 1 and console["start_id"] <= children[0]["start_id"]
                < children[0]["exit_filetime_100ns"] <= console["exit_filetime_100ns"], "Shipped console child identity missing")
    for row in rows:
        if row is root:
            continue
        parents = [p for p in rows if p["pid"] == row["parent_pid"] and p["start_id"] <= row["start_id"] <= p["exit_filetime_100ns"]]
        require(len(parents) == 1 and root["start_id"] <= row["start_id"] < row["exit_filetime_100ns"] <= root["exit_filetime_100ns"],
                "Process escaped the actual launcher tree")
    cold.validate_resources(resources, process, rows)
    result = validate_launcher_log(log, source, persistent=persistent)
    if persistent:
        close = process.get("persistent_close", {})
        ready = cold.persistent_readiness(log)
        application = next(row for row in engines if row["parent_pid"] == consoles[1]["pid"])
        require(isinstance(close, dict) and close.get("schema") == "ramcache-strata-persistent-close-v1"
                and close.get("message") == "WM_CLOSE" and close.get("message_id") == 0x0010
                and cold.integer(close.get("hwnd"), 1) and close.get("visible") is True and close.get("posted") is True
                and close.get("pid") == close.get("window_owner_pid") == application["pid"]
                and close.get("start_id") == application["start_id"]
                and cold.normalized(close.get("image_path", "")) == cold.normalized(application["image_path"])
                and close.get("readiness") == ready["value"] == result["admission"]
                and close.get("readiness_line_sha256") == ready["line_sha256"],
                "Persistent shortcut did not post normal close to its exact ready engine window")
        ready_time, posted_time = close.get("ready_observed_unix_seconds"), close.get("posted_unix_seconds")
        require(cold.number(ready_time, 1) and cold.number(posted_time, 1)
                and application["start_id"] / 10_000_000 - 11644473600 <= ready_time <= posted_time
                <= application["exit_filetime_100ns"] / 10_000_000 - 11644473600,
                "Persistent close/readiness times fall outside the actual engine lifetime")
        result["normal_window_close"] = close
    result.update(console_process_ids=[r["pid"] for r in consoles], engine_process_ids=[r["pid"] for r in engines],
                  cold_import_command_seconds=consoles[0]["lifetime_seconds"],
                  ordinary_workbench_command_seconds=consoles[1]["lifetime_seconds"])
    return result


def read_launcher_evidence(location: Path, source: str, *, persistent=False) -> dict:
    process = q.read(location / "process.json")
    for name, key in (("process.log", "log_sha256"), ("resources.json", "resources_sha256"),
                      ("lifetimes.json", "lifetimes_sha256")):
        require(sha(location / name) == process.get(key), "Original launcher observation changed: " + name)
    return validate_launcher_execution(process, q.read(location / "lifetimes.json"),
        q.read(location / "resources.json"), (location / "process.log").read_text(encoding="utf-8"),
        source, persistent=persistent)


def persistent_container(path: Path, magic: bytes, metadata_limit: int, native_limit: int) -> tuple[bytes, bytes]:
    require(path.is_file() and not path.is_symlink() and 52 <= path.stat().st_size <= 64 * 1024**2,
            "Missing, linked or oversized persistent container")
    data = path.read_bytes()
    require(52 <= len(data) <= 64 * 1024**2 and data[:8] == magic + b"\0", "Unsupported persistent container")
    version, metadata_size, native_size = struct.unpack_from("<III", data, 8)
    require(version == 1 and 1 <= metadata_size <= metadata_limit and native_size <= native_limit
            and len(data) == 52 + metadata_size + native_size
            and hashlib.sha256(data[52:]).digest() == data[20:52],
            "Persistent container lengths, version or checksum differ")
    return data[52:52 + metadata_size], data[52 + metadata_size:]


def read_persistent_profile(profile: Path, native_sha256: str) -> dict:
    metadata, native = persistent_container(profile / "current.cypm", b"CYSPROF", 262144 - 52, 0)
    value = json.loads(metadata)
    require(not native and value.get("version") == 1 and set(value.get("areas", {})) == {"a", "b", "c"}
            and value.get("active_area") in ("a", "b", "c") and value.get("revision", 0) > 0
            and re.fullmatch(r"[0-9a-f]{32}", str(value.get("session_id", "")))
            and value.get("profile_id") == "gen006-three-areas-v1"
            and value.get("compatibility") == "gen006-current-freemass-512-cyps2-v1:" + native_sha256,
            "Shortcut profile lacks the three durable source-matched areas")
    for area, record in value["areas"].items():
        filename = record.get("blob", "")
        require(re.fullmatch("area-" + area + r"-[0-9a-f]{32}\.cypa", filename)
                and record.get("area_id") == area and record.get("extent") == [512, 512]
                and sha(profile / filename) == record.get("sha256"), "Profile references an absent or changed native area")
        _, native = persistent_container(profile / filename, b"CYSAREA", 8 * 1024**2, 32 * 1024**2)
        require(native.startswith(b"CYPS") and hashlib.sha256(native).hexdigest() == record.get("native_sha256"),
                "Actual native checkpoint payload differs from its durable manifest")
    return {"session_id": value["session_id"], "revision": value["revision"], "active_area": value["active_area"],
            "manifest_sha256": sha(profile / "current.cypm"), "native_areas": value["areas"],
            "files_sha256": {p.name: sha(p) for p in profile.iterdir() if p.is_file()}}


def validate_portable_compiler(receipt: dict, installation: str, dependencies: dict, source: str,
                               expected_snapshot: dict) -> None:
    expected = ntpath.join(installation, "dependencies", *dependencies["tools"]["compiler"]["path"].split("/"))
    compiler = dependencies["tools"]["compiler"]
    require(receipt.get("compiler") == ntpath.basename(expected)
            and receipt.get("compiler_version") == compiler["version"].splitlines()[0],
            "Actual Lab compiler version differs from the shipped offline tool")
    for name in ("reference_build", "candidate_build"):
        argv = receipt.get(name, {}).get("argv", [])
        require(isinstance(argv, list) and argv and isinstance(argv[0], str)
                and ntpath.normcase(ntpath.normpath(argv[0])) == ntpath.normcase(ntpath.normpath(expected))
                and q.HEX64.fullmatch(str(receipt[name].get("native_executable_sha256", ""))),
                "Lab compiled native Worlds with an unshipped compiler")
    identity = receipt.get("source_identity", {})
    require(identity == expected_snapshot and identity.get("git_head") == source
            and q.HEX64.fullmatch(str(identity.get("digest", "")))
            and receipt.get("source_identity_after") == identity["digest"]
            and isinstance(identity.get("lf_sha256"), dict) and identity["lf_sha256"],
            "Offline native comparison did not retain exact source custody")


def verify_portable_lab_execution(installation: Path, folder: Path, manifest: dict) -> dict:
    report = q.verify(folder, manifest["source_identity"])
    require(report["mode"] == "lab" and report["platform"] == "win32", "Wrong extracted authoring campaign")
    dependencies = manifest["offline_authoring_dependencies"]
    lab.verify_dependencies(installation / "dependencies", dependencies)
    environment = lab.dependency_environment(installation)
    resolved = {}
    for name, command in (("python", "python"), ("git", "git"), ("compiler", "g++")):
        actual = shutil.which(command, path=environment["PATH"])
        expected = installation / "dependencies" / dependencies["tools"][name]["path"]
        require(actual and Path(actual).resolve() == expected.resolve(),
                "Extracted authoring resolves a developer-machine tool: " + name)
        resolved[name] = {"path": str(expected), "sha256": sha(expected),
                          "version": dependencies["tools"][name]["version"]}
    original = q.validate_marker((folder / "material-lab-author/process.log").read_text(encoding="utf-8"),
                                 "MAT_WB_EVIDENCE ")["candidate_world_receipt"]
    # Run the existing World's exact source snapshot using the shipped Python
    # and Git. This replays its full 113-input inventory/digest independently of
    # the receipt, including native headers, Lab compiler tools and fixtures.
    snapshot_command = [str(installation / "dependencies/python/python.exe"), "-I", "-c",
        "import json,sys;sys.path.insert(0,sys.argv[1]);import world_candidate;print(json.dumps(world_candidate._source_snapshot()[0],sort_keys=True))",
        str(installation / "source/tools/material_catalogue")]
    snapshot = subprocess.run(snapshot_command, cwd=installation / "source", env=environment,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=30)
    require(not snapshot.stderr, "Portable source snapshot emitted unexpected diagnostics")
    snapshot_path = folder.parent / "portable-lab-source-snapshot.json"
    snapshot_path.write_bytes(snapshot.stdout)
    expected_snapshot = json.loads(snapshot.stdout)
    validate_portable_compiler(original, str(installation), dependencies, manifest["source_commit"], expected_snapshot)
    return {"status": "passed", "source_commit": manifest["source_commit"], "resolved_tools": resolved,
            "campaign_sha256": sha(folder / "integration.json"),
            "source_snapshot_sha256": sha(snapshot_path), "source_snapshot_command": snapshot_command,
            "scope": "Actual graphical Make editable copy, compiled native comparison, cancellation, save and fresh reopen using shipped tools"}


def installed(args):
    require(sys.platform == "win32", "Actual shipped CMD qualification requires Windows")
    names = inspect_archive(args.archive)
    destination = args.installation.resolve()
    require(not destination.exists() and " " in str(destination), "Use a new extraction directory containing spaces")
    destination.mkdir(parents=True)
    with zipfile.ZipFile(args.archive) as bundle:
        for name in names:
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with bundle.open(name) as src, target.open("xb") as dst:
                shutil.copyfileobj(src, dst, 1024 * 1024)
    require({p.relative_to(destination).as_posix(): sha(p) for p in destination.rglob("*") if p.is_file()} == names,
            "Pristine extracted bytes differ from actual archive")
    manifest = verify(destination, pristine=True)
    expanded_bytes = sum((destination / name).stat().st_size for name in names)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    # This is deliberately the first Godot invocation against the extracted copy.
    cold.execute_launcher(destination, output / "cold-launch", q.metrics)
    location = output / "cold-launch"
    observation = read_launcher_evidence(location, manifest["source_commit"])
    write_json(output / "cold-launch-verification.json", observation)
    shortcut = []
    for phase in ("first", "reopen"):
        location = output / ("persistent-shortcut-" + phase)
        cold.execute_launcher(destination, location, q.metrics, persistent=True)
        result = read_launcher_evidence(location, manifest["source_commit"], persistent=True)
        profiles = list((destination / "userdata/roaming").glob(
            "Godot/app_userdata/*/persistent-areas/three-areas-v1/current.cypm"))
        require(len(profiles) == 1, "Persistent shortcut did not use the normal package-local default profile")
        retained = location / "original-profile"
        shutil.copytree(profiles[0].parent, retained)
        result["profile"] = read_persistent_profile(retained, manifest["runtime"]["cybersand_runtime"]["sha256"])
        ready, saved = result["admission"], result["profile"]
        require(ready["session"] == saved["session_id"] and ready["area"] == saved["active_area"]
                and ready["revision"] <= saved["revision"], "Shortcut readiness contradicts actual durable profile")
        shortcut.append(result)
    require(shortcut[0]["profile"]["session_id"] == shortcut[1]["profile"]["session_id"]
            and set(shortcut[0]["engine_process_ids"]).isdisjoint(shortcut[1]["engine_process_ids"]),
            "Persistent shortcut did not reopen the same profile through new actual engine processes")
    write_json(output / "persistent-shortcut-verification.json", {"status": "passed", "launches": shortcut,
               "scope": "Actual shipped CMD launch, default profile, readiness-driven normal WM_CLOSE and clean durable reopen; full fault/save fixtures remain separate"})
    environment = lab.dependency_environment(destination)
    previous = dict(os.environ)
    try:
        # Godot's backend subprocesses resolve only the actual shipped authoring
        # tools. The orchestrator is not used as a substitute for those tools.
        os.environ.clear()
        os.environ.update(environment)
        for mode in ("ramcache", "strata", "lab"):
            from types import SimpleNamespace
            code = q.run(SimpleNamespace(mode=mode, godot=destination / cold.CONSOLE,
                         project=destination / "source/godot", output=output / mode))
            require(code == 0, "Actual extracted " + mode + " campaign failed")
        authoring = verify_portable_lab_execution(destination, output / "lab", manifest)
        powershell = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32/WindowsPowerShell/v1.0/powershell.exe"
        command = [str(powershell), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
            str(ROOT / "tools/ci/check_windows_package_modules.ps1"), "-Package", str(destination),
            "-Evidence", str(output / "runtime-modules.json"), "-Manifest", MANIFEST,
            "-ProjectRelative", "source/godot"]
        with (output / "runtime-modules-observer.log").open("w", encoding="utf-8") as log:
            subprocess.run(command, env=windows_powershell_environment(environment), stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=180)
        modules = q.read(output / "runtime-modules.json")
        require(modules.get("status") == "passed" and modules.get("source_commit") == manifest["source_commit"],
                "Actual portable module observer did not pass")
    finally:
        os.environ.clear()
        os.environ.update(previous)
    verify(destination)
    result = {"schema": "ramcache-strata-extracted-evaluator-v1", "status": "passed",
              "source_commit": manifest["source_commit"], "source_tree": manifest["source_tree"],
              "archive": {"filename": args.archive.name, "bytes": args.archive.stat().st_size, "sha256": sha(args.archive),
                          "expanded_bytes": expanded_bytes},
              "manifest_sha256": sha(destination / MANIFEST), "cold_cmd_was_first_engine_invocation": True,
              "cold_launch": observation, "extracted_modes": {m: sha(output / m / "integration.json") for m in ("ramcache", "strata", "lab")},
              "offline_authoring": authoring, "runtime_modules_sha256": sha(output / "runtime-modules.json"),
              "runtime_modules_observer_log_sha256": sha(output / "runtime-modules-observer.log"),
              "runtime_modules_command": command,
              "persistent_shortcut_receipt_sha256": sha(output / "persistent-shortcut-verification.json"),
              "payload_after_execution": "all original manifest files unchanged", "physical_gpu_acceptance": False}
    write_json(output / "extracted-verification.json", result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    reuse = commands.add_parser("reuse-admission")
    reuse.add_argument("--output", type=Path, required=True)
    reuse.add_argument("--metadata", type=Path)
    make = commands.add_parser("build")
    for name in ("dependencies", "evidence", "output", "archive", "qualification-admission"):
        make.add_argument("--" + name, type=Path, required=True)
    check = commands.add_parser("verify")
    check.add_argument("package", type=Path)
    check.add_argument("--pristine", action="store_true")
    execute = commands.add_parser("installed")
    for name in ("archive", "installation", "output"):
        execute.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    result = (reuse_admission(args) if args.command == "reuse-admission" else build(args) if args.command == "build"
              else installed(args) if args.command == "installed" else verify(args.package, pristine=args.pristine))
    print(json.dumps({"status": "passed", "source_commit": result["source_commit"],
                      "archive_sha256": result.get("sha256", result.get("archive", {}).get("sha256"))}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
