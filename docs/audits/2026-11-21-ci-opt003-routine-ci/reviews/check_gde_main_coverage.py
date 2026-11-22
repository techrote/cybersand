#!/usr/bin/env python3
"""Read-only inspection of retained final GDE receipts and attempt-specific API records."""
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ARTIFACTS = ROOT / "gde-main-coverage"
SOURCE = "662df51cd8409a52332fa7ef15d06d8ab8945aed"
RUN = 44967549040
ATTEMPT = 2

def read(path):
    return json.loads(path.read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

expected = read(ROOT / "gde-main-expected-inventory.json")
jobs = read(ARTIFACTS / "gde-main-attempt2-terminal-jobs.json")
run = read(ARTIFACTS / "gde-main-attempt2-terminal-run.json")
assert expected["source_sha"] == SOURCE
assert run["id"] == RUN and run["run_attempt"] == ATTEMPT and run["head_sha"] == SOURCE
assert run["event"] == "push" and run["status"] == "completed" and run["conclusion"] == "success"
names = {"ready validation scope", "physical-actor-stress", "complete execution budgets", "linux build x86_64", "windows x86_64", "art workbench graphical smoke", "windows sharded execution coverage", "linux x86_64", "retained execution and physical timing history"}
names |= {f"windows headless regression shard {i}" for i in range(23)}
names |= {f"linux regression shard {i}" for i in range(24)}
assert jobs["total_count"] == len(jobs["jobs"]) == len(names) == 56
assert Counter(x["name"] for x in jobs["jobs"]) == Counter(names)
for job in jobs["jobs"]:
    assert job["head_sha"] == SOURCE and job["run_id"] == RUN and job["run_attempt"] == ATTEMPT
    assert job["status"] == "completed"
    assert job["conclusion"] == ("skipped" if job["name"] in {"ready validation scope", "physical-actor-stress"} else "success")

receipts = {}
for platform in ("windows", "linux"):
    spec = expected["platforms"][platform]
    directory = ARTIFACTS / platform
    path = directory / f"{platform}-coverage.json"
    receipt = read(path)
    meta_path = ARTIFACTS / f"{platform}-artifact-metadata.json"
    meta = read(meta_path)
    archive = ARTIFACTS / f"{platform}-coverage-{RUN}-{ATTEMPT}.zip"
    assert meta["name"] == archive.stem and not meta["expired"]
    assert meta["workflow_run"]["id"] == RUN and meta["workflow_run"]["head_sha"] == SOURCE
    assert meta["digest"] == "sha256:" + digest(archive) and meta["size_in_bytes"] == archive.stat().st_size
    assert receipt["status"] == "passed" and receipt["source_sha"] == SOURCE
    assert receipt["source_tree"] == expected["source_tree"] and receipt["execution_policy"] == expected["execution_policy"]
    assert str(receipt["run_id"]) == str(RUN) and str(receipt.get("attempt", receipt.get("run_attempt"))) == str(ATTEMPT)
    assert receipt["shard_count"] == spec["shard_count"]
    if platform == "windows":
        assert receipt["schema"] == "windows-godot-sharded-coverage-v2"
        assert receipt["applicable_case_count"] == receipt["unique_case_count"] == spec["case_count"] == 315
        assert receipt["graphical_cases_explicitly_out_of_scope"] == expected["windows_graphical_exclusions"]
        assert len(receipt["shards"]) == spec["shard_count"] == 23
        assert receipt["raw_logs_verified"] == 315 + 23
        for index, shard in enumerate(receipt["shards"]):
            assert shard["shard_index"] == index and shard["test_names"] == spec["shards"][index]
            assert shard["case_count"] == len(shard["test_names"]) and shard["raw_logs_verified"] == len(shard["test_names"]) + 1
            assert shard["report_path"] == f"build/windows-coverage-input/windows-godot-headless-{index}-{RUN}-{ATTEMPT}/windows-execution.json"
            assert re.fullmatch(r"[0-9a-f]{64}", shard["report_sha256"])
        assert (directory / "windows-coverage-verification.log").read_text().strip() == "WINDOWS_SHARD_COVERAGE PASS: 315 cases across 23 actual Windows shards, 338 hash-verified logs against source-derived coverage"
    else:
        assert receipt["schema"] == "linux-godot-coverage-v1"
        assert receipt["case_count"] == len(receipt["cases"]) == spec["case_count"] == 338
        assert Counter(receipt["cases"]) == Counter(spec["cases"])
        assert len(receipt["originals"]) == spec["shard_count"] == 24
        assert Counter(x["shard_index"] for x in receipt["originals"]) == Counter(range(24))
        assert receipt["cases"] == [case for original in receipt["originals"] for case in spec["shards"][original["shard_index"]]]
        for original in receipt["originals"]:
            index = original["shard_index"]
            assert original["path"] == f"linux-godot-shard-{index}-{RUN}-{ATTEMPT}/godot-regressions/shard-{index}/timings.json"
            assert re.fullmatch(r"[0-9a-f]{64}", original["sha256"])
    play_proofs = sorted((directory / f"{platform}-play-readback").glob("*/proof.json"))
    for proof_path in play_proofs:
        proof = read(proof_path)
        assert proof["source_revision"] == SOURCE and proof["platform"] == platform.capitalize()
        assert proof["status"] == "passed" and proof["complete"] is True and proof["returncode"] == 0
        assert proof["case"] == proof_path.parent.name
        assert proof["verified_sha256"] == digest(proof_path.parent / "verified.json")
        assert proof["verifier_log_sha256"] == digest(proof_path.parent / "verifier-output.txt")
    receipts[platform] = {"artifact_id": meta["id"], "archive": str(archive.relative_to(ROOT)), "archive_sha256": digest(archive), "metadata_sha256": digest(meta_path), "receipt": str(path.relative_to(ROOT)), "receipt_sha256": digest(path), "source_sha": receipt["source_sha"], "source_tree": receipt["source_tree"], "run_id": RUN, "run_attempt": ATTEMPT, "case_count": spec["case_count"], "shard_count": spec["shard_count"], "source_inputs_verified": receipt["source_inputs_verified"], "retained_play_proofs_verified": len(play_proofs), "extracted_files_sha256": {str(p.relative_to(directory)): digest(p) for p in sorted(directory.rglob("*")) if p.is_file()}}

result = {"schema": "ci-opt003-independent-postmerge-gde-admission-v1", "reviewer": "/root/review_ci_proof", "verdict": "GO", "source_sha": SOURCE, "source_tree": expected["source_tree"], "run_id": RUN, "run_attempt": ATTEMPT, "run_url": run["html_url"], "event": "push", "completed_applicable_jobs": 54, "expected_policy_skips": 2, "unexpected_skips_or_failures": 0, "job_outcomes_sha256": digest(ARTIFACTS / "gde-main-attempt2-terminal-jobs.json"), "run_record_sha256": digest(ARTIFACTS / "gde-main-attempt2-terminal-run.json"), "source_derived_inventory_sha256": digest(ROOT / "gde-main-expected-inventory.json"), "admission_script_sha256": digest(Path(__file__)), "receipts": receipts, "scope": "Original coverage artifacts, exact source-derived case and shard inventory, retained play-readback seals, and every applicable attempt-2 job outcome. The production hosted reducers verified original shard logs; this readback does not claim a second local execution of all scientific tests or a local replay of every raw shard artifact.", "attempt1_evidence_used_for_admission": False, "new_ci_runs_started": False}
out = ROOT / "gde-main-attempt2-final-qualification.json"
out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps({key: value for key, value in result.items() if key != "receipts"}, indent=2))
for platform, receipt in receipts.items():
    print(platform, json.dumps({key: value for key, value in receipt.items() if key != "extracted_files_sha256"}, sort_keys=True))
