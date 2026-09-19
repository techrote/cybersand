---
title: Status and foundational roadmap
status: Current
document-kind: reference
scope: Current implementation map, unresolved correctness and policy decisions, and bounded next checkpoints
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-09-19
related-documents: [validation-evidence.md, invariants.md, ../operations/documentation-maintenance.md, ../operations/architecture-programme-water-feel-addendum.md, ../operations/microscenarios-programme.md]
---

# Status and foundational roadmap

## Is the foundation ready to extend?

**Current documentation is organized for foundational work; the simulation has
known correctness and policy gaps.** The [source checkpoint](../operations/source-checkpoint-and-recovery.md)
secures existing work locally. Resolve the relevant issues below before building
new physics on assumptions that the current implementation does not guarantee.
The [validation ledger](validation-evidence.md) separates dated runtime results
from inspected code. No documentation status is a blanket platform acceptance.

## Current implementation map

| Area | Implemented scope and canonical contract |
|---|---|
| Cellular authority and platform owners | Native World; asynchronous desktop GDScript owner, synchronous Web callbacks with optional internal pool; [threading](../architecture/simulation-tick-and-threading.md) |
| Scheduler and storage | Sparse chunks, phased in-place jobs, explicit capacities and activity sleep; [chunk/tile model](../architecture/chunk-tile-and-buffer-model.md), [storage](../systems/world-storage-and-interest-region.md) |
| Materials | Bounded adapted kernels, mass-conserving native Water, discrete fallback, secondary interaction lanes; [materials](../systems/materials-and-rule-kernels.md), [Water](../systems/water-design.md) |
| Field storage and events | Optional temperature storage and bounded explosions; no general heat/pressure/wind solver; [field roadmap](../systems/smoke-heat-pressure-roadmap.md) |
| Bodies and character | Main-thread Rapier, rectangular masks/displacement, static terrain packets and sampled character; [coupling](../architecture/rigid-body-and-cellular-coupling.md) |
| Rendering | Immutable native snapshots, copied dirty RG8 patches, full finite GPU texture update and derived material appearance; [bridges](../architecture/rendering-and-gameplay-bridges.md) |
| Persistence | Fixed CYSD1 demo levels; complete resumed replay absent; [save contract](level-saves-and-replay.md) |
| Runtime availability | All 18 required LFS payloads materialized; current execution scope is platform-specific; [build](../operations/local-build-and-validation.md) and [evidence](validation-evidence.md) |

## Decisions and defects to resolve

Rows distinguish **Current fixes**, remaining defects and open decisions; dated
evidence defines each fix's platform acceptance.

