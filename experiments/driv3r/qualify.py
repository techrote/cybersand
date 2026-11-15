"""Explicit, frozen Stage A campaign: real resident d1 and real native painting.

No training, retries of poor model answers, model-selected coordinates, default
changes or schedules. Failed attempts and original receipts remain evidence.
"""
from __future__ import annotations

import argparse
import base64
import html
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import threading
import time
import traceback

from .backend import ResidentDecisionBackend
from .contracts import digest
from .controller import (D1Policy, EpisodeController, GeometricBaseline, decision_record,
                         validate_episode, write_json)
from .inference_smoke import run_inference_smoke
from .native import NativeSession
from .provenance import ROOT, runtime_custody, source_identity
from .providers import DirectProvider, FuzzyProvider
from .replay import replay_episode
from .tests.test_native import run_native_regressions

FROZEN = {
    "schema": "driv3r-stage-a-cohort-v1", "stage": "A", "training": False,
    "direct": {"fixture": "wall-v1", "start": [12, 24], "target": [12, 30], "offset": 4,
               "orderings": ["forward", "reverse"], "max_decisions": 8},
    "fuzzy": {"fixture": "fuzzy-v1", "nodes": ["platform", "extension", "support"],
              "orderings": ["forward", "reverse"], "max_decisions": 4},
    "common": {"max_changed_cells": 1024, "max_wall_seconds": 420, "request_seconds": 60},
    "baseline": "deterministic geometric, same native fixture and direct budgets",
    "replay": "every original episode, actual native material equality; no new model inference",
    "safety": ["native refusal suite", "explicit STOP", "invalid candidate ID", "real model timeout",
               "real outstanding-request cancellation", "startup deadline", "retired model refusal", "cleanup"],
    "evaluation": "Infrastructure gates separate from objective accuracy, graph completion and artistic usefulness",
}


def new_backend(runtime: dict, output: Path, **kwargs) -> ResidentDecisionBackend:
    return ResidentDecisionBackend(runtime["binary"], runtime["model"], output,
        model_identity=runtime["model_identity"], backend_identity=runtime["backend_identity"], **kwargs)


def percentile(values: list[float], p: float):
    if not values:
        return None
    values = sorted(values)
    position = (len(values)-1)*p
    low = int(position)
    high = min(low+1, len(values)-1)
    return values[low]+(values[high]-values[low])*(position-low)


class InjectedControl:
    """Deliberate synthetic decision controls against a real native World."""
    name = "synthetic-decision-safety-control"

    def __init__(self, choice):
        self.choice = choice

    def decide(self, observed, candidates, **_):
        return decision_record(observed, candidates, choice=self.choice,
            probabilities={c["id"]: float(c["id"] == self.choice) for c in candidates},
            confidence=1.0, model_identity={"kind": "synthetic_safety_control"},
            backend_identity={"kind": "qualification_injection"}, raw={"synthetic": True})


class CancelOutstanding:
    name = D1Policy.name

    def __init__(self, backend):
        self.policy = D1Policy(backend)

    def decide(self, observed, candidates, *, timeout_seconds, cancel_event):
        timer = threading.Timer(0.1, cancel_event.set)
        timer.start()
        try:
            return self.policy.decide(observed, candidates, timeout_seconds=timeout_seconds, cancel_event=cancel_event)
        finally:
            timer.cancel()
            timer.join(timeout=1)


