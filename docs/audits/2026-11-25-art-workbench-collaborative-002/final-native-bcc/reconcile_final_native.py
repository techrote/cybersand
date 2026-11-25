#!/usr/bin/env python3
"""Independently reconcile immutable native campaign and Apply replay records.

Reads existing source, records and original native receipt arrays. It does not
load Godot, invoke a model or mutate a World. JSON stdout is the only output.
"""
from pathlib import Path
import argparse
import hashlib
import json
import platform
import sys

SOURCE = "bcc92927ce3894a16d5544923cfbf7b1d0339fda"
TREE = "517164084860a19f18b36cb94f77597eb3220578"
OLD = "2743f89a0df6f6afcf7484e859c10790d521e74b"
ARTIFACTS = {
    "linux": (14992946063, "art-bcc-linux-original-evidence.zip", 17148660,
              "7ff9971f911a1b417582f05a929fdda021b2d536a78eb6434e002c172676d59a"),
    "windows": (14993247449, "evidence-artifact.zip", 12820321,
                "45df2fecb95f21fe769f15202d15411156b658d7670e249f76e4b6877f9b3f47"),
}
checks = 0
failures = []


def check(ok, label):
    global checks
    checks += 1
    if not ok:
        failures.append(label)


def sha(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def verify(review, artifact, native_platform):
    old_path = review / "creative-native-summary-2743.json"
    old = read(old_path)
    baseline = {row["id"]: row for row in old["outcomes"]}
    check(len(baseline) == old["scenarios"] == 9 and old["failures"] == 0, "Original cohort")
    check(old["checks"] == 770, "Original saved-summary count")
    check((review/"native-test-bcc.gd").read_bytes() == (review/"native-test-2743.gd").read_bytes(),
          "Native test source remains byte-identical")
    original_staged = sum(row["native_chunks"] for row in baseline.values())
    original_direct = sum(row["comparisons"][0]["native_chunks"] for row in baseline.values())
    artifact_id, archive_name, archive_bytes, archive_sha = ARTIFACTS[native_platform]
    archive = artifact.parent / archive_name
    check(archive.stat().st_size == archive_bytes and sha(archive) == archive_sha, "Final original artifact")
    stable = ("id", "title", "region", "stages", "before_materials_sha256",
              "after_materials_sha256", "native_changed", "native_checked",
              "preview_changed", "constraint_preservation", "static_clearance",
              "proposal", "source_before", "source_after")
    direct_stable = ("arm", "region", "native_changed", "native_checked",
                     "material_sha256", "complete_material_plane_matches")
    outputs = []
    for mode, graphical in (("displayed", True), ("headless", False)):
        campaign_root = artifact / ("art-collaborative-"+mode)
        native = campaign_root / "test_art_collaborative_native"
        campaign = read(campaign_root / "summary.json")
        summary = read(native / "creative-native-summary.json")
        platform_prefix = "windows-" if native_platform == "windows" else ""
        replay_path = review / ("final-bcc-"+platform_prefix+mode+"-raw-review.json")
        replay = read(replay_path)
        check(campaign["source"] == {"commit": SOURCE, "tree": TREE, "tracked_source_clean": True},
              mode+" exact application source")
        check(campaign["status"] == "passed" and campaign["graphical"] == graphical
              and campaign["platform"] == native_platform
              and campaign["model_calls"] == 0, mode+" campaign scope")
        case = next(row for row in campaign["cases"] if row["name"] == "test_art_collaborative_native")
        check(case["status"] == "passed" and case["exit_code"] == 0 and not case["timed_out"],
              mode+" native completed")
        check(summary["scenarios"] == 9 and summary["model_requests"] == 0 and summary["failures"] == 0,
              mode+" native cohort")
        check(replay["status"] == "passed" and replay["source"] == campaign["source"]
              and replay["scenarios"] == 9 and replay["stages"] == 25,
              mode+" independent raw replay source")
        check(replay["verified_readback_rows"] == 377234 and replay["native_changed_per_arm"] == 184396,
              mode+" exact raw work denominator")
        check(len(replay["verified_original_files"]) == (73 if graphical else 55),
              mode+" original-file denominator")
        scene_rows = []
        staged_chunks = direct_chunks = changed = checked = max_chunk = 0
        for index, row in enumerate(summary["outcomes"]):
            prior = baseline[row["id"]]
            for field in stable:
                check(row[field] == prior[field], mode+" "+row["id"]+" stable "+field)
            check(row["preview"]["stages"] == prior["preview"]["stages"],
                  mode+" "+row["id"]+" exact per-stage prediction planes/counters")
            check(row["preview"]["zero_native_writes"] and row["preview"]["ok"]
                  and row["preview"]["conflict_count"] == 0, mode+" preview scope")
            check(row["comparisons"][1]["same_predicted_material_plane"]
                  and row["comparisons"][1]["model_calls"] == 0, mode+" frozen ablation scope")
            direct = row["comparisons"][0]
            for field in direct_stable:
                check(direct[field] == prior["comparisons"][0][field],
                      mode+" "+row["id"]+" direct "+field)
            prefix = f"{index:02d}-{row['id']}"
            for suffix, declared in (("-original-native-receipts.json", row["native_chunks"]),
                                     ("-direct-original-native-receipts.json", direct["native_chunks"])):
                receipts = read(native / (prefix+suffix))
                check(len(receipts) == declared, mode+" "+prefix+suffix+" chunks")
                maximum = max(receipt["checked"] for receipt in receipts)
                check(0 < maximum <= 4096, mode+" "+prefix+suffix+" bounded chunks")
                max_chunk = max(max_chunk, maximum)
            staged_chunks += row["native_chunks"]
            direct_chunks += direct["native_chunks"]
            changed += row["native_changed"]
            checked += row["native_checked"]
            scene_rows.append({"id": row["id"], "stages": row["stages"],
                               "before_materials_sha256": row["before_materials_sha256"],
                               "after_materials_sha256": row["after_materials_sha256"],
                               "native_changed_per_arm": row["native_changed"],
                               "native_checked_per_arm": row["native_checked"],
                               "staged_chunks": row["native_chunks"],
                               "direct_chunks": direct["native_chunks"],
                               "same_original_material_geometry": True})
        # Source has two checks per actual staged receipt and one per actual
        # direct receipt. Graphical mode adds before/after screenshot checks.
        expected_summary = old["checks"] + 2*(staged_chunks-original_staged) + (direct_chunks-original_direct)
        if not graphical:
            expected_summary -= 18
        check(summary["checks"] == expected_summary, mode+" dynamic assertion denominator")
        check(case["result"]["checks"] == expected_summary+1, mode+" final summary-file assertion")
        lines = (native/"process.log").read_text().splitlines()
        assertions = [line for line in lines if line.startswith("ART_COLLAB_NATIVE_CHECK ")]
        check(len(assertions) == case["result"]["checks"]
              and all(line.endswith(" true") for line in assertions), mode+" original individual checks")
        check(changed == 184396 and checked == 188617, mode+" summed actual native work")
        outputs.append({"mode": mode, "summary_checks": summary["checks"],
                        "terminal_checks": case["result"]["checks"],
                        "staged_chunks": staged_chunks, "direct_chunks": direct_chunks,
                        "maximum_chunk_checked": max_chunk, "stages": 25,
                        "verified_original_files": len(replay["verified_original_files"]),
                        "verified_readback_rows": replay["verified_readback_rows"],
                        "raw_review_sha256": sha(replay_path),
                        "native_summary_sha256": sha(native/"creative-native-summary.json"),
                        "campaign_summary_sha256": sha(campaign_root/"summary.json"),
                        "process_log_sha256": sha(native/"process.log"),
                        "runtime_identity_from_campaign": campaign["runtime"],
                        "scenes": scene_rows})
    return {"schema": "art-final-bcc-native-independent-comparison-v1",
            "status": "passed" if not failures else "failed", "checks": checks, "failures": failures,
            "source": SOURCE, "tree": TREE, "original_source": OLD,
            "original_native_summary_sha256": sha(old_path),
            "identical_native_test_sha256": sha(review/"native-test-bcc.gd"),
            "campaign": 45546845554, "artifact": artifact_id, "native_platform": native_platform,
            "archive_sha256": archive_sha, "archive_bytes": archive_bytes,
            "verifier_sha256": sha(review/"verify_art_creative_native_evidence.py"),
            "execution_platform": platform.platform(), "python": platform.python_version(),
            "method": "B independently executed the unchanged raw native verifier twice and reconciled final headless/displayed originals against preserved2743; no new native or model execution.",
            "outcomes": outputs,
            "limits": ["Native chunk grouping and therefore assertion counts vary; no test gate was removed.",
                       "Original and final scene geometry/counters match; context/provenance disclosures intentionally evolved.",
                       "Timing across different hosts/campaigns is not a controlled performance comparison.",
                       "Static clearance and stored materials do not establish actor traversal, machinery function or real-model creativity.",
                       "This record replays the named platform's campaign; portable package and physical owner acceptance remain separate."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("review_directory", type=Path)
    parser.add_argument("artifact_extraction", type=Path)
    parser.add_argument("--platform", choices=tuple(ARTIFACTS), required=True)
    args = parser.parse_args()
    try:
        result = verify(args.review_directory, args.artifact_extraction, args.platform)
    except Exception as error:
        result = {"schema": "art-final-bcc-native-independent-comparison-v1",
                  "status": "failed", "checks": checks, "failures": failures,
                  "error": str(error), "error_type": type(error).__name__}
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
