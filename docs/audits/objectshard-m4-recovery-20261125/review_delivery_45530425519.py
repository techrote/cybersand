#!/usr/bin/env python3
"""Read-only, one-run ObjectShard M4 artifact audit; no application execution.

The application, package and native build remain source 5f0722ae. The audit
checkout is separately identified and never substituted into producer receipts.
Authenticated GitHub requests never follow a redirect; the signed download is
opened separately without an Authorization header.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

REPO = "techrote/cybersand"
REPO_ID = 1350077435
RUN = 45530425519
ATTEMPT = 1
SOURCE = "5f0722ae231d955a98a83b0fbb9a0e7517ef2d8a"
TREE = "51ff1e6a0949dff3b2b17cdca7a40d4943b05f78"
AUDIT_BASE = Path("docs/audits/objectshard-m4-recovery-20261125")
INVENTORY_SHA = "a7ac44da9d6915574dab0900449efe88acdcd29417e68795e2bfd8dac74ad100"
JOBS = {"linux-workbench": 138924056891, "windows-native": 138924057296,
        "native-sanitizers": 138924057320, "windows-workbench": 138926161028}
REVIEWER_BLOBS = {
    "review_native_candidate.py": "901fb005072aaf29374277c31938b851488f7c4a",
    "review_windows_native.py": "60bbe74a9907f96085b2d7cdb6357825b23437d4",
    "review_workbench_evidence.py": "90eba97b9b297b24f28866470cd053db9d3f9de1",
    "inspect_windows_evaluator.py": "42c6bbdf8567929204604cec51c3d9c31e75a8c4",
}
KNOWN_ARTIFACTS = {
    "workbench-evaluator": (14986488170, 93044387,
                          "5eee64f2147efe057a0768eb39476ec8730dae7dd133480c46ed4911a09f1f2a"),
    "linux": (14986462220, 14264606,
              "3f745a25db44992edb8f2d2d889fff77d319f2273c583663c0b5c9c4eba94743"),
    "windows": (14986123965, 39179166,
                "e9621d53c45fb649738c6b3c8572dc76c1a90fa4f020131967ff536d86e54468"),
    "native": (14985522687, 135240202,
               "e4928403e5fd033768f50cfde4a576aef4475eae1d895d67f5156ed79e6ad7e7"),
    "dll": (14984556771, 2265508,
            "12563fa3c449963ad1adf04bc7dbb701c61777e18a823607d1e60b9815820a1c"),
    "crossbuild": (14984426850, 8810,
                  "b40d49dec15665919de07f8ebdf33e9cc016d02447b549754dd207080f7ae4aa"),
}
DLL_SHA = "cfd75fcdcc252ab8b6b42fba1e0c78182517db6142b89a261a5b881eaff047c4"
GODOT_URL = ("https://github.com/godotengine/godot-builds/releases/download/"
             "4.7-stable/Godot_v4.7-stable_win64.exe.zip")
GODOT_BYTES = 83764371
GODOT_SHA = "02a5312236f4e0209c78bcb2f52135b1963e6b8888c873c9cee81459e60bcd71"
GODOT_SHA512 = ("41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d1428"
                "14f3e6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9")
CONSOLE_SHA = "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c"
RAPIER_SHA = "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"
PARITY_PATHS = {
    "materials/catalogue/catalogue.json",
    "materials/catalogue/generated/catalogue.shadow.hpp",
    "materials/catalogue/generated/catalogue_shadow.gd",
    "materials/catalogue/generated/inspection.json",
    "materials/catalogue/compatibility-lock.json",
    "tools/material_catalogue/native_oracle.cpp",
    "tools/material_catalogue/check_native_parity.py",
    "tools/material_catalogue/compatibility.py",
}
PARITY_BASELINE = "0fd4af5987e77db4da3e37c757cf2c0917ae9e15"
INNER_NAME = "objectshard-workbench-evaluator.zip"


def need(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_digest(path: Path, algorithm: str = "sha256") -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def save(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n",
                    encoding="utf-8")


def git(repo: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(repo), *args], timeout=120)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        return None


class HTTPSOnlyRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        parsed = urllib.parse.urlsplit(new_url)
        need(parsed.scheme == "https" and parsed.hostname and not parsed.username
             and not parsed.password, "Refused unsafe unauthenticated download redirect")
        return super().redirect_request(request, fp, code, message, headers, new_url)


def api(path: str, *, redirect: bool = False) -> bytes | str:
    need(path.startswith("/repos/" + REPO + "/"), "Unexpected authenticated API scope")
    token = os.environ.get("GITHUB_TOKEN", "")
    need(bool(token), "Read-only GitHub token is unavailable")
    request = urllib.request.Request("https://api.github.com" + path, headers={
        "Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "cybersand-m4-independent-audit",
    })
    opener = urllib.request.build_opener(NoRedirect())
    for attempt in range(3):
        try:
            with opener.open(request, timeout=60) as response:
                need(not redirect, "Artifact endpoint did not supply its expected download redirect")
                raw = response.read(8 * 1024 * 1024 + 1)
                need(len(raw) <= 8 * 1024 * 1024, "Unexpectedly large API response")
                return raw
        except urllib.error.HTTPError as error:
            if redirect and error.code == 302:
                target = error.headers.get("Location", "")
                error.close()
                parsed = urllib.parse.urlsplit(target)
                need(parsed.scheme == "https" and parsed.hostname and not parsed.username
                     and not parsed.password, "Refused unsafe signed download URL")
                return target
            retry = error.code in {429, 500, 502, 503, 504}
            error.close()
            if not retry or attempt == 2:
                raise RuntimeError("GitHub metadata request failed") from None
        except (OSError, TimeoutError, urllib.error.URLError):
            if attempt == 2:
                raise RuntimeError("GitHub metadata request failed") from None
        time.sleep(2)
    raise RuntimeError("GitHub metadata retries exhausted")


def download(url: str, output: Path, *, limit: int, seconds: int = 1200) -> None:
    """Unauthenticated bounded transfer; signed URLs and tokens are never logged."""
    parsed = urllib.parse.urlsplit(url)
    need(parsed.scheme == "https" and parsed.hostname and not parsed.username
         and not parsed.password, "Expected a safe HTTPS download")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".partial")
    deadline = time.monotonic() + seconds
    opener = urllib.request.build_opener(HTTPSOnlyRedirect())
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "cybersand-m4-independent-audit"})
            with opener.open(request, timeout=60) as source, temporary.open("wb") as target:
                size = 0
                while block := source.read(1024 * 1024):
                    need(time.monotonic() <= deadline, "Download exceeded the dependency allowance")
                    size += len(block)
                    need(size <= limit, "Download exceeded its expected byte bound")
                    target.write(block)
            temporary.replace(output)
            return
        except (OSError, TimeoutError, urllib.error.URLError):
            temporary.unlink(missing_ok=True)
            if attempt == 2 or time.monotonic() >= deadline:
                raise RuntimeError("Unauthenticated artifact/dependency download failed") from None
            time.sleep(2)
    raise RuntimeError("Download retries exhausted")


def metadata(output: Path) -> tuple[dict, dict, dict, dict]:
    documents = {}
    for label, suffix in (
        ("run", f"/actions/runs/{RUN}"),
        ("jobs", f"/actions/runs/{RUN}/jobs?filter=latest&per_page=100"),
        ("artifacts", f"/actions/runs/{RUN}/artifacts?per_page=100"),
    ):
        raw = api("/repos/" + REPO + suffix)
        need(isinstance(raw, bytes), "API metadata was redirected")
        path = output / "metadata" / (label + ".json")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
        documents[label] = json.loads(raw)
    run, jobs, artifacts = (documents[k] for k in ("run", "jobs", "artifacts"))
    need(run["id"] == RUN and run["run_attempt"] == ATTEMPT
         and run["head_sha"] == SOURCE and run["repository"]["id"] == REPO_ID
         and run["head_repository"]["id"] == REPO_ID
         and run["repository"]["full_name"] == REPO
         and run["path"] == ".github/workflows/objectshard-m4-completion.yml",
         "Original workflow/source/repository/attempt identity differs")
    need(run["status"] == "completed" and run["conclusion"] == "success",
         "Original application qualification is not terminal PASS")
    need(jobs["total_count"] == len(jobs["jobs"]) == len(JOBS), "Incomplete original job inventory")
    need({job["name"] for job in jobs["jobs"]} == set(JOBS), "Unexpected original jobs")
    for job in jobs["jobs"]:
        need(job["id"] == JOBS[job["name"]] and job["run_id"] == RUN
             and job["run_attempt"] == ATTEMPT and job["head_sha"] == SOURCE
             and job["status"] == "completed" and job["conclusion"] == "success",
             "Original producer job is not exact-source terminal PASS: " + job["name"])
    need(artifacts["total_count"] == len(artifacts["artifacts"]), "Truncated artifact inventory")
    selected = {}
    for kind in ("native", "dll", "crossbuild", "linux", "windows", "workbench-evaluator"):
        name = f"objectshard-m4-{kind}-{SOURCE}-{RUN}"
        matches = [row for row in artifacts["artifacts"] if row["name"] == name]
        need(len(matches) == 1, "Missing/ambiguous original artifact: " + kind)
        row = matches[0]
        workflow = row["workflow_run"]
        need(row["expired"] is False and type(row["size_in_bytes"]) is int
             and row["size_in_bytes"] > 0
             and re.fullmatch(r"sha256:[0-9a-f]{64}", row["digest"])
             and workflow["id"] == RUN and workflow["head_sha"] == SOURCE
             and workflow["repository_id"] == workflow["head_repository_id"] == REPO_ID,
             "Invalid external artifact identity: " + kind)
        if kind in KNOWN_ARTIFACTS:
            expected = KNOWN_ARTIFACTS[kind]
            need((row["id"], row["size_in_bytes"], row["digest"][7:]) == expected,
                 "Previously independently pinned artifact differs: " + kind)
        selected[kind] = row
    return run, jobs, artifacts, selected


def raw_artifact(row: dict, output: Path) -> dict:
    target = api(f"/repos/{REPO}/actions/artifacts/{row['id']}/zip", redirect=True)
    need(isinstance(target, str), "Artifact download URL was not received")
    download(target, output, limit=row["size_in_bytes"])
    observed = {"bytes": output.stat().st_size, "sha256": file_digest(output)}
    need(observed["bytes"] == row["size_in_bytes"] and "sha256:" + observed["sha256"] == row["digest"],
         "Original outer artifact ZIP differs from fresh GitHub size/digest")
    with zipfile.ZipFile(output) as archive:
        need(archive.testzip() is None, "Original outer artifact ZIP failed CRC")
    return {"id": row["id"], "name": row["name"], **observed,
            "url": f"https://github.com/{REPO}/actions/runs/{RUN}/artifacts/{row['id']}"}


def extract_inner(outer: Path, inner: Path) -> None:
    with zipfile.ZipFile(outer) as archive:
        rows = archive.infolist()
        need(len(rows) == 1 and rows[0].filename == INNER_NAME and not rows[0].is_dir()
             and not stat.S_ISLNK(rows[0].external_attr >> 16),
             "Evaluator artifact must contain only the original principal ZIP")
        count = 0
        with archive.open(rows[0]) as source, inner.open("wb") as target:
            while block := source.read(1024 * 1024):
                count += len(block)
                need(count <= rows[0].file_size, "Unexpected inner ZIP length")
                target.write(block)
        need(count == rows[0].file_size, "Actual inner ZIP length differs")


def parity(archive_path: Path, candidate: Path) -> dict:
    with zipfile.ZipFile(archive_path) as archive:
        raw = archive.read("material-native-parity.json")
    p = json.loads(raw)
    need(p["schema_id"] == "cybersand.material-catalogue.native-parity"
         and type(p["schema_version"]) is int and p["schema_version"] == 1
         and p["status"] == p["compiled_queries"]["status"] == "PASS"
         and p["native_authored_compiled_shadow_facts_equal"] is True
         and p["world_executed"] is p["godot_executed"] is p["physics_qualification"] is False,
         "Material compatibility parity report is incomplete or has the wrong scope")
    rows = p["inputs"] + p["tool_sources"]
    need(len(p["inputs"]) == 5 and len(p["tool_sources"]) == 3
         and len(rows) == len({r["path"] for r in rows}) == 8
         and {r["path"] for r in rows} == PARITY_PATHS, "Incomplete material parity input registry")
    for row in rows:
        exact = git(candidate, "show", SOURCE + ":" + row["path"])
        need(len(exact) == row["bytes"] and digest(exact) == row["sha256"],
             "Material parity frozen source mismatch: " + row["path"])
    need(p["source_commit"] == PARITY_BASELINE, "Historical material compatibility baseline differs")
    return {"status": "passed-independent-eight-input-join", "report_sha256": digest(raw),
            "executed_source": SOURCE, "historical_compatibility_baseline": p["source_commit"],
            "inputs": rows, "compiled_queries": p["compiled_queries"],
            "world_executed": False, "godot_executed": False, "physics_qualification": False}


def package_pe_imports(inner: Path, reports: Path, scratch: Path) -> dict:
    """Static direct-import evidence; core OS classification is an explicit review."""
    rows = []
    candidates, contracts = set(), set()
    compiler_runtime = re.compile(r"(?:vcruntime|msvcp|concrt|libgcc|libstdc\+\+|libwinpthread|msvcr[0-9]|vcomp[0-9]).*\.dll", re.I)
    with zipfile.ZipFile(inner) as archive:
        manifest = json.loads(archive.read("objectshard-workbench-manifest.json"))
        inventory = manifest["files_sha256"]
        dlls = {}
        for name, expected in inventory.items():
            if Path(name).suffix.lower() == ".dll":
                dlls.setdefault(Path(name).name.lower(), []).append({"path": name, "sha256": expected})
        targets = [manifest["native"]["path"], manifest["rapier"]["path"], "vcruntime140.dll",
                   "Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe"]
        for index, member in enumerate(targets):
            staged = scratch / ("pe-%d-" % index + Path(member).name)
            with archive.open(member) as source, staged.open("wb") as output:
                while block := source.read(1024 * 1024):
                    output.write(block)
            need(file_digest(staged) == inventory[member], "Static import inspector input differs from verified package")
            table = reports / ("pe-%d-imports.txt" % index)
            with table.open("wb") as output:
                subprocess.run(["objdump", "-p", str(staged)], stdout=output, stderr=subprocess.STDOUT,
                               check=True, timeout=120)
            names = re.findall(r"DLL Name:\s*(\S+)", table.read_text(encoding="utf-8", errors="strict"))
            need(bool(names), "Static PE inspector did not report any direct imports")
            resolved = []
            for name in sorted(set(names), key=str.lower):
                need(re.fullmatch(r"[A-Za-z0-9_.+-]+\.dll", name, re.I), "Unsafe PE import basename")
                key = name.lower()
                matches = dlls.get(key, [])
                if matches:
                    need(len(matches) == 1, "Ambiguous package-local DLL basename")
                    resolved.append({"name": name, "kind": "manifest-declared-package-payload", **matches[0]})
                elif re.fullmatch(r"(?:api|ext)-ms-win-[a-z0-9-]+\.dll", key):
                    contracts.add(key)
                    resolved.append({"name": name, "kind": "named-Windows-API-set-contract"})
                else:
                    need(not compiler_runtime.fullmatch(key),
                         "Required compiler runtime is absent from portable payload: " + name)
                    candidates.add(key)
                    resolved.append({"name": name, "kind": "core-Windows-candidate-requires-concrete-review"})
            rows.append({"member": member, "sha256": inventory[member], "imports": resolved,
                         "original_import_table": table.name, "original_import_table_sha256": file_digest(table)})
    result = {"status": "captured-static-imports-core-OS-classification-pending",
              "source": SOURCE, "images": rows, "core_windows_candidates": sorted(candidates),
              "api_set_contracts": sorted(contracts),
              "scope": "Read-only exact-payload direct PE imports. Named API sets are OS loader contracts, not missing packaged files. "
                       "System32 presence alone is not proof of Windows11 inbox availability. "
                       "Omitted compiler runtime families are refused; remaining concrete names require independent documented OS review."}
    save(reports / "package-pe-imports.json", result)
    return result


BRIDGE_BYTES_USED = 0


def emit_original_bytes(tag: str, identity: dict, raw: bytes, *, image: bool = False) -> None:
    global BRIDGE_BYTES_USED
    key = "png_base64" if image else "base64"
    line = tag + " " + json.dumps({**identity, "bytes": len(raw), "sha256": digest(raw),
                                   key: base64.b64encode(raw).decode("ascii")}, sort_keys=True)
    BRIDGE_BYTES_USED += len(line.encode("utf-8")) + 1
    need(BRIDGE_BYTES_USED <= 4 * 1024 * 1024, "Original-image/report log bridge exceeded its 4 MiB bound")
    print(line, flush=True)


def emit_original_overviews(archive_path: Path, artifact_id: int, reports: Path) -> list[dict]:
    """Five byte-identical final captures for cloud visual inspection."""
    captured = []
    with zipfile.ZipFile(archive_path) as archive:
        report = json.loads(archive.read("graphical/qualification.json"))
        need(report["status"] == "passed" and report["source_commit"] == SOURCE,
             "Original graphical report is not exact-source PASS")
        for scene in ("tower", "viaduct", "timber", "mixed", "stress"):
            case_name = f"m4_workbench_{scene}_overview_render"
            cases = [c for c in report["cases"] if c["name"] == case_name]
            need(len(cases) == 1, "Missing/ambiguous original overview case")
            case = cases[0]
            receipt = case["receipt"]
            need(case["status"] == "passed" and case["requires_display"] is True
                 and receipt["source_commit"] == SOURCE and receipt["scene"] == scene
                 and receipt["camera"] == "overview" and receipt["sampling"] == "cohorts",
                 "Original overview capture scope differs")
            member = f"graphical/{case_name}-artifacts/{scene}-overview.png"
            rows = [i for i in archive.infolist() if i.filename == member]
            need(len(rows) == 1 and not rows[0].is_dir()
                 and 8 <= rows[0].file_size <= 2 * 1024 * 1024,
                 "Original overview PNG is absent, ambiguous or outside its bound")
            raw = archive.read(rows[0])
            need(len(raw) == rows[0].file_size and raw.startswith(b"\x89PNG\r\n\x1a\n"),
                 "Original overview payload is not the bounded PNG")
            identity = {"artifact_id": artifact_id, "member": member, "bytes": len(raw),
                        "sha256": digest(raw), "case": case_name, "source": SOURCE}
            captured.append(identity)
            (reports / (scene + "-overview.png")).write_bytes(raw)
            emit_original_bytes("OBJECTSHARD_M4_ORIGINAL_PNG", identity, raw, image=True)
    return captured


def audit(candidate: Path, auditor: Path, output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    reports = output / "reports"
    reports.mkdir(exist_ok=True)
    scratch = output / "scratch"
    scratch.mkdir(exist_ok=True)
    need(git(candidate, "rev-parse", "HEAD").decode().strip() == SOURCE
         and git(candidate, "rev-parse", "HEAD^{tree}").decode().strip() == TREE,
         "Qualification checkout is not the immutable application source")
    auditor_head = git(auditor, "rev-parse", "HEAD").decode().strip()
    need(auditor_head == os.environ["GITHUB_SHA"], "Audit orchestration checkout differs from audit run")
    reviewers = {}
    for filename, blob in REVIEWER_BLOBS.items():
        path = auditor / AUDIT_BASE / filename
        raw = path.read_bytes()
        actual_blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        need(actual_blob == blob, "Independently reviewed inspector source changed: " + filename)
        reviewers[filename] = {"git_blob": actual_blob, "bytes": len(raw), "sha256": digest(raw)}
    inventory_raw = git(candidate, "show", SOURCE + ":" + (AUDIT_BASE / "registered-workbench-inventory.json").as_posix())
    need(digest(inventory_raw) == INVENTORY_SHA, "Independent frozen inventory changed")
    inventory = json.loads(inventory_raw)
    need({k: len(v) for k, v in inventory.items()} == {"headless": 43, "graphical": 32, "package-replay": 17},
         "Independent frozen inventory scope differs")
    inventory_path = reports / "registered-workbench-inventory.json"
    inventory_path.write_bytes(inventory_raw)
    run, jobs, artifact_metadata, selected = metadata(output)
    raw_paths, custody = {}, {}
    for kind, row in selected.items():
        path = output / "raw" / (kind + ".zip")
        custody[kind] = raw_artifact(row, path)
        raw_paths[kind] = path
    original_logs = {}
    for name, job_id in JOBS.items():
        url = api(f"/repos/{REPO}/actions/jobs/{job_id}/logs", redirect=True)
        need(isinstance(url, str), "Original job log download URL is missing")
        path = output / "job-logs" / (name + ".log")
        download(url, path, limit=64 * 1024 * 1024)
        original_logs[name] = {"job_id": job_id, "bytes": path.stat().st_size, "sha256": file_digest(path)}
    official = output / "raw" / "Godot_v4.7-stable_win64.exe.zip"
    download(GODOT_URL, official, limit=GODOT_BYTES)
    need(official.stat().st_size == GODOT_BYTES and file_digest(official) == GODOT_SHA
         and file_digest(official, "sha512") == GODOT_SHA512, "Official pinned Godot archive differs")
    metadata_path = output / "metadata" / "artifacts.json"

    def inspect(script: str, label: str, extra: list[str]) -> dict:
        report = reports / (label + ".json")
        command = [sys.executable, str(auditor / AUDIT_BASE / script), *extra, "--output", str(report)]
        with (reports / (label + "-inspector.log")).open("wb") as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=1200)
        value = json.loads(report.read_text(encoding="utf-8"))
        return value

    common = ["--metadata", str(metadata_path), "--repo", str(candidate),
              "--source-sha", SOURCE, "--git-ref", SOURCE]
    native = inspect("review_native_candidate.py", "native-independent-review",
                     ["--archive", str(raw_paths["native"]), "--artifact-id", str(selected["native"]["id"]), *common])
    need(native["status"] == "passed-independent-native-archive", "Native archive review did not pass")
    native_dll = inspect("review_windows_native.py", "windows-native-independent-review",
                         ["--archive", str(raw_paths["dll"]), "--artifact-id", str(selected["dll"]["id"]),
                          "--job-id", str(JOBS["windows-native"]), "--scratch", str(scratch), *common])
    need(native_dll["status"] == "passed-static-identity" and native_dll["dll"]["sha256"] == DLL_SHA
         and native_dll["dll"]["bytes"] == 6196224, "Independent fresh native DLL binding differs")
    workbench = {}
    for platform in ("linux", "windows"):
        extra = ["--archive", str(raw_paths[platform]), "--artifact-id", str(selected[platform]["id"]),
                 "--platform", platform, "--inventory", str(inventory_path), "--expect-complete", *common]
        if platform == "windows":
            extra.append("--require-provenance-refusals")
        workbench[platform] = inspect("review_workbench_evidence.py", platform + "-workbench-independent-review", extra)
        need(workbench[platform]["integrity_status"] == workbench[platform]["application_qualification"] == "passed",
             "Actual " + platform + " Workbench evidence is incomplete")
        expected_counts = {"headless/qualification.json": (43, 0), "graphical/qualification.json": (32, 18)}
        if platform == "windows":
            expected_counts["package-replay/qualification.json"] = (17, 0)
        need({r["path"]: (r["case_count"], r["rendered_case_count"])
              for r in workbench[platform]["reports"]} == expected_counts,
             "Independent process or actual graphical inventory count differs")
    inner = output / "raw" / INNER_NAME
    extract_inner(raw_paths["workbench-evaluator"], inner)
    package = inspect("inspect_windows_evaluator.py", "principal-evaluator-independent-review", [
        "--zip", str(inner), "--godot-archive", str(official), "--checkout", str(candidate),
        "--source-ref", SOURCE, "--expected-source", SOURCE, "--native-sha256", DLL_SHA,
        "--native-artifact-id", str(selected["dll"]["id"]),
    ])
    need(package["status"] == "passed", "Independent principal evaluator audit did not pass")
    launcher = workbench["windows"]["launcher"]
    need(package["zip"]["sha256"] == launcher["zip_sha256"]
         and launcher["paths"] == ["spaces", "parentheses", "unicode", "nested"]
         and launcher["provenance_refusals"] == 8
         and launcher["all_observed_display_publications_coherent"] is True,
         "Audited ZIP is not the exact successfully replayed shipped ZIP")
    for report in workbench["windows"]["reports"]:
        runtime = report["runtime"]
        need(runtime["native_sha256"] == DLL_SHA and runtime["godot_sha256"] == CONSOLE_SHA
             and runtime["rapier_sha256"] == RAPIER_SHA
             and runtime["godot_version"] == "4.7.stable.official.5b4e0cb0f",
             "Actual Windows process group runtime differs from the audited package")
    import_inventory = package_pe_imports(inner, reports, scratch)
    original_captures = emit_original_overviews(raw_paths["windows"], selected["windows"]["id"], reports)
    material = parity(raw_paths["native"], candidate)
    save(reports / "material-parity-independent-review.json", material)
    summary = {
        "schema": "objectshard-m4-independent-delivery-45530425519-v1", "status": "passed",
        "application_source": SOURCE, "application_tree": TREE,
        "package_producing_source": SOURCE, "native_build_source": SOURCE,
        "qualification_run": RUN, "qualification_attempt": ATTEMPT, "producer_jobs": JOBS,
        "audit_source": auditor_head, "audit_run": int(os.environ["GITHUB_RUN_ID"]),
        "audit_attempt": int(os.environ["GITHUB_RUN_ATTEMPT"]),
        "reviewer_inputs": reviewers, "inventory_sha256": INVENTORY_SHA,
        "driver_sha256": file_digest(Path(__file__)), "artifacts": custody,
        "original_job_logs": original_logs, "original_captures": original_captures,
        "principal_evaluator": package["zip"],
        "native_dll_sha256": DLL_SHA, "official_godot_archive_sha256": GODOT_SHA,
        "case_counts": {platform: {r["path"]: r["case_count"] for r in value["reports"]}
                        for platform, value in workbench.items()},
        "actual_shipped_cmd_paths": launcher["paths"], "provenance_refusals": 8,
        "native_checks": native["native"]["checks_reported"],
        "native_world_cases": native["native"]["test_cases_reported"],
        "native_benchmark_checks": native["benchmark"]["checks"], "native_budget_limits": len(native["budgets"]),
        "material_parity": material["status"], "package_import_inventory": import_inventory,
        "scope": "Independent archival/source review; no new application or physical GPU execution",
        "physical_owner_acceptance": "HOLD",
    }
    summary["report_identities"] = {
        path.name: {"bytes": path.stat().st_size, "sha256": file_digest(path)}
        for path in sorted(reports.iterdir()) if path.is_file()
    }
    save(reports / "summary.json", summary)
    emit_original_bytes("OBJECTSHARD_M4_ORIGINAL_JSON", {"filename": "delivery-audit-summary.json",
                        "application_source": SOURCE, "qualification_run": RUN},
                        (reports / "summary.json").read_bytes())
    if "GITHUB_OUTPUT" in os.environ:
        with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as stream:
            stream.write("audit_summary_sha256=" + file_digest(reports / "summary.json") + "\n")
            stream.write("evaluator_artifact_id=" + str(selected["workbench-evaluator"]["id"]) + "\n")
    print("OBJECTSHARD_M4_INDEPENDENT_DELIVERY_REVIEW " + json.dumps({
        "status": "passed", "source": SOURCE, "tree": TREE, "qualification_run": RUN,
        "audit_source": auditor_head, "principal_evaluator": package["zip"],
        "evaluator_artifact_id": selected["workbench-evaluator"]["id"],
        "cases": summary["case_counts"], "provenance_refusals": 8,
        "physical_owner_acceptance": "HOLD"}, sort_keys=True), flush=True)
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("candidate", "auditor", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    args.candidate, args.auditor, args.output = (p.resolve() for p in (args.candidate, args.auditor, args.output))
    try:
        audit(args.candidate, args.auditor, args.output)
    except Exception as error:
        save(args.output / "reports" / "audit-failure.json", {
            "status": "failed", "application_source": SOURCE, "qualification_run": RUN,
            "error_type": type(error).__name__, "error": str(error),
            "physical_owner_acceptance": "HOLD",
        })
        print("OBJECTSHARD_M4_INDEPENDENT_DELIVERY_REVIEW failed", flush=True)
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
