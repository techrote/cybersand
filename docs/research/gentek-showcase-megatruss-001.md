---
retrieval: explicit-only
title: Megatruss Station — CLASSIC multi-bay superstructure showcase
status: Draft
document-kind: research
scope: GENTEK-SHOWCASE-MEGATRUSS-001 single native v1 sampler, preset, deterministic geometry and source-bound visual evidence
last-reviewed: 2026-11-16
related-documents: [gentek-classic-001.md, ../systems/architectural-generator.md, ../decisions/ADR-013-canonical-semantic-generation.md]
---

# Megatruss Station

**Draft / HOLD. Do not merge or promote Ready.** This is a separate stacked
showcase on CLASSIC parent PR #624, whose revalidated source is
`615828b28337f85e4663e03ba479616db4ddf764`. The parent branch is not modified.
The only new module is `megatruss_station` version 1; its ordinary Architectural
Generator preset is `megatruss-station`, displayed as **Megatruss Station**.

## Architectural decision

The station uses six ordinary base bays across three vertical bands. Two large
primary diagonals each cross three bays, connecting continuous upper/lower
chords to a centre transfer node. Heavy concrete seam cores continue through all
three bands, with either forked shoulders or solid haunches. The lower chord
carries suspended service galleries; a continuous transit deck and short lower
technical shelves provide separate levels. A partial upper concourse and an
offset glazed equipment crown complete the station programme.

Fine secondary trusses occupy two selected base-bay pockets. They do not fill
the primary envelope. A two-bay hall below the lower chord is explicitly protected
from secondary construction. Aperture controls affect bounded enclosures,
leaving the main chords, deck and piers intact at the zero-shaft hero preset.

The choice is intentionally a fixed six-bay supercell, rather than enlarging the
base room size. It preserves independently visible macro, bay and panel scales.
The existing CLASSIC samplers retain their original bounds-relative formulas.
Only Megatruss uses absolute signed world coordinates, so a clipped style zone
cannot restart its phase. Reversing that decision would change module output
identity and require a different version.

## Geometry and controls

All dimensions are integer native cells. The hero configuration is
`B=64`, `L=96`, `w=3`, door width 10, shaft 0, windows and doors On,
deterioration 0. The palette is Reinforced Concrete 58, Rusted Steel 65 and
Frosted Glass 121. The existing preset compiler assigns floor and accent roles
the same material; the native evidence campaign uses that exact palette.

| Architectural frequency or datum | Formula | Hero cells |
| --- | --- | ---: |
| Station repeat width | 6B | 384 |
| Station repeat height | 3L | 288 |
| Primary diagonal horizontal travel | 3B | 192 |
| Ordinary base bay | B | 64 |
| Secondary panel pitch | floor(B/4) | 16 |
| Upper chord | L/2 | y=48 |
| Lower chord | 3L/2 | y=144 |
| Hanging service platform | 2L | y=192 |
| Main transit deck | 5L/2 | y=240 |
| Lower technical gallery | floor(11L/4) | y=264 |

These are measured/designed spatial frequencies, not a complexity score.
Odd bay dimensions leave a shortened terminal panel; its coordinates still
reset at the explicit base bay rather than a storage chunk.

`room_size` sets B; `floor_height` sets L; `wall_thickness` sets w. Primary
half-width is 2w, pier half-width is 3w, and secondary half-width is
max(1, floor(w/2)). Room size must be at least `4w+24`; floor height must be at
least `8w+32`. Both native admission and the existing project validator report
these bounds. The ordinary preset JSON is
[`megatruss-station.style.json`](../../examples/worldgen/architectural/megatruss-station.style.json).

Windows Off replaces glazing with shell cells. Doors Off restores service
openings. The optional existing shaft control carves a world-phased central
shaft and can intentionally interrupt structural datums; hero evidence keeps
it at zero. The independent automatic tunnel and deterioration controls can
also remove material and are disabled in the isolated gallery.

## Seed programme and continuity

