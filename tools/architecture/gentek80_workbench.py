#!/usr/bin/env python3
"""Run all 80 ordinary Workbench selections and independent process reopening."""
from __future__ import annotations
import argparse
import json
import os
import re
from pathlib import Path
import sys
import subprocess
import qualify
from gentek80_compositions import inventory_packaged_godot

ROOT = Path(__file__).resolve().parents[2]
# The Windows console launcher may leave a separate GUI engine process.
# Keep this gate independent for adversarial tests without platform spoofing.
REQUIRE_ENGINE_EXIT_CHECK = os.name == "nt"


REFERENCE_GALLERY = ROOT / "docs/images/gentek80-integration/gallery-manifest.json"
SHA256 = re.compile(r"[0-9a-f]{64}\Z")


def expected_catalogue() -> dict[str, str]:
    """Source-committed 80-style identity reference, independent of phase receipts."""
    manifest = json.loads(REFERENCE_GALLERY.read_text(encoding="utf-8"))
    defaults = manifest.get("defaults")
    if not isinstance(defaults, list) or len(defaults) != 80:
        raise ValueError("Committed Gentek identity reference must have 80 defaults")
    result: dict[str, str] = {}
    modules = set()
    for row in defaults:
        if not isinstance(row, dict):
            raise ValueError("Malformed committed Gentek identity reference")
        preset, module = row.get("preset_id"), row.get("module")
        if (not isinstance(preset, str) or not preset
                or not isinstance(module, str) or not module
                or preset in result or module in modules):
            raise ValueError("Missing or duplicate committed Gentek identity")
        result[preset] = module
        modules.add(module)
    return result


def validate_phase_receipt(receipt: dict, phase: str, source: str,
                           count: int, reference: dict[str, str]) -> dict[str, tuple[str, str]]:
    """Fail closed on missing, duplicate, foreign or invented catalogue cases."""
    if not isinstance(receipt, dict) or receipt.get("schema") != "gentek80-workbench-phase-v1":
        raise ValueError("Wrong Workbench phase receipt schema")
    if (receipt.get("phase") != phase or receipt.get("source_commit") != source
            or receipt.get("completed") is not True or receipt.get("complete") is not True
            or receipt.get("failures") != 0 or receipt.get("styles") != count
            or receipt.get("catalogue_choices") != 93):
        raise ValueError("Workbench phase, source, completion, style count or catalogue-size mismatch")
    pid = receipt.get("process_id")
    if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
        raise ValueError("Missing authentic phase process identifier")
    catalogue = receipt.get("catalogue_ids")
    if (not isinstance(catalogue, list) or len(catalogue) != 80
            or len(set(catalogue)) != 80 or set(catalogue) != set(reference)):
        raise ValueError("Phase catalogue differs from the 80 source-committed preset IDs")
    required = set(catalogue[:count])
    cases = receipt.get("cases")
    if not isinstance(cases, list) or any(not isinstance(case, dict) for case in cases):
        raise ValueError("Workbench phase cases must be objects")
    selected = [case for case in cases if case.get("case") == "gentek80-" + phase]
    ids = [case.get("preset_id") for case in selected]
    if (len(selected) != count or len(set(ids)) != count
            or set(ids) != required):
        raise ValueError("Workbench phase must contain each expected preset exactly once")
    matched = {}
    for case in selected:
        preset = case["preset_id"]
        material, recipe = case.get("source_sha256"), case.get("recipe_sha256")
        if (case.get("module") != reference[preset]
                or not isinstance(material, str) or SHA256.fullmatch(material) is None
                or not isinstance(recipe, str) or SHA256.fullmatch(recipe) is None):
            raise ValueError("Workbench case module or native material/recipe digest invalid: " + preset)
        matched[preset] = (material, recipe)
    return matched


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
    phase_contracts = {}
    phase_contract_errors = []
    process_boundaries = []
    expected = args.smoke or 80
    reference = expected_catalogue()
    if expected < 1 or expected > 80:
        raise ValueError("Workbench smoke count must be 1..80")
    if results[0]["passed"]:
        for phase in ("author", "reopen"):
            # Inspect BOTH exact engine paths. Never terminate unrelated Godot
            # processes or assume the console wrapper's exit implies GUI exit.
            before_phase = inventory_packaged_godot(engine)
            process_boundaries.append({"phase": phase, "when": "before", **before_phase})
            if REQUIRE_ENGINE_EXIT_CHECK and (not before_phase.get("supported") or before_phase.get("pids")):
                results.append({"case": phase + "-preexisting-engine-process", "passed": False,
                                "inventory": before_phase})
                break
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
                try:
                    phase_contracts[phase] = validate_phase_receipt(
                        value, phase, before["source_commit"], expected, reference)
                except (ValueError, KeyError, TypeError) as exc:
                    phase_contract_errors.append(phase + ": " + str(exc))
                    result["passed"] = False
            else:
                phase_contract_errors.append(phase + ": missing original phase receipt")
                result["passed"] = False
            results.append(result)
            after_phase = inventory_packaged_godot(engine)
            process_boundaries.append({"phase": phase, "when": "after", **after_phase})
            if REQUIRE_ENGINE_EXIT_CHECK and (not after_phase.get("supported") or after_phase.get("pids")):
                results.append({"case": phase + "-surviving-engine-process", "passed": False,
                                "inventory": after_phase})
                break
            if not result["passed"]:
                break
    after = qualify.source_identity(project)
    stable = before == after
    results.append({"case": "source-stability", "passed": stable})
    fresh = (len(phases) == 2
             and phases["author"].get("process_id") != phases["reopen"].get("process_id")
             and all(isinstance(phases[p].get("process_id"), int) for p in ("author", "reopen")))
    comparable = (len(phase_contracts) == 2
                  and phase_contracts["author"] == phase_contracts["reopen"])
    passed = all(row["passed"] for row in results) and fresh and comparable and not phase_contract_errors
    report = {"schema": "gentek80-workbench-qualification-v1", "source_commit": before["source_commit"], "source_tree": before["source_tree"], "runtime_sha256": before["runtime_sha256"], "graphical_requested": args.graphical,
              "platform": "windows" if os.name == "nt" else "linux", "smoke": args.smoke, "passed": passed, "failures": sum(not r["passed"] for r in results) + int(not fresh) + int(not comparable), "results": results,
              "independent_processes": fresh, "material_and_recipe_replay": comparable, "phase_contract_errors": phase_contract_errors,
              "source_committed_catalogue_count": len(reference),
              "matching_engine_process_boundaries": process_boundaries, **phases}
    (output / "source-runtime-identity.json").write_text(json.dumps(before, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (output / "qualification.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"passed": passed, "styles": expected, "fresh_process": fresh, "source": before["source_commit"]}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
