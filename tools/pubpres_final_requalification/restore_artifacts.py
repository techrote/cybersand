#!/usr/bin/env python3
"""Restore only the three archive-pinned retained inputs for new execution."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import sys
import zipfile

from contract import ROOT, need, registration

sys.path.insert(0, str(ROOT / "tools/pubpres_final_engine"))
import payload


def extract_exact(archive: Path, output: Path, expected: dict) -> dict:
    need(payload.file_record(archive) == {"bytes": expected["bytes"], "sha256": expected["sha256"]},
         "Retained artifact ZIP does not match the registered bytes")
    need(not output.exists(), "Refusing to replace an existing retained payload")
    seen, records = set(), {}
    with zipfile.ZipFile(archive) as bundle:
        # Validate the whole namespace before creating any member.
        for info in bundle.infolist():
            need(info.orig_filename == info.filename, "Non-canonical artifact member")
            name = info.filename[:-1] if info.is_dir() else info.filename
            payload.relative(name)
            need(name.casefold() not in seen and not stat.S_ISLNK(info.external_attr >> 16),
                 "Duplicate, case-colliding or linked artifact member")
            seen.add(name.casefold())
        output.mkdir(parents=True)
        for info in bundle.infolist():
            if info.is_dir():
                continue
            target = output / payload.relative(info.filename)
            target.parent.mkdir(parents=True, exist_ok=True)
            h, count = hashlib.sha256(), 0
            with bundle.open(info) as source, target.open("xb") as destination:
                while block := source.read(1024 * 1024):
                    h.update(block)
                    count += len(block)
                    destination.write(block)
            need(count == info.file_size, "Artifact member size differs")
            records[info.filename] = {"bytes": count, "sha256": h.hexdigest(), "zip_crc32": f"{info.CRC:08x}"}
    return {"archive": payload.file_record(archive), "all_member_crcs_verified": True, "members": records}


def validate_metadata(metadata: dict, expected: dict) -> None:
    need(metadata.get("id") == expected["id"] and metadata.get("expired") is False
         and metadata.get("size_in_bytes") == expected["bytes"]
         and metadata.get("digest") == "sha256:" + expected["sha256"]
         and metadata.get("workflow_run", {}).get("id") == expected["workflow_run"]
         and metadata.get("workflow_run", {}).get("head_sha") == expected["source_commit"],
         "Artifact metadata belongs to a different source, run or archive")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    reg = registration()
    need(not args.output.exists(), "Use a fresh retained-input directory")
    args.output.mkdir(parents=True)
    args.evidence.mkdir(parents=True, exist_ok=True)
    report = {"schema": "pubpres-retained-font-input-restoration-v1", "complete": False,
              "registration": reg, "artifacts": {}, "physical_acceptance": "HOLD"}
    report_path = args.evidence / "restoration.json"
    def save():
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    save()
    for role, expected in reg["artifacts"].items():
        endpoint = f"repos/{expected['repository']}/actions/artifacts/{expected['id']}"
        metadata = json.loads(subprocess.check_output(["gh", "api", endpoint], text=True, timeout=120))
        validate_metadata(metadata, expected)
        archive = args.output / (role + ".zip")
        with archive.open("xb") as stream:
            subprocess.run(["gh", "api", endpoint + "/zip"], stdout=stream, check=True, timeout=600)
        record = extract_exact(archive, args.output / role, expected)
        report["artifacts"][role] = {"metadata": metadata, **record}
        save()
    native = args.output / "native/C"
    actual = {p.relative_to(native).as_posix(): payload.file_record(p) for p in native.rglob("*") if p.is_file()}
    need(actual == reg["native_files"], "Retained C native build inventory differs")
    proof = payload.verify_payload(args.output / "engine", **reg["engine_identity"])
    need(payload.digest(args.output / "engine" / proof["gui_executable"]) == reg["engine_gui_sha256"],
         "Admitted retained engine is not the registered GUI executable")
    report.update(complete=True, native_files=actual, engine_proof_sha256=reg["engine_identity"]["proof_sha256"],
                  engine_gui_sha256=reg["engine_gui_sha256"])
    save()
    print(json.dumps({"complete": True, "artifact_ids": [v["id"] for v in reg["artifacts"].values()],
                      "physical_acceptance": "HOLD"}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
