#!/usr/bin/env python3
"""Publish one independently reviewed, already qualified Windows evaluation.

This temporary branch only copies the original tested ZIP and checksum into a
draft prerelease. It cannot build, merge, replace assets, or qualify a failure.
"""
from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
REPO = "techrote/cybersand"
INTEGRATION_BRANCH = "codex/mat-auth-workbench-integration-20261112"
RELEASE_BRANCH = "codex/mat-workbench-evaluation-release-20261113"
WORKFLOW = ".github/workflows/mat-workbench-evaluation-release.yml"
REQUEST = "tools/ci/mat_workbench_evaluation_release_request.json"
NOTES = "docs/releases/mat-workbench-evaluation-20261113.md"
APPARATUS = {WORKFLOW, REQUEST, NOTES, "tools/ci/mat_workbench_evaluation_release.py"}
PUBLISH_WORKFLOW = "mat-workbench-runtime-publication.yml"
GATES = ("documentation.yml", "native.yml", "gdextension.yml", "palette-shader-qualification.yml")
ACCEPTED_MAIN = "63f8b1ba6559906fe85f3ad0269aa296e4141d67"
WORKBENCH_HEAD = "6319ab1d94d85d01c9cdb44d973a92d224bfa9aa"
CAPABILITY_TRANSITION = "b432d52d0d9acaa22f93eeb8d1fad48c64b4c087"
# A replacement candidate must finish qualification before these reviewed pins
# and the request can be filled together. d664 is a preserved failed attempt.
PINS = {"source_commit": None, "source_tree": None, "publisher_run_id": None,
        "publisher_attempt": None, "request_sequence": None,
        "windows_native_sha256": None, "linux_native_sha256": None}
PUBLISH_JOBS = {
    "validate staged publisher without building runtimes",
    "require an explicit MAT-AUTH + Workbench publication request",
    "complete source-bound MAT-AUTH + Workbench catalogue suite on Linux",
    "build and execute the Linux MAT-AUTH + Workbench runtime",
    "cross-build the Windows MAT-AUTH + Workbench runtime",
    "execute Windows MAT-AUTH + Workbench cases",
    "package and execute a self-contained Windows MAT-AUTH + Workbench",
    "fast-forward the source branch with both validated runtimes",
    "request unchanged full automated gates on the published Draft head",
}
GATE_JOBS = {
    "documentation.yml": {"consistency"},
    "native.yml": {"Native evidence and provider policy", "native", *[
        "Native family / " + name for name in
        ("tsan", "native-normal", "asan-ubsan", "worldgen", "soliding-normal", "soliding-asan")]},
    "gdextension.yml": {"complete execution budgets", "linux build x86_64", "windows x86_64",
        "windows sharded execution coverage", "art workbench graphical smoke", "linux x86_64"},
    "palette-shader-qualification.yml": {"plan", "readback"},
}
PALETTE_PREFIXES = tuple(f"{job} ({platform}, {group}, {index}, {count}, "
    for job, platform in (("linux", "linux"), ("windows", "win32"))
    for group, index, count in (("main-cache", 0, 1), ("visual", 0, 2), ("visual", 1, 2)))
API_ROOT = "https://api.github.com/repos/" + REPO
# The repository's established REST version exposes release asset SHA-256
# digests (verified by a read-only repository release GET on 2026-11-13).
API_VERSION = "2022-11-28"
SCHEMA = "cybersand-mat-workbench-evaluation-release-v1"


def require(value, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def canonical(value) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=300)


def positive(value) -> bool:
    return type(value) is int and value > 0


def hex_value(value, length: int) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{" + str(length) + "}", value) is not None


