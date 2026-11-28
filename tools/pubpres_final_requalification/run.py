#!/usr/bin/env python3
"""Execute the fixed c2 font and renderer cohort with an explicit new qualifier."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

from contract import (ENGINE_IDENTITY, ROOT, augment_driver, execution_registration,
                      need, qualified_functions, registration, validate_request)


def invoke(function, arguments: list[str]) -> int:
    previous = sys.argv
    try:
        sys.argv = [str(Path(__file__))] + arguments
        return function()
    finally:
        sys.argv = previous


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--original-engine-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    need(os.name == "nt", "This is new Windows execution, not an offline/platform-emulated replay")
    validate_request()
    reg = registration()
    need(not args.output.exists(), "Retain every original execution; output must be fresh")
    font_main, renderer_main, _ = qualified_functions()
    import run_font_renderer_comparison as renderer
    import payload
    driver = augment_driver(renderer.verify_driver())
    args.output.mkdir(parents=True)
    report = {"schema": "pubpres-retained-font-new-execution-outcome-v1", "complete": False,
              "execution_registration": execution_registration(driver), "driver": driver,
              "workflow_run": os.environ.get("GITHUB_RUN_ID"), "workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
              "outcomes": [], "physical_acceptance": "HOLD"}
    def save():
        (args.output / "SUMMARY.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    save()
    runtime = args.inputs.resolve() / "native/C"
    need({p.name: payload.file_record(p) for p in runtime.iterdir() if p.is_file()} == reg["native_files"],
         "Actual retained native files differ from the registered archive")
    engine = args.inputs.resolve() / "engine"
    identity_args = ["--engine-build-source", ENGINE_IDENTITY["build_source"],
                     "--engine-build-run", str(ENGINE_IDENTITY["build_run"]),
                     "--engine-build-attempt", str(ENGINE_IDENTITY["build_attempt"]),
                     "--engine-proof-sha256", ENGINE_IDENTITY["proof_sha256"]]
    common = ["--source", str(args.source.resolve()), "--runtime", str(runtime)] + identity_args
    font_output = args.output.resolve() / "font"
    result = invoke(font_main, common + ["--original-engine-root", str(args.original_engine_root.resolve()),
                    "--repaired-engine-root", str(engine), "--output", str(font_output)])
    report["outcomes"].append({"stage": "font-and-startup", "exit_code": result,
                               "summary_sha256": payload.digest(font_output / "SUMMARY.json")})
    save()
    if result != 0:
        return 1
    comparison_output = args.output.resolve() / "comparison"
    result = invoke(renderer_main, common + ["--engine-payload", str(engine),
                    "--font-qualification", str(font_output / "SUMMARY.json"), "--output", str(comparison_output),
                    "--case", "wave_512_follow", "--case", "wave_gameplay_2048_follow", "--presentation-observer"])
    report["outcomes"].append({"stage": "gpu-history-and-owner-comparison", "exit_code": result,
                               "summary_sha256": payload.digest(comparison_output / "SUMMARY.json")})
    need(augment_driver(renderer.verify_driver()) == driver, "Qualifier changed during actual Windows execution")
    report["complete"] = result == 0
    save()
    print(json.dumps({"complete": report["complete"], "outcomes": report["outcomes"], "physical_acceptance": "HOLD"}))
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
