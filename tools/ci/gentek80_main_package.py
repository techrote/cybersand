#!/usr/bin/env python3
"""Package the qualified Gentek/main join without rebuilding or restamping native code.

The accepted landscape packager supplies the ordinary Workbench launcher,
retained-runtime verification and source payload. This auxiliary wrapper adds
the combined graphical receipts, byte-bound sample saves and selection guide.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile
import zipfile

ASSETS_SHA256 = "1ecfef2bca82e73200cc686ce225f8e60a5bccd49a9853cc12f66863d11e06f1"
GALLERY = "https://github.com/techrote/cybersand/blob/fea465b014757fce9000be6b30e368d5ab187c43/docs/images/gentek80-integration/README.md"
STYLES = ["ring-pier", "tripod-frame", "cascade-terrace", "scalloped-vault",
          "suspended-deck", "buttress-wall", "cathedral-megaframe"]
GUIDE = "docs/operations/gentek80-evaluation.md"
NATIVE_MANIFESTS = ["godot/addons/cybersand_native/runtime-provenance.json",
                    "godot/addons/cybersand_native/runtime-provenance.linux.json"]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read(path: Path) -> dict:
    require(path.is_file() and not path.is_symlink(), "Missing or linked input: " + str(path))
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), "Expected JSON object: " + str(path))
    return value


def write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def member_name(name: str) -> str:
    path = PurePosixPath(name)
    require(name and "\\" not in name and ":" not in name and not path.is_absolute()
            and ".." not in path.parts and path.as_posix() == name, "Unsafe archive name: " + name)
    return name


def zip_entries(bundle: zipfile.ZipFile) -> list[zipfile.ZipInfo]:
    entries, seen, total = [], set(), 0
    for item in bundle.infolist():
        name = member_name(item.filename.rstrip("/") if item.is_dir() else item.filename)
        require(name.casefold() not in seen, "Duplicate archive member: " + name)
        seen.add(name.casefold())
        require((item.external_attr >> 16) & 0o170000 != 0o120000, "Archive symlink: " + name)
        total += item.file_size
        require(item.file_size <= 512 * 1024 * 1024 and total <= 1536 * 1024 * 1024,
                "Archive exceeds its payload allowance")
        if not item.is_dir():
            entries.append(item)
    return entries


def load_packager(candidate: Path):
    sys.path[:0] = [str(candidate / "tools"), str(candidate / "tools/ci")]
    path = candidate / "tools/package_workbench_landscape_review.py"
    spec = importlib.util.spec_from_file_location("gentek_main_landscape_packager", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    require(module.ROOT.resolve() == candidate, "Packager came from another checkout")
    return module


def verify_integration(directory: Path, identity: dict, candidate: Path, expected_runtime: dict) -> tuple[dict, dict]:
    report = read(directory / "qualification.json")
    require(report.get("schema") == "gentek80-main-integration-v1"
            and all(report.get(key) is True for key in
                    ("passed", "completed", "independent_processes", "archive_unchanged", "graphical_requested")),
            "Packaging requires completed graphical combined Workbench qualification")
    require(report.get("source") == identity and identity["local_delta"] == [],
            "Integration source differs from the clean packaging source")
    helpers = {}
    for relative in ("tools/architecture/gentek80_main_integration.py", "tools/architecture/qualify.py"):
        data = (candidate / relative).read_bytes().replace(b"\r\n", b"\n")
        committed = subprocess.check_output(["git", "-C", str(candidate), "show", "HEAD:" + relative], timeout=60)
        require(data == committed.replace(b"\r\n", b"\n"), "Uncommitted integration helper: " + relative)
        helpers[relative] = hashlib.sha256(data).hexdigest()
    require(report.get("execution_helpers_sha256") == helpers, "Integration execution helpers changed after execution")
    platform = report.get("platform")
    require(platform == "win32", "Windows sample starts require actual Windows integration execution")
    manifest = read(candidate / NATIVE_MANIFESTS[0])
    runtime = report.get("runtime", {})
    require(runtime == expected_runtime
            and runtime.get("native_source_inputs") == manifest["source_inputs"]
            and runtime.get("runtime_build_commit") == manifest["build_commit"]
            and runtime.get("cybersand_runtime", {}).get("sha256") == manifest["sha256"],
            "Integration used a different retained native runtime")
    rows = report.get("results", [])
    require([row.get("case") for row in rows] == ["import", "author", "reopen"],
            "Integration process chain is incomplete")
    for row in rows:
        name = row["case"]
        require(row.get("passed") is True and row.get("returncode") == 0 and not row.get("timed_out")
                and read(directory / (name + "-process.json")) == row
                and sha(directory / (name + ".log")) == row.get("log_sha256"),
                "Missing or changed integration process evidence: " + name)
    phases = report.get("phases", {})
    require(set(phases) == {"author", "reopen"}, "Integration phase receipts are incomplete")
    phase_readback = {}
    for phase, receipt in phases.items():
        original = directory / ("gentek-main-" + phase + ".json")
        decoded = read(original)
        decoder = "utf-8"
        if decoded != receipt and platform == "win32":
            # The frozen runner used Path.read_text() without an encoding.
            # Windows' original cp1252 default changed UI status characters in
            # the aggregate only. Compare the complete original object through
            # that exact decoder; do not drop or rewrite any field or evidence.
            decoder = "cp1252"
            decoded = json.loads(original.read_bytes().decode(decoder))
        require(decoded == receipt
                and receipt.get("completed") is True and receipt.get("failures") == 0
                and receipt.get("catalogue_choices") == 93 and receipt.get("style_ids") == STYLES and receipt.get("styles") == 7
                and receipt.get("source_commit") == identity["source_commit"]
                and receipt.get("os") == "Windows" and receipt.get("display") != "headless",
                "Invalid Windows graphical phase receipt: " + phase)
        phase_readback[phase] = {"original_file_sha256": sha(original),
                                 "aggregate_file_decoder": decoder, "complete_object_equal": True}
    require(phases["author"]["process_id"] != phases["reopen"]["process_id"],
            "Independent reopen process is missing")
    require(set(report.get("native_material_replay", {})) == set(STYLES), "Sample replay identities are incomplete")
    for receipt in phases.values():
        samples = {row["id"]: row["identity"] for row in receipt.get("cases", []) if row.get("case") == "gentek"}
        require(samples == report["native_material_replay"], "Sample identities differ between author and reopen")
    require(bool(report.get("screenshots")), "Combined graphical evidence is absent")
    for name, digest in report["screenshots"].items():
        require(Path(name).name == name and name.endswith(".png") and sha(directory / name) == digest,
                "Screenshot is absent or changed: " + name)
        require((directory / name).read_bytes()[:8] == b"\x89PNG\r\n\x1a\n", "Invalid PNG evidence")
    return report, phase_readback


def exact_archive(package: Path, archive: Path, packager) -> None:
    require(not archive.exists() and not archive.is_relative_to(package), "Archive must be a new file outside its payload")
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in sorted(package.rglob("*")):
            require(not path.is_symlink(), "Package symlink: " + str(path))
            if path.is_file():
                bundle.write(path, path.relative_to(package).as_posix())
    with tempfile.TemporaryDirectory(prefix="gentek-main-extract-", dir=archive.parent) as temporary:
        extracted = Path(temporary)
        with zipfile.ZipFile(archive) as bundle:
            for item in zip_entries(bundle):
                target = extracted / item.filename
                target.parent.mkdir(parents=True, exist_ok=True)
                with bundle.open(item) as source, target.open("wb") as destination:
                    shutil.copyfileobj(source, destination)
        packager.verify_package(extracted)
        expected = {p.relative_to(package).as_posix(): sha(p) for p in package.rglob("*") if p.is_file()}
        actual = {p.relative_to(extracted).as_posix(): sha(p) for p in extracted.rglob("*") if p.is_file()}
        require(actual == expected, "Extracted ZIP differs from the exact package payload")
    archive.with_suffix(archive.suffix + ".sha256").write_text(sha(archive) + "  " + archive.name + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("candidate", "assets-zip", "landscape-evidence", "integration-evidence", "output", "archive"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    candidate = args.candidate.resolve(strict=True)
    landscape = args.landscape_evidence.resolve(strict=True)
    integration = args.integration_evidence.resolve(strict=True)
    output, archive = args.output.resolve(), args.archive.resolve()
    require(not output.exists() and not archive.exists(), "Package output and archive must be new")
    require(sha(args.assets_zip) == ASSETS_SHA256, "Original admitted Windows asset ZIP changed")
    packager = load_packager(candidate)
    identity = packager.source_identity()
    windows_runtime = packager.windows.verify_retained_runtime(candidate)
    report, phase_readback = verify_integration(integration, identity, candidate, windows_runtime)
    manifest, maps = packager.load_maps(packager.MANIFEST)
    item = next(row for row in maps if row["name"] == "graftloom-slipway")
    require(report.get("landscape") == item, "Integration fixture differs from pinned Graftloom")
    landscape_report = read(landscape / "qualification.json")
    require([row.get("name") for row in landscape_report.get("maps", [])] == [item["name"]],
            "Use the exact-source --map graftloom-slipway landscape qualification")
    preserved_manifests = {name: sha(candidate / name) for name in NATIVE_MANIFESTS}
    assets = set(packager.DEPENDENCIES) | {"vcruntime140.dll", "vc-runtime-provenance.json"}
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="gentek-main-assets-", dir=output.parent) as temporary:
        stage = Path(temporary)
        with zipfile.ZipFile(args.assets_zip) as bundle:
            names = {item.filename for item in zip_entries(bundle)}
            require(assets <= names, "Original package lacks Windows dependency assets")
            for name in sorted(assets):
                (stage / name).write_bytes(bundle.read(name))
        one_map = dict(manifest, maps=[item])
        one_map_path = stage / "graftloom-manifest.json"
        write(one_map_path, one_map)
        packager.build(argparse.Namespace(dependencies=stage, qualification=landscape,
                       manifest=one_map_path, fixture_dir=landscape / "fixtures", output=output, archive=None))
    launcher_hash = sha(output / "Open Workbench.cmd")
    saved = output / "userdata/roaming/Godot/app_userdata/Cyber Sand Reference Sandbox/workbench"
    original_saves = integration / "profile/userdata/Godot/app_userdata/Cyber Sand Reference Sandbox/workbench"
    samples = {}
    for style in STYLES:
        name = "setup-gentek-main-" + style + ".json"
        source = original_saves / name
        expected = report["native_material_replay"][style]
        require(sha(source) == expected.get("saved_file_sha256"), "Sample save differs from executed receipt: " + style)
        value = read(source)
        require(value.get("format") == "cybersand-generated-start-v1" and value.get("version") == 1
                and value.get("generation", {}).get("sha256") == expected["source_sha256"]
                and value["generation"].get("recipe_sha256") == expected["recipe_sha256"], "Sample generator identity differs")
        shutil.copyfile(source, saved / name)
        samples[name] = {"sha256": sha(saved / name), "native_replay_identity": expected}
    evidence = output / "qualification/gentek-main-integration"
    evidence.mkdir()
    for path in sorted(integration.iterdir()):
        if path.is_file() and path.suffix in (".json", ".log", ".png"):
            shutil.copyfile(path, evidence / path.name)
    guide = output / GUIDE
    guide.parent.mkdir(parents=True, exist_ok=True)
    guide.write_bytes(subprocess.check_output(["git", "-C", str(candidate), "show", "HEAD:" + GUIDE], timeout=60))
    sample_rows = "\n".join("| `gentek-main-" + style + "` | " + style.replace("-", " ").title() + " |" for style in STYLES)
    (output / "READ-ME.md").write_text(f"""# CyberSand — 80 Genteks with accepted Shared Workbench

