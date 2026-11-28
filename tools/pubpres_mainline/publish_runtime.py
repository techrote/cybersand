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
FOCUSES = ("frozen", "water", "members", "held-placement", "mainline", "native-owner",
           "selected-water", "selected-members", "selected-held-placement")
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
from run_regressions import terminal_json
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
    allowed = {request.REQUEST, WORKFLOW, "tools/pubpres_mainline/publish_runtime.py",
               "tools/pubpres_mainline/test_publication.py", "tools/pubpres_mainline/publish_local_evidence.py",
               "tools/pubpres_mainline/local_evidence.json"}
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
    selected_owner = focus.startswith("selected-")
    if selected_owner:
        focus = focus.removeprefix("selected-")
        selected = proof.get("selected_workbench_owner", {})
        flags = {key: common.SELECTORS[key] for key in (
            "CYBERSAND_WORKBENCH_FLIGHT_PACING", "CYBERSAND_WORKBENCH_COUPLING_CLOCK", "CYBERSAND_WORKBENCH_EMPTY_EFFECTS")}
        require(selected.get("schema") == "pubpres-mainline-selected-owner-v1"
                and selected.get("owner_flags") == flags
                and selected.get("actual_readback") == {"flight_pacing": True, "coupling_clock": True, "empty_effects": True}
                and selected.get("failure") is None
                and selected.get("adapter_sha256") == digest(ROOT / "tools/pubpres_mainline/run_selected_qualification.py")
                and selected.get("original_driver_sha256") == digest(ROOT / "tools/pubpres_final_recovery/run_qualification.py")
                and selected.get("case_population_readers_and_timeouts_unchanged") is True,
                "Selected owner qualification adapter or actual readback differs")
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
    expected_count = {"frozen": 19, "water": 4, "members": 4, "held-placement": 2, "mainline": 10, "native-owner": 2}[focus]
    require(len(proof["outcomes"]) == expected_count and all(row.get("valid") is True and row.get("returncode") == 0
            and row.get("timed_out") is False for row in proof["outcomes"]), "Original process population failed or is incomplete")
    if focus == "mainline":
        expected_tests = ["import", "test_transport_profiles", "test_transport_profile_reuse", "test_microscenarios",
                          "test_ambient_perception", "test_ambient_publication_owner",
                          "verify_pubpres_owner_gameplay_rotation", "test_workbench_retained_water_hold",
                          "test_workbench_retained_water_hold_native", "test_workbench_continuous_actor_pick"]
        require([row.get("test") for row in proof["outcomes"]] == expected_tests
                and [row.get("graphical") for row in proof["outcomes"]] == [False] * 8 + [True, True],
                "Original focused process identities or graphical populations differ")
    if selected_owner:
        require(len(selected.get("processes", [])) == expected_count
                and all(row.get("owner_flags") == flags for row in selected["processes"]),
                "Selected owner process population differs")
    for row in proof["outcomes"]:
        name = row["test"] + ("-slots" + str(row["slots"]) if "slots" in row else "")
        folder = path.parent / name
        log = folder / "stdout.log"
        text = log.read_text(encoding="utf-8", errors="replace")
        require(digest(log) == row["log_sha256"] and "ERROR:" not in text, "Original strict process log failed or changed")
        if focus == "mainline" and row["test"] in ("test_ambient_perception", "test_ambient_publication_owner"):
            marker = "AMBIENT_PERCEPTION " if row["test"] == "test_ambient_perception" else "AMBIENT_PUBLICATION_OWNER "
            raw = terminal_json(text, marker)
            require(raw == row.get("result") and raw.get("failures") == [],
                    "Original Ambient terminal evidence changed or failed")
            if row["test"] == "test_ambient_perception":
                actual = raw.get("evidence", {}).get("native", {})
                decisions = actual.get("composed_decisions", [])
                require(raw.get("checks", 0) >= 130 and raw.get("physical_trajectory_evidence") is False
                        and len(decisions) == 8 and actual.get("native_tick", 0) > 0
                        and actual.get("native_revision", 0) > 0
                        and actual.get("sensor", {}).get("sample_tick") == actual.get("native_tick")
                        and [value.get("actors") for value in actual.get("benchmarks", [])] == [1, 4, 8]
                        and all(value.get("native_tick", 0) > 0
                                and value.get("material_tick") == value.get("native_tick") for value in decisions),
                        "Original native Ambient material and complete decision population did not execute")
            else:
                actual = raw.get("evidence", {})
                final_owner = actual.get("final", {})
                require(raw.get("checks", 0) >= 49 and actual.get("native_simulation_executed") is False
                        and final_owner.get("available") is True and final_owner.get("world_generation") == 5
                        and final_owner.get("owner_snapshot_serial") == 20 and final_owner.get("current_tick") == 2
                        and final_owner.get("sample_tick") == 2 and final_owner.get("publication_serial") == 3
                        and final_owner.get("cache_bytes") == 8192 and final_owner.get("owner_refusal") == ""
                        and final_owner.get("material_refusal") == "",
                        "Original owner/material refusal controls did not execute without fabricated simulation")
        if focus in ("water", "members", "held-placement") and row["test"] != "import":
            actual = supplemental_result(row["test"], text, folder, proof["source"], project,
                engine_sha=ENGINE_SHA256[platform], expected_inline=True, expected_lookahead=0,
                expected_atomic=False, stock_held=focus == "held-placement")
            require(actual == row["evidence"], "Original graphical reader no longer reproduces its receipt")
            if selected_owner and (folder / "receipt.json").is_file():
                raw = json.loads((folder / "receipt.json").read_bytes())
                require(raw.get("selected_owner_readback") == selected["actual_readback"],
                        "Original graphical Main/worker readback changed")
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
                    and raw.get("failures") == [] and raw.get("source_revision") == source
                    and raw.get("engine_sha256") == ENGINE_SHA256[platform]
                    and raw.get("selected_owner_readback") == {"flight_pacing": True, "coupling_clock": True, "empty_effects": True},
                    "Actual mounted graphical source/readback differs")
            require(raw.get("input_hashes"), "Missing mounted graphical input inventory")
            for name, sha in raw["input_hashes"].items():
                require(name.startswith("res://") and ".." not in PurePosixPath(name.removeprefix("res://")).parts
                        and digest(project / name.removeprefix("res://")) == sha, "Mounted graphical source byte differs")
            if row["test"] == "test_workbench_retained_water_hold_native":
                require(raw.get("checks", 0) >= 45 and raw.get("schema") == "pubpres-retained-water-native-v1"
                        and [p.get("label") for p in raw.get("probes", [])] == ["held", "expired"], "Retained actual draw controls differ")
                require(set(raw["framebuffer_files_sha256"]) == {"held.png", "expired.png", "hidden-control.png", "restored.png"}, "Incomplete rendered controls")
                for image, sha in raw["framebuffer_files_sha256"].items():
                    require(digest(folder / image) == sha, "Actual retained framebuffer changed")
            else:
                require(row["test"] == "test_workbench_continuous_actor_pick" and raw.get("checks", 0) >= 22
                        and raw.get("schema") == "pubpres-continuous-actor-pick-v1", "Unknown mounted graphical case")
                baseline = raw.get("input_physical_step", -1)
                require(type(baseline) is int and baseline > 0 and raw.get("input_manual_steps") == baseline
                        and raw.get("final_input_physical_step") == baseline and raw.get("final_input_manual_steps") == baseline,
                        "Real native/Rapier contact must precede mouse input without changing its completion count")
                rows = raw.get("records", [])
                require(len(rows) == 5 and [r.get("label") for r in rows[:4]] == ["visible_continuous_edge", "opaque_member_pixel", "foreign_owner", "restored_original_owner"]
                        and [r.get("selected") for r in rows[:4]] == [4, 0, 0, 4]
                        and [r.get("expected") for r in rows[:4]] == [4, 0, 0, 4]
                        and all(r.get("physical_step") == baseline for r in rows[:4]), "Actual Select and refusal population differs")
                for index, r in enumerate(rows[:4]):
                    require(r.get("mask_session") == r.get("session", -2) + (1 if index == 2 else 0)
                            and all(r.get(k, 0) > 0 for k in ("session", "epoch", "world")), "Select owner adversary differs")
                require(rows[4].get("framebuffer") == "continuous-pick.png"
                        and digest(folder / "continuous-pick.png") == rows[4].get("sha256"), "Select framebuffer changed")
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