def controller_safety(runtime, godot, source_sha, runtime_manifest, output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=False)
    rows = []
    with NativeSession(ROOT, godot, output/"native", source_sha, runtime_manifest=runtime_manifest) as native:
        for label, choice, expected in (("explicit-stop", "STOP", "stop"), ("invalid-id", "UNAUTHORIZED_ID", "invalid_decision")):
            record = EpisodeController(max_decisions=1, max_wall_seconds=60).run(native=native,
                provider=DirectProvider(), policy=InjectedControl(choice), episode_id=label, output=output/label)
            passed = (record["terminal_status"] == expected and record["native_actions"] == 0
                and record["initial_native"]["world_material_sha256"] == record["final_native"]["world_material_sha256"])
            rows.append({"label": label, "passed": passed, "kind": "synthetic decision / real native control",
                         "episode_sha256": digest(record), "terminal_status": record["terminal_status"]})
        for label, policy_type, request_seconds, expected in (
                ("real-timeout", D1Policy, 0.01, "model_failure"),
                ("real-cancellation", CancelOutstanding, 60, "cancelled")):
            backend = new_backend(runtime, output/(label+"-backend"))
            with backend:
                record = EpisodeController(max_decisions=1, max_wall_seconds=120, request_seconds=request_seconds).run(
                    native=native, provider=DirectProvider(), policy=policy_type(backend),
                    episode_id=label, output=output/label)
                retired = backend.decide("Cannot act after retirement", {"check": {"type": "choice",
                    "instructions": "Choose", "criteria": {"A": "First", "B": "Second"}}}, timeout_seconds=1)
            first = record["steps"][0]["decision"] if record["steps"] else None
            raw = first["raw"] if first else {}
            actual = raw.get("status") == ("timeout" if label == "real-timeout" else "cancelled")
            if label == "real-cancellation":
                actual = actual and "outstanding" in str(raw.get("error", ""))
            passed = (actual and record["terminal_status"] == expected and record["native_actions"] == 0
                and record["initial_native"]["world_material_sha256"] == record["final_native"]["world_material_sha256"]
                and retired["status"] == "model_failure" and backend.shutdown_record["process_reaped"])
            rows.append({"label": label, "passed": passed, "kind": "actual resident d1 / real native refusal",
                         "episode_sha256": digest(record), "terminal_status": record["terminal_status"],
                         "model_status": raw.get("status"), "model_error": raw.get("error"),
                         "retired_request": retired, "shutdown": backend.shutdown_record})
            write_json(output/(label+"-check.json"), rows[-1])
    expired = new_backend(runtime, output/"startup-timeout", startup_seconds=0.000001)
    refused = False
    try:
        expired.start()
    except Exception as exc:
        refused = True
        startup_error = f"{type(exc).__name__}: {exc}"
    finally:
        expired.close()
    rows.append({"label": "bounded-startup-refusal", "passed": refused and expired.shutdown_record["process_reaped"],
                 "error": startup_error if refused else None, "startup": expired.startup_record,
                 "shutdown": expired.shutdown_record})
    cleanup = json.loads((output/"native"/"cleanup.json").read_text())
    rows.append({"label": "native-safety-cleanup", "passed": cleanup["exit_code"] == 0, "cleanup": cleanup})
    result = {"passed": all(row["passed"] for row in rows), "checks": rows,
              "claim": "Synthetic decision controls are labelled separately from actual d1 timeout/cancellation"}
    write_json(output/"safety.json", result)
    return result


def episode_summary(record: dict) -> dict:
    decisions = [s["decision"] for s in record["steps"] if s["decision"] is not None]
    latencies = [d["latency_seconds"] for d in decisions]
    selected = [s["selected_action"] for s in record["steps"] if s["selected_action"] is not None]
    errors = [c["predicted"]["offset_error"] for c in selected if c["kind"] == "movement"]
    return {k: record[k] for k in ("episode_id", "mode", "policy", "terminal_status", "reason", "decisions",
            "native_actions", "native_attempts", "partial_native_actions", "actual_changed_cells", "elapsed_seconds",
            "final_cursor", "task_complete", "completion_kind")} | {
        "choices": [d["candidate_id"] for d in decisions], "decision_seconds": latencies,
        "decision_p50_seconds": statistics.median(latencies) if latencies else None,
        "decision_p95_seconds": percentile(latencies, .95),
        "mean_wall_offset_error": statistics.mean(errors) if errors else None,
        "maximum_wall_offset_error": max(errors) if errors else None,
        "retraces": sum(c["predicted"].get("retrace", False) for c in selected),
        "initial_world_material_sha256": record["initial_native"]["world_material_sha256"] if record["initial_native"] else None,
        "final_world_material_sha256": record["final_native"]["world_material_sha256"] if record["final_native"] else None,
        "episode_sha256": digest(record)}


def gallery(records, native_directory: Path, output: Path, source_sha: str):
    cards = []
    for record in records:
        if record["final_native"] is None:
            continue
        image_path = native_directory/record["final_native"]["png_path"]
        encoded = base64.b64encode(image_path.read_bytes()).decode()
        data = episode_summary(record)
        cards.append(f'<article><h2>{html.escape(record["episode_id"])}</h2>'
                     f'<img width="384" height="384" src="data:image/png;base64,{encoded}" alt="Original native material readback">'
                     f'<pre>{html.escape(json.dumps(data,indent=2))}</pre></article>')
    content = ('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">'
        '<title>DRIV3R Stage A native material evidence</title><style>body{font:16px system-ui;background:#17202b;color:#eee;'
        'margin:2rem;max-width:1400px}main{display:flex;flex-wrap:wrap;gap:2rem}article{max-width:640px;border:1px solid #607080;'
        'padding:1rem;border-radius:8px}img{image-rendering:pixelated;max-width:100%;height:auto;background:#000}'
        'pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:12px}</style><h1>DRIV3R Stage A</h1>'
        '<p>Original PNG bytes from native stored material. These are headless readback visualizations, not framebuffer '
        'captures or AI illustrations. Protected wall/obstacle are part of the initial fixture. Model answers are retained '
        'without repair. A completed fuzzy graph does not establish artistic usefulness.</p>'
        f'<p>Source <code>{source_sha}</code> · Draft/HOLD · No training</p><main>'+''.join(cards)+'</main></html>')
    (output/"gallery.html").write_text(content, encoding="utf-8")


