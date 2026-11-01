from contextlib import redirect_stdout
from pathlib import Path
import hashlib
import io
import json
import subprocess
import sys
import zipfile

SOURCE = "8e86ffd4eb2eb769178808a1012701076e3a4d19"
RUN = "41331369142"
ATTEMPT = "1"
ROOT = Path("/workspace/scratch/59ce0c87fdea")
SOURCE_ROOT = ROOT / "sol281-qualified-source-8e"
OUT = ROOT / "evidence/publication-final-review"
sys.path.insert(0, str(SOURCE_ROOT / "tools/sol281"))
import publish_runtime as publisher
import run_qualification as qualification

# Retrieved independently from GitHub Actions artifact metadata on 2026-11-01.
ARCHIVES = {
    "build-linux": (13093736693, "8bd75b14777511fc37eaf27c21e44169a1ca9e380de111166d94d78eaae67c70"),
    "build-windows": (13093458061, "ccf2cb9a8f7e65db5f5a9038898df670e1c8b2b5e8e0ac79a5e9ceb16f4f12c1"),
    "host-linux-core": (13093847583, "40bdc171f59eb5be56d247bae20c345d4ce2bfc7de2a4dcf3d40507065ad1e6b"),
    "host-linux-contact-w1": (13093403810, "4303ea4e345ce089cb6ebf199cfbff2573f546513b90655aa5be3695954bd00c"),
    "host-linux-contact-w4": (13093423586, "5ac3082571a5f5433e642174104f8f57515d264cf6e4e55402a606b52f687cb4"),
    "host-windows-core": (13093817701, "bc4e0cde0d78452cd704afbaa6bd18132b0d8c2f8a642c92c9ac4c91a18ceda2"),
    "host-windows-contact-w1": (13094096259, "8c1fd10feeec9c7e3875def90f4dcda9c7b5820e976357bff9c702098d6276a3"),
    "host-windows-contact-w4": (13093358854, "57fe7c18f57d998c9c827756a19b2e15f7932f14f5de22dc0f449adeca347aca"),
}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def extract(key, artifact_id, expected):
    family = "builds" if key.startswith("build-") else "hosts"
    name = f"sol281-{key}-{RUN}-{ATTEMPT}"
    archive = ROOT / "hosted-qualification" / ("final-" + family) / (name + ".zip")
    assert qualification.digest(archive) == expected, name
    destination = OUT / "originals" / family / name
    destination.mkdir(parents=True, exist_ok=False)
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None, name
        entries = [entry for entry in package.infolist() if not entry.is_dir()]
        assert len({entry.filename for entry in entries}) == len(entries), name
        for entry in entries:
            relative = publisher.safe_relative(entry.filename)
            assert (entry.external_attr >> 16) & 0o170000 != 0o120000
            path = destination / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(package.read(entry))
    return destination, {"artifact_id": artifact_id, "archive_sha256": expected,
                         "original_entries": len(entries)}

identity = qualification.source_identity()
assert identity["sha"] == SOURCE
inputs = qualification.source_inputs()
assert len(inputs) == 1064
ctx = {"source": identity, "run_id": RUN, "run_attempt": ATTEMPT}
review = {
    "schema": "cybersand.sol281.independent-final-artifact-review.v1",
    "status": "incomplete", "source": identity, "run_id": RUN, "run_attempt": ATTEMPT,
    "workflow_run": f"https://github.com/techrote/cybersand/actions/runs/{RUN}",
    "scope": "Read-only original artifact review using unchanged readers at the exact qualified source; no publication operation or GitHub environment spoofing",
    "canonical_source_inputs": len(inputs), "native_source_inputs": len(publisher.native_ledger(inputs)),
    "archives": {}, "builds": {}, "hosts": {}, "replay": {}, "populated": [], "motion": [],
    "local_extraction_discrepancy": "local-extraction-discrepancy.json; origin unknown, absent from authenticated original ZIP, excluded by fresh independent extraction",
    "remaining_gates": {
        "dense_bed_resistance_and_acceptable_penetration": "not passed; conservation/contact fixtures do not establish a physical penetration bound",
        "representative_interactive_gpu_frame_pacing": "not tested by this headless matrix",
        "accepted_gcr_candidate_integration": "not tested; current-main contact policy only",
        "active_transformed_restoration_arbitrary_fracture_and_persistence": "explicitly deferred",
        "normal_gameplay_and_owner_physical_acceptance": "explicitly deferred",
        "full_ready_pr_ci_and_merge": "outside this scoped matrix; draft and owner approval required",
    },
}
directories = {}
for key, (artifact_id, expected) in ARCHIVES.items():
    directories[key], review["archives"][key] = extract(key, artifact_id, expected)

