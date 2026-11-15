"""Frozen Stage B native evaluation and paired, nonexecuting decision probes.

No model output changes fixtures, scoring, policies or the conditional C gate.
Behavioral failure is a valid result; missing execution custody is not.
"""
from __future__ import annotations

import argparse
import base64
from copy import deepcopy
import html
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import signal
import statistics
import subprocess
import sys
import threading
import time
import traceback

from ..contracts import Refusal, canonical, digest, validate_decision
from ..controller import D1Policy, EpisodeController, validate_episode, write_json
from ..native import NativeSession
from ..provenance import ROOT, runtime_custody
from ..qualify import new_backend, percentile, controller_safety
from ..replay import replay_episode
from ..tests.test_native import run_native_regressions
from . import direct, fuzzy, vector
from .catalog import catalogs
from .representation import SemanticPolicy, semantic_view, encode, decode

PROTOCOL_PATH = Path(__file__).with_name("protocol.json")
FAMILIES = {"direct": (direct, direct.DirectCaseProvider),
            "fuzzy": (fuzzy, fuzzy.FuzzyCaseProvider), "vector": (vector, vector.VectorProvider)}


def frozen_protocol():
    value = json.loads(PROTOCOL_PATH.read_text())
    if value["schema"] != "driv3r-stage-b-protocol-v1":
        raise Refusal("Unknown frozen Stage B protocol")
    return value


class CampaignDeadline(RuntimeError):
    pass


class BudgetBackend:
    """Bound the whole study, including counterfactual probes, on one resident."""
    def __init__(self, backend, maximum, deadline):
        self.backend, self.maximum, self.deadline = backend, maximum, deadline
        self.calls = 0

    def decide(self, *args, **kwargs):
        if self.calls >= self.maximum or time.monotonic() >= self.deadline:
            raise CampaignDeadline("Frozen campaign request/time budget exhausted")
        self.calls += 1
        kwargs["timeout_seconds"] = min(kwargs["timeout_seconds"], max(.001, self.deadline-time.monotonic()))
        return self.backend.decide(*args, **kwargs)


def policy_for(family, label, backend):
    if label == "model":
        return SemanticPolicy(backend)
    if label == "geometric_or_fixed":
        return {"direct": direct.GeometricPolicy, "fuzzy": fuzzy.FixedOrderFuzzyBaseline,
                "vector": vector.VectorGeometricBaseline}[family]()
    if label == "geometry_preference":
        return vector.VectorGeometryPreferenceBaseline()
    seed = int(label.removeprefix("random_"))
    return {"direct": lambda: direct.RandomLegalPolicy(seed),
            "fuzzy": lambda: fuzzy.SeededRandomFuzzyBaseline(seed),
            "vector": lambda: vector.VectorRandomBaseline(seed, include_stop=True)}[family]()


def distribution(probabilities):
    if not probabilities:
        return {"entropy_bits": None, "margin": None}
    ranked = sorted(probabilities.values(), reverse=True)
    return {"entropy_bits": -sum(p*math.log2(p) for p in ranked if p),
            "margin": ranked[0]-(ranked[1] if len(ranked) > 1 else 0)}


def decision_cost(answer):
    raw = answer.get("raw") or {}
    response = raw.get("raw_response") or {}
    return {"candidate_id": answer.get("candidate_id"), "status": answer["status"],
            "confidence": answer.get("confidence"), "probabilities": answer.get("probabilities"),
            "latency_seconds": answer["latency_seconds"],
            "input_tokens": response.get("usage", {}).get("input_tokens"),
            "output_tokens": response.get("usage", {}).get("output_tokens"),
            "request_bytes": len(canonical(raw["request"])) if raw.get("request") else None,
            **distribution(answer.get("probabilities"))}


