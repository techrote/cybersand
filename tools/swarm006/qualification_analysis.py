#!/usr/bin/env python3
"""Frozen SWARM-006 explicit-policy analysis. Reads evidence; never runs native code.

This is a source-custody/evidence consistency checker, not a replacement native
validator or authority to Apply. The master wrapper owns source/build custody and
the unchanged SWARM004/005 behavioral-parity comparisons.
"""
from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import importlib.util
import json
from collections import Counter
from pathlib import Path

SCHEMA = 1
CONTROL_OPTIONS = {
    "recovery+no_offers": "recovery_offers",
    "recovery+mosaic_frozen": "mosaic_adaptation",
    "recovery+frame_frozen": "frame_adaptation",
}
PHASES = ("frame_work", "mosaic_work", "solver_work", "shared_work")
ENDPOINTS = {
    "R_primary": "successful child; native complete, can_apply true, zero remaining requirements, and at least one qualified native foreign joint",
    "A_secondary": "successful child; native complete, can_apply true, zero remaining requirements",
    "bilateral_secondary": "R plus positive MOSAIC occupancy XOR against no_offers and FRAME occupancy XOR against mosaic_frozen, with exact matched input/initial plans and all three explicit controls available",
    "unknown": "not established; retained in the full registered denominator, with availability reported separately",
}


