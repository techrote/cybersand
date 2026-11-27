#!/usr/bin/env python3
"""Independent raw-position/selection readback of the completed supplement."""
import argparse
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--comparison", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    raw = json.loads(args.report.read_text())
    comparison = json.loads(args.comparison.read_text())
    assert raw["complete"] and raw["completed_actor_episodes"] == 6 and not raw["qualifies_primary_programme"]
    assert comparison["report_sha256"] == sha(args.report)
    assert raw["source_identity"]["source_revision"] == "a7250e15495667b2fcf564cbed1eaa8dea217c45"
    by_case = {(c["seed"], c["arm"]): c for c in raw["campaigns"]}
    assert len(by_case) == 6
    count = 0

    def same(a, b):
        nonlocal count
        count += 1
        assert math.isfinite(a) and math.isfinite(b) and abs(a-b) < 1e-8, (a, b)

    pairs = []
    position_hashes = {"low": [], "high": []}
    for pair in comparison["pairs"]:
        seed = pair["seed"]
        rows = {arm: by_case[seed, arm+"_curiosity"]["episodes"][0] for arm in ("low", "high")}
        low_profile = deepcopy(rows["low"]["profile"])
        high_profile = deepcopy(rows["high"]["profile"])
        assert low_profile["personality"].pop("curiosity") == 0
        assert high_profile["personality"].pop("curiosity") == 1
        assert low_profile == high_profile
        computed = {}
        for arm, row in rows.items():
            trace = row["trace"]
            assert len(trace) == 300 and row["accepted_commands"] == 300 and row["rejected_commands"] == 0
            first = trace[0]
            assert first["oil"]["available"] and first["oil"]["present"]
            assert first["policy_oil"]["available"] and first["policy_oil"]["present"]
            samples = trace[:100]
            assert [round(s["seconds"], 5) for s in samples] == [round(i/10, 5) for i in range(100)]
            reference_x = first["oil"]["nearest"][0]
            xs = [s["position"][0] for s in samples]
            value = {
                "investigation_seconds": len([s for s in samples if s["selection"] == "discovery"])/10,
                "horizontal_approach_gain_cells": abs(xs[0]-reference_x)-min(abs(x-reference_x) for x in xs),
                "net_x_cells": xs[-1]-xs[0], "x_range_cells": max(xs)-min(xs),
            }
            for key, number in value.items(): same(number, pair[arm][key])
            candidates = {c["id"]: c for c in first["candidates"]}
            same(candidates["discovery"]["score"], 1.4 if arm == "high" else .1)
            same(candidates["routine"]["score"], .45)
            position_hashes[arm].append(hashlib.sha256(json.dumps([s["position"] for s in trace]).encode()).hexdigest())
            computed[arm] = value
        assert rows["low"]["trace"][0]["oil"] == rows["high"]["trace"][0]["oil"]
        assert rows["low"]["trace"][0]["policy_oil"] == rows["high"]["trace"][0]["policy_oil"]
        for key in computed["low"]:
            same(computed["high"][key]-computed["low"][key], pair["high_minus_low"][key])
        high = rows["high"]["trace"]
        inspection = [s for s in high if s["selection"] == "discovery" and s["phase"] == "inspect"]
        late = [s for s in high if 17 <= s["seconds"] < 24.3-1e-8]
        phases = [{"seconds": s["seconds"], "selection": s["selection"], "goal_key": s["goal_key"],
                   "policy_oil": s["policy_oil"], "candidate_scores": {c["id"]: c["score"] for c in s["candidates"]}}
                  for s in high if 17.0-1e-8 <= s["seconds"] <= 17.4+1e-8]
        pairs.append({"seed": seed, "primary": computed,
            "inspection": {"first_seconds": inspection[0]["seconds"], "sampled_seconds": len(inspection)/10,
                "x_range_cells": max(s["position"][0] for s in inspection)-min(s["position"][0] for s in inspection),
                "centre_path_between_inspection_samples_cells": sum(math.dist(a["position"], b["position"])
                    for a, b in zip(inspection, inspection[1:]))},
            "late_selected_goal_identities": sorted({s["selection"]+":"+s["goal_key"] for s in late}),
            "same_goal_competition_example": phases,
            "final_interest_entries": rows["high"]["final_memory"]["interests"],
            "explicit_habituated_candidate_samples": sum("habituated" in c.get("reason", "")
                for s in high for c in s["candidates"] if c["id"] == "discovery")})
    result = {"schema": "ambient2-curiosity-independent-readback/v1", "status": "PASS",
        "source_revision": raw["source_identity"]["source_revision"], "numeric_comparisons": count,
        "actual_completed_supplementary_episodes": 6, "qualifies_primary_programme": False,
        "report_sha256": sha(args.report), "comparison_sha256": sha(args.comparison),
        "reviewer_sha256": sha(__file__), "pairs": pairs,
        "position_sequences_identical_across_declared_seeds": {arm: len(set(hashes)) == 1
            for arm, hashes in position_hashes.items()},
        "position_sequence_sha256": position_hashes,
        "interpretation": "One geometry and deterministic goal competition, repeated in fresh Worlds under three declared seeds. "
            "These are not independent stochastic choices, general personality-quality evidence or owner playfeel acceptance."}
    args.output.write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps({"status": "PASS", "numeric_comparisons": count, "episodes": 6, "output": str(args.output)}))


if __name__ == "__main__":
    main()