def measure_probes(entry, backend, output, protocol, counter, retained):
    """Copied native states, no execution. Differences have one declared cause."""
    record, case, family = entry["record"], entry["case"], entry["family"]
    source_rows = [r for r in record["steps"] if r["decision_requested"]]
    source_rows = source_rows[:2 if family == "vector" else 1]
    result = []
    for source in source_rows:
        if source["decision"]["status"] != "ok":
            continue
        obs, candidates = source["observation"], source["candidates"]
        view = semantic_view(obs, candidates)
        if decode(encode(view)) != view:
            raise Refusal("Semantic compaction is not reversible")
        pair = ["canonical", "compact_repeat"]
        if counter % 2:
            pair.reverse()
        variants = pair + (["original_stage_a"] if case["split"] == "development" else
                           ["reverse_candidates", "objective_paraphrase"])
        if family == "direct":
            variants.append("without_host_metrics")
        for variant in variants:
            probe_obs, probe_candidates = deepcopy(obs), deepcopy(candidates)
            encoding = "compact"
            if variant == "canonical":
                encoding = "canonical"
            elif variant == "without_host_metrics":
                encoding = "without-host-metrics"
            elif variant == "reverse_candidates":
                probe_candidates.reverse()
            elif variant == "objective_paraphrase":
                probe_obs["objective"] = case["paraphrase"]
            policy = D1Policy(backend) if variant == "original_stage_a" else SemanticPolicy(backend, encoding)
            answer = policy.decide(probe_obs, probe_candidates,
                timeout_seconds=protocol["limits"]["request_seconds"], cancel_event=threading.Event())
            valid = answer["status"] == "ok"
            if valid:
                validate_decision(answer, probe_obs, probe_candidates)
                if answer["raw"]["request"] != policy.request(probe_obs, probe_candidates):
                    raise Refusal("Probe original request differs from frozen representation")
            base = source["decision"]
            tv = (.5*sum(abs(base["probabilities"][k]-answer["probabilities"][k]) for k in base["probabilities"])
                  if valid else None)
            row = {"schema": "driv3r-stage-b-probe-v1", "family": family, "case_id": case["id"],
                "split": case["split"], "variant": variant, "source_step": source["step"],
                "source_episode_sha256": digest(record), "source_step_sha256": source["record_sha256"],
                "source_observation_sha256": digest(obs), "source_candidate_set_sha256": digest(candidates),
                "observation": probe_obs, "candidates": probe_candidates, "policy": policy.name,
                "semantic_sha256": digest(semantic_view(probe_obs, probe_candidates,
                                                         ablate=variant == "without_host_metrics")),
                "decision": answer, "base_decision": base, "valid": valid,
                "same_choice": valid and base["candidate_id"] == answer["candidate_id"],
                "total_variation": tv, "cost": decision_cost(answer),
                "native_execution": False, "counterbalanced_pair_index": counter,
                "claim": "Decision-only counterfactual on original native state; no new World mutation or task-success claim"}
            write_json(output/f"{case['id']}-step-{source['step']}-{variant}.json", row)
            result.append(row)
            retained.append(row)
            print(json.dumps({"event": "probe", "case": case["id"], "step": source["step"],
                              "variant": variant, **decision_cost(answer)}, sort_keys=True), flush=True)
        counter += 1
    return result, counter


def episode_result(entry):
    record = entry["record"]
    answers = [s["decision"] for s in record["steps"] if s["decision"] is not None]
    costs = [decision_cost(d) for d in answers]
    return {"family": entry["family"], "case_id": entry["case"]["id"], "split": entry["case"]["split"],
            "policy_label": entry["policy_label"], "episode_id": record["episode_id"], "policy": record["policy"],
            "episode_sha256": digest(record), "episode_path": entry["episode_path"],
            "native_directory": entry["native_directory"], "score": entry["score"],
            "choices": [d["candidate_id"] for d in answers], "decisions": record["decisions"],
            "native_actions": record["native_actions"], "actual_changed_cells": record["actual_changed_cells"],
            "terminal_status": record["terminal_status"], "reason": record["reason"],
            "elapsed_seconds": record["elapsed_seconds"], "decision_costs": costs,
            "final_material_sha256": (record.get("final_native") or {}).get("world_material_sha256"),
            "final_png_sha256": (record.get("final_native") or {}).get("png_sha256")}


