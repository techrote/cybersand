---
title: Thick Oil and Lava in the Water ramp
status: Current
document-kind: audit
scope: Radius-24 Oil and Lava brush replay, quantity accounting and protected source review
last-reviewed: 2026-11-19
related-documents: [../architecture/wave-flow-v1.md, ../architecture/liquid-prepared-setup-and-receipts.md, ../operations/workbench-water-lab.md]
---

# Thick Oil and Lava in the Water ramp

The owner reported that a brushful of Oil remained in a blob and a subsequent Lava drop paused the Workbench. The previous [buried-strip test](wave-oil-buoyancy-2026-11-19/evaluation.md) used 48 Oil cells. A single radius-24 brush paints 1,793. The screenshot does not preserve the original edit coordinates or timing. The replay uses the original saved 2048 × 2048 ramp and a repeatable pair of brush strokes.

## Reproduction

In the previous Windows playtest, let the ramp run to tick 360 with six workers, Wave, full-face spill, Ballistic Water and fall speed 3. Paint Oil at (805, 448) with radius 24. At tick 721, just before adding Lava, the patch spanned 85 columns. Its most populated column held 47 Oil cells. Paint Lava at (826, 452) on tick 721. The next attempted tick failed. The ordinary spray readback reported `get_water_spray failed: quantity reaction input exceeds cell bound`. The last good snapshot was tick 721. OpenGL and headless playbacks produced the same four material-plane hashes through failure.

## Lava reaction

The original quantity check allowed at most 510 Water units per reaction on this profile. A legal Wave cell holds up to 65,535. Commit `baa5699083f5f668f9c03309aceaccd0f1fb80d9` makes the validator use the Wave carrier limit. The quench replaces Lava with Stone and the Water cell with Steam. It charges the exact Water amount to the registered reaction. Existing production quanta, inventory checks, other Water laws and failed-World containment retain their validation paths.

A 256 × 256 Godot regression uses Wave to compress Water beneath a shelf. After two ticks the chosen cell holds 838 units. The brush seals the two-cell pocket and introduces Lava via the ordinary native adapter. The previous DLL failed during the third spray readback after painting. The test requires Steam, Stone, and a healthy quantity readback equal to the pre-quench total minus the whole compressed cell. The native quantity regression separately quenches cells holding 1, 510, 511 and 65,535 units across chunk boundaries with one and six workers.

The isolated quench-only Windows build reproduced the same four pre-Lava material planes as the control. Tick 722 produced 43 Steam cells and 43 Stone cells. Tick 841 contained 558 Steam and 503 Stone and the native quantity readback remained healthy. The Lava brush itself replaced 990 Oil cells where the discs overlapped. All 803 remaining Oil cells were present at tick 841. These are before-and-after measurements of a saved-start replay, with the same gameplay settings. [Previous build](wave-oil-lava-2026-11-19/workbench-before.json) · [Quench fix in isolation](wave-oil-lava-2026-11-19/workbench-quench-only.json)

The quench-only DLL was built from the source commit above using LLVM-MinGW 20260826, Clang 23.1.0, and tested in Godot 4.7. DLL SHA-256 was `c2f0928a29baa34ff055c80bbd203d20ca7bc533334faad43d1a658c72b72922` and its input fingerprint was `369787a8ee8c83e6b8b505d4da9083ee3afc145ef87e92356f61968e85b0b869`. The focused Workbench spill test passed all 809 assertions. Its previous-build run failed on the spray readback. The native quantity suite passed under GCC 13.3 with normal, ASan/UBSan, and TSan builds on WSL Ubuntu 24.04. TSan ran under `setarch x86_64 -R`.

## Oil transport and independent review

The selected implementation spreads an exposed top cell of Oil to a thinner part of the same Water-backed surface. A path across a wall, mask, paused core or a steep ledge is ineligible. Wave workers mark candidates during their existing final column pass. After the barriers the owner visits only marked half-strip row ranges and moves complete Oil tuples in a fixed order. Worlds with no candidates skip the owner pass. A step is bounded to 16 columns horizontally and 64 cells of inspected thickness. A Water-backed Oil shelf thicker than 64 cells everywhere needs a thinner edge before it can spread by this route. No new UI control is needed. [Solver contract](../architecture/wave-flow-v1.md#oil-floating-on-wave-water)

Neighbor-only prototypes spread too slowly or left ongoing spray in a settled tank. The chosen surface transfer carries an intact Oil cell across the pile without pushing the underlying Water. It preserves each cell’s state and temperature. Source commits `f2178bf79c48012fadedcd13943d0865e624c93d` and `b5f2f95a34a574c9aa76f79bfdcd897eb66fa727` implement and harden this behavior. Reverting these two source changes restores the prior thick-drop behavior independently of the Lava accounting fix. This follow-up changes neither protected source file.

An independent native review found that relocating Oil beside a paused region could clear a stored Wave face carrying 4,800 units of fixed-point flux. The corrected owner defers movement at a selected-region boundary. A mirrored regression exercises both orientations with one and six workers. The destination temperature field for warm Oil is admitted before moving either cell. A cross-chunk test follows each of 16 tagged warm cells. For walls, body masks and paused cores, an independent 192-tick replay tracked all 412 tags and identical Water inventories and state traces at one and six workers. [Regressions](../../native/tests/test_wave_spill.cpp)

| Native radius-24 Oil deposit, 384-column tank | Previous | Candidate |
|---|---:|---:|
| Occupied columns, tick 300 | 91 | 212 |
| Maximum Oil cells per column, tick 300 | 34 | 17 |
| Occupied columns, tick 900 | 124 | 361 |
| Maximum Oil cells per column, tick 900 | 29 | 10 |

All 1,793 Oil cells reached the surface in the candidate. The tank conserved 9,067,545 Water units and produced no new spray between ticks 300 and 900. In the separate 48-cell Oil tank, Sand settled and the undisturbed surface stayed quiet. Opening the gate at tick 3,600 threw 53,436 Water units. The local Windows DLL for the combined fix has SHA-256 `ad96ac5ff048a040515af4aa12d34eb624fa755f4ec0213e31e087fbff616d3f` and input fingerprint `87e95f6bc25abd6f469461d52f0efc28fb028efd8b666bc32985afda95a32d6f`. [Workbench replay driver](wave-oil-lava-2026-11-19/workbench-ramp-replay.gd) · [Material census](wave-oil-lava-2026-11-19/workbench-ramp-metrics.py)
