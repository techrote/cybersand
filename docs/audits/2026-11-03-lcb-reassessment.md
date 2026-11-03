---
title: LCB-REASSESS current-main liquid capability and comparison handover
status: Current
document-kind: audit
scope: Issue 359 source audit of main 89020b9e, retained platform and worker evidence, parked-PR reconciliation, and bounded prospective handovers for issues 360-363; no new runtime or human acceptance
canonical-for: []
last-reviewed: 2026-11-03
related-documents: [../architecture/liquid-solver-family-policy.md, ../architecture/inertial-cellular-v1.md, ../architecture/pressure-flow-v1.md, ../architecture/pressure-optimization.md, ../operations/lcb-manual-comparison-ux.md, ../operations/lcb-scenario-catalogue.md, ../systems/player-control-playground.md, ../reference/status-and-roadmap.md]
---

# LCB-REASSESS — 3 November 2026

## Finding and scope

**All four liquid families already exist on main and are selectable through the
ordinary native-backed application.** The shared desktop PLAY host also constructs,
advances and resets all eight liquid presets with real native and Rapier owners.
What remains is a fair, recorded comparison of their liquid behavior and full
host cost, plus specific tool/contact capabilities. Another solver implementation,
selector or desktop simulation owner is unnecessary.

The smallest successor is to connect the existing prepared-session controls,
versioned fixtures, actual task-participation observations and retained scientific
accounting into seven bounded comparisons. Reconcile the unique work in parked
#258/#259 before duplicating it. Use the already admitted shared PLAY route when
possible; arbitrary default-sandbox actor retention remains a separate #260 delta.
No preferred solver, production migration, full LCB release or human acceptance
is selected by this audit.

### Contents

