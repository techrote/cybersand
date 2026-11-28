#!/usr/bin/env python3
"""Exact-source, four-path publication after material audition qualification.

This helper never pushes or changes PR state. The branch-scoped workflow owns
the final single-parent, leased fast-forward after both operating systems and
the delivered Windows archive have passed. Existing acceptance gates remain.
"""
from __future__ import annotations

import argparse
import hashlib
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import re
import shutil
import sys
import platform as host_platform
import zipfile

import run_material_audition_qualification as qualification
import reduce_material_audition_performance as performance_reducer

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_material_audition_candidate as package

ROOT = Path(__file__).resolve().parents[2]
BRANCH = "mat/audition-live-001"
WORKFLOW = ".github/workflows/material-audition.yml"
REQUEST = ".github/material-audition-run.json"
EVIDENCE = "docs/audits/material-audition-live-20261124/shared-ledger.md"
REQUEST_VALUE = {
    "schema": "cybersand.material-audition.run-request",
    "schema_version": 1,
    "mission": "MAT-AUDITION-LIVE-001",
    "intent": "qualify-and-publish-source-matched-candidate-runtimes",
    "disposition": "Draft/HOLD",
    "canonical_defaults_changed": False,
}

# Reuse the already guarded binary-format, complete native-input and staged-LFS
# contracts privately. No other publisher's globals or acceptance are changed.
_spec = spec_from_file_location("_material_audition_publication_engine",
                               Path(__file__).with_name("lcb001_shared_contract_runtime_publication.py"))
engine = module_from_spec(_spec)
_spec.loader.exec_module(engine)
engine.ROOT, engine.BRANCH, engine.WORKFLOW, engine.REQUEST = ROOT, BRANCH, WORKFLOW, REQUEST
engine.git = lambda *args: qualification.git(ROOT, *args)
engine.BUILD_EXACT = {
    "Makefile", ".gitattributes", WORKFLOW, REQUEST, EVIDENCE,
    "tools/build_native_extension.sh", "tools/build_native_extension_windows.sh",
    "tools/build_pinned_godot_cpp.sh", "tools/requirements-build.txt",
    "tools/toolchains/g++", "tools/check_linux_runtime_floor.sh", "tools/verify_pinned_source_tree.py",
    "third_party/native-toolchain.lock.json", "third_party/godot-runtime.lock.json",
    "godot/third_party/rapier2d.lock.json", "third_party/rapier-bvh-build.lock.json",
    "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch",
    "godot/addons/godot-rapier2d/runtime-provenance.linux.json",
    "godot/addons/godot-rapier2d/runtime-provenance.windows.json",
    "godot/addons/cybersand_native/cybersand_native.gdextension",
    "godot/addons/godot-rapier2d/godot-rapier2d.gdextension",
    "tools/ci/lcb001_shared_contract_runtime_publication.py",
    "tools/ci/material_audition_publication.py", "tools/ci/test_material_audition_publication.py",
    "tools/ci/run_material_audition_qualification.py", "tools/ci/native_candidate_identity.py",
    "tools/ci/test_material_audition_evidence.py", "tools/package_material_audition_candidate.py",
    "tools/ci/build_material_audition_windows_probe.sh",
    "tools/ci/reduce_material_audition_performance.py",
}


def require(condition: bool, message: str) -> None:
    qualification.require(condition, message)


def validate_request(request: object) -> None:
    require(isinstance(request, dict) and set(request) == set(REQUEST_VALUE) | {"request_sequence"},
            "Unexpected publication request fields")
    require(all(type(request.get(key)) is type(value) and request[key] == value
                for key, value in REQUEST_VALUE.items()), "Unexpected publication intent or disposition")
    require(type(request["request_sequence"]) is int and request["request_sequence"] > 0,
            "Publication request needs a positive integer sequence")


def check_source(source: str) -> dict:
    context = engine.context(source)
    path = ROOT / REQUEST
    require(path.is_file() and not path.is_symlink(), "Missing explicit material audition run request")
    raw = path.read_bytes().replace(b"\r\n", b"\n")
    require(qualification.git(ROOT, "show", source + ":" + REQUEST) == raw,
            "Run request differs from the built commit")
    validate_request(json.loads(raw))
    remote = qualification.git(ROOT, "ls-remote", "--exit-code", "origin", "refs/heads/" + BRANCH).decode().strip()
    require(remote == source + "\trefs/heads/" + BRANCH, "Feature branch changed after build selection")
    return context


