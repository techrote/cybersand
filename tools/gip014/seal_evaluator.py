#!/usr/bin/env python3
"""Seal actual extracted qualification evidence beside unchanged evaluator bytes.

No code or manifest-tracked payload is changed. The final ZIP is re-extracted
and independently verified; base and final archive digests remain distinct.
This is developer Draft/HOLD delivery, not release publication or owner GPU acceptance.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import stat
import tempfile
import zipfile

import package_evaluator as package

SCHEMA = "cybersand-goblin-qualified-delivery-v1"
ROOT_NAME = "CyberSand-goblin"
MAX_ARCHIVE_BYTES = 4 * 1024 * 1024 * 1024
MAX_EVIDENCE_BYTES = 256 * 1024 * 1024
MAX_MEMBER_BYTES = 1024 * 1024 * 1024
MAX_FILES = 20000
REPORT = "delivery/extracted-selftest.json"
RECORD = "delivery/qualified-delivery.json"
OWNER_INDEX = "OPEN-ME.md"
MUTABLE_MEMORY = {"test-output/goblin-memory.json", "test-output/goblin-memory.previous.json",
                  "test-output/goblin-memory.partial.json", "test-output/goblin-memory-receipt.json"}


def encoded(value) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def archive_members(archive: zipfile.ZipFile) -> dict:
    entries, folded, total = {}, set(), 0
    for item in archive.infolist():
        if item.is_dir() or not item.filename.startswith(ROOT_NAME + "/"):
            raise ValueError("Unexpected evaluator archive root/directory member")
        name = item.filename[len(ROOT_NAME) + 1:]
        if not package.safe_relative(name) or name.casefold() in folded:
            raise ValueError("Unsafe or duplicate archive member")
        if stat.S_ISLNK(item.external_attr >> 16) or item.file_size > MAX_MEMBER_BYTES:
            raise ValueError("Linked or oversized archive member")
        total += item.file_size
        if total > MAX_ARCHIVE_BYTES or len(entries) >= MAX_FILES:
            raise ValueError("Evaluator archive exceeds finite expansion bounds")
        entries[name], folded = item, folded | {name.casefold()}
    return entries


def member_hash(archive: zipfile.ZipFile, item: zipfile.ZipInfo) -> str:
    digest = hashlib.sha256()
    with archive.open(item) as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_base(base: Path, directory: Path, manifest: dict) -> None:
    if base.is_symlink() or not base.is_file() or base.stat().st_size > MAX_ARCHIVE_BYTES:
        raise ValueError("Base evaluator must be a bounded ordinary archive")
    expected = {**manifest["files_sha256"], package.MANIFEST: package.sha(directory / package.MANIFEST)}
    with zipfile.ZipFile(base) as archive:
        entries = archive_members(archive)
        if set(entries) != set(expected):
            raise ValueError("Base archive member set differs from original manifest")
        for name, checksum in expected.items():
            if member_hash(archive, entries[name]) != checksum or package.sha(package.checked_member(directory, name)) != checksum:
                raise ValueError("Base archive bytes differ from the qualified extraction")


def referenced_evidence(directory: Path, report: dict, manifest: dict) -> dict[str, Path]:
    result, total = {}, 0
    def add(name, checksum):
        nonlocal total
        if not isinstance(name, str) or not isinstance(checksum, str):
            raise ValueError("Missing qualification artifact identity")
        path = package.checked_member(directory, name)
        if not path.is_file() or package.sha(path) != checksum:
            raise ValueError("Qualification artifact changed before sealing")
        if name in manifest["files_sha256"]:
            if checksum != manifest["files_sha256"][name]:
                raise ValueError("Qualification changed an original payload member")
            return
        if not name.startswith("test-output/") or name.casefold() in {item.casefold() for item in MUTABLE_MEMORY}:
            raise ValueError("Only isolated immutable qualification artifacts may be sealed")
        if path.stat().st_size > 32 * 1024 * 1024:
            raise ValueError("Qualification artifact exceeds finite member bound")
        if name not in result:
            total += path.stat().st_size
            result[name] = path
        if len(result) > 128 or total > MAX_EVIDENCE_BYTES:
            raise ValueError("Qualification evidence exceeds finite delivery bound")
    add(report["import_log"], report["import_log_sha256"])
    for row in report["cases"]:
        for key in ("log", "transcript"):
            add(row[key], row[key + "_sha256"])
    replay = report["portable_replay"]
    for key in ("original", "transcript", "log"):
        add(replay[key], replay[key + "_sha256"])
    graphical = report["graphical_smoke"]
    add(graphical["log"], graphical["log_sha256"])
    for item in graphical["screenshots"]:
        add(item["path"], item["sha256"])
    memory = report["memory_roundtrip"]
    for key in ("first_corpus", "source_corpus"):
        add(memory[key], memory[key + "_sha256"])
    imported = memory["fresh_profile_import"]
    add(imported["staged_corpus"], imported["staged_sha256"])
    add(imported["admission_log"], imported["admission_log_sha256"])
    for item in memory["archive_checks"]:
        add(item["path"], item["sha256"])
    if manifest.get("successor_contract_version") == 3:
        lineage = report["authored_lineage"]
        for key in ("log", "report"):
            add(lineage[key], lineage[key + "_sha256"])
    return result


def owner_index(manifest: dict, report: dict, base_sha: str, report_sha: str) -> bytes:
    rows = "\n".join(f"| {row['fixture']} | {row['policy']} | {row['attempted_actions']} | {row['completed_actions']} | {row['elapsed_seconds']:.2f} |" for row in report["cases"])
    lineage = ("\nThe extracted authored-lineage gate completed four additional native cases and 20\n"
               "ordinary actions. Fresh and restored authored starts passed material equality;\n"
               "material retained after actual simulation exposure stayed distinct from its\n"
               "authored reopen, with the equality oracle explicitly inapplicable. The raw\n"
               "source-bound report and all four tapes are retained beside this evaluator.\n") \
        if manifest.get("successor_contract_version") == 3 else ""
    historical_paths = ("tools/gip014/cases/retained-clock-070-original.json.gz",
                        "tools/gip014/cases/retained-clock-070-custody.json")
    historical = ("\n## Retained earlier oracle observation\n\n"
                  "tools/gip014/cases/retained-clock-070-original.json.gz preserves the actual\n"
                  "five-action failed tape at source 070addb0fdae2240f22e663a2299cef739f83c05.\n"
                  "The adjacent retained-clock-070-custody.json records exact identities and\n"
                  "the independent test-oracle applicability adjudication. These are forensic\n"
                  "data; their original automatic candidate remains unresolved. Reproduction\n"
                  "uses that recorded source/runtime. The current ReplayCase catalogue keeps\n"
                  "its own exact package-identity guard. No automatic reduction or production\n"
                  "gameplay-defect claim is attached to this five-action case.\n") \
        if all(name in manifest["files_sha256"] for name in historical_paths) else ""
    text = f"""# CyberSand goblin developer evaluator

