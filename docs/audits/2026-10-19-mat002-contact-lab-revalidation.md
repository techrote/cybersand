---
title: MAT-002 contact-lab recipe and phase-inventory revalidation
status: Current
document-kind: evidence
scope: Exact-source Linux reproduction of the stale Steam-count expectation, focused recipe-v2 quantity/worker-parity regression and source-only ACT-005 integration review
canonical-for: []
last-reviewed: 2026-10-19
related-documents: [2026-10-18-mat002-phase-quantity.md, 2026-09-19-issue-28-ms001.md, ../operations/microscenario-reference-pack.md, ../systems/water-design.md, ../systems/intermaterial-interactions.md]
---

# MAT-002 contact-lab revalidation — 2026-10-19

## Frozen failure and ownership

[PR #162](https://github.com/techrote/cybersand/pull/162), source head
`19f7ff43ecc494185226d1fff07dc21ef4a220fb`, changes partial Water phase inventory
and cumulative hot-material quenching under issue #160. Its ordinary
[Linux regression shard](https://github.com/techrote/cybersand/actions/runs/39105610881/job/117611494960)
fails `test_microscenario_materials_lab.gd`: 233 assertions, one failure at the
combined Stone/Steam count assertion. The exact source and retained Linux runtime
reproduce that failure locally. This is an unrevalidated moving-contact trace;
the native full-contact product/probability oracle remains a separate control.

The correction versions only the affected contact-lab and generated Lava/Water
recipes. Their ordinary geometry, Water reservoir, shelf release, native kernels,
runtime binaries and dependency pins are unchanged. Other Materials Laboratory
recipes stay at version 1. The
[historical MS-001 evidence](2026-09-19-issue-28-ms001.md) retains its original
384-Steam observation and named runtime. A prior valid trace is not rewritten as
though it ran against MAT-002.

## Exact phase inventory

At seed 2 and tick 120, the sealed quench bay `[180,68,124,176]` has the following
results under `int.current-behaviour` profile 2:

| Recipe | Lava dose | Stone | Steam parcels | Steam quantity histogram | Remaining Water | Steam quantity | Combined aqueous quantity |
|---|---:|---:|---:|---|---:|---:|---:|
| Three-bay contact lab | 384 | 384 | 386 | `255:384, 171:1, 208:1` | 1,545,941 | 98,299 | 1,644,240 |
| Single-bay Lava/Water, dose 32 | 384 | 384 | 386 | `255:384, 171:1, 208:1` | 1,545,941 | 98,299 | 1,644,240 |
| Single-bay Lava/Water, dose 16 | 192 | 192 | 194 | `255:192, 48:1, 208:1` | 1,595,024 | 49,216 | 1,644,240 |

Each reservoir starts with 6,448 full Water cells (`6,448 * 255 = 1,644,240`)
and no Steam or Ice. Each result has zero remaining Lava and zero Ice. The
full-dose excess over `384 * 255` coolant units is 379, retained in partial Steam
parcels under the admitted completion-overshoot rule. A parcel-count-only ledger
would incorrectly treat all 386 Steam parcels as full and overstate this snapshot
by 131 units. These measurements establish the bounded software trace; they are
not energy calibration or a universal per-contact product ratio.

A separate read-only diagnostic captured 38 native snapshots for each 1/4-worker
configuration at ticks 0, 12, 24, 48, 60 through 90, 120, 180 and 240. All 76
snapshots conserved the initial aqueous quantity and retained 384 combined
Lava/Stone cells. Counts, quantity histograms, partial Lava state and content
hashes matched between worker configurations. At tick 73, Lava at `(222,193)`
retains progress 208; at tick 74 the same progress is at `(222,194)` after motion.
All Lava is Stone by tick 89. The two partial Steam quantities remain through
the declared 240-tick window. Per-thread utilization is not exposed by these
snapshots and is not inferred from the worker configuration.

Salt/Brine and non-reacting Sand controls remain unchanged: final Salt 0, Brine
768, Sand 384. The combined phase ledger is confined to the sealed thermal bay;
it does not claim conservation across Salt/Brine chemistry or arbitrary edits.
The host's existing explicit-edit ledger and liquid-only `water_integer` observer
retain their original scope.

## Corrected recipe and regression

The affected generated definitions use `recipe_version = 2`, a presentation
profile ending in `v2-phase-quantity`, and an explicit MAT-002 baseline and
source-recipe identity. Their geometry/action ancestry hash stays unchanged;
their complete definition hash changes. The GUI and CLI still consume the same
schema-2 data through the unchanged host, and captures retain the full definition.

The focused regression retains exact Stone and Steam parcel counts and also
decodes owned native CYSD1 cell snapshots at setup, during contact, at tick 120
and, for the lab, tick 240. It sums Water `a` and decoded Steam/Ice `b` quantities,
checks the exact final partial-parcel histogram, compares the independent native
Water observation, and verifies conserved phase inventory and retained Lava/Stone
counts throughout its sampled contact stages. It compares those results, declared
observations and content hashes under worker configurations 1 and 4 for all three
rows above. Transactional replacement rejection, fresh reset and the other lab
controls remain exercised.

The existing native `phase_quantity_tests.hpp`, Godot phase/save regression and
full-contact/probability oracle are unchanged. They establish semantic controls
independently of this specific moving-contact trace. The correction does not
replace the old failed expectation with a broad presence-only assertion.

## Executed validation and integration boundary

This record describes a local correction on top of the PR head above; it does
not declare a merge or exact-head hosted acceptance. Only the following two
executable GDScript files differ from that head in this focused correction:

| Tested file | SHA-256 |
|---|---|
| `godot/scripts/microscenario_reference_pack.gd` | `1f39a2c8281e1a92f7f2f4be167e3aae1b3889b8fd83a0acb1340e8a6ed766cf` |
| `godot/tests/test_microscenario_materials_lab.gd` | `f8593f2d8dcb8d7a4b6b722963f57e930a868e0f22e5c69c9bb05840a2a5e24c` |

The runtime source is `b2691594bdc27622979f52df0b9969e8da185b4f`; all 30 manifest
source-input hashes match the PR's native Git blobs. The retained Linux extension
is 1,635,176 bytes, SHA-256
`a4ed004b81d68200f5142c96b6bbff1ee76d4ebd3c087af28a8b7e121bc1d00e`.
Godot is `4.7.stable.official.5b4e0cb0f`, on Linux x86_64, with Rapier 0.35.2.
The Godot executable SHA-256 is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`;
the retained Rapier extension SHA-256 is
`147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831`.

Commands use writable XDG data/config/cache directories and the pinned executable:

```sh
timeout 180s <pinned-godot> --headless --path godot \
  --script res://tests/test_microscenario_materials_lab.gd
timeout 180s <pinned-godot> --headless --path godot \
  --script res://tests/test_phase_quantity_regression.gd
```

The corrected material-lab test passes **615 assertions, zero failures**, in
**29.027 seconds**. The unchanged phase/save regression passes **1,378 assertions,
zero failures**, in **0.766 seconds**. The measured runs use the existing
180-second case limit; the lab's 240-tick and single-bay 120-tick horizons are
unchanged. Both exit zero without engine/script diagnostics. The original
233-assertion failure remains separately retained as the before-correction result.

Documentation structure and ordinary repository identity checks pass with no
errors/warnings after supplying the isolated checkout's five required companion
workspace inputs; the initial absence of those files was an environment-only
documentation failure. Only the two Linux libraries are materialized for this
focused execution, so this is not an all-platform materialization claim. M11
integrity passes for 18 records and 28 source hashes. Retrieval retains 32/32
top-five and 22/32 top-one frozen-question hits (MRR 0.8281), and 38/38 top-five
and 28/38 top-one supplementary hits (MRR 0.8496). The existing canonical
reference-pack page owns the updated recipe/accounting claims and links this
evidence; no new corpus owner, API, capacity, architecture decision or execution
ordering change is introduced. `git diff --check` passes.

Later integration with current main must retain its newer native interfaces and
generation/lifecycle inputs. This older PR runtime is source-matched for the
focused test above; it is not a valid replacement for a newly combined native
tree. Conflict reconciliation requires fresh combined-source runtime publication
and all applicable exact-head normal merge gates. No additional native sanitizer,
Windows execution, browser, graphical or game-feel acceptance follows from these
Linux headless results.

## Read-only ACT-005 integration review — 02:18 UTC

The focused correction is recoverable at
[`71ae8a5007940bc4ab95f956f58bc7df3cc6ba31`](https://github.com/techrote/cybersand/commit/71ae8a5007940bc4ab95f956f58bc7df3cc6ba31)
on `codex/issue-160-contact-fixture-20261019`. A separate source-only review
compared PR #162 `19f7ff43ecc494185226d1fff07dc21ef4a220fb` with the ACT-005
candidate `b4e2cb7ac71816239628b94a8d4240e364e7a649`, using a temporary merge-tree.
ACT-005 was still awaiting its exact-head native gate at this review; neither a
completed ACT-005 merge nor a combined MAT-002 runtime is claimed here. PR #179
was excluded from this review and remains a separate integration responsibility.
The correction adds no native input changes.

No new native semantic incompatibility was found in the inspected body and
generation interfaces. This is a source-review result, not execution evidence:

| Intersection | Source-confirmed finding |
|---|---|
| Body identity and capacity | The merged `World::kMaximumTransientBodies`, adapter `parse_body_states` and `rigid_body_id_at` retain the current 64-body limit, finite record validation and composed occupancy query. Phase state bytes do not share body identity storage. |
| Masked phase contact | `World::update_cell` refuses masked sources. Phase quantity reads use occupancy-aware access; masked neighbours appear as Wall instead of exposing hidden Steam/Water. |
| Physical relocation | Adapter overlap reconciliation uses `relocate_stored_cell`; the move paths copy the complete cell payload, preserving partial Steam quantity and unfinished hot-material quench progress. |
| Generated chunk admission | `install_generated_chunk` retains absent-chunk and body-mask admission and initializes material IDs through `World::set`. New Steam/Ice use the full-parcel zero sentinel; new Lava/MoltenGlass start with zero quench progress. |
| State lanes and wake behavior | Water's reduced delay mask does not truncate the eight-bit Steam/Ice/Lava/MoltenGlass payload. Phase writes retain the existing dirty, activity, discovery and pending-reaction wake paths. Visual projections continue to expose their documented appearance channels rather than phase inventory. |

### Authored usable recipes remain outside the closed phase ledger

The ACT-005
[usable accounting contract](https://github.com/techrote/cybersand/blob/b4e2cb7ac71816239628b94a8d4240e364e7a649/docs/systems/actor-usables.md)
explicitly describes authored slot recipes and excludes universal mass/economy
conservation. In that candidate, U27 Steam Condenser consumes one Steam slot and
emits one freshly initialized Water slot. The path is `usable_catalog.gd`'s
`steam_condenser`, `usable_runtime.gd::_object_cycle`, the physical runtime's
`_write`, native `emit_disc`, then `World::set`; it reads material identity rather
than the Steam quantity byte.

Source inspection therefore implies that after the future MAT-002 join, an
admitted partial Steam parcel of quantity `q` can produce a full Water cell of
quantity `M`, adding `M - q` units through this authored recipe. Under the default
policy, a one-unit Steam parcel could produce 255 Water units. This intersection
was not executed in the read-only review. It is outside ACT-005's promised
accounting envelope, and it must also be named explicitly among the MAT-002
phase contract's sources/sinks when the branches are integrated. Do not extend
the closed native phase conservation claim to all equipment Steam-to-Water
behavior. A quantity-preserving processor would require a separately scoped
recipe and bounded quantity read/write interface change.

### Premises for the future combined-runtime regression

`native/include/cybersand/demo_snapshot.hpp::copy_level` clears transient masks
while exporting stored temperatures. The present `quench_snapshot` measurement
uses a body-free fixture. A later phase/body regression must observe its mask
condition before export, or reinstall the same body frame afterward; otherwise
the measurement removes the condition under test.

`microscenario_reference_pack.gd::PHASE_BASELINE` remains the registered recipe's
historical lineage at `b2691594bdc27622979f52df0b9969e8da185b4f`. Future combined
source and loaded-runtime identities need a separate receipt; that recipe string
does not identify a newly built extension.

Before accepting a combined candidate, preserve the reviewed interfaces and the
exact recipe-v2 quantity/histogram controls, reconcile the usable accounting
exclusion, and publish fresh Linux/Windows runtime artifacts with all current
native source inputs. Focused intersection checks should cover body ID 64 masking
a partial phase contact, relocation of partial Steam/quench progress, and default
phase initialization through generated-chunk installation. Those checks, the
combined runtime and its hosted gates remain future work. No executable source,
runtime, dependency or earlier measured result was changed by this review.

This documentation-only checkpoint passed the documentation and ordinary
repository identity checks, historical M11 integrity (18 records, 28 hashes),
and whitespace validation. Retrieval remained 32/32 frozen and 38/38
supplementary top-five hits, with 22/32 and 28/38 top-one hits respectively.
The focused runtime tests above were not rerun for this evidence-only addition.
