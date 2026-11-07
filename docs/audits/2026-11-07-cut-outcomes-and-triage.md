---
title: Cut outcomes, asynchronous boundary and owner triage
status: Current
document-kind: audit
scope: Source-pinned fresh authored post-cut comparison; asynchronous feasibility and stop-for-triage checkpoint, no physics or production disposition change
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../architecture/workbench-freed-objects.md, 2026-11-07-workbench-rectangle-core.md, 2026-11-06-sol-workbench-law.md, ../operations/cybersand-codex-development-handover.md]
---

# Cut outcomes, asynchronous boundary and owner triage

Owner asks whether cutting can continue without pausing the whole simulation,
then compares rectangle+Sand, all Sand and rectangle-only/discard. Owner directs
that work stop afterward for assessment of the accumulated tangents. Keep519
Draft, keep physics unchanged, add no test menus, and preserve earlier windows.

Registration/observer5b56b416 precedes execution. Parent is
dc4fe60fbd503a7043c7e63934da44015bd849b3 on the sole-writer branch
`codex/workbench-rectangle-core-20261107`. Production remains the3ad15e4a
scheduling/native stack; this checkpoint adds tests, analysis, ordinary authored
canvas data and documentation. Native93-source+15-build-input inventories and
protected material inputs match the prior executed cohort. No native rebuild,
new sanitizer run, default change or parent-PR write is claimed.

## Asynchronous cutting: current boundary

**UNAVAILABLE through the current admitted handoff while both simulations keep
running.** Current commands are asynchronous with respect to UI dispatch, but
the simulation is held. Removing `host.paused` or worker hold would not implement
a valid asynchronous transaction:

- `workbench_cut.gd::finish_stroke` pauses and suspends the physical session.
- `simulation_worker.gd::queue_workbench_cut` admits only paused cuts; the held
  worker branch executes commands rather than ticks.
- `world_solid_detachment.inc::prepare_workbench_solid` enters Prepared. Native
  `solid_detachment_fenced()` includes Prepared/Acknowledged/Committed/
  DebrisCommitted. Commit requires the same source tick and terrain revision.
- `solid_workbench_adapter.inc` acknowledgement requires every existing body's
  transform, velocities, COM, mass/inertia and geometry to match begin exactly.
- `physical_actor_session.gd::stage_workbench_piece` requires suspension and
  changes the live bridge roster/history. Advancing Rapier alone while native
  Sand is held would change the coupled physics.

**Planned option, not implemented:** speculative copied-value discovery/recipe
and first-body preparation in the existing permanent inactive physics space,
while native cells continue. A final authoritative hold must redo full current
tuple/eligibility/geometry/COM/inertia/policy/capacity proof and discard any stale
prediction. This might move the two frozen preparation frames out of the hold;
it does not eliminate the final fence. Mixed bodies additionally need a new
split staging API that does not alter the active roster/history, followed by
admitted append/rebind. Full non-pausing operation needs a local reservation,
terrain revision and epoch contract. No such authority is added here, and E1/E2
and365 restrictions are not waived. Do not label background recipe work alone
as a fully asynchronous cutter.

## Three representation arms and exact limits

The live cutter supports exact rigid capture, core+Sand and original-source
1–16-cell Sand/Rust. It has no all-Sand520/356 or discarded-fringe disposition.
The comparison therefore uses **uniform fresh authored post-cut representations
for all three arms**, via existing CanvasBody/native edit APIs. This measures
real existing World/Rapier behaviour, not alternative live-cut execution,
cut latency, captured-tuple persistence or asynchronous transfer admission.

One genuine native stem cut per shape/bed supplies the prepared full/core/fringe
tuple witnesses, rectangles, COM/inertia and resulting authored recipe. Each
measured arm then starts a fresh World/session from that recipe:

