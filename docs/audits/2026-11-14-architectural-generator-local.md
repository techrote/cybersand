---
title: Architectural Generator A+B — local qualification
status: Current
document-kind: audit
scope: Dated local source-matched implementation, native material captures and numerical evidence; hosted platform acceptance is recorded separately in the Draft PR
last-reviewed: 2026-11-14
related-documents: [../systems/architectural-generator.md, ../operations/architectural-generator-playtest.md]
---

# Architectural Generator A+B — local qualification

**Draft/HOLD. Do not merge.** This report records local evidence before hosted
publication. The dedicated PR and its exact-head Actions artifacts carry the
subsequent Linux graphical, Windows graphical and packaged execution results.
No Windows execution is inferred from this Linux report.

## Source custody and implementation

The dedicated branch is `feat/gen007-architectural-generator-ab`, based on
accepted main `ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`. The tested Linux
extension SHA-256 is
`84a0dae9de7419078aceaa363997e2062598acfa31afebcb1b48e4826f8c5dac`.
Its 90 native input hashes were recorded before compilation and checked again
after compilation and qualification. The source is an uncommitted implementation
at the time of these local records; the base SHA alone does **not** identify it.
The [machine-readable evidence](2026-11-14-architectural-generator-local.json)
retains those input identities, original measurements and log hashes.

