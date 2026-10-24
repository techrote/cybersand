---
title: Status and foundational roadmap
status: Current
document-kind: reference
scope: Current implementation map, unresolved correctness and policy decisions, and bounded next checkpoints
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-10-24
related-documents: [validation-evidence.md, invariants.md, ../operations/documentation-maintenance.md, ../operations/architecture-programme-water-feel-addendum.md, ../operations/microscenarios-programme.md, ../operations/development-claims-remediation-programme.md, ../operations/water-hybrid-pressure-extension-programme.md, ../operations/github-development-and-release.md, ../audits/2026-09-24-cybersand-recovery-audit.md]
---

# Status and foundational roadmap

## MAT-003PREPASS S1 World apparatus — 2026-10-22

**Current registered Linux S1 correctness; broader qualification open:** [#204](https://github.com/techrote/cybersand/issues/204) retains the [S0 isolated-storage pass](../audits/2026-10-22-mat003-prepass-foundation.md), source inventory, epoch consumer audit and [proposed GEN-006 semantic handoff](../research/mat-003prepass-gen006-handoff.md). The [registered S1 apparatus](../operations/mat-003prepass-registration.md) adds seventeen real World arms using generated source copies, typed 8/16-bit counters, full semantic and conservation checks, and a gate covering two natural sixteen-bit rollovers. The registered normal/sanitized collection and independent readback passed at apparatus source `e31d296`; this qualifies the declared native Linux fixtures. The [World report](../audits/2026-10-22-mat003-world-correctness.md) owns execution status and limits. Production source and 64-bit/epoch8 storage remain unchanged.

Next: the [S2F source-only preflight](../audits/2026-10-22-mat003-s2f-preflight.md) passes six untimed Linux developer scenes and independent evidence readback. The remaining 18 source contexts, candidate observed twins and separately registered S2A/S2B paired measurements are unqualified; the S2 proposal remains unadmitted as a timing campaign. #204 remains open. Programme order is GEN-007 → MAT-003PREPASS → GEN-006 → full MAT-003; GEN-006 architecture can continue, but durable state contracts must consume this prepass. #14/G-final and unrelated Water/soliding gates remain open.

## 4LY shared physical free-flight — 2026-10-22

**Current experimental source, 4LY-001 / #205:** the
[free-flight contract](../systems/physical-free-flight.md) adds a shared single
rectangular Rapier chassis, validated versioned profile schema and two-output
desired-velocity controller. Gravity compensation, response/slew and braking
share finite thrust authority; attitude assistance has its own bounded torque.
The stabilizer has no goal, terrain or evaluator input. Authorized neutral
brakes/hovers; cancellation and expiry select explicit passive fallback.

The four stable `4ly_*` IDs retain one actual collider each with no automatic
equipment body. **4LY-002 candidate implementation (#206)** adds distinct
Trainer/Hauler/Drifter/Dart mass/footprint, speed, brake, response, thrust and
drag profiles. Ordinary F5 selection now appends a named `set4LY` after the
original eight sets: the existing 46 actor IDs and SetP positions are untouched.
The same human/script/policy owner and two-axis actuator path is reused, with
visible assistance/identity and actual-Rapier handling tests. On tested source
`f7721a1...` the [measured handling record](../audits/2026-10-23-4ly002-measured-handling-qualification.md)
shows all prospective manoeuvre thresholds passed on GitHub-hosted Linux
and Windows, as well as full Godot/Native and documentation/provenance checks.
The original failed Windows attempt was retained; its 121/121-case rerun passed.
The source field remains `candidate_4ly002` to preserve these measured hashes;
final revised-head validation, descriptive gameplay footage and human owner-feel
approval remain separate. Learning or unmeasured Web/target-PC qualification
must not be inferred from these measurements.

4LY-002 [#206](https://github.com/techrote/cybersand/issues/206) now has
passing source-bound physical manoeuvre envelopes and profile hashes, but
owner-feel and final changed-head reconciliation are still not accepted.
Next, [4LY-003 #207](https://github.com/techrote/cybersand/issues/207)
owns actual-host lab/teacher qualification. Their independent preparation may
overlap after this interface is fixed, but final host evidence uses frozen
4LY-002 profiles. Companion 4LY-004/005 own Trainer-first and family learning,
with a passing Trainer result required before family learning. Parent #132 and
generic physical/Jolt/morphology gates remain separate.

## GEN-007 authoring and qualification — 2026-10-21

**Current implementation with scoped qualification:** [Generation Workbench 2](../systems/generation-workbench-2.md) adds native provenance replay and true stages, transactional visual authoring, graph/hierarchy/plane diagnostics, undo/redo and bounded seed/recipe comparison. The [procedural qualification scene](../operations/procedural-qualification.md) supplies one compact 1024 × 1024 four-plane map: four declared seeds pass final-raster structural and equivalence checks, eight paired-plane native exhibits pass mechanism controls, and retained display captures receive a qualified visual pass for approaching Deepworks. Broad negative spaces, repeated service cabinets and less varied fine machinery remain explicit. Source-matched Linux and Windows publication passed; the [dated ledger](../audits/2026-10-21-gen007-workbench-qualification.md) retains source/runtime identities, the revised 4 GiB graphical envelope and observed authoring hitches. [PR #198](https://github.com/techrote/cybersand/pull/198) records final exact-head repository acceptance and merge verification. GEN-006 remains the subsequent streaming/persistence owner.

## Player control playground — 2026-10-20

**Current experimental source:** the [player playground](../systems/player-control-playground.md)
adds seven human movement presets and a dedicated course. Five mechanical
presets form F5 SetP, bringing the physical catalogue to 46 rigs across eight
sets; dry Sand and liquid Water remain separate native material-field modes.
Acrobat chains, sprung vehicles, damped lander flight and strong barrel torque
use the shared leased physical owner. Circular wheels keep conservative square
native material masks. The material lane relocates bounded local native cells
without repainting or changing Water kernels.

The [original evidence](../audits/2026-10-20-player-control-playground.md) preserves
local Linux execution and desktop builds. The
[PR #189 completion record](../audits/2026-10-21-player-playground-pr189-completion.md)
records original-head hosted success, including actual Windows headless
execution of 107/107 applicable cases. Integration with GEN-003 main and the
quick-tap course-clock correction require combined-source runtimes and fresh
final-head gates. That record owns their status and routes exact final-head
outcomes to PR #189's description and Checks. Physical gamepad/window
interaction, target-PC human feel, complete timed routes and new browser
execution remain separate qualifications. Generic granular, soliding and Water
successor work retains its own gates.

## Exploratory actor integration and physical migration — 2026-10-18

**Current experimental desktop source, ACT-004:** F5 selects all 29 existing
actor identities as articulated Rapier rigs, plus twelve SetX mechanisms, with
keyboard, scripted-demo and external-policy producers. Physical is the default
actor route; sampled references remain explicit choices. Applying restores the
selected map and R retains the actor. Controlled apparatus and Benchmark mode
remain protected. See the [physical actor contract](../systems/physical-actor-rigs.md)
and [programme](../operations/physical-actor-programme.md).

The shared owner provides bounded rotary/slide/spring mechanics, gyro assistance,
compliant play, part-matched polygons, mounts/recoil and held-part lifecycle.
The native coupling budget is 64 body IDs. Physical Thunderbowl v2 is a separate
owner from the retained sampled v1 experiment. Learned policies, global planning,
Windows/browser feel qualification and broad granular acceptance remain outside
this implementation result.

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

**Layered exhibition source, 2026-10-20:**
[Deepworks](../operations/deepworks-exhibition.md) adds one 1024 × 1024
composition with sixteen districts, 32 foreground/rear native exhibits and all
51 MAT-002 building materials. Four independent full-size worlds run at
30/20/15/0 Hz; the true distant background is frozen. Finite reaction sources
preserve products, while the camera/painting viewer supports whole-map reset,
apparatus focus and a guided tour. It does not install an ordinary actor session.
The shared [depth APIs](../systems/depth-layers-and-parallax.md) now admit each
axis from 8 through 1024, including non-square worlds, while preserving Strata
Theatre's 640 × 360 default. Native ABI and material rules are unchanged.
Runtime and actual rendered acceptance remain separately scoped by the
[dated exhibition audit](../audits/2026-10-20-deepworks-exhibition.md).

**Connected scene content, 2026-10-18:**
[Blacksite Nine](../operations/blacksite-nine-demo.md) composes nine 320 × 320
districts into one 960 × 960 native region: a surface laboratory between two
wastelands, above six dense underground industrial districts. Twelve reciprocal
ports and a common final passage carve connect the whole map. Shift+F11 and the
Web demo menu install the complex; the 3×3 map, atlas and following views change
only the camera, while R resets all nine districts together. Its fixed interest
region and world-coordinate presentation preserve continuity without introducing
a streaming subsystem. The [dated scene audit](../audits/2026-10-18-blacksite-nine.md)
owns recipe, runtime and visual evidence; physics programmes retain their gates.

**Scene content, 2026-10-18:** [Neon Reliquary](../operations/neon-reliquary-demo.md)
adds an ornate machine-cathedral demo and the three tiles beneath it: Middle
Cyberberbia, Sewertech Alley and Industrial Underswamp. They use the shared native
MicroScenario host, with desktop/Web entry points, five views per tile, Above/Below
navigation and themed distant scenery. District changes load original layouts.
It is an aesthetic showcase; existing physics programmes retain their own gates.

| Area | Implemented scope and canonical contract |
|---|---|
| Cellular authority and platform owners | Native World; asynchronous desktop GDScript owner, synchronous Web callbacks with optional internal pool; [threading](../architecture/simulation-tick-and-threading.md) |
| Scheduler and storage | Sparse chunks, phased in-place jobs, explicit capacities and activity sleep; [chunk/tile model](../architecture/chunk-tile-and-buffer-model.md), [storage](../systems/world-storage-and-interest-region.md) |
| Procedural generation candidates | Opt-in Strata, Flow Network and District Grammar; theme/brush/override/module recipes plus bounded scalar fields, masked context guidance and aggregate materials; copied chunk proposals and explicit fresh-chunk admission; [generation contract](../systems/procedural-world-generation.md), [field/modifier contract](../systems/procedural-generation-fields-and-modifiers.md) |
| Materials | Bounded adapted kernels, mass-conserving native Water, discrete fallback, secondary interaction lanes; 51 MAT-002 building materials (IDs 81–131) with combustion and 42 versioned pair reactions; [materials](../systems/materials-and-rule-kernels.md), [building catalogue](../systems/building-material-catalogue.md), [Water](../systems/water-design.md). Source/runtime publication and completed-test scope are recorded in the [MAT-002 review](../audits/2026-10-19-mat002-review-and-validation.md). |
| Field storage and events | Optional temperature storage and bounded explosions; no general heat/pressure/wind solver; [field roadmap](../systems/smoke-heat-pressure-roadmap.md) |
| Bodies and character | Main-thread Rapier, 64-ID rectangular native coupling, static terrain packets, 46 articulated [physical actors](../systems/physical-actor-rigs.md), shared keyboard/demo/policy control and usables; SetP circles retain conservative square native masks; sampled and single-hull references remain available |
| Human movement playground | Seven [player presets](../systems/player-control-playground.md), keyboard/gamepad sampler, acrobat chains and separate leased native Sand/Water fields; course checkpoints and focused tests are not human feel or route-completion acceptance |
| Assisted physical free flight | Internal [4LY single-chassis family](../systems/physical-free-flight.md), strict two-output velocity profile, bounded goal-blind assistance and passive revocation; initial Trainer conformance numbers only, with normal selection and differentiated handling owned by 4LY-002 |
| Actor control and battle experiments | Separate physical Thunderbowl v2 plus retained sampled [Thunderbowl v1](../systems/thunderbowl-control-reference.md); physical wire control does not silently inherit sampled metal/NCA/message semantics; trained policies and general actor damage remain Planned |
| Rendering | Immutable native snapshots, copied dirty RG8 patches, full finite GPU texture update and derived material appearance; [bridges](../architecture/rendering-and-gameplay-bridges.md) |
| Persistence | Fixed CYSD1 demo levels; complete resumed replay absent; [save contract](level-saves-and-replay.md) |
| Runtime availability | All 18 required LFS payloads materialized; current execution scope is platform-specific; [build](../operations/local-build-and-validation.md) and [evidence](validation-evidence.md) |

## Procedural generation candidate checkpoint — 2026-10-18

**Current source, GEN-001 / [#163](https://github.com/techrote/cybersand/issues/163):**
three deterministic native candidates share hierarchical theme selections,
weighted blends, spatial brushstrokes, guide paths, fine parameters, hard
overrides and a registry of prepared structure modules. Flow Network and
District Grammar reserve a shared macro route skeleton across independently
requested chunks; explicit hard material overrides can block those routes.
The [canonical generation contract](../systems/procedural-world-generation.md)
owns exact precedence, bounds, identity and module responsibilities.

The opt-in Godot workbench generates and caches copied material previews. Native
`World::install_generated_chunk` supplies a separate exclusive-owner primitive
that accepts only absent storage chunks. A production caller must still bind
results to its current World/reset session before admission. General world
loading, resident-chunk eviction and modified-world persistence remain
**Deferred/Planned in their existing scope**. This source checkpoint does not
claim a merged release or platform acceptance; use the
[dated GEN-001 evidence](../audits/2026-10-18-gen001-procedural-generation.md).

## Procedural fields and aggregate checkpoint — 2026-10-18

**Current source, GEN-002 / [#171](https://github.com/techrote/cybersand/issues/171):**
named fields add finite Hilbert/Morton ranks, structured noise, analytic masks,
scalar sidechains and immutable initial-material/surface/route context. Masked
modifiers guide themes/parameters or carve/paint ordinary materials and aggregate
mixtures; registered feature instances accept the same application/exclusion
controls. The workbench edits these recipes and previews paced diagnostic masks.
The [field/modifier contract](../systems/procedural-generation-fields-and-modifiers.md)
owns finite-curve scope, fixed context, hard/exclusion authority and budgets.

These are generation controls. They do not add live World sculpting, new material
physics, optional simulation field storage or inter-tile Hilbert connectivity.
Schema remains 1 and generator algorithm identity advances to 2; retained legacy
material hashes cover the three old candidates without the new controls. Exact
source/runtime results and remaining publication/platform gates belong to the
[GEN-002 evidence](../audits/2026-10-18-gen002-fields-and-aggregates.md), independently
of the older GEN-001 checkpoint.

## Typed spatial generation checkpoint — 2026-10-20

**Current source implementation, GEN-003 / [#190](https://github.com/techrote/cybersand/issues/190):**
explicit schema 2 adds signed scalar/distance, vector, exact category and boolean
fields; affine/polar/repeat/warp resampling; analytical finite-difference
derivatives; ternary Peano and bounded Voronoi/Delaunay/Poisson controls; immutable
route/feature geometry; a bounded finite adjacency solver; reusable typed
subgraphs; and absolute-world multiresolution sampling with caller-owned cache.
The [typed contract](../systems/procedural-typed-spatial-fields.md) and
[operator inventory](procedural-spatial-operators.md) own types, units, numerical
qualifications and declared costs. Schema 1 retains generator algorithm 2;
schema 2 uses generator algorithm 3/spatial algorithm 1. Source/runtime execution
and completion remain distinct gates.

The Workbench offers minimal typed JSON authoring, catalogue metadata, raw typed
inspection and executable profiles. This is the native field/interface stage,
not completion of hierarchical places or runtime streaming. The approved order
continues with [GEN-004 #191](https://github.com/techrote/cybersand/issues/191),
[GEN-005 #192](https://github.com/techrote/cybersand/issues/192),
[GEN-007 #193](https://github.com/techrote/cybersand/issues/193), then
[GEN-006 #194](https://github.com/techrote/cybersand/issues/194). GEN-004 reuses
the immutable geometry/assignment interfaces and the existing bounded solver.

## Hierarchical places checkpoint — 2026-10-21

**Current source implementation, GEN-004 / [#191](https://github.com/techrote/cybersand/issues/191):**
schema 3 adds a finite canonical regional hierarchy with stable rule/slot IDs,
bounded candidate placement, exact multiplicities and occupancy ranges,
support/neighbor/family requirements, matched sockets, shared boundary ports,
explicit loops/service trunks and finite-curve structural tours. Geometry exports
feed GEN-003 typed fields; the shared finite assignment solver owns district
categories. The existing candidates/modules/masks/aggregates rasterize the
semantic plan and preserve final hard material authority.

The [hierarchy contract](../systems/procedural-hierarchical-generation.md) and
[ADR-013](../decisions/ADR-013-canonical-semantic-generation.md) own semantics and
ownership. The executable four-district profile contains cross-chunk foundries,
rooms, apparatus and nested detail. Copied inspection exposes semantic ancestry,
constraints, field inputs and material contributions. Final raster route reports
qualify an explicit floating-square clearance profile; they do not establish
actor/controller or gravity traversal. Source/runtime acceptance is separately
recorded in the [GEN-004 audit](../audits/2026-10-21-gen004-hierarchical-generation.md).

This stage adds no persistent resident-world streaming, automatic player-edit
reconciliation or semantic depth projection. The next programme stages remain
GEN-005 → GEN-007 → GEN-006, subject to this issue's explicit acceptance gates.

## Semantic depth checkpoint — 2026-10-21

**Current source implementation, GEN-005 / [#192](https://github.com/techrote/cybersand/issues/192):**
[one semantic hierarchy projects into four planes](../systems/procedural-semantic-planes.md)
with explicit geometry, per-plane material intent and omissions, six typed link
families, finite source/drain/setup fixtures, copied provenance and optional
play-only actor placements. Native output is private until complete; the existing
depth owner stages all four Worlds and existing sampled actor owner before one
configuration commit. Camera/parallax never enters generation.

The two executable [refinery/cavern examples](../operations/semantic-depth-authoring.md)
cover four canonical regions and multiple negative-coordinate chunks. Runtime
authority is limited to existing play-to-rear blast and rear-to-effects burst;
background remains frozen. Identical bundle retries are idempotent and old
observations/revisions cannot replay into a new generation. Native reaction
controls measure actual transport/products and complete fixture application counts.

The [dated evidence](../audits/2026-10-21-gen005-semantic-planes.md) and
implementation PR separately record final native/sanitized, Godot/rendered,
Linux/Windows runtime publication and hosted acceptance. Pending gates do not
count as passes. GEN-007 #193 is the next authoring/quality stage after acceptance;
GEN-006 #194 retains persistent streaming and durable mutation reconciliation.

## Decisions and defects to resolve

Rows distinguish **Current fixes**, remaining defects and open decisions; dated
evidence defines each fix's platform acceptance.

| ID | Precise uncertainty or contradiction | Next bounded check/decision |
|---|---|---|
| F01 — failed ticks | Current fix: latch failed World, distinguish attempted/completed ticks, suppress partial publication, stop desktop/Web owners; explicit reset/validated replacement, no replay/rollback | Windows/native acceptance and browser limits: [issue #1 evidence](../audits/2026-09-08-issue-1-failed-ticks.md); [tick contract](../architecture/simulation-tick-and-threading.md) |
| F02 — region re-entry | Current fix: phased exclusion retains activity/quiet state; new core coverage wakes resident blocks once without catch-up. Serial still ignores the region | Separate and combined acceptance: [issue #2 evidence](../audits/2026-09-08-issue-2-interest-regions.md); [storage](../systems/world-storage-and-interest-region.md). Future field/streaming semantics remain open |
| F03 — tick ownership | Desktop moves character before cells with async Rapier samples; Web moves character after cells and gates on terrain backlog | Decide which ordering differences are acceptable before a common physics/replay contract; [threading](../architecture/simulation-tick-and-threading.md) |
| F04 — delayed rules and sleep | Current MAT-001 fix retains future compact-pair and Ice reaction opportunities across sleep and wakes the center block on body-mask changes; other specialized waiting paths remain material-specific | [Scoped #158 evidence](../audits/2026-10-18-mat001-material-reaction-progress.md), [materials](../systems/materials-and-rule-kernels.md); characterize further lifecycle/feel changes separately rather than claiming every material is accepted |
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
a user-facing material-presentation quality tier with weaker-GPU and browser cost
measurement ([effects register](material-effects-register.md#planned));
remaining platform/LeakSanitizer and production performance acceptance. Current
Linux native ASan/UBSan/TSan results are in the validation ledger.

**Deferred:** asynchronous Web simulation/render ownership, general streamed
world loading/eviction, and GPU/coarse/hex experiments. Opt-in procedural chunk
generation now has the bounded candidate scope described above; it does not
supply a resident-world streaming manager. Active-only buffering is a **Planned candidate**
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

## PCHAR-001 player representation checkpoint

**Current experiment:** issue #137 under parent #132 introduces a fresh-reset
choice between the historical sampled character and a barrel/Rapier player using
the existing body-0 rectangle. The sampled baseline now measures its bounded
upward-first runtime enclosure recovery; an optional sampled-burial-safe mode
retains explicit invalid-spawn repair while refusing runtime actor reordering.

The barrel candidate keeps native cells as material authority and main-thread
Rapier as body authority. Horizontal movement is a bounded additive impulse after
cellular reaction, with no vertical velocity assignment and no generic
body↔granular semantic change. #83 remains the production body-envelope owner and
#132 remains open for later representation experiments and selection.

## PENV-001 player/environment tuning checkpoint

**Current implementation candidate:** sampled-player gravity, terminal speed,
effective mass, jetpack acceleration/rise limit, granular/liquid response identity
and step/knee/clamber traversal are explicit versioned profile inputs. The
exact-current preset reproduces the pre-PENV values and one-pixel step envelope;
an Earth-feel owner-tuning candidate doubles gravity only.

Profile changes pause and use the current fresh-reset owner boundary. After
PCHAR-001 merged as `5e53178ba083a0ccd10933cd404395fdbd7dc2b3`,
ordinary barrel/sample selection and sampled burial-safe recovery remain intact.
Tower, Water and ordinary registered MicroScenarios still force PCHAR's
sampled-baseline identity; PLAY-VAL-001 / #139 adds only three explicitly named
experimental REM-003 arms for matched sampled-baseline, sampled-burial-safe and
barrel/Rapier owner review. The desktop exposes active values and REC-001 retains
the resolved profile with exact render-generation evidence.

Granular response reuses the existing REM-003 C1 hook with separate mass and
sensitivity multipliers. Liquid sensitivity is inspectable/captured only; Water
and generic-body semantics are unchanged. Parent #133 remains the long-lived
programme for later environment/player tuning after finite child #138.

## Provisional actor control checkpoint — 2026-10-18

**Current sampled reference implementation, experimental:** ACT-002 / #168 expands the original
ACT-001 trio into 29 [actor rigs](../systems/actor-rigs.md) across SetA/B/F/Y/U/V.
SetA preserves Runner, Skimmer and Crawler plus their original two-button motor
and 16-value observations. The new rigs add independent aim, effort, trim, reel
and auxiliary input, with additive 40-value observations and consumed action/edge
readback. Human, scripted and external-policy producers share admission and motor
capabilities. The canonical rig contract owns each rig's control map and limits.

The experiments include nimble ground traversal, a broad three-legged lunging
robot, tracked/hover/drilling machines, unusual flight/descent, adhesion, ropes,
bounded recoil and six salvage-tool designs. SetV's seven named interface personas
are explicitly fictional designs, not real model preference or capability claims.
F5 compares the selected set through a fresh ordinary-world reset.

New-rig sampled rectangles have bounded conservative rotation/resize queries and
selected local tool effects through existing native cell writes. They do not
replace PENV profiles, select PCHAR's final representation, add articulated rigid
bodies or change generic Rapier/Water authority. Runtime enclosure immobilizes
the rig rather than invoking sampled-baseline runtime relocation.

Neural-network inference/training, larger NPC populations and target-PC
performance/feel acceptance remain future work. A shared command seam or
hand-authored demonstration policy is not evidence of a trained controller.
Registered scientific/control fixtures retain their existing actor identities.
Use the [validation ledger](validation-evidence.md) for scoped execution evidence;
the preserved ACT-001 audit does not automatically validate the additional rigs.

## Physical actor usable checkpoint — 2026-10-19

**Current experimental source, USABLE-002 / ACT-005 / #182:** the
[32-entry equipment catalogue](../systems/actor-usables.md) is reconciled with
ACT-004's physical owner: 12 tools, 10 swept ballistic payloads and 10 processors
retain their U01-U32 identities. Physical loadouts and demonstration strategies
are defined for all 41 actors. The retained sampled equipment route remains a
separate compatibility path.

The physical session binds one actual chassis to an owning part/grip, aims
through configured physical joints, applies matching admitted recoil, and
releases/recovers the same body. The worker receives copied physical source and
part-occupancy information; controllers cannot mutate cells, resources or body
transforms. Equipment epochs, actor control generations, pending-request identity
and issued-observation leases fence stale actions and results. Fixed processors
start from a dropped/settled body and preflight input/output conditions; pickup
and retooling cannot replenish their retained stock history.

The [ACT-005 audit](../audits/2026-10-19-act005-physical-usables.md) owns ongoing
implementation checkpoints, source/runtime identities, recorded failures, actual
regressions and merge status. Current source is not a claim that exact-head hosted
acceptance or owner feel evaluation has already passed. Existing ACT-004,
native/sanitizer, Godot/GDExtension and provenance gates remain applicable.

Committed projectiles and admitted processors outlive a released input, freeze
with simulation pause and clear on fresh actor/World reset. Sampled gameplay
recording retains its equipment state at actor-sample and material-generation
boundaries; this does not establish complete resumed equipment replay.
Health/damage, general inventory/economy, exact chemistry/heat/momentum accounting,
learned policies and Windows/browser interactive qualification remain separate.

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
- [#95](https://github.com/techrote/cybersand/issues/95) synthesis is recorded in
  the [2026-10-23 WEX-005 record](../audits/2026-10-23-wex005-water-evidence-synthesis.md):
  the deep-release deficit is unresolved (on current `main` deep and medium outlets
  deliver identical discharge; sheets untested), and **#45 is NARROW** —
  admission/design only, under shared/vented-atmosphere assumptions, with a
  separately registered surge fixture. No production mechanism is selected.
- The opt-in Liquid Comparison Build pressure lane
  ([#200](https://github.com/techrote/cybersand/issues/200)) is reconciled
  separately by the
  [LCB-000 Gate A record](../audits/2026-10-23-lcb000-gate-a-water-pressure-admission.md).
  [#213](https://github.com/techrote/cybersand/issues/213) is **closed completed;
  Gates A–E PASS**. The [final checkpoint](#liquid-comparison-build-design-checkpoint--2026-10-23)
  records bounded admission; the [#200 policy foundation](#lcb-001-policy-foundation--2026-10-24)
  is the only lifted part of the owner hold on #200/#212.

Water FreeMass and other-liquid CellularYield remain separate; no unification or
production solver change is selected. Equal-level communicating-head fixtures are
vented/shared-pressure controls, not universal sealed-room targets. #18 remains
held pending the resulting evidence rather than by issue-number sequence alone.

## Liquid Comparison Build design checkpoint — 2026-10-23

**Current admission status — 2026-10-24:** LCB-000 [#213](https://github.com/techrote/cybersand/issues/213)
is **closed completed; Gates A–E and integrated LCB-000 PASS**, with no RECHARTER.
The [final landed-stack evidence](https://github.com/techrote/cybersand/issues/213#issuecomment-6377498947)
and subsequent [closure](https://github.com/techrote/cybersand/issues/213#issuecomment-6377517354)
supersede the earlier pending-admission status without rewriting those dated records.

| Gate | Accepted scope |
|---|---|
| A — PASS | Separate experimental Water lane; production Water/WEX limits retained. |
| B — PASS | Bounded reversible storage design; no representation winner or schema/ABI freeze; #204 is not complete. |
| C — PASS | [Solver-family policy design](../architecture/liquid-solver-family-policy.md) and source-derived capability matrix. |
| D — PASS | [Bounded Water comparison contract and protected fixtures](../operations/lcb-water-comparison-and-fixtures.md). |
| E — PASS | Independently closed I1/P2 and listed P3; reviewed integrated apparatus landed with passing post-merge CI. |

**Current landed checkpoint:** #215 → #217 → #226 merged to main
`e95fe85d82e108a682a2ae0212d85569f1c03cd8`, whose tree
`fece020ef7fc83faf5cfe3081b018f2647f7e4fe` equals the reviewed #226 head.
Documentation/provenance, Native and GDExtension/Godot post-merge CI passed.
The [dated reconciliation](../audits/2026-10-24-lcb000-landed-status-reconciliation.md)
records exact identities, evidence classes and validation limits.

**Approved bounded admission; solver ports held:** only a separately scoped initial opt-in
[#200](https://github.com/techrote/cybersand/issues/200) start is admitted.
The owner then lifted the hold for the bounded
[#200 policy foundation](#lcb-001-policy-foundation--2026-10-24) only and continues to hold
the #200 pressure backend, every other solver port and [#212](https://github.com/techrote/cybersand/issues/212). This PASS does not admit
#212, a pressure/inertial port, schema/ABI freeze, defaults changes or Rapier
integration. The bounded native policy foundation is **Current** as recorded
below; candidate family-state implementation and kernels remain **Planned**. #201/#202/#203 remain open; the scenario apparatus delivered part of
#202, not the complete comparison host or its [manual UX](../operations/lcb-manual-comparison-ux.md).

**Current apparatus:** the [LCB scenario catalogue](../operations/lcb-scenario-catalogue.md)
contains 25 scenarios plus the protected Dam Break and mixed fixtures, with
Current-default controls. Water is the only `freemass_v1` liquid; ten liquids
use `cellular_yield_v1`. The mixed control runs two families; three-family World
execution remains blocked. All **90 candidate arms remain blocked**.
Controls and v2–v6 records are preserved byte-for-byte; v7 retains
**20 closed / 4 unverified source-sink timing / 3 unverified reaction amount**,
with `changed_from_v6=[]`. Characterization and contract-model evidence do not
establish candidate runtime acceptance or change defaults.

## LCB-001 policy foundation — 2026-10-24

**Current on main:** [PR #239](https://github.com/techrote/cybersand/pull/239)
landed as `1e032e492cafb232e604baf6e2b823b13d779aa8` on 2026-10-24, from
source `cc01899331bf3010a2a9a98f1e7450e4f1cfc4be`.
The owner lifted the #200 hold for this bounded foundation only. It implements the
accepted Gate C policy object, not a solver: validation precedence, canonical
SHA-256 identity, normalized readback and transactional construction for the
running build, which **admits only each liquid's current default** and refuses
every candidate mapping before any World is built. Defaults, dispatch, C64-E8,
kernels and goldens are unchanged. See the
[native foundation contract](../architecture/liquid-solver-family-policy.md#native-policy-foundation-current-2026-10-24)
and [dated evidence](../audits/2026-10-24-issue-200-policy-foundation.md).

| Item | Status |
|---|---|
| Native policy, wire decode, refusal codes, hash, World admission, experimental C API, GDExtension receipt/validation/construction, MicroScenario request, worker receipt | Current (main; PR #239) |
| NC-1, NC-2 and NC-10 | Executable in the foundation regressions; the LCB registry is unchanged |
| Pressure backend, W-CY/W-IN kernels, run receipt hash, normalization, physical-state hash, remaining #202 constructors, durable schema/ABI freeze | Planned, held or deferred |
| #212, #201, #202, #203 and all 90 candidate arms | Unchanged: held or blocked |

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

## Combined desktop features and physical actor trial — 2026-10-18

The [physical actor programme](../operations/physical-actor-programme.md) retains the initial barrel/Ripper comparison and owner notes. The [ACT-004 contract](../systems/physical-actor-rigs.md) now owns articulation, shared physical control and usable attachments. Broad granular acceptance remains separate; owner observations and scripted fixture results are distinct forms of evidence.

## Strata Theatre integration — 2026-10-18

The opt-in [depth prototype](../systems/depth-layers-and-parallax.md) supplies four native material worlds and five compositor modes. It remains a synchronous comparison host, separate from ordinary asynchronous gameplay; production layering, immutable native-event forwarding, persistence and browser qualification remain Planned.
