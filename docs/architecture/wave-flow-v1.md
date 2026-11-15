---
title: Wave flow Water solver (experimental)
status: Current
document-kind: reference
scope: Experimental-branch WAVE-MT-001 wave_flow_v1 opt-in bulk strip-parallel Water law; mechanism, ownership, parallel execution, state and memory, admission and refusal, limits and the candidate comparison that selected it; not on main, no default changed, not a policy family yet
canonical-for: [wave-flow-v1]
last-reviewed: 2026-11-15
related-documents: [liquid-solver-family-policy.md, pressure-flow-v1.md, inertial-cellular-v1.md, simulation-tick-and-threading.md, rigid-body-and-cellular-coupling.md, ../audits/2026-11-15-wave-mt-001-wave-flow.md, ../audits/2026-11-15-wave-mt-001-completion.md]
---

# Wave flow Water solver (experimental)

**Status:** experimental implementation on PR #618,
`codex/wave-mt-001-parallel-20261115`, **not on main**. The independent original
Claude PR #617 remains separate. `WorldConfig::wave_flow` opts in; a World that
does not enable it keeps its existing kernels, physical hashes and save formats,
and allocates no Wave storage. This is not another `LiquidSolverPolicy` family
and does not change the default Water solver.

The additive C API and Godot evaluator expose the experimental law, worker and
substep selection, representative scenarios and copied native diagnostics.
Exact physical save/restore remains explicitly unsupported; authored scenarios
can be reconstructed, but this is not continuation of a running Wave World.
The [completion evidence](../audits/2026-11-15-wave-mt-001-completion.md) owns
actual resulting-source qualification. The
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
   threshold that is spread evenly over the rows of a column and over
   successive rounds, so the rows of one face together move the rounded total.

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
| Evenly spread rounding | additive sequence over rows and rounds, per-column offset | The rows of a face move the rounded total, not a random sample of it: far less noise, same average, rows still out of step |
| Calm band (`kCalm`) | flux below ⅛ unit per round loses ⅛ per round | Absorbs what rounding leaves behind. A real wave is in this range only near its turning points, where its energy is in the heads |
| Rest rule (`kRestHead`, `kStick`) | heads within 1 unit and flux in the calm band → flux is discarded | One unit cannot level a one-unit step (it only flips it). What remains moves a unit only down a step of two or more, which strictly levels and therefore ends |
| Films | two partly filled cells that both rest on a solid floor exchange ¼ of their difference per round, at least one unit, with no momentum | Less than a cell of Water carries no wave worth keeping, and with momentum it crept for tens of thousands of ticks |

Rest is exact: no cell changes and every retained flux is zero. That state is a
fixed point of the three passes, so a chunk at rest can stop being solved
without changing any later result. Measured consequences are in the
[completion record](../audits/2026-11-15-wave-mt-001-completion.md#2026-11-15-claude-review-rest-and-identity-repair).

The costs are deliberate and bounded. Rested columns may differ by one unit
(1/255 of a cell) from their neighbours. Ripples whose flux never leaves the
calm band (roughly 8 units of amplitude, 3% of a cell) die within tens of
ticks instead of fading slowly. A film has no waves at all.

### Limits that keep it stable

| Limit | Value | Reason |
|---|---|---|
| Responding rows per stack | 32 | Gravity can stay a true constant (wave speed ≤ ½ cell per round) instead of weakening with depth, which pumped energy |
| Inertia per face (`kCoast`) | 16 units per round | Small flows keep their momentum and make waves; large flows relax without overshoot |
| Downhill share | head difference ÷ (8 × responding rows) | The explicit-diffusion bound: two columns cannot swap places in one round |
| Pour into an empty cell | ¼ of the source cell | A pair of columns cannot invert |
| Residual film | A cell resting on a solid floor keeps 24 units with adhesion enabled; zero with it disabled | A supported spill does not thin out forever, on a floor or at the edge of a ledge (the per-cell Water law's rule) |
| Receiver capacity | At most half its remaining uint16 capacity from each adjacent face | Simultaneous arrivals cannot overflow a cell |
| Sealed-stack inflow stop | Top mass at least 32,000 units | Stops additional inflow before the carrier limit |
| Derived head | At most 2²⁶ units | Bounds arithmetic for extreme legal sealed columns |

These are **bounded-approximation choices**, not physics. Their visible cost is
that bulk surges are sedate at one round per tick; see [limits](#limits).

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
- settled discovery, or `ballistic_water_v1`;
- an odd storage chunk size;
- a configured custom cellular transport policy, whose cadence/direction
  semantics Wave does not implement.

A nonzero Water coherence byte is explicitly refused before mutation. Coherent
jets require a different law; accepting an immortal countdown would be misleading.
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
| Other materials' kernels (Sand sinking, reactions seen from the other material) | Unchanged; they are woken where Water arrives or leaves |
| Body masks | Solid to Water; Water under a mask is frozen, as today |
| Body contacts | Recorded when Water rests on a body or leans on its side, through the existing `record_transient_contact` |
| Water's own per-cell kernel | **Does not run**: Water-initiated pair chemistry and Water-initiated exchange through lighter fluids are unsupported. Nonzero coherence is explicitly refused |
| Buoyancy | **None**, as in FreeMass: nothing pushes a body up |

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
  asleep) until it has. Rested Water is level to one unit, not exactly level.
- **Falling Water loses sideways momentum**; waterfalls drop straight.
- **Deep reservoirs drain through their top 32 rows and their exposed face.**
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
retained face flux. Returning to the ordinary demo retires the opt-in law.

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
