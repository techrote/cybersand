---
title: Small detached RedBrick to native granular debris
status: Current
document-kind: audit
scope: Fixed sixteen-cell Sand/Rust tangent on a branch dependent on unchanged Draft466; existing granular rules and larger rigid response retained
canonical-for: [workbench-small-debris-20261107-evidence]
last-reviewed: 2026-11-07
related-documents: [../architecture/workbench-freed-objects.md, ../architecture/inertial-cellular-v1.md, 2026-11-07-workbench-brush-cut.md, ../reference/configuration-reference.md]
---

# Small cut-debris tangent

## Owner decision and source

The owner requested small detached RedBrick pieces as individual native pixels,
explicitly permitted Sand/Rust conversion, and then selected **existing Sand/Rust
granular rules** rather than extending the liquid inertial solver. The latter
currently admits Water/Brine and is not used here. The Noita contour/mesh redesign
and larger-body settling work remain paused.

The sole writer uses C:/khybersand/build/sol466-order-owned/khybersand on
codex/workbench-small-cut-debris-20261107. Its parent is unchanged Draft466
b140265d1a2ef2fd76787f8048dbcc5e9fa545ac. Native build/test source is
1826c9943c83166c7f36fb22085a6fac7a5dcfbd; the actual host receipt records the
later test-only source. No protected material source, catalogue/compatibility
lock, World contact arithmetic, liquid policy, rigid mass/inertia, gravity,
damping, gains or force/correction cap changes. No main/default promotion,
Ready, merge or ancestry rewrite is authorized.

## Design choices

- Count the complete **remaining component**, inclusively:1..16 cells becomes
  debris;17 or more keeps the prior rigid route and capacities. This is occupied
  cell area, not bounding-box area. Native callers default0 for old controls;
  this tangent's ordinary workbench controller requests16. No new menu/setting.
- Reuse the complete native eligibility proof. Anchors, hot/stateful, foreign,
  masked, unresident, pending-event and failed-source exclusions remain binding.
  Smallness is not clearance. Existing noncohesive boundary admission is Sand
  and ordinary FreeMass Water; Rust contact is still a foreign-contact refusal
  for a later cut. This tangent does not broaden that source policy.
- Convert in place in sorted y,x order, alternating Sand2/Rust29 and starting
  with Sand:ceil(N/2) Sand and floor(N/2) Rust. One output cell replaces each
  brick cell at the same coordinate, ambient temperature and ordinary zero
  state. The conversion intentionally changes material identity/density; cell
  conservation does not claim unchanged calibrated physical mass or energy.
- Keep cells native-owned throughout. No aggregate source removal/restoration,
  Rapier body, body/proxy ID, new per-cell sidecar or liquid-IN dispatch is used.
  Normal external writes clear arrival history; subsequent actual transport
  supplies ordinary granular provenance. There is no supplied kick/velocity.
- Main preflights the exact saved recipe before commit. Native revalidates all
  tuples, masks, tick/revision and capacity, then DebrisCommitted phase8 fences
  ticks/mutation until the exact updated terrain is installed. End re-primes
  the unchanged live roster; existing RIDs, pose and motion survive.
- Unknown post-request outcomes fail-stop. A partially failed native write is
  quarantined; prefix counters describe returned writes, not an independently
  reconciled failed-write census. No retry replenishes material or motion.
- Append ordered version4 one-cell material stamps for authored replay. No new
  root schema or live-state serialization is introduced. The output is a fresh
  granular starting map when restored, not a continuation of current velocity.

## Executed evidence

Registration native/tests/fixtures/workbench_small_debris_001.json precedes
candidate execution. tools/sol281/workbench_small_debris.py retains each command,
exit, log and compiled dependency/source hash. Output has a separate1GiB cap
and5GiB reserve; old registrations and evidence are not changed or deleted.

| Executed scope | Windows | WSL Ubuntu24.04 |
|---|---:|---:|
| New small-debris suite, worker1 |230/230|230/230|
| New small-debris suite, worker4 |230/230|230/230|
| Retained brush geometry, workers1/4 |165 each|165 each|
| Retained tree520/6 + building356/5, workers1/4 |83 each|83 each|
| Existing lifecycle before/after commit |52|52|
| Canvas-body/fleet/canvas/pilot/input controls |PASS|PASS|

