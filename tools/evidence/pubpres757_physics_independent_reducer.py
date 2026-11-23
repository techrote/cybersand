#!/usr/bin/env python3
"""Independent raw trace reducer for PUBPRES #757 Wave512 physics ABBA.

Read the original Windows artifact; insist on real unique-callback Rapier steps,
unmodified frozen application source, physical equal-step body/input parity,
unchanged Full material/current GPU, exact early/combined/combined/early order.
Never interpret CPU upload timing as GPU completion or physical NVIDIA acceptance.
"""
import argparse, hashlib, json, math, zipfile
from pathlib import Path

SOURCE = "c90dbc46e1f57f28e06b1f4205b83467335ff657"
ORDER = ("early", "combined", "combined", "early")
CASE = "wave_512_follow"


def need(condition, message):
    if not condition: raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def q(values, fraction):
    values = sorted(values)
    need(values, "missing measured gaps")
    loc = (len(values) - 1) * fraction
    return values[math.floor(loc)] + (values[math.ceil(loc)]-values[math.floor(loc)])*(loc-math.floor(loc))


def reduce(path):
    with zipfile.ZipFile(path) as archive:
        need(archive.testzip() is None, "Corrupt source artifact ZIP")
        summary_files = [p for p in archive.namelist() if p.endswith("wave512/summary.json")]
        need(len(summary_files) == 1, "Ambiguous original summary")
        prefix = summary_files[0][:-len("summary.json")]
        summary = json.loads(archive.read(summary_files[0]))
        identity = json.loads(archive.read("IDENTITY.json"))
        need(identity["frozen_application_source"] == SOURCE, "Wrong frozen application")
        need(identity["treatment_order"] == list(ORDER), "Wrong physics experiment")
        need(summary["complete"] and not summary["failures"], "Incomplete original capture")
        need(summary["source"]["source_commit"] == SOURCE, "Changed tested application")
        need(summary["material"] == "full", "Non-Full material")
        need(len(summary["cases"]) == 1 and summary["cases"][0]["case"] == CASE, "Wrong source fixture")
        cohort = summary["cases"][0]
        need(cohort["physical_outcome_parity"]["same_source_pairs_equal"], "Equal-step physical outcome parity failed")
        arms = sorted(cohort["arms"], key=lambda x:x["index"])
        need(len(arms) == 4 and [a["index"] for a in arms] == list(range(4)), "Incomplete original ABBA")
        reported = []
        body_hashes, move_hashes, matches = [], [], []
        for i, arm in enumerate(arms):
            folder = f"{prefix}{CASE}/{i}-C/"
            raw_receipt = archive.read(folder+"receipt.json")
            raw_trace = archive.read(folder+"receipt-events.jsonl")
            receipt = json.loads(raw_receipt)
            analysis = json.loads(archive.read(folder+"analysis.json"))
            request = json.loads(archive.read(folder+"arm.json"))
            need(sha(raw_receipt) == arm["receipt_sha256"], "Original receipt SHA mismatch")
            need(sha(raw_trace) == analysis["trace_sha256"], "Original trace SHA mismatch")
            need(receipt["source_identity"]["source_sha"] == SOURCE, "Unexpected receipt source")
            need(request["source"]["source_commit"] == SOURCE, "Unexpected arm source")
            need(request["arm"]["material"] == "full" and request["arm"]["physics_mode"] == ORDER[i], "Arm selector mismatch")
            need(request["arm"]["same_frame_continuation"] is False, "Continuation enabled")
            need(request["selectors"]["CYBERSAND_DIAG_PHYSICS_PUBLICATION"] == ORDER[i], "Requested physics selector mismatch")
            for key in ("selectors_before","selectors_after"):
                selected=receipt[key]
                need(selected["physics"] == ORDER[i], "Effective physics selector mismatch")
                need(selected["presentation"] == "coherent", "Presentation selector changed")
                need(selected["material"]["backend"] == "full", "Material backend changed")
            need(analysis["gpu_history"]["current_matches_cpu"] is True, "Current GPU history differs from CPU")
            win = analysis["windows"]["first_144_steps"]
            need(win["completed_rapier_steps"] == win["completed_native_ticks"] == 144, "Missing real steps")
            events = [json.loads(row) for row in raw_trace.splitlines() if row]
            callbacks = {e["callback_id"] for e in events if e.get("event") == "physics_callback"}
            steps = sorted((e for e in events if e.get("event") == "rapier_step"
                and win["start_usec"] <= e["time_usec"] <= win["end_usec"]),key=lambda e:e["step"])
            need(len(steps) == 144 and [e["step"] for e in steps] == list(range(1,145)), "Not 144 contiguous genuine steps")
            need(len({e["origin_callback_id"] for e in steps}) == 144, "Reused physics callback credit")
            need(all(e["execution_kind"] == "physics_callback" and
                e["origin_callback_id"] in callbacks and e["response_accepted"] and e["manual_steps"] == 1
                for e in steps), "Non-real step credit")
            gaps = [(b["time_usec"]-a["time_usec"])/1000 for a,b in zip(steps, steps[1:])]
            need(len(gaps) == win["physical_gap_ms"]["count"] == 143, "Wrong genuine gap count")
            for name,fraction in (("p50",.5),("p95",.95),("p99",.99)):
                need(abs(q(gaps,fraction)-win["physical_gap_ms"][name]) < .002, "Reported gap quantile mismatches original")
            need(abs(max(gaps)-win["physical_gap_ms"]["max"]) < .002, "Reported worst gap mismatches original")
            uploads = [e for e in events if e.get("event") == "texture_upload"]
            need(uploads and all(e["material"]["backend"] == "full" for e in uploads), "Missing/incorrect Full uploads")
            body_hashes.append(analysis["first_144_body_trajectory_sha256"])
            move_hashes.append(analysis["first_144_admitted_moves_sha256"])
            matches.append(analysis["match"])
            reported.append({
                "arm":i, "physics":ORDER[i], "completed_real_rapier_steps":144,
                "real_steps_per_sec":win["rapier_steps_per_second"],
                "physical_gap_p50_ms":q(gaps,.5),"physical_gap_p95_ms":q(gaps,.95),
                "physical_gap_p99_ms":q(gaps,.99),"physical_gap_max_ms":max(gaps),
                "gaps_above_250ms":sum(g>250 for g in gaps),
                "gaps_above_500ms":sum(g>500 for g in gaps),
                "full_backend_submit_p95_ms":q([e["material"]["backend_submit_usec"]/1000 for e in uploads],.95),
                "gpu_current_equals_cpu":True, "gpu_previous_verified_in_this_experiment":analysis["gpu_history"].get("previous_verified",False) is True,
                "receipt_sha256":sha(raw_receipt), "trace_sha256":sha(raw_trace)
            })
        need(len(set(body_hashes)) == len(set(move_hashes)) == 1, "Physical trajectory/commands changed at equal steps")
        need(all(json.dumps(m,sort_keys=True) == json.dumps(matches[0],sort_keys=True) for m in matches), "Host/fixture/tape differs")
        a=[reported[0],reported[3]]
        b=[reported[1],reported[2]]
        verdict={
            "combined_rates_better_than_both_early":all(x["real_steps_per_sec"]>y["real_steps_per_sec"] for x in b for y in a),
            "combined_p95_better_than_both_early":all(x["physical_gap_p95_ms"]<y["physical_gap_p95_ms"] for x in b for y in a),
            "combined_p99_better_than_both_early":all(x["physical_gap_p99_ms"]<y["physical_gap_p99_ms"] for x in b for y in a),
            "combined_worst_no_worse":max(x["physical_gap_max_ms"] for x in b)<=max(y["physical_gap_max_ms"] for y in a),
            "combined_above_250_no_worse":max(x["gaps_above_250ms"] for x in b)<=max(y["gaps_above_250ms"] for y in a),
            "combined_above_500_no_worse":max(x["gaps_above_500ms"] for x in b)<=max(y["gaps_above_500ms"] for y in a),
        }
        return {"schema":"pubpres757-independent-physics-abba-v1","frozen_application_source":SOURCE,
                "artifact":path.name,"body_trajectory_sha256":body_hashes[0],
                "admitted_moves_sha256":move_hashes[0],"arms":reported,"strict_direction":verdict,
                "candidate_direction":"ESTABLISHED_ON_TEST_HOST" if all(verdict.values()) else "NOT_ESTABLISHED",
                "physical_owner_nvidia_acceptance":"HOLD",
                "limitations":"CPU submission != GPU completion/scanout. Hosted Windows ANGLE is not physical Windows NVIDIA. Equal-step physical parity is not uninterrupted real-time playability."}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip",type=Path)
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    result=json.dumps(reduce(args.zip),indent=2)+"\n"
    if args.output: args.output.write_text(result)
    print(result)


if __name__ == "__main__":main()