def retained_entry(family, case, label, record, directory):
    """A broken receipt still gets a visible failed row and its original journal."""
    try:
        validate_episode(record)
        score = FAMILIES[family][0].score_episode(case, record)
        valid = True
    except Exception as exc:
        score = {"task_success": False, "evidence_error": f"{type(exc).__name__}: {exc}"}
        valid = False
    return {"family": family, "case": case, "policy_label": label, "record": record,
            "score": score, "validation_passed": valid,
            "episode_path": record["episode_id"]+"/episode.json", "native_directory": directory}


def evaluate_usefulness(episodes, probes, prerequisites):
    families = {}
    thresholds = frozen_protocol()["stage_c_gate"]["family_success"]
    for family, threshold in thresholds.items():
        selected = [r for r in episodes if r["family"] == family and r["split"] == "held_out"]
        model = [r for r in selected if r["policy_label"] == "model"]
        random = [r for r in selected if r["policy_label"].startswith("random_")]
        success = sum(r["score"]["task_success"] for r in model)
        rate = success/len(model) if model else 0
        random_rate = sum(r["score"]["task_success"] for r in random)/len(random) if random else 1
        stability = {}
        for variant in ("reverse_candidates", "objective_paraphrase"):
            rows = [p for p in probes if p["family"] == family and p["split"] == "held_out" and p["variant"] == variant]
            stability[variant] = {"pairs": len(rows), "same_choices": sum(r["same_choice"] for r in rows),
                                  "fraction": sum(r["same_choice"] for r in rows)/len(rows) if rows else 0}
        passed = (success >= threshold and rate > random_rate and all(
            s["pairs"] and s["fraction"] >= .75 for s in stability.values()))
        baselines = {}
        for label in sorted({r["policy_label"] for r in selected if r["policy_label"] != "model"}):
            group = [r for r in selected if r["policy_label"] == label]
            baselines[label] = {"successes": sum(r["score"]["task_success"] for r in group), "episodes": len(group),
                                "elapsed_seconds": sum(r["elapsed_seconds"] for r in group)}
        families[family] = {"successes": success, "episodes": len(model), "success_fraction": rate,
            "threshold": threshold, "random_episodes": len(random), "random_fraction": random_rate,
            "stability": stability, "baselines": baselines, "behavior_criterion_passed": bool(passed)}
    return {"prerequisites_passed": bool(prerequisites), "families": families,
            "proceed_to_modest_stage_c": bool(prerequisites and any(x["behavior_criterion_passed"] for x in families.values())),
            "claim": "Predeclared exploratory usefulness threshold, not model superiority or population generalization"}


def gallery(entries, output, source_sha):
    cards = []
    for entry in entries:
        record = entry["record"]
        if not record.get("final_native"):
            continue
        picture = output/entry["native_directory"]/record["final_native"]["png_path"]
        if not picture.is_file():
            continue
        image = base64.b64encode(picture.read_bytes()).decode()
        cards.append(f'<article><h2>{html.escape(record["episode_id"])}</h2>'
            f'<img src="data:image/png;base64,{image}" alt="Original native material readback">'
            f'<pre>{html.escape(json.dumps(episode_result(entry), indent=2))}</pre></article>')
    (output/"gallery.html").write_text('<!doctype html><meta charset="utf-8"><title>DRIV3R Stage B native evidence</title>'
        '<style>body{font:16px system-ui;background:#17202b;color:#eee;margin:2rem}main{display:flex;flex-wrap:wrap;gap:1rem}'
        'article{max-width:38rem;padding:1rem;border:1px solid #789}img{width:384px;image-rendering:pixelated;max-width:100%}'
        'pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:12px}</style><h1>DRIV3R Stage B</h1>'
        '<p>Original headless native stored-material PNGs, not framebuffer screenshots. Every policy and failure is retained. '
        'Planning in vector cases is a no-paint transition, followed by one acknowledged path-mask tool.</p>'
        f'<p>Source {html.escape(source_sha)} · Draft/HOLD</p><main>'+''.join(cards)+'</main>')


def new_native(args, output):
    return NativeSession(ROOT, args.godot, output, args.source_sha, runtime_manifest=args.runtime_manifest)


