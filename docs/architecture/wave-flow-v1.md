---
title: Wave flow Water solver (experimental)
status: Current
document-kind: reference
scope: Experimental-branch WAVE-MT-001 wave_flow_v1 opt-in bulk strip-parallel Water law; mechanism, ownership, parallel execution, state and memory, admission and refusal, limits and the candidate comparison that selected it; not on main, no default changed, not a policy family yet
canonical-for: [wave-flow-v1]
last-reviewed: 2026-11-15
related-documents: [liquid-solver-family-policy.md, pressure-flow-v1.md, inertial-cellular-v1.md, simulation-tick-and-threading.md, rigid-body-and-cellular-coupling.md, ../audits/2026-11-15-wave-mt-001-wave-flow.md]
---

# Wave flow Water solver (experimental)

**Status:** implemented on the experimental branch
`claude/cybersand-wave-mt-001-9d38c0` (Draft PR), **not on main**. It is opt-in
through `WorldConfig::wave_flow`; a World that does not enable it keeps its
Current kernels, hashes, formats and behaviour, and allocates nothing for it.
It is **not** a fifth `LiquidSolverPolicy` family yet, has no Godot selection
path and no persistence. Measurements and negative results are in the
[dated evidence record](../audits/2026-11-15-wave-mt-001-wave-flow.md).

## What it is, in one paragraph

Every existing Water law visits Water one cell at a time through the generic
kernel dispatch, which costs roughly 300–700 ns per visited cell. `wave_flow_v1`
instead solves all Water in bulk, in three simple passes over column strips,
and keeps one extra number per cell: the **flux** through its right-hand face.
Because that flux is remembered from tick to tick, a disturbance keeps moving
after the push that caused it. That remembered motion is what makes real waves:
two disturbances pass through each other, add where crests meet and cancel
where a crest meets a trough. There is no pressure solve, flood fill, gas
compartment or head field.

## Why this candidate

