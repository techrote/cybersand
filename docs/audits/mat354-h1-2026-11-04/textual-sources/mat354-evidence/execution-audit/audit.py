#!/usr/bin/env python3
"""Read-only audit of frozen MAT354 F2 execution; creates one new report only.

Reproduce: python audit.py --output /a/new/nonexistent/report.json
No compilation, timing, native execution, Git mutation, or causal waiver occurs.
"""
import argparse
import collections
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess


def digest(path):
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def verify(item, root=Path("/")):
    path = Path(item["path"])
    if not path.is_absolute():
        path = root / path
    data = path.read_bytes()
    assert len(data) == item["bytes"] and hashlib.sha256(data).hexdigest() == item["sha256"], path
    return data


def rows(data):
    return [json.loads(line) for line in data.splitlines()]


def physical(data):
    return [(r["tick"], r.get("world_tick"), r["physical_hash"], r["tuple_hash"])
            for r in data if r["type"] == "tick"]


def process(receipt):
    assert receipt["returncode"] == 0 and not receipt["timed_out"]
    assert not verify(receipt["stderr"])
    return rows(verify(receipt["stdout"]))


def audit(root):
    receipt_paths = [
        "correctness-attempt-2/qualification.json",
        "asan-ubsan-attempt-2-no-leaks/receipt.json", "tsan-attempt-1/receipt.json",
        "correctness-attempt-1/qualification.json",
        "correctness-attempt-1/h1-regress-r0.process.json",
        "asan-ubsan-attempt-1/receipt.json", "h1-diagnostic-setupfix-1/diagnostic.json",
    ]
    q = json.loads((root / receipt_paths[0]).read_text())
    assert q["status"] == "EXECUTED" and q["mode"] == "correctness" and len(q["runs"]) == 250
    result = {"schema": "mat354.h1.execution-audit.v1", "status": "PASS_WITH_EXPLICIT_SCOPE_LIMITS",
              "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "analysis_script": digest(Path(__file__).resolve()),
              "sourced_receipts": [digest(root / p) for p in receipt_paths],
              "source_and_binary_identities": {}, "sanitizers": {}}
    for variant, source in q["sources"].items():
        source_root = Path(source["root"])
        git = subprocess.check_output(["git", "-C", str(source_root), "rev-parse", "HEAD", "HEAD^{tree}"], text=True).splitlines()
        assert git == [source["commit"], source["tree"]]
        assert not subprocess.check_output(["git", "-C", str(source_root), "status", "--porcelain"])
        for item in source["inputs"] + q["builds"][variant]["dependencies"]:
            verify(item, source_root)
        verify(q["builds"][variant]["executable"])
        result["source_and_binary_identities"][variant] = {
            "commit": source["commit"], "tree": source["tree"], "world_lf_sha256": source["world_lf_sha256"],
            "source_input_count": len(source["inputs"]), "compiled_dependency_count": len(q["builds"][variant]["dependencies"]),
            "source_inventory_sha256": source["inputs_sha256"], "executable": q["builds"][variant]["executable"],
            "compiler": q["compiler"], "flags": q["builds"][variant]["flags"], "git_status": "clean",
        }
    for item in q["apparatus"]["inputs"]:
        verify(item, Path(q["sources"]["successor"]["root"]))
    verify(q["compiler"])
    result["apparatus"] = q["apparatus"]
    phase, groups, tick_counts, case_counts, examples = {}, {}, collections.Counter(), collections.Counter(), {}
    new_runs = []
    for run in q["runs"]:
        data = process(run["process"])
        if run["kind"] == "h1-regression":
            new_runs.append(data)
            continue
        variant, meta = run["variant"], data[0]
        ticks = [r for r in data if r["type"] == "tick"]
        assert meta["type"] == "metadata" and meta["case_id"] == run["process"]["id"] == run["reduction"]["case_id"]
        assert [r["tick"] for r in ticks] == list(range(1, meta["horizon"] + 1))
        assert len([r for r in data if r["type"] == "summary"]) == 1 and data[-1]["type"] == "summary"
        assert all(not r["has_failed"] and r["quantity_ok"] and r["reset_fresh_equal"] for r in ticks)
        assert data[-1]["quantity_ok"] and not data[-1]["has_failed"] and len(ticks) == run["reduction"]["ticks"]
        phase[(variant, meta["case_id"])] = physical(data)
        tick_counts[variant] += len(ticks)
        case_counts[variant] += 1
        key = (variant, meta["fixture"], meta["variant"], meta["x"], meta["y"], meta["quiet"], meta["active_neighbour"])
        groups.setdefault(key, []).append((meta["workers"], meta["repeat"], physical(data)))
        if meta["fixture"] == "molten_isolated" and meta["quiet"] == 3 and meta["workers"] == 1:
            examples[f"{variant}-phase{ticks[0]['thermal_phase']}"] = {
                "x": meta["x"], "y": meta["y"], "first_executed_due_tick": next((r["tick"] for r in ticks if r["cooling_due"] and r["kernel_visits"]), None),
                "first_glass": data[-1]["first_glass"], "final_material": ticks[-1]["material"], "final_a": ticks[-1]["state_a"],
                "last_kernel": data[-1]["last_kernel_visit"], "scheduled_jobs": data[-1]["scheduled_jobs"],
            }
    assert case_counts == {"baseline": 124, "successor": 124}
    for variant in case_counts:
        assert {case for source, case in phase if source == variant} == set(q["plan"]["phase_a_case_ids"])
    for key, group in groups.items():
        assert all(sequence == group[0][2] for _, _, sequence in group), key
    for difference in q["correctness"]["differences"]:
        old, new = phase[("baseline", difference["id"])], phase[("successor", difference["id"])]
        if difference["oracle_category"] == "exact":
            assert old == new, difference["id"]
        elif difference["oracle_category"] == "tuples":
            assert [(r[0], r[-1]) for r in old] == [(r[0], r[-1]) for r in new], difference["id"]
    result["phase_a_reuse"] = {
        "processes_per_source": dict(case_counts), "tick_rows_per_source": dict(tick_counts),
        "worker_groups_with_exact_physical_sequence_parity": sum(len({w for w, _, _ in g}) > 1 for g in groups.values()),
        "repeat_groups_with_exact_physical_sequence_parity": sum(len({r for _, r, _ in g}) > 1 for g in groups.values()),
        "sequence_comparisons": sum(len(g) - 1 for g in groups.values()),
        "comparison_categories": dict(collections.Counter(d["oracle_category"] for d in q["correctness"]["differences"])),
        "pending_causal_reviews_retained": q["correctness"]["pending_causal_reviews"],
        "actual_distributed_workers": q["correctness"]["actual_distributed_workers"], "isolated_phase_observations": examples,
    }
    new_sequences = []
    for data in new_runs:
        tests = [r for r in data if r["type"] == "h1_case"]
        assert [r["case"] for r in tests] == q["plan"]["new_regression_expected_cases"] and all(r["status"] == "PASS" for r in tests)
        assert data[-1] == {"type": "h1_regression_summary", "status": "PASS"}
        buckets = collections.defaultdict(list)
        ticks = [r for r in data if r["type"] == "h1_tick"]
        new_sequences.append([(r["case"], r["replica"], r["tick"], r["physical_hash"], r["tuple_hash"]) for r in ticks])
        for row in ticks:
            buckets[(row["case"], row["replica"])].append(row)
        for (case, replica), sequence in buckets.items():
            if case == "eight-visible-heat-neighbours":
                assert [r["tick"] for r in sequence] == list(range(1, 33)) * 8
            else:
                assert all(b["tick"] == a["tick"] + 1 for a, b in zip(sequence, sequence[1:])), (case, replica)
            other = replica.replace("w1", "w4") if "w1" in replica else None
            if other and (case, other) in buckets:
                assert [(r["tick"], r["physical_hash"], r["tuple_hash"]) for r in sequence] == [(r["tick"], r["physical_hash"], r["tuple_hash"]) for r in buckets[(case, other)]]
            if replica == "q3-w1":
                assert [(r["tick"], r["tuple_hash"]) for r in sequence] == [(r["tick"], r["tuple_hash"]) for r in buckets[(case, "q1024-w1")]]
    assert len(new_sequences) == 2 and new_sequences[0] == new_sequences[1]
    result["new_regressions"] = {"process_repeats": 2, "cases_per_repeat": 30, "tick_rows_per_repeat": len(new_sequences[0]),
        "case_replica_groups_per_repeat": len(buckets), "complete_repeated_physical_and_tuple_sequences_equal": True,
        "case_tick_coverage": dict(collections.Counter(r["case"] for r in new_runs[0] if r["type"] == "h1_tick")),
        "row_types_per_repeat": dict(collections.Counter(r["type"] for r in new_runs[0])),
        "direction_coverage_note": "Eight 32-step neighbour Worlds share one case/replica label; direction identity is fixed by authenticated source loop order, not an explicit raw direction field."}
    for name in ["asan-ubsan-attempt-2-no-leaks", "tsan-attempt-1"]:
        receipt = json.loads((root / name / "receipt.json").read_text())
        assert receipt["status"] == "EXECUTED" and len(receipt["executions"]) == 7
        assert receipt["source"]["commit"] == q["sources"]["successor"]["commit"]
        source_root = Path(q["sources"]["successor"]["root"])
        for item in receipt["dependencies"] + receipt["source"]["inputs"]:
            verify(item, source_root)
        verify(receipt["executable"])
        verify(receipt["compiler"])
        checks, by_fixture = [], {}
        for execution in receipt["executions"]:
            data = process(execution)
            if execution["case"] == "full-h1-regressions":
                assert verify(execution["stdout"]) == verify(q["runs"][0]["process"]["stdout"])
                checks.append({"case": execution["case"], "all_raw_bytes_equal_ordinary_O3": True, "cases_passed": 30})
                continue
            meta, sequence = data[0], physical(data)
            assert sequence == phase[("successor", execution["case"])] and len(sequence) == meta["horizon"]
            assert all(r["quantity_ok"] and not r["has_failed"] for r in data if r["type"] == "tick")
            by_fixture.setdefault(meta["fixture"], []).append(sequence)
            checks.append({"case": execution["case"], "tick_rows": len(sequence), "physical_and_tuple_sequence_equal_ordinary_O3": True,
                           "actual_worker_claimants": data[-1]["max_workers_observed"], "quantity_ok": data[-1]["quantity_ok"]})
        assert all(len(pair) == 2 and pair[0] == pair[1] for pair in by_fixture.values())
        result["sanitizers"][name] = {"source_commit": receipt["source"]["commit"], "source_tree": receipt["source"]["tree"],
            "executable": receipt["executable"], "compiler": receipt["compiler"], "flags": receipt["flags"],
            "sanitizer_environment": receipt["sanitizer_environment"], "leak_check": receipt["leak_check"],
            "executions": checks, "one_four_physical_parity": list(by_fixture), "scope": receipt["scope"]}
    first = json.loads((root / "correctness-attempt-1/qualification.json").read_text())
    first_process = json.loads((root / "correctness-attempt-1/h1-regress-r0.process.json").read_text())
    failed_sanitizer = json.loads((root / "asan-ubsan-attempt-1/receipt.json").read_text())
    failed_run = failed_sanitizer["executions"][0]
    assert first["status"] == failed_sanitizer["status"] == "FAILED" and not first["runs"]
    assert first_process["returncode"] == failed_run["returncode"] == 1
    old_stdout, old_stderr = verify(first_process["stdout"]), verify(first_process["stderr"])
    san_stdout, san_stderr = verify(failed_run["stdout"]), verify(failed_run["stderr"])
    assert b'initial cooling state refused' in old_stdout and b'initial cooling state refused' in san_stdout
    assert not any(r["type"] == "h1_tick" for r in rows(old_stdout) + rows(san_stdout))
    assert b'LeakSanitizer has encountered a fatal error' in san_stderr
    result["initial_failure_custody"] = {
        "source_commit": first["sources"]["successor"]["commit"], "source_tree": first["sources"]["successor"]["tree"],
        "native_status": first["status"], "native_tick_rows": 0, "native_stdout": first_process["stdout"], "native_stderr": first_process["stderr"],
        "asan_status": failed_sanitizer["status"], "asan_tick_rows": 0, "asan_stdout": failed_run["stdout"], "asan_stderr": failed_run["stderr"],
        "diagnosis": "Test setup mistook unchanged set_cell_state changed=false for failure; correction verifies state readback. No physics/oracle change.",
        "leak_sanitizer_failure": san_stderr.decode(),
        "diagnostic_status": json.loads((root / "h1-diagnostic-setupfix-1/diagnostic.json").read_text())["status"],
    }
    cross = q["cross_source_save"]
    export_rows, import_rows = process(cross["export"]), process(cross["import"])
    verify(cross["snapshot"])
    assert cross["observation"] in import_rows
    assert cross["observation"]["accepted"] and cross["observation"]["unaltered_1024_jobs"] == 0
    assert cross["observation"]["unaltered_a"] == 180 and cross["observation"]["unaltered_material"] == 36
    assert cross["observation"]["after_explicit_reentry_material"] == 35
    result["cross_source_save"] = {"snapshot": cross["snapshot"], "observation": cross["observation"], "scope": cross["scope"],
                                   "export_row_count": len(export_rows), "import_row_count": len(import_rows)}
    result["scope_limits"] = [
        "Execution audit is not an independent causal disposition of the 10 aggregate/edit comparison cases.",
        "Sanitizers cover the 30 new H1 cases plus six selected one/four-worker scenarios, not full ordinary sanitizer CI.",
        "LeakSanitizer failed environmentally on the first source and was disabled for F2 ASan/UBSan; no successful leak qualification exists here.",
        "Small Water PF/IN fixtures observe one actual claimant under either configuration; distributed MoltenGlass observes four.",
        "Historical CYPS is accepted but its sleeping180/no-deadline source remains stalled for1024 ticks; explicit region re-entry resumes it. This is not migration or strict replay acceptance.",
        "No performance, Windows, Godot, CI merge-checkout, or adoption disposition is established by this audit.",
        "Status PASS_WITH_EXPLICIT_SCOPE_LIMITS validates coverage, custody, exact controls, and trajectory equality only; owner compatibility/performance and independent final review remain required.",
    ]
    result["verified_completed_process_output_facts"] = 2 * (len(q["runs"]) + 14 + 2)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assert not args.output.exists(), "refusing to overwrite any report"
    report = audit(args.evidence_root.resolve())
    with args.output.open("x", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    print(json.dumps({"status": report["status"], "report": digest(args.output)}))