replays = {}
for target in ("linux", "windows"):
    directory = directories["build-" + target]
    build, runtime, files = publisher.verify_build(directory, target, ctx, inputs)
    review["builds"][target] = {"status": "passed", "file_count": len(files), "runtime": runtime,
                                "build_manifest_sha256": qualification.digest(directory / "build.json")}
    for cohort in qualification.COHORTS:
        key = "host-" + target + "-" + cohort
        directory = directories[key]
        report, files = publisher.verify_host(directory, target, cohort, ctx, build,
            review["builds"][target]["build_manifest_sha256"])
        host = directory / "host" if target == "linux" else directory
        readbacks = {}
        for spec, record in zip(qualification.inventory(cohort), report["records"]):
            footer = qualification.verify_footer(spec, (host / record["log"]).read_text(encoding="utf-8"), target.title())
            assert footer == record["readback"]
            assert qualification.verify_result_file(spec, host, footer) == record["result"]
            readbacks[spec.name] = footer.get("checks") if footer is not None else "ordinary completion footer"
            if spec.script == "test_solid_detachment_populated":
                result = publisher.load(host / (spec.name + ".json"))
                counts = result["displacement"]
                review["populated"].append({key: result[key] for key in (
                    "platform", "workers", "surroundings", "conservative_displacement", "checks",
                    "sand_before", "sand_after", "water_mass_before", "water_mass_after",
                    "max_translation", "max_rotation") } | {
                        "accepted": counts["accepted"], "moved_cells": counts["moved_cells"],
                        "attempts": counts["attempts"], "refusal_causes": counts["outcomes"],
                        "contacts": result["coupling"]["contacts"],
                        "unresolved": result["coupling"]["unresolved"],
                    })
            if spec.script == "test_solid_detachment":
                result = publisher.load(host / (spec.name + ".json"))
                review["motion"].append({key: result[key] for key in (
                    "platform", "workers", "checks", "members", "shapes", "mass", "inertia",
                    "aggregate_owned", "max_down", "max_rotation", "max_angular_velocity", "max_horizontal")})
        review["hosts"][target + "/" + cohort] = {
            "status": "passed", "file_count": len(files), "case_count": len(report["records"]),
            "checks": readbacks, "report_sha256": qualification.digest(host / "report.json"),
            "raw_checkout_unchanged": report["checkout_inputs_unchanged"],
        }
        if cohort != "core":
            result = publisher.load(host / ("displacement-w" + cohort[-1] + ".json"))
            replays[target + "/" + cohort] = result["cases"]

reference = next(iter(replays.values()))
comparison_fields = ("id", "expected_accepted", "failure_count", "outcome", "moved_cells",
                     "path", "geometry_clear", "before_sha256", "after_sha256", "water_quantity")
assert len(reference) == 17
project = lambda cases: [{key: case[key] for key in comparison_fields} for case in cases]
review["replay"] = {
    "cases_per_run": 17, "checks_per_run": 292,
    "runs": list(replays), "full_case_records_equal": all(cases == reference for cases in replays.values()),
    "all_outcome_fields_equal": all(project(cases) == project(reference) for cases in replays.values()),
    "case_record_sha256": {key: sha(publisher.encoded(cases)) for key, cases in replays.items()},
    "accepted_per_run": sum(case["outcome"] == "Applied" for case in reference),
    "refused_per_run": sum(case["outcome"] != "Applied" for case in reference),
    "cases": project(reference),
}
assert review["replay"]["all_outcome_fields_equal"]
assert review["replay"]["accepted_per_run"] == 4 and review["replay"]["refused_per_run"] == 13
for result in review["populated"]:
    assert result["sand_before"] == result["sand_after"]
    assert result["water_mass_before"] == result["water_mass_after"]
    assert result["refusal_causes"]["Quarantined"] == 0

summary = OUT / "strict-source-reducer.json"
with redirect_stdout(io.StringIO()):
    status = qualification.summarize(type("Args", (), {"input": OUT / "originals/hosts", "output": summary})())
assert status == 0, publisher.load(summary)
review["strict_source_reducer"] = {"status": "passed", "sha256": qualification.digest(summary)}
published_summary = ROOT / "cybersand/docs/audits/sol281-20261101/hosted" / SOURCE / "qualification.json"
assert published_summary.read_bytes() == summary.read_bytes()
review["strict_source_reducer"]["equals_published_original_bytes"] = True
review["total_host_cases"] = sum(row["case_count"] for row in review["hosts"].values())
review["status"] = "passed"
(OUT / "review.json").write_bytes(publisher.encoded(review))

