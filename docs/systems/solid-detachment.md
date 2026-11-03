---
title: Native structural detachment, conservative displacement and experimental Sand resistance
status: Current
document-kind: contract
scope: Opt-in single native aggregate, conservative Sand/Water displacement, exact contact observations and separately enabled supported-Sand resistance; draft implementation, not full issue acceptance
canonical-for: [native-structural-detachment-runtime, conservative-detachment-displacement, detachment-sand-contact-experiment]
last-reviewed: 2026-11-03
related-documents: [../operations/soliding-programme.md, ../architecture/soliding-lifecycle.md, ../architecture/rigid-body-and-cellular-coupling.md, ../audits/2026-11-01-sol281-current-main.md, ../audits/2026-11-03-sol281-dense-contact-registration.md, ../audits/2026-11-03-sol281-dense-contact.md]
---

# Native structural detachment

## Implemented scope and source authority

**Current experimental source:** the `sol-detach-001-current-main` branch starts
from accepted main and fast-forwarded to `a8f08a67fea3c58f6df7473cbae1831334fcc04e`
before its first implementation commit, retaining production render-copy #344
and accepted PLAY #331. It recovers the finite native ownership kernel and compound
host from frozen #283, then adds a local conservative displacement transaction.
The [dated qualification record](../audits/2026-11-01-sol281-current-main.md)
owns exact executed sources, runtime hashes, failures and platform outcomes.
Source availability alone is not a passing physics or platform gate.

The 3 November continuation preserves that branch and all its qualification
ancestors. Ordinary merge `2321cf24d65024a609140b949efc3f5d909f6afa` reconciles
accepted main `89020b9eb6d540383a5bb64b58dcd29a87592c32`, including PLAY #332,
after the [prospective registration](../audits/2026-11-03-sol281-dense-contact-registration.md).
It adds a separately enabled Sand resistance experiment and exact contact
measurements below. The [new evidence ledger](../audits/2026-11-03-sol281-dense-contact.md)
owns its source and gate results; earlier binaries and platform passes do not
qualify this successor. PR #347 remains draft and unmerged.

The frozen archive remains at `254235ec4c3d58782bba44b478caca86bf57c856`.
Documentation predecessor #282 remains unmerged. Neither branch is rebased,
merged or used as the production baseline. Historical B=289 ejection is still
**Rejected / NO-GO**; render-retention experiments are not imported. Current-main
ordinary granular, liquid, render and independent-body policies remain in force.

## Native tree support loss and remaining lifecycle limits

The playable diagnostic starts with actual native RedBrick terrain, an
asymmetric crown, two open geometric regions, a cuttable trunk, a floor and an
unrelated control structure. A real native cut triggers local support discovery.
Exactly 520 eligible cells can become one six-shape Rapier aggregate. This is
an explicit local diagnostic trigger, not automatic general gameplay fracture.
The tree then falls, rotates and translates through Rapier. Native payloads
retain exclusive ownership. Dense-material penetration, general fracture,
multiple aggregates, active restoration and normal gameplay remain incomplete;
functional support loss alone does not complete #281.

## Owners and the handoff

[`World`](../../native/src/world_solid_detachment.inc) owns cells, exact captured
material/state/temperature tuples and the aggregate payload store.
[`CyberSimulationWorker`](../../godot/scripts/simulation_worker.gd) remains the
sole asynchronous cellular owner. The specialized
[`solid_detachment_worker.gd`](../../godot/scripts/solid_detachment_worker.gd)
adds copied commands and replies to that owner; it creates no second simulation
clock. The main-thread
[`session`](../../godot/scripts/solid_detachment_session.gd) and
[`CyberRapierPhysicsBridge`](../../godot/scripts/rapier_physics_bridge.gd) own
live bodies, shapes, collision refresh and Rapier stepping.

