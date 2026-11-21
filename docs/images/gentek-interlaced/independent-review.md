# Independent review — Interlaced Viaduct

**Final disposition: no unresolved substantive finding in the reviewed scope. Preserve Draft / HOLD.** This review does not provide owner aesthetic acceptance or authorize merge/Ready promotion.

The reviewer is a separate agent who did not author production code or publish GitHub messages. Findings below were sent to the implementation owner, repaired, and checked again.

## Exact reviewed source

| Identity | Value |
| --- | --- |
| Source commit | `8f39f68ae1bcf81045b007e233b2e6838cca4d24` |
| Source tree | `a4453f91437de3bef6e20bc4b3ea5b9c38467060` |
| Frozen parent | `615828b28337f85e4663e03ba479616db4ddf764` |
| Isolated PR | [#667](https://github.com/techrote/cybersand/pull/667) |
| Native sampler | `native/src/generation_interlaced_viaduct.inc` |
| Gallery | `build/interlaced-viaduct-gallery` |
| Canonical qualification | `build/interlaced-qualification-final/qualification.json` |

The final PR metadata was independently read: open, Draft, unmerged, with base `experiment/gentek-classic-001-20261115` at the exact parent above. The final code/qualification repair delta was reviewed; the architectural source did not change after its frozen geometry review.

## Findings and resolution

- **P2, resolved: incomplete qualification source boundary.** The initial qualifier read HEAD before compilation but hashed inputs only at the end and did not reject dirty inputs. The final qualifier binds on-disk bytes to the exact committed archive, rejects dirt/untracked build inputs, rechecks HEAD/tree and enumerates inputs again before publishing success. Eight real temporary-Git fault tests independently rerun and passed.
- **P2, resolved: cached compiler identity.** A normal make target could reuse objects made by another compiler. Final qualification forces `make -B -j2`, retains the candidate build command/log, and records the actual compiler and binary digest.
- **CI-discovered adapter/contract issue, verified resolved.** The new module now advertises schema-4 minimum metadata. The ordinary contract explicitly names all CLASSIC identities instead of treating their schema metadata as legacy-only. Genuine legacy assertions remain, with explicit v1-only CLASSIC checks. The source-built Godot and final parity jobs passed.
- Renderer source guards now check initial/final HEAD, tree, ledger and index; the final source archive is checked before success manifests are emitted.

## Independent evidence checks

- Focused native test execution independently rerun: **1,305 assertions, pass**. The final CI repeats the focused test from a fresh build of the exact source.
- Both inherited architecture include files compared byte-for-byte with the frozen parent: unchanged. Final parent/candidate snapshots independently compared: all 72 CLASSIC samplers and Viaduct v1/v2 preserve **3,637,248 material cells**, native fingerprints and chunk receipts across their retained fixtures.
- **87 gallery source inputs** independently hashed against committed bytes at the named source. The final qualification's own committed input ledger and clean/source identity matched.
- **26 native captures +4 composites** independently checked against recorded hashes. All **7,864,320 native pixels** exactly match retained raw material IDs mapped through the committed `BASE_RGBA8` palette. No authored renderer was imported for this verification. The retained exact-source ZIP was independently opened and every archived input plus its source ledger matched the same manifest.
- Actual PNGs opened and visually inspected: `01-hero-512.png`, `28-contact-controls.png`, `29-layer-comparison.png`, `30-classic-comparison.png`.

The authored source-layer diagnostic exercises 32 seeds and 207,491 checks, finds 32 different compositions and 30 crossing programmes, and checks independent primary/secondary contributions and bounded added crossing geometry. Its source and retained results were inspected; the reviewer did not implement a second geometric renderer.

Machine-readable independent results are retained in `review-interlaced-final-attestation.json`; the independent read-only checker is `review_verify_campaign.py`. Complete CI step/log observations are in `review-ci-final.json`.

## Architectural judgment

The thick primary arch/pier/deck language and lighter opposite-curvature suspended frame remain independently legible. Their combination changes the void geometry, with compact collars at crossings. The large lower central openings survive the inspected scale and thin/heavy variants. The matched CLASSIC panel establishes a geometry change beyond material substitution. The actual production composition is also the diagnostic path: layer ablations use the same sampler with a layer bit removed, and diagnostic captures correctly omit ordinary chunk receipts.

The complete sampler is small, comprehensible, bounded integer arithmetic over immutable prepared parameters. No heap allocation, unbounded search, mutable World inspection or new composition abstraction was added. Its geometry is anchored to the module origin. Tests prove module-local translation and chunk independence; the ordinary project compiler supplies one project-wide anchor.

## CI and ordinary preset confirmation

[Final branch qualification run 43972726620](https://github.com/techrote/cybersand/actions/runs/43972726620) completed **success** at the exact source. The reviewer fetched every job's steps and decoded native/Godot/verify logs independently:

- All nine native generation suites pass with strict hosted GCC 13 flags, including procedural generation 416,267 assertions, typed fields 14,162, semantic grammar 208,725 and semantic planes 774,842 with zero failures.
- Source-built Godot 4.7 ordinary project contract: **2,829 checks, zero failures**.
- Native Architectural Generator campaign: **2,490 checks, zero failures, complete=true**, with 73 distinct CLASSIC maps.
- The verify job independently compares the ordinary selectable preset's material SHA-256 with the standalone native hero and passes.

The adapter repair adds the new module to explicit schema-4 metadata; it does not introduce a new recipe schema or remove valid legacy expectations. No existing 72 sampler is repurposed. The scope remains v1-only through the existing CLASSIC preset/compiler/preview path.

## Performance review

The final exact-source benchmark uses bay80 / floor64, seed 271828, wall 3 and chunk 64. Seven measured warm trials follow one warm-up; module order rotates. Timing includes full native chunk generation, allocation and content hashing, with preparation excluded.

| Module |512² median ms |1024² median ms |
| --- | ---: | ---: |
| `hanging_arcade` | 237.61 | 974.31 |
| `suspended_deck` | 234.61 | 970.42 |
| `arcade` | 238.43 | 979.51 |
| `interlaced_viaduct` | 243.40 | 997.98 |

These matched measurements show no material native-generation regression. They are comparative observations on the shared host, not end-to-end UI/GPU latency guarantees.

## Remaining limitations

Layer coherence and finite seed/parameter coverage are geometric evidence, not structural-physics or gameplay-route certification. Material PNGs are native previews; physical GPU/framebuffer and Windows owner acceptance remain open. The source-built headless Godot path is separately verified below.
