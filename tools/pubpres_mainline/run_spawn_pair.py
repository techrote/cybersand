#!/usr/bin/env python3
"""Run the registered source-exact P/C/C/P graphical spawn comparison."""
from __future__ import annotations
import argparse
import json
import platform
from pathlib import Path
import statistics
import sys
import time

import common
import run_spawn

ROOT = Path(__file__).resolve().parents[2]
REGISTRATION = Path(__file__).with_name("spawn-registration.json")
TIMINGS = (
    "request_latency_usec", "owner_admission_observed_usec",
    "first_observed_step_upper_bound_usec", "first_coherent_draw_observed_usec",
    "input_admission_observed_usec", "input_physical_application_observed_usec",
    "input_upward_pose_response_observed_usec",
    "observed_draw_callback_gaps.p95_usec", "observed_draw_callback_gaps.maximum_usec",
)
RATES = ("post_admission.physical_steps_per_second", "post_admission.native_ticks_per_second",
         "post_admission.simulated_seconds_per_wall_second")


def value_at(row, name):
    for key in name.split("."):
        if not isinstance(row, dict):
            return None
        row = row.get(key)
    return row


def distribution(values):
    observed = [value for value in values if value is not None]
    return {"values": values, "count": len(observed), "minimum": min(observed) if observed else None,
            "median": statistics.median(observed) if observed else None,
            "maximum": max(observed) if observed else None}


def compare(reference, candidate):
    p, c = distribution(reference), distribution(candidate)
    complete = p["count"] == c["count"] == 2
    return {"reference": p, "candidate": c, "both_repetitions_observed": complete,
            "candidate_minus_reference": c["median"]-p["median"] if complete else None,
            "candidate_to_reference_ratio": c["median"]/p["median"] if complete and p["median"] > 0 else None}


def startup_match(ready):
    wave = ready["wave_flow"]
    return {key: ready[key] for key in (
        "scene", "extent", "authored_setup_sha256", "authored_actor_count", "engine_sha256",
        "rapier_sha256", "render_thread_inline", "render_driver", "display_server", "adapter", "platform")
    } | {"water": {key: wave[key] for key in (
        "parameters", "workers_requested", "water_cells", "water_quantity", "construction_options")}}


