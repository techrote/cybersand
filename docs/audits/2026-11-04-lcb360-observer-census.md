---
title: LCB-FEEL #360 observer material-census repair (#358 audit P1-03)
status: Current
document-kind: evidence
scope: Source-pinned Windows and WSL2 Linux qualification of the #360 observer's admitted-catalogue material census against the published #358 new-ID fixture, plus full preflight parity at the repaired source; observer-only, no native, policy, default, Rapier, rendering, combined-#358-source or GitHub-hosted execution claim
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-03-lcb360-feel-preflight.md, ../operations/lcb-feel-comparison-route.md, ../architecture/pressure-flow-v1.md, ../architecture/inertial-cellular-v1.md]
---

# LCB-FEEL #360 observer material-census repair — 4 November 2026

## Result

**Checkpoint A met for the observer at its tested source.** The census no longer
assumes a catalogue size. It counts the published #358 fixture exactly, refuses
reserved and unknown identities, and keeps bound Water out of free Water. At the
repaired source, the complete original preflight reproduces every committed
physical observable on both hosts. The strict reducer admits 32/32 primary rows
again.

A **combined #358 + #370 source has not been executed.** The new-ID case uses a
synthetic readback through the same census, as the #358 coordination allowed.
Whichever PR integrates second must qualify the real union.

## Defect

