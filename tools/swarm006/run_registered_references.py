#!/usr/bin/env python3
"""Execute immutable SWARM004/005 references for an already registered006 corpus.

This wrapper never selects cases and never weakens the006 registration guard.
The actual frozen005 both-on result is the primary reference;006 both-on is a
per-case compatibility witness. All controls are explicit registered policies.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace

HELPER_PATH = Path(__file__).resolve().parents[2] / "native/experiments/gentek_swarm/run_swarm006.py"
_spec = importlib.util.spec_from_file_location("swarm006_reference_helper", HELPER_PATH)
runner = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(runner)

REFERENCE_POLICIES = {"swarm004": [("off", 2)], "swarm005": [(name, 2) for name in
    ("off", "terminal_only", "receptor_only", "both")]}
PRIMARY = {"before": {"variant": "swarm005", "policy": "both", "rounds": 2},
           "after": {"variant": "swarm006", "policy": "recovery", "rounds": 2},
           "priority": "R", "endpoints": ["R", "A"]}
PARITY = ["swarm004_off_vs_swarm005_off"] + ["swarm005_vs_swarm006_" + name for name, _ in REFERENCE_POLICIES["swarm005"]]
MASTER_KEYS = {"schema", "programme", "classification", "registration_id", "candidate_registration",
    "candidate_registration_sha256", "cases_sha256", "wrapper_sha256", "helper_runner_sha256",
    "analysis_plan_sha256", "analysis_program_sha256", "candidate_build", "references", "controls",
    "expected_candidate_ids", "expected_candidate_executions", "expected_reference_executions",
    "expected_total_executions", "primary", "required_parity"}


def equal(a, b) -> bool:
    return runner.canonical(a) == runner.canonical(b)


def digest(value) -> str:
    return hashlib.sha256(runner.canonical(value)).hexdigest()


def execution_ids(cases: list[dict], policies: list[tuple[str, int]]) -> list[str]:
    return [f'{c["fixture"]}--{c["profile"]}--s{c["seed"]}--{p}--r{r}' for c, (p, r) in itertools.product(cases, policies)]


def build_identity(path: Path) -> tuple[dict, dict]:
    """Bind the original receipt and verify its exact clean source and artifacts."""
    receipt_path = path / "build.json"
    receipt = json.loads(receipt_path.read_bytes())
    variant = receipt.get("variant")
    if (receipt.get("result") != "PASS" or variant not in (*REFERENCE_POLICIES, "swarm006") or
            receipt.get("source_dirty") != "" or receipt.get("allow_dirty_requested") is not False or
            receipt.get("source_custody_revalidated") is not True):
        raise ValueError("Registered references require successful exact clean builds")
    root = Path(receipt["source_root"])
    if (runner.git(root, "rev-parse", "HEAD") != receipt["source_commit"] or
            runner.git(root, "rev-parse", "HEAD^{tree}") != receipt["source_tree"] or
            runner.git(root, "status", "--porcelain") or runner.source_inputs(root) != receipt["source_inputs"] or
            runner.definition(root) != receipt["definition_sha256"]):
        raise ValueError("Registered build source custody changed")
    if variant in runner.FROZEN and receipt["source_commit"] != runner.FROZEN[variant]:
        raise ValueError("Reference build is not the unchanged historical native commit")
    if runner.sha(Path(receipt["binary"])) != receipt["binary_sha256"] or runner.sha(Path(receipt["harness"])) != receipt["harness_sha256"]:
        raise ValueError("Registered binary or harness changed")
    identity = {key: receipt[key] for key in ("variant", "source_commit", "source_tree", "definition_sha256",
        "binary_sha256", "harness_sha256", "runner_sha256")}
    identity["build_receipt_sha256"] = runner.sha(receipt_path)
    return identity, receipt


def validate_plan(master: dict, registration: dict, candidate_receipt: dict, identities: dict,
                  hashes: dict) -> tuple[list[dict], list[tuple[str, int]]]:
    if not isinstance(master, dict) or set(master) != MASTER_KEYS:
        raise ValueError("Master reference manifest fields must match schema exactly")
    if (type(master["schema"]) is not int or master["schema"] != 1 or master["programme"] != "GENTEK-SWARM-006" or
            master["classification"] != "preregistered_frozen_reference_comparison" or
            not isinstance(master["registration_id"], str) or not 1 <= len(master["registration_id"]) <= 96):
        raise ValueError("Invalid master reference registration")
    for key, value in hashes.items():
        if master[key] != value: raise ValueError("Frozen registration/tool/analysis bytes changed: " + key)
    if not equal(master["candidate_registration"], registration):
        raise ValueError("Master does not contain the exact006 registration")
    # Keep the native006 guard intact, including fresh-seed exclusions, exact
    # source/tool identities, limits and its complete registered policy list.
    cases, policies = runner.validate_registration(registration, candidate_receipt, hashes["helper_runner_sha256"])
    if master["controls"] is not False or registration["controls"] is not False:
        raise ValueError("Reference corpus requires explicit policies, never conditional hidden controls")
    if master["cases_sha256"] != digest(cases) or not equal(master["candidate_build"], identities["swarm006"]):
        raise ValueError("Registered candidate cases/build do not match")
    required_candidate = set(REFERENCE_POLICIES["swarm005"]) | {("recovery", 2)}
    if not required_candidate.issubset(set(policies)):
        raise ValueError("Candidate registration omits a required005 parity policy or recovery@2")
    if not equal(master["primary"], PRIMARY) or not equal(master["required_parity"], PARITY):
        raise ValueError("Primary frozen005 reference or required parity gates changed")
    if not isinstance(master["references"], dict) or set(master["references"]) != set(REFERENCE_POLICIES):
        raise ValueError("Both unchanged reference variants must be registered")
    for variant, choices in REFERENCE_POLICIES.items():
        reference = master["references"][variant]
        expected = {"build": identities[variant], "policies": [{"name": p, "rounds": r} for p, r in choices],
                    "expected_ids": execution_ids(cases, choices)}
        if not equal(reference, expected): raise ValueError("Reference build/policies/expected IDs changed: " + variant)
        if (identities[variant]["harness_sha256"] != identities["swarm006"]["harness_sha256"] or
                identities[variant]["runner_sha256"] != hashes["helper_runner_sha256"]):
            raise ValueError("References require the same frozen harness and helper runner")
    ids = execution_ids(cases, policies)
    counts = {"expected_candidate_executions": len(ids), "expected_reference_executions": len(cases) * 5,
              "expected_total_executions": len(ids) + len(cases) * 5}
    if not equal(master["expected_candidate_ids"], ids): raise ValueError("Candidate execution IDs changed")
    for key, value in counts.items():
        if type(master[key]) is not int or master[key] != value: raise ValueError("Registered denominator changed: " + key)
    return cases, policies


def context(args) -> dict:
    paths = {"master": args.master, "registration": args.registration,
             "analysis_plan": args.analysis_plan, "analysis_program": args.analysis_program}
    raw = {key: path.read_bytes() for key, path in paths.items()}
    master, registration = json.loads(raw["master"]), json.loads(raw["registration"])
    identities, receipts = {}, {}
    builds = {"swarm006": args.candidate_build, "swarm004": args.swarm004_build, "swarm005": args.swarm005_build}
    for variant, path in builds.items():
        identities[variant], receipts[variant] = build_identity(path)
        if identities[variant]["variant"] != variant: raise ValueError("Reference/candidate build was interchanged")
    hashes = {"candidate_registration_sha256": hashlib.sha256(raw["registration"]).hexdigest(),
        "wrapper_sha256": runner.sha(Path(__file__)), "helper_runner_sha256": runner.sha(HELPER_PATH),
        "analysis_plan_sha256": hashlib.sha256(raw["analysis_plan"]).hexdigest(),
        "analysis_program_sha256": hashlib.sha256(raw["analysis_program"]).hexdigest()}
    cases, policies = validate_plan(master, registration, receipts["swarm006"], identities, hashes)
    return {"master": master, "registration": registration, "raw": raw, "paths": paths, "builds": builds,
            "identities": identities, "receipts": receipts, "cases": cases, "policies": policies,
            "master_sha256": hashlib.sha256(raw["master"]).hexdigest(), "hashes": hashes}


def custody(ctx: dict) -> bool:
    if (runner.sha(Path(__file__)) != ctx["hashes"]["wrapper_sha256"] or
            runner.sha(HELPER_PATH) != ctx["hashes"]["helper_runner_sha256"]): return False
    if any(path.read_bytes() != ctx["raw"][key] for key, path in ctx["paths"].items()): return False
    return all(equal(build_identity(path)[0], ctx["identities"][variant]) for variant, path in ctx["builds"].items())


def execute_reference(ctx: dict, variant: str, output: Path) -> dict:
    runner.fresh_directory(output)
    receipt = ctx["receipts"][variant]
    choices = REFERENCE_POLICIES[variant]
    expected = ctx["master"]["references"][variant]["expected_ids"]
    manifest = {"schema": 1, "programme": "GENTEK-SWARM-006", "scope": "preregistered unchanged native references; no owner qualification",
        "classification": "preregistered_frozen_reference", "suite": "registered_reference", "variant": variant,
        "revealed005_is_unseen": False, "source": receipt["source_commit"], "build_receipt": receipt,
        "build_receipt_sha256": ctx["identities"][variant]["build_receipt_sha256"],
        "runner_sha256": ctx["hashes"]["helper_runner_sha256"], "wrapper_sha256": ctx["hashes"]["wrapper_sha256"],
        "master_sha256": ctx["master_sha256"], "registration_sha256": ctx["hashes"]["candidate_registration_sha256"],
        "cases": ctx["cases"], "policies": choices, "expected_executions": len(expected),
        "started_utc": runner.now(), "result": "RUNNING", "records": []}
    runner.atomic_json(output / "manifest.json", manifest)
    for (case, (policy, rounds)), identity in zip(itertools.product(ctx["cases"], choices), expected, strict=True):
        destination = output / identity
        command = [receipt["binary"], "run", str(destination), receipt["source_commit"], case["fixture"],
                   case["profile"], str(case["seed"]), policy, str(rounds)]
        execution = runner.execute(command, output / (identity + ".log"), ctx["registration"]["timeout_seconds"])
        row = {**case, "id": identity, "policy": policy, "effective_policy": policy, "rounds": rounds,
               "execution": execution, "status": "execution_failed", "can_apply": False}
        try:
            if (destination / "response-native.json").exists():
                request = json.loads((destination / "request-envelope.json").read_bytes())["input"]
                runner.atomic_json(destination / "request.json", request)
                row["request_sha256"] = digest(request)
                value = json.loads((destination / "response-native.json").read_bytes())
                row.update(runner.reduce_result(value))
                row["input_representation"] = runner.verify_native_input(request, value)
                if value["source"] != receipt["source_commit"]: raise ValueError("Reference returned another source")
                if execution["returncode"] != 0 and row["can_apply"]: raise ValueError("Failed child left an authorizing reference")
            if (destination / "controls.json").exists(): raise ValueError("Unexpected conditional reference controls")
        except (ValueError, KeyError, TypeError, OSError) as error:
            row["evidence_error"], row["can_apply"] = str(error), False
        row["storage"] = {}
        try:
            if destination.exists():
                for path in sorted(destination.glob("*.json")): row["storage"][path.name] = runner.compress_json(path)
                runner.atomic_json(destination / "storage.json", row["storage"])
        except (ValueError, KeyError, TypeError, OSError) as error:
            row["evidence_error"], row["can_apply"] = str(error), False
        manifest["records"].append(row)
        runner.atomic_json(output / "manifest.json", manifest)
        print(json.dumps({"variant": variant, **{k: row.get(k) for k in ("id", "status", "can_apply", "evidence_error")}}), flush=True)
        if execution["cancelled"]: break
    manifest["retained_executions"] = len(manifest["records"])
    manifest["source_custody_revalidated"] = equal(build_identity(ctx["builds"][variant])[0], ctx["identities"][variant])
    manifest["binary_custody_revalidated"] = runner.sha(Path(receipt["binary"])) == receipt["binary_sha256"]
    manifest["registration_custody_revalidated"] = ctx["paths"]["registration"].read_bytes() == ctx["raw"]["registration"]
    manifest["distributions"] = {f"{p}@{r}": runner.distribution([v for v in manifest["records"] if (v["policy"], v["rounds"]) == (p, r)]) for p, r in choices}
    good = (manifest["retained_executions"] == len(expected) and manifest["source_custody_revalidated"] and
            manifest["binary_custody_revalidated"] and manifest["registration_custody_revalidated"] and all(v["execution"]["returncode"] == 0 and
            v["status"] != "execution_failed" and not v.get("evidence_error") for v in manifest["records"]))
    manifest.update({"result": "PASS" if good else "FAIL", "ended_utc": runner.now()})
    runner.atomic_json(output / "manifest.json", manifest)
    return manifest


def run(ctx: dict, output: Path) -> int:
    runner.fresh_directory(output)
    for name, content in ctx["raw"].items():
        (output / (name + (".py" if name == "analysis_program" else ".json"))).write_bytes(content)
    report = {"schema": 1, "classification": "preregistered_frozen_references", "master_sha256": ctx["master_sha256"],
              "expected_reference_executions": ctx["master"]["expected_reference_executions"], "result": "RUNNING", "references": {}}
    runner.atomic_json(output / "manifest.json", report)
    for variant in REFERENCE_POLICIES:
        value = execute_reference(ctx, variant, output / variant)
        report["references"][variant] = {"manifest_sha256": runner.sha(output / variant / "manifest.json"),
            "result": value["result"], "retained_executions": value["retained_executions"]}
        runner.atomic_json(output / "manifest.json", report)
    report["custody_revalidated"] = custody(ctx)
    report["result"] = "PASS" if report["custody_revalidated"] and all(v["result"] == "PASS" for v in report["references"].values()) else "FAIL"
    runner.atomic_json(output / "manifest.json", report)
    return 0 if report["result"] == "PASS" else 1


def campaign(ctx: dict, path: Path, variant: str) -> dict:
    value = json.loads((path / "manifest.json").read_bytes())
    expected = ctx["master"]["expected_candidate_ids"] if variant == "swarm006" else ctx["master"]["references"][variant]["expected_ids"]
    choices = ctx["policies"] if variant == "swarm006" else REFERENCE_POLICIES[variant]
    if (value.get("result") not in ("PASS", "FAIL") or value.get("variant") != variant or
            value.get("source") != ctx["identities"][variant]["source_commit"] or
            value.get("build_receipt_sha256") != ctx["identities"][variant]["build_receipt_sha256"] or
            value.get("runner_sha256") != ctx["hashes"]["helper_runner_sha256"] or
            not equal(value.get("cases"), ctx["cases"]) or not equal(value.get("policies"), choices) or
            [r.get("id") for r in value.get("records", [])] != expected or
            value.get("expected_executions") != len(expected) or value.get("retained_executions") != len(expected)):
        raise ValueError("Campaign source, policy, denominator or integrity mismatch: " + variant)
    if any(value.get(key) is not True for key in ("source_custody_revalidated", "binary_custody_revalidated", "registration_custody_revalidated")):
        raise ValueError("Campaign custody is unverified or changed: " + variant)
    if value.get("registration_sha256") != ctx["hashes"]["candidate_registration_sha256"]:
        raise ValueError("Campaign was not bound to the registered006 corpus")
    if variant == "swarm006":
        if (value.get("classification") != "preregistered_unseen" or
                (path / "registration.json").read_bytes() != ctx["raw"]["registration"]):
            raise ValueError("Candidate evidence is not the exact preregistered run")
    elif value.get("master_sha256") != ctx["master_sha256"] or value.get("wrapper_sha256") != ctx["hashes"]["wrapper_sha256"]:
        raise ValueError("Reference evidence master or wrapper changed")
    return value


def endpoint_rows(path: Path, manifest: dict, source: str, policy: str) -> dict:
    """Describe every declared primary case without authorizing failed children."""
    rows = {}
    for row in manifest["records"]:
        if (row["policy"], row["rounds"]) != (policy, 2): continue
        key = (row["fixture"], row["profile"], row["seed"])
        execution = row.get("execution", {})
        process_ok = (type(execution.get("returncode")) is int and execution["returncode"] == 0 and
                      execution.get("timed_out") is False and execution.get("cancelled") is False)
        failed = not process_ok or bool(row.get("evidence_error")) or row.get("status") == "execution_failed"
        missing = {"A": False, "R": False, "status": "execution_failed", "closure_evaluated": False,
                   "still_required": None, "qualified_joints": None,
                   "failure_reason": row.get("evidence_error") or "No verified native response from a successful child"}
        if "response-native.json" not in row.get("storage", {}):
            if not failed: raise ValueError("Successful campaign row omitted its native response")
            rows[key] = missing
            continue
        # Declared compressed/raw hashes must verify even when the child failed.
        # Missing declared artifacts or hash corruption remain hard failures.
        try:
            value = runner.retained_document(path, row)
        except json.JSONDecodeError:
            if not failed: raise ValueError("Successful campaign row contains malformed native JSON")
            missing["failure_reason"] = row.get("evidence_error") or "Malformed native response from failed child"
            rows[key] = missing
            continue
        if not isinstance(value, dict) or "source" not in value:
            if not failed: raise ValueError("Successful campaign row omitted native source identity")
            rows[key] = missing
            continue
        if value["source"] != source: raise ValueError("Primary response changed source")
        if failed:
            missing["observed_native_status"] = value.get("status")
            rows[key] = missing
            continue
        reduced = runner.reduce_result(value)
        a = reduced["status"] == "complete" and reduced["can_apply"] and reduced["still_required"] == 0
        rows[key] = {"A": a, "R": a and reduced["qualified_joints"] > 0, "status": reduced["status"],
                     "closure_evaluated": reduced["closure_evaluated"], "still_required": reduced["still_required"],
                     "qualified_joints": reduced["qualified_joints"], "failure_reason": None}
    return rows


def compare(ctx: dict, candidate: Path, references: Path, output: Path) -> int:
    runner.fresh_directory(output)
    sources = {"swarm006": candidate, "swarm004": references / "swarm004", "swarm005": references / "swarm005"}
    manifests = {v: campaign(ctx, p, v) for v, p in sources.items()}
    gates = [(PARITY[0], "swarm004", "swarm005", "off")]
    gates += [(name, "swarm005", "swarm006", policy) for name, (policy, _) in zip(PARITY[1:], REFERENCE_POLICIES["swarm005"], strict=True)]
    results = {}
    for name, before, after, policy in gates:
        destination = output / (name + ".json")
        runner.compare(SimpleNamespace(before=sources[before], after=sources[after], before_policy=policy + "@2",
            after_policy=policy + "@2", out=destination, exact=False))
        result = json.loads(destination.read_bytes())
        results[name] = {"result": result["result"], "compared": result["compared"], "sha256": runner.sha(destination)}
    before = endpoint_rows(sources["swarm005"], manifests["swarm005"], ctx["identities"]["swarm005"]["source_commit"], "both")
    after = endpoint_rows(sources["swarm006"], manifests["swarm006"], ctx["identities"]["swarm006"]["source_commit"], "recovery")
    pairs = [{"case": case, "before": before[(case["fixture"], case["profile"], case["seed"])],
              "after": after[(case["fixture"], case["profile"], case["seed"])]} for case in ctx["cases"]]
    report = {"schema": 1, "master_sha256": ctx["master_sha256"], "analysis_plan_sha256": ctx["hashes"]["analysis_plan_sha256"],
        "analysis_program_sha256": ctx["hashes"]["analysis_program_sha256"], "primary": PRIMARY, "denominator": len(pairs),
        "primary_definition": "A=Complete AND can_apply AND zero remaining; R=A AND at least one native joint. Unknown closure stays negative in the full denominator.",
        "parity": results, "pairs": pairs, "endpoints": {}}
    for endpoint in ("R", "A"):
        report["endpoints"][endpoint] = {"before": sum(v["before"][endpoint] for v in pairs), "after": sum(v["after"][endpoint] for v in pairs),
            "gained": sum(not v["before"][endpoint] and v["after"][endpoint] for v in pairs),
            "lost": sum(v["before"][endpoint] and not v["after"][endpoint] for v in pairs)}
    report["custody_revalidated"] = custody(ctx)
    report["campaign_results"] = {variant: value["result"] for variant, value in manifests.items()}
    report["result"] = "PASS" if (report["custody_revalidated"] and all(v["result"] == "PASS" for v in manifests.values()) and
        all(v["result"] == "PASS" and v["compared"] == len(pairs) for v in results.values())) else "FAIL"
    runner.atomic_json(output / "manifest.json", report)
    return 0 if report["result"] == "PASS" else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "run", "compare"))
    for name in ("master", "registration", "analysis-plan", "analysis-program", "candidate-build", "swarm004-build", "swarm005-build"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--candidate-evidence", type=Path)
    parser.add_argument("--reference-evidence", type=Path)
    args = parser.parse_args()
    if args.command != "validate" and args.out is None: parser.error("--out is required")
    if args.command == "compare" and (args.candidate_evidence is None or args.reference_evidence is None):
        parser.error("compare requires candidate and reference evidence")
    try:
        ctx = context(args)
        if args.command == "validate":
            print(json.dumps({"result": "PASS", "master_sha256": ctx["master_sha256"], "cases": len(ctx["cases"]),
                "candidate_executions": ctx["master"]["expected_candidate_executions"],
                "reference_executions": ctx["master"]["expected_reference_executions"]}))
            return 0
        return run(ctx, args.out.resolve()) if args.command == "run" else compare(ctx, args.candidate_evidence, args.reference_evidence, args.out.resolve())
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        print("SWARM006_REGISTERED_REFERENCE: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
