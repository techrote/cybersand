---
title: Water design
status: Current
scope: Current discrete and fixed-point Water semantics, phased pairwise and buffered candidates, conversion constraints, stable rest, render-only dithering, tests, and diagnostics
keywords: [water shimmer, static heap, fixed-point mass, pairwise transfer, buffered flux, conservation, phased water, dithered water]
related-documents: [materials-and-rule-kernels.md, ../architecture/determinism-and-boundary-transfers.md, ../operations/troubleshooting.md]
last-reviewed: 2026-08-27
implementation-state: Preferred runnable Godot Water is the native conserved 8-bit mass solver with phased pairwise transfers, a 12-tick coherent-emission delay, optional supported-film adhesion, and stable render-only mass dithering; native Paste/Slush use viscous heap-capable whole-cell yield. The older discrete GDScript solver remains a platform fallback.
---

# Water design

## At a glance

- Purpose: preserve the dithered-water look while eliminating endless shimmer and static heaps.
- **Current**: preferred Godot Water uses native conserved mass at full active cadence; the discrete directed solver is a fallback only.
- **Current**: normalized gameplay viscosity controls rate independently of pressure yield; Water is 0 (fastest), while higher provisional values are assigned to Acid, Oil, and Lava.
- **Current**: native Water stores mass from 1–255 in compact `state_a`; zero mass is Empty.
- **Current**: exact pairwise transfers run under phased exclusive ownership.
- **Current**: lateral transfer stops when adjacent mass differs by at most one unit.
- **Current**: settled pools become hash-stable and sleep; a closed fixture conserves exact mass on every tick.
- **Current**: native Paste and Slush exercise viscosity-gated heap-capable whole-cell yield; broader gels and trapped-fluid materials remain future uses.
- **Current**: the Godot RG8 material/condition path uses stable coordinate/mass coverage dithering without mutating authority.
- **Planned**: immutable-current active-only buffered flux remains a fallback only if future liquid/field needs justify it.
- **Explicitly rejected**: starting with a general fluid solver or a separate competing liquid world.
- Unresolved: generalized reaction mass accounting, serialization encoding, and whether a future field needs buffered flux.

## Search anchors

debug water shimmer, water piles up, water heap, flow budget, conserved liquid mass, stable rest, render-only dither, liquid leakage

## Current implementation evidence

### GDScript fallback water

godot/scripts/cell_world.gd retains the unsupported-platform fallback:

- FREE_LIQUID_LATERAL_FLOW set to 255 for Water;
- YIELDING_LIQUID_LATERAL_BUDGET set to 6 for Slush;
- WATER_VISCOSITY set to 0 and MAX_LIQUID_LATERAL_FLOW_RATE set to 24;
- SLUSH_VISCOSITY set to 192 and PASTE_VISCOSITY set to 240;
- EMISSION_FLAG_COHERENT_LIQUID stored through an otherwise-unused flow-state bit;
- COHERENT_LIQUID_LATERAL_FLOW_RATE set to 1;
- independent per-material surface-adhesion constants plus a runtime override;
- LIQUID_PRESSURE_SAMPLE_DEPTH set to 64 and LIQUID_LEVEL_SEARCH_DISTANCE set to 256;
- flow_budget per cell;
- flow_direction per cell;
- _try_liquid_lateral;
- _liquid_has_pressure_advantage;
- _liquid_viscosity and _liquid_lateral_flow_rate;
- in-place material-cell movement.

The earlier six-cell Water budget could freeze a one-cell-per-column staircase
into a visible heap. Replacing it with unlimited one-cell motion prevented that
small-fixture failure but left broad piles far too slow and able to sleep with
a residual four-cell mound. The Current serial rule derives a bounded movement
distance from viscosity, scans every intervening cell, and moves Water up to 24
empty cells per update. Once momentum stops, pressure look-ahead scans only
along the open surface row for a genuinely lower column; level pools therefore
stop rather than reverse and shimmer. Finite travel, higher viscosity, and a
nonzero pressure yield are now exercised by prototype Paste and Slush without
changing Water's tuning.

### Preferred native placement, spray, and surface adhesion

Normal Water emission immediately uses conserved gravity and lateral mass
transfer, retaining the emergent spray/mist and edge-fall behavior. Coherent
(UI label: calm) emission is an explicit command flag, not a second material.
The adapter initializes Water's compact `state_b` to a 12-tick lateral-delay
countdown. The countdown moves with mass and suppresses source-time lateral
spread only; after it expires, water falling from a later edge uses normal flow.

Surface adhesion is independent of viscosity and emission mode. With adhesion
enabled, supported Water mass at or below 48/255 is retained as a thin film;
disabling `T` removes that threshold while gravity and density exchange remain
active. Per-material adhesion traits for future dangerous liquids remain
**Planned**; the Current native toggle affects Water globally.

