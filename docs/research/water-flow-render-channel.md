---
title: Water flow render channel and seam-fix presentation proposal
document-kind: design
canonical-for: [water-flow-render-channel-proposal, water-seam-fix-presentation-proposal]
status: Planned
scope: Proposed optional render-snapshot flow plane carrying prototype Water velocity/overfill, its upload cost, the shader effects it enables, and an opt-in Water seam-fix presentation flag; no production Water semantics, cell layout or renderer change
last-reviewed: 2026-10-20
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../systems/material-appearance-and-rendering.md, ../reference/interfaces-and-message-contracts.md, ../systems/water-design.md, ../operations/water-hybrid-pressure-extension-programme.md, ../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md, ../operations/configuration-and-capacity-budgets.md]
---

# Water flow render channel and seam-fix presentation proposal

## Status and gate

**Planned, not implemented.** This page proposes how per-cell Water flow data
could reach the Godot renderer so the shader can draw currents, foam and depth,
plus a presentation-only fix for Water seam lines. Nothing here changes Current
Water semantics, the 8-byte `PrecisionStorage` cell, render publication or any
shader.

The flow data exists only in a 2026-10-19/20 scratch "snapshot head" Water
prototype (pressure + overfill + lateral velocity + trapped-air pockets), kept
outside this repository with its own README, diff and sandboxes. Adopting that
prototype is head transmission and therefore a #45 decision, gated by the
corrected #49 apparatus and the #95 synthesis per the
[Water hybrid/pressure extension](../operations/water-hybrid-pressure-extension-programme.md).
**Current production Water has no velocity or overfill state, so the flow plane
below would be all-neutral until that decision lands.** The proposal is split so
the parts that work on Current data can be judged separately:

| Stage | Needs #45 integration? | Content |
|---|---|---|
| 0 | No | Seam-fix presentation flag; shader-derived depth tint |
| 1 | Yes | Optional flow plane; streaks, foam, current-aware ripple/refraction |
| Deferred | Yes, plus new state | Published head/pressure and trapped-air pocket identity |

## What the prototype offers

Source: the scratch prototype kernel (`water_proto_b_air.inc`) and its sandbox
overlay (`water_sandbox.cpp`, key `V`).

| Prototype datum | Where it lives | Lifetime | Publishable? |
|---|---|---|---|
| Signed lateral velocity, int8, 127 = 1 cell/tick | Cell bits 40-47 (spare in Current `PrecisionStorage`) | Persistent cell state | Yes |
| Transient overfill, 0-255 extra mass | Cell bits 48-55 | Persistent cell state | Yes |
| Settled head / pressure | Pre-pass scratch over the active cores' box + halo | One tick, active region only | Not without new state |
| Trapped-air pocket id/offset | Same pre-pass (union-find per tick) | One tick, active region only, ids reassigned each tick | Not as ids |

The sandbox overlay paints overfill orange and positive/negative velocity
green/purple directly from the bits; the shader effects below are the
production-quality equivalent.

## Proposed snapshot format

### Options considered

