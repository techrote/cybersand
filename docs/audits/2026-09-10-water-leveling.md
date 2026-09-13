# Faster Water sideways leveling

Date: 2026-09-10. Owner feedback after issue #13 requested faster sideways
flow and asked about the purple layer on burning Coal. Work is in
`C:/kybersand/source` on `codex/water-sideways-leveling`, starting from verified
`4bead5501d902c424820814e7b5bcf1f9abea324`. The focused **Speed up Water lateral
leveling and document Coal residue** commit is recoverable from branch history.

## Change and boundaries

Water's lateral request is now `floor(3 * (source_mass - target_mass) / 4)`
instead of half the difference, followed by the existing viscosity and bounded
mass transfer. It can cross the pair midpoint while contracting the difference;
the existing difference-at-most-one rest tolerance prevents one-unit ping-pong.
Gravity and diagonals still precede lateral work. Candidate count, tick cadence,
read/write radius, capacity, ownership, saves, films at 48/255, coherent-emission
delay 12, adhesion and density exchange are unchanged. No new field or loop was
added. See the [Water contract](../systems/water-design.md) and
[ADR-005](../decisions/ADR-005-water-model.md).

Coal already converts to **Dust (14)** when its burn counter expires. Dust's
RGBA palette is `(218,198,238,255)`, explaining the pale purple residue. There
is no separate Ash material. This checkpoint changes neither reactions nor fire
cadence. The owner's earlier observation that reduced cadence made Wood smoulder
while Oil and Coal felt good remains an observation, not a tuning change.

Schema-1 profile values/hashes are unchanged. A profile hash alone therefore
cannot certify solver behavior: source and artifact identity are also required.
The optional Threshold erosion preset receives stronger real Water motion;
it was not retuned to hide that consequence. Ordinary gameplay keeps pickup off.
#11 barrel work, #12 soliding, large turbulence and chemistry tuning remain separate.

## Reproducible basin measurement

Raw evidence prefix: `C:/kybersand/validation/local/2026-09-10-water-leveling/`.
`tools/physics/water_leveling.py <output>` independently rebuilt the old and new
CLI in `baseline/` and `three-quarter/`. Compilation timeout is 300 seconds;
each execution timeout is 180 seconds. The runner records commands, exits, seven
fixed-tick samples and work counters. Each implementation passed 24 cases:
width 48/96, signed translation -65/0/63 applied to both axes, mirrored/unmirrored,
one/four workers, 1,800 ticks. Closed basins start with 12 by 32 full Water cells.
Every tick conserves exactly 97,920 mass units. Prepared chunk/temperature
allocations are zero; recorded samples match exactly across worker counts.

[Baseline inputs](water-leveling-2026-09-10/baseline-manifest.json) and
[results](water-leveling-2026-09-10/baseline-results.json) remain separate from
[candidate inputs](water-leveling-2026-09-10/candidate-manifest.json) and
[results](water-leveling-2026-09-10/candidate-results.json). The candidate build
preceded a comment-only solver edit; the final DLL/Web builds contain the final
comment and new regression. Exact per-series hashes preserve that distinction.

Medians over six one-worker geometries; arrival means a column containing at
least 128 mass units reaches three quarters of basin width. Leveling means the
largest minus smallest column mass is at most 255 (one full cell).

| Measurement | Previous half | New three quarters |
|---|---:|---:|
| 96-wide arrival, ticks | 480 | 258 |
| 48-wide one-cell leveling, ticks | 1,080.5 | 562 |
| 96-wide column spread at tick 1,800, mass units | 1,076 | 425 |
| 48-wide column spread at tick 1,800 | 57 | 46 |
| 48-wide visited cells / active block sum | 714,316 / 11,328 | 406,306 / 6,391 |
| 96-wide visited cells / active block sum | 730,615.5 / 18,220 | 726,517 / 17,991 |
| 48-wide total tick cost, ms | 481.806 | 274.260 |
| 96-wide total tick cost, ms | 520.441 | 526.413 |
| 48-wide p50 / p95 tick, microseconds | 263.75 / 290.80 | 256.65 / 279.70 |
| 96-wide p50 / p95 tick, microseconds | 284.55 / 304.65 | 284.55 / 334.80 |

The narrow basin levels about 1.92 times sooner; the wide front arrives about
1.86 times sooner. Neither wide implementation meets the one-cell leveling
criterion by 1,800 ticks (zero in the result field means not reached). Remaining
wide-basin spread improves from 4.22 to 1.67 full cells. Timing is descriptive on
a shared Windows host, with some other checks/builds overlapping; it does not
establish a universal tick speedup. The small basin sleeps sooner and does less
work. Measurement scans and output are outside timed `tick()` calls.

## Regression and rebuilt platform evidence

Tools remain pinned: LLVM-MinGW clang 23.1.0, Godot 4.7
`5b4e0cb0f`, Rapier 0.35.2, Emscripten 4.0.20. All builds/logs stay in the raw
prefix or its dated wrapper directories. No deliverables were copied to
`C:/cybersand` and published manifests were not rewritten.

- `C:/kybersand/dev.cmd native-test`: **55/55 pass**, 136.66 seconds. The new
  Water lateral-speed regression checks mirrored signed basins, exact mass on
  every tick, front arrival and leveling at fixed deadlines, one/four workers and
  zero prepared allocations. Existing Water films/spray, sleep, conservation,
  player support, packing, chemistry and failure regressions also pass.
