---
title: WEX-005 Water evidence synthesis and #45 disposition
status: Current
document-kind: evidence
scope: Issue #95 decision record — source-qualified synthesis of #49/#91/#92/#93/#94 Water evidence, separate deep-release / vented communicating-head / sealed-gas answers, and the explicit #45 disposition; no Water semantic, solver or production change
canonical-for: [wex-005-water-evidence-synthesis]
last-reviewed: 2026-10-23
related-documents: [../operations/water-hybrid-pressure-extension-programme.md, ../systems/water-design.md, ../decisions/ADR-005-water-model.md, ../operations/architecture-programme.md, 2026-09-20-issue-49-water-apparatus-v2-baseline.md, 2026-09-20-issue-91-wex001-water-body-baseline.md, 2026-09-24-wex002-water-sheet-blocked-disposition.md, 2026-09-24-wex004-decompression-disposition.md, ../research/lumped-gas-region-pressure-bookkeeping.md, 2026-10-23-lcb000-gate-a-water-pressure-admission.md]
---

# WEX-005 Water evidence synthesis and #45 disposition

## Decision summary

This is the [#95](https://github.com/techrote/cybersand/issues/95) synthesis.
It changes no source, Water semantics, solver selection, Cell layout, ADR or
production default.

| Question | Disposition |
|---|---|
| Q1 deep-release surge | **Unresolved deficit; not improved by any WEX lane.** The hybrid/sheet mechanism was never executed. Current-main outlet evidence shows no depth-dependent drive beyond saturated outlet cells. |
| Q2 Water sheets (#92) | **Still blocked by missing generic hybrid substrate.** Untested, not rejected. |
| Q3 #45 | **NARROW.** Bounded head-transmission research may continue to its admission/design phase only under explicit shared/vented-atmosphere assumptions, with deep-release surge registered separately. No implementation is selected. |
| Q4 equal levels | Valid only as a shared/vented-atmosphere control. Not a target for separately sealed headspaces or low-pressure/vacuum boundaries. |
| Q5 compartment pressure (#93) | **Useful research only.** No production architecture issue now. |
| Q6 decompression (#94) | **Narrow-use research; no production issue justified now.** |
| Q7 #18 | **Remains held, not no-go.** WEX supplies no concrete unmet directional-persistence target, and the bulk-head confound persists. |
| Q8 FreeMass/CellularYield | **Separation unchanged.** Nothing here selects liquid unification. |

The disposition becomes the canonical routing when the PR carrying this record
merges. It does not close #45, #14, #18 or #90 by itself.

## Inputs and identities

**Source:** authoritative `main` at
`9012425e3bba62aa1fefb15ea5d7306f196b8da2` (2026-10-23 fetch). Decision branch
`claude/lcb000-water-architecture` from that commit. No source file is modified.

**Current Water source check.** `World::transfer_water` and `World::update_water`
in [world.cpp](../../native/src/world.cpp) are byte-identical between #49 merge
`4e4381d304458ef9b0dfa9336cfe08e8cc162210` and current `main` (function-body
SHA-256 `70327394…eb7b2` and `ac6a1d60…e80e61` respectively, extracted by text
range and hashed). Other `world.cpp` changes since #49 (MAT-002 materials,
player/material playground commands, REM-002 body support, Stage-3B witnesses)
do not alter those two Water rules. Inspection evidence only; the runtime
evidence follows.

**Current-main apparatus rerun.** The `Issue 49 Water apparatus v2` workflow
re-runs the unchanged preregistered campaign on pushes to `main` that touch its
input paths. Latest run: **39739371203** (push, 2026-10-22, success) on
`90a5bfc9a0664ca6eb78c00a18619aa4409619b1`, an ancestor of current `main`.
`git diff 90a5bfc..9012425` is empty for every workflow input path, so that run is
source-matched to current `main` for this apparatus.

- runner/apparatus/fixture/metric schemas: `water-evidence-runner-v2`,
  `water-apparatus-v2`, `water-fixtures-v2`, `water-equilibrium-v2`;
- manifest `source_sha256` `f698cf52399c2ed0a085bf33437708b525db2fdd2491555ae8f0ce41ec2d3919`;
- built `water_issue49` SHA-256 `b88de6e65c49700fbbcbaf16ef8bdd01669fc96e8ab1f018a1e9157aa59b3f41`;
- platform `Linux-7.0.0-1017-azure-x86_64-with-glibc2.39`, Python 3.12.3;
- artifact `issue49-water-v2-39739371203`, ID `12409012082`, digest
  `sha256:ae4270463b369dd347a764dfea952411f7fd27d7d0b5e0d03f387c5b0f4239e8`
  (retention expires 2026-11-21; the values below are copied here so the
  record outlives the artifact);
- completion manifest: 120 registered, 120 accounted, 120 success, 0 duplicate;
  every case mass-conserved with zero post-setup allocations. Reading the
  retained per-case JSON, the 1-worker and 4-worker runs gave identical
  `final_mass`, `receive_mass_tick300`, `moved` and `water_transfers` in all 60
  pairs.

This is Linux native runtime evidence. It is not Windows runtime, browser,
Godot-scene or owner visual evidence.

**Landed WEX/apparatus records consumed:**

- #49 [v2 registration](2026-09-20-issue-49-water-apparatus-v2-registration.md) and
  [v2 Current-Water baseline](2026-09-20-issue-49-water-apparatus-v2-baseline.md)
  (PR #104, merge `4e4381d3…`, proving run `35536086473`, artifact `10613591045`);
- #91 [generic Rapier↔Water baseline](2026-09-20-issue-91-wex001-water-body-baseline.md)
  (PR #102, merge `3fa6728d…`), reconciled by REM-002 in
  [the #81 forensics record](2026-09-24-rem002-issue11-integration-forensics.md);
- #92 [blocked disposition](2026-09-24-wex002-water-sheet-blocked-disposition.md)
  (PR #127, merge `7e17007f…`);
- #93 [lumped gas-region research](../research/lumped-gas-region-pressure-bookkeeping.md)
  (PR #103, merge `195a7ce1…`);
- #94 [decompression disposition](2026-09-24-wex004-decompression-disposition.md)
  (PR #105, merge `723656c9…`);
- [#26 post-merge review](2026-09-19-issue-26-post-merge-review.md) (apparatus v1 is
  historical/qualified context only).

**Unmerged exploratory input (not acceptance evidence).** Branch
`claude/water-pressure-prototype` at `7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09`
holds a 2026-10-19..22 snapshot-head/overfill/velocity/trapped-air prototype as
patches on `620826f5…`. Its README records local MSVC Windows runs of
unregistered scenes. The 2026-10-22 review in
[#200](https://github.com/techrote/cybersand/issues/200) found gas-amount,
merge, reseal and hashing defects. Its numbers are not used for any
disposition below. The record matters because it shows a bounded snapshot-head
family *can be built* in the current scheduler, and because LCB-001 names it as
the candidate to port.

## Evidence matrix

Category key: **C** Current implementation fact · **E** experimental/research
result · **O** owner intent · **A** accepted ADR constraint · **U** unresolved
question · **G** platform/evidence gap.

| # | Input | Finding | Category | Qualifiers |
|---|---|---|---|---|
| 1 | Current Water control | Pairwise 8-bit FreeMass transfers; gravity then diagonals; lateral request = 3/4 of the positive difference, one-unit rest tolerance; no persistent direction, pressure or gas state. `Empty` carries no pressure, so every World behaves as one shared atmosphere. | C, A | [water-design](../systems/water-design.md), [ADR-005](../decisions/ADR-005-water-model.md); unchanged since #49 (see identities). |
| 2a | #49 v2 head outlets (current-main rerun) | Receive mass at tick 300 in the six 1-worker views: shallow `21459, 20650, 21536, 20749, 21710, 20646`; medium `27401, 27272, 27174, 26499, 27274, 27095`; deep — **identical to medium in every view**, also at tick 120. The deep fixture holds 302,940 units versus 168,300 for medium. | C, E | Linux runtime run 39739371203; matches historical v1 (#26: medium = deep = 27,223 median). |
| 2b | #49 v2 communicating-head controls | `unequal-head-two-limb-v2`: 6/6 `not_reached` for half-life and ≤1-cell targets by tick 4800, starting from a 24.000-cell difference (original baseline final differences 23,580–24,420 milli-cells). `communicating-pools` and `unequal-head-communicating-reservoir-v2`: 6/6 `not_reached`. `calm-settling`: 6/6 reached, median tick 3360. | C, E | Same in the 2026-09-20 baseline and the 2026-10-22 rerun. Fixtures are open-topped boxes (floor plus side walls, roofed only over the connecting passage), so they are shared/vented-atmosphere controls. |
| 2c | Deep-release / dam-break surge fixture | **None registered.** `fast-dump` uses a release gate but measures wall gap and final spread, not front speed or centre-of-mass travel against depth. | U, G | Gate E of [#213](https://github.com/techrote/cybersand/issues/213) plans the `lcb.dam.water.freemass.reference.v1` preset; it is not yet registered. |
| 3 | #91 generic body splash | A generic rectangular Rapier body entering Water causes real outward displacement before floor contact (Dn: 7,395 units above the surface, 3-cell excursion). Exact mass conserved. | E | Linux Godot run 35532203400. This is body-driven displacement, not deep release. |
| 4 | #91 hard boundary | Characterized 2026-09-20: Water crossed the hard floor before the body touched it. REM-002 (#81) then added barrier-aware ejection, and the current WEX-001 regression ([test](../../godot/tests/test_wex001_water_body_baseline.gd)) requires zero forbidden-floor Water mass. | C (repaired), E (history) | Bounded generic coupling only; no dynamic ownership substrate. |
| 5 | #92 Water sheets | No sheet arm ran. #12 Stage 4 / dynamic singular-owner handoff remains blocked (soliding programme and lifecycle unchanged since 2026-09-24). | U | BLOCKED, not no-go. |
| 6 | #93 compartment pressure | Lumped region amount + free volume → derived absolute pressure. Merges are cheap; splits are lazy and bounded. Water sees only a read-only `surface_pressure` boundary query. No executable proof or churn cost exists. | E | Research only. Does not transmit head through saturated Water. |
| 7 | #94 decompression | NARROW-USE: a finite local breach event with occlusion suppression, stale-topology cancellation and capped work. No routed, corner or room-scale flow. | E | Linux Godot, one worker, one generic body. |
| 8 | #18 directional memory | Held. No measured unmet directional target. The bulk-head confound is still present (rows 2a/2b). | U | Architecture programme G-M gate. |
| 9 | #12 hybrid substrate | Cells-owned read-only Stage-3B discovery. Production dynamics/Stage 4 blocked. | C | Sole owner of reversible soliding and hybrid handoff. |
| 10 | Owner intent | Backend-first, generic-body barrel, convincing depth-dependent bulk behaviour rather than CFD (2026-09-20). Game-grade approximation; residual units and films acceptable if visually settled and cheap (recorded in the 7ef2aac README, 2026-10-22). Opt-in four-family manual comparison with Water as common test material (owner-approved [#200](https://github.com/techrote/cybersand/issues/200) amendment, 2026-10-22; [#213](https://github.com/techrote/cybersand/issues/213)). | O | Owner preference among algorithms is explicitly *not* decided. |
| 11 | Platform gaps | All runtime Water evidence above is Linux CI. No Windows runtime, Web runtime or target-hardware Water-head measurement exists. No owner H review of any head mechanism. | G | — |

## Q1 — deep-release behavior

**Answer: the owner-observed deep-release deficit is real and unresolved. No WEX
lane improved it, and none was in a position to.**

- The only WEX mechanism aimed at it, upper-volume Water sheets (#92), never ran.
  There is no evidence for or against it.
- #91 shows that *externally driven* body entry produces credible displacement.
  That is a different mechanism from unrestrained deep Water collapsing outward,
  and it cannot stand in for it.
- The source-matched depth proxy is unambiguous: on current `main`, a reservoir
  with 1.8× the mass of the medium reservoir delivers byte-identical outlet
  discharge at ticks 120 and 300 in every registered view. Extra column depth
  above the saturated outlet supplies no drive. This matches the "slow draining
  slope" observation.
- No registered dam-break/surge fixture exists, so surge front speed and
  centre-of-mass travel against depth are **unmeasured**. Communicating-head
  equalization (row 2b) is not used as a substitute.

## Q2 — production value of Water sheets

**Still blocked by missing generic hybrid substrate.** No production migration
issue is justified. Re-entry stays as the
[WEX-002 re-entry gate](2026-09-24-wex002-water-sheet-blocked-disposition.md#re-entry-gate)
defines it.

## Q3 — #45 disposition: NARROW

**#45 continues as the production saturated-head architecture owner. Its scope is
narrowed as follows.**

1. **Boundary assumption.** The question is bounded head transmission through
   saturated connected Water **under a shared/vented atmosphere**. That is Current's
   implicit model and the assumption of every #49 v2 fixture. Sealed-headspace
   targets, gas-amount state, vacuum/low-pressure boundaries and decompression
   are **out of #45 scope** until a separately admitted gas-boundary owner exists.
2. **Two separate questions.** Deep-release surge and vented communicating-head
   leveling are evaluated separately. Before any candidate code, #45 must
   preregister a versioned deep-release/surge fixture family (front position,
   occupied/mass centroid and discharge against initial depth). This extends the
   #49 v2 fixtures; it does not mutate them. It may reuse the Gate E Dam Break
   geometry once that preset is source-registered.
3. **Admission/design first.** The next permitted step is #45's own admission
   phase: compare bounded families (derived per-tick head summaries, a bounded
   scalar carrier, staged propagation, or the snapshot-head family recorded on
   `7ef2aac`), record ownership, scratch/capacity, sleep/wake, determinism,
   failure semantics and state needs, and freeze thresholds against the
   current-main #49 v2 control **before** candidate code. Apparatus-v1 numbers
   cannot set thresholds.
4. **No production selection here.** A production change additionally needs
   candidate evidence on the registered fixtures, focused owner H review, an
   ADR-005 amendment for any new authoritative Water state (overfill, velocity,
   gas), a separate implementation/default-switch authority and the full
   platform gate matrix.
5. **Relationship to LCB.** The owner-approved opt-in Liquid Comparison Build
   ([#200](https://github.com/techrote/cybersand/issues/200)) is a *separate
   experimental lane*. Its terms are in the
   [LCB-000 Gate A record](2026-10-23-lcb000-gate-a-water-pressure-admission.md).
   #45 does not wait for LCB, and LCB does not complete #45. #45 may consume the
   LCB `pressure_flow_v1` family as one candidate family **only** through this
   registered apparatus with source identity. LCB manual-feel preference is owner
   input, not #45 acceptance. #45 must not start a second competing pressure-backend
   port while LCB-001 owns the opt-in port; a later production proposal evaluates
   or promotes that backend rather than re-porting it.

Why the other dispositions were rejected:

- **Proceed (unnarrowed):** it would leave the gas-boundary question implicit and
  invite the vented equal-level fixture to be used as a sealed-room oracle.
- **Recharter to compartment-pressure boundary conditions:** #93 is research-only
  with no executable cost evidence, and a surface-pressure boundary still does not
  transmit head through saturated cells (row 6).
- **Defer because hybrid behaviour meets the need:** there is no hybrid evidence
  (row 5).
- **No-go / authored sources and sinks:** the deficit is reconfirmed on current
  source (rows 2a/2b), it affects generic deep Water rather than rare set pieces,
  and the owner continues to pursue it (row 10).

## Q4 — communicating-head physical assumptions

An equal free-surface level is a valid target only when **all** of these hold:

- both free surfaces open to the **same** atmosphere (vented/shared-pressure
  headspace — every Current World, and every #49 v2 fixture);
- a continuous liquid path through the connection;
- the same liquid density, with no body load, source/sink or active input;
- a declared quantization/residual tolerance (≤1 cell in #49 v2).

Other cases:

- **Separately sealed headspaces:** equilibrium satisfies
  `Δh = (p_A − p_B)/(ρ·g)`, with each headspace pressure set by its gas amount
  and free volume. Equal levels are **not** a target. Current has no gas state,
  so it has no defined sealed target. Any sealed fixture needs a gas-state model
  and preregistered expected pressures (LCB sealed-air arm: experimental only).
- **Configured low-pressure/vacuum boundaries:** absolute pressure is ≥ 0;
  "suction" is a pressure differential, not negative absolute pressure. No Current
  or #45 target exists. #94 covers only direct local breach events.

## Q5 — compartment pressure

**Useful research only.** A production gas-region issue needs a concrete use
case, an owner, and measured topology-churn cost on real CyberSand geometry (the
measurement list in the
[#93 research](../research/lumped-gas-region-pressure-bookkeeping.md#what-a-later-production-proof-must-measure)).
None is admitted here. It is not merged into Water semantics.

## Q6 — decompression

#94 ran (admitted by #93) and is **NARROW-USE**. **No later production issue is
justified now.** Re-entry needs a concrete use case plus an admitted gas-region
or portal owner, and a new proof for routed or corner flow.

## Q7 — #18 directional memory

**#18 remains held.** WEX produced no concrete unmet directional-persistence
target, and the saturated-head confound (rows 2a/2b) still contaminates
directional references. Reassessment follows a #45 accepted bulk baseline or
no-go. LCB-005 [#212](https://github.com/techrote/cybersand/issues/212) is an
owner-approved opt-in comparison family with retained velocity. It is not #18
G-M admission, allocates no production bits, and counts as #18 evidence only
through #18's own registration.

## Q8 — FreeMass versus CellularYield

**Unchanged.** Water stays fractional FreeMass; most other liquids stay whole-cell
CellularYield-style with Oil specialization. LCB's per-material family policy and
Water-for-all-four comparison (Gates C/D of #213) are opt-in experimental
settings with unchanged production defaults. They are not liquid unification.

## Downstream routing

`#49 v2 control (current-main rerun) + #91/#92/#93/#94 -> #95 (this record) -> #45 NARROW: admission/design + surge registration -> directional-reference reassessment -> #18 admission/no-go -> #20/G-B if justified -> G-final`.

- #14/G-final: open and unchanged.
- #20/B: still downstream of #18/G-M and its own G-B admission.
- #12: unchanged sole owner of hybrid/soliding. #92 re-entry stays gated on it.
- #90: all child dispositions are now consumed. #90 may close once this record
  is merged and verified on `main`.
- LCB: [Gate A record](2026-10-23-lcb000-gate-a-water-pressure-admission.md);
  [#213](https://github.com/techrote/cybersand/issues/213) still needs Gates B–E.

## Draft review (issue #95 step 4)

The draft was checked for each named failure mode before publication:

| Risk | Result |
|---|---|
| Surge confused with head equalization | Q1 uses the outlet family and an explicitly unregistered surge fixture. Row 2b is not cited as surge evidence. |
| Sealed rooms expected to equalize like vented rooms | Q4 restricts equal-level targets to a shared atmosphere. Sealed cases are excluded from #45. |
| Prototypes treated as production | The archived prototype is excluded from every disposition. #93/#94 remain research. LCB is opt-in only. |
| Invented owner acceptance | Owner rows cite dated sources. No H acceptance is claimed. Algorithm preference is recorded as undecided. |
| Duplicated #45/#49/#12 ownership | #49 fixtures are not mutated; the surge fixture is a versioned extension. #12 stays the hybrid owner. #45 and LCB backend ownership is de-duplicated (Q3 item 5). |
| Silent Water/other-liquid unification | Q8. |

## Limitations

- No new simulation was run for this record. Runtime facts come from the cited CI
  runs, read from their retained artifacts.
- Surge, dam-break front speed and sealed-headspace behaviour are unmeasured on
  any registered fixture.
- Linux-only runtime evidence; timing is CI-host characterization, not a
  performance claim.
- Historical records (#26, #49, #91, #92, #93, #94) are unchanged. This record
  adds an interpretation and does not rewrite them.
