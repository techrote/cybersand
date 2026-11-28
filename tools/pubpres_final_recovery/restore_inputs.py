#!/usr/bin/env python3
"""Restore exact original artifacts and bind new application inputs separately."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import zipfile

from identity import ROOT, HERE, digest
from retained_runtime import BINDING, make_binding
from run_campaign import source_identity
from results import need
from run_focus import write_json
import engine_admission


def download(record, output):
    need(not output.exists(), "Preserve previous original artifact downloads")
    output.parent.mkdir(parents=True, exist_ok=True)
    endpoint = "repos/techrote/cybersand/actions/artifacts/" + str(record["id"])
    metadata = json.loads(subprocess.check_output(["gh", "api", endpoint], text=True, timeout=120))
    need(metadata.get("id") == record["id"] and metadata.get("name") == record["name"]
         and metadata.get("expired") is False and metadata.get("digest") == "sha256:" + record["sha256"]
         and metadata.get("workflow_run", {}).get("id") == record["run"]
         and metadata.get("workflow_run", {}).get("head_sha") == record["source"],
         "Artifact service identity differs from prospective external pin")
    write_json(output.with_suffix(".metadata.json"), metadata)
    with output.open("xb") as stream:
        subprocess.run(["gh", "api", endpoint + "/zip"], stdout=stream, check=True, timeout=600)
    need(digest(output) == record["sha256"], "Downloaded archive differs from pinned original")
    return metadata


def extract(archive, output):
    need(not output.exists(), "Use a fresh artifact extraction")
    # Reuse the reviewed Windows-safe canonical archive path predicate on both
    # platforms; no source, executable or receipt is admitted by extraction.
    payload = engine_admission.load_bounded_payload()
    seen, total = set(), 0
    with zipfile.ZipFile(archive) as bundle:
        need(bundle.testzip() is None, "Original artifact ZIP CRC failed")
        for member in bundle.infolist():
            need(member.orig_filename == member.filename, "Noncanonical ZIP member")
            name = member.orig_filename[:-1] if member.is_dir() else member.orig_filename
            relative = payload.relative(name)
            need(name.casefold() not in seen and not stat.S_ISLNK(member.external_attr >> 16),
                 "Duplicate, case-colliding or linked artifact member")
            seen.add(name.casefold()); total += member.file_size
            need(len(seen) < 30000 and total < 2 * 1024 ** 3, "Unbounded artifact inventory")
            path = output / relative
            if member.is_dir(): path.mkdir(parents=True, exist_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(bundle.read(member))
    return {"members": len(seen), "uncompressed_bytes": total, "crc_checked": True}


def restore_native(source_root, platform, output, *, existing_archive=None):
    pin = json.loads((HERE / "retained_artifacts.json").read_bytes())
    need(platform in ("linux", "windows") and not output.exists(), "Invalid native restore destination")
    record = pin[platform]
    archive = existing_archive or output.parent / (output.name + "-original.zip")
    metadata = None if existing_archive else download(record, archive)
    need(digest(archive) == record["sha256"], "Native archive differs from original pin")
    original = output.parent / (output.name + "-original")
    extraction = extract(archive, original)
    application = source_identity(source_root)
    binding = make_binding(source_root, application, original / "C", target_platform=platform)
    need(binding["original_build"]["source_commit"] == pin["runtime_source"], "Retained C build source differs")
    donor = json.loads((original / "D/PUBPRES-RUNTIME.json").read_bytes())
    need(donor["source_commit"] == pin["frozen_donor"], "Retained D build source differs")
    output.mkdir()
    for role in ("C", "D"):
        shutil.copytree(original / role, output / role)
    write_json(output / "C" / BINDING, binding)
    custody = {"schema": "pubpres-recovery-restored-native-v1", "original_artifact": record,
        "archive_sha256": digest(archive), "metadata": metadata, "extraction": extraction,
        "application": binding["application"], "reuse_binding": binding,
        "scope": "Exact input-equivalent retained native only; unchanged original build identity, no inherited runtime execution or gameplay qualification."}
    write_json(output / "RESTORED-NATIVE.json", custody)
    return custody


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--native-archive", type=Path)
    parser.add_argument("--engine-record", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    need(not output.exists(), "Preserve earlier restore records")
    output.mkdir(parents=True)
    result = {"native": restore_native(args.source.resolve(), args.platform, output / "runtime",
                                      existing_archive=args.native_archive.resolve() if args.native_archive else None)}
    if args.engine_record:
        need(args.platform == "windows", "The source-qualified atomic payload is a Windows binary")
        record = json.loads(args.engine_record.read_bytes())
        archive = output / "engine-original.zip"
        metadata = download(record, archive)
        payload = engine_admission.load_bounded_payload()
        identity = {"build_source": record["source"], "build_run": record["run"], "build_attempt": record["attempt"],
                    "proof_sha256": record["proof_sha256"]}
        build = payload.restore(archive, output / "engine", archive_sha256=record["sha256"], **identity)
        result["engine"] = {"original_artifact": record, "admission": identity, "metadata": metadata, "build": build}
    write_json(output / "RESTORE.json", result)
    print(json.dumps({"restored": list(result), "application": result["native"]["application"], "physical_acceptance": "HOLD"}))


if __name__ == "__main__": main()
