"""Independent audit of the packaged linker selection in extracted Lab evidence.

This reads only the completed extracted evaluator and its qualification outputs.
It does not rerun the application or claim process-level observation of ld.lld.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
from types import ModuleType
from typing import Any

SCHEMA = "pubpres-mainline-extracted-linker-audit-v1"
MANIFEST = "PUBPRES-MAINLINE-EVALUATOR.json"
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
MARKER = "MAT_WB_EVIDENCE "


class AuditError(RuntimeError):
    """Extracted package or raw Lab evidence failed the independent audit."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditError(message)


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, allow_nan=False, sort_keys=True,
                       indent=2) + "\n").encode("utf-8")


def object_digest(value: Any) -> str:
    return sha_bytes(canonical_json(value))


def read_json(path: Path, label: str, *, maximum_bytes: int = 64 * 1024 * 1024) -> dict:
    require(path.is_file() and not path.is_symlink(), label + " is missing or not a regular file")
    size = path.stat().st_size
    require(0 < size <= maximum_bytes, label + " has an invalid or excessive size")
    try:
        value = json.loads(path.read_bytes())
    except (OSError, json.JSONDecodeError, UnicodeDecodeError) as error:
        raise AuditError(label + " is not valid UTF-8 JSON") from error
    require(type(value) is dict, label + " must contain a JSON object")
    return value


def _safe_relative(name: str) -> PurePosixPath:
    require(type(name) is str and name and "\\" not in name,
            "Source identity contains an invalid relative path")
    relative = PurePosixPath(name)
    require(not relative.is_absolute() and relative.parts
            and all(part not in ("", ".", "..") for part in relative.parts),
            "Source identity contains an unsafe relative path")
    return relative


def _source_snapshot(installation: Path, manifest: dict, identity: dict,
                     snapshot_path: Path) -> dict:
    source = installation / "source"
    require(source.is_dir() and not source.is_symlink(), "Extracted source directory is missing")
    require(identity.get("git_head") == manifest.get("source_commit"),
            "World receipt Git HEAD differs from the evaluator source commit")
    hashes = identity.get("lf_sha256")
    require(type(hashes) is dict and hashes, "World receipt lacks its source-file hash map")
    require(all(type(name) is str and HEX64.fullmatch(str(value)) for name, value in hashes.items()),
            "World receipt source hash map is malformed")
    require(identity.get("digest") == object_digest(hashes),
            "World receipt source-map digest does not recompute")
    file_map = manifest.get("files_sha256")
    require(type(file_map) is dict, "Evaluator manifest lacks its complete file map")
    checked = 0
    for name, expected_lf_hash in sorted(hashes.items()):
        relative = _safe_relative(name)
        path = source.joinpath(*relative.parts)
        require(path.is_file() and not path.is_symlink(),
                "World source snapshot path is missing or not a regular file: " + name)
        require(sha_file(path) == file_map.get("source/" + name),
                "Extracted source file differs from the evaluator manifest: " + name)
        normalized = path.read_bytes().replace(b"\r\n", b"\n")
        require(sha_bytes(normalized) == expected_lf_hash,
                "Extracted source file differs from the World receipt snapshot: " + name)
        checked += 1
    sidecar = read_json(snapshot_path, "Portable Lab source snapshot")
    require(sidecar == identity, "Portable Lab source snapshot differs from the World receipt")
    return {"git_head": identity["git_head"], "digest": identity["digest"],
            "file_count": checked, "sidecar_sha256": sha_file(snapshot_path)}


def _windows_path(value: str) -> str:
    # Windows TEMP may expose the same existing file through an 8.3 alias.
    # Resolve the real file before comparing; a different executable still
    # resolves to a different path and a missing target remains a refusal.
    return os.path.normcase(str(Path(value).resolve(strict=True)))