def qualify(arms, registration, sources, driver=None):
    """Fail closed on missing/reordered arms, source drift or changed fixtures."""
    common.require(len(arms) == len(registration["order"]), "Incomplete registered spawn comparison")
    driver_source = driver if driver is not None else sources["C"]
    population = {}
    fixture_matches = {}
    native_by_role = {}
    common_driver = None
    common_fixtures = None
    for index, (arm, planned) in enumerate(zip(arms, registration["order"])):
        common.require(arm["index"] == index and arm["plan"] == planned and arm["pass"],
                       "Failed or reordered spawn arm; original evidence remains descriptive")
        role, identity = planned["role"], arm["identity"]
        common.require(identity["source"] == sources[role]["source_commit"]
                       and identity["source_tree"] == sources[role]["source_tree"] and identity["graphical"]
                       and identity["selected"] == common.SELECTORS
                       and identity["native_sha256"] == sources[role]["native_runtime_sha256"]
                       and identity["driver"]["source_commit"] == driver_source["source_commit"]
                       and identity["driver"]["source_tree"] == driver_source["source_tree"],
                       "Spawn source, graphical mode or selected policy differs")
        native_by_role.setdefault(role, identity["native_sha256"])
        common.require(native_by_role[role] == identity["native_sha256"], "Native runtime changed within a source role")
        if common_driver is None:
            common_driver, common_fixtures = identity["driver"], identity["fixtures"]
        common.require(identity["driver"] == common_driver and identity["fixtures"] == common_fixtures,
                       "Executing spawn driver or mounted observer differs")
        modes = planned["recording_order"].split("-") if planned["recording"] == "both" else [planned["recording"]]
        expected = [(scene, mode) for scene in registration["scenes"] for mode in modes]
        common.require([(row["scene"], row["recording"]) for row in arm["results"]] == expected,
                       "Missing, duplicate or reordered scene/recording arm")
        for row in arm["results"]:
            scene, mode = row["scene"], row["recording"]
            common.require(row["pass"] and row["spawn"]["recording"] == (mode == "on"),
                           "Spawn report does not satisfy its requested recording mode")
            reduced = row["reduced"]
            common.require([case["label"] for case in reduced["cases"]] == registration["cases"]
                           and all(case["accepted"] for case in reduced["cases"]),
                           "Required production spawn case was skipped or refused")
            raw_cases = row["spawn"]["cases"]
            request_shape = [{key: case[key] for key in ("label", "kind", "fire", "position", "actor_instance")}
                             for case in raw_cases]
            match = {"startup": startup_match(row["startup"]), "requests": request_shape}
            fixture_matches.setdefault(scene, match)
            common.require(fixture_matches[scene] == match, "Authored world, Water law, hardware or input route differs")
            common.require(row["startup"]["native_sha256"] == identity["native_sha256"]
                           and row["startup"]["source_commit"] == identity["source"],
                           "Observed native or application identity differs")
            common.require(not reduced["recorder_loss_intervals"], "Recorder loss invalidates timing comparison")
            if mode == "on":
                common.require(run_spawn.complete_recording(reduced, True), "Incomplete exact candidate timing recording")
            else:
                common.require(reduced["recorded_actual_steps"] == reduced["recorded_draw_callbacks"] == 0,
                               "Recording-off arm emitted gameplay clock records")
            population.setdefault((scene, role, mode), []).append(row)
    comparisons, exact_physical = [], []
    for scene in registration["scenes"]:
        for case_index, label in enumerate(registration["cases"]):
            p = [row["reduced"]["cases"][case_index] for row in population[(scene, "P", "off")]]
            c = [row["reduced"]["cases"][case_index] for row in population[(scene, "C", "off")]]
            on = [row["reduced"]["cases"][case_index] for row in population[(scene, "C", "on")]]
            common.require(len(p) == len(c) == len(on) == 2, "Incomplete repeated spawn population")
            comparisons.append({"scene": scene, "case": label,
                "candidate_vs_owner_recording_off": {name: compare([value_at(row, name) for row in p], [value_at(row, name) for row in c])
                                                     for name in (*TIMINGS, *RATES)},
                "candidate_recording_on_vs_off": {name: compare([value_at(row, name) for row in c], [value_at(row, name) for row in on])
                                                   for name in (*TIMINGS, *RATES)}})
            for repetition, row in enumerate(on):
                gaps = row["physical_gaps"]
                observed_maximum = max(gaps["maximum_usec"], row["physical_unfinished_suffix_usec"] or 0)
                exact_physical.append({"scene": scene, "case": label, "candidate_recording_on_repetition": repetition,
                    "physical_gaps": gaps, "first_completed_step_usec": row["first_completed_step_usec"],
                    "physical_gap_context_both_boundaries": row["physical_gap_context_both_boundaries"],
                    "unfinished_suffix_lower_bound_usec": row["physical_unfinished_suffix_usec"],
                    "maximum_including_unfinished_suffix_usec": observed_maximum,
                    "cadence_return": row["cadence_return"],
                    "p95_deficit_usec": max(0, gaps["p95_usec"]-registration["physical_targets_ms"]["p95"]*1000),
                    "maximum_deficit_usec": max(0, observed_maximum-registration["physical_targets_ms"]["maximum"]*1000)})
    return {"comparisons": comparisons, "candidate_exact_physical": exact_physical,
            "matched_initial_fixture_and_observers": fixture_matches,
            "scope": registration["scope"], "performance_acceptance": "DESCRIPTIVE_ONLY",
            "physical_owner_acceptance": "HOLD", "mainline_promotion": "HOLD"}


FROZEN_APPLICATION = {"source_commit": "65f71aaf4be3a67896bafac7f5220a0cb25a8fb7",
                      "source_tree": "f6b7b8d3d613b70cdcdf3643fb906934b3887173"}
FOLLOWUP_DRIVER_PATHS = frozenset({
    "tools/pubpres_mainline/common.py",
    "tools/pubpres_mainline/run_spawn_pair.py",
    "tools/pubpres_mainline/test_spawn_reader_binding.py",
    "tools/pubpres_mainline/test_evaluator_boundaries.py",
    ".github/workflows/pubpres-mainline-spawn-followup.yml",
})


