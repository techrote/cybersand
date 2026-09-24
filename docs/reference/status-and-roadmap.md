---
title: Status and foundational roadmap
status: Current
document-kind: reference
scope: Current implementation map, unresolved correctness and policy decisions, and bounded next checkpoints
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-09-24
related-documents: [validation-evidence.md, invariants.md, ../operations/documentation-maintenance.md, ../operations/architecture-programme-water-feel-addendum.md, ../operations/microscenarios-programme.md, ../operations/development-claims-remediation-programme.md, ../operations/water-hybrid-pressure-extension-programme.md, ../operations/github-development-and-release.md, ../audits/2026-09-24-cybersand-recovery-audit.md]
---

# Status and foundational roadmap

## Is the foundation ready to extend?

**Current documentation is organized for foundational work; the simulation has
known correctness and policy gaps.** The [source checkpoint](../operations/source-checkpoint-and-recovery.md)
secures existing work locally. Resolve the relevant issues below before building
new physics on assumptions that the current implementation does not guarantee.
The [validation ledger](validation-evidence.md) separates dated runtime results
from inspected code. No documentation status is a blanket platform acceptance.

## Recovery / current CI checkpoint — 2026-09-24

The [final recovery audit](../audits/2026-09-24-cybersand-recovery-audit.md)
closes the 2026-09-20 through 2026-09-22 CI / Stage-3B recovery programme.
The inspected pre-REC-008 main is
`0405cdfe35a855e8287215a71d1165e3107fd1d6`.

Routine active CI is GitHub-hosted and machine-checkably rejects obsolete
Avrea/Sengi/CircleCI routing, self-hosted/custom runner labels and
`*_RUNNER` indirection. #65 is merged and fully verified; Stage-3B's next
dependency-ready package is **#66**, followed by #67, #68 and #70. Stage 4 remains
blocked. PR #105/#94 is recovered but remains draft research pending its separate
disposition.

Remote `main` remains unprotected with no repository ruleset. The owner-side
minimal protection action is explicitly documented; do not report it as installed.

## Development-claims remediation checkpoint — 2026-09-20

The [canonical remediation programme](../operations/development-claims-remediation-programme.md)
governs F01-F19 and issues #79-#87. It separates Implemented, Integrated, Verified,
Accepted and Dispositioned instead of using issue closure as a proxy for all five.

Current tracker truth is deliberately conservative: #8 remains open; #9 retains
its scoped characterization; #10 retains its bounded policy/fixture evidence but
broad player/granular acceptance is open under #82; #11 retains its bounded
historical repair evidence but that repair is absent from audited current main,
so #81 owns integration and #83 owns later broad body/granular acceptance. #12 is
an independent scalable-soliding programme, not the sole remaining reason for #8.

#10/#11 are evidence/objective anchors, not duplicate implementation lanes.
Historical completion records remain immutable.

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
and [reproducible tooling](../operations/physics-characterisation.md) retain the
scoped characterization. Issue #10's
[versioned player and exchange policy](../systems/granular-interaction-policy.md)
is implemented and its dated fixture evidence remains valid, but later owner
gameplay evaluation did not accept the broader player/granular objective; #82 owns
that remediation.

Issue #11's historical repair checkpoint remains bounded evidence, and REM-002
has now established why it disappeared from project truth: the repair branch was
**never integrated into main**, rather than later merged and regressed. Current
source reconciles the still-valid generic masked-source, barrier/foreign-mask
ejection and bounded granular-bearing semantics, with source-matched retained
runtimes and a focused recurrence regression. See the
[REM-002 forensic/current evidence](../audits/2026-09-24-rem002-issue11-integration-forensics.md).

This does not convert the historical result into broad acceptance. The owner
clarification still treats the barrel as a generic Rapier reference body and does
not accept the historical ordinary envelope as finished body physics. **#83 /
REM-004 is now the body↔granular acceptance owner after REM-002**. Raising impulse
caps alone remains an invalid substitute. The
[remediation programme](../operations/development-claims-remediation-programme.md)
owns these claim-state distinctions; #12 remains independently active.

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

**Current implementation, bounded acceptance:** Material-aware player support,
separate side resistance, bounded enclosure recovery, powder-pair exclusion and
scheduled Mercury permeability are implemented. The
[dated evidence](../audits/2026-09-09-issue-10-granular-policy.md) records parameter
screening, native/fallback/desktop/Web execution and remaining publication/platform
limits. Those results are retained, but they do not constitute the later owner
gameplay acceptance that #82 must obtain or explicitly disposition. Body/granular
integration/acceptance is separately #81/#83.

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

This checkpoint is a valid simulation/presentation apparatus result, not an H
preference result: mass8/coherence12 remain the production/reference control, no
preferred candidate or production packing was selected, #18 remains held, #20
remains downstream and G-final remains open. The earlier "H-ready" label is
qualified for current use by REM-001: formal blind-study capture remains blocked
on #84's arm-identity separation and append-only observation repair.

