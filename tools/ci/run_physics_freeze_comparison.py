#!/usr/bin/env python3
"""Same-host ABBA comparison of c1ad and the repaired ordinary Workbench.

Both sources use coherent presentation, the original 2048² Needle geometry,
the same completed-step input tape, and the ordinary native sample wait/wake.
Raw traces remain authoritative. Elapsed upload scopes include waits and OS
descheduling; neither those scopes nor achieved rates prove GPU acceptance.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import io
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

from analyze_pose_trace import analyze_physics_progress, distribution, event_time, read_trace
from run_render_cadence_matrix import run_case

ROOT = Path(__file__).resolve().parents[2]
CONTROL = "c1ad4910a07422b37d63df270bac337863ae7b2f"


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def source_project(source, destination, runtime_project):
    """Extract immutable Git source; source-identical native binaries are reused."""
    destination.mkdir(parents=True, exist_ok=False)
    with tarfile.open(fileobj=io.BytesIO(git("archive", source, "godot"))) as archive:
        for member in archive:
            if not member.isfile() or member.name.startswith("godot/.godot/"):
                continue
            parts = Path(member.name).parts
            need(".." not in parts and not Path(member.name).is_absolute(), "Unsafe source path")
            target = destination / member.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.extractfile(member).read())
    project = destination / "godot"
    platform = "windows" if os.name == "nt" else "linux"
    manifests = ["addons/cybersand_native/" + ("runtime-provenance.json" if os.name == "nt" else "runtime-provenance.linux.json"),
                 "addons/godot-rapier2d/runtime-provenance." + platform + ".json"]
    identities = []
    for relative in manifests:
        provenance = json.loads((project / relative).read_text())
        need(bool(provenance.get("source_inputs")), "Missing runtime source-input ledger: " + relative)
        for name, expected in provenance["source_inputs"].items():
            body = git("show", source + ":" + name).replace(b"\r\n", b"\n")
            need(hashlib.sha256(body).hexdigest() == expected, "Control runtime source drift: " + name)
        name = Path(provenance["artifact"]).relative_to("godot")
        binary = runtime_project / name
        need(sha(binary) == provenance["sha256"], "Control/candidate runtime mismatch: " + str(name))
        shutil.copyfile(binary, project / name)
        identities.append({"artifact": name.as_posix(), "sha256": provenance["sha256"],
                           "source_inputs": len(provenance["source_inputs"])})
    return project, identities


def verify_candidate_project(source, project):
    extensions = {".gd", ".gdshader", ".gdshaderinc", ".gdextension", ".tscn", ".tres", ".json", ".godot", ".cfg"}
    tracked = git("ls-tree", "-r", "--name-only", source, "--", "godot").decode().splitlines()
    expected = {Path(name).relative_to("godot").as_posix(): name for name in tracked
                if Path(name).suffix in extensions and not name.startswith("godot/.godot/")}
    actual = {p.relative_to(project).as_posix() for p in project.rglob("*")
              if p.is_file() and p.suffix in extensions and not p.relative_to(project).as_posix().startswith(".godot/")}
    # The Windows packager copies canonical generator recipes into this runtime
    # discovery directory. Validate their contents against the canonical source.
    extras = actual - expected.keys()
    for relative in sorted(extras):
        need(relative.startswith("authoring/worldgen/") and relative.endswith(".json"), "Untracked executable/config source: " + relative)
        canonical = "examples/worldgen/" + Path(relative).name
        need((project / relative).read_bytes().replace(b"\r\n", b"\n") == git("show", source + ":" + canonical).replace(b"\r\n", b"\n"),
             "Packaged generator recipe drift: " + relative)
    need(expected.keys() <= actual, "Candidate project is missing tracked source files")
    ledger = {}
    for relative, canonical in expected.items():
        body = (project / relative).read_bytes().replace(b"\r\n", b"\n")
        need(body == git("show", source + ":" + canonical).replace(b"\r\n", b"\n"), "Executed candidate source drift: " + relative)
        ledger[relative] = hashlib.sha256(body).hexdigest()
    return ledger


def verify_runtime_project(source, project):
    platform = "windows" if os.name == "nt" else "linux"
    manifests = ["addons/cybersand_native/" + ("runtime-provenance.json" if os.name == "nt" else "runtime-provenance.linux.json"),
                 "addons/godot-rapier2d/runtime-provenance." + platform + ".json"]
    identities = []
    for relative in manifests:
        provenance = json.loads((project / relative).read_text())
        need(bool(provenance.get("source_inputs")), "Missing runtime source-input ledger: " + relative)
        for name, expected in provenance["source_inputs"].items():
            body = git("show", source + ":" + name).replace(b"\r\n", b"\n")
            need(hashlib.sha256(body).hexdigest() == expected, "Candidate runtime source drift: " + name)
        name = Path(provenance["artifact"]).relative_to("godot")
        need(sha(project / name) == provenance["sha256"], "Candidate runtime payload drift: " + str(name))
        identities.append({"artifact": name.as_posix(), "sha256": provenance["sha256"],
                           "source_inputs": len(provenance["source_inputs"])})
    return identities


def physical_states(events):
    def finite_number(value):
        return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)

    states = {}
    for event in events:
        if event.get("event") != "rapier_step":
            continue
        required = {"step", "native_tick_used", "epoch", "session", "world_generation", "native_response",
                    "hard_surface_shapes", "pending_hard_chunks", "input_tape_index", "fixed_delta", "simulation_time_sec", "bodies"}
        need(required <= event.keys(), "Incomplete physical completion association record")
        need(bool(event["bodies"]), "Physical completion has no actor state records")
        need(all(finite_number(event[key]) for key in ("fixed_delta", "simulation_time_sec")),
             "Physical completion has a nonfinite or missing physical clock")
        step = int(event["step"])
        # Timing and Main callback indices are observations, not physical state.
        associations = {key: event.get(key) for key in
                        ("native_tick_used", "native_sample_serial", "sample_serial", "epoch", "session", "world_generation",
                         "native_response", "hard_surface_shapes", "pending_hard_chunks", "input_tape_index", "fixed_delta", "simulation_time_sec")
                        if key in event}
        for body in event.get("bodies", []):
            need({"slot", "instance_id", "xy", "angle", "velocity"} <= body.keys(), "Incomplete physical actor state record")
            need(finite_number(body["angle"]) and all(isinstance(body[key], list) and len(body[key]) == 2
                 and all(finite_number(value) for value in body[key]) for key in ("xy", "velocity")),
                 "Physical actor has a nonfinite, missing or malformed authoritative pose/velocity")
            key = (step, int(body["slot"]))
            need(key not in states, "Duplicate physical completion/body " + str(key))
            states[key] = {"body": body, "associations": associations}
    return states


def exact_common_states(left, right, required_steps=144):
    left_steps = sorted({key[0] for key in left})
    right_steps = sorted({key[0] for key in right})
    need(left_steps and right_steps, "Missing completed physical state records")
    need(left_steps[0] == right_steps[0], "Compared captures start at different physical steps")
    need(left_steps[0] == 1, "Compared captures omit initial physical completions")
    for label, steps in (("control", left_steps), ("candidate", right_steps)):
        need(steps == list(range(steps[0], steps[-1]+1)), label + " has missing intermediate physical completions")
    first, last = left_steps[0], min(left_steps[-1], right_steps[-1])
    need(last - first + 1 >= required_steps, "Compared captures omit required physical completions")
    for step in range(first, last+1):
        need({key[1] for key in left if key[0] == step} == {key[1] for key in right if key[0] == step},
             "Missing or changed actor slots at matched physical step " + str(step))
    common = sorted(left.keys() & right.keys())
    differences = [{"step": key[0], "slot": key[1], "control": left[key], "candidate": right[key]}
                   for key in common if left[key] != right[key]]
    return {"common_step_bodies": len(common), "control_step_bodies": len(left),
            "candidate_step_bodies": len(right), "exact": bool(common) and not differences,
            "differences": differences, "step_range": [common[0][0], common[-1][0]] if common else None}


def reduction(path, maximum_step=None):
    header, frames, footer = read_trace(path)
    events = footer["_events"]
    steps = sorted((e for e in events if e.get("event") == "rapier_step"), key=event_time)
    indices = [int(e["step"]) for e in steps]
    need(indices and indices == list(range(indices[0], indices[-1]+1)), "Missing or duplicate physical completions")
    native_events = sorted((e for e in events if e.get("event") == "native_tick"), key=event_time)
    native_indices = [int(e["tick_index"]) for e in native_events]
    need(native_indices and native_indices == list(range(native_indices[0], native_indices[-1]+1)),
         "Missing or duplicate native tick completions")
    if maximum_step is not None:
        steps = [e for e in steps if int(e["step"]) <= maximum_step]
        need(len(steps) > 1, "Insufficient matched completion prefix")
        begin, end = event_time(steps[0]), event_time(steps[-1])
        events = [e for e in events if event_time(e) is not None and begin <= event_time(e) <= end]
        frames = [f for f in frames if begin <= f["time_usec"] <= end]
    progress = analyze_physics_progress(frames, events)
    # Read old controls with the current independent reducer, including ≥50ms.
    holds = Counter(e.get("reason", "unknown") for e in events if e.get("event") == "rapier_hold")
    uploads = [e for e in events if e.get("event") == "texture_upload"]
    publication = [e["material_publication"] for e in uploads if isinstance(e.get("material_publication"), dict)]
    components = {name: distribution([p[name] / 1000 for p in publication if isinstance(p.get(name), (int, float))])
                  for name in ("image_patch_usec", "content_cache_usec", "tile_assembly_usec", "atlas_assembly_usec",
                               "backend_submit_usec", "staging_upload_usec", "gpu_blit_submit_usec")}
    rates = {}
    for name, rows in (("rapier", steps), ("native", [e for e in events if e.get("event") == "native_tick"]),
                       ("main", frames)):
        times = sorted(event_time(row) for row in rows if event_time(row) is not None)
        rates[name] = (len(times)-1)*1e6/(times[-1]-times[0]) if len(times) > 1 and times[-1] > times[0] else None
    upload_ms = [(e["completed_usec"]-e["start_usec"])/1000 for e in uploads
                 if isinstance(e.get("start_usec"), (int, float)) and isinstance(e.get("completed_usec"), (int, float))]
    natives = {int(e["tick_index"]): e for e in events if e.get("event") == "native_tick"}
    admission_ms = [(e["start_usec"]-event_time(natives[int(e["native_tick_used"])]))/1000 for e in steps
                    if "start_usec" in e and int(e.get("native_tick_used", -1)) in natives
                    and e["start_usec"] >= event_time(natives[int(e["native_tick_used"])])]
    callback_ms = [(event_time(e)-e["start_usec"])/1000 for e in events
                   if e.get("event") == "main_callback" and "start_usec" in e]
    publication_ids = [e.get("render_serial") for e in events if e.get("event") == "render_publication"]
    return {"trace_sha256": sha(path), "source": header.get("settings", {}).get("source_commit"),
            "maximum_matched_step": maximum_step, "rates_hz": rates, "physics": progress,
            "hold_reasons": dict(holds), "material_upload_elapsed_ms": distribution(upload_ms),
            "material_component_elapsed_ms": components,
            "native_completion_to_physics_admission_ms": distribution(admission_ms),
            "main_callback_elapsed_ms": distribution(callback_ms),
            "render_publications": len(publication_ids),
            "duplicate_render_publications": len(publication_ids)-len(set(publication_ids)),
            "backend_modes": dict(Counter(p.get("backend", p.get("mode", "unknown")) for p in publication)),
            "fallback_reasons": dict(Counter(p["fallback_reason"] for p in publication if p.get("fallback_reason"))),
            "submitted_bytes": distribution([p["submitted_bytes"] for p in publication if "submitted_bytes" in p]),
            "estimated_gpu_target_write_bytes": distribution([p["estimated_target_write_bytes"] for p in publication
                                                               if "estimated_target_write_bytes" in p]),
            "allocated_gpu_bytes": distribution([p["allocated_gpu_bytes"] for p in publication if "allocated_gpu_bytes" in p]),
            "observer_drops": {k: footer.get(k, 0) for k in ("dropped", "events_dropped", "worker_events_dropped")},
            "meaning": "Measured event completion rates and elapsed call scopes, not isolated CPU/GPU execution or physical display scanout. "
                       "Backend submission includes staging upload and blit/retirement submission; assembly aliases and child scopes must not be summed. "
                       "Submitted bytes count CPU texture uploads; GPU target-write bytes are a logical estimate, not measured bandwidth."}, physical_states(events)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--conditions", nargs="+", default=["interactive-follow", "interactive-free"])
    parser.add_argument("--rendering-driver", choices=["opengl3", "opengl3_angle"], required=True)
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--single-pair", action="store_true", help="Focused development AB only; final qualification uses ABBA")
    args = parser.parse_args()
    args.evidence = args.evidence.resolve()
    args.project = args.project.resolve()
    args.godot = args.godot.resolve()
    need(not args.evidence.exists(), "Use a fresh evidence directory; failed runs are retained")
    need(git("rev-parse", "HEAD").decode().strip() == args.source_sha, "Wrong candidate source")
    need(not git("diff", "--name-only", args.source_sha, "--", "godot/scripts", "godot/tests", "godot/shaders"),
         "Uncommitted application changes prevent a source-matched comparison")
    args.evidence.mkdir(parents=True)
    # Preserve the original observer event families in the source ABBA run.
    # Runtime publication counters/timers remain charged to the new implementation.
    os.environ["CYBERSAND_DIAG_COMMON_OBSERVER"] = "1"
    os.environ["CYBERSAND_MATERIAL_PUBLICATION"] = "auto"
    os.environ["CYBERSAND_DIAG_PHYSICS_PUBLICATION"] = ""
    for selector in ("CYBERSAND_DIAG_NATIVE_RENDEZVOUS", "CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS",
                     "CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS", "CYBERSAND_DIAG_MATERIAL_COPY_MODE"):
        os.environ[selector] = ""
    report = {"schema": "physics-freeze-remediation-comparison-v1", "control": CONTROL,
              "candidate": args.source_sha, "candidate_tree": git("rev-parse", "HEAD^{tree}").decode().strip(),
              "order": "AB" if args.single_pair else "ABBA", "cases": [], "comparisons": [], "failures": [],
              "complete": False, "physical_acceptance": "pending_owner_Windows11_NVIDIA",
              "qualified_performance_claim": False, "runner_sha256": sha(Path(__file__))}
    report["observer"] = {"common_event_families": True,
                          "new_main_callback_and_physics_publication_events": "suppressed",
                          "candidate_runtime_component_timers": "included in measured candidate cost; not CPU-exclusive"}
    output = args.evidence / "summary.json"
    write(output, report)
    try:
        report["candidate_source_inputs"] = verify_candidate_project(args.source_sha, args.project)
        report["candidate_runtimes"] = verify_runtime_project(args.source_sha, args.project)
        control_project, report["control_runtimes"] = source_project(CONTROL, args.evidence / "control-source", args.project)
        with (args.evidence / "control-import.log").open("w") as log:
            result = subprocess.run([str(args.godot), "--headless", "--path", str(control_project), "--editor", "--quit"],
                                    stdout=log, stderr=subprocess.STDOUT, timeout=240)
        need(result.returncode == 0 and "SCRIPT ERROR:" not in (args.evidence / "control-import.log").read_text(errors="replace"),
             "Control import failed")
        conditions_path = args.project / "tests/fixtures/engine_lab/coherence-conditions.json"
        control_conditions = control_project / "tests/fixtures/engine_lab/coherence-conditions.json"
        need(sha(conditions_path) == sha(control_conditions), "Control and candidate conditions differ")
        conditions = json.loads(conditions_path.read_text())["conditions"]
        need(set(args.conditions) <= {c["name"] for c in conditions}, "Unknown condition")
        for condition in [c for c in conditions if c["name"] in args.conditions]:
            need(condition["wait"] and condition["wake"] and condition["display_profile"] == "interactive-default",
                 "Comparison must retain ordinary coupled interactive defaults")
            arms = []
            for number, arm in enumerate(["control", "candidate"] if args.single_pair else ["control", "candidate", "candidate", "control"]):
                directory = args.evidence / (condition["name"] + "-" + str(number) + "-" + arm)
                run_args = argparse.Namespace(**vars(args))
                run_args.evidence = directory
                run_args.project = control_project if arm == "control" else args.project
                run_args.source_sha = CONTROL if arm == "control" else args.source_sha
                run_args.coherence = True
                case, _ = run_case(run_args, condition, "coherent")
                trace = directory / "cases" / (condition["name"] + "-coherent") / "receipt-poses.jsonl"
                reduced, states = reduction(trace)
                row = {"arm": arm, "order": number, "condition": condition["name"], "case": case,
                       "reduction": reduced, "trace": str(trace)}
                report["cases"].append(row)
                arms.append((row, states))
                write(output, report)
                if arm == "candidate":
                    need(set(reduced["backend_modes"]) == {"blit"} and not reduced["fallback_reasons"],
                         "Candidate capture did not exercise blit throughout; automatic full fallback remains valid application behavior, "
                         "but cannot qualify this incremental-publication comparison")
            for index in range(0, len(arms), 2):
                first, second = arms[index:index+2]
                left, right = (first, second) if first[0]["arm"] == "control" else (second, first)
                equality = exact_common_states(left[1], right[1])
                maximum = equality["step_range"][1] if equality["step_range"] else None
                before, _ = reduction(Path(left[0]["trace"]), maximum)
                after, _ = reduction(Path(right[0]["trace"]), maximum)
                report["comparisons"].append({"condition": condition["name"], "pair": index // 2,
                                             "physical_equivalence": equality,
                                             "control_matched_prefix": before, "candidate_matched_prefix": after})
                need(equality["exact"], "Physical-state or native-association mismatch in " + condition["name"])
                write(output, report)
        report["complete"] = True
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        report["failures"].append(str(error))
    write(output, report)
    print("PHYSICS_FREEZE_COMPARISON", json.dumps({k: report[k] for k in ("complete", "failures", "candidate", "order")}), flush=True)
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    sys.exit(main())
