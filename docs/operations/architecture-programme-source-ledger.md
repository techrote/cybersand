---
title: Architecture programme source synthesis
status: Planned
document-kind: evidence
scope: Dated claim-by-claim synthesis of four architecture conversations against local source; not a new runtime acceptance record
canonical-for: []
last-reviewed: 2026-09-10
related-documents: [architecture-programme.md, ../decisions/ADR-005-water-model.md, ../decisions/ADR-007-rigid-body-cellular-coupling.md]
---

# Source synthesis and epistemic ledger

## Issue 12 execution qualification, 2026-09-13

The local combined baseline is `f32faa93cbaaef08f7eb8cf9d5e445e9113db73c`.
[ADR-012](../decisions/ADR-012-bounded-soliding-ownership.md) now freezes a one-slot
isolated manual-step near-rest owner; older OPEN topology rows below describe
the programme intake and remain unresolved for general production integration.
The [dated execution record](../audits/2026-09-13-issue-12-soliding.md) supplies
candidate, transition, reversal, review and platform evidence. This is no
production Cell migration, H decision or #18/#20 admission.


## Integrated source qualification, 2026-09-13

**Current source:** merged #19 uses the eight-byte `detail::PrecisionStorage`
carrier (`World::Chunk::Cell`), with default mass8/coherence12 semantics. Older
four-byte baseline statements describe the programme reference or dated intake,
not the physical storage in this checkout. This inherited experimental carrier
is not a G-final production-layout choice and is not a new #12 packing migration.

**Current #11:** source `d5f0de687283ec366ed4ff33160a274e2a35ddc6` repairs
masked-source authority, barrier/body-aware ejection and ordinary rectangle bearing.
The #11 support prerequisite is satisfied within the documented ordinary
rectangle/load envelope. Earlier intake defect/issue-state claims below are
historical and are superseded by the [repair evidence](../audits/2026-09-13-issue-11-repair.md).

This is the working source synthesis for the [master programme](architecture-programme.md).
Repository source establishes Current behavior; retained dated runs establish only
their measured scope; ADRs establish decisions. Conversations establish what was
proposed and how the reasoning evolved. The dependency atlas was orientation only.

## Complete conversation coverage

