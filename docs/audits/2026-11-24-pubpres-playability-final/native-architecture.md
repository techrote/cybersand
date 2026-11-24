# PUBPRES final native architecture investigation — 24 November 2026

Status: **Draft/HOLD candidate; physical playability not yet established.**
Frozen predecessor: `c90dbc46e1f57f28e06b1f4205b83467335ff657`.
This dated evidence record does not promote any default, merge or runtime.

## Selected causal repair for qualification

The Workbench adapter allocates its transient obstacle field for the entire
finite canvas (`cyber_native_cell_world.cpp`, construction near line 2054).
`wave_column_task` used that allocation's rectangle to decide where to call
`transient_obstacle_at`. One small actor therefore caused a column pass to
probe every cell in the allocated canvas, in each Wave round. Most calls
returned zero. This is distinct from the previously rejected column tiling,
conditional metadata stores, fixed clipped-loop bounds and task pairing.

The candidate computes an exact occupied bounding rectangle from the existing
`occupied_indices` list once on the exclusive World owner before any Wave
dispatch. The column pass intersects that rectangle with its strip and probes
only the resulting rows/columns. The original allocated rectangle continues to
govern dry columns, clean halves and derived metadata. All original gathers,
settling, flux, scatter, pressure, material writes and barriers remain present.
No extra worker, lock, per-cell allocation, simulation tick or physical credit
is introduced. Retained native Wave storage increases by one rectangle plus
alignment (40 bytes in the measured local GCC build), independently of canvas
size and actor count.

### Why the omitted lookups must return zero

`World::set_transient_obstacle` admits only a valid nonzero body ID into a
previously zero field entry, then records exactly that index. Duplicate,
out-of-region and zero-ID attempts do not alter the list. The only clearing
operation visits the same index list before clearing it. No other writer to
this private field participates during a World tick. Consequently every
nonzero entry belongs to the list and lies within its min/max rectangle.
Outside that rectangle, the existing lookup necessarily returns zero.

The bounds are rebuilt on each tick, so clear/move/reconfigure and replacement
cannot retain a previous body's bounds. Entries originate from representable
signed world positions; translating their minimum local indices back into world
coordinates is safe even when the *allocated* rectangle's mathematical endpoint
extends beyond int64. The implementation never forms that allocated endpoint.
Existing unsigned-distance clipping handles distant and signed-edge strips.

## Why stale terrain alone cannot license extra Rapier steps

The exact-sample fence in `main.gd` near lines 2339–2378 is part of a larger
dependency. `simulation_worker.gd` near lines 2952–2971 prepares occupancy from
the copied body sample. `workbench_granular_coupling.inc` lines 118–136 replaces
`current_bodies_` and invokes ordinary body coupling for that sample.
`main.gd` near lines 5111–5128 publishes the next actual post-step body state.

Reusing a matching hard-surface revision proves only collider identity. It does
not prove that a moving body's new position is clear of native materials while
the worker continues using its old endpoint mask. It also does not qualify new
equipment origins or body/material displacement and impulses. The Workbench
bridge's response age, duplicate and geometry guards are rejection mechanisms,
not a fresh-state lease. Compound authored entry-face inference additionally
depends on consecutive body sample serials.

A safe decoupled empty-space lease would need an exclusive-native certificate
covering every body's reachable swept geometry, rotations and equipment reach;
all possible incoming material/ballistic work; relevant terrain and ownership;
and edit/replacement cancellation before any affected work. The current
snapshot contains no such certificate. Wave refill can propagate along an
entire column, so a generic three-cell material-kernel halo cannot prove the
required bound. Holding native idle while advancing extra Rapier steps would
instead suppress required native work and change the coupled cadence. Neither
intervention is selected as a shortcut to responsive counters.

## Independent review and source tests

The physics/presentation specialist independently checked the private field's
write/clear paths, ownership/barrier ordering, signed coordinate proof and
preservation of the original dry/clean classifications. No source blocker was
found. Required challenges include moving and absent masks, separated bodies,
negative coordinates, chunk seams, partial-region re-entry and signed endpoints.

The new `sparse_mask_bounds_follow_clear_move_and_reconfigure` native regression
shrinks and expands actual occupancy across three separated shafts, clears all
bodies, reconfigures storage, and challenges duplicate/zero/outside IDs. It
checks actual Water blocking and downward body pressure, then compares complete
physical and state hashes across one and four workers. The existing signed-edge
mask test exercises mathematical allocated endpoints beyond int64 while only
admitting representable body cells. Both targeted tests passed locally.

The complete Wave, spill and body-boundary suites, sanitizer results and final
source/runtime identities belong in the resulting final qualification packet.
No unexecuted gate is treated as passing by this source record.

## Prospective native comparison

`native/bench/pubpres_mask_bounds.cpp` is an explicit native-only causal screen.
It uses current two-round Wave/spill/ballistics or a separately labelled
historical one-round control, full-canvas obstacle storage, deterministic moving
body masks, complete World ticks, Water/parcel conservation, actual task
participants, complete physical/state/content hashes and body-pressure
checkpoints. It does not simulate Rapier, render frames or measure input feel.

Before timing, build the unchanged native predecessor and candidate independently
with identical GCC 14.2 flags and the identical apparatus file. Run fresh
processes sequentially in A/B/B/A order, 72 native ticks each, four configured
workers. Registered cohorts: current 512/1024/2048 with one body; historical 512
with one body; current 2048 with zero and eight bodies. Retain every ordered arm.
No tests or compilation run concurrently with the timing cohort.

Admission requires identical complete checkpoint arrays, conservation and native
health. The source supports a repeatable native gain only if both candidate
mean complete-tick times improve over both controls in the principal masked
2048 cohort, with no repeated smaller-workload regression. Mixed tails remain
explicit. This screen cannot establish the programme's whole-gameplay target;
source-exact ordinary Workbench and physical Windows/NVIDIA acceptance remain
separate requirements.