def validate_candidate_context(candidate: dict, source: str, platform: str) -> None:
    require(candidate.get("source_commit") == source and candidate.get("platform") == platform,
            "Candidate belongs to a different source or target OS")
    require(candidate.get("run_id") == os.environ.get("GITHUB_RUN_ID"), "Candidate is from another workflow run")
    attempt = candidate.get("run_attempt", "")
    current = os.environ.get("GITHUB_RUN_ATTEMPT", "")
    require(isinstance(attempt, str) and attempt.isdecimal() and current.isdecimal()
            and 0 < int(attempt) <= int(current), "Unexpected candidate build attempt")
    require(candidate.get("toolchain_drift") is False, "Development toolchain drift cannot publish a runtime")
    require(candidate.get("status") == "built-not-executed", "Unexpected immutable build receipt status")


def native_completion(path: Path) -> dict:
    raw = path.read_text(encoding="utf-8", errors="strict")
    require(not re.search(r"ERROR: AddressSanitizer|runtime error:|WARNING: ThreadSanitizer|\"status\":\"FAIL\"", raw),
            "Native qualification contains a sanitizer or suite failure")
    found = []
    for line in raw.splitlines():
        if line.startswith('{"status":'):
            value = json.loads(line)
            if value.get("suite") == "material-audition-native":
                found.append(value)
    require(len(found) == 1 and found[0].get("status") == "PASS"
            and type(found[0].get("assertions")) is int and found[0]["assertions"] > 0,
            "Missing unique positive native suite completion")
    return found[0]


