"""Deterministic, write-once analysis of original Stage B execution evidence.

This is a report generator, not a scorer or a native qualification substitute.
It never runs a policy, rewrites an episode, imputes missing measurements, or
turns graph completion into task success.  Original records remain authoritative.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import re

from ..contracts import canonical, digest

SCHEMA = "driv3r-stage-b-analysis-v1"
SHA40 = re.compile(r"[0-9a-f]{40}\Z")
SHA64 = re.compile(r"[0-9a-f]{64}\Z")
SOURCE_KEYS = ("source_episode_sha256", "source_step_sha256", "source_observation_sha256",
               "source_candidate_set_sha256")
COST_FIELDS = ("latency_seconds", "input_tokens", "output_tokens", "request_bytes")
UNCERTAINTY_FIELDS = ("confidence", "entropy_bits", "margin")
SCORE_FIELDS = (
    "final_goal_distance", "movements", "movements_after_first_goal", "retrace_count",
    "mean_offset_error", "max_offset_error", "clearance_violation_count", "excess_movements",
    "quality_score", "target_coverage", "new_paint_precision", "spill_cells",
    "acknowledged_full_action_overdraw_visits", "protected_changed_cells", "unexpected_changed_cells",
    "intent_target_error", "endpoint_error", "travelled_length", "straight_distance", "travel_ratio",
    "unique_path_cells", "coverage_cells", "retrace_visits", "retraced_edges",
)
OUTCOME_FLAGS = ("goal_reached", "explicit_policy_stop", "premature_stop", "geometry_success",
                 "fixture_matches", "native_receipts_consistent", "target_reached", "intent_optimal",
                 "planning_transition_only", "path_applied", "path_invariants_pass",
                 "native_materials_match", "preference_met")


def _number(value):
    return value if type(value) in (int, float) and math.isfinite(value) else None


def _mapping(value):
    return value if isinstance(value, dict) else {}


def _items(value):
    return value if isinstance(value, list) else []


def _label(value, default="unknown"):
    return value if isinstance(value, str) and value else default


def _fraction(a, b):
    return a/b if b else None


def _stats(values):
    """Linear-interpolated percentiles, with absent values counted, never zeroed."""
    values = list(values)
    observed = sorted(v for v in values if _number(v) is not None)
    def quantile(p):
        if not observed:
            return None
        position = (len(observed)-1)*p
        low = int(position)
        high = min(low+1, len(observed)-1)
        return observed[low]+(observed[high]-observed[low])*(position-low)
    return {"observations": len(observed), "missing": len(values)-len(observed),
            "total": math.fsum(observed) if observed else None,
            "mean": math.fsum(observed)/len(observed) if observed else None,
            "p50": quantile(.5), "p95": quantile(.95),
            "minimum": min(observed) if observed else None, "maximum": max(observed) if observed else None}


def _probabilities(value):
    if (not isinstance(value, dict) or not value or any(_number(v) is None or not 0 <= v <= 1 for v in value.values())
            or abs(math.fsum(value.values())-1) > 1e-4):
        return None
    return dict(sorted(value.items()))


def _cost(answer=None, fallback=None):
    answer, fallback = _mapping(answer), _mapping(fallback)
    raw = _mapping(answer.get("raw"))
    usage = _mapping(_mapping(raw.get("raw_response")).get("usage"))
    probabilities = _probabilities(answer.get("probabilities", fallback.get("probabilities")))
    ranked = sorted(probabilities.values(), reverse=True) if probabilities else []
    request = raw.get("request")
    return {"candidate_id": answer.get("candidate_id", fallback.get("candidate_id")),
            "status": answer.get("status", fallback.get("status", "missing")),
            "latency_seconds": _number(answer.get("latency_seconds", fallback.get("latency_seconds"))),
            "input_tokens": _number(usage.get("input_tokens", fallback.get("input_tokens"))),
            "output_tokens": _number(usage.get("output_tokens", fallback.get("output_tokens"))),
            "request_bytes": len(canonical(request)) if isinstance(request, dict) else _number(fallback.get("request_bytes")),
            "confidence": _number(answer.get("confidence", fallback.get("confidence"))),
            "probabilities": probabilities,
            "entropy_bits": -math.fsum(p*math.log2(p) for p in ranked if p) if ranked else None,
            "margin": ranked[0]-(ranked[1] if len(ranked) > 1 else 0) if ranked else None}


def _tv(a, b):
    a, b = _probabilities(a), _probabilities(b)
    return .5*math.fsum(abs(a[k]-b[k]) for k in a) if a and b and set(a) == set(b) else None


class _Evidence:
    def __init__(self, root):
        self.root = root.resolve()
        self.files = {}
        self.issues = []

    def issue(self, kind, path, detail):
        self.issues.append({"kind": kind, "path": str(path), "detail": str(detail)})

    def read(self, relative, *, required=False):
        if not isinstance(relative, str):
            if required:
                self.issue("missing", "<unspecified>", "Evidence path was not recorded")
            return None
        relative_path = Path(relative)
        path = self.root/relative_path
        if relative_path.is_absolute() or ".." in relative_path.parts or path.resolve() != path:
            self.issue("invalid", relative, "Evidence path is not an ordinary file within the execution directory")
            return None
        if not path.is_file():
            if required:
                self.issue("missing", relative, "Original evidence file is absent")
            return None
        try:
            if path.stat().st_size > 32*1024*1024:
                raise ValueError("JSON evidence exceeds the report reader bound")
            raw = path.read_bytes()
            def reject_nonfinite(value):
                raise ValueError("Nonfinite JSON constant: "+value)
            value = json.loads(raw, parse_constant=reject_nonfinite)
            if not isinstance(value, dict):
                raise ValueError("Expected a JSON object")
            self.files[relative_path.as_posix()] = {"path": relative_path.as_posix(), "bytes": len(raw),
                                                   "sha256": hashlib.sha256(raw).hexdigest()}
            return value
        except (OSError, ValueError, TypeError, RecursionError) as exc:
            self.issue("invalid", relative, exc)
            return None


def _episodes(evidence, summary):
    results, originals = [], {}
    for index, item in enumerate(_items(summary.get("episodes"))):
        item = _mapping(item)
        path = item.get("episode_path")
        original = evidence.read(path, required=True)
        verified = False
        if original is not None:
            actual_hash = digest(original)
            verified = actual_hash == item.get("episode_sha256")
            if not verified:
                evidence.issue("mismatch", path, "Original episode differs from its summary identity")
        score = _mapping(item.get("score"))
        if isinstance(path, str) and original is not None:
            saved_score = evidence.read(str(Path(path).with_name("score.json")))
            if saved_score is not None and saved_score != score:
                evidence.issue("mismatch", path, "Saved score differs from summary score")
                verified = False
        value = original or item
        decisions = []
        if original is not None:
            for position, step in enumerate(_items(original.get("steps"))):
                step = _mapping(step)
                if step.get("decision") is not None or step.get("decision_requested") is True:
                    decisions.append({"step": step.get("step", position), "host_status": step.get("host_status"),
                                      **_cost(step.get("decision"))})
        else:
            decisions = [{"step": i, "host_status": None, **_cost(fallback=d)}
                         for i, d in enumerate(_items(item.get("decision_costs")))]
        requested = value.get("decisions")
        if type(requested) is int and 0 <= requested <= 64:
            while len(decisions) < requested:
                decisions.append({"step": len(decisions), "host_status": None, **_cost()})
        reasons = []
        for key in ("failure_reasons", "failures", "receipt_errors"):
            reasons.extend(str(v) for v in _items(score.get(key)))
        if score.get("evidence_error"):
            reasons.append(str(score["evidence_error"]))
        success = score.get("task_success") if type(score.get("task_success")) is bool else None
        if success is False and not reasons:
            reasons.append("One or more objective or execution predicates were not satisfied")
        final = _mapping(value.get("final_native"))
        result = {"episode_id": _label(value.get("episode_id"), f"unidentified-{index}"),
            "case_id": _label(item.get("case_id")), "family": _label(item.get("family")),
            "split": _label(item.get("split")), "policy_label": _label(item.get("policy_label")),
            "policy": value.get("policy"), "task_success": success,
            "terminal_status": _label(value.get("terminal_status")), "reason": value.get("reason"),
            "failure_reasons": reasons, "decisions": decisions, "decision_requests": _number(requested),
            "native_actions": _number(value.get("native_actions")),
            "actual_changed_cells": _number(value.get("actual_changed_cells")),
            "elapsed_seconds": _number(value.get("elapsed_seconds")),
            "choices": [d["candidate_id"] for d in decisions],
            "score_metrics": {k: _number(score[k]) for k in SCORE_FIELDS if k in score},
            "outcome_flags": {k: score[k] for k in OUTCOME_FLAGS if type(score.get(k)) is bool},
            "selected_intent": score.get("selected_intent"), "selected_algorithm": score.get("selected_algorithm"),
            "episode_path": path, "episode_sha256": item.get("episode_sha256"),
            "original_record_verified": verified,
            "final_material_sha256": final.get("world_material_sha256", item.get("final_material_sha256")),
            "final_png_sha256": final.get("png_sha256", item.get("final_png_sha256"))}
        results.append(result)
        if verified:
            if actual_hash in originals:
                evidence.issue("duplicate", path, "Episode identity occurs more than once in summary")
            originals[actual_hash] = {"record": original, "row": result}
    return sorted(results, key=lambda r: (r["split"], r["family"], r["policy_label"], r["case_id"], r["episode_id"])), originals


def _group(rows):
    decisions = [d for r in rows for d in r["decisions"]]
    model = rows[0]["policy_label"] == "model"
    successes = sum(r["task_success"] is True for r in rows)
    return {"split": rows[0]["split"], "family": rows[0]["family"], "policy_label": rows[0]["policy_label"],
        "episodes": len(rows), "unique_cases": len({r["case_id"] for r in rows}), "successes": successes,
        "objective_failures": sum(r["task_success"] is False for r in rows),
        "unscored": sum(r["task_success"] is None for r in rows), "success_fraction": successes/len(rows),
        "terminal_statuses": dict(sorted(Counter(r["terminal_status"] for r in rows).items())),
        "failure_terminal_statuses": dict(sorted(Counter(r["terminal_status"] for r in rows if r["task_success"] is not True).items())),
        "decision_statuses": dict(sorted(Counter(str(d["status"]) for d in decisions).items())),
        "selected_ids": dict(sorted(Counter(str(d["candidate_id"]) for d in decisions).items())),
        "episode_seconds": _stats(r["elapsed_seconds"] for r in rows),
        "changed_cells": _stats(r["actual_changed_cells"] for r in rows),
        "decision_requests": _stats(r["decision_requests"] for r in rows),
        "native_actions": _stats(r["native_actions"] for r in rows),
        "decision_cost": {k: _stats(d.get(k) for d in decisions) for k in COST_FIELDS},
        "model_uncertainty": {k: _stats(d.get(k) for d in decisions) for k in UNCERTAINTY_FIELDS} if model else None,
        "probability_semantics": ("Actual model answer distribution" if model else
            "Baseline control probabilities are not model uncertainty; inspect original raw sampling rule"),
        "score_metrics": {k: _stats(r["score_metrics"].get(k) for r in rows)
                          for k in SCORE_FIELDS if any(k in r["score_metrics"] for r in rows)},
        "failed_episode_ids": [r["episode_id"] for r in rows if r["task_success"] is not True]}


def _baseline_comparisons(episodes):
    results = []
    for split, family in sorted({(r["split"], r["family"]) for r in episodes}):
        rows = [r for r in episodes if (r["split"], r["family"]) == (split, family)]
        model_attempts = defaultdict(list)
        for row in rows:
            if row["policy_label"] == "model":
                model_attempts[row["case_id"]].append(row)
        model = {key: value[0] for key, value in model_attempts.items() if len(value) == 1}
        for label in ("geometric_or_fixed", "geometry_preference"):
            baseline_attempts = defaultdict(list)
            for row in rows:
                if row["policy_label"] == label:
                    baseline_attempts[row["case_id"]].append(row)
            baseline = {key: value[0] for key, value in baseline_attempts.items() if len(value) == 1}
            if not baseline_attempts:
                continue
            ids = sorted(set(model) & set(baseline))
            m, b = [model[k] for k in ids], [baseline[k] for k in ids]
            ms, bs = sum(r["task_success"] is True for r in m), sum(r["task_success"] is True for r in b)
            unknown = sum(a["task_success"] is None or c["task_success"] is None for a, c in zip(m, b))
            mt, bt = _stats(r["elapsed_seconds"] for r in m), _stats(r["elapsed_seconds"] for r in b)
            if not ids or unknown:
                interpretation = "Matched outcome evidence is incomplete; no success advantage is established."
            elif ms == bs:
                interpretation = "Observed success matches ordinary code; this establishes no incremental success advantage."
            elif ms < bs:
                interpretation = "Observed model success is lower than ordinary code on this small matched cohort."
            else:
                interpretation = "Observed model success is higher on this small matched cohort; no population superiority claim follows."
            results.append({"split": split, "family": family, "baseline": label, "matched_cases": ids,
                "unpaired_model_cases": sorted(set(model)-set(baseline)),
                "unpaired_baseline_cases": sorted(set(baseline)-set(model)), "unknown_outcome_pairs": unknown,
                "duplicate_model_cases_excluded": sorted(k for k, v in model_attempts.items() if len(v) > 1),
                "duplicate_baseline_cases_excluded": sorted(k for k, v in baseline_attempts.items() if len(v) > 1),
                "model_successes": ms, "baseline_successes": bs, "model_success_fraction": _fraction(ms, len(ids)),
                "baseline_success_fraction": _fraction(bs, len(ids)),
                "success_fraction_difference": _fraction(ms-bs, len(ids)),
                "model_wins": sum(a["task_success"] is True and c["task_success"] is False for a, c in zip(m, b)),
                "baseline_wins": sum(c["task_success"] is True and a["task_success"] is False for a, c in zip(m, b)),
                "model_episode_seconds": mt, "baseline_episode_seconds": bt,
                "elapsed_total_ratio": mt["total"]/bt["total"] if mt["total"] is not None and bt["total"] else None,
                "interpretation": interpretation})
    return results


def _probe_key(row):
    return tuple(str(row.get(k, "")) for k in ("split", "family", "case_id", "source_step", "variant"))


def _probes(evidence, summary, originals):
    saved, results = {}, []
    directory = evidence.root/"probes"
    if directory.is_dir() and not directory.is_symlink():
        for path in sorted(directory.glob("*.json")):
            relative = path.relative_to(evidence.root).as_posix()
            row = evidence.read(relative, required=True)
            if row is not None:
                key = _probe_key(row)
                if key in saved:
                    evidence.issue("duplicate", relative, "Duplicate probe identity")
                saved[key] = (row, relative)
    for row in _items(summary.get("probes")):
        row = _mapping(row)
        key = _probe_key(row)
        if key not in saved:
            saved[key] = (row, None)
            evidence.issue("missing", "/".join(key), "Summary probe has no original saved record")
        else:
            original, path = saved[key]
            if any(row.get(k) != original.get(k) for k in SOURCE_KEYS+("semantic_sha256",)):
                evidence.issue("mismatch", path, "Probe summary/source identity mismatch")
    for key, (probe, path) in sorted(saved.items()):
        source = originals.get(probe.get("source_episode_sha256"))
        source_step = None
        if source is not None:
            source_step = next((s for s in _items(source["record"].get("steps"))
                                if s.get("step") == probe.get("source_step")), None)
        verified = bool(path and source and source_step and source["row"]["policy_label"] == "model")
        if verified:
            verified = (all(source["row"][k] == probe.get(k) for k in ("case_id", "family", "split")) and
                source_step.get("record_sha256") == probe.get("source_step_sha256") and
                digest(source_step.get("observation")) == probe.get("source_observation_sha256") and
                digest(source_step.get("candidates")) == probe.get("source_candidate_set_sha256"))
        if not verified:
            evidence.issue("unverified", path or "/".join(key), "Probe is not bound to an available original model episode/step")
        answer = _cost(probe.get("decision"), probe.get("cost"))
        base = _cost(source_step.get("decision")) if source_step else _cost(probe.get("base_decision"))
        valid = (probe.get("valid") is True and answer["status"] == "ok" and
                 answer["probabilities"] is not None and probe.get("native_execution") is False)
        if probe.get("variant") == "without_host_metrics" and probe.get("family") != "direct":
            valid = False
            evidence.issue("invalid", path, "Host-metric ablation appears outside the direct cohort")
        results.append({**{k: probe.get(k) for k in ("family", "case_id", "split", "variant", "source_step", *SOURCE_KEYS,
                                                  "semantic_sha256", "counterbalanced_pair_index")},
            **{k: _label(probe.get(k)) for k in ("family", "case_id", "split", "variant")},
            "path": path, "source_verified": verified, "valid": valid, "cost": answer, "base_cost": base,
            "same_choice": valid and verified and answer["candidate_id"] == base["candidate_id"],
            "total_variation": _tv(base["probabilities"], answer["probabilities"]) if valid and verified else None,
            "native_execution": False})
    return results


def _pair_identity(row):
    return tuple(row.get(k) for k in ("split", "family", "case_id", "source_step", *SOURCE_KEYS))


def _paired_comparison(probes, reference, *, same_semantics):
    """Pair only exact audited states; cost totals use complete measured pairs."""
    by_source = defaultdict(lambda: defaultdict(list))
    for row in probes:
        if reference == "original_stage_a" and row["split"] != "development" and row["variant"] != reference:
            continue
        if row["variant"] in (reference, "compact_repeat"):
            by_source[_pair_identity(row)][row["variant"]].append(row)
    pairs, rejected = [], []
    for identity, variants in sorted(by_source.items(), key=lambda item: str(item[0])):
        left, right = variants[reference], variants["compact_repeat"]
        reason = None
        if len(left) != 1 or len(right) != 1:
            reason = "Missing or duplicate comparison member"
        elif not all(r["source_verified"] and r["valid"] for r in (left[0], right[0])):
            reason = "Failed decision or unverified original-state custody"
        elif any(not isinstance(v, str) or not SHA64.fullmatch(v) for v in identity[4:]):
            reason = "Incomplete original-state identity"
        elif same_semantics and (not isinstance(left[0]["semantic_sha256"], str) or
                not SHA64.fullmatch(left[0]["semantic_sha256"]) or left[0]["semantic_sha256"] != right[0]["semantic_sha256"]):
            reason = "Canonical and compact semantic hashes differ"
        elif reference == "original_stage_a" and identity[0] != "development":
            reason = "Original Stage A comparison is development-only"
        if reason:
            rejected.append({"split": identity[0], "family": identity[1], "case_id": identity[2],
                             "source_step": identity[3], "reason": reason})
            continue
        a, b = left[0], right[0]
        row = {"split": a["split"], "family": a["family"], "case_id": a["case_id"], "source_step": a["source_step"],
               "source_episode_sha256": a["source_episode_sha256"], "semantic_sha256": a["semantic_sha256"],
               "reference_path": a["path"], "compact_path": b["path"],
               "reference_choice": a["cost"]["candidate_id"], "compact_choice": b["cost"]["candidate_id"],
               "choice_flip": a["cost"]["candidate_id"] != b["cost"]["candidate_id"],
               "total_variation": _tv(a["cost"]["probabilities"], b["cost"]["probabilities"]),
               "cost": {}}
        for metric in COST_FIELDS:
            x, y = _number(a["cost"].get(metric)), _number(b["cost"].get(metric))
            row["cost"][metric] = {"reference": x, "compact": y,
                "absolute_reduction": x-y if x is not None and y is not None else None,
                "fractional_reduction": (x-y)/x if x and y is not None else None}
        pairs.append(row)
    aggregates = []
    for split, family in sorted({(r["split"], r["family"]) for r in pairs}):
        group = [r for r in pairs if (r["split"], r["family"]) == (split, family)]
        costs = {}
        for metric in COST_FIELDS:
            complete = [r["cost"][metric] for r in group if all(_number(r["cost"][metric][k]) is not None
                                                                        for k in ("reference", "compact"))]
            total_a = math.fsum(r["reference"] for r in complete) if complete else None
            total_b = math.fsum(r["compact"] for r in complete) if complete else None
            costs[metric] = {"measured_pairs": len(complete), "missing_pairs": len(group)-len(complete),
                "reference_total": total_a, "compact_total": total_b,
                "weighted_fractional_reduction": (total_a-total_b)/total_a if total_a else None,
                "per_pair_fractional_reduction": _stats(r["cost"][metric]["fractional_reduction"] for r in group),
                "absolute_reduction": _stats(r["cost"][metric]["absolute_reduction"] for r in group)}
        aggregates.append({"split": split, "family": family, "pairs": len(group),
            "choice_flips": sum(r["choice_flip"] for r in group),
            "flip_fraction": sum(r["choice_flip"] for r in group)/len(group),
            "total_variation": _stats(r["total_variation"] for r in group), "cost": costs})
    return {"reference_variant": reference, "compact_variant": "compact_repeat",
            "information_preserving_comparison": same_semantics, "pairs": pairs, "groups": aggregates,
            "rejected_pairs": rejected,
            "claim": ("Same semantic state; compare encoding, measured cost and selected-ID fidelity" if same_semantics else
                      "Development diagnostic against the older full prompt; instruction and metadata changes are confounded")}


def _probe_groups(probes):
    groups = []
    keys = sorted({(p["split"], p["family"], p["variant"]) for p in probes}, key=str)
    for split, family, variant in keys:
        rows = [p for p in probes if (p["split"], p["family"], p["variant"]) == (split, family, variant)]
        admitted = [p for p in rows if p["valid"] and p["source_verified"]]
        matches = sum(p["same_choice"] for p in admitted)
        groups.append({"split": split, "family": family, "variant": variant, "attempts": len(rows),
            "valid_source_bound_decisions": len(admitted), "failed_or_unverified": len(rows)-len(admitted),
            "same_choices": matches, "same_choice_fraction_all_attempts": matches/len(rows),
            "same_choice_fraction_valid": _fraction(matches, len(admitted)),
            "total_variation": _stats(p["total_variation"] for p in rows),
            "cost": {k: _stats(p["cost"].get(k) for p in rows) for k in COST_FIELDS},
            "model_uncertainty": {k: _stats(p["cost"].get(k) for p in rows) for k in UNCERTAINTY_FIELDS},
            "statuses": dict(sorted(Counter(str(p["cost"]["status"]) for p in rows).items()))})
    return groups


def _provenance(evidence, summary):
    custody = evidence.read("runtime-custody.json", required=True) or {}
    manifest = evidence.read("model-runtime.json") or {}
    freeze = evidence.read("frozen-protocol.json") or {}
    host = evidence.read("host.json") or {}
    startup = _mapping(_mapping(summary.get("model_process")).get("startup"))
    shutdown = _mapping(_mapping(summary.get("model_process")).get("shutdown"))
    if not startup:
        files = sorted((evidence.root/"resident-inference").glob("*-startup.json"))
        if len(files) == 1:
            startup = evidence.read(files[0].relative_to(evidence.root).as_posix()) or {}
    declared_model, executed_model = _mapping(manifest.get("model_identity")), _mapping(startup.get("model_identity"))
    declared_backend, executed_backend = _mapping(manifest.get("backend_identity")), _mapping(startup.get("backend_identity"))
    model_keys = ("repository", "revision", "filename", "quantization", "sha256", "bytes", "license", "license_sha256")
    runtime_keys = ("repository", "revision", "tag", "version", "binary_sha256", "archive_sha256", "endpoint")
    source_complete = bool(SHA40.fullmatch(str(summary.get("source_sha", ""))) and SHA40.fullmatch(str(summary.get("source_tree", ""))))
    source_matches = source_complete and all(custody.get(k) == summary.get(k) for k in ("source_sha", "source_tree"))
    identity_matches = bool(executed_model and declared_model and executed_backend and declared_backend and
        SHA40.fullmatch(str(executed_model.get("revision", ""))) and SHA64.fullmatch(str(executed_model.get("sha256", ""))) and
        SHA40.fullmatch(str(executed_backend.get("revision", ""))) and SHA64.fullmatch(str(executed_backend.get("binary_sha256", ""))) and
        all(executed_model.get(k) == declared_model.get(k) for k in ("repository", "revision", "sha256")) and
        all(executed_backend.get(k) == declared_backend.get(k) for k in ("repository", "revision", "binary_sha256")))
    return {"source_sha": summary.get("source_sha"), "source_tree": summary.get("source_tree"),
        "source_identity_complete": source_complete, "runtime_source_identity_matches": source_matches,
        "source_qualified": bool(source_matches and summary.get("development") is False),
        "development_diagnostic": summary.get("development") is True,
        "model_manifest_identity": {k: declared_model.get(k) for k in model_keys},
        "executed_model_identity": {k: executed_model.get(k) for k in model_keys},
        "executed_runtime_identity": {k: executed_backend.get(k) for k in runtime_keys},
        "executed_runtime_files_sha256": digest(executed_backend["files"]) if isinstance(executed_backend.get("files"), dict) else None,
        "loaded_model_matches_manifest": identity_matches and startup.get("status") == "ok",
        "startup_status": startup.get("status"), "model_load_seconds": _number(startup.get("load_seconds")),
        "model_session_id": startup.get("session_id"), "model_pid": startup.get("pid"),
        "model_startup_seconds": _number(startup.get("elapsed_seconds")),
        "model_acquisition_seconds": _number(_mapping(manifest.get("model_acquisition")).get("elapsed_seconds")),
        "runtime_acquisition_seconds": _number(_mapping(manifest.get("runtime_acquisition")).get("elapsed_seconds")),
        "cpu_threads": startup.get("threads"), "context_tokens": startup.get("context_tokens"),
        "physical_batch_tokens": startup.get("batch_tokens"), "startup_resources": startup.get("resources"),
        "shutdown_resources": shutdown.get("resources"), "model_process_reaped": shutdown.get("process_reaped"),
        "host": {k: host.get(k) for k in ("platform", "python", "cpu_count", "affinity")},
        "protocol_sha256": freeze.get("protocol_sha256"), "fixture_catalog_sha256": freeze.get("catalog_sha256"),
        "report_generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}


def _verification(summary, episodes, provenance, issues):
    replays = _items(summary.get("replays"))
    replay_passed = sum(_mapping(r).get("passed") is True for r in replays)
    replay_status = ("NOT_RECORDED" if not replays else "FAIL" if replay_passed != len(replays) else
                     "PASS" if len(replays) == len(episodes) else "PARTIAL")
    controls = {k: {"passed": _mapping(summary.get(k)).get("passed"),
                    "checks": _mapping(summary.get(k)).get("checks")}
                for k in ("native_controls", "pixel_controls", "controller_safety", "cleanup", "persistent_model")}
    # Keep a small checks summary, not copies of nested native responses.
    for value in controls.values():
        if isinstance(value["checks"], list):
            value["checks"] = [{"label": c.get("label"), "passed": c.get("passed"), "kind": c.get("kind")}
                               for c in value["checks"] if isinstance(c, dict)]
    all_controls = all(value["passed"] is True for value in controls.values())
    complete = summary.get("campaign_complete") is True
    prerequisites = (summary.get("infrastructure_passed") is True and complete and all_controls and
        replay_status == "PASS" and provenance["source_qualified"] and provenance["loaded_model_matches_manifest"] and
        not issues and all(r["original_record_verified"] for r in episodes))
    return {"runner_infrastructure_passed": summary.get("infrastructure_passed"), "campaign_complete": complete,
        "replay": {"status": replay_status, "passed": replay_passed, "recorded": len(replays), "episodes": len(episodes)},
        "controls": controls, "declared_result": summary.get("result", "HOLD"),
        "stage_c_requested_by_runner": _mapping(summary.get("usefulness")).get("proceed_to_modest_stage_c") is True,
        "stage_c_claim_supported": prerequisites and _mapping(summary.get("usefulness")).get("proceed_to_modest_stage_c") is True,
        "claim": "This report cannot upgrade a failed, partial, diagnostic or unverified execution into Stage C readiness"}


def _fmt(value, digits=3):
    if value is None:
        return "—"
    if type(value) is bool:
        return "yes" if value else "no"
    if type(value) is int:
        return str(value)
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value).replace("|", "\\|").replace("\n", "; ")


def _table(headers, rows):
    return "\n".join(["| "+" | ".join(headers)+" |", "| "+" | ".join("---" for _ in headers)+" |"]+
                     ["| "+" | ".join(_fmt(v) for v in row)+" |" for row in rows])+"\n"


def _markdown(analysis):
    p, verification = analysis["provenance"], analysis["verification"]
    lines = ["# DRIV3R Stage B execution report", "", "**Draft/HOLD.** "+
        ("The runner's bounded Stage C continuation claim is supported by the recorded gates." if verification["stage_c_claim_supported"] else
         "This report does not authorize or establish Stage C readiness."), "",
        f"Runner result: **{_fmt(verification['declared_result'])}**. Campaign complete: **{_fmt(verification['campaign_complete'])}**. "
        f"Infrastructure passed: **{_fmt(verification['runner_infrastructure_passed'])}**.", "",
        "Task success comes from the frozen geometry/native score. Graph completion is never counted as success. "
        "All recorded episodes, poor choices, refusals and missing measurements remain visible. This small exploratory cohort "
        "does not establish population generalization or model superiority.", "",
        "## Source and measured runtime", "",
        _table(["Identity / measurement", "Recorded value"], [
            ("Repository source SHA", p["source_sha"]), ("Source tree", p["source_tree"]),
            ("Source qualified", p["source_qualified"]), ("Development diagnostic", p["development_diagnostic"]),
            ("Model repository", p["executed_model_identity"].get("repository")),
            ("Model revision", p["executed_model_identity"].get("revision")),
            ("Weight file", p["executed_model_identity"].get("filename")),
            ("Weight SHA256", p["executed_model_identity"].get("sha256")),
            ("Runtime revision", p["executed_runtime_identity"].get("revision")),
            ("Runtime binary SHA256", p["executed_runtime_identity"].get("binary_sha256")),
            ("Loaded model matches manifest", p["loaded_model_matches_manifest"]),
            ("Resident model session / PID", f"{_fmt(p['model_session_id'])} / {_fmt(p['model_pid'])}"),
            ("Model acquisition seconds", p["model_acquisition_seconds"]), ("Model load seconds", p["model_load_seconds"]),
            ("Model startup seconds, including validation", p["model_startup_seconds"]),
            ("CPU inference threads", p["cpu_threads"]), ("Context / physical batch tokens", f"{_fmt(p['context_tokens'])} / {_fmt(p['physical_batch_tokens'])}"),
            ("Startup RSS / high-water memory, KiB", f"{_fmt(_mapping(p['startup_resources']).get('VmRSS'))} / {_fmt(_mapping(p['startup_resources']).get('VmHWM'))}"),
            ("Shutdown RSS / high-water memory, KiB", f"{_fmt(_mapping(p['shutdown_resources']).get('VmRSS'))} / {_fmt(_mapping(p['shutdown_resources']).get('VmHWM'))}"),
            ("Protocol SHA256", p["protocol_sha256"])]),
        f"Recorded campaign wall time: **{_fmt(analysis['campaign_elapsed_seconds'])} s**; counted primary/probe model requests: "
        f"**{_fmt(analysis['campaign_model_requests'])}**. Safety-control model processes are reported separately in the original safety records.", "",
        "Evidence: [summary](summary.json), [runtime custody](runtime-custody.json), [model/runtime manifest](model-runtime.json), "
        "[frozen protocol](frozen-protocol.json), [complete analysis](analysis.json). Missing links are identified below.", "",
        "## Task outcomes and execution costs", "",
        "Fractions use all recorded attempts in each split/family/policy group. Unscored attempts stay in the denominator. "
        "Missing costs are excluded from numeric totals and reported as missing; they are never replaced with zero. "
        "P50/P95 use linear interpolation over observed measurements.", "",
        _table(["Split", "Family", "Policy", "Task success", "Unscored", "Cells P50 / P95 / total", "Episode s P50 / P95 / total", "Decision s P50 / P95 / total", "Input tokens P50 / P95 / total"],
            [(g["split"], g["family"], g["policy_label"], f"{g['successes']}/{g['episodes']}", g["unscored"],
              " / ".join(_fmt(g["changed_cells"][k]) for k in ("p50", "p95", "total")),
              " / ".join(_fmt(g["episode_seconds"][k]) for k in ("p50", "p95", "total")),
              " / ".join(_fmt(g["decision_cost"]["latency_seconds"][k]) for k in ("p50", "p95", "total")),
              " / ".join(_fmt(g["decision_cost"]["input_tokens"][k]) for k in ("p50", "p95", "total"))) for g in analysis["groups"]]),
        "### Model answer distributions", "",
        "Only model decisions contribute below. Baseline probability vectors are control/sampling records and are not model uncertainty. "
        "Direct random controls record uniform sampling probabilities; fuzzy/vector seeded controls may record one-hot chosen outputs. "
        "Their original sampling rule remains in each original decision record.", "",
        _table(["Split", "Family", "Confidence P50 / P95", "Entropy bits P50 / P95", "Margin P50 / P95", "Failed / missing decision statuses"],
            [(g["split"], g["family"],
              f"{_fmt(g['model_uncertainty']['confidence']['p50'])} / {_fmt(g['model_uncertainty']['confidence']['p95'])}",
              f"{_fmt(g['model_uncertainty']['entropy_bits']['p50'])} / {_fmt(g['model_uncertainty']['entropy_bits']['p95'])}",
              f"{_fmt(g['model_uncertainty']['margin']['p50'])} / {_fmt(g['model_uncertainty']['margin']['p95'])}",
              json.dumps({k:v for k,v in g["decision_statuses"].items() if k != "ok"}, sort_keys=True))
             for g in analysis["groups"] if g["model_uncertainty"] is not None]),
        "## Matched ordinary-code comparisons", "",
        _table(["Split", "Family", "Baseline", "Matched cases", "Model / baseline successes", "Elapsed total ratio", "Interpretation"],
            [(c["split"], c["family"], c["baseline"], len(c["matched_cases"]),
              f"{c['model_successes']} / {c['baseline_successes']}", c["elapsed_total_ratio"], c["interpretation"])
             for c in analysis["baseline_comparisons"]]),
        "Ratios compare total episode wall time on matched cases, including native overhead. A model that matches ordinary code at higher cost "
        "has not demonstrated incremental success value. Vector geometry_preference is the stronger visible-geometry comparator; straight-only results are also retained.", "",
        "## Information-preserving compaction", "",
        "Canonical and compact-repeat calls are paired only when their original episode, step, observation, candidate-set and semantic identities match. "
        "The weighted reduction is 1 − total compact cost / total canonical cost over complete measured pairs; it is distinct from the mean of per-pair reductions. "
        "First-use primary cost remains in episode results. Repeated-call latency is a warm-process measurement.", ""]
    for heading, section in ((None, analysis["compaction"]), ("### Original Stage A prompt: development diagnostic", analysis["original_stage_a_development"])):
        if heading:
            lines.extend([heading, "", "This comparison includes prompt instructions and metadata changes; it is not the information-preserving encoding experiment.", ""])
        lines.append(_table(["Split", "Family", "Pairs", "Choice flips", "Token reduction weighted / mean", "Latency reduction weighted", "TV P50 / P95"],
            [(g["split"], g["family"], g["pairs"], g["choice_flips"],
              f"{_fmt(g['cost']['input_tokens']['weighted_fractional_reduction'])} / {_fmt(g['cost']['input_tokens']['per_pair_fractional_reduction']['mean'])}",
              g["cost"]["latency_seconds"]["weighted_fractional_reduction"],
              f"{_fmt(g['total_variation']['p50'])} / {_fmt(g['total_variation']['p95'])}") for g in section["groups"]]))
        lines.extend([f"Rejected or incomplete pair groups: **{len(section['rejected_pairs'])}**; reasons are retained in analysis.json.", ""])
    lines.extend(["## Order, paraphrase and information ablation", "",
        "These are decision-only probes on copied native observations. Their alternative choices were not executed and do not establish counterfactual native task success. "
        "The host-metric ablation is direct-only; it removes derived metrics while preserving raw crop, task constraints, coordinates and history.", "",
        _table(["Split", "Family", "Variant", "Attempts / valid source-bound", "Same choice, all attempts", "TV P50 / P95", "Latency s total", "Input tokens total"],
            [(g["split"], g["family"], g["variant"], f"{g['attempts']} / {g['valid_source_bound_decisions']}",
              g["same_choice_fraction_all_attempts"], f"{_fmt(g['total_variation']['p50'])} / {_fmt(g['total_variation']['p95'])}",
              g["cost"]["latency_seconds"]["total"], g["cost"]["input_tokens"]["total"])
             for g in analysis["probe_groups"] if g["variant"] in ("reverse_candidates", "objective_paraphrase", "without_host_metrics")]),
        "## Every native episode outcome", "",
        "The following ledger includes successful and unsuccessful choices. An unsuccessful episode does not imply that every individual decision in its sequence was wrong.", "",
        _table(["Split / family", "Case / policy", "Task success", "Terminal", "Original chosen IDs", "Cells", "Failure or terminal reason", "Evidence"],
            [(f"{r['split']} / {r['family']}", f"{r['case_id']} / {r['policy_label']}", r["task_success"], r["terminal_status"],
              ", ".join(str(v) for v in r["choices"]), r["actual_changed_cells"],
              "; ".join(r["failure_reasons"]) or r["reason"],
              f"[episode]({r['episode_path']})" if r["episode_path"] else "missing") for r in analysis["episodes"]]),
        "### Vector intent and path outcomes", "",
        _table(["Split", "Case / policy", "Intent / algorithm", "Target error / vector endpoint error", "Travel / ratio", "Coverage", "Retrace visits", "Success"],
            [(r["split"], f"{r['case_id']} / {r['policy_label']}", f"{_fmt(r['selected_intent'])} / {_fmt(r['selected_algorithm'])}",
              f"{_fmt(r['score_metrics'].get('intent_target_error'))} / {_fmt(r['score_metrics'].get('endpoint_error'))}",
              f"{_fmt(r['score_metrics'].get('travelled_length'))} / {_fmt(r['score_metrics'].get('travel_ratio'))}",
              r["score_metrics"].get("coverage_cells"), r["score_metrics"].get("retrace_visits"), r["task_success"])
             for r in analysis["episodes"] if r["family"] == "vector"]),
        "Vector path order is an audited host construction. Native execution paints its cell mask; it does not simulate a physical vehicle traversing that order. "
        "Original headless material images are in [gallery.html](gallery.html); they are not framebuffer screenshots.", "",
        "## Native verification, failures and custody", "",
        _table(["Gate", "Recorded outcome"], [("Native replay", json.dumps(verification["replay"], sort_keys=True))]+
            [(k, v["passed"]) for k,v in verification["controls"].items()]+[("Stage C claim supported", verification["stage_c_claim_supported"])]),
        "Campaign failure: "+_fmt(analysis["campaign_failure"])+".", "",
        f"Report evidence issues: **{len(analysis['evidence_issues'])}**.", ""])
    for issue in analysis["evidence_issues"]:
        lines.append(f"- {_fmt(issue['kind'])}: {_fmt(issue['path'])} — {_fmt(issue['detail'])}")
    lines.extend(["", "## Interpretation limits", "",
        "No missing token count, latency, confidence or native readback is inferred. Confidence and score distributions are descriptive observations. "
        "Baseline probabilities retain their original controller semantics. Full original requests, responses, materials and receipts remain in their source records; "
        "analysis.json contains compact measurements and file integrity hashes, not replacements for those records. "
        "The frozen usefulness decision remains exploratory and conditional on source/native safety qualification. No training, merge or production-default change is implied.", ""])
    return "\n".join(lines)


def write_report(output: Path, summary: dict) -> dict:
    """Write output/report.md and output/analysis.json once; return integrity IDs."""
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    report_path, analysis_path = output/"report.md", output/"analysis.json"
    if report_path.exists() or analysis_path.exists():
        raise FileExistsError("Stage B report outputs already exist; original evidence is never overwritten")
    if not isinstance(summary, dict):
        raise TypeError("Stage B summary must be a mapping")
    evidence = _Evidence(output)
    saved_summary = evidence.read("summary.json")
    if saved_summary is not None and saved_summary != summary:
        evidence.issue("mismatch", "summary.json", "Passed summary differs from saved original summary")
    episodes, originals = _episodes(evidence, summary)
    probes = _probes(evidence, summary, originals)
    provenance = _provenance(evidence, summary)
    grouped = defaultdict(list)
    for row in episodes:
        grouped[(row["split"], row["family"], row["policy_label"])].append(row)
    issues = sorted(evidence.issues, key=lambda i: (i["kind"], i["path"], i["detail"]))
    analysis = {"schema": SCHEMA, "summary_sha256": digest(summary), "provenance": provenance,
        "recorded_episodes": len(episodes), "recorded_probes": len(probes),
        "campaign_elapsed_seconds": _number(summary.get("elapsed_seconds")),
        "campaign_model_requests": summary.get("model_requests"),
        "campaign_failure": _mapping(summary.get("failure")).get("message"),
        "groups": [_group(rows) for _, rows in sorted(grouped.items())],
        "baseline_comparisons": _baseline_comparisons(episodes),
        "compaction": _paired_comparison(probes, "canonical", same_semantics=True),
        "original_stage_a_development": _paired_comparison(probes, "original_stage_a", same_semantics=False),
        "probe_groups": _probe_groups(probes), "episodes": episodes, "probes": probes,
        "verification": _verification(summary, episodes, provenance, issues),
        "runner_usefulness": deepcopy(summary.get("usefulness")), "evidence_issues": issues,
        "input_files": [value for _, value in sorted(evidence.files.items())],
        "statistics": {"percentiles": "Linear interpolation at (n-1)*p", "missing": "Excluded from numeric sums; counted explicitly",
            "success_denominator": "All recorded episode attempts, including failed and unscored outcomes",
            "probabilities": "Model uncertainty is aggregated only for policy_label=model; baseline controls remain separately labelled"},
        "claims": ["Original recorded outcomes only", "No counterfactual native execution claim",
                   "No population generalization or model superiority claim", "No overwrite of original evidence"]}
    analysis_bytes = (json.dumps(analysis, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False)+"\n").encode()
    report_bytes = _markdown(analysis).encode()
    with analysis_path.open("xb") as file:
        file.write(analysis_bytes)
    with report_path.open("xb") as file:
        file.write(report_bytes)
    return {"schema": "driv3r-stage-b-report-manifest-v1", "source_sha": summary.get("source_sha"),
            "summary_sha256": analysis["summary_sha256"], "analysis_path": "analysis.json", "report_path": "report.md",
            "analysis_sha256": hashlib.sha256(analysis_bytes).hexdigest(), "report_sha256": hashlib.sha256(report_bytes).hexdigest(),
            "episodes": len(episodes), "probes": len(probes), "evidence_issues": len(issues),
            "stage_c_claim_supported": analysis["verification"]["stage_c_claim_supported"]}
