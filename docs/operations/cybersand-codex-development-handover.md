---
title: Development handover
status: Current
document-kind: guide
scope: Short onboarding sequence and checkpoint protocol; product intent, source identity and contracts have canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-09-19
related-documents: [source-checkpoint-and-recovery.md, ../reference/product-intent-and-priorities.md, ../reference/status-and-roadmap.md, microscenarios-programme.md]
---

# Development handover

## Start here for the next task

Work in `C:/kybersand`, with executable source in `source/`. The companion workspace
and source now have separate Git histories. Read [source identity](source-checkpoint-and-recovery.md)
and inspect both relevant working trees before changing anything. Godot is in
`C:/Godot47`; `C:/cybersand` is for functional deliverables. The original rewrite
was local; the owner subsequently authorized a [GitHub checkpoint](../audits/2026-09-08-github-milestone.md)
of both histories. User-confirmed USB backup is recorded; no further backup search is needed.

Read [AGENTS.md](../../AGENTS.md), the [documentation index](../README.md),
[roadmap](../reference/status-and-roadmap.md), then the canonical subsystem and ADR
for the requested change. Use the [retrieval index](../reference/retrieval-index.md)
for a focused question. The [owner-intent reference](../reference/product-intent-and-priorities.md)
preserves product goals, liked material behavior and deliberate deferrals.

## Current execution-order rule

**Do not execute GitHub issues numerically.** For #24/#27-#30 and their links to
#18/#20/#26/#14, read the
[MicroScenarios and intermaterial-interactions programme](microscenarios-programme.md)
before choosing the next task. #27 may proceed once its launcher/input hygiene is
present; it no longer waits for #18 or G-final. #28 exploratory scenarios may
begin on a stable-enough #27 host and are explicitly provisional until affected
physics/architecture changes are revalidated. #29/INT-000 may inventory/design
early; implementation waits for the stable fixture contract plus the #28
Materials Laboratory readiness checkpoint, not for all of #28 or a global
physics freeze.

The [architecture programme](architecture-programme.md) remains authoritative for
#14/#18/#20 scientific gates. MicroScenarios may supply apparatus/fixtures but
cannot satisfy or weaken those gates merely by existing. If issue text and these
canonical documents disagree, fix the planning contradiction before implementation.

## Foundational work boundary

**Current:** native C++ owns cells. Desktop uses an asynchronous GDScript owner
Thread; Web completes ticks synchronously on the Godot main thread with optional
internal native pthreads. Rapier objects stay on the main thread. Follow
[ownership](../architecture/data-ownership-and-lifetimes.md) and
[coupling](../architecture/rigid-body-and-cellular-coupling.md) before changing either.

The first foundational checkpoint should resolve the bounded correctness/ownership
issues in the roadmap before broad physics additions. In particular, tick failure
is not a transaction: issue #1 now quarantines failures until explicit reset or
validated replacement, with no retry/rollback. Issue #2 retains excluded phased
activity and wakes newly included resident blocks once, without catch-up; serial
keeps its distinct behavior. The [combined evidence](../audits/2026-09-08-issue-2-interest-regions.md)
separates regressions and runtime artifacts from remaining platform gaps.

Use [build/test instructions](local-build-and-validation.md) for commands and
[validation evidence](../reference/validation-evidence.md) for actual dated passes.
Historical Linux and retained Windows/browser results do not certify every current
artifact. Level saves do not provide exact replay continuation.

## Finish a checkpoint