def probe_identity(candidate_directory: Path, candidate: dict) -> dict:
    path = candidate_directory / "test_material_audition.build.json"
    probe = json.loads(path.read_text(encoding="utf-8"))
    binary = candidate_directory / "test_material_audition.exe"
    expected_native = {key: value for key, value in candidate["native_inputs"].items()
                       if key.startswith(("native/include/", "native/src/"))}
    require(probe.get("schema") == "cybersand.material-audition.windows-native-probe"
            and probe.get("schema_version") == 1 and probe.get("platform") == "windows"
            and probe.get("status") == "built-not-executed", "Unexpected Windows native probe receipt")
    require(all(probe.get(key) == candidate.get(key) for key in ("source_commit", "source_tree"))
            and probe.get("native_inputs") == expected_native, "Native probe was built from different source")
    for field, relative in (("test_sha256", "native/tests/test_material_audition.cpp"),
                            ("builder_sha256", "tools/ci/build_material_audition_windows_probe.sh")):
        qualification.git(ROOT, "diff", "--exit-code", "HEAD", "--", relative)
        require(probe.get(field) == hashlib.sha256((ROOT / relative).read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
                "Windows native probe test or builder source changed")
    require(probe.get("artifact") == binary.name and probe.get("sha256") == qualification.sha(binary)
            and probe.get("bytes") == binary.stat().st_size and probe.get("stack_reserve_bytes") == 1048576,
            "Windows native probe identity or ordinary stack changed")
    require("23.1.0" in probe.get("compiler_version", "") and "clang" in probe.get("compiler_version", "").lower(),
            "Windows native probe compiler differs from the pin")
    return probe


def run_windows_probe(candidate_directory: Path, evidence: Path, source: str) -> None:
    require(os.name == "nt", "Actual Windows is required to execute the native probe")
    candidate = qualification.verify(ROOT, candidate_directory, "windows")
    require(candidate["source_commit"] == source, "Requested native execution source differs from the candidate")
    probe = probe_identity(candidate_directory, candidate)
    require(not evidence.exists(), "Native execution evidence is immutable")
    evidence.mkdir(parents=True)
    receipt = qualification.run_process([str((candidate_directory / "test_material_audition.exe").resolve())],
                                         evidence / "native-probe.log", dict(os.environ), 1200)
    complete = native_completion(evidence / "native-probe.log")
    require(probe_identity(candidate_directory, candidate) == probe, "Probe changed during execution")
    qualification.write(evidence / "native-execution.json", {
        "schema": "cybersand.material-audition.windows-native-execution", "status": "passed",
        "platform": "windows", "platform_detail": host_platform.platform(),
        "source_commit": candidate["source_commit"], "source_tree": candidate["source_tree"],
        "native_sha256": candidate["native_sha256"], "probe_sha256": probe["sha256"],
        "build_receipt_sha256": qualification.sha(candidate_directory / "test_material_audition.build.json"),
        "process": receipt, "completion": complete,
    })


def verified_windows_probe(candidate_directory: Path, evidence: Path, candidate: dict) -> dict:
    probe = probe_identity(candidate_directory, candidate)
    report = json.loads((evidence / "native-execution.json").read_text(encoding="utf-8"))
    receipt = json.loads((evidence / "native-probe.receipt.json").read_text(encoding="utf-8"))
    require(report.get("schema") == "cybersand.material-audition.windows-native-execution"
            and report.get("status") == "passed" and report.get("platform") == "windows",
            "Native probe has no actual passing Windows execution")
    require(all(report.get(key) == candidate[key] for key in ("source_commit", "source_tree", "native_sha256"))
            and report.get("probe_sha256") == probe["sha256"]
            and report.get("build_receipt_sha256") == qualification.sha(candidate_directory / "test_material_audition.build.json"),
            "Windows native execution source or binary identity differs")
    require(report.get("process") == receipt and receipt.get("status") == "passed"
            and type(receipt.get("exit_code")) is int and receipt["exit_code"] == 0
            and receipt.get("log_sha256") == qualification.sha(evidence / "native-probe.log")
            and report.get("completion") == native_completion(evidence / "native-probe.log"),
            "Original native Windows process receipt or completion is inconsistent")
    return report


def retained_manifest(source: str, platform: str, candidate_directory: Path,
                      evidence_directory: Path, graphical_directory: Path | None = None) -> dict:
    candidate = qualification.verify(ROOT, candidate_directory, platform)
    validate_candidate_context(candidate, source, platform)
    report = package.verified_execution(evidence_directory, candidate,
                                       graphical=platform == "windows", platform=platform)
    if graphical_directory is not None:
        package.verified_execution(graphical_directory, candidate, graphical=True,
                                   platform=platform, cases=qualification.CASES[:1])
    binary = candidate_directory / Path(qualification.RUNTIMES[platform]).name
    identity = engine.runtime_identity(binary, platform)
    require(identity["sha256"] == candidate["native_sha256"], "Qualified runtime changed")
    inputs = engine.input_ledgers(source)
    require(inputs["source_inputs"] == candidate["native_inputs"], "Native input ledgers disagree")
    context = engine.context(source)
    result = context | inputs | identity | {
        "schema_version": 1, "platform": platform,
        "status": "validated-development-runtime", "build_attempt": candidate["run_attempt"],
        "validated_platform": ("Windows" if platform == "windows" else "Linux") +
                              " x86_64 / real graphical Godot 4.7",
        "godot_version": qualification.VERSION, "evidence": EVIDENCE,
        "toolchain": (candidate_directory / "toolchain.txt").read_text(encoding="utf-8"),
        "candidate_manifest_sha256": qualification.sha(candidate_directory / qualification.MANIFEST),
        "validation_sha256": qualification.sha(evidence_directory / "execution.json"),
        "qualification_cases": [row[0] for row in qualification.CASES],
        "acceptance": "Exact-source current-scene native consumer, owner transaction, profile, Lab regression and graphical qualification. Scope is the retained case list; physical owner acceptance remains pending.",
        "canonical_defaults_changed": False, "disposition": "Draft/HOLD",
        "physical_owner_acceptance": "OWNER-PENDING",
    }
    if graphical_directory is not None:
        result["graphical_validation_sha256"] = qualification.sha(graphical_directory / "execution.json")
    return result


def stage(args: argparse.Namespace) -> None:
    check_source(args.source_sha)
    require(not qualification.git(ROOT, "diff", "--cached", "--name-only").strip(),
            "Publication requires an initially empty index")
    qualification.git(ROOT, "diff", "--exit-code", "HEAD", "--", *engine.RUNTIMES.values(), *engine.MANIFESTS.values())
    linux_candidate = args.linux_bundle / "build/audition-linux"
    linux_evidence = args.linux_bundle / "evidence"
    manifests = {
        "linux": retained_manifest(args.source_sha, "linux", linux_candidate,
                                   linux_evidence / "headless", linux_evidence / "graphical"),
        "windows": retained_manifest(args.source_sha, "windows", args.windows_candidate,
                                     args.windows_evidence / "windows"),
    }
    native_completion(linux_evidence / "native-profile.log")
    native_completion(linux_evidence / "native-profile-sanitized.log")
    performance = json.loads((linux_evidence / "performance/summary.json").read_text(encoding="utf-8"))
    measured = performance_reducer.summarize(linux_evidence / "performance/accepted.jsonl",
                                             linux_evidence / "performance/candidate.jsonl")
    require(performance == measured and performance.get("status") == "passed"
            and performance.get("matched_default_samples") == 12 and performance.get("candidate_samples") == 36
            and {(row["side"], row["workers"], row["ticks"], row["repeats"]) for row in performance["groups"]}
                == {(side, workers, 96, 3) for side in (256, 1024) for workers in (1, 4)}
            and all(row["modified_cell_effect_observed"] for row in performance["groups"]),
            "Complete default-equivalence measurements do not reproduce their summary")
    require((linux_evidence / "performance/accepted-source.txt").read_text().strip()
                == "00cdb02f103265b6dc5224c68283e9a0c8cb449f"
            and (linux_evidence / "performance/candidate-source.txt").read_text().strip() == args.source_sha,
            "Performance matrix source identities differ from accepted and candidate source")
    windows_candidate = qualification.verify(ROOT, args.windows_candidate, "windows")
    verified_windows_probe(args.windows_candidate, args.windows_evidence / "windows-native", windows_candidate)
    with zipfile.ZipFile(args.windows_archive) as archive:
        with archive.open("Godot_v4.7-stable_win64_console.exe") as stream:
            windows_engine_sha256 = hashlib.file_digest(stream, "sha256").hexdigest()
    package.verified_execution(args.windows_evidence / "windows", windows_candidate, graphical=True,
                               godot_digest=windows_engine_sha256)
    package.verify_extracted_execution(args.windows_evidence / "relocated-package", windows_candidate,
                                       args.windows_archive,
                                       candidate_digest=qualification.sha(args.windows_candidate / qualification.MANIFEST),
                                       godot_digest=windows_engine_sha256)
    package_sha = qualification.sha(args.windows_evidence / "relocated-package/package-execution.json")
    for platform, manifest in manifests.items():
        manifest["windows_package_execution_sha256"] = package_sha
        manifest["windows_native_execution_sha256"] = qualification.sha(args.windows_evidence / "windows-native/native-execution.json")
        manifest["default_equivalence_sha256"] = qualification.sha(linux_evidence / "performance/summary.json")
        candidate = linux_candidate if platform == "linux" else args.windows_candidate
        shutil.copyfile(candidate / Path(engine.RUNTIMES[platform]).name, ROOT / engine.RUNTIMES[platform])
        qualification.write(ROOT / engine.MANIFESTS[platform], manifest)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check-source", "stage", "check-index", "run-windows-probe"))
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--linux-bundle", type=Path)
    parser.add_argument("--windows-candidate", type=Path)
    parser.add_argument("--windows-evidence", type=Path)
    parser.add_argument("--windows-archive", type=Path)
    args = parser.parse_args()
    if args.command == "stage":
        require(all(getattr(args, key) is not None for key in
                    ("linux_bundle", "windows_candidate", "windows_evidence", "windows_archive")), "Missing qualification bundle")
        stage(args)
    elif args.command == "run-windows-probe":
        require(args.windows_candidate is not None and args.windows_evidence is not None,
                "Native Windows execution requires its candidate and a new evidence directory")
        run_windows_probe(args.windows_candidate, args.windows_evidence, args.source_sha)
    elif args.command == "check-index":
        check_source(args.source_sha)
        engine.check_index(args)
    else:
        check_source(args.source_sha)
    print(json.dumps({"status": "passed", "command": args.command, "source_commit": args.source_sha}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