def check_request(request: dict, notes: bytes) -> dict:
    keys = {"schema", "repository", "accepted_main", "workbench_head", "capability_transition", *PINS,
            "publication_commit", "evaluation_artifact_id", "artifact_outer_sha256", "archive_sha256",
            "archive_name", "acceptance_sha256", "gate_runs", "tag", "release_name"}
    require(isinstance(request, dict) and set(request) == keys, "Unexpected release request schema")
    require(request["schema"] == SCHEMA and request["repository"] == REPO, "Foreign release request")
    for name, expected in PINS.items():
        require(expected is not None and request.get(name) == expected, "Unresolved or changed reviewed pin: " + name)
    for name in ("source_commit", "source_tree", "publication_commit", "accepted_main", "workbench_head", "capability_transition"):
        require(hex_value(request[name], 40), "Missing full commit/tree identity: " + name)
    for name in ("windows_native_sha256", "linux_native_sha256", "artifact_outer_sha256", "archive_sha256", "acceptance_sha256"):
        require(hex_value(request[name], 64), "Missing independently reviewed digest: " + name)
    for name in ("publisher_run_id", "publisher_attempt", "request_sequence", "evaluation_artifact_id"):
        require(positive(request[name]), "Missing positive integer identity: " + name)
    require(request["accepted_main"] == ACCEPTED_MAIN and request["workbench_head"] == WORKBENCH_HEAD and
            request["capability_transition"] == CAPABILITY_TRANSITION, "Accepted source scope changed")
    require(request["publication_commit"] != request["source_commit"], "A source commit is not a runtime publication child")
    require(request["archive_name"] == "CyberSand-MAT-Workbench-Windows-" + request["source_commit"][:12] + ".zip",
            "Evaluation ZIP name differs from its source")
    require(request["tag"] == "eval-mat-workbench-20261113-" + request["publication_commit"][:12], "Tag differs from publication child")
    require(request["release_name"] == "CyberSand Materials Lab + Workbench evaluation — 2026-11-13", "Unexpected release title")
    require(hashlib.sha256(notes).hexdigest() == request["acceptance_sha256"], "Acceptance notes changed")
    require(b"PENDING" not in notes and b"UNRESOLVED" not in notes, "Acceptance notes still contain unresolved claims")
    gates = request["gate_runs"]
    require(isinstance(gates, dict) and set(gates) == set(GATES), "All four final gates are required")
    for row in gates.values():
        require(isinstance(row, dict) and set(row) == {"run_id", "attempt"} and
                positive(row["run_id"]) and positive(row["attempt"]), "Missing exact final-gate run/attempt")
    require(len({row["run_id"] for row in gates.values()}) == 4, "Final gate run IDs must be distinct")
    return request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class GitHub:
    def __init__(self, token: str):
        require(bool(token), "Scoped Actions token is unavailable")
        self.token = token
        self.opener = urllib.request.build_opener(NoRedirect())

    def _open(self, url: str, *, method="GET", data=None, authenticated=True, accept="application/vnd.github+json"):
        parsed = urllib.parse.urlsplit(url)
        require(parsed.scheme == "https" and parsed.username is None and parsed.password is None, "Unsafe download URL")
        if authenticated:
            require(url.startswith(API_ROOT + "/"), "Refuse credential forwarding outside the repository API")
        headers = {"Accept": accept, "User-Agent": "CyberSand-evaluation-release", "X-GitHub-Api-Version": API_VERSION}
        if authenticated:
            headers["Authorization"] = "Bearer " + self.token
        if data is not None:
            headers["Content-Type"] = "application/json"
        return self.opener.open(urllib.request.Request(url, data=data, headers=headers, method=method), timeout=300)

    def call(self, path: str, *, method="GET", data=None, missing=False):
        require(path.startswith("/") and not path.startswith("//"), "Expected repository-relative API path")
        try:
            with self._open(API_ROOT + path, method=method, data=None if data is None else canonical(data)) as response:
                raw = response.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            if missing and error.code == 404:
                return None
            raise RuntimeError(f"GitHub {method} {path.split('?')[0]} returned HTTP {error.code}") from None

    def pages(self, path: str, key: str | None = None) -> list:
        rows = []
        for page in range(1, 101):
            value = self.call(path + ("&" if "?" in path else "?") + f"per_page=100&page={page}")
            batch = value[key] if key else value
            require(isinstance(batch, list), "Malformed paginated API response")
            rows.extend(batch)
            if len(batch) < 100:
                return rows
        raise RuntimeError("Unexpectedly large API inventory")

    def download(self, path: str, output: Path) -> None:
        require(not output.exists(), "Refuse to replace downloaded evidence")
        url, authenticated = API_ROOT + path, True
        for _ in range(6):
            try:
                with self._open(url, authenticated=authenticated, accept="application/octet-stream") as response:
                    with output.open("xb") as stream:
                        shutil.copyfileobj(response, stream, length=1024 * 1024)
                return
            except urllib.error.HTTPError as error:
                require(error.code in (301, 302, 303, 307, 308) and error.headers.get("Location"),
                        "Artifact or release asset download failed")
                url = urllib.parse.urljoin(url, error.headers["Location"])
                authenticated = False  # Never forward the token to a signed storage URL.
        raise RuntimeError("Too many artifact redirects")

    def upload(self, release: dict, path: Path) -> dict:
        url = release["upload_url"].split("{")[0]
        parsed = urllib.parse.urlsplit(url)
        expected = f"/repos/{REPO}/releases/{release['id']}/assets"
        require(parsed.scheme == "https" and parsed.netloc == "uploads.github.com" and parsed.path == expected and
                not parsed.query and not parsed.fragment, "Unexpected asset upload destination")
        connection = http.client.HTTPSConnection("uploads.github.com", timeout=300)
        try:
            connection.putrequest("POST", parsed.path + "?" + urllib.parse.urlencode({"name": path.name}))
            for name, value in {"Authorization": "Bearer " + self.token, "Accept": "application/vnd.github+json",
                                "X-GitHub-Api-Version": API_VERSION, "Content-Type": "application/octet-stream",
                                "Content-Length": str(path.stat().st_size), "User-Agent": "CyberSand-evaluation-release"}.items():
                connection.putheader(name, value)
            connection.endheaders()
            with path.open("rb") as stream:
                while chunk := stream.read(1024 * 1024):
                    connection.send(chunk)
            response = connection.getresponse()
            raw = response.read()
            require(response.status == 201, f"Release asset upload returned HTTP {response.status}")
            return json.loads(raw)
        finally:
            connection.close()


