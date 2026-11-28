"""Independent read-only validation of the actual delivered M3 ZIP bytes."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import tarfile
import zipfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def committed_files(repo, source):
    payload = subprocess.check_output([
        "git", "-C", str(repo), "archive", source, "--", "godot", "native/include", "native/src",
        "tools/objectshard", "docs/operations/objectshard-lab-playtest.md",
        "docs/operations/objectshard-m3-preflight-playtest.md", "third_party/godot-runtime.lock.json",
        "third_party/native-toolchain.lock.json", "third_party/rapier-bvh-build.lock.json",
        "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch", "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md"
    ])
    with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
        return {member.name: archive.extractfile(member).read() for member in archive if member.isfile()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--zip", type=Path, required=True)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--qualification", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    committed = committed_files(args.repo, args.source)
    with args.zip.open("rb") as f:
        zip_hash = hashlib.file_digest(f, "sha256").hexdigest()
    result = {"schema": "objectshard-independent-delivered-archive-review-v1", "archive": str(args.zip),
              "archive_sha256": zip_hash, "archive_bytes": args.zip.stat().st_size,
              "source_commit": args.source, "failures": [], "status": "incomplete"}
    def expect(value, message):
        if not value:
            result["failures"].append(message)
    with zipfile.ZipFile(args.zip) as z:
        members = z.infolist()
        names = [i.filename for i in members]
        expect(len(names) == len(set(names)), "Duplicate ZIP name")
        expect(len(names) == len(set(n.casefold() for n in names)), "Windows case-colliding ZIP names")
        for item in members:
            p = PurePosixPath(item.filename)
            expect(not p.is_absolute() and ".." not in p.parts and "\\" not in item.filename and ":" not in item.filename,
                   "Unsafe archive name: " + item.filename)
            expect(item.external_attr >> 16 & 0o170000 != 0o120000, "Archive symlink: " + item.filename)
        manifest = json.loads(z.read("objectshard-lab-manifest.json"))
        expect(manifest.get("schema") == "objectshard-lab-package-v1", "Manifest schema")
        expect(manifest.get("godot", {}).get("version") == "4.7.stable.official.5b4e0cb0f", "Pinned engine version")
        expect(manifest.get("source_commit") == args.source, "Manifest source differs from requested final source")
        tree = subprocess.check_output(["git", "-C", str(args.repo), "rev-parse", args.source + "^{tree}"], text=True).strip()
        expect(manifest.get("source_tree") == tree, "Manifest source tree differs from Git object")
        inventory = manifest["files_sha256"]
        expect(set(names) == set(inventory) | {"objectshard-lab-manifest.json"}, "ZIP contains unverified or missing members")
        for path, expected in inventory.items():
            data = z.read(path)
            expect(sha(data) == expected, "Manifest hash mismatch: " + path)
            expect(not data.startswith(b"version https://git-lfs.github.com/spec/v1\n"), "Unmaterialized LFS pointer: " + path)
        preflight = manifest.get("preflight", {})
        expect(preflight.get("host") == "standalone-exclusive-worker-rehearsal" and preflight.get("production_workbench") is False,
               "Missing or misleading standalone host identity")
        expect(manifest.get("ordinary_production_defaults_changed") is False, "Production defaults claim")
        expect(manifest.get("physical_owner_acceptance") == "not established by automated qualification",
               "Physical owner acceptance claim")
        for path in ["Open ObjectShard Lab.cmd", "Open ObjectShard M3 Preflight.cmd", "Verify ObjectShard Lab.cmd",
                     "godot/object_shard_worker_rehearsal.tscn", "godot/scripts/object_shard_native_worker.gd",
                     "godot/scripts/object_shard_worker_host.gd", "godot/scripts/object_shard_worker_rehearsal.gd",
                     "docs/operations/objectshard-m3-preflight-playtest.md",
                     "godot/tests/probe_object_shard_package_boot.gd",
                     "godot/tests/probe_object_shard_worker_package_boot.gd"]:
            expect(path in inventory, "Missing executable owner surface: " + path)
        for path in ["Open ObjectShard Lab.cmd", "Open ObjectShard M3 Preflight.cmd"]:
            launcher = z.read(path).decode("utf-8")
            expect('set "OBJECTSHARD_PACKAGE_ROOT=%~dp0."' in launcher, "Launcher path fix missing: " + path)
            expect("DisableDelayedExpansion" in launcher, "Delayed expansion enabled: " + path)
            expect(args.source in launcher, "Launcher source missing: " + path)
        candidate = json.loads(z.read("source-built-candidate-provenance.json"))
        expect(candidate.get("source_commit") == args.source and candidate.get("build_commit") == args.source
               and candidate.get("source_tree") == tree, "Native candidate source identity")
        native_path = manifest["native"]["path"]
        expect(candidate.get("sha256") == sha(z.read(native_path)) == manifest["native"]["sha256"], "Native candidate DLL hash")
        expect(candidate.get("source_inputs") == manifest["native"]["source_inputs"], "Native source ledgers differ")
        suffixes = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".tpp"}
        native_inputs = {path: sha(data.replace(b"\r\n", b"\n")) for path, data in committed.items()
                         if path.startswith(("native/include/", "native/src/", "godot/native_extension/"))
                         and PurePosixPath(path).suffix in suffixes}
        expect(candidate.get("source_inputs") == native_inputs, "Incomplete or incorrect exact-commit native source inventory")
        for path, expected in candidate["source_inputs"].items():
            data = z.read(path).replace(b"\r\n", b"\n")
            expect(sha(data) == expected == sha(committed[path].replace(b"\r\n", b"\n")), "Native source bytes: " + path)
        # Independently bind every packaged repository file, including UI,
        # probes and verifier, to immutable Git objects. A self-consistent
        # edited package manifest alone cannot satisfy this source check.
        native_reference = "godot/addons/cybersand_native/retained-runtime-provenance.reference.json"
        native_original = "godot/addons/cybersand_native/runtime-provenance.json"
        expected_source_members = {
            native_reference if path == native_original else path
            for path in committed
            if not path.startswith("godot/.godot/")
            and ("/bin/" not in path or path in (native_path, manifest["rapier"]["path"]))
        }
        expect(expected_source_members.issubset(inventory), "Committed package source inventory missing members")
        source_count = 0
        lfs_count = 0
        for path in sorted(expected_source_members):
            if path not in inventory or path == native_path:
                continue
            original_path = native_original if path == native_reference else path
            expected_data = committed[original_path]
            data = z.read(path)
            pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", expected_data)
            if pointer:
                expect(sha(data) == pointer[1].decode() and len(data) == int(pointer[2]), "Committed LFS payload: " + path)
                lfs_count += 1
            else:
                expect(data == expected_data, "Committed package source bytes: " + path)
                source_count += 1
        expect(z.read("READ-ME.md") == committed["docs/operations/objectshard-m3-preflight-playtest.md"],
               "Delivered front-door guide differs from committed M3 playtest guide")
        result["committed_source_members_verified"] = source_count
        result["committed_lfs_payloads_verified"] = lfs_count
        result["exact_native_inputs_verified"] = len(native_inputs)
        for path in [native_path, manifest["rapier"]["path"], "Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe"]:
            data = z.read(path)
            expect(data[:2] == b"MZ", "Not PE: " + path)
            offset = struct.unpack_from("<I", data, 0x3c)[0]
            expect(data[offset:offset+4] == b"PE\0\0" and struct.unpack_from("<H", data, offset+4)[0] == 0x8664,
                   "Not AMD64 PE: " + path)
        result["manifest_sha256"] = sha(z.read("objectshard-lab-manifest.json"))
        result["verified_files"] = len(inventory)
        result["native_sha256"] = sha(z.read(native_path))
        result["rapier_sha256"] = sha(z.read(manifest["rapier"]["path"]))
        result["godot_gui_sha256"] = sha(z.read("Godot_v4.7-stable_win64.exe"))
        result["godot_console_sha256"] = sha(z.read("Godot_v4.7-stable_win64_console.exe"))
        expect(manifest["godot"].get("runtime_sha256") == result["godot_gui_sha256"]
               and manifest["godot"].get("console_sha256") == result["godot_console_sha256"], "Pinned engine manifest hashes")
        expect(result["rapier_sha256"] == "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7",
               "Selected cooperative-BVH Rapier runtime differs")
        result["source_tree"] = tree
        if args.qualification:
            q = json.loads(args.qualification.read_text())
            expect(q.get("status") == "passed" and q.get("source_commit") == args.source and q.get("source_tree") == tree,
                   "Qualification does not pass for this exact source")
            expect(q.get("runtime", {}).get("native_sha256") == result["native_sha256"], "Qualified native runtime mismatch")
            expect(q.get("runtime", {}).get("rapier_sha256") == result["rapier_sha256"], "Qualified Rapier mismatch")
            expect(q.get("runtime", {}).get("godot_sha256") == result["godot_console_sha256"], "Qualified Windows console engine mismatch")
            expect(q.get("runtime", {}).get("godot_version") == manifest["godot"]["version"], "Qualified engine version mismatch")
            expect(q.get("package_manifest_sha256") == result["manifest_sha256"], "Replay used a different delivered manifest")
            for path, expected in q.get("lab_source_inputs", {}).items():
                expect(path in inventory and sha(z.read(path)) == expected, "Qualified Lab source mismatch: " + path)
            result["qualification_sha256"] = sha(args.qualification.read_bytes())
    result["status"] = "passed" if not result["failures"] else "failed"
    result["scope"] = "Read-only archive/source byte custody. Actual Windows launches, displayed performance and owner physical acceptance remain separate evidence."
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["status"] == "passed" else 1)


if __name__ == "__main__":
    main()