Keep implementation changes focused, run relevant tests, and apply the
[documentation-update checklist](documentation-maintenance.md#documentation-update-checklist).
Update canonical facts and retrieval routes together; record failed/unavailable
checks and the tested source/runtime identities. Commit locally when authorized.
Preserve existing historical audit records. The former long handover and checkpoint
tables are retained in the [historical record](../audits/pre-rag-rewrite-2026-09-08/README.md),
excluded from ordinary current retrieval.

## Publication and legacy validation follow-up

The owner authorized finalising issues #1/#2 in PR #6. Preserve their separate
commits and contracts. [Current validation and M11 retention](current-and-historical-validation.md)
now have independent gates; original historical hashes stay unchanged.
[Publication evidence](../audits/2026-09-08-validation-reconciliation.md) records
Linux native/sanitizer results and the rebuilt-runtime CI transition. Remaining
Web CI/export identity work remains issue #3.

## Physics measurement handoff, 2026-09-09

Start with the [measured issue #9 report](../audits/2026-09-09-physics-characterisation.md)
and [reproduction runbook](physics-characterisation.md). That dated baseline used
`ab4851e9e6a3ee182aba1a31a8f66d135e87df3a` plus a recorded diagnostic delta,
subsequently committed as `10e8153` on `codex/issue-9-physics-characterisation`.
Density exchange, the former Sand-only player predicate and masked-source barrel
feedback have separate baseline evidence. Issue #10 changes the first two under
its versioned policy; barrel work remains #11. The local source checkpoint includes
fixtures, reduced data and plots; generated runtimes/raw logs remain in the
active development workspace. Do not treat the old published DLL as containing
the new diagnostic API or close the issue by reusing historical acceptance.

## Issue #10 handoff

**Current:** Issue #9 baseline is committed at 10e8153. Player and exchange are separate focused changes, with fresh DLL builds and preserved intake artifact. Barrel feedback/bearing/ejection belongs to #11. See the [granular/player policy](../systems/granular-interaction-policy.md).

Continue from `codex/issue-10-player-and-exchange`; support commit `1fba848`
precedes the exchange/evidence commit. Read the
[acceptance audit](../audits/2026-09-09-issue-10-granular-policy.md) before reusing
local artifacts. Runtime publication manifests remain historical and intentionally
do not attest the new uncommitted DLL or local exports.


## Issue #13 experiment checkpoint

Issue #13 develops on `codex/issue-13-experiment-tower` from verified `372bfb3`. Follow the [tower procedure](experiment-tower.md) and [dated audit](../audits/2026-09-09-issue-13-transport.md). Preserve the intentionally dirty DLL and rebuild before source-matched runtime evidence.


## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.

The subsequent [Water leveling follow-up](../audits/2026-09-10-water-leveling.md)
implements faster lateral relaxation on `codex/water-sideways-leveling`. Water
traces and optional erosion strength change; Mercury/powder controls remain exact.
Profile hashes alone do not identify this solver revision. Coal's purple residue
is existing Dust; chemistry and fire cadence remain unchanged.

## Programme gate handoff, 2026-09-11

Read [current G-C/G-L decisions](architecture-programme.md#g-c-staged-decision-2026-09-11)
and [reconciliation identities](../audits/2026-09-11-programme-gate-reconciliation.md).
Both research results are published on separate experiment branches; this active
checkpoint changes documentation only. #17 subsequently completed P1/P2/P3; read the [G-P review](architecture-programme.md#g-p-staged-decision-2026-09-11)
and [precision evidence](../audits/2026-09-11-issue-17-state-precision.md). Retain mass8
and Water-specific delay4 as an experimental budget without inferring production migration.
That dated checkpoint retained its 4-byte baseline pending G-final. For later source
physical-size accounting, use the [source-qualified storage contract](../architecture/chunk-tile-and-buffer-model.md#what-is-stored-per-cell-and-per-chunk).

## MS-000 handover, 2026-09-19

Read the [MicroScenario contract](microscenarios.md) before new scenario authoring.
The shared host and JSON API are extracted from existing Tower/Water owners; do
not build a second per-scenario simulation loop or assume the capture is replay.
The [dated evidence](../audits/2026-09-19-issue-27-microscenarios.md) scopes regression
results and remaining platform/merge gates. #28's Materials Laboratory readiness
and #18/#20/#14 scientific gates still require their own evidence.

## Issue #12 successor handoff, 2026-09-19

Use [soliding programme gates](soliding-programme.md), then the precise
[Phase 0 reuse map](../audits/2026-09-19-issue-12-phase0-reuse.md) before any port.
The dedicated successor is `codex/issue-12-incremental-foundation` from `de332ea`.
Do not reset/rebase the Phase 0 control or #26/#27 experiments. Current-main
ordinary sleep is the performance control; full #12 scope includes acceleration,
macro momentum/torque/rotation and coherent-child fracture. A model or block
summary does not satisfy production ownership or connected-region gates.

Use the [successor evidence and next prerequisites](../audits/2026-09-19-issue-12-foundation.md)
for #12 continuation. The ordinary-sleep control is frozen independently; do not
relabel synthetic journal service epochs as simulated World ticks.

For the remaining Stage 3 work, follow the frozen
[producer/connectivity execution contract](soliding-stage3-freeze.md). The linked
Spark packets intentionally split World witness integration from cross-tile region
construction; independent verification and measurement follow only after parent
integration. Stage 3 remains cells-owned discovery and cannot be used to admit
stationary acceleration or Rapier dynamics.

## Issue #26 / Water bulk-head handoff, 2026-09-19

[Issue #26 evidence](../audits/2026-09-19-issue-26-water-leveling.md) is the current
source-backed answer for deep/extended Water leveling. The retained harness proves
that Current local three-quarter equalization can leave communicating pools/U-tubes
quiescent with large unequal heads. Both admitted small local no-state fixes were
rejected; do not resurrect or combine them without a new registration.

Current production Water remains unchanged. [#45](https://github.com/techrote/cybersand/issues/45)
owns the next bounded head/pressure-transmission architecture question. Keep it
separate from #18 directional history; #18 stays held until #45 supplies an accepted
bulk baseline or a documented no-go. #20 and G-final remain downstream under the
architecture programme. #28/#29 may continue in parallel, with targeted
revalidation only after a later accepted Water semantic change.

## Issue #49 Water apparatus correction handoff, 2026-09-19

Use [the post-merge #26 review](../audits/2026-09-19-issue-26-post-merge-review.md)
before any successor Water experiment. #26 remains closed and its two local
candidate rejections remain valid, but the v1 harness is historical evidence rather
than the acceptance oracle for #45.

[#49](https://github.com/techrote/cybersand/issues/49) must first version/fix the
settling and censoring metrics, add the clean two-limb communicating-head fixture,
separate active/sleep performance accounting and harden evidence output. Preserve
all original #26 archives and generate new baselines for changed metrics/fixtures.

Required order is `#49 -> #45 -> #18`. #28/#29 remain independently runnable.