def check_jobs(workflow: str, jobs: list, required: set[str], godot_counts=None) -> None:
    names = [job.get("name") for job in jobs]
    require(len(names) == len(set(names)), "Duplicate workflow job names")
    by_name = dict(zip(names, jobs))
    require(required <= set(names), "Required actual jobs are missing: " + workflow)
    for job in jobs:
        require(job.get("status") == "completed" and job.get("conclusion") in {"success", "skipped"},
                "Workflow contains failed or unfinished jobs: " + workflow)
    for name in required:
        require(by_name[name]["conclusion"] == "success", "Required job was skipped: " + name)
    if workflow == "palette-shader-qualification.yml":
        cohort = [name for name in names if name.startswith(("linux (", "windows ("))]
        require(len(cohort) == 6 and all(sum(name.startswith(prefix) for name in cohort) == 1
                for prefix in PALETTE_PREFIXES), "Missing or duplicate Palette matrix cohort")
        require(all(by_name[name]["conclusion"] == "success" for name in cohort), "Palette matrix did not execute successfully")
    if workflow == "gdextension.yml":
        require(godot_counts and set(godot_counts) == {"linux", "windows"}, "Missing source-derived Godot matrix")
        for platform, count in godot_counts.items():
            prefix = "linux regression shard " if platform == "linux" else "windows headless regression shard "
            cohort = {name for name in names if name.startswith(prefix)}
            expected = {prefix + str(index) for index in range(count)}
            require(cohort == expected and all(by_name[name]["conclusion"] == "success" for name in cohort),
                    "Incomplete actual Godot shard cohort: " + platform)


