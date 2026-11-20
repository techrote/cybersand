#!/usr/bin/env python3
"""Supplemental three-mixture Workbench acceptance with immutable F/S3 custody.

The GDScript entry point is external to both the candidate and the Windows ZIP.
No application file is copied, patched, shadowed or relabelled by this runner.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import traceback

sys.dont_write_bytecode = True

FINAL = "bf1bd8c8e6f189b36a3cb0f582185e5d529297d0"
TREE = "546750300019d2e5534e96d4e1dd751bc28d9f2e"
BUILT = "82da41a945b1d98e0267a2a20b56ec66d83f71f6"
ORIGINAL_ORCHESTRATION = "f69b68a88401b28b3fe688c3d070162ebcd090c5"
ORIGINAL_ASSEMBLY_RUN = "44690026779"
CONFIG_SHA = "feb46ab177a4a6c6faca34947e385d2bcd499ff43b2e8b6696cbef5b124326d9"
ARCHIVE_SHA = "1ecfef2bca82e73200cc686ce225f8e60a5bccd49a9853cc12f66863d11e06f1"
ARCHIVE_BYTES = 92410079
ASSEMBLY_SHA = "5d8fcd406a60f7da88262bf7b26d267038f6fe6dd5ed769dab1801f7c27c8a42"
ENGINE_SHA = {
    "linux": "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75",
    "windows_console": "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c",
    "windows_gui": "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8",
}
HELPERS = {
    "retained_runtime_admission.py": "baa42413bbebdeae031dfcf41f73b127b5bc1ff982b0c997d35dd3d34fc6971b",
    "package_retained_gentek80.py": "735a620b3b02aa0c3578a9e7d7125489519fad36819eb4a0fccc9921c840a63f",
    "run_final_admission.py": "e7d052ef4637fd54332e835aa6e8e0eace1192407a6691f1e74c743add8ae7cf",
}
MIXTURES = {
    "a": (161803, ["suspended_deck", "rib_vault", "cathedral_megaframe", "interlaced_viaduct", "megatruss_station"]),
    "b": (271828, ["ring_pier", "tripod_frame", "seeded_typology_megablock", "metabolist_spine", "rosework_gatehouse"]),
    "c": (314159, ["cascade_terrace", "scalloped_vault", "buttress_wall", "interlock_brutalism", "suspended_arcology"]),
}
HASH = re.compile(r"[0-9a-f]{64}\Z")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def outside(path: Path, root: Path, label: str) -> None:
    require(not path.resolve().is_relative_to(root.resolve()), label + " must stay outside " + str(root))


def load_file(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, "Cannot load helper " + str(path))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def load_harness(directory: Path):
    # These exact helpers are the independently reviewed R versions. Any new
    # orchestration must retain their bytes rather than silently editing them.
    for name, expected in HELPERS.items():
        require((directory / name).is_file() and not (directory / name).is_symlink() and sha(directory / name) == expected,
                "Reviewed R helper changed: " + name)
    admission = load_file("retained_runtime_admission", directory / "retained_runtime_admission.py")
    package = load_file("package_retained_gentek80", directory / "package_retained_gentek80.py")
    boundary = load_file("run_final_admission", directory / "run_final_admission.py")
    return admission, package, boundary


def validate_phase(value: dict, phase: str, driver: Path, runtime_sha: str, graphical: bool) -> dict:
    require(value.get("schema") == "gentek80-mixed-workbench-phase-v1" and value.get("phase") == phase,
            "Wrong mixed phase schema or phase")
    require(value.get("complete") is True and value.get("completed") is True and
            value.get("failures") == 0 and type(value.get("checks")) is int and value["checks"] > 0 and
            value.get("mixtures") == 3 and value.get("catalogue_choices") == 93,
            "Incomplete or failed mixed phase")
    require(value.get("source_commit") == FINAL and value.get("native_build_commit") == BUILT and
            value.get("runtime_sha256") == runtime_sha and value.get("driver_sha256") == sha(driver) and
            Path(value.get("driver_path", "")).resolve() == driver.resolve(),
            "Phase source, native runtime or external driver identity differs")
    require(type(value.get("process_id")) is int and value["process_id"] > 0,
            "Missing actual Godot process identity")
    require(value.get("graphical") is graphical and (value.get("display") != "headless") is graphical,
            "Requested graphical mode not actually observed")
    require(value.get("godot") == "4.7-stable (official)" and value.get("os") == ("Windows" if os.name == "nt" else "Linux"),
            "Wrong Godot or target operating system in phase")
    rows = [row for row in value.get("cases", []) if row.get("case") == "mixed-" + phase]
    require(len(rows) == 3 and {row.get("mixture_id") for row in rows} == set(MIXTURES),
            "Expected exactly the three distinct mixed project identities")
    latency = [row for row in value["cases"] if row.get("case") == "ui-preview-latency"]
    require(len(latency) == (6 if phase == "author" else 3), "Missing actual preview/replay measurements")
    for sample in latency:
        require(sample.get("display") == value["display"] and sample.get("extent") == [512, 512] and
                type(sample.get("request_to_ready_us")) is int and sample["request_to_ready_us"] >= 0 and
                (sample.get("request_to_first_drawn_frame_us") is not None) is graphical,
                "Preview timing is incomplete or not graphical")
    by_id = {}
    for row in rows:
        identity = row["mixture_id"]
        seed, modules = MIXTURES[identity]
        require(row.get("modules") == modules and row.get("seed") == seed and row.get("extent") == [512, 512] and
                row.get("origin") == [0, 0] and row.get("zone_scale") == 64 and row.get("display") == value["display"],
                "Mixture input identity differs: " + identity)
        for key in ("source_sha256", "recipe_sha256", "edits_sha256", "expected_edited_material_sha256", "installed_material_sha256"):
            require(isinstance(row.get(key), str) and HASH.fullmatch(row[key]) is not None, "Missing material/recipe/edit digest: " + key)
        require(row.get("native_receipt_hashes") and
                row.get("construction_receipt", {}).get("generated_source_sha256") == row["source_sha256"],
                "Actual native constructor did not attest generated source")
        edits = row.get("edits", [])
        require(len(edits) == 2 and all(isinstance(stamp, list) and len(stamp) == 4 for stamp in edits), "Expected exactly two saved ordinary strokes")
        require(edits[0][:2] == [101, 99] and edits[0][3] == 58 and edits[1][:2] == [111, 99] and edits[1][3] == 0 and
                edits[0][2] == edits[1][2] and type(edits[0][2]) in (int, float) and 2 <= edits[0][2] <= 24,
                "Saved edit material, order, coordinate or radius differs")
        if phase == "author":
            project = row.get("selected_project", {})
            require(project.get("seed") == seed and project.get("extent") == [512, 512] and project.get("origin") == [0, 0] and
                    project.get("zone_scale") == 64 and all(project.get(flag) is True for flag in
                    ("automatic_tunnels", "automatic_doors", "automatic_windows")), "Author project changed defaults or bounds")
            selections = row.get("selection_events", [])
            styles = project.get("styles", [])
            require(len(styles) == 5 and len(selections) == 5, "Missing ordinary five-card selection evidence")
            for slot, (style, event) in enumerate(zip(styles, selections)):
                require(style.get("enabled") is True and style.get("share") == 20 and
                        style.get("preset", {}).get("module") == modules[slot] and style["preset"] == event.get("preset") and
                        event.get("slot") == slot and event.get("module") == modules[slot] and event.get("signal") == "OptionButton.item_selected" and
                        type(event.get("catalogue_index")) is int and 13 <= event["catalogue_index"] < 93,
                        "Actual OptionButton selection or preset parameters/materials changed")
            expected = {"material_sha256": row["source_sha256"], "recipe_sha256": row["recipe_sha256"]}
            require(row.get("initial") == expected and row.get("replay") == expected, "Repeated Apply changed source materials or recipe")
            require(row["installed_material_sha256"] == row["source_sha256"], "Installed World materials differ from generated source")
            require(row.get("tick_after") == row.get("tick_before", -2) + 1, "Ordinary single material tick did not complete")
        else:
            require(row.get("restored_material_sha256") == row["expected_edited_material_sha256"],
                    "Full restored native material raster differs from source plus saved edits")
        by_id[identity] = row
    return by_id


def compare_phases(author: dict, reopen: dict) -> None:
    for identity in MIXTURES:
        for key in ("source_sha256", "recipe_sha256", "edits", "edits_sha256", "expected_edited_material_sha256", "saved_start"):
            require(author[identity].get(key) == reopen[identity].get(key), "Independent reload differs: " + identity + "/" + key)


def png_evidence(output: Path, phases: dict, graphical: bool) -> dict:
    framebuffers = []
    for identity in MIXTURES:
        framebuffers.extend("author-mixed-" + identity + "-" + suffix + ".png" for suffix in
                            ("form", "preview", "zone-overlay", "replay", "installed-world", "edited-world"))
        framebuffers.extend("reopen-mixed-" + identity + "-" + suffix + ".png" for suffix in ("preview", "restored-world"))
    if not graphical:
        framebuffers = []
    materials = ["author-mixed-" + identity + "-native-materials.png" for identity in MIXTURES]
    declared = phases["author"].get("captures", []) + phases["reopen"].get("captures", [])
    require(sorted(declared) == sorted(framebuffers), "Incomplete or mislabelled original framebuffer capture manifest")
    expected = set(framebuffers + materials)
    actual = {path.name for path in output.glob("*.png")}
    require(actual == expected, "PNG inventory differs from required framebuffers and native material previews")
    hashes = {}
    for name in sorted(expected):
        path = output / name
        require(path.is_file() and not path.is_symlink() and path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"),
                "Invalid original PNG: " + name)
        hashes[name] = sha(path)
    return {"framebuffer_png_sha256": {name: hashes[name] for name in sorted(framebuffers)},
            "native_material_preview_png_sha256": {name: hashes[name] for name in sorted(materials)}}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("config", "candidate", "bundle", "harness", "output"):
        parser.add_argument("--" + flag, type=Path, required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    for flag in ("godot", "archive", "assembly", "assets-archive", "extraction"):
        parser.add_argument("--" + flag, type=Path)
    parser.add_argument("--timeout", type=int, default=1800, help="Per-process timeout in seconds")
    parser.add_argument("--sanity-headless", action="store_true", help="Non-admitting local sanity only; never counts as graphical acceptance")
    args = parser.parse_args()
    output = args.output.resolve()
    require(not output.exists() or not any(output.iterdir()), "Evidence output must be new or empty")
    output.mkdir(parents=True, exist_ok=True)
    candidate, bundle, harness = args.candidate.resolve(), args.bundle.resolve(), args.harness.resolve()
    driver = Path(__file__).resolve().with_name("mixed_gentek_workbench.gd")
    runner = Path(__file__).resolve()
    graphical = not args.sanity_headless
    before = manifest = directory = engine = project = None
    admission = package = boundary = None
    engine_hashes = {}
    result = {"schema": "gentek80-mixed-workbench-admission-v1", "status": "running", "passed": False,
              "admitted": False, "graphical_requested": graphical, "platform": args.platform,
              "application_source_commit": FINAL, "application_source_tree": TREE, "native_build_commit": BUILT,
              "orchestration_commit": os.environ.get("GITHUB_SHA"), "orchestration_run": os.environ.get("GITHUB_RUN_ID"),
              "orchestration_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"), "original_orchestration_commit": ORIGINAL_ORCHESTRATION,
              "original_assembly_run": ORIGINAL_ASSEMBLY_RUN, "driver_path": str(driver), "driver_sha256": sha(driver),
              "runner_sha256": sha(runner), "results": [], "errors": [],
              "scope": "Three supplemental ordinary Workbench mixtures. No claim of supported/walkable boundaries or SWARM behavior."}
    def verify():
        return admission.verify(candidate, bundle, args.platform, BUILT, FINAL, TREE,
                                config["original_run_id"], config["original_run_attempt"])
    try:
        for path, label in ((driver, "External driver"), (runner, "External runner"), (output, "Evidence output"), (harness, "Reviewed harness")):
            outside(path, candidate, label)
        require(driver.is_file() and not driver.is_symlink(), "Missing regular external driver")
        require(args.timeout > 0, "Timeout must be positive")
        require(sha(args.config) == CONFIG_SHA, "Immutable original admission inputs changed")
        config = read(args.config)
        require(config.get("published_source") == FINAL and config.get("published_tree") == TREE and config.get("built_source") == BUILT,
                "Admission inputs name a different source")
        admission, package, boundary = load_harness(harness)
        result.update(configuration_sha256=CONFIG_SHA, reviewed_helpers_sha256=HELPERS)
        before = verify()
        result.update(before=before, native_sha256=before["runtime"]["sha256"])
        if args.platform == "windows":
            require(all((args.archive, args.assembly, args.assets_archive, args.extraction)), "Windows requires the immutable final ZIP, assembly and original assets")
            require(sha(args.assembly) == ASSEMBLY_SHA and sha(args.archive) == ARCHIVE_SHA and args.archive.stat().st_size == ARCHIVE_BYTES,
                    "Original final assembly or Windows ZIP changed")
            assembly = read(args.assembly)
            require(assembly.get("schema") == "gentek80-final-package-assembly-v1" and assembly.get("status") == "packaged-not-executed" and
                    assembly.get("application_source_commit") == FINAL and assembly.get("application_source_tree") == TREE and
                    assembly.get("native_build_commit") == BUILT and assembly.get("native_sha256") == before["runtime"]["sha256"] and
                    assembly.get("orchestration_commit") == ORIGINAL_ORCHESTRATION and assembly.get("orchestration_run") == ORIGINAL_ASSEMBLY_RUN and
                    assembly.get("archive_sha256") == ARCHIVE_SHA and assembly.get("archive_bytes") == ARCHIVE_BYTES and
                    assembly.get("asset_package_sha256") == config["windows_asset_zip_sha256"],
                    "Assembly does not belong to the immutable original R/final execution")
            directory = args.extraction.resolve()
            outside(directory, candidate, "Test extraction")
            for path, label in ((driver, "External driver"), (runner, "External runner"), (output, "Evidence output"), (harness, "Reviewed harness")):
                outside(path, directory, label)
            package.extract_pristine(args.archive, directory, ARCHIVE_SHA)
            manifest = package.verify_package(candidate, directory, final_sha=FINAL, final_tree=TREE, built_sha=BUILT,
                                               native_sha=before["runtime"]["sha256"], assets_sha256=config["windows_asset_zip_sha256"],
                                               bundle=bundle, assets_archive=args.assets_archive)
            project, engine = directory / "godot", directory / package.CONSOLE
            engine_hashes = {str(engine): ENGINE_SHA["windows_console"], str(directory / package.GUI): ENGINE_SHA["windows_gui"]}
            result.update(archive_sha256=ARCHIVE_SHA, archive_bytes=ARCHIVE_BYTES, assembly_receipt_sha256=ASSEMBLY_SHA,
                          package_manifest_sha256=sha(directory / package.MANIFEST))
        else:
            require(args.godot is not None, "Linux requires the pinned Godot executable")
            project, engine = candidate / "godot", args.godot.resolve()
            engine_hashes = {str(engine): ENGINE_SHA["linux"]}
        require(all(sha(Path(path)) == expected for path, expected in engine_hashes.items()), "Actual Godot executable differs from its original pin")
        version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
        require(version == package.VERSION, "Godot version pin mismatch")
        result.update(project=str(project), engine_files_sha256=engine_hashes, godot_version=version)
        # Reuse the accepted candidate process monitor; its ROOT/cwd remains the
        # exact candidate. The supplemental driver is always an absolute path.
        qualify = load_file("mixed_candidate_qualify", candidate / "tools/architecture/qualify.py")
        environment = os.environ.copy()
        for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"),
                            ("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
            path = output / "profile" / suffix
            path.mkdir(parents=True, exist_ok=True)
            environment[key] = str(path)
        environment.update(CYBERSAND_SOURCE_REVISION=FINAL, CYBERSAND_MIXED_BUILD_SOURCE=BUILT,
                           CYBERSAND_ARCHITECTURE_OUTPUT=str(output), CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS="1" if graphical else "0",
                           PYTHONDONTWRITEBYTECODE="1")
        # The real GITHUB_* values are inherited unchanged. They describe this
        # supplemental workflow, never F or the original assembly workflow R.
        base = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
        row = qualify.run("import", [*base, "--headless", "--editor", "--quit"], environment, output, args.timeout)
        result["results"].append(row)
        require(row["passed"], "Candidate import failed; original log retained")
        phases, validated = {}, {}
        for phase in ("author", "reopen"):
            environment["CYBERSAND_MIXED_WB_PHASE"] = phase
            display = (["--rendering-method", "gl_compatibility"] +
                       (["--rendering-driver", "opengl3_angle"] if args.platform == "windows" else ["--display-driver", "x11"])) if graphical else ["--headless"]
            row = qualify.run(phase, [*base, *display, "--script", str(driver)], environment, output, args.timeout,
                              rf"GENTEK80_MIXED_WORKBENCH phase={phase} mixtures=3 checks=[1-9][0-9]* failures=0 complete=true")
            result["results"].append(row)
            path = output / ("mixed-workbench-" + phase + ".json")
            if path.is_file():
                phases[phase] = read(path)
                result[phase] = phases[phase]
            require(row["passed"], "Mixed " + phase + " process failed; original log/report retained")
            require(path.is_file(), "Missing mixed phase report: " + phase)
            validated[phase] = validate_phase(phases[phase], phase, driver, before["runtime"]["sha256"], graphical)
        require(phases["author"]["process_id"] != phases["reopen"]["process_id"], "Author and reopen did not use distinct OS processes")
        compare_phases(validated["author"], validated["reopen"])
        result.update(independent_processes=True, exact_material_recipe_edit_replay=True)
        result["original_process_receipts_sha256"] = boundary.process_binding(result["results"], output, project, engine)
        result.update(png_evidence(output, phases, graphical))
        result["passed"] = True
    except Exception as error:
        result["errors"].append(str(error))
        (output / "runner-error.txt").write_text(traceback.format_exc(), encoding="utf-8")
    finally:
        # Post-custody runs even after a failed import or campaign. Failure is
        # preserved rather than being hidden by skipping the after boundary.
        if before is not None:
            try:
                after = verify()
                result["after"] = after
                require(after == before, "Source/build/runtime identity changed during execution")
                require(sha(driver) == result["driver_sha256"] and sha(runner) == result["runner_sha256"], "External driver/runner changed during execution")
                require(all(sha(harness / name) == digest for name, digest in HELPERS.items()), "Reviewed R helpers changed during execution")
                require(all(sha(Path(path)) == digest for path, digest in engine_hashes.items()), "Godot executable changed during execution")
                if manifest is not None:
                    result["extracted_copy_postcheck"] = boundary.protected_after(directory, manifest)
                    require(sha(directory / package.MANIFEST) == result["package_manifest_sha256"] and
                            sha(args.archive) == ARCHIVE_SHA and sha(args.assembly) == ASSEMBLY_SHA and
                            sha(args.assets_archive) == config["windows_asset_zip_sha256"], "Original package/manifest/assembly/assets changed")
                result["source_stable"] = True
            except Exception as error:
                result["errors"].append("Post-custody: " + str(error))
                result["source_stable"] = False
        result["passed"] = result["passed"] and not result["errors"] and result.get("source_stable") is True
        result["admitted"] = result["passed"] and graphical
        result["status"] = "passed" if result["admitted"] else "sanity-only" if result["passed"] else "failed"
        result["failures"] = len(result["errors"])
        write(output / "qualification.json", result)
        print(json.dumps({key: result.get(key) for key in ("status", "passed", "admitted", "platform", "source_stable", "errors")}))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
