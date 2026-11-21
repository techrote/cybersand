#!/usr/bin/env python3
"""Read candidate scope, retain exact-head evidence and dispatch standard CI.

This separate harness never publishes files, writes Git refs, changes PR state,
or invokes the full 80-Gentek campaign. Historical evidence retains its source.
"""
from __future__ import annotations

import argparse
from collections import Counter
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import zipfile

REPO = "techrote/cybersand"
BRANCH = "integration/gentek80-water-conflict-reconcile"
HARNESS_REF = "refs/heads/qualification/gentek691-final-ci-followup"
MAIN = "69209acaffb34ebe18c45e19290b5976b7fb2c82"
SOURCE = "c53fd6f9d3d0f2b3f39396c7e605654f65c17299"
SOURCE_TREE = "81c57e073ef94522e17a09d1981e0fb2389aca6e"
PUBLICATION = "54e47c297a7610fc6a09cc3743d1860f2930d05e"
PUBLICATION_TREE = "00fb0b214b3accc6e1d91de3f618ba9c98b75bc9"
FULL_RUN = 44916761139
SCOPE = frozenset({
    "tools/ci/run_godot_regressions.py",
    "tools/ci/verify_linux_godot_shards.py",
    "tools/ci/verify_windows_godot_shards.py",
    "tools/ci/test_godot_regression_sharding.py",
    "tools/ci/test_verify_linux_godot_shards.py",
    "tools/ci/test_verify_windows_godot_shards.py",
})
PUBLICATION_PATHS = frozenset({
    "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
    "godot/addons/cybersand_native/runtime-provenance.json",
    "godot/addons/cybersand_native/runtime-provenance.linux.json",
})
WORKFLOWS = (
    "documentation.yml", "native.yml", "gdextension.yml",
    "palette-shader-qualification.yml", "wave-flow.yml", "native-scope-advisory.yml",
)
RUNTIMES = {
    "linux": ("runtime-provenance.linux.json", "a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7", 5253776),
    "windows": ("runtime-provenance.json", "668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e", 5820416),
}
ENGINES = {
    "linux": "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75",
    "windows": "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8",
}
ART_COUNTS = {
    "test_art_provider": 54, "test_art_lazy_traffic": 23,
    "test_art_traffic_integrity": 148, "test_art_traffic_panel_safety": 55,
    "test_art_history_receipt_identity": 122, "test_workbench_actor_equipment_extent": 29,
    "art-durability-suite": 345, "art-durability-restart-seed": 14,
    "art-durability-restart-recover": 13, "art-durability-crash-seed": 8,
    "art-durability-crash-recover": 8, "art-durability-secret-turn-seed": 24,
    "art-durability-secret-turn-recover": 15, "art-durability-secret-raw-seed": 31,
    "art-durability-secret-raw-recover": 17,
}
LINUX_COUNTS = {
    "art-durability-posix-listing": 29, "art-durability-listing-clock-seed": 12,
    "art-durability-listing-clock-recover": 17,
}
FLATTEN_COUNTS = {
    "standalone-format-adversarial": 102, "side-512-workers-1-author": 196,
    "side-512-workers-1-reopen": 44, "owner-failure-author": 53,
    "owner-failure-reopen": 44,
}


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], timeout=60)


def git_text(root, *args):
    return git(root, *args).decode().rstrip("\r\n")


def read_blobs(root, ref, names):
    names = sorted(set(names))
    if not names:
        return {}
    payload = subprocess.check_output(
        ["git", "-C", str(root), "cat-file", "--batch"],
        input="".join(f"{ref}:{name}\n" for name in names).encode(), timeout=60)
    offset, result = 0, {}
    for name in names:
        end = payload.index(b"\n", offset)
        fields = payload[offset:end].split()
        require(len(fields) == 3 and fields[1] == b"blob", "Missing regular Git blob: " + name)
        size = int(fields[2])
        result[name] = payload[end + 1:end + 1 + size]
        require(len(result[name]) == size, "Truncated Git blob: " + name)
        offset = end + size + 2
    require(offset == len(payload), "Unexpected Git batch response")
    return result