def check_run(api: GitHub, workflow: str, run_id: int, attempt: int, head: str, event: str,
              required: set[str], godot_counts=None) -> dict:
    run = api.call(f"/actions/runs/{run_id}")
    expected_workflow = api.call("/actions/workflows/" + workflow)
    require(run.get("id") == run_id and run.get("run_attempt") == attempt and run.get("head_sha") == head and
            run.get("head_branch") == INTEGRATION_BRANCH and run.get("event") == event and
            run.get("path") == ".github/workflows/" + workflow and run.get("workflow_id") == expected_workflow.get("id") and
            run.get("repository", {}).get("full_name") == REPO and run.get("status") == "completed" and
            run.get("conclusion") == "success", "Exact completed workflow identity is missing: " + workflow)
    jobs = api.pages(f"/actions/runs/{run_id}/attempts/{attempt}/jobs", "jobs")
    check_jobs(workflow, jobs, required, godot_counts)
    return {"id": run_id, "attempt": attempt, "head_sha": head, "url": run["html_url"],
            "workflow": workflow, "jobs": [{key: row[key] for key in ("id", "name", "status", "conclusion")} for row in jobs]}


def check_scope(api: GitHub, request: dict, release_head: str) -> None:
    for branch, expected in (("main", ACCEPTED_MAIN), (INTEGRATION_BRANCH, request["publication_commit"]),
                             (RELEASE_BRANCH, release_head)):
        ref = api.call("/git/ref/heads/" + urllib.parse.quote(branch, safe="/"))
        require(ref.get("object", {}).get("type") == "commit" and ref["object"]["sha"] == expected,
                "Live branch lease changed: " + branch)
    pr = api.call("/pulls/564")
    require(pr.get("head", {}).get("sha") == WORKBENCH_HEAD, "Latest Workbench source changed")


def check_local(request: dict) -> dict:
    import mat_workbench_runtime_publication as publication
    import godot_job_plan
    engine = publication.engine
    head = git("rev-parse", "HEAD").decode().strip()
    source, published = request["source_commit"], request["publication_commit"]
    expected_env = {"GITHUB_REPOSITORY": REPO, "GITHUB_EVENT_NAME": "push", "GITHUB_REF": "refs/heads/" + RELEASE_BRANCH,
                    "GITHUB_SHA": head, "GITHUB_WORKFLOW_REF": REPO + "/" + WORKFLOW + "@refs/heads/" + RELEASE_BRANCH}
    require(all(os.environ.get(key) == value for key, value in expected_env.items()), "Unexpected release workflow context")
    require(git("status", "--porcelain", "--untracked-files=no") == b"", "Release checkout has tracked modifications")
    require(git("rev-parse", "--is-shallow-repository").strip() == b"false", "Complete source ancestry is required")
    require(git("rev-list", "--parents", "-n", "1", published).decode().strip() == published + " " + source,
            "Runtime publication must be the direct single-parent source child")
    require(git("rev-list", "--parents", "-n", "1", head).decode().strip() == head + " " + published,
            "Release apparatus must directly append to the qualified publication child")
    added = git("diff", "--name-status", "--no-renames", published, head).decode().splitlines()
    require(set(added) == {"A\t" + name for name in APPARATUS}, "Release branch may add only its four reviewed apparatus files")
    changed = set(git("diff", "--name-only", "--no-renames", source, published).decode().splitlines())
    require(changed <= set(engine.RUNTIMES.values()) | set(engine.MANIFESTS.values()) and
            set(engine.MANIFESTS.values()) <= changed, "Publication changed application source or omitted provenance")
    require(git("rev-parse", source + "^{tree}").decode().strip() == request["source_tree"], "Frozen source tree changed")
    for ancestor in (ACCEPTED_MAIN, WORKBENCH_HEAD, CAPABILITY_TRANSITION):
        require(subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", ancestor, source],
                               timeout=300, check=False).returncode == 0, "Source lacks required accepted ancestry")
    source_request = json.loads(git("show", source + ":tools/ci/mat_workbench_publish_request.json"))
    require(source_request.get("request_sequence") == request["request_sequence"], "Publication request sequence changed")
    ledgers = engine.input_ledgers(source)
    require(len(ledgers["source_inputs"]) == 89 and len(ledgers["build_inputs"]) == 841, "Frozen source inventory changed")
    manifests = {}
    for platform in ("linux", "windows"):
        manifest = json.loads(git("show", published + ":" + engine.MANIFESTS[platform]))
        pointer = git("show", published + ":" + engine.RUNTIMES[platform])
        match = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", pointer)
        require(match and match[1].decode() == request[platform + "_native_sha256"] == manifest.get("sha256") and
                int(match[2]) == manifest.get("size"), "Published runtime pointer differs from reviewed native bytes")
        expected = {"source_commit": source, "build_commit": source, "source_tree": request["source_tree"],
                    "status": "validated-development-runtime", "platform": platform, **ledgers,
                    "workflow_run": f"https://github.com/{REPO}/actions/runs/{request['publisher_run_id']}",
                    "workflow_attempt": str(request["publisher_attempt"]), "artifact": engine.RUNTIMES[platform]}
        require(all(manifest.get(key) == value for key, value in expected.items()), "Published provenance identity differs: " + platform)
        require(all(hex_value(manifest.get(key), 64) for key in
                    ("validation_sha256", "materials_lab_catalogue_suite_sha256", "materials_lab_graphical_sha256", "mat_workbench_execution_sha256")),
                "Published provenance lacks complete source-platform execution receipts")
        manifests[platform] = manifest
    cases = godot_job_plan.runner.discover_cases()
    counts = {platform: godot_job_plan.plan([case for case in cases if platform == "linux" or not case.requires_display],
                                          platform=platform)["shard_count"] for platform in ("linux", "windows")}
    return {"release_head": head, "manifests": manifests, "godot_counts": counts, "source_inputs": 89, "build_inputs": 841}