def replay_native_gate(directory, source, kind):
    require((directory / "source.txt").read_text().strip() == source,
            "Original native gate belongs to another source")
    name = "thread-sanitizer.log" if kind == "ownership" else kind + ".log"
    path = directory / name
    text = path.read_text(encoding="utf-8", errors="replace")
    rows = re.findall(r'^PUBPRES_POOL_LIFETIME_RESULT (.+)$', text, re.M)
    require(len(rows) == 1 and json.loads(rows[0]) == {"checks": 509, "failures": []},
            "Original native ownership/lifetime population did not complete")
    require(not re.search(r'ERROR: (AddressSanitizer|LeakSanitizer)|WARNING: ThreadSanitizer|runtime error:', text),
            "Original native sanitizer evidence contains an error")
    if kind != "ownership":
        require("192 tests passed" in text and "RENDER_COPY_QUALIFICATION " in text,
                "Original complete World/publication test population is absent")
        value = json.loads(re.findall(r'^RENDER_COPY_QUALIFICATION (.+)$', text, re.M)[0])
        require(value.get("assertions") == 153284 and value.get("failures") == 0,
                "Original material publication assertions did not complete")
    return {"source": source, "log_sha256": digest(path), "lifetime_checks": 509,
            "actual_process_success_authenticated": True, "raw_terminal_evidence_replayed": True}