Costs below are for the Current 128-cell chunk (16,384 cells) and the 1024×1024
desktop world. Godot currently uploads the **whole** world texture on every
consumed snapshot ([bridges](../architecture/rendering-and-gameplay-bridges.md#does-a-small-dirty-patch-mean-a-small-gpu-upload));
render cadence presets are 30/45/60 Hz (`RENDER_SNAPSHOT_HZ_PRESETS`).

| Option | Native bytes per fully dirty chunk | GPU upload per snapshot | At 60 Hz | Notes |
|---|---|---|---|---|
| Current RG8 | 32,768 | 2 MiB | 120 MiB/s | Baseline |
| A: widen main snapshot to RGBA8 (B = velocity+128, A = overfill) | 65,536 (every dirty chunk, Water or not) | 4 MiB, always | 240 MiB/s | Doubles slot capacity; every consumer (blacksite, showcase, depth layers, recorder, Web, validation's 1/2-channel check) changes |
| B: separate full-resolution RG8 flow plane | +32,768 | +2 MiB when flow changed | ≤240 MiB/s | Exact per cell; idle Water costs nothing extra |
| **C: separate half-resolution RG8 flow plane (recommended)** | **+8,192** | **+0.5 MiB when flow changed** | **≤150 MiB/s** | Velocity is already radius-2 smoothed in the prototype; linear filtering gives the shader a smooth advection field |

**Recommendation: option C.** Keep the RG8 `cells` payload byte-for-byte
unchanged and add an optional, additive flow plane at 2×2-cell resolution:

| Byte | Meaning | Reduction over the 2×2 block | Neutral |
|---|---|---|---|
| 0 | Lateral velocity + 128 (128 = still, 255 ≈ +1 cell/tick) | Mass-weighted mean over Water cells, round to nearest | 128 |
| 1 | Overfill (0-255 extra mass) | Max | 0 |

The wire format is semantic (lateral velocity in 1/127 cell/tick, transient
overfill mass), not "bits 40-55", so a different #45 representation only changes
the native projection function.

### Native publication

- `RenderSnapshotExchange` gains an optional flow byte capacity per slot
  (default 0: no allocation, no flow work, Current behavior). A 1024×1024 world
  needs 524,288 bytes per slot for a full flow refresh beside the existing
  2,097,152.
- The flow plane is captured in the same `publish` call, under the same lock,
  into the same preallocated slot, so lease immutability and the
  [ADR-003](../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
  contract are unchanged. `RenderSnapshotPatch` gains additive
  `flow_data_offset`/`flow_stride_bytes`; `RenderSnapshotLease` gains
  `flow_cells()`. `CapacityExceeded` counts flow bytes too; dirty state is
  still acknowledged only after both planes are captured.
- Dirty rectangles are widened to even coordinates inside their chunk (128 is
  even) so 2×2 blocks never straddle a patch edge.
- A `project_water_flow` helper next to
  [project_visual_state](../../native/include/cybersand/material_appearance.hpp)
  emits neutral bytes for every non-Water cell; epoch and scheduler history stay
  excluded.
- Each patch carries a `flow_any` bit (any non-neutral block). Godot keeps one
  bit per chunk (64 bits for 1024×1024) recording which chunks last held flow;
  it re-uploads the flow texture only when a patch has `flow_any` or overwrites a
  chunk that previously had flow. Settled scenes therefore pay zero extra upload.

**Required integration fix (prototype defect).** The prototype changes velocity
without moving mass (decay, `set_flow`) and folds overfill back (`normalize`)
without marking render dirtiness; only `transfer_water`/`write_cell` do. Published
flow would go stale, and streaks would keep running over water that has
stopped. Integration must mark render-dirty (not activity, no wake) whenever the
published projection of a cell changes, through `JobEffects` in phased jobs,
including the transition to zero velocity.

### Godot consumption

- The adapter packet adds `flow_format` (0 absent, 1 = half-res RG8 v1), a flow
  byte array and per-rectangle flow offset/stride/`flow_any`; the six-int
  rectangle metadata is untouched. Validation follows the existing Current rules.
- One `water_flow_texture` (RG8, 512×512, `filter_linear`), not ping-ponged:
  the effects animate from presentation time, so blending velocity between
  snapshots is unnecessary and the skip rule stays simple.
- Desktop GDScript fallback (R8) and any world without the plane bind a neutral
  texture with `water_flow_enabled = 0`. Web uses the same native path but
  should keep the plane off by default until its synchronous upload cost is
  measured.

## Shader effects enabled

All are presentation-only reads in
[material_palette.gdshader](../../godot/shaders/material_palette.gdshader) for
Water pixels (material ID 3); none feeds back into simulation.

| Effect | Inputs | Approach | Extra reads per Water pixel |
|---|---|---|---|
| Flow streaks | Flow byte 0 | Two-phase flow-map advection: anisotropic noise stretched along x, offset by `u·t` in two layers half a period apart, crossfaded with triangle weights so varying `u` never shears without bound. `u` in cells/s = `(byte − 128) / 127 × tick_hz`. | 1 (linear) |
| Foam / whitewater | Bytes 0-1, RG `cells` | Hashed, flickering speckle where overfill > 0, at the free surface (Empty above) when \|u\| is high, and on shear (\|∂u/∂x\| from two flow samples) | 2 |
| Depth tint | RG `cells` only | Upward probes at 2, 4, 8, 16 and 32 cells, like the existing `run_length` probes, bucket depth below the free surface into a darker/bluer ramp | 5 (R only) |
| Current-aware ripple/refraction | Byte 0 | Advect the existing Water caustic/ripple phase with `u` and add a small horizontal UV wobble scaled by \|u\| to the Water finish and to depth-layer content seen through it | 0 beyond streaks |

The depth tint needs no flow plane and works on Current Water, so it belongs in
stage 0. A **pressure** tint differs from depth only under lids and trapped-air
pockets, and is Deferred below.

## Seam-fix presentation (stage 0)

The prototype sandbox showed that the faint horizontal core-seam line in deep
Water (a cell at the top row of a lower core is refilled from above only next
tick) and transit holes disappear with two presentation rules; Current Water has
the same seam and alternating-row artifacts (prototype README: "also in HEAD").

1. **Interior fill:** a Water cell whose cell directly above is also Water draws
   at full coverage.
2. **Two-snapshot union:** an interior Water cell draws full if it is full in
   either the current or previous snapshot; otherwise it shows the current
   coverage. Surface cells always show the current snapshot unchanged, keeping
   edges crisp.

The owner found the sandbox's optional vertical [1 2 1] coverage blur too soft;
it is **not** proposed.

Proposed shape: an orthogonal `water_seam_fix` uniform (default 0) rather than a
fourth `water_presentation_mode`, because it composes with the existing hash,
coverage and oriented modes. Rule 1 costs one extra texel read (the cell above);
rule 2 reuses `previous_world_texture`, already bound for `snapshot_blend`, and
is applied to coverage before the crossfade. In Godot "previous" is the previous
*published* snapshot, which at 30-60 Hz may be several ticks old; rule 1 covers
the one-tick seam hole in every published frame regardless.

With the flag on, displayed coverage is no longer a mass readout, so
measurement captures and Water Feel Lab evidence must keep it off.

## Deferred: head/pressure and trapped-air pockets

Settled head and pocket data are recomputed per tick only over active cores; a
sleeping body of Water has none, and pocket ids are reassigned every tick, so
publishing ids would flicker. Showing pressure or pocket boundaries would need
either persistent state or a publish-time bounded column scan, which is new
authoritative or capacity design for #45, not a render-format question. If
wanted later, a 1-bit "enclosed air" flag in a reserved flow-plane bit is the
smallest candidate.

## Implementation checklist (when approved)

- Native tests: flow plane dimensions/offsets/even alignment; neutral bytes for
  non-Water; mean/max reduction; `flow_any`; capacity accounting including
  flow; lease immutability; render-dirty on velocity-only change and on decay to
  zero; disabled capacity allocates nothing.
- Godot tests: malformed flow payload rejection and resynchronization; skip-upload
  rule; fallback/neutral binding; an actual-pixel test for seam fix on/off and
  streak direction sign.
- Measure upload time on desktop and Web before enabling defaults.
- Update the [bridges contract](../architecture/rendering-and-gameplay-bridges.md),
  [interfaces](../reference/interfaces-and-message-contracts.md),
  [appearance](../systems/material-appearance-and-rendering.md),
  [capacity budgets](../operations/configuration-and-capacity-budgets.md) and
  roadmap, with dated evidence.