def check_artifact(row: dict, request: dict) -> None:
    expected_name = f"mat-workbench-windows-evaluation-{request['source_commit']}-{request['publisher_run_id']}-{request['publisher_attempt']}"
    require(row.get("id") == request["evaluation_artifact_id"] and row.get("name") == expected_name and
            row.get("expired") is False and positive(row.get("size_in_bytes")) and
            row.get("digest") == "sha256:" + request["artifact_outer_sha256"] and
            row.get("workflow_run", {}).get("id") == request["publisher_run_id"] and
            row["workflow_run"].get("head_sha") == request["source_commit"], "Evaluation artifact custody differs")


def check_dispatch(raw: bytes, request: dict) -> dict:
    receipt = json.loads(raw)
    expected = {"schema": "materials-lab-existing-gates-dispatch-v1", "source_commit": request["source_commit"],
                "published_commit": request["publication_commit"], "request_sequence": request["request_sequence"],
                "workflow_run": f"https://github.com/{REPO}/actions/runs/{request['publisher_run_id']}",
                "workflow_attempt": str(request["publisher_attempt"]), "status": "requested", "completed": True,
                "requests": [{"workflow": name, "status": "accepted", "head_sha": request["publication_commit"]} for name in GATES]}
    require(all(receipt.get(key) == value for key, value in expected.items()), "Original final-gate dispatch receipt differs")
    return receipt


