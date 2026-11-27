"""Run retained reciprocal generation using a freshly built combined Workbench."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

import runtime_custody as custody
from shared import legacy, qualification_engine, ui_report_errors, verify_engine

sys.path.insert(0, str(custody.ROOT / "tools/ci"))
import check_swarm_runtime
import run_workbench_actor_qualification as extension


def qualify(engine: Path, project: Path, candidate: Path, output: Path) -> None:
    platform = "windows" if os.name == "nt" else "linux"
    engine = qualification_engine(engine.resolve(), platform)
    version = verify_engine(engine)
    check = check_swarm_runtime.check(custody.ROOT)
    custody.require(check["status"] == "passed", str(check["errors"]))
    manifest = extension.candidate(candidate, platform)
    generator = json.loads((project / "tools" / f"swarm004-runtime.{platform}.json").read_bytes())
    proposed = check["platforms"][platform]
    cli = project / "tools" / Path(generator["artifact"]).name
    native = project / Path(manifest["artifact"]).relative_to("godot")
    custody.require(generator["source"] == proposed["source"] and custody.sha(cli) == proposed["sha256"]
                    and custody.sha(native) == manifest["sha256"], "Combined native/reciprocal bytes differ")
    script_sha = custody.sha(project / legacy.UI_SCRIPT)
    custody.require(script_sha == custody.sha(custody.ROOT / "godot" / legacy.UI_SCRIPT), "Fixture source differs")
    output.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, CYBERSAND_SOURCE_REVISION=manifest["source_commit"])
    for key in ("CYBERSAND_SWARM004_CLI", "CYBERSAND_SWARM004_SOURCE", "CYBERSAND_SWARM004_SHA256"):
        env.pop(key, None)
    env = legacy.isolated_environment(env, output, "reciprocal")
    base = [str(engine), "--audio-driver", "Dummy", "--path", str(project)]
    patch = legacy.execute("native-adapter", [*base, "--headless", "--script", "res://tests/test_workbench_authoring_patch.gd"],
                           dict(env, WB_AUTHORING_PATCH_REPORT=str(output / "native-adapter.json")), output, 180)
    adapter = legacy.read_report(output / "native-adapter.json")
    custody.require(patch["passed"] and not legacy.assertion_errors(adapter) and adapter.get("passed") is True,
                    "Native authoring patch and admission did not pass")
    controller = legacy.execute("controller-mechanical", [*base, "--headless", "--script",
                                "res://tests/test_workbench_reciprocal_controller.gd"], env, output, 90)
    errors = legacy.marker_errors(output / "controller-mechanical.log", "SWARM004_CONTROLLER ", mechanical=True)
    custody.require(legacy.validate_result(controller, errors, output)["passed"],
                    "Shared Art and reciprocal authoring history did not pass")
    display = ["--rendering-method", "gl_compatibility", "--max-fps", "60"]
    display += ["--rendering-driver", "opengl3_angle"] if platform == "windows" else ["--display-driver", "x11"]
    reports = {}
    for mode in ("create", "reopen"):
        process = legacy.execute(mode, [*base, *display, "--script", "res://" + legacy.UI_SCRIPT],
                                 dict(env, SWARM004_UI_MODE=mode), output, 420)
        report = legacy.read_report(output / (mode + ".json"))
        errors = ui_report_errors(report, mode, "reciprocal", proposed["source"], proposed["sha256"], script_sha, platform)
        if report.get("process_id") != process["process_id"]:
            errors.append("Receipt does not belong to the launched engine process")
        result = legacy.validate_result(process, errors, output)
        custody.require(result["passed"], mode + " failed: " + str(errors))
        reports[mode] = report
    proof = legacy.example_evidence(output, reports)
    custody.require(proof["passed"], str(proof["validation_errors"]))
    custody.require(custody.sha(cli) == proposed["sha256"] and custody.sha(native) == manifest["sha256"],
                    "Installed runtime changed during qualification")
    custody.write_json(output / "combined-reciprocal.json", {
        "source": manifest["source_commit"], "tree": manifest["source_tree"], "platform": platform,
        "native_sha256": manifest["sha256"], "generator": proposed, "engine_sha256": custody.sha(engine),
        "godot_version": version, "checks": {k: v["checks"] for k, v in reports.items()},
        "adapter_checks": adapter["checks"], "controller_log_sha256": custody.sha(output / "controller-mechanical.log"),
        "persistence": proof, "passed": True,
    })


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ("godot", "project", "candidate", "output"):
        parser.add_argument("--" + field, type=Path, required=True)
    args = parser.parse_args()
    qualify(args.godot, args.project.resolve(), args.candidate.resolve(), args.output.resolve())