Prototype paint slots and simulation material IDs are deliberately independent.
The current UI maps slot 5 to Paste ID 20 (viscosity 240) and slot 6 to Slush ID
21 (viscosity 192). IDs 20/21 avoid the Sandspiel-compatible Cloner/Fire IDs
5/6; no slot number is sent to simulation. They deliberately use whole-cell
yield rather than conserved Water mass so heap/slush behavior remains available.

Historical behavior included:

- water cells oscillating and appearing to shimmer;
- water never reaching a true sleeping state;
- attempts to reduce oscillation allowing static liquid heaps;
- dithered-looking water formed by alternating authoritative Water and Empty cells.

The fallback headless Godot regression covers Water self-leveling, a screenshot-scale
320-cell basin with a six-second/two-pixel acceptance bound, and Smoke density
displacement. On the 2026-08-27 Godot 4.7 run, Smoke, the small Water fixture,
and rigid-body coupling assertions passed, but the wide basin failed: occupied
column heights ranged from 9 to 22 pixels after 360 ticks. That pre-existing
liquid-tuning defect is outside the Rapier migration and remains unresolved.
Native behavioral tests were not rerun for this focused build.

### Native water

native/src/world.cpp stores Water mass in the first generic state byte. A Water
cell therefore holds 1–255 units; Empty represents zero. Transfers attempt down,
then deterministic diagonal order, then lateral equalization. The source cannot
emit more than it owns and the destination cannot exceed 255. Full Water cells
exchange downward with lighter density-participating materials including Smoke
and Oil. The descriptor viscosity index scales lateral pairwise transfer; Water
is zero viscosity, so its existing full relaxation amount is retained. No
mutable lateral direction/history is stored in native Water, and viscosity does
not expand the native phased kernel's radius-one write domain.

## Behavioral invariants

The following are Current invariants for pure closed Water fixtures and retained
requirements for future reactions/serialization.

### Conservation

- A closed pure-Water fixture neither creates nor destroys fixed-point liquid mass.
- Cross-core and cross-chunk transfers count exactly once.
- **Planned** interacting conversions identify and account for explicit sources/sinks rather than silently losing mass.
- Sleep, wake, and replay do not change total mass; serialization remains to be proved when implemented.

### Bounded flow

- A source cannot emit more mass than it contains.
- A destination cannot accept more than its approved capacity.
- Competing flux is resolved deterministically.
- Any arithmetic saturation or overflow behavior must be specified and tested before implementation.

### Stable rest

- Equivalent resting cells do not swap solely to create activity.
- With no external command, topology change, or interacting field, settled authoritative water reaches a stable state.
- After settling, replay hashes and authoritative dirty state remain unchanged for an explicit test observation window.
- Dither animation or texture variation cannot wake water or modify mass.

### No static liquid heap

- In a connected container under the minimal liquid model, water must not remain as a sand-like slope solely because a per-cell travel budget expired.
- The reference fixture must demonstrate lateral leveling appropriate to its approved simplified physics.
- The wide discrete reference fixture must reach a maximum occupied-column height difference of two cells within 360 ticks.
- The Current native fixture bounds settled cross-container column-mass variation below 1/32 of a cell; tighter canonical remainder distribution may be evaluated later.

## Minimal shared-grid representation

### Current representation

- The existing material grid remains the common world occupancy/category model.
- Water-bearing cells use a minimal fixed-point liquid state associated with that grid.
- Liquid state is not a parallel spatial world with independent authority.
- The mass byte is present in the four-byte hot Cell and is mutated pairwise under phase ownership.
- Empty, partial, full, and material-conversion semantics are explicit and deterministic.

### Current numeric choices

- storage width: unsigned 8-bit integer;
- nominal full cell: 255 units;
- minimum Water cell: 1 unit;
- Empty-to-Water transition: destination mass changes from zero to nonzero;
- Water-to-Empty transition: source mass reaches zero;
- lateral rest tolerance: one integer unit;
- execution: direct pairwise transfer in the phased backend.

Serialization encoding and generalized source/sink reaction accounting remain
**Planned**. These Current choices can be revised only with migration and fixture
evidence.

## Conversion rules

The final reference must explicitly define:

1. how a gameplay command introduces a specified mass into material-grid cells;
2. when an Empty cell becomes Water-bearing;
3. when a Water-bearing cell becomes Empty;
4. how partial mass is represented;
5. how displaced or incompatible materials interact;
6. how removal returns an exact mass result;
7. how serialization preserves values;
8. how conversions contribute to dirty and wake state.

Direct `set`/paint creates a full 255-unit Water cell. Movement conversions are
implemented. Exact mass-return commands, serialization, and generalized reaction
accounting remain **Planned**.

## Current phased pairwise sequence