| Phase | Material and collision authority |
|---|---|
| Idle / refused discovery | Native cells and their existing derived static collider remain authoritative. |
| Prepared / acknowledged | Exact tuple and shape copies are evidence only. Native mutation/ticking is fenced; the staged Rapier body is inactive. |
| Committed | The bounded native aggregate owns the payload. Native source cells are empty. Physics stepping stays fenced while static collision is replaced. |
| Active | Rapier alone moves the aggregate; copied rectangle proxies describe cellular occupancy. The native aggregate retains all original tuples. |
| Rollback before motion | Destination and source witnesses are rechecked, exact cells restored, static geometry acknowledged, and the inactive body retired. |
| Unexpected failure | Quarantine/reset preserves the actual owner; a failed partial operation is never reported as a mutation-free refusal. |

Every awaited session continuation binds its generation and exact worker. The
post-mask-priming continuation is fenced too. Newer sessions cannot be unpaused,
destroyed or receive stale acknowledgements from retired workers. Overlapping
releases refuse. Saving CYPS state or claiming a physical-state hash during
unsupported active/pending aggregate states refuses instead of omitting matter.

## Structural admission and exact geometry

Admission is intentionally narrow: one homogeneous, ambient **Wall or RedBrick**
component inside a fully resident, included 64×64 domain. Connectivity is
four-connected. Explicit hard-material anchors keep the ground/stump native.
An unknown domain edge, missing/excluded region, pending event, foreign mask,
hot/reactive member, unsupported contact, stale source or exhausted member/shape
capacity refuses. Ambient Sand and Current FreeMass Water may border the
structure without acquiring rigid cohesion; their payloads stay native.

The native store holds at most 1,024 members. Exact horizontal runs merge only
when their spans match, preserving holes. The host also preflights the available
64 proxy IDs; an oversized compound ID interval refuses before transfer. Unit
cell mass, centre of mass and inertia derive from actual member positions,
including each unit square's intrinsic inertia. The diagnostic uses the retained
0.094 gravity scale and 0.04 linear/angular damping; these are fixture parameters,
not a general SI calibration or a change to ordinary gameplay defaults.

The body is positioned once during inactive creation. Subsequent motion comes
from Rapier gravity, hard contact and the shared cellular response. Exact
non-overlapping rectangles, rather than a filled bounding box or per-cell bodies,
provide both collision geometry and the copied native silhouette.

## Conservative displacement and the GCR interface

The strict policy is selected only by diagnostic setup
`conservative_displacement=true`; the detachment session selects it by default.
It replaces **all** ejection attempts in that session. It never falls back to
the permissive ordinary direct relocation. The ordinary body interface remains
11 input / 9 result floats, so GCR need not change its packed protocol.

[`conservative_displacement_adapter.inc`](../../godot/native_extension/conservative_displacement_adapter.inc)
validates a contact normal, ownership, full cell-square geometry and a bounded
vacancy route. [`World::conservative_displace_cells`](../../native/src/world_conservative_displacement.inc)
revalidates tick, optional active aggregate lease, every expected tuple, masks,
residency, inclusion, policy and thermal capacity before changing any cell.

| Rule | Implemented bound / refusal |
|---|---|
| Path | Two to five distinct positions, at most four cardinal one-cell parcel moves; no cycles. |
| Search | Deterministic breadth-first depth four using fixed 81-site scratch; no wider ejection-radius tuning. |
| Direction | Each edge has nonnegative projection on the outward normal; the complete path has positive outward progress. |
| Parcels | Ambient Sand or ordinary FreeMass Water; no pressure/inertial sidecars, gas, reactive or unsupported material. |
| Destination | Full closed unit square has more than `1e-6` cell separation from every current oriented proxy rectangle, and no transient swept/body mask. Exact touch and ambiguous geometry refuse. |
| Source | Exact source mask ownership; overlap with a foreign body's square geometry refuses even when first-writer mask sampling hides it. Sibling shapes of the active aggregate share physical ownership. |
| Terminal | Canonical ambient Empty, without hidden state or temperature to overwrite. |
| Per sample | At most 64 search attempts and 320 touched-coordinate slots. Every source, intermediate and terminal of an accepted path is reserved across repeated preparations of that sample. |
| Commit | Shift the vacancy backwards through ordinary `move_cell`, preserving each parcel's material, semantic state and temperature and all dirty/activity/discovery bookkeeping. Scheduling epochs update normally. |