One `hash_xy(seed, supercolumn, superrow, 1773)` selects the programme. There is
no per-brace noise, mutable RNG or neighbouring chunk query. A hall label names
the protected corridor; the full connected hall can extend farther, and two hall
labels may choose the same visible gallery side. The diagnostic
programme ledger accompanies every rendered native case and records:

| Choice | Rule |
| --- | --- |
| Transfer support | Bit 0 selects forked shoulders or haunched shoulders |
| Protected hall | `(programme >> 1) % 3` selects left, centre or right two-bay corridor |
| Upper concourse | Bit 3 selects presence |
| Hanging gallery | Opposite an offset hall; bit 4 chooses the side for a central hall |
| Secondary network | Bit 5 selects Warren or complete X panels |
| Roof/crown | Bit 6 selects left or right |

The seam core, upper/lower chords and main deck are invariant shared interfaces.
A neighbouring station may choose a different programme without requiring
neighbour sampling or phase negotiation. Supercell origins use mathematical
floor division and positive modulo at signed global coordinates. The source
explicitly separates `super_x`, `bay_index`, `bay_x`, `major_band` and `panel_x`.

## Native qualification

The focused native harness is
[`test_megatruss_station.cpp`](../../native/tests/test_megatruss_station.cpp).
It checks byte-identical repeats, forward/reverse chunk order, varied
work slices, 8/32/64/128/256-cell storage partitions, signed coordinates including
large signed origins, bounds-only clipping, concurrent reads, cancellation,
charged-work limits and refusal of invalid versions/schema/materials.

Geometric probes inspect complete chord/deck rows, all-band transfer cores,
three-bay diagonal runs, unobstructed hall rectangles, emitted secondary post
pitch, primary/secondary cross-sections, both secondary families, multiple seed
outputs and the effect/locality of wall, bay, floor, glazing and door controls.
The catalogue uniqueness gates are extended from 72 to 73 in both native and
Godot tests; no parent test is removed.

The parent comparator independently compiles the immutable parent native source
and the same public-API fixture. It compares full material bytes, fingerprints
and receipts for all 72 existing modules, three configurations and four signed
or positive chunks each: **3,538,944 cells**. It does not infer compatibility
merely from unchanged source or a sample image.

Reproduction:

```bash
make -j2 worldgen-test
make -j2 megatruss-station-test
make -j2 megatruss-station-sanitize
python3 tools/architecture/qualify_megatruss.py --output build/megatruss-qualification
python3 tools/architecture/render_megatruss_station.py --require-clean-source --output build/megatruss-station-gallery
```

Qualified implementation source is
`279bc4634b1d2b3a47f747c628163e419a728be7`, tree
`a0839f7bcad328770e522b5ddda3e45b91b5b222`. The sampler and preset are
byte-identical to the initially qualified `0059f5e62592ed1fa8c46429fbc816cfb26f4b27`;
the repair changes only adapter catalogue metadata and its contract test.
Both the local and hosted focused qualification passed **1,499 assertions / 18 named gates**.
The measured minimum protected clear hall was 221 × 86 cells across the sampled
signed supercells and seeds. Representative primary/secondary cross-sections
were 13 and 2 cells. The hosted native job also passed all nine existing generation suites,
including 416,267 world-generation assertions. The independently compiled parent
comparison passed all 3,538,944 cells plus receipts and fingerprints. The exact
7,093,458-byte snapshot hash is
`ac0aba5b446b0315fb7e2b705ef46be71337070edd9b232c80dd50c8785c4a41`.

AddressSanitizer and UBSan passed the same 1,499 checks. LeakSanitizer refused
the workspace ptrace environment; its failure is retained in the local evidence
and is not labelled a pass. The successful rerun retained ASan/UBSan and used
`detect_leaks=0`. See the [source-bound local qualification](megatruss-station-001/local-qualification.json),
[legacy comparison](megatruss-station-001/local-legacy-comparison.json) and
[sanitizer report](megatruss-station-001/local-sanitizer.json).

