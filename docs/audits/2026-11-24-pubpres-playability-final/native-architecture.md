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

The complete native Wave suite passed **34/34**, and the complete spill suite
passed **47/47**, locally on the candidate native source below. The complete
body-boundary suite passed **50 runs / 6,000 ticks**, covering two seeds, three
boundary modes, substeps 1/3 and workers 1/2/4/6, with checkpoint parity.
[Safety receipts](native-safety-receipts.json) retain complete diagnostic output
and executable hashes.

The full ASan/UBSan Wave process emitted all 34 fixture PASS lines without a
memory/undefined-behavior diagnostic, then LeakSanitizer terminated with its
explicit ptrace-environment fatal error. **The complete sanitizer run is not a
pass.** The new sparse-mask and existing signed-endpoint fixtures subsequently
passed as separately scoped ASan/UBSan processes with `detect_leaks=0`; that
establishes no leak acceptance. Full source-exact hosted sanitizer/leak gates
remain required. No failed or unexecuted gate is treated as passing.

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


## Retained native ABBA result

Execution: 24 November 2026, 15:48:08–15:49:54 UTC, local Linux development
host. All 24 fresh processes completed successfully, used four observed native
participants and retained identical physical/state/content/contact checkpoint
arrays within each matched cohort. Each process independently enforced complete
Water plus in-flight-parcel conservation on every tick. The physical checksums
include retained Wave flux, weights, metadata, dry/clean marks and wake state;
cell-image equality alone was not the admission rule.

The [byte-exact benchmark outputs and execution manifest](native-abba-receipts.json)
retain every arm, original stdout/stderr, output digests, exact native source
identities, compiler flags and independently built binary digests. Reproduce the
reduction with:

```sh
python3 tools/pubpres_final/native_abba.py \
  docs/audits/2026-11-24-pubpres-playability-final/native-abba-receipts.json \
  --output /tmp/pubpres-native-reduction.json
```

The [reduction](native-abba-reduction.json) and
[independent qualification specialist review](native-independent-review.json)
retain all per-process timing metrics. The following values are mean complete
native tick times in milliseconds, preserving the two runs for each source:

| Cohort | Frozen A means | Candidate B means | Change in mean across both runs | Both B means below both A means |
|---|---:|---:|---:|---|
| Current 512, one body | 7.308 / 7.516 | 7.226 / 6.866 | −4.94% | Yes |
| Current 1024, one body | 23.167 / 27.339 | 21.097 / 20.493 | −17.65% | Yes |
| Current 2048, one body | 94.110 / 109.393 | 83.245 / 81.863 | −18.87% | Yes |
| Historical 512, one body | 2.574 / 2.857 | 2.431 / 2.542 | −8.45% | Yes |
| Current 2048, zero bodies | 46.676 / 42.211 | 47.437 / 46.009 | +5.13% | No |
| Current 2048, eight bodies | 98.550 / 123.338 | 81.845 / 129.926 | −4.56% | No |

Only the current 2048 one-body cohort consistently improves mean, p50, p95,
p99 and maximum across both candidate runs versus both controls. Its column
phase means fall from 75.608/87.386 ms to 61.144/60.729 ms, consistent with the
removed zero-valued mask queries being a real native contributor.

There is **no broad native latency or whole-gameplay pass**. Current 512
candidate p95 is 9.359/10.367 ms versus 8.718/9.219 ms, and one candidate maximum
is 71.566 ms versus control maxima 22.099/14.828 ms. Current 1024 and historical
512 have mixed tail direction despite lower mean times. The zero-body control
has a higher paired mean and mixed tails. Eight-body candidate p95 is
92.209/194.709 ms versus 108.187/166.837 ms; candidate maxima are
125.941/214.876 ms versus 112.897/175.807 ms. Its adverse candidate run is retained
and prevents a repeatable multi-actor gain claim. No measured host-interference
witness licenses dismissing those runs as environmental noise.

These short processes emit nearest-rank per-process percentiles. With 72 ticks,
p99 is the maximum. Individual per-tick clock arrays were not captured, so the
independent reviewer can verify every reported aggregate and compare arms, but
cannot recompute those quantiles from original clocks. The reducer does not pool
or interpolate these values, and this evidence is not interchangeable with the
separate graphical reducer's timing convention. The team suspended its local
builds/tests during this sequence; the shared host itself was not controlled.

### Exact local source and runtime identities

- Frozen native source: `c90dbc46e1f57f28e06b1f4205b83467335ff657`.
- Candidate native source: `7e983d170aabb06c1b9d48788d5a8e416c3afd3e`.
- Candidate tree: `c339e062110b83dc67bcc10b7c7787e62e4ef802`.
- Shared benchmark apparatus SHA-256: `ef3f6f15ca4efc03824c75ab85603ac457b5448383f6f3747c8552c5c51f2fe6`.
- Frozen native diagnostic executable SHA-256: `110b269d67af1e535fc1e431fc6797c1e30b32e6d45f7b2c89ae99dd1ff5dc11`.
- Candidate native diagnostic executable SHA-256: `83ccc7b68e0d106c59616a2745d6a57753016f506338282ffbb112015bd6def8`.
- Compiler: `g++ (Debian 14.2.0-19) 14.2.0`; flags `-std=c++20 -O3 -DNDEBUG -pthread`.

The benchmark at the candidate commit was compiled unchanged against each
source's independent native include/source tree. This local compiler is not the
pinned hosted qualification toolchain; these executables are native diagnostics,
not Godot runtimes or deliverable evaluator libraries. Retained Wave storage
increased by exactly 40 bytes in every cohort, including 55,912,000 to
55,912,040 bytes for 2048. The new 32-byte rectangle adds eight bytes of layout
padding between existing fields on this measured build; no vector capacity or
per-cell allocation changed.