There is no allocation in search or admitted chain commit. Resident chunks and
any needed thermal fields are preflighted. Expected refusals change no payload.
An unexpected commit exception quarantines the World and reports actual partial
progress; it is not safe to retry it as an ordinary refusal.

**Baseline force/torque ownership (`sand_resistance=false`):** detachment supplies
geometry and an ownership lease.
The existing cellular coupling supplies exactly one ordinary contact reaction,
not one reaction per shifted parcel. The shared Rapier bridge reduces the proxy
results to one bounded aggregate correction and applies each existing impulse at
its rotated proxy centre, preserving attributable off-centre torque. Duplicate,
mixed, incomplete or stale samples refuse before Rapier mutation. Age scaling,
correction age and opposing-velocity handling use the ordinary bridge policy.
Conservative displacement introduces no friction, bearing gain or yielding law.
Ordinary GCR retains its normal response, friction and granular yielding policy.
The independently enabled experiment below adds a supported-Sand normal
constraint for this aggregate only; it does not import or promote Y1 #343.
Accepted GCR integration needs its own combined-source qualification.

Exact material accounting does **not** establish calibrated momentum/energy
conservation. This bounded corrective rearrangement is not a bulk granular
solver. Fully buried contacts without a nearby admissible vacancy remain
unresolved, retain all material, and use the existing contact response.

The dedicated worker refuses native-only reset/scenario replacement for its
entire session. Reset joins that worker and retires the Rapier body together.
A copied native failure latches the session stopped, including mask priming and
held-tick waits; unpause cannot bypass the latch. An unexpected native chain
quarantine stops preparation before further mask mutation or force publication.
Compound feedback admits only forward modular sample identities, preventing a
nonconsecutive replay from applying an impulse twice.

## Opt-in supported-Sand resistance

**Current experimental source, qualification separate:**
[`solid_contact_adapter.inc`](../../godot/native_extension/solid_contact_adapter.inc)
adds the read-only `solid_detachment_contact_observation()` value channel for
the one active aggregate. It changes neither the conservative material
transaction nor the ordinary 11/9 coupling ABI. Session `sand_resistance` defaults
to `false`; `measure_contacts` may enable observation without response. The lab
measures both arms and labels the candidate explicitly.

### Exact native geometry and admission

The native owner reconstructs all proxy rectangles from one aggregate transform,
checking each copied proxy's identity, sample, size, mass and pose coherence.
[`solid_contact_geometry.hpp`](../../native/include/cybersand/solid_contact_geometry.hpp)
uses four-axis SAT and clipped polygons against the **whole native unit square**.
The AABB only bounds traversal; cell centers do not decide overlap. Recorded
depth is minimum separating translation, while area is the exact polygon
intersection. Area sums across disjoint proxies; unique overlapping cells are
deduplicated across the compound. The six-shape tree and both holes remain intact.

All nonempty native materials contribute geometry measurements. Only ambient
Sand with the existing native support predicate supplies response segments;
the body's transient mask cannot count as that support. Exterior face runs are
derived on the exact source cell grid before rotation. Sibling-covered internal
seams are removed, including partial seams within a single material square.
The resulting face segment, normal, cell, weight, area and depth are copied as
one complete witness. Water, hot Sand and unsupported materials receive no new
response. Their ordinary policies remain unchanged.

