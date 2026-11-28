#!/usr/bin/env python3
"""Independent streaming audit of delivered ZIP bytes against frozen source.

Run from the repository root. Imported repository helpers are byte-bound to
the explicitly supplied frozen commit before any payload is admitted.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import re
import struct
import subprocess
import sys
import zipfile

sys.path.insert(0, str(Path.cwd() / "tools/ci"))
import qualify_strata_workbench as gate
import package_strata_workbench as package

parser = argparse.ArgumentParser()
for name in ("archive", "manifest", "checksum", "linux", "windows", "output"):
    parser.add_argument("--" + name, type=Path, required=True)
for name in ("frozen", "source"):
    parser.add_argument("--" + name, required=True)
parser.add_argument("--extracted", type=Path)
parser.add_argument("--launcher-folder", type=Path)
args = parser.parse_args()
require, sha = gate.require, gate.sha

def git(*parts):
    return subprocess.check_output(["git", "-C", str(gate.ROOT), *parts])

def frozen_hashes(names):
    order = sorted(names)
    data = subprocess.run(["git", "-C", str(gate.ROOT), "cat-file", "--batch"],
        input="".join(args.frozen + ":" + name + "\n" for name in order).encode(), capture_output=True, check=True).stdout
    output, position = {}, 0
    for name in order:
        end = data.index(b"\n", position)
        header = data[position:end].split()
        require(len(header) == 3 and header[1] == b"blob", "Missing frozen source blob " + name)
        count = int(header[2])
        payload = data[end+1:end+1+count]
        output[name] = hashlib.sha256(payload).hexdigest()
        position = end+count+2
    require(position == len(data), "Unexpected source-byte remainder")
    return output

tree = git("rev-parse", args.frozen + "^{tree}").decode().strip()
# This external reader may run in a different checkout from the frozen product.
# Bind every imported repository helper to the supplied source before using it.
helper_hashes = {}
for module in list(sys.modules.values()):
    if getattr(module, "__name__", "") == "__main__":
        continue
    name = getattr(module, "__file__", None)
    if not name or not name.endswith(".py"):
        continue
    path = Path(name).resolve()
    if not path.is_relative_to(gate.ROOT):
        continue
    relative = path.relative_to(gate.ROOT).as_posix()
    data = path.read_bytes().replace(b"\r\n", b"\n")
    expected = git("show", args.frozen + ":" + relative).replace(b"\r\n", b"\n")
    require(data == expected, "Imported audit dependency differs from frozen source " + relative)
    helper_hashes[relative] = hashlib.sha256(data).hexdigest()
for platform in ("linux", "win32"):
    retained = gate.retained_runtime_manifest(platform)
    pin_paths = [retained["runtime_provenance"]["path"], retained["cybersand_runtime"]["path"], retained["rapier_runtime"]["path"]]
    for name in pin_paths:
        require(git("show", "HEAD:" + name) == git("show", args.frozen + ":" + name),
            "HEAD-derived retained pin differs from frozen source " + name)
manifest_bytes = args.manifest.read_bytes()
manifest = json.loads(manifest_bytes)
require(manifest["schema"] == "strata-workbench-evaluation-v1" and manifest["draft_hold"] is True,
        "Wrong evaluator disposition")
require(manifest["source_commit"] == args.source and manifest["source_tree"] == tree, "Package source identity differs")
require(set(manifest["qualification_platforms"]) == {"linux", "win32"}, "Missing platform")
runtime = gate.retained_runtime_manifest("win32")
require(manifest["runtime"] == runtime and manifest["godot_version"] == gate.custody.windows.GODOT_VERSION,
        "Package native or engine identity differs")
archive_sha = sha(args.archive)
require(args.checksum.read_text().strip() == archive_sha + "  " + args.archive.name, "External archive checksum differs")

with zipfile.ZipFile(args.archive) as archive:
    infos = archive.infolist()
    names = [entry.filename for entry in infos]
    require(len(names) == len(set(names)) and len(names) == len({n.casefold() for n in names}), "Duplicate portable ZIP path")
    devices = {"CON", "PRN", "AUX", "NUL", "CONIN$", "CONOUT$", *("COM"+str(n) for n in range(1,10)), *("LPT"+str(n) for n in range(1,10))}
    for entry in infos:
        path = PurePosixPath(entry.filename)
        raw_parts = entry.filename.split("/")
        require(not entry.is_dir() and not path.is_absolute() and ".." not in path.parts
            and "\\" not in entry.filename and not re.match(r"^[A-Za-z]:", entry.filename)
            and path.as_posix() == entry.filename and all(part not in ("", ".", "..") for part in raw_parts)
            and all(part.rstrip(" .") == part and part.split(".")[0].upper() not in devices
                and not any(ord(c) < 32 or ord(c) == 127 or c in ':<>"|?*' for c in part) for part in raw_parts),
            "Unsafe or aliased portable ZIP path")
        require((entry.external_attr >> 16) & 0o170000 != 0o120000, "Linked ZIP entry")
    require(archive.read(package.MANIFEST) == manifest_bytes, "External and embedded payload manifests differ byte-for-byte")
    payload = {}
    for name in names:
        if name == package.MANIFEST:
            continue
        h = hashlib.sha256()
        with archive.open(name) as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                h.update(block)
        payload[name] = h.hexdigest()
    require(payload == manifest["files_sha256"], "ZIP contents differ from complete payload manifest")
    archived = set(git("ls-tree", "-r", "--name-only", args.frozen, "--", *package.ARCHIVE_INPUTS).decode().splitlines())
    materialized = {runtime[key]["path"]:runtime[key]["sha256"] for key in ("cybersand_runtime", "rapier_runtime")}
    omitted = {name:digest for name,digest in package.REGENERATED_RAPIER_IMPORTS.items() if name in archived}
    require(manifest["regenerated_imports_sha256"] == omitted, "Unexpected import omissions")
    original_names = {name for name in archived if not name.startswith("godot/.godot/")
        and ("/bin/" not in name or name in materialized) and name not in omitted}
    original_hashes = frozen_hashes(original_names - set(materialized)) | materialized
    require(original_names <= set(payload), "Archived source file omitted from ZIP")
    for name, digest in original_hashes.items():
        require(payload[name] == digest, "Delivered source bytes differ from frozen Git tree " + name)
    profiles = {PurePosixPath(name).name:digest for name,digest in original_hashes.items()
        if PurePosixPath(name).parent == PurePosixPath("examples/worldgen") and name.endswith(".json")}
    require(manifest["generator_profiles_sha256"] == profiles and len(profiles) > 0, "Canonical profile inventory differs")
    for name,digest in profiles.items():
        require(payload.get("godot/authoring/worldgen/" + name) == digest, "Portable canonical profile bytes differ " + name)
    for name,digest in package.DEPENDENCIES.items():
        require(payload.get(name) == digest, "Pinned dependency differs " + name)
    vc = json.loads(archive.read("vc-runtime-provenance.json").decode("utf-8-sig"))
    require(vc["schema"] == 1 and set(vc["files_sha256"]) == {"vcruntime140.dll", "Microsoft-Visual-C-Runtime-LICENSE.docx", "Microsoft-Visual-Studio-2022-LICENSE.docx"}, "VC provenance incomplete")
    for name,digest in vc["files_sha256"].items():
        require(payload[name] == digest, "VC payload changed " + name)
    vc_binary = archive.read("vcruntime140.dll")
    pe = struct.unpack_from("<I", vc_binary, 0x3c)[0]
    require(vc_binary[:2] == b"MZ" and vc_binary[pe:pe+6] == b"PE\x00\x00\x64\x86"
        and manifest["vc_runtime_sha256"] == payload["vcruntime140.dll"], "VC runtime is not the retained x64 payload")
    expected_launcher = package.launcher_text({"source_commit":args.source})
    require(archive.read("Open Workbench.cmd").decode().replace("\r\n", "\n") == expected_launcher, "Shipped ordinary launcher differs")
    require(all(name in payload for name in ("READ-ME.md", "OWNER-EVALUATION.md", "godot/project.godot")), "Missing owner/application entry")

    expected_source = None
    admitted = {}
    for platform, folder, label in (("linux", args.linux, "linux"), ("win32", args.windows, "windows")):
        report = json.loads((folder / "qualification.json").read_text())
        require(report["platform"] == platform, "Original campaign platform differs from its labelled slot")
        require(report["source_commit"] == args.source and report["source_tree"] == tree, "Original campaign source differs")
        if expected_source is None:
            # All execution inputs are separately bound to frozen source here.
            actual_inputs = frozen_hashes(report["source_inputs_sha256"])
            require(actual_inputs == report["source_inputs_sha256"], "Original campaign inputs differ from committed source")
            expected_source = {k:report[k] for k in ("source_commit", "source_tree", "source_inputs_sha256")}
        gate.verify_campaign(folder, expected_source)
        prefix = "qualification/" + label + "/"
        require(archive.read(prefix + "qualification.json") == (folder / "qualification.json").read_bytes(), "Embedded campaign manifest differs")
        embedded = {name.removeprefix(prefix):digest for name,digest in payload.items() if name.startswith(prefix)}
        originals = dict(report["evidence_sha256"], **{"qualification.json":sha(folder / "qualification.json")})
        require(embedded == originals, "Embedded campaign is not byte-exact original evidence")
        admitted[platform] = {"manifest_sha256":sha(folder / "qualification.json"), "evidence_files":len(report["evidence_sha256"]), "status":report["status"]}

delivery = {"schema":"strata-independent-evaluator-audit-v1", "source_commit":args.source, "source_tree":tree,
    "archive":str(args.archive), "archive_sha256":archive_sha, "archive_bytes":args.archive.stat().st_size,
    "payload_file_count":len(payload), "frozen_archived_files_exact":len(original_hashes), "canonical_profiles_exact":len(profiles),
    "manifest_sha256":sha(args.manifest), "embedded_campaigns":admitted, "frozen_audit_dependencies_sha256":helper_hashes,
    "extracted_execution":"pending", "ordinary_cmd_execution":"pending", "owner_physical_windows11_nvidia":"pending", "draft_hold":True}
if args.extracted:
    report = gate.verify_campaign(args.extracted, expected_source)
    require(report["platform"] == "win32", "Extracted execution is not Windows")
    require(" " in report["project"]["path"] and report["project"]["path"].endswith("godot"), "Extracted project path lacks requested space-containing case")
    require(report["godot"]["sha256"] == payload["Godot_v4.7-stable_win64_console.exe"], "Extracted engine is not shipped engine")
    for name,digest in report["project"]["inputs_sha256"].items():
        require(payload.get("godot/" + name) == digest, "Executed project input is not shipped payload " + name)
    delivery["extracted_execution"] = {"status":"passed", "manifest_sha256":sha(args.extracted / "qualification.json"), "project_path":report["project"]["path"], "evidence_files":len(report["evidence_sha256"])}
if args.launcher_folder:
    folder = args.launcher_folder
    launch = json.loads((folder / "launcher.json").read_text(encoding="utf-8-sig"))
    admitted = launch["admitted"]
    stdout = (folder / "launcher.stdout.log").read_text(encoding="utf-8-sig")
    stderr = (folder / "launcher.stderr.log").read_text(encoding="utf-8-sig")
    markers = [line.removeprefix("STRATA_WORKBENCH_LAUNCH_ADMITTED ") for line in stdout.splitlines() if line.startswith("STRATA_WORKBENCH_LAUNCH_ADMITTED ")]
    require(len(markers) == 1 and json.loads(markers[0]) == admitted, "CMD admission differs from original stdout")
    require(type(launch["exit_code"]) is int and launch["exit_code"] == 0 and type(launch["wrapper_pid"]) is int
        and launch["wrapper_pid"] > 0 and launch["source_revision"] == args.source
        and "Godot Engine v" + gate.custody.windows.GODOT_VERSION in stdout
        and not gate.custody.ERRORS.search(stdout + stderr), "CMD process failed or lacks exact engine/process evidence")
    require(admitted["source_revision"] == args.source and admitted["workbench_script"] == "res://scripts/shared_workbench.gd"
        and type(admitted["world_generation"]) is int and admitted["world_generation"] > 0 and gate.instance_id(admitted["worker_id"])
        and admitted["strata_enabled"] is False and admitted["extent"] == [2048,2048], "CMD did not admit the ordinary default native World")
    require(isinstance(launch["pristine_directory"], str) and " " in launch["pristine_directory"]
        and PureWindowsPath(launch["pristine_directory"]).is_absolute(), "Wrong ordinary launcher directory")
    cmd = re.fullmatch(r"([A-Za-z]:\\Windows\\System32\\cmd\.exe) (.*)", launch["command"], re.IGNORECASE)
    path = str(PureWindowsPath(launch["pristine_directory"]) / "Open Workbench.cmd")
    arguments = '/d /s /c ""' + path + '" --audio-driver Dummy --rendering-method gl_compatibility --rendering-driver opengl3 --quit-after 180"'
    require(cmd is not None and cmd[2] == arguments, "CMD command differs from the frozen ordinary launcher contract")
    normalized = lambda value: value.replace("\\", "/").rstrip("/").casefold()
    if args.extracted:
        extracted = json.loads((args.extracted / "qualification.json").read_text())
        base = normalized(launch["pristine_directory"])
        require(normalized(extracted["project"]["path"]) == base + "/godot"
            and normalized(extracted["godot"]["path"]) == base + "/godot_v4.7-stable_win64_console.exe",
            "CMD receipt and extracted campaign do not use the same shipped directory")
    delivery["ordinary_cmd_execution"] = {"status":"passed", "receipt_sha256":sha(folder / "launcher.json"), "admitted":admitted,
        "stdout_sha256":sha(folder / "launcher.stdout.log"), "stderr_sha256":sha(folder / "launcher.stderr.log")}
delivery["verified_portable_evaluator"] = isinstance(delivery["extracted_execution"], dict) and isinstance(delivery["ordinary_cmd_execution"], dict)
args.output.write_text(json.dumps(delivery, indent=2) + "\n")
print(json.dumps({k:delivery[k] for k in ("source_commit", "archive_sha256", "archive_bytes", "payload_file_count", "frozen_archived_files_exact", "canonical_profiles_exact", "verified_portable_evaluator")}))