This extracted Windows evaluator passed the retained hosted qualification.
It remains **Draft/HOLD**. Physical NVIDIA owner acceptance is not claimed.

## Open the laboratory

Run **Open goblin.cmd**, choose a scenario and personality, and press Start.
The ordinary Workbench runs inside an explicitly disposable application profile.
Each campaign has a bounded action budget and wall deadline. The owner's window
may stay open for normal interactive use.

The launcher validates bounded experiment memory and retains it between clean
launches at test-output/goblin-memory.json, with one previous backup. The shipped
default memory is empty. Portable examples are explicit imports; their retained
records become unverified hints until actual play admits fresh observations.

Use PowerShell from this directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\\Open goblin.ps1" -Mode Replay
powershell -NoProfile -ExecutionPolicy Bypass -File ".\\Open goblin.ps1" -ClearCorpus
```

Clear removes only fixed experiment memory; archived game tapes remain available.
READ-ME.md contains the complete developer guide and capability limits.

## Actual extracted qualification

| Scenario | Personality | Attempted | Completed | Real seconds |
|---|---|---:|---:|---:|
{rows}

The portable replay gate passed semantic comparison. Exact asynchronous physics
trajectories are reported separately and are not promised across runs or platforms.
The persistent-memory gate saved two actual nonempty corpora, retained one backup,
validated import into a fresh profile, and cleared memory while preserving native
archives. The graphical gate includes actual Workbench screenshots.
{lineage}

## Exact identities and evidence

- Source commit: {manifest['source_commit']}
- Source tree: {manifest['source_tree']}
- Godot SHA256: {manifest['provenance']['godot_sha256']}
- Native SHA256: {manifest['provenance']['native_sha256']}
- Rapier SHA256: {manifest['provenance']['rapier_sha256']}
- Original base ZIP SHA256: {base_sha}
- Extracted qualification report SHA256: {report_sha}

delivery/qualified-delivery.json records the evidence manifest and qualification
scope. delivery/extracted-selftest.json and the referenced test-output files
retain actual observations. The original evaluator manifest's initial candidate
status is historical; its tracked bytes have not been changed. The later delivery
record and fresh final extraction establish this package's qualification.
{historical}
"""
    return text.encode()


def verify_final(path: Path, expected: dict) -> dict:
    with tempfile.TemporaryDirectory(prefix="goblin-seal-check-", dir=path.parent) as temporary:
        root = Path(temporary) / ROOT_NAME
        root.mkdir()
        with zipfile.ZipFile(path) as archive:
            entries = archive_members(archive)
            for name, item in entries.items():
                destination = package.checked_member(root, name)
                destination.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(item) as source, destination.open("xb") as target:
                    shutil.copyfileobj(source, target, 1024 * 1024)
        record = json.loads((root / RECORD).read_text(encoding="utf-8"))
        if record != expected:
            raise ValueError("Final delivery record differs after extraction")
        manifest = json.loads((root / package.MANIFEST).read_text(encoding="utf-8"))
        names = set(manifest["files_sha256"]) | {package.MANIFEST, RECORD} | set(record["supplementary_files_sha256"])
        if set(entries) != names or package.sha(root / package.MANIFEST) != record["base_manifest_sha256"]:
            raise ValueError("Final evaluator changed the original manifest or file closure")
        for name, checksum in record["supplementary_files_sha256"].items():
            if package.sha(package.checked_member(root, name)) != checksum:
                raise ValueError("Final supplementary evidence changed during extraction")
        result = package.verify_extracted(root, root / REPORT)
        if result.get("qualified") is not True:
            raise ValueError("Final extracted evaluator did not independently qualify")
        return result


def seal(base: Path, directory: Path, qualification: Path, output: Path, receipt: Path) -> dict:
    if output.exists() or receipt.exists() or output.resolve() in {base.resolve(), receipt.resolve()} or output.suffix.lower() != ".zip":
        raise ValueError("Final evaluator and receipt must be new distinct outputs")
    if qualification.is_symlink() or not qualification.is_file() or qualification.stat().st_size > 2 * 1024 * 1024:
        raise ValueError("Qualification report must be an ordinary bounded file")
    verified = package.verify_extracted(directory, qualification)
    if verified.get("qualified") is not True:
        raise ValueError("An unqualified evaluator cannot be sealed")
    manifest = json.loads((directory / package.MANIFEST).read_text(encoding="utf-8"))
    if type(manifest.get("successor_contract_version")) is not int or manifest["successor_contract_version"] not in (2, 3):
        raise ValueError("Successor delivery contract is required")
    verify_base(base, directory, manifest)
    report = json.loads(qualification.read_text(encoding="utf-8-sig"))
    sources = referenced_evidence(directory, report, manifest)
    base_sha = package.sha(base)
    generated = {REPORT: qualification.read_bytes(), "delivery/base-verification.json": encoded(verified),
                 OWNER_INDEX: owner_index(manifest, report, base_sha, package.sha(qualification))}
    additions = {name: package.sha(path) for name, path in sources.items()}
    additions.update({name: hashlib.sha256(data).hexdigest() for name, data in generated.items()})
    if (set(additions) | {RECORD}) & (set(manifest["files_sha256"]) | {package.MANIFEST}):
        raise ValueError("Sealing would overwrite original evaluator payload")
    record = {"schema": SCHEMA, "status": "qualified_hosted_windows_draft_hold",
              "created_utc": datetime.now(timezone.utc).isoformat(), "source_commit": manifest["source_commit"],
              "source_tree": manifest["source_tree"], "base_zip_sha256": base_sha, "base_zip_bytes": base.stat().st_size,
              "base_manifest_sha256": package.sha(directory / package.MANIFEST), "qualification_report": REPORT,
              "supplementary_files_sha256": additions, "original_payload_changed": False,
              "physical_nvidia_acceptance": False, "scope": "Hosted extracted Windows developer evaluator; Draft/HOLD"}
    generated[RECORD] = encoded(record)
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_suffix(output.suffix + ".partial")
    if partial.exists():
        raise ValueError("A previous partial sealing attempt is retained")
    shutil.copyfile(base, partial)
    with zipfile.ZipFile(partial, "a", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, source in sorted(sources.items()):
            archive.write(source, ROOT_NAME + "/" + name)
        for name, data in sorted(generated.items()):
            archive.writestr(ROOT_NAME + "/" + name, data)
    final = verify_final(partial, record)
    if package.sha(base) != base_sha:
        raise ValueError("Original base archive changed during sealing")
    partial.replace(output)
    result = {"schema": SCHEMA, "status": "pass", "source_commit": manifest["source_commit"],
              "base_zip_sha256": base_sha, "base_zip_bytes": base.stat().st_size,
              "final_zip_sha256": package.sha(output), "final_zip_bytes": output.stat().st_size,
              "base_verification": verified, "final_verification": final,
              "delivery_record_sha256": hashlib.sha256(generated[RECORD]).hexdigest(),
              "original_payload_changed": False, "scope": record["scope"]}
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_bytes(encoded(result))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("base", "extracted", "qualification", "out", "receipt"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        result = seal(args.base.resolve(), args.extracted.resolve(), args.qualification.resolve(), args.out.resolve(), args.receipt.resolve())
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        print(json.dumps({"status": "failed", "error": str(error)}))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
