#!/usr/bin/env python3
"""Strict reducer for WATER-CONTACT #362 `water_contact.submerged.v1`.

Applies every `water_contact.impact.v1` per-run invariant to the dynamic rows
(via reduce_impact_evidence.check_record), then the study gates: classifier
positive controls, zero oracle/adapter disagreement, nonvacuous observer
samples, configured-1/4 parity on the registered parity cases, and exact
quantity in kinematic descents. Missing, duplicate or unregistered rows fail.
Never repairs or reclassifies a row; exit status is nonzero on any failure.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import reduce_impact_evidence as impact  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "godot/tests/fixtures/water_contact/water_contact.submerged.v1.json"


def as_impact_manifest(manifest: dict) -> dict:
    """The per-run v1 checks read `cases`; the study names them `dynamic_cases`."""
    out = dict(manifest)
    out["cases"] = [dict(case) for case in manifest["dynamic_cases"]]
    return out


def expected(manifest: dict, stage: int) -> tuple[set, set]:
    parity = set(manifest["parity_cases"]["cases"])
    dynamic, kinematic = set(), set()
    for case in manifest["dynamic_cases"]:
        if int(case["stage"]) > stage:
            continue
        workers = manifest["parity_cases"]["workers"] if case["id"] in parity else manifest["workers"]
        for arm in case["arms"]:
            for count in workers:
                dynamic.add((case["id"], arm, int(count)))
    for descent in manifest["kinematic_descents"]:
        if int(descent["stage"]) > stage:
            continue
        for arm in descent["arms"]:
            kinematic.add((descent["id"], arm))
    return dynamic, kinematic


def bucket_share(table: dict, keys: tuple[str, ...]) -> float | None:
    total = sum(int(v) for v in table.values())
    return None if total == 0 else round(sum(int(table.get(k, 0)) for k in keys) / total, 4)


def summarize_dynamic(record: dict) -> dict:
    obs = record.get("observer", {})
    results = record.get("relocation", {}).get("results", {})
    masked = results.get("masked_water_cells", {})
    reasons = obs.get("reasons", {})
    return {
        "case": record["case"], "arm": record["arm"], "workers": record["workers_configured"],
        "displaced": results.get("displaced"), "unresolved_overlap_ticks": results.get("unresolved"),
        "masked_water_p50": masked.get("p50"), "masked_water_max": masked.get("max"),
        "classifier_samples": obs.get("samples"), "residual_cell_samples": obs.get("residual_cell_samples"),
        "reasons": reasons, "normal_kind_reasons": obs.get("normal_kind_reasons"),
        "no_empty_within_reach_share": bucket_share(reasons, ("no_empty_within_reach",)),
        "lateral_share": bucket_share({k: v for k, v in obs.get("normal_kind_reasons", {}).items()},
                                      tuple(k for k in obs.get("normal_kind_reasons", {}) if k.startswith("lateral"))),
        "required_straight_reach": obs.get("required_straight_reach"),
        "push_chain_length": obs.get("push_chain_length"),
        "chain_within_4_share": bucket_share(obs.get("push_chain_length", {}), ("1-4",)),
        "trail_cell_samples": obs.get("trail_cell_samples"), "trail_reasons": obs.get("trail_reasons"),
        "floor_contact_tick": record.get("boundary", {}).get("floor_contact_tick"),
        "peak_height": record.get("peaks", {}).get("height"),
        "trace_sha256": record.get("trace_sha256"),
        "final_physical_state_hash": record.get("final", {}).get("physical_state_hash"),
    }


def reduce(path: Path, manifest_path: Path, stage: int) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    digest = impact.manifest_digest(manifest_path)
    v1 = as_impact_manifest(manifest)
    errors: list[str] = []
    dynamic: dict = {}
    kinematic: dict = {}
    index = None
    for file in sorted(path.glob("*.json")):
        try:
            value = json.loads(file.read_text(encoding="utf-8"))
        except ValueError as exc:
            errors.append(f"{file.name}: unreadable JSON: {exc}")
            continue
        if file.name == "index.json":
            index = value
        elif file.name == "reduction.json":
            continue
        elif value.get("schema") == impact.RECORD_SCHEMA:
            key = (value.get("case"), value.get("arm"), value.get("workers_configured"))
            if key in dynamic:
                errors.append(f"duplicate dynamic row {key}")
            dynamic[key] = value
        elif value.get("schema") == "water-contact-kinematic-descent-v1":
            key = (value.get("descent_id"), value.get("arm"))
            if key in kinematic:
                errors.append(f"duplicate kinematic row {key}")
            kinematic[key] = value
        else:
            errors.append(f"{file.name}: unknown evidence file")
    want_dynamic, want_kinematic = expected(manifest, stage)
    for key in sorted(want_dynamic - set(dynamic)):
        errors.append(f"missing dynamic row {key}")
    for key in sorted(set(dynamic) - want_dynamic):
        errors.append(f"unregistered dynamic row {key}")
    for key in sorted(want_kinematic - set(kinematic)):
        errors.append(f"missing kinematic row {key}")
    for key in sorted(set(kinematic) - want_kinematic):
        errors.append(f"unregistered kinematic row {key}")

    # Positive controls (recorded in the index by the runner).
    controls = [row for row in (index or {}).get("rows", []) if row.get("kind") == "positive_control"]
    arms = {arm["id"] for arm in manifest["arms"]}
    if index is None:
        errors.append("index.json missing")
    elif {row.get("arm") for row in controls} != arms or not all(row.get("ok") for row in controls):
        errors.append("classifier positive control missing or failed")
    if index is not None and index.get("manifest_sha256") != digest:
        errors.append("index manifest hash differs")

    for key, record in sorted(dynamic.items()):
        errors.extend(impact.check_record(record, v1, digest))
        obs = record.get("observer")
        if not isinstance(obs, dict):
            errors.append(f"{key}: observer summary missing")
            continue
        if int(obs.get("oracle_admissible", 1)) != 0:
            errors.append(f"{key}: classifier/adapter disagreement {obs.get('oracle_admissible')}")
        if int(obs.get("samples", 0)) < 1:
            errors.append(f"{key}: classifier never sampled")
        if not record.get("study_ok"):
            errors.append(f"{key}: runner study_ok false")
    parity = []
    for case_id in manifest["parity_cases"]["cases"]:
        for arm in next(c for c in manifest["dynamic_cases"] if c["id"] == case_id)["arms"]:
            one, four = dynamic.get((case_id, arm, 1)), dynamic.get((case_id, arm, 4))
            if one is None or four is None:
                continue
            same = (one.get("trace_sha256") == four.get("trace_sha256")
                    and one.get("final", {}).get("physical_state_hash") == four.get("final", {}).get("physical_state_hash")
                    and one.get("observer") == four.get("observer"))
            parity.append({"case": case_id, "arm": arm, "identical": same})
            if not same:
                errors.append(f"worker parity failed {case_id}/{arm}")
    descents = []
    for key, row in sorted(kinematic.items()):
        if row.get("manifest_sha256") != digest:
            errors.append(f"{key}: manifest hash differs")
        quantity = row.get("quantity", {})
        if not row.get("ok") or quantity.get("before") != quantity.get("after") \
                or int(row.get("observer", {}).get("oracle_admissible", 1)) != 0:
            errors.append(f"{key}: kinematic descent failed {row.get('error', '')}")
        if not row.get("runtime", {}).get("runtime_matches_provenance"):
            errors.append(f"{key}: runtime does not match provenance")
        steps = row.get("steps", [])
        descents.append({"descent": key[0], "arm": key[1], "rate": row.get("rate"), "tick_liquid": row.get("tick_liquid"),
                         "body_size": row.get("body_size"), "steps": len(steps),
                         "deepest_relocating_body_top": row.get("deepest_relocating_body_top"),
                         "displaced_total": sum(int(s[1]) for s in steps),
                         "displaced_by_top_depth": {str(s[0]): s[1] for s in steps if float(s[0]) in
                                                    (-2.0, 0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 16.0, 24.0, 48.0, 72.0)},
                         "final_residual_masked": steps[-1][3] if steps else None,
                         "reasons": row.get("observer", {}).get("reasons"),
                         "push_chain_length": row.get("observer", {}).get("push_chain_length")})
    return {"schema": "water-contact-submerged-reduction-v1", "manifest_sha256": digest, "stage": stage,
            "dynamic_rows": len(dynamic), "kinematic_rows": len(kinematic), "positive_controls": controls,
            "parity": parity, "rows": [summarize_dynamic(r) for _, r in sorted(dynamic.items())],
            "descents": descents, "errors": errors, "status": "failed" if errors else "passed"}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packet", type=Path)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--stage", type=int, default=2)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    report = reduce(args.packet, args.manifest, args.stage)
    if args.out:
        args.out.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"status": report["status"], "errors": report["errors"][:30],
                      "dynamic_rows": report["dynamic_rows"], "kinematic_rows": report["kinematic_rows"]}, indent=2))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
