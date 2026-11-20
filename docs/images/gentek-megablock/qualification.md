# Seeded Typology Megablock — qualification record

**Draft / HOLD research candidate.** Module `seeded_typology_megablock` v1; preset **Seeded Typology Megablock**. This record concerns the isolated showcase branch, not accepted main or physical Windows owner acceptance.

## Source and evidence identity

| Item | Identity |
| --- | --- |
| Branch / stacked PR | `experiment/gentek-showcase-megablock-001` / [#665](https://github.com/techrote/cybersand/pull/665) |
| Base / exact parent #624 | `experiment/gentek-classic-001-20261115` / `615828b28337f85e4663e03ba479616db4ddf764` |
| Final implementation source | `c846223ee0411662268f0a40942fd5e31002da6f` |
| Source tree | `8077dc18e35f82a2f30bbc300b9cc32afe1a41f8` |
| Local gallery input ledger | `b403d9e2a963f9e53522879523a56dc96f4e94557b648c3b2fd9ad5e5e274f26` |
| Native capture binary SHA-256 | `6d6e45b0440f2d850e09ace4006122a11406ec29f97fc770ae14a5a7cdfb16ce` |
| Source-built Linux extension SHA-256 | `dab33da6d93e06c81baeccf7e39c9edf7f866191c8a5b31c2c553c92c1ed6837` |
| Full hosted qualification | [Run 43972648873](https://github.com/techrote/cybersand/actions/runs/43972648873) |

The retained gallery was generated from a clean checkout of the final implementation source. Later evidence commits change documentation and retained images/metrics only. All 84 recorded source inputs verify; the final packet's 181 payload entries verify. All 60 PNGs and all 55 raw maps are byte-identical to the preceding independent visual review. The hosted Linux artifact also reproduces all 60 PNG and 55 raw-map bytes exactly; its ZIP SHA-256 is `09f5cace482a202cfe2e38cf945d1184ac007f90150bbeffad855aebd8cde3dc`. The CSV in Git uses LF line endings; its retained-file manifest records those exact bytes.

Both jobs in the exact-source qualification run completed successfully.

| Completed gate | Actual result |
| --- | --- |
| Linux normal generation | All ten suites PASS; five counted suites total 1,433,746 assertions |
| Linux ASan/UBSan with leak detection | Procedural/CLASSIC 416,267 and Megablock 19,750 assertions PASS |
| Source-built Linux Godot native campaign | 2,490 checks, zero failures, complete=true |
| Linux Godot project contract | 2,757 checks, zero failures; includes all 73 CLASSIC entries |
| Focused Godot Megablock project | 188 checks, zero failures |
| Windows MSVC native tests | Procedural/CLASSIC 416,263 and Megablock 19,750 assertions PASS |
| Windows/Linux material parity | All 32 complete 512×512 raw-map SHA-256 hashes match |
| Source Documentation/provenance | [Run 43972660053](https://github.com/techrote/cybersand/actions/runs/43972660053) PASS for c846223; retained-runtime gate intentionally skipped for Draft |

[Linux native gallery, raw maps, offline index and Godot logs](https://github.com/techrote/cybersand/actions/runs/43972648873/artifacts/14280303022) · [Windows native tests and 32-map parity](https://github.com/techrote/cybersand/actions/runs/43972648873/artifacts/14279273693). Both artifacts are bound to `c846223` and retained for 90 days; the PNGs, metrics and reports are also committed here.

Windows artifact ZIP SHA-256: `d6c6332f1ea2bee4186085246508fa08e91fabd2f7733071f4ff1b44fc435dac`.

## Native requirements and preservation

Unless another file is named, functions below are in
`native/tests/test_seeded_typology_megablock.cpp`. Row counts overlap and must
not be added together as independent assertions.

| # | Requested requirement | Exact test/function and completed evidence |
|---|---|---|
| 1 | Same seed deterministic | `seed_survey_and_control_response()` compares complete 512² maps from fresh compilations for seeds **0–7**: **8/8 exact repeats**. `chunk_order_slicing_and_signed_origins()` additionally compares cells, content hashes and receipts after fresh compilation. |
| 2 | Reversed chunk order deterministic | `chunk_order_slicing_and_signed_origins()`: **36 chunks × 2 origins = 72 reversed-order chunk comparisons**, all exact. Chunk coordinates cover −2 through 3 on both axes. |
| 3 | Work slicing deterministic | Same function: budgets **1, 7, 31 and 4096 cells**, at both origins: **8 sliced jobs** match complete reference cells and receipts. Every budget samples chunk (0,0), which intersects Megablock in both fixtures. It also compares **288 64² partitions** against their 128² references. |
| 4 | Negative global origin deterministic | Same function repeats the complete order/slicing/partition checks at module origin **(−137,−211)**. Additional interface tests use **(−197,−151)** and connectivity tests use **(−137,−83)**. |
| 5 | At least eight seeds give multiple material hashes | `seed_survey_and_control_response()`: predeclared seeds **0–31** produce **32/32 distinct full 512² material hashes**. Hashes are FNV-1a-64 over row-major little-endian uint16 material IDs. |
| 6 | Representative seeds retain substantial negative space | Same function checks **all 32 seeds** have occupied ratios strictly between **8% and 75%**. `material_interface_contract()` verifies an entire bay × floor rectangle remains native Empty in **896 complete supercell configurations**. |
| 7 | Windows toggle changes glazing-capable output | `seed_survey_and_control_response()`: **8 seeds** have nonzero window changes; every changed cell goes from FrostedGlass to occupied material when disabled, and disabled output contains no FrostedGlass. |
| 8 | Room size changes topology/material map | Same function: with seed 7 and other settings fixed, native `bay_width` **96→64** changes the full 512² material hash. `bay_width` is the compiled native control for project `room_size`. |
| 9 | Floor height changes topology/material map | Same function: with seed 7 and other settings fixed, `floor_height` **64→96** changes the full 512² material hash. |
| 10 | Wall thickness changes occupancy | Same function: with seed 7 and other settings fixed, wall thickness **1 versus 5** produces strictly greater occupied-cell count for the heavier structure. |
| 11 | Existing CLASSIC outputs remain unchanged | `unchanged_parent_materials()`: **72 CLASSIC modules × 2 complete-map profiles = 144 frozen material-map matches**. `classic_architectural_genteks()` in `native/tests/test_world_generation.cpp` additionally verifies **73/73 distinct material outputs**, valid occupancy, slicing and schema admission. |
| 12 | Viaduct v1/v2 retain exact behavior | `unchanged_parent_materials()`: **2 versions × 2 profiles = 4 additional frozen full-map matches**. Existing `refined_architectural_details()` in `test_world_generation.cpp` still checks v1 empty pier ports, v2 solid SteelPlate pier inlays and slicing. |

The complete normal suite passes all ten executables. Five report assertion counts, totaling **1,433,746**: procedural/CLASSIC 416,267; focused Megablock 19,750; typed fields 14,162; semantic grammar 208,725; semantic planes 774,842. Installation, fields, modifiers, typed integration and spatial suites report PASS without aggregate counts. These counts do not include sanitizer reruns or Godot checks.

The existing procedural test guards four Linux x86_64/libstdc++ C++11-ABI-specific legacy receipt literals on other platforms. Windows therefore reports four fewer assertions while retaining its material comparisons and schema-1 receipts; this work does not create a new Windows legacy-receipt baseline.

The focused suite includes 896 full-supercell parameter/seed/coordinate combinations for actual core, empty atrium, bridge/landing and transfer-slab cells. Independent material flood fills cover 224 complete-supercell configurations. It exercises all nine families and all eight core/bridge placements, minimum/odd/maximum dimensions and both 18×256 and 256×18 anisotropic limits.

Parent preservation is both source and output based. The two parent sampler include files are byte-identical. An independently built executable from exact parent `615828b2` produced 148 fixed hashes of complete 256×256 material maps: 72 CLASSIC samplers plus Viaduct v1/v2, each under two material/parameter profiles. The new suite compares complete map hashes against those frozen parent values. Parent #624 and its branch have not been edited, merged, rebased or Ready-promoted by this work.

## Seed and visual evidence

The fixed survey uses every seed 0–31 at 512×512, bay96/floor64/wall4, windows and doors on, with industrial material roles. Principal examples 0–7 and hero seed 0 were selected before visual review. No seed blacklist or discarded bad-seed list is used.

- 32 distinct SHA-256 material maps; occupancy 39.049%–44.905%.
- 8–9 families per map; 27 maps use nine and five use eight.
- One four-connected occupied component and zero isolated cells in every survey map; zero survey warnings.
- A guaranteed 96×64 entirely empty middle lot per complete intact supercell. Largest observed empty rectangles are 96×82 or 96×146.
- Core columns occur 10/8/8/6 times at supercell (0,0); bridge bands 1/2 occur 19/13 times.

See the [full 32-row hash survey](seed-survey.md), [eight readable programmes](showcase-programmes.md), [complete diagnostic programmes](typology-programmes.json), and [60-PNG gallery](README.md). The native-map archive contains both raw uint16 little-endian cells and their per-capture configuration records. Python applies the existing material LUT; it does not create geometry.

The principal visual repairs were semantic: doors-off now closes the actual full arcade gateway rather than leaving a centre pedestal. Contact-sheet captions were shortened to prevent overflow. All 32 seed images, control variants, 1024 hero and matched comparisons were visually reviewed; independent source/raster verification confirmed exact raw-material-to-PNG parity. This is an independent engineering/visual review, not owner acceptance of physical gameplay or display.

## Parameter response and performance

Compared with seed 0's default 512×512 map, compact/large lots change 108,549/90,872 cells; short/tall bands change 142,220/109,615 cells. Thin/heavy structure changes occupancy from the 42.794% baseline to 32.8865%/47.4972%. Windows-off replaces all 10,888 glazing cells with shell material and preserves occupancy. Doors-off changes 22,664 cells and raises occupancy to 51.4397%. Each control remains one occupied component. A translated negative module origin preserves its local material map exactly, as intended.

| Module |Direct median ms | Direct ns/cell | Native chunk median ms |
| --- | ---: | ---: | ---: |
| seeded_typology_megablock | 8.683 | 33.12 | 169.013 |
| cantilever_spine | 2.951 | 11.26 | 166.528 |
| staggered_balcony | 1.502 | 5.73 | 135.816 |
| bridgehouse | 1.621 | 6.18 | 156.099 |
| stacked_arcade | 2.935 | 11.20 | 139.059 |

These are advisory five-repeat medians from the final local packet: the same binary, compiler, seed, 512×512 extent, dimensions and material roles for each module. Direct sampling isolates geometry; the native timing includes common candidate evaluation, receipts and raster assembly. Raw repeats are retained in [performance.json](performance.json). Megablock spends about 2.9–5.8 times as long in its direct sampler as these simple motifs; measured full generation is about 1.01–1.24 times as long. The earlier run of the identical binary measured 6.537 ms direct versus the final 8.683 ms, showing shared-host variation; no strict speed guarantee is claimed.

Sampling uses a bounded programme lookup and one supercell hash per call, with finite integer geometry. It has no heap allocation, loops, mutable cache or runtime neighbour negotiation. The nine families have dedicated local expressions; none delegates to one of the parent samplers.

## Catalogue techniques and architectural distinction

The full 72-entry CLASSIC source catalogue was inspected. Useful techniques carried into this exemplar are architectural principles and integer geometry, with new cooperating typology expressions.

| Existing exemplar | Useful technique | Megablock interpretation |
| --- | --- | --- |
| Offset Arcade | Level-dependent arch phase with stable floor rhythm | Programme variation retains a common datum instead of shifting every interface |
| Cantilever Spine | A deterministic seed changes arm orientation around a stable support | The programme chooses an outer cantilever and points it toward a known inner support |
| Staggered Balcony | Alternating shelves attach to persistent edge towers | Local asymmetry is bounded by an attachment contract |
| Bridgehouse | Gabled habitation and a bridge share a clear carrier deck | Habitation and bridge become separately chosen lots with explicit landings |
| Basilica | Different nave/aisle heights preserve one architectural language | Crown, core and middle bands have different roles within common vertical spacing |
| Shelf Stack / Crossbeam Stack | Multiple shelf elevations attach to a visible spine | Core ribs and landings provide a recognizable vertical identity |
| Lantern Tower | Controlled glazed volume is distinct from the support | Glazing is restricted to habitation panels; core/support remain structural |
| Buttress Wall / Stepped Buttress | Strong edge mass frames deliberate negative space | Stepped lower supports and doubled void-facing piers bound the atrium |
| Clerestory Hall | High glazing bands sit between structural datums | Habitation uses fixed heads, sills and mullions |
| Lattice Tower / Pyramidal Frame / Nested Arcade | Multiple decks or nested tiers can remain an immutable local expression | Four programme bands share interfaces while each lot selects its own role |

The [matched comparison sheet](classic-comparison.png) uses the same material roles and dimensions. Cantilever Spine varies platform direction, Staggered Balcony alternates shelves, Bridgehouse repeats a roof/deck unit, and Stacked Arcade repeats arch tiers. Megablock varies the allocation of core, court, bridge, habitation, frame and support roles. The shared rails, slab elevations, stepped masses, inclined knees and restrained glazing give those programmes one family identity.

## Failures, repairs and limits

The first hosted run [43969027723](https://github.com/techrote/cybersand/actions/runs/43969027723) passed native/sanitizer tests and the 2,490-check native Godot campaign, then failed the inherited project-contract test (2,748 checks, 72 failures). Its old expectation treated all parent CLASSIC entries as unrestricted legacy metadata. That also concealed a new omission: Megablock's adapter catalogue entry lacked its required minimum schema. Commit `c846223` adds the metadata, extends CLASSIC project coverage to 73, preserves the three real legacy v1 exceptions and asserts Megablock v1 without v2. The failed run is retained; it is not counted as a full pass. Its Windows job was skipped and the focused GDScript project test was not reached.

Local normal native tests passed. One unchanged GCC14 spatial allocation-probe test required `-Wno-error=mismatched-new-delete`; strict hosted GCC13 uses the normal gate. The initial parallel local sanitizer build exhausted memory, its serial build succeeded, and LeakSanitizer then rejected the ptrace environment. A no-leak local rerun passed the main suite but the focused retry was stopped after hosted leak-enabled qualification succeeded. That incomplete local retry is unqualified. Hosted sanitizer evidence provides the actual completed leak-enabled result.

The retained-runtime repository provenance check still reports the same four inherited source/platform rebuild requirements (generator wrapper and generation implementation on Linux/Windows). Old LFS runtime assets were not rewritten. The branch's actual integration qualification rebuilds the Linux extension from source; it does not establish a fresh packaged Windows runtime or physical owner acceptance. The generic expensive workflows remain intentionally skipped for a Draft PR; their skipped state is not reported as a pass.

The programme is a finite four-by-four grammar. Neighbour-specific cooperation is within each supercell; the lower transfer slab is the cross-supercell interface. Arbitrary style/map clipping, optional shaft carving, deterioration and later tunnel/path carving can remove support. Connected material, including glass, does not prove physical stability or traversable empty space. The common `door_width` parameter remains validated but does not independently resize this family's major gateway.

The [independent review](independent-review.md) records source, visual, material and platform findings. No Cathedral Megaframe or Megatruss Station branch was incorporated. **This PR remains Draft / HOLD. No merge, auto-merge or Ready promotion is authorized or performed.**
