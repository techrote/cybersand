# Water pressure / trapped-air prototype (experiment record, not production)

Research prototype for a faster, levelling Water flow with trapped-air pressure, built
2026-10-19..22 outside production source. **Nothing under `native/`, `godot/` or `docs/`
is changed on this branch.** Integration is the owner's decision; a head/pressure
mechanism is #45 territory, gated by #49/#95 (see AGENTS.md "Water successor safety").

Layout:
- `patches/perf-vs-620826f.diff` - the uncommitted "perf" working tree the prototype was
  built on (main checkout at 620826f, Water perf changes). Apply first.
- `patches/prototype-v5-vs-perf.diff` - the prototype (v5) on top of that.
  From a checkout of 620826f: `patch -p1 < patches/perf-vs-620826f.diff` then
  `patch -p1 < patches/prototype-v5-vs-perf.diff` (verified to reproduce the v5 sources).
- `src/` - readable copies of the new files (`water_proto.hpp` params from env,
  `water_proto_b.inc` pre-pass + kernel).
- `bench/water_lab.cpp` - probe (scenes pool calm cloud rain column utube basin bell
  chamber sealed strokes cavity deep dome); `large_scene.cpp`, `box_check.cpp`,
  `sampler.hpp` (sampling profiler).
- `sandbox/water_sandbox.cpp` - standalone Win32 sandbox; `build_probe.bat`,
  `build_sandbox.bat` (MSVC BuildTools 2022), `suite2.sh`, `grid.py`, `results/` sweeps.

Run: `build_probe.bat <out> <patched native> bench\water_lab.cpp`, then
`probe.exe <scene> <ticks> <workers>` (env LAB_QUIET, LAB_EVERY, LAB_DUMP, LAB_KEEP,
LAB_QUIETTICKS, LAB_THRESH, LAB_CORE; W* params in `src/water_proto.hpp`).
Sandboxes are built locally to `build/water-sandbox/` (ignored): `9-pressure-air-v5.exe`
(current), `8-pressure-air-v5-bell-cycle.exe` (v5 before the full-height box fix).

The development log below was written alongside the work (dated addenda; later entries
supersede earlier defaults).

---

# Water flow prototype: snapshot pressure + velocity + overfill (scratch only)

Date 2026-10-19. Prototype lives only in a scratch copy of `native/` taken from the
`mat/material-fidelity-pass-2` working tree (perf changes included). No production
source, Godot fixture or doc was changed. Integration is the owner's decision; a
head/pressure mechanism is #45 territory (gated by #49/#95 per AGENTS.md).

Files here: `prototype-vs-perf-working-tree.diff` (apply to the perf working tree's
`native/`), `water_proto_b.inc` + `water_proto.hpp` (kernel, pre-pass, params),
`water_lab.cpp` (probe: pool|calm|cloud|rain|column|utube|basin), `box_check.cpp`
(body-mask check), `water_sandbox.cpp`, `grid1.txt`/`grid2.txt` (parameter sweeps),
`build_probe.bat`/`build_sandbox.bat` (MSVC BuildTools 2022 vcvars64).

Sandboxes: `C:\khybersand\build\water-sandbox\4-current-scenes.exe` (current perf
Water) and `5-pressure.exe` (prototype). Keys: 1 slab drop, 2 dam (D removes dam),
3 rain cloud, 4 U-tube, 5 standing column, 6 basin mound, B floating box at cursor,
V overlay (orange = overfill, green/purple = right/left velocity), Space/N/F.

## Results (384x256 basin, 1 worker, MSVC /O2, same machine, sequential runs)

level = first tick column spread <=1 cell that stays; sleep = 0 active blocks that
stays; 0 = not reached within the run. Mass exact (integer, incl. hidden overfill)
in every run of every build.

