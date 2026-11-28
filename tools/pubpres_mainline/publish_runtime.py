#!/usr/bin/env python3
"""Guarded two-platform native publication on the principal Draft branch only.

This is a new mission-owned publisher. It authenticates original Actions jobs
and archive digests, replays native/dependency custody and actual test evidence,
then permits exactly four runtime paths in a normal fast-forward child. It never
merges, changes Draft state, or grants physical acceptance.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import io
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile
import common
import campaign_request as request

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = "techrote/cybersand"
WORKFLOW = ".github/workflows/pubpres-mainline.yml"
FOCUSES = ("frozen", "water", "members", "held-placement", "mainline", "native-owner")
FEATURES = ("ramcache", "strata", "shared")
BUILD_JOBS = {"admission", "runtimes (linux)", "runtimes (windows)", "native (normal)", "native (sanitizers)", "native (ownership)"}
QUALIFICATION_JOBS = {"admission", "source-gates"} | {
    "qualification-" + platform + "-" + focus for platform in ("linux", "windows") for focus in FOCUSES
} | {"features-" + platform + "-" + mode for platform in ("linux", "windows") for mode in FEATURES}
PATHS = set(common.NATIVE.values()) | set(common.MANIFEST.values())
sys.path.insert(0, str(ROOT / "tools/pubpres_final_recovery"))
from identity import digest
from run_focus import ENGINE_SHA256
from retained_runtime import make_binding
_spec = importlib.util.spec_from_file_location("pubpres_original_qualification", ROOT / "tools/pubpres_final_recovery/run_qualification.py")
_original_qualification = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_original_qualification)
supplemental_result = _original_qualification.supplemental_result
sys.path.insert(0, str(ROOT / "tools/pubpres_recovery_windows"))
from native_owner_receipt import validate as validate_native_owner


def require(value, message):
    common.require(value, message)


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=600).decode().strip()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class GitHub:
    def __init__(self):
        self.token = os.environ.get("PUBPRES_PUBLICATION_TOKEN", "")
        require(self.token, "A job-scoped publication token is required")

    def api(self, path):
        require(path.startswith(("actions/", "git/")) and ".." not in path, "Unregistered API resource")
        req = urllib.request.Request("https://api.github.com/repos/" + REPOSITORY + "/" + path,
            headers={"Authorization": "Bearer " + self.token, "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"})
        with urllib.request.urlopen(req, timeout=120) as response:
            return json.load(response)

    def archive(self, artifact, output):
        require(artifact.get("expired") is False and re.fullmatch(r"sha256:[0-9a-f]{64}", artifact.get("digest", "")),
                "Original artifact lacks a live independently supplied digest")
        require(0 < artifact.get("size_in_bytes", 0) <= 600 * 1024**2, "Original artifact size is outside the bounded custody scope")
        req = urllib.request.Request("https://api.github.com/repos/" + REPOSITORY + "/actions/artifacts/" + str(artifact["id"]) + "/zip",
            headers={"Authorization": "Bearer " + self.token, "Accept": "application/vnd.github+json"})
        try:
            urllib.request.build_opener(NoRedirect).open(req, timeout=120)
            raise ValueError("Expected the original artifact's temporary download redirect")
        except urllib.error.HTTPError as response:
            require(response.code in (301, 302, 303, 307), "Artifact download admission failed")
            location = response.headers.get("Location", "")
        parsed = urllib.parse.urlparse(location)
        require(parsed.scheme == "https" and bool(parsed.netloc) and parsed.username is None, "Unsafe artifact download target")
        # The repository token is deliberately absent from the storage request.
        with urllib.request.urlopen(location, timeout=180) as response:
            data = response.read(600 * 1024**2 + 1)
        require(len(data) == artifact["size_in_bytes"] and hashlib.sha256(data).hexdigest() == artifact["digest"].removeprefix("sha256:"),
                "Downloaded original archive differs from live Actions custody")
        output.mkdir(parents=True, exist_ok=False)
        with zipfile.ZipFile(io.BytesIO(data)) as bundle:
            rows = bundle.infolist()
            require(len(rows) <= 100000 and sum(row.file_size for row in rows) <= 2 * 1024**3, "Archive expansion exceeds custody limits")
            names = set()
            for row in rows:
                path = PurePosixPath(row.filename)
                require(not path.is_absolute() and ".." not in path.parts and "\\" not in row.filename
                        and not stat.S_ISLNK(row.external_attr >> 16) and row.filename not in names,
                        "Unsafe or duplicated original archive member")
                names.add(row.filename)
            require(bundle.testzip() is None, "Original archive CRC failure")
            bundle.extractall(output)
        return {"id": artifact["id"], "name": artifact["name"], "sha256": artifact["digest"].removeprefix("sha256:"),
                "bytes": len(data), "url": "https://github.com/" + REPOSITORY + "/actions/runs/" + str(artifact["workflow_run"]["id"]) + "/artifacts/" + str(artifact["id"])}


def admit_jobs(run, jobs, *, source, attempt, expected):
    require(run.get("repository", {}).get("full_name", "").lower() == REPOSITORY
            and run.get("head_branch") == request.BRANCH and run.get("head_sha") == source
            and run.get("event") == "push" and run.get("path") == WORKFLOW
            and run.get("run_attempt") == attempt and run.get("status") == "completed",
            "Original workflow/source/branch/attempt is not the declared completed campaign")
    mapped = {}
    for job in jobs:
        require(job["name"] not in mapped, "Duplicated original job identity")
        mapped[job["name"]] = job
    require(expected <= set(mapped), "Original campaign has unexecuted required jobs")
    for name in expected:
        job = mapped[name]
        require(job.get("run_id") == run["id"] and job.get("status") == "completed" and job.get("conclusion") == "success",
                "Required job failed, was skipped or belongs to another run: " + name)
    return {name: {"id": mapped[name]["id"], "conclusion": mapped[name]["conclusion"]} for name in sorted(expected)}


def campaign(api, run_id, attempt, source, expected):
    run = api.api("actions/runs/" + str(run_id))
    jobs = []
    for page in range(1, 20):
        part = api.api("actions/runs/" + str(run_id) + "/attempts/" + str(attempt) + "/jobs?per_page=100&page=" + str(page))["jobs"]
        jobs.extend(part)
        if len(part) < 100:
            break
    admitted = admit_jobs(run, jobs, source=source, attempt=attempt, expected=expected)
    artifacts = []
    for page in range(1, 20):
        part = api.api("actions/runs/" + str(run_id) + "/artifacts?per_page=100&page=" + str(page))["artifacts"]
        artifacts.extend(part)
        if len(part) < 100:
            break
    return {"run": run_id, "attempt": attempt, "source": source, "jobs": admitted}, artifacts


def acquire(api, artifacts, name, output, run_id, source):
    selected = [row for row in artifacts if row["name"] == name]
    require(len(selected) == 1, "Missing or ambiguous original artifact: " + name)
    item = selected[0]
    require(item["workflow_run"]["id"] == run_id and item["workflow_run"]["head_sha"] == source
            and item["workflow_run"]["head_branch"] == request.BRANCH, "Original artifact source role differs")
    return api.archive(item, output)


def source_projection(reference):
    require(subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", reference, "HEAD"], check=False).returncode == 0,
            "Original qualified source is not an ancestor")
    changed = git("diff", "--name-only", reference, "HEAD").splitlines()
    # Publication plumbing and dated engineering evidence may follow successful
    # execution. Every production byte, original reader and actual q adapter is
    # immutable across that join. Final delivery executes its complete source.
    allowed = {request.REQUEST, WORKFLOW, "tools/pubpres_mainline/publish_runtime.py", "tools/pubpres_mainline/test_publication.py"}
    require(all(name in allowed or name.startswith("docs/audits/") for name in changed),
            "Unqualified source change after the exact successful application campaign")
    return {"qualified_source": reference, "qualified_tree": git("rev-parse", reference + "^{tree}"),
            "publication_parent": git("rev-parse", "HEAD"), "publication_parent_tree": git("rev-parse", "HEAD^{tree}"),
            "non_execution_changes": changed, "production_and_qualification_bytes_identical": True}


def replay_summary(directory, source, platform, focus, native):
    paths = list(directory.rglob("SUMMARY.json"))
    require(len(paths) == 1, "Missing or ambiguous actual qualification summary")
    path = paths[0]
    proof = json.loads(path.read_bytes())
    require(proof.get("complete") is True and proof.get("physical_acceptance") == "HOLD"
            and proof.get("source", {}).get("source_commit") == source
            and proof["source"].get("source_tree") == git("rev-parse", source + "^{tree}")
            and proof.get("engine_sha256") == ENGINE_SHA256[platform]
            and proof.get("native", {}).get("binary_sha256") == native["runtime_sha256"],
            "Actual qualification source/native/engine/scope did not pass")
    project = path.parent / "project"
    for name, expected in proof["staged_input_files_sha256"].items():
        require(not PurePosixPath(name).is_absolute() and ".." not in PurePosixPath(name).parts, "Unsafe staged source member")
        if name not in {".godot/global_script_class_cache.cfg", ".godot/extension_list.cfg"}:
            require(digest(project / name) == expected, "Original staged execution byte changed: " + name)
    expected_count = {"frozen": 19, "water": 4, "members": 4, "held-placement": 2, "mainline": 7, "native-owner": 2}[focus]
    require(len(proof["outcomes"]) == expected_count and all(row.get("valid") is True and row.get("returncode") == 0
            and row.get("timed_out") is False for row in proof["outcomes"]), "Original process population failed or is incomplete")
    for row in proof["outcomes"]:
        name = row["test"] + ("-slots" + str(row["slots"]) if "slots" in row else "")
        folder = path.parent / name
        log = folder / "stdout.log"
        text = log.read_text(encoding="utf-8", errors="replace")
        require(digest(log) == row["log_sha256"] and "ERROR:" not in text, "Original strict process log failed or changed")
        if focus in ("water", "members", "held-placement") and row["test"] != "import":
            actual = supplemental_result(row["test"], text, folder, proof["source"], project,
                engine_sha=ENGINE_SHA256[platform], expected_inline=True, expected_lookahead=0,
                expected_atomic=False, stock_held=focus == "held-placement")
            require(actual == row["evidence"], "Original graphical reader no longer reproduces its receipt")
        elif focus == "native-owner" and row["test"] != "import":
            raw = json.loads((folder / "receipt.json").read_bytes())
            actual = validate_native_owner(raw, text, source=source, test_sha=digest(project / "tests" / (row["test"] + ".gd")),
                engine_sha=ENGINE_SHA256[platform], native_sha=native["runtime_sha256"],
                native_descriptor_sha=digest(project / "addons/cybersand_native/cybersand_native.gdextension"),
                platform="Windows" if platform == "windows" else "Linux")
            require(actual == proof["result"] and digest(folder / "receipt.json") == proof["receipt_sha256"],
                    "Original native owner reader differs")
        elif focus == "mainline" and row.get("graphical"):
            raw = row["receipt"]
            require(digest(folder / "receipt.json") == row["receipt_sha256"] and json.loads((folder / "receipt.json").read_bytes()) == raw
                    and raw.get("checks", 0) >= 45 and raw.get("failures") == []
                    and [p.get("label") for p in raw.get("probes", [])] == ["held", "expired"], "Retained actual draw controls differ")
            require(set(raw["framebuffer_files_sha256"]) == {"held.png", "expired.png", "hidden-control.png", "restored.png"}, "Incomplete rendered controls")
            for image, sha in raw["framebuffer_files_sha256"].items():
                require(digest(folder / image) == sha, "Actual retained framebuffer changed")
    for key in ("source_mutations", "import_source_mutations", "final_source_mutations"):
        if key in proof:
            require(proof[key] == [], "Execution changed authored inputs")
    return {"summary_sha256": digest(path), "source": source, "engine_sha256": ENGINE_SHA256[platform],
            "native_sha256": native["runtime_sha256"], "processes": expected_count, "complete": True,
            "raw_native_and_graphical_readers_replayed": focus in ("water", "members", "held-placement", "native-owner")}


def remote_head():
    value = git("ls-remote", "origin", "refs/heads/" + request.BRANCH).split()
    require(len(value) == 2 and value[1] == "refs/heads/" + request.BRANCH, "Missing principal branch")
    return value[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args()
    selected = request.validate()
    require(selected["phase"] == "publish" and os.environ.get("GITHUB_ACTIONS") == "true", "Only the guarded source-owned publication job may run")
    parent = git("rev-parse", "HEAD")
    require(remote_head() == parent, "Principal branch moved before publication admission")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    projection = source_projection(selected["qualification_source"])
    api = GitHub()
    build, build_artifacts = campaign(api, selected["runtime_run"], selected["runtime_attempt"], selected["runtime_source"], BUILD_JOBS)
    qualified, qualification_artifacts = campaign(api, selected["qualification_run"], selected["qualification_attempt"], selected["qualification_source"], QUALIFICATION_JOBS)
    report = {"schema": "pubpres-mainline-guarded-publication-v1", "parent": parent, "build": build, "qualification": qualified,
              "projection": projection, "platforms": {}, "physical_acceptance": "HOLD", "merge_authorized": False, "published": False}
    common.write_json(output / "PUBLICATION.json", report)
    manifests = {}
    for platform in ("linux", "windows"):
        runtime_folder = output / (platform + "-runtime")
        build_name = f"pubpres-mainline-runtimes-{platform}-{build['run']}-{build['attempt']}"
        archive = acquire(api, build_artifacts, build_name, runtime_folder, build["run"], build["source"])
        original = runtime_folder / "C"
        native, checked = common.runtime_record(ROOT, original, platform)
        require(native["source_commit"] == build["source"], "Built candidate belongs to another source")
        outcomes = {}
        for focus in FOCUSES:
            folder = output / (platform + "-" + focus)
            name = f"pubpres-mainline-qualified-{platform}-{focus}-{qualified['run']}-{qualified['attempt']}"
            receipt_archive = acquire(api, qualification_artifacts, name, folder, qualified["run"], qualified["source"])
            outcomes[focus] = {"artifact": receipt_archive, "replay": replay_summary(folder, qualified["source"], platform, focus, native)}
        report["platforms"][platform] = {"build_artifact": archive, "runtime": checked, "outcomes": outcomes}
        previous = json.loads((ROOT / common.MANIFEST[platform]).read_bytes())
        binding = make_binding(ROOT, common.source_identity(ROOT), original, target_platform=platform)
        manifests[platform] = {
            "schema_version": 1, "status": "validated-development-runtime", "kind": "source-matched-pubpres-mainline-draft-runtime",
            "artifact": common.NATIVE[platform], "platform": platform + " x86_64", "validated_platform": platform + " x86_64; native and hosted graphical qualification passed",
            "source_commit": native["source_commit"], "source_tree": native["source_tree"], "build_commit": native["source_commit"],
            "source_inputs": native["source_inputs_sha256"], "source_input_hash_kind": "sha256-canonical-lf",
            "sha256": native["runtime_sha256"], "size": native["runtime_bytes"], "godot_version": "4.7.stable.official.5b4e0cb0f",
            "godot_cpp_commit": native["godot_cpp_commit"], "toolchain": native["compiler_version"],
            "build_custody": {"artifact": archive, "source": build["source"], "run": build["run"], "attempt": build["attempt"],
                "manifest_sha256": digest(original / "PUBPRES-RUNTIME.json"), "dependency_sha256": digest(original / "GODOT-CPP-DEPENDENCY.json"),
                "godot_cpp_library_sha256": native["godot_cpp_library_sha256"], "log_sha256": native["log_sha256"]},
            "native_input_binding": binding, "qualification": {"source": qualified["source"], "run": qualified["run"], "attempt": qualified["attempt"], "outcomes": outcomes},
            "publication_source_comparison": projection, "publication_branch": request.BRANCH,
            "publication_workflow": WORKFLOW, "publication_run": os.environ["GITHUB_RUN_ID"], "publication_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
            "workflow_run": str(build["run"]), "workflow_attempt": str(build["attempt"]),
            "validation_date": "2026-11-28", "supersedes": {"build_commit": previous.get("build_commit"), "sha256": previous["sha256"]},
            "acceptance": "Draft/HOLD. Successful original native and hosted source gates do not grant physical owner acceptance or mainline promotion. Final published-source extracted evaluator qualification is separate."
        }
        common.write_json(output / "PUBLICATION.json", report)
    require(remote_head() == parent, "Principal branch moved during evidence replay")
    if not args.publish:
        common.write_json(output / "STAGED-MANIFESTS.json", manifests)
        print(json.dumps({"admitted": True, "published": False, "parent": parent}))
        return
    require(os.environ.get("PUBPRES_ALLOW_RUNTIME_PUBLICATION") == "four-path-principal-fast-forward-v1", "Publication capability was not explicitly granted to this job")
    git("lfs", "install", "--local")
    for platform, manifest in manifests.items():
        original = output / (platform + "-runtime") / "C"
        shutil.copyfile(original / Path(common.NATIVE[platform]).name, ROOT / common.NATIVE[platform])
        common.write_json(ROOT / common.MANIFEST[platform], manifest)
    git("add", "--", *sorted(PATHS))
    require(set(git("diff", "--cached", "--name-only").splitlines()) == PATHS, "Staged publication escaped the exact four runtime paths")
    for platform, manifest in manifests.items():
        expected = f"version https://git-lfs.github.com/spec/v1\noid sha256:{manifest['sha256']}\nsize {manifest['size']}"
        require(git("show", ":" + common.NATIVE[platform]) == expected, "Staged runtime is not the exact admitted LFS pointer")
    require(remote_head() == parent, "Principal branch moved before creating its four-path child")
    git("-c", "user.name=github-actions[bot]", "-c", "user.email=41898282+github-actions[bot]@users.noreply.github.com",
        "commit", "-m", "Publish qualified source-exact PUBPRES mainline native runtimes")
    child = git("rev-parse", "HEAD")
    require(git("rev-parse", "HEAD^") == parent and set(git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").splitlines()) == PATHS,
            "Publication child changed ancestry or path population")
    git("lfs", "push", "origin", "HEAD")
    require(remote_head() == parent, "Principal branch moved before guarded push; refusing history rewrite")
    git("push", "origin", "HEAD:refs/heads/" + request.BRANCH)
    require(remote_head() == child, "Published branch identity does not match its exact child")
    report.update(published=True, commit=child, tree=git("rev-parse", "HEAD^{tree}"), changed_paths=sorted(PATHS))
    common.write_json(output / "PUBLICATION.json", report)
    print(json.dumps({"published": True, "parent": parent, "commit": child, "tree": report["tree"], "physical_acceptance": "HOLD"}))


if __name__ == "__main__":
    main()
