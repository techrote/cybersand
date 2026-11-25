#!/usr/bin/env python3
"""Read-only independent reconciliation of the lead-brokered original-byte reviews."""
import argparse
import hashlib
import json
from pathlib import Path

def main(root):
    checks = 0
    failures = []
    def check(ok, label):
        nonlocal checks
        checks += 1
        if not ok:
            failures.append(label)
    def read(name):
        return json.loads((root/name).read_text())
    def sha(name):
        return hashlib.sha256((root/name).read_bytes()).hexdigest()
    execution = read("apply-review-execution.json")
    preparation = read("preparation-review.json")
    pair = read("pair-review.json")
    original = read("near-cap-apply-pair.json")
    for name in ("preparation-review.json", "pair-review.json"):
        record = read(name)
        check(sha(name) == execution["stdout"][name]["sha256"], name+" original stdout SHA")
        check((root/name).stat().st_size == execution["stdout"][name]["bytes"], name+" original bytes")
        check(record["status"] == execution["stdout"][name]["result"] == "passed", name+" actual result")
    for name, key in (("verify_art_conversation_preparation_evidence.py", "verify_preparation.py"),
                      ("verify_art_apply_pair_evidence.py", "verify_pair.py")):
        check(sha(name) == execution["script_sources"][key]["sha256"], name+" unchanged independently authored source")
    check(preparation["checks"] == 295 and pair["checks"] == 161, "Raw review denominator")
    check(preparation["source"] == "8a015efbeb7926a3c835303d3b163c01d353aca3", "Prepared source")
    check(preparation["verified_original_payload_files"] == 64
          and preparation["original_payload_bytes"] == 31575371, "Preparation original files")
    check(preparation["audit_bytes"] == 13641575 and preparation["audit_events"] == 28, "Actual complete audit")
    check(preparation["audit_kinds"] == {"conversation":14, "conversation_edited":12,
          "collaboration_preview":1, "collaboration_proposal":1}, "Admitted event denominator")
    check(preparation["lifecycle_checks"] == 154 and preparation["provider_mechanism_checks"] == 66,
          "Actual lifecycle/mechanism assertions")
    check(preparation["retained_failures"]["fixture_failed_checks"] == 11
          and len(preparation["retained_failures"]["near_cap_incomplete"]) == 2
          and all(row["execution"]["exit_code"] == -9 for row in preparation["retained_failures"]["near_cap_incomplete"]),
          "Retained original failures")
    check(preparation["model_calls"] == preparation["native_draw_batches_from_test"] == 0, "Lifecycle scope")
    check(pair["verified_original_files"] == 29 and pair["zip_members_including_manifest"] == 30
          and pair["original_payload_bytes"] == 67120420, "Pair original files")
    check(pair["matched_complete_value_bytes"] == 16769024
          and pair["matched_complete_value_sha256"] == "ffc422efd777b216bfece96071e4fdd4ffed8e05375783e43dd47fde6b7c7a7a",
          "Pair full edited value")
    for index, result in enumerate(pair["results"]):
        arm = original["arms"][index]
        check(result["source"] == arm["source_before"]["commit"]
              and result["tree"] == arm["source_before"]["tree"], "Pair source "+str(index))
        check(result["case"] == arm["report"]["cases"][0], "Exact original counters "+str(index))
        check(result["audit"]["audit_bytes"] == 33538622 and result["audit"]["events"] == 2
              and result["audit"]["event_kinds"] == {"conversation":1, "conversation_edited":1},
              "Pair complete audit "+str(index))
        check(result["audit"]["complete_value_sha256"] == pair["matched_complete_value_sha256"],
              "Pair complete replayed hash "+str(index))
    check(pair["completion_difference_usec"] == 24543
          and pair["results"][1]["case"]["apply_completion_usec"]-pair["results"][0]["case"]["apply_usec"] == 24543,
          "Slower complete latency retained")
    result = {"schema":"art-independent-apply-stdout-reconciliation-v1",
              "status":"passed" if not failures else "failed", "checks":checks, "failures":failures,
              "execution_commit":"d3222f291bb96cee78af6f46d4a4a17e4892024d",
              "execution_sha256":sha("apply-review-execution.json"), "verified_stdout":execution["stdout"],
              "verified_script_sources":execution["script_sources"],
              "method":"B independently fetched and authenticated complete stdout/execution and verifier source. The original-byte methods were independently authored by B and executed unchanged by the lead.",
              "limits":["No additional native execution.",
                        "The pair result's historical runtime_hash_record field holds artifact-file hashes; binary custody remains in source-specific provenance and package evidence.",
                        "One sequential headless pair, with total completion24.543ms slower and residual73.356ms maximum frame.",
                        "Earlier incomplete attempts and the physical Windows no-listener acceptance remain separate."]}
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "passed" else 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    raise SystemExit(main(parser.parse_args().directory))
