#!/usr/bin/env python3
"""Independently bind a Windows candidate archive to Git and its actual PE DLL.

Static native identity only. This neither executes Windows nor establishes
application qualification or physical NVIDIA acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import zipfile


DLL = "cybersand_native.windows.x86_64.dll"
BUILD_CONTRACT = (
    ".github/workflows/objectshard-m4-completion.yml",
    "third_party/native-toolchain.lock.json",
    "tools/requirements-build.txt",
    "tools/build_native_extension_windows.sh",
    "tools/build_pinned_godot_cpp.sh",
    "tools/ci/native_candidate_identity.py",
    "godot/addons/cybersand_native/cybersand_native.gdextension",
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def need(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def git(repo: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(repo), *args], timeout=120)


def review(args: argparse.Namespace) -> dict:
    metadata = json.loads(args.metadata.read_text())
    artifact = next(a for a in metadata["artifacts"] if a["id"] == args.artifact_id)
    raw = args.archive.read_bytes()
    need(len(raw) == artifact["size_in_bytes"] and "sha256:" + sha(raw) == artifact["digest"],
         "Native archive differs from externally pinned GitHub artifact")
    need(artifact["workflow_run"]["head_sha"] == args.source_sha, "Artifact source differs")
    tree = git(args.repo, "rev-parse", args.git_ref + "^{tree}").decode().strip()
    with zipfile.ZipFile(args.archive) as archive:
        names = [i.filename for i in archive.infolist() if not i.is_dir()]
        need(len(names) == 2 and set(names) == {"candidate-provenance.json", DLL},
             "Candidate archive has missing, duplicated or unregistered members")
        ledger_raw = archive.read("candidate-provenance.json")
        provenance = json.loads(ledger_raw)
        payload = archive.read(DLL)
    need(type(provenance.get("schema_version")) is int and provenance["schema_version"] == 1
         and provenance.get("kind") == "source-built-windows-candidate", "Wrong candidate provenance schema/kind")
    need(provenance.get("source_commit") == args.source_sha and provenance.get("build_commit") == args.source_sha
         and provenance.get("source_tree") == tree, "Candidate source, build or tree differs")
    need(provenance.get("artifact") == "godot/addons/cybersand_native/bin/" + DLL,
         "Wrong candidate native runtime path")
    need(type(provenance.get("size")) is int and provenance["size"] == len(payload)
         and provenance.get("sha256") == sha(payload), "Candidate native payload size/hash differs")

    names = git(args.repo, "ls-tree", "-r", "--name-only", "-z", args.git_ref).decode().split("\0")
    suffixes = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
    inputs = {p for p in names if p.startswith(("native/include/", "native/src/", "godot/native_extension/"))
              and Path(p).suffix in suffixes}
    need(set(provenance.get("source_inputs", {})) == inputs, "Incomplete registered native source inventory")
    source = {p: sha(git(args.repo, "show", args.git_ref + ":" + p).replace(b"\r\n", b"\n"))
              for p in sorted(inputs)}
    need(source == provenance["source_inputs"], "Native candidate input hash differs from exact Git source")
    contract = {p: sha(git(args.repo, "show", args.git_ref + ":" + p)) for p in BUILD_CONTRACT}

    need(len(payload) >= 64 and payload[:2] == b"MZ", "Native runtime lacks DOS header")
    pe = struct.unpack_from("<I", payload, 0x3C)[0]
    need(pe + 26 <= len(payload) and payload[pe:pe + 4] == b"PE\0\0", "Native runtime lacks actual PE header")
    machine = struct.unpack_from("<H", payload, pe + 4)[0]
    characteristics = struct.unpack_from("<H", payload, pe + 22)[0]
    optional = struct.unpack_from("<H", payload, pe + 24)[0]
    need(machine == 0x8664 and optional == 0x20B and bool(characteristics & 0x2000),
         "Native runtime is not an AMD64 PE32+ DLL")
    with tempfile.TemporaryDirectory(prefix="native-pe-review-", dir=args.scratch) as temporary:
        dll = Path(temporary) / DLL
        dll.write_bytes(payload)
        inspected = subprocess.check_output(["objdump", "-p", str(dll)], timeout=60)
    normalized_inspection = inspected.replace(str(dll).encode(), DLL.encode())
    text = normalized_inspection.decode("utf-8", errors="strict")
    export_sections = text.split("[Ordinal/Name Pointer] Table")
    need(len(export_sections) == 2, "Actual PE lacks a unique named export table")
    export_table = export_sections[1].split("\n\n", 1)[0]
    exports = [line.split()[-1] for line in export_table.splitlines() if line.lstrip().startswith("[")]
    need("cybersand_native_library_init" in exports,
         "Actual PE export table lacks the native initialization entry")
    imports = re.findall(r"DLL Name:\s*(\S+)", text)
    need(bool(imports) and all(name.lower() == "kernel32.dll" or
                              re.fullmatch(r"api-ms-win-crt-[a-z0-9-]+\.dll", name.lower()) for name in imports),
         "Native runtime has an unreviewed dynamic dependency")
    result = {
        "schema": "objectshard-m4-independent-windows-native-artifact-review-v1",
        "status": "passed-static-identity",
        "artifact": {"id": args.artifact_id, "bytes": len(raw), "sha256": sha(raw)},
        "workflow_run": artifact["workflow_run"], "job_id": args.job_id,
        "source_commit": args.source_sha, "reviewed_git_ref": args.git_ref, "source_tree": tree,
        "build_commit": provenance["build_commit"], "candidate_provenance_sha256": sha(ledger_raw),
        "native_source_inputs": source, "build_contract_inputs": contract,
        "dll": {"bytes": len(payload), "sha256": sha(payload), "pe_offset": pe,
                "coff_machine": hex(machine), "optional_header": hex(optional),
                "dll_characteristic": True, "initialization_export_present": True, "imports": imports},
        "objdump_version": subprocess.check_output(["objdump", "--version"], text=True, timeout=30).splitlines()[0],
        "normalized_objdump_output_sha256": sha(normalized_inspection),
        "objdump_normalization": "Replace the temporary DLL filename with its portable basename; table bytes unchanged.",
        "limitations": ["Static PE/source inspection does not execute the DLL.",
                        "Native source equivalence does not qualify changed application or workflow inputs.",
                        "Physical Windows/NVIDIA acceptance remains HOLD without physical owner evidence."]}
    if args.baseline_source:
        before = {p: sha(git(args.repo, "show", args.baseline_source + ":" + p).replace(b"\r\n", b"\n"))
                  for p in sorted(inputs)}
        result["baseline_comparison"] = {
            "source": args.baseline_source, "all_registered_native_inputs_equal": before == source,
            "changed_native_inputs": [p for p in source if before[p] != source[p]],
            "changed_build_contract_inputs": [p for p in contract if
                sha(git(args.repo, "show", args.baseline_source + ":" + p)) != contract[p]]}
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("archive", "metadata", "repo", "scratch", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--artifact-id", type=int, required=True)
    parser.add_argument("--job-id", type=int, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--git-ref", required=True)
    parser.add_argument("--baseline-source")
    args = parser.parse_args()
    result = review(args)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": result["status"], "source": result["source_commit"],
                      "native_inputs": len(result["native_source_inputs"]), "dll": result["dll"]}))


if __name__ == "__main__":
    main()