- `issue13.py --layouts packed poured powder --reference
  docs/audits/issue-13-2026-09-09/baseline-references.json --output <raw>`:
  **30 unchanged reference cases**, with exact samples against frozen #13
  packed/poured Mercury and powder controls. [Input identity](water-leveling-2026-09-10/reference-manifest.json).
  Historical Water traces are intentionally not claimed unchanged.
- `dev.cmd native-build`: pass, 10.817 seconds, wrapper `20260910-011904`.
  Rebuilt DLL SHA-256:
  `fc6cb4ee1096219f581bace3df04ee8138e996aaf4c1436f5b2c071ea62dd496`.
- `dev.cmd web` and `dev.cmd web --profile threaded`: pass, 41.443 and
  40.671 seconds, wrappers `20260910-011939` and `20260910-012021`.
- `dev.cmd godot-test` initially **failed** importing the original project:
  locked `~cybersand_native...dll` and `~libgodot_rapier...dll` copies from an open
  editor. Godot exited zero but emitted import errors; these are retained in
  `godot-tests.log` and `20260910-012013/godot-import.log`, not counted as passes.
  `tools/physics/isolated_godot.py <fresh-output>` copied the source project and
  rebuilt DLL without cache/shadow files, imported it and passed **24/24 Godot
  fixtures** (240-second timeout each). [Copied input hashes](water-leveling-2026-09-10/godot-manifest.json)
  and [commands/results](water-leveling-2026-09-10/godot-results.json) identify
  actual desktop execution including asynchronous owner, player and renderer.
- **72 transport cases**: 24 [native](water-leveling-2026-09-10/native-probe.json),
  24 [compat Web](water-leveling-2026-09-10/web-compat.json), 24
  [four-worker Web](water-leveling-2026-09-10/web-threaded.json). Real Chromium
  152 on Windows loaded rebuilt exports at loopback ports 8901/8902 with
  `?test=1&transport=1`, COOP/COEP, no-cache headers, and write-once collectors.
  Both browser profiles pass failure quarantine/region re-entry and match all
  transport rows exactly. Native and Web counts, events and profiles match;
  platform-width-dependent native/Wasm state hashes are not compared across ABI.

[Runtime manifest](water-leveling-2026-09-10/runtime-manifest.json) records final
source hash `62f58762e2b578af6668c163c1e19ccebb032e164a4470b92f81d38fe009df8f`,
HEAD plus deltas, DLL, exported Wasm/PCK and tool identities. It also inventories
older diagnostic executables: inventory alone does not certify those as rebuilt
for this follow-up. Only the named per-series executables and rebuilt runtime
artifacts support the results above. Final committed identity is captured under
the raw prefix after the checkpoint.

## Transport consequences and limits

In the unsampled 600-tick native packed/loose Water layouts, Baseline pickups
remain 0/0. Gentle pickups change from 0/15 to 0/18. Threshold erosion pickups
change from 71/89 to **428/508**: the same threshold sees stronger mass motion.
Baseline transferred mass rises from 18,078,720/18,024,029 to
28,296,903/28,414,321. All species/mass checks pass, and every pure Mercury/powder
platform row stays identical to the prior source on its own ABI. Faster Water
does not imply preserved optional erosion strength; the older 480-case sampling
screen remains dated evidence of the older solver, not new measurements.

The rebuilt compat Tower was visually checked on the Water floor with the Water
plug opened, ordinary run/pause and contained sideways flow. Screenshots remain
in the raw prefix. This is a focused visual smoke check, not a new five-floor
walkthrough or proof of performance. The prior #13 walkthrough remains dated.
Linux, fresh owner feel review and isolated performance benchmarking remain gaps.

Intake normal DLL and both shadow DLLs were copied intact to `intake/` before
changes. No agent command removed shadow files or closed the owner's editor.
At final inspection the shadow files were absent, so a current-byte equality
check could not run; their intake bytes/hashes remain preserved in
[comparison evidence](water-leveling-2026-09-10/comparison.json). The normal rebuilt
DLL stays deliberately dirty. Existing user sessions may still hold older code;
restart before assessing the new solver.

Canonical synchronization covers Water/ADR-005, material residue, profile source
identity, configuration, Tower controls, tests, validation evidence, roadmap,
handover and checkpoint recovery. Ownership, interfaces, capacity, saves and
other invariant definitions are unchanged. Supplementary retrieval C15/C16 route
Coal residue and faster Water; the frozen 32 questions remain unchanged.

Final gates: documentation, historical M11 integrity, eight validation-checker
unit tests, retrieval execution and `git diff --check` pass. The current repository
gate retains **16 published-provenance/LFS mismatches**: seven changed source
inputs for each of Windows/Linux, Windows published bytes and Windows committed
LFS identity. This is not an all-green publication result. Fresh Windows build
evidence is separate; no current Linux rebuild is claimed.

[Gate commands/exits](water-leveling-2026-09-10/validation.json),
[repository result](water-leveling-2026-09-10/repository.json),
[frozen retrieval](water-leveling-2026-09-10/retrieval.json) and
[supplementary retrieval](water-leveling-2026-09-10/challenges.json) are retained.
The unchanged 32 score 23 top-1 / 32 top-5, MRR 0.8385. Sixteen supplementary
questions score 12 top-1 / 16 top-5, MRR 0.8562. C15 ranks first; C16 ranks second.
An earlier local iteration missed C16 in the top five; adding a dedicated Water
flow/profile-identity heading corrected the route. That iteration remains in
raw `gates/`, with final results in `gates-final/`; this is development-set
maintenance, not an unseen-question improvement claim. Manual review confirms
the canonical paragraphs supply residue identity and the required solver/profile
qualifier. Lexical rank does not independently certify answer correctness.