def exact_delta(root, before, after, expected):
    rows = git_text(root, "diff", "--no-renames", "--name-status", before, after).splitlines()
    require(Counter(rows) == Counter("M\t" + p for p in expected), "Candidate delta exceeds or omits the exact approved scope")
    for p in expected:
        for ref in (before, after):
            entry = git_text(root, "ls-tree", ref, "--", p).split()
            require(len(entry) == 4 and entry[0] in {"100644", "100755"} and entry[1] == "blob", "Non-regular scoped file: " + p)
        modes = git_text(root, "diff", "--summary", before, after, "--", p)
        require(not modes, "Scoped file mode changed: " + p)
    return rows


def candidate_scope(root, target, tree):
    require(git_text(root, "rev-parse", "HEAD") == target, "Candidate checkout SHA differs")
    require(git_text(root, "rev-parse", "HEAD^{tree}") == tree, "Candidate tree differs")
    require(not git_text(root, "status", "--porcelain", "--untracked-files=no"), "Candidate tracked checkout is dirty")
    require(git_text(root, "rev-list", "--parents", "-n", "1", target).split() == [target, PUBLICATION], "Final candidate is not one direct child of the published Q")
    require(git_text(root, "rev-parse", PUBLICATION + "^{tree}") == PUBLICATION_TREE, "Published Q tree differs")
    require(git_text(root, "rev-list", "--parents", "-n", "1", PUBLICATION).split() == [PUBLICATION, SOURCE], "Publication ancestry differs")
    require(git_text(root, "rev-parse", SOURCE + "^{tree}") == SOURCE_TREE, "Full campaign source tree differs")
    require(git_text(root, "merge-base", MAIN, target) == MAIN, "Final candidate omits accepted main")
    delta = exact_delta(root, PUBLICATION, target, SCOPE)
    exact_delta(root, SOURCE, PUBLICATION, PUBLICATION_PATHS)
    manifests = {}
    for platform, (filename, digest, size) in RUNTIMES.items():
        relative = "godot/addons/cybersand_native/" + filename
        manifest = json.loads((root / relative).read_bytes())
        require(manifest["source_commit"] == SOURCE and manifest["source_tree"] == SOURCE_TREE, "Historical native build identity was relabeled")
        require(manifest["sha256"] == digest and manifest["size"] == size, "Published runtime identity differs")
        library = root / manifest["artifact"]
        require(library.is_file() and not library.is_symlink() and sha(library.read_bytes()) == digest and library.stat().st_size == size, "Runtime must be materialized and unchanged")
        native, build = manifest["source_inputs"], manifest["build_inputs"]
        require(len(native) == 105 and len(build) == 995, "Historical native/build inventory differs")
        current = read_blobs(root, target, set(native) | set(build))
        require(all(sha(current[p]) == h for p, h in native.items()), "A compiled native input changed")
        changed_build = sorted(p for p, h in build.items() if sha(current[p]) != h)
        require(changed_build == ["tools/ci/run_godot_regressions.py"], "Historical build input delta exceeds the one reviewed classifier")
        require(all(sha((root / p).read_bytes().replace(b"\r\n", b"\n")) == sha(data) for p, data in current.items()), "Working native/build input differs from final Git source")
        manifests[platform] = {"manifest_sha256": sha((root / relative).read_bytes()), "native_sha256": digest, "size": size, "native_inputs_unchanged": len(native), "historical_build_inputs": len(build), "historical_build_input_delta": changed_build}
    scripts = [p for p in git_text(root, "ls-tree", "-r", "--name-only", target, "--", "godot").splitlines() if p.endswith(".gd")]
    require(len(scripts) == 660 and not (set(scripts) & SCOPE), "Godot script inventory differs")
    return {"candidate_commit": target, "candidate_tree": tree, "accepted_main": MAIN,
            "publication_commit": PUBLICATION, "full_campaign_source": SOURCE,
            "full_campaign_source_tree": SOURCE_TREE, "exact_modified_paths": delta,
            "all_other_tracked_blobs_and_modes_unchanged_from_Q": True,
            "godot_scripts_unchanged": len(scripts), "runtimes": manifests,
            "source_scope": "Six CI classifier/reducer/test files only. Historical995 build inputs remain dated c53 evidence, with exactly one changed current entry; no provenance is rewritten.",
            "retained_runtime_package_scope": "The c53 full native/gallery/Workbench/package evidence remains c53 evidence. All product, full-campaign execution scripts, package inputs and library bytes are unchanged by this six-file follow-up."}