1. establish the fixed four-phase and within-job traversal order;
2. visit only pairs wholly contained in the current owned write domain;
3. transfer an exact bounded integer amount directly between the pair;
4. defer or postpone ownership-edge pairs using one documented policy;
5. enforce conservation, capacity, material conversion, wake, and dirty invariants;
6. produce a replay hash covering all future-affecting liquid state.

## Planned buffered flux fallback

1. read one immutable committed liquid state;
2. calculate bounded candidate flux;
3. resolve all flux deterministically;
4. apply flux to active next liquid state;
5. enforce the same conservation, conversion, activity, and replay invariants.

The buffered path is not implemented and is not required merely for symmetry.
It remains appropriate only if a future field cannot satisfy its invariants with
bounded in-place ownership.

## Tile and chunk boundaries

- Activity, scheduling, and storage boundaries do not change liquid behavior.
- The pairwise candidate processes an edge only in a phase that exclusively owns both cells, or through a future explicitly approved boundary policy.
- The buffered candidate stages flux crossing isolated output regions.
- Any accepted edge effect wakes relevant destination work.
- Sleeping or out-of-interest state cannot absorb or lose mass.
- Merge order does not depend on which TileJob completed first.

## Rest and activity

Water remains active only while authoritative state or rule eligibility still changes.

Native sleep uses 32×32 activity-block change observations and the configured
quiet-tick threshold. Visual dither never marks activity or dirty authority.

## Visual dithering

### Current native behavior

- Dithering preserves the current stylistic appearance where practical.
- Resting water may look textured without alternating Water and Empty authoritative cells.
- If authoritative state and view inputs are unchanged, the resting dither pattern is stable.
- RenderBridge or immutable snapshot derivation owns the presentation result.
- Render-only changes do not enter replay hashes, liquid conservation, wake state, or collision authority.

`World::copy_rgba` hashes stable world coordinates to a byte threshold and emits
Water color only when the threshold is below mass. Thus partial mass changes
coverage, while unchanged authoritative state produces an unchanged image.
The mass-aware path is **Current** in the bundled Linux and Windows x86_64 Godot adapter. Broader
platform binaries and accessibility controls remain **Planned**.

## Acceptance fixtures

### Conservation

- closed container at rest;
- falling column;
- lateral leveling;
- tile-edge crossing;
- chunk-edge crossing;
- repeated sleep/wake;
- serialization round trip when serialization exists.

Each fixture requires exact equality in fixed-point total mass unless the test explicitly models a source or sink.

### Stability

- flat pool reaches stable authoritative state;
- sloped container levels without sand-like heap;
- deep buried water stops scheduling interior work;
- render dithering remains visually present but produces no authoritative changes;
- one-worker and multiworker replays produce identical hashes within the selected backend;
- mirrored fixtures reveal directional and phase-order bias;
- the candidate comparison records behavioral differences rather than hiding them.

The observation duration and geometry are test-fixture configuration decisions not yet frozen.

## Troubleshooting decision tree

1. **Water visually shimmers while metrics show no authoritative changes**
   - Likely subsystem: render-only dither.
   - Inspect: snapshot/render output and accessibility setting.
   - Safe action: adjust presentation only; do not wake or mutate water.

2. **Water visually shimmers and authoritative hashes/dirty counts change**
   - Likely subsystem: liquid rest/flux or material conversion.
   - Inspect: per-tick moved mass, net flux, equivalent-state transitions, active tiles.
   - Safe action: reproduce in the single-thread reference before touching scheduler behavior.

3. **Water forms a static heap**
   - Godot likely subsystem: flow direction, pressure look-ahead, or premature sleep.
   - Future likely subsystem: insufficient lateral flux/equilibrium rule or premature sleep.
   - Inspect: mass distribution, available destination capacity, sleep decision, boundary wake.
   - Safe action: fix reference liquid invariants; do not restore endless equivalent swaps.

4. **Liquid mass changes**
   - Likely subsystem: transfer merge, arithmetic, or conversion.
   - Inspect: total mass before/after every stage and edge transfer counts.
   - Safe action: stop integration; conservation failure blocks the checkpoint.

5. **Seam at a tile/chunk edge**
   - Likely subsystem: phase ownership, edge eligibility, buffered transfer classification, event order, or wake.
   - Inspect: mirrored/shifted edge fixtures, owned pairs, and transfer totals where applicable.
   - Safe action: fix shared boundary semantics, not a special-case edge rule.

6. **Active region grows indefinitely**
   - Likely subsystem: nonzero equivalent flux, dirty/wake feedback, or render state entering authority.
   - Inspect: wake causes, net mass change, tile quiet history, render-only inputs.
   - Safe action: remove false authoritative change; do not merely shorten timeouts.

## Related decisions

- [ADR-005](../decisions/ADR-005-water-model.md)
- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [Testing and replay](../operations/testing-validation-and-replay.md)