def frozen_driver_projection(driver, candidate, changed_paths):
    """Separate the corrected measurement program from the immutable application."""
    common.require(candidate == FROZEN_APPLICATION, "Follow-up application is not the exact frozen candidate")
    common.require(set(changed_paths) == FOLLOWUP_DRIVER_PATHS and len(changed_paths) == len(FOLLOWUP_DRIVER_PATHS),
                   "Follow-up driver changed an application, fixture, native input or unregistered path")
    common.require(driver["source_commit"] != candidate["source_commit"]
                   and common.HEX40.fullmatch(driver["source_commit"]) and common.HEX40.fullmatch(driver["source_tree"]),
                   "Corrected measurement driver requires its own committed source identity")
    return {"schema": "pubpres-spawn-frozen-application-driver-v1",
            "application": dict(candidate),
            "measurement_driver": {key: driver[key] for key in ("source_commit", "source_tree")},
            "changed_driver_paths": sorted(changed_paths), "application_and_fixture_bytes_identical": True,
            "original_failed_run": 46144440297, "original_failed_attempt": 1,
            "original_budget_seconds": 1200, "followup_budget_seconds": 1800, "individual_process_timeout_seconds": 240,
            "scope": "Only reader-module import ownership and explicit driver/application identity are corrected. "
                     "The complete original P/C/C/P source, fixture, input, native and recording population is rerun."}


