---
title: Issue 15 acceptance coverage and G-C review
status: Current
document-kind: evidence
scope: Read-only audit of retained source-matched characterization and completed focused measurements; no new campaign
canonical-for: []
last-reviewed: 2026-09-11
related-documents: [../operations/liquid-characterization.md, ../operations/architecture-programme.md, 2026-09-11-programme-gate-reconciliation.md]
---

# Issue 15 acceptance review

Recorded by Codex, 2026-09-11, after G-L reconciliation and #16 completion.
**Acceptance is satisfied for characterization; no new experiment is necessary.**
This conclusion follows coverage/identity review, not a desire to unblock #17.
Original #15 [preparation](https://github.com/techrote/cybersand/blob/cdb4c2a6df0248c76e7957fd09cae77655ec974f/docs/audits/2026-09-10-issue-15-liquid-characterization.md)
and [completed results](https://github.com/techrote/cybersand/blob/cdb4c2a6df0248c76e7957fd09cae77655ec974f/docs/audits/2026-09-10-issue-15-liquid-results.md)
remain unchanged on their research branch. Preparation's pending labels are
historical; the completed result supplies the later controlled observations.

## Identity and retained source compatibility

Completed result `cdb4c2a6df0248c76e7957fd09cae77655ec974f` follows preparation
`903e40f27a1c9abf2e50f1d9e5817c7855b7d21b`. Native inputs are identical between
those commits. Source control is `b16408c`, including current Water `8f4ffb9`;
the observed delta adds three diagnostic counters and a standalone harness,
without solver/default changes. Baseline-source and observer-off controls retain
matching semantics. This instrumentation stays on the research branch because
tail-cost neutrality was not demonstrated.

Verification at `C:/kybersand/validation/local/2026-09-11-gate-reconciliation/`
checks 18 source-input identities per executable against the appropriate Git
commit (including checkout line endings), both executables/compiler, completion
metadata, all576 raw JSONL hashes and both summary hashes. No physics process or
new timing measurement is launched. Raw evidence remains at
`C:/kybersand/worktrees/issue-15-liquid-characterization/validation/local/issue-15/`.

| Identity | SHA-256 |
|---|---|
| Baseline-source executable | `497e7269cf5d99fcc40576cfb22caa3353b5a4de406fc98e7f38e4b0023dfca1` |
| Observed executable | `df3447b98f5b7532575855a1eb922cfddfbb0998118ce9345fd7a487836b3435` |
| Completed audit | `521f18435312ee4aa272682784ccd6a7a44bbf2459420b14c95eb2cf7d959ad1` |
| Integrity manifest | `3fb614f8c008fc520ed01d65838c6c8aa98b1d788d898829fefb102cd907149b` |
| Behavior summary | `c770272c1a8bad80eda64159fa3252b473de33dc5bf8a5f34d85a6e58a5541bd` |
| Timing summary | `b4bea99395c2aa84f30e6d77a98bb6e3b013a6e64dc5cb3224fd6e39acd5960e` |

Historical reuse is claim-specific: [#9](2026-09-09-physics-characterisation.md)
at10e8153 establishes viscosity/permeability separation and Oil nonpenetration,
but its old Mercury rate is superseded. [#10](2026-09-09-issue-10-granular-policy.md)
through372bfb3 supplies198 all-liquid pair cases,62 permeability cases, protected
period30,119 nonreactive Water controls and26 reaction cases. [#13](2026-09-09-issue-13-transport.md)
through4bead55 supplies opt-in transport/cadence,480 corrected sampling runs and60
exact controls; its older Water trajectories and rejected injector/depth results
are not current evidence. [Water follow-up](2026-09-10-water-leveling.md) at8f4ffb9
supplies24 old/new cases each,97,920-unit exact basins,30 unchanged Mercury/powder
controls and72 dated native/Web transport cases. Its shared-host timing is
insufficient for causal cost attribution; #15 provides the registered focused
timing comparison. Profile hashes alone cannot identify the solver revision.

## Coverage matrix

Classification uses exactly: **satisfied by retained source-matched evidence**
(R), **satisfied by existing Issue #15 focused evidence** (F), **still missing**
(M), **ambiguous / insufficient** (A). Source inspection is identified separately
from executed runtime evidence within R. Explicit limitations meet the issue's
requirement to record gaps; they do not authorize claims outside measured scope.

| Required dimension | Classification | Evidence and remaining limit |
|---|---|---|
| All11 quantities, kernels, exceptions and state | R | Current descriptors/dispatch plus per-material table below and original source inventory. Whole-cell counts differ from Water mass. |
| Lateral mechanism, adhesion, delay and cadence | R | Current source; Water three-quarter relaxation/12 delay/48 film, generic gate after gravity, three specialized bypasses. No universal solver judgment. |
| Exchange/permeability and player/liquid policy | R | #9 causal controls, #10 all198 pairs and62 rate cases, #13 and Water protected references. Historical Mercury rate explicitly superseded. |
| Chemistry interaction order | R | Four-tick pair lane before dispatch; kernel-specific cure/cooling/burning/erosion ordering. Reactive counts remain conversions, not conserved chemical mass. |
| Sleep versus deterministic mobility | F | 352 behavior runs; five translations/mirrors,1/4 workers,quiet3/4096,off/on/repeats; four whole-cell trajectories differ in every translation. Single-cell scope only. |
| Water flow, residual, rest and film | F | Entire trajectories identical between thresholds; wide418..435 at1800 while active; narrow46 rest;48-unit film immutable. Retained old/new front/level metrics remain separately attributed. |
| Release, wake/re-entry and paused regions | F | Shelf removal before601; first descent602 in all support cases; exclusion901..960 preserves content; existing re-entry at961. No catch-up change. |
| Exact quantity, state/temperature, protected controls | F | Every process exact quantities/no conversion or prepared allocation/overflow; matching worker/observer/repeat groups; identical-input55 native/C11 tests retained. #10/#13/Water support wider historical cases. |
| p50/p95/p99/max/total and work | F | 224 processes/112 interleaved pairs,2048 ticks,120 warmup and separate post-re-entry windows. Scheduled cores, active blocks and visited cells remain distinct. All85 flagged pairs retained. |
| Observer/source neutrality | F | Off/on plus unmodified-source controls have matching semantics. Neutrality means behavior, not zero overhead. |
| Heap-scale yield and desirability | A | Single-cell evidence cannot infer a constitutive law, unwanted heaps or macroscopic strength. No such model/change is admitted. |
| Cause of Water residual: precision versus finite horizon/thresholds | A | Sleep comparison rules out quiet3 in this horizon only. This bounded unresolved question justifies P; lower precision need not win. |
| Oil/Lava/Acid viscosity bypass intent; independent cooling/sleep | A | Mechanism inspected, intent unproven; reactive/lifecycle scope is explicit. No proposed change requires an extra diagnostic before G-C. |
| General reaction quantity units | M | Missing generalized contract; existing conversion accounting is retained. General FreeMass/yield work is non-admitted, so no broader campaign is required. |
| Named jet/spray deficit for M | M | No measured target. M implementation is held; P completion alone will not invent a target. |
| V visual benefit, orientation and render cost | M | Stable frozen inputs available; no visual benefit established. V's existing experiment is the bounded way to investigate; production renderer change is non-admitted. |
| Process/allocator/PMU/GPU, exact wake causes/write counts, cross-platform migration | M | Explicit evidence limits; no migration or universal performance claim. BlockSleep includes empty blocks; content hashes count changed ticks. |

No material unanswered question prevents the scoped G-C decision. Missing broader
semantics/benefit evidence causes non-admission or limits a later experiment; it
is not silently reported as satisfied runtime measurement.

## Per-liquid final coverage

All rows inherit current source and #10 pair evidence. R/F/A refer to the matrix.
All whole-cell liquids preserve two state bytes/temperature during moves; none
uses Water's partial quantity, coherent delay or supported-film adhesion. Pair
chemistry, where present, is sampled before motion on the four-tick lane and
returns after writing products. Source-side attempts and target exchange
eligibility are distinct; horizontal density swaps are forbidden.

| Liquid | Quantity / movement path | Lateral / timing and adhesion | Exchange / chemistry ordering | Scheduler and evidence / disposition |
|---|---|---|---|---|
| Water3 | state_a1..255 FreeMass, down/diagonal transfer first | Local floor(3*imbalance/4), tolerance1; state_b12, max merge/pre-decrement; supported<=48 film | Directional exchange; sampled Lava/Fire/Salt/Sodium/Sludge/MoltenGlass rules | R+F: all tested sleep trajectories equal; preserve current specialization, admit only P diagnostic. |
| Lava8 | Whole; specialized Lava | One lateral after down/two diagonals; descriptor224 bypasses mobility | Vertical exchange; sampled ignition/Ice melt before motion, pair quench/melt | R; chemistry writes affect activity, no independent sleep screen. A on bypass intent; retain. |
| Acid12 | Whole; specialized Acid, strength255 | Down/one diagonal/one lateral; descriptor64 bypasses mobility | Vertical exchange; pair Metal reaction first; two-tick erosion after failed movement, strength-24 | R; erosion/activity can differ from transport. No new corrosion or sleep claim; intent A, retain. |
| Oil16 | Whole; specialized Oil, burn in b | Down/two diagonals/one lateral; descriptor160 bypasses mobility | Source swaps disabled; ignition/extinguish/burn/emission before motion, Spark pair | R: protected nonpenetration; burning writes affect activity. Bypass intent A; retain. |
| Paste20 | Whole; generic YieldingLiquid | After gravity, mobility16/256 then up to2 lateral empties | Vertical exchange; no direct pair reaction | R+F: sleep censors later mobility, paired trajectories differ5/5. Liked heaps retained; no stress law. |
| Slush21 | Whole; generic YieldingLiquid | Mobility64/256, viscosity192 | Vertical exchange; no direct pair reaction | R+F: paired trajectories differ5/5, distinct cadence/rate; no tuning. |
| Brine24 | Whole; generic YieldingLiquid | Mobility224/256, viscosity32 | Vertical exchange; Sodium/Fire pair chemistry | R+F: mobile control differs5/5; desired late-rest behavior remains an explicit future requirement. |
| Cement30 | Whole; cure a180 then generic flow | Mobility80/256; two-tick cure rate4 Water/Brine,2 Concrete,1 air | Vertical exchange; cure/conversion precedes generic motion | R: lifecycle writes can sustain activity; no new pure-flow/cure isolation. Preserve chemistry/state. |
| Toxic Sludge32 | Whole; generic YieldingLiquid | Mobility192/256, viscosity64 | Vertical exchange; Water purification pair creates Water | R: generic early-return sleep mechanism applies; no new pure-flow comparison. Reaction-unit generalization M; retain. |
| Mercury33 | Whole; generic YieldingLiquid | Mobility160/256, viscosity96; void movement full rate | Powder exchange period30 with explicit wake deadline; no direct pair reaction | R+F: empty-space rest differs5/5; support fixture does not remeasure powder permeability. Preserve period30. |
| Molten Glass36 | Whole; cooling a180 then generic flow | Mobility32/256; four-tick cooling/reset by hot neighbors | Vertical exchange; cooling/Glass conversion before flow; Water quench pair | R: thermal writes can sustain activity. Independent cooling/sleep A; retain specialization. |

Mobility fractions are deterministic byte-range tests, not independent probability
claims. Generic failure has no retry deadline and precedes `lateral_due`; default
cadence1 adds no delay. Material-specific temporal lanes, movement eligibility,
partial redistribution, whole-cell moves and block activity remain separate causes.

## G-C disposition

[G-C](../operations/architecture-programme.md#g-c-staged-decision-2026-09-11)
retains distinct liquids/defaults. P is justified by the residual/film question
and now has independent G-L evidence. M is not justified for implementation from
C's evidence; it still waits on P/G-P and a named target/no-go review. V remains
justified to test frozen-authority presentation under its own visual/cost contract,
without a claim of measured visual benefit. Generalization/unification, new yield,
universal FreeMass, production velocity/history, widening and migration are not
admitted. No new measurements, no remaining G-C blocker, no #17 implementation.