class Commands:
    def __init__(self, root, evidence):
        self.root, self.evidence = root, evidence
        self.rows = []

    def run(self, name, command, *, output=None, timeout=120):
        row = {"name": name, "command": command, "status": "started"}
        self.rows.append(row)
        save(self.evidence / "commands.json", self.rows)
        try:
            result = subprocess.run(command, cwd=self.root, capture_output=True, timeout=timeout)
            out = output or self.evidence / (name + ".stdout.log")
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(result.stdout)
            err = self.evidence / (name + ".stderr.log")
            err.write_bytes(result.stderr)
            row.update(status="completed", returncode=result.returncode,
                       stdout_sha256=sha(result.stdout), stderr_sha256=sha(result.stderr))
            require(result.returncode == 0, "Command failed: " + name)
            return result.stdout
        except subprocess.TimeoutExpired as error:
            out = output or self.evidence / (name + ".stdout.log")
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(error.stdout or b"")
            (self.evidence / (name + ".stderr.log")).write_bytes(error.stderr or b"")
            row.update(status="timed_out", returncode=None,
                       stdout_sha256=sha(error.stdout or b""), stderr_sha256=sha(error.stderr or b""))
            raise
        except Exception as error:
            row.update(status="failed", error=type(error).__name__ + ": " + str(error))
            raise
        finally:
            save(self.evidence / "commands.json", self.rows)

    def api(self, name, path):
        return json.loads(self.run(name, ["gh", "api", "repos/" + REPO + "/" + path]))


def lease(commands, label, target):
    branch = commands.api(label + "-candidate", "git/ref/heads/" + BRANCH)
    main = commands.api(label + "-main", "git/ref/heads/main")
    require(branch["object"]["sha"] == target, "Owning branch lease differs from exact final candidate")
    require(main["object"]["sha"] == MAIN, "Accepted main lease changed")
    return {"candidate": target, "main": MAIN}


def validate_run(run, *, run_id, head, path):
    require(run.get("id") == run_id and run.get("head_sha") == head, "Run identity differs")
    require(run.get("path") == path and run.get("status") == "completed" and run.get("conclusion") == "success", "Required original run is not successful")
    require(run.get("repository", {}).get("full_name") == REPO, "Run repository differs")