- [Source authority](#source-authority-and-live-work): exact inspected source, runtime identities and merged/parked ownership.
- [Capability inventory](#implementation-and-capability-inventory): all material assignments, state, quantity, radius and persistence.
- [Inertial mechanism](#inertial-leaks-voids-and-upward-spray): what retained motion, apparent bubbles and impact relocation actually do.
- [Application readiness](#normal-application-and-host-readiness): existing controls, actor routes, refusals and lifecycle evidence.
- [Workers and evidence](#multithreaded-execution-and-existing-evidence): actual participation, platform scope, cost and unknowns.
- [Reuse map](#feature-and-infrastructure-reuse-map): preserve, reconcile, extend or defer each component.
- [Comparison registration](#minimal-comparison-registration): seven scenarios, fairness, metrics, provenance and stop conditions.
- [Risks and successors](#engineering-risks-and-successor-handover): dependency-ordered tasks and explicit source ownership.
- [Post-audit status update](#post-audit-current-main-status-update-2026-11-03): main `070c7a22` (#334 merged), live ownership recheck, file-overlap register and count clarifications; **not** a re-inspection of source.
- [Audit validation](#documentation-validation-and-review): checks of this documentation change and their limits.

## Source authority and live work

The 3 November GitHub API and remote-ref observations agree on the following;
a final API recheck on3November still returned the same main. PR ownership states
below include the newer #347/#304 heads observed during this audit.

| Input | Exact identity / scope |
|---|---|
| Inspected main | `89020b9eb6d540383a5bb64b58dcd29a87592c32` |
| Main source tree | `79de02472a653a4315149bc5e1970a512e6d74b6` |
| Last main merge | [#332](https://github.com/techrote/cybersand/pull/332), stopped-session recovery; reviewed head `4de225be5a6cb44273bcd1fe581d7e842058ec99` has the same tree |
| Audit branch | `docs/lcb-reassess-359-20261103`; isolated checkout, no inherited implementation delta |
| Retained native build source | `a7ee10f251f647a16dec8a1d7f18c4f299100cba`, render-copy publication [41301725876](https://github.com/techrote/cybersand/actions/runs/41301725876) |
| Windows retained library | SHA-256 `ee09f7ab485f817b5f58e767ddb26f2e430439bb3dd4f185019eda028f47199a`, 4,824,064 bytes |
| Linux retained library | SHA-256 `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45`, 4,222,424 bytes |
| Dependency authority | Existing [Windows manifest](../../godot/addons/cybersand_native/runtime-provenance.json), [Linux manifest](../../godot/addons/cybersand_native/runtime-provenance.linux.json), pinned Godot 4.7 and godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`; no dependency changes |
| Review mode | Native/source/host/test/audit inspection, live PR/workflow metadata, documentation/provenance checks; **no fresh native, Godot, browser or human experiment** |

All source paths in this report refer to that main unless a different commit is
explicitly given. A historical successful run keeps its original source, artifact,
platform and fixture. Current source presence is not a new runtime pass.

| Label | Meaning in this report |
|---|---|
| Implemented / Current | Inspected executable source or configuration |
| Tested | An existing test covers the claim; the evidence row identifies an actual run where one is claimed |
| Source-qualified | A dated execution record binds source/runtime/platform/fixture; its scope is retained |
| Manually accepted | Explicit owner observation; **not established here** for the comparative feel target |
| Experimental | Admitted opt-in behavior with stated limits; does not change Current defaults |
| Planned / Unmeasured | Registered successor work or missing execution evidence |
| Blocked / Deferred | A named admission, identity, capacity or ownership boundary prevents that claim |
| Not implemented | No implementation of the specific capability was found in the inspected paths |

### Merged work that must be consumed

Live issue mirrors #200/#201/#202/#203/#212 remain open. Their old open state
does not mean the following implementation is missing:

| PR | Merged checkpoint | Reusable result |
|---|---|---|
| [#245](https://github.com/techrote/cybersand/pull/245) | `03785c3dcaa5c82df000eeca1471bd6ec698be00` | Corrected Water PressureFlow reference and gas/overfill state |
| [#246](https://github.com/techrote/cybersand/pull/246), [#251](https://github.com/techrote/cybersand/pull/251) | `ec58d919b3d904fbd338eaccc25de35782c41a24`, `d70699b6bcf84480d106f7919e16d6f7038dd114` | Water CY, normalization, prepared native state and receipts; accepted residual #200 contract |
| [#253](https://github.com/techrote/cybersand/pull/253) | `6605112986dd905c1b2ec626030be7067ca07ef0` | Pressure cached/cached_dormant implementation |
| [#250](https://github.com/techrote/cybersand/pull/250) | `dc915f2b2cc1261501058d0e967a98f32ecdee9d` | Brine IN, pressure union and resting contact/gas repairs |
| [#254](https://github.com/techrote/cybersand/pull/254) | `06451f8ac9e8ac9b23a105d2fe22393375dc2d6b` | Whole-cell Water IN, carrier/coherence hooks and pool/activity repair |
| [#256](https://github.com/techrote/cybersand/pull/256) | `56422c050bd5ed2ceb5f816b1269748764e2dcb7` | Native-default/normal application preparation and transactional adoption |
| [#257](https://github.com/techrote/cybersand/pull/257) | `9e53a5b1b501e0667037b8502d3c1d15089211f5` | Transactional barrel/Ripper reconstruction |
| [#285](https://github.com/techrote/cybersand/pull/285) | `1a7f9dd559215bfa66b53e3e029c2bcc641d3f3f` | Native task-participant readback and repeated default-workload measurements |
| Later PLAY integration | `adaaa37ae35ffcdaa961b80353be3a23b805c0cc`, then accepted successors through main | LIFE011 all-eight-preset/five-rig lifecycle; UI007 sampled participation; #332 fresh-owner recovery |

Several canonical pages still contain explicitly dated pre-merge statements.
The current-status additions accompanying this audit supersede their availability
claims, while retaining their original evidence and failure records. In particular,
Water IN is no longer an isolated unavailable candidate; pressure optimizations
are merged; application and Trial integration are merged; and PLAY coverage is
broader than the original two-preset lifecycle checks.

### Parked work and active ownership

| PR / exact observed head | State on 3 November | Unique work and reconciliation boundary |
|---|---|---|
| [#258](https://github.com/techrote/cybersand/pull/258) `fec2c73a33e146c63398849a1d128cf45c0ba59b` | Open, ready, unmerged; conflicts reported | Copied nineteen-field IN ledger, observer availability/qualification. Later PLAY already supplies task counts; reconcile the unique delta against current adapter/observation files. Do not restore its old runtime or publisher request. |
| [#259](https://github.com/techrote/cybersand/pull/259) `513bf479e0c069ce492c9e1b6806a7978ae60461` | Open, ready, unmerged; based on App `56422c05` | Godot-prepared CYPS, native full-resident census and IN ledger consumer, strict reducer, portable Release builder. Three short actor-free precursors are qualified; full-horizon/current-host comparison is not. Three omitted hidden bootstrap files remain a retained-artifact limit. |
| [#260](https://github.com/techrote/cybersand/pull/260) `86f95617d2966f9071e9fe8bdd334ea3888fa5cd` | Open draft, unmerged | Native-default single actor/equipment retention and local IN/skimmer play. Shared PLAY on main can be used without importing this entire delta. Main/worker/prepared-owner edits collide with it. |
| [#261](https://github.com/techrote/cybersand/pull/261) `7880635dae4b1229d286c66df123f102b8f3423a` | Open documentation handover, unmerged | Preserve accepted/parked source and failure history plus historical desktop guide. Its October stop snapshot is not current integration authority. |
| [#347](https://github.com/techrote/cybersand/pull/347) `3ac7701f013452c94a8c08b0746e1b13523e7234` | Active draft structural-detachment work; updated during this audit | Owns structural transfer, contact and conservative displacement; #362 must coordinate before touching those paths. No unmerged behavior is attributed to inspected main. |
| [#334](https://github.com/techrote/cybersand/pull/334) `4f3decc242633fb621d76b7529ef87b420dbd87a` | Open, ready, unmerged PLAY pacing qualification (**superseded after this audit: merged, see [post-audit update](#post-audit-current-main-status-update-2026-11-03)**) | Preserve actual graphical/startup failures and source boundaries. #360 does not change shaders, workflows or its fixtures. |
| [#304](https://github.com/techrote/cybersand/pull/304) `f4f1e3374c89222cb446a77d0cdd0c09c4c1ddc3` | Optional draft; current owner records partial qualification, unmerged | The live PR records authoritative Linux graphical success and Windows failure before native-gate/framebuffer capture; combined workflow remains failed. This is an owner/status record, not a fresh artifact review here. It is not a dependency for #360 or the ordinary PLAY acceptance lanes. |

Live API readback supersedes the old “still running” snapshot: #258 final
Documentation [40247494788](https://github.com/techrote/cybersand/actions/runs/40247494788),
Native [40247494793](https://github.com/techrote/cybersand/actions/runs/40247494793)
and Godot [40247494969](https://github.com/techrote/cybersand/actions/runs/40247494969)
are completed/success. #259 Documentation
[40245503126](https://github.com/techrote/cybersand/actions/runs/40245503126),
Native [40245503184](https://github.com/techrote/cybersand/actions/runs/40245503184),
Godot [40245503129](https://github.com/techrote/cybersand/actions/runs/40245503129)
and scoped Release [40245503135](https://github.com/techrote/cybersand/actions/runs/40245503135)
also report success. This is status readback, **not** a fresh independent reduction
of their artifacts or approval of a different integrated source. No old PR is
merged by this audit, and no original programme issue is closed.

## Implementation and capability inventory

### Material × family × variant

Source authority is
[`LiquidPolicyBuild::running()`](../../native/include/cybersand/liquid_solver_policy.hpp),
the [compiled catalogue](../../native/include/cybersand/liquid_policy_catalogue.hpp)
and [source-derived matrix](../reference/liquid-solver-capability-matrix.json).
The matrix's historical design labels/notes are not current merge status;
native qualified cells and variant masks decide admission.

| Material / ID | FreeMass reference | CellularYield reference | PressureFlow reference / cached / cached_dormant | InertialCellular reference |
|---|---|---|---|---|
| Water / 3 | **Current default** | Experimental, admitted | All three experimental variants admitted | Experimental, admitted |
| Brine / 24 | Refused | **Current default** | Refused | Experimental, admitted |
| Lava / 8 | Refused | **Current default** | Refused | Refused |
| Acid / 12 | Refused | **Current default** | Refused | Refused |
| Oil / 16 | Refused | **Current default** | Refused | Refused |
| Paste / 20 | Refused | **Current default** | Refused | Refused |
| Slush / 21 | Refused | **Current default** | Refused | Refused |
| Cement / 30 | Refused | **Current default** | Refused | Refused |
| Toxic Sludge / 32 | Refused | **Current default** | Refused | Not selectable; proposed alternate is not executable |
| Mercury / 33 | Refused | **Current default** | Refused | Refused |
| Molten Glass / 36 | Refused | **Current default** | Refused | Refused |

There are **11 liquid catalogue rows**. The larger descriptor inventory includes
an invalid sentinel; do not infer a twelfth liquid by subtracting metadata counts.
Nonliquids cannot receive a liquid-family assignment. Cached/dormant variants on
FM, CY or IN are refused. Material-specialized chemistry, viscosity and exchange
remain material rules even when transport is called CY.

One immutable applied family/variant governs each material in a World. Supported
mixed examples are FM Water + CY Oil + IN Brine, and PF Water (any admitted variant)
+ CY Oil + IN Brine. Four alternative Water laws require separate/rebuilt Worlds.
The current material matrix permits at most three distinct families simultaneously;
it does not permit two Water authorities in one World.

Native validation also binds optional parameter schemas: pressure family block v1
(`gas_enabled` 0/1 and `atmospheric_head_rows` 16…4096, defaults 1/32);
Water-CY material block v2 (`viscosity_index` 0…255); IN family block v2
(`damping_numerator` 0…16 over denominator 16, default 1). Unsupported versions,
parameters, materials and execution geometry refuse before replacing the live
owner. The older illustrative IN parameter block is not the running schema.

### Physical state, radius and memory

Sources: [World storage/dispatch](../../native/src/world.cpp),
[World configuration](../../native/include/cybersand/world.hpp),
[IN state/law](../../native/include/cybersand/inertial_cellular.hpp),
[pressure state](../../native/include/cybersand/pressure_flow.hpp), and the
[optimization contract](../architecture/pressure-optimization.md).

| Family | Quantity and physical state | Complete World radius | Incremental storage |
|---|---|---|---|
| FM | Water's integer fractional-cell quantity, coherence/material/temperature state; fractional redistribution | Normal/minimum complete World radius 2 | No PF/IN sidecar |
| CY | Whole cells; Water-CY requires `state_a == maximum()`; other liquids retain their own material state/chemistry | 2 | No PF/IN sidecar |
| PF | Visible Water quanta + hidden overfill; signed **horizontal** flow; Empty-cell gas labels and World compartment/ledger state | 2 | Per resident cell: physical tuple 8 B + head 4 B + visit 4 B; cached adds base-head 4 B; dormant adds certificate 1 B, plus World scratch |
| IN | Whole Water/Brine cells with persistent signed horizontal/downward velocity and subcell accumulators | **3**, explicitly selected; observed read 3/write 2 | Dense 6 B slot per resident cell whenever any material selects IN, plus owners/job ledger/World state |

The common World includes rules reaching radius 2, even where a particular liquid
descriptor lists a smaller write radius. An IN candidate at radius 2 is refused;
neither policy validation nor UI selection silently expands the protected Current
control. Default geometry is chunk 128, core 64, activity block 32; even-core and
radius/core separation checks remain authoritative.

IN's 128² chunk array is 98,304 B (96 KiB). A fully resident 1024² rectangle
requires 6,291,456 B (6 MiB) of IN slots; 2048² requires 24 MiB. These are
**resident-area**, not wet-cell, costs; halo chunks and simultaneous prepared
candidates increase allocation. PF array payload at 128² is 256 KiB reference,
320 KiB cached and 336 KiB cached+dormant. These sums exclude vector/owner padding,
allocator bookkeeping, C64 cells, temperatures, scheduler scratch, snapshots and
process RSS. A PF-Water/IN-Brine World pays both sidecars.

Pressure also reserves bounded global topology/index scratch. Capacity includes
1,024 compartments, a 16,384-cell sealed-volume threshold and 64 retirement records;
cache gas-member storage can reserve 1,048,576 members (8 MiB logical payload).
Report measured capacity and component/RSS values instead of presenting the
per-cell sums as total memory. Reference pressure preparation is serial owner
work over resident state; workers do not parallelize that entire cost.

### Conservation, ingress and persistence

[`world_quantity.inc`](../../native/src/world_quantity.inc) owns exact native
quantity accounting. Water's precision is 3…8 bits, ordinarily 8
(`maximum() == 255`); other-liquid populations are whole-cell counts, not a
universal mass conversion. PF conservation includes invisible overfill, bounded
by `maximum()` and permitted only on saturated Water. Authoritative
census includes stored cells under body masks and outside the active region.
`liquid_mass()` is an occupancy query and is insufficient for that census.

| Operation | Implemented behavior / qualification boundary |
|---|---|
| Painting and ordinary emission | Existing native `emit_disc`/writers insert full Water and follow the selected law on later ticks. Fresh IN paint/products start with zero motion; overwrite retires prior motion explicitly. |
| Fractional Water setup | FM/PF can represent it. CY/IN require full cells or explicit initial `water-normalize-v1`; receipts retain produced/consumed deltas and digest. Normalization is not a conservation-free conversion. |
| Future source actions | A fractional scheduled Water source remains incompatible with CY/IN after initial normalization. Refusal preserves the accepted World/owner/receipt. |
| Sources, sinks, reactions | Native category/rule ledgers distinguish setup, external edits, generated chunks, deferred events, reactions and conversions. Count actual admitted changes; a usable's changed-slot count is not fractional mass. |
| Extraction | Existing whole-cell removal/usable sinks are available. A conserved intake-to-outlet pump with a reservoir is not supplied merely by pairing a drain and emitter. |
| Body displacement | Moves the stored tuple, temperature and PF/IN state through `relocate_stored_cell`/`move_cell`; no invented liquid quantity or new velocity. Blocked displacement preserves payload and reports unresolved overlap. |
| Clear/rebuild/failure | Clear retires sidecars/ledgers. A failed tick quarantines the World; rejected preparation never authorizes retry or replacement. Current PLAY recovery retires the whole failed owner and rebuilds accepted settings. |
| Native physical continuation | Non-IN physical hash/CYPS use version 2; any IN World uses version 3, including actual parameters and motion authority. CYPS additionally persists accounting/diagnostic ledgers. Physical-hash equality does not replace separate IN/pressure ledger checks. Restore validates into a private candidate; ordinary level CYSD is not exact continuation. |
| Hosted save limits | Transient masks affect physical identity but are host-owned and omitted from native saves; Rapier graphs/commands need host reconstruction. Saving with settled discovery is refused. Native CYPS is not complete arbitrary gameplay replay. |

The [physical-state codec](../../native/src/world_pressure.inc) and
[prepared setup contract](../architecture/liquid-prepared-setup-and-receipts.md)
already implement those distinctions. Across different families, physical hashes
are expected to differ. Exact parity belongs to the same admitted model/geometry
at different worker counts; pressure variant comparisons use the declared
variant-normalized projection plus independent quantity/gas/ledger checks.

## Inertial leaks, voids and upward spray

[`world_inertial.inc`](../../native/src/world_inertial.inc) implements a
non-pressure retained-motion law. It performs support checks, one gravity
application, diagonal re-aim/support cancellation and deflection, saturation,
integer damping, collision-checked unit travel, then rest eligibility. Velocity
and accumulators use 16 quanta per cell. The actual limits are `vx = -32…32`,
`vy = 0…32`, `ax/ay = -15…15`; each IN update applies gravity +4 before support
cancellation. Sleeping/inactive cells do not update on every World tick. First blocking
contact ends travel. Water coherence/cadence still gates its purely horizontal
opportunities, and carrying follows the actual Water carrier after a grain swap.

This mechanism can retain lateral flow after a source stops, spill through a
small opening and leave Empty cavities as cells move. Default integer damping
does not guarantee every small lateral velocity decays: truncation can leave a
nonzero tail. A low-damping leak can therefore look persistent without a gas
pressure term. **That is a source-based mechanism explanation, not proof that
the owner's particular remembered scene has been reproduced.**

IN itself has no gas amount, gas compartment, pressure-head or buoyant bubble
operator. Empty-cell cavities, displaced lower-density material and rendering
must be distinguished by material/state captures. PF separately labels Empty
regions and tracks gas creation/absorption/vent/collapse; that state is not
automatically inherited by IN. Brine IN can share a World with Water PF, but
the IN operator still does not consult PF gas head. Water cannot select both.

Negative `vy` is rejected by the IN diagnostic setter, kernel invariant and
physical-state restore. Signed storage is not permission for a signed upward
law. Subcell remainder alone cannot generate an upward unit move within the
admitted ranges. **Current IN does not support genuine upward ballistic liquid
momentum.**

The [native body adapter](../../godot/native_extension/cyber_native_cell_world.cpp)
builds swept occupancy, chooses a bounded ejection destination and calls
`World::relocate_stored_cell`. The stored IN tuple moves unchanged. Response
impulses go to the body coupling channel; body velocity/impulse is not converted
to a new liquid velocity. Resting IN contact feedback is implemented, but it is
not impact-to-liquid momentum injection. Likewise, the native player material
field can relocate/loft Water using bounded deterministic dithering without
storing new per-cell velocity. An upward change in pixel position alone cannot
identify a ballistic mechanism.

Reproduction is feasible with the current IN policy, explicit radius 3 and
existing source/drain/geometry controls. Freeze a bottom-puncture fixture and
record Empty connectivity, native motion and quantity before claiming the
remembered leak/drain behavior or actual bubbles. A directional IN nozzle,
negative-vertical law or sparse flight carrier is a separately versioned design
decision, owned by the bounded successor scopes below.

## Normal application and host readiness

The [comparison panel](../../godot/scripts/liquid_comparison_panel.gd) defines
eight native-admitted presets: Current, Water CY, PF reference, PF cached,
PF cached_dormant, Water IN, PF Water/IN Brine and Current Water/IN Brine.
Per-material choices, IN damping, explicit radius 2/3 and initial normalization
already exist. The panel is embedded in both the liquid-comparison route and the
[shared PLAY selector](../../godot/scripts/playable_session_panel.gd).

| Application route | Available now | Qualification or refusal boundary |
|---|---|---|
| Launcher → Liquid comparison | Existing Main, protected Dam Break, Liquids controls; pause/step/reset, requested/applied identity | Two protected setup choices (Dam and Water/Oil/Brine), not a ready seven-scenario A/B campaign |
| Controlled schema-2 MicroScenario | Native prepared policy/radius/normalization; private candidate and receipt before adoption | Fixed actor-free setup; player/body definitions refuse |
| Shared PLAY session | All eight presets, five mechanical rigs, actual asynchronous owner and Rapier; authored course includes a 60×8 Water pool and Sand | LIFE011 proves construction/progress/reset/refusal/retirement, not comparative liquid census, scaling, display or feel |
| Exploratory MicroScenario / Tower | Existing allowlisted sampled or physical owner preparation; retains authored settings | Controlled mode is not a body-bearing substitute; exact owner/terrain admission still required |
| Water Feel | Existing recipes, sampled player/reference-body preparation, explicit exploratory rebuild | Fractional future sources refuse for CY/IN; blind/unsupported constructors keep their own limits |
| Native-default sandbox | Original native recipe, accepted sampled/reference/Trial-body paths | PF's initial gas-compartment capacity refusal remains; generalized single-actor/equipment retention is parked #260 |
| Curated synchronous demos / Physics Pit / import | Existing explicit selected-policy preparation, private owner and retained restart | Executing the synchronous controller on desktop is not actual browser qualification; physical imports have narrower admission |
| Separate arena, depth planes and generator | Their own existing constructors | They do not automatically inherit Main's policy/worker selection; not required to expand for #360 |

[`main.gd`](../../godot/scripts/main.gd),
[`prepared_level_session.gd`](../../godot/scripts/prepared_level_session.gd) and
[`simulation_worker.gd`](../../godot/scripts/simulation_worker.gd) own those
transactions. Requested, pending and applied states remain distinct. A queued
request is not an applied policy; refusal preserves the old owner and receipt.
Reset uses accepted settings rather than unsubmitted form edits. Accepted #332's
LIFE007/LIFE008 fresh-owner recovery is the reuse boundary for a stopped composed
session; ordinary CYPS capture alone does not reconstruct its Rapier graph.

### Existing usable and source paths

The [usable catalogue](../../godot/scripts/usable_catalog.gd),
[usable runtime](../../godot/scripts/usable_runtime.gd) and
[physical usable adapter](../../godot/scripts/physical_usable_runtime.gd) already
provide Water Lance, Liquid Drain, Water Capsule, Brine Splitter and Steam
Condenser. Lance is aimed line deposition; Drain removes selected liquid cells;
Capsule's ballistic velocity belongs to its projectile before Water deposition.
None establishes a directed fluid momentum inlet. Mechanical PLAY rigs start
with an empty mount, but existing human equipment configuration can select a
catalogue usable. No new actor/equipment owner is needed for a bounded experiment.

The worker prepares body masks before effects/usables and emissions, then ticks
native cells. Preserve lease/generation checks, pause/hold/failure fences, blocked
output and body-mask refusal. Zero-initial-motion full-cell IN emission is already
implemented. A native command accepting liquid velocity and a conserved pump
reservoir are specific missing capabilities, if selected by #361; an emitter
plus a sink is not already such a pump.

## Multithreaded execution and existing evidence

### Three ownership layers and measurement limits

Main owns Godot scene objects, live Rapier bodies, terrain colliders and rendering.
The asynchronous desktop `CyberSimulationWorker` exclusively owns the native
adapter/World and publishes immutable values. Within a native tick, a persistent
pool executes eligible same-phase cell jobs; those pool workers call no Godot
APIs. Main-thread Rapier stepping and owner native ticks have separate timing
boundaries. Web's synchronous native tick path does not acquire desktop's
asynchronous scheduling merely because its build has pthreads.

Native `SerialInPlace` executes on its sole owner and rejects multiple workers.
`Phased` prepares disjoint domains, dispatches eligible jobs, then reduces
effects deterministically. Default parallel job threshold is 8. Radius, core
geometry, active area and sleeping state affect whether multiple jobs are
available. The enumerated `Buffered` backend is not implemented. Serial and
phased are not promised identical trajectories for every scene; phased 1/4
parity is the primary exact worker comparison.

| Existing observation | Meaning and excluded work |
|---|---|
| `get_worker_threads()` | Configured capacity; not actual task participation |
| `worker_threads_observed` | Maximum distinct task-claiming participants in one phase dispatch during the completed tick; nonempty inline phased work reports 1 |
| Serial participant value | Current SerialInPlace leaves the counter at 0: **unmeasured**, not zero execution; preserve #258's availability distinction |
| `phase_jobs_last_tick`, scheduler/active counters | Actual eligible job/work structure; not per-worker CPU utilization or overlap duration |
| `get_simulation_time_ms()` | Complete native `World::tick()`, including native preparation/scheduling/reduction; excludes preceding host body-mask/ejection/usable work, publication, Rapier and display |
| `worker_step_time_ms`, snapshot/publication timing | Existing broader owner and publication observations; boundaries can overlap, so do not blindly add all counters |
| Rapier step/flush and collider budget timing | Existing main-thread physics observations; complete transform packing/mask/coupling attribution is still narrower than a full frame-cost decomposition |
| Main frame interval, snapshot age | Callback/publication timing; headless values do not establish displayed FPS or physical input latency |
| UI007 participation sampling | Existing optional at-most-4-Hz immutable sample with World generation, completed tick, timestamp, phase jobs and collection cost; enabled by expanded HUD plus active PLAY course |

Sources are [native pool/phase dispatch](../../native/src/world.cpp),
[copied observation values](../../godot/native_extension/cyber_observation_values.hpp),
[worker sampling](../../godot/scripts/simulation_worker.gd),
[Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd) and
[snapshot fields](../../godot/scripts/simulation_snapshot.gd).

The participant mechanism is **implemented**; enabling/exporting it for actor-free
comparison is a small integration gap. Full per-tick campaign recording is
different from the 4-Hz HUD sampler. True simultaneous overlap, per-worker
utilization, queue high-water and complete heap-allocation profiles are not
supplied by these counts. Additional timing instrumentation is needed only for
those specifically claimed metrics, not to recreate participant counting.

### Existing evidence inventory

These are retained source-qualified records, inspected during this audit rather
than rerun. “Configured 1/4” never implies observed four.

| Evidence / source | Platform, fixture and actual worker scope | Established result / retained limit |
|---|---|---|
| [LCB catalogue qualification](2026-10-23-lcb003-scenario-qualification.md) | Recorded Windows Current-default controls; 27 fixed scenarios, configured 1/4; CI-reexecuted tick-30 prefix | Canonical definitions/inventory/goldens and prefix parity. Long horizons are author characterization; 117 registered arm classifications are not a four-family campaign. No participant proof from worker configuration. |
| [Brine IN native checkpoint](2026-10-24-lcb005-native-brine-checkpoint.md), damping source `e192af9dd8133b39828cb9e5366e8fd82195055a` | Windows LLVM native, 512² fixture; phased 1/4 with exactly 4 observed task claimants for damping 0/1/16 | Exact physical state/ledger parity, read3/write2 and prepared allocation controls. This is Brine IN, not a full four-Water gameplay comparison. |
| Water-IN [native](2026-10-25-water-inertial-native.md) / [publication](2026-10-25-water-inertial-publication.md), source `aa8af2473a59ab92cc81dfff1dda17be0f41a46d` | Actual Windows/Linux publication [40220697738](https://github.com/techrote/cybersand/actions/runs/40220697738); 15 processes per OS, strict 642-assertion policy proof | Water-specific whole-cell/coherence/carrier/refusal/continuation. Current Water native parity fixtures require observed **more than one**, not necessarily all four, with four configured. Final #254 gates retain their separate source. |
| Water CY / PF native tests | [CY](../../native/tests/test_water_cellular_yield.cpp), [PF](../../native/tests/test_lcb_pressure.cpp), [optimization](../../native/tests/test_pressure_optimization.inc); configured phased 1/4 | Existing quantity/continuation/equivalence coverage. A test without claimant assertions cannot prove four participants; use the associated runtime or benchmark observation separately. |
| [Actual PF Rapier fixture](../../godot/tests/test_liquid_pressure_rapier.gd) | Three PF variants, configured 1/4, 96 ticks, translating/rotating 8×14 body in real independent Rapier spaces | Native quantity/gas and body response/trajectory controls; test explicitly excludes performance and actual worker-count claims. |
| App #256 / Trial #257 | Actual Windows/Linux [App publication](2026-10-25-lcb003-runtime-publication.md) source `5f02d089ee4cff8b34421cc4ca58bb4ef50dd92c`, 36 processes per OS; exact final PR gates separately accepted | Normal constructors, native applied identity and bounded transactional owners. Trial's FM/CY/PF body proof and later IN/PLAY evidence are distinct. |
| [PLAY-AUTO002](2026-10-27-play-auto002-worker-matrix-candidate.md), publication source `d7e35aa3` / run [40651352334](https://github.com/techrote/cybersand/actions/runs/40651352334) | Each actual Windows/Linux host: 50 fresh measurement processes, 6,000 measured ticks; default Sand/Water workloads 480/960; 1/2/4/6/Auto, five balanced repeats | Up to four actual task claimants, fixed per-size terminal hashes; raw total-tick distributions, phases and machine identity. Auto is slower in some repeats despite equal capacity. Separate ordinary course had maximum one job and zero parallel phases. No four-family or gameplay-FPS result. |
| [PLAY-LIFE011](2026-10-31-play-life011-composed-solver-matrix.md), local source `704de34cc2d0bbd12647fc28b11cf7094a963666` | Linux official Godot 4.7, native `496bf3df…`, Rapier `566e68ae…`; 2,955 assertions, 40 policy cohorts, 80 constructed/reset graphs | All eight presets × five mechanical rigs, real native/Rapier progress. Later [accepted-main lineage](2026-10-31-execution-watchdog-modernization.md) includes original successful Native/Godot runs 41204873121/41204873192; do not relabel the earlier local receipt. No per-family claimant/scaling/feel proof. |
| [#259 science apparatus](https://github.com/techrote/cybersand/pull/259), `513bf479e0c069ce492c9e1b6806a7978ae60461` | Independently accepted short Release Windows/Linux scope: three prepared precursors, six configured 1/4 native children per OS, 30 ticks; FM Water, IN Water, mixed FM/CY/IN | Complete resident census and nineteen-field ledger reduction with strict refusal controls. Historical O1 receipts also record actual maxima 1/4. Neither extends to long horizons or Rapier gameplay; three hidden staged bootstrap files were omitted from upload (646 declared / 643 rehashable tracked entries). |
| [Historical Web common-Water](2026-10-25-lcb003-web-common-water.md) | Source-specific body-free 96×96, radius3, 30 ticks, six Water/four mixed arms; compatibility 77 and threaded 76 assertions | Functional terminal proof; worker values 1/6 are configured, not observed claimants. Visible controls/rendering timed out or failed; no current-main browser, body-bearing or human pass. |
| [WEX-001](2026-09-20-issue-91-wex001-water-body-baseline.md) / [REM-002](2026-09-24-rem002-issue11-integration-forensics.md) | Original source-qualified generic Rapier/Water displacement and later hard-boundary controls | Real ejection/free-surface disturbance exists. Historical hard-floor crossing was a defect, not desired splash behavior; retain the repaired no-crossing boundary. |

The current inspected IN and pressure law fragments and policy header have no
changes between the accepted Water-IN head and this main. Broader World/adapter/
host inputs did change. This supports reuse of law evidence with stated scope;
it does **not** relabel old binaries, timings or host results as tests of main.

### Performance and memory evidence

The existing [pressure total-cost harness](../../native/bench/lcb_pressure_optimization.cpp)
and [reducer](../../tools/lcb/pressure_optimization_cost.py) already measure
whole ticks, cold preparation, warm repairs, motion/certificate work, allocations,
declared memory, RSS, actual participants and explicit fallback. The
[pressure evidence record](2026-10-25-lcb002-pressure-variants.md) retains six
profile families, five rotated repeats and configured 1/4 runs. Reference, cached
and cached+dormant share a pressure law; their benefit is workload/source-dependent.
Serial head/gas preparation, invalidations, dormant bookkeeping and ordinary
sleep can dominate differently. A reduction in one kernel counter is not proof
of lower complete tick cost.

The latest retained [packed-source pressure repeat](2026-10-25-water-inertial-native.md#fresh-packed-source-total-cost-repeat)
binds source `c97f68ec6dd5d92aec94c874a6510b16e3a81847`, optimized Windows x64
LLVM-MinGW/Clang binary SHA-256
`2517939e2d3dc2f2c24869c7c7513dafd4753ecc20aade6068b6e3a457e1e3c7`,
18 qualification plus 90 measured children and 23,760 timed ticks. Its
five-replicate median complete-tick ratios are:

| Registered profile | Configured workers | Cached / reference | Cached+dormant / reference |
|---|---:|---:|---:|
| Awake warm | 1 | 0.904676 | 0.356669 |
| Awake warm | 4 | 0.774858 | 0.414603 |
| Disturbed topology churn | 1 | 1.083510 | 1.078905 |
| Disturbed topology churn | 4 | 1.060474 | 1.070289 |
| Forced head fallback, all 88 ticks | 1 | 1.096028 | 1.076441 |
| Forced head fallback, all 88 ticks | 4 | 1.059804 | 1.047144 |

Lower ratios mean faster **on that recorded source/workload/machine**. Awake
configured-four runs reached four actual task claimants; small gas/churn/fallback
cases observed at most one, while sleeping cases could report 0/1/4. Census,
hashes and verification/output were outside the tick timer; body/Rapier/render
cost was absent. The retained campaign recorded 70 tick chunk allocations per arm
and zero temperature allocations, so it is not an allocation-free result.
Reported peak process RSS 13,557,760…21,614,592 B includes apparatus and pools,
and is not a complete solver-memory census. The original external raw packet
and independent reduction hashes remain in the dated record; this audit did
not retrieve and rehash that entire historical packet.

The [Brine memory fixture](2026-10-24-lcb005-native-brine-checkpoint.md) reports
6,291,456 slot bytes for a 1024² resident fixture, only one nonzero slot, 2,048 B
of vector/pointer owners, 622,592 B of job-ledger capacity and, after the parameter
cache, 289 B of declared World components: **6,916,385 declared component bytes**.
Its 12,603,966-byte CYPS3 capture and capture/restore durations have their own
source/ABI scope. This excludes allocator overhead/shared resources/RSS and is
not a portable total-host memory promise.

No inspected record establishes a matched, current-main four-family ranking for
complete desktop native + body-mask/usable + Rapier + publication + rendering
cost, or owner feel. Kernel cost, validation-suite duration and software-rendered
callback rates cannot supply that missing measurement. Existing instrumentation
and raw-receipt patterns are sufficient to start a bounded recorder; fine-grained
phase/coupling/utilization attribution remains explicitly scoped instrumentation.

### Historical negatives to keep visible

Pressure's original moving-mask gas retirement and earlier sparse topology
failures, IN's missing resting contact feedback, Water-IN activity/pool startup
failures, the MSVC test-stack overflow, App/Trial obsolete assertion failures and
#259's compiler/CRLF/path-alias failures all have later bounded repairs. Their
original failed source/runs remain failed. The pressure sealed/narrow-vessel
physical limitations, default-demo gas-capacity refusal, unverified full-host
identity, old Web visual failure and untested human comparison remain limits.
In particular, PF's gravity path does not resist falling Water with gas pressure:
a sealed pocket can collapse with explicit accounting, and same-tick vent/reseal
uses the documented atmospheric reconstruction simplification. Gas bookkeeping
does not establish validated sealed-gas physics.
Do not rerun an old failed source unchanged or reinterpret a negative experiment
as accepted physics.

## Feature and infrastructure reuse map

| Component | Disposition | Concrete reuse / bounded delta |
|---|---|---|
| Four native laws, capability/schema validation, quantity and continuation | **Reuse unchanged** | Existing World dispatch, policy/catalogue, normalization, CYPS2/3, default controls and native tests |
| Comparison picker, parameter/radius controls, private preparation and restart | **Reuse unchanged** | `liquid_comparison_panel.gd`, Main/worker/prepared sessions; extend scenario binding rather than create another host |
| Shared PLAY all-eight lifecycle and recovery | **Reuse unchanged** | LIFE011 plus LIFE007/LIFE008; preserve actual native/Rapier ownership and invalid-input controls |
| Native actual-participant/phase counters and UI007 | **Extend narrowly** | Enable/copy/export existing observations for the selected comparison route; retain generation/tick/availability |
| Godot copied IN cumulative ledger | **Reconcile existing PR #258** | Unique ledger and availability semantics; retain newer PLAY counts and current runtimes |
| Prepared-state native scientific consumer | **Reconcile existing PR #259** | Existing CYPS preparer, native consumer, complete census/ledger reader and source/compiler fences; repair omitted retention bytes and add only registered cases |
| Arbitrary single default-sandbox actor retention | **Reconcile existing PR #260 if needed** | Not required to reuse admitted shared PLAY; coordinate shared Main/worker/preparation ownership |
| Earlier session handover | **Reuse history from #261** | Link exact historical source; this audit supplies current source/CI status, without rewriting its stop record |
| 27 scenarios / 117-arm accounting | **Reuse unchanged** | Protected definitions, signed-ledger reducer and prefix goldens. New comparison capsules/receipts do not rewrite historical measured classifications. |
| Legacy controlled runner | **Extend narrowly** | Add explicit admitted policy/radius/preparation and source-bound recording by consuming existing science work; current runner calls default `diagnostic_reset({workers})` and legacy install |
| Water Feel / MicroScenario recipes | **Reuse and version narrow derivatives** | 35 Water Feel recipes provide release, cavity, constriction and body examples; incompatible fractional future sources need separately named whole-cell fixtures |
| Pressure reference/cache/dormant benchmark | **Reuse unchanged** | Dedicated optimization parity/cost lane; not extra physics-family arms |
| Existing material usables and owner command path | **Reuse unchanged** | Lance/Drain/Capsule/processors, masks, lease/generation/budget/blocked-output checks |
| Directed liquid-momentum inlet / conserved pump | **Missing implementation** | Only if chosen for #361, specify bounded native quantity/state/ledger semantics first |
| Upward ballistic IN motion | **Not implemented; separately gated** | Current negative-`vy` refusal remains. #362 Phase B requires a distinct owner-approved law decision; sparse flight retains #20 gates. |
| Full mapped-module/script/actor scientific binding | **Blocked for a full-match claim** | Existing host evidence deliberately retains false eligibility; use independent executed-source envelopes and state residual gaps |
| Browser, public package, production default and human acceptance | **Deferred / unmeasured** | Not required to restart #203 release scope in this audit; human fields remain UNTESTED |

The [legacy runner](../../godot/tests/lcb_scenario_runner.gd) is native-only,
rejects bodies/players and currently has no selected policy in its install call.
Its statistics omit participant/timing export. This is a current-main integration
gap, not proof that the solver, observer or native scientific consumer must be
written again.

### Exact parked implementation entry points

Use the following immutable PR-head files for reconciliation. They are not files
newly supplied by this audit and their historical documentation may still describe
CI as pending; use the live status ledger above and retained #261 final evidence.
Do not copy old runtime manifests, publication requests or workflow files into
the successor. Reconcile only the unique functionality against current owners.

| Owner / pinned head | Exact reusable code | Preserve or reconcile |
|---|---|---|
| #258 `fec2c73a` | [Adapter implementation](https://github.com/techrote/cybersand/blob/fec2c73a33e146c63398849a1d128cf45c0ba59b/godot/native_extension/cyber_native_cell_world.cpp), corresponding `.hpp`, and [copied observation values](https://github.com/techrote/cybersand/blob/fec2c73a33e146c63398849a1d128cf45c0ba59b/godot/native_extension/cyber_observation_values.hpp) | Copied nineteen-field IN ledger and explicit availability; preserve newer #285 participant fields and current adapter ownership |
| #258 tests | [`test_lcb_inertial_observation.gd`](https://github.com/techrote/cybersand/blob/fec2c73a33e146c63398849a1d128cf45c0ba59b/godot/tests/test_lcb_inertial_observation.gd), `godot/tests/test_native_worker_observation.gd` | Reconcile copied-value/refusal/participant tests with current source; no second worker-count implementation |
| #259 `513bf479` preparation | [`godot/tests/lcb_science_prepare.gd`](https://github.com/techrote/cybersand/blob/513bf479e0c069ce492c9e1b6806a7978ae60461/godot/tests/lcb_science_prepare.gd) | Real schema-2 Godot construction, CYPS precursor, normalization and original/restored host identities |
| #259 native consumer | [`native/bench/lcb_science.cpp`](https://github.com/techrote/cybersand/blob/513bf479e0c069ce492c9e1b6806a7978ae60461/native/bench/lcb_science.cpp) | CYPS restore, full resident census, actions, native tick and separate observation timing; preserve all-slot coverage and refused/incomplete output |
| #259 staging and strict reduction | [`tools/lcb/science_apparatus.py`](https://github.com/techrote/cybersand/blob/513bf479e0c069ce492c9e1b6806a7978ae60461/tools/lcb/science_apparatus.py), `tools/lcb/test_science_apparatus.py` | Exact source/runtime/event/receipt binding, strict integers and independent phase/quantity/IN ledger reduction |
| #259 portable build and qualification | [`build_science_consumer.py`](https://github.com/techrote/cybersand/blob/513bf479e0c069ce492c9e1b6806a7978ae60461/tools/lcb/build_science_consumer.py), [`qualify_science_apparatus.py`](https://github.com/techrote/cybersand/blob/513bf479e0c069ce492c9e1b6806a7978ae60461/tools/lcb/qualify_science_apparatus.py), corresponding `test_build_science_consumer.py` / `test_qualify_science_apparatus.py` | Current-base source/compiler/flags/path validation, bounded child execution and both OS receipts; retain original portability failures |

The [parked apparatus runbook](https://github.com/techrote/cybersand/blob/513bf479e0c069ce492c9e1b6806a7978ae60461/docs/operations/lcb-native-scientific-apparatus.md)
documents `make lcb-science` and
`lcb_science SNAPSHOT.cyps EVENTS.txt WORKERS HORIZON OUTPUT.ndjson`.
Its consumer admits workers1/4, horizon0..4800 and bounded snapshot/event input;
these existing bounds cover the proposed1200-tick capsules. Recover the exact
preparer and builder commands from that source before execution, then pin their
reconciled source and actual inputs. This is an entry-point handover, not a
direction to execute the old branch as a current-main qualification.

## Minimal comparison registration

**Planned for #360–#362, not executed by #359.** Freeze this small contract in a
versioned comparison manifest before collecting results. Existing fixture files,
goldens, scientific negatives and 117 historical classifications stay immutable.
Record new fixture IDs and canonical hashes for any derivative instead of editing
an old fixture to make another family pass.

### Fairness and bounded execution

Use four separately constructed Water configurations: FM reference, CY reference,
PF reference, IN reference. First compare all at radius 3, identical core/chunk
geometry, precision, seed, temperature, active/interest region, cadence, initial
whole-cell Water placement and authorized source/sink schedule. For fractional
historical recipes, either retain them as model-specific controls or create a
new explicit full-cell derivative. Record both raw input and normalized output,
including gross produced/consumed quantities; do not silently normalize only a
candidate and call initial conditions identical.

Keep a separate preferred-configuration control: non-IN at native radius 2,
IN at required radius 3. Do not compare those costs as if scheduler geometry
were matched. The protected Original Current fixture remains untouched at its
original geometry. Do not require cross-family hashes to match. PF
cached/cached_dormant belong in a later reference-equivalence/cost submatrix
using the existing optimization harness, not in the four-family count.

Start with the existing finite dam and quiet-pool constructions at configured
workers 1/4, a 30-tick admission/accounting preflight, on Windows and Linux:
at most **32 initial rows** (2 scenarios × 4 families × 2 capacities × 2 OSes).
Require exact applied policy/geometry, closed quantities and healthy retirement
before the longer stage. Stop at the first violated authority/quantity/boundary
invariant, preserve its packet and assign the existing owner; no brute-force
campaign retries or automatic fallback.

The seven primary scenarios then have at most **112 correctness rows** with one
fixed registered run per family/capacity/OS, plus explicitly named negative
controls. Preserve each reused fixture's original horizon. New leak/drain
capsules below use 1,200 ticks, without extending a slower family after seeing
results. Record incompletion/continued motion at that horizon as an outcome.
For performance, begin with only two predeclared representative profiles
(distributed active liquid and quiet→wake), three rotated repeats each:
48 rows per OS. Keep cold construction/first ticks separate from matched warm
windows. Reuse the existing pressure optimization repeats instead of multiplying
the full seven-scenario matrix by every cache variant.

If a normal small scenario yields one task claimant, report that fact. For a
worker-scaling question use a separately named, bounded distributed workload
with enough disjoint eligible jobs, identical across families. Do not silently
enlarge or change the player scene, reduce the phase threshold or count configured
capacity as a successful parallel workload. Confirm actual native participant
and phase arrays in every measured arm.

### Seven scenarios and reusable infrastructure

| Scenario | Existing fixture or closest infrastructure | Required machine metrics | Qualitative observation / narrow addition |
|---|---|---|---|
| Small leak / puncture | Water Feel slow-release/support-removal recipes; MicroScenario bounded edit schedule; LCB shallow ledge/obstacle examples | Exact initial/remaining/outlet Water, opening/closure time, leakage flux, tail duration, runout, collision refusal, IN vx/ax | Flow continuity and residual motion; add one versioned puncture/closure geometry, not a new solver |
| Bottom drain / apparent bubbles | Water Feel cavity-fill-drain as an ingredient, existing Liquid Drain sink and source ledger | Drain quanta, output/remaining inventory, Empty-region area/connectivity and lifetime, IN motion; PF compartment IDs/amount/volume/gas ledger separately | Cavities/bubble appearance; register actual bottom puncture and a top-vent control. Existing cavity-fill-drain is not assumed geometrically equivalent. |
| Deep dam break / bulk surge | `lcb.dam.water.freemass.depth-48/96/160.v1.json` and protected Dam infrastructure | Front position/arrival, retained upstream quantity, downstream flux, peak surge, total water, tick/phase cost | Bulk surge and lateral persistence; begin depth96, add48/160 only when the preregistered depth discrimination is needed |
| Pipes / constrictions / communicating vessels | `lcb.head.narrow-passage.v1.json`, vented-two-limb and separately sealed-two-limb; Water Feel constriction/U-vessel | Transfer/settling windows, level difference, reverse flow, residual quantity, PF head/gas | Pipe response; label shared-atmosphere and sealed assumptions. Equal levels are not a universal sealed-room requirement. |
| Quiet pool → wake → rest | `lcb.rest.deep-quiet-pool.v1.json`, remote-disturbance/two-pool variants; pressure stationary/sleeping harness | Native tick distribution, active/visited/saved work, certificate/fallback counts, actual claimants, allocation/memory, residual motion | Rest/jitter/wake behavior; ordinary sleeping zero work must be distinguished from pressure certificate savings |
| Source/nozzle/usable flow | Existing Water Lance, Drain, Capsule, processor effects and controlled source schedules | Actual inserted/removed quantities per tick, blocked/exhausted budget, source-stop tail, native state at inlet, owner/lease/refusal | Tool responsiveness and directed appearance; label current aimed deposition versus a separately implemented momentum inlet. Avoid incompatible fractional future events. |
| Rapier impact / displacement | WEX-001 apparatus, `test_liquid_pressure_rapier.gd`, prepared reference bodies and REM-002 hard-boundary tests | Body pose/velocity, contact/impulse, displaced/unresolved cells, masked stored quantity, above-surface amount, destination and IN tuple before/after, cost | Splash/plume/return; #360 records baseline only, #362 owns mechanism discrimination and any later ballistic decision |

Fixture paths above live in
[`godot/tests/fixtures/lcb/scenarios/`](../../godot/tests/fixtures/lcb/scenarios)
and the [Water Feel recipes](../../godot/scripts/water_feel_scenarios.gd).
Use the existing contract parser, action scheduler and source-derived registry.
If a source path or admission has changed, compare the old exact fixture and new
authority before changing the plan.

For the two new geometry capsules, use a 256×256 authored geometry/observation
footprint inside the existing 1024×1024 MicroScenario construction contract
([fixed `SIDE`](../../godot/scripts/microscenario_contract.gd)), with core64,
radius3, E8, fixed seed359, ambient fixture temperature and no initial actor.
This does not introduce a 256-sized World/compiler contract. Record the actual
interest/halo/resident allocation and census all stored cells, including liquid
that leaves the observation footprint. Use a two-cell wall tank with outer half-open bounds
`[64,192) × [48,176)`, internal full-cell Water
`[66,190) × [64,174)`, and a containing floor below the tank.
The side-leak variant opens `[190,192) × [150,152)`; the bottom-drain variant
opens `[128,130) × [174,176)`. Open at tick120, close at600, observe to1200.
Pair a top vent `[128,130) × [48,50)` open/closed control and a no-opening
control. The implementer must register the exact floor, source/action ordering,
initial census and boundary region before first execution. An actual removal
sink is separately tagged and budgeted; crossing the tank opening is internal
transfer until a declared sink removes it. These proposed fixtures claim neither
perfect gas physics nor reproduction of an unspecified historical scene.

### Measurement and provenance contract

Each original result must retain exact commit/tree and dirty-input status;
fixture ID/canonical bytes/hash; seed and material precision; requested/applied
policy, family/variant/parameters, native receipt and setup-normalization identity;
World generation; radius/core/chunk/interest/cadence; configured workers and actual
per-tick participant/phase observations; completed and attempted tick ranges;
source/sink/reaction/control ledger; engine/native/Rapier/compiler identities;
OS/CPU/memory/renderer; command, named watchdog, exit and cleanup result; raw
observations and SHA-256 inventory. Reuse #259's strict integer decoding and
current execution-policy/receipt tooling; never accept booleans/floats as integer
quantity or relabel an unobserved quantity as zero.

Three result dimensions remain separate:

- **Correctness:** full stored Water plus overfill and relevant species/IN/gas
  ledgers; no unexplained source/sink or wall/floor crossing; capacity, mask and
  failure/refusal behavior; exact same-model phased1/4 continuation where
  applicable. Reaction-bearing recipes require the existing signed accounting,
  not a constant-Water assertion.
- **Cost:** complete native tick p50/p95/max, preparation and phase/scheduler
  components where actually measured, owner/coupling/Rapier/publication time,
  snapshot age and graphical callback distributions; allocations and declared
  optional storage versus peak RSS; cold/warm windows and instrument cost.
  Missing component timing is explicitly null/unmeasured. Headless is not GPU FPS.
- **Human feel:** fixed-view, same-speed clips/play sessions with leak realism,
  drain/cavity appearance, persistence, surge, splash, rest, tool usefulness and
  perceived lag recorded separately. Leave ratings/acceptance **UNTESTED** until
  the owner actually reviews them. An appealing picture is not gas or momentum
  proof.

The [host observation collector](../../godot/scripts/liquid_host_evidence.gd)
intentionally retains `host_eligible_for_full_matched_evidence=false` and
unverified mapped-module/script/complete-actor binding. A matching file path/hash
does not prove that exact library/script was loaded. Build an independent
source-bound execution envelope from existing qualification tooling, state the
remaining binding limits, and do not flip that flag to make a report acceptable.
Do not claim full #203 host/release closure from bounded source-qualified results.

Stop an arm for unsupported mapping/geometry/fractional ingress, gas or storage
capacity refusal, quarantine, missing/mismatched source/runtime, incomplete
quantity/census, wall crossing, leaked owner, or missing expected receipt.
An arm with no parallel dispatch is **measured nonparticipation**, not a physics
failure; it cannot support scaling claims. A slow or censored arm remains in
the result set. Use the existing named execution watchdogs and preserve original
timeouts; changing measurement horizons or failure thresholds after results
requires a new registration, not an amended pass.

## Engineering risks and successor handover

### Prioritized risks

| Priority | Risk and implication | Bounded treatment / owner |
|---|---|---|
| P0 — scientific validity | Old availability prose, configured workers, partial census or native file identity can be mistaken for complete comparable execution | #360 consumes this source/evidence table; preserve full-match false, actual claimants, normalization and source scopes |
| P0 — material safety | Fractional ingress, PF hidden overfill, masked cells and usable slot counts can invalidate conservation | Use native complete quantity/census and existing refusal/ledger contracts; #258/#259 reconciliation before new accounting |
| P0 — contact/ownership | New ejection or momentum code could bypass REM-002 or collide with #347 structural ownership | #362 Phase A initially observes existing paths; coordinate any shared adapter/bridge change, preserve no-crossing and stored payload |
| P1 — runtime integration | Parked observer/science/actor work predates current Main/worker/render recovery; old DLLs would erase newer source | Select narrow deltas, rebuild/requalify changed compiled inputs on the actual result; no old publisher/runtime overwrite |
| P1 — scaling/cost | Small scenes have too few jobs; PF serial preparation and IN policy-wide memory may dominate | Use matched radius, record jobs/claimants and total tick/host cost; report representative small scene and separate distributed scaling profile |
| P1 — physical interpretation | Void appearance, upward relocation, projectile motion and PF redistribution can be miscalled gas buoyancy or ballistic IN | Capture material/motion/gas mechanism; keep current negative-vy refusal and conditional law decision |
| P2 — product acceptance | Headless/Linux/functionality evidence can be promoted to visible Web, actual display or human feel | Separate Windows/Linux execution, graphical captures and owner assessment; browser/release scope remains deferred |

### Shared prerequisite and parallel ownership

One integration owner should establish the chosen current-main comparison source,
fixture IDs, quantity units, receipt schema and observation/export seam for #360.
Reconcile the unique #258 ledger and #259 scientific consumer work there if used;
consume existing PLAY participant code. #260 is conditional on needing its
specific native-default actor-retention behavior, not a mandatory prerequisite
for shared PLAY comparison.

After that small common contract is fixed, #361 can author/qualify its tool
capsules while #362 develops read-only impact fixtures and mechanism analysis.
Give them distinct fixture/test/report files. Main, worker, native observation,
prepared ownership and rigid-body coupling remain shared files with one active
owner; proposals touching them must be sequenced. #347 owns structural
contact/displacement; #334/#304 own their PLAY graphical/diagnostic work.
#363 joins reviewed evidence from the three lanes. None of these tasks implicitly
finishes #200–#203/#212 or resumes the old release mandate.

### #360 — LCB-FEEL

**Reuse:** comparison/PLAY panels, Main prepared adoption, LIFE011/LIFE007/LIFE008,
fixture parser/catalogue, current native observation and worker benchmark patterns;
#258 copied IN ledger and #259 science consumer where needed.

**Implement only:** one visible versioned scenario selector/recorder/export path
for the seven capsules, enabling existing participant observations outside the
PLAY-only HUD gate; explicit source/policy/radius/normalization identity; bounded
per-tick native/owner/Rapier/publication data and separate fixed-view captures.
Wire admitted policy setup into controlled execution by reusing prepared state.
Add only missing measurement boundaries needed for claimed metrics. Keep the
Current control and old registry results unchanged.

**Acceptance:** first the 32-row short preflight; then registered seven-scenario
correctness and limited repeated cost cohort on actual Windows/Linux at the
resulting source. Record genuine claimant counts, complete quantity, same-model
worker parity, constructor/reset/refusal/retirement, raw records and independent
readback. Reuse existing applicable native/sanitizer/Godot gates for changed
implementation. Owner feel remains a separate packet. A family-specific
admission/capacity failure is recorded and routed, not replaced by default Water.

**Dependency/stop:** baseline #359 inventory; reconcile live #258/#259/#260 and
PLAY owners before shared-file edits. Stop at an unqualified source/runtime,
accounting or ownership boundary; do not require a new full browser/release
programme to complete a desktop comparison.

### #361 — IN-TOOLS

**Reuse:** Water/Brine IN admission, radius3/full-cell setup, existing geometry
edits, Water Lance/Drain/Capsule and physical usable adapters, worker command
queue, equipment configuration, native quantity ledger and shared #360 recorder.

**Implement only:** opt-in leak and actual bottom-drain capsules with reversible
opening and authorized sink accounting, plus one existing usable path. First
qualify zero-initial-motion whole-cell sources. If a directed nozzle is necessary,
write the small native ingress contract before code: eligible material, admitted
vx/vy/accumulators, quantity, blocked/capacity behavior, external momentum ledger,
phase ownership, receipt and save/reset semantics. Stay within current
nonnegative-vy law unless a distinct law change is authorized. An intake-reservoir
pump is optional separate scope, not assumed existing.

**Acceptance:** fixed openings/vent controls, source stop/tail, Empty connectivity,
exact source/sink closure for Water and Brine, body-mask/wall refusal, exhaustion,
1/4 parity and actual participants where asserted; shared Main/native/Rapier
smoke, lease/pause/reset/failure retirement on both target OSes. Preserve Current
FM controls. Slot counts and aimed deposition cannot substitute for mass or
momentum evidence. Ask the owner to assess the recorded leak/drain behavior.

**Dependency/stop:** share policy/fixture/recording authority with #360; reuse
#258/#259 accounting rather than a competing ledger. #260 only if its exact actor
retention route is needed. Do not edit #347 coupling, introduce gas physics or
reinterpret incompatible fractional schedules.

### #362 — WATER-CONTACT

**Reuse:** WEX-001 original apparatus/evidence, REM-002 hard-boundary regressions,
actual PF Rapier fixture, prepared reference bodies, current mask/displacement
observations and #360 source/quantity/participant recorder.

**Phase A:** compare four separate Water policies at matched radius3 with identical
body/shape/input state and stored quantity; retain preferred-radius FM separately.
Register shallow/deep, low/high speed, off-centre/rotated and no-body/no-Water
controls only as needed for a defined discrimination. First establish state
relocation with a bounded identifiable/single-cell probe: inspect the IN tuple
before and immediately after `prepare_rigid_body_coupling`, before the next tick,
using existing `inspect_inertial_cell` and a bounded stored-cell census. Aggregate
WEX contacts/displaced/unresolved counters do not identify every cell's ejection
destination. If a multi-cell correspondence trace is necessary, register that
narrow read-only instrumentation under the coupling owner before implementation.
Record contact/displaced/unresolved counts, body pose/impulse, stored quantity,
above-surface mass, peak height/range
and return. Preserve floor/wall and foreign-mask constraints. Label spatial
relocation, later native transport, PF pressure response, visuals and actual
stored momentum separately.

**Acceptance:** actual Windows/Linux native/Rapier records, closed quantity,
same-policy worker controls, real participant/phase readback and independent
mechanism review. The phase may conclude “upward ballistic IN absent” without
implementing a spray feature.

**Conditional Phase B:** only after a concrete gap and separate owner authorization,
compare a versioned contact-derived IN momentum/law extension, gated sparse flight
under #20, or explicitly nonphysical presentation. Upward IN requires revisiting
velocity domain, collision/gravity/rest, external momentum accounting, radius,
hash/codec identity and deterministic worker tests. No implicit change to
`inertial_cellular_v1/reference`, per-cell Rapier bodies or hidden liquid creation.

**Dependency/stop:** coordinate shared coupling with #281/#347 and #12; a shared
source conflict is a stop/sequence boundary. Do not treat structural-detachment
qualification as generic liquid impact acceptance or repair its contact law here.

### #363 — LCB-DECIDE

**Reuse:** the admitted material/family matrix and reviewed #360/#361/#362 packets,
including retained negative/censored runs, source/platform limits and owner ratings.

**Deliver only:** a compact source-qualified profile decision/ADR proposal per
material and use case: retain Current, supported opt-in, experimental/restricted,
further study or no-go. Weigh authoritative quantity/containment/stability first,
measured native/host/memory cost separately, and actual owner feel separately.
Declare missing evidence and prospective budgets; do not adjust thresholds
retroactively or force a winner. Pressure cache/dormant choices remain within PF.

**Acceptance:** independently reviewed trace from every recommendation to a tested
fixture/source/runtime and, for feel claims, owner observation. An insufficient-data
or defer disposition is valid. Any future default, fluid law, Web release, #45
pressure or #20 flight change needs a separately authorized implementation.
No parent LCB issue closes automatically.

## Post-audit current-main status update (2026-11-03)

**Added after the audit above; everything above still describes main
`89020b9e…`.** This section records a later documentation review. It did not
re-inspect, rebuild or rerun native, Godot, browser or human evidence, and it
does not turn any original observation into a result at the newer main.

### Newer main and #334

| Item | Observation |
|---|---|
| Current main | `070c7a22ad51ea9206931cd9d56fd1e7cfe212aa`, tree `2c10df4c03c0495051d8d7c9e48d580803b185fe` |
| Change since audit source | Only [#334](https://github.com/techrote/cybersand/pull/334) (merged 2026-11-03T21:55:12Z; head `9c90fb5dd1e9cd2903daec7fd87c39d25ead911d`). The 15 added files are the PACE004 workflow, its `godot/tests/*pace004*` fixtures, `tools/play/*pace004*` helpers/tests, one PACE004 audit and one local six-graphical receipt. |
| LCB-relevant delta | **None.** No change to native sources, solver policy, materials, `godot/scripts`, the native extension, runtime libraries/provenance, LCB tooling or the fourteen paths of this review. The capability, mechanism and cost analysis above is unaffected. |
| Ownership consequence | The #334 row in the live-work table is historical: PACE004 is no longer an open PR. Its merged audit remains `Planned` for one complete exact-head hosted campaign, so PACE004 is still a PLAY pacing qualification lane, not an LCB input. #360 still does not change shaders, workflows or PACE004 fixtures. #304 remains the separate optional draft. |
| Reusable instrumentation | `godot/tests/play_pace004_worker_probe.gd` is a fixture-only copied-native-row observer of the production owner. It adds no production participation counter, so the gap noted for #360 (exporting existing task-participant observations outside the PLAY-only HUD) is unchanged. |
| Integration | The audit branch and main change disjoint paths; a trial merge needs no resolution. The hosted result recorded for the branch head predates the merge and does not cover the merged result. |

### Live ownership recheck

The exact heads of #258 `fec2c73a`, #259 `513bf479`, #260 `86f95617`, #261
`7880635d` and #347 `3ac7701f` were unchanged at this recheck; all remain open
and unmerged. #304 was `f4f1e337` at the recheck but advanced to
`f6d960798d3a6c2190867ae8a56e23f583286952` (pushed 22:41 UTC, after the #334
merge); the audit table's #304 head is therefore historical. A local trial merge
of each parked head with main `070c7a22` reports conflicts, a **broader** result
than the audit's “#258 conflicts reported”; GitHub's own mergeability, `UNKNOWN`
at the recheck, later reported `CONFLICTING` for all four:

| Head | Conflicted paths |
|---|---|
| #258 | `cyber_observation_values.hpp`, both runtime libraries and both provenance manifests, plus five documentation paths |
| #259 | `Makefile` plus eight documentation/retrieval paths |
| #260 | Six documentation/retrieval paths only; `main.gd` and `simulation_worker.gd` combine textually, which is not behavioral compatibility |
| #261 | Three documentation/retrieval paths (handover, retrieval corpus and index); the audit's documentation-only handover is not a source dependency |

Binary runtimes and provenance must never be resolved from an old head. Every
reconciliation of #258/#259/#260 starts from a fresh current-main branch and
selects the unique functions listed in the entry-point table. This changes
no disposition: none is merged by this audit.

### Open-PR file-overlap register

Observed from the PR file lists on 3 November; unmerged behavior is not
attributed to main.

| PR / area | Shared paths relevant to #360–#362 |
|---|---|
| [#347](https://github.com/techrote/cybersand/pull/347) SOL-DETACH | `cyber_native_cell_world.cpp/.hpp`, `rapier_physics_bridge.gd`, `simulation_snapshot.gd`, `simulation_worker.gd`, runtime libraries/provenance, and shared status/handover/retrieval documents. Owns structural contact and conservative displacement. |
| [#349](https://github.com/techrote/cybersand/pull/349), [#350](https://github.com/techrote/cybersand/pull/350), [#351](https://github.com/techrote/cybersand/pull/351) GCR | Native adapter, `world.hpp`/`world.cpp` (#349), `rapier_physics_bridge.gd`, `simulation_snapshot.gd`, `simulation_worker.gd`; #350 stacks on #349. Granular-response lane, not an input to liquid decisions. |
| [#358](https://github.com/techrote/cybersand/pull/358) materials | Native adapter, `world.cpp`, `rapier_physics_bridge.gd`, `material.hpp`, `liquid_run_receipt_contract.py` and the capability-matrix source hashes. It appends IDs 132–137; its matrix change is non-liquid only (descriptors 138, non-liquid 126; **liquid rows remain 11**). If it merges first, #360 must regenerate/check the matrix and receipt contract rather than quote 132. |
| [#162](https://github.com/techrote/cybersand/pull/162) WAT-002 | Native adapter, `world.hpp`, `world.cpp`; Water quantity semantics, already named by the policy page as unmerged. Do not compare quantities across it without source identity. |
| [#260](https://github.com/techrote/cybersand/pull/260), [#308](https://github.com/techrote/cybersand/pull/308) | `main.gd`, `simulation_worker.gd` (#260); `main.gd`, `playable_session_panel.gd` (#308). |
| [#258](https://github.com/techrote/cybersand/pull/258), [#259](https://github.com/techrote/cybersand/pull/259) | Adapter/observation values (#258); `native/bench/lcb_science.cpp`, `tools/lcb/*science*`, `Makefile`, preparation script (#259). |

The shared native adapter, worker, snapshot and Rapier bridge therefore have
several concurrent owners. #360 should own the common comparison recorder and
only the smallest observation seam it needs; #361 should add tool behavior and
fixtures; #362 should start read-only. A required edit to a path above is a
sequencing decision against the named owner before implementation, not a reason
to create another planning issue. No missing prerequisite was demonstrated.

### Count clarifications

The bounded row counts in the comparison registration are matched-radius counts
(all four families at radius 3). The **preferred-radius control** is additional:
FM, CY and PF at radius 2; IN has no radius-2 candidate, so its row is identical
to the matched row. If registered, it adds three families to each cohort: 24
preflight rows, up to 84 correctness rows, and 36 rows per OS for the two cost
profiles. The 32-row preflight remains the matched-radius admission gate, and
the control must be named and bounded in the #360 manifest before collection.
These are ceilings, not required totals.

## Documentation validation and review

This checkpoint changes documentation and retrieval data only. Native laws,
gameplay, defaults, runtimes, dependencies, generated capability vectors,
historical evidence and CI workflows remain at the inspected main bytes.

The isolated source checkout initially failed documentation/repository validation
on six references to five absent companion files. The exact five files were
recovered from the already pinned companion commit
`6a58311982941b75f46e22109a0829e5acb83c7e`; no checker or reference was weakened.
All 18 required runtime payloads were independently matched to committed LFS
SHA-256/size, materialized for provenance checking, then returned to their
committed pointer representation. Identity verification does not execute them.

Before edits, documentation and materialized repository/provenance checks pass.
Historical M11 integrity passes 18 retained records and 28 original source hashes.
Baseline lexical retrieval is frozen **32/32 top-five** (19 top-one), supplementary
**156/157 top-five** (123 top-one); the pre-existing miss must remain disclosed.

### Resulting documentation checks

| Check | Result / scope |
|---|---|
| `python3 tools/ci/check_docs.py` | PASS:117 current documents,8 navigation documents,231 canonical claims,3,493 local links and651 heading links; no errors/warnings |
| `python3 tools/ci/check_repository.py --require-materialized` | PASS: all18 committed LFS payloads independently matched by SHA-256/size and materialized; source/dependency/runtime provenance unchanged. Payload representations restored after checking. |
| `python3 tools/ci/check_m11_consistency.py` | PASS:18 historical records and28 source hashes at original `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`; no current execution claim |
| Existing LCB `--check` contracts | PASS: `derive_capability_matrix.py`, `policy_contract.py`, `native_policy_artifacts.py`, `water_normalization_contract.py` (8 vectors), `liquid_run_receipt_contract.py` (7 vectors), `scenario_catalogue.py` (25 generated definitions) and `lcb_registry.py build --check` |
| Fresh audit and new question references | PASS:62 local report links,10 heading links and8 additive question source/canonical routes, using the existing checker's parsing/anchor rules. Historical audits remain excluded from link rewriting. |
| Frozen32 retrieval | Unchanged:19 top-one,32 top-five, MRR@5=0.7536 |
| Existing157 challenges |123 top-one,156 top-five; MRR@5=0.8712 versus baseline0.8696. The same pre-existing `LCB03` pressure-contract route miss remains; source truth is separately reviewed. |
| Eight new reassessment questions |8 top-one/top-five, MRR@5=1.0; independent expected-fact review completed. This lexical development check is not a general retrieval or answer-accuracy claim. |
| Scope / whitespace | `git diff --check` passes. Only14 documentation/retrieval paths change; frozen questions/challenges, generated capability inputs, historical artifacts, all native/gameplay/runtime/dependency and CI paths retain base bytes. |

Run retrieval with `python3 tools/docs/retrieval_eval.py --output OUT.json` for
the frozen set, adding `--queries docs/reference/retrieval-challenges.json` or
`--queries docs/reference/retrieval-questions-lcb-reassess.json` for the other
sets. Scratch JSON/context receipts retain corpus and evaluator hashes; they are
not committed build output. The dated audit is excluded from default retrieval;
the policy, mechanism, threading, scenario and host contracts own current answers.

### Independent review and disposition

Three read-only reviews covered native capability/mechanisms, retained performance
evidence and bounded scenarios, and the complete documentation/handover change.
All substantive findings were corrected: hash versus additional saved ledgers,
gravity per update, explicit PF gas limitations, current-versus-pre-merge canonical
claims, the actual `update_inertial` dispatch symbol, exact parked implementation
paths, the fixed1024 MicroScenario host around the256 footprint, and the need for
an identifiable-cell contact probe before a general trace. The final documentation
review reports no remaining findings; native and evidence reviews found no
blocking mechanism or scope error after their stated corrections.

Review did not re-run engines, human/browser sessions, old performance packets or
the proposed fixtures. Live PR/workflow readback and local provenance checks are
separate from those source reviews. The publication is a documentation-only draft
PR for #359, left unmerged; its resulting-head hosted status is recorded in the PR
and issue ledger. No fresh engine, scientific performance or human pass is claimed.