| ID | Precise uncertainty or contradiction | Next bounded check/decision |
|---|---|---|
| F01 — failed ticks | Current fix: latch failed World, distinguish attempted/completed ticks, suppress partial publication, stop desktop/Web owners; explicit reset/validated replacement, no replay/rollback | Windows/native acceptance and browser limits: [issue #1 evidence](../audits/2026-09-08-issue-1-failed-ticks.md); [tick contract](../architecture/simulation-tick-and-threading.md) |
| F02 — region re-entry | Current fix: phased exclusion retains activity/quiet state; new core coverage wakes resident blocks once without catch-up. Serial still ignores the region | Separate and combined acceptance: [issue #2 evidence](../audits/2026-09-08-issue-2-interest-regions.md); [storage](../systems/world-storage-and-interest-region.md). Future field/streaming semantics remain open |
| F03 — tick ownership | Desktop moves character before cells with async Rapier samples; Web moves character after cells and gates on terrain backlog | Decide which ordering differences are acceptable before a common physics/replay contract; [threading](../architecture/simulation-tick-and-threading.md) |
| F04 — delayed rules and sleep | Secondary interaction lanes differ by material, including specialized Ice cadence; waiting branches do not all keep cells active | Test eventual intended reactions across sleep/region transitions; preserve material-specific semantics; [materials](../systems/materials-and-rule-kernels.md) |
| F05 — replay and fidelity | Current hashes omit some future-affecting state; CYSD1 omits more; no selectable strict runtime policy | Specify complete input/configuration identity, fidelity policy and replay schema before promising continuation; [determinism](../architecture/determinism-and-boundary-transfers.md) |
| F06 — bounded operations | Native lazy allocation and partial failure coexist with Approved prepared/no-allocation goals; desktop input Array is unbounded | Define command backpressure, setup/reconfiguration and allocation accounting; [capacity](../operations/configuration-and-capacity-budgets.md) |
| F07 — body physics scope | Rectangle proof does not settle general shapes, sweep/CCD, force/torque units, sample-age policy or particle overflow | Name units and fixture tolerances, extend one bounded coupling case at a time; [coupling](../architecture/rigid-body-and-cellular-coupling.md) |
| F08 — build/release identity | CI 4.0.11 versus builder 4.0.20; missing native binding argument; compile-only skips runtime; historical template lock and base-only export identity | Current/M11 gate separation is implemented; remaining Web work stays in issue #3. [CI contradictions](../operations/github-development-and-release.md#unresolved-ci-contradictions) |

## Approved, Planned, Deferred and Rejected work

**Approved:** native authority, exclusive ownership, immutable handoff, explicit
capacity outcomes, exact fixture comparison, bounded visible approximation, and
replaceable Rapier behind engine interfaces. Some requirements remain only partially
enforced; [invariants](invariants.md) identifies that gap.

**Planned:** generalized bounded command/result queues; safe live reconfiguration;
general world/configuration/replay persistence; field equations and units; production
body-shape/CCD/force policy; GPU subregion writes; authored appearance schema/tooling;
remaining platform/LeakSanitizer and production performance acceptance. Current
Linux native ASan/UBSan/TSan results are in the validation ledger.

**Deferred:** asynchronous Web simulation/render ownership, streamed generation,
and GPU/coarse/hex experiments. Active-only buffering is a **Planned candidate**
whose implementation/comparison is **Deferred** until a field or benchmark
justifies it. The reserved buffered enum does not run.

**Rejected within the current architecture:** erase/restore bodies into authoritative
cells, mutable rendering reads, native workers calling Godot, per-cell locks/physics
objects, per-material threads and automatic use of GPU visuals as simulation authority.
See [principles](../architecture/principles-and-non-goals.md) and the [ADRs](../decisions).

## Next implementation checkpoints

**Current:** the [issue #9 measured baseline](../audits/2026-09-09-physics-characterisation.md)
and [reproducible tooling](../operations/physics-characterisation.md) establish
density-exchange, player-sampling and barrel-feedback evidence. Issue #10 now
implements the [versioned player and exchange policy](../systems/granular-interaction-policy.md).
Issue #11 retains **Planned** barrel work: masked-source feedback, barrier-aware
ejection and persistent bearing. Raising barrel impulse caps alone does not
provide the intended behavior. The
[soliding plan](../operations/physics-characterisation-plan.md) still requires an
explicit ownership decision before dynamic membership handoff. Current F01/F02
contracts and the separate runtime publication gate remain applicable.

1. Preserve the implemented F01 quarantine and F02 pause/re-entry contracts and
   their combined regressions; extend the documented platform/failure-site gaps
   before broader production acceptance. Do not fold in a new solver or backend.
2. Freeze ordering, units, approximation and replay-input contracts needed by the
   first physics increment; record unresolved choices rather than guessing.
3. Extend one bounded physical behavior, validate conservation/ownership/capacity
   and affected platforms, then apply the [documentation checklist](../operations/documentation-maintenance.md).

CI/provenance repair can be a separate bounded prerequisite for release-quality
builds. The earlier M11 checkpoint sequence and reported rollback archives remain
[historical records](../audits/pre-rag-rewrite-2026-09-08/README.md), not newly verified recovery points.

## Issue #10 player and exchange checkpoint

**Current:** Material-aware player support, separate side resistance, bounded
enclosure recovery, powder-pair exclusion and scheduled Mercury permeability are
implemented. The [dated evidence](../audits/2026-09-09-issue-10-granular-policy.md)
records parameter screening, native/fallback/desktop/Web execution and remaining
publication/platform limits. Barrel feedback/bearing/ejection stays in issue #11.

## Issue #13 experiment checkpoint

**Current:** shared five-floor Experiment Tower, frozen pre-change references,
validated editable profiles, optional motion-driven transport and measured
horizontal sampling. Desktop and both native Web profiles execute the lab.
[Issue #13 evidence](../audits/2026-09-09-issue-13-transport.md) distinguishes
regression results, measured transport changes, visual observations and remaining
owner feel/performance limits. Baseline remains the gameplay default. Chemistry
retuning, barrel #11 and soliding #12 remain separate.

The Tower is also the Current base for #19's Water Feel Lab extension. #13's
existing evidence and recipes remain unchanged historical/current controls.

## Issue #19 Water Feel Lab checkpoint

**Current, 2026-09-12:** V1 four-level/oriented presentation and V2 H-preparation
are complete. One normalized runtime policy covers semantic mass3..8,
coherence0..12, presentation/interface mode, deterministic scenario/seed and
provenance. The existing Tower now exposes 35 deterministic Water scenarios,
transactional Apply + Reset and reconstructible blind/export controls. Native,
full Windows Godot, actual GPU and real Chrome compatibility/threaded gates pass.
See the [completion evidence](../audits/2026-09-12-issue-19-water-feel-lab.md).

This checkpoint is **H-ready**, not an H result: mass8/coherence12 remain the
production/reference control, no preferred candidate or production packing was
selected, #18 remains held, #20 remains downstream and G-final remains open.

## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
The [September 10 Water follow-up](../audits/2026-09-10-water-leveling.md) increases
default lateral relaxation after owner feedback. Historical #13 Water traces are
preserved; the new source identity owns its changed front/erosion behavior.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.

## Architecture investigation after the Water checkpoint

**Planned:** the [architecture programme](../operations/architecture-programme.md)
and its dated [Water-feel addendum](../operations/architecture-programme-water-feel-addendum.md)
isolate raw Cell layout/epoch cost, liquid characterization, quantitative precision,
presentation, human-test preparation and conditional compact motion before any
policy migration. Sparse ballistic implementation still requires admission evidence;
coherent soliding reuses #12. No 4/8-byte winner, liquid unification or representation
ladder is adopted. GitHub #11 is closed while this source still records its missing
barrel work; support-dependent integration requires actual source/evidence reconciliation.

## Architecture gate reconciliation, 2026-09-11

**Current programme state:** G-L, G-C and G-P are complete. #16 research is complete;
the current 4-byte Cell remains the baseline pending G-final, not a permanent width
selection. #17 retains mass8 as the numerical/reference Water control and proves
existing Water coherence 0..12 fits exactly in four semantic bits. No production
Water precision or Cell layout migration is authorized.

Following G-P, owner intent clarified the role of precision work: lower Water
precision primarily exists to investigate flexible material-state budgets, while
performance is secondary. Quantitative differences therefore describe what changes
but do not by themselves determine gameplay desirability. The dated
[post-G-P Water-feel refinement](../operations/architecture-programme-water-feel-addendum.md)
records the governing rule that **quantitative equivalence and perceptual adequacy
are separate gates**.

#19 completed its expansion from presentation-only V into **V plus H-preparation**. Its
[first-stage contract](../operations/architecture-programme-prompts/fractional-presentation.md)
established the intended four-visible-level fractional presentation and left
a verified Water Feel Lab with deterministic scenarios, runtime semantic policies,
A/B/blind support and #17 correspondence. Available later human-test semantic axes include
mass3..8 and coherent duration0..12 without recompilation; this is semantic emulation
in a superset experimental representation, not production repacking.

#19 completion is **H-ready**, not evidence that a preferred Water model has been selected.
The later human-led H gate will use the real apparatus to classify candidates and,
where applicable, name a perceptual motion deficit. #18/M remains held until such
a concrete directional-persistence target is justified, or may complete by reasoned
no-go. #20/B remains dependent on #18/G-M and its own admission. #14/G-final remains open.

See the earlier [identity and scope audit](../audits/2026-09-11-programme-gate-reconciliation.md)
for the pre-refinement reconciliation; the Water-feel addendum is the later dated
planning authority for the affected #19/#18 ordering.

## Issue17 precision completion

[G-P is complete](../operations/architecture-programme.md#g-p-staged-decision-2026-09-11)
with [exact fixed-carrier evidence](../audits/2026-09-11-issue-17-state-precision.md).
Mass8 remains the numerical reference; Water delay4 is an exact storage budget for
current 0..12 coherence semantics. That result is **not retracted** by the later
Water-feel refinement. Instead, #19/H-preparation uses it as the quantitative oracle
against which runtime mass4/6/8 controls are checked before novel mass3/5/7 and
shortened-coherence candidates are offered for human testing. No production migration.


## MicroScenarios and intermaterial-interaction programme

**Planned/active apparatus, revised 2026-09-18:** the
[canonical programme graph](../operations/microscenarios-programme.md) is the
ordering authority for #24/#27-#30. GitHub issue numbers are identifiers, not a
serial path.

#27/MS-000 no longer waits for #18 or G-final. Once the #24 launcher/input fix is
present (including as an isolated prerequisite on the working branch), #27 may
extract the deterministic common scenario host from #13/#19. It remains
apparatus-only and cannot alter #18 compact-motion admission, #20 G-B admission,
#26 Water evidence or #14 architecture semantics.

#28/MS-001 may then build **exploratory/provisional** Materials Laboratory,
Flood-Control Puzzle and Simulation Stress Test scenarios before G-final. Their
purpose includes organically discovering unknown edge cases. The Materials
Laboratory has an explicit readiness checkpoint that can unblock #29 while the
other two scenarios continue; all affected provisional scenarios are versioned
and revalidated after relevant physics/architecture changes rather than being
silently relabelled as accepted evidence.

#29 is **INT-000: intermaterial interactions**, not a chemistry-only campaign. It
covers non-kinetic material/material semantics such as reaction, combustion,
thermal/phase consequences, dissolution/corrosion, curing, electrical and other
state conversions/products. Kinetic movement/support/bridging/erosion/collision
remain owned by existing physics systems. INT-000 planning/inventory may begin
early; implementation uses the stable #27 fixture contract plus the #28 Materials
Laboratory readiness checkpoint. Each accepted tuning pass pins the relevant
source/contact/transport baseline and retains prior evidence, so later physics
changes trigger targeted re-screening rather than a destructive global retune.

The discovery workflow is: explore a scenario -> capture an anomaly with exact
identities -> reduce it -> triage ownership -> bounded fix/tuning -> retained
regression -> return to the larger world. #30 tracks this programme; it is not
itself an execution prerequisite. #18/#20/#14 retain their independent gates in
the architecture programme.

## MS-000 common MicroScenarios checkpoint

**Current source, 2026-09-19:** [MS-000](../operations/microscenarios.md) extracts one
validated, bounded scenario host for the existing Tower/Water owners and a
native-only runner. Play/Inspect/Benchmark share definitions, while legacy blind,
reset and physics-order contracts remain distinct where they were distinct before.
Two exploratory generic fixtures exercise Water quantity and non-Water material
observations. Captures identify source/runtime/profile state but are not replay saves.

This is apparatus, not a solver/interaction migration. The [programme graph](../operations/microscenarios-programme.md)
still controls #28/#29 readiness and keeps architecture gates separate. Read the
[checkpoint evidence](../audits/2026-09-19-issue-27-microscenarios.md) before claiming
Windows, GPU or native Web runtime acceptance for this version.

## Issue #12 successor programme, 2026-09-19

**Approved direction / Planned implementation:** #12 now owns scalable reversible
soliding for large-world acceleration and Rapier macro-dynamics/fracture. The
[canonical stage gates](../operations/soliding-programme.md) supersede the earlier
bounded-prototype scope. PR #23 remains Phase 0 evidence at `0b96ce2`; it does not
close #12. The successor starts at `de332ea` in an isolated worktree, preserving
#26/#27 source identities. Lifecycle tests precede discovery; measured Current
sleep precedes performance claims; region discovery precedes acceleration.
Dynamic handoff, torque-driven rotation, coherent-child fracture and persistence
remain later unpassed gates, not implied by a standalone contract model.