| Source | Core+Sand | All Sand2 | Core only |
|---|---|---|---|
| RedBrick tree-shaped520 |208 rigid +312 Sand|520 Sand, no body|208 rigid +312 explicitly discarded|
| RedBrick building356 |152 rigid +204 Sand|356 Sand, no body|152 rigid +204 explicitly discarded|

The tree core is44/27/16/13, COM52/33.5, mass208, inertia22100/3. Building core
is50/27/4/38, COM52/46, mass152, inertia55480/3. Both leave the original anchored
eight-cell stump50/70/4/2. Holes, floor and brush-erased surroundings are
preserved. All-Sand fills only the actual core in addition to existing fringe;
discard erases only exact fringe tuples, never an AABB. Both rigid arms use the
same core, mass/inertia,92.12 gravity,0.04 damping,0.78 friction,20 budget,
LA-SELECTIVE law and current Water policy. No drive or force tuning occurs.

These are RedBrick structural shapes, not qualified Wood/bark cohesion or
reactive/mixed-material buildings. Authored starts have no native cut archive;
their tick/history/arrival sidecars are fresh. Source-derived material positions
and body geometry/M-I are verified, but this is not strict live-cut trajectory
replay or a complete copy of the original bed/liquid auxiliary state.

## Executed comparison and observations

Fixed profile `native/tests/fixtures/workbench_cut_outcomes_001.json` specifies
120 exact native quanta at1/60, with one actual Rapier step per quantum where a
body exists. The last30 steps describe tail motion. This two-second window is
descriptive; it is not a rest or original SOL clearance gate.

- Windows worker1:60 fresh episodes, five repeats per shape/bed/arm, packed Sand
  and Sand/Water split beds;54084 checks/0 failures.
- Linux worker1 and Windows worker4: six packed-Sand spot episodes each;
  5434 checks/0 failures each. Actual four-worker participation is checked.
- Total72 episodes,8640 native steps,5760 actual rigid steps. All rigid geometry
  stays inside the authoritative128-square census. Initial tick0 material read
  uses the generation/serial-qualified immutable native render copy; final maps
  use four bounded native censuses. No hidden warm step is inserted.

The [median/range ledger](workbench-cut-outcomes-20261107/comparison.csv),
[execution identities](workbench-cut-outcomes-20261107/execution.json),
[summary](workbench-cut-outcomes-20261107/summary.json) and
[raw artifact index](workbench-cut-outcomes-20261107/raw-artifact-index.json)
retain all runs, commands, exits, maps and step traces. Raw data stays local.
`tools/sol281/analyze_cut_outcomes.py` independently clips the observed rectangle
against native material cells and calculates SAT depth. These calculations do
not call candidate decision code. Native/owner timing includes every step;
it excludes main-thread/GPU costs and is not the original inclusive SOL CPU gate.

Primary Windows medians after120 steps:

| Shape/bed | Arm | Tail mean speed, cells/s | Sand overlap, cell² | Mean native tick, ms |
|---|---|---:|---:|---:|
| Tree/packed |core+Sand|18.615|0.0688|0.1212|
| Tree/packed |all Sand|N/A|N/A|0.0817|
| Tree/packed |core only|0.8094|14.4936|0.0700|
| Tree/mixed |core+Sand|5.3824|0.0018|0.2794|
| Tree/mixed |all Sand|N/A|N/A|0.3584|
| Tree/mixed |core only|0.7973|14.3035|0.2443|
| Building/packed |core+Sand|approximately0|0|0.1208|
| Building/packed |all Sand|N/A|N/A|0.0791|
| Building/packed |core only|0|0|0.0871|
| Building/mixed |core+Sand|0.0005|0|0.2791|
| Building/mixed |all Sand|N/A|N/A|0.2983|
| Building/mixed |core only|0|0|0.2503|

