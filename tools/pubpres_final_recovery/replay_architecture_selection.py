"""Supplement the original six-arm refusal using its exact retained Windows artifact."""
from __future__ import annotations
import argparse
from decimal import Decimal
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import struct
import zipfile

from engine_trace import validate_transactions
from results import canonical, distribution, need
from run_bounded_comparison import ORDER, compare_registered_direction, product_gates
from observer_support import calibration_measurements

SOURCE = "00478f29b9abaccb1e358137e8a9a48894c1690b"
ARCHIVE_SHA = "da2ae0f3c528304c66e6703d422334acc1944d3480cd3c3e393a22c1a6a95fed"
URL = "https://github.com/techrote/cybersand/actions/runs/46060454634/artifacts/15229833054"
CASES = ["wave_512_follow", "wave_gameplay_2048_follow"]
GAPS = (100, 250, 500, 1000)
REFUSAL = "Equal-step body or admitted input outcomes diverged; causal comparison refused"
BODY_FIELDS = {"slot", "instance_id", "contacts", "angle", "xy", "velocity"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def binary32(value):
    need(type(value) in (int, Decimal) and Decimal(value).is_finite(), "Unexpected Vector2 component")
    return struct.pack(">f", float(value))


def compare_bodies(reference, current):
    """Only exact ties of adjacent printed decimals around one binary32 are accepted."""
    need(len(reference) == len(current) == 144, "Incomplete physical histories")
    changes = {"xy": 0, "velocity": 0}
    for left, right in zip(reference, current):
        need(len(left) == len(right) == 1, "Registered body roster differs")
        a, b = left[0], right[0]
        need(set(a) == set(b) == BODY_FIELDS, "Unexpected body field")
        for key in ("slot", "instance_id", "contacts"):
            need(type(a[key]) is type(b[key]) is int and a[key] == b[key], "Physical identity or contact count differs")
        need(type(a["angle"]) is type(b["angle"]) is Decimal and a["angle"].is_finite()
             and a["angle"].as_tuple() == b["angle"].as_tuple(), "Angle differs")
        for key in changes:
            need(type(a[key]) is type(b[key]) is list and len(a[key]) == len(b[key]) == 2, "Invalid Vector2")
            for x, y in zip(a[key], b[key]):
                bits = binary32(x)
                need(type(x) is type(y) and bits == binary32(y), "Different binary32 vector components")
                if x == y:
                    continue
                unit = Decimal(1).scaleb(x.as_tuple().exponent)
                midpoint = Decimal.from_float(struct.unpack(">f", bits)[0])
                need(x.as_tuple().exponent == y.as_tuple().exponent and abs(x-y) == unit and x+y == 2*midpoint,
                     "Unequal decimals are not adjacent exact midpoint spellings")
                changes[key] += 1
    return changes


def vector_digest(steps):
    rows = [[{**body, "xy": [binary32(x).hex() for x in body["xy"]],
              "velocity": [binary32(x).hex() for x in body["velocity"]], "angle": str(body["angle"])}
             for body in step] for step in steps]
    return sha(canonical(rows).encode())


def audit_arm(z, folder, arm):
    def data(name):
        return z.read(str(folder / name))
    receipt = json.loads(data("receipt.json"))
    need(sha(data("receipt.json")) == arm["receipt_sha256"] and receipt["source_identity"]["source_sha"] == SOURCE,
         "Original source or receipt differs")
    raw = data("receipt-events.jsonl")
    need(sha(raw) == receipt["trace_sha256"] == arm["statistics"]["trace_sha256"], "Original physical trace differs")
    start, end = receipt["capture_start_usec"], receipt["capture_end_usec"]
    def captured(line):
        e = json.loads(line, parse_float=Decimal)
        return e if e["event"] == "rapier_step" and start <= e["time_usec"] <= end else None
    steps = [e for line in raw.splitlines() if (e := captured(line)) is not None][:144]
    need(len(steps) == 144 and all(b["step"] == a["step"]+1 for a,b in zip(steps, steps[1:])), "Nonconsecutive steps")
    bodies = [s["bodies"] for s in steps]
    inputs = [s["admitted_move"] for s in steps]
    # Reproduce the prospective raw hashes with its original JSON number parser.
    original = [e for line in raw.splitlines() if (e := json.loads(line))["event"] == "rapier_step"
                and start <= e["time_usec"] <= end][:144]
    stats = arm["statistics"]
    for key, field in (("bodies","first_144_body_trajectory_sha256"), ("admitted_move","first_144_admitted_moves_sha256")):
        need(sha(canonical([s[key] for s in original]).encode()) == stats[field], "Original equal-step digest differs")
    gaps = [(b["time_usec"]-a["time_usec"])/1000 for a,b in zip(steps,steps[1:])]
    dist = distribution(gaps)
    first = stats["windows"]["first_144_steps"]
    rate = 144e6/(steps[-1]["time_usec"]-start)
    need(dist == first["physical_gap_ms"] and math.isclose(rate, first["rapier_steps_per_second"], rel_tol=1e-14),
         "Physical rates or gaps differ")
    counts = {str(n):sum(g>n for g in gaps) for n in GAPS}
    need(counts == stats["physical_gap_counts_above_ms"]["first_144_steps"], "Severe gap counts differ")
    deferred = joined = None
    if arm["engine_trace"] is not None:
        trace = arm["engine_trace"]
        raw_engine = data("engine-draws.json")
        need(sha(raw_engine) == trace["trace_sha256"], "Actual engine trace differs")
        captures = [r for r in json.loads(raw_engine)["frames"] if start <= r["submitted_usec"] <= end]
        deferred = sum(r["previous_batch_deferred_turns"] for r in captures[1:])
        need(len(captures) == trace["capture_draws"] and deferred == trace["capture_deferred_opportunities"],
             "Actual in-capture treatment differs")
        if arm["observers"]["presentation_enabled"]:
            joins = {(r["owner_instance"],r["submission_serial"],r["candidate_serial"]):r for r in captures}
            result = validate_transactions(json.loads(data("receipt-submissions.json")), json.loads(data("receipt-presentation.json")),receipt,joins)
            need(result == trace["application_join"], "Original submitted engine/application/probe join differs")
            joined = result["exact_engine_application_probe_joins"]
    return bodies, inputs, deferred, joined


def arm_metrics(arm, deferred, joined):
    first = arm["statistics"]["windows"]["first_144_steps"]
    whole = arm["statistics"]["windows"]["whole_capture"]
    observed = arm["observers"]["presentation"]["windows"]["whole_capture"]
    def p95_max(key):
        return [round(observed[key][q],3) for q in ("p95","max")]
    return {"steps_per_s": round(first["rapier_steps_per_second"],3),
            "physical_p95_p99_max_ms": [round(first["physical_gap_ms"][q],3) for q in ("p95","p99","max")],
            "gaps_above_100_250_500_1000_ms": [arm["statistics"]["physical_gap_counts_above_ms"]["first_144_steps"][str(n)] for n in GAPS],
            "whole_capture_no_step_prefix_suffix_ms":[whole["physical_no_step_prefix_ms"],whole["physical_no_step_suffix_ms"]],
            "material_p95_max_ms":p95_max("material_generation_age_at_submission_ms"),
            "verified_pose_p95_max_ms":p95_max("verified_first_part_completion_age_ms"),
            "withheld_body_submissions":observed["withheld_body_submissions"], "total_body_submissions":observed["body_submissions"],
            "whole_process_peak_rss_mib":round(arm["process"]["sampled_peak_rss_bytes"]/2**20,2),
            "whole_process_mean_cpu_cores":round(arm["observers"]["cpu"]["mean_cpu_core_equivalents"],3),
            "in_capture_deferrals":deferred, "engine_application_probe_joins":joined}


def replay(path):
    need(sha(path.read_bytes()) == ARCHIVE_SHA, "Supply the digest-bound original Windows artifact")
    out = {"schema":"pubpres-final-six-arm-supplement-v1", "source":SOURCE, "workflow_marker":"4035243c2b6ad449f3af9652578c33de7abdcfb2", "original_artifact":URL,
           "sha256":ARCHIVE_SHA, "water_composition":0, "source_qualification_run":46046627411,
           "scope":"Supplemental interpretation of original capture data. Hosted Windows ANGLE on Microsoft Basic Render Driver; no physical display qualification.",
           "body_comparison":"Only xy and velocity originate as single-precision Vector2. Preserve every other field exactly. Unequal printed components must be adjacent decimal representations with one exact binary32 midpoint. No epsilon.",
           "body_source":["godot/scripts/main.gd::_cadence_rapier_completed","godot/scripts/workbench_pose_trace.gd::xy","tools/pubpres_recovery_engine/engine.lock.json::precision=single"],
           "observer_calibration":{}, "order":["Stock Safe","Separate0","Separate4","Separate4","Separate0","Stock Safe"],"cases":{}}
    with zipfile.ZipFile(path) as z:
        rehydrated=json.loads(z.read("replay-custody/rehydration.json"))
        need(rehydrated["source"] == SOURCE and rehydrated["raw_admission_replayed"] is True, "Missing original admission")
        out["rehydration"] = {k:rehydrated[k] for k in ("inventory_sha256","water_off_sha256","native_sha256","stock_engine_sha256","custom_engine_sha256")}
        for group in ("calibration-stock","calibration-bounded","six-arms"):
            base = PurePosixPath("performance/bounded-water-off")/group
            report = json.loads(z.read(str(base/"SUMMARY.json")))
            registration = Path(__file__).with_name("registration.json").read_bytes()
            need(sha(registration) == report["registration_sha256"] and json.loads(registration) == report["registration"],
                 "Prospective registration changed")
            need(report["source"]["source_commit"] == SOURCE and report["water_composition"] == 0
                 and [c["case"] for c in report["cases"]] == CASES, "Original source/policy/cases differ")
            if group == "six-arms":
                need(report["order"] == ORDER and report["complete"] is False and report["failures"] == [
                    {"case":c, "reason":REFUSAL} for c in CASES], "Original strict trajectory failure changed")
                out["original_refusals"] = report["failures"]
            else:
                need(report["complete"] is True and not report["failures"], "Observer ABBA did not complete")
                out["observer_calibration"][group]={}
            for case in report["cases"]:
                name=case["case"]; arms=case["arms"]
                audited=[audit_arm(z,base/name/str(a["index"]),a) for a in arms]
                reference, inputs, _, _ = audited[0]
                need(all(moves==inputs for _,moves,_,_ in audited) and
                     len({a["statistics"]["first_144_admitted_moves_sha256"] for a in arms})==1, "Admitted input differs")
                changes=[compare_bodies(reference,bodies) for bodies,_,_,_ in audited]
                if group != "six-arms":
                    need(all(not any(counts.values()) for counts in changes), "Within-engine calibration body drift")
                    calibration=calibration_measurements(arms)
                    need(calibration==case["observer_calibration"], "Original observer analysis differs")
                    out["observer_calibration"][group][name]={"order":"off/on/on/off",
                        "on_over_off_rate_ratios":[round(r["physical_rate_ratio_on_over_off"],5) for r in calibration["all_cross_arm_ratios"]],
                        "on_over_off_gap_p95_ratios":[round(r["gap_ratio_on_over_off"]["p95"],5) for r in calibration["all_cross_arm_ratios"]]}
                    continue
                need(len(arms)==6 and [a["treatment"] for a in arms]==ORDER, "Incomplete or reordered six-arm treatment")
                need(len({vector_digest(bodies) for bodies,_,_,_ in audited}) == 1, "IEEE physical trajectories differ")
                metrics=[arm_metrics(a, aud[2], aud[3]) for a,aud in zip(arms,audited)]
                checks={}
                for label, indices in report["registration"]["comparisons"].items():
                    subset=[dict(arms[idx],index=i,arm="D" if i in (0,3) else "C") for i,idx in enumerate(indices)]
                    checks[label]=compare_registered_direction(subset)
                step, axis, stock_value, bounded_value = next(
                    (step, axis, x, y) for step, (a, b) in enumerate(zip(reference, audited[1][0]), 1)
                    for axis, (x, y) in enumerate(zip(a[0]["xy"], b[0]["xy"])) if x != y)
                out["cases"][name]={"raw_body_sha256_by_engine":{"stock":arms[0]["statistics"]["first_144_body_trajectory_sha256"],
                    "bounded":arms[1]["statistics"]["first_144_body_trajectory_sha256"]},"vector_bits_body_sha256":vector_digest(reference),
                    "admitted_moves_sha256":arms[0]["statistics"]["first_144_admitted_moves_sha256"],
                    "unequal_midpoint_components_vs_stock":changes,
                    "first_unequal_xy":{"observed_step":step, "axis":axis, "stock":str(stock_value),
                        "bounded":str(bounded_value), "exact_binary32":str(Decimal.from_float(struct.unpack(">f",binary32(stock_value))[0]))},
                    "arms":metrics,
                    "supplemental_registered_comparisons":checks,"product":product_gates(arms,report["registration"])["rows"]}
        need(all(not v["repeatable_direction"] for case in out["cases"].values()
                 for v in case["supplemental_registered_comparisons"].values()) and
             all(not p["passed"] for case in out["cases"].values() for p in case["product"]), "Selection contradicts registered trials")
        out["selection"]="Keep qualified Stock Safe. Both lookahead4 repeats actually deferred in both workloads, but neither workload meets either registered relative direction or both product targets. The original cross-engine JSON-hash refusal stands."
    return out


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive",type=Path)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    args.output.write_text(json.dumps(replay(args.archive),indent=2)+"\n",encoding="utf-8",newline="\n")