| Key | Conversation and retrieval identity | Coverage and reasoning trajectory |
|---|---|---|
| R | [Sand Archit rejectdeleterestore](https://chatgpt.com/c/6aa2de46-33a0-83eb-9f92-5293634e3266) | All three user/assistant turns, oldest to newest. Initial Water/occupancy/inertia question; refined cost/benefit of derived occupancy; owner explicitly agrees to stand by the decision; final response freezes that boundary during material research and prioritizes equivalent-semantics layout measurement and yield/sleep characterization. |
| W | [Sand Archit Water](https://chatgpt.com/c/6aa2dbe3-6358-83ed-a492-c884ebfe0ad4) | All four turns. Shared initial question; owner questions early constraints and asks to extract #9/#13 evidence; fractional bottom-fill proposal; directionality correction replaces that with local interface reconstruction; final 40-bit discussion explicitly changes the earlier preference toward testing persistent flow memory first and precision independently. |
| B | [Sand Archit Bytes](https://chatgpt.com/c/6aa2d4a6-3f3c-83ed-b911-02de9fd1cd2b) | All seven turns. Shared initial question; 8/16/32-byte cost and sidecars; state/epoch explanation; 10/14/8 packed proposal; 16/40/8 and sidecar comparison; initial caution on 6-bit epoch; final endorsement of testing 8/18/6 and correction that wrap frequency differs while each clear can still hitch. |
| I | [Analyse CyberSand Implementation Paths](https://chatgpt.com/c/6aa27702-7690-83eb-96a8-78ae804d335e) | Entire single user/assistant turn: executive assessment and sections 1–12 from the task reader; section 13 heading overlaps the owner's supplied continuation through section 30 and Recommended direction. Reader truncated the assistant at 20,000 characters; owner supplied the missing remainder in this task. |

The common opening response in R/W/B is shared ancestry, not three independent
measurements. W's two images are absent from the reader; its textual question and
complete answer establish the directionality refinement. No pixel-level claim
about those images is needed. I's five underlying attachments, external analyses,
footage and cited web pages were **not** retrieved or independently evaluated.
Its examples below are CyberSand proposals described in that conversation, not
claims that the external material proves an implementation.

Read-only exports of the three complete text conversations and the truncated I
reader response are retained under
`C:/kybersand/validation/local/2026-09-10-architecture-programme/`.
The owner's continuation is preserved in this task; the section-level synthesis
below makes later implementation independent of that conversation.

## Ledger

| Topic | Status / authority | Evidence and change in reasoning | Consequence |
|---|---|---|---|
| Native cells and independent Rapier | ACCEPTED / ADR; CURRENT | ADR-001/003/007/009; source ownership contracts. R and I retain the foundation. | Value-only boundaries and singular material ownership remain invariants. |
| Erase/simulate/restore as sole collision representation | REJECTED / ADR | ADR-007 describes false Empty space and ambiguous overwrites. R turn 2 clarifies synchronization/bandwidth/raster error costs and caching benefits; owner acceptance in turn 3 affirms the decision. | No reopened collision model or occupancy bits inside persistent Cell. |
| Explicit ejection / transfer | CURRENT, with limitations; future transfer is OPEN | ADR-007 permits bounded displacement; failed placement retains cells and records overlap. R distinguishes that from erase/restore authority. | Explicit extraction/insertion is allowed only with defined owner, capacity and failure semantics. |
| General shape benefits from body-ID projection | EXPERIMENT / proposal, not Current shapes | R describes flexible potential; I §§9–14 acknowledges rectangle prototype and 16-body cap. | Do not claim arbitrary masks or membership already exist. |
| Masked-source feedback and barrier bypass | CURRENT / VALIDATED defect evidence | #9 audit and fixtures; source still uses existing coupling path. #10/#13 and latest audit explicitly exclude #11 repairs. | Keep known failures visible; an experimental candidate must not claim a support fix by hiding them. |
| #11 completion | OPEN evidence conflict | GitHub closed as completed 2026-09-10 09:40:42 UTC, with zero comments and unchecked acceptance; local source/docs still describe pending barrel work. Remote main is older. | Administrative closure does not pass a support-integration gate. Resolve from a source-matched fix/evidence or explicit scope decision. |
| Four-byte Cell | CURRENT / source | `World::Chunk::Cell` in native/src/world.cpp: byte material, two state bytes, byte epoch, sizeof assertion. | Control layout; neither permanent prohibition on widening nor evidence for a winner. |
| Temperature sidecar | CURRENT / source | Optional chunk-owned int16 storage, materials/geometry contracts. R final conceptual grouping calls it a transient field, but it is World-owned state and hashes include temperature. | Distinguish persistent optional fields from derived occupancy and disposable render flux. |
| 8/16/32-byte universal layouts | EXPERIMENT / B | Initial rough models predict cost, not measured percentages. B recommends serious 8-byte versus sidecar comparison; 16/32 for sparse state are discouraged, not benchmarked rejections. | Required first screen is 4/8 bytes; defer 16/32-byte universal stress variants absent a demand. |
| Packed 10/14/8 | Earlier provisional preference / B | More IDs without wider cells, but cannot encode all existing 16-bit material state unchanged without proof/rescaling. Later owner proposes 8/18/6. | Retain as an alternative, not replace the later explicit candidate or silently truncate existing state. |
| Packed 8/18/6 and 16/40/8 | EXPERIMENT / final B and W | Arbitrary per-material masks/shifts; typed accessors rather than compiler bitfields or anonymous registers. No result selects either. | Isolate access packing, width, epoch and state use with intermediate controls. |
| Epoch frequency | SUPERSEDED precision of conversational approximation / source | B says 64/256 ticks. `World::begin_tick` clears on zero then sets epoch to 1; first 8-bit clear at tick 256, subsequent clears every 255. Same design at 6 bits first clears at 64, then every 63. | Record exact clear ticks, max/p99 and clear duration; do not only compare mean or p95. Sleeping resident cells participate. |
| 16-bit material IDs | OPEN | B/W propose headroom; current catalogue ends at 80, and adapter/profile/render paths assume narrow IDs. | Measure access cost, inventory actual need and migration surface; 40-bit state does not justify larger IDs by itself. |
| Water FreeMass | CURRENT / VALIDATED and ACCEPTED / ADR-005 | State_a 1–255 mass; Empty zero; state_b coherent-delay countdown, not generic velocity/settled flag. Merge uses max delay; supported film threshold 48; delay 12. | Exact integer pure-Water oracle, gravity, film and stable rest remain control behavior. |
| Half-imbalance Water relaxation | SUPERSEDED as Current policy | Shared R/W/B response predates local commit 8f4ffb9, whose dated audit replaces half with floor(3*delta/4). | Use three-quarter relaxation as current control; old traces are historical. Profile v1 hash alone cannot identify solver. |
| CellularYield | CURRENT, not a real yield-stress constitutive model | Whole-cell down/diagonal motion, mobility roll 256-viscosity and bounded lateral attempts; Oil has specialized movement. W calls for comparison, R warns stopping may involve sleep. | Attribute per-material exceptions. Retained heap behavior does not prove explicit stress/yield state. |
| Sleep-caused apparent yielding | EXPERIMENT, not established conclusion | R final proposes default versus disabled/extended sleep; current config rejects zero quiet ticks. | Use legal horizon-exceeding quiet threshold or a separately explicit diagnostic; never claim sleep-disabled from zero. |
| Water conservation flexibility | OPEN proposed revision; ACCEPTED baseline unchanged | W owner permits measured small error for demonstrated benefit. W initially proposes looser doctrine; final response says richer state reduces urgency to relax mass conservation. ADR-005/008 still preserve exact closed operations. | Experiments may measure declared drift only if needed; no silent ADR downgrade, unaccounted loss or immediate production relaxation. |
| Persistent flow memory | EXPERIMENT, refined preference | W originally favors reconstructed topology plus transient flux; final W explicitly tests short-lived persistent direction/strength first. R independently suggests radius-1 decaying bias. | Transient render flux preference is not permanent rejection of persistent material-local history. |
| Universal vx/vy | OPEN, no selection | Native cells lack it; specialized Rocket heading and Rapier velocity are distinct. #13 says no general field *in that issue*. | ISSUE-SCOPED non-goal must not become a universal ADR. Compact history, body/event velocity and sparse promoted state compete. |
| Mass precision 4/6/8/10 | EXPERIMENT / final W | Lower precision might reduce churn; higher precision may improve behavior. Neither demonstrated. W proposes physical normalization then separate one-unit threshold experiment. | Hold physical geometry/quantity/thresholds as equivalent as representable; report quantization and initialization error independently. |
| Bottom-filled fractional rendering everywhere | SUPERSEDED / W turn 3 | Amount does not encode subcell position; underfaces/vertical/diagonal edges require context. | Local fill gradient first, isolated droplets/gravity fallback; centroid heuristic explicitly REJECTED in discussion. |
| PLIC-like rendering / optional flux | EXPERIMENT / W | Reconstruct interface on presentation side; optional flow disambiguates weak gradients. Final W prefers reuse of measured useful history if it exists. | Rendering can be tested on 4-byte current state; render success does not approve a solver or wider Cell. |
| Quantity versus transport and material traits | EXPERIMENT / R final, W | Variable mass and equalization are distinct; mobility, yield, permeability and adhesion serve different purposes. #10 already implements independent Mercury permeability. | Reuse the selected policy; no duplicate permeability rework. Generalizing partial liquids requires explicit unlike-liquid and reaction quantity contract. |
| Promotion hierarchy and I D0–D5 | Provisional recommendation / I §§26–30 | I ends by recommending four-byte CA, ballistic pool first, native coherent membership next, bounded detachment. No owner adoption or measured proof is present. Later W/B explicitly investigate width and compact history. | Preserve candidate reasoning, replace mandatory sequence with evidence gates; representation is distinct from activity. |
| Damage descriptors / generic DamageEvent | EXPERIMENT / I §§4–7,27 | Existing granular Stone/explosion seam makes proposal plausible; immutable material response avoids per-cell descriptor copies. | Useful only when a selected experiment needs a second cause/material response; do not front-load general infrastructure. |
| Sparse ballistic pool | EXPERIMENT / I §§8,18,27 | High-speed ejecta avoids enlarging CA write domain and may offer future displacement fallback. W/B supply inline/history/sidecar alternatives. | Conditional bounded proof only after a concrete motion deficit and ownership charter; no automatic unresolved-overlap deletion/conversion. |
| Native coherent membership + Rapier proxy | EXPERIMENT / I §§9–14; existing issue-scoped plan #12 | Exact local membership and transformed occupancy differ from simplified convex collision geometry. Candidate stable slot+generation handles and spatial buckets address reuse/stale sample/scaling. | Reuse #12, begin small; >16 registry, arbitrary hull pipeline and all-mask caching are not blanket prerequisites. |
| Topology handover | OPEN contract, prerequisite if promotion proceeds | I §§20–22: stale terrain collider risks self-contact, early removal risks holes; acknowledgement must separate rare topology changes from ordinary aged transform samples. #12 already prescribes prepare/ack/commit. | Preflight before deletion; source owns until commit, pending occupancy carries no duplicate material authority; failure stays explicit under ADR-010. |
| Momentum inheritance | EXPERIMENT / I §17 and #12 | Parent v + omega cross r for child COM; event data for ejecta; #12 allows near-rest restricted reversal. | Requires units/rounding/error ledger; does not require universal cell velocity or mandatory ballistic dependency for near-rest #12 proof. |
| Fracture, torque, anchors | DEFERRED / this programme, following I staging | I makes fracture second S2 milestone and torque after basic motion/masks; selective local anchors later. | Do not create separate implementation issues until a coherent-body result justifies them. |
| Universal structural solver / literal external ownership cycle | REJECTED recommendation in I; erase/restore also ADR-rejected | I §§15,25–27 explicitly reject global unsupported=>dynamic and copied erase/raster authority. | Preserve authored impossible structures and bounded event regions. No universal collapse programme. |
| Sleeping-body rebake / streaming | DEFERRED / I §24; streaming orthogonal | Sleeping Rapier body can retain identity; rebake needs a measured debris-count problem. | No sleeping=>welded terrain assumption; no streaming work here. |

## Repository intake and evidence reuse

Intake source root `C:/kybersand/source`, HEAD
`8f4ffb96e03dc50cb43ab9c84de17ccb44c03774`, branch
`codex/water-sideways-leveling`. Sole dirty tracked path:
`godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll`, SHA-256
`fc6cb4ee1096219f581bace3df04ee8138e996aaf4c1436f5b2c071ea62dd496`.
It remains untouched and uncommitted. Companion workspace `codex/workspace-docs`
was clean. Planning branch: `codex/architecture-programme`.
Origin is the private `https://github.com/techrote/cybersand.git`.
Remote main at intake is `ab4851e9e6a3ee182aba1a31a8f66d135e87df3a`;
local physics checkpoints are not implicitly published. No tag points at intake HEAD.

Relevant chain: #9 `10e8153`; #10 support `1fba848` and exchange `372bfb3`;
#13 `f88423f`, `af80634`, `1290e0a`, `4bead55`; Water follow-up `8f4ffb9`.
Pins retained: Godot 4.7 `5b4e0cb0f`, Rapier 0.35.2, godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`, Emscripten 4.0.20,
Windows Clang 23.1.0. LFS status and DLL identity were inspected; no new
all-platform payload recovery or runtime certification is claimed.

| Evidence | Reuse and limit |
|---|---|
| [#9 audit](../audits/2026-09-09-physics-characterisation.md) and [runbook](physics-characterisation.md) | Ordered pair, player and barrel causal measurements, confinement/chemistry distinctions, diagnostic saturation, global Water versus crop accounting. Its 2,496 runs are historical, not rerun here. |
| [#10 audit](../audits/2026-09-09-issue-10-granular-policy.md) / ADR-011 | Powder-pair exclusion, sampled support and period-30 Mercury. 32-grain confined breakthrough 960 ticks; 33-grain #13 fixture uses 990. Different geometry, no contradiction. |
| [#13 audit](../audits/2026-09-09-issue-13-transport.md) | Tower, immutable profiles, successful-motion-driven optional transport, independently screened knobs, 480-run corrected sampling evidence and 60 frozen controls. Shared-host timing is not isolated hardware acceptance. |
| [Water follow-up](../audits/2026-09-10-water-leveling.md) | 24 cases per old/new implementation, exact 97,920-unit basins; current 55 native / 24 Godot fixtures; 30 unchanged Mercury/powder controls and 72 native/Web transport cases, as dated evidence. Water traces and erosion pickups intentionally differ from #13. |
| [Publication limitations](../audits/2026-09-10-water-leveling.md) | Retained repository check has 16 provenance/LFS mismatches. Do not rewrite hashes or report fresh Linux acceptance. |

GitHub intake: #8 and #12 open; #9/#10/#11/#13 closed, all four closed on
September 10 at 09:40:41–42 UTC. Related issues carry no labels/milestones;
use the same convention. #1/#2/#3 are closed; their source contracts and
publication limitations still need claim-level evidence. #12's existing staged
scope is reused rather than duplicated. No broad audit or physics test was run
for this planning intake; targeted source reads resolved Water, epoch, liquid
mobility, ownership and scheduling facts needed by the new experiments.

## G-L reconciliation, 2026-09-11

The [staged G-L record](architecture-programme.md#g-l-staged-decision-2026-09-11)
admits completed #16 evidence at `4726f8d0fae72f959926a47ab37f7244e9399638`.
The existing 4-byte layout is the baseline pending G-final, not a permanent
selection. This later programme control decision does not rewrite the experiment's
original no-production-selection conclusion. Experimental code stays on its branch.
The [reconciliation audit](../audits/2026-09-11-programme-gate-reconciliation.md)
records exact timing commits, reduction hashes and preserved DLL identity.

## G-C reconciliation, 2026-09-11

Result `cdb4c2a6df0248c76e7957fd09cae77655ec974f` completes C after preparation
903e40f; all576 raw outputs and both source/artifact manifests were reverified.
The [coverage audit](../audits/2026-09-11-issue-15-coverage.md) classifies retained,
focused, missing and ambiguous evidence. No new measurement or production change.
[G-C](architecture-programme.md#g-c-staged-decision-2026-09-11) admits bounded P
now that G-L is complete; V's frozen-state research remains independent. C does
not admit M implementation without a target, generalized quantity/yield or any
production migration. #18 still waits on P/G-P, #20 on M/G-M plus admission;
#14/G-final stays open. Original C/L result records retain their dated scope.

## G-P reconciliation, 2026-09-11

[Completed Issue17](../audits/2026-09-11-issue-17-state-precision.md) executes the
later tightened owner request on f3fb9de plus isolated experimental source. The
[staged G-P](architecture-programme.md#g-p-staged-decision-2026-09-11) retains mass8,
records Water-only delay4 equivalence, rejects interpreting coarse early stalls as
an uncomplicated speedup, and preserves independent M/V/B/G-final admissions.
The current4-byte production baseline remains pending G-final; no production
migration or downstream feature implementation occurred.
