---
title: Architecture experiment: fractional liquid presentation and Water Feel Lab
status: Current
document-kind: runbook
scope: Self-contained V plus H-preparation work item in the architecture experimental programme; presentation research and human-test infrastructure, not production approval or human preference selection
canonical-for: []
last-reviewed: 2026-09-13
related-documents: [../architecture-programme.md, ../architecture-programme-source-ledger.md, ../experiment-tower.md, ../state-precision-experiment.md, ../../audits/2026-09-11-issue-17-state-precision.md]
---

# Architecture experiment: fractional liquid presentation and Water Feel Lab

## Identity and dependencies

**Execution status, 2026-09-12:** V1 and V2 are complete and H-ready. The frozen
contract below is retained as the preregistered acceptance boundary. Exact source,
artifacts, review findings and limitations are in the
[completion record](../../audits/2026-09-12-issue-19-water-feel-lab.md). No human
preference, production migration, #18 admission, #20 admission or G-final decision
was made.

Issue: [#19](https://github.com/techrote/cybersand/issues/19).
Programme/workstream: V, expanded after G-P with H-preparation. Human preference/acceptance remains a later gate.

Completed prerequisites and inputs:

- #15/G-C supplies current liquid characterization and stable Water cases.
- #16/G-L supplies representation/packing evidence but selects no production Cell width.
- #17/G-P supplies the quantitative precision oracle. Mass8 remains the numerical reference; existing Water coherence 0..12 is exactly representable in four bits.
- #13 supplies the reusable Experiment Tower, deterministic recipes, profile/reset concepts and human-facing testing precedent.
- #18 remains held for a concrete directional-persistence target. This issue may prepare observations that later justify such a target, but does not implement flow memory.
- #20 remains blocked by #18/G-M and its own admission.

This prompt is executable without the original architecture conversations.

## Objective

Complete two separable stages:

1. **V1 — fractional presentation.** Establish an intended compact Water presentation based on four visible partial-fill levels, with local interface reconstruction where useful, while authoritative simulation remains unchanged for presentation comparisons.
2. **V2 — Water Feel Lab / H-preparation.** Extend the existing Experiment Tower into a broad deterministic Water testing environment and provide runtime-selectable Water semantic policies so later blinded human assessment can compare meaningful state budgets without recompilation.

#19 must finish with a trusted, reproducible laboratory. It **must not select the perceptually preferred Water precision, coherence duration, production Cell packing or gameplay default**.

## Why this work exists

#17 established what changes numerically when Water precision changes. It did not establish which differences matter perceptually in a game. A numerically more faithful liquid can still look or feel worse; a coarser model can be visually acceptable or preferable. Conversely, subjective preference cannot waive conservation, ownership, determinism, bounded work or failure/region contracts.

The intended Water renderer exposes only a small number of partial-fill levels. Therefore internal state precision and visible precision are distinct questions. The programme needs a controlled way to judge behavior under a fixed presentation before spending reclaimed bits on new state or declaring mass8 perceptually necessary.

**Programme principle:** quantitative equivalence and perceptual adequacy are separate gates. Quantitative diagnostics describe differences; correctness establishes safe observation; later human evaluation determines desirability.

## Relevant Current architecture and protected decisions

Work in `C:/kybersand/source`; read `C:/kybersand/AGENTS.md`, source `AGENTS.md` and their required focused docs before changes. Use a separate `codex/` worktree/branch. Preserve the deliberately dirty Windows DLL and unrelated work; keep raw logs/builds under `C:/kybersand` rather than functional deliverables.

Current production Water uses 8-bit fractional mass, a 12-tick coherent-emission countdown in Water state_b, exact closed-operation integer conservation, local three-quarter lateral redistribution, one-unit tolerance and the existing supported-film policy. Material authority remains native; transient rigid-body occupancy remains outside persistent Cell state; immutable render handoffs, failed-world quarantine and paused interest-region semantics remain protected. #10/#13 granular/player/Mercury/transport policies remain distinct controls.

Geometry is independently 128x128 storage,32x32 activity,64x64 scheduling core, maximum write radius2 (68x68 expanded domain). Native liquid operations are local; do not copy fallback long-range Water. Desktop pacing is asynchronous against main-thread Rapier; native Web waits synchronously, with optional internal workers. Fallback and serial have different semantics. Current rectangles lack general pixel membership. #11 now satisfies the support prerequisite only within its documented ordinary rectangle/load envelope; preserve high-energy/general-shape limits.

Completed #17 used a fixed wider experimental carrier and compile-time precision arms to isolate science. Those compile-time controls are evidence, not a requirement for the Feel Lab. V2 may emulate lower semantic precision in a superset runtime storage lane; it does not physically repack the production Cell or reinterpret old saves.

## Stage V1 — fractional presentation

### Presentation question

Can a compact **four-visible-level** fractional Water presentation, optionally assisted by local 3x3 mass-gradient/interface reconstruction, improve readability and appearance of surfaces, droplets and thin streams without changing authoritative simulation state?

### Required modes and cases

Retain current display behavior as a reference and implement a selectable experimental four-level partial-fill path. Evaluate local gradient/interface orientation where useful and deterministic fallbacks where orientation is weak or ambiguous.

Cover at least:

- top surfaces and settled horizontal pools;
- undersides and overhang-adjacent Water;
- left/right vertical boundaries;
- diagonal boundaries and slopes;
- concave/U-shaped cavities;
- one-cell/thin jets and ledge sheets;
- isolated small droplets/partial cells;
- supported slope films;
- adjacent continuity across cell/storage/activity/core seams;
- 1x and representative enlarged display scales;
- temporal stability/flicker on known sequences.

Do not mutate authoritative mass to make rendering easier. Render-only modes may hot-switch live if the handoff remains immutable and simulation authority is untouched.

### Presentation instrumentation

Record as appropriate:

- rendered coverage error versus normalized authoritative mass on synthetic/frozen frames;
- orientation/boundary discontinuity failures;
- temporal flicker on fixed sequences;
- CPU snapshot/copy cost and publication bytes/high-water;
- actual upload size and GPU/render timing where measurable;
- authoritative content/hash/activity equality across presentation modes;
- delayed-consumer/immutable-snapshot regressions.

Do not infer a GPU, cache or bandwidth benefit from visual appearance or patch size alone.

## Stage V2 — Water Feel Lab infrastructure

Reuse and extend #13's Experiment Tower instead of building an unrelated benchmark application. Add a dedicated Water Feel Lab floor, annex or equivalently clear selectable environment with deterministic recipes, a known seed/input schedule and one-action fresh reset.

### Required scenario families

| Scenario family | Required cases / purpose |
|---|---|
| Flat pooling | Broad shallow basin, deep basin, wide calm settling, connected pools at unequal starting levels. |
| Small quantities | Isolated partial cells, repeated tiny drips accumulating into visible Water, low-flow trickle, residual pockets. |
| Channels / geometry | Narrow and broad channels, stair/step terrain, U-shaped vessel, constriction/nozzle, irregular/sloped bed. |
| Releases | Fast reservoir dump, slow gate opening, vertical fall, ledge sheet, thin stream, shower/drizzle. |
| Directional reference | Vertical jet plus horizontal/diagonal emission cases suitable for later #18 target/no-go discussion. |
| Terrain interaction | Excavation then refill, support removal, cavity filling/draining, real voids and barriers. |
| Material interaction | Water over/through Sand using preserved #13 Baseline policy; downstream transport/deposition observations. Keep Mercury reference separate and protected. |
| Player/body interaction | Player disturbance where supported; representative rigid-body displacement only when the existing source-matched path already exists and does not broaden this issue. |
| Films / boundaries | Supported film, side/underside interfaces, droplets crossing storage/activity/core seams. |
| Long-tail feel | Settling, lingering micro-motion, apparent stickiness/crawling, abrupt stopping and repeated identical resets. |

For semantic comparisons use the intended four-level presentation unless the tester explicitly enters a presentation study. The UI must make it difficult to unknowingly vary both render precision and simulation precision at once.

## Runtime Water semantic policy

Implement one validated policy object consumed at World construction/restart. Follow repository naming conventions, but conceptually include:

```text
WaterExperimentPolicy
  mass_bits               integer 3..8
  coherence_ticks         integer 0..12
  rest_policy             registered enum/policy; current-normalized default
  render_fill_levels      default 4; presentation-only
  interface_mode          presentation-only
  scenario_id
  seed / deterministic recipe identity
```

Precompute derived values such as mass maximum, normalized film threshold and rest tolerance at configuration time rather than repeatedly calculating setup values in the hot loop.

### Mass precision candidates

Support every integer Water mass width **3, 4, 5, 6, 7 and 8 bits** without recompilation.

These widths describe semantic quantization inside a superset experimental storage representation. They are not distinct production layouts and do not authorize cross-cell bitstream packing. Use #17's nearest/half-up physical quantization rule unless an alternative policy is separately named and registered. Preserve an exact integer ledger within each candidate lattice; distinguish initial quantization error from runtime drift.

Mass8 is the source/numerical reference. Mass4/6/8 must correspond to #17 sufficiently to trust the runtime harness. Mass3/5/7 are new human-test candidates and require focused arithmetic/correctness characterization, not a full #17 timing campaign. Mass10 remains available as external #17 higher-precision evidence; it need not become a routine Feel Lab runtime setting.

### Coherent-duration candidates

Allow runtime selection of `coherence_ticks` across **0..12**, with named convenience candidates:

- 12 — current behavioral reference;
- 7 — maximum duration that fits a 3-bit semantic field;
- 3 — aggressive shorter-coherence / 2-bit-maximum candidate;
- 0 — no-coherence behavioral reference.

Do not confuse semantic duration with storage width. Existing 0..12 semantics require four bits if retained exactly. Shortening the maximum deliberately changes behavior and is a later perceptual candidate, not a lossless representation result.

## Runtime configuration surfaces

Expose the **same normalized policy** through:

1. an in-game developer popup/panel;
2. a versioned profile/config file;
3. launch arguments or the closest existing launch-configuration mechanism.

Do not create three independent policy implementations. Each surface must resolve into one validated effective policy. Show/export effective values and their source/provenance.

Example intent, not prescribed spelling:

```text
--water-mass-bits=5
--water-coherence=7
--water-render-levels=4
--water-interface=oriented
--experiment=shallow-pool
--seed=18472
```

Keep these test profiles separate from ordinary world-save compatibility unless existing versioned profile infrastructure already offers a safe place.

## Apply/reset and threading semantics

Simulation-semantic policy must not change underneath active workers.

Preferred flow:

1. pause/open Water Feel Lab panel;
2. choose/edit policy;
3. validate complete policy;
4. **Apply + Reset Experiment** at the existing exclusive owner boundary;
5. construct/reset a fresh deterministic world/recipe with that policy;
6. run, pause, single-step or restart the identical scenario.

Invalid application leaves the running World and active configuration unchanged. Render-only settings may switch immediately where safe.

Do not use arbitrary live conversion of existing Water from one mass lattice to another as the normal A/B method; that adds a new quantization event and confounds comparison. A live-conversion robustness test may be separate and clearly labeled.

## Blind and A/B preparation

Prepare the later human experiment; do not perform its final preference decision here.

Support anonymous candidate labels such as A/B/C. A blind set maps labels to complete policies while retaining the hidden mapping in exported metadata.

The tester must be able to:

- choose a scenario/seed;
- select or randomize a candidate set;
- run candidate A;
- reset the identical scenario under B/C/etc. with one action;
- preserve starting camera/player position and scheduled release sequence where applicable;
- record observations before optional reveal;
- export enough metadata to reconstruct exact tested configurations.

## Ground-truth and trust gate against #17

Before new candidates are considered H-ready, demonstrate:

- runtime mass8 reproduces current/source-authoritative behavior in shared fixtures;
- runtime mass4, mass6 and mass8 reproduce #17 semantic/ledger expectations sufficiently for the common scenarios used by this issue;
- current coherence12 reproduces source behavior;
- widened/superset test storage does not alter current coherence semantics;
- initial quantization and runtime drift remain separately reported;
- worker1/4 and repeat behavior match where the native contract expects parity;
- observer/debug/UI presence does not silently change simulation results;
- every deterministic run records its effective runtime policy identity.

New mass3/5/7 and shorter coherence settings require focused conservation, boundary and low-quantity tests sufficient to exclude implementation errors and gross invalidity. Do not automatically repeat #17's complete process matrix.

## Controlled variables

### V1 comparisons

Change presentation only. Keep authoritative material/mass/activity/collision/epoch/input fixed.

### V2 semantic comparisons

Change only registered Water policy fields. Hold scenario/seed, presentation mode/four levels, viewport/camera/start state, release/input schedule, geometry/scheduler/worker configuration, #10/#13 interaction policy, unrelated material state and ownership/failure/region contracts fixed.

Combined mass+coherence candidates are allowed after isolated controls work, but #19 does not rank them.

## Quantitative context for later human judgment

For reproducible Feel Lab runs, expose/export as appropriate:

- effective policy/profile/version/hash;
- scenario, seed and release schedule;
- source/artifact/platform/worker identity;
- exact integer Water quantity plus explicit source/sink/outflow accounting;
- initial physical quantization error;
- optional visits/transfers/active-block/last-change/rest summaries;
- presentation mode/fill levels;
- screenshot/video hooks where existing infrastructure supports them;
- anonymous candidate label and hidden mapping for blind tests.

These diagnostics explain differences. They are **not an automatic desirability score**.

## Hard invariants versus perceptual questions

Hard failures include material loss/duplication, invalid ownership, nondeterministic policy application where determinism is required, unbounded work/capacity, broken region/failure behavior, unsafe mutation during worker execution, or inability to reproduce the declared candidate.

The following are observations rather than automatic rejection criteria in #19: basin residual, discharge amount, settling time, tiny-quantity survival, spread, active lifetime, abruptness, chunkiness or other deliberate consequences of semantic quantization. Later human evaluation decides whether such differences are acceptable or desirable for the game.

## Non-goals

- No production Water precision migration or production Cell repacking.
- No bitstream packing across Cell boundaries.
- No claim that mass8 is perceptually optimal or that lower precision is perceptually acceptable.
- No final human preference/owner sign-off.
- No universal velocity field, compact flow history, pressure/Navier-Stokes solver or #18 implementation.
- No sparse ballistic system or #20 implementation.
- No generalized liquid unification or reaction retuning.
- No relaxation of exact per-candidate closed integer conservation.
- No authoritative render orientation or full-Cell GPU upload solely for experimentation.
- No unrelated body renderer or connected-component centroid system.

## Repository touchpoints

Inspect actual source before implementation. Expected touchpoints include:

- `native/include/cybersand/world.hpp`, `native/src/world.cpp` for immutable World-level Water experiment policy and quantity semantics;
- existing #17 precision registration/evidence for reference math, not direct production adoption;
- `native/include/cybersand/render_snapshot.hpp`, `native/src/render_snapshot.cpp` and native adapter paths for compact immutable presentation data;
- `godot/shaders/material_palette.gdshader` and material appearance controls;
- `godot/scripts/experiment_tower.gd`, `tower_panel.gd`, `transport_profile_panel.gd`, `demo_worlds.gd` and native/Web demo bridges;
- `godot/tests/test_experiment_tower.gd`, presentation/handoff regressions and focused new Water-policy tests;
- `docs/operations/experiment-tower.md`, Water/material-appearance contracts, programme/status/retrieval docs.

Proposed new modules must be named as new rather than described as if they already exist.

## Preservation requirements

Preserve protected current behavior except where a registered Water candidate deliberately changes the tested semantic variable. Keep Mercury/powder references and #13 Baseline policy separate. Preserve state/temperature transfer, bounded work, immutable handoff, failed-world quarantine and paused region/re-entry contracts. Keep original controls and never reinterpret existing saves as a new layout.

Freed candidate bits are evidence for later packing/motion decisions. They do not authorize spending those bits in this issue.

## Validation

### Native semantic validation

- focused quantity/conservation tests for each supported runtime mass width;
- legal range validation and refusal tests;
- repeat and matching worker comparisons;
- mass8/current-coherence source reference comparison;
- shared #17 reproduction for mass4/6/8 sufficient to establish harness correspondence;
- mass3/5/7 arithmetic boundary and low-quantity tests;
- coherence 0..12 countdown/reset/merge checks as applicable;
- invalid Apply leaves current World intact;
- panel/profile/launch-argument resolution produces the same effective policy.

### Presentation/application validation

- actual native desktop walkthrough of every lab scenario;
- affected real Web compatibility/threaded path if the lab is exposed there;
- panel navigation, Apply+Reset, pause/single-step, deterministic reset, candidate switch and blind-label behavior;
- no accidental contamination between bays;
- readable experiment labeling without cluttering ordinary gameplay;
- immutable/delayed render consumer regressions.

Record unavailable platform targets rather than inferring acceptance.

### Documentation/repository validation

Synchronize this prompt, #19, architecture programme/current gate notes, Experiment Tower documentation, material appearance/Water contracts as planning/current-state appropriate, roadmap and retrieval routes. Preserve historical evidence and M11 hashes. Run required docs/history/repository/retrieval/diff checks and disclose inherited publication/provenance failures rather than rewriting them.

## Acceptance criteria

#19 completes only when V1 and V2 are both satisfied or an explicit evidence-backed no-go is recorded for a substage.

### V1

- four-level partial-fill presentation exists as a selectable documented experimental mode;
- orientation/fallback behavior is demonstrated on positive and negative cases;
- presentation modes leave authoritative simulation unchanged;
- coverage/artifact/cost and immutable-handoff evidence is retained;
- no production renderer is silently selected.

### V2

- #13 Experiment Tower is extended/reused with the broad Water scenario suite;
- runtime mass precision 3..8 is selectable without recompilation;
- runtime coherence duration 0..12 is selectable without recompilation, including named 12/7/3/0 candidates;
- panel, profile/config and launch configuration resolve to one policy implementation;
- semantic Apply uses validated Apply+Reset rather than worker-time mutation;
- deterministic reset, A/B switching and blind labels work;
- mass4/6/8 reference behavior corresponds to #17 sufficiently to trust the harness;
- mass3/5/7 and shortened-coherence controls preserve hard invariants and have focused characterization;
- effective policy/run identity is exportable;
- lab scenarios are manually verified in the actual application;
- no preferred Water state budget is selected by #19.

## Required evidence artefacts

- source/build/profile identities and commands;
- frozen/synthetic presentation frames and screenshot/video pairs;
- coverage/artifact/cost table;
- runtime policy schema, validation/range tests and provenance resolution;
- #17 correspondence results;
- scenario catalogue and deterministic recipe identities;
- representative run metadata from every supported semantic axis;
- native/app/Web scope results and known gaps;
- H-readiness statement listing safe/unsafe/unavailable candidates without ranking perceptual preference;
- updated programme/roadmap/retrieval documentation.

## Decision unlocked

V1 may support a separately reviewed presentation migration, but cannot approve wider Cells or altered Water semantics.

V2 may declare the Water Feel Lab **H-ready** and supply a set of technically safe, reproducible candidate policies plus descriptive quantitative context. A later human-led H gate may then classify variants as preferred/acceptable/unacceptable and identify concrete perceptual deficits for #18 admission or no-go.

This issue itself performs neither production migration nor the final human selection.
