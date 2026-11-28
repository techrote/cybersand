#!/usr/bin/env python3
"""Run or resume a finite queue of fresh disposable real-game goblin episodes.

Only committed scenario/personality IDs and fixed Godot entrypoints are used.
The persisted queue resumes experiments, never an asynchronous physics state.
Every attempt has an immutable directory, including interrupted processes.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import random
import shutil
import sys
import time
import uuid

import psutil

import campaign_evidence
import replay_identity
from owned_process import read_log_prefix
from corpus_io import load_corpus
from run_goblin import (ROOT, COMPLETION_MARKERS, execute, git, make_profile, read_transcript,
                        runtime_identity, sha_file, stage_project, write_json)
from verify_transcript import digest, load, verify
from vocabulary import FIXTURES, POLICIES

SCHEMA = "cybersand-goblin-experiment-queue-v1"
MODES = ("CONTROL", "WANDERER", "BUILDER", "TINKERER", "CURIOSITY", "RANDOM", "STATEFUL", "NOVELTY", "COVERAGE_HUNTER")
SEEDS = (13, 605, 1701)
MATCHED_FIXTURES = ("construction", "liquid_channel", "actor_workshop", "history_edges")
PLAN_KINDS = ("smoke", "matched", "long", "personalities", "scenarios", "full")


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def episodes_for(kind: str) -> list[dict]:
    if kind not in PLAN_KINDS:
        raise ValueError("Unknown committed campaign plan")
    rows = []
    def add(cohort, fixture, policy, seed, budget):
        rows.append({"id": f"{cohort}-{len(rows):04d}-{policy.lower()}-{fixture}-s{seed}-n{budget}",
                     "cohort": cohort, "fixture": fixture, "policy": policy, "seed": seed, "budget": budget,
                     "timeout_seconds": int(min(900, max(150, budget * 1.2))) + 60})
    if kind == "smoke":
        add("smoke", "construction", "CONTROL", 13, 16)
        add("smoke", "alchemy", "COVERAGE_HUNTER", 13, 16)
    if kind in ("matched", "full"):
        for fixture in MATCHED_FIXTURES:
            for seed in SEEDS:
                for policy in MODES:
                    add("matched", fixture, policy, seed, 64)
    if kind in ("long", "full"):
        for budget in (128, 256, 512, 1024):
            for policy in ("RANDOM", "COVERAGE_HUNTER"):
                add("long", "construction", policy, 1701, budget)
    if kind in ("personalities", "full"):
        for policy in POLICIES:
            add("personality", "mixed_stress", policy, 605, 64)
    if kind in ("scenarios", "full"):
        for fixture in FIXTURES:
            add("scenario", fixture, "COVERAGE_HUNTER", 2309, 64)
    # Randomized but fixed ordering reduces warm-host/order confounding; all
    # matched cases still have the same fixture, seed, budget and process limits.
    random.Random(17713).shuffle(rows)
    return rows


def acquire(out: Path, resume: bool) -> Path:
    lock = out / "queue.lock"
    if lock.exists():
        record = json.loads(lock.read_text())
        active = False
        try:
            process = psutil.Process(int(record["pid"]))
            active = process.create_time() == record.get("created")
        except (psutil.Error, ValueError, TypeError, KeyError):
            pass
        if active or not resume:
            raise ValueError("Queue has an active/uncleared owner; use --resume only after it exits")
        lock.rename(out / ("abandoned-lock-" + uuid.uuid4().hex + ".json"))
    with lock.open("x", encoding="utf-8") as stream:
        json.dump({"pid": os.getpid(), "created": psutil.Process().create_time(), "utc": utc()}, stream)
    return lock


def check_stage(project: Path, snapshot: dict) -> None:
    # Caches may be generated. Only CRLF-to-LF is accepted in the four declared
    # descriptors; no arbitrary editor rewrite bypasses exact input custody.
    for name, expected in snapshot["files"].items():
        path = project / name
        if name in replay_identity.IMPORT_DESCRIPTORS:
            canonical_expected = snapshot.get("normalized_import_descriptors", {}).get(name)
            if canonical_expected is None or not path.is_file() or __import__("hashlib").sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest() != canonical_expected:
                raise ValueError("Immutable normalized import descriptor changed: " + name)
            continue
        if not path.is_file() or sha_file(path) != expected:
            raise ValueError("Immutable staged source changed: " + name)


def _terminal(episode: dict, process: dict, tape: dict | None, checked: dict | None, cov: dict | None,
              completion: bool) -> str:
    if process["status"] != "pass":
        return process["status"]
    if not completion:
        return "incomplete_test"
    if tape is None:
        return "missing_transcript"
    if not checked or not checked["valid"]:
        return "evidence_failure"
    if cov and (cov["recorded_count_mismatches"] or cov["recorded_dimension_mismatches"]):
        return "coverage_mismatch"
    summary = tape["summary"]
    if summary.get("failures"):
        return "candidate_anomaly"
    if summary.get("termination") != "budget_complete" or summary.get("attempted_actions") != episode["budget"]:
        return "incomplete_evidence"
    return "pass"


def run_episode(episode: dict, target: Path, project: Path, provenance: dict, godot: Path, memory: int,
                cancel: Path, corpus: dict | None = None) -> dict:
    target.mkdir(parents=True, exist_ok=False)
    launch = {"fixture_id": episode["fixture"], "policy": episode["policy"], "seed": episode["seed"],
              "budget": episode["budget"], "pacing_ms": 0, "evidence_kind": "headless_godot"}
    profile = target / "profile"
    env = make_profile(profile, launch, provenance, corpus=corpus)
    write_json(target / "attempt.json", {"episode": episode, "source_commit": provenance["source_commit"],
                                       "status": "running", "started_utc": utc(), "physical_resume": False})
    command = [str(godot), "--headless", "--path", str(project), "--script", "res://goblin/run_campaign.gd"]
    process = execute(command, env, target / "campaign.log", episode["timeout_seconds"],
                      memory_limit_mib=memory, cancel_path=cancel)
    write_json(target / "process.json", process)
    tape, tape_path, checked, cov = None, None, None, None
    result = {"episode": episode, "process": process, "completed_utc": utc(), "status": "unreported",
              "classification": "unresolved_observation", "fresh_disposable_profile": True, "physical_resume": False}
    try:
        tape, tape_path = read_transcript(profile)
        if tape is not None:
            result["transcript"] = tape_path.relative_to(target).as_posix()
            result["transcript_sha256"] = sha_file(tape_path)
            checked = verify(tape)
            write_json(target / "independent-readback.json", checked)
            result["readback_sha256"] = sha_file(target / "independent-readback.json")
            result["summary"] = tape.get("summary", {})
            if checked["valid"]:
                cov = campaign_evidence.coverage(tape)
                write_json(target / "coverage.json", cov)
                result["coverage_sha256"] = sha_file(target / "coverage.json")
            result["pending_action_retained"] = "pending_action" in tape
    except (OSError, ValueError, KeyError, TypeError, AttributeError, OverflowError) as error:
        # Malformed or truncated evidence is a retained attempted process, not a
        # reason to abandon the rest of a finite experiment queue.
        result["evidence_error"] = type(error).__name__ + ": " + str(error)[:1000]
        candidates = list(profile.rglob("goblin/transcript.json"))
        result["retained_raw_transcripts"] = [{"path": p.relative_to(target).as_posix(), "bytes": p.stat().st_size,
                                               "sha256": sha_file(p)} for p in candidates[:4] if p.is_file()]
    lines = read_log_prefix(target / "campaign.log").splitlines()
    completion = process["status"] != "output_limit" and lines.count(COMPLETION_MARKERS["campaign"]) == 1
    result["status"] = _terminal(episode, process, tape, checked, cov, completion)
    if result.get("evidence_error") and process["status"] == "pass":
        result["status"] = "evidence_failure"
    result["completion_marker"] = completion
    if result["status"] == "pass":
        result["classification"] = "legal_unusual_gameplay"
    elif result["status"] in ("execution_error", "output_limit", "resource_limit"):
        result["classification"] = "infrastructure_failure"
    result["scope"] = "Observed experiment outcome; production defect confirmation requires independent reproduction and examination"
    write_json(target / "result.json", result)
    return result


def collect_attempts(out: Path, queue: dict, recheck: bool = False, *, latest_only: bool = False) -> list[dict]:
    """Custody-checked attempts; missing measurements stay absent, never zero."""
    evidence = []
    for row in queue["episodes"]:
        for attempt in (row["attempts"][-1:] if latest_only else row["attempts"]):
            target = out / row["episode"]["id"] / f"attempt-{attempt['number']:02d}"
            if not target.resolve().is_relative_to(out.resolve()):
                raise ValueError("Retained attempt path is outside its queue")
            result_path = target / "result.json"
            if not result_path.is_file():
                evidence.append({"episode": row["episode"], "attempt_number": attempt["number"], "status": attempt["status"], "classification": "infrastructure_failure"})
                continue
            if attempt.get("result_sha256") != sha_file(result_path):
                raise ValueError("Retained attempt receipt changed")
            result = json.loads(result_path.read_text())
            if result.get("episode") != row["episode"]:
                raise ValueError("Retained attempt identity differs")
            result["attempt_number"] = attempt["number"]
            if "coverage_sha256" in result:
                path = target / "coverage.json"
                if result["coverage_sha256"] != sha_file(path):
                    raise ValueError("Retained coverage evidence changed")
                result["coverage"] = json.loads(path.read_text())
            if recheck and "transcript" in result:
                transcript = target / result["transcript"]
                if not transcript.resolve().is_relative_to(target.resolve()) or result["transcript_sha256"] != sha_file(transcript):
                    raise ValueError("Retained transcript custody differs")
                try:
                    tape = load(transcript)
                    checked = verify(tape)
                except (ValueError, KeyError, TypeError) as error:
                    if result["status"] == "pass" or not result.get("evidence_error"):
                        raise ValueError("Retained transcript cannot be read") from error
                    tape, checked = None, None
                if checked is not None:
                    if "readback_sha256" in result:
                        prior = target / "independent-readback.json"
                        if sha_file(prior) != result["readback_sha256"] or json.loads(prior.read_text()) != checked:
                            raise ValueError("Retained independent readback differs")
                    if result["status"] == "pass" and not checked["valid"]:
                        raise ValueError("Passing transcript no longer validates")
                    if checked["valid"]:
                        if tape["header"]["provenance"] != queue["plan"]["provenance"]:
                            raise ValueError("Retained transcript source differs")
                        if "coverage" in result and campaign_evidence.coverage(tape) != result["coverage"]:
                            raise ValueError("Independent coverage recomputation differs")
            if recheck:
                process = result.get("process", {})
                if "log_sha256" in process and sha_file(target / "campaign.log") != process["log_sha256"]:
                    raise ValueError("Retained process log custody differs")
                for raw in result.get("retained_raw_transcripts", []):
                    path = target / raw["path"]
                    if not path.resolve().is_relative_to(target.resolve()) or sha_file(path) != raw["sha256"]:
                        raise ValueError("Retained malformed transcript custody differs")
            evidence.append(result)
    return evidence


def collect(out: Path, queue: dict, recheck: bool = False) -> list[dict]:
    """One latest attempted result per independently identified planned episode."""
    return collect_attempts(out, queue, recheck, latest_only=True)


def recover_interrupted(out: Path, queue: dict) -> None:
    """Reconcile a completed receipt if the queue owner died before checkpoint."""
    for row in queue["episodes"]:
        for attempt in row["attempts"]:
            if attempt["status"] != "running":
                continue
            target = out / row["episode"]["id"] / f"attempt-{attempt['number']:02d}"
            receipt = target / "result.json"
            attempt["interruption_observed_utc"] = utc()
            if receipt.is_file():
                result = json.loads(receipt.read_text())
                if result.get("episode") != row["episode"] or result.get("status") in (None, "running", "unreported"):
                    raise ValueError("Interrupted attempt receipt has inconsistent identity")
                attempt.update(status=result["status"], result_sha256=sha_file(receipt), recovered_receipt=True)
            else:
                attempt["status"] = "interrupted"
        if row["status"] == "running":
            row["status"] = row["attempts"][-1]["status"]
    collect_attempts(out, queue, recheck=True)


def report(out: Path, queue: dict, recheck: bool = False) -> dict:
    episodes = collect(out, queue, recheck)
    attempts = collect_attempts(out, queue, recheck)
    result = campaign_evidence.compare(episodes, queue["plan"])
    import paired_comparison
    result["paired_comparison"] = paired_comparison.compare(episodes, queue["plan"], attempts=attempts)
    result["queue_status"] = queue["status"]
    result["retained_attempts"] = sum(len(row["attempts"]) for row in queue["episodes"])
    result["attempt_statuses"] = dict(Counter(attempt["status"] for row in queue["episodes"] for attempt in row["attempts"]))
    result["predecessor_incomplete_runs"] = "See committed predecessor-recovery.json; no old process relabeled as a successor pass"
    write_json(out / "comparison.json", result)
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--plan", choices=PLAN_KINDS, default="matched")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--retry-incomplete", action="store_true")
    parser.add_argument("--cancel", action="store_true")
    parser.add_argument("--report-only", action="store_true")
    parser.add_argument("--allow-dirty", action="store_true", help="Exploratory local evidence only; cannot qualify an evaluator")
    parser.add_argument("--memory-limit-mib", type=int, default=3072)
    parser.add_argument("--wall-seconds", type=int, default=7200)
    parser.add_argument("--max-output-mib", type=int, default=4096)
    args = parser.parse_args(argv)
    if not 256 <= args.memory_limit_mib <= 8192 or not 60 <= args.wall_seconds <= 18000 or not 512 <= args.max_output_mib <= 16384:
        parser.error("Queue bounds:256..8192MiB memory,60..18000s wall,512..16384MiB output")
    out = args.out.resolve()
    lock = None
    try:
        if args.cancel or args.report_only:
            queue = json.loads((out / "queue.json").read_text())
            if queue.get("schema") != SCHEMA:
                raise ValueError("Unknown queue; refusing fixed-file mutation")
            if args.cancel:
                write_json(out / "cancel-requested.json", {"requested_utc": utc()})
                return 0
            print(json.dumps(report(out, queue, recheck=True), sort_keys=True))
            return 0
        if args.godot is None:
            parser.error("--godot is required to execute the fixed queue")
        if args.resume:
            if not out.is_dir():
                raise ValueError("No prior queue to resume")
        else:
            out.mkdir(parents=True, exist_ok=False)
        lock = acquire(out, args.resume)
        godot = args.godot.resolve(strict=True)
        provenance = runtime_identity(godot)
        if provenance["source_dirty"] and not args.allow_dirty:
            raise ValueError("Campaign qualification requires clean committed source")
        project = out / "project"
        if args.resume:
            queue = json.loads((out / "queue.json").read_text())
            if queue.get("schema") != SCHEMA or queue["plan"]["episodes"] != episodes_for(args.plan):
                raise ValueError("Resume plan differs from the committed finite plan")
            snapshot = json.loads((out / "source-snapshot.json").read_text())
            provenance["project_files_sha256"] = snapshot["project_files_sha256"]
            provenance["replay_identity"] = replay_identity.build(provenance, project, snapshot["files"])
            if queue["plan"]["provenance"] != provenance:
                raise ValueError("Resume requires identical source, runtime, host identity and staged source")
            payload = {k: v for k, v in queue["plan"].items() if k != "plan_sha256"}
            if digest(payload) != queue["plan"]["plan_sha256"]:
                raise ValueError("Queue plan checksum differs")
            if queue["plan"]["memory_limit_mib"] != args.memory_limit_mib:
                raise ValueError("Resume cannot change matched process resource limits")
            check_stage(project, snapshot)
            recover_interrupted(out, queue)
            if (out / "cancel-requested.json").exists():
                (out / "cancel-requested.json").rename(out / ("retained-cancel-" + uuid.uuid4().hex + ".json"))
        else:
            snapshot = stage_project(project)
            provenance["project_files_sha256"] = snapshot["project_files_sha256"]
            provenance["replay_identity"] = replay_identity.build(provenance, project, snapshot["files"])
            write_json(out / "source-snapshot.json", snapshot)
            plan = {"kind": args.plan, "provenance": provenance, "episodes": episodes_for(args.plan),
                    "memory_limit_mib": args.memory_limit_mib, "seed_order": 17713, "pacing_ms": 0,
                    "corpus_reuse": False, "execution": "one fresh process/profile per episode; shared immutable imported project"}
            plan["plan_sha256"] = digest(plan)
            queue = {"schema": SCHEMA, "plan": plan, "status": "initializing", "created_utc": utc(), "sessions": [],
                     "episodes": [{"episode": ep, "status": "pending", "attempts": []} for ep in plan["episodes"]]}
            write_json(out / "queue.json", queue)
            env = make_profile(out / "import-profile", {"fixture_id": "construction", "policy": "CONTROL", "seed": 13, "budget": 1}, provenance)
            imported = execute([str(godot), "--headless", "--path", str(project), "--editor", "--quit"], env,
                               out / "import.log", 240, memory_limit_mib=args.memory_limit_mib)
            write_json(out / "import-result.json", imported)
            if imported["status"] != "pass":
                queue["status"] = "import_failure"
                write_json(out / "queue.json", queue)
                return 2
            check_stage(project, snapshot)
        started = time.monotonic()
        session = {"started_utc": utc(), "wall_limit_seconds": args.wall_seconds, "resume": args.resume,
                   "retry_incomplete": args.retry_incomplete, "status": "running"}
        queue["sessions"].append(session)
        queue["status"] = "running"
        write_json(out / "queue.json", queue)
        for row in queue["episodes"]:
            if row["status"] != "pending" and not (args.retry_incomplete and row["status"] != "pass" and len(row["attempts"]) < 3):
                continue
            if (out / "cancel-requested.json").exists():
                queue["status"] = "cancelled"
                break
            if time.monotonic() - started + row["episode"]["timeout_seconds"] + 15 > args.wall_seconds:
                queue["status"] = "session_wall_limit"
                break
            used = sum(p.stat().st_size for p in out.rglob("*") if p.is_file())
            if used > args.max_output_mib * 1024 * 1024 or shutil.disk_usage(out).free < 512 * 1024 * 1024:
                queue["status"] = "output_resource_limit"
                break
            if git("rev-parse", "HEAD") != provenance["source_commit"]:
                raise ValueError("Source HEAD changed during campaign")
            attempt = {"number": len(row["attempts"]) + 1, "status": "running", "started_utc": utc()}
            row["attempts"].append(attempt)
            row["status"] = "running"
            write_json(out / "queue.json", queue)
            target = out / row["episode"]["id"] / ("attempt-%02d" % attempt["number"])
            result = run_episode(row["episode"], target, project, provenance, godot, args.memory_limit_mib, out / "cancel-requested.json")
            attempt.update(status=result["status"], result_sha256=sha_file(target / "result.json"), completed_utc=utc())
            row["status"] = result["status"]
            write_json(out / "queue.json", queue)
            report(out, queue)
            print(json.dumps({"episode": row["episode"]["id"], "status": result["status"], "summary": result.get("summary", {}),
                              "elapsed_seconds": result["process"]["elapsed_seconds"], "peak_tree_rss_bytes": result["process"]["peak_tree_rss_bytes"]}), flush=True)
            if result["status"] == "cancelled":
                queue["status"] = "cancelled"
                break
        if queue["status"] == "running":
            queue["status"] = "complete" if all(row["status"] == "pass" for row in queue["episodes"]) else "complete_with_retained_failures"
        session.update(status=queue["status"], elapsed_seconds=round(time.monotonic() - started, 3), completed_utc=utc())
        write_json(out / "queue.json", queue)
        result = report(out, queue, recheck=True)
        print("GOBLIN_QUEUE_COMPLETE " + json.dumps({k: result[k] for k in ("source_commit", "queue_status", "planned_episodes", "observed_episodes", "complete_episodes", "retained_attempts")}), flush=True)
        return 0 if queue["status"] == "complete" else 2
    except (OSError, ValueError, KeyError, TypeError) as error:
        if out.is_dir():
            write_json(out / ("queue-error-" + uuid.uuid4().hex + ".json"), {"status": "infrastructure_failure", "error": str(error), "utc": utc()})
        print(json.dumps({"status": "infrastructure_failure", "error": str(error)}), flush=True)
        return 2
    finally:
        if lock is not None and lock.exists():
            lock.unlink()


if __name__ == "__main__":
    raise SystemExit(main())
