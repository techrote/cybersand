---
title: Issue 11 focused barrel-support repair, 2026-09-13
status: Current
document-kind: evidence
scope: Current-source masked-material, bounded-ejection and ordinary rectangle granular-bearing acceptance
canonical-for: [issue-11-repair-evidence]
keywords: [issue 11, barrel, granular bearing, embedding, excavation, ejection, P4, P5]
last-reviewed: 2026-09-13
related-documents: [2026-09-12-issue-11-reconciliation.md, 2026-09-09-physics-characterisation.md, 2026-09-09-issue-10-granular-policy.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# Issue #11 focused barrel-support repair, 2026-09-13

## Disposition

**Current source satisfies issue #11 for the documented ordinary rectangle/load
envelope.** An 8 by 14, mass-1 rectangle yields into supported Sand, establishes
cellular-owned local bearing, and loses that bearing when the real bed is removed.
The repair also removes masked-source proxy feedback and prevents bounded overlap
ejection through hard terrain or another body's mask. Native cells remain material
authority; main-thread Rapier remains rigid-body authority; no granular Rapier
collider, material erasure/restoration, sparse particle, fixed-height clamp or
second support owner was introduced.

This record supersedes the disposition, not the observations, in the
[September 12 negative reconciliation](2026-09-12-issue-11-reconciliation.md).
The #9 characterization and #10 policy records remain historical evidence at
their original source identities.

## Source and artifact identity

| Item | Identity |
|---|---|
| Workspace source found at intake | `fc4d15d9c0d673e78f9baa4acf7500f28282196a`, `codex/reconcile-architecture-gates`, clean |
| Integrated #9/#10 repair base | `dad1230fdd7e3dbe02b6a78b56107a0005201930`, `codex/issue-9-10-reconciliation` |
| Isolated worktree/branch | `C:/kybersand/worktrees/issue-11-repair`; `codex/issue-11-repair` |
| Reconciled repair intake | `76ac3f7b137001c59862fa573fb113dbe349f5fe` after applying the dated #11 reconciliation to the integrated base |
| Stable code/evidence commit | `f8720d331e653ff40c12149dc1b7164724accd9f` |
| Final Windows extension | SHA-256 `85b0c1e730dd930ac765361afc2eee3ffa35d2f5012936b113f3394a92e4f21a` |
| Godot / godot-cpp / Rapier | Godot `4.7.stable.official.5b4e0cb0f`; godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`; Rapier `0.35.2` Windows SHA-256 `4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180` |
| Web side modules | compat SHA-256 `c531526d728234e627e880fcc8ff71066fdb51bbbab9f829b454ec28e1961715`; threaded SHA-256 `4e40cae70d7adaca6462d95668da5a2b1a1bb7ac930677fa141c02ab43b768ae` |

The retained raw root is
`C:/kybersand/validation/local/2026-09-12-issue-11-repair/`. Its final manifests
bind the source hashes and generated artifacts. The tracked Windows DLL remains
an intentional uncommitted build product, consistent with repository handover
policy; the intake DLL is preserved under `intake/`.

## Defect classification and repair

| Concern | Current-source classification | Repair |
|---|---|---|
| Masked-source feedback | Acceptance-critical and broken at intake | Rule dispatch carries the stored source material explicitly. A stored cell beneath a transient body mask defers its cellular kernel to bounded overlap reconciliation, so the Wall occupancy proxy cannot become material/contact authority. The regression retains exactly one Sand cell, the body mask, and zero proxy-derived contact impulse. |
| Barrier-aware ejection | Real and required for ownership/conservation acceptance | Candidate endpoints and their bounded half-cell path must avoid stored hard surfaces and masks belonging to other bodies. The source body's own mask is traversable. No route retains the complete source cell and reports unresolved overlap. Native and fallback hard-floor/second-body regressions preserve one Water payload. |
| Persistent bearing | Acceptance-critical and absent at intake | Each current coupling sample scans only the rasterized body's downward exposed cells. Actual stored support-capable material must pass #10's local 3 by 3 packing/last-tick stability policy. Active grains paused outside the selected interest region are ineligible. The cellular result supplies a yielding load impulse and a bounded 99-percent correction of only the just-observed downward travel at settled velocity. |

## Bearing contract and bounds

Bearing is recomputed from current cells on every accepted body sample; there is
no per-body support cache. The response uses gravity impulse `92/60` per mass/tick,
velocity response `0.18`, capacity `2.0` per qualifying exposed sample, global
cap `20`, settled-velocity threshold `4 px/s`, and at most `0.5` cell positional
correction multiplied by `0.99` of measured downward sample travel. Legacy
cellular impulses and bearing share one cellular owner and cannot stack above
the bearing target. The ordinary result ABI remains 11 input / 9 result floats;
diagnostics append bearing and support-sample observations only.

This is local bounded bearing, not a connectivity solver. Missing, moving,
excluded-region or liquid samples produce zero bearing. Excavation therefore
removes support on the next current sample. Corrections older than one body
sample remain suppressed; results older than eight are rejected by the existing
bridge policy. No hot-loop allocation, component scan, load history or hard
terrain shape was added.

## P4/P5 core gate

`r7-core-final-3seeds/` contains the post-review 1,800-tick gate at commit
`f8720d3`; all 12 cases pass their encoded assertions.

| Case | Seeds | Peak depth | Final depth | Worst final-10-second descent | Result |
|---|---:|---:|---:|---:|---|
| P4 Sand, one-height drop | 3 | `3.75` | `0.00` | `0.00` | Pass; yielded during impact, bearing persists, no floor |
| P4 Sand, four-height drop | 3 | `6.65` | `0.47..1.49` | `+0.03` | Pass; below the eight-cell provisional limit, no floor |
| P5 excavation at tick 600 | 3 | pre-removal depth `0.00` | depth `41.90..43.54` at tick 661 | zero support samples between removal and tick 661 | Pass; downward velocity `82.37..82.55 px/s`, then later granular re-bearing |
| Hard-floor control | 3 | `0.00` | `0.00` | `0.00` | Pass; Rapier-only hard contact, zero granular samples |

`r7-core-final-120s/` repeats the finalist for 7,200 ticks: one-height peak/final/
last-ten are `3.75/0.00/0.00`; four-height are `6.65/1.48/+0.01`. Neither reaches
the deep floor. P5 again drops after excavation and later re-establishes support.

The P4 initial/final fixture contains exactly `36,864` Sand and `1,122` Wall
cells, total `50,274` cells in the sampled rectangle, with zero duplicates,
telemetry overflow or tick-time chunk allocation. P5's explicit excavation is
the declared external removal and is not counted as conservation failure.

## Accepted and stress envelopes

`r8-envelope-reviewed/` covers representative one-seed cases after the review
repairs. The accepted ordinary envelope is: current 0/1-sample-age rectangular
coupling; deep supported Sand/Dust/Salt; mass `0.5..2`; 0/45/90-degree initial
orientation; 0.5x/1x/2x rectangle size; the tested slope (local peak `3.85`);
mixed seams; three spaced simultaneous barrels; and pause/re-entry. All avoid the
deep floor and finish with final-ten-second descent at or below `0.03` cell.
Water receives zero granular samples and reaches the hard floor as the separate
liquid control. A one-cell granular film likewise supplies zero bearing.

Stress/known limits are explicit:

- eight-body-height impact peaks at `10.99` cells, outside the ordinary depth
  envelope, although it later settles;
- artificial body-sample delays of two/four ticks end at `157.47/147.76` cells
  with `+6.67/+12.42` cells of final-ten-second creep; age one peaks at `6.03`
  and settles;
- sustained async publication gaps, thin/unsupported beds, crowding beyond the
  spaced three-body case, extreme rotations, fast/thin barrier CCD and arbitrary
  shapes are not accepted;
- bearing is central and downward-load oriented. General torque, fracture,
  structural integrity, coherent membership and sparse ballistics remain outside
  #11.

## Independent review and dispositions

A task-neutral Terra xHigh read-only review attacked the stable diff. It found:

1. active grains excluded by the selected interest region could appear stable;
2. ejection paths rejected hard material but could cross another body's mask;
3. pre-review manifests did not attest the then-final fixture hashes.

Sol accepted all three. Commit `f8720d3` adds native/fallback region and
second-body regressions and the final evidence was regenerated from that exact
commit. No other architectural change was accepted.

## Platform and contract validation

| Scope | Retained result |
|---|---|
| Native/fallback/bridge | `r9-final-regressions/`: 55/55 native tests plus instrumentation, 11-case fallback interaction suite, failed-world regression and Rapier manual-step regression pass |
| Desktop asynchronous owner | `r9-desktop-async-reviewed/`: three 1,800-tick seeds, peak `3.80`, no floor, no worker overrun, exact Sand count, mostly age zero with bounded accepted older samples |
| Web compatibility | exact-commit export plus `r9-browser-compat/browser-result.json`: isolated Headless Chrome 152, 25/25 cases; five P4 seeds peak `3.75`, final/late `0/0`, zero overflow/allocation |
| Web threaded | exact-commit export plus `r9-browser-threaded/browser-result.json`: isolated Headless Chrome 152, 25/25 cases; same five P4 and hard-control results with native Auto workers |
| F01/F02 | failed-world publication/reset and interest pause/re-entry regressions pass; paused active grains cannot provide bearing |

An earlier pre-review async run recorded one `13.31`-cell transient while only
1,611 of 1,800 body samples produced distinct accepted results. The clean
post-review rerun passed, but sustained result starvation is therefore retained
as a stress limitation rather than hidden by the passing rerun.

## Issue and #12 effect

The source/evidence criterion for issue #11 is satisfied inside the accepted
ordinary rectangle/load envelope. The completion publication identifies code
commit `f8720d3`, the artifact identities and this record before administrative
closure.

The precise downstream statement is: **#11 support prerequisite is satisfied
within the documented ordinary rectangle/load envelope.** This does not admit
general granular rigid-body behavior, arbitrary coherent bodies, structural
materials, soliding, fracture, torque redesign or the stress cases above.

## Documentation and repository gates

The current docs checker and repository checker were executed after the canonical
updates. They retain the same six missing legacy expected-fact sources; the
repository checker additionally reports the expected source-versus-published
runtime identities, including the intentionally rebuilt Windows DLL. These are
inherited provenance/publication failures, not repaired or hidden by #11.

The historical M11 consistency checker passes 18 records and 28 source hashes.
The frozen retrieval set reaches 32/32 canonical hit-at-k (`MRR 0.8385`), the
challenge set 16/16 (`MRR 0.8594`), and the architecture programme set 5/5 with
the updated #11 question at rank one (`MRR 0.75`). Raw gate outputs are under
`r10-docs/` in the retained evidence root.
