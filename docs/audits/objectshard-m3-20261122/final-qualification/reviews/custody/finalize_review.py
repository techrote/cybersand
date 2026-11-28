"""Seal the independent e034 custody review; never modify product or artifacts."""
from __future__ import annotations

import collections
import datetime
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SHA = "e034f2294663e0485cfb9adcc8ada46a6e977cee"
TREE = "246e7324ca618d98c43a0ed54fe19bc86a155877"
NOW = datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def read(name: str):
    return json.loads((OUT / name).read_text())


def write(name: str, value):
    (OUT / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


assert subprocess.check_output(["git", "rev-parse", SHA + "^{tree}"], cwd=ROOT, text=True).strip() == TREE
protected_delta = subprocess.check_output(
    ["git", "diff", "--name-only", SHA, "--", "godot", "native", "tools", ".github", ".gitattributes", "third_party"],
    cwd=ROOT, text=True,
).splitlines()
assert not protected_delta, protected_delta

# Reproduce the additional metadata-only DLL comparison without recompiling.
old_dll = (ROOT / "build/m3-platform/windows/14743743167/cybersand_native.windows.x86_64.dll").read_bytes()
new_dll = (ROOT / "build/m3-platform/repair-windows/14745122677/cybersand_native.windows.x86_64.dll").read_bytes()
assert len(old_dll) == len(new_dll) == 6075904
differences = [i for i, (a, b) in enumerate(zip(old_dll, new_dll)) if a != b]
assert len(differences) == 14
assert set(differences) == set(range(4131197, 4131203)) | set(range(4493344, 4493352))
assert old_dll[4493340:4493344] == new_dll[4493340:4493344] == b"RSDS"
drift = read("windows-performance-drift-investigation.json")
drift["native_metadata_only_difference"] = {
    "differing_bytes": len(differences),
    "export_name_random_temporary_suffix": {
        "offset": 4131197, "bytes": 6,
        "baseline": old_dll[4131197:4131203].decode("ascii"),
        "repair": new_dll[4131197:4131203].decode("ascii"),
    },
    "codeview_build_identifier": {"offset": 4493344, "bytes": 8, "prefix": "RSDS"},
    "text_code_identical": True,
    "all_other_bytes_identical": True,
    "scope": "All 6,075,904 actual DLL bytes compared. Only a temporary export-filename suffix and CodeView build identity differ; no executable instruction or numerical constant delta was observed.",
}
drift["interpretation"][0] = "The observed regression is retained: the same 240-interval pump workload takes longer and the same 153-action UI burst has larger queue/presentation tails. No performance equivalence to the superseded baseline is claimed."
drift["interpretation"][1] = "Headless pump profiles do not instantiate the repaired owner scene. They retain identical script/runtime interface inputs, canonical publications, accounting, cadence target and workload counts; native execution, snapshot and value-accounting medians rose in the new actual run."
drift["interpretation"][2] = drift["native_metadata_only_difference"]["scope"] + " Fresh exact-source compilation and custody are independently established."
drift["interpretation"][5] = "Unchanged registered Lab limits still pass. These do not constrain the new burst input latency. The observed 1.9-second tail remains a practical limitation for owner evaluation; no 60 FPS or universally responsive editing claim is supported."
write("windows-performance-drift-investigation.json", drift)

# The reviewer directly inspected these seven images; this records that human/model
# visual observation separately from machine-verifiable PNG and source hashes.
render = read("windows-render-review.json")
render["independently_viewed"] = sorted(x["file"] for x in render["rendered_images"] if x["case"] == "objectshard_worker_render")
assert len(render["independently_viewed"]) == 7
render["observations"] = [
    "Initial supported scene: native/published tick 1, no active shard, paused between asynchronous operations; a structural tree visibly connects to terrain.",
    "Falling image: awake 526-cell body, geometry revision 1 with six shapes, tick 21 and 77 physical segments.",
    "Settled-after-erosion image: visibly rotated resting 525-cell body, naturally sleeping, geometry revision 2 with seven shapes, tick 471 and 1,877 segments.",
    "Priority image: three occupied slots, main structure of 817 cells and smaller 72-cell candidates explicitly refused for BodySlots. Native tick 7 / published tick 6 and the pending applied-motion receipt remain visible.",
    "Water/Sand pocket image: 498 structural cells plus one cargo cell, mass 499, sleeping with installed geometry revision 2. Native tick 101 / published tick 100 and a pending prepare receipt are explicit. Extinction counter is zero in this image; it is not Water-extinction evidence.",
    "External Fire image: 256 by 160 native fixture, 83 accepted authored Fire cells and an explicit occupied-cell refusal. Native tick 31 / published tick 21 and the outstanding receipt are visible; Rapier is held at the barrier.",
    "Extended image: 320 by 192 canvas, three occupied owner slots, three separate drawn structures including a visibly rotated third body. Native and published tick 81 agree; the first two displayed owners are naturally sleeping.",
]
render["utc_completed"] = NOW
render["scope"] = "Actual hosted renderer output and source-bound report/image hashes. Adjacent diagnostic JSON can be sampled after the drawn frame and is not relabelled as its exact pose. Still images do not establish monitor motion, physical owner acceptance or default NVIDIA performance."
write("windows-render-review.json", render)

# Reduce the actual retained source/package action traces; no simulation rerun.
trace_reports = []
for mode in ("windows-lab", "package-replay"):
    path = ROOT / "build/m3-platform/repair-windows/14745662483" / mode / "continuous-physics-session-1.jsonl"
    kinds = collections.Counter()
    accepted = 0
    motion_acks = 0
    header = None
    with path.open() as stream:
        for line in stream:
            row = json.loads(line)
            kinds[row["kind"]] += 1
            detail = row.get("detail", {})
            if row["kind"] == "header":
                header = detail
            if row["kind"] == "action":
                assert detail["result"]["ok"] is True
                assert detail["result"]["outcome"] == "Accepted"
                accepted += 1
            if row["kind"] == "event" and detail.get("kind") == "NativeReceipt":
                receipt = detail["detail"]
                if receipt.get("operation") == "motion":
                    assert receipt["result"]["applied"] is True
                    assert receipt["result"]["ok"] is True
                    assert receipt["result"]["accepted_pose_serials"]
                    motion_acks += 1
    assert header["source_revision"] == SHA
    assert sum(kinds.values()) == 44819
    assert kinds["step_requested"] == kinds["step_completed"] == 3599
    assert accepted == 540 and motion_acks == 14388
    trace_reports.append({
        "mode": mode, "path": str(path.relative_to(ROOT)),
        "sha256": digest(path), "rows": sum(kinds.values()),
        "record_kinds": dict(kinds), "accepted_actions": accepted,
        "nonempty_applied_motion_acknowledgements": motion_acks,
    })
write("continuous-trace-review.json", {
    "schema": "objectshard-independent-final-trace-reduction-v1",
    "source_commit": SHA, "source_tree": TREE, "utc": NOW, "status": "passed",
    "traces": trace_reports,
    "scope": "Actual source/package JSONL reductions. The 14,390 physical-step total is separately in the qualified run summary; two steps have no body sample. This does not establish cross-platform bit-identical replay or Water extinction/Sand ingestion in the long run.",
})

narrative = read("narrative-scope-review.json")
narrative["utc"] = NOW
narrative["narrative_sha256"] = digest(ROOT / "build/final-audit-narrative.md")
narrative["prefix_sha256"] = digest(ROOT / "build/final-audit-prefix.md")
narrative["status"] = "Passed read-only verification of the final numeric prefix and stable narrative against independently audited e034 evidence; no additional unsupported scope or custody claim found."
narrative["remaining_checks"] = []
narrative["verified_claim_boundaries"] = [
    "The separate-World exclusive native-worker rehearsal is explicitly distinguished from ordinary CyberSimulationWorker and Workbench adoption.",
    "Precommit cancellation leaves native ownership intact; postcommit uncertain state quarantines inactive inventory rather than claiming rollback.",
    "Host capacity is 32 queued actions plus one in flight; worker channels hold 32 data and eight control messages; the 64 KiB bound applies to parameter values, not whole-envelope allocator memory; UI capacity is 256 pending intents.",
    "F2 requires native disposal, stopped-thread join and RID release; quit priority survives retry. No arbitrary forced-scene replacement guarantee is made.",
    "Fresh 93,529 ASan/UBSan checks, 192 complete World cases, 41 source Godot cases per platform, 32 actual package cases, and each 135-parent/18-child navigation result match raw receipts. LeakSanitizer remains disabled.",
    "All 56 headless and 80 rendered Lab limits pass unchanged. The separate 74-limit native matrix retains its actual historical source label and is not relabelled as a new CI execution.",
    "Both negative cross-campaign throughput observations, Windows 1.929-second and Linux 1.838-second burst tails, and soft pump-budget overruns remain explicit. The retained records do not prove a CPU, runner or navigation-patch cause.",
    "Actual frame_post_draw distributions are not raw per-presentation sequence logs or monitor scanout. Stage percentiles are not added across enclosing intervals.",
    "Long-run Fire/Smoke, contact and three-body natural sleep are distinct from separate Sand-ingestion and Water-extinction fixtures. The long-run ingestion/extinction counters are zero.",
    "The actual package has 1,099 verified members; its exact SHA, source, native runtime and manifest agree. Four path cases and 12 verifier/launcher self-tests passed; normal default-driver owner gameplay is not equated with ANGLE self-test qualification.",
    "All seven M3 images were directly viewed. Priority and pocket image counters may precede their adjacent after-draw JSON diagnostics.",
    "The superseded 682 source/package remains historical. Final production provenance has six unchanged failures; all merges, production runtime publication and physical owner acceptance remain outside this review.",
]
write("narrative-scope-review.json", narrative)

source = read("source-review.json")
source["cust_01"] = "Original UI capture time, separate host-admission metrics and rendered sample gates are preserved. Final Windows and Linux raw action ledgers and presented distributions were independently verified in the corresponding performance reviews."
source["final_evidence_closeout_utc"] = NOW
write("source-review.json", source)

win = read("windows-review-verdict.json")
win["final_evidence_closeout_utc"] = NOW
win["remaining_boundaries"] = [b for b in win["remaining_boundaries"] if not b.startswith("Fresh Linux")]
win["linux_review_completion"] = "Fresh Linux review completed; see linux-execution-review.json, linux-performance-review.json and final-review-verdict.json."
for name in win["source_bound_reports"]:
    win["source_bound_reports"][name] = digest(OUT / name)
write("windows-review-verdict.json", win)

linux = read("linux-execution-review.json")
wperf = read("windows-performance-review.json")
lperf = read("linux-performance-review.json")
matrix = read("retained-native-matrix-review.json")
required_pass_reports = [
    "source-review.json", "windows-crossbuild-review.json", "windows-artifact-inventory.json",
    "windows-delivered-archive-review.json", "windows-execution-review.json", "windows-performance-review.json",
    "windows-render-review.json", "linux-execution-review.json", "linux-performance-review.json",
    "continuous-trace-review.json",
]
for name in required_pass_reports:
    report = read(name)
    assert report.get("status", "").startswith("passed"), (name, report.get("status"))
    assert not report.get("failures"), (name, report.get("failures"))

report_names = sorted(p.name for p in OUT.glob("*.json") if p.name not in {"final-review-verdict.json", "retention-index.json"})
verdict = {
    "schema": "objectshard-independent-final-custody-review-v1",
    "reviewer": "review_custody; independent of product implementation, CI execution and artifact acquisition",
    "utc": NOW, "source_commit": SHA, "source_tree": TREE,
    "draft_pr": "https://github.com/techrote/cybersand/pull/741",
    "base_commit": "44abd754d014a44078a41792d2d46967a9b8cf30",
    "status": "passed for the scoped experimental source-matched delivery; performance limitations, future Workbench binding and production gates remain explicit",
    "confirmed_unrepaired_class_a_b_findings_in_reviewed_scope": [],
    "authority": "Review only. No merge, Ready transition, release, auto-merge, ordinary default change, retained runtime publication or physical owner acceptance.",
    "protected_worktree_delta_at_closeout": protected_delta,
    "scope": "Independent source/build/input custody, unchanged gate and budget integrity, native/sanitizer/World receipts, real Godot and extracted-package receipts, rendered evidence, performance reductions, negative drift investigation and owner-authorized mergedown checklist. This complements, rather than replaces, the separate ownership and physics reviews.",
    "workflow": {
        "run_id": 44999117090, "attempt": 1,
        "jobs": [
            {"name": "Windows crossbuild", "id": 137136516082, "conclusion": "success"},
            {"name": "Windows source and delivered package", "id": 137137548583, "conclusion": "success"},
            {"name": "Linux native and actual Godot", "id": 137136516239, "conclusion": "success"},
        ],
        "source_bound_remote_readback": "remote-linux-readback.json",
    },
    "owner_zip": win["owner_zip"],
    "verification_summary": {
        "unchanged_native_inputs": 116,
        "protected_gate_build_budget_inputs": 21,
        "ordinary_discovered_cases": 360,
        "strict_package_probes_in_ordinary_discovery": 0,
        "package_receipt_contract_tests": 50,
        "linux_archive_members_stream_hashed": 327,
        "windows_execution_archive_members_stream_hashed": 196,
        "native_sanitizer_checks": 93529,
        "native_sanitizers": ["ASan", "UBSan"],
        "leak_sanitizer": False,
        "world_cases": 192,
        "world_seconds": linux["native_sanitizer"]["suites"][-1]["seconds"],
        "source_godot_cases_each_platform": 41,
        "actual_extracted_package_cases": 32,
        "navigation_parent_checks_each_mode": 135,
        "navigation_real_exit_child_checks_each_mode": 18,
        "launcher_path_cases": 4,
        "successful_verifier_launcher_commands": 12,
        "exact_tamper_reason": "Package file changed: READ-ME.md",
        "tamper_exit_code": 1,
        "get_file_hash_shadow_bypass_rejected": True,
        "actual_source_bound_images": 22,
        "m3_images_directly_viewed": 7,
    },
    "performance": {
        "unchanged_lab_limits_each_platform": {"headless": 56, "rendered": 80},
        "retained_native_matrix": {
            "recorded_source": matrix["recorded_run_head"], "limits_passed": 74,
            "checks": matrix["checks"], "inputs_identical_to_final": 94,
            "peak_accounted_cpp_bytes": 6277280, "budget_bytes": 6291456, "margin_bytes": 14176,
            "fresh_ci_matrix_claimed": False,
        },
        "same_source_pairs": {
            platform: perf["worker_scheduling_pair"]
            for platform, perf in (("windows", wperf), ("linux", lperf))
        },
        "rendered_153_input_burst_to_presented_usec": {
            platform: perf["rendered_live_burst"]["host_timings_usec"]["input_to_presented_usec"]
            for platform, perf in (("windows", wperf), ("linux", lperf))
        },
        "negative_comparison_to_superseded_baseline": {
            "windows_pump_throughput_change_percent": -12.2496063,
            "linux_pump_throughput_change_percent": -10.8251869,
            "windows_burst_p95_change_percent": 24.9828443,
            "windows_burst_maximum_change_percent": 24.7114501,
            "attribution": "Unresolved. Equal executed hot-path source, matching work/accounting, identical Windows text section and entire Linux native binary, and comparable reported renderers do not prove hardware equivalence or an external scheduling cause.",
        },
        "interpretation": "Registered Lab limits pass, but the burst input tails remain a practical limitation. The 4 ms receipt setting is a soft loop budget with observed maximum calls of 5.996 ms on Windows and 4.517 ms on Linux. No target-hardware FPS or universal responsiveness claim is made.",
    },
    "findings_disposition": win["findings_disposition"],
    "remaining_boundaries": [
        "The experimental scene owns a separate real native World on an exclusive thread. It does not attach to the ordinary Workbench CyberSimulationWorker World; immutable GCR and missing same-World facade attachment remain successor work.",
        "Six unchanged full production provenance errors remain, across three native source paths for each platform. Both retained runtimes and complete 116-input manifests require a later owner-authorized exact-source publication and ordinary gates.",
        "The source-matched hosted package and actual Windows ANGLE runs do not establish physical Windows 11/NVIDIA owner acceptance or normal-driver performance.",
        "The final campaign is fresh; the 74-limit native matrix is a separately retained, source-identical local repeat with only 14,176 bytes of native allocator margin. It does not bound Godot, Rapier, GPU, mailbox memory or larger canvas totals.",
        "The long three-body test has actual Fire/Smoke but zero ingestion and extinction counts; Sand capture and Water extinction are separately qualified fixtures.",
        "Original timing and memory failures, old published candidate failures and final slower timing observations remain retained. No extra campaign replaced an inconvenient result.",
        "Three bodies and existing material, geometry, motion and resident-area bounds remain. General fracture, recellularisation, durable persistence and ordinary production adoption are not qualified.",
    ],
    "narrative_review": {"prefix_sha256": narrative["prefix_sha256"], "narrative_sha256": narrative["narrative_sha256"], "additional_findings": []},
    "reports": {name: {"sha256": digest(OUT / name), "bytes": (OUT / name).stat().st_size} for name in report_names},
}
write("final-review-verdict.json", verdict)

# No self-reference: this index hashes every other own report/script/log, including
# the verdict. Large raw artifacts remain in their authenticated original ZIPs.
files = []
for path in sorted(OUT.rglob("*")):
    if path.is_file() and path.name != "retention-index.json" and "__pycache__" not in path.parts:
        files.append({"path": str(path.relative_to(OUT)), "bytes": path.stat().st_size, "sha256": digest(path)})
write("retention-index.json", {
    "schema": "objectshard-independent-final-review-retention-v1",
    "source_commit": SHA, "source_tree": TREE, "utc": NOW,
    "scope": "Authoritative closeout hashes for this independent review directory. The index excludes itself; original platform ZIP hashes and member inventories are bound by the reports. Product and downloaded evidence were read only.",
    "files": files,
    "archive_only_retention": "Native compiler objects and test binaries remain inside the authenticated Linux archive; no duplicate extraction is required. Baseline raw profiles and JSONL remain inside their authenticated historical archives after verified duplicate-copy reclamation.",
})
for name in ("final-review-verdict.json", "retention-index.json", "narrative-scope-review.json", "windows-render-review.json"):
    print(name, (OUT / name).stat().st_size, digest(OUT / name))