The [isolated local Godot 4.7 confirmation](megatruss-station-001/local-runtime-qualification.json)
passed 2,829 project-contract checks and 2,490 native-gallery checks with zero
failures, producing 73 distinct CLASSIC material hashes. All 72 parent builtin
pixel buffers were preserved. Megatruss matched the standalone hero exactly.
This local build records its GCC14/linker drift explicitly. The authoritative
[GCC13 hosted qualification](megatruss-station-001/hosted-runtime-qualification.json)
then passed the same 2,829 contract and 2,490 gallery checks, with 73 unique maps
and all 72 parent previews preserved. Its [exact-source parity result](megatruss-station-001/hosted-source-verification.json)
binds the ordinary preset and standalone hero to source `279bc4634b1d2b3a47f747c628163e419a728be7`
and material SHA-256 `96f92d7b7325a9b8d13ca2c2d539ac6960d274bad056228e06b1f70b4f4a7171`.
The [fresh Linux runtime artifact](https://github.com/techrote/cybersand/actions/runs/43969089140/artifacts/14276434716)
retains the library, its 94 verified source hashes, logs and native maps.
All three jobs in [qualification run 43969089140](https://github.com/techrote/cybersand/actions/runs/43969089140) passed.
Final-head Documentation results are recorded separately in [PR #663](https://github.com/techrote/cybersand/pull/663).
Evidence-only gallery/report commits do not change the tested source inputs.

## Performance and visual campaign

The harness compares Steel Trestle, Space Frame, Arched Viaduct v2 and Megatruss
at identical palette, seed, parameters and 512²/1024² extents. It reports seven
warmed raster trials per module, median and range. Preparation is excluded;
the per-image exporter separately records preparation time.
No timing ratio is used as a correctness gate. The sampler performs bounded
integer arithmetic, with no cell-time allocations, loops, recursion, search or
mutable cache. Its conservative charge is 240 logical module operations/cell.
That charge is an engine budget estimate, not an instruction or CPU-cycle count.

Hosted Ubuntu/GCC13 medians from the qualified native artifact:

| Native generator | 512×512 | 1024×1024 |
| --- | ---: | ---: |
| Steel Trestle | 129.180 ms | 517.466 ms |
| Space Frame | 130.166 ms | 521.100 ms |
| Arched Viaduct v2 | 130.801 ms | 524.311 ms |
| Megatruss Station | 133.138 ms | 532.987 ms |

The measured overhead versus Trestle is about 3.1% / 3.0% on this runner.
These are whole generation-path measurements, including allocation and content
hashing, not a sampler-only microbenchmark or universal performance guarantee.
The diagnostic benchmark uses shell58/deck62/glass121/accent65 for every module;
the presentation preset uses deck65/accent65. Trial arrays and scope are retained
in the [hosted/local comparison](megatruss-station-001/hosted-local-comparison.json).

The retained campaign contains 21 native images: three heroes, six seed cases,
four scale contrasts, two member-mass contrasts, glazing On/Off, portals Off,
a negative-coordinate landscape, and identical-extent Trestle/Space Frame
controls. The comparison places all three 1024×512 outputs side by side at
one native cell per image pixel. Two contact sheets aid review; full-resolution
originals remain separate.

Every PNG is a direct colour mapping of actual native material IDs through the
existing `BASE_RGBA8` preview palette. No generated illustration, resampled
geometry, procedural decoration overlay or alternative rasterizer is used.
Raw native bytes, per-chunk receipts, every PNG SHA-256, executable hash and
complete source-input hash ledger accompany the gallery. The source archive
contains the exact files that produced the campaign.

The [rendered PR gallery](https://github.com/techrote/cybersand/pull/663#issuecomment-6930945285)
embeds the hero, all seed/scale/control contrasts and identical-scale comparison.
The [retained full-resolution gallery](../images/gentek-megatruss/GALLERY.md) and
[manifest](../images/gentek-megatruss/manifest.json) preserve all 24 PNGs and their
source/material hashes. The source-input digest is
`8689d760e11dfbe5ec7114b343ff09396c69a5e441dd5eaa4732cc83f90ee6ec`.
The [hosted native artifact](https://github.com/techrote/cybersand/actions/runs/43969089140/artifacts/14278331044)
retains all raw cells, receipts, source ZIP and the tested executable. Its ZIP
SHA-256 is `3817ee901f5fc77cc52726f5b1b2c6081735792ed7684c49a60a9267fbb8985a`.

All 21 hosted native arrays and all 24 PNGs match the independently reviewed
local campaign byte for byte. The [metadata-repair comparison](megatruss-station-001/metadata-repair-comparison.json)
confirms that regeneration at the repaired commit preserves every image and
native array exactly while binding the updated source-input ledger. The complete 512² hero matches the landscape
for 262,144 common cells; landscape/large hero match for 524,288; the signed
and positive landscapes match for 131,072 common world cells. These capture
comparisons independently demonstrate cross-boundary and changed-extent phase
continuity. Hero empty ratios are 68.32%, 70.00% and 70.60%. Thin/heavy members
retain 81.29% / 56.58% empty space. Glazing Off changes exactly 8,653 glass cells
to shell and nothing else. All six seed hashes differ.

## Hosted pipeline and independent review

The new branch-only workflow
[`gentek-megatruss-draft.yml`](../../.github/workflows/gentek-megatruss-draft.yml)
checks out the immutable triggering commit and has read-only repository
permissions. It preserves all native generation gates, runs the focused/parent
comparison, builds a fresh Linux Godot extension, exercises the ordinary preset
compiler and 73-style native gallery, then compares the hero's exact material
hash between the standalone native exporter and ordinary Godot preset path.
It publishes evidence artifacts and never pushes to the parent or this branch.

Independent review identified an early secondary-X defect: odd panels repeated
the first diagonal instead of adding its complement. The source now tests the
complementary strip, with witnesses for both odd and even panels. The reviewer also found and
repaired piped CI commands that could mask gate failure; the workflow now uses
an explicit pipe-failing Bash shell.

The first source-built Godot run then exposed a catalogue-metadata omission
for Megatruss and an inherited test error that classified the original 72
CLASSIC styles as legacy. The [recorded repair](megatruss-station-001/runtime-metadata-repair.json)
adds the missing schema-4 marker, shares the unchanged ordered 73-style test
fixture, and explicitly requires every CLASSIC v1 identity while rejecting
invented v2 entries. Native geometry and legacy metadata semantics are unchanged.
The independent reviewer verified that adapter metadata and native admission
now agree on all 76 schema-4-only families (73 CLASSIC plus three existing families).

The [independent review](megatruss-station-001/independent-review.json)
accepts the native implementation, visual campaign and source-built runtime
with no remaining blocking findings. The reviewer independently ran all 1,499 checks, compared parent
snapshots, verified 67 qualification and 84 gallery source hashes against
immutable Git blobs, decoded every native PNG pixel against the material palette,
and inspected every original and composite. The primary/secondary hierarchy,
station voids, seeded programmes, source readability and proportional cost passed
that review. The reviewer also inspected both local and hosted source-built
Godot evidence, verified runtime source and library identities, and checked
73-map uniqueness, parent preview preservation and exact Megatruss material parity.

## Remaining limits

This is a deterministic CLASSIC geometry exemplar, not structural engineering,
actor-navigation certification, self-assembly or a terrain-aware station planner.
Finite masks can clip piers/spans; the sampler does not adapt to or repair zone
edges. Seed choices come from a bounded family and the primary frame repeats
by design. Extremely thin/compact settings show discrete raster aliasing more
strongly than the hero configuration. Enclosure fronts are material cells,
not interactive room actors.

The inherited parent Windows DLL and Linux SO predate this module. Only a fresh
source-built runtime can select it successfully. The hosted Linux headless
qualification and native PNGs do not establish physical Windows owner acceptance
or authorize retained runtime publication, a merge, or Ready promotion.
The default repository checker still reports four retained-runtime/source
mismatches (two files for each platform); the [parent diagnosis](megatruss-station-001/retained-runtime-parent-diagnosis.json)
confirms all four also exist at the immutable parent. This is not counted as a
passing gate. The existing Documentation workflow skips published-runtime
provenance while a PR is Draft; that policy and all Ready gates remain unchanged.
