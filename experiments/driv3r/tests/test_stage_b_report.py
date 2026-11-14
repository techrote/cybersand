"""Synthetic report arithmetic/custody fixtures, never inference evidence."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from experiments.driv3r.contracts import digest
from experiments.driv3r.stage_b.report import write_report


def save(root, relative, value):
    path = root/relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True)+"\n")


def answer(choice="A", *, tokens=100, latency=1.0, confidence=.8, model=True, status="ok"):
    other = "B" if choice == "A" else "A"
    probs = {choice: confidence, other: 1-confidence}
    return {"status": status, "candidate_id": choice, "probabilities": probs,
            "confidence": confidence, "latency_seconds": latency,
            "model_identity": {"kind": "synthetic_report_fixture"},
            "backend_identity": {"kind": "synthetic_report_fixture"},
            "raw": {"request": {"state": "synthetic report fixture", "questions": {}},
                    "raw_response": {"usage": {"input_tokens": tokens, "output_tokens": 0}} if model else None}}


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.summary = {"schema": "driv3r-stage-b-summary-v1", "source_sha": "a"*40, "source_tree": "b"*40,
            "development": False, "development_only": False, "campaign_complete": True,
            "infrastructure_passed": True, "result": "GO_TO_BOUNDED_STAGE_C", "episodes": [], "probes": [],
            "usefulness": {"proceed_to_modest_stage_c": True}, "replays": [],
            "native_controls": {"passed": True, "checks": 3}, "pixel_controls": {"passed": True, "checks": 2},
            "controller_safety": {"passed": True, "checks": [{"label": "synthetic safety", "passed": True}]},
            "cleanup": {"passed": True, "native_processes": 1}, "persistent_model": {"passed": True, "pids": [123]},
            "elapsed_seconds": 100.0, "model_requests": 1}
        model = {"repository": "synthetic/report-model", "revision": "c"*40, "filename": "synthetic.gguf",
                 "quantization": "synthetic", "sha256": "d"*64, "bytes": 1}
        runtime = {"repository": "synthetic/report-runtime", "revision": "e"*40, "binary_sha256": "f"*64}
        self.summary["model_process"] = {"startup": {"status": "ok", "model_identity": model,
            "backend_identity": runtime, "load_seconds": 2.0, "elapsed_seconds": 3.0,
            "threads": 2, "context_tokens": 4096, "batch_tokens": 4096,
            "resources": {"VmRSS": 100, "VmHWM": 120}},
            "shutdown": {"process_reaped": True, "resources": {"VmRSS": 110, "VmHWM": 150}}}
        save(self.root, "runtime-custody.json", {"source_sha": "a"*40, "source_tree": "b"*40})
        save(self.root, "model-runtime.json", {"model_identity": model, "backend_identity": runtime,
            "model_acquisition": {"elapsed_seconds": 4.0}, "runtime_acquisition": {"elapsed_seconds": 1.0}})
        save(self.root, "frozen-protocol.json", {"protocol_sha256": "0"*64, "catalog_sha256": {"synthetic": "1"*64}})
        save(self.root, "host.json", {"platform": "synthetic", "python": "synthetic", "cpu_count": 2, "affinity": [0,1]})

    def episode(self, case, *, family="direct", split="held_out", policy="model", success=True,
                tokens=100, latency=1.0, elapsed=10.0, changed=2, terminal=None, extra_score=None):
        name = f"{case}-{policy}"
        observed = {"synthetic": True, "case": case, "cursor": [10,10]}
        candidates = [{"id": "A"}, {"id": "B"}]
        decision = answer(tokens=tokens, latency=latency, model=policy == "model",
                          confidence=.8 if policy == "model" else 1.0)
        step = {"step": 0, "observation": observed, "candidates": candidates, "decision": decision,
                "decision_requested": True, "host_status": "applied"}
        step["record_sha256"] = digest(step)
        record = {"episode_id": name, "policy": "synthetic-report-"+policy, "steps": [step], "decisions": 1,
                  "native_actions": 1, "actual_changed_cells": changed, "elapsed_seconds": elapsed,
                  "terminal_status": terminal or ("stop" if success else "budget_exhausted"),
                  "reason": "synthetic report fixture", "task_complete": True,
                  "final_native": {"world_material_sha256": "2"*64, "png_sha256": "3"*64}}
        score = {"task_success": success, **(extra_score or {})}
        if success is False:
            score["failure_reasons"] = ["synthetic objective failure"]
        row = {"episode_id": name, "case_id": case, "family": family, "split": split,
               "policy_label": policy, "policy": record["policy"], "episode_path": name+"/episode.json",
               "episode_sha256": digest(record), "score": score, "decision_costs": [],
               **{k: record[k] for k in ("decisions", "native_actions", "actual_changed_cells", "elapsed_seconds", "terminal_status", "reason")}}
        save(self.root, row["episode_path"], record)
        save(self.root, name+"/score.json", score)
        self.summary["episodes"].append(row)
        self.summary["replays"].append({"episode_id": name, "passed": True, "original_episode_sha256": digest(record)})
        return row, record

    def probe(self, episode, record, variant, *, tokens, latency, choice="A", semantic=None, valid=True):
        step = record["steps"][0]
        probe = {"schema": "driv3r-stage-b-probe-v1", "family": episode["family"], "case_id": episode["case_id"],
                 "split": episode["split"], "variant": variant, "source_step": 0,
                 "source_episode_sha256": digest(record), "source_step_sha256": step["record_sha256"],
                 "source_observation_sha256": digest(step["observation"]),
                 "source_candidate_set_sha256": digest(step["candidates"]),
                 "semantic_sha256": semantic or digest({"synthetic_semantics": episode["case_id"]}),
                 "observation": step["observation"], "candidates": step["candidates"],
                 "decision": answer(choice, tokens=tokens, latency=latency, status="ok" if valid else "timeout"),
                 "base_decision": step["decision"], "valid": valid, "native_execution": False,
                 "counterbalanced_pair_index": 0}
        path = f"probes/{episode['case_id']}-step-0-{variant}.json"
        save(self.root, path, probe)
        self.summary["probes"].append({k: v for k, v in probe.items() if k not in
                                      ("observation", "candidates", "decision", "base_decision")})
        return path, probe

    def report(self):
        save(self.root, "summary.json", self.summary)
        manifest = write_report(self.root, self.summary)
        return manifest, json.loads((self.root/"analysis.json").read_text()), (self.root/"report.md").read_text()

    def test_success_denominators_cost_percentiles_and_baseline_uncertainty_are_distinct(self):
        self.episode("one", tokens=100, latency=1, elapsed=10, changed=2)
        self.episode("two", success=False, tokens=300, latency=3, elapsed=30, changed=4)
        self.episode("one", policy="geometric_or_fixed", elapsed=1)
        self.episode("two", policy="geometric_or_fixed", elapsed=2)
        _, analysis, text = self.report()
        model = next(g for g in analysis["groups"] if g["policy_label"] == "model")
        baseline = next(g for g in analysis["groups"] if g["policy_label"] == "geometric_or_fixed")
        self.assertEqual((model["successes"], model["episodes"], model["success_fraction"]), (1,2,.5))
        self.assertEqual(model["changed_cells"]["total"], 6)
        self.assertEqual(model["changed_cells"]["p50"], 3)
        self.assertAlmostEqual(model["decision_cost"]["latency_seconds"]["p95"], 2.9)
        self.assertEqual(model["decision_cost"]["latency_seconds"]["total"], 4)
        self.assertEqual(model["decision_cost"]["input_tokens"]["total"], 400)
        self.assertEqual(model["model_uncertainty"]["confidence"]["p50"], .8)
        self.assertIsNone(baseline["model_uncertainty"])
        self.assertEqual(model["failure_terminal_statuses"], {"budget_exhausted": 1})
        comparison = analysis["baseline_comparisons"][0]
        self.assertEqual(comparison["success_fraction_difference"], -.5)
        self.assertAlmostEqual(comparison["elapsed_total_ratio"], 40/3)
        self.assertIn("two / model", text)
        self.assertIn("synthetic objective failure", text)
        self.assertNotIn("task_complete", json.dumps(analysis["episodes"]))

    def test_weighted_compaction_savings_differ_from_mean_pair_percentages(self):
        first, a = self.episode("small")
        second, b = self.episode("large")
        self.probe(first, a, "canonical", tokens=100, latency=10)
        self.probe(first, a, "compact_repeat", tokens=50, latency=5)
        self.probe(second, b, "canonical", tokens=1000, latency=100)
        self.probe(second, b, "compact_repeat", tokens=900, latency=90, choice="B")
        _, analysis, _ = self.report()
        group = analysis["compaction"]["groups"][0]
        cost = group["cost"]["input_tokens"]
        self.assertEqual(group["pairs"], 2)
        self.assertEqual(group["choice_flips"], 1)
        self.assertAlmostEqual(cost["weighted_fractional_reduction"], 150/1100)
        self.assertAlmostEqual(cost["per_pair_fractional_reduction"]["mean"], .3)
        self.assertEqual((cost["reference_total"], cost["compact_total"]), (1100,950))
        self.assertAlmostEqual(group["total_variation"]["p50"], .3)
        self.assertEqual(analysis["original_stage_a_development"]["pairs"], [])
        self.assertEqual(analysis["original_stage_a_development"]["rejected_pairs"], [])

    def test_compaction_rejects_semantic_mismatch_even_when_case_names_match(self):
        row, record = self.episode("different-semantics")
        self.probe(row, record, "canonical", tokens=100, latency=10, semantic="a"*64)
        self.probe(row, record, "compact_repeat", tokens=1, latency=1, semantic="b"*64)
        _, analysis, _ = self.report()
        self.assertEqual(analysis["compaction"]["pairs"], [])
        self.assertEqual(len(analysis["compaction"]["rejected_pairs"]), 1)
        self.assertIn("semantic hashes differ", analysis["compaction"]["rejected_pairs"][0]["reason"])

    def test_compaction_rejects_other_source_step_and_preserves_unmatched_record(self):
        row, record = self.episode("different-source")
        self.probe(row, record, "canonical", tokens=100, latency=10)
        path, altered = self.probe(row, record, "compact_repeat", tokens=1, latency=1)
        altered["source_candidate_set_sha256"] = "c"*64
        save(self.root, path, altered)
        _, analysis, _ = self.report()
        self.assertEqual(analysis["compaction"]["pairs"], [])
        self.assertEqual(len(analysis["probes"]), 2)
        self.assertTrue(any(i["kind"] == "mismatch" for i in analysis["evidence_issues"]))
        self.assertTrue(any(i["kind"] == "unverified" for i in analysis["evidence_issues"]))

    def test_original_stage_a_development_comparison_is_not_pooled_with_compaction(self):
        row, record = self.episode("dev", split="development")
        self.probe(row, record, "canonical", tokens=100, latency=5)
        self.probe(row, record, "compact_repeat", tokens=80, latency=4)
        self.probe(row, record, "original_stage_a", tokens=300, latency=10)
        _, analysis, text = self.report()
        self.assertTrue(analysis["compaction"]["information_preserving_comparison"])
        self.assertFalse(analysis["original_stage_a_development"]["information_preserving_comparison"])
        self.assertEqual(analysis["compaction"]["groups"][0]["cost"]["input_tokens"]["reference_total"], 100)
        self.assertEqual(analysis["original_stage_a_development"]["groups"][0]["cost"]["input_tokens"]["reference_total"], 300)
        self.assertIn("instruction and metadata changes", analysis["original_stage_a_development"]["claim"])
        self.assertIn("development diagnostic", text)

    def test_missing_cost_is_counted_without_imputation_and_failed_probe_remains(self):
        row, record = self.episode("missing", tokens=None, latency=None, success=False)
        self.probe(row, record, "reverse_candidates", tokens=None, latency=2, valid=False)
        _, analysis, _ = self.report()
        group = analysis["groups"][0]
        self.assertEqual(group["decision_cost"]["input_tokens"]["missing"], 1)
        self.assertIsNone(group["decision_cost"]["input_tokens"]["total"])
        self.assertIsNone(group["decision_cost"]["latency_seconds"]["p50"])
        probe = analysis["probe_groups"][0]
        self.assertEqual((probe["attempts"], probe["valid_source_bound_decisions"], probe["failed_or_unverified"]), (1,0,1))
        self.assertEqual(probe["cost"]["latency_seconds"]["total"], 2)
        self.assertEqual(probe["same_choice_fraction_all_attempts"], 0)
        self.assertIsNone(probe["same_choice_fraction_valid"])

    def test_vector_metrics_and_strong_baseline_are_visible_for_failed_choices(self):
        metrics = {"selected_intent": "INTENT_UP_6", "selected_algorithm": "STRAIGHT", "intent_target_error": 0,
                   "endpoint_error": 0, "travelled_length": 6, "travel_ratio": 1, "coverage_cells": 7,
                   "retrace_visits": 0, "preference_met": False}
        self.episode("vector", family="vector", success=False, extra_score=metrics, elapsed=20)
        self.episode("vector", family="vector", policy="geometry_preference", extra_score={**metrics, "preference_met": True}, elapsed=1)
        _, analysis, text = self.report()
        comparison = analysis["baseline_comparisons"][0]
        self.assertEqual(comparison["baseline"], "geometry_preference")
        self.assertEqual((comparison["model_successes"], comparison["baseline_successes"]), (0,1))
        model = next(r for r in analysis["episodes"] if r["policy_label"] == "model")
        self.assertEqual(model["score_metrics"]["coverage_cells"], 7)
        self.assertEqual(model["selected_algorithm"], "STRAIGHT")
        self.assertIn("Vector intent and path outcomes", text)
        self.assertIn("geometry_preference", text)

    def test_failed_safety_cannot_be_presented_as_supported_stage_c(self):
        self.episode("safe-source")
        self.summary["cleanup"]["passed"] = False
        self.summary["failure"] = {"message": "Synthetic child cleanup failure"}
        _, analysis, text = self.report()
        self.assertTrue(analysis["verification"]["stage_c_requested_by_runner"])
        self.assertFalse(analysis["verification"]["stage_c_claim_supported"])
        self.assertIn("does not authorize or establish Stage C readiness", text)
        self.assertIn("Synthetic child cleanup failure", text)

    def test_incomplete_summary_and_absent_native_output_still_produce_report(self):
        self.summary = {"result": "HOLD", "campaign_complete": False,
                        "failure": {"message": "Synthetic startup failure"}, "episodes": [], "probes": []}
        _, analysis, text = self.report()
        self.assertEqual(analysis["recorded_episodes"], 0)
        self.assertFalse(analysis["provenance"]["source_qualified"])
        self.assertFalse(analysis["verification"]["stage_c_claim_supported"])
        self.assertEqual(analysis["verification"]["replay"]["status"], "NOT_RECORDED")
        self.assertIn("Synthetic startup failure", text)

    def test_nullable_metadata_rows_remain_visible_without_sorting_errors(self):
        self.episode("known")
        self.summary["episodes"].append({"case_id": None, "family": None, "split": None,
            "policy_label": None, "episode_id": None, "terminal_status": None, "score": None,
            "actual_changed_cells": None, "elapsed_seconds": None})
        _, analysis, _ = self.report()
        self.assertEqual(len(analysis["episodes"]), 2)
        unknown = next(r for r in analysis["episodes"] if r["family"] == "unknown")
        self.assertIsNone(unknown["task_success"])
        self.assertEqual(unknown["terminal_status"], "unknown")
        self.assertFalse(analysis["verification"]["stage_c_claim_supported"])

    def test_duplicate_case_attempts_are_not_cherry_picked_for_baseline_comparison(self):
        first, record = self.episode("retry", success=False)
        second, later = deepcopy(first), deepcopy(record)
        later["episode_id"] = "retry-model-second-attempt"
        second.update(episode_id=later["episode_id"], episode_path=later["episode_id"]+"/episode.json",
                      episode_sha256=digest(later), score={"task_success": True})
        save(self.root, second["episode_path"], later)
        save(self.root, later["episode_id"]+"/score.json", second["score"])
        self.summary["episodes"].append(second)
        self.episode("retry", policy="geometric_or_fixed")
        _, analysis, _ = self.report()
        comparison = analysis["baseline_comparisons"][0]
        self.assertEqual(comparison["matched_cases"], [])
        self.assertEqual(comparison["duplicate_model_cases_excluded"], ["retry"])
        model = next(g for g in analysis["groups"] if g["policy_label"] == "model")
        self.assertEqual((model["successes"], model["episodes"]), (1,2))

    def test_model_identity_mismatch_is_not_described_as_loaded_verified_weights(self):
        self.episode("identity")
        self.summary["model_process"]["startup"]["model_identity"]["sha256"] = "9"*64
        _, analysis, _ = self.report()
        self.assertFalse(analysis["provenance"]["loaded_model_matches_manifest"])
        self.assertFalse(analysis["verification"]["stage_c_claim_supported"])

    def test_source_record_tampering_invalidates_custody_without_hiding_episode(self):
        row, record = self.episode("tamper")
        record["actual_changed_cells"] = 999
        save(self.root, row["episode_path"], record)
        _, analysis, _ = self.report()
        self.assertEqual(len(analysis["episodes"]), 1)
        self.assertFalse(analysis["episodes"][0]["original_record_verified"])
        self.assertTrue(any(i["kind"] == "mismatch" for i in analysis["evidence_issues"]))
        self.assertFalse(analysis["verification"]["stage_c_claim_supported"])

    def test_deterministic_outputs_and_write_once_preserve_original_evidence(self):
        self.episode("deterministic")
        save(self.root, "summary.json", self.summary)
        original_files = {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*.json")}
        with tempfile.TemporaryDirectory() as tmp:
            other = Path(tmp)
            for path, raw in original_files.items():
                (other/path).parent.mkdir(parents=True, exist_ok=True)
                (other/path).write_bytes(raw)
            first = write_report(self.root, self.summary)
            second = write_report(other, deepcopy(self.summary))
            self.assertEqual(first, second)
            self.assertEqual((self.root/"analysis.json").read_bytes(), (other/"analysis.json").read_bytes())
            self.assertEqual((self.root/"report.md").read_bytes(), (other/"report.md").read_bytes())
        with self.assertRaises(FileExistsError):
            write_report(self.root, self.summary)
        for path, raw in original_files.items():
            self.assertEqual((self.root/path).read_bytes(), raw)
        self.assertEqual(first["report_sha256"], hashlib.sha256((self.root/"report.md").read_bytes()).hexdigest())


if __name__ == "__main__":
    unittest.main()
