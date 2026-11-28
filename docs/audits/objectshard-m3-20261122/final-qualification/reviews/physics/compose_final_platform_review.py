#!/usr/bin/env python3
"""Compose an independent evidence addendum from the already audited artifacts."""
import datetime
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/review-physics"
SHA = "e034f2294663e0485cfb9adcc8ada46a6e977cee"
TREE = "246e7324ca618d98c43a0ed54fe19bc86a155877"
inputs = {}


def read(relative):
    path = ROOT / relative
    inputs[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    return json.loads(path.read_text())


def bind(relative):
    path = ROOT / relative
    inputs[relative] = hashlib.sha256(path.read_bytes()).hexdigest()


platforms = {p: read(f"build/review-physics/platform-{p}-final-e034-review.json") for p in ("windows", "linux")}
local = read("build/review-physics/final-e034f229/review-final.json")
publication = read("build/review-physics/final-publication-source-review.json")
finding = read("build/review-physics/navigation-68235b12/finding.json")
for relative in ("build/review-physics/final-windows-audit-config.json", "build/review-physics/final-linux-audit-config.json",
                 "build/review-physics/audit_final_platform.py", "build/review-physics/audit_platform_physics.py",
                 "build/review-physics/compose_final_platform_review.py"):
    bind(relative)
assert local["reviewed_commit"] == SHA and local["reviewed_tree"] == TREE
assert local["totals"]["assertion_executions_including_child"] == 669 and local["totals"]["failures"] == 0
assert publication["source_commit"] == SHA and publication["source_tree"] == TREE
for p, r in platforms.items():
    assert r["source_commit"] == SHA and r["source_tree"] == TREE
    assert r["status"] == "passed" and not r["failures"]
    assert r["paired_same_platform_publication_digest_and_ledger_equality"]
    assert len(r["rendered_images"]) == 7
    assert all(i["visible_png_telemetry"] and "Actually opened and visually inspected" in i["visual_review"] for i in r["rendered_images"])

physics = {}
timing = {}
captures = {}
for p, r in platforms.items():
    physics[p] = {}
    for lab, s in r["sustained_physics"].items():
        fields = ("checks_reported", "trace_rows", "native_endpoint", "completed_intervals", "physical_steps",
                  "acknowledged_nonempty_segments", "action_material_counts", "moving_owners", "contacting_owners", "sleeping_owners",
                  "recomputed_maximum_displacements", "post_edit_translation", "post_edit_rotation", "timing_usec")
        physics[p][lab] = {k: s[k] for k in fields}
    timing[p] = {"paired_profile": r["pump_profiles"], "semantic_progression_ratio": r["paired_semantic_progression_ratio"],
                 "rendered_ui": r["rendered_ui"], "rendered_replay": r["rendered_trace_replay"], "renderer": r["renderer_lines"]}
    captures[p] = [{"image": i["image"], "sha256": i["sha256"], "visible_png_telemetry": i["visible_png_telemetry"],
                    "adjacent_post_draw_host_tick": i["adjacent_post_draw_host_diagnostics"]["native_tick"],
                    "adjacent_post_draw_published_tick": i["adjacent_post_draw_host_diagnostics"]["published_tick"],
                    "adjacent_post_draw_host_state": i["adjacent_post_draw_host_diagnostics"]["host_state"],
                    "visual_review": i["visual_review"]} for i in r["rendered_images"]]

report = {
    "schema": "independent-final-source-platform-physics-addendum-v1", "reviewer": "/root/review_physics; independent reviewer B",
    "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "reviewed_commit": SHA, "reviewed_tree": TREE,
    "status": "Final exact-source and fresh Linux/Windows evidence review complete; no unresolved Class A/B finding in the reviewed supported experimental paths.",
    "scope": "Separate one-real-World/exclusive-worker ObjectShard M3 rehearsal. Main-thread Godot/Rapier RID authority and native M0-M2 material law; not ordinary CyberSimulationWorker or Workbench adoption.",
    "class_a_findings": [], "class_b_findings": [],
    "supersedes": "The fresh-platform-pending status in the immutable exact-published local review is now closed by the final e034 campaign 44999117090. Older68235 platform datasets remain historical and do not qualify the repair.",
    "local_actual_runtime_review": {"totals": local["totals"], "groups": local["groups"], "runtime_scope": "Pinned 4.7 actual local Godot/Rapier tests with identical native input/runtime bytes reused from fresh 68235b12 Linux. These were iteration evidence; fresh e034 source builds and natural qualification runs are separately verified below."},
    "fresh_platforms": {p: {"runtime": r["runtime"], "source_input_counts": r["source_input_counts"], "qualification_cases": r["qualification_cases"], "navigation_lifecycle": r["navigation_lifecycle"], "authenticated_archives": r["authenticated_archives"], "artifact_consistency_assertions": r["checks"], "artifact_consistency_assertion_scope": "Repeated checks over already retained raw trace rows, source bindings and receipts; not additional runtime tests or unique test cases."} for p, r in platforms.items()},
    "sustained_physics": physics,
    "within_windows_source_vs_delivered_package": {"nontiming_physics_identical": platforms["windows"]["same_platform_source_vs_package_nontiming_physics_identical"], "native_accounting_identical": platforms["windows"]["same_platform_source_vs_package_native_accounting_identical"]},
    "material_fixture_outcomes": {p: r["material_fixture_outcomes"] for p, r in platforms.items()},
    "timing_and_presentation": timing, "actual_png_review": captures,
    "closed_navigation_finding": local["resolved_findings"],
    "other_reviewers_navigation_repairs": "Root and ownership reviewer retained independent OPERATOR02 post-close input admission and OPERATOR03 held quit-priority negatives/repairs. This reviewer re-read the final gates and ran its own 49 lifecycle/fence checks plus maintained 135+18; ownership-review counts are not added to this review's 669 assertions.",
    "negative_evidence_preserved": ["Original 68235b12 F2 active/sleeping orphan-native-worker, live RID and wrong quit-policy reproduction, including no-cleanup native/ObjectDB leak log.", "Earlier local buffered-input test harness failure and corrected test-only flush; strict float-basis comparison, timer and mutable-reference harness negatives remain retained.", "Earlier isolated editor import SIGABRTs after completed import/layout remain retained with successful exact-byte retries. Exact final e034 initial import was successful.", "Earlier baseline artifact-auditor assumptions about expected prepare Busy outcomes, ignored .log enumeration and cross-platform rendered replay counts remain retained with corrected auditor versions."],
    "limits": [
        "Controlled F2/window-close paths retain the owner until acknowledged native disposal, join and RID teardown. Arbitrary externally forced direct SceneTree replacement/free of a live owner is unsupported, not a universal destructor-cleanup guarantee.",
        "Within-platform pump 0/4000 compare the same 240 publication digests, native ledger, 60 live inputs and 954 physical steps. No cross-platform Rapier/float/replay bit identity is asserted.",
        "The 4000 µs pump is a soft main-thread loop budget. A complete receipt handler can overrun, as observed. It does not create semantic ticks, native material opportunities or Rapier intervals.",
        "Scheduling profiles do not call mark_presented and do not measure display FPS. Rendered UI timing is source-bound actual frame_post_draw counts/distributions, not monitor scanout or target-GPU latency.",
        "Original result timestamps and scene queue distributions were recomputed. Stored presented evidence has aggregate counts/distributions; there is no per-present raw timestamp ledger to independently reconstruct every presented latency.",
        "Rendered UI latency includes deliberate backlog, stale targets and held receipts. It is not normal steady-play latency.",
        "PNG-visible publication/HUD state and adjacent post-draw host/backend diagnostics are separate observations. Windows priority 7/6 and pocket 101/100, and Linux settled 471/470, must not be relabeled with later host 7/7, 101/101 or 471/471 poses.",
        "The long three-body run authors99 Sand and 100 Water but records zero Sand/Water ingestion and zero extinctions. Actual Sand capture and Water extinction are established by separate source-bound maintained Lab fixtures; the M3 pocket PNG shows one Sand cargo and zero extinctions.",
        "No physical Windows 11/NVIDIA owner acceptance, ordinary worker adoption, Ready/merge/default promotion or repository runtime publication is established. Draft/HOLD scope remains."
    ], "input_sha256": inputs, "product_files_changed_by_reviewer": []
}
json_path = OUT / "final-source-platform-addendum.json"
json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def dist(d):
    return " / ".join(str(d[k]) for k in ("p50", "p95", "p99", "maximum"))


lines = [
    "# Independent final ObjectShard M3 physics and presentation review",
    "",
    f"**Reviewed runtime source:** `{SHA}`, tree `{TREE}`. **Disposition:** final exact-source and fresh Linux/Windows artifact review completed with no unresolved Class A/B finding in the reviewed supported experimental paths. Draft/HOLD remains. This addendum closes the fresh-platform-pending status in the immutable earlier local review; it does not replace the retained original negative evidence.",
    "",
    "## Source, runtime and navigation evidence",
    "",
    "The exact published local run completed 651 parent assertions across 10 suites plus 18 assertions in an actual quit child, 669/0. It included 52 independent actual-worker/Rapier physics assertions, 24 independent live-admission assertions, 49 independent navigation lifecycle/fence assertions, and maintained tests. That local run reused an input-equivalent native runtime; campaign 44999117090 separately built and exercised the final source on both platforms.",
    "",
    "| Execution | Completed qualification cases | Navigation parent / actual quit child | Native runtime SHA256 |",
    "|---|---:|---:|---|",
    f"| Fresh Windows source |41|135/0 +18/0|`{platforms['windows']['fresh_native_hash']}`|",
    f"| Delivered Windows ZIP rerun |32|135/0 +18/0|Same delivered DLL, exact manifest-bound ZIP|",
    f"| Fresh Linux source |41|135/0 +18/0|`{platforms['linux']['fresh_native_hash']}`|",
    "",
    "Every qualification case's natural completion and retained log hash was checked. Windows binds 186 unique Git blobs: 116 native inputs, 51 Lab inputs and 19 qualification-tool inputs. Linux adds five build-contract files, 191 blobs. The fresh Linux compile receipt/log and source provenance passed; Windows selected DLL provenance matches all 116 qualified native inputs. Actual owner ZIP engine, console launcher, DLL, Rapier, manifest and all 51 Lab files were checked. This review's raw artifact checks are repeated consistency assertions over stored rows, not additional runtime test cases.",
    "",
    "The original 68235b12 F2 defect remains a retained Class B high-severity finding against that source: scene destruction orphaned a live native worker and real RIDs, allowed re-entry to overlap owners, and retained the wrong quit policy. The repaired controlled F2/window-close handshake waits for acknowledged disposal, joins the worker, releases RIDs, restores prior quit policy and fences deferred completion by scene identity. All three final execution locations passed the eight maintained lifecycle scenarios and real quit child. Direct externally forced scene replacement/free remains unsupported.",
    "",
    "## Sustained physics and material outcomes",
    "",
    "Each source-platform run and the delivered Windows rerun retains 44,819 raw rows, 3,599 completed intervals from native tick 1 to endpoint 3600, 14,388 acknowledged nonempty motion segments plus two empty physical steps, 14,390 physical steps total, and 540 accepted edits. All 540 action records remain present with a complete footer. Every nonempty segment has an ordered applied native motion receipt before another segment; accepted owner/session/generation/geometry/pose identities agree with completion records. The same-platform Windows source/package non-timing trajectories and native accounting match.",
    "",
    "The three real bodies move about 19.977, 19.977 and 20.138 cells, report contacts and naturally sleep. The tick 2400 resting-owner erase updates owner 1 mass 490→489 and geometry revision 5→6. Subsequent maximum translation is about 0.000067919 cells and rotation 0.0000035882 rad on both platforms; final owners are sleeping. The raw rows support finite mass, COM, inertia and velocity, with consistent geometry and accepted-pose identities; the native quantity ledger is source-bound and is not reconstructed from a full per-cell history, which is not stored in every row.",
    "",
    "| Evidence | Actual material outcome | Scope |",
    "|---|---|---|",
    "| Long three-body run |241 erases, 99 authored Sand, 100 authored Water, 100 authored Fire; chemistry creates 34 Fire and 10 Smoke and destroys 9 Wood |Zero Sand/Water ingestion and zero extinctions in this run|",
    "| Separate maintained Lab fixture, 379/0 |Five World Sand cells become four World cells plus one cargo cell; carried tuple: material 2, states 0/0, temperature 200, incarnation 2 |Actual inventory-conserving Sand transfer; separate from long-run workload|",
    "| Same maintained Water fixture |Water contact of 255 quanta extinguishes the same surviving Wood cell/incarnation; Water ingestion remains 0 |Liquid stays with World; source-bound outcome assertions|",
    "| Separate naturally sleeping chemistry fixture |Burn state 237→227 across 10 sleeping opportunities; retained and World Fire/Smoke observed, geometry changes |Material chemistry continues during actual sleep|",
    "| M3 worker pocket capture |498 structure + 1 Sand cargo, mass 499, 6 shapes, zero Water extinctions |Visible cargo is established; this image does not establish Water extinction|",
    "",
    "## Matched pump timing and actual presentation",
    "",
    "Within each platform, pump 0 and 4000 use the same 240 completed intervals/publication digests, native ledger, 60 live inputs and 954 physical steps. The requested callback cadence is 60 Hz. The table reports semantic progression and interval completion time; these are not display FPS.",
    "",
    "| Platform / pump budget | Semantic intervals per wall second | Interval p50 / p95 / p99 / max (µs) | Actual pump p50 / p95 / p99 / max (µs) |",
    "|---|---:|---|---|",
]
for p, r in platforms.items():
    for budget in ("0", "4000"):
        pr = r["pump_profiles"][budget]
        lines.append(f"|{p.capitalize()} / {budget}µs|{pr['semantic_ticks_per_wall_second']:.5f}|{dist(pr['semantic_interval_and_input_usec'])}|{dist(pr['pump_call_usec']) if budget != '0' else 'No pump'}|")
lines += [
    "",
    f"The measured semantic progression ratios are {platforms['windows']['paired_semantic_progression_ratio']:.5f}× on Windows and {platforms['linux']['paired_semantic_progression_ratio']:.5f}× on Linux. The 4 ms budget is soft and checked between complete handlers: actual maxima are 5.996 ms and 4.517 ms. This rendezvous grants no extra native or physical time. No cross-platform bit identity or target-hardware performance is asserted.",
    "",
    "The separate actual-rendered stress scene retains 153 original pointer intents/results on each platform, with captured≤admitted≤completed timestamps. Original input→result and scene-queue distributions were recomputed from retained values. Source-bound frame_post_draw instrumentation reports 153 input-presentation observations on each platform. The underlying per-present raw timestamp stream is not retained, so the presentation aggregates are not claimed to have been independently reconstructed from raw draw events.",
    "",
    "| Platform | Presented publication observations | Input→presented p50 / p95 / p99 / max (µs) | Publication→presented p50 / p95 / p99 / max (µs) |",
    "|---|---:|---|---|",
]
for p, r in platforms.items():
    ui = r["rendered_ui"]
    lines.append(f"|{p.capitalize()}|{ui['post_draw_publication_count']}|{dist(ui['timings_usec']['input_to_presented_usec'])}|{dist(ui['timings_usec']['publication_to_presented_usec'])}|")
lines += [
    "",
    "These timings include deliberate backlog, stale-target and held-receipt cases; they do not describe normal steady play. Windows rendered through ANGLE/Microsoft Basic Render Driver; Linux through Mesa llvmpipe. The scheduling profiles deliberately do not call mark_presented. Actual rendered replay matches each platform's own trace: Windows 155 actions / 38 intervals, 387/0; Linux 155 / 39, 389/0. The scheduling-dependent difference is retained, not forced into a cross-platform equality claim.",
    "",
    "## Rendered evidence and publication boundaries",
    "",
    "All seven fresh worker PNGs on each platform were individually opened, visually inspected and matched to qualification hashes: supported Wood, actual falling owner, settled post-erase owner, large-structure priority with deferred offcuts, Sand pocket, actual external flame, and the 320×192 three-owner scene. The accepted external Fire fixture is 83 cells in this Windows capture and 84 in Linux. Those are authored flame counts, distinct from chemistry-created Fire.",
    "",
    "The PNG and adjacent post-draw host report are separate observations. The source saves the image after frame_post_draw, then samples diagnostics. Windows priority shows native 7 / published 6 and a motion wait, while its later report is 7/7 Idle; the pocket shows 101/100 and a prepare wait, while the report is 101/101 Idle. Linux's settled PNG shows 471/470 AwaitingNative, while the later report is 471/471 Idle. The complete capture campaign records 120 continued host intervals after erosion; that does not make the earlier visible publication an exact 120-interval image. The audit stores visible HUD telemetry separately from backend bodies and does not substitute adjacent backend transforms as exact displayed poses.",
    "",
    "The exact-source view path uses accepted publication material and pose together, without a live-RID override. Ordinary pointer targets come from view.frame. Maintained tests retain an older displayed snapshot while a newer accepted pose overlaps the same pixel: the stale target explicitly returns TargetChanged and leaves inventory unchanged, while the distinct fresh target removes exactly one cell. Delayed receipts preserve publication and physical-step counts. The independent actual-worker/Rapier probe separately exercises genuine withheld motion receipts; bridge-only unit fixtures are not represented as that full native-worker evidence.",
    "",
    "## Retained record and remaining scope",
    "",
    "No new Class A/B finding arose from the final source/platform review. The original F2 failure, no-cleanup leak logs, earlier harness failures, and editor-import SIGABRT/retry evidence remain preserved. The final exact-source first import and required local tests passed, followed by the fresh final CI builds and qualification runs. There is no physical Windows 11/NVIDIA owner acceptance, ordinary worker adoption, Ready/merge/default promotion or runtime publication established by this review.",
    "",
    "The machine-readable addendum binds the detailed platform audits, all source/case log/trace/PNG hashes, exact reviewed source and retained original finding. Complete source and evidence claims remain in those files; this prose is a comparison guide.",
    "",
    "| Review artifact | SHA256 |",
    "|---|---|",
]
for path in ("build/review-physics/final-e034f229/review-final.json", "build/review-physics/platform-windows-final-e034-review.json", "build/review-physics/platform-linux-final-e034-review.json", "build/review-physics/final-publication-source-review.json"):
    lines.append(f"|`{path}`|`{inputs[path]}`|")
(OUT / "final-source-platform-addendum.md").write_text("\n".join(lines) + "\n")
print(json.dumps({"json": str(json_path.relative_to(ROOT)), "sha256": hashlib.sha256(json_path.read_bytes()).hexdigest(),
                  "markdown": "build/review-physics/final-source-platform-addendum.md", "class_a_findings": 0, "class_b_findings": 0}, indent=2))