def check_online(api: GitHub, request: dict, local: dict, temporary: Path) -> dict:
    check_scope(api, request, local["release_head"])
    publisher = check_run(api, PUBLISH_WORKFLOW, request["publisher_run_id"], request["publisher_attempt"],
                          request["source_commit"], "push", PUBLISH_JOBS)
    gates = [check_run(api, workflow, request["gate_runs"][workflow]["run_id"], request["gate_runs"][workflow]["attempt"],
                       request["publication_commit"], "workflow_dispatch", GATE_JOBS[workflow], local["godot_counts"]) for workflow in GATES]
    artifacts = api.pages(f"/actions/runs/{request['publisher_run_id']}/artifacts", "artifacts")
    rows = [row for row in artifacts if row.get("id") == request["evaluation_artifact_id"]]
    require(len(rows) == 1, "Evaluation artifact is absent from the successful publisher")
    check_artifact(rows[0], request)
    receipt_name = f"mat-workbench-existing-gates-{request['publisher_run_id']}-{request['publisher_attempt']}"
    receipts = [row for row in artifacts if row.get("name") == receipt_name]
    require(len(receipts) == 1 and receipts[0].get("expired") is False and
            receipts[0].get("workflow_run", {}).get("head_sha") == request["source_commit"], "Original dispatch artifact is missing")
    receipt = receipts[0]
    require(isinstance(receipt.get("digest"), str) and re.fullmatch(r"sha256:[0-9a-f]{64}", receipt["digest"]),
            "Dispatch artifact is missing its service digest")
    path = temporary / "dispatch.zip"
    api.download(f"/actions/artifacts/{receipt['id']}/zip", path)
    require("sha256:" + digest(path) == receipt["digest"], "Dispatch artifact bytes changed")
    with zipfile.ZipFile(path) as archive:
        require(archive.namelist() == ["mat-workbench-existing-gates.json"], "Unexpected dispatch archive contents")
        dispatch = check_dispatch(archive.read(archive.namelist()[0]), request)
    return {"publisher": publisher, "gates": gates, "artifact": rows[0], "dispatch": dispatch}


def package_assets(outer: Path, destination: Path, request: dict, notes: bytes) -> list[Path]:
    require(digest(outer) == request["artifact_outer_sha256"], "Actions archive differs from independently reviewed bytes")
    names = [request["archive_name"], request["archive_name"] + ".sha256"]
    with zipfile.ZipFile(outer) as archive:
        require(len(archive.infolist()) == 2 and set(archive.namelist()) == set(names), "Evaluation artifact must contain only original ZIP and checksum")
        for name in names:
            with archive.open(name) as source, (destination / name).open("xb") as target:
                shutil.copyfileobj(source, target, length=1024 * 1024)
    inner, checksum = (destination / name for name in names)
    record = (request["archive_sha256"] + "  " + inner.name).encode("ascii")
    # The Windows producer's Path.write_text uses CRLF; retain its exact bytes.
    # Admit only one correct record with the producer's LF or CRLF terminator.
    require(digest(inner) == request["archive_sha256"] and
            checksum.read_bytes() in (record + b"\n", record + b"\r\n"),
            "Original evaluation ZIP or checksum differs from independent review")
    with zipfile.ZipFile(inner) as archive:
        files = [entry for entry in archive.infolist() if not entry.is_dir()]
        file_names = [entry.filename for entry in files]
        require(len(file_names) == len(set(file_names)), "Duplicate packaged file paths")
        for entry in files:
            path = PurePosixPath(entry.filename)
            require(not path.is_absolute() and ".." not in path.parts and "\\" not in entry.filename and
                    (entry.external_attr >> 16) & 0o170000 != 0o120000, "Unsafe packaged path")
        manifest = json.loads(archive.read("materials-lab-evaluation.json"))
        require(manifest.get("schema") == "cybersand-materials-lab-evaluation-v1" and manifest.get("platform") == "windows" and
                manifest.get("source_commit") == request["source_commit"] and manifest.get("source_tree") == request["source_tree"] and
                manifest.get("native_sha256") == request["windows_native_sha256"] and
                manifest.get("source_history", {}).get("source_commit") == request["source_commit"] and
                manifest.get("integration_scope") == "MAT-AUTH #562 + Integrated Workbench #564" and
                manifest.get("runtime_active_candidates") is False, "Delivered application identity differs")
        inventory = manifest.get("files_sha256")
        require(isinstance(inventory, dict) and set(inventory) == set(file_names) - {"materials-lab-evaluation.json"},
                "Delivered file inventory is incomplete")
        for name, expected in inventory.items():
            with archive.open(name) as stream:
                require(hashlib.file_digest(stream, "sha256").hexdigest() == expected, "Packaged file differs: " + name)
        required = {"Open Workbench.cmd", "Open-Materials-Lab.cmd", "README.txt", "Godot-LICENSE.txt", "Godot-COPYRIGHT.txt",
                    "source/.git/HEAD", "source/LICENSE_STATUS.md", "source/THIRD_PARTY_NOTICES.md",
                    "dependencies/python/python.exe", "dependencies/python/LICENSE.txt", "dependencies/git/cmd/git.exe",
                    "dependencies/git/LICENSE.txt", "dependencies/cxx/bin/g++.exe"}
        require(required <= set(file_names), "Standalone application lost history, tools, launchers or notices")
        require(archive.read("source/.git/HEAD").decode().strip() == request["source_commit"], "Delivered source HEAD differs")
        config = archive.read("source/.git/config").decode().lower()
        require(not any(word in config for word in ("[remote", "[http", "[credential", "[include", "[url")),
                "Delivered repository retained external or credential configuration")
        require(not any(name.startswith("source/.git/hooks/") for name in file_names), "Delivered repository retained hooks")
        for name in ("LICENSE_STATUS.md", "THIRD_PARTY_NOTICES.md"):
            require(archive.read("source/" + name) == git("show", request["source_commit"] + ":" + name), "Source notice changed")
        native = "source/godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
        require(inventory.get(native) == request["windows_native_sha256"], "Delivered native DLL differs")
        provenance = "godot/addons/cybersand_native/runtime-provenance.json"
        require(archive.read("source/" + provenance) == git("show", request["publication_commit"] + ":" + provenance),
                "Packaged Windows provenance differs from the publication child")
    acceptance = destination / Path(NOTES).name
    acceptance.write_bytes(notes)
    return [inner, checksum, acceptance]


