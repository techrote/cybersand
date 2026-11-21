#!/usr/bin/env python3
"""Run all 80 ordinary Workbench selections and independent process reopening."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import sys
import subprocess
import qualify

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--package", type=Path)
    parser.add_argument("--smoke", type=int, default=0)
    parser.add_argument("--timeout", type=int, default=2700)
    args = parser.parse_args()
    engine, project, output = args.godot.resolve(), args.project.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
    if version != qualify.VERSION:
        raise ValueError("Godot pin mismatch: " + version)
    before = qualify.source_identity(project)
    if args.package:
        package = args.package.resolve()
        manifest = json.loads((package / "candidate-manifest.json").read_text(encoding="utf-8"))
        if manifest["source_commit"] != before["source_commit"] or manifest["native_sha256"] != before["runtime_sha256"]:
            raise ValueError("Packaged source/runtime identity differs")
        for relative, digest in manifest["files_sha256"].items():
            if qualify.sha(package / relative) != digest:
                raise ValueError("Package content changed: " + relative)
    env = os.environ.copy()
    for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"), ("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
        path = output / "profile" / suffix
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    env.update({"CYBERSAND_SOURCE_REVISION": before["source_commit"], "CYBERSAND_ARCHITECTURE_OUTPUT": str(output), "CYBERSAND_ARCHITECTURE_REQUIRE_GRAPHICS": "1" if args.graphical else "0", "CYBERSAND_GENTEK80_WB_LIMIT": str(args.smoke)})
    base = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
    results = [qualify.run("import", [*base, "--headless", "--editor", "--quit"], env, output, args.timeout)]
    phases = {}
    expected = args.smoke or 80
    if results[0]["passed"]:
        for phase in ("author", "reopen"):
            env["CYBERSAND_GENTEK80_WB_PHASE"] = phase
            display = ["--headless"]
            if args.graphical:
                display = ["--rendering-method", "gl_compatibility"] + (["--rendering-driver", "opengl3_angle"] if os.name == "nt" else ["--display-driver", "x11"])
            result = qualify.run(phase, [*base, *display, "--script", "res://tools/qualify_gentek80_workbench.gd"], env, output, args.timeout,
                                 rf"GENTEK80_WORKBENCH phase={phase} styles={expected} checks=[1-9][0-9]* failures=0 complete=true")
            path = output / ("gentek80-workbench-" + phase + ".json")
            if path.is_file():
                phases[phase] = json.loads(path.read_text(encoding="utf-8"))
                value = phases[phase]
                result["passed"] = result["passed"] and value.get("completed") is True and value.get("styles") == expected and value.get("failures") == 0
            else:
                result["passed"] = False
            results.append(result)
            if not result["passed"]:
                break
    after = qualify.source_identity(project)
    stable = before == after
    results.append({"case": "source-stability", "passed": stable})
    fresh = len(phases) == 2 and phases["author"]["process_id"] != phases["reopen"]["process_id"]
    comparable = (len(phases) == 2 and
                  {x["preset_id"]: (x["source_sha256"], x["recipe_sha256"]) for x in phases["author"]["cases"] if x["case"] == "gentek80-author"} ==
                  {x["preset_id"]: (x["source_sha256"], x["recipe_sha256"]) for x in phases["reopen"]["cases"] if x["case"] == "gentek80-reopen"})
    passed = all(row["passed"] for row in results) and fresh and comparable
    report = {"schema": "gentek80-workbench-qualification-v1", "source_commit": before["source_commit"], "source_tree": before["source_tree"], "runtime_sha256": before["runtime_sha256"], "graphical_requested": args.graphical,
              "platform": "windows" if os.name == "nt" else "linux", "smoke": args.smoke, "passed": passed, "failures": sum(not r["passed"] for r in results) + int(not fresh) + int(not comparable), "results": results,
              "independent_processes": fresh, "material_and_recipe_replay": comparable, **phases}
    (output / "source-runtime-identity.json").write_text(json.dumps(before, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (output / "qualification.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"passed": passed, "styles": expected, "fresh_process": fresh, "source": before["source_commit"]}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