lines = ["# Independent final SOL281 artifact review", "", "**Result: passed within the declared scope.**", "",
    f"Qualified source: `{SOURCE}`; tree `{identity['tree']}`.",
    f"Original GitHub-hosted run: [{RUN}](https://github.com/techrote/cybersand/actions/runs/{RUN}), attempt {ATTEMPT}.", "",
    "The unchanged readers ran from a detached checkout of the qualified source. The later runtime-publication commit is not relabelled as the compiled or tested source. No publication entry point was invoked and no GitHub environment was spoofed.", "",
    "## Original source and artifacts", "",
    "All eight original ZIPs match GitHub's independently retrieved SHA-256 digests and pass CRC checks. Fresh independent extraction avoids an extra local file of unknown origin in an earlier extracted directory; that file is absent from the authenticated ZIP. Its exact details remain in `local-extraction-discrepancy.json`.", "",
    "Both original builds pass the publication reader. All 1,064 execution/build source inputs match exact qualified Git blobs, including all 86 native inputs. Both builds retain complete raw checkout identities and successful original command receipts.", "",
    "| Host | Cohort | Cases | Result |", "|---|---|---:|---|"]
for key, row in review["hosts"].items():
    target, cohort = key.split("/")
    lines.append(f"| {target.title()} | {cohort} | {row['case_count']} | Passed |")
lines += ["", f"All {review['total_host_cases']} host cases and six imports complete naturally. Original logs, structured results, worker settings, source ledgers, runtime identities and Godot/Rapier pins pass the strict readers. The unchanged source-bound reducer passes and produces byte-identical output to the published original qualification summary.", "",
    "## Deterministic conservative displacement", "",
    "All four combinations—Linux/Windows and workers 1/4—complete 17 fixtures and 292 assertions. All 17 case outcome records agree, including exact before/after payload hashes, paths, moved-cell counts, refusal outcomes, geometry and Water quantity.", "",
    f"Complete case dictionaries, including counters and geometry data, are identical across all four executions: **{review['replay']['full_case_records_equal']}**.", "",
    "| Fixture | Outcome | Moved parcels |", "|---|---|---:|"]
for case in reference:
    lines.append(f"| {case['id']} | {case['outcome']} | {case['moved_cells']} |")
lines += ["", "Each execution has four accepted analytical boundary controls and thirteen mutation-free refusals. All eight frozen historical contacts remain refusals under the stricter physical geometry rule; the earlier radius and chain NO-GO conclusions are preserved.", "",
    "## Actual-host scope", "",
    "The matrix passes genuine native support-cut handoff of the 520-cell, six-shape aggregate, dry gravity/toppling/angular/rolling thresholds, payload ownership, failure/rollback/replacement/reset controls, twenty owner-replacement lifecycle cycles, compound torque and duplicate/stale response controls, material-image handoff, terrain refresh after excavation, and ordinary compatibility controls.", "",
    "All 24 populated runs—three surroundings, two contact policies, two worker settings and two operating systems—retain exact Sand count and Water quantity. The twelve conservative candidates show actual contact and aggregate motion. These fourteen-assertion population gates do not establish an acceptable penetration bound or calibrated granular resistance.", "",
    "### Conservative packed-Sand observations", "",
    "| Host | Workers | Accepted contacts | Parcels moved | Max translation (cells) | Max rotation (rad) | Sand before/after |", "|---|---:|---:|---:|---:|---:|---|"]
for result in review["populated"]:
    if result["conservative_displacement"] and result["surroundings"] == "packed_sand":
        lines.append(f"| {result['platform']} | {result['workers']} | {result['accepted']} | {result['moved_cells']} | {result['max_translation']:.6f} | {result['max_rotation']:.6f} | {result['sand_before']}/{result['sand_after']} |")
lines += ["", "Asynchronous host contact totals and poses are measured observations; they are not required to match across OS scheduling or worker settings. Deterministic fixture replay is the equality gate.", "",
    "## Remaining acceptance gates", "", "| Gate | Disposition |", "|---|---|"]
for gate, disposition in review["remaining_gates"].items():
    lines.append(f"| {gate.replace('_', ' ')} | {disposition} |")
lines += ["", "The first hosted attempt remains a separate negative record: source `c8c81a8b…`, run `41329746261`, Windows checkout refusal before engine execution. This successful run does not rewrite that evidence or close issue #281 as a whole.", "",
    "Machine-readable detail: `review.json`. Strict reducer output: `strict-source-reducer.json`. Reproduction reader: `review_originals.py`.", ""]
(OUT / "review.md").write_text("\n".join(lines), encoding="utf-8")
print(json.dumps({"status": review["status"], "source": identity, "builds": 2,
    "host_cohorts": 6, "host_cases": review["total_host_cases"], "replay_full_cases_equal": review["replay"]["full_case_records_equal"],
    "replay_outcomes_equal": review["replay"]["all_outcome_fields_equal"], "review_json_sha256": qualification.digest(OUT / "review.json")}, indent=2))
