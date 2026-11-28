#!/usr/bin/env python3
"""Attach original qualification archives without changing application payload."""
import argparse
from pathlib import Path
import shutil
import tempfile
import zipfile

from package_windows import ACCEPTANCE, MANIFEST, digest, need, safe_name, verify, write_json


def finalize(package, evidence, report, output, source):
    need(not output.exists() and output.resolve() != package.resolve(), "Use a new output archive")
    with tempfile.TemporaryDirectory(prefix="pubpres-evaluation-") as temporary:
        root = Path(temporary)
        with zipfile.ZipFile(package) as archive:
            names = archive.namelist()
            need(len(names) == len(set(name.lower() for name in names)), "Duplicate archive member")
            for member in archive.infolist():
                path = safe_name(member.filename)
                need(not member.is_dir() and (member.external_attr >> 16) & 0o170000 != 0o120000,
                     "Unexpected non-file package entry")
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(member) as incoming, target.open("wb") as outgoing:
                    shutil.copyfileobj(incoming, outgoing)
        manifest = verify(root, source)
        need(set(names) == {*manifest["files_sha256"], MANIFEST, ACCEPTANCE}, "Unlisted original payload")
        qualification = root / "Qualification"
        need(not qualification.exists(), "Package already contains qualification")
        qualification.mkdir()
        shutil.copyfile(root / MANIFEST, qualification / "original-PUBPRES-MANIFEST.json")
        shutil.copyfile(report, qualification / "RESULTS.md")
        records = []
        evidence_names = {file.name.lower() for file in qualification.iterdir()}
        for item in evidence:
            need(item.is_file(), "Missing evidence: " + str(item))
            target = qualification / safe_name(item.name)
            need(item.name.lower() not in evidence_names, "Duplicate Windows evidence filename")
            evidence_names.add(item.name.lower())
            shutil.copyfile(item, target)
            records.append({"path": target.relative_to(root).as_posix(),
                            "sha256": digest(target), "bytes": target.stat().st_size})
        write_json(qualification / "EVIDENCE.json", {
            "schema": "pubpres-executable-evidence-v1", "application_source": source,
            "original_package_sha256": digest(package), "original_package_bytes": package.stat().st_size,
            "meaning": "Original application payload unchanged; added qualification is separately hashed.",
            "archives": records, "physical_windows_nvidia_acceptance": "HOLD"})
        for file in qualification.iterdir():
            manifest["files_sha256"][file.relative_to(root).as_posix()] = digest(file)
        manifest["qualification"] = {"index": "Qualification/EVIDENCE.json", "report": "Qualification/RESULTS.md"}
        write_json(root / MANIFEST, manifest)
        verify(root, source)
        output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(output, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for name in sorted({*manifest["files_sha256"], MANIFEST, ACCEPTANCE}):
                archive.write(root / name, name)
        with zipfile.ZipFile(output) as archive:
            need(archive.testzip() is None, "Final archive CRC verification failed")
        checksum = digest(output)
        output.with_suffix(".zip.sha256").write_text(f"{checksum}  {output.name}\n", encoding="ascii")
        write_json(output.with_suffix(".zip.json"), {"source_commit": source, "sha256": checksum,
                   "bytes": output.stat().st_size, "payload_files": len(manifest["files_sha256"]),
                   "original_package_sha256": digest(package), "physical_acceptance": "HOLD"})
        return checksum


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, action="append", default=[])
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    print(finalize(args.package, args.evidence, args.report, args.output, args.source_sha))
