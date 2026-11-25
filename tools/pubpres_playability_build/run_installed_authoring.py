#!/usr/bin/env python3
"""Exercise real graphical author/Save/reopen on a pristine Windows package copy."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_playability_windows"))
import package_windows
from run_regressions import run, validate_completion, combined_evidence, continuation_policy


def parse_arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--same-frame", choices=("off", "on"), default="off",
                        help="Explicit continuation configuration for both fresh processes (default: off)")
    return parser.parse_args(argv)


def main():
    args = parse_arguments()
    if os.name != "nt":
        raise ValueError("Installed graphical qualification requires actual Windows")
    payload, output = args.package.resolve(), args.output.resolve()
    if output.exists():
        raise ValueError("Use a fresh directory; retain every prior result")
    manifest = package_windows.verify(payload, args.candidate)
    policy = continuation_policy(args.same_frame)
    output.mkdir(parents=True)
    source = manifest["sources"]["C"]
    staged = output / "source"
    shutil.copytree(payload / source["root"], staged)
    project = staged / "godot"
    engine = payload / manifest["engine"]["gui"]["path"]
    environment = {k: v for k, v in os.environ.items() if not k.startswith(("CYBERSAND_", "WB_COMBINED_"))}
    for name in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        path = output / "profile" / name
        path.mkdir(parents=True)
        environment[name] = str(path)
    environment.update(CYBERSAND_SOURCE_REVISION=args.candidate, CYBERSAND_SOURCE_SHA=args.candidate,
        WB_COMBINED_SIDE="512", WB_COMBINED_WORKERS="1", WB_COMBINED_REQUIRE_GRAPHICS="1",
        WB_COMBINED_SAME_FRAME=args.same_frame)
    environment.update(policy["selectors"])
    if manifest["schema"] == package_windows.COMPLETION_SCHEMA:
        environment["CYBERSAND_DIAG_MATERIAL_RETIREMENT_SOURCE"] = "target"
    prefix = [str(engine), "--path", str(project), "--audio-driver", "Dummy"]
    outcomes, failure = [], None
    try:
        item = run(prefix + ["--headless", "--editor", "--import"], environment, output / "import", 300)
        item["validation_errors"] = validate_completion("import", (output / "import/stdout.log").read_text(errors="replace"), item["returncode"])
        outcomes.append(item)
        if item["validation_errors"] or item["timed_out"]:
            raise ValueError("Installed source import failed")
        for reopen in (False, True):
            label = "reopen" if reopen else "author"
            folder = output / label
            environment.update(WB_COMBINED_REOPEN="1" if reopen else "0", WB_COMBINED_SCREENSHOTS=str(folder / "screenshots"))
            item = run(prefix + ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle",
                "--render-thread", "safe", "--script", "res://tests/test_workbench_combined_authoring.gd"], environment, folder, 600)
            text = (folder / "stdout.log").read_text(encoding="utf-8", errors="replace")
            item["validation_errors"] = validate_completion("test_workbench_combined_authoring", text, item["returncode"], reopen=reopen)
            outcomes.append(item)
            if item["validation_errors"] or item["timed_out"]:
                raise ValueError("Installed graphical " + label + " failed")
            item["authoring_evidence"] = combined_evidence(text, project, source["native"]["sha256"],
                folder / "screenshots", graphical=True, reopen=reopen, same_frame=args.same_frame)
            if reopen and item["authoring_evidence"]["prepared_sha256"] != outcomes[1]["authoring_evidence"]["prepared_sha256"]:
                raise ValueError("Installed reopened complete native material digest differs")
            (folder / "process.json").write_text(json.dumps(item, indent=2) + "\n")
    except BaseException as error:
        failure = type(error).__name__ + ": " + str(error)
    finally:
        try:
            package_windows.verify(payload, args.candidate)
        except Exception as error:
            failure = (failure + "; " if failure else "") + "Pristine payload changed: " + str(error)
        summary = {"schema": "pubpres-installed-authoring-v2", "candidate": args.candidate,
            "manifest_sha256": package_windows.digest(payload / package_windows.MANIFEST),
            "engine_sha256": package_windows.digest(engine), "native_sha256": source["native"]["sha256"],
            "complete": failure is None and len(outcomes) == 3, "failure": failure, "outcomes": outcomes,
            "same_frame_continuation_policy": policy,
            "material_retirement_source": environment.get("CYBERSAND_DIAG_MATERIAL_RETIREMENT_SOURCE"),
            "scope": "512-square graphical native author/Save/fresh-process reopen; continuation configuration/status only; software renderer; owner NVIDIA HOLD"}
        (output / "SUMMARY.json").write_text(json.dumps(summary, indent=2) + "\n")
        # Preserve actual logs, framebuffer images, saved profile and receipts.
        shutil.rmtree(staged)
    return 0 if summary["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
