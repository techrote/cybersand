#!/usr/bin/env python3
"""Run focused existing regression fixtures against the installed Windows payload."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

from package_windows import CONSOLE, digest, need, verify, write_json


CASES = (
    "test_feature_worker_preference",
    "test_material_tile_publication", "test_pubpres_transition_history_render",
    "test_material_vapour_pipeline_render", "test_render_patch_handoff_regression",
    "test_render_world_generation", "test_workbench_physics_publication",
    "test_workbench_native_render_overlap", "test_workbench_native_rendezvous_integration",
    "test_workbench_presentation_coherence", "test_workbench_presentation_history",
    "test_workbench_physics_pacing", "test_workbench_owner_deadline", "test_workbench_failure_containment",
    "test_workbench_failure_recovery", "test_workbench_generator_installed", "test_workbench_engine_lab",
    "test_workbench_combined_authoring", "test_workbench_deferred_paint",
    "test_workbench_canvas", "test_paint_editor_workbench",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--installed", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    installed, output = args.installed.resolve(), args.output.resolve()
    manifest = verify(installed, args.source_sha)
    need(os.name == "nt" and not output.exists(), "Use Windows and a fresh evidence directory")
    output.mkdir(parents=True)
    project = output / "project"
    shutil.copytree(installed / "godot", project)
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith("CYBERSAND_")}
    env.update(CYBERSAND_SOURCE_REVISION=args.source_sha, CYBERSAND_SOURCE_SHA=args.source_sha,
               CYBERSAND_MATERIAL_PUBLICATION="blit", CYBERSAND_DIAG_PHYSICS_PUBLICATION="early",
               CYBERSAND_DIAG_PRESENTATION="coherent", CYBERSAND_DIAG_MATERIAL_TIMING="measured",
               CYBERSAND_DIAG_RENDER_CADENCE="repaired", CYBERSAND_DIAG_NATIVE_RENDEZVOUS="0")
    plans = [("import", ["--headless", "--editor", "--import"], {})]
    graphical = ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle"]
    plans.extend((name, [*graphical, "--render-thread",
                  "separate" if name == "test_workbench_native_render_overlap" else "safe",
                  "--script", f"res://tests/{name}.gd"], {}) for name in CASES)
    plans.extend((name + "-reopen", [*graphical, "--render-thread", "safe", "--script", f"res://tests/{name}.gd"], flags)
                 for name, flags in (("test_workbench_canvas", {"CYBERSAND_WORKBENCH_REOPEN": "1"}),
                                     ("test_paint_editor_workbench", {"PAINT_REOPEN": "1"})))
    plans.extend((f"queued-separate-{slots}", [*graphical, "--render-thread", "separate", "--script",
                  "res://tests/run_material_threaded_publication.gd"],
                  {"CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS": str(slots),
                   "CYBERSAND_MATERIAL_QUEUE_THREAD": "separate"}) for slots in (1, 2, 3))
    rows = []
    for name, flags, settings in plans:
        folder = output / name
        folder.mkdir()
        artifacts = folder / "artifacts"
        artifacts.mkdir()
        local_env = dict(env, **settings, CYBERSAND_TEST_ARTIFACT_DIR=str(folder / "artifacts"),
                         CYBERSAND_PHYSICS_PACING_OUTPUT=str(folder / "artifacts"),
                         CYBERSAND_MATERIAL_QUEUE_OUTPUT=str(artifacts / "queue.json"),
                         CYBERSAND_MATERIAL_TILE_OUTPUT=str(artifacts / "tiles.json"),
                         CYBERSAND_NATIVE_RENDER_OVERLAP_OUTPUT=str(artifacts / "native-render-overlap.json"),
                         CYBERSAND_WORKBENCH_CAPTURE=str(artifacts / "canvas.png"),
                         PAINT_CAPTURE_DIR=str(artifacts), PAINT_STARTUP_OUTPUT=str(artifacts / "paint-startup.json"),
                         CYBERSAND_WORKBENCH_TEST_NAME="pubpres-qualification-canvas")
        for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            profile = output / "profile" / name.removesuffix("-reopen") / key
            profile.mkdir(parents=True, exist_ok=True)
            local_env[key] = str(profile)
        command = [str(installed / CONSOLE), "--path", str(project), "--audio-driver", "Dummy", *flags]
        row = {"case": name, "command": command, "timeout_seconds": 900, "timed_out": False,
               "selectors": {k: v for k, v in local_env.items() if k.startswith("CYBERSAND_")}}
        with (folder / "stdout.log").open("wb") as stdout, (folder / "stderr.log").open("wb") as stderr:
            with subprocess.Popen(command, env=local_env, cwd=installed, stdout=stdout, stderr=stderr) as process:
                try:
                    process.wait(timeout=row["timeout_seconds"])
                except subprocess.TimeoutExpired:
                    row["timed_out"] = True
                    subprocess.run([str(Path(os.environ["SystemRoot"]) / "System32/taskkill.exe"),
                                    "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=30, check=False)
                    process.wait(timeout=30)
                row["exit_code"] = process.returncode
        logs = "\n".join((folder / name).read_text(errors="replace") for name in ("stdout.log", "stderr.log"))
        row["diagnostic_errors"] = any(token in logs for token in ("ERROR:", "Parse Error:", "Failed to load", "SKIP ", " skipped"))
        row["passed"] = not row["timed_out"] and row["exit_code"] == 0 and not row["diagnostic_errors"]
        row["logs_sha256"] = {name: digest(folder / name) for name in ("stdout.log", "stderr.log")}
        write_json(folder / "process.json", row)
        rows.append(row)
        write_json(output / "summary.json", {"source_commit": args.source_sha, "source_tree": manifest["source_tree"],
                   "engine": manifest["engine"], "tests": rows, "complete": len(rows) == len(plans),
                   "passed": len(rows) == len(plans) and all(r["passed"] for r in rows), "physical_acceptance": "HOLD"})
        print(name, "PASS" if row["passed"] else "FAIL", flush=True)
        if name == "import" and not row["passed"]:
            break
    # Every immutable package input is checked again; generated imports stay in
    # the disposable copy. Original logs and pixel captures are always retained.
    verify(installed, args.source_sha)
    shutil.rmtree(project)
    shutil.rmtree(output / "profile")
    return 0 if len(rows) == len(plans) and all(row["passed"] for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
