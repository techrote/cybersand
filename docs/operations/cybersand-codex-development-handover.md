---
title: Development handover
status: Current
document-kind: guide
scope: Short onboarding sequence and checkpoint protocol; product intent, source identity and contracts have canonical homes
canonical-for: [development-onboarding]
last-reviewed: 2026-10-19
related-documents: [source-checkpoint-and-recovery.md, ../reference/product-intent-and-priorities.md, ../reference/status-and-roadmap.md, microscenarios-programme.md, development-claims-remediation-programme.md, water-hybrid-pressure-extension-programme.md, github-development-and-release.md, ../audits/2026-09-24-cybersand-recovery-audit.md]
---

# Development handover

## Physical usable integration checkpoint — 2026-10-19

USABLE-002 / ACT-005 / #182 reconciles PR #180's U01-U32 catalogue with the
ACT-004 physical session. Start with [actor usables](../systems/actor-usables.md),
[physical equipment actions](../reference/interfaces-and-message-contracts.md#physical-equipment-actions-and-results)
and the [dated checkpoint](../audits/2026-10-19-act005-physical-usables.md).
Keep physical source/body frames, issued observations and equipment incarnations
separate from the retained sampled equipment mailbox. Worker edits and physical
recoil use identity-matched results. Dropped/settled/reattached chassis preserve
body slots and processor history. All 41 default loadouts remain authored data;
controllers only submit ordinary actions.

Read the current checkpoint's unfinished gates before claiming completion. Native
source/provenance identity, current GDScript execution, hosted exact-head checks
and Windows interactive execution are distinct evidence. Continue the owner's
30-minute repository progress checkpoints during this implementation task.

## Grey Area 51 scene checkpoint — 2026-10-19

[Grey Area 51](grey-area-51-demo.md) adds a connected five-tile concrete bunker
through the existing MicroScenario host and exploratory actor path. The feature
launcher, Ctrl+F11 and `-- --grey-area-51` open one 960 × 192 native slab; its
5×1 camera map and 320 × 192 follow view retain scene state, and R restores the
whole bunker. One presenter owns both Blacksite and Grey map/minimum-size/modal
lifecycle. Native semantics and capacities are unchanged. Use the
[dated scene audit](../audits/2026-10-19-grey-area-51.md) for source, recipe and
platform evidence; the ACT-005 equipment checkpoint above retains its own gates.

## Exploratory actor picker follow-up — 2026-10-18

F5 now connects the sandbox, Blacksite and four showcase maps to explicit Sampled
and Rapier choices. The selected map is restored on change; R retains the actor.
ACT-004 supplies [41 articulated physical rigs](../systems/physical-actor-rigs.md),
including all existing identities, twelve new mechanisms and local feedback
scripts. Read its physical v2 command/mount contract before changing producers.
Actor resets need both owner request serial and map hash; do not regress to
hash-only admission. The implementation remains desktop scoped. Sampled control
rows and scientific references retain their own meanings; the current generic
body capacity is 64. Exact runtime/source evidence belongs to the dated ACT-004 audit.

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

## Procedural generation candidates — 2026-10-18

GEN-001 / [#163](https://github.com/techrote/cybersand/issues/163) implements a
separate native generator and opt-in authoring workbench. Start with the
[generation contract](../systems/procedural-world-generation.md) and
[dated evidence](../audits/2026-10-18-gen001-procedural-generation.md). Strata,
Flow Network and District Grammar share theme DAG selections, blends, brush
controls, routes, exact overrides and prepared versioned feature factories.
The workbench previews bounded demand generation; general simulation streaming,
eviction/persistence and automatic reconciliation of edited recipes remain
separate. Its native fresh-chunk installer refuses all existing storage and
requires caller-owned receipt/reset admission. Do not attach it concurrently to
a live World owner or infer production streaming from the preview.

## Procedural fields and masked authoring — 2026-10-18

GEN-002 / [#171](https://github.com/techrote/cybersand/issues/171) extends those
candidates with a bounded scalar DAG, finite Hilbert/Morton tiles, structured
noise, analytic/context masks, theme/parameter/material modifiers, aggregates and
field-masked feature instances. Read the
[field/modifier contract](../systems/procedural-generation-fields-and-modifiers.md)
and [dated evidence](../audits/2026-10-18-gen002-fields-and-aggregates.md) before
changing observation order or selection semantics. Every mask sees the initial
proposal; hard geometry is reapplied after guidance, the route skeleton follows
material modifiers, and hard material is final. Aggregate weights are strictly
positive and resolve ordinary existing material IDs.

The workbench adds field/aggregate/modifier editing, context-aware brushes,
transforms and copied diagnostic overlays. `make worldgen-test` and
`make worldgen-sanitize` include independent curve/field and modifier regressions,
including historical GEN-001 material hashes. The
[local build guide](local-build-and-validation.md) covers both Godot test scripts
and the native example renderer. Algorithm identity is now 2; a retained GEN-001
binary is not source-matched evidence for these APIs. The ACT-002 merge preserves
its rig behavior and supplementary retrieval questions; no actor/native physics
owner is changed by generation guidance.

## Thunderbowl control laboratory — 2026-10-18

ACT-003 / #172 adds the standalone native
[Thunderbowl reference and examples](../systems/thunderbowl-control-reference.md).
Its owner wraps a real World and the current eight-slot actor session; it does
not replace ordinary F5 selection or registered scientific fixtures. New actor
definitions may fix `control_mode` to `metal` for Ripper, Copter or Gemini.
That lane bypasses intent actuation and publishes separate 32-value force/torque
readback; original v1/v2 observations and SetA motor bytes remain compatible.

The shared driver collects copied policy views before stepping any actors.
Self/local/oracle privileges, message delivery, arena-only virtual tag combat,
model-plan freshness and resource/work bounds are explicit. Controller examples,
eight JSON schemas and fourteen match definitions live under
[`godot/examples/thunderbowl`](../../godot/examples/thunderbowl).
The NCA-inspired graph weights are untrained; the Python smart-link client is an
offline mock. Model inference, learned performance, complete replay and broad
platform/feel acceptance must not be inferred from runnable examples.
The [dated ACT-003 audit](../audits/2026-10-18-act003-thunderbowl-control-lab.md)
binds local execution to the public source checkpoint; PR #174 records final
hosted CI and integration disposition.

## Actor control prototypes — 2026-10-18

ACT-002 / #168 expands the original ACT-001 / #161 trio into 29 optional desktop
rigs in SetA/B/F/Y/U/V. Read the [rig contract](../systems/actor-rigs.md) before
changing movement, input or observation fields. The
[SetA compatibility page](../systems/actor-control-prototypes.md) preserves Runner,
Skimmer and Crawler's original motor and 16-value observations. New rigs use
independent aim, effort, trim, reel and auxiliary with additive 40-value state and
consumed action/edge readback. Catalog names and fictional SetV personas do not
connect model services or claim real model behavior.

**F5** selects a set/rig, keyboard/demo/external-policy pilot, power and optional
comparison with the other rigs in that set. WASD, pointer aim, Space/Shift/C,
Q/E trim, Z/X reel and brackets use the same expiring policy interface. The owner
acknowledges reset outcomes before human control resumes; controlled fixtures
retain their explicit player identities. Expiry/cancellation discards charge,
attachment and pending effects before neutral input advances.

The session remains capped at eight actors. SetA retains its 32-query limit;
new rigs have explicit occupancy, ray, effect and angular/translation budgets in
the [configuration reference](../reference/configuration-reference.md#actor-rig-values).
Source and Linux headless evidence remain separate from target-PC feel,
many-NPC throughput and Windows/Web execution. The
[validation ledger](../reference/validation-evidence.md) owns dated execution;
the original ACT-001 audit remains unchanged.

## Connected scene content — 2026-10-18

[Blacksite Nine](blacksite-nine-demo.md) adds a new, continuous 3×3 scene on
`scene/blacksite-nine`, based on the four-scene branch and current ACT-002 main
`087ca3e972296b189c8b83060463125c06d600e2`. It places a fortified research lab
between two industrial wastelands above six dense underground districts. Twelve
ordinary native openings connect all neighbouring tiles. Shift+F11/Web menu
launch the whole world; its 3×3 camera map preserves edits and player state,
while R restores the complete complex. The
[dated evidence](../audits/2026-10-18-blacksite-nine.md) owns traversal, rendering,
source/runtime identities and publication status.

## Material consistency repair — 2026-10-18

The separate [Neon Reliquary descent](neon-reliquary-demo.md) adds four detailed
districts based on accepted MAT-001 main `ec05d722`: Neon Reliquary, Middle
Cyberberbia, Sewertech Alley and Industrial Underswamp. Desktop F11 and the Web
menu use the existing shared scenario host; Above/Below load the neighboring
district's original paused layout, while viewpoint changes preserve edits.
The [four-tile evidence](../audits/2026-10-18-neon-reliquary-descent.md) records
actual Godot views, focused validation and the owner's explicit branch-push
authorization. Work is isolated on `scene/neon-reliquary-demo`. Keep subsequent
material-shader work separate from these recipes and their empty-space backdrop.

The owner reports that restarting resolved the all-four-builds problem and asks
for actual material-behavior improvements. MAT-001 / #158 owns the bounded native
repair for persistent compact-pair/Ice reactions lost to sleep and center-block
waking on body-mask changes. Read the [dated implementation/validation record](../audits/2026-10-18-mat001-material-reaction-progress.md)
and [activity contract](../systems/activity-dirty-regions-and-waking.md) before
extending that scope. It does not select a #45 Water successor or change authored
interaction products/probabilities. Source-matched retained Linux/Windows runtimes
and the normal applicable ready-for-review checks remain integration gates.

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

## PCHAR player-representation experiment — 2026-09-25

PCHAR-001 / #137 adds a reset-scoped ordinary-sandbox experiment under parent
#132. F6 switches between the historical sampled character and body 0 acting as
a barrel/Rapier player; F7 toggles the sampled-only burial-safe runtime policy.
Both controls perform a fresh reset. Registered Tower/Water and ordinary
MicroScenario definitions still force the historical sampled-baseline identity.

PLAY-VAL-001 / #139 adds three explicit **experimental** REM-003 catalogue arms
for matched owner comparison: sampled-baseline, sampled-burial-safe and
barrel-rapier. Their representation is selected only by loading the named fixture
through a fresh reset; F6/F7 remain blocked while a controlled MicroScenario is
active. This is the only current registered-MicroScenario exception to the
historical sampled-baseline rule.

The sampled baseline now exposes runtime enclosure-recovery attempts, successes
and upward relocation. Burial-safe sampled mode retains explicit invalid-spawn
repair but does not reorder an actor that becomes enclosed at runtime. The barrel
player reuses current generic body coupling and receives only bounded horizontal
main-thread locomotion impulses. Do not change generic body bearing/ejection or
sample-age semantics here; those remain #83 / REM-004. Parent #132 remains open
regardless of the PCHAR-001 experimental outcome.

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


## PENV-001 player/environment tuning handoff

Issue #138 is the first finite child under long-lived parent #133. Read the
[player/environment tuning contract](../systems/player-environment-profiles-and-traversal.md)
before changing sampled-character gravity, terminal speed, effective mass,
jetpack values or traversal thresholds.

The exact-current profile is the regression control. Candidate edits remain
fresh-reset inputs; do not turn the panel into unsynchronized live mutation.
REM-003 C1 still owns bounded player↔granular disturbance semantics, while
PENV-001 supplies only separate player-side mass/sensitivity scaling. The exposed
liquid-sensitivity identity is not permission to alter Water pressure,
displacement or generic Rapier-body behavior.

PCHAR-001 / #137 merged first as `5e53178ba083a0ccd10933cd404395fdbd7dc2b3`.
PENV-001 is reconciled on top of that representation layer: ordinary sandbox
barrel/sample selection and sampled burial-safe recovery remain independently
owned, while registered Tower/Water/MicroScenario runs retain PCHAR's forced
sampled-baseline behavior. Tuning a profile therefore must not erase or silently
change the selected representation/recovery policy.

Parent #133 remains open after #138.

## Combined features and physical actors — 2026-10-18

Use the [physical actor programme](physical-actor-programme.md) for the combined desktop launcher, retained single-hull Blacksite comparison and preserved owner notes. ACT-004's [physical actor contract](../systems/physical-actor-rigs.md) owns the articulated Ripper and full roster. Its authored gyro and flex/play mechanics deliberately approximate reality for gameplay.

## Reconstructed depth prototype — 2026-10-18

PR #169 integrates [Strata Theatre](../systems/depth-layers-and-parallax.md) with the feature branches. Use its [fresh validation record](../audits/2026-10-18-depth-integration-validation.md); old local evidence does not certify the reconstructed source. F4 opens the separate lab; it does not attach four new owners to the ordinary gameplay World.