[Independent review 6618628335](https://github.com/techrote/cybersand/pull/358#issuecomment-6618628335)
finding P1-03 is confirmed. The v1 `inventory()` in
[`liquid_feel_probe.gd`](../../godot/scripts/liquid_feel_probe.gd) did three things wrong:

- It counted only IDs 1..131 from the copied material cells.
- It computed Empty as the remainder of the World area.
- Its `complete` flag was therefore tautological.

On a union with #358 (IDs 132..137), those cells would have been reported as
Empty, with `complete=true`. The test's v1 witness reproduces this: Empty
1,048,574 and no 132..137 entries. On current main no such IDs exist, so the
[committed preflight](2026-11-03-lcb360-feel-preflight.md) remains valid at
its own source.

The peer #360 review also identified a second, independent weakness, which this
repair confirms. `get_cells()` is a render cache. It refreshes only when the adapter
revision changes, and `simulation_tick` bumps that revision only for moved cells
or deferred events. A tick that changes materials any other way could leave
non-Water counts stale. The cache also dithers fractional Water to Empty.

## Corrected contract (probe schema `lcb-feel-probe-v2`)

- **Identity domain.** Native material IDs are byte-sized (`material.hpp`
  static assertion). The census histograms all 256 byte values and stops only
  once every cell has been covered. Nothing can hide outside the counted range.
- **Admission.** `native_catalogue()` reads the loaded native artifact. On a
  private, never-ticked scratch World, it offers each byte to a 1×1
  `diagnostic_fill_rect`. That call accepts exactly the `kLastMaterial`-bounded
  `valid_material` identities. The result must equal the `cell_world.gd` mirror
  (0..`LAST_MATERIAL`, reserved 10); otherwise every census refuses. A future
  admitted catalogue extension is therefore enumerated without an observer edit.
- **Refusal.** An observed identity that is not admitted refuses the census. IDs
  below the highest admitted ID are reported as *reserved*, and IDs above it as
  *unknown*. A refused census has no `counts`, so nothing can be folded into
  Empty or reported complete.
- **Uncached stored source.** Live inventories read `World::stored_material`
  through `diagnostic_snapshot` in four 512×512 tiles. This read is const, has
  no render cache, does no dithering and consumes no dirty state.
  - Water bytes must equal the stored Water cell count exactly.
  - The census must agree with the native per-tile histogram and with the
    stored Water `state_a` sum of the same observation.
  - A World without that source (non-diagnostic) is reported incomplete; the
    cache is not used as a fallback.
  - The explicit dithered-copy reconciliation path remains available for copy
    readbacks.
- **Empty** is derived only after every non-Empty identity is validated:
  copy Empty+Water minus stored Water.
- **Bound Water** is reported only for catalogue-declared carriers. It comes from
  an explicit per-cell `state_b` readback that must cover every carrier cell,
  and it is never part of free Water. The native catalogue declares no carriers
  on current main. A union would need its integrator to wire a carrier readback
  before reporting bound Water.
- **Unchanged.** The free-Water census (stored `state_a` plus PressureFlow
  overfill), the IN tuple census, the pressure/gas ledgers and the existing
  `inventory {complete, area, counts}` fields and key order. New inventory keys
  are additive.
- **Apparent cavities.** `voids()` gains an additive `enclosed` definition:
  4-connected Empty components that touch no region edge, plus a Water-bounded
  subset. The column definition is unchanged. In the test it counts 284 Empty
  cells under a one-row Water film where only 16 cells are enclosed. Neither
  definition is gas or bubble physics.

The [MAT-AUTH-001 shadow catalogue](https://github.com/techrote/cybersand/blob/7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1/docs/operations/material-catalogue-shadow.md)
(#371, merged to main during this work, not yet in this branch) is deliberately **not** consumed. Production
consumer migration (#353-B) is unadmitted, and the loaded native artifact
remains the authority.

## Source and runtime authority

| Input | Identity |
|---|---|
| Accepted main at start | `3da7e7be4a6af4c85e03a7d8a0ed57229e5db33d`; `origin/main` later advanced to `7ef4856e` (#371, docs/materials/tools only) and is not merged here |
| Base | #370 local head `d99daed81f19a70f46bdb169ba123705d23431b9` (published head `9a7436aa…` + host-cohort driver) |
| Repair commits | `22ed127d23bcf884229bfda1daa57273cdf1bf07` (catalogue census) → **`4bd7560aaa6a213b966516176b238a8c1bd6fcb7`** (uncached source, cavities), tree `c169f498a41c7940174ae12cdcef881f9e9ea96a`, branch `claude/lcb360-observer-census` |
| #358 fixture | [`pr358.observer-fixture.json`](../../godot/tests/fixtures/lcb/feel/pr358.observer-fixture.json): byte-identical Git blob `3619d3a2…` at #358 `077f9c52` and `7383946a`, SHA-256 `0b487ede7608d83f…22c1438`; the test pins this digest |
| Native runtimes (unchanged) | Windows DLL `ee09f7ab…`, Linux SO `0f60213c…`, both matching provenance; Rapier Windows `b54e54bd…`, Linux `566e68ae…` |
| Godot 4.7.stable.official.5b4e0cb0f | Windows `Godot_v4.7-stable_win64.exe` `b2ca888d…`, console wrapper `d8055fb8…`; Linux `f85bbc6b…` |
| Machine | AMD Ryzen 5 5600X; Windows 11 Pro 10.0.26300; WSL2 Ubuntu 24.04.5, kernel `6.18.54.1-microsoft-standard-WSL2`, same hardware |

The Windows packet records branch `claude/lcb360-observer-census`, no dirty
source or generated paths, and an executed tree matching HEAD. The Linux
detached checkout records the same tree. Its two runtimes are classified as
materialized LFS objects matching HEAD; the other 410 dirty paths are
Godot-generated only.

## Commands

```bash
godot --headless --path godot --script res://tests/test_liquid_feel_census.gd
python tools/lcb/feel_preflight.py run --godot C:/tools/Godot/Godot_v4.7-stable_win64.exe --output OUT/windows
python3 tools/lcb/feel_preflight.py run --godot ~/…/Godot_v4.7-stable_linux.x86_64 --output OUT/linux
python -I tools/lcb/feel_observer_parity.py docs/audits/lcb360-preflight-2026-11-03/windows OUT/windows
python -I tools/lcb/feel_observer_parity.py docs/audits/lcb360-preflight-2026-11-03/linux OUT/linux
python tools/lcb/feel_preflight.py reduce --logs-external --packet OUT/windows --packet OUT/linux --output summary.json
python -m unittest discover -s tools/lcb -p test_feel_preflight.py
```

The census test has the CI `test_liquid_` complex-case watchdog and is
auto-discovered by the Godot regression runner. Preflight arms used the shared
`ordinary_case_seconds` watchdog (1,200 s).

## Results

### Focused census test

[`test_liquid_feel_census.gd`](../../godot/tests/test_liquid_feel_census.gd):

| Source | Windows | Linux |
|---|---|---|
| `22ed127d` | 67 assertions, 0 failures | 67/0 (log `421a8ab8…`) |
| `4bd7560a` | **79/0** (log `43a383f7…`) | **79/0** (log `016c8fa9…`) |

A mutation that admits every identity produced 10 failures at `22ed127d`. All
three adversaries and the native-catalogue refusal failed, so the test
discriminates the defect. Live 1024² census cost was 63 ms on Windows and
105 ms on Linux, including the four-tile copy, in a headless process.
This is not a benchmark.

Fixture checks are against the fixture's own `expected` values, never a census
recomputation:

| Fixture expectation | Observed (Water visible and Water dithered readbacks) |
|---|---|
| Empty 1,048,568; Sand2, Water3, IDs 132–137 one each | exact; no other key |
| Counted cells 1,048,576; complete | 1,048,576; `complete=true` |
| Free Water 7 | 7 (Water `state_a` plus overfill only) |
| Bound Water 510 separately | 510 = Activated Binder136 255 + Binder Crust137 255; internal states 180/255 and 0/255 delivered |
| Reserved 10; unknown 138, 255 | each refused, one cell named, no counts |
| Current-main native catalogue on the same fixture | refuses exactly 132..137 as unknown |

Other adversarial controls:

- A carrier without a state readback, a partial carrier readback or a foreign
  state entry is incomplete.
- A visible Water byte without stored Water is incomplete. So is stored Water
  with no Water/Empty byte, an undithered copy hiding a stored Water cell, or a
  short copy.
- A catalogue that is unavailable or malformed refuses: duplicate IDs, no Water,
  a non-byte ID, Water as a carrier or an unadmitted carrier.

The live diagnostic World checks:

- Counts equal the filled geometry: Sand 100, Stone 20, highest ID 131 nine,
  Water 200, Empty remainder.
- The cached copy showed only 110 Water bytes; the stored source showed all 200.
- The result equals the v1 result for this admitted-only World.

### Preflight parity at `4bd7560a`

The registered 29 jobs per host (28 arms plus negative controls) ran once each,
not as a new qualification. They match the [committed packet](lcb360-preflight-2026-11-03/)
in every compared physical observable on both hosts:

- inventory counts;
- visible Water, PF overfill, quantity, cell count and hashes;
- physical-state hash;
- IN tuple census;
- pressure/gas ledgers;
- health;
- every per-tick hash, quantity and movement value.

See [`parity-comparison.txt`](lcb360-observer-2026-11-04/parity-comparison.txt).
The PressureFlow hidden-overfill control holds in all four PF dam rows: final
visible 4,679,482 + overfill 20,678 = 4,700,160. The inventory is unchanged
(Wall 14,844, Water 18,408, Empty 1,015,324).

The strict reducer returns **ADMITTED**:

- 32 primary rows (16 per platform);
- all 28 cross-platform cases with equal tick and final hashes;
- summary SHA-256 `17d3cc3c…7e4ffc`;
- Windows packet committed LF blob `ead5a653…7fb958`. The driver wrote it with
  CRLF as `35cbc821…8550e1`, because its `packet.json` write still uses
  platform newline translation;
- Linux packet `90fcd95c…3d756ae`.

Receipt hashes are unaffected, because Godot writes receipts with LF.

These are committed under [`lcb360-observer-2026-11-04/`](lcb360-observer-2026-11-04/).
`test_feel_preflight.py` passes 33/33, including the committed-packet reduction.

Raw receipts and logs are retained outside Git in WSL
`~/cybersand-lcb360-evidence/observer-4bd7560a/`. Their hashes are in the
committed packet manifests.

## Gaps and observations

- **No combined-source execution.** The #358 native IDs were not imported.
- **Bound Water on a union is not observed yet.** The census reports it only
  when a carrier readback is wired.
- **Diagnostic-fixture Worlds only.** The uncached source needs one. The
  harness uses `diagnostic_reset`, and the desktop comparison route does not use
  this probe.
- **Latent native diagnostic hazard.** `diagnostic_snapshot` increments a
  132-entry histogram indexed by the stored byte. It is unreachable while native
  writes validate identities, but it would be out of bounds for an unadmitted
  byte. It belongs to the native owner and is not changed here.
- **No GitHub-hosted CI result.** No Rapier, rendering, host-timing or feel
  claim is made either.

**Handover.** The #360 integrating session cherry-picks these commits onto
`claude/lcb360-feel` and adds navigation links. Its reducer may consume
`voids().enclosed`.
