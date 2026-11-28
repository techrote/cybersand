"""Stream-authenticate independently downloaded fresh Windows build artifacts."""
import datetime
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
PLATFORM = ROOT / "build/m3-platform/repair-windows"
SOURCE = "e034f2294663e0485cfb9adcc8ada46a6e977cee"
TREE = "246e7324ca618d98c43a0ed54fe19bc86a155877"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def streamsha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    remote = json.loads((OUT / "remote-crossbuild-readback.json").read_text())
    inventory = json.loads((OUT / "source-inventory.json").read_text())
    report = {"schema": "objectshard-independent-windows-crossbuild-review-v1", "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "reviewer": "review_custody independent of implementation and download workstream", "source_commit": SOURCE, "source_tree": TREE,
              "workflow_run": "https://github.com/techrote/cybersand/actions/runs/44999117090", "build_job": 137136516082,
              "remote_readback_sha256": sha((OUT / "remote-crossbuild-readback.json").read_bytes()), "failures": [], "artifacts": []}
    def expect(condition, message):
        if not condition:
            report["failures"].append(message)
    job = next(row for row in remote["jobs"] if row["id"] == report["build_job"])
    expect(job["status"] == "completed" and job["conclusion"] == "success", "Actual fresh build job unsuccessful")
    archives = {}
    for artifact_id in [14745122677, 14745236878]:
        metadata = next(row for row in remote["artifacts"] if row["id"] == artifact_id)
        path = PLATFORM / ("objectshard-m3-repair-artifact-" + str(artifact_id) + ".zip")
        digest = streamsha(path)
        expect(path.stat().st_size == metadata["size_in_bytes"] and "sha256:" + digest == metadata["digest"], "Remote artifact archive identity: " + str(artifact_id))
        expect(metadata["workflow_run"]["head_sha"] == SOURCE and metadata["workflow_run"]["id"] == 44999117090 and not metadata["expired"], "Artifact workflow/source metadata")
        archive = zipfile.ZipFile(path)
        archives[artifact_id] = archive
        expect(len(archive.namelist()) == len(set(archive.namelist())), "Duplicate artifact member")
        members = []
        for item in archive.infolist():
            with archive.open(item) as stream:
                digest_member = hashlib.file_digest(stream, "sha256").hexdigest()
            extracted = PLATFORM / str(artifact_id) / item.filename
            if extracted.is_file():
                expect(streamsha(extracted) == digest_member, "Extracted artifact member changed: " + item.filename)
            members.append({"path": item.filename, "bytes": item.file_size, "sha256": digest_member})
        report["artifacts"].append({"id": artifact_id, "url": metadata["url"], "name": metadata["name"], "archive_sha256": digest, "archive_bytes": path.stat().st_size, "members": members})
    candidate_archive = archives[14745122677]
    expect(set(candidate_archive.namelist()) == {"cybersand_native.windows.x86_64.dll", "candidate-provenance.json"}, "Candidate artifact exact inventory")
    provenance_data = candidate_archive.read("candidate-provenance.json")
    candidate = json.loads(provenance_data)
    native = candidate_archive.read("cybersand_native.windows.x86_64.dll")
    expect(candidate["source_commit"] == SOURCE and candidate["build_commit"] == SOURCE and candidate["source_tree"] == TREE, "Candidate committed source identity")
    expect(candidate["size"] == len(native) and candidate["sha256"] == sha(native), "Candidate binary identity")
    expect(candidate["source_inputs"] == inventory["native_inputs"] and len(candidate["source_inputs"]) == 116, "Complete exact Git native input inventory")
    pe = struct.unpack_from("<I", native, 0x3c)[0]
    machine = struct.unpack_from("<H", native, pe + 4)[0]
    optional = struct.unpack_from("<H", native, pe + 24)[0]
    flags = struct.unpack_from("<H", native, pe + 22)[0]
    expect(native[:2] == b"MZ" and native[pe:pe+4] == b"PE\0\0" and machine == 0x8664 and optional == 0x20b and flags & 0x2000, "Windows AMD64 PE DLL contract")
    report.update(candidate_provenance_sha256=sha(provenance_data), native_sha256=sha(native), native_bytes=len(native), native_inputs_verified=116,
                  native_pe={"machine": hex(machine), "optional_magic": hex(optional), "dll_flag": bool(flags & 0x2000)})
    build = archives[14745236878]
    expect(set(build.namelist()) == {"bindings/performance.jsonl", "bindings/receipt.json", "bindings/command.log", "extension/performance.jsonl", "extension/receipt.json", "extension/command.log", "scons.log", "source-commit.txt"}, "Crossbuild exact evidence inventory")
    expect(build.read("source-commit.txt").decode().strip() == SOURCE, "Build source file")
    report["build_receipts"] = []
    for stage, command in [("bindings", ["tools/build_pinned_godot_cpp.sh", "windows"]), ("extension", ["tools/build_native_extension_windows.sh"])]:
        receipt_bytes = build.read(stage + "/receipt.json")
        row = json.loads(receipt_bytes)
        log = build.read(stage + "/command.log")
        source = row["source"]
        expect(row["command"] == command and row["status"] == "passed" and row["returncode"] == 0 and row["complete"] is True and row["natural_completion"] is True and row["timed_out"] is False, "Real compiler completion: " + stage)
        expect(source["commit"] == SOURCE and source["tree"] == TREE and source["tracked_delta_sha256"] is None and source["run_id"] == "44999117090" and source["run_attempt"] == "1", "Source-bound compiler receipt: " + stage)
        expect(sha(log) == row["log_sha256"], "Compiler log hash: " + stage)
        policy = row["execution_policy"]
        actual_policy = subprocess.check_output(["git", "-C", str(ROOT), "show", SOURCE + ":" + policy["path"]])
        expect(sha(actual_policy) == policy["sha256"] and policy["scale"] == 1, "Compiler watchdog policy: " + stage)
        if stage == "bindings":
            expect(b"scons: done building targets." in log and b"Compiling" in log, "Fresh complete bindings compilation log")
        else:
            expect(b"x86_64-w64-mingw32-g++" in log and b"cyber_object_shard_lab.cpp" in log and b"object_shard_coordinator.cpp" in log, "Fresh ObjectShard extension command")
        report["build_receipts"].append({"stage": stage, "source": source, "elapsed_seconds": row["elapsed_seconds"], "receipt_sha256": sha(receipt_bytes), "log_sha256": sha(log), "build_complete": True, "resource_scope": row["resources"]["scope"]})
    report["status"] = "passed" if not report["failures"] else "failed"
    report["scope"] = "Fresh e034 Windows cross-compilation and immutable candidate custody only; actual final Windows launched ZIP and Linux qualification remain separate mandatory evidence."
    report["measurement_caveat"] = "Compiler resource observations are direct_process_only; no total compiler child or gameplay resource claim."
    (OUT / "windows-crossbuild-review.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k:v for k,v in report.items() if k not in ["artifacts", "build_receipts"]}, indent=2))
    for archive in archives.values():
        archive.close()
    raise SystemExit(bool(report["failures"]))


if __name__ == "__main__":
    main()
