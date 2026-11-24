---
title: Wave flow Water solver (experimental)
status: Current
document-kind: reference
scope: Current Wave Flow law, player defaults, bulk strip-parallel execution, admission, state and memory
canonical-for: [wave-flow-v1]
last-reviewed: 2026-11-24
related-documents: [liquid-solver-family-policy.md, pressure-flow-v1.md, inertial-cellular-v1.md, simulation-tick-and-threading.md, rigid-body-and-cellular-coupling.md, ../audits/2026-11-15-wave-mt-001-wave-flow.md, ../audits/2026-11-15-wave-mt-001-completion.md]
---

# Wave flow Water solver (experimental)

Wave Flow entered the shared Workbench through PR #631. New sandbox and Workbench sessions use the owner-approved gameplay profile with waterfall spill and ballistic release. Native callers opt in through `WorldConfig::wave_flow`; disabled Worlds keep their original kernels, physical hashes, save formats and memory use. Wave runs on the FreeMass carrier. The [ramp evaluation](../audits/2026-11-19-wave-water-ramp-003.md) records the default transition and the [Oil tank](../audits/2026-11-20-wave-oil-impinge.md) records the final playtest.

The additive C API and Godot evaluator expose the experimental law, worker and
substep selection, representative scenarios and copied native diagnostics.
Exact physical save/restore remains explicitly unsupported; authored scenarios
can be reconstructed, but this is not continuation of a running Wave World.
The [completion evidence](../audits/2026-11-15-wave-mt-001-completion.md) owns
historical implementation evidence; the [Astra takeover record](../audits/2026-11-15-wave-mt-001-astra-takeover.md)
and PR #631 ledger own resulting-source qualification. The
[original evidence](../audits/2026-11-15-wave-mt-001-wave-flow.md) is historical:
its timings and platform results do not qualify a later #618 candidate.

## What it is, in one paragraph

Every existing Water law visits Water one cell at a time through the generic
kernel dispatch; the original experiment measured roughly 300–700 ns per visited cell on its stated machine. `wave_flow_v1`
instead solves all Water in bulk, in three simple passes over column strips,
and keeps one extra number per cell: the **flux** through its right-hand face.
Because that flux is remembered from tick to tick, a disturbance keeps moving
after the push that caused it. That remembered motion is what makes real waves:
two disturbances pass through each other, add where crests meet and cancel
where a crest meets a trough. There is no pressure solve, flood fill, gas
compartment or retained global pressure field. A local weight field is derived each round.

## Why this candidate