def verify_remote_assets(api: GitHub, release: dict, assets: list[Path], temporary: Path) -> dict:
    rows = api.pages(f"/releases/{release['id']}/assets")
    require(len(rows) == len(assets) and {row["name"] for row in rows} == {path.name for path in assets},
            "Remote release has missing, extra or duplicate assets")
    records = {}
    for path in assets:
        row = next(row for row in rows if row["name"] == path.name)
        require(row.get("state") == "uploaded" and row.get("size") == path.stat().st_size and
                row.get("digest") == "sha256:" + digest(path), "Remote asset digest/size differs: " + path.name)
        if path.suffix != ".zip":
            remote = temporary / ("readback-" + str(row["id"]) + "-" + str(len(list(temporary.glob('readback-*')))))
            api.download(f"/releases/assets/{row['id']}", remote)
            require(remote.read_bytes() == path.read_bytes(), "Remote checksum or acceptance text differs")
        records[path.name] = {key: row[key] for key in ("id", "size", "digest", "browser_download_url")}
    return records


def verify_tag(api: GitHub, request: dict, *, create=False) -> None:
    path = "/git/ref/tags/" + request["tag"]
    ref = api.call(path, missing=True)
    if ref is None and create:
        api.call("/git/refs", method="POST", data={"ref": "refs/tags/" + request["tag"], "sha": request["publication_commit"]})
        ref = api.call(path)
    require(ref is not None and ref.get("object", {}).get("type") == "commit" and
            ref["object"].get("sha") == request["publication_commit"], "Release tag does not target the exact publication child")


