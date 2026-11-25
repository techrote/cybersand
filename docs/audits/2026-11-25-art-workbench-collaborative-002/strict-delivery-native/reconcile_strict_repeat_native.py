#!/usr/bin/env python3
"""Compare actual delivery-native originals with the preserved qualified bcc run.

Read-only evidence reduction: no native/model process and no original archive upload.
Use the separately pinned raw material/receipt verifier first for each input mode.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

SOURCE = "d503d824aac4128968f7dfba5dccd540c3c07b59"
TREE = "464c60288d5461d61578b000ae68ac029cffb5bd"
BASELINE = "bcc92927ce3894a16d5544923cfbf7b1d0339fda"
BASELINE_TREE = "517164084860a19f18b36cb94f77597eb3220578"
DELTA = {"docs/operations/art-workbench-collaborative-evaluation.md",
         "tools/package_art_collaborative.py", "tools/ci/test_art_collaborative_packaging.py",
         "docs/audits/2026-11-25-art-workbench-collaborative-002/README.md"}
RAW_VERIFIER_SHA = "64292c1a48babae89b51e0dfa2c99792c29e9f2f813962294da8fc6d8c4536a9"


def read(path: Path):
    return json.loads(path.read_bytes())


def sha(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--review-dir", type=Path, required=True)
    p.add_argument("--candidate-root", type=Path, required=True)
    p.add_argument("--baseline-extraction", type=Path, required=True)
    p.add_argument("--source-repo", type=Path, required=True)
    p.add_argument("--platform", choices=["linux", "windows"], required=True)
    a = p.parse_args()
    counts = Counter()
    failures = []

    def check(category, condition, message):
        counts[category] += 1
        if not condition:
            failures.append(category + ": " + message)

    def git(*argv):
        return subprocess.check_output(["git", "-C", str(a.source_repo), *argv])

    metadata = read(a.review_dir / "repeat-artifact-metadata.json")
    artifact = next(v for v in metadata["artifacts"] if v["name"] == f"art-workbench-{a.platform}{'-evidence' if a.platform == 'windows' else ''}-{SOURCE}")
    archive = a.candidate_root / "evidence-artifact.zip"
    check("artifact", metadata["source"] == SOURCE and metadata["tree"] == TREE and metadata["campaign"] == 45556633896 and artifact["source"] == SOURCE, "refreshed API source identity")
    check("artifact", archive.stat().st_size == artifact["bytes"] and sha(archive) == artifact["sha256"], "original outer size and SHA")
    with zipfile.ZipFile(archive) as z:
        check("artifact", len(z.namelist()) == len(set(z.namelist())) and z.testzip() is None, "original outer members and all CRCs")
        original_member_count = len(z.namelist())
    check("source", git("rev-parse", f"{BASELINE}^{{tree}}").decode().strip() == BASELINE_TREE, "baseline tree")
    check("source", set(git("diff", "--name-only", BASELINE, TREE).decode().splitlines()) == DELTA, "exact guide/package plus one-ledger four-file delta")
    fixture_path = "godot/tests/test_art_collaborative_native.gd"
    fixture_before = git("show", f"{BASELINE}:{fixture_path}")
    fixture_after = git("show", f"{TREE}:{fixture_path}")
    check("source", fixture_before == fixture_after, "native qualification fixture unchanged")
    check("source", sha(a.review_dir / "verify_art_creative_native_evidence.py") == RAW_VERIFIER_SHA, "independent raw verifier unchanged")

    outputs = []
    stable = ("id", "title", "region", "stages", "before_materials_sha256", "after_materials_sha256",
              "native_changed", "native_checked", "preview_changed", "constraint_preservation",
              "static_clearance", "proposal", "source_before", "source_after")
    direct_fields = ("arm", "region", "native_changed", "native_checked", "material_sha256", "complete_material_plane_matches")
    for mode, graphical in [("headless", False), ("displayed", True)]:
        root = a.candidate_root / "extracted" / ("art-collaborative-" + mode)
        before_root = a.baseline_extraction / ("art-collaborative-" + mode)
        campaign = read(root / "summary.json")
        before_campaign = read(before_root / "summary.json")
        summary = read(root / "test_art_collaborative_native/creative-native-summary.json")
        before_summary = read(before_root / "test_art_collaborative_native/creative-native-summary.json")
        replay_path = a.review_dir / f"final-d503-{a.platform}-{mode}-raw-review.json"
        replay = read(replay_path)
        expected_source = {"commit": SOURCE, "tree": TREE, "tracked_source_clean": True}
        check("source", campaign["source"] == expected_source and replay["source"] == expected_source, mode + " exact fresh candidate identity")
        check("source", before_campaign["source"] == {"commit": BASELINE, "tree": BASELINE_TREE, "tracked_source_clean": True}, mode + " preserved bcc source")
        check("execution", campaign["status"] == before_campaign["status"] == "passed" and campaign["platform"] == a.platform and campaign["graphical"] == graphical and campaign["model_calls"] == 0, mode + " original campaign outcome/scope")
        check("runtime", campaign["runtime"] == before_campaign["runtime"], mode + " complete recorded runtime identity unchanged")
        for path, materialized_sha in campaign["runtime"]["payloads"].items():
            pointer = git("show", f"{TREE}:{path}").decode()
            check("runtime", f"oid sha256:{materialized_sha}\n" in pointer, mode + " runtime/source LFS identity: " + path)
        case = next(v for v in campaign["cases"] if v["name"] == "test_art_collaborative_native")
        before_case = next(v for v in before_campaign["cases"] if v["name"] == "test_art_collaborative_native")
        check("execution", case["status"] == "passed" and case["exit_code"] == 0 and not case["timed_out"] and case["result"]["failures"] == 0, mode + " actual native completion")
        check("raw_replay", replay["status"] == "passed" and replay["scenarios"] == 9 and replay["stages"] == 25 and replay["verified_readback_rows"] == 377234 and replay["native_changed_per_arm"] == 184396, mode + " complete independently verified actual work")
        check("raw_replay", len(replay["verified_original_files"]) == (73 if graphical else 55), mode + " original native file denominator")
        check("execution", summary["failures"] == 0 and summary["scenarios"] == len(summary["outcomes"]) == 9 and summary["model_requests"] == 0, mode + " native fixture cohort")
        before_rows = {r["id"]: r for r in before_summary["outcomes"]}
        scenes = []
        totals = Counter()
        for row in summary["outcomes"]:
            prior = before_rows[row["id"]]
            for field in stable:
                check("geometry", row[field] == prior[field], mode + " " + row["id"] + " " + field)
            check("geometry", row["preview"]["stages"] == prior["preview"]["stages"], mode + " " + row["id"] + " all predicted stage planes/counters")
            check("geometry", row["preview"]["zero_native_writes"] and row["preview"]["ok"] and row["preview"]["conflict_count"] == 0, mode + " " + row["id"] + " preview admission")
            for field in direct_fields:
                check("geometry", row["comparisons"][0][field] == prior["comparisons"][0][field], mode + " " + row["id"] + " matched direct " + field)
            check("geometry", row["comparisons"][1]["same_predicted_material_plane"] and row["comparisons"][1]["model_calls"] == 0, mode + " frozen-proposal ablation scope")
            totals.update({"changed": row["native_changed"], "checked": row["native_checked"], "stages": row["stages"], "staged_chunks": row["native_chunks"], "direct_chunks": row["comparisons"][0]["native_chunks"]})
            scenes.append({"id": row["id"], "stages": row["stages"], "region": row["region"], "before_materials_sha256": row["before_materials_sha256"], "after_materials_sha256": row["after_materials_sha256"], "changed_per_arm": row["native_changed"], "checked_per_arm": row["native_checked"], "native_source_before": row["source_before"], "native_source_after": row["source_after"], "same_bcc_geometry_and_native_source_endpoints": True})
        prior_staged = sum(v["native_chunks"] for v in before_rows.values())
        prior_direct = sum(v["comparisons"][0]["native_chunks"] for v in before_rows.values())
        expected_checks = before_case["result"]["checks"] + 2 * (totals["staged_chunks"] - prior_staged) + totals["direct_chunks"] - prior_direct
        check("execution", case["result"]["checks"] == expected_checks == summary["checks"] + 1, mode + " dynamic chunk-dependent assertions unchanged")
        check("geometry", totals["changed"] == 184396 and totals["checked"] == 188617 and totals["stages"] == 25, mode + " native totals")
        outputs.append({"mode": mode, "original_terminal_checks": case["result"]["checks"], "verified_original_files": len(replay["verified_original_files"]), "verified_readback_rows": replay["verified_readback_rows"], "counts": dict(totals), "runtime": campaign["runtime"], "runtime_matches_bcc": True, "raw_review_sha256": sha(replay_path), "native_summary_sha256": sha(root / "test_art_collaborative_native/creative-native-summary.json"), "process_log_sha256": sha(root / "test_art_collaborative_native/process.log"), "scenes": scenes})
    result = {"schema": "art-strict-repeat-native-independent-comparison-v1", "passed": not failures, "checks": sum(counts.values()), "checks_by_category": dict(counts), "failures": failures, "source": SOURCE, "tree": TREE, "baseline_source": BASELINE, "baseline_tree": BASELINE_TREE, "platform": a.platform, "campaign": metadata["campaign"], "original_artifact": artifact, "original_archive_members_crc_checked": original_member_count, "raw_verifier_sha256": RAW_VERIFIER_SHA, "comparison_script_sha256": sha(Path(__file__)), "native_fixture_sha256": hashlib.sha256(fixture_after).hexdigest(), "exact_delta": sorted(DELTA), "outcomes": outputs, "limits": ["Read-only original-byte and Git-object review; no application/native/model rerun.", "Recorded engine/native/Rapier identities match bcc; original measurement archives do not contain standalone executable binaries.", "This comparison reuses unchanged independently authored material/receipt replay, not a mock World mutation.", "Nine distinct scenes are repeated across modes/platforms; observations are not new creative briefs.", "Static clear cells and stored material do not prove actor traversal, structural stability or LLM creativity.", "Scenario boundary native source identities also match bcc; intermediate chunk revisions are validated within each campaign and are not asserted equal across different chunk groupings.", "Geometry matches; differing host timing is not a causal performance comparison.", "Portable package launch and physical owner acceptance are separately qualified."]}
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if not failures else 1)


if __name__ == "__main__":
    main()
