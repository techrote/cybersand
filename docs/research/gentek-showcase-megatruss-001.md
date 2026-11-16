---
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
It checks byte-identical repeats, forward/reverse/permuted chunk order, varied
work slices, 32/64/128-cell storage partitions, signed coordinates including
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

Initial local focused qualification passed **1,499 assertions / 18 named gates**.
The measured minimum protected clear hall was 221 × 86 cells across the sampled
signed supercells and seeds. Representative primary/secondary cross-sections
were 13 and 2 cells. Final hosted results and source identities belong in the
PR evidence handoff; this source checkpoint does not assert a completed CI run.

## Performance and visual campaign

The harness compares Steel Trestle, Space Frame, Arched Viaduct v2 and Megatruss
at identical palette, seed, parameters and 512²/1024² extents. It reports seven
warmed raster trials per module, median and range, and native preparation time.
No timing ratio is used as a correctness gate. The sampler performs bounded
integer arithmetic, with no cell-time allocations, loops, recursion, search or
mutable cache. Its conservative charge is 240 logical module operations/cell.
That charge is an engine budget estimate, not an instruction or CPU-cycle count.

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
complementary strip, with witnesses for both odd and even panels. Final review
must additionally inspect all retained images, source ledgers, benchmark claims,
legacy comparisons and the exact-source Godot equality result.

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
