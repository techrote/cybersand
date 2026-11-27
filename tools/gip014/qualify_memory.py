#!/usr/bin/env python3
"""Seven bounded real-game campaigns separating corpus hints from prefix reuse.

The fixed Linux experiment uses ordinary run_campaign.gd and typed launch
options. A fresh CONTROL64 campaign supplies the unmodified corpus; two seeds
then compare fresh, imported-hint and explicit-prefix COVERAGE_HUNTER64 runs.
No physical checkpoint, arbitrary action fixture, network or shell is admitted.
--analyze only rechecks retained evidence and never launches Godot.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
import uuid
import zipfile

import campaign_evidence as coverage
import campaign_queue
import corpus_io
import owned_process
import replay_identity
import run_goblin as runner
import verify_transcript as reader

SCHEMA = "cybersand-goblin-memory-experiment-v1"
ENGINE_SHA256 = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
TOTAL_SECONDS = 900
GAME_SECONDS = 180
IMPORT_SECONDS = 240
MEMORY_MIB = 3072
OUTPUT_BYTES = 1024 * 1024 * 1024
ARMS = ("fresh", "hints_only", "explicit_prefix")
CULTIVATION = "cultivation-control-s13"
PREFIX = [{"id": "pause", "args": {}},
          {"id": "camera", "args": {"x": 0, "y": 0, "width": 480, "height": 270}},
          {"id": "select_material", "args": {"material": 58}},
          {"id": "rectangle", "args": {"x0": 32, "y0": 32, "x1": 39, "y1": 39}}]
READER_FILES = ("qualify_memory.py", "run_goblin.py", "owned_process.py", "campaign_queue.py",
                "campaign_evidence.py", "corpus_io.py", "replay_identity.py", "verify_transcript.py",
                "vocabulary.py", "minimize.py", "paired_comparison.py")


class CustodyError(ValueError):
    """Source/runtime/input identity no longer matches the registered experiment."""


def bounds() -> dict:
    return {"whole_worker_tree_seconds": TOTAL_SECONDS, "per_game_seconds": GAME_SECONDS,
            "one_import_seconds": IMPORT_SECONDS, "process_tree_memory_mib": MEMORY_MIB,
            "sampled_total_output_bytes": OUTPUT_BYTES, "per_process_log_bytes": owned_process.MAX_LOG_BYTES,
            "maximum_gameplay_processes": 7, "maximum_attempted_actions": 448,
            "additional_engine_processes": "one editor import and one bounded15-second version query",
            "scope": "sequential games; process-tree RSS and output are sampled bounds, not allocator/disk quotas"}


def tool_hashes() -> dict:
    return {name: runner.sha_file(Path(__file__).with_name(name)) for name in READER_FILES}


def config(policy: str, seed: int, arm: str) -> dict:
    if arm not in ARMS or policy not in ("CONTROL", "COVERAGE_HUNTER"):
        raise ValueError("Unknown fixed memory treatment")
    return {"fixture_id": "construction", "policy": policy, "seed": int(seed), "budget": 64,
            "pacing_ms": 0, "reuse_memory": arm == "explicit_prefix", "interactive": False,
            "replay": False, "reproduce": False, "evidence_kind": "headless_godot"}


def action_inputs(tape: dict) -> list[dict]:
    return [{"id": row["action"]["id"], "args": row["action"]["args"]} for row in tape["steps"]]


def context_for(tape: dict) -> dict:
    header = tape["header"]
    provenance = header["provenance"]
    if not replay_identity.valid(provenance):
        raise ValueError("Memory experiment requires the exact portable source/runtime identity")
    return {"fixture_id": header["fixture_id"], "fixture_version": header["fixture_version"],
            "fixture_sha256": header["fixture_sha256"], "provenance_sha256": reader.digest(corpus_io._canonical(
                {"replay_identity": provenance["replay_identity"], "source_dirty": provenance["source_dirty"]}))}


def selected_prefix(corpus: dict, context: dict) -> dict:
    """Mirror the bounded policy selection, without changing the actual corpus."""
    candidates = [record for record in corpus["records"]
                  if record.get("reusable") is True and record.get("prefix_complete") is True
                  and not str(record.get("classification", "")).startswith("confirmed_")
                  and all(record["context"].get(key) == value for key, value in context.items())]
    candidates.sort(key=lambda record: (-int(record["score"]), int(record["sequence"])))
    matches = [(index, record) for index, record in enumerate(candidates)
               if [{"id": action["id"], "args": action["args"]} for action in record["actions"]] == PREFIX]
    if len(matches) != 1:
        raise ValueError("Cultivation must retain exactly one eligible actual four-action edit prefix")
    rank, record = matches[0]
    if not 0 <= rank < 64:
        raise ValueError("Retained selection exceeds the bounded policy offset")
    return {"record_id": record["id"], "candidate_rank": rank, "eligible_candidates": len(candidates),
            "seeds": [rank + 64, rank + 128], "action_inputs": PREFIX,
            "selection_rule": "rank+64 and rank+128 select the same actual prefix; chosen before measured outcomes",
            "candidate_order_ids": [record["id"] for record in candidates]}


def measured_plan(selection: dict) -> list[dict]:
    orders = (ARMS, tuple(reversed(ARMS)))
    return [{"case_id": f"measured-{index * 3 + offset + 1:02d}-s{seed}-{arm}", "seed": seed, "arm": arm}
            for index, seed in enumerate(selection["seeds"]) for offset, arm in enumerate(orders[index])]


def prefix_proof(tape: dict) -> dict:
    if len(tape.get("steps", [])) < 4:
        return {"valid": False, "reason": "fewer than four observed actions"}
    rows = tape["steps"][:4]
    row = rows[-1]
    completed = all(item.get("status") == "completed" and
                    (item.get("admission", {}).get("accepted") is True or
                     item.get("admission", {}).get("status") in ("accepted", "queued")) for item in rows)
    first, last = row.get("capture_before", {}), row.get("capture_after", {})
    native = (coverage.valid_capture(first, row["before"].get("native", {})) and
              coverage.valid_capture(last, row["after"].get("native", {})))
    planes = bool(native and first.get("region") == last.get("region") == [32, 32, 8, 8]
                  and first.get("materials") == [0] * 64 and last.get("materials") == [58] * 64)
    inputs_match = action_inputs(tape)[:4] == PREFIX
    return {"valid": inputs_match and completed and planes, "inputs_match": inputs_match,
            "first_four_completed": completed, "native_planes_match": planes,
            "actual_changed_cells": 64 if planes else None,
            "before_native": row.get("before", {}).get("native"),
            "after_native": row.get("after", {}).get("native")}


def choice_change(first: dict | None, second: dict | None) -> dict:
    if first is None or second is None:
        return {"available": False, "reason": "one validated tape unavailable"}
    a, b = action_inputs(first), action_inputs(second)
    limit = min(len(a), len(b))
    changed = next((index for index in range(limit) if a[index] != b[index]), None)
    if changed is None:
        return {"available": True, "same_observed_prefix_actions": limit, "same_complete_action_sequence": a == b,
                "different_recorded_lengths": len(a) != len(b), "observed_choice_change": False,
                "scope": "No differing action in the common prefix; different lengths alone are not a changed choice."}
    before_a, before_b = first["steps"][changed]["before"], second["steps"][changed]["before"]
    return {"available": True, "observed_choice_change": True, "first_different_action_index": changed,
            "same_prior_action_prefix": a[:changed] == b[:changed], "fresh_action": a[changed], "hints_action": b[changed],
            "before_abstract_state_equal": coverage.state(before_a) == coverage.state(before_b),
            "both_native_paused": before_a.get("native", {}).get("paused") is True and before_b.get("native", {}).get("paused") is True,
            "before_native_fresh": before_a.get("native"), "before_native_hints": before_b.get("native"),
            "scope": "Observed matched-seed choice difference; state/timing differences remain explicit, no causal effect size."}


def _path(root: Path, relative: str) -> Path:
    path = root / relative
    if not path.resolve().is_relative_to(root.resolve()) or path.is_symlink():
        raise ValueError("Retained evidence path escapes its experiment")
    return path


def _load(path: Path, limit: int = 32 * 1024 * 1024):
    with path.open("rb") as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("Evidence exceeds its fixed record bound")
    return json.loads(raw, parse_constant=lambda value: (_ for _ in ()).throw(ValueError("Nonfinite JSON constant")))


def _source_guard(source: str, tree: str, project: Path | None = None, snapshot: dict | None = None) -> None:
    if runner.git("rev-parse", "HEAD") != source or runner.git("rev-parse", "HEAD^{tree}") != tree:
        raise CustodyError("Repository source identity changed")
    if runner.git("status", "--porcelain", "--untracked-files=all"):
        raise CustodyError("Memory qualification requires clean committed source")
    if project is not None:
        _stage_guard(project, snapshot)


def _stage_guard(project: Path, snapshot: dict) -> None:
    try:
        campaign_queue.check_stage(project, snapshot)
    except (OSError, ValueError) as error:
        raise CustodyError("Immutable project input: " + str(error)) from error


def _checked_process(target: Path) -> dict:
    process = _load(target / "process.json")
    if (not isinstance(process, dict) or runner.sha_file(target / "campaign.log") != process.get("log_sha256")
            or not coverage.number(process.get("elapsed_seconds")) or process["elapsed_seconds"] < 0):
        raise ValueError("Attempt process/log custody or recorded cost changed")
    return process


def _watch_output(out: Path, cancel: Path, finished: threading.Event) -> None:
    while not finished.wait(0.5):
        try:
            total = 0
            for path in out.rglob("*"):
                try:
                    if path.is_file():
                        total += path.stat().st_size
                except FileNotFoundError:
                    pass
            if total <= OUTPUT_BYTES:
                continue
            cause = {"status": "aggregate_output_limit", "observed_bytes": total, "limit_bytes": OUTPUT_BYTES}
        except OSError as error:
            cause = {"status": "output_monitor_failure", "error": str(error)}
        try:
            with cancel.open("x", encoding="utf-8") as stream:
                json.dump(cause, stream)
        except OSError:
            pass
        return


def _room(deadline: float, seconds: int, cancel: Path) -> None:
    if cancel.exists():
        raise RuntimeError("Experiment cancellation requested")
    if time.monotonic() + seconds + 10 > deadline:
        raise RuntimeError("Aggregate wall bound leaves no complete next-process slot")


def _validate_launch(tape: dict, launch: dict, provenance: dict, fixture: dict | None = None) -> None:
    header = tape["header"]
    expected = {"fixture_id": "construction", "policy": launch["policy"], "seed": launch["seed"],
                "budget": 64, "pacing_ms": 0, "reuse_memory_requested": launch["reuse_memory"],
                "evidence_kind": "headless_godot", "replay": False, "reproduction_fixture": False}
    if header.get("provenance") != provenance or any(header.get(key) != value for key, value in expected.items()):
        raise ValueError("Actual tape differs from the fixed launch and exact source/runtime")
    if fixture is not None and header.get("fixture_state") == "installed" and any(header.get(key) != fixture.get(key) for key in
                                   ("fixture_id", "fixture_version", "fixture_sha256", "initial_scene_identity")):
        raise ValueError("Measured initial authored fixture differs from cultivation")


def memory_integrity(tape: dict, arm: str, imported_observations: int, actual_observations: int | None) -> bool:
    policy = tape.get("policy_summary", {})
    proposed = 4 if arm == "explicit_prefix" else 0
    expected_observations = imported_observations + len(tape["steps"])
    return (policy.get("retained_prefix_actions_proposed") == proposed
            and policy.get("retained_prefix_actions_queued") == proposed
            and policy.get("memory", {}).get("total_observed") == expected_observations
            and actual_observations == expected_observations
            and (proposed == 0 or prefix_proof(tape)["valid"]))


def _episode(out: Path, case: dict, project: Path, snapshot: dict, provenance: dict,
             godot: Path, corpus: dict | None, deadline: float, fixture: dict | None = None) -> tuple[dict, dict | None]:
    cancel = out / "cancel-requested.json"
    _room(deadline, GAME_SECONDS, cancel)
    _source_guard(provenance["source_commit"], provenance["source_tree"], project, snapshot)
    target = out / case["case_id"]
    target.mkdir()
    launch = case["launch"]
    runner.write_json(target / "attempt.json", {"schema": SCHEMA, **case, "status": "running",
                                                "fresh_disposable_profile": True, "physical_resume": False})
    env = runner.make_profile(target / "profile", launch, provenance, corpus=corpus)
    command = [str(godot), "--headless", "--path", str(project), "--script", "res://goblin/run_campaign.gd"]
    process = runner.execute(command, env, target / "campaign.log", GAME_SECONDS,
                             memory_limit_mib=MEMORY_MIB, cancel_path=cancel)
    runner.write_json(target / "process.json", process)
    result = {"schema": SCHEMA, **case, "process": process, "status": process["status"],
              "fresh_disposable_profile": True, "physical_resume": False,
              "profile_marker_sha256": runner.sha_file(target / "profile/goblin-profile.json"),
              "staged_corpus_sha256": runner.sha_file(target / "profile/goblin-corpus.json") if corpus is not None else None}
    tape = None
    try:
        tape, path = runner.read_transcript(target / "profile")
        if tape is not None:
            result.update(transcript=path.relative_to(out).as_posix(), transcript_sha256=runner.sha_file(path),
                          summary=tape.get("summary", {}))
            _validate_launch(tape, launch, provenance, fixture)
            checked = reader.verify(tape)
            result["independent_readback"] = checked
            runner.write_json(target / "independent-readback.json", checked)
            if checked["valid"]:
                result["coverage"] = coverage.coverage(tape)
                runner.write_json(target / "coverage.json", result["coverage"])
            memory_paths = list((target / "profile").rglob("goblin/corpus.json"))
            if len(memory_paths) == 1:
                actual_memory = corpus_io.load_corpus(memory_paths[0])
                result.update(output_corpus=memory_paths[0].relative_to(out).as_posix(),
                              output_corpus_sha256=runner.sha_file(memory_paths[0]),
                              actual_memory_total_observed=actual_memory["total_observed"])
        elif result["status"] == "pass":
            result["status"] = "missing_transcript"
    except (OSError, ValueError, TypeError, KeyError, AttributeError, OverflowError) as error:
        result["evidence_error"] = type(error).__name__ + ": " + str(error)[:1000]
        if result["status"] == "pass":
            result["status"] = "evidence_failure"
    marker = owned_process.read_log_prefix(target / "campaign.log").splitlines().count("GOBLIN_CAMPAIGN_COMPLETE") == 1
    result["completion_marker"] = marker
    if result["status"] == "pass":
        result["status"] = campaign_queue._terminal({"budget": 64}, process, tape,
                                                     result.get("independent_readback"), result.get("coverage"), marker)
    if tape is not None and result.get("independent_readback", {}).get("valid"):
        memory_base = corpus["total_observed"] if corpus is not None else 0
        result["memory_integrity"] = memory_integrity(tape, case["arm"], memory_base,
                                                      result.get("actual_memory_total_observed"))
        if not result["memory_integrity"] and result["status"] == "pass":
            result["status"] = "experiment_integrity_failure"
    runner.write_json(target / "result.json", result)
    _source_guard(provenance["source_commit"], provenance["source_tree"], project, snapshot)
    return result, tape


def _eligible(result: dict) -> bool:
    cov = result.get("coverage", {})
    return (result.get("status") == "pass" and result.get("memory_integrity") is True
            and cov.get("recorded_coverage_present") is True and not cov.get("recorded_count_mismatches")
            and not cov.get("recorded_dimension_mismatches"))


def source_archive_record(out: Path, snapshot: dict) -> dict:
    """Check exact retained source members without extracting executable files."""
    suffixes = {".gd", ".gdshader", ".tscn", ".tres", ".godot", ".json", ".gdextension"}
    expected = {name: digest for name, digest in snapshot["files"].items() if Path(name).suffix in suffixes}
    archive_path = out / "executed-game-source.zip"
    with zipfile.ZipFile(archive_path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(expected):
            raise ValueError("Executed-source archive membership differs from the source snapshot")
        if sum(info.file_size for info in archive.infolist()) > 512 * 1024 * 1024:
            raise ValueError("Executed-source archive exceeds its bounded source payload")
        for name, digest in expected.items():
            fingerprint = hashlib.sha256()
            with archive.open(name) as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    fingerprint.update(block)
            if fingerprint.hexdigest() != digest:
                raise ValueError("Executed-source archive member changed: " + name)
    return {"path": "executed-game-source.zip", "sha256": runner.sha_file(archive_path), "members": expected,
            "scope": "Exact executed scripts/scenes/configuration; native binaries remain pinned by runtime provenance"}


def comparison_report(ledger: dict, training: dict | None, results: list[dict], tapes: dict) -> dict:
    """Pure aggregation: missing arms remain unknown, failed observations retained."""
    train_keys = (training or {}).get("coverage", {}).get("keys", {})
    by_id = {result["case_id"]: result for result in results}
    rows = []
    for item in ledger.get("measured_plan", []):
        result = by_id.get(item["case_id"])
        tape = tapes.get(item["case_id"])
        cov = (result or {}).get("coverage", {})
        valid = bool(result and _eligible(result))
        policy = (tape or {}).get("policy_summary", {})
        rows.append({**item, "status": (result or {}).get("status", "not_attempted"),
                     "termination": (result or {}).get("summary", {}).get("termination"),
                     "coverage_valid_and_budget_complete": valid,
                     "counts": {key: cov.get(key) for key in ("attempted_records", "admitted_observed_actions",
                         "completed_admitted_actions", "partial_admitted_actions", "refused_actions")},
                     "coverage_unique": cov.get("unique"),
                     "new_keys_beyond_training": {dimension: len(set(cov["keys"][dimension]) - set(train_keys[dimension]))
                                                  for dimension in coverage.DIMENSIONS} if valid and training and _eligible(training) else None,
                     "retained_prefix_actions_proposed": policy.get("retained_prefix_actions_proposed"),
                     "retained_prefix_actions_queued": policy.get("retained_prefix_actions_queued"),
                     "actual_prefix_proof": prefix_proof(tape) if tape and item["arm"] == "explicit_prefix" else None,
                     "memory": {key: value for key, value in policy.get("memory", {}).items() if key != "observations"},
                     "observed_fixture_ids": sorted({state.get("fixture_id", "unknown") for step in (tape or {}).get("steps", [])
                                                     for state in (step["before"], step["after"])}) if tape else None,
                     "world_replacements": [{"step": step["index"], "action": step["action"], "status": step["status"]}
                                            for step in (tape or {}).get("steps", []) if step["action"]["id"] in
                                            ("replace_fixture", "reset_fixture", "restore_start")] if tape else None,
                     "process_seconds": (result or {}).get("process", {}).get("elapsed_seconds"),
                     "sampled_peak_tree_rss_bytes": (result or {}).get("process", {}).get("peak_tree_rss_bytes"),
                     "transcript": (result or {}).get("transcript"), "transcript_sha256": (result or {}).get("transcript_sha256")})
    changes, pairs = [], []
    for seed in ledger.get("selection", {}).get("seeds", []):
        by_arm = {row["arm"]: row for row in rows if row["seed"] == seed}
        a, b = by_arm.get("fresh"), by_arm.get("hints_only")
        changes.append({"seed": seed, **choice_change(tapes.get(a["case_id"]) if a else None,
                                                    tapes.get(b["case_id"]) if b else None)})
        for candidate, baseline in (("hints_only", "fresh"), ("explicit_prefix", "hints_only"), ("explicit_prefix", "fresh")):
            a, b = by_arm.get(candidate), by_arm.get(baseline)
            eligible = bool(a and b and a["coverage_valid_and_budget_complete"] and b["coverage_valid_and_budget_complete"])
            pairs.append({"seed": seed, "candidate": candidate, "baseline": baseline, "eligible": eligible,
                          "coverage_differences": {d: a["coverage_unique"][d] - b["coverage_unique"][d] for d in coverage.DIMENSIONS} if eligible else None,
                          "new_beyond_training_differences": {d: a["new_keys_beyond_training"][d] - b["new_keys_beyond_training"][d] for d in coverage.DIMENSIONS}
                          if eligible and a["new_keys_beyond_training"] is not None and b["new_keys_beyond_training"] is not None else None,
                          "completed_actions_difference": a["counts"]["completed_admitted_actions"] - b["counts"]["completed_admitted_actions"] if eligible else None,
                          "process_seconds_difference": a["process_seconds"] - b["process_seconds"] if eligible else None})
    attempts = ([training] if training else []) + results
    return {"schema": SCHEMA, "source_commit": ledger.get("expected_source"), "provenance": ledger.get("provenance"),
            "planned_gameplay_episodes": 7, "retained_gameplay_results": len(attempts),
            "registered_gameplay_slots": len(ledger.get("attempts", [])),
            "not_registered_gameplay_slots": 7 - len(ledger.get("attempts", [])),
            "measured_slots_without_result": 6 - len(results),
            "budget_complete_valid_gameplay_episodes": sum(_eligible(result) for result in attempts),
            "planned_measured_episodes": 6, "retained_measured_results": len(results), "training_episode_budget": 64,
            "training_cost": (training or {}).get("process"), "selection": ledger.get("selection"),
            "cultivation": {"status": (training or {}).get("status", "not_attempted"),
                            "termination": (training or {}).get("summary", {}).get("termination"),
                            "counts": {key: (training or {}).get("coverage", {}).get(key) for key in
                                       ("attempted_records", "admitted_observed_actions", "completed_admitted_actions",
                                        "partial_admitted_actions", "refused_actions")},
                            "coverage_unique": (training or {}).get("coverage", {}).get("unique")},
            "training_prefix_proof": prefix_proof(tapes[CULTIVATION]) if CULTIVATION in tapes else None,
            "frozen_corpus_sha256": ledger.get("frozen_corpus_sha256"), "measured_episodes": rows,
            "hints_only_actual_choice_comparison": changes, "paired_differences": pairs,
            "terminal_inventory": dict(Counter(result.get("status", "unknown") for result in attempts)),
            "process_status_inventory": dict(Counter(result.get("process", {}).get("status", "unavailable") for result in attempts)),
            "tape_termination_inventory": dict(Counter(result.get("summary", {}).get("termination", "unavailable") for result in attempts)),
            "all_observed_gameplay_process_seconds_including_training": sum(result["process"]["elapsed_seconds"] for result in attempts if result.get("process", {}).get("elapsed_seconds") is not None),
            "attempts_missing_process_cost": sum(result.get("process", {}).get("elapsed_seconds") is None for result in attempts),
            "statistical_inference_performed": False, "production_defect_confirmation_performed": False,
            "limits": ["Two seeds and one cultivated corpus: descriptive evidence, no population effect or significance claim.",
                       "Cultivation64 actions and its measured process cost are separate and included in total; no amortized benefit presumed.",
                       "The same whole corpus is imported each time; measured outputs are never fed into later treatments.",
                       "Prefix reuse spends four of64 attempt slots. Its reproduction may be useful without increasing novel coverage.",
                       "Prior-memory-loaded is not import proof: empty hint dictionaries also set it. Actual input custody and counter deltas are checked.",
                       "Imported hints earn no current-episode coverage. New-key counts subtract the actual cultivation keys.",
                       "Initial construction is matched; ordinary later world replacement and asynchronous state may differ.",
                       "Action pipeline costs include evidence checkpoints; this is not engine-only performance measurement.",
                       "Missing/failed treatments stay visible and do not become zero-valued complete pairs.",
                       "Exact retained failures require separate triage; this tool never confirms production gameplay defects."]}


def _collect(out: Path, ledger: dict) -> tuple[dict | None, list[dict], dict]:
    """Read-only custody check; recompute native readback and coverage from raw tapes."""
    if ledger.get("reader_sha256") != tool_hashes():
        raise ValueError("Use the exact recorded reader source to analyze this experiment")
    provenance = ledger.get("provenance")
    if provenance is None:
        return None, [], {}
    if (not replay_identity.valid(provenance) or provenance.get("source_dirty") is not False or
            provenance.get("source_commit") != ledger["expected_source"] or provenance.get("source_tree") != ledger["expected_tree"]):
        raise ValueError("Experiment provenance differs from its fixed source")
    if _load(out / "provenance.json") != provenance:
        raise ValueError("Retained provenance record changed")
    snapshot = _load(out / "source-snapshot.json")
    if reader.digest(snapshot["files"]) != provenance["project_files_sha256"]:
        raise ValueError("Executed source snapshot identity changed")
    if (out / "project").is_dir():
        campaign_queue.check_stage(out / "project", snapshot)
    elif (out / "source-archive.json").is_file():
        if source_archive_record(out, snapshot) != _load(out / "source-archive.json"):
            raise ValueError("Executed-source archive receipt changed")
    else:
        raise ValueError("Executed game source is not retained")
    if ledger.get("import_process"):
        if (_load(out / "import-result.json") != ledger["import_process"] or
                runner.sha_file(out / "import.log") != ledger["import_process"]["log_sha256"]):
            raise ValueError("Retained import custody changed")
    frozen = None
    if ledger.get("frozen_corpus_sha256"):
        if runner.sha_file(out / "frozen-corpus.json") != ledger["frozen_corpus_sha256"]:
            raise ValueError("Frozen cultivation corpus changed")
        frozen = corpus_io.load_corpus(out / "frozen-corpus.json")
    training, results, tapes = None, [], {}
    expected_cases = [{"case_id": CULTIVATION, "arm": "fresh", "launch": config("CONTROL", 13, "fresh")},
                      *[{**item, "launch": config("COVERAGE_HUNTER", item["seed"], item["arm"])}
                        for item in ledger.get("measured_plan", [])]]
    attempts = ledger.get("attempts", [])
    if len(attempts) > 7 or len(attempts) > len(expected_cases):
        raise ValueError("Experiment exceeds the fixed seven attempts")
    for index, attempt in enumerate(attempts):
        if any(attempt.get(key) != value for key, value in expected_cases[index].items()):
            raise ValueError("Actual attempt differs from the fixed experiment order")
        target = _path(out, attempt["case_id"])
        path = target / "result.json"
        if not path.is_file() or not attempt.get("result_sha256"):
            result = {**attempt, "status": "incomplete_attempt", "process": {}}
            if (target / "process.json").is_file():
                result.update(process=_checked_process(target),
                              process_receipt_sha256=runner.sha_file(target / "process.json"),
                              process_receipt_scope="Checked raw receipt and log; final result was not sealed, no gameplay success inferred")
        else:
            if runner.sha_file(path) != attempt["result_sha256"]:
                raise ValueError("Retained attempt result changed")
            result = _load(path)
            if any(result.get(key) != attempt[key] for key in ("case_id", "arm", "launch")):
                raise ValueError("Retained attempt launch changed")
            profile = target / "profile"
            marker = _load(profile / "goblin-profile.json")
            if (runner.sha_file(profile / "goblin-profile.json") != result["profile_marker_sha256"] or
                    marker != {"schema": runner.PROFILE_SCHEMA, "launch": attempt["launch"], "provenance": provenance}):
                raise ValueError("Disposable profile marker changed")
            staged = profile / "goblin-corpus.json"
            if attempt["arm"] == "fresh":
                if staged.exists() or result.get("staged_corpus_sha256") is not None:
                    raise ValueError("Fresh treatment contains an imported corpus")
            elif (frozen is None or not staged.is_file() or runner.sha_file(staged) != result["staged_corpus_sha256"]
                  or corpus_io._canonical(corpus_io.load_corpus(staged)) != corpus_io._canonical(frozen)):
                raise ValueError("Imported treatment differs from the frozen cultivation corpus")
            process = _checked_process(target)
            if result.get("process") != process:
                raise ValueError("Attempt process/log custody changed")
            actual_marker = owned_process.read_log_prefix(target / "campaign.log").splitlines().count("GOBLIN_CAMPAIGN_COMPLETE") == 1
            if result.get("completion_marker") != actual_marker:
                raise ValueError("Actual completion marker differs")
            if result.get("transcript"):
                raw = _path(out, result["transcript"])
                if not raw.resolve().is_relative_to(profile.resolve()) or runner.sha_file(raw) != result["transcript_sha256"]:
                    raise ValueError("Raw tape custody changed")
                tape = reader.load(raw)
                _validate_launch(tape, attempt["launch"], provenance, tapes.get(CULTIVATION, {}).get("header"))
                checked = reader.verify(tape)
                if checked != result.get("independent_readback"):
                    raise ValueError("Independent readback result changed")
                if checked["valid"]:
                    actual = coverage.coverage(tape)
                    if actual != result.get("coverage") or tape["summary"] != result.get("summary"):
                        raise ValueError("Coverage/summary differs from the actual tape")
                    tapes[attempt["case_id"]] = tape
            if result.get("output_corpus"):
                path = _path(out, result["output_corpus"])
                if not path.resolve().is_relative_to(profile.resolve()) or runner.sha_file(path) != result["output_corpus_sha256"]:
                    raise ValueError("Actual output memory custody changed")
                memory = corpus_io.load_corpus(path)
                if memory["total_observed"] != result.get("actual_memory_total_observed"):
                    raise ValueError("Actual memory counter changed")
                if attempt["case_id"] == CULTIVATION and frozen is not None and runner.sha_file(path) != ledger["frozen_corpus_sha256"]:
                    raise ValueError("Frozen corpus is not the actual unmodified cultivation output")
            if attempt["case_id"] in tapes:
                tape = tapes[attempt["case_id"]]
                imported = frozen["total_observed"] if attempt["arm"] != "fresh" and frozen else 0
                actual_integrity = memory_integrity(tape, attempt["arm"], imported, result.get("actual_memory_total_observed"))
                if actual_integrity != result.get("memory_integrity"):
                    raise ValueError("Memory accounting differs from the actual tape and output corpus")
                terminal = campaign_queue._terminal({"budget": 64}, process, tape, result["independent_readback"],
                                                     result["coverage"], actual_marker)
                if terminal == "pass" and not actual_integrity:
                    terminal = "experiment_integrity_failure"
                if terminal != result["status"]:
                    raise ValueError("Episode classification differs from independently rechecked evidence")
        if attempt["case_id"] == CULTIVATION:
            training = result
        else:
            results.append(result)
    if frozen is not None:
        selection = selected_prefix(frozen, context_for(tapes[CULTIVATION]))
        if selection != ledger.get("selection") or measured_plan(selection) != ledger.get("measured_plan"):
            raise ValueError("Measured seed/order selection differs from the actual retained prefix")
    return training, results, tapes


def analyze(output: Path) -> dict:
    """Recheck evidence without mutating it or launching any process."""
    out = output.resolve(strict=True)
    if not (out / "experiment.json").is_file():
        report = comparison_report({"attempts": []}, None, [], {})
        report.update(status="incomplete_or_failed", experiment_status="worker_ended_before_ledger",
                      bounds=bounds(), supervisor=_load(out / "supervisor.json") if (out / "supervisor.json").is_file() else None,
                      evidence_kind="no_validated_gameplay_evidence", retained_attempts=0,
                      planned_slots_without_validated_result=7, reader_sha256=tool_hashes())
        report["operator_cancelled"] = bool((report.get("supervisor") or {}).get("interrupted"))
        return report
    ledger = _load(out / "experiment.json")
    training, results, tapes = _collect(out, ledger)
    report = comparison_report(ledger, training, results, tapes)
    supervisor = _load(out / "supervisor.json") if (out / "supervisor.json").is_file() else None
    complete = (ledger.get("status") == "complete" and training is not None and _eligible(training)
                and len(results) == 6 and all(_eligible(result) for result in results)
                and supervisor is not None and supervisor.get("status") == "pass" and not supervisor.get("surviving_owned_pids"))
    report.update(status="pass" if complete else "incomplete_or_failed", experiment_status=ledger.get("status"),
                  bounds=bounds(), supervisor=supervisor, import_process=ledger.get("import_process"),
                  source_archive=_load(out / "source-archive.json") if (out / "source-archive.json").is_file() else None,
                  reader_sha256=ledger["reader_sha256"], error=ledger.get("error"),
                  failure_kind=ledger.get("failure_kind"),
                  source_custody_failure=ledger.get("failure_kind") == "source_custody_failure",
                  operator_cancelled=bool((supervisor or {}).get("interrupted")),
                  retained_attempts=len(ledger.get("attempts", [])), evidence_kind="actual_headless_godot_campaigns")
    return report


def _worker(godot: Path, out: Path) -> int:
    owner = _load(out / "experiment-owner.json")
    if (not isinstance(owner.get("token"), str) or len(owner["token"]) != 32 or
            owner["token"] != os.environ.get("GOBLIN_MEMORY_WORKER_TOKEN") or owner.get("reader_sha256") != tool_hashes()):
        raise ValueError("Worker requires its own bounded supervisor and exact source readers")
    deadline = float(os.environ["GOBLIN_MEMORY_DEADLINE"])
    cancel = out / "cancel-requested.json"
    ledger = {"schema": SCHEMA, "status": "preflight", "expected_source": owner["expected_source"],
              "expected_tree": owner["expected_tree"], "reader_sha256": owner["reader_sha256"], "bounds": bounds(), "attempts": []}
    runner.write_json(out / "experiment.json", ledger)
    try:
        _source_guard(owner["expected_source"], owner["expected_tree"])
        if runner.sha_file(godot) != ENGINE_SHA256:
            raise CustodyError("Pinned Linux Godot bytes differ")
        _room(deadline, 15, cancel)
        try:
            provenance = runner.runtime_identity(godot)
        except ValueError as error:
            raise CustodyError("Runtime/source admission: " + str(error)) from error
        if provenance["platform"] != "linux":
            raise CustodyError("This registered memory experiment is the Linux qualification lane")
        project = out / "project"
        try:
            snapshot = runner.stage_project(project)
        except ValueError as error:
            raise CustodyError("Source snapshot admission: " + str(error)) from error
        provenance["project_files_sha256"] = snapshot["project_files_sha256"]
        provenance["replay_identity"] = replay_identity.build(provenance, project, snapshot["files"])
        ledger["provenance"] = provenance
        runner.write_json(out / "source-snapshot.json", snapshot)
        runner.write_json(out / "provenance.json", provenance)
        _room(deadline, IMPORT_SECONDS, cancel)
        env = runner.make_profile(out / "import-profile", config("CONTROL", 13, "fresh"), provenance)
        imported = runner.execute([str(godot), "--headless", "--path", str(project), "--editor", "--quit"], env,
                                  out / "import.log", IMPORT_SECONDS, memory_limit_mib=MEMORY_MIB, cancel_path=cancel)
        ledger["import_process"] = imported
        runner.write_json(out / "import-result.json", imported)
        if imported["status"] != "pass":
            raise RuntimeError("Isolated source import failed")
        _stage_guard(project, snapshot)

        def attempt(case, corpus=None, fixture=None):
            # Register before dispatch so a killed worker still has a durable
            # missing/incomplete attempt, never a silently absent success.
            ledger["attempts"].append(case.copy())
            runner.write_json(out / "experiment.json", ledger)
            result, tape = _episode(out, case, project, snapshot, provenance, godot, corpus, deadline, fixture)
            ledger["attempts"][-1].update(status=result["status"], result_sha256=runner.sha_file(out / case["case_id"] / "result.json"))
            runner.write_json(out / "experiment.json", ledger)
            print(json.dumps({"case_id": case["case_id"], "status": result["status"],
                              "completed_admitted_actions": result.get("coverage", {}).get("completed_admitted_actions")}), flush=True)
            return result, tape

        training, train_tape = attempt({"case_id": CULTIVATION, "arm": "fresh", "launch": config("CONTROL", 13, "fresh")})
        if not _eligible(training) or train_tape is None or not prefix_proof(train_tape)["valid"]:
            raise RuntimeError("Cultivation did not establish the actual admitted four-action native edit prefix")
        memory_path = _path(out, training["output_corpus"])
        corpus = corpus_io.load_corpus(memory_path)
        if not any(corpus["search_hints"].get(dimension) for dimension in ("action", "state_action", "action_transition", "variants")):
            raise ValueError("Cultivation has no nonempty actual prior counts")
        selection = selected_prefix(corpus, context_for(train_tape))
        shutil.copyfile(memory_path, out / "frozen-corpus.json")
        ledger.update(selection=selection, frozen_corpus_sha256=runner.sha_file(out / "frozen-corpus.json"),
                      measured_plan=measured_plan(selection), status="running_measured_cases")
        runner.write_json(out / "experiment.json", ledger)
        results = []
        for item in ledger["measured_plan"]:
            if runner.sha_file(out / "frozen-corpus.json") != ledger["frozen_corpus_sha256"]:
                raise CustodyError("Frozen actual corpus changed")
            result, _ = attempt({**item, "launch": config("COVERAGE_HUNTER", item["seed"], item["arm"])},
                                None if item["arm"] == "fresh" else corpus, train_tape["header"])
            results.append(result)
        _source_guard(owner["expected_source"], owner["expected_tree"], project, snapshot)
        ledger["status"] = "complete" if all(_eligible(result) for result in results) else "complete_with_retained_failures"
    except CustodyError as error:
        ledger.update(status="incomplete_retained", failure_kind="source_custody_failure",
                      error=type(error).__name__ + ": " + str(error)[:2000])
    except (OSError, ValueError, RuntimeError, KeyError, TypeError, subprocess.SubprocessError) as error:
        ledger.update(status="incomplete_retained", error=type(error).__name__ + ": " + str(error)[:2000])
    finally:
        runner.write_json(out / "experiment.json", ledger)
    print("GOBLIN_MEMORY_EXPERIMENT " + json.dumps({"status": ledger["status"], "retained_attempts": len(ledger["attempts"])}), flush=True)
    return 0 if ledger["status"] == "complete" else 2


def qualify(godot: Path, output: Path, *, source_project: Path | None = None) -> dict:
    """Run the fixed plan inside one independently bounded owned worker tree.

    A fresh project snapshot/import is intentional. Passing a different project
    is rejected; generated caches are not implicitly accepted as qualification.
    """
    if source_project is not None and source_project.resolve() != (runner.ROOT / "godot").resolve():
        raise ValueError("Memory qualification snapshots the current repository game; external project reuse is unsupported")
    godot = godot.resolve(strict=True)
    if runner.sha_file(godot) != ENGINE_SHA256:
        raise ValueError("Pinned Linux Godot executable required")
    source, tree = runner.git("rev-parse", "HEAD"), runner.git("rev-parse", "HEAD^{tree}")
    _source_guard(source, tree)
    out = output.resolve()
    if out.is_relative_to((runner.ROOT / "godot").resolve()):
        raise ValueError("Disposable experiment output must be outside game source")
    out.mkdir(parents=True, exist_ok=False)
    token = uuid.uuid4().hex
    runner.write_json(out / "experiment-owner.json", {"schema": SCHEMA, "token": token, "reader_sha256": tool_hashes(),
        "expected_source": source, "expected_tree": tree, "disposable": True, "purpose": "fixed seven-campaign memory experiment"})
    cancel = out / "cancel-requested.json"
    finished = threading.Event()
    watcher = threading.Thread(target=_watch_output, args=(out, cancel, finished), daemon=True)
    watcher.start()
    try:
        env = dict(os.environ, GOBLIN_MEMORY_WORKER_TOKEN=token, GOBLIN_MEMORY_DEADLINE=str(time.monotonic() + TOTAL_SECONDS))
        process = owned_process.execute([sys.executable, str(Path(__file__).resolve()), "--worker", "--godot", str(godot), "--out", str(out)],
                                        env, out / "experiment-driver.log", TOTAL_SECONDS, cwd=runner.ROOT,
                                        memory_limit_mib=MEMORY_MIB, cancel_path=cancel)
        runner.write_json(out / "supervisor.json", process)
    finally:
        finished.set()
        watcher.join(timeout=1)
    try:
        _source_guard(source, tree)
        if (out / "project").is_dir() and not process.get("surviving_owned_pids"):
            snapshot = _load(out / "source-snapshot.json") if (out / "source-snapshot.json").is_file() else None
            if snapshot is not None:
                campaign_queue.check_stage(out / "project", snapshot)
            runner.retain_source_and_remove_project(out, out / "project")
            if snapshot is not None:
                runner.write_json(out / "source-archive.json", source_archive_record(out, snapshot))
        report = analyze(out)
    except (OSError, ValueError, KeyError, TypeError, AttributeError, zipfile.BadZipFile) as error:
        report = {"schema": SCHEMA, "status": "evidence_failure", "error": type(error).__name__ + ": " + str(error),
                  "source_commit": source, "bounds": bounds(), "supervisor": process,
                  "failure_kind": "source_custody_failure", "source_custody_failure": True,
                  "operator_cancelled": bool(process.get("interrupted")),
                  "planned_gameplay_episodes": 7, "planned_measured_episodes": 6,
                  "planned_slots_without_validated_result": 7, "completed_admitted_actions": None,
                  "scope": "All raw attempts retained; no missing result is counted as successful gameplay"}
    runner.write_json(out / "report.json", report)
    return report


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--analyze", action="store_true", help="Read-only verification; print report without launching any process")
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    if args.analyze:
        report = analyze(args.out)
    elif args.godot is None:
        parser.error("--godot is required for the fixed experiment")
    elif args.worker:
        return _worker(args.godot.resolve(strict=True), args.out.resolve(strict=True))
    else:
        report = qualify(args.godot, args.out)
    print(json.dumps(report, sort_keys=True), flush=True)
    return 0 if report["status"] == "pass" else 2


if __name__ == "__main__":
    raise SystemExit(main())