def validate_focused_zip(path, platform, target, tree):
    with zipfile.ZipFile(path) as archive:
        infos = archive.infolist()
        names = [item.filename for item in infos]
        require(len(names) == len(set(names)) == len({name.casefold() for name in names}), "Artifact has duplicate paths")
        require(sum(i.file_size for i in infos) < 1024 ** 3, "Focused artifact is oversized")
        require(all(not PurePosixPath(i.filename).is_absolute() and ".." not in PurePosixPath(i.filename).parts and "\\" not in i.filename and (i.external_attr >> 16) & 0o170000 != 0o120000 for i in infos), "Unsafe focused artifact path")
        def obj(name):
            require(archive.getinfo(name).file_size < 32 * 1024 ** 2, "Oversized focused report")
            return json.loads(archive.read(name))
        art = obj("art-recovery/qualification.json")
        require(art.get("passed") is True and art.get("status") == "passed" and art.get("errors") == [] and art.get("development_only") is False, "Focused Art qualification did not pass strictly")
        identity = art["identity_before"]
        require(identity == art["identity_after"], "Focused source changed during execution")
        require(identity["source_commit"] == target and identity["source_tree"] == tree and art["checkout_identity"]["source_commit"] == target and art["checkout_identity"]["source_tree"] == tree, "Focused source/tree differs from final candidate")
        require(identity["native_sha256"] == RUNTIMES[platform][1] and identity["native_build_commit"] == SOURCE and identity["engine_sha256"] == ENGINES[platform] and identity["godot_version"] == "4.7.stable.official.5b4e0cb0f", "Focused runtime/engine identity differs")
        require(art["editor_import"].get("passed") is True, "Focused bounded import transition failed")
        counts = dict(ART_COUNTS)
        if platform == "linux":
            counts.update(LINUX_COUNTS)
        rows = art["cases"]
        require(Counter(row["name"] for row in rows) == Counter(["import", *counts]), "Focused case inventory differs")
        require(Counter(art["expected_cases"]) == Counter(counts.keys()), "Focused declared inventory differs")
        for row in rows:
            name = row["name"]
            require(row.get("status") == "passed", "Focused case failed: " + name)
            require(sha(archive.read("art-recovery/" + name + ".log")) == row["log_sha256"], "Focused raw log differs: " + name)
            killed = name in {"art-durability-crash-seed", "art-durability-secret-turn-seed"}
            require(row.get("returncode") == ((-9 if platform == "linux" else 1) if killed else 0), "Focused process return code differs: " + name)
            if killed:
                require(row.get("kill_requested") is True and re.fullmatch(r"[0-9a-f]{64}", row.get("boundary_sha256", "")) and re.fullmatch(r"[0-9a-f]{64}", row.get("pending_at_kill_sha256", "")), "Missing original witnessed hard-kill boundary")
            if name != "import":
                completion = row["completion"]
                require(completion.get("checks") == counts[name] and completion.get("failures") in (0, []), "Focused positive count or failure list differs: " + name)
        require(art.get("positive_assertions") == sum(counts.values()), "Focused positive total differs")
        qualification = obj("flatten/qualification.json")
        require(qualification.get("status") == "passed" and qualification.get("graphical") is True and qualification.get("cases") == [[512, 1]] and qualification.get("storage_faults", {}).get("status") == "passed", "Original graphical512/failed-owner qualification did not pass")
        flatten = obj("flatten/results.json")
        require(Counter(row["label"] for row in flatten) == Counter(["flatten-import", *FLATTEN_COUNTS]), "Original Flatten process inventory differs")
        for row in flatten:
            name = row["label"]
            require(row.get("exit_code") == 0 and row.get("status") == "passed" and row.get("engine_executable_sha256") == ENGINES[platform], "Original Flatten process or engine differs")
            if name != "flatten-import":
                require(row["completion"].get("checks") == FLATTEN_COUNTS[name] and row["completion"].get("failures") in (0, []), "Original Flatten positive assertions differ")
            if name not in {"flatten-import", "standalone-format-adversarial"}:
                require("--headless" not in row["command"], "Graphical case was replaced with headless execution")
        return {"platform": platform, "candidate_commit": target, "candidate_tree": tree,
                "art_checks": sum(counts.values()), "flatten_graphical_checks": 337,
                "flatten_standalone_format_checks": 102, "actual_art_processes": len(rows),
                "actual_flatten_processes": len(flatten), "native_sha256": identity["native_sha256"],
                "engine_sha256": identity["engine_sha256"], "qualification_sha256": sha(archive.read("art-recovery/qualification.json")),
                "scope": "Same-commit original execution retained; no test rerun or skip is substituted."}


