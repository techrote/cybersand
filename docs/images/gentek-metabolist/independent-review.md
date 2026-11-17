# Independent review — Metabolist Spine

**Final disposition: no unresolved substantive finding in the reviewed scope. Preserve Draft / HOLD.** This review does not provide owner aesthetic acceptance or authorize merge/Ready promotion.

The reviewer is a separate agent who did not author production code or publish GitHub messages. Findings below were sent to the implementation owner, repaired, and checked again.

## Exact reviewed source

| Identity | Value |
| --- | --- |
| Source commit | `18215b08c0555922d5e5096a38c4b67af9c6b26f` |
| Source tree | `d52975f369e97fa0e88b0ff3c0a669e6fe565a46` |
| Frozen parent | `615828b28337f85e4663e03ba479616db4ddf764` |
| Isolated PR | [#666](https://github.com/techrote/cybersand/pull/666) |
| Native sampler | `native/src/generation_architecture_metabolist.inc` |
| Gallery | `build/metabolist-spine-gallery` |
| Canonical qualification | `build/metabolist-qualification/qualification.json` |

The final PR metadata was independently read: open, Draft, unmerged, with base `experiment/gentek-classic-001-20261115` at the exact parent above. The final code/qualification repair delta was reviewed; the architectural source did not change after its frozen geometry review.

## Findings and resolution

- **Integration failure, resolved before this review's frozen geometry:** the first candidate failed the unchanged first-128-square catalogue occupancy gate because its core was too far from the origin. The repaired source places the first core one bay into the map while keeping three-bay nearest-core spacing. The original failure is retained separately; the acceptance threshold was not weakened.
- **P2, resolved: qualification identity and cached compiler reuse.** Final tooling rejects dirty/uncommitted input bytes, checks HEAD/tree and inputs before/after, and forces a fresh named-compiler build. Seven temporary-Git provenance faults independently rerun and passed, including hidden assume-unchanged edits and same-tree HEAD movement.
- **Nonblocking interface mismatch, resolved:** ordinary preset validation now mirrors native wall-dependent minimum room/floor dimensions, with admitted/refused edge tests at wall 1/3/5.
- **CI-discovered adapter/contract issue, verified resolved:** explicit CLASSIC metadata expectations preserve true legacy behavior, and the new module advertises its schema-4 minimum. The source-built Godot and parity jobs passed.

## Independent evidence checks

- Focused native test execution independently rerun: **204,424 assertions, pass**. The final CI repeats the focused test from a fresh build of the exact source.
- Both inherited architecture include files compared byte-for-byte with the frozen parent: unchanged. Final parent/candidate snapshots independently compared: all 72 CLASSIC samplers and Viaduct v1/v2 preserve **3,637,248 material cells**, native fingerprints and chunk receipts across their retained fixtures.
- **87 gallery source inputs** independently hashed against committed bytes at the named source. The final qualification's own committed input ledger and clean/source identity matched.
- **50 native captures +7 composites** independently checked against recorded hashes. All **15,204,352 native pixels** exactly match retained raw material IDs mapped through the committed `BASE_RGBA8` palette. No authored renderer was imported for this verification. The retained exact-source ZIP was independently opened and every archived input plus its source ledger matched the same manifest.
- Actual PNGs opened and visually inspected: `02-hero-landscape.png`, `contact-controls.png`, `contact-comparisons.png`.

The focused actual-cell sweep covers 32 seeds × walls1/3/5: continuous core rails, every emitted attachment rooted, bounded cantilevers, a complete vacant attachment band and 45 actual bridge instances reaching both endpoints. The final 32-seed gallery has 32 distinct native hashes, occupancy 19.58–27.94%, logical attachment counts 14–19, represented family counts 4–6 and bridge counts 0–4. The metadata ledger's declared count scope includes clipped outermost logical slots; these counts should not be described as fully visible building counts.

Machine-readable independent results are retained in `review-metabolist-final-attestation.json`; the independent read-only checker is `review_verify_campaign.py`. Complete CI step/log observations are in `review-ci-final.json`.

## Architectural judgment

The continuous service spine is visibly primary. Six private families provide compact pods, tall open frames, knee-braced platforms, stepped glazed habitats, hanging modules and open outriggers. Selection is per logical attachment, not per-pixel noise. The two sides of a bridge use a shared immutable boundary identity and common floor datum. Reserved empty bands and bounded reach preserve substantial negative space.

Actual matched images show a heterogeneous occupied/vacant programme rather than a regular alternating shelf pattern. Bay, floor, wall, windows and door settings alter the expected features. Sampling is bounded integer arithmetic with immutable state and no allocation, search, mutable World read or neighbour solver. The source anchors to module origin and preserves relative geometry under signed translation and chunk partitioning.

## CI and ordinary preset confirmation

[Final branch qualification run 43972681556](https://github.com/techrote/cybersand/actions/runs/43972681556) completed **success** at the exact source. The reviewer fetched every job's steps and decoded native/Godot/verify logs independently:

- All nine native generation suites pass with strict hosted GCC 13 flags, including procedural generation 416,267 assertions, typed fields 14,162, semantic grammar 208,725 and semantic planes 774,842 with zero failures.
- Source-built Godot 4.7 ordinary project contract: **2,778 checks, zero failures**.
- Native Architectural Generator campaign: **2,490 checks, zero failures, complete=true**, with 73 distinct CLASSIC maps.
- The verify job independently compares the ordinary selectable preset's material SHA-256 with the standalone native hero and passes.

The adapter repair adds the new module to explicit schema-4 metadata; it does not introduce a new recipe schema or remove valid legacy expectations. No existing 72 sampler is repurposed. The scope remains v1-only through the existing CLASSIC preset/compiler/preview path.

## Performance review

The final exact-source benchmark uses bay96 / floor88, seed 271828, wall 3 and chunk 64. Seven measured warm trials follow one warm-up; module order rotates. Timing includes full native chunk generation, allocation and content hashing, with preparation excluded.

| Module |512² median ms |1024² median ms |
| --- | ---: | ---: |
| `cantilever_spine` | 249.51 | 1056.77 |
| `shelf_stack` | 260.78 | 998.99 |
| `staggered_balcony` | 247.11 | 993.07 |
| `metabolist_spine` | 264.07 | 1017.38 |

These matched measurements show no material native-generation regression. They are comparative observations on the shared host, not end-to-end UI/GPU latency guarantees.

## Remaining limitations

Map/style edges can clip architecture. Logical programme metadata does not create or modify pixels; support assertions use native emitted materials. Finite seed coverage and connected material paths do not certify structural stability or playable interiors. Physical GPU/framebuffer and Windows owner acceptance remain outside this native preview review.