Three families were compared before code was integrated
([evidence](../audits/2026-11-15-wave-mt-001-wave-flow.md#candidate-comparison)).

| Candidate | Finding | Outcome |
|---|---|---|
| A. Parallelise `pressure_flow_v1` | At 2048² the cached+dormant variant measured 2.1 ticks/s on one worker and 5.7 on four in a dam break, and 8.5 ticks/s for a pool that is **at rest**. The cost is spread over serial preparation and the per-cell kernel, so more workers cannot reach the target | Not pursued |
| B. Whole-cell transport plus a separate coarse wave layer | A single height per column cannot describe caves, overhangs and stacked pools; whole cells quantise wave height to one cell, too coarse for interference | Analysed, not built |
| C. Local conserved mass with retained face flux | Standalone prototype: exact conservation, measured constructive and destructive interference, about five times faster than A on one worker before any optimisation | **Selected** |
| C without retained flux (ablation) | Levels correctly but transmits no wave at all | Rejected: momentum is what buys waves |

## The law

Mass is the existing fractional Water carrier (`state_a`, 255 = one full cell).
One round is three barriers. Each strip owns a 64-column band of a column of
chunks.

1. **Column pass** (owns its columns). For each column, bottom-up:
   - loose Water falls one cell;
   - a stack of full cells is treated as connected: a deficit left by sideways
     outflow is refilled from above in the same pass, so a deep pool never
     splits into two "surfaces";
   - excess is carried up to the surface, or stays as overfill under a solid
     ceiling.

   Then, top-down, it derives each cell's **head**: the weight of the liquid
   resting on that cell's floor. Only a full cell carries what rests on it, so
   a falling curtain of thin cells exerts no pressure.
2. **Flux pass** (owns its faces). For each face between two cells in the same
   row: `flux += gain × (head left − head right)`, minus 1/128 damping, then
   limited (below). Only the top 32 rows of a stack respond to head.
3. **Apply pass** (owns its cells). Each cell gains what its left face carries
   and loses what its right face carries. Both sides evaluate the same pure
   function of the face, so mass is conserved exactly.

Why head is "weight above" rather than "height of the surface": moving one unit
sideways in a row then changes potential energy by exactly the head difference,
for any mixture of full, thin and falling cells. The retained flux therefore
cannot gain energy from a mis-stated surface. Three earlier variants that used
a surface height each pumped energy into the pool
([negative results](../audits/2026-11-15-wave-mt-001-wave-flow.md#negative-results)).

### Limits that keep it stable

| Limit | Value | Reason |
|---|---|---|
| Responding rows per stack | 32 | Gravity can stay a true constant (wave speed ≤ ½ cell per round) instead of weakening with depth, which pumped energy |
| Inertia per face (`kCoast`) | 16 units per round | Small flows keep their momentum and make waves; large flows relax without overshoot |
| Downhill share | head difference ÷ (8 × responding rows) | The explicit-diffusion bound: two columns cannot swap places in one round |
| Pour into an empty cell | ¼ of the source cell | A pair of columns cannot invert |
| Dry-floor film | 24 units | A spill does not thin out forever |

These are **bounded-approximation choices**, not physics. Their visible cost is
that bulk surges are sedate at one round per tick; see [limits](#limits).

### Sealed passages

Water under a solid ceiling cannot rise, so inflow there becomes overfill. The
overfill adds head (stiffly, scaled by how many rows can respond) and pushes
onward. This gives U-tube equalisation with no pressure field. Its cost is that
a sealed passage temporarily stores a little extra Water as overfill.

## Parallel execution

- Runs inside `World::begin_tick`, on the **existing** persistent worker pool,
  before the generic phased scheduler. No new threads.
- Tasks are disjoint column strips. No pass reads anything another strip
  writes in that pass. There are no per-cell locks or atomics.
- No pass depends on task order, so **every worker count produces identical
  cells**. A regression compares 1, 2, 4 and 6 workers cell by cell.
- `TickStats::worker_threads_observed` and `WaveFlowDiagnostics::maximum_participants`
  report actual pool participants, not configured capacity.

### Sparse work

- A chunk is solved while its Water moved recently, or an owner edit, kernel
  write or body mask touched it; its eight neighbours are solved with it. After
  30 quiet ticks it stops. A level pool costs nothing.
- Inside a solved chunk, a column with no Water is skipped, and a half-chunk
  that is entirely empty is skipped.
- Workers never allocate. Before the passes the owner admits any missing
  neighbour chunk that liquid on a chunk edge needs. If
  `maximum_chunk_count` is reached the neighbour stays a wall: an explicit
  capacity outcome, with the quantity unchanged.

## State, memory and identity

| Storage | Per cell | Kind |
|---|---|---|
| Water mass | existing `state_a` | Authoritative; unchanged carrier. May briefly exceed 255 as overfill |
| Retained flux | `int32` | Authoritative, solver-owned |
| Head | `int32` | Derived, rebuilt every round |
| Meta (gain, full, solid, wet, depth class) | `uint8` | Derived |

Nine extra bytes per cell on the eight-byte cell, allocated only in a
wave-flow World. Narrowing flux and head to 16 bits is a known follow-up.

**Not persisted.** `save_physical_state` throws for a wave-flow World, because
the retained flux has no registered CYPS section. Refusing is deliberate:
writing a save that silently dropped authoritative state would be worse.

## Admission and refusal

`World::World` throws `std::invalid_argument` before allocating wave storage
when wave flow is requested with any of:

- substeps outside 1–8;
- a backend other than phased in-place;
- Water mass narrower than 8 bits;
- Water assigned to anything but `freemass_v1` (the fractional carrier);
- settled discovery, or `ballistic_water_v1`.

If a defect ever produced a mass the carrier cannot hold, the tick throws and
the World is quarantined as failed, rather than wrapping the value.

## What stays the same, and what does not

| Area | Under wave flow |
|---|---|
| Water material identity, density, render coverage from `state_a` | Unchanged |
| Other materials' kernels (Sand sinking, reactions seen from the other material) | Unchanged; they are woken where Water arrives or leaves |
| Body masks | Solid to Water; Water under a mask is frozen, as today |
| Body contacts | Recorded when Water rests on a body or leans on its side, through the existing `record_transient_contact` |
| Water's own per-cell kernel | **Does not run**: no coherence countdown, no Water-initiated pair chemistry, no Water sinking through lighter fluids |
| Buoyancy | **None**, as in FreeMass: nothing pushes a body up |

## Limits

- **Bulk surges are sedate.** At one round per tick a dam-break front moves
  about as fast as FreeMass. `substeps = 3` triples every speed for three times
  the Water cost, which is still far below the existing solvers.
- **Waves are small-amplitude.** Above roughly four cells of amplitude the
  inertia limit turns wave motion into relaxation.
- **Falling Water loses sideways momentum**; waterfalls drop straight.
- **Deep reservoirs drain through their top 32 rows and their exposed face.**
- Not qualified against real Rapier bodies, in Godot, on Web, or by a person
  looking at it running.

## Controls

| Setting | Default | Meaning |
|---|---|---|
| `WorldConfig::wave_flow.enabled` | `false` | Opt in at construction |
| `WorldConfig::wave_flow.substeps` | `1` | Rounds per tick, 1–8 |

Source: [`wave_flow.hpp`](../../native/include/cybersand/wave_flow.hpp),
[`world_wave.inc`](../../native/src/world_wave.inc); hooks in
[`world.cpp`](../../native/src/world.cpp) (`begin_tick`, `ensure_chunk`,
`rule_is_active`, `mark_cell_dirty`, `merge_job_effects`, body-mask edits).
Regressions: [`test_wave_flow.cpp`](../../native/tests/test_wave_flow.cpp)
(`make wave-flow-test`, `wave-flow-sanitize`, `wave-flow-thread-sanitize`).