Local dependencies were official Godot `4.7.stable.official.5b4e0cb0f`, clean
godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`, and the committed pinned
Linux Rapier library. The host used GCC 14.2, ld 2.44, Linux 6.18.57, glibc 2.41
and an AMD EPYC 9V74, with nine reported logical processors. The existing explicit
local toolchain-drift option admitted this compiler; it is not release-toolchain
evidence. Hosted builds use the repository's pinned compilers.

The [source contract](../systems/architectural-generator.md) describes schema 4,
generator algorithm 5, Arcology/Vault v2, the embedded project/preset format and
the bounded `connected-hilbert-v1` compiler. The generated-start v1 manifest and
native World installation boundary are unchanged. Existing retained binary
provenance is not rewritten to pretend that an old runtime contains this change:
candidate packages receive their own verified source/build manifest. Publishing
accepted retained runtimes remains a later integration gate.

## Executed tests

| Local test | Observed result |
| --- | --- |
| `make -j2 CXX='g++ -Wno-error=mismatched-new-delete' worldgen-test` | All nine suites passed; zero failures |
| Same target family, `worldgen-sanitize`, ASan/UBSan | All nine suites passed; zero failures |
| Procedural generation / semantic grammar / typed fields / semantic planes | 415,193 / 208,725 / 14,162 / 774,842 assertions |
| Independent architectural project contract | 1,817 checks; zero failures |
| Architectural compiler/native campaign, run 6 | 745 checks; zero failures |
| Final focused architectural UI | 49 checks; zero failures |
| Ordinary Workbench author/install/paint/erase/save | 30 checks; zero failures |
| Separate-process reconstruction and continued painting | 16 checks; zero failures |
| Existing Workbench / fields / typed / hierarchy / planes | 143 / 271 / 394 / 438 / 606 assertions; zero failures |
| Existing Workbench canvas and built-in policy scenarios | 164 checks; zero failures |
| General profile discovery | 23 checks; zero failures |
| Dedicated GEN-007 Workbench / inspection | 166 / 116 assertions; zero failures |

The compiler contract independently traverses zones with breadth-first search
over 64 seeds and three grid resolutions. It also checks infeasible quotas,
sparse selected slots, hostile JSON, custom aperture resolution, input mutation,
and fresh native owners at seeds 0 and 9007199254740991. Focused UI tests include
real required GEN-004 routes and support contacts, with actionable refusal of
blocked schema-4 proposals and preserved legacy schema-3 admission behavior.

ASan used `detect_leaks=0:strict_string_checks=1`; UBSan used
`halt_on_error=1`. These are not leak-detection results. The GCC 14 warning
exception applies to pre-existing test allocation instrumentation; it does not
weaken production compiler diagnostics. Final native build-and-test campaigns
took 27.55 s normally and 102.71 s sanitized, including incremental compilation.

Five required example profiles were captured from an independently built,
immutable base worktree, then compared against the new runtime. All material,
recipe, fingerprint and receipt hashes matched for `district-arcology`,
`sidechained-arcology`, `typed-categorical-districts`, `hierarchy-multi-district`
and `gen007-deepworks`. A separate native oracle freezes six schema-1/2/3 module-v1
fingerprints and 24 signed-chunk material hashes; all remain unchanged.
The six fixed fingerprint snapshots were captured on Linux/libstdc++; the
schema-2/3 fingerprint assertions are explicitly scoped to that ABI. Their
material hashes remain unconditional. Other-platform complete receipt identity
requires the independently built same-platform baseline described below.

The owner campaign opened the panel, disabled tunnels/windows, generated 1024²,
cancelled a changed request, rejected stale admission, restored the previous
proposal, changed dimensions/seed/ratios, generated again and installed through
the ordinary Workbench. It painted and erased actual native cells, waited for
all edit completion receipts, saved, exited, reopened in a new process and
verified source reconstruction plus retained edits. Invalid and cancelled
proposals preserved the installed World.

## Coverage and actual native output

Each 1024² result at seeds **161803, 271828 and 314159** used a 16×16 grid of
64-cell planning blocks and independently measured one four-connected zone
component per style:

| Style | Requested | Blocks | Achieved area |
| --- | ---: | ---: | ---: |
| Industrial Service | 45% | 115 | 44.921875% |
| Habitation / Arcology | 30% | 77 | 30.078125% |
| Overgrown / Ruined Construction | 25% | 64 | 25.000000% |

These count assigned zone cells, including Empty cells. At 512² the shares are
45.3125%, 29.6875% and 25%. Shape connectivity is distinct from material or
player traversal connectivity. Style boundaries may clip rooms.

With all three apertures disabled, a 512² Industrial/Habitation comparison had
**61,004 occupied-versus-empty differences**, demonstrating real geometry
differences independently of palette. Changing only tunnels, doors or windows
in the three-style 512² fixture changed **3,417**, **3,956** or **2,883** material
cells respectively; native tests additionally assert the precise carving stage,
aperture closure and preservation of unrelated shafts, authored paths and
required semantic passages. A targeted receipt-backed test examined 2,432
adjacent cross-style cell pairs and found 121 automatic route crossings covering
all three style pairs. Every crossing had Empty native raster cells on both
sides; the same positions had no automatic-route receipt with tunnels disabled.

Original native-material captures (not a stitched illustration or framebuffer):

| Comparison | Captures |
| --- | --- |
| Same project, three seeds | [161803](../images/architectural-generator/three-style-seed-161803.png), [271828](../images/architectural-generator/three-style-seed-271828.png), [314159](../images/architectural-generator/three-style-seed-314159.png) |
| Independent switches | [All on](../images/architectural-generator/controls-all-on.png), [tunnels off](../images/architectural-generator/automatic_tunnels-off.png), [doors off](../images/architectural-generator/automatic_doors-off.png), [windows off](../images/architectural-generator/automatic_windows-off.png) |

The ruined style was revised after an early capture left only 25.40% of its
structure in one seed. The final 0.20 deterioration threshold and smaller noise
scale retain **86.89%, 79.50% and 82.33%** of that zone's undamaged occupied cells
across the three seeds. This is measured structural retention, not its area quota.

## Timing and bounded work

Measurements below are wall-clock samples on a shared local host, taken from
the original run-4 receipt. PNG time includes material colour conversion and
file encoding, not a displayed frame or interactive GPU latency.

| Configuration | Planner | Native preparation | Native raster | Material copy | Colour + PNG |
| --- | ---: | ---: | ---: | ---: | ---: |
| Three styles 512² | 0.604 ms | 0.366 ms | 0.829 s | 0.079 s | 0.046 s |
| Three styles 1024², seed 161803 | 1.149 ms | 0.551 ms | 3.448 s | 0.348 s | 0.229 s |
| Three styles 1024², seed 271828 | 0.846 ms | 0.496 ms | 4.515 s | 0.431 s | 0.197 s |
| Three styles 1024², seed 314159 | 1.281 ms | 0.648 ms | 3.193 s | 0.302 s | 0.228 s |
| Existing district-arcology 512² | — | 0.173 ms | 0.301 s | 0.090 s | — |
| Existing district-arcology 1024² | — | 0.181 ms | 1.041 s | 0.371 s | — |

The old-profile comparison uses equal map extents and the same runtime, but a
different recipe and fewer masks/modules; it is not an equivalent-output
overhead ratio. Native phase peak RSS was about 140 MiB; author/reopen phases
peaked at roughly 475–483 MiB. Editor import has a separate larger peak.

A 1024² proposal copies 1 MiB of material bytes and produces a 4 MiB RGBA
preview. Its 64 chunks account for 3,586,129,920 logical operations, or
56,033,280 per chunk, below the native 64,000,000 per-chunk limit. Logical
operations are budget units, not CPU instructions. Planning retains at most
256 blocks. Vault preparation remains bounded at 64×64 rooms; Arcology v2 adds
constant prepared state and no per-cell allocation. Cancelled work retains no
installation authority.

## Review findings and remaining acceptance

Review repaired malformed-type JSON exceptions, large-seed and fractional-share
UI rounding, duplicate versioned module-picker entries, and schema-4 semantic
route/support admission. Early harness failures were also retained: insufficient
test polling for tiny slices, saving before all edit receipts drained, and an
incorrect restore assertion after successful installation. No production save
or source-integrity guard was weakened to make those tests pass.

Local documentation/link, M11 custody, CI provider and scheduling checks passed.
The repository-wide retained-runtime check correctly reports that accepted
binary provenance needs rebuilding for changed native inputs; candidate custody
does not silently renew that accepted-runtime claim. Frozen retrieval questions
were preserved and three additive architecture questions were supplied.

The finite allocator, clipped boundaries, fixed dimensions, three visible UI
slots and lack of guaranteed cropped-maze traversal are deliberate prototype
limits. A Windows package and actual graphical execution require hosted results;
human Windows 11 acceptance at the owner's display scale remains separate from
automation. Follow the [owner checklist](../operations/architectural-generator-playtest.md)
and keep the PR Draft/HOLD.

## First hosted attempt: compatibility-reference correction

The first hosted run,
[43547442838](https://github.com/techrote/cybersand/actions/runs/43547442838),
tested source `a32e3aeb26a57222cec72915cf282b87e6b6f83d`. Its pinned Windows
DLL had SHA-256
`284885299ccae733b83a7742075ede258824c6e8cef16a9fc967428e0b6b7f40`.
Windows native/compiler/UI and all existing regression scripts passed. Actual
graphical owner authoring passed 34 checks and separate-process reopen passed
19, both with zero failures. The final legacy-reference comparison failed and
correctly stopped packaging; this attempt is **not** a complete qualification PASS.

All five legacy material and canonical recipe hashes matched the immutable
Linux baseline. Only the schema-2/3 native fingerprints and receipt hashes
differed. Independent source review traced this to the unchanged typed-spatial
fingerprint's `sizeof`-based memory ledger. The correct repair is an independently
built Windows accepted-base reference with the same pinned toolchain, retaining
all-field exact comparisons there and separate cross-platform material/recipe
comparisons. No legacy production fingerprint or material algorithm is changed.

The Windows process-memory sampler also observed the console launcher's small
working set, not the engine child. Those initial Windows RSS values are invalid
as engine measurements. Subsequent qualification records mark Windows engine
memory unavailable; Linux high-water measurements remain valid.

On the frozen source above, a separate actual-dialog benchmark, using normal
process frames, measured request-to-verified-ready at **1.008064 s for 512²**
and **4.160945 s for 1024²**, seed 161803, all switches on. This local headless
measurement included compilation, generation, copy, colour conversion, texture
creation and scheduling in a standalone dialog; it did not include an active
Workbench World or first displayed frame. It passed seven checks with no source
drift. Final graphical timing and package results belong to the exact-head
[Draft/HOLD PR #582](https://github.com/techrote/cybersand/pull/582) and its retained
workflow artifacts.