def load_runner(path):
    spec = importlib.util.spec_from_file_location("swarm006_frozen_runner", Path(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def case_key(case):
    return (case["fixture"], case["profile"], case["seed"])


def policy_key(policy):
    return (policy["name"], policy["rounds"]) if isinstance(policy, dict) else tuple(policy)


def stored_json(directory, record, name, runner):
    item = record["storage"][name]
    if Path(record["id"]).name != record["id"] or Path(item["file"]).name != item["file"]:
        raise ValueError("Evidence path is not a single local filename")
    parent = (Path(directory) / record["id"]).resolve()
    path = parent / item["file"]
    if not path.resolve().is_relative_to(Path(directory).resolve()):
        raise ValueError("Evidence path escaped campaign")
    if runner.sha(path) != item["compressed_sha256"]:
        raise ValueError("Compressed retained evidence changed")
    raw = gzip.decompress(path.read_bytes())
    if len(raw) != item["raw_bytes"] or hashlib.sha256(raw).hexdigest() != item["raw_sha256"]:
        raise ValueError("Raw retained evidence changed")
    return json.loads(raw)


def plane_difference(left, right):
    if len(left) != len(right):
        raise ValueError("Matched native material-plane lengths differ")
    return {"occupancy_xor": sum((a == 0) != (b == 0) for a, b in zip(left, right)),
            "material_differences": sum(a != b for a, b in zip(left, right))}


def audit_obligations(value, reduced):
    """Count original and assembly receipts separately; one joint is not two joints."""
    source = value["original_frame"]["result"]
    connectors = source["connectors"]
    source_observed = source["width"] > 0 and source["height"] > 0 and bool(source["cells"])
    source_ids = {c["id"]: c for c in connectors}
    if len(source_ids) != len(connectors):
        raise ValueError("Original source connector IDs are duplicated")
    pending = {key: c for key, c in source_ids.items() if c["required"] and not c["fulfilled"]}
    answer = {"closure_evaluated": reduced["closure_evaluated"], "original_source_observed": source_observed,
        "original_connectors": len(connectors) if source_observed else None,
        "original_required_total": sum(c["required"] for c in connectors) if source_observed else None,
        "original_required_initially_fulfilled": sum(c["required"] and c["fulfilled"] for c in connectors) if source_observed else None,
        "original_required_initially_unfulfilled": len(pending) if source_observed else None,
        "counts_by_origin_and_state": reduced["obligation_counts"],
        "original_receipts": None, "new_assembly_receipts": None,
        "original_foreign_joined": None, "original_still_required": None,
        "original_local_termination_flags": None, "source_time": {
            "compact_termination_count": value["metrics"].get("source_time_compact_terminations"),
            "accepted_initial_termination_caps": source["metrics"].get("accepted_termination_cap"),
            "local_opportunities_not_terminations": source["metrics"].get("swarm006_source_local_opportunities"),
            "foreign_opportunities_not_joints": source["metrics"].get("swarm006_source_foreign_opportunities"),
            "feasibility_records": len(value["original_frame"].get("source_feasibility", [])) if source_observed else None}}
    if not reduced["closure_evaluated"]:
        return answer
    obligations, joints = value["obligations"], value["joints"]
    originals = [o for o in obligations if o.get("origin", "original_frame") == "original_frame"]
    new = [o for o in obligations if o.get("origin", "original_frame") == "new_assembly"]
    original_ids = [o["connector"] for o in originals]
    if len(set(original_ids)) != len(original_ids) or set(original_ids) != set(pending):
        raise ValueError("Frozen original required obligations were omitted or duplicated")
    for receipt in obligations:
        origin = receipt.get("origin", "original_frame")
        if origin not in ("original_frame", "new_assembly", "damage_lost_internal"):
            raise ValueError("Unrecognized obligation origin")
        if receipt["state"] not in ("STILL_REQUIRED", "FOREIGN_JOINED") or type(receipt["foreign_joined"]) is not bool:
            raise ValueError("Invalid obligation state")
        if receipt["foreign_joined"] != (receipt["state"] == "FOREIGN_JOINED"):
            raise ValueError("Obligation receipt state disagrees with foreign closure")
        if origin == "original_frame":
            connector = pending[receipt["connector"]]
            if any(receipt[a] != connector[b] for a, b in (("instance", "instance"), ("original", "a"), ("facing", "facing"))):
                raise ValueError("Original receipt changed immutable source identity or geometry")
            matches = [j for j in joints if j["connector"] == receipt["connector"] and j["slot"] == receipt["slot"]]
        elif origin == "new_assembly":
            matches = [j for j in joints if j["slot"] == receipt["slot"] and
                j["frame_face"] == receipt["original"] and j["normal"] == receipt["facing"] and
                j["frame_instance"] == receipt["instance"]]
        else:
            matches = []
        if receipt["foreign_joined"] and len(matches) != 1:
            raise ValueError("Foreign obligation lacks exactly one matching native joint witness")
        if not receipt["foreign_joined"] and matches:
            raise ValueError("Unresolved receipt contradicts its native joint witness")
    used_sources, used_targets = set(), set()
    for joint in joints:
        if joint["connector"] not in source_ids:
            raise ValueError("Joint is not bound to an original native source connector")
        a, b = tuple(joint["frame_face"]), tuple(joint["masonry_face"])
        if a in used_sources or b in used_targets:
            raise ValueError("Native joint contact capacity was reused")
        used_sources.add(a); used_targets.add(b)
    original_joined = sum(o["foreign_joined"] for o in originals)
    expected = {"original_required": len(originals), "original_still_required": len(originals) - original_joined,
        "foreign_joined_required": original_joined, "new_assembly_required": len(new),
        "qualified_joints": len(joints)}
    for key, count in expected.items():
        if key in value["metrics"] and value["metrics"][key] != count:
            raise ValueError("Native obligation metric disagrees with identity receipts: " + key)
    answer.update({"original_receipts": len(originals), "new_assembly_receipts": len(new),
        "original_foreign_joined": original_joined, "original_still_required": len(originals) - original_joined,
        "original_local_termination_flags": sum(o["local_terminated"] for o in originals),
        "receipts": [{key: receipt.get(key, "original_frame" if key == "origin" else None) for key in
            ("origin", "connector", "instance", "slot", "original", "facing", "state", "foreign_joined", "local_terminated", "reason")}
            for receipt in obligations],
        "joint_path_lengths": [len(j["path"]) for j in joints]})
    return answer


def audit_work(value):
    metrics, request = value["metrics"], value["input"]
    limits = {"frame_work": request["frame"]["limits"]["work"],
        "mosaic_work": request["mosaic"]["limits"]["work"],
        "solver_work": request["mosaic"]["limits"]["solver_work"], "shared_work": 2_000_000}
    for key, limit in limits.items():
        if key in metrics and (type(metrics[key]) is not int or not 0 <= metrics[key] <= limit):
            raise ValueError("Charged work exceeds the declared native ceiling: " + key)
    if all(key in metrics for key in PHASES):
        if metrics.get("total_charged_work") != sum(metrics[key] for key in PHASES):
            raise ValueError("Aggregate native debit does not equal its four phases")
    if "total_charged_work" in metrics and (type(metrics["total_charged_work"]) is not int or not 0 <= metrics["total_charged_work"] <= 10_000_000):
        raise ValueError("Aggregate native work ceiling exceeded")
    bound = metrics.get("conservative_memory_bound_bytes")
    if bound is not None and (type(bound) is not int or bound < 0):
        raise ValueError("Invalid native conservative memory estimate")
    allowance = min(request[o]["limits"]["bytes"] for o in ("frame", "mosaic"))
    if value["status"] in ("complete", "blocked") and bound is not None and bound > allowance:
        raise ValueError("Usable native composition exceeds conservative memory allowance")
    return {"all_four_phase_debits_observed": all(k in metrics for k in PHASES),
        "memory_estimate_observed": bound is not None,
        "memory_admission_estimate_exceeded_allowance": None if bound is None else bound > allowance}


def explicit_controls(candidate, controls):
    """Inputs are compared even when a result cannot establish a causal effect."""
    out = {"available": False, "causal_complete": False, "controls": {}, "effects": {}}
    if candidate is None:
        out["unavailable_reason"] = "candidate native response unavailable"
        return out
    available = candidate["row"]["closure_evaluated"] and bool(candidate["value"]["rounds"]) and not candidate["row"].get("execution_failed", False)
    for policy, option in CONTROL_OPTIONS.items():
        control = controls.get(policy)
        out["controls"][policy] = {"available": False}
        if control is None:
            available = False
            continue
        expected = copy.deepcopy(candidate["request"])
        if expected["options"].get(option) is not True:
            raise ValueError("Candidate does not enable the matched control option")
        expected["options"][option] = False
        if control["request"] != expected:
            raise ValueError("Explicit control changed unrelated request fields: " + policy)
        usable = control["row"]["closure_evaluated"] and bool(control["value"]["rounds"]) and not control["row"].get("execution_failed", False)
        out["controls"][policy] = {"available": usable, "A": control["row"]["A"], "R": control["row"]["R"]}
        if not usable or not candidate["row"]["closure_evaluated"]:
            available = False
            continue
        cv, pv = candidate["value"], control["value"]
        if cv["original_frame"] != pv["original_frame"]:
            raise ValueError("Matched control changed original immutable FRAME source")
        for key in ("frame", "mosaic", "mosaic_request"):
            if cv["rounds"][0][key] != pv["rounds"][0][key]:
                raise ValueError("Matched control changed initial plan or donor grant: " + key)
        owner = "mosaic" if policy == "recovery+mosaic_frozen" else "frame" if policy == "recovery+frame_frozen" else None
        if owner and any(r[owner] != cv["rounds"][0][owner] for r in pv["rounds"]):
            raise ValueError("Frozen owner changed geometry, provenance, slots or categories: " + owner)
        for owner in ("frame", "mosaic"):
            out["effects"][policy + "/" + owner] = plane_difference(
                cv["rounds"][-1][owner]["result"]["cells"], pv["rounds"][-1][owner]["result"]["cells"])
    out["available"] = bool(available)
    if available:
        me = out["effects"]["recovery+no_offers/mosaic"]["occupancy_xor"]
        fe = out["effects"]["recovery+mosaic_frozen/frame"]["occupancy_xor"]
        out["causal_complete"] = candidate["row"]["R"] and me > 0 and fe > 0
    else:
        out["unavailable_reason"] = "one or more matched native closures unavailable"
    return out


def checked_record(directory, manifest, record, runner):
    """Return raw docs only for one case; the caller releases them after analysis."""
    if Path(record["id"]).name != record["id"] or record["id"] in (".", ".."):
        raise ValueError("Execution ID is not a local directory name")
    execution = record["execution"]
    failed = execution.get("returncode") != 0 or execution.get("timed_out") or execution.get("cancelled")
    log = Path(directory) / (record["id"] + ".log")
    if execution.get("log_sha256") and runner.sha(log) != execution["log_sha256"]:
        raise ValueError("Execution log changed")
    if execution.get("child_reaped") is not True:
        raise ValueError("Native child was not confirmed reaped")
    argv = execution["argv"]
    expected = [manifest["source"], record["fixture"], record["profile"], str(record["seed"]),
        record.get("effective_policy", record["policy"]), str(record["rounds"])]
    if len(argv) != 9 or argv[1] != "run" or argv[3:] != expected:
        raise ValueError("Execution identity changed or conditional controls were run")
    row = {"id": record["id"], "status": "execution_failed", "can_apply": False, "A": False, "R": False,
        "closure_evaluated": False, "still_required": None, "metrics": {}, "execution_failed": bool(failed),
        "timed_out": bool(execution.get("timed_out")), "process_cancelled": bool(execution.get("cancelled")),
        "returncode": execution.get("returncode"), "native_response_available": False}
    if "response-native.json" not in record.get("storage", {}):
        if not failed or record.get("can_apply") is not False:
            raise ValueError("Successful child omitted its native response")
        return {"row": row, "value": None, "request": None}
    value = runner.retained_document(Path(directory), record)
    request = stored_json(directory, record, "request.json", runner)
    envelope = stored_json(directory, record, "request-envelope.json", runner)
    if hashlib.sha256(runner.canonical(request)).hexdigest() != record["request_sha256"]:
        raise ValueError("Retained request changed its canonical request digest")
    if envelope["input"] != request:
        raise ValueError("Request envelope disagrees with retained exact request")
    runner.verify_native_input(request, value)
    if value["source"] != manifest["source"] or any(request[o]["source"] != manifest["source"] or
            request[o]["seed"] != record["seed"] for o in ("frame", "mosaic")):
        raise ValueError("Native request/result changed declared source or seed")
    derived = runner.reduce_result(value)
    if record.get("evidence_error"):
        raise ValueError("Campaign retained an evidence integrity error: " + record["evidence_error"])
    for key, expected_value in derived.items():
        if record.get(key) != expected_value:
            raise ValueError("Reduced manifest field disagrees with native JSON: " + key)
    if failed and derived["can_apply"]:
        raise ValueError("Failed child left an authorizing response")
    row.update(derived)
    row["native_response_available"] = True
    row["A"] = not failed and derived["can_apply"]
    row["R"] = row["A"] and derived["qualified_joints"] > 0
    row["obligation_audit"] = audit_obligations(value, derived)
    row["work_audit"] = audit_work(value)
    return {"row": row, "value": value, "request": request}


def index_campaign(directory, expected_cases, expected_policies, variant):
    manifest = json.loads((Path(directory) / "manifest.json").read_text())
    if manifest["variant"] != variant or manifest["cases"] != expected_cases:
        raise ValueError("Campaign variant or ordered case corpus differs from registration")
    if [policy_key(p) for p in manifest["policies"]] != expected_policies:
        raise ValueError("Campaign policies differ from frozen analysis")
    if manifest["expected_executions"] != len(expected_cases) * len(expected_policies):
        raise ValueError("Campaign execution denominator changed")
    if manifest.get("retained_executions") != len(manifest["records"]):
        raise ValueError("Campaign retained-execution receipt disagrees with its records")
    if manifest["source"] != manifest["build_receipt"]["source_commit"]:
        raise ValueError("Campaign source differs from its built source")
    index = {}
    allowed = {(case_key(c), p) for c in expected_cases for p in expected_policies}
    for row in manifest["records"]:
        key = (case_key(row), (row["policy"], row["rounds"]))
        if key not in allowed or key in index:
            raise ValueError("Unexpected or duplicated native execution identity")
        index[key] = row
    return manifest, index


def work_coverage(distribution, rows):
    """An observed subtotal never silently becomes an all-execution total."""
    known = sum("total_charged_work" in row["metrics"] for row in rows)
    distribution["observed_known_work_sum"] = distribution.pop("charged_work")
    distribution["known_total_work_count"] = known
    distribution["unknown_total_work_count"] = len(rows) - known
    distribution["all_execution_charged_work_total"] = distribution["observed_known_work_sum"] if known == len(rows) else None
    for summary in distribution["work"].values():
        summary["missing_count"] = len(rows) - summary["count"]
    distribution["memory_bound_bytes"]["missing_count"] = len(rows) - distribution["memory_bound_bytes"]["count"]
    return known


def analyze(candidate_dir, baseline005_dir, registration, runner):
    """Analyze exactly the preregistered Cartesian product, including missing rows."""
    cm = json.loads((Path(candidate_dir) / "manifest.json").read_text())
    cases, policies = runner.validate_registration(registration, cm["build_receipt"], runner.sha(Path(runner.__file__)))
    if registration["controls"] is not False:
        raise ValueError("Explicit-policy analysis requires controls=false")
    baseline_policies = [(p, 2) for p in ("off", "terminal_only", "receptor_only", "both")]
    mandatory = {("recovery", 2), ("recovery+reverse", 2)} | {(p, 2) for p in CONTROL_OPTIONS}
    if not mandatory.issubset(set(policies)) or not set(baseline_policies).issubset(set(policies)):
        raise ValueError("Registration omitted a mandatory explicit control/parity policy")
    cm, ci = index_campaign(candidate_dir, cases, policies, "swarm006")
    bm, bi = index_campaign(baseline005_dir, cases, baseline_policies, "swarm005")
    if bm["build_receipt"]["source_commit"] != runner.FROZEN["swarm005"]:
        raise ValueError("Baseline is not the actual unchanged SWARM005 source")
    if cm.get("registration") != registration or cm.get("registration_custody_revalidated") is not True:
        raise ValueError("Candidate registration custody was not retained")
    for manifest in (cm, bm):
        if manifest.get("source_custody_revalidated") is not True or manifest.get("binary_custody_revalidated") is not True:
            raise ValueError("Campaign source/binary custody did not pass")
    report = {"schema": SCHEMA, "programme": "GENTEK-SWARM-006", "endpoints": ENDPOINTS,
        "scope": "finite registered synthetic crops; no physical owner World or Windows/NVIDIA acceptance",
        "case_denominator": len(cases), "runner_sha256": runner.sha(Path(runner.__file__)),
        "analysis_sha256": runner.sha(Path(__file__)),
        "manifest_sha256": {"swarm006": runner.sha(Path(candidate_dir) / "manifest.json"),
            "swarm005": runner.sha(Path(baseline005_dir) / "manifest.json")},
        "campaign_results": {"swarm006": cm["result"], "swarm005": bm["result"]},
        "cases": [], "records": [], "errors": [], "distributions": {}}
    groups = {(variant, policy): [] for variant, ps in (("swarm006", policies), ("swarm005", baseline_policies)) for policy in ps}
    needed = {("recovery", 2), ("recovery+reverse", 2)} | {(p, 2) for p in CONTROL_OPTIONS}
    transitions = {endpoint: Counter() for endpoint in ("A", "R")}
    for case in cases:
        retained = {}
        for variant, directory, manifest, index, choices in (("swarm006", candidate_dir, cm, ci, policies),
                ("swarm005", baseline005_dir, bm, bi, baseline_policies)):
            for policy in choices:
                identity = (case_key(case), policy)
                record = index.get(identity)
                packet = None
                row = {"status": "not_started", "can_apply": False, "A": False, "R": False,
                    "closure_evaluated": False, "still_required": None, "metrics": {}, "native_response_available": False}
                if record is None:
                    report["errors"].append({"case": case, "variant": variant, "policy": policy, "error": "registered execution not retained"})
                else:
                    try:
                        packet = checked_record(directory, manifest, record, runner)
                        row = packet["row"]
                    except (ValueError, KeyError, TypeError, OSError) as error:
                        row["status"] = "evidence_invalid"
                        row["evidence_error"] = str(error)
                        report["errors"].append({"case": case, "variant": variant, "policy": policy, "error": str(error)})
                groups[(variant, policy)].append(row)
                report["records"].append({**case, "variant": variant, "policy": policy[0], "rounds": policy[1], **row})
                if variant == "swarm006" and policy in needed or variant == "swarm005" and policy == ("both", 2):
                    retained[(variant, policy)] = packet
        candidate = retained.get(("swarm006", ("recovery", 2)))
        baseline = retained.get(("swarm005", ("both", 2)))
        case_result = {**case, "primary": {}}
        for endpoint in transitions:
            before = bool(baseline and baseline["row"][endpoint])
            after = bool(candidate and candidate["row"][endpoint])
            transition = f"{int(before)}->{int(after)}"
            transitions[endpoint][transition] += 1
            case_result["primary"][endpoint] = {"baseline": before, "candidate": after, "transition": transition}
        try:
            controls = {p: retained.get(("swarm006", (p, 2))) for p in CONTROL_OPTIONS}
            # Missing native response packets do not expose an empty fake plane.
            causal_candidate = candidate if candidate and candidate["value"] is not None else None
            controls = {p: v if v and v["value"] is not None else None for p, v in controls.items()}
            case_result["bilateral"] = explicit_controls(causal_candidate, controls)
            reverse = retained.get(("swarm006", ("recovery+reverse", 2)))
            comparable = causal_candidate is not None and reverse is not None and reverse["value"] is not None
            equal = comparable and runner.canonical(candidate["value"]) == runner.canonical(reverse["value"])
            case_result["reverse_exact"] = {"available": comparable, "equal": bool(equal)}
            if not equal:
                raise ValueError("Registered reverse execution is unavailable or differs in native JSON")
        except (ValueError, KeyError, TypeError) as error:
            case_result["analysis_error"] = str(error)
            case_result.setdefault("bilateral", {"available": False, "causal_complete": False})
            report["errors"].append({"case": case, "error": str(error)})
        report["cases"].append(case_result)
    for (variant, policy), rows in groups.items():
        result = runner.distribution(rows)
        result["causal_complete"] = sum(c["bilateral"]["causal_complete"] for c in report["cases"]) if (variant, policy) == ("swarm006", ("recovery", 2)) else None
        result["causality_available_count"] = sum(c["bilateral"]["available"] for c in report["cases"]) if (variant, policy) == ("swarm006", ("recovery", 2)) else None
        known_work = work_coverage(result, rows)
        result.update({"registered_denominator": len(cases), "A": sum(r["A"] for r in rows),
            "R": sum(r["R"] for r in rows), "native_response_available": sum(r["native_response_available"] for r in rows),
            "execution_failures": sum(r.get("execution_failed", False) for r in rows),
            "timeouts": sum(r.get("timed_out", False) for r in rows),
            "process_cancellations": sum(r.get("process_cancelled", False) for r in rows),
            "qualified_joint_count_observed": sum("qualified_joints" in r for r in rows),
            "total_work_observed": known_work,
            "memory_note": "conservative admission estimate, not measured RSS; refused demand may exceed allowance",
            "memory_admission_refusals_observed": sum(r.get("work_audit", {}).get("memory_admission_estimate_exceeded_allowance") is True for r in rows)})
        counts = Counter()
        for row in rows:
            counts.update(row.get("obligation_counts", {}))
        result["obligation_counts_by_origin_and_state"] = dict(counts)
        report["distributions"][variant + "/" + policy[0] + "@" + str(policy[1])] = result
    report["primary_transitions"] = {e: {"registered_pairs": len(cases),
        "counts": {key: counts[key] for key in ("0->0", "0->1", "1->0", "1->1")},
        "rescues": counts["0->1"], "regressions": counts["1->0"],
        "baseline_confirmed_successes": counts["1->0"] + counts["1->1"],
        "candidate_confirmed_successes": counts["0->1"] + counts["1->1"],
        "baseline_rate": (counts["1->0"] + counts["1->1"]) / len(cases),
        "candidate_rate": (counts["0->1"] + counts["1->1"]) / len(cases),
        "net_confirmed_success_gain": counts["0->1"] - counts["1->0"]} for e, counts in transitions.items()}
    report["bilateral"] = {"registered_denominator": len(cases),
        "available": sum(c["bilateral"]["available"] for c in report["cases"]),
        "causal_complete": sum(c["bilateral"]["causal_complete"] for c in report["cases"])}
    report["result"] = "FAIL" if report["errors"] else "PASS"
    report["qualification_note"] = "Analysis integrity only. Frozen baseline parity, native gates, Workbench and Windows/owner qualification are separate mandatory gates; all PRs remain Draft/HOLD."
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("runner", "registration", "candidate", "baseline005", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        raise SystemExit("Refusing to overwrite analysis evidence")
    runner = load_runner(args.runner)
    registration = json.loads(args.registration.read_text())
    result = analyze(args.candidate, args.baseline005, registration, runner)
    result["registration_sha256"] = runner.sha(args.registration)
    runner.atomic_json(args.out, result)
    print(json.dumps({key: result[key] for key in ("result", "case_denominator", "primary_transitions", "bilateral")}))
    return 0 if result["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