With fringe Sand the tree core tumbles/translates more. The core-only tree is
less mobile by the end but overlaps more Sand; this is not a better-clearance
result. The building's retained core is a narrow column over its stump, so both
rigid arms behave similarly. All-Sand loses rigid structure and becomes a grain
pile. It is cheaper in the packed fixture but not consistently in mixed Water.
Lower cost with discarded material also partly follows deleting312/204 cells;
it is not a solver improvement. All-Sand pose/M-I/rigid penetration/energy are
N/A, never zero-valued successes. Granular physical mass/energy is uncalibrated;
reported kinetic/potential values are rigid proxies, not whole-system closure.

**Additional retained discovery:** all48 fresh rigid episodes reject the first
contact application with individual `age` refusal. The physical step still
executes. Each then accepts119 applications,5712 total. No warm-up, age threshold
or physics change is added to hide this. Latest published native rows can lead
the actual application sample; their occurrence counters are not an aligned
one-use applied-wrench ledger. Actual applied actions are retained separately.
This first-response behaviour needs triage if authored spawning is promoted;
it is not silently treated as genuine-cut first-step equivalence.

## Ordinary canvas left for observation

The local window is titled “CyberSand · Cut outcomes comparison · P to play”.
It is a real ordinary workbench, paused at tick0 with four bodies/four proxies.
Columns are CORE SAND, ALL SAND and CORE ONLY; rows are TREE and BUILD.
`cut-outcomes-packed-20261107` and `cut-outcomes-mixed-20261107` are ordinary
named starts. No model/menu entry was added. Existing windows remain untouched.
The shared visual demo adds distant separating walls; it is not the isolated
quantitative cohort. Native tuple archives and physical Wood trees are not
claimed. Its actual OpenGL startup/capture remains in the local custody record.

## Triage: stop here for owner assessment

These lanes should not be treated as one completed SOL fix:

| Lane | Established result | Review/decision still needed |
|---|---|---|
|460 mass/readiness and scalar energy|Effective first-impulse mass readiness/AUTO COM and scalar64 evaluation repaired; actual source geometry and native M/I retained|Keep scoped repairs separate from settling claims; physical Sand/object weight remains uncalibrated|
|461 gravity/contact order|Post ordering failed; pre remains default; ownership/disposition checks hardened|Retain negative evidence; decide whether diagnostic arm remains useful|
|466 workbench law|LA-SELECTIVE law+pacing reduces burial/sinking; packed rest still0/20; original clearance unproved|Owner D1 intended primary candidate remains; no cap/weight tuning or main promotion|
|466 correction/impulse order|Terminal world_failed diagnostic fixed; impulse-first NO-GO; correction-first remains|Retain diagnostic repair and negative evidence separately|
|466 ordinary cutting|Real native discovery, tuple-bound handoff, RID preservation, lifecycle/replay and default-brush admission implemented|Homogeneous RedBrick only; global hold, geometry limits, no live-body recutting/restoration|
|510 small debris|Eligible1–16 source cells become Sand/Rust under existing native granular rules|Provisional gameplay material choice; not calibrated fracture or liquid inertial physics|
|510 carried material/terrain|Collider stripes and all-chunk scheduling wait repaired|Separable useful repairs even if representation changes|
|519 rectangle+Sand|Full-source proof and exact core/fringe custody implemented|Lossy geometry/material choice remains provisional; this comparison adds no alternative cut mode|
|519 spans/wake/prefetch|Measured delay reduced with native sequence/fences intact|Global simulation hold remains; full async requires a new contract|
|Fresh authored starts|Three outcomes compared under existing law; first age-refused application recorded|Keep as observation; investigate first-response issue only after triage|
|Contour/triangles/mesh|Video-inspired direction discussed only|Deferred: holes, queries, mass/I, material mapping, re-cutting and bounded complexity need design|

Preserve84/84 clearance,64/84 depth,36/36 overlaps,1452 refusals, original CPU
failures,365, hard exclusions and tiny RedBrick1e-9. Linux GLIBC2.35/
GLIBCXX3.4.31 still exceeds2.34/3.4.30; actual Windows native qualification is
LLVM-MinGW, not fresh MSVC. Inherited Windows growth/camera and wake-query1/2
canonical-top5 gaps remain separate. Complete active-aggregate persistence,
reanchoring, burning/explosive release and mixed cohesion are not admitted.