Extract the complete ZIP and run **Open Workbench.cmd**. This opens ordinary interactive Shared Workbench.
Open **New from generator → Architectural Generator** for 80 Genteks plus the 13 existing presets (93 choices).
Use a style card's **Find style**, enable one card at 100%, select **Generate preview**, then **Install into workbench**.
Save valued work before installing another world. The full selection and Windows test procedure is in `{GUIDE}`.

## Ready to load examples

Enter a name in Setup and click **Load start**. Generated starts open the generator preview; use **Install into workbench**.

| Setup name | Example |
| --- | --- |
| `my-canvas` | Original Graftloom Slipway R6, 2048×1024, 13,839 rectangles |
{sample_rows}

The Cathedral sample includes Midge and a small native material patch. Select Midge in **Pilot**, press **P** to play,
and use the ordinary movement controls. Pause before painting. Save a named start, close the app, reopen it and load
the same name to check persistence. Saves stay under this extracted folder's `userdata` directory.
These sample starts preserve authored structures, edits and actors; they do not save an evolved simulation snapshot.

## Evidence and identity

Application source: `{identity['source_commit']}`; tree `{identity['source_tree']}`.
Native binaries retain their original source/build identities in the unchanged provenance manifests.
Combined graphical qualification platform: `{report['platform']}`; Godot: `{report['godot_version']}`.
Actual screenshots, source-bound author/reopen receipts and process logs are in `qualification/gentek-main-integration`.
`main-integration-manifest.json` binds the supplied sample saves and qualification source; `evaluation-manifest.json`
hashes the complete delivered payload. The original [complete 80-Gentek gallery]({GALLERY}) retains its original source.

