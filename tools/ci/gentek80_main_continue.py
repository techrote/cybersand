#!/usr/bin/env python3
"""Continue an exact-source qualification without rerunning its completed cases.

The prior failed invocation and all original process receipts remain unchanged.
Native paint uses the repository's registered headless one/four-worker contract.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

PREFIX = ["architecture", "installed-author", "installed-reopen", "paint-author", "paint-reopen",
          "art-lazy", "art-integrity", "art-panel-safety", "art-native-batch", "workbench_edit_ordering"]
ORIGINAL_RUN = 44770730491
ORIGINAL_ORCHESTRATION = "561a0ac544027b8fa85b3e24ed7b903ab9732719"


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def verify_previous(prior: Path, identity: dict, runtime: dict, project: dict, engine_hash: str,
                    qualify, custody) -> dict:
    report = read(prior / "qualification.json")
    custody.require(report.get("schema") == "gentek80-main-existing-regressions-v1"
                    and report.get("completed") is True and report.get("source") == identity
                    and report.get("runtime") == runtime and report.get("project_inputs_sha256") == project
                    and report.get("platform") == sys.platform and report.get("godot_sha256") == engine_hash,
                    "Prior report does not qualify these exact source/runtime/engine/project inputs")
    rows = report.get("cases", [])
    names = [row.get("case") for row in rows]
    custody.require(names[:len(PREFIX)] == PREFIX and len(names) == len(set(names))
                    and set(names) <= set(PREFIX + ["paint-native", "material-baseline", "water-lab"]),
                    "Prior qualification does not contain the required completed prefix")
    reused = []
    for row in rows:
        name = row["case"]
        process = read(prior / (name + "-process.json"))
        custody.require(all(row.get(key) == value for key, value in process.items())
                        and row.get("passed") is True and row.get("returncode") == 0 and not row.get("timed_out")
                        and not row.get("assertion_failures")
                        and qualify.sha(prior / (name + ".log")) == row.get("log_sha256"),
                        "Prior successful process evidence changed: " + name)
        if name != "paint-native":
            reused.append(row)
    architecture = read(prior / "architecture/qualification.json")
    custody.require(architecture.get("passed") is True and architecture.get("failures") == 0
                    and architecture.get("source_commit") == identity["source_commit"]
                    and architecture.get("runtime_sha256") == runtime["cybersand_runtime"]["sha256"]
                    and architecture.get("graphical_requested") is True,
                    "Prior architectural suite is not exact-source graphical evidence")
    expected = ["import", "project-contract", "native", "ui", "author", "reopen",
                "multistyle-author", "multistyle-reopen", "source-stability"]
    custody.require([row.get("case") for row in architecture.get("cases", [])] == expected,
                    "Prior architecture suite is incomplete")
    for row in architecture["cases"]:
        custody.require(row.get("passed") is True, "Prior architectural case failed")
        if row["case"] == "source-stability":
            continue
        name = row["case"]
        custody.require(read(prior / "architecture" / (name + "-process.json")) == row
                        and qualify.sha(prior / "architecture" / (name + ".log")) == row["log_sha256"]
                        and row["returncode"] == 0 and not row["timed_out"],
                        "Original architectural process evidence changed: " + name)
    paint_process = read(prior / "paint-native-process.json")
    paint_log = (prior / "paint-native.log").read_text(encoding="utf-8", errors="replace")
    paint_matches = re.findall(r"(?m)^PAINT_EDITOR_NATIVE (\{[^\r\n]*\})$", paint_log)
    custody.require(len(paint_matches) == 1
                    and qualify.sha(prior / "paint-native.log") == paint_process.get("log_sha256")
                    and not paint_process.get("timed_out"), "Original graphical paint attempt is absent or changed")
    paint_terminal = json.loads(paint_matches[0])
    custody.require(paint_terminal.get("checks") == 109 and paint_terminal.get("workers") == 0,
                    "Original paint attempt is not the observed default-worker invocation")
    if paint_terminal.get("failures"):
        custody.require(paint_terminal["failures"] == ["Stop reports truthful partial prefix"]
                        and paint_process.get("passed") is False and paint_process.get("returncode") == 1,
                        "Original paint failure differs from the diagnosed invocation")
    else:
        custody.require(paint_process.get("passed") is True and paint_process.get("returncode") == 0,
                        "Original extra graphical paint result is incomplete")
    paint_attempt = {"process_sha256": qualify.sha(prior / "paint-native-process.json"),
                     "log_sha256": paint_process["log_sha256"], "command": paint_process["command"],
                     "returncode": paint_process["returncode"], "passed": paint_process["passed"],
                     "checks": paint_terminal["checks"], "workers": paint_terminal["workers"],
                     "failures": paint_terminal["failures"]}
    return {"run_id": ORIGINAL_RUN, "orchestration_commit": ORIGINAL_ORCHESTRATION,
            "original_report_sha256": qualify.sha(prior / "qualification.json"),
            "original_passed": report["passed"], "original_error": report.get("error"),
            "cases": reused, "architecture_report_sha256": qualify.sha(prior / "architecture/qualification.json"),
            "original_graphical_default_worker_paint_attempt": paint_attempt}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("candidate", "godot", "output", "prior"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    root, engine, output, prior = [getattr(args, key).resolve() for key in ("candidate", "godot", "output", "prior")]
    output.mkdir(parents=True, exist_ok=False)
    sys.path[:0] = [str(root / "tools/architecture"), str(root / "tools"), str(root / "tools/ci")]
    import qualify
    import qualify_workbench_landscapes as custody
    from stress_physical_godot import case_environment
    report = {"schema": "gentek80-main-regression-continuation-v1", "passed": False, "cases": []}
    try:
        identity, runtime = custody.source_identity(), custody.verify_runtime_identity()
        project = custody.project_identity(root / "godot", identity, runtime)
        version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
        custody.require(version == qualify.VERSION, "Godot pin mismatch")
        engine_hash = qualify.sha(engine)
        report.update(source=identity, runtime=runtime, project_inputs_sha256=project,
                      godot_version=version, godot_sha256=engine_hash, platform=sys.platform,
                      continuation_helper_sha256=qualify.sha(Path(__file__)),
                      execution_helpers_sha256={name: qualify.sha(root / name) for name in
                          ("tools/architecture/qualify.py", "tools/ci/run_workbench_qualification.py")})
        report["reused"] = verify_previous(prior, identity, runtime, project, engine_hash, qualify, custody)
        reused_names = {row["case"] for row in report["reused"]["cases"]}
        base = [str(engine), "--audio-driver", "Dummy", "--path", str(root / "godot")]
        result = qualify.run("import", [*base, "--headless", "--editor", "--quit"],
                             case_environment(output / "profiles/import"), output, 300)
        report["cases"].append(result)
        custody.require(result["passed"], "Godot import failed")
        cases = [("paint-native-1", "test_paint_editor_native", ["--headless"], {"PAINT_TEST_WORKERS":"1"}, "PAINT_EDITOR_NATIVE", 109),
                 ("paint-native-4", "test_paint_editor_native", ["--headless"], {"PAINT_TEST_WORKERS":"4"}, "PAINT_EDITOR_NATIVE", 109)]
        if "material-baseline" not in reused_names:
            cases.append(("material-baseline", "test_workbench_material_baseline", ["--headless"], {}, "WORKBENCH_MATERIAL_BASELINE", None))
        if "water-lab" not in reused_names:
            cases.append(("water-lab", "test_workbench_wave_spill", ["--headless"], {}, "WORKBENCH_WAVE_SPILL", None))
        for label, script, display, extra, marker, count in cases:
            environment = case_environment(output / "profiles" / label)
            environment.update(CYBERSAND_SOURCE_REVISION=identity["source_commit"], **extra)
            pattern = (r"(?m)^" + marker + (r" checks=[1-9][0-9]* failures=0$" if label == "material-baseline" else r" (\{[^\r\n]*\})$"))
            row = qualify.run(label, [*base, *display, "--script", "res://tests/" + script + ".gd"],
                              environment, output, 600, pattern)
            report["cases"].append(row)
            text = (output / (label + ".log")).read_text(encoding="utf-8", errors="replace")
            if label != "material-baseline":
                matches = re.findall(pattern, text)
                custody.require(len(matches) == 1, "Missing/duplicate anchored JSON result: " + label)
                value = json.loads(matches[0])
                row["assertions"] = value.get("checks")
                row["assertion_failures"] = value.get("failures")
                row["passed"] = row["passed"] and bool(value.get("checks")) and not value.get("failures")
                if "completed" in value:
                    row["passed"] = row["passed"] and value["completed"] is True
                if count is not None:
                    custody.require(value.get("checks") == count and value.get("workers") == int(extra["PAINT_TEST_WORKERS"]),
                                    "Registered native-paint contract did not execute: " + label)
                    row["workers"] = value["workers"]
                    row["native_witness_sha256"] = value["witness_sha256"]
            custody.write_json(output / "qualification.json", report)
            custody.require(row["passed"], "Existing regression failed: " + label)
        custody.require(custody.source_identity() == identity and custody.verify_runtime_identity() == runtime
                        and custody.project_identity(root / "godot", identity, runtime) == project,
                        "Source/runtime/project changed during continuation")
        report.update(passed=True, source_stable=True)
    except Exception as error:
        report["error"] = str(error)
        print("CONTINUATION_QUALIFICATION_FAILED:", error, file=sys.stderr)
    report["completed"] = True
    custody.write_json(output / "qualification.json", report)
    print(json.dumps({"passed":report["passed"], "new_cases":len(report["cases"]),
                      "reused_cases":len(report.get("reused",{}).get("cases",[])),
                      "source":report.get("source",{}).get("source_commit")}))
    return int(not report["passed"])


if __name__ == "__main__":
    raise SystemExit(main())
