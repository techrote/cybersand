---
title: Native structural detachment and conservative local displacement
status: Current
document-kind: contract
scope: Opt-in single native aggregate, asynchronous ownership, compound Rapier motion and bounded conservative Sand/Water contact; draft implementation, not full issue acceptance
canonical-for: [native-structural-detachment-runtime, conservative-detachment-displacement]
last-reviewed: 2026-11-01
related-documents: [../operations/soliding-programme.md, ../architecture/soliding-lifecycle.md, ../architecture/rigid-body-and-cellular-coupling.md, ../audits/2026-11-01-sol281-current-main.md]
---

# Native structural detachment

## Implemented scope and source authority

**Current experimental source:** the `sol-detach-001-current-main` branch starts
at accepted main `809fd30dfac0c5e127302997075be9c4b279e5aa`, including production
render-copy #344. It recovers the finite native ownership kernel and compound
host from frozen #283, then adds a local conservative displacement transaction.
The [dated qualification record](../audits/2026-11-01-sol281-current-main.md)
owns exact executed sources, runtime hashes, failures and platform outcomes.
Source availability alone is not a passing physics or platform gate.

The frozen archive remains at `254235ec4c3d58782bba44b478caca86bf57c856`.
Documentation predecessor #282 remains unmerged. Neither branch is rebased,
merged or used as the production baseline. Historical B=289 ejection is still
**Rejected / NO-GO**; render-retention experiments are not imported. Current-main
ordinary granular, liquid, render and independent-body policies remain in force.

The playable diagnostic starts with actual native RedBrick terrain, an
asymmetric crown, two open geometric regions, a cuttable trunk, a floor and an
unrelated control structure. A real native cut triggers local support discovery.
Exactly 520 eligible cells can become one six-shape Rapier aggregate. This is
an explicit local diagnostic trigger, not automatic general gameplay fracture.

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

**Force/torque ownership:** detachment supplies geometry and an ownership lease.
The existing cellular coupling supplies exactly one ordinary contact reaction,
not one reaction per shifted parcel. The shared Rapier bridge reduces the proxy
results to one bounded aggregate correction and applies each existing impulse at
its rotated proxy centre, preserving attributable off-centre torque. Duplicate,
mixed, incomplete or stale samples refuse before Rapier mutation. Age scaling,
correction age and opposing-velocity handling use the ordinary bridge policy.
No new friction, bearing gain, yielding law or alternate motion authority is
introduced. GCR remains responsible for normal response, friction and granular
yielding; accepted GCR integration needs its own combined-source qualification.

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
| X | Excavate supporting terrain through the native owner. |
| I | Request copied conservation/contact inspection. |
| Escape | Exit. |

The lab consumes immutable material packets and acknowledges only successfully
consumed publications. It draws aggregate members from the actual body transform.
Terrain edits refresh derived hard collision before another Rapier step. The
lab is an inspectable diagnostic, not normal launcher/gameplay acceptance.

## Qualification and remaining limits

Measurements separate sampled healthy worker/native publications, main-thread
consume/publish segments, manual Rapier stepping and collider refresh. Sampled
worker totals do not represent every native tick. These headless metrics cannot
establish graphical frame pacing or target-GPU acceptance.

Focused native ownership and displacement tests, deterministic frozen contacts,
actual Rapier motion/failure/worker-replacement cases, populated environments,
excavation and shared response tests are distinct gates. Frozen #338 contacts
retain their original source metadata and negative outcomes; four new shallow
boundary controls demonstrate real multi-parcel movement. No historical result
is relabelled as a current execution.

**Deferred:** reactive Wood/bark, heterogeneous bonds, arbitrary fracture,
multiple persistent aggregates, transformed rest-to-cell restoration, normal
gameplay integration and Web qualification. Sleeping is still aggregate ownership.
The existing inactive rollback is not dynamic desoliding. Representative hardware
GPU pacing and human physical acceptance remain separate from headless host
timing. The dated audit assigns each #281 gate; neither #281 nor #12 is closed by
this functional increment.