Try the six repaired CLASSIC examples, the detailed Cathedral, a freshly selected advanced showcase and an existing
preset. Reopen Graftloom after using the generator. Leave Art unopened while doing so, then open it only when desired.
Automated graphical evidence does not establish human gameplay feel on the owner's physical GPU.
This remains Draft/HOLD awaiting explicit owner merge approval.
""", encoding="utf-8")
    supplemental = {"schema": "gentek80-main-evaluation-v1", "source": identity,
                    "native_manifests_sha256": preserved_manifests, "original_assets_zip_sha256": ASSETS_SHA256,
                    "integration_platform": report["platform"], "integration_qualification_sha256": sha(integration / "qualification.json"),
                    "original_phase_readback": phase_readback,
                    "landscape_qualification_sha256": sha(landscape / "qualification.json"),
                    "samples": samples, "gallery_url": GALLERY,
                    "helper_sha256": sha(Path(__file__)), "launcher_sha256": launcher_hash}
    write(output / "main-integration-manifest.json", supplemental)
    evaluation = read(output / "evaluation-manifest.json")
    evaluation["gentek_main_integration_manifest"] = "main-integration-manifest.json"
    evaluation["files_sha256"] = packager.payload_files(output)
    write(output / "evaluation-manifest.json", evaluation)
    packager.verify_package(output)
    require(preserved_manifests == {name: sha(output / name) for name in NATIVE_MANIFESTS},
            "Native provenance changed during packaging")
    require(packager.source_identity() == identity and sha(output / "Open Workbench.cmd") == launcher_hash,
            "Source or ordinary Workbench launcher changed during packaging")
    exact_archive(output, archive, packager)
    print(json.dumps({"archive": str(archive), "sha256": sha(archive), "bytes": archive.stat().st_size,
                      "source_commit": identity["source_commit"], "samples": len(samples), "passed": True}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
