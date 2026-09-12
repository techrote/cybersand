---
title: Status and foundational roadmap
status: Current
document-kind: reference
scope: Current implementation map, unresolved correctness and policy decisions, and bounded next checkpoints
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-09-12
related-documents: [validation-evidence.md, invariants.md, ../operations/documentation-maintenance.md]
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
reusable fixtures, bounded telemetry and historical density-exchange,
player-sampling and barrel-feedback evidence. Results for behavior changed by #10
and the later Water checkpoint are not current policy. The
[2026-09-12 reconciliation](../audits/2026-09-12-issue-9-10-reconciliation.md)
confirms that issue #10's [versioned player and exchange policy](../systems/granular-interaction-policy.md)
is present and exercised at current source; persistent barrel bearing remains
outside that policy.
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

**Planned:** the [architecture programme](../operations/architecture-programme.md) isolates raw Cell layout/epoch cost, liquid characterization, precision, compact memory and fractional rendering before any policy migration. Sparse ballistic implementation requires admission evidence; coherent soliding reuses #12. No 4/8-byte winner, liquid unification or representation ladder is adopted. GitHub #11 is closed while this source still records its missing barrel work; support-dependent integration requires actual source/evidence reconciliation.

## Architecture gate reconciliation, 2026-09-11

**Current programme state:** [G-L is complete / evidence admitted](../operations/architecture-programme.md#g-l-staged-decision-2026-09-11).
#16 research is complete; the current 4-byte Cell remains the baseline pending
G-final, not a permanent width selection. Experimental carriers remain on their
research branch. #15/G-C is also complete after acceptance review; #17 is now unblocked by both
C and L, with no implementation begun. #19/V has its C prerequisite satisfied.
#18/M still waits on #17/G-P and a named target; #20/B waits on M/G-M and its
admission gate. #14 remains open. See the [identity and scope audit](../audits/2026-09-11-programme-gate-reconciliation.md).