The owner decision set is: **which material outcome, how much structural
fidelity, whether a new asynchronous ownership contract is worth building, and
which independently useful repairs to separate for review.** No winner/default
is selected here. Keep the draft stack. Stop further tangents at this checkpoint
and request independent adversarial review before any integration decision.


Documentation routing correction: initial checks-final incorrectly placed this
dated audit in the default corpus and failed docs/repository. It is now in the
excluded dated inventory, with canonical answers in the freed-object contract.
The two new query strings remain unchanged; canonical expectations now name that
contract. Earlier retrieval scores using the invalid corpus are not acceptance.

The corrected-corpus checks at97bbea26 all exit0: docs, M11, materialized
repository, material compatibility/compiler, runtime inventory, five retrieval
sets and diff-check. Canonical top5 results are32/32 default,7/7 freed,2/2 hitch,
**1/2 wake and1/2 cut-outcomes**. The latter two remain retrieval gaps even
though the evaluation command exits0; source review is separate from ranking.
The exact final publication-head checks and receipt hash are recorded in the PR.

## Owner pause and reusable findings — 2026-11-07

After reviewing the triage, the owner benches SOL until the majority of major
physics integrations are reconciled with main, and asks that findings useful to
other work be documented now. The canonical [owner direction](../reference/product-intent-and-priorities.md#sol-deferred-during-physics-reconciliation--2026-11-07)
supersedes earlier continuation instructions. This is a docs-only handoff;
SOL implementation, geometry design and further physical campaigns are Deferred.
PRs stay Draft. No integration, issue completion or solver/default change follows.

### Reusable repairs and unresolved observations

The receiving workstream should inspect these records before rediscovering a
known issue or copying an experimental implementation. **Keep** means retain a
review candidate and its evidence; it is not accepted-main status. Source and
runtime qualifiers belong to the linked original record, not this summary.

| Finding | Useful receiving work | Source-qualified result and required boundary |
|---|---|---|
| Effective mass readiness | Rapier actor/aggregate construction | [Readiness oracle and repair](2026-11-06-sol-stage-and-mass-readiness.md), Draft46061924a97: cached M/I could be correct while first impulses were lost. Keep actual immediate/post-step wrench tests and zero-step handoff; do not infer physical weight calibration. [Canonical coupling](../architecture/rigid-body-and-cellular-coupling.md#source-local-sol-mass-readiness--2026-11-06). |
| Rounded-state energy arithmetic | Planner guards and numerical diagnostics | [Scalar64 repair](2026-11-05-sol-energy-precision.md), executed861440e9: eight false refusals corrected and two previously accepted excessive proposals refused on the registered grid. Keep actual rounded-component accounting and genuine refusals; no general energy closure or engine speedup follows. |
| Public failure/readback correctness | Native facade, failure quarantine and tools | [Facade repair](2026-11-04-sol-facade-refusal-repair.md) and [terminal world_failed P2](2026-11-06-sol-workbench-ordering.md#p2-repair-and-source-custody) fix distinct boundary observations. Preserve native refusal authority; wrapper success is not healthy-World or ownership admission. |
| Actual gravity/damping operator | Actor mechanics and any later support predictor | [Draft42967f93a28 oracle](https://github.com/techrote/cybersand/blob/67f93a28bc05fc3b90beec9ea32e60f0864af642/docs/audits/2026-11-05-sol-gravity-operator.md): one-step no-contact gravity-then-rational-damping compatibility is source-bound. Barrel and flyer effective gravity/damping differ. No native-owner binding, exact long rollout or implemented support predictor follows. |
| Stale passive-response protection | Generic granular body application | [Draft400a38098b1 qualification](https://github.com/techrote/cybersand/blob/a38098b1a807fc3ac7b60166e75b217dd7bc629e/docs/audits/2026-11-05-la-physical-qualification.md): retain the opt-in guard as a separately reviewed candidate; two broader passive-energy filters weakened support and were rejected. Do not silently enable or port it into SOL. |
| Mixed-body regression | Workbench law/policy reconciliation | [Draft429 contact/application result](https://github.com/techrote/cybersand/blob/67f93a28bc05fc3b90beec9ea32e60f0864af642/docs/audits/2026-11-05-sol-contact-application.md): clipping-only repair failed and the recorded Kestrel regression remains unresolved at that source. Keep it as gameplay regression evidence; it does not stand in for actual structural cuts or establish current-main behaviour. |
| LA-SELECTIVE contact package | Shared granular coupling | [Draft466 law+pacing result](2026-11-06-sol-workbench-law.md) reduces burial/depth/sink in all eight primary comparisons but fails packed rest0/20. Selective arrival changes the event wrench; legacy/passive/correction remain. Avoid duplicate SOL281 response; preserve liquid policy and completed-sample pacing. Equation-only causality is unproved. |
| Application/sample chronology | Async host observations and fresh authored spawning | At07d86d10 all48 fresh rigid episodes have one age-refused first application; Rapier still steps. Latest native rows may lead actual application. [Canonical ownership caveat](../architecture/data-ownership-and-lifetimes.md#fresh-response-age-and-application-chronology) requires identity-aligned accepted actions before work attribution. This is unresolved; do not hide it with a warm-up or weakened guard. |
| Relative material weight | Material catalogue and actor mass work | [Actual-cut quantities](2026-11-06-sol-structural-cut-behaviour.md): unit structural mass is authenticated, Sand/object physical weight is not. Catalogue density ranks are not calibrated mass; cap/gravity comparison alone omits correction/clipping/hard contact. Keep these limits visible before any separately authorized tuning. |
| Native/rigid ownership and ordinary brush admission | Shared host and future cutting | [Freed rules](../architecture/workbench-freed-objects.md) preserve full tuples, one owner/body, old RIDs and fresh terrain/roster/sample fences. [Default-brush correction](2026-11-07-workbench-brush-cut.md) fixes a real eight-proxy admission defect. Current bounds remain1024 members,62-cell occupied span,8 bodies and64 shared proxies; do not silently split or replace an over-capacity shape. |
| Carried material instead of visible proxy seams | Rendering/material appearance | [Draft510 feedback repair](2026-11-07-workbench-cut-feedback.md) and [shader transition](2026-11-07-workbench-carried-shader-transition.md) retain one bounded RG8 image, holes and original coordinates without changing collision. [Canonical appearance route](../systems/material-appearance-and-rendering.md#carried-redbrick-appearance-on-the-experimental-cutting-stack); general reactive-body rendering is unqualified. |
| Changed-terrain scheduling and exact recipe rows | Terrain installation, authoring and saves | [Feedback](2026-11-07-workbench-cut-feedback.md) skips unchanged chunks; [rectangle-core follow-ups](2026-11-07-workbench-rectangle-core.md) avoid dense history replay with exact ordered row spans. Keep partial-supersession/removal handling, source-once replay and final budgets. Authored fresh starts are not active-token runtime continuation; fragmented peak memory is unmeasured. |
| Held-worker wake, notifications and prefetch | Worker scheduling/latency integration | [Wake/resume comparison](2026-11-07-workbench-rectangle-core.md#cut-wake-and-live-resume-follow-up--2026-11-07) reduces live Windows medians to about140–152ms in its two cases. [Canonical threading route](../architecture/simulation-tick-and-threading.md#held-cut-scheduling-lessons-for-other-integrations) preserves stop wake, serial checks and all refused work. A global hold remains; this is not fully asynchronous capture or a universal60Hz result. |
| Failed mechanisms and representation variants | Future SOL design and acceptance planning | Keep clipping-only, post-gravity and impulse-first negative results. Tiny Sand/Rust debris, inscribed core+Sand, all-Sand and discard remain provisional gameplay comparisons. The latter two are not live-cut modes. Contours/triangles, true Wood/bark/mixed cohesion, live-body recutting and fully async ownership remain Deferred, not established solutions. |

### Reuse and restart contract

For an independently authorized receiving integration: compare the actual
receiving source and dependency pins, identify overlap with existing main fixes,
preserve admission ancestry and original MAT locks, record real design choices,
then run its focused native/Godot/Rapier, ownership/lifecycle and platform checks.
Rebuild source-authenticated artifacts when executable inputs change. Never
relabel old executions as tests of the newly reconciled source. Compare paused
latency, live-resume latency, native cost, main/GPU work, memory and refused work
separately. First-step readback must establish actual application, not only a mode
selector or cached property. No mass/cap tuning or solver change is authorized here.

Before SOL resumes, inspect current main reconciliation progress and agree the
cutting scope: material cohesion/anchors, shape fidelity/capacity, moving-body
recutting, ownership transfer latency and supported persistence. The owner has
not defined a numeric majority or restart date. Do not restart automatically
because one PR lands. Keep original clearance84/84, depth64/84, async36/36,
1452 refusals, original CPU, hard exclusions, tiny RedBrick1e-9 and365 unchanged.

### Documentation checkpoint identity and routing

Input is clean owned branch `codex/workbench-rectangle-core-20261107` at
07d86d10c7f14d7473501d399e5f297c0003a4a2, tree90cc25a87b01c62b8cd161dd87bb0252e33ee967.
Read-only remote observation finds main81bbd5ff5cf366159e2b8a630609359c13560080;
that is not a tested integration base or proof that the requested reconciliation
is complete. Draft466b140265d and Draft51053d642b8 stay unchanged. Draft519 is
the sole publication target. Native artifacts/manifests remain the df5fa14e build
described above; no compiler, sanitizer, physics campaign or GUI reset occurs.

| Documentation surface | Disposition |
|---|---|
| Owner intent, roadmap, handover, soliding programme | Record execution deferral; earlier next-step suggestions are superseded without changing programme dependency graphs or issue states. |
| Detachment and freed-object contracts | Add explicit pause routes; preserve executable behaviour/capacities and historical results. |
| Coupling, ownership, threading, material appearance | Add focused reusable lessons and source-specific unresolved observations; do not copy ownership into a second canonical home. |
| Docs/retrieval indexes and manifest | Route new findings; existing canonical files remain in the corpus, this dated audit stays excluded. Add separate post-result questions without rewriting frozen sets. |
| Interfaces, invariants, configuration, ADRs, user controls and build tools | No executable/format/default/architectural decision changes; existing contracts and qualified commands remain applicable. |
| Evidence and checks | Keep prior runtime identities. New docs/M11/materialized-repository/material/runtime/retrieval/diff receipts are local and cited on Draft519 at final source. No runtime replay is needed for prose-only changes. |

Local `git lfs status` is clean, but the captured standalone read-only
`git lfs ls-files` exits2 with missing Git object
d058b3d1cbfaafa614fc9f4534209fb883e480f7. Earlier composite shell invocations
reported exit1; the standalone command/log is separate. This whole-tree LFS
inventory gap is retained separately from materialized artifact/provenance
checks; no object repair or universal-LFS-completeness claim is made here.

Docs-only precheck-001 passes docs/M11/materialized-repository/material/compiler/
runtime/diff commands. Canonical top5 is32/32 frozen,7/7 freed,2/2 hitch,1/2 wake,
1/2 outcomes and4/5 new handoff; wake hit@1 is0/2. Ranking gaps remain explicit,
and no query wording or expected destinations are tuned to improve them. A
read-only factual review corrected one nonexistent script class name; no material
overclaim or contradictory pause scope remained. Final-head checks are cited in
the PR, without rerunning physics campaigns for these documentation-only edits.