def focused_evidence(commands, run_id, target, tree):
    run = commands.api("focused-run", f"actions/runs/{run_id}")
    validate_run(run, run_id=run_id, head=target, path=".github/workflows/gentek691-art-history-repro.yml")
    jobs = commands.api("focused-jobs", f"actions/runs/{run_id}/jobs?per_page=100")
    required = {"Linux X11 full native Flatten 512 + Art deferred-history", "Windows ANGLE full native Flatten 512 + Art deferred-history"}
    require(jobs.get("total_count") == 2 and {j["name"] for j in jobs["jobs"]} == required and all(j["conclusion"] == "success" and j["status"] == "completed" for j in jobs["jobs"]), "Focused target-OS original jobs are missing or failed")
    metadata = commands.api("focused-artifacts", f"actions/runs/{run_id}/artifacts?per_page=100")
    require(metadata.get("total_count") == 2 and len(metadata["artifacts"]) == 2, "Focused artifact inventory differs")
    result = {"run_id": run_id, "url": run["html_url"], "head_sha": target, "source_tree": tree, "status": "passed", "reused_same_commit": True, "platforms": []}
    for platform in RUNTIMES:
        matches = [a for a in metadata["artifacts"] if a["name"] == f"gentek691-focused-{platform}-{run_id}"]
        require(len(matches) == 1 and matches[0].get("expired") is False, "Missing original focused artifact")
        artifact = matches[0]
        require(artifact.get("workflow_run", {}).get("id") == run_id and artifact["workflow_run"].get("head_sha") == target, "Focused artifact source association differs")
        path = commands.evidence / (artifact["name"] + ".zip")
        commands.run("download-focused-" + platform, ["gh", "api", f"repos/{REPO}/actions/artifacts/{artifact['id']}/zip"], output=path, timeout=240)
        digest = sha(path.read_bytes())
        require(artifact.get("digest") == "sha256:" + digest, "Focused artifact digest differs")
        row = validate_focused_zip(path, platform, target, tree)
        row.update(artifact_id=artifact["id"], artifact_sha256=digest, artifact_name=artifact["name"])
        result["platforms"].append(row)
    return result


def run_guards(commands):
    definitions = [
        ("py-compile", [sys.executable, "-m", "py_compile", "tools/ci/gen007_architectural_runtime_publication.py"]),
        ("gen007-publisher", [sys.executable, "tools/ci/test_gen007_architectural_runtime_publication.py"]),
        ("lcb001-publisher", [sys.executable, "tools/ci/test_lcb001_shared_contract_runtime_publication.py"]),
        ("provider-policy", [sys.executable, "tools/ci/check_ci_provider_policy.py"]),
        ("gentek80-publisher", [sys.executable, "tools/ci/test_gentek80_runtime_publication.py"]),
        ("gentek80-water-publisher", [sys.executable, "tools/ci/test_gentek80_water_runtime_publication.py"]),
        ("gentek80-reference-inputs", [sys.executable, "tools/architecture/test_gentek80_reference_inputs.py"]),
        ("classifier-registration", [sys.executable, "tools/ci/test_godot_regression_sharding.py"]),
        ("linux-raw-log-reducer", [sys.executable, "tools/ci/test_verify_linux_godot_shards.py"]),
        ("windows-raw-log-reducer", [sys.executable, "tools/ci/test_verify_windows_godot_shards.py"]),
        ("materialized-provenance", [sys.executable, "tools/ci/check_repository.py", "--require-materialized"]),
    ]
    for name, command in definitions:
        commands.run(name, command, timeout=300)
    return {"status": "passed", "command_count": len(definitions), "commands": commands.rows}


def request_workflows(commands, target, focused):
    require(focused.get("status") == "passed" and focused.get("head_sha") == target, "Seventh focused gate is not source matched")
    result = {"status": "requesting", "candidate_commit": target, "focused_same_commit_gate": focused,
              "standard_dispatches": [], "complete_gate_inventory": [*WORKFLOWS, "gentek691-art-history-repro.yml"]}
    path = commands.evidence / "dispatch.json"
    save(path, result)
    try:
        for workflow in WORKFLOWS:
            before = lease(commands, "before-" + workflow, target)
            command = ["gh", "workflow", "run", workflow, "--repo", REPO, "--ref", BRANCH]
            if workflow == "native-scope-advisory.yml":
                command += ["-f", "base_sha=" + MAIN]
            row = {"workflow": workflow, "requested": False, "lease_before": before}
            result["standard_dispatches"].append(row)
            save(path, result)
            commands.run("dispatch-" + workflow, command)
            row["requested"] = True
            save(path, result)
            after = lease(commands, "after-" + workflow, target)
            row["lease_after"] = after
            save(path, result)
        result["final_lease"] = lease(commands, "final", target)
        result["status"] = "requested"
    except Exception as error:
        result.update(status="failed", error=type(error).__name__ + ": " + str(error))
        raise
    finally:
        save(path, result)
    return result


