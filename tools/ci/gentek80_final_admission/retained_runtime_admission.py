#!/usr/bin/env python3
"""Admit retained qualified runtime bytes at their four-file publication child.

This auxiliary verifier does not build, re-stamp, stage or publish a runtime.
It preserves the original validated bundle and distinguishes its built source
from the actual publication checkout and any fresh final-head Workbench run.
"""
from __future__ import annotations

import argparse
import hashlib
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

RUNTIMES = {
    "linux": "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
    "windows": "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
}
MANIFESTS = {
    "linux": "godot/addons/cybersand_native/runtime-provenance.linux.json",
    "windows": "godot/addons/cybersand_native/runtime-provenance.json",
}
PUBLICATION_PATHS = set(RUNTIMES.values()) | set(MANIFESTS.values())
POINTER = re.compile(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n")
SHA = re.compile(r"[0-9a-f]{40}")
HASH = re.compile(r"[0-9a-f]{64}")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def git(candidate: Path, *arguments: str, input_bytes: bytes | None = None) -> bytes:
    completed = subprocess.run(["git", "--no-replace-objects", "-C", str(candidate), *arguments],
                               input=input_bytes, capture_output=True, check=False, timeout=60)
    if completed.returncode:
        raise RuntimeError("Git admission check failed: " + " ".join(arguments) + "\n"
                           + completed.stderr.decode(errors="replace")[-2000:])
    return completed.stdout


def regular(path: Path) -> Path:
    require(path.is_file() and not path.is_symlink(), "Missing or non-regular admission input: " + str(path))
    require(not any(parent.is_symlink() for parent in path.parents),
            "Symlinked admission input directory: " + str(path))
    return path


def payload(path: Path) -> bytes:
    return regular(path).read_bytes()


def read_json(path: Path) -> dict:
    try:
        value = json.loads(payload(path))
    except (OSError, ValueError, UnicodeError) as error:
        raise RuntimeError("Missing or malformed admission JSON: " + str(path)) from error
    require(isinstance(value, dict), "Admission JSON must be an object: " + str(path))
    return value


def tree_entries(candidate: Path, source: str) -> dict[str, tuple[bytes, bytes, bytes]]:
    result = {}
    for row in git(candidate, "ls-tree", "-rz", "--full-tree", source).split(b"\0"):
        if row:
            metadata, name = row.split(b"\t", 1)
            result[name.decode("utf-8")] = tuple(metadata.split())
    return result


def blobs(candidate: Path, entries: dict, paths: set[str]) -> dict[str, bytes]:
    ordered = sorted(paths)
    for path in ordered:
        require(path in entries and entries[path][0] in (b"100644", b"100755")
                and entries[path][1] == b"blob", "Missing or non-regular committed input: " + path)
    data = git(candidate, "cat-file", "--batch", input_bytes=b"".join(entries[p][2] + b"\n" for p in ordered))
    result, offset = {}, 0
    for path in ordered:
        end = data.index(b"\n", offset)
        oid, kind, size = data[offset:end].split()
        size = int(size)
        value = data[end + 1:end + 1 + size]
        require(oid == entries[path][2] and kind == b"blob" and len(value) == size,
                "Invalid committed blob response: " + path)
        result[path] = value
        offset = end + size + 2
    require(offset == len(data), "Trailing committed blob response")
    return result


def assert_working(candidate: Path, committed: dict[str, bytes]) -> dict[str, str]:
    result = {}
    for name, expected in committed.items():
        actual = payload(candidate / name)
        require(actual.replace(b"\r\n", b"\n") == expected,
                "Working source input differs from its committed bytes: " + name)
        result[name] = digest(actual)
    return result


def load_publisher(candidate: Path):
    """Import the unchanged publisher only after its source bytes were checked."""
    directory = candidate / "tools/ci"
    sys.path.insert(0, str(directory))
    try:
        spec = spec_from_file_location("_retained_gentek80_publisher", directory / "gentek80_runtime_publication.py")
        require(spec is not None and spec.loader is not None, "Cannot load the qualified publisher")
        module = module_from_spec(spec)
        spec.loader.exec_module(module)
    finally:
        sys.path.pop(0)
    require(Path(module.engine.ROOT).resolve() == candidate,
            "Publisher dependencies came from a different checkout")
    return module


def pointer_identity(data: bytes, artifact: str) -> dict:
    match = POINTER.fullmatch(data)
    require(match is not None and int(match[2]) > 64, "Invalid canonical runtime LFS pointer: " + artifact)
    return {"artifact": artifact, "sha256": match[1].decode(), "size": int(match[2])}


def validate_manifest(value: dict, platform: str, identity: dict, built_source: str,
                      built_tree: str, run_id: str, run_attempt: str, engine) -> None:
    expected = {"schema_version": 1, "platform": platform, "source_commit": built_source,
                "build_commit": built_source, "source_tree": built_tree,
                "workflow_run": "https://github.com/techrote/cybersand/actions/runs/" + run_id,
                "workflow_attempt": run_attempt, "status": "validated-development-runtime",
                "evidence": engine.EVIDENCE, **identity}
    require(type(value.get("schema_version")) is int and type(value.get("size")) is int,
            "Invalid manifest numeric identity: " + platform)
    for key, wanted in expected.items():
        require(value.get(key) == wanted, "Original provenance mismatch for " + platform + ": " + key)
    build_attempt = value.get("build_attempt")
    require(isinstance(build_attempt, str) and build_attempt.isdecimal()
            and 0 < int(build_attempt) <= int(run_attempt), "Invalid original build attempt: " + platform)
    require(isinstance(value.get("toolchain"), str) and bool(value["toolchain"].strip()),
            "Missing original toolchain identity: " + platform)
    require(isinstance(value.get("validation_sha256"), str) and HASH.fullmatch(value["validation_sha256"]),
            "Missing original validation hash: " + platform)
    require(value.get("validation_output") == engine.BUNDLE_PREFIX + "-" + platform + "-" + run_id + "/validation.json",
            "Unexpected original validation output: " + platform)


def fresh_workbench(candidate: Path, directory: Path, platform: str, published_source: str,
                    published_tree: str, runtime: dict, ledgers: dict, identity_inputs: dict, original: dict,
                    publisher) -> dict:
    value = read_json(directory / "qualification.json")
    publisher.validate_workbench(value, published_source, runtime["sha256"], platform)
    require(value.get("source_tree") == published_tree, "Fresh Workbench source tree differs from final HEAD")
    identity = read_json(directory / "source-runtime-identity.json")
    expected = {"source_commit": published_source, "source_tree": published_tree,
                "runtime_sha256": runtime["sha256"], "runtime_bytes": runtime["size"],
                "source_inputs_sha256": identity_inputs}
    for key, wanted in expected.items():
        require(identity.get(key) == wanted, "Fresh Workbench source identity mismatch: " + key)
    hashes = {name: digest(payload(directory / name)) for name in ("qualification.json", "source-runtime-identity.json")}
    projects = set()
    for row in value["results"][:-1]:
        name = row["case"]
        process_path = directory / (name + "-process.json")
        require(read_json(process_path) == row, "Fresh Workbench process receipt differs: " + name)
        command = row.get("command")
        require(isinstance(command, list) and all(isinstance(word, str) for word in command)
                and command.count("--path") == 1 and command.index("--path") + 1 < len(command),
                "Fresh Workbench command does not identify its project: " + name)
        project = Path(command[command.index("--path") + 1]).resolve()
        projects.add(project)
        require(digest(payload(project / "addons/cybersand_native/bin" / Path(runtime["artifact"]).name)) == runtime["sha256"],
                "Fresh Workbench command used different runtime bytes")
        if name != "import":
            require("--headless" not in command and command.count("--script") == 1
                    and command[command.index("--script") + 1] == "res://tools/qualify_gentek80_workbench.gd",
                    "Fresh Workbench did not execute the graphical all80 script")
            phase_file = "gentek80-workbench-" + name + ".json"
            require(read_json(directory / phase_file) == value[name], "Fresh Workbench phase JSON differs: " + name)
            hashes[phase_file] = digest(payload(directory / phase_file))
        log_file = name + ".log"
        require(digest(payload(directory / log_file)) == row.get("log_sha256"),
                "Fresh Workbench process log is missing or changed: " + name)
        hashes[log_file] = row["log_sha256"]
        hashes[process_path.name] = digest(payload(process_path))
    require(len(projects) == 1, "Fresh Workbench phases used different project directories")
    project = next(iter(projects))
    scripts = {path.relative_to(project).as_posix(): digest(payload(path))
               for path in sorted(project.rglob("*.gd")) if ".godot" not in path.relative_to(project).parts}
    expected_scripts = {name.removeprefix("godot/"): digest(payload(candidate / name))
                        for name in ledgers["build_inputs"] if name.startswith("godot/") and name.endswith(".gd")}
    require(scripts == expected_scripts and identity.get("project_scripts_sha256") == scripts,
            "Fresh Workbench project scripts differ from final source")
    publisher.validate_workbench(original, original["source_commit"], runtime["sha256"], platform)
    require(value["author"]["catalogue_ids"] == original["author"]["catalogue_ids"],
            "Fresh Workbench catalogue differs from qualified build")
    joins = []
    for phase in ("author", "reopen"):
        def maps(report):
            return {row["preset_id"]: (row["source_sha256"], row["recipe_sha256"])
                    for row in report[phase]["cases"] if row.get("case") == "gentek80-" + phase}
        fresh, qualified = maps(value), maps(original)
        require(fresh == qualified and len(fresh) == 80,
                "Fresh Workbench native/recipe output differs from qualified build: " + phase)
        joins.append({"phase": phase, "styles": 80, "matches": True,
                      "outputs_sha256": digest(json.dumps(fresh, sort_keys=True).encode())})
    return {"status": "passed", "source_commit": published_source, "source_tree": published_tree,
            "runtime_sha256": runtime["sha256"], "platform": platform, "styles": 80,
            "original_source_commit": original["source_commit"], "original_output_matches": joins,
            "receipt_sha256": hashes, "project": str(project)}


def verify(candidate: Path, bundle: Path, platform: str, built_source: str,
           published_source: str, published_tree: str, run_id: str,
           run_attempt: str, *, workbench: Path | None = None) -> dict:
    candidate, bundle = Path(candidate).resolve(), Path(bundle).resolve()
    require(platform in RUNTIMES, "Unsupported admission platform")
    require((platform == "linux" and sys.platform.startswith("linux"))
            or (platform == "windows" and sys.platform == "win32"), "Admission must execute on the actual target OS")
    require(all(isinstance(value, str) and SHA.fullmatch(value)
                for value in (built_source, published_source, published_tree)), "Expected exact source/tree identities")
    require(all(isinstance(value, str) and value.isdecimal() and int(value) > 0 for value in (run_id, run_attempt)),
            "Expected original qualification run and attempt")
    require(Path(git(candidate, "rev-parse", "--show-toplevel").decode().strip()).resolve() == candidate,
            "Candidate path must be the Git root")
    require(git(candidate, "rev-parse", "HEAD").decode().strip() == published_source, "Candidate HEAD differs from final source")
    require(git(candidate, "rev-parse", "HEAD^{tree}").decode().strip() == published_tree, "Final candidate tree mismatch")
    require(git(candidate, "show", "-s", "--format=%P", published_source).decode().strip().split() == [built_source],
            "Final publication must have the sole built-source parent")
    require(not git(candidate, "diff", "--cached", "--name-only", "-z"), "Candidate index differs from final HEAD")
    built_tree = git(candidate, "rev-parse", built_source + "^{tree}").decode().strip()
    before, after = tree_entries(candidate, built_source), tree_entries(candidate, published_source)
    changed = {name for name in before.keys() | after.keys() if before.get(name) != after.get(name)}
    require(changed == PUBLICATION_PATHS, "Final publication must change exactly the four runtime/provenance paths")
    require(all(after[name][:2] == (b"100644", b"blob") for name in PUBLICATION_PATHS),
            "Final publication paths must be regular non-executable Git files")
    imports = {name for name in after if name.startswith(("tools/ci/", "tools/architecture/")) and name.endswith(".py")}
    require("tools/ci/gentek80_runtime_publication.py" in imports, "Qualified publisher is absent")
    import_blobs = blobs(candidate, after, imports)
    working_hashes = assert_working(candidate, import_blobs)
    source_suffixes = {".gd", ".tscn", ".tres", ".gdshader"}
    actual_scripts = {path.relative_to(candidate).as_posix()
                      for path in (candidate / "godot").rglob("*")
                      if path.is_file() and path.suffix in source_suffixes
                      and ".godot" not in path.relative_to(candidate).parts}
    tracked_scripts = {name for name in after if name.startswith("godot/") and Path(name).suffix in source_suffixes}
    require(actual_scripts == tracked_scripts, "Untracked or missing Godot source input")
    for directory in (candidate / "tools/ci", candidate / "tools/architecture"):
        require({p.relative_to(candidate).as_posix() for p in directory.rglob("*.py")} <= imports,
                "Untracked Python input can shadow the qualified validator")
    publisher = load_publisher(candidate)
    engine = publisher.engine
    require(engine.RUNTIMES == RUNTIMES and engine.MANIFESTS == MANIFESTS, "Unexpected publisher runtime paths")
    ledgers = engine.input_ledgers(built_source)
    require(engine.input_ledgers(published_source) == ledgers, "Build/native input ledgers changed at publication")
    source_paths = set(ledgers["source_inputs"]) | set(ledgers["build_inputs"])
    working_hashes.update(assert_working(candidate, blobs(candidate, after, source_paths)))
    # qualify.source_identity intentionally hashes every file in these folders,
    # including native_extension/README.md; it is broader than the compilation
    # ledger. Preserve that full raw-byte identity without dropping its extras.
    identity_paths = {path.relative_to(candidate).as_posix()
                      for directory in ("native/include", "native/src", "godot/native_extension")
                      for path in (candidate / directory).rglob("*") if path.is_file()}
    identity_blobs = blobs(candidate, after, identity_paths)
    identity_inputs = assert_working(candidate, identity_blobs)
    require(set(ledgers["source_inputs"]) <= identity_paths
            and all(digest(identity_blobs[name]) == expected
                    for name, expected in ledgers["source_inputs"].items()),
            "Full Workbench source identity differs from canonical compiled inputs")
    working_hashes.update(identity_inputs)
    public = read_json(candidate / publisher.PUBLIC_GALLERY_MANIFEST)
    rendering = public.get("rendering_inputs_sha256")
    require(isinstance(rendering, dict) and bool(rendering), "Missing committed rendering-input ledger")
    for name, expected in rendering.items():
        require(isinstance(name, str) and not PurePosixPath(name).is_absolute() and ".." not in PurePosixPath(name).parts
                and "\\" not in name and isinstance(expected, str) and HASH.fullmatch(expected), "Invalid rendering input")
    render_blobs = blobs(candidate, after, set(rendering))
    require({name: digest(value) for name, value in render_blobs.items()} == rendering,
            "Final Git rendering inputs differ from qualified gallery")
    working_hashes.update(assert_working(candidate, render_blobs))
    published_blobs = blobs(candidate, after, PUBLICATION_PATHS)
    identities, manifests = {}, {}
    for target in RUNTIMES:
        identities[target] = pointer_identity(published_blobs[RUNTIMES[target]], RUNTIMES[target])
        require(payload(candidate / MANIFESTS[target]) == published_blobs[MANIFESTS[target]],
                "Working provenance differs from final Git bytes: " + target)
        manifests[target] = read_json(candidate / MANIFESTS[target])
        validate_manifest(manifests[target], target, identities[target], built_source, built_tree, run_id, run_attempt, engine)
        require({key: manifests[target].get(key) for key in ledgers} == ledgers,
                "Committed provenance input ledgers differ from qualified source: " + target)
    manifest_path = engine.manifest_path(bundle, platform)
    require(payload(manifest_path) == published_blobs[MANIFESTS[platform]],
            "Retained original bundle manifest differs from committed provenance")
    manifest, runtime = manifests[platform], identities[platform]
    for runtime_path in (candidate / runtime["artifact"], bundle / Path(runtime["artifact"]).name):
        regular(runtime_path)
        require(engine.runtime_identity(runtime_path, platform) == runtime, "Materialized runtime differs from final LFS pointer")
    rapier_relative, rapier_pin = engine.RAPIER[platform]
    require(digest(payload(candidate / rapier_relative)) == rapier_pin, "Target Rapier runtime differs from its original pin")
    rapier_pointer = pointer_identity(blobs(candidate, after, {rapier_relative})[rapier_relative], rapier_relative)
    require(rapier_pointer["sha256"] == rapier_pin
            and rapier_pointer["size"] == (candidate / rapier_relative).stat().st_size,
            "Committed Rapier LFS pointer differs from materialized pin")
    report_path = bundle / "validation.json"
    require(digest(payload(report_path)) == manifest["validation_sha256"], "Original validation report hash mismatch")
    report = read_json(report_path)
    require(type(report.get("schema_version")) is int and report["schema_version"] == 1
            and report.get("status") == "passed" and report.get("completed") is True
            and report.get("source_commit") == built_source and report.get("source_tree") == built_tree
            and report.get("platform") == platform and report.get("runtime") == runtime,
            "Original validation report is stale, incomplete or names a different runtime")
    archive_key = "archive_sha256" if platform == "linux" else "archive_sha512"
    archive_pin = engine.GODOT_LINUX_SHA256 if platform == "linux" else engine.windows.GODOT_SHA512
    require(report.get("godot", {}).get("version") == engine.GODOT_VERSION
            and report["godot"].get(archive_key) == archive_pin and report.get("rapier_sha256") == rapier_pin,
            "Original Godot or Rapier qualification pin mismatch")
    # Pure receipt validation deliberately avoids publisher context/verify_bundle:
    # this checkout is the publication child, not the original build commit.
    publisher.verify_case_results(bundle, report)
    original_receipts = {name: row["sha256"] for name, row in report["receipts"].items()}
    fresh = None
    if workbench is not None:
        original = read_json(bundle / publisher.RECEIPTS["workbench"])
        fresh = fresh_workbench(candidate, Path(workbench).resolve(), platform, published_source,
                                published_tree, runtime, ledgers, identity_inputs, original, publisher)
    require(git(candidate, "rev-parse", "HEAD").decode().strip() == published_source
            and git(candidate, "rev-parse", "HEAD^{tree}").decode().strip() == published_tree,
            "Final HEAD changed during admission")
    require(engine.input_ledgers(published_source) == ledgers, "Final input ledger changed during admission")
    require({name: digest(payload(candidate / name)) for name in working_hashes} == working_hashes,
            "Working input bytes changed during admission")
    require(digest(payload(report_path)) == manifest["validation_sha256"]
            and payload(manifest_path) == published_blobs[MANIFESTS[platform]], "Original bundle changed during admission")
    for name, row in report["receipts"].items():
        require(digest(payload(bundle / row["filename"])) == original_receipts[name],
                "Original receipt changed during admission: " + name)
    require(engine.runtime_identity(candidate / runtime["artifact"], platform) == runtime,
            "Final runtime changed during admission")
    return {"schema": "gentek80-retained-runtime-admission-v1", "status": "passed", "platform": platform,
            "scope": "retained-runtime-and-final-head-workbench" if fresh else "retained-runtime-custody-only",
            "built": {"source_commit": built_source, "source_tree": built_tree,
                      "workflow_run_id": run_id, "workflow_attempt": run_attempt},
            "published": {"source_commit": published_source, "source_tree": published_tree,
                          "sole_parent": built_source, "changed_paths": sorted(changed)},
            "executed": {"source_commit": published_source, "source_tree": published_tree,
                         "runtime_sha256": runtime["sha256"]} if fresh else None,
            "runtime": runtime, "rapier_sha256": rapier_pin,
            "original_manifest_sha256": digest(published_blobs[MANIFESTS[platform]]),
            "original_validation_sha256": manifest["validation_sha256"],
            "original_receipt_sha256": original_receipts, "input_ledgers": ledgers,
            "source_identity_inputs_sha256": identity_inputs,
            "rendering_inputs_sha256": rendering, "working_input_bytes_sha256": working_hashes,
            "final_workbench": fresh,
            "admission_workflow": {name: os.environ.get(name) for name in
                                   ("GITHUB_REPOSITORY", "GITHUB_WORKFLOW_REF", "GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")}}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("candidate", "bundle", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--platform", choices=sorted(RUNTIMES), required=True)
    for name in ("built-source", "published-source", "published-tree", "run-id", "run-attempt"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--workbench", type=Path)
    args = parser.parse_args()
    try:
        result = verify(args.candidate, args.bundle, args.platform, args.built_source, args.published_source,
                        args.published_tree, args.run_id, args.run_attempt, workbench=args.workbench)
        code = 0
    except (RuntimeError, OSError, ValueError, KeyError, TypeError, IndexError) as error:
        result = {"schema": "gentek80-retained-runtime-admission-v1", "status": "failed",
                  "platform": args.platform, "built_source": args.built_source,
                  "published_source": args.published_source, "published_tree": args.published_tree,
                  "error": str(error)}
        code = 1
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "output": str(args.output), "error": result.get("error")}))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
