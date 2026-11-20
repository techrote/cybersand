# Megablock native validation matrix

## Evidence identity and status

Frozen parent: `615828b28337f85e4663e03ba479616db4ddf764` (#624).
The first completed native qualification used implementation source
`aedf1ba98b0a07669c1781ec4c5519072d5ca949`. All ten Linux generation suites
passed, including **19,750 focused Megablock assertions** and **416,267 general
generation/CLASSIC assertions**. Hosted run **43969027723** also passed its
native and leak-enabled sanitizer steps.

Current correction source is `c846223ee0411662268f0a40942fd5e31002da6f`.
Its change repairs adapter catalogue metadata and stale Godot contract tests;
the native sampler, programme, material geometry and native tests are unchanged.
Fresh hosted run **43972648873** completed successfully on the correction source.
Windows MSVC passed **416,263 procedural/CLASSIC assertions**, **19,750 focused
Megablock assertions** and **32/32 full-map SHA-256 comparisons with Linux**.
Four pre-existing Linux/libstdc++ ABI-specific receipt literals are guarded on
Windows; all material comparisons remain active. This is Windows native
qualification, without physical owner-acceptance or a new legacy-receipt baseline claim.

## The twelve requested native requirements

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

## Parent oracle provenance

The literal oracle was captured with a separate native executable compiled from
a `git archive` of the exact parent, before Megablock implementation. It covers
**148 full 256² maps = 144 CLASSIC + 4 Viaduct**, using these two profiles:

| Profile | Seed | Origin | Bay / floor / wall | Doors / windows |
|---|---:|---|---|---|
| Ordinary | 271828 | (0,0) | 96 / 80 / 3 | On / on |
| Negative, closed | 7 | (−197,−151) | 64 / 48 / 3 | Off / off |

Both use door width 10, shaft width 0, and material roles wall=62, floor=66,
window=121, accent=114. The expected values are literal constants in
`legacy`; they are not regenerated from candidate source at test time.
These are bounded material regression fixtures, not exhaustive sampling of every
possible parameter combination.

Scratch capture provenance:

- `megablock-parent-native/legacy_hashes.cpp` SHA-256:
  `8e71e0b9f99d9245b4aa238eab5cc3b617933485650782b721db18f95ca5b67e`.
- `megablock-parent-native/legacy_hashes.txt` SHA-256:
  `575eeb6e3af7da994bdc4f8a086efe8676675fdb8a5480fc8a489baa0b0f0864`.

## Additional structural coverage and its limits

`material_interface_contract()` checks **32 seeds × 4 supercells × 7 dimension
profiles = 896 configurations**. Each checks the complete core rail, the entire
protected void rectangle, every cell across the bridge and both neighbour
landing strips, the lower transfer slab and legal typology bands. All **nine
families** and all **eight core-column/bridge-band combinations** are observed.
Profiles (bay, floor, wall): (96,64,4), (18,18,1), (42,42,5), (67,51,3),
(256,256,5), (18,256,1), (256,18,1).

`material_connectivity_extremes()` independently flood-fills actual occupied
cells in **32 seeds × 7 profiles = 224 complete supercells**; all have exactly
one four-connected occupied component. Its profiles cover both anisotropic
extremes and the minimum legal clearance for every wall thickness 1–5.
The seed survey also rejects isolated interior one-cell fragments in all 32 maps.
Eight doors-toggle witnesses verify real Empty-to-occupied changes independently
of glazing. Admission, invalid controls, cancellation, concurrent generation and
operation-budget refusal are covered by the focused suite.

These structural guarantees apply to **complete supercells with shaft width 0**.
Arbitrary zone clipping and an explicitly requested shaft can cut structure.
Four-connectivity proves material contact, not mechanical stability or player
traversability. The private programme helper identifies lots; bridge, core, void
and connectivity assertions inspect actual native material cells.

## Suite counts and execution qualifiers

| Suite | Completed Linux result |
|---|---:|
| Procedural generation / CLASSIC | 416,267 assertions |
| Seeded Typology Megablock | 19,750 assertions |
| Typed generation fields | 14,162 assertions |
| Semantic grammar | 208,725 assertions |
| Native semantic planes | 774,842 assertions; zero failures |
| Installation, fields, modifiers, typed integration, spatial | All five passed; no numeric assertion count printed |

The five counted suites total **1,433,746 assertions**. All ten suites passed.
Primary local log:
`/workspace/scratch/d425b9146667/megablock-all-worldgen-retry.log`.

The unchanged spatial test needed a local GCC 14
`-Wno-error=mismatched-new-delete` override for its intentional malloc/free
allocation probe; other native builds retained strict `-Werror`. No source or
assertion was changed for that compiler diagnostic. Local LeakSanitizer rejected
the ptrace environment; the later local ASan/UBSan retry was stopped after its
procedural pass and before a focused completion record. It is **not** a completed
local sanitizer pass. Hosted run **43969027723** supplies the complete
leak-enabled sanitizer result; the corrected-source hosted rerun also passed both binaries with leak detection
enabled, as recorded in [qualification.md](qualification.md).