def collect(folder, index, planned, code, timed_out, error):
    arm = {"index": index, "plan": planned, "exit_code": code, "timed_out": timed_out,
           "error": error, "pass": False, "results": []}
    if not (folder / "SUMMARY.json").is_file():
        return arm
    summary = json.loads((folder / "SUMMARY.json").read_bytes())
    arm["identity"] = summary["identity"]
    arm["pass"] = code == 0 and not timed_out and error is None and summary["pass"]
    for result in summary["results"]:
        detail = dict(result)
        location = folder / (result["scene"] + "-" + result["recording"])
        for name, filename in (("startup", "startup.json"), ("spawn", "spawn.json"),
                               ("reduced", "REDUCED.json"), ("process", "process.json")):
            if (location / filename).is_file():
                detail[name] = json.loads((location / filename).read_bytes())
        arm["results"].append(detail)
    return arm


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner-source", type=Path, required=True)
    parser.add_argument("--candidate-source", type=Path, default=ROOT)
    parser.add_argument("--owner-runtime", type=Path, required=True)
    parser.add_argument("--candidate-runtime", type=Path, required=True)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--budget-seconds", type=int, default=1200)
    parser.add_argument("--frozen-candidate", action="store_true",
                        help="Use only final65f application with the explicitly bounded corrected measurement-driver projection")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    registration = json.loads(REGISTRATION.read_bytes())
    report = {"schema": "pubpres-mainline-spawn-pair-result-v1", "registration": registration,
              "registration_sha256": common.digest(REGISTRATION), "arms": [], "failures": [],
              "complete": False, "host": {"system": platform.system(), "release": platform.release(),
                                          "machine": platform.machine(), "node": platform.node()},
              "physical_owner_acceptance": "HOLD"}
    def save(): common.write_json(output / "SUMMARY.json", report)
    save()
    clock = time.monotonic()
    try:
        common.require(registration["schema"] == "pubpres-mainline-spawn-pair-v1"
                       and registration["owner_reference"] == common.OWNER_REFERENCE,
                       "Unknown spawn registration")
        common.require(common.platform_name() == "windows", "This registered delivery comparison requires actual Windows execution")
        driver = run_spawn.driver_identity()
        extra = {}
        for path in (Path(__file__), REGISTRATION):
            relative = path.relative_to(ROOT).as_posix()
            common.require(path.read_bytes().replace(b"\r\n", b"\n") == common.git(ROOT, "show", "HEAD:"+relative).replace(b"\r\n", b"\n"),
                           "Paired driver differs from committed source: "+relative)
            extra[relative] = common.digest(path)
        report.update(driver=driver, paired_driver_sha256=extra)
        roots = {"P": args.owner_source.resolve(), "C": args.candidate_source.resolve()}
        runtimes = {"P": args.owner_runtime.resolve(), "C": args.candidate_runtime.resolve()}
        sources = {role: common.source_identity(root) for role, root in roots.items()}
        common.require(sources["P"]["source_commit"] == registration["owner_reference"],
                       "Frozen owner source differs")
        if args.frozen_candidate:
            common.require(args.budget_seconds == 1800, "Follow-up aggregate allowance must be the registered1800 seconds")
            common.git(ROOT, "merge-base", "--is-ancestor", FROZEN_APPLICATION["source_commit"], driver["source_commit"])
            changed = common.git(ROOT, "diff", "--name-only", FROZEN_APPLICATION["source_commit"],
                                 driver["source_commit"]).decode().splitlines()
            report["measurement_projection"] = frozen_driver_projection(driver, sources["C"], changed)
        else:
            common.require(sources["C"] == {key: driver[key] for key in ("source_commit", "source_tree")},
                           "Candidate and executing driver source differ without explicit frozen projection")
        native = {role: common.runtime_record(roots[role], runtimes[role], "windows")[0] for role in roots}
        fields = ("compiler_version", "godot_cpp_commit", "godot_cpp_dependency_sha256", "godot_cpp_library_sha256")
        common.require({key: native["P"][key] for key in fields} == {key: native["C"][key] for key in fields},
                       "Reference/candidate native dependency or compiler cohort differs")
        for role in sources:
            sources[role]["native_runtime_sha256"] = native[role]["runtime_sha256"]
        report.update(sources=sources, native_build_receipts=native)
        save()
        for index, planned in enumerate(registration["order"]):
            remaining = int(args.budget_seconds-(time.monotonic()-clock))
            if remaining <= 0:
                report["failures"].append({"index": index, "error": "Registered comparison exceeded its bounded budget; remaining original arms were not run"})
                break
            role = planned["role"]
            folder = output / (str(index)+"-"+role)
            command = [sys.executable, str(Path(run_spawn.__file__)), "--source-root", str(roots[role]),
                       "--source", sources[role]["source_commit"], "--runtime", str(runtimes[role]),
                       "--engine", str(args.engine.resolve()), "--output", str(folder),
                       "--recording", planned["recording"], "--recording-order", planned["recording_order"], "--timeout", "240"]
            for scene in registration["scenes"]:
                command.extend(["--scene", scene])
            common.write_json(output / (str(index)+"-request.json"), {"index": index, "plan": planned, "command": command,
                                                                    "source": sources[role], "remaining_budget_seconds": remaining})
            code, timed_out, failure = None, False, None
            print(json.dumps({"starting_index": index, **planned, "remaining_budget_seconds": remaining}), flush=True)
            try:
                with (output / (str(index)+"-driver.log")).open("x", encoding="utf-8") as stream:
                    code, timed_out = run_spawn.bounded_process(command, cwd=ROOT, stdout=stream, timeout=remaining)
            except Exception as error:
                failure = str(error)
            try:
                arm = collect(folder, index, planned, code, timed_out, failure)
                report["arms"].append(arm)
                if not arm["pass"]:
                    report["failures"].append({"index": index, "error": failure or "Spawn arm failed; original process and gameplay receipts retained"})
            except Exception as error:
                report["failures"].append({"index": index, "error": str(error)})
            save()
        report["comparison"] = qualify(report["arms"], registration, sources, driver)
        report["complete"] = not report["failures"]
    except Exception as error:
        report["failures"].append({"error": str(error)})
    finally:
        report["elapsed_seconds"] = time.monotonic()-clock
        save()
        # Original execution logs, profiles and clock segments are retained.
        # The reproducible imported template is source-bound separately and may
        # be excluded from the uploaded artifact to avoid four source copies.
        files = {path.relative_to(output).as_posix(): {"sha256": common.digest(path), "bytes": path.stat().st_size}
                 for path in output.rglob("*") if path.is_file() and "template" not in path.relative_to(output).parts}
        common.write_json(output / "EVIDENCE-MANIFEST.json", {"files": files,
            "excluded": "Reproducible imported template directories; source-custody.json binds every authored input and explicit overlay"})
    print(json.dumps({"complete": report["complete"], "failures": report["failures"], "physical_owner_acceptance": "HOLD"}), flush=True)
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
