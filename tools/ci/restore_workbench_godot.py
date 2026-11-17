#!/usr/bin/env python3
"""Restore the reviewed Windows engine artifact and verify its source join.

The artifact identity is checked before extraction. Payload provenance must match
the current builder, ordered source patches and dependency lock. This does not
substitute for executing the final application on Windows.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def relative(name):
    path = PurePosixPath(name)
    need(isinstance(name, str) and name and str(path) == name and
         not path.is_absolute() and ".." not in path.parts and "\\" not in name,
         "Unsafe engine path: " + str(name))
    need(all(part and not re.search(r'[<>:"|?*\x00-\x1f]', part) and
             not part.endswith((".", " ")) and
             not re.fullmatch(r"(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?", part)
             for part in path.parts), "Windows-incompatible engine path: " + name)
    return path


def locks():
    build = read(ROOT / "third_party/workbench-godot.lock.json")
    delivery = read(ROOT / "third_party/workbench-godot-evaluation.lock.json")
    need(delivery.get("schema") == "workbench-godot-evaluation-lock-v1" and
         delivery.get("repository") == "techrote/cybersand", "Wrong engine artifact repository or schema")
    for key in ("artifact_sha256", "build_provenance_sha256"):
        need(re.fullmatch(r"[0-9a-f]{64}", delivery.get(key, "")), "Unpinned engine digest: " + key)
    for key in ("artifact_id", "workflow_run"):
        need(type(delivery.get(key)) is int and delivery[key] > 0, "Unpinned engine workflow identity: " + key)
    need(re.fullmatch(r"[0-9a-f]{40}", delivery.get("application_source", "")), "Unpinned engine build source")
    return build, delivery


def verify_payload(directory):
    directory = Path(directory).resolve()
    build, delivery = locks()
    proof_path = directory / "build-provenance.json"
    need(digest(proof_path) == delivery["build_provenance_sha256"], "Engine provenance differs from qualified artifact")
    proof = read(proof_path)
    need(proof.get("schema") == "workbench-godot-build-provenance-v1" and
         proof.get("complete") is True and proof.get("custom_engine") is True and
         proof.get("public_api_equivalent") is True, "Incomplete engine build/API qualification")
    need(proof.get("upstream_commit") == build["source_commit"] and
         proof.get("patches") == build["patches"] and proof.get("version") == build["version"] and
         proof.get("scope") == build["scope"], "Engine source patch or build scope differs")
    need(proof.get("application_source") == delivery["application_source"] and
         str(proof.get("workflow_run")) == str(delivery["workflow_run"]), "Engine build/run identity differs")
    for field, file in (("lock", ROOT / "third_party/workbench-godot.lock.json"),
                        ("builder", ROOT / "tools/ci/build_workbench_godot.py")):
        need(proof[field]["sha256"] == digest(file) and proof[field]["bytes"] == file.stat().st_size,
             "Current engine build input differs: " + field)
    for patch in build["patches"]:
        need(digest(ROOT / relative(patch["path"])) == patch["sha256"], "Current engine patch drift")
    records = proof.get("payload_files", {})
    need(isinstance(records, dict) and records, "Missing engine payload ledger")
    actual = set()
    for file in directory.rglob("*"):
        need(not file.is_symlink(), "Engine payload contains a symlink")
        if file.is_file():
            actual.add(file.relative_to(directory).as_posix())
    need(actual == set(records) | {"build-provenance.json"}, "Unexpected or missing engine payload files")
    need(len({name.casefold() for name in actual}) == len(actual), "Case-colliding engine payload")
    for name, record in records.items():
        file = directory / relative(name)
        need(file.is_file() and file.stat().st_size == record["bytes"] and digest(file) == record["sha256"],
             "Engine payload drift: " + name)
    for role, key in (("gui_executable", "output_gui"), ("console_executable", "output_console")):
        need(proof.get(role) == "bin/" + build[key], "Unexpected engine executable role")
        record = proof["executables"][build[key]]
        need(record["sha256"] == digest(directory / proof[role]) and
             record["pe"]["unresolved_non_system_imports"] == [], "Unqualified engine runtime dependency")
    api = read(directory / "api-equivalence.json")
    need(api.get("api_equal_except_declared_build_labels") is True and
         api.get("interface_bytes_equal") is True and
         api.get("ignored_header_fields") == ["version_build", "version_full_name"],
         "Engine public API equivalence evidence is incomplete")
    return proof


def restore(archive, output):
    _, delivery = locks()
    need(digest(archive) == delivery["artifact_sha256"], "Engine artifact archive digest mismatch")
    need(not output.exists(), "Use a fresh engine extraction directory")
    output.mkdir(parents=True)
    seen = set()
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            # ZipInfo can normalize platform separators and truncate NULs while
            # parsing. Validate the original archive spelling before accepting
            # an OS-dependent alias for a different destination.
            need(member.orig_filename == member.filename, "Non-canonical engine archive member")
            name = member.orig_filename[:-1] if member.is_dir() else member.orig_filename
            path = relative(name)
            need(name.casefold() not in seen and not stat.S_ISLNK(member.external_attr >> 16),
                 "Duplicate or linked engine archive member")
            seen.add(name.casefold())
            destination = output / path
            if member.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(bundle.read(member))  # CRC checked on read.
    proof = verify_payload(output)
    return {"archive_sha256": digest(archive), "source": proof["upstream_commit"],
            "version": proof["version"], "artifact": delivery, "payload_files": len(proof["payload_files"])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--download", action="store_true", help="Use the job-scoped GitHub CLI token; never embedded credentials")
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    _, delivery = locks()
    args.evidence.mkdir(parents=True, exist_ok=True)
    if args.download:
        need(not args.archive.exists(), "Refusing to overwrite an engine archive")
        endpoint = f"repos/{delivery['repository']}/actions/artifacts/{delivery['artifact_id']}"
        metadata = json.loads(subprocess.check_output(["gh", "api", endpoint], text=True, timeout=120))
        (args.evidence / "artifact-metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
        need(metadata.get("expired") is False and metadata.get("digest") == "sha256:" + delivery["artifact_sha256"] and
             metadata.get("workflow_run", {}).get("id") == delivery["workflow_run"] and
             metadata.get("workflow_run", {}).get("head_sha") == delivery["application_source"],
             "Engine artifact metadata does not match its qualified source")
        args.archive.parent.mkdir(parents=True, exist_ok=True)
        with args.archive.open("xb") as stream:
            subprocess.run(["gh", "api", endpoint + "/zip"], stdout=stream, check=True, timeout=600)
    report = restore(args.archive, args.output.resolve())
    (args.evidence / "restore.json").write_text(json.dumps(report, indent=2) + "\n")
    print("WORKBENCH_ENGINE_RESTORE", json.dumps(report))


if __name__ == "__main__":
    main()