| scenario (ticks) | HEAD/perf level/sleep, final spread | prior momentum proto | prototype level/sleep, spread |
|---|---|---|---|
| pool slab drop (2400) | 0/0, 14.86 | 2090/0, 0.98 | **897/1339**, 0.80 |
| calm (600) | 1/3 | 1/3 | 1/3 |
| standing column (2400) | 0/0, 36.05 | 0/0, 11.22 | **622/1263**, 0.67 |
| U-tube (4000) | no flow at all (160 cells) | no flow | **3907**/0, 0.51 (9000: still not asleep, 26 blocks) |
| shallow basin mound (2400) | 0/0, 18.87 | 2208/0 | **405/759**, 0.38 |
| cloud (1500) | 0/0, 15.81 | 0/0, 1.09 | **590/1008**, 0.34 |
| rain (800) | 250/457 | 252/549 | 248/**367** |

Late churn (cells changed/tick, last quarter): HEAD pool 388, column 428, basin 401,
cloud 380 -> prototype 0 in all except U-tube (286).

Cost, ms/tick averaged over the run (1 worker): pool 3.48 -> 6.46 (p95 3.8 -> 14.6),
column 2.43 -> 1.52, basin 2.31 -> 1.01, cloud 2.40 -> 2.07, rain 0.21 -> 0.38,
calm 0.045 -> 0.052, U-tube 0.01 (HEAD does nothing) -> 16. Steady state (settled)
is free in both (asleep). While deep water is actually flowing the prototype costs
~3-4x HEAD per tick (pool first 1200 ticks: 13.4 vs 3.5 ms); the pre-pass is
~0.58 ms of that, the rest is genuine bulk transport (lateral moves into full cells
+ refill chains). Shallow scenes are cheaper overall because they finish.

Determinism: identical full-cell hashes (material, state_a, state_b, spare bits)
for 1, 2 and 4 workers in pool, U-tube, cloud, column, rain. All reads/writes are
radius <= 2 except the new serial pre-pass, which only reads tick-start cells.

Body coupling (`box_check.cpp`, toy buoyant 16x16 body mask on the slab-drop pool):
mass exact, contact rate equal to HEAD (~38 contacts/tick), box floats in both.
Prototype keeps ~60 blocks awake around the box (HEAD ~37) and surface waves push it
sideways less than HEAD's skin waves. Not a Rapier test; Godot not run.

## Recommended mechanism (tier B "snapshot head")

1. Serial read-only pre-pass after `gather_active_cores`, over the active cores'
   bounding box + radius-2 halo, from the tick-start cells:
   - per vertical Water run: settled head per cell
     `max(0, run_total - (floor - y) * 255)` = free-surface elevation over that row,
     independent of where holes/overfill in transit sit inside the run;
   - runs under a solid/body ceiling take their row's head interpolated between the
     nearest open runs (exact at rest, pipe gradient while flowing; makes U-tubes work);
   - unsupported runs are in free fall (no pressure); run length kept for gain/drag.
   Same snapshot for every core and phase => no seam disagreement (the earlier
   1-row/tick depth relaxation failed exactly here).
2. Kernel: gravity as HEAD; overfill is relayed upward in the same tick (receiver not
   epoch-marked) and held under bodies/ceilings; velocity u += G*grad/(64*max(H,4))
   with a radius-2 smoothed gradient and a head dead band (10 mass units), dithered
   (spatially coherent, 64-column) sub-unit acceleration and decay; decay 252/256
   plus bed drag 64/H (shallow sheets settle like HEAD, deep water keeps inertia);
   flux = u*mass/127 into the upwind neighbour, allowed to overfill a full cell;
   mass-weighted round-to-nearest velocity blend; HEAD 3/4 skin rule kept for top
   cells; HEAD film/coherence/transport rules unchanged.
3. Bit budget: bits 40-47 signed velocity (127 = 1 cell/tick), bits 48-55 overfill
   (0-255 extra mass). Pressure, run length and gradient are per-tick scratch, not
   cell state. 16/16 spare bits used; epoch untouched.

Why the alternatives lost (measured): skin-only depth+momentum (tier A) cannot move
mass through full cells, so mounds stay (no better than HEAD); first-order pressure
diffusion is bounded by explicit stability (D<=1/2) and would need ~10^4 ticks for a
382-wide basin; per-cell (non-coherent) dithering and integer truncation in decay and
velocity blends created a self-sustaining micro-slosh; per-core pressure
interpolation broke at core seams; a low-speed friction/settle rule stalled deep
leveling (deep water levels through |u|=1 crawls).

## Known gaps / risks (prototype, not production)

- Deep-water sleep is marginal: pool sleeps at 1339 with these defaults but other
  nearby parameter sets leave ~100 cells/tick of HEAD's own skin-rule flicker on a
  residual sub-cell tilt; the 215-deep U-tube levels but was still not asleep at
  9000. The remaining churn is the 3/4 skin rule on a slope (the owner's "flicker in
  near-calm volumes" mechanism), not the new dynamics.
- Leveling ~e-fold per 130 ticks is near the explicit limit (wave ~1 cell/tick,
  near-critical damping) for a 382-wide basin; "a few hundred ticks" is only met for
  the shallow basin (405); pool 897.
- Tall-column faces still shed a striped waterfall (alternating-row scan artifact,
  also in HEAD); base spreads faster and smoother than HEAD (front at t=240: base
  +158 vs HEAD +90 cells; no base cliff), the upper column is still a vertical wall.
- Per-active-tick cost 3-4x HEAD in deep flowing water; pre-pass scratch is sized to
  the active bounding box (tick-time growth); serial pre-pass; `tick_serial` and
  physics diagnostics/transport profiles not exercised; Godot fixtures, render
  snapshot, saves and c_api untested; content_hash ignores spare bits (hidden mass in
  overfill is not hashed or rendered).
- Semantics change: head transmission (U-tube equalizes) => #45 decision; overfill
  means up to 255 hidden mass per cell transiently and under bodies/ceilings.

## Engine phasing / worker review (asked by the owner)

Pros: deterministic and worker-count independent by construction (verified: equal
hashes for 1/2/4 workers incl. spare bits); in-place, no double buffer; simple
conservation; persistent pool; clean failure quarantine.

Measured problems:
1. Workers do nothing at typical scene sizes: `parallel_job_threshold = 8` jobs per
   phase means a 384x256 scene (<=~6 cores per phase) always runs serial. HEAD pool
   1 vs 4 workers: 3.51 vs 3.55 ms; cloud 2.53 vs 2.50. Threshold 1: pool 3.36 ->
   1.70 ms, cloud 2.35 -> 1.17 (2.0x). Threshold 1 + 32-cell cores: 1.40 / 0.96 ms
   (2.4x). Hashes stay identical across worker counts (core size changes results).
   Prototype pool with threshold 1, 4 workers: 12.3 -> 6.5 ms.
2. Core seams: instant in-core chains (bottom-up gravity refill, same-tick relays) lag
   one tick across seams and the phase order rotates with tick%4; the prototype's
   late churn concentrated on the y=192 seam row until heads were made transit-proof.
3. Scan-order artifacts: alternating row direction produces the striped column faces
   in both HEAD and the prototype.
4. Over-waking: `merge_job_effects` wakes the per-chunk change bounding box plus
   block-corner neighbours (documented); whole 64x64 cores are scanned when any of
   their four blocks is active.
5. Per-tick O(resident chunks x blocks) metadata passes in begin/finish_tick and a
   full epoch clear every 255 ticks.
6. No stage for read-only per-tick fields (pressure needed one).

Suggested adjustments (low risk first): make dispatch depend on work (active blocks
per phase) and set the threshold to ~1-2; try 32-cell cores; record per-block change
bits in JobEffects for precise waking; skip inactive blocks inside active cores;
give jobs a 3x3 chunk-pointer window instead of hash lookups; formalize a snapshot
pre-pass stage; consider per-chunk/incremental epoch clearing.

## Addendum 2026-10-19 (later): trapped air + large-scene scaling

Trapped air (variant `water_proto_b_air.inc`, diff `prototype-air-vs-perf-working-tree.diff`,
sandbox `C:\khybersand\build\water-sandbox\6-pressure-air.exe`, scenes 7 bell / 8 sealed chamber):
- Stateless, inside the existing snapshot pre-pass, no flood fill and no air state:
  per column, mark Empty runs capped by solid/body above (within 255 rows); per row,
  an Empty segment is "enclosed" if both ends are non-Empty inside the box and every
  column is capped (max span 512). Enclosed air is incompressible (instant sound speed):
  it is a ceiling for heads (row interpolation, else hydrostatic continuation upward
  from the water below, held excess raises pressure), refuses pressure relief and
  pipe flow into it, and has head = the neighbour's own (no gradient). Gravity falls
  and skin levelling into it still happen; optional leak WLEAK/256 per relief attempt
  (default 0). Anything touching open sky, the box edge or a long open column vents,
  so misclassification errs toward flooding.
- Diving bell (air pocket 60 rows below outside level): HEAD holds (no pressure at
  all), pressure prototype floods to row 152, air variant holds row 200 and sleeps at tick 3.
- Sealed chamber fed from a 176-row reservoir: pressure prototype floods (row 216 ->
  128 by 2000), air variant holds (row 216 -> ~210, all during the initial transient);
  the deep reservoir itself still micro-churns (~450 cells/tick, existing deep-water
  sleep gap). Determinism and exact mass unchanged (1 vs 4 workers identical).
- Ordinary scenes unchanged vs the pressure prototype (pool, column, basin, cloud,
  rain, calm identical numbers); U-tube arms equalize (L-R 0.46) but a ~1.2-cell local
  residual and churn remain to 7000 ticks.
- Limits: air reachable sideways only through an opening that is not directly above
  the pocket's surface rows is treated as trapped; pockets wider than 512 vent; no air
  mass is tracked, so a pocket never pushes water back out after it shrinks (by falls)
  and compression is modelled as zero (real air at ~10 m water/atm would yield a little).

Large scenes (perf build, `large_scene.cpp`):
- 4096x2048 fully active (pool + dense cloud, 803 cores): 1 worker 187.5 ms, 4 workers
  48.5 ms (3.9x), 8 workers 35.2 ms (5.3x). Threshold 8 vs 1 and 64 vs 32 cores make no
  material difference at this size. Phases are the parallel mechanism and scale.
- Mostly asleep big worlds (one 40x40 splash): 1024x512 0.4 ms, 4096x2048 0.39 ms,
  8192x4096 0.5-0.6 ms; cost grows with resident chunks (~0.09 us/chunk/tick) plus a
  ~30 ms full epoch-clear spike every 255 ticks at 8192x4096 (mean-p50 gap). These
  serial O(resident) passes, not the phases, are what will limit extremely large worlds.

## Addendum 2026-10-20: trapped air v2 (per-pocket pressure offset)

v1 blocked every enclosed-air cell, so a closed box (e.g. the sandbox's top border)
turned the whole sky into "trapped air" and froze the waves. v2 (current
`water_proto_b_air.inc`, `6-pressure-air.exe`):
- Enclosed segments (both ends non-Empty in the box, every column capped by solid/body,
  and no vented air directly above - venting propagates down so trough air under open
  sky never counts) are unioned vertically into pockets (union-find over segments).
- Water under a pocket keeps its free-surface head (waves keep their slopes); the
  pocket adds one uniform pressure offset = mean(head the connected water would impose
  if the pocket were a lid - own free-surface head) over its capped run tops. A pocket
  with no connection to open water (all lid heads from the no-information fallback)
  gets offset 0 and behaves as the local atmosphere. Air cells report the pocket
  offset as their head. No per-cell blocking, no air state, recomputed per tick.
- Results: closed-box slab drop identical to the open pool (level 897 / sleep 1339);
  bell holds its pocket (row 200, asleep at tick 3); sealed chamber 216 -> 204 by tick
  2000 (no-air prototype floods to 128); all other scenes identical to the pressure
  prototype; 1 vs 4 worker hashes identical; mass exact.

## Addendum 2026-10-20 (later): trapped air v3 - solid-edge fixes

Owner sandbox showed water spikes where thin/slanted strokes touch the surface and
stuck excess under a boulder (thin films on solids are wanted and unchanged).
Cause: in a closed box the whole sky is one valid pocket; water under each stroke tip
(a real solid lid) was resolved in the same pass as the pocket runs, found no known
neighbours and fell back to an arbitrary near-zero head, so water rushed into those
columns. Fixes (`water_proto_b_air.inc`, `6-pressure-air.exe`, lab scene `strokes`):
1. Pocket offsets are priced first from an independent "as if capped" resolution of
   the unresolved heads; offsets are added to the free-surface heads; real lids are
   resolved last against those offset-corrected neighbour heads.
2. Pocket validity: vented if any cell touches vented air above or below (air under
   an arch whose legs stop above the water vents), must contain a wall-to-wall segment
   (overhang slivers bounded by a wave crest are not pockets), size >= 16.
3. Water (not just solid) counts as cover, so splash droplets inside a pocket no
   longer vent it intermittently (that let the chamber flood in bursts).
4. Pressurized pockets (offset > 255) admit rising water only where the local surface
   is below the pocket's mean level (troughs refill, the mean cannot ratchet).
5. Excess under a solid/body lid spreads sideways to the less-loaded neighbour.
Results: strokes scene sleeps at 253 with surface roughness equal to HEAD (was never
asleep, spikes growing to 10 cells); closed box = open pool (897/1339); bell holds and
sleeps at 3; sealed chamber interior 216 -> 209 by tick 1200, 200 by 3000 (slow
wave-driven trough refill, i.e. gradual air loss); ordinary suite unchanged; 1 vs 4
worker hashes identical; mass exact.
Faint dark horizontal line in deep pools = core-seam refill lag (row 192): a cell that
lost mass sideways at the top row of a lower core is refilled from the core above only
next tick; it shows as one slightly lighter row. Engine-level, see scheduler notes.

## Addendum 2026-10-20 (evening): hiding seam lines and stripes in presentation

Tested in `water_lab cavity` (LAB_SMOOTH=1) and the sandboxes (key S, default on):
presentation-only smoothing, no simulation change:
1. Interior fill: a Water cell with Water directly above draws at full coverage (holes
   in transit, incl. the one-tick core-seam refill lag at rows 64/128/192, vanish).
2. Previous-tick blend: interior cells full if full in either of the last two ticks,
   otherwise the average (one-tick flicker disappears).
3. Vertical [1 2 1] filter on coverage: alternating-row stripes at lateral fronts read
   as a soft gradient.
Result: seam line and overfill speckle gone, stripes reduced to faint banding.
Simulation-side alternative rejected: scan parity "one direction per tick" still
stripes and adds vertical core-seam lines; "hashed per row" still stripes and is
noisier. The stripes come from lateral entry into a cavity + one move per tick, not
from row alternation. HEAD scan order kept.
Godot mapping: `godot/shaders/material_palette.gdshader` already binds
`current_world_texture` and `previous_world_texture` (`snapshot_blend`) and reads Water
coverage from the RG8 condition byte (`sampled_water_condition_byte`), so 1-3 are a few
extra texel reads in the existing pass (no new buffers); the presentation modes
(`water_presentation_mode`) are the natural place for an opt-in.

## Addendum 2026-10-20 (night): idle cost, settle, profiler, seam-fix presentation

Owner report: a ~3/4-full basin costs 25-35 ms/tick idle or moving. Reproduced with
`water_lab deep` (384x256, rows 70-254 full + slab): prototype 32 ms/tick, all 96 blocks
awake, ~74k visited cells/tick (HEAD 6 ms, 25k visited, also never asleep: 386
cells/tick of skin churn). Cause: column-to-column surface roughness (+-50..120 mass
units) seeds noise accelerations in the 194-deep bulk; crawls keep every cell on the
full kernel path; plus HEAD's 3/4 skin rule churning on the residual tilt.
Built-in sampling profiler (`sampler.hpp`, LAB_SAMPLE=1, /Zi build): hot spots were
neighbour lookups (find_chunk/get/address ~30%).
Changes (v4, `6-pressure-air.exe`, all hash-identical across 1/4 workers, mass exact):
- Same-chunk neighbour access in the Water kernel (hash-identical, 12-25% faster).
- Start/stop hysteresis: a resting cell needs |head gradient| > 30 to start moving
  (moving cells continue above 10) - noise cannot restart a settled bulk.
- Skin rule minimum step 4 mass units (was 1) - terminates on residual tilts.
Result: deep scene asleep at 1270 (6000-tick average 5.8 ms vs 32), pool/sealed 1209,
column 953, basin 706, cloud 943, rain 306, strokes 204, calm/bell 3. Cost: residual
unevenness ~2 cells in deep pools (visually ~2 px across 384), U-tube settles at 1.5
cells L-R. Still not asleep: cavity, sealed chamber, U-tube (deep bodies joined by
narrow passages).
Presentation: sandbox S cycles seam fix (default: interior fill + previous-tick full,
surface unblurred) / seam fix + vertical blur / raw; owner found full blur too soft.

## Addendum 2026-10-22: trapped air v5 - stored air (Boyle) + full-height pre-pass box

Owner report: the dome (arch dipping into a closed-box pool) flooded in v4. Cause: stateless
pricing gives a pocket exactly the pressure that balances its surroundings, so there is no
restoring force; in a sealed box the sky pocket had no reference at all.
v5 (`9-pressure-air-v5.exe`, branch `claude/water-pressure-prototype`):
- Air amount stored in the pocket's Empty cells (spare bits 40-55, which Empty cells do not
  otherwise use): A = equivalent atmospheric volume in cells. Gauge = P_atm*(A*255 - V255)/V255,
  V255 = pocket cells*255 + unfilled part of the water cell below each (smooth), P_atm = WATM
  rows (512), quantized to WAQ (16), clamped [0, P_atm]. A new pocket seals at atmospheric
  (A = V). Each pocket takes the amount most of its cells hold; an amount claimed by several
  pockets (a split) is shared by volume. Pockets > WAMAX (24576) cells act as atmosphere.
  The v3 relief gate is off when air state is on.
- Full-height pre-pass box (WBOXV=1): the pre-pass box spans the occupied chunks' full
  height in the active columns. A box cut to the active cores truncated columns once part
  of a pool slept: the awake part saw false heads and the sleeping rim discharged ~35 cells
  in a burst when woken, refilled slowly, and repeated (~1000-tick stick-slip cycle; with
  sleep disabled the bell settles completely by tick ~1000). Snapshot of that behaviour kept
  as `8-pressure-air-v5-bell-cycle.exe` at the owner's request.
- Tried and left off (no benefit): pressure hysteresis (WAHYS), dp/dt damping (WAD),
  equilibrium band snapping to the balance price (WABAND), wake-all-on-pressure-change
  (WAWAKE, harmless, on), holding small overfill under lids (WOHOLD: lets bell/chamber
  sleep fully at 1710/2813 but makes the dome cycle).
Results (5000 ticks, 1 worker): dome holds (inside surface 165 -> 159, air conserved), 0
cells/tick late, 2 blocks kept awake by 1-3 units of overfill under the rim; bell holds
(row 189) 0 late, 2 blocks; chamber holds, 3.8 late, 8 blocks; deep closed box asleep 1627;
sealed 1209; strokes 204; suite unchanged (calm 3, rain 306, cloud 943, basin 706, column
953, pool 1209); U-tube and cavity still churn (as v4). Mass exact; 1 vs 4 worker hashes
identical (dome, bell, chamber, sealed, strokes; threshold 1). Owner: residual units/films
are acceptable (render tricks); this is a game approximation, not a perfect simulation.
Cost note: the full-height box iterates resident chunks per tick (prototype); production
needs a per-column-band occupied extent.