## Issue #26 Water head/leveling disposition

**Complete experimental Outcome B, 2026-09-19:** the
[dated #26 evidence](../audits/2026-09-19-issue-26-water-leveling.md) confirms that
Current Water has a real deep/extended head-transmission deficit rather than only a
presentation or mass-precision problem. A 108-case frozen control preserves exact
mass, 1/4-worker authoritative parity and zero post-setup allocations. Medium and
deep identical outlets produce the same early discharge; communicating pools and a
true unequal-head U-tube can quiesce with roughly 16- and 24-cell level differences.

The preregistered radius-2 head-scaled-local and same-row-horizon arms were both
rejected. Neither reached the automated survival gate, so no combined arm or owner
H audition was warranted and **no Water semantic change is selected**. The retained
characterization apparatus is reusable.

[Issue #45](https://github.com/techrote/cybersand/issues/45) is the bounded successor
for transmitting head/pressure through saturated connected Water. #18 remains
open/held until that bulk confound is resolved; #20 remains downstream and G-final
remains open. MicroScenario/INT-000 work continues independently and only affected
Water-dependent provisional evidence needs later revalidation.

## Issue #26 post-merge review and #49 correction

The [post-merge review](../audits/2026-09-19-issue-26-post-merge-review.md)
preserves #26 Outcome B for its two exact rejected local candidates, while
qualifying apparatus v1 for future acceptance use.

Confirmed apparatus limitations include dry-column false-pass equilibrium,
success-valued zero for unreached thresholds, non-revoked sustained passage,
a historical three-compartment fixture mislabeled as a clean U-tube, mixed
active/sleep p95 interpretation and evidence-runner durability gaps.

[#49](https://github.com/techrote/cybersand/issues/49) now supplies the bounded
versioned correction and source-matched
[Current-Water v2 baseline](../audits/2026-09-20-issue-49-water-apparatus-v2-baseline.md).
The clean two-limb control remains `not_reached` for both preregistered equilibrium
thresholds by tick 4800; this is a corrected Current-Water observation, not a new
solver selection. Production Water is unchanged. #95 must synthesize this control
with WEX evidence before #45 may proceed, narrow, recharter, defer or no-go.

## Water hybrid / pressure extension checkpoint — 2026-09-20

The [WEX programme](../operations/water-hybrid-pressure-extension-programme.md)
and tracker [#90](https://github.com/techrote/cybersand/issues/90) add a parallel
investigation before any new #45 pressure/head mechanism is treated as inevitable.

- [#91](https://github.com/techrote/cybersand/issues/91) freezes current generic
  Rapier↔Water splash/displacement and hard-boundary failure evidence.
- [#92](https://github.com/techrote/cybersand/issues/92) is dispositioned
  **BLOCKED** on current main: the required generic dynamic cell↔Rapier singular-owner
  handoff remains Planned/model-only under #12. No sheet arm ran and the hypothesis
  is untested, not rejected. See the
  [blocked disposition](../audits/2026-09-24-wex002-water-sheet-blocked-disposition.md).
- [#93](https://github.com/techrote/cybersand/issues/93) research records a
  [bounded lumped-region candidate](../research/lumped-gas-region-pressure-bookkeeping.md):
  technically promising for optional/research use, with no production atmosphere
  adoption.
- [#94](https://github.com/techrote/cybersand/issues/94) completed as
  [NARROW-USE local decompression research](../audits/2026-09-24-wex004-decompression-disposition.md);
  no general routed/room-scale atmosphere feature is admitted.
- [#95](https://github.com/techrote/cybersand/issues/95) now has all prerequisites
  in their allowed form (#92 explicitly blocked) and is the next WEX action. It
  synthesizes WEX evidence with merged #49 controls and decides whether #45 should
  proceed, narrow, recharter, defer or no-go.

Water FreeMass and other-liquid CellularYield remain separate; no unification or
production solver change is selected. Equal-level communicating-head fixtures are
vented/shared-pressure controls, not universal sealed-room targets. #18 remains
held pending the resulting evidence rather than by issue-number sequence alone.

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

**Dated 2026-09-11 programme state:** G-L, G-C and G-P are complete. #16 research is complete;
that checkpoint retained its 4-byte Cell baseline pending G-final, not a permanent
width selection. The source-qualified 2026-09-19 storage correction below governs
current physical-size accounting. #17 retains mass8 as the numerical/reference Water control and proves
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

#29 is **INT-000: intermaterial interactions**, not a chemistry-only campaign.
**Merged/current infrastructure:** PR #55 landed as
`910717aac101363ec2b1b89e4041a22bc9a97b97`; #29 is complete for its bounded
infrastructure checkpoint and #30 remains the programme tracker. The landed #27/#28
apparatus has been consumed by the versioned sparse interaction substrate. The compact 14-rule
pair boundary now resolves through stable IDs/channels with a literal frozen
pre-migration oracle; layered family/material/pair/context authoring, conflict
validation, specialized-kernel provenance, coverage/revalidation records,
generated schema-2 fixtures and batch comparison tooling are implemented in the
source checkpoint. Specialized neighbourhood/lifecycle mechanisms remain
authoritative in their existing `world.cpp` kernels where migration would
unnecessarily entangle kinetic ownership.

No broad interaction tuning is selected by this infrastructure checkpoint.
Kinetic movement/support/bridging/erosion/collision remain owned by existing
physics systems. Each later accepted tuning pass must pin the relevant
source/runtime/contact/transport baseline and retain prior evidence so later
physics changes trigger targeted re-screening rather than destructive retuning.

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

## MS-001 reference-pack checkpoint

**Merged exploratory checkpoint, 2026-09-19:** PR #44 landed the schema-2
[reference pack](../operations/microscenario-reference-pack.md) at merge
`c1edf907cce1693fa45f89e9f1f573f05483c1e4`: Materials Laboratory with
complete generated interaction fixtures/fresh-reset A/B, a Flood-Control Puzzle
with a wet untreated control and three distinct geometry-only successful
witnesses, and four finite Water/granular/gas/mixed Simulation Stress profiles.
Schema-1 Tower/Water definitions retain their hashes and existing blind controls.
No material rules, profiles, capacities or physics defaults changed.

The accepted PR head `95aa2a0cb7b68445ed4a23ad16481c947e5a4695` passed
documentation/provenance, native and Godot CI before merge. The
[execution ledger](../audits/2026-09-19-issue-28-ms001.md) records a bounded
post-merge review that retained the implementation while correcting Flood
endpoint wording, the Stress uniqueness regression and stale compact definition
hashes. Actual Windows/browser/target-GPU execution remains unavailable.

The explicit Lab readiness prerequisite for #29 was satisfied and consumed by
PR #55 after a fresh reconciliation of the historical preflight against the
landed schema-2 contract. PR #55 subsequently passed its required acceptance gates
and merged; #29 is closed. MS-001/INT-000 completion still does not waive
#18/#20/#26/#14 gates, and later interaction tuning remains separately bounded.

## INT-000 implementation checkpoint, 2026-09-19

**Historical pre-merge checkpoint:** PR #55 was the sole #29 implementation
owner at this point. It has since merged as
`910717aac101363ec2b1b89e4041a22bc9a97b97`; use the current programme/status
paragraphs above for live routing. It preserves existing compact pair behavior while migrating
that bounded authority behind the versioned sparse resolver, exposes read-only
effective provenance through the existing schema-2 Materials Laboratory path, and
adds generated mechanism fixtures plus batch coverage/pass comparison tooling.

The interaction schema defines seven independent channels and explicit precedence
for channel default < family default < material adjustment < pair override <
context modifier. Current behavior authors no implicit defaults/adjustments/
modifiers; tests cover ordered, symmetric and unordered-role-preserving pair
semantics plus equal-precedence conflict detection. Captures retain rolling
source/runtime/transport/Water/execution/worker baseline identity for targeted
revalidation. Coverage gaps remain explicit rather than being converted into a
dense fabricated matrix.

This checkpoint does **not** migrate specialized movement-entangled `world.cpp`
kernels, select new material tuning, alter Water/granular/soliding/ballistic
semantics or satisfy independent architecture gates. Final status is not upgraded
from candidate until exact-head current checks and final diff/acceptance review
complete.

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

[Successor evidence](../audits/2026-09-19-issue-12-foundation.md) includes the
reviewed standalone lifecycle, bounded journal and measured Current sleep control.
The parent-owned [Stage-3 review](../audits/issue-12-2026-09-19/stage3-exit-review.md)
classifies the integrated producer/connectivity implementation as the passed Stage-3A
bounded correctness/reference checkpoint at `82e65f3`, with exact-head CI,
provenance and final parent review complete. Stage 3B locality/scalability remains open: measured fixed memory,
full tracked-tile signal refresh and whole-region sparse-edit rebuilds prevent full
Stage-3 admission. PR #47 merged the bounded reference as `fc299c1`. The read-only Stage-3B
architecture review is complete; its supervising-parent reconciliation is recorded in
the [Stage-3B parent decision](../audits/issue-12-2026-09-19/stage3b-parent-decision.md).
The active implementation route is the
[Stage-3B production plan](../operations/soliding-stage3b-production-plan.md), issues
#56-#70. #56-#65 and #69 are complete. #65 / PR #106 landed as
`cdf0a0874d4732c41273e10d921bcd5feaac3e3c` after exact-head validation and
source-matched runtime publication; landed-main Documentation, Water, Native and
GDExtension/Godot validation also passed. **#66 is now dependency-ready**, then
#67, #68 and #70. Stage 4 is blocked; production dynamics, fracture and persistence
remain unimplemented. Source `de332ea` actually uses
the 8-byte superset carrier after #19 integration;
the [storage contract](../architecture/chunk-tile-and-buffer-model.md) supersedes
earlier four-byte physical-size statements for this source without selecting G-final.
