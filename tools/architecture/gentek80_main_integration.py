#!/usr/bin/env python3
"""Qualify the finite Gentek/accepted-Workbench join in two actual Godot processes.

Reuses the pinned original landscape and retained-runtime custody checks; it does
not rebuild a catalogue, regenerate its gallery, or rewrite native provenance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools/ci"))
import qualify_workbench_landscapes as landscapes
import qualify_art_traffic_lifetime as traffic
import qualify

STYLES = ["ring-pier", "tripod-frame", "cascade-terrace", "scalloped-vault",
          "suspended-deck", "buttress-wall", "cathedral-megaframe"]


def helper_identity(allow_delta: bool) -> dict:
    identities = {}
    for relative in ("tools/architecture/gentek80_main_integration.py", "tools/architecture/qualify.py"):
        data = (ROOT / relative).read_bytes().replace(b"\r\n", b"\n")
        if not allow_delta:
            landscapes.require(data == landscapes.git("show", "HEAD:" + relative).replace(b"\r\n", b"\n"),
                               "Commit exact integration helpers before final qualification: " + relative)
        identities[relative] = hashlib.sha256(data).hexdigest()
    return identities


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--fixture-dir", type=Path, required=True)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--allow-source-delta", action="store_true", help="Local debugging only; preserve every source delta")
    args = parser.parse_args()
    output, project, engine = args.output.resolve(), args.project.resolve(), args.godot.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {"schema": "gentek80-main-integration-v1", "passed": False, "results": [], "phases": {}}
    try:
        version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
        landscapes.require(version == qualify.VERSION, "Godot pin mismatch: " + version)
        identity = landscapes.source_identity(args.allow_source_delta)
        runtime = landscapes.verify_runtime_identity()
        loaded = landscapes.project_identity(project, identity, runtime)
        helpers = helper_identity(args.allow_source_delta)
        report.update(source=identity, runtime=runtime, project_inputs_sha256=loaded,
                      execution_helpers_sha256=helpers, godot_version=version,
                      godot_sha256=qualify.sha(engine), platform=sys.platform,
                      graphical_requested=args.graphical)
        _, maps = landscapes.load_maps(landscapes.MANIFEST)
        item = next(value for value in maps if value["name"] == "graftloom-slipway")
        source = args.fixture_dir.resolve() / item["fixture_file"]
        landscapes.require(source.stat().st_size == item["source_bytes"] and qualify.sha(source) == item["sha256"], "Pinned Graftloom fixture differs")
        landscapes.require(landscapes.independent_grid(source)["grid_sha256"] == item["grid_sha256"], "Pinned Graftloom independent material grid differs")
        fixture_dir = output / "fixtures"
        fixture_dir.mkdir()
        source_copy = fixture_dir / item["fixture_file"]
        shutil.copyfile(source, source_copy)
        report["landscape"] = item
        env, archive_dir, archive_fixture = traffic.fixture(output / "profile", 4)
        for variable, suffix in (("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"), ("LOCALAPPDATA", "local")):
            path = output / "profile" / suffix
            path.mkdir()
            env[variable] = str(path)
        archive_before = traffic.inventory(archive_dir)
        env.update(CYBERSAND_SOURCE_REVISION=identity["source_commit"],
                   CYBERSAND_ARCHITECTURE_OUTPUT=str(output),
                   CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS="1" if args.graphical else "0",
                   GENTEK_MAIN_LANDSCAPE=str(source_copy), GENTEK_MAIN_LANDSCAPE_SHA256=item["sha256"],
                   GENTEK_MAIN_LANDSCAPE_GRID_SHA256=item["grid_sha256"])
        base = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
        result = qualify.run("import", [*base, "--headless", "--editor", "--quit"], env, output, args.timeout)
        report["results"].append(result)
        landscapes.require(result["passed"], "Godot import failed")
        for phase in ("author", "reopen"):
            env["GENTEK_MAIN_PHASE"] = phase
            display = ["--headless"]
            if args.graphical:
                display = ["--rendering-method", "gl_compatibility"] + (["--rendering-driver", "opengl3_angle"] if os.name == "nt" else ["--display-driver", "x11"])
            result = qualify.run(phase, [*base, *display, "--script", "res://tools/qualify_gentek80_main_integration.gd"], env, output, args.timeout,
                                 rf"GENTEK_MAIN_INTEGRATION phase={phase} styles=7 checks=[1-9][0-9]* failures=0 complete=true")
            report["results"].append(result)
            landscapes.require(result["passed"], "Combined Workbench phase failed: " + phase)
            value = json.loads((output / f"gentek-main-{phase}.json").read_text())
            landscapes.require(value["schema"] == "gentek80-main-integration-phase-v1" and value["completed"] is True
                               and value["failures"] == 0 and value["style_ids"] == STYLES and value["styles"] == 7
                               and value["catalogue_choices"] == 93 and value["source_commit"] == identity["source_commit"], "Incomplete or mismatched integration receipt")
            if args.graphical:
                landscapes.require(value["display"] != "headless", "Graphical phase ran headlessly")
            report["phases"][phase] = value
            landscapes.require(traffic.inventory(archive_dir) == archive_before, "Generator/startup changed archive bytes, files, size or mtime")
            landscapes.require(landscapes.source_identity(args.allow_source_delta) == identity
                               and landscapes.verify_runtime_identity() == runtime
                               and landscapes.project_identity(project, identity, runtime) == loaded
                               and helper_identity(args.allow_source_delta) == helpers,
                               "Source, runtime or loaded project changed during execution")
            landscapes.write_json(output / "qualification.json", report)
        author, reopen = report["phases"]["author"], report["phases"]["reopen"]
        landscapes.require(author["process_id"] != reopen["process_id"], "Reopening reused the author process")
        authored = {row["id"]: row["identity"] for row in author["cases"] if row["case"] == "gentek"}
        restored = {row["id"]: row["identity"] for row in reopen["cases"] if row["case"] == "gentek"}
        landscapes.require(set(authored) == set(STYLES) and authored == restored, "Fresh native generated-state replay differs")
        landscapes.require(qualify.sha(source_copy) == item["sha256"], "Original landscape fixture changed")
        report.update(passed=True, independent_processes=True, archive_unchanged=True,
                      archive_fixture=archive_fixture, archive_inventory=archive_before,
                      native_material_replay=authored,
                      screenshots={path.name: qualify.sha(path) for path in sorted(output.glob("*.png"))})
    except Exception as error:
        report["error"] = str(error)
        print("GENTEK_MAIN_QUALIFICATION_FAILED:", error, file=sys.stderr)
    finally:
        report["completed"] = True
        landscapes.write_json(output / "qualification.json", report)
    print(json.dumps({"passed": report["passed"], "phases": list(report["phases"]), "source": report.get("source", {}).get("source_commit")}))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