| Work or admission | Bound / behavior |
|---|---|
| Proxy geometry | At most 64 proxies and 8,192 cell/proxy probes per observation. |
| Exterior construction | At most four source edge units per aggregate member, bounded by 4,096 units. |
| Sand support | Known resident/included 3×3 native footprint per support query; unknown support refuses the complete observation. |
| Contact output | At most 256 exterior segments; capacity, foreign-body, malformed, incomplete or incoherent geometry refuses the complete response. |
| Native mutation | None in observation or response planning; existing conservative transfers retain their own atomic preflight. |

A deeply embedded square with no exterior face crossing can contribute positive
overlap but no response segment. This limitation is measured; the candidate
does not resolve initial burial by deleting material or correcting body position.

### Immutable publication and main-thread response

The exclusive worker copies the observation into `solid_contact_observation`
before publishing its snapshot and recursively freezes the payload. Native tick,
World revision, body sample, aggregate token/generation, snapshot serial and
physics epoch bind that copy to its enclosing publication. Failed publications
clear the channel. Main reads no live native cells.

After the existing compound result is admitted, the main-thread bridge validates
the complete identity against that publication, including exact revision
equality, forward sample ordering and the last applied snapshot/tick. Duplicated,
old, out-of-order, incomplete and wrong-session observations perform no new RID
mutation. A contact sample may be at most one sample old. Every proxy corner must
remain within 0.25 cells of the observed pose, and the current geometry must still
intersect the recorded cell. These are refusal fences, not inflation of geometry.

[`solid_contact_response.gd`](../../godot/scripts/solid_contact_response.gd)
plans the complete response before any impulse is applied. For inward normal
`n`, contact offset `r`, current velocity `v`, angular velocity `omega`, mass `M`
and inertia `I`, an approaching contact uses
`j = -((v + omega × r) · n) / (1/M + (r × n)^2/I)`.
The zero-restitution impulse is `j*n`; separating motion receives none.
Parallel face segments use a contact-length-weighted resultant over the
**currently approaching subset**, recomputed on each of four fixed sweeps.
That bounded approximation preserves symmetric loading without hiding a spinning
edge behind its separating counterpart. Residual approach is reported after the
sweeps; full multi-contact convergence is not guaranteed.

Each planned impulse must satisfy the registered kinetic-energy nonincrease
bound, `1e-8 * max(1, energy before that impulse)`. The bridge alone applies the
plan through Rapier, then reads back velocity, angular velocity, energy, impulse
and angular momentum change. A readback energy increase beyond the registered
`1e-4` relative bound stops the session. The candidate adds no positional
correction, friction gain, restitution, ejection search or Sand mutation.
Supported Sand acts as a dissipative contact reservoir here; exact two-way
granular momentum or calibrated mechanical-energy conservation is not claimed.

### Physical measurements and their denominators

Each complete consumed observation records exact overlap area, maximum
penetration, unique overlapping cells and per-proxy values at its source pose.
The live trace distinguishes source and current Rapier poses and retains their
identity fields. Summed asynchronous measurements are **overlap-cell-samples**
and **area-samples**, with the complete consumed observation count as denominator.
They are not native cell-ticks or a synchronized per-step trajectory. Three
repeats per arm and environment report ranges; unmatched live paths are not
controlled causal comparisons.

Contact cost includes all native-owner observation attempts, including refused
or unconsumed publications and payload freezing, plus every main response
attempt. Cumulative owner timing prevents dropped publications from disappearing
from the cost account. The proposed CPU feasibility gate divides that total
contact work by complete consumed geometry observations and requires a mean no
greater than 2 ms on the disclosed host. Report native-worker, Rapier-step,
synchronization and publication latency separately. Headless CPU results do not
establish GPU frame pacing or human gameplay acceptance.

## Diagnostic scene and controls

Use a freshly built source-matched extension and pinned Godot 4.7/Rapier:

```text
godot --path godot res://solid_detachment_lab.tscn
```