def verify_published_lfs(output, child, manifests):
    # A new LFS store prevents our local upload cache from satisfying this read.
    # This read uses the ordinary repository remote after its exact child exists.
    storage = output / "fresh-remote-lfs"
    require(not storage.exists(), "Remote runtime replay must start with an empty LFS store")
    git("-c", "lfs.storage=" + str(storage), "lfs", "fetch", "origin", child,
        "--include=" + ",".join(sorted(common.NATIVE.values())), "--exclude=")
    result = {}
    for platform, manifest in manifests.items():
        sha = manifest["sha256"]
        path = storage / "objects" / sha[:2] / sha[2:4] / sha
        require(path.is_file() and path.stat().st_size == manifest["size"] and digest(path) == sha,
                "Published remote runtime failed independent fresh-store retrieval")
        result[platform] = {"sha256": sha, "bytes": manifest["size"], "fresh_store_retrieval_verified": True}
    return result


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
    report["native_gates"] = {}
    for kind in ("normal", "sanitizers", "ownership"):
        folder = output / ("native-" + kind)
        name = f"pubpres-mainline-native-{kind}-{build['run']}-{build['attempt']}"
        archive = acquire(api, build_artifacts, name, folder, build["run"], build["source"])
        report["native_gates"][kind] = {"artifact": archive,
            "replay": replay_native_gate(folder, build["source"], kind)}
    report["cross_feature_evidence_scope"] = {
        "all_six_exact_source_jobs_authenticated_success": True,
        "original_semantic_readers_executed_by_each_job": True,
        "raw_feature_readers_replayed_by_this_publisher": False,
        "final_delivery_reexecutes_all_features_and_independent_package_readers": True}
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
            "native_gates": report["native_gates"], "cross_feature_evidence_scope": report["cross_feature_evidence_scope"],
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
    sys.path.insert(0, str(ROOT / "tools/ci"))
    from check_repository import verify_runtime
    for manifest in manifests.values():
        require(verify_runtime(ROOT, manifest) == [], "Current repository native provenance reader refused publication")
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
    report["remote_lfs_retrieval"] = verify_published_lfs(output, child, manifests)
    require(remote_head() == child, "Principal branch changed during final remote runtime verification")
    common.write_json(output / "PUBLICATION.json", report)
    print(json.dumps({"published": True, "parent": parent, "commit": child, "tree": report["tree"], "physical_acceptance": "HOLD"}))


if __name__ == "__main__":
    main()