def native_pixel_controls(args, output):
    rows = []
    with new_native(args, output) as native:
        case = vector.load_cases("development")[0]
        original = native.reset(case["fixture"]["id"])["observation"]
        unknown = native.reset("not-in-frozen-catalog")
        rows.append({"label": "unknown fixture refused without replacing World", "passed":
            unknown["status"] == "refused" and unknown["reset_admitted"] is False and
            unknown["observation"]["world_material_sha256"] == original["world_material_sha256"] and
            unknown["observation"]["generation"] == original["generation"]})
        for label, points, material, budget in (("pixel out of focus", [[96, 0]], 58, 1),
                ("pixel boolean coordinate", [[True, 1]], 58, 1), ("pixel unauthorized material", [[22, 20]], 28, 1),
                ("duplicate visits exceed native budget", [[22, 20], [22, 20]], 58, 1)):
            state = native.latest_observation
            reply = native.apply([{"shape": "pixels", "material": material, "points": points}],
                expected_generation=state["generation"], expected_revision=state["revision"], expected_tick=state["tick"],
                action_id="pixel-refusal", cell_budget=budget)
            rows.append({"label": label, "passed": reply["status"] == "refused" and
                         reply["receipt"]["actual_changed_cells"] == 0, "reply": reply})
    result = {"passed": all(r["passed"] for r in rows), "checks": rows}
    write_json(output/"pixel-controls.json", result)
    return result


