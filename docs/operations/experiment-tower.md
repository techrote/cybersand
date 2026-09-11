---
title: Experiment Tower and transport comparisons
status: Current
document-kind: runbook
scope: Shared five-floor recipe, exclusive owner controls and issue 13 transport evidence; planned issue 19 Water Feel Lab extension is clearly separated
canonical-for: [experiment-tower, transport-comparison-procedure]
last-reviewed: 2026-09-11
related-documents: [physics-characterisation.md, architecture-programme-water-feel-addendum.md, architecture-programme-prompts/fractional-presentation.md, ../systems/granular-interaction-policy.md, ../audits/2026-09-09-issue-13-transport.md]
---

# Experiment Tower

## How do I open and reset the experiments?

**Current:** desktop has an Experiment Tower button and F9.
The native Web menu includes Experiment Tower. Both consume the same
[recipe](../../godot/scripts/experiment_tower.gd) through `CyberDemoWorlds` and
`CyberDemoBridge`. Existing demos retain their recipes. The lab starts paused;
floor selection places the player on a safe shaft landing and pans the camera.
Arrows pan horizontally to the remaining bays; A/D and Space provide normal movement.

Floors contain flowing powders; Water/Sand slopes and settling; eleven liquids;
packed, poured and excavated Mercury references; and separated chemistry.
Amber bottom plugs can be erased or opened with the tube selector, singly or
with their neighbour. Sequence releases use offsets 30 and 90 from the command
tick. Navigation cancels pending releases without catch-up. Fresh tower restores
recipe version 4, seed 0, selected floor and successfully applied profile.
The [tuning panel](../systems/flow-transport-and-profiles.md) provides protected
templates, editable copies, effective origins and Apply and restart.
Selecting a tube also pauses and focuses its bay. Recipe v2 adds a continuous
shaft passage and a converging powder chute. Recipe v3 protects marked Acid
plugs and adjacent gallery gates with an inert Wall facing. Erase the whole
marked plug; Open plug handles both layers. Recipe v4 adds a Metal bed under
the Acid outlet because solid Metal does not drain from its tube. Earlier recipes
remain dated evidence. Lab controls do not take keyboard focus from movement.

Chemistry is deliberately unchanged. Materials may age before their release.
The owner reports that an earlier reduced fire cadence made Wood smoulder while
Oil and Coal felt good. This is owner feedback for later chemistry work, not a
new measurement or authorization to retune combustion here.

## Who owns tower commands and what is bounded?

Desktop `CyberSimulationWorker.queue_lab` copies one latest pending command under
its mutex. The worker constructs the candidate through the native bridge outside
ticks; only successful installation replaces authority. Web controls operate at
their synchronous main-thread owner boundary. Native workers call no Godot APIs.
Single-step executes one tick while paused. Recipes obey the existing 4096-record
and eight-world-area construction budgets, without changing cell or CYSD1 layout.
Lab observations retain at most 256 control inputs and two scheduled releases.
Current snapshot metadata is copied; it exposes no mutable native storage.
Ordinary camera interest filtering remains in use; other floors are not forced
to simulate and exclusion never represents elapsed simulation work.

## Which reference fixtures precede solver changes?

[transport_characterisation.cpp](../../native/bench/transport_characterisation.cpp)
defines packed Mercury, Sand poured onto a slope then Mercury at tick 300,
Sand/Dust coflow, Water release at tick 30 over Sand, loose grains and a 32-unit
Water film control. Five translations include negative coordinates and core/chunk
seams; each runs one/four workers for 1800 ticks. Every 60 ticks records exact
content identity, species counts and Water mass. Seed is a translation, not a
new random stream. Input timing is independent of wall clock and workers.

Run `tools/physics/issue13.py --output <raw>` to rebuild before executing. Pass
`--reference <baseline/references.json>` to reject any Baseline content drift.
Raw results belong under `C:/kybersand/validation/local`; the
[dated audit](../audits/2026-09-09-issue-13-transport.md) owns acceptance and gaps.
Native counters do not constitute visual approval of the poured Mercury feel.