| Control | Action |
|---|---|
| 1 / 2 / 3 / 4 | Reset into dry / packed Sand / partially embedded Sand / mixed Sand–Water surroundings. |
| Space | Apply the native support cut and attempt the fenced release. |
| P | Pause/resume. |
| R | Reset the whole session. |
| W | Reset with one or four native workers. |
| V | Reset and toggle the explicitly experimental Sand resistance candidate. |
| X | Excavate supporting terrain through the native owner. |
| I | Request copied conservation/contact inspection. |
| Escape | Exit. |

The lab consumes immutable material packets and acknowledges only successfully
consumed publications. It draws aggregate members from the actual body transform.
Terrain edits refresh derived hard collision before another Rapier step. The
lab is an inspectable diagnostic, not normal launcher/gameplay acceptance.
Start the candidate directly with
`godot --path godot res://solid_detachment_lab.tscn -- --sand-resistance`.
Omitting the flag keeps the prior contact response selected; observation in the
lab is enabled for both choices.

## Qualification and remaining limits

Measurements separate sampled healthy worker/native publications, main-thread
consume/publish segments, manual Rapier stepping and collider refresh. Sampled
worker totals do not represent every native tick. These headless metrics cannot
establish graphical frame pacing or target-GPU acceptance.

The complete source-matched Linux/Windows matrix at `8e86ffd4` passed on
GitHub-hosted runners, including workers 1 and 4. Its qualified development
runtimes and original six-cohort evidence were published in `bdd751dc`.
The dated audit records exact identities and preserves the earlier failed
Windows checkout attempt. Passing populated cases establish material quantities,
aggregate payload, ownership and actual interaction; they do not establish
acceptable dense resistance. That historical matrix did not measure live
penetration depth or overlap area. The 3 November experiment adds those
measurements and local impulse/energy accounting, with its own qualification
required. Dry impact produces real rotation and horizontal
displacement; a calibrated no-slip rolling criterion is not qualified.

Focused native ownership and displacement tests, deterministic frozen contacts,
actual Rapier motion/failure/worker-replacement cases, populated environments,
excavation and shared response tests are distinct gates. Frozen #338 contacts
retain their original source metadata and negative outcomes; four new shallow
boundary controls demonstrate accepted relocation, including three multi-parcel
paths. No historical result
is relabelled as a current execution.

The scoped GitHub-hosted workflow authenticates build inputs and every declared
Linux/Windows cohort, then reopens their original evidence before publishing
the two development runtimes on this draft branch. Publication requires an exact
branch-head lease; its commit is a child of the qualified source. Provenance
continues to name the original build/execution commit and tree. Raw Windows
evidence retains its original line endings. A later metadata commit does not
become a newly executed physics source by relabelling the records.

The new focused gates cover exact native geometry, source-pose observation,
pure response planning, actual Rapier readback, publication/revision refusal and
repeated packed/embedded/mixed sessions. The controlled 12-step mechanism test
compares identical loads with the prior three-unit aggregate impulse ceiling
offered fully upward on each step. It isolates that ceiling's mechanical limit;
it is not a replacement native simulator or a complete B0/Y1 gameplay comparison.
Source-bound results and the preserved failed rotating-contact experiment are
in the new dated ledger. Dense resistance, sustained clearance, cost and
rotation remain acceptance questions even when conservation and narrow gates pass.

## Embedded Sand and reversible restoration limits

Improved contact does not establish deep-embedding recovery. A native Sand cell
can remain inside the compound without crossing an exterior face, producing
measured overlap but no candidate normal impulse. No moving or sleeping aggregate
is rasterized back into terrain by this experiment. Sleeping retains native
aggregate payload ownership and a live Rapier body; it is not native restoration.

**Deferred:** reactive Wood/bark, heterogeneous bonds, arbitrary fracture,
multiple persistent aggregates, transformed rest-to-cell restoration, normal
gameplay integration and Web qualification. Sleeping is still aggregate ownership.
The existing inactive rollback is not dynamic desoliding. Representative hardware
GPU pacing and human physical acceptance remain separate from headless host
timing. The dated audit assigns each #281 gate; neither #281 nor #12 is closed by
this functional increment.