The new suite performs genuine support cuts at1,15,16 and17 remaining cells,
on hard-floor and Sand-bed cases. Paused native censuses independently confirm
output materials and that converted pixels vacate their source positions;
pre-existing bed Sand cannot satisfy that motion assertion. Each host run
advances at least120 real native ticks per primary case, with actual windows
recorded. Native matched-law tests execute exactly120 ticks.

Threshold0 creates the original16-cell rigid body. Mixed conversion retains
the existing17-cell body's actual RID/transform/velocity, resumes through the
fresh-sample fence, and preserves16 native grains. The test reads the saved
recipe back from disk, then uses ordinary Restore to verify fresh replay of
one body plus the blend. It also observes actual phase8 and departs the scene
while conversion is pending; the native owner and coroutine retire together.

Native optimized and strict ASan/UBSan each pass **1,742 workbench/debris checks
plus19,338 original transaction checks**. Leak detection is disabled. The new
native cases prove inclusive classification, deterministic source/output counts,
source cancellation, stale/duplicate refusal, absence of aggregate ownership,
full-eight-body capacity bypass and exact state-hash equality with normally
authored Sand/Rust before and through120 ticks. Anchored/hot/foreign refusals
are directly exercised with the small option. Masked/pending/unresident and
failed-world coverage also uses inherited shared-proof controls; do not relabel
every old case as a new small-option execution. Phase8 tick fencing is checked
through the fence predicate/save refusal and the unchanged first tick guard;
there is no claimed direct phase8 tick-call fault-injection campaign.

[Summary](workbench-small-debris-20261107/summary.json),
[build](workbench-small-debris-20261107/build.json),
[native commands](workbench-small-debris-20261107/native.json),
[host commands](workbench-small-debris-20261107/hosts.json), and
[runtime custody](workbench-small-debris-20261107/runtime-validation.md)
retain source/platform qualifiers. Four compact platform/worker ledgers in the
same directory preserve all cut receipts and nonempty native census coordinates;
all other coordinates in their complete bounded rectangles are explicitly Empty.
Raw full censuses/logs remain local with report/artifact hashes. The pending
representation field describes the current snapshot, not final output after it
returns to Idle; conversion receipts and cumulative counters identify the output.

## Limits, decisions and next action

**PASS for the executed bounded granular-conversion tangent.** This is a new
representation/material routing choice using unchanged material laws. It is
not an inertial-RedBrick material admission, Noita mesh implementation, larger
SOL recovery fix or general solver comparison. Keep the new dependent PR Draft
and #466 unchanged. Separate independent adversarial review is requested before
an owner integration decision. The owner can assess whether small fragments
crumbling feels useful before choosing any later threshold or geometry design.

The current Linux build's supported ABI-floor blocker remains; Windows uses
LLVM-MinGW, not MSVC, and no instrumented extension-host sanitizer is claimed.
Small functional timing does not establish the original CPU gate or universal
60Hz. Preserve84/84 clearance failures,64/84 depth failures,36/36 async overlaps,
1,452/1,452 refusals, old CPU failures,#365, hard exclusions and tiny RedBrick
1e-9 filter. No historic hashes, failure denominators or frozen guards change.

## Documentation checklist

Canonical freed-object rules, interface/action/phase layout, capacities,
controls, build instructions, handover, roadmap, documentation route and an
additive retrieval question are updated together. No new contact-law ADR,
material catalogue identity or liquid-IN design is selected. Ownership is the
same exclusive native World, with main-thread-only collider installation and
immutable copied worker replies. Source/runtime identity and repository gates
remain separate from functional and physical acceptance.

All nine source/documentation gates pass at the recorded checkpoint:
[checks](workbench-small-debris-20261107/checks.json). The fresh rebuilt Linux
artifact again fails the unchanged2.34 ABI floor with GLIBC2.35, separately
retained in [ABI receipt](workbench-small-debris-20261107/abi.json). The
[raw artifact index](workbench-small-debris-20261107/artifact-index.json)
authenticates local logs, binaries, full censuses and source helpers. The
measured evidence footprint is273,427,445 bytes with15,136,088,064 bytes free.
The native optional store reports278,384 bytes, up176 from the brush build;
no new per-cell sidecar is introduced. Both worker4 cohorts actually observe
four workers; that is participation, not utilization or60Hz proof.

Two read-only agent reviews found no production P1/P2 blocker. Their test
feedback strengthened source-vacancy, disk round-trip and phase8 retirement
checks before actual host qualification; no result-driven threshold or law
tuning occurred. Request separate independent adversarial review before any
owner integration decision. Existing workbench windows are not reset or closed.
