# Independent review — Interlock Brutalism

**Final disposition: no unresolved substantive finding in the reviewed scope. Preserve Draft / HOLD.** This review does not provide owner aesthetic acceptance or authorize merge/Ready promotion.

The reviewer is a separate agent who did not author production code or publish GitHub messages. Findings below were sent to the implementation owner, repaired, and checked again.

## Exact reviewed source

| Identity | Value |
| --- | --- |
| Source commit | `9b8609d8011a95bb9516f02f3a67d2feaff6dee9` |
| Source tree | `05298c6f01fb25317b261f83987556b40f108550` |
| Frozen parent | `615828b28337f85e4663e03ba479616db4ddf764` |
| Isolated PR | [#669](https://github.com/techrote/cybersand/pull/669) |
| Native sampler | `native/src/generation_interlock_brutalism.inc` |
| Gallery | `build/interlock-brutalism-gallery-final` |
| Canonical qualification | `build/interlock-qualification-final/qualification.json` |

The final PR metadata was independently read: open, Draft, unmerged, with base `experiment/gentek-classic-001-20261115` at the exact parent above. The final code/qualification repair delta was reviewed; the architectural source did not change after its frozen geometry review.

## Findings and resolution

- **P2, resolved: disconnected void measurements.** Initial tests could combine the largest component's area with another component's vertical span. The final test requires one actual four-connected empty component to satisfy both substantial area and at least two-floor vertical span.
- **P2, resolved: explicit bridge endpoint proof.** Initial support flood fill proved connection to some core, which did not prove both bridge endpoints. Final black-box tests discover full-height inner core columns from emitted cells and require every bridge row to continue through both endpoints. The 32-seed thin/heavy sweep exercises 36 bridge programmes.
- **P2 qualification guard/compiler findings, resolved:** clean committed-input and HEAD/tree guards run before/after; fresh `make -B` avoids stale compiler objects. Source-built CI also exercises the provenance fault suite and corrected CLASSIC schema metadata contract.

## Independent evidence checks

- Focused native test execution independently rerun: **1,725 assertions, pass**. The final CI repeats the focused test from a fresh build of the exact source.
- Both inherited architecture include files compared byte-for-byte with the frozen parent: unchanged. Final parent/candidate snapshots independently compared: all 72 CLASSIC samplers and Viaduct v1/v2 preserve **3,637,248 material cells**, native fingerprints and chunk receipts across their retained fixtures.
- **87 gallery source inputs** independently hashed against committed bytes at the named source. The final qualification's own committed input ledger and clean/source identity matched.
- **63 native captures +4 composites** independently checked against recorded hashes. All **18,075,648 native pixels** exactly match retained raw material IDs mapped through the committed `BASE_RGBA8` palette. No authored renderer was imported for this verification. The retained exact-source ZIP was independently opened and every archived input plus its source ledger matched the same manifest.
- Actual PNGs opened and visually inspected: final `contact-controls.png`, `contact-32-seed-survey.png`, `comparison-native-scale.png`, plus the prefreeze landscape hero whose geometry is unchanged.

The final focused suite independently reran with 1,725 passing assertions. It covers signed/chunk/order/slice invariance, zero budget, concurrency/cancellation, schema/version/clearance, real controls, admitted minimum/odd dimensions and thick-wall support. The final 32-seed native captures have32 distinct hashes and occupancy 24.77–34.74%. Support is measured from actual cells rather than a geometric reimplementation.

Machine-readable independent results are retained in `review-interlock-final-attestation.json`; the independent read-only checker is `review_verify_campaign.py`. Complete CI step/log observations are in `review-ci-final.json`.

## Architectural judgment

A broad recessed concrete body opposes a narrow skeletal core. Grouped heavy fingers, offset thinner beams, root haunches, suspended returns and missing levels shape a substantial central chamber. Their common immutable supercell chooses orientation, core width, cadence and a rare shared bridge datum. The actual matched comparator establishes a hierarchy beyond Cantilever Spine, Double Cantilever, Buttress Wall and Shelf Stack.

The full 32-seed sheet shows changing asymmetry and bridge placement while retaining family identity. Thin/heavy and bay/floor controls preserve legible negative space. The source is bounded integer arithmetic over immutable parameters, with no per-cell heap allocation, search, mutable World state or negotiation framework. Absolute signed coordinates make ordinary bounds clip rather than rephase geometry; the existing optional shaft is intentionally bounds-relative.

## CI and ordinary preset confirmation

[Final branch qualification run 43972891232](https://github.com/techrote/cybersand/actions/runs/43972891232) completed **success** at the exact source. The reviewer fetched every job's steps and decoded native/Godot/verify logs independently:

- All nine native generation suites pass with strict hosted GCC 13 flags, including procedural generation 416,267 assertions, typed fields 14,162, semantic grammar 208,725 and semantic planes 774,842 with zero failures.
- Source-built Godot 4.7 ordinary project contract: **2,756 checks, zero failures**.
- Native Architectural Generator campaign: **2,490 checks, zero failures, complete=true**, with 73 distinct CLASSIC maps.
- The verify job independently compares the ordinary selectable preset's material SHA-256 with the standalone native hero and passes.

The adapter repair adds the new module to explicit schema-4 metadata; it does not introduce a new recipe schema or remove valid legacy expectations. No existing 72 sampler is repurposed. The scope remains v1-only through the existing CLASSIC preset/compiler/preview path.

## Performance review

The final exact-source benchmark uses bay64 / floor64; the hero uses bay80 / floor72, seed 271828, wall 3 and chunk 64. Seven measured warm trials follow one warm-up; module order rotates. Timing includes full native chunk generation, allocation and content hashing, with preparation excluded.

| Module |512² median ms |1024² median ms |
| --- | ---: | ---: |
| `cantilever_spine` | 238.57 | 974.94 |
| `double_cantilever` | 252.25 | 1014.11 |
| `shelf_stack` | 237.00 | 973.76 |
| `interlock_brutalism` | 239.49 | 989.29 |

These matched measurements show no material native-generation regression. They are comparative observations on the shared host, not end-to-end UI/GPU latency guarantees.

## Remaining limitations

The brief allows occasional full connections. A full width bridge partitions a 2D cross-section. Qualification proves a substantial connected chamber spanning at least two floors, sparse bridge rows and more than half central negative space; it does not establish an uninterrupted top-to-bottom gameplay route. This interpretation is explicit in the source documentation. Connected material is not structural-physics certification. Physical GPU/framebuffer and Windows owner acceptance remain open.