def execute(args):
    root, evidence = args.candidate.resolve(), args.evidence.resolve()
    target, tree, focused_id = (os.environ.get(k, "") for k in ("CANDIDATE_SHA", "CANDIDATE_TREE", "CANDIDATE_FOCUSED_RUN"))
    require(re.fullmatch(r"[0-9a-f]{40}", target) and re.fullmatch(r"[0-9a-f]{40}", tree) and re.fullmatch(r"[1-9][0-9]+", focused_id), "Fill the reviewed exact candidate SHA/tree/focused-run constants before publication")
    require(os.environ.get("GITHUB_REPOSITORY") == REPO and os.environ.get("GITHUB_REF") == HARNESS_REF, "Foreign dispatcher repository or branch")
    folder = evidence / args.phase
    commands = Commands(root, folder)
    identity = candidate_scope(root, target, tree)
    identity.update(orchestration_commit=os.environ["GITHUB_SHA"], orchestration_run=os.environ["GITHUB_RUN_ID"], checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
    save(folder / "source-scope.json", identity)
    if args.phase == "scope":
        lease(commands, "initial", target)
        run = commands.api("original-full-campaign", f"actions/runs/{FULL_RUN}")
        validate_run(run, run_id=FULL_RUN, head=SOURCE, path=".github/workflows/gentek80-water-merged-requalification.yml")
        focused = focused_evidence(commands, int(focused_id), target, tree)
        save(folder / "focused-gate.json", focused)
        lease(commands, "scope-complete", target)
        result = {"status": "passed", "source_scope": identity, "focused_gate": focused,
                  "retained_full_campaign": {"run_id": FULL_RUN, "head_sha": SOURCE, "tree": SOURCE_TREE, "publication": PUBLICATION,
                    "owner_zip_sha256_prior_independent_audit": "b900ff9de532349844a6c2a0cad40410f411a15f185a40093b275e90994d511f",
                    "owner_artifact_id": 14717366117, "owner_artifact_sha256_prior_independent_audit": "121c5003555ffa0b0747821f37cdb7c807989636ccf48cf9251a3184101bda66",
                    "scope": "Original c53 full campaign and independently extracted owner package; retained because all application/runtime/campaign/package inputs are unchanged by the six-file CI-only follow-up."}}
    elif args.phase == "guards":
        prior = json.loads((evidence / "scope/receipt.json").read_text())
        require(prior["status"] == "passed" and prior["source_scope"]["candidate_commit"] == target, "Source/focused gate missing")
        result = run_guards(commands)
        candidate_scope(root, target, tree)
    else:
        prior = json.loads((evidence / "scope/receipt.json").read_text())
        guards = json.loads((evidence / "guards/receipt.json").read_text())
        require(prior["status"] == "passed" and prior["source_scope"]["candidate_commit"] == target and guards["status"] == "passed", "Scope or final-source guards failed")
        result = request_workflows(commands, target, prior["focused_gate"])
        candidate_scope(root, target, tree)
    result.update(candidate_commit=target, candidate_tree=tree, orchestration_commit=os.environ["GITHUB_SHA"], orchestration_run=os.environ["GITHUB_RUN_ID"])
    save(folder / "receipt.json", result)
    print(json.dumps({"phase": args.phase, "status": result["status"], "candidate_commit": target, "candidate_tree": tree}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("scope", "guards", "dispatch"))
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    try:
        execute(args)
    except Exception as error:
        save(args.evidence.resolve() / args.phase / "failure.json", {
            "status": "failed", "error": type(error).__name__ + ": " + str(error),
            "candidate_commit": os.environ.get("CANDIDATE_SHA"),
            "candidate_tree": os.environ.get("CANDIDATE_TREE"),
            "orchestration_commit": os.environ.get("GITHUB_SHA"),
            "orchestration_run": os.environ.get("GITHUB_RUN_ID"),
        })
        raise


if __name__ == "__main__":
    main()
