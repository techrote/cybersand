---
title: Development handover
status: Current
document-kind: guide
scope: Short onboarding sequence and checkpoint protocol; product intent, source identity and contracts have canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-09-24
related-documents: [source-checkpoint-and-recovery.md, ../reference/product-intent-and-priorities.md, ../reference/status-and-roadmap.md, microscenarios-programme.md, development-claims-remediation-programme.md, water-hybrid-pressure-extension-programme.md, github-development-and-release.md, ../audits/2026-09-24-cybersand-recovery-audit.md]
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

## Recovery and CI checkpoint — 2026-09-24

The 2026-09-20 through 2026-09-22 CI / Stage-3B incident is closed by the
[final recovery audit](../audits/2026-09-24-cybersand-recovery-audit.md). The
pre-REC-008 authoritative baseline is
`0405cdfe35a855e8287215a71d1165e3107fd1d6` (REC-007 / PR #124).
Routine active CI is GitHub-hosted; active Avrea, Sengi, CircleCI, self-hosted
routing and `*_RUNNER` indirection are rejected by the repository policy checker.

#65 / PR #106 is genuinely landed and verified. Its accepted merge is
`cdf0a0874d4732c41273e10d921bcd5feaac3e3c`; source-sensitive retained
Linux/Windows runtimes are matched to the validated #65 source, with Windows
explicitly cross-build-only. Stage-3B resumes at **#66**, then #67, #68 and #70.
Stage 4 remains blocked.

PR #105 / #94 was reconstructed cleanly from recovered main and remains draft,
non-production research pending #94's separate evidence/disposition review. Do
not merge or promote it merely because REC-006 validated the recovered proof.

Remote `main` is still unprotected and has no ruleset at this checkpoint.
The exact owner-side minimal ruleset is recorded in
[repository development and release](github-development-and-release.md#main-branch-protection-exact-owner-action).
That unresolved owner action is not a CI recovery failure and must not be described
as already installed.

## Development-claims remediation routing — 2026-09-20

Before relying on a closed/completed issue as current acceptance, read the
[development-claims remediation programme](development-claims-remediation-programme.md).
#8 remains open; #10/#11 retain bounded evidence but are reopened as
evidence/objective anchors because later owner evaluation did not accept their
broader gameplay objectives. #82 owns broad player/granular acceptance. REM-002 /
#81 has now reconstructed the historical #11 divergence as a never-integrated
branch and reconciled the still-valid bounded generic body↔cellular semantics on
current source; [its dated audit](../audits/2026-09-24-rem002-issue11-integration-forensics.md)
is the current integration record. #83 now owns the broader body/granular envelope
and owner acceptance. The barrel remains a generic Rapier reference body; do not
start substitute implementation work under #10/#11.

#19's simulation/presentation apparatus remains valid, but formal blind H capture
waits for #84. #26's exact negative candidate result remains valid; #49 has now
supplied the corrected successor apparatus/control, and #95 is the decision join
before #45 may select a successor disposition.

This remediation is not a global physics freeze. #12 Stage 3B continues under its
own plan, subject to live owner/write-set collision checks before a remediation
child touches the same native World/test surfaces.

## Current execution-order rule

**Do not execute GitHub issues numerically.** For #24/#27-#30 and their links to
#18/#20/#26/#14, read the
[MicroScenarios and intermaterial-interactions programme](microscenarios-programme.md)
before choosing the next task. #27 may proceed once its launcher/input hygiene is
present; it no longer waits for #18 or G-final. #28 exploratory scenarios may
begin on a stable-enough #27 host and are explicitly provisional until affected
physics/architecture changes are revalidated. The #29 readiness gate has been consumed and PR #55 has merged as
`910717aac101363ec2b1b89e4041a22bc9a97b97`. #29 is complete for its bounded
INT-000 infrastructure checkpoint; #30 remains a tracker, not an execution gate.
Do not restart #29 from the historical preflight branch. Later material tuning is
separate bounded/versioned work using the landed schema/fixtures/provenance, and
no global physics freeze follows from INT-000.

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
feedback have separate baseline evidence. Issue #10 changed the first two under
its versioned policy. The masked-source/barrier/bearing defect family was later
reconciled by REM-002; use the current coupling contract and REM-002 audit rather
than treating this 2026-09-09 baseline as Current behavior. The local historical
checkpoint still retains its original fixtures, reduced data and plots.

## Issue #10 handoff

**Current:** Issue #9 remains historical characterization and Issue #10's
bounded player/exchange policy remains valid. REM-002 now supplies the current
bounded generic rectangle baseline for masked-source authority, barrier-aware
ejection and granular bearing; broad body/granular acceptance belongs to #83.
See the [granular/player policy](../systems/granular-interaction-policy.md) and
[current coupling contract](../architecture/rigid-body-and-cellular-coupling.md).

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

The frozen [producer/connectivity execution contract](soliding-stage3-freeze.md)
was implemented on `codex/issue-12-stage3-integration`; the parent-owned
[Stage-3 exit review](../audits/issue-12-2026-09-19/stage3-exit-review.md) maps every
checklist item to source, tests or an explicit safe refusal. Its corrected
[276-process cost record](../audits/issue-12-2026-09-19/stage3-cost-results.md)
retains material fixed memory and large-region rebuild costs rather than claiming
a win. Publication checkpoint `82e65f3` passed exact-head native/sanitizer,
Windows/Linux build, sharded Linux Godot, documentation/provenance, retrieval and
runtime-identity gates. The bounded correctness/observability reference therefore
passes **Stage 3A**; PR #47 merged as `fc299c1` and its exact head is on `main`.
The locality/scalability objective is **Stage 3B open**, but the recovery-era
producer/reconstruction chain through #65 is now complete. PR #106 landed as
`cdf0a0874d4732c41273e10d921bcd5feaac3e3c`; exact-head and landed-main
Documentation, Water, Native, dedicated sanitizer/TSan/shared/benchmark and
GDExtension/Godot gates are recorded in the
[final recovery audit](../audits/2026-09-24-cybersand-recovery-audit.md).

Use the [Stage-3B production plan](soliding-stage3b-production-plan.md), issues
#56-#70, as the active handoff. #56-#65 and #69 are complete. **#66 is next**;
then #67, #68 and the registered #70 campaign/exit packet. Recheck live ownership
before overlapping World edits and again before the final campaign. Stage 4 is not
admitted. Stage 3 remains cells-owned discovery and cannot be used to admit
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

## Issue #49 Water successor apparatus v2 handoff, 2026-09-20

Use [the post-merge #26 review](../audits/2026-09-19-issue-26-post-merge-review.md),
the [frozen v2 correction registration](../audits/2026-09-20-issue-49-water-apparatus-v2-registration.md)
and the [source-matched Current-Water v2 baseline](../audits/2026-09-20-issue-49-water-apparatus-v2-baseline.md).
#26 remains closed and its two exact candidate rejections remain valid; the v1
harness remains historical evidence rather than the successor acceptance oracle.

[#49](https://github.com/techrote/cybersand/issues/49) now supplies versioned
coverage/equilibrium/censoring metrics, the clean roofed-passage two-limb fixture,
fixture-appropriate surface evidence, phase-separated timing and a
failure-retaining evidence runner. Its 120-case Current-Water campaign preserves
mass, zero post-setup allocation and 1/4-worker authoritative parity. The clean
two-limb control remains `not_reached` for both preregistered equilibrium
thresholds by tick 4800. Production Water semantics are unchanged.

The apparatus-side gate is therefore supplied. #95 must consume this corrected
control with the available WEX evidence before #45 may proceed, narrow, recharter,
defer or no-go.

## WEX Water hybrid / pressure extension handoff, 2026-09-20

Read the [canonical WEX programme](water-hybrid-pressure-extension-programme.md)
and tracker [#90](https://github.com/techrote/cybersand/issues/90) before selecting
a new #45 mechanism.

#49's corrected successor control is now available and remains independently
required input to #95. In parallel, #91 freezes current generic Rapier↔Water
splash/displacement and hard-boundary behavior. #92 may later test at
most roughly 3-5 segmented upper-volume solided-Water sheet tiers, but only through
a suitable generic #12 hybrid substrate; do not create a Water-only handoff backend.
#93 is independent lumped gas-region research and #94 is conditional on its
positive admission.

[#95](https://github.com/techrote/cybersand/issues/95) is the decision join. It
must consume corrected #49 controls plus WEX evidence and then route #45 to
proceed, narrow, recharter, defer or no-go. Equal-level communicating-head results
must state vented/shared-pressure assumptions; separately sealed headspaces are a
different physical control.

The current affected route is therefore
`#49 corrected apparatus + #91/#92 hybrid evidence + #93 optional gas evidence -> #95 -> #45 disposition -> #18 admission/no-go`.
#28/#29 remain independently runnable.
