#!/usr/bin/env python3
"""Build or verify the opt-in goblin Windows developer evaluator.

Packaging creates an UNQUALIFIED candidate. The extracted Windows package must
pass its own fixed launcher self-tests before the owner may receive a qualified
evaluator. Existing source-matched native/Rapier binaries are reused; this tool
does not rebuild or publish runtime libraries or change a production default.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "cybersand-goblin-evaluator-v1"
MANIFEST = "goblin-evaluator-manifest.json"
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
GODOT = "Godot_v4.7-stable_win64.exe"
CONSOLE = "Godot_v4.7-stable_win64_console.exe"
REQUIRED_CASES = ("actor_workshop", "save_reopen")


def sha(path: Path, algorithm: str = "sha256") -> str:
    result = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def git(*arguments: str) -> str:
    return subprocess.check_output(["git", *arguments], cwd=ROOT, text=True, timeout=30).strip()


def windows_pin() -> dict:
    tree = ast.parse((ROOT / "tools/ci/run_windows_godot_regressions.py").read_text(encoding="utf-8"))
    result = {}
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id in {"GODOT_SHA512", "GODOT_VERSION"}:
                    result[target.id] = ast.literal_eval(node.value)
                elif isinstance(target, ast.Name) and target.id == "RAPIER_IMPORT_DESCRIPTORS":
                    value = node.value
                    if not isinstance(value, ast.Call) or not isinstance(value.func, ast.Name) or value.func.id != "frozenset" or len(value.args) != 1 or value.keywords:
                        raise ValueError("Existing Windows import-descriptor rule is unavailable")
                    result[target.id] = frozenset(ast.literal_eval(value.args[0]))
    if len(result) != 3 or re.fullmatch(r"[0-9a-f]{128}", result["GODOT_SHA512"]) is None:
        raise ValueError("Existing Windows Godot pin is unavailable")
    if len(result["RAPIER_IMPORT_DESCRIPTORS"]) != 4 or not all(isinstance(name, str) and name.startswith("godot/addons/godot-rapier2d/") and name.endswith(".import") and safe_relative(name) for name in result["RAPIER_IMPORT_DESCRIPTORS"]):
        raise ValueError("Existing Windows import-descriptor scope differs")
    return result


def runtime_inputs() -> tuple[dict, dict]:
    provenance, source_inputs = {}, {}
    for name, path in (("native", "godot/addons/cybersand_native/runtime-provenance.json"),
                       ("rapier", "godot/addons/godot-rapier2d/runtime-provenance.windows.json")):
        manifest = json.loads((ROOT / path).read_text(encoding="utf-8"))
        artifact = ROOT / manifest["artifact"]
        if sha(artifact) != manifest["sha256"] or artifact.stat().st_size != manifest["size"]:
            raise ValueError(name + " retained runtime bytes are not materialized/source-matched")
        for relative, expected in manifest["source_inputs"].items():
            actual = hashlib.sha256((ROOT / relative).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
            if actual != expected:
                raise ValueError(name + " retained runtime source drift: " + relative)
            source_inputs[relative] = expected
        provenance[name + "_sha256"] = manifest["sha256"]
        provenance[name + "_provenance_sha256"] = sha(ROOT / path)
        provenance[name + "_source_input_count"] = len(manifest["source_inputs"])
        provenance[name + "_build_commit"] = manifest.get("source_commit", manifest.get("build_commit"))
    return provenance, source_inputs


def safe_relative(name: str) -> bool:
    path = PurePosixPath(name)
    return not path.is_absolute() and bool(path.parts) and path.as_posix() == name and ".." not in path.parts and "\\" not in name and ":" not in name


def checked_member(path: Path, name: str) -> Path:
    if not safe_relative(name):
        raise ValueError("Non-relative package member: " + name)
    result = path / name
    if result.is_symlink() or not result.resolve().is_relative_to(path.resolve()):
        raise ValueError("Symlink is not an evaluator payload: " + name)
    return result


def copy_committed_source(destination: Path, source_inputs: dict) -> dict:
    # The accepted Windows runner already treats these four Rapier text
    # descriptors as LF-canonical inputs. Canonicalize before freezing package
    # bytes; extraction and post-test verification remain raw SHA comparisons.
    import_descriptors = windows_pin()["RAPIER_IMPORT_DESCRIPTORS"]
    normalized_imports = {}
    names = ["godot", "examples/worldgen", "third_party/godot-runtime.lock.json", "THIRD_PARTY_NOTICES.md",
             "LICENSE_STATUS.md", "docs/operations/gip014-goblin-gameplay-qa.md", "docs/research/gip014-goblin-gameplay-qa.md",
             "tools/gip014/Open-goblin.cmd", "tools/gip014/Open-goblin.ps1", *source_inputs]
    committed = set(git("ls-tree", "-r", "--name-only", "HEAD").splitlines())
    names = [name for name in names if name in committed or any(path.startswith(name + "/") for path in committed)]
    payload = subprocess.check_output(["git", "archive", "HEAD", "--", *names], cwd=ROOT, timeout=60)
    with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
        for entry in archive:
            if not entry.isfile() or not safe_relative(entry.name):
                continue
            if entry.name.startswith("godot/.godot/"):
                if entry.name not in {"godot/.godot/.gdignore", "godot/.godot/extension_list.cfg", "godot/.godot/global_script_class_cache.cfg"}:
                    continue
            if "/bin/" in entry.name and entry.name not in {NATIVE, RAPIER}:
                continue
            stream = archive.extractfile(entry)
            if stream is None:
                raise ValueError("Unreadable committed source member")
            data = stream.read()
            if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", data)
                actual = (ROOT / entry.name).read_bytes()
                if pointer is None or hashlib.sha256(actual).hexdigest() != pointer[1].decode() or len(actual) != int(pointer[2]):
                    raise ValueError("Unmaterialized or changed committed LFS payload: " + entry.name)
                data = actual
            if entry.name in import_descriptors:
                original = data
                data = data.replace(b"\r\n", b"\n")
                normalized_imports[entry.name] = {
                    "archive_sha256": hashlib.sha256(original).hexdigest(),
                    "packaged_sha256": hashlib.sha256(data).hexdigest(),
                    "crlf_pairs_removed": original.count(b"\r\n"),
                }
            target = destination / entry.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    if set(normalized_imports) != import_descriptors:
        raise ValueError("Committed package lacks the existing four Rapier import descriptors")
    rule = ROOT / "tools/ci/run_windows_godot_regressions.py"
    return {"schema": "cybersand-goblin-import-descriptor-normalization-v1", "operation": "CRLF to LF before package manifest",
            "rule_source": rule.relative_to(ROOT).as_posix(), "rule_source_sha256": sha(rule), "files": normalized_imports}


def build(archive_path: Path, notices: Path, vc_runtime: Path, output: Path) -> dict:
    if git("status", "--porcelain", "--untracked-files=all"):
        raise ValueError("Evaluator packaging requires clean committed source")
    if output.exists():
        raise ValueError("Evaluator output must be new; original evidence is retained")
    if output.suffix.lower() != ".zip":
        raise ValueError("Evaluator output must be a ZIP file")
    pins = windows_pin()
    if sha(archive_path, "sha512") != pins["GODOT_SHA512"]:
        raise ValueError("Windows Godot archive differs from existing exact pin")
    provenance, inputs = runtime_inputs()
    provenance.update(source_commit=git("rev-parse", "HEAD"), source_tree=git("rev-parse", "HEAD^{tree}"),
                      source_dirty=False, platform="windows", godot_version=pins["GODOT_VERSION"],
                      runtime_basis="existing retained source-matched libraries; no fresh native build claimed")
    sys.path.insert(0, str(ROOT / "tools"))
    from package_explore001_candidate import stage_vc_runtime
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="goblin-evaluator-", dir=output.parent) as temporary:
        staged = Path(temporary) / "CyberSand-goblin"
        staged.mkdir()
        import_normalization = copy_committed_source(staged, inputs)
        with zipfile.ZipFile(archive_path) as engine:
            if engine.testzip() is not None:
                raise ValueError("Pinned Godot ZIP failed integrity check")
            for name in (GODOT, CONSOLE):
                if engine.namelist().count(name) != 1:
                    raise ValueError("Pinned Godot ZIP lacks unique " + name)
                (staged / name).write_bytes(engine.read(name))
        provenance["godot_sha256"] = sha(staged / GODOT)
        provenance["godot_console_sha256"] = sha(staged / CONSOLE)
        for name in ("LICENSE.txt", "COPYRIGHT.txt"):
            source = notices / name
            if not source.is_file() or source.stat().st_size < 100:
                raise ValueError("Official Godot notice unavailable: " + name)
            shutil.copyfile(source, staged / ("Godot-" + name))
        stage_vc_runtime(vc_runtime, staged)
        for name in ("cmd", "ps1"):
            shutil.copyfile(staged / "tools/gip014" / ("Open-goblin." + name), staged / ("Open goblin." + name))
        guide = staged / "docs/operations/gip014-goblin-gameplay-qa.md"
        if not guide.is_file():
            guide = staged / "docs/research/gip014-goblin-gameplay-qa.md"
        if not guide.is_file():
            raise ValueError("Committed goblin developer guide is missing")
        shutil.copyfile(guide, staged / "READ-ME.md")
        (staged / "source-inputs.json").write_text(json.dumps({"source_commit": provenance["source_commit"],
            "source_tree": provenance["source_tree"], "source_inputs": inputs}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        files = {path.relative_to(staged).as_posix(): sha(path) for path in sorted(staged.rglob("*")) if path.is_file()}
        project_files = {name.removeprefix("godot/"): digest for name, digest in files.items()
                         if name.startswith("godot/") and not name.startswith("godot/.godot/")}
        provenance["project_files_sha256"] = hashlib.sha256(json.dumps(project_files, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        manifest = {"schema": SCHEMA, "qualification": "unqualified candidate; extracted Windows self-tests required",
                    "source_commit": provenance["source_commit"], "source_tree": provenance["source_tree"], "provenance": provenance,
                    "godot_archive_sha512": pins["GODOT_SHA512"], "files_sha256": files,
                    "import_descriptor_normalization": import_normalization,
                    "required_selftests": [{"fixture": name, "policy": "CONTROL", "seed": 13, "budget": 64} for name in REQUIRED_CASES]}
        (staged / MANIFEST).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        verify_extracted(staged)
        if git("status", "--porcelain", "--untracked-files=all") or git("rev-parse", "HEAD") != provenance["source_commit"]:
            raise ValueError("Source changed during evaluator packaging")
        with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as package:
            for path in sorted(staged.rglob("*")):
                if path.is_file():
                    package.write(path, path.relative_to(staged.parent).as_posix())
    return {"package": str(output), "package_sha256": sha(output), "source_commit": provenance["source_commit"],
            "qualification": "unqualified candidate; do not publish before extracted Windows self-tests"}


def verify_extracted(directory: Path, qualification: Path | None = None) -> dict:
    manifest_path = directory / MANIFEST
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    if manifest.get("schema") != SCHEMA or not isinstance(manifest.get("files_sha256"), dict):
        raise ValueError("Unknown evaluator manifest")
    for name, expected in manifest["files_sha256"].items():
        path = checked_member(directory, name)
        if not path.is_file() or not isinstance(expected, str) or re.fullmatch(r"[0-9a-f]{64}", expected) is None or sha(path) != expected:
            raise ValueError("Extracted evaluator payload hash mismatch: " + name)
    if qualification is None:
        return {"payload_verified": True, "qualified": False, "files": len(manifest["files_sha256"])}
    report = json.loads(qualification.read_text(encoding="utf-8-sig"))
    if report.get("schema") != "cybersand-goblin-package-selftest-v1" or report.get("status") != "pass" or report.get("platform") != "Windows":
        raise ValueError("Extracted Windows package self-test did not pass")
    if report.get("manifest_sha256") != sha(manifest_path) or report.get("source_commit") != manifest.get("source_commit") or report.get("source_tree") != manifest.get("source_tree"):
        raise ValueError("Windows self-test qualifies a different package/source")
    rows = report.get("cases", [])
    if len(rows) != 2 or {row.get("fixture") for row in rows} != set(REQUIRED_CASES):
        raise ValueError("Complete actor-workshop and save/reopen cases are required")
    for row in rows:
        if row.get("status") != "pass" or row.get("policy") != "CONTROL" or row.get("budget") != 64 or row.get("seed") != 13 or row.get("termination") != "budget_complete" or row.get("attempted_actions") != 64 or not 1 <= row.get("completed_actions", 0) <= 64 or row.get("assertion_failures") != 0 or row.get("validation_ok") is not True or row.get("completion_marker") is not True:
            raise ValueError("Incomplete extracted Windows self-test evidence")
        for key in ("log", "transcript"):
            path = checked_member(directory, row[key])
            if not path.is_file() or sha(path) != row[key + "_sha256"]:
                raise ValueError("Windows self-test artifact hash mismatch: " + key)
        try:
            from .verify_transcript import load, verify
        except ImportError:
            from verify_transcript import load, verify
        tape = load(checked_member(directory, row["transcript"]))
        readback = verify(tape)
        if not readback["valid"] or readback["summary"]["failures"] or tape["header"].get("provenance") != manifest.get("provenance"):
            raise ValueError("Independent Windows transcript/source readback failed: " + str(readback.get("errors")))
        if tape["header"].get("fixture_id") != row["fixture"] or tape["header"].get("policy") != row["policy"] or tape["header"].get("seed") != row["seed"] or tape["header"].get("budget") != row["budget"] or tape["header"].get("evidence_kind") != "packaged_evaluator":
            raise ValueError("Self-test report does not identify the actual packaged campaign")
        for key in ("termination", "attempted_actions", "completed_actions"):
            if tape["summary"].get(key) != row[key]:
                raise ValueError("Self-test report differs from actual transcript: " + key)
        text = checked_member(directory, row["log"]).read_text(encoding="utf-8-sig")
        results = [line[len("GOBLIN_CAMPAIGN_RESULT "):] for line in text.splitlines() if line.startswith("GOBLIN_CAMPAIGN_RESULT ")]
        if text.splitlines().count("GOBLIN_CAMPAIGN_COMPLETE") != 1 or len(results) != 1 or any(marker in text for marker in ("SCRIPT ERROR:", "Parse Error:", "ERROR:", "Fatal signal", "Segmentation fault")):
            raise ValueError("Actual package log lacks a unique clean completion")
        completion = json.loads(results[0])
        if completion.get("validation", {}).get("ok") is not True or completion.get("validation", {}).get("errors") or completion.get("summary") != tape["summary"]:
            raise ValueError("Godot completion/validation does not match actual transcript")
        required_features = {"brush", "rectangle", "undo", "redo", "play", "save_layout", "reopen_layout"}
        if row["fixture"] == "actor_workshop":
            required_features.add("actor_drive")
        if not all(tape["summary"]["completed_features"].get(name, 0) > 0 for name in required_features):
            raise ValueError("Extracted Windows campaign omitted required actual gameplay features")
    return {"payload_verified": True, "qualified": True, "source_commit": manifest["source_commit"],
            "manifest_sha256": sha(manifest_path), "qualification_sha256": sha(qualification), "cases": len(rows),
            "scope": "hosted extracted Windows developer evaluator; no physical NVIDIA acceptance claim"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-archive", type=Path)
    parser.add_argument("--engine-notices", type=Path)
    parser.add_argument("--vc-runtime", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--verify-extracted", type=Path)
    parser.add_argument("--qualification", type=Path)
    args = parser.parse_args()
    if args.verify_extracted:
        result = verify_extracted(args.verify_extracted.resolve(), args.qualification)
    elif all((args.godot_archive, args.engine_notices, args.vc_runtime, args.out)):
        result = build(args.godot_archive.resolve(), args.engine_notices.resolve(), args.vc_runtime.resolve(), args.out.resolve())
    else:
        parser.error("build requires --godot-archive, --engine-notices, --vc-runtime, --out; or --verify-extracted")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