def validate_world_receipt(outer: dict, installation: Path, manifest: dict,
                           snapshot_path: Path) -> dict:
    world = outer.get("candidate_world_receipt")
    require(type(world) is dict and world.get("schema_id") == "cybersand.material-lab.world-receipt"
            and world.get("schema_version") == 1 and world.get("runtime_active") is False,
            "MAT_WB_EVIDENCE lacks the actual external World comparison receipt")
    require(outer.get("errors") == [] and outer.get("complete") is True,
            "MAT_WB_EVIDENCE reports an incomplete or failed Lab route")
    checks = world.get("checks")
    require(type(checks) is dict and checks.get("reference_qualification") is True
            and checks.get("candidate_qualification") is True,
            "World receipt does not record successful reference and candidate execution")
    require(type(world.get("reference")) is dict and type(world.get("candidate")) is dict,
            "World receipt is missing a reference or candidate result")

    offline = manifest.get("offline_authoring")
    require(type(offline) is dict and type(offline.get("tools")) is dict,
            "Evaluator manifest lacks offline authoring dependencies")
    compiler = offline["tools"].get("compiler")
    require(type(compiler) is dict and compiler.get("path") == "cxx/bin/g++.exe"
            and HEX64.fullmatch(str(compiler.get("sha256", ""))),
            "Evaluator manifest does not identify the pinned bundled g++")
    expected_compiler = installation / "dependencies" / Path(*compiler["path"].split("/"))
    require(expected_compiler.is_file() and not expected_compiler.is_symlink()
            and sha_file(expected_compiler) == compiler["sha256"],
            "Bundled g++ does not match the offline compiler receipt")
    require(manifest.get("files_sha256", {}).get("dependencies/cxx/bin/g++.exe") == compiler["sha256"],
            "Bundled g++ differs from the evaluator payload manifest")
    require(world.get("compiler") == expected_compiler.name
            and world.get("compiler_version") == str(compiler.get("version", "")).splitlines()[0],
            "World receipt compiler name/version differs from the shipped compiler")

    build_records = {}
    for role in ("reference_build", "candidate_build"):
        build = world.get(role)
        require(type(build) is dict, "World receipt is missing " + role)
        argv = build.get("argv")
        require(type(argv) is list and argv and all(type(part) is str for part in argv),
                role + " lacks its actual compiler argv")
        require(Path(argv[0]).is_absolute()
                and _windows_path(argv[0]) == _windows_path(str(expected_compiler)),
                role + " did not invoke the exact bundled g++.exe")
        linker_flags = [part for part in argv if part.startswith("-fuse-ld=")]
        require(linker_flags == ["-fuse-ld=lld"],
                role + " did not select exactly the registered LLD linker")
        require(not any(part == "-B" or (part.startswith("-B") and len(part) > 2) for part in argv),
                role + " contains a -B override that could redirect compiler program discovery")
        executable_hash = build.get("native_executable_sha256")
        require(type(executable_hash) is str and HEX64.fullmatch(executable_hash),
                role + " lacks a valid generated native executable hash")
        build_records[role] = {"argv": argv, "linker": "lld",
                               "native_executable_sha256": executable_hash}

    identity = world.get("source_identity")
    require(type(identity) is dict and HEX64.fullmatch(str(identity.get("digest", "")))
            and world.get("source_identity_after") == identity["digest"],
            "World build source identity is missing or changed during the actual build")
    source = _source_snapshot(installation, manifest, identity, snapshot_path)

    # Keep generated executable hashes tied to this exact raw World receipt.
    # The executable files are temporary and are not required to remain in the package.
    return {"schema_id": world["schema_id"], "scenario": world.get("scenario"),
            "source_snapshot": source, "reference_build": build_records["reference_build"],
            "candidate_build": build_records["candidate_build"],
            "reference_result_present": True, "candidate_result_present": True,
            "process_level_linker_child_observed": False,
            "process_level_linker_child_note": "Not asserted; the raw World receipt proves exact compiler argv and generated executable hashes, while process sampling is not used to claim ld.lld child observation."}