def publish(api: GitHub, request: dict, notes: bytes, assets: list[Path], local: dict,
            temporary: Path, report: dict, checkpoint) -> dict:
    check_scope(api, request, local["release_head"])
    tag = request["tag"]
    require(api.call("/git/ref/tags/" + tag, missing=True) is None and
            api.call("/releases/tags/" + tag, missing=True) is None and
            all(row.get("tag_name") != tag for row in api.pages("/releases")), "Refuse any existing tag or release; never overwrite")
    latest = api.call("/releases/latest", missing=True)
    release = api.call("/releases", method="POST", data={"tag_name": tag, "target_commitish": request["publication_commit"],
                       "name": request["release_name"], "body": notes.decode("utf-8"), "draft": True,
                       "prerelease": True, "make_latest": "false"})
    require(release.get("draft") is True and release.get("prerelease") is True and release.get("tag_name") == tag,
            "Unexpected draft release identity")
    report.update(status="draft-created", release_id=release["id"])
    checkpoint()
    require(api.pages(f"/releases/{release['id']}/assets") == [], "New draft already contains assets")
    for path in assets:
        api.upload(release, path)
        report.update(status="uploading", last_uploaded_asset=path.name)
        checkpoint()
    report["assets"] = verify_remote_assets(api, release, assets, temporary)
    report["final_admission"] = check_online(api, request, local, temporary / "final-admission")
    verify_tag(api, request, create=True)
    check_scope(api, request, local["release_head"])
    api.call(f"/releases/{release['id']}", method="PATCH", data={"draft": False, "prerelease": True, "make_latest": "false"})
    published = api.call(f"/releases/{release['id']}")
    require(published.get("draft") is False and published.get("prerelease") is True and published.get("published_at") and
            published.get("tag_name") == tag and published.get("target_commitish") == request["publication_commit"] and
            published.get("body") == notes.decode("utf-8"), "Public prerelease readback differs")
    verify_tag(api, request)
    report["assets"] = verify_remote_assets(api, published, assets, temporary)
    now_latest = api.call("/releases/latest", missing=True)
    require(now_latest is None or now_latest.get("id") != release["id"], "Evaluation unexpectedly became latest")
    if latest is not None:
        require(now_latest is not None and now_latest.get("id") == latest.get("id"), "Latest release changed during evaluation publication")
    report.update(status="published", completed=True, release_url=published["html_url"], tag=tag,
                  publication_commit=request["publication_commit"], source_commit=request["source_commit"])
    checkpoint()
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publish", action="store_true", help="Create the reviewed draft, verify all assets, then publish its prerelease")
    parser.add_argument("--output", type=Path, default=ROOT / "build/mat-workbench-evaluation-release/receipt.json")
    args = parser.parse_args()
    require(not args.output.exists(), "Refuse to replace an earlier release receipt")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    report = {"schema": SCHEMA, "status": "preflight", "completed": False}
    def checkpoint():
        args.output.write_bytes(canonical(report))
    checkpoint()
    try:
        notes = (ROOT / NOTES).read_bytes()
        request = check_request(json.loads((ROOT / REQUEST).read_text(encoding="utf-8")), notes)
        local = check_local(request)
        api = GitHub(os.environ.get("GH_TOKEN", ""))
        with tempfile.TemporaryDirectory(prefix="cybersand-evaluation-release-") as temporary_name:
            temporary = Path(temporary_name)
            (temporary / "final-admission").mkdir()
            report["admission"] = check_online(api, request, local, temporary)
            outer = temporary / "original-actions-artifact.zip"
            api.download(f"/actions/artifacts/{request['evaluation_artifact_id']}/zip", outer)
            require(outer.stat().st_size == report["admission"]["artifact"]["size_in_bytes"], "Actions artifact size differs")
            assets = package_assets(outer, temporary, request, notes)
            report.update(status="verified", source_commit=request["source_commit"], publication_commit=request["publication_commit"],
                          package_sha256=request["archive_sha256"], release_head=local["release_head"])
            checkpoint()
            if args.publish:
                publish(api, request, notes, assets, local, temporary, report, checkpoint)
        print(json.dumps({key: report[key] for key in ("status", "completed", "source_commit", "publication_commit") if key in report}))
        return 0
    except Exception as error:
        report.update(status="failed", completed=False, error=str(error))
        checkpoint()
        raise


if __name__ == "__main__":
    raise SystemExit(main())