The original experiment compared three families before integration. These are
historical selection results, not final-candidate performance claims
([evidence](../audits/2026-11-15-wave-mt-001-wave-flow.md#candidate-comparison)).

| Candidate | Finding | Outcome |
|---|---|---|
| A. Parallelise `pressure_flow_v1` | At 2048² the cached+dormant variant measured 2.1 ticks/s on one worker and 5.7 on four in a dam break, and 8.5 ticks/s for a pool that is **at rest**. The cost is spread over serial preparation and the per-cell kernel, so more workers cannot reach the target | Not pursued |
| B. Whole-cell transport plus a separate coarse wave layer | A single height per column cannot describe caves, overhangs and stacked pools; whole cells quantise wave height to one cell, too coarse for interference | Analysed, not built |
| C. Local conserved mass with retained face flux | Standalone prototype: exact conservation, measured constructive and destructive interference, about five times faster than A on one worker before any optimisation | **Selected** |
| C without retained flux (ablation) | Levels correctly but transmits no wave at all | Rejected: momentum is what buys waves |

## The law

Mass is the existing fractional Water carrier (`state_a`, 255 = one full cell).
One round has three barrier-separated passes. Each strip owns half the columns
of a contiguous chunk column (64 columns at the default 128-cell chunk size).

1. **Column pass** (owns its columns). For each column, bottom-up:
   - loose Water falls one cell;
   - a stack of full cells is treated as connected: a deficit left by sideways
     outflow is refilled from above in the same pass, so a deep pool never
     splits into two "surfaces";
   - excess is carried up to the surface, or stays as overfill under a solid
     ceiling. Extreme overfill is retained across that sealed segment if it
     cannot fit in one uint16 cell.

   Then, top-down, it derives each cell's **head**: the weight of the liquid
   resting on that cell's floor. Only a full cell carries what rests on it, so
   a falling curtain of thin cells exerts no pressure.
2. **Flux pass** (owns its faces). For each face between two cells in the same
   row: `flux += gain × (head left − head right)`, minus symmetric 1/128 damping,
   then limited (below). Only the top 32 rows of a stack originate a restoring
   response; exposed faces can pour. Two exceptions make rest possible
   ([coming to rest](#coming-to-rest)): small flux is damped hard and discarded
   across a level face, and a film on a solid floor levels directly.
3. **Apply pass** (owns its cells). Each cell gains what its left face carries
   and loses what its right face carries. Both sides evaluate the same pure
   function of the face, so mass is conserved exactly. Flux is held in 1/4096
   of a unit; the whole units a face moves in a round come from a stateless
   additive threshold sequence over rows and successive rounds. For a constant
   flux its average over all 4096 round phases is exact; a column's aggregate
   can still differ from its rounded total in any one round.

Why head is "weight above" rather than "height of the surface": moving one unit
sideways in a row then changes potential energy by exactly the head difference,
for any mixture of full, thin and falling cells. The retained flux therefore
cannot gain energy from a mis-stated surface. Three earlier variants that used
a surface height each pumped energy into the pool
([negative results](../audits/2026-11-15-wave-mt-001-wave-flow.md#negative-results)).

### Coming to rest

Law version 1 never came to rest once it had been disturbed. Each face rounded
its sub-unit flux to whole units with an independent random threshold. Across
the 32 responding rows that is about ±3 units of noise per face per round, and
the solver's deliberately low damping (1/128) amplified it into a permanent
slosh: adjacent columns traded about 25 units every few ticks, for ever. Only a
level pool that nothing had ever touched stopped being solved. Version 2 makes
rest reachable with four rules, none of which adds stored state:

| Rule | Value | What it does |
|---|---|---|
| Additive rounding | sequence over rows and rounds, per-column offset | Spreads thresholds to reduce the observed sampling noise; a constant flux has the same average over 4096 round phases, and rows remain out of step |
| Calm band (`kCalm`) | flux below ⅛ unit per round loses ⅛ per round | Absorbs what rounding leaves behind. A real wave is in this range only near its turning points, where its energy is in the heads |
| Rest rule (`kRestHead`, `kStick`) | heads within 1 unit and flux in the calm band → flux is discarded | Removes small momentum that would only flip a one-unit step; larger flux still follows the inertial law |
| Films | two partly filled cells on a solid floor exchange about ¼ of their difference with no momentum, while the donor exceeds the adhesion threshold and the difference exceeds 1 unit | Removes the long-lived creep of supported films; adhesion can leave an uneven residue |

Rest is exact: no cell changes and every retained flux is zero. That state is a
fixed point of the three passes, so a chunk at rest can stop being solved
without changing any later result. Measured consequences are in the
[completion record](../audits/2026-11-15-wave-mt-001-completion.md#2026-11-15-claude-review-rest-and-identity-repair).

The costs are deliberate and bounded. The rested pool regressions allow
neighbouring column totals to differ by one unit (1/255 of a cell). Supported
adhesion residue can remain more uneven, as described below. Ripples whose flux
never leaves the calm band (roughly 8 units of amplitude, 3% of a cell) die within
tens of ticks instead of fading slowly. A film has no waves at all.

### Limits that keep it stable

| Limit | Value | Reason |
|---|---|---|
| Responding rows per stack | 32 | Gravity can stay a true constant (wave speed ≤ ½ cell per round) instead of weakening with depth, which pumped energy |
| Inertia per face (`kCoast`) | 16 units per round | Small flows keep their momentum and make waves; large flows relax without overshoot |
| Downhill share | head difference ÷ (8 × responding rows) | The explicit-diffusion bound: two columns cannot swap places in one round |
| Pour into an empty cell | ¼ of the source cell | A pair of columns cannot invert |
| Adhesion threshold | 24 units with adhesion enabled; zero with it disabled | Stops continued thinning of a supported spill; the final residue can be below the threshold and can remain uneven |
| Receiver capacity | At most half its remaining uint16 capacity from each adjacent face | Simultaneous arrivals cannot overflow a cell |
| Sealed-stack inflow stop | Top mass at least 32,000 units | Stops additional inflow before the carrier limit |
| Derived head | At most 2²⁶ units | Bounds arithmetic for extreme legal sealed columns |

These are **bounded-approximation choices**, not physics. Their visible cost is
that bulk surges are sedate at one round per tick; see [limits](#limits).

The adhesion amount is a threshold for starting supported pouring or direct
film levelling, not a hard minimum mass. Like the per-cell Water law, a cell that starts above the threshold
can finish below it. Each film face uses the donor's mass before the apply pass;
two-sided outflow can therefore leave a supported row `[1, 25, 1]` at `[2, 23, 2]`,
or `[1, 32, 1]` at `[9, 16, 9]`. Quantity is unchanged. With adhesion enabled these
residues stop moving even though neighbouring masses differ by more than one
unit. Disabling adhesion wakes them and permits further levelling. The native
threshold regression checks both examples across strip and chunk seams with
one and four workers, including stable rest and region re-entry.

### Sealed passages

Water under a solid ceiling cannot rise, so inflow there becomes overfill. The
overfill adds head (stiffly, scaled by how many rows can respond) and pushes
onward. This gives U-tube equalisation with no pressure field. Its cost is that
a sealed passage temporarily stores extra Water as overfill. The ordinary
transport regime stays below the uint16 limit. For explicitly seeded extreme
volumes, a 64-bit column accumulator redistributes excess through the same
sealed segment up to 65,535 units per cell; it never discards quantity merely
to fit the preferred top cell. The derived head is bounded, so these extremes
are a numerical capacity contract, not a high-pressure physical model.

## Parallel execution

- Runs inside `World::begin_tick`, on the **existing** persistent worker pool,
  before the generic phased scheduler. No new threads.
- Tasks are disjoint column strips. No pass reads anything another strip
  writes in that pass. There are no per-cell locks or atomics.
- No pass depends on task order, so **every worker count produces identical
  cells and complete Wave physical state**. Regressions compare 1, 2, 4 and 6
  workers, including fixed-seed edits, moving masks and signed-coordinate seams.
- `TickStats::worker_threads_observed` and `WaveFlowDiagnostics::maximum_participants`
  report actual pool participants, not configured capacity.
- Separate counter sets have a full cache line of trailing padding. Ordinary
  allocation avoids the aligned-allocation `CXXABI_1.3.11` dependency while
  retaining separation between concurrent writers; the Linux floor is unchanged.
- Wave writes contribute to `TickStats::moved_cells`, so a changed native Water
  publication advances the Godot render revision.

### Sparse work

- The exclusive owner derives the exact bounding rectangle of the current
  nonzero transient body cells before dispatch. The column pass probes only
  that occupied rectangle, instead of the configured obstacle allocation
  (which can cover a complete Workbench canvas for one small actor). The
  original configured region still determines dry/clean metadata, so this
  removes only lookups that must return zero. Cells, impulses, column order,
  barriers and physical sample admission are unchanged. This scoped PUBPRES
  successor is Draft/HOLD; [source proof and qualification](../audits/2026-11-24-pubpres-playability-final/native-architecture.md)
  distinguish native measurements from whole-Workbench playability.
- A chunk is solved until it is at exact rest, and again when an owner edit,
  kernel write, body mask or region re-entry touches it; its eight neighbours
  are solved with it. Rest means 30 consecutive ticks in which no cell changed
  and every retained flux was zero. Every one-unit change and nonzero face flux
  retains work, so a falling trickle cannot sleep halfway through a chunk
  crossing and Water that is still draining is still solved. A pool at rest
  dispatches no strip tasks; resident metadata checks still have a small cost.
- Disturbed Water does come to rest ([coming to rest](#coming-to-rest)). How
  long that takes is the time the Water really needs to stop: about a thousand
  ticks for a splashed pool, several thousand for a sheet one or two cells
  deep, and tens of thousands for a thin sheet draining off a long flat ledge.
- Inside a solved chunk, a column with no Water is skipped, and a half-chunk
  that is entirely empty is skipped.
- Workers never allocate. Before the passes the owner admits any missing
  neighbour chunk that liquid on a chunk edge needs. If
  `maximum_chunk_count` is reached the neighbour stays a wall: an explicit
  capacity outcome counted in `capacity_refusals`, with quantity unchanged.
  Admission candidates are sorted and deduplicated before capacity is spent.
- Sparse roster/task buffers are bounded by configured chunk capacity. Per-task
  column scratch grows on the owner thread when a taller solved column is first
  encountered; this is observed allocation, not an allocation-free tick claim.
  Steady-state reuse and actual allocated bytes are reported separately.

### Selected region, edits and masks

Wave uses the same selected scheduling-core coverage as the phased scheduler.
Included cores run; excluded Water cells and their retained faces freeze. A face
crossing the selected boundary transfers no quantity, and its stored flux is
retained for re-entry. No elapsed-time catch-up occurs. Newly included resident
blocks wake Wave once at tick entry; equivalent coverage and coalesced
A-to-B-to-A requests do not repeatedly wake it. Unlike generic cellular halo
writes, Wave's bulk pass is strictly clipped to selected-core boundaries.

The Wave pass does not admit offscreen neighbour chunks. Ordinary selected
non-Water kernels retain their existing bounded halo semantics and may initiate
an interaction across a core boundary; Wave is not a new ownership boundary for
those kernels. A failed World remains quarantined regardless of region requests.

Explicit painting, erasure and external tuple displacement retire the edited
cell's right and left flux faces and invalidate its old support metadata. Moving
body masks remain transient solid barriers; stored Water under a body is retained.
Masks wake affected chunks, and copied contact observations use the existing
native contact accumulator. No native pool worker accesses Godot or Rapier objects.

`World::wave_column_task` clips each mask axis to its bounded local strip before
probing cells. `wave_clip_mask_axis` uses signed ordering and unsigned relative
distances, then narrows only values bounded by the strip size. It never forms a
global mask endpoint. Valid sparse origins may be more than `INT64_MAX` apart,
and a configured mask's mathematical endpoint may exceed the signed range;
only representable occupied cells are accessed. A distant, disjoint mask covers
no strip cells. This avoids overflow before a clamp could take effect.

The PUBPRES continuation also bounds obstacle probes by the actual sparse
occupied-cell rectangle, built once by the exclusive owner. The original
allocated mask region still controls dry/clean classification. Its separate
derived `empty_derived` half-cache certifies only that all actual cells are Empty
and retained head/meta bytes are zero; it makes no claim about flux. A complete
selected half outside actual occupied bounds can fill zero column scratch and,
if column physics leaves it empty, omit redundant zero scatter. Gravity,
refill, head/depth reconstruction, dry/clean decisions, retained-face retirement,
flux snapshot, flux and apply still run unchanged. Incoming Water, bodies or
other materials revoke reuse. Owner/material mutations wake the half, positive
Wave writes revoke it, and partial selections cannot certify untouched cells.
The [candidate proof and qualification record](../audits/2026-11-24-pubpres-playability-final/native-empty-derived.md)
distinguishes source correctness, native measurements and unfulfilled gameplay
acceptance. This continuation remains Draft/HOLD.

## Waterwall spill (experimental, WAVE-WATERWALL-001)

**Status:** Draft/HOLD branch `claude/wave-waterwall-001`, stacked on PR #661. It is
selected through `WaveFlowConfig::spill.enabled`. The Water Ramp player profile enables it. With spill off,
the law is the qualified Wave law: `test_wave_spill` pins cells, `state_hash`,
`physical_state_hash` and `content_hash` for 12 scenes (1/4 workers, 1/3
substeps, a selected region) to values computed from the unmodified #661 source.
The dated [evidence record](../audits/2026-11-17-wave-waterwall-001.md) holds the
diagnosis, the candidates that were tried, timings and Workbench captures.
The [18 November review remediation](../audits/2026-11-18-waterwall-review-remediation.md)
records the later corner, coordinate, force and Water Lab repairs and their
separate qualification status.

**The defect.** A large Water body standing on a ledge beside open air kept an
almost vertical face for thousands of ticks while a narrow stream trickled away.
Three limits in the original law combined to cause this. The Water was never
physically blocked, and it was not being replenished from above:

1. An exposed face donates at most ¼ of its cell per round into an Empty
   neighbour (`empty_pour_shift`). Falling Water then moves only one cell per
   round and carries no momentum. The face therefore feeds a curtain one or two
   cells wide.
2. Bulk flow toward that face is limited by `coast` (16 units per round) or by a
   share of the head that shrinks with stack depth (1/256 at 32 rows). The pool
   behind the face cannot supply it any faster.
3. Unsupported falling cells are treated as stacks, so heads and depth classes
   are derived for Water that rests on nothing.

The existing tuning ranges do not fix this cheaply. `coast` 64–255 drains the
reservoir about 3× faster but keeps a straight, thin curtain. Eight substeps
drain it about 8× faster at about 8× the tick cost.

**The mechanism.** Spill changes nothing in storage. Its only carried state is
one launch back-off flag, and every transfer goes through the existing conserved
faces or the ballistic parcel owner.

| Part | Rule |
|---|---|
| Falling Water | Water with no solid, full resting Water or solved edge beneath it is marked *falling* (depth code 6). It carries no head and falls `fall` cells per round (default 3) |
| Exposed face | A face whose receiver is falling Water, or Empty air with nothing able to support Water beneath it, discharges `1/2^share_shift` of the donor cell per round (default ½). Receiver room is shared between the two faces. A falling donor sheds only its mass above `stream`, so a stream stays together until it is dense |
| Pool feed | A wet-wet face may carry `draw` units per round (default 64, Coast stays 16) unless the flow runs against more than `draw_head` units of head. This lets the pool keep feeding its draining edge while reversing surges still relax |
| Ballistic release | Only when the World also enables `ballistic_water_v1`. In the last round of a tick, exposed faces beside Empty air are nominated into a fixed 512-entry list per strip, and the face itself carries nothing. After the passes, the tick owner serially launches up to `launch_budget` parcels (clamped to free pool slots) at `launch_speed/256 · √(2gh)` outward. Each launch is an exact transfer of at most one cell. A refused or deferred launch leaves the Water in its cell, and the next tick spills it through the grid |

| Blobs (`catch_falling`, default on) | A parcel older than the 4-tick self-contact grace merges into falling Wave Water instead of passing through it. Thrown water then clumps the falling stream into beads ("blobs") while the outer spray keeps arcing. Off: parcels fly through falling Water |
| Stream share (`stream_share`, default 0) | n/256 of each thrown share keeps pouring through the grid as a vertical stream, and the release may spawn into that falling Water. Measured on the supplied map: values above 0 thin the throw, draw the lip back toward vertical and slow draining, so the default is off |
| Stream draw (`stream_draw`, default 0) | n/256 of each thrown share additionally pours from the face cell through the grid as a vertical stream, without reducing the throw (2026-11-18). The face keeps being refilled by the pool feed, so the stream is drawn from the volume behind it. The poured amount is capped at half an Empty receiver; the launch then takes what the cell still holds, so ownership stays exact. Bound into identity only when non-zero |

Generic `ballistic_water_v1` (impact splashes, sprays, jets, nozzles and
body-launched or injected parcels) is admitted under Wave with or without spill
(2026-11-18; before that, #631 and this branch refused it). The release above
throws through the same parcel pool, so it needs `ballistic_water_v1` enabled;
the Workbench sets `launch_budget` to 0 when Ballistic Water is on without
Ballistic release, so spill then drains faces through the grid only. The
per-cell WCX-FR face scan is admitted under Wave only while spill is off, because
spill owns exposed faces. With spill on, parcels pass through falling Wave Water. They may not
land beyond a wall one cell thick, including a diagonal one, and they may not
step diagonally through such a wall even when the diagonal destination already
contains Water. Connected Water neighbours retain the existing merge priority.
Automatic spill and Face release check both spawn-cell coordinates against the
ballistic domain before q256 multiplication or the cell-centre offset. A
refusal leaves the donor with the grid owner; spill retains its usual grid
fallback, while Face release retains ordinary grid simulation.
A parcel is never born in, enters, lands in
or moves inside an unselected simulation core (outcome `Paused`). A parcel
leaving an overfilled cell (more than 255 units) takes exactly one cell, and a
deposit never adds to an overfilled cell.

**Determinism and ownership.** Workers write only their own task's candidate
list and half-chunk counters, and capacity is reserved by the owner before
dispatch. Launches run in sorted strip order on the owner thread. Results are
identical for 1–8 workers and repeat runs, under ThreadSanitizer too. Paused
cells are solid to both the column pass and the spill receiver and support
tests. A spill World therefore evolves identically against a paused floor and
a wall. Original Wave keeps its known stale-support read there.

**Body push.** Two new fields control the force Wave Water offers to bodies:
`WaveFlowConfig::body_push` (n/256, 0–1024, default 256) and
`body_push_by_mass` (0/1, default 0). With the defaults, the original
per-wet-cell contact is unchanged. With `body_push_by_mass`, each resting or
leaning contact is scaled by its cell's mass up to one cell. The contact count
is unchanged. The Workbench applies Body push to Water contact, boundary pressure,
displacement, incoming parcel impulse and optional impact-spray launch reaction.
The launch reaction already scales by the exact launched quantity; it does not
receive another per-cell mass multiplier. Body push 0 suppresses these Water
forces without disabling parcel launches or ownership transfers.
These fields are observation-only: they never change Water state
and are not bound into identity.

**Diagnostics** (`WaveFlowDiagnostics`, appended): `spill_units`, `relief_units`,
`spill_faces`, `last_falling_units/cells`, `launched_parcels/units`,
`launch_refusals`, `launch_deferrals`, `launch_capacity_skips` and
`launch_nanoseconds`. The candidate lists are counted in `storage_bytes`.

**Identity.** The spill configuration and the back-off flag are bound into
`state_hash` and `physical_state_hash` only while spill is enabled. Parcels are
bound by the existing ballistic block. `clear()` resets the flag. Exact physical
save remains refused for every Wave World.

**Limits.** Spill is an approximation: grid-only spill drops straight down, and
only ballistic release throws Water outward. Parcels are one cell each, at most
`launch_budget` per tick and at most the pool capacity (4096) live. A face
beyond those limits keeps spilling through the grid. Sealed reservoirs, narrow
slots, sub-threshold films and contained pools are unchanged in kind, although
pool feed makes bulk levelling faster.

## State, memory and identity

| Storage | Per cell | Kind |
|---|---|---|
| Water mass | existing `state_a` | Authoritative; unchanged carrier. May briefly exceed 255 as overfill |
| Retained flux | `int32` | Authoritative, solver-owned |
| Head | `int32` | Derived, rebuilt every round |
| Meta (gain, full, solid, wet, depth class) | `uint8` | Derived, with previous-full support retained into the next column pass |

The dense side arrays add nine bytes per resident cell on the existing
eight-byte cell. Per-column dryness flags, chunk metadata, task/roster capacity
and reusable column scratch are additional; `storage_bytes` includes their
allocated capacities. Nothing is allocated for this law when disabled.

**Complete identity:** Wave Worlds report physical hash version **6**. The hash
includes solver version, substeps, round/dither phase, flux, previous support and
weight metadata, quiet/wake eligibility and the sparse skip state, in addition
to the ordinary cells, masks, regions, policies and quantity ledger. Diagnostic
timing, participant counts and allocation capacities are excluded. This Wave
identity also excludes the redundant Empty/zero-derived cache: its certificate
can only replace reads/writes of values already determined by hashed actual
cells, head and meta. Original clean/dry/sleep/flux state remains hashed exactly.
This does not add a physical-state serialization route. The Wave
identity deliberately binds resident solver chunks; legacy complete hashes keep
their existing empty-resident equivalence and byte stream. `state_hash` of a
Wave World binds the same solver state (version, substeps, round, flux, weight
and support metadata, sleep and skip state), so two Worlds with equal cells and
different retained momentum never share it; for every other World it keeps its
historical definition and value. `content_hash` remains the documented
cells-and-temperature projection and is not a continuation identity.

**Not persisted:** physical format version **0** means unsupported.
`save_physical_state` throws for a Wave World, and `restore_physical_state` rejects
Wave-enabled execution even if handed a valid legacy CYPS save. This prevents
both silently dropped flux and silently changing the selected law. CYSD1 demo
level copying/export and reconstruction are also explicitly refused for Wave:
that format has an 8-bit Water payload and cannot represent retained flux.
Copying refuses before clearing a transient mask or changing any native state.
Legacy save/restore semantics remain unchanged.

**Mass access:** `World::liquid_mass` and the additive
`cybersand_world_liquid_mass_v2` return uint16 without truncation. The existing
uint8 C accessor keeps its ABI and saturates at 255. Exact quantities use the
wide accessor or native quantity ledger. Wave-only `set_cell_state` accepts the
full uint16 mass carrier, which permits exact overfilled-cell edits and drains;
ordinary FreeMass setters keep their prior bounds.

## Admission and refusal

`World::World` throws `std::invalid_argument` before allocating wave storage
when wave flow is requested with any of:

- substeps outside 1–8;
- a backend other than phased in-place;
- any Water mass profile other than 8 bits;
- Water assigned to anything but `freemass_v1` (the fractional carrier);
- settled discovery, or the per-cell WCX-FR face release while Waterwall spill
  is enabled;
- spill tuning outside its bounds while spill is enabled;
- an odd storage chunk size;
- a configured custom cellular transport policy, whose cadence/direction
  semantics Wave does not implement.

A nonzero Water coherence byte is explicitly refused before mutation, including
a zero-mass Water tuple that would otherwise normalize to Empty. Ordinary
zero-mass erasure without coherence remains valid. Coherent jets require a
different law; accepting an immortal countdown would be misleading.
Wave chunk admission also refuses the extreme signed-coordinate fringe unless
there is one complete chunk of halo headroom before each int64 endpoint.
Neighbour growth at that bound records `boundary_refusals` and retains quantity;
it never wraps coordinates. Excessive column scratch index range throws an
explicit capacity error.

If a defect ever produced a mass the carrier cannot hold, the tick throws and
the World is quarantined as failed, rather than wrapping the value.

## What stays the same, and what does not

| Area | Under wave flow |
|---|---|
| Water material identity, density, render coverage from `state_a` | Unchanged |
| Other materials | Sand keeps its sinking law. Water wakes other materials where it arrives or leaves. Oil can exchange with Water directly above it. |
| Body masks | Solid to Water; Water under a mask is frozen, as today |
| Body contacts | Recorded when Water rests on a body or leans on its side, through the existing `record_transient_contact` |
| Water's own per-cell kernel | Bulk Wave owns Water motion. Oil schedules the vertical Water–Oil density exchange. Water-initiated pair chemistry and other Water-initiated density exchanges remain unsupported. Nonzero coherence is explicitly refused. |
| Floating rigid bodies | Wave supplies no upward body force. |

### Oil floating on Wave Water

When Oil touches Wave Water immediately above it, the heavier Water can sink one cell and lift the Oil into its place. This uses the existing density ordering and transports the full stored cells, including Water overfill, Oil state and temperature. Oil handles ignition and extinguishing first. Both endpoints must be visible to the simulation and eligible to move this tick. A solid obstruction or a body mask can shelter a pocket. The exchange requires neither spill nor ballistic release. An exposed Water edge still uses the configured release law.

Only a scheduled Oil cell checks for this contact. The Water worker count, Wave rounds and parcel budget do not control the rise rate. The owner prepares temperature storage for a warm exchange across a chunk edge before workers run.

Oil can flow into a lower opening. Once it rests on Water, or on one other Oil cell directly on Water, it stops taking random steps along the level surface. The second-row check uses the admitted two-cell rule radius. The column pass keeps floating Oil impermeable and omits the extra rigid-ceiling pressure response below it. A contiguous Oil layer pinned directly under a solid, body mask or paused region retains the rigid response. These rules allow surface spray to die out after a disturbance. [Tank measurements and Windows playtest](../audits/wave-oil-buoyancy-2026-11-19/evaluation.md) · [Source review](../audits/2026-11-19-wave-oil-buoyancy.md)

A thick floating Oil patch can spread over the pool. On the last Wave round, the column workers mark rows with at least three Oil cells directly on Water. After all workers and parcel launches finish, the owner can move the top Oil cell to a thinner part of the connected surface. Each move preserves the complete Oil cell and its temperature. The search reaches 16 columns in either direction, follows a rise or fall of at most one row per column, and checks up to 64 cells of Oil thickness. It needs open air above a Water-backed surface along the route. Walls, body masks, steep breaks and dry ground stop the search. The receiving layer must be at least two cells thinner than the donor. A uniform layer can settle and ordinary Wave Water continues to throw spray. Very deep deposits spread from eligible edges. [Radius-24 Oil and Lava replay](../audits/2026-11-19-wave-oil-lava.md)

An open Oil slick also follows the Water beneath it. In a rising column, once the top Water cell holds more than 1½ ordinary cells of volume, Water can lift the slick one row. As a wave recedes, less than ¼ cell of Water can drain into the full row below and lower the slick. The different thresholds prevent small fluctuations from repeatedly lifting and dropping a resting layer. The owner tests the actual Water quantities after the Wave and ballistic passes. It moves one complete Oil cell between the ends of the contiguous layer and accounts for the transferred Water. This applies to films one to 64 cells thick. A rigid cap, blocked path or paused boundary prevents the move. Consolidation on descent requires matching Water temperatures. [Saved impingement tank](../audits/2026-11-20-wave-oil-impinge.md)

Lava can initiate a quench when it touches Wave Water. Its Steam and Stone
products account for the full Water cell, including stored overfill. The
Workbench can keep reading spray and stepping the World after this reaction.
[Water quantity accounting](liquid-prepared-setup-and-receipts.md)

## Limits

- **Bulk surges are sedate.** At one round per tick a dam-break front moves
  about as fast as FreeMass. `substeps = 3` triples every speed for three times
  the Water work. Resulting-source benchmark CSVs, rather than inherited
  timings, determine the cost compared with other laws.
- **Waves are small-amplitude.** Above roughly four cells of amplitude the
  inertia limit turns wave motion into relaxation. Below roughly 3% of a cell
  the rest rules end a ripple quickly; films carry no waves.
- **Thin sheets drain slowly.** A sheet a cell or two deep on a long flat ledge
  takes tens of thousands of ticks to finish running off, and is solved (not
  asleep) until it has. The rested pool fixtures are level to one unit;
  supported adhesion residue can remain more uneven.
- **Falling Water loses sideways momentum**; waterfalls drop straight. Opt-in
  [Waterwall spill](#waterwall-spill-experimental-wave-waterwall-001) with
  ballistic release throws exposed-face Water outward as parcels.
- **Deep reservoirs drain through their top 32 rows and their exposed face.**
  Without spill, a tall exposed face can stand almost vertical for thousands of
  ticks (the "waterwall").
- **Water-owned material interactions are limited.** Sand can sink and active
  non-Water kernels can initiate their established reactions. Parked Water does
  not initiate erosion, corrosion or dissolution of passive hard materials;
  the BareIron regression records this intentional limit. It must not be
  advertised as complete material-interaction parity.
- **Exact running-state persistence and coherent emission are unavailable.**
  Reconstructing an authored evaluation scenario does not restore its flux.
- Real Rapier/Needle, source-built Godot, Windows package and sanitizer
  qualification are separate evidence levels in the completion record. Native
  mask tests alone do not establish a live Rapier result. Automated Godot
  execution does not establish physical-GPU human acceptance; Web is unqualified.

## Controls

| Setting | Default | Meaning |
|---|---|---|
| `WorldConfig::wave_flow.enabled` | `false` | Opt in at construction |
| `WorldConfig::wave_flow.substeps` | `1` | Rounds per tick, 1–8 |

The ordinary feature launcher has **Wave Flow**. The equivalent direct route is
`-- --wave-flow` or `res://wave_flow_evaluation.tscn`; the Windows evaluation ZIP
provides `Test It.cmd`. The [evaluation guide](../operations/wave-flow-evaluation.md)
owns the launch and scene walkthrough.

The evaluator constructs a fresh native World when **Reset scene** applies
Wave/FreeMass/Inertial/PressureFlow selection, workers, substeps and world size.
It exposes ten scenes, 256/512/1024/2048 sizes, 1–32 workers, 1–8 Wave substeps,
native pacing 1–120 Hz and Rapier pacing 30–120 Hz. **Run/Pause**, **Single tick**
and **Disturb pool** control the scenario. Native tick timing is reported
separately from presentation rate. `get_wave_flow_status` returns copied
selection, actual participants, timing, tasks, solved chunks, allocated storage
and quantity; `inspect_wave_flow_cell` copies stored/visible uint16 mass and
retained face flux. A replacement creates the Water law selected by its destination session.

Moving-body and Needle scenes own actual Rapier objects on Godot's main thread;
only their bounded transient masks/contact values cross into native simulation.
Needle retains its existing authored weight and thrust; **W/A/D/S** provide
thrust/turn/reverse. The evaluator uses native material publication, with no
cosmetic animation standing in for the solver.

Source: [`wave_flow.hpp`](../../native/include/cybersand/wave_flow.hpp),
[`world_wave.inc`](../../native/src/world_wave.inc); hooks in
[`world.cpp`](../../native/src/world.cpp) (`begin_tick`, `ensure_chunk`,
`rule_is_active`, `mark_cell_dirty`, `merge_job_effects`, body-mask edits).
Regressions: [`test_wave_flow.cpp`](../../native/tests/test_wave_flow.cpp)
(`make wave-flow-test`, `wave-flow-sanitize`, `wave-flow-thread-sanitize`).


## Workbench authoring tuning

Wave Flow remains an experimental overlay on the `freemass_v1` Water carrier,
but the development Workbench now exposes its kinetic tuning profile directly.
The historical qualified-v2 constants remain the defaults. A Workbench rebuild
may vary substeps, active response depth, open/confined gain, sealed stiffness,
normal/calm damping, coasting, levelling, sleep/wake thresholds, rest/stick
thresholds, calm threshold, sealed saturation mass, empty/wet donor shares and
surface-film scaling.

The fixed-point flux width, absolute head clamp, two-face safety rules and native
bounds are not authoring controls. Empty-pour and wet-flow share shifts are
bounded at one or greater so two opposing faces cannot overdraw one donor in one
apply pass. Active rows remain at most 32 because the per-cell depth code is a
three-bit derived field.

Changing any Wave tuning in Workbench constructs a new exclusive World and
retains the authored cell inventory through the existing prepared replacement
transaction. Retained Wave face momentum is intentionally not migrated: tuning
starts a new law state. Non-default tuning is included in `state_hash()` and
the physical identity. The exact qualified-v2 parameter point retains its
historical hash path.

Live Wave cells can contain more than 255 mass units after ordinary simulation
ticks. Prepared Wave reconstruction uses the explicit `WaveStored16` setup
domain: Water mass 1–65,535, coherence zero, and the unchanged eight-bit quantity
scale. This is selected only for enabled Wave Worlds and never enters Water
normalization. Retuning retains every stored mass unit; the generic fractional
and whole-cell setup limits remain unchanged. A live switch to a law that cannot
represent an overfilled Wave cell refuses without changing the old World. Use
**Load / reset scene** to compare that law from the same authored scene instead.

### Ordinary Workbench configuration ownership

The Water solver in `workbench_water_spray_panel.gd` stages requested values.
`Main.workbench_apply` passes their original types through the simulation owner
and `MicroScenarioHost.install` to
`CyberDemoBridge::prepare_liquid_candidate`. Native preparation validates the
complete request and owns a private candidate World. Successful commit swaps
that World once; refusal preserves the old World and its native state. A cleared
pending request is not evidence of acceptance: the copied application receipt
must positively acknowledge the matching request/generation.

Workbench's schema-1 Baseline transport is a resolved table, and `unpack()` marks
it configured. Wave's qualified law rejects custom transport. The adapter
therefore recognizes only the exact Baseline values (all pair fields, horizontal
limits, cadence and the native Mercury period) and maps that representation to
native default transport for Wave. A changed value remains a custom-policy
refusal. This resolves PR #631's initial activation failure without weakening
the native law's custom-transport restriction.

Pool workers are a bounded integer construction option, 1–32; changing the value
prepares a new pool before commit. Applied status is copied from the actual
World: enabled law, parameter values, substeps, configured workers, observed
participants, session generation, completed ticks/rounds, health, storage,
capacity refusals and native tick time. Participant counts describe observed
task claimants, not CPU utilization or simultaneous execution. Invalid types and
out-of-range values are explicit refusals, not silently substituted defaults.

Wave tuning is retained across ordinary scene reconstruction and restart from
the accepted construction settings. Unsubmitted or refused panel edits are not
an accepted reset state. Pause/resume does not reconstruct the World. An explicit
Apply or scene reset creates a new law state and clears retained face flux.
Its Wave tick counters and sleep state also restart; material reconstruction is not exact physical continuation. The panel keeps
Wave tuning separate from other Water-law settings and displays requested and
native values independently.

The [owner guide](../operations/wave-flow-evaluation.md) describes editable
comparison scenes and the ordinary Windows launcher. The
[dated finisher record](../audits/2026-11-16-wave-workbench-631-finisher.md)
retains the original failures; final-source execution and independent review
remain separate source-bound evidence.

## Waterwall 002 sheet, crest and scale-selective damping

The Draft/HOLD successor to #672 exposes four optional integers. Zero selects the preceding behavior for each control.

| Control | Native setting and bounds | Effect |
|---|---|---|
| Deep gain | `deep_gain`, 0–512 | Separate restoring gain for connected deep Water. Dry and shallow fronts use ordinary Gain. Zero inherits Gain. |
| Flux smoothing | `flux_smoothing`, 0–64 | Each connected neighboring wet face contributes its retained-flux difference multiplied by this value divided by 256. Missing neighbors contribute zero difference. |
| Sheet rate | `spill.sheet_rate`, 0–127 | An exposed resting row can shed this many units per full cell of outward head each round. Deep rows pour through the grid. The top two cell-equivalents can throw parcels. |
| Coyote ticks | `spill.coyote_ticks`, 0–8 | A launched top crest adds its outward face velocity to the throw and travels level for this many active flight ticks before gravity acts. |

The column pass snapshots retained flux into four additional bytes per resident Wave cell only when smoothing is selected. The existing barrier separates writes from neighbor reads. Adjacent faces in a broad wave carry similar flux, so the correction is small. At strength 64 an alternating pattern of equal and opposite retained fluxes cancels in one round. Dry gaps, walls and selection boundaries end the stencil.

Sheet discharge reuses falling Water, the active band and bounded parcel nominations. Two faces of a donor may each spend at most half of its starting mass. With either new spill control active, a face reserves its throw before spending the rest of its half-budget on a grid pour. Each receiving face also caps inflow to half the free space. Serial launch checks remaining Water, spawn path and pool capacity. A refused launch leaves its quantity in the grid. An active crest countdown is hashed as future physical state. See the [dated evidence](../audits/2026-11-19-wave-waterwall-002.md).

## Shallow Water on level ground

The shipping player profile sets `floor_gain` to 1024. In `World::wave_flux_task`, the extra restoring force acts only at a normal, shallow advancing face above a continuous level solid floor. The lower of the two heads must be less than one full cell. Each side must reach real solid material at the same depth within three rows. Every intervening cell must be full Water and included in the solved region. This allows the bottom of a breaking wave to spread as a low sheet. A floor step, an unsupported receiver or a solver boundary uses the ordinary flux law.

The adjusted head contribution is limited to one cell of Water. Retained flux, the two-face donor bound, uint16 receiver room and the existing apply pass still account for every moved unit. The solver reads existing settled metadata and allocates no new state. Zero disables this law and omits it from both state hashes. The [ramp evaluation](../audits/2026-11-19-wave-water-ramp-003.md) compares a single active floor row, three active rows and raising gain throughout the pool.

Normal desktop sandbox, new Shared Workbench and ordinary curated Web demo constructors request the gameplay Water bundle. The Play Session course and authored policy comparisons use their explicit experiment constructors. Plain native construction retains the historical baseline law. V2 Workbench starts save material assignments and the authored canvas. The Web CYSD1 format supports FreeMass new demos and legacy slots. Full physical persistence for a running Wave World remains unavailable.

## Full-face Waterwall release

With spill and ballistic release enabled, `spill.full_face=1` lets each exposed, supported Water row nominate an outward parcel, including through an adjacent falling curtain. Exposed means the adjacent cell is falling Water or unsupported Empty. Water against a solid or another resting column still uses its ordinary contact law. The raw configuration has `full_face=0`. The Water Face evaluation stages it on with fall speed 3. [Water Lab](../operations/workbench-water-lab.md#try-full-face-release-at-fall-speed-3)

Each side derives its allowance from its own donor before the grid and parcel split. A grid transfer has a second limit of half the receiving room. A parcel can pass through a filled, falling receiver, as its quantity is carried by the ballistic pool. The larger of Sheet rate and Stream share, in 256ths of the face allowance, reserves a grid portion. Stream draw can use the remaining allowance. The owner still withdraws from the donor after the apply pass. Refusals keep their Water in the grid. The crest alone receives coyote flight.

A strip can retain up to 512 nominations. On overflow, full-face mode uses deterministic reservoir sampling across visited heights. The serial owner distributes the remaining launch quota through the retained nominations. Both stages count capacity deferrals. The pool and per-tick launch limits still apply. Every exposed row can participate over time. The number of simultaneous jets depends on available slots, Water quantity and geometry. [Measured face coverage and capacity tests](../audits/2026-11-19-wave-water-face-004.md)

## Deep pool feed and ramp crest direction

Adjacent horizontal faces can draw Water away from the same donor in opposite directions. With strong pool feed this can leave a narrow, almost empty column flanked by Water, making the upstream side of a moving crest unusually abrupt. The visible crest and the net quantity passing a point can travel in different directions. The [ramp replay](../audits/2026-11-19-wave-water-face-004.md) measures both independently.

The staged **Deep pool feed** control (`spill.deep_draw`, 0–127) limits the extra wet-to-wet pool feed when either connected stack has five or more responding rows. A zero value inherits ordinary Pool feed at all depths. In the evaluation profile the deep limit is 64 and ordinary Pool feed is 127. A face whose responding stacks stay below five rows still receives the selected shallow feed. Floor gain retains its existing level-ground rule. The limit does not reduce the ordinary Coast allowance or increase a lower Pool feed. Wall discharge and parcel flight use their separate existing budgets.