def _load_exact_module(name: str, path: Path) -> ModuleType:
    require(path.is_file() and not path.is_symlink(), "Packaged verifier source is missing: " + str(path))
    module_name = "_pubpres_extracted_linker_audit_" + name
    spec = importlib.util.spec_from_file_location(module_name, path)
    require(spec is not None and spec.loader is not None,
            "Unable to load exact packaged verifier source: " + str(path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    try:
        spec.loader.exec_module(module)
    except BaseException:
        sys.modules.pop(module_name, None)
        raise
    require(Path(module.__file__).resolve() == path.resolve(),
            "Verifier import resolved to a different source file")
    return module


def _load_portable_tools(installation: Path) -> tuple[ModuleType, ModuleType]:
    ci = installation / "source" / "tools" / "ci"
    return (_load_exact_module("portable_compiler_utf8", ci / "portable_compiler_utf8.py"),
            _load_exact_module("portable_lld", ci / "portable_lld.py"))


def verify_linker_bundle(installation: Path, manifest: dict, *,
                         load_tools=None) -> dict:
    file_map = manifest.get("files_sha256")
    offline = manifest.get("offline_authoring")
    require(type(file_map) is dict and type(offline) is dict,
            "Evaluator manifest lacks the source and dependency custody maps")
    ci_sources = {
        "tools/ci/portable_compiler_utf8.py": "source/tools/ci/portable_compiler_utf8.py",
        "tools/ci/portable_lld.py": "source/tools/ci/portable_lld.py",
    }
    for relative, key in ci_sources.items():
        path = installation / "source" / Path(*relative.split("/"))
        require(path.is_file() and not path.is_symlink() and HEX64.fullmatch(str(file_map.get(key, "")))
                and sha_file(path) == file_map[key],
                "Extracted verifier source differs from its evaluator source manifest: " + relative)
    compiler_root = installation / "dependencies" / "cxx"
    utf8 = offline.get("compiler_utf8")
    lld = offline.get("portable_lld")
    require(type(utf8) is dict and utf8.get("status") == "verified"
            and type(lld) is dict and lld.get("status") == "verified",
            "Evaluator manifest lacks verified compiler or LLD receipts")
    compiler_marker = compiler_root / "CYBERSAND-COMPILER-UTF8.json"
    linker_marker = compiler_root / "CYBERSAND-PORTABLE-LINKER.json"
    require(compiler_marker.is_file() and not compiler_marker.is_symlink()
            and linker_marker.is_file() and not linker_marker.is_symlink(),
            "Bundled compiler/linker marker is missing")
    require(file_map.get("dependencies/cxx/CYBERSAND-COMPILER-UTF8.json") == sha_file(compiler_marker)
            and file_map.get("dependencies/cxx/CYBERSAND-PORTABLE-LINKER.json") == sha_file(linker_marker),
            "Bundled compiler/linker marker differs from the evaluator payload manifest")

    load = load_tools or _load_portable_tools
    compiler_module, lld_module = load(installation)
    compiler_actual = compiler_module.verify(compiler_root, execute=False)
    lld_actual = lld_module.verify(compiler_root, execute=True)
    require(compiler_actual == utf8,
            "Packaged UTF-8 compiler receipt differs from the independently verified marker")
    require(lld_actual == lld,
            "Packaged LLD receipt differs from the independently verified marker")
    require(lld_actual.get("schema") == "cybersand.portable-linker-v1"
            and lld_actual.get("source", {}).get("lld_version") == "LLD 23.1.0",
            "Bundled linker proof does not identify the pinned LLD release")
    driver = compiler_actual.get("binaries", {}).get("bin/g++.exe", {})
    binding = lld_actual.get("gnu_compiler_binding", {})
    require(binding.get("compiler_receipt_sha256") == compiler_actual.get("receipt_sha256")
            and binding.get("driver_prepared_sha256") == driver.get("sha256")
            and binding.get("driver_relative_path") == "bin/g++.exe",
            "LLD proof is not bound to the exact prepared GNU compiler")

    checked_lld_files = 0
    for relative, record in lld_actual.get("files", {}).items():
        require(type(record) is dict and HEX64.fullmatch(str(record.get("sha256", "")))
                and type(record.get("bytes")) is int,
                "LLD proof contains a malformed file row")
        path = compiler_root / Path(*relative.split("/"))
        require(path.is_file() and not path.is_symlink() and path.stat().st_size == record["bytes"]
                and sha_file(path) == record["sha256"],
                "Bundled LLD file differs from its pin: " + relative)
        require(file_map.get("dependencies/cxx/" + relative) == record["sha256"],
                "Bundled LLD file differs from evaluator manifest: " + relative)
        checked_lld_files += 1
    require(checked_lld_files > 0, "LLD proof contains no executable/dependency closure")
    checked_compiler_files = 0
    for relative, record in compiler_actual.get("binaries", {}).items():
        require(type(record) is dict and HEX64.fullmatch(str(record.get("sha256", ""))),
                "Compiler proof contains a malformed executable row")
        path = compiler_root / Path(*relative.split("/"))
        require(path.is_file() and not path.is_symlink() and sha_file(path) == record["sha256"]
                and file_map.get("dependencies/cxx/" + relative) == record["sha256"],
                "Bundled compiler executable differs from its receipt/manifest: " + relative)
        checked_compiler_files += 1
    require(checked_compiler_files > 0, "Compiler proof contains no executables")
    return {"schema": lld_actual["schema"], "status": lld_actual["status"],
            "lld_version": lld_actual["source"]["lld_version"],
            "archive_sha256": lld_actual["source"]["archive_sha256"],
            "lld_receipt_sha256": lld_actual["receipt_sha256"],
            "compiler_receipt_sha256": compiler_actual["receipt_sha256"],
            "lld_files_checked": checked_lld_files,
            "licensed_files_checked": sum(1 for name in lld_actual["files"] if name.startswith("licenses/")),
            "compiler_executables_checked": checked_compiler_files}


def audit(installation: Path, output: Path) -> dict:
    installation = installation.resolve(strict=True)
    output = output.resolve(strict=True)
    require(installation.is_dir() and output.is_dir(), "Installation and output must be existing directories")
    manifest_path = installation / MANIFEST
    manifest = read_json(manifest_path, "Evaluator manifest")
    require(manifest.get("schema") == "pubpres-mainline-windows-evaluator-v1",
            "Unexpected evaluator manifest schema")
    manifest_sha = sha_file(manifest_path)
    extracted = read_json(output / "extracted-verification.json", "Extracted verification record")
    require(extracted.get("schema") == "pubpres-mainline-extracted-evaluator-v1"
            and extracted.get("status") == "passed"
            and extracted.get("source_commit") == manifest.get("source_commit")
            and extracted.get("source_tree") == manifest.get("source_tree")
            and extracted.get("manifest_sha256") == manifest_sha,
            "Independent extracted qualification is not complete or is bound to another package")

    lab_root = output / "lab"
    cross_feature = read_json(lab_root / "pubpres-mainline-qualification.json",
                              "Extracted Lab cross-feature record")
    require(cross_feature.get("schema") == "pubpres-mainline-cross-feature-v1"
            and cross_feature.get("status") == "passed" and cross_feature.get("mode") == "lab"
            and cross_feature.get("platform") == "windows"
            and cross_feature.get("source") == {"source_commit": manifest.get("source_commit"),
                                                  "source_tree": manifest.get("source_tree")}
            and extracted.get("extracted_modes", {}).get("lab", {}).get("record_sha256")
                == sha_file(lab_root / "pubpres-mainline-qualification.json"),
            "Extracted Lab cross-feature record is incomplete or belongs to another source")
    lab_root = lab_root / "original"
    lab_record = read_json(lab_root / "integration.json", "Extracted original Lab integration record")
    require(lab_record.get("schema") == "ramcache-strata-integration-v1"
            and lab_record.get("status") == "passed" and lab_record.get("completed") is True
            and lab_record.get("mode") == "lab" and lab_record.get("platform") == "win32"
            and lab_record.get("source_identity", {}).get("source_commit") == manifest.get("source_commit")
            and lab_record.get("source_identity", {}).get("source_tree") == manifest.get("source_tree"),
            "Extracted original Lab integration record is incomplete or belongs to another source")
    label = "material-lab-author"
    author = lab_root / label
    log_path = author / "process.log"
    process = read_json(author / "process.json", "Actual Lab author process record")
    require(process.get("status") == "passed" and process.get("exit_code") == 0
            and process.get("log_sha256") == sha_file(log_path),
            "Actual Lab author process did not complete or its log changed")
    cases = lab_record.get("cases")
    require(type(cases) is list, "Extracted Lab integration record lacks case rows")
    matching_cases = [row for row in cases if row.get("label") == label]
    require(len(matching_cases) == 1 and matching_cases[0].get("status") == "passed"
            and matching_cases[0].get("exit_code") == 0
            and matching_cases[0].get("log_sha256") == process["log_sha256"],
            "Lab integration record does not bind the actual author process log")
    lab_file_hash = lab_record.get("files_sha256", {}).get(label + "/process.log")
    require(lab_file_hash == process["log_sha256"]
            and cross_feature.get("original_report_sha256") == sha_file(lab_root / "integration.json"),
            "Lab integration records do not bind the actual author process log/report")
    log_bytes = log_path.read_bytes()
    require(len(log_bytes) <= 128 * 1024 * 1024, "Actual Lab author log exceeds its bounded size")
    try:
        log_text = log_bytes.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise AuditError("Actual Lab author log is not UTF-8") from error
    markers = [line[len(MARKER):] for line in log_text.splitlines() if line.startswith(MARKER)]
    require(len(markers) == 1, "Actual Lab author log must contain exactly one MAT_WB_EVIDENCE receipt")
    try:
        outer = json.loads(markers[0])
    except json.JSONDecodeError as error:
        raise AuditError("MAT_WB_EVIDENCE payload is malformed") from error
    require(type(outer) is dict, "MAT_WB_EVIDENCE payload must be an object")
    world = validate_world_receipt(outer, installation, manifest,
                                   output / "portable-lab-source-snapshot.json")
    linker = verify_linker_bundle(installation, manifest)
    result = {
        "schema": SCHEMA,
        "status": "passed",
        "source_commit": manifest["source_commit"],
        "source_tree": manifest["source_tree"],
        "manifest_sha256": manifest_sha,
        "extracted_verification_sha256": sha_file(output / "extracted-verification.json"),
        "lab_integration_sha256": sha_file(lab_root / "integration.json"),
        "lab_process_log_sha256": process["log_sha256"],
        "world_comparison": world,
        "portable_linker": linker,
        "qualification_boundary": "Independent extracted execution must already have passed. This audit additionally checks the raw Materials Lab World receipt, source snapshot, exact packaged GNU compiler argv, -fuse-ld=lld selection and source-bound LLD/license closure. It does not claim process-level observation of ld.lld.",
        "physical_owner_evaluated": False,
        "merge_authorized": False,
    }
    destination = output / "extracted-linker-audit.json"
    require(not destination.exists() and not destination.is_symlink(),
            "Refuse to overwrite an existing extracted linker audit")
    destination.write_bytes(canonical_json(result))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--installation", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.installation, args.output)
    print(json.dumps({"status": result["status"], "source_commit": result["source_commit"],
                      "audit": str(args.output / "extracted-linker-audit.json")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