def qualify(args):
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    protocol = frozen_protocol()
    started = time.monotonic()
    deadline = started+protocol["limits"]["max_campaign_seconds"]
    summary = {"schema": "driv3r-stage-b-summary-v1", "source_sha": args.source_sha,
        "source_tree": subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True).strip(),
        "draft_hold": True, "development": args.development, "development_only": args.development_only,
        "campaign_complete": False, "infrastructure_passed": False, "result": "HOLD", "episodes": [], "probes": [],
        "limitations": ["Small frozen exploratory cohort; no population generalization or artistic superiority claim",
          "Counterfactual order/paraphrase probes do not execute their alternative choices",
          "Headless material PNGs are not framebuffer captures", "Official Q8 only; no fine tuning or reference/Q4 experiment"]}
    entries, probes, backend = [], [], None
    def check_deadline():
        if time.monotonic() >= deadline:
            raise CampaignDeadline("Frozen total campaign deadline reached")
    def interruption(signum, _frame):
        signal.setitimer(signal.ITIMER_REAL, 0)
        raise CampaignDeadline(f"Campaign interrupted by signal {signum}; owned children will be reaped")
    old_handlers = {sig: signal.signal(sig, interruption) for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGALRM)}
    previous_timer = signal.setitimer(signal.ITIMER_REAL, protocol["limits"]["max_campaign_seconds"])
    try:
        _, fixture_hashes = catalogs(ROOT)
        write_json(output/"frozen-protocol.json", {"protocol": protocol,
                                                  "protocol_sha256": hashlib.sha256(PROTOCOL_PATH.read_bytes()).hexdigest(),
                                                  "canonical_protocol_sha256": digest(protocol),
                                                  "catalog_sha256": fixture_hashes})
        if args.development:
            from experiments.agent_painter.native.runtime import development_runtime
            custody = development_runtime(ROOT, args.source_sha, args.godot)
        else:
            custody = runtime_custody(args.source_sha, args.runtime_manifest, args.godot)
        write_json(output/"runtime-custody.json", custody)
        write_json(output/"host.json", {"platform": platform.platform(), "python": sys.version,
            "cpu_count": os.cpu_count(), "affinity": sorted(os.sched_getaffinity(0)),
            "cpuinfo": Path("/proc/cpuinfo").read_text(), "meminfo": Path("/proc/meminfo").read_text()})
        env = os.environ.copy()
        env.pop("DRIV3R_NATIVE_GODOT", None)
        with (output/"offline-tests.log").open("w") as log:
            tested = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "experiments/driv3r/tests",
                                    "-p", "test_*.py", "-v"], cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        if tested.returncode:
            raise Refusal("Offline contract checks failed")
        runtime = json.loads((args.runtime_dir/"runtime-manifest.json").read_text())
        write_json(output/"model-runtime.json", runtime)
        backend = new_backend(runtime, output/"resident-inference", threads=protocol["runtime"]["cpu_threads"],
                              ctx_size=protocol["runtime"]["context_tokens"], batch_size=protocol["runtime"]["physical_batch_tokens"])
        counted = BudgetBackend(backend, protocol["limits"]["max_model_requests"], deadline)
        counter = 0
        splits = ("development",) if args.development_only else ("development", "held_out")
        with backend:
            for split in splits:
                for family, (module, provider_type) in FAMILIES.items():
                    cases = module.load_cases(split)
                    directory = f"native-{split}-{family}-model"
                    group_entries = []
                    with new_native(args, output/directory) as native:
                        for case in cases:
                            check_deadline()
                            name = case["id"]+"-model"
                            max_decisions = case.get("max_decisions", protocol["limits"][family+"_max_decisions"])
                            record = EpisodeController(max_decisions=max_decisions,
                                max_changed_cells=protocol["limits"]["max_changed_cells_per_episode"],
                                max_wall_seconds=protocol["limits"]["max_episode_seconds"],
                                request_seconds=protocol["limits"]["request_seconds"]).run(native=native,
                                provider=provider_type(case), policy=SemanticPolicy(counted), episode_id=name, output=output/name)
                            entry = retained_entry(family, case, "model", record, directory)
                            entries.append(entry)
                            group_entries.append(entry)
                            write_json(output/name/"score.json", entry["score"])
                            print(json.dumps({"event": "episode", **episode_result(entry)}, sort_keys=True), flush=True)
                            # Implementation failures in development cannot silently enter held-out evaluation.
                            if not entry["validation_passed"] or record["terminal_status"] in ("model_failure", "invalid_decision", "native_refusal", "cancelled"):
                                raise Refusal("Primary model/native implementation failure; original episode retained")
                    # The copied states need no live World. Close this bounded
                    # native group before warm probes consume its lifetime.
                    for entry in group_entries:
                        new_probes, counter = measure_probes(entry, counted, output/"probes", protocol, counter, probes)
                        if not all(p["valid"] for p in new_probes):
                            raise Refusal("Paired probe inference failure; original raw output retained")
        summary["model_requests"] = counted.calls
        summary["model_process"] = {"startup": backend.startup_record, "shutdown": backend.shutdown_record}
        # All ordinary-code baselines are native executions, never model repairs.
        for split in splits:
            labels = [p for p in protocol[split]["policies"] if p != "model"]
            for family, (module, provider_type) in FAMILIES.items():
                family_labels = labels + (["geometry_preference"] if split == "held_out" and family == "vector" else [])
                for label in family_labels:
                    directory = f"native-{split}-{family}-{label}"
                    with new_native(args, output/directory) as native:
                        for case in module.load_cases(split):
                            check_deadline()
                            name = case["id"]+"-"+label
                            record = EpisodeController(max_decisions=case.get("max_decisions", protocol["limits"][family+"_max_decisions"]),
                                max_changed_cells=protocol["limits"]["max_changed_cells_per_episode"],
                                max_wall_seconds=protocol["limits"]["max_episode_seconds"],
                                request_seconds=protocol["limits"]["request_seconds"]).run(native=native,
                                provider=provider_type(case), policy=policy_for(family, label, None), episode_id=name, output=output/name)
                            entry = retained_entry(family, case, label, record, directory)
                            entries.append(entry)
                            write_json(output/name/"score.json", entry["score"])
                            print(json.dumps({"event": "episode", **episode_result(entry)}, sort_keys=True), flush=True)
                            if not entry["validation_passed"] or record["terminal_status"] in ("invalid_decision", "native_refusal", "cancelled", "model_failure"):
                                raise Refusal("Baseline native/contract failure; original episode retained")
        # Split replay sessions along original groups to retain bounded RPC counts.
        replays = []
        for directory in dict.fromkeys(e["native_directory"] for e in entries):
            with new_native(args, output/("replay-"+directory)) as native:
                for entry in (e for e in entries if e["native_directory"] == directory):
                    check_deadline()
                    result = replay_episode(entry["record"], native, output/directory,
                                            output/(entry["record"]["episode_id"]+"-replay"))
                    replays.append({"episode_id": result["episode_id"], "passed": result["passed"],
                                    "original_episode_sha256": result["original_episode_sha256"]})
            print(json.dumps({"event": "replay_group", "group": directory, "replayed_total": len(replays)}), flush=True)
        summary["replays"] = replays
        gallery(entries, output, args.source_sha)
        controls = run_native_regressions(ROOT, args.godot, output/"native-controls", args.source_sha, args.runtime_manifest)
        pixels = native_pixel_controls(args, output/"pixel-controls")
        safety = controller_safety(runtime, args.godot, args.source_sha, args.runtime_manifest, output/"controller-safety")
        summary["native_controls"] = {"passed": controls["passed"], "checks": len(controls["checks"])}
        summary["pixel_controls"] = {"passed": pixels["passed"], "checks": len(pixels["checks"])}
        summary["controller_safety"] = safety
        cleanup = [json.loads(p.read_text()) for p in output.rglob("cleanup.json")]
        cleaned = backend.shutdown_record["process_reaped"] and all(r["exit_code"] == 0 for r in cleanup)
        summary["cleanup"] = {"passed": cleaned, "native_processes": len(cleanup)}
        pids = {s["decision"]["raw"]["pid"] for e in entries if e["policy_label"] == "model"
                for s in e["record"]["steps"] if s["decision_requested"]}
        pids.update(p["decision"]["raw"]["pid"] for p in probes)
        summary["persistent_model"] = {"passed": len(pids) == 1, "pids": sorted(pids)}
        if not args.development and runtime_custody(args.source_sha, args.runtime_manifest, args.godot) != custody:
            raise Refusal("Source/runtime changed during campaign")
        summary["infrastructure_passed"] = all((controls["passed"], pixels["passed"], safety["passed"], cleaned,
            len(pids) == 1, all(r["passed"] for r in replays), all(p["valid"] for p in probes)))
        summary["campaign_complete"] = not args.development_only
    except Exception as exc:
        summary["failure"] = {"type": type(exc).__name__, "message": str(exc), "traceback": traceback.format_exc()}
        write_json(output/"failure.json", summary["failure"])
        if backend is not None:
            backend.close()
            summary["model_process"] = {"startup": backend.startup_record, "shutdown": backend.shutdown_record}
    finally:
        signal.setitimer(signal.ITIMER_REAL, *previous_timer)
        for sig, handler in old_handlers.items():
            signal.signal(sig, handler)
        summary["episodes"] = [episode_result(e) for e in entries]
        summary["probes"] = [{k: v for k, v in p.items() if k not in
                              ("observation", "candidates", "decision", "base_decision")} for p in probes]
        summary["usefulness"] = evaluate_usefulness(summary["episodes"], probes,
            summary["infrastructure_passed"] and summary["campaign_complete"] and not args.development)
        summary["elapsed_seconds"] = time.monotonic()-started
        if "counted" in locals():
            summary["model_requests"] = counted.calls
        summary["result"] = ("GO_TO_BOUNDED_STAGE_C" if summary["usefulness"]["proceed_to_modest_stage_c"] else
                             "QUALIFIED_BEHAVIOR_HOLD" if summary["infrastructure_passed"] and not args.development else "HOLD")
        from .report import write_report
        try:
            report_manifest = write_report(output, summary)
            write_json(output/"report-manifest.json", report_manifest)
        except Exception as exc:
            summary["report_failure"] = {"type": type(exc).__name__, "message": str(exc)}
            summary["infrastructure_passed"] = False
            summary["result"] = "HOLD"
            summary["usefulness"]["proceed_to_modest_stage_c"] = False
        write_json(output/"summary.json", summary)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--runtime-manifest", type=Path)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--runtime-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--development", action="store_true", help="Label retained native build as diagnostic only")
    parser.add_argument("--development-only", action="store_true", help="Run development cases only; never publication eligible")
    args = parser.parse_args()
    if not args.development and args.runtime_manifest is None:
        parser.error("Same-source native build manifest required unless --development")
    summary = qualify(args)
    print(json.dumps({k: summary[k] for k in ("result", "infrastructure_passed", "campaign_complete", "elapsed_seconds")}), flush=True)
    raise SystemExit(0 if summary["infrastructure_passed"] else 1)


if __name__ == "__main__":
    main()