After the [September 10 Water leveling update](../audits/2026-09-10-water-leveling.md),
historical #13 Water samples intentionally differ. Use `--layouts packed poured
powder` with the frozen reference to check unchanged Mercury/powder behavior;
do not rewrite that historical reference. `tools/physics/water_leveling.py`
rebuilds and records the new closed-basin speed/conservation measurements.

## How should comparisons and observations be interpreted?

The three profile v1 presets retain their initial values after screening. Mixing
96 increases coflow interface interleaving while avoiding maximum-probability
churn; more swaps at 255 did not imply more final interleaving. Carrying 255,
pickup 64 and packing 8 separate Gentle loose-grain pickup from Threshold erosion.
The threshold is `max(64, pickup + occupied * packing)`: controls below the fixed
64-unit floor may share an outcome. These are gameplay experiments, not physical
units. Horizontal 2/cadence 1 remain all preset defaults; one-sample and reduced
cadence variants must be saved as explicit user copies. Reduced sampling can
change stream trajectories, deposited grains and pickup in either direction.

`transport_matrix.py` executes 480 cases: three presets, two sampling policies,
eight layouts, five translations, one/four workers, 1800 ticks. Sparse uses ten
rows of initial Water; sustained tops up only Empty/Water in a fixed reservoir
rectangle every 120 ticks and records every injected mass unit. The report checks
conservation against that ledger. `transport_knobs.py` independently screens
mixing, carrying, pickup, packing and cadence without wall-clock adaptation.
`transport_report.py` validates sample/worker/Mercury gates before summarizing.
`transport_permeability.py` screens periods 1/30/60 separately; protected presets
keep Mercury at 30. `transport_matrix.py --reuse <prior>` preserves original
manifests/commands for unaffected runs, while rerunning every sustained case and
seed-zero Water depth fixtures. The report declares the depth sample count:
`eroded_initial_sites` excludes the bottom wall; legacy `eroded_sites` is retained
only for frozen-reference compatibility. Never compare their raw totals as the
same metric. Preserve failures before correcting a measurement fixture.

Counters distinguish Empty moves, density swaps, conversions, powder swaps,
grain pickup, eligible lateral probes and new flow probes. Transferred Water
telemetry counts mass units; resident active activity blocks include excluded
work and are distinct from scheduled cores or visited cells. Timing includes the
instrumented whole tick and is reported alongside ns/visited cell. The dated
shared-host screen does not establish a universal or isolated speedup.

Observation export contains recipe/seed, resolved profile/hash, floor, last tick,
platform, UTC and up to 256 lab controls; pair it with the source/artifact manifest.
It is not complete replay: arbitrary brush strokes, player input and OS scheduling
are not all captured. Scheduled +30/+90 releases are tick-relative; changing floor
cancels them. Current camera interest can include part of an adjacent floor, so
its reagents may age. Fresh tower restores everything reproducibly.

## Planned #19 Water Feel Lab extension

**Planned, not Current:** issue #19 expands the Tower as the shared human-test
apparatus rather than creating another laboratory application. The current five
floors and #13 evidence above remain unchanged historical/current facts until the
new work is implemented and validated.

The #19 extension is specified by
[`fractional-presentation.md`](architecture-programme-prompts/fractional-presentation.md)
and the dated
[Water-feel programme addendum](architecture-programme-water-feel-addendum.md).
Its goal is to leave the Tower **H-ready**, not to select a preferred Water model.

The planned lab adds deterministic Water scenarios covering broad/deep/shallow
pools, connected levels, tiny-drip accumulation, channels/steps/U-vessels,
constrictions, fast and slow releases, ledge sheets, thin streams, drizzle,
vertical/horizontal/diagonal emission, excavation/refill, cavities/barriers,
Water/Sand interaction, supported films/seams and long-tail settling. Existing
Mercury references remain separate preservation controls.

The same planned runtime Water experiment policy will be selectable without a
rebuild through an in-game developer panel, versioned config/profile and launch
configuration. Those surfaces resolve to one validated effective policy. Planned
semantic candidates include Water mass precision 3..8 bits and coherent duration
0..12 ticks; this is semantic emulation in a superset test representation, **not
production Cell repacking**.

Simulation-semantic changes use validated **Apply + Reset Experiment** at the
exclusive owner boundary. The normal A/B path never requantizes an already-running
world in place. Render-only presentation controls may switch live where safe.

Human-test comparisons hold the intended four-visible-level Water presentation
fixed unless the experiment explicitly studies rendering. Anonymous A/B/C labels,
identical recipes/seeds/camera/player starts and hidden candidate mappings are
planned so observations can be recorded before identities are revealed.

Before novel 3/5/7-bit or shortened-coherence candidates are treated as valid
human-test inputs, the runtime harness must reproduce relevant #17 mass4/6/8 and
current mass8/coherence12 semantics and preserve the required hard invariants.
Quantitative differences such as levelness or settling remain descriptive context;
later human evaluation, not this runbook, decides whether they are desirable.