def qualify(args) -> dict:
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    summary = {"schema": "driv3r-stage-a-result-v1", "source_sha": args.source_sha, "stage": "A",
               "draft_hold": True, "result": "HOLD", "development_only": args.development,
               "gates": {f"A{n}": {"status": "BLOCKED", "reason": "Execution not reached"} for n in range(1, 9)},
               "episodes": [], "limitations": ["Linux CPU headless only; no Windows or graphical framebuffer qualification",
                  "No reference Transformers inference or Q4 parity experiment", "No artistic superiority claim or training",
                  "Fuzzy success means graph terminal, separately from actual painted geometry",
                  "Replay proves stored-material action equality, not full simulation replay"]}
    records = []
    backend = None
    active_gates = ["A1"]
    try:
        write_json(output/"frozen-cohort.json", {**FROZEN, "sha256": digest(FROZEN)})
        if args.development:
            from experiments.agent_painter.native.runtime import development_runtime
            custody = development_runtime(ROOT, args.source_sha, args.godot)
        else:
            custody = runtime_custody(args.source_sha, args.runtime_manifest, args.godot)
        write_json(output/"runtime-custody.json", custody)
        summary["source_tree"] = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], text=True, cwd=ROOT).strip()
        summary["gates"]["A1"] = {"status": "PARTIAL" if args.development else "PASS",
            "reason": "Retained-runtime diagnostic only" if args.development else "Exact clean source/lineage and source-built native custody verified"}
        runtime = json.loads((args.runtime_dir/"runtime-manifest.json").read_text())
        write_json(output/"model-runtime.json", runtime)
        host = {"platform": platform.platform(), "python": sys.version, "cpu_count": os.cpu_count(),
                "affinity": sorted(os.sched_getaffinity(0)), "cpuinfo": Path("/proc/cpuinfo").read_text(),
                "meminfo": Path("/proc/meminfo").read_text()}
        write_json(output/"host.json", host)
        active_gates = ["A4"]
        env = os.environ.copy()
        env.pop("DRIV3R_NATIVE_GODOT", None)
        with (output/"offline-tests.log").open("w") as log:
            tests = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "experiments/driv3r/tests",
                                    "-p", "test_*.py", "-v"], stdout=log, stderr=subprocess.STDOUT,
                                   env=env, cwd=ROOT, timeout=120)
        log = (output/"offline-tests.log").read_text()
        match = re.search(r"Ran (\d+) tests", log)
        summary["offline_tests"] = {"exit_code": tests.returncode, "discovered": int(match[1]) if match else None,
                                    "native_suite": "executed separately; offline invocation deliberately skips it"}
        if tests.returncode or match is None or int(match[1]) < 1:
            raise RuntimeError("Offline controller/backend/native-evidence contracts failed")
        summary["gates"]["A4"] = {"status": "PASS", "reason": "Versioned contracts, providers, ordering and parser/refusal tests executed"}
        active_gates = ["A2", "A3"]
        backend = new_backend(runtime, output/"resident-inference")
        with backend:
            smoke = run_inference_smoke(backend, output/"inference-smoke")
            summary["inference"] = smoke
            summary["gates"]["A2"] = {"status": smoke["status"], "reason": "Actual typed requests/raw answers, official model and runtime hashes retained"}
            with NativeSession(ROOT, args.godot, output/"native", args.source_sha, runtime_manifest=args.runtime_manifest) as native:
                for mode in ("direct", "fuzzy"):
                    active_gates = ["A5" if mode == "direct" else "A6"]
                    for reverse in (False, True):
                        name = f"{mode}-{'reverse' if reverse else 'forward'}"
                        provider = DirectProvider(reverse_order=reverse) if mode == "direct" else FuzzyProvider(reverse_order=reverse)
                        record = EpisodeController(max_decisions=FROZEN[mode]["max_decisions"], **FROZEN["common"]).run(
                            native=native, provider=provider, policy=D1Policy(backend), episode_id=name, output=output/name)
                        records.append(record)
                        validate_episode(record)
                        summary["episodes"].append(episode_summary(record))
                        print(json.dumps(summary["episodes"][-1], sort_keys=True), flush=True)
                baseline = EpisodeController(max_decisions=8, **FROZEN["common"]).run(native=native,
                    provider=DirectProvider(), policy=GeometricBaseline(), episode_id="geometric-baseline", output=output/"geometric-baseline")
                records.append(baseline)
                validate_episode(baseline)
                summary["episodes"].append(episode_summary(baseline))
            pids = {d["decision"]["raw"]["pid"] for record in records if record["policy"] == D1Policy.name
                    for d in record["steps"] if d["decision"] and d["decision"].get("raw")}
            summary["gates"]["A3"] = {"status": "PASS" if pids == set(smoke["pids"]) and len(pids) == 1 else "FAIL",
                                       "reason": "Same resident inference process served inference cohort and both native modes", "pids": sorted(pids)}
        summary["model_process"] = {"startup": backend.startup_record, "shutdown": backend.shutdown_record}
        direct = [r for r in records if r["mode"] == "direct" and r["policy"] == D1Policy.name]
        fuzzy = [r for r in records if r["mode"] == "fuzzy" and r["policy"] == D1Policy.name]
        summary["gates"]["A5"] = {"status": "PASS" if any(r["native_actions"] >= 2 for r in direct) else "FAIL",
            "reason": "Original multi-decision model controls with actual native material acknowledgement; task quality reported separately"}
        summary["gates"]["A6"] = {"status": "PASS" if any(r["native_actions"] >= 1 for r in fuzzy) else "FAIL",
            "reason": "Original selected existing Art operation/profile with native acknowledgement"}
        active_gates = ["A8"]
        gallery(records, output/"native", output, args.source_sha)
        with NativeSession(ROOT, args.godot, output/"replay-native", args.source_sha, runtime_manifest=args.runtime_manifest) as native:
            replays = [replay_episode(record, native, output/"native", output/(record["episode_id"]+"-replay")) for record in records]
        summary["replays"] = [{"episode_id": r["episode_id"], "passed": r["passed"],
                               "original_episode_sha256": r["original_episode_sha256"]} for r in replays]
        active_gates = ["A7"]
        native_checks = run_native_regressions(ROOT, args.godot, output/"native-controls", args.source_sha, args.runtime_manifest)
        summary["native_controls"] = {"passed": native_checks["passed"], "checks": len(native_checks["checks"])}
        safety = controller_safety(runtime, args.godot, args.source_sha, args.runtime_manifest, output/"controller-safety")
        summary["controller_safety"] = safety
        cleaned = backend.shutdown_record["process_reaped"] and all(
            json.loads((output/name/"cleanup.json").read_text())["exit_code"] == 0 for name in ("native", "replay-native", "native-controls"))
        summary["gates"]["A7"] = {"status": "PASS" if native_checks["passed"] and safety["passed"] and cleaned else "FAIL",
            "reason": "Actual native refusal/STOP controls, model timeout/cancellation, zero unintended cells and process cleanup"}
        summary["gates"]["A8"] = {"status": "PASS" if all(r["passed"] for r in replays) and not args.development else "PARTIAL",
            "reason": "Original request/response and native material records replayed; exact source/model/runtime identities and artifact inventory retained"}
        if not args.development:
            active_gates = ["A1", "A8"]
            after = runtime_custody(args.source_sha, args.runtime_manifest, args.godot)
            if after != custody:
                raise RuntimeError("Source/runtime custody changed during campaign")
        summary["result"] = "GO" if all(g["status"] == "PASS" for g in summary["gates"].values()) else "HOLD"
    except Exception as exc:
        summary["failure"] = {"type": type(exc).__name__, "message": str(exc), "traceback": traceback.format_exc()}
        for gate in active_gates:
            summary["gates"][gate] = {"status": "FAIL", "reason": f"{type(exc).__name__}: {exc}"}
        write_json(output/"failure.json", summary["failure"])
        if backend is not None:
            backend.close()
            summary["model_process"] = {"startup": backend.startup_record, "shutdown": backend.shutdown_record}
    finally:
        summary["elapsed_seconds"] = time.monotonic()-started
        write_json(output/"summary.json", summary)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--runtime-manifest", type=Path)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--runtime-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--development", action="store_true", help="Explicitly non-qualifying retained-runtime diagnostic")
    args = parser.parse_args()
    if args.runtime_manifest is None and not args.development:
        parser.error("Source-qualified execution requires --runtime-manifest")
    args.godot = args.godot.resolve()
    args.runtime_manifest = args.runtime_manifest.resolve() if args.runtime_manifest else None
    args.runtime_dir = args.runtime_dir.resolve()
    result = qualify(args)
    print(json.dumps({"result": result["result"], "gates": result["gates"], "failure": result.get("failure")}, indent=2))
    return 0 if result["result"] == "GO" else 1


if __name__ == "__main__":
    raise SystemExit(main())
