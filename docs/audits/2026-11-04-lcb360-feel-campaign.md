---
title: LCB-FEEL #360 seven-scenario campaign, desktop-host cohort and comparison report
status: Current
document-kind: evidence
scope: Source-pinned native correctness campaign of four Water liquid families over six executable comparison slots at configured workers 1/4 on Windows and WSL2 Linux, a small windowed full desktop-host cohort on Windows, the compact comparison report, and successor handovers to issues 361-363; no human feel, GitHub-hosted, browser or preferred-solver claim
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-03-lcb360-feel-preflight.md, ../operations/lcb-feel-comparison-route.md, ../architecture/liquid-solver-family-policy.md, ../architecture/inertial-cellular-v1.md, ../architecture/pressure-flow-v1.md, ../architecture/simulation-tick-and-threading.md]
---

# LCB-FEEL #360 campaign and comparison — 3–4 November 2026

## Result

**Correctness campaign ADMITTED:** all **96 registered primary rows** passed
every registered invariant: six executable slots × four Water families at
matched radius 3 × configured workers 1/4 × Windows/Linux. Every arm's
physical-hash sequence (each 10th tick plus the horizon) is identical for
workers 1 and 4, and across both OSes. Slot 7 (Rapier impact) is a
**registered gap**: the native-only controlled route cannot carry a body.

The behavior differences below are **measured physical outcomes of
correct runs**. They are not defects, rankings or feel judgements. A
preferred gameplay solver is not selected.

## Source, runtime and execution identity

| Input | Identity |
|---|---|
| Accepted main | `070c7a22ad51ea9206931cd9d56fd1e7cfe212aa` (rechecked) |
| Registration | [`lcb.feel.campaign.v1.json`](../../godot/tests/fixtures/lcb/feel/lcb.feel.campaign.v1.json), committed in `9a7436aa` before execution |
| Executed source | `9a7436aa3d…` on both OSes, clean apart from Godot-regenerated files; Linux ran in a pointer-only clone with byte-verified LFS runtimes |
| Runtimes | Unchanged source-matched DLL `ee09f7ab…` and SO `0f60213c…` (provenance build `a7ee10f2`; no native or adapter change on this branch) |
| Godot | `4.7.stable.official.5b4e0cb0f`, same binaries as the [preflight](2026-11-03-lcb360-feel-preflight.md) |
| Machine | One Ryzen 5 5600X (6C/12T), 32 GB. Windows 11 and WSL2 Ubuntu 24.04 on the same hardware |
| Windows run | 2026-11-03 23:08:14–23:53:50Z, 49 processes (48 arms plus negative controls), slowest 127 s |
| Linux run | 2026-11-03 23:10:33Z–2026-11-04 00:01:53Z, 49 processes, slowest 125 s |
| Committed packet | [`lcb360-campaign-2026-11-03/`](lcb360-campaign-2026-11-03/): both `packet.json` manifests binding every raw receipt and log SHA-256, plus `summary-compact.json`. Committed LF-blob SHA-256: Windows manifest `d215e965…5f3279` (produced as CRLF `e1da17a1…52f96` before the `c23f63dd` writer fix), Linux manifest `feb833f8…72b5e`, compact summary `1da7bc86…1583e5`. The compact summary derives from the hardened reducer's full reduction `3f9176d6…a764d0` |
| Raw packet | 94 MB of receipts and logs, retained outside Git (`~/cybersand-lcb360-evidence/campaign-9a7436aa` on the WSL host) |

**Overlap disclosure.** The two OS legs ran at the same time on one machine,
so campaign tick timings are **excluded from every cost statement** here.
Clean cost evidence comes from the preflight's single-leg windows and the
host cohort below. Correctness, parity and physical outcomes do not depend
on timing.

## Registered campaign

Each slot uses a registered primary fixture at its own horizon, with
explicit zero-delta `water-normalize-v1`:

| Slot | Fixture | Horizon | Quantity rule | Registered edits |
|---|---|---:|---|---|
| 1 | `lcb.feel.leak-side.vented.v1` | 1200 | constant 3,478,200 | Lid vent tick 0, side puncture tick 120 (Wall −8) |
| 2 | `lcb.feel.drain-bottom.sealed.v1` | 1200 | constant 3,478,200 | Bottom drain tick 120 (Wall −4) |
| 3 | `lcb.dam.water.freemass.depth-96.v1` | 1800 | constant 4,700,160 | Gate erase tick 0 (Wall −1,536) |
| 4 | `lcb.head.vented-two-limb.v1` | 2400 | constant 2,758,080 | None |
| 5 | `lcb.rest.remote-disturbance.v1` | 1200 | ledger | Source at tick 300, sink at tick 900 |
| 6 | `lcb.shallow.stream-steps.v1` | 1800 | ledger | 4×4 whole-cell source every 30 ticks to tick 600 |

Applied edits are checked against the fixture itself: every scheduled edit
due before the horizon must appear exactly once in the owner history, with
the registered tick, kind and rectangle. A fill may add at most one cell
maximum per cell; an erase may remove at most two (stored Water plus PF
overfill). Water after tick *t* must then equal the initial quantity plus
every verified edit applied before *t*.

The review found the first version of this rule circular. The campaign was
re-reduced with the hardened rule. It verified all 20 stream fills, both
remote-wake edits and every opening, and the verdict was unchanged. The
[reducer tests](../../tools/lcb/test_feel_preflight.py) number 44; the
committed preflight packet still reduces to ADMITTED.

## Correctness

Every one of the 96 rows satisfied:

- the requested family, radius and workers equal native applied readback, with
  no foreign-material change;
- exact stored Water after every tick (constant or ledger);
- only Empty, Wall and Water in the complete inventory;
- the net Wall count changed only by the registered edits (a count check, not
  a positional digest);
- no failure; horizon reached;
- for IN, a complete census with zero negative `vy`; for PF, a closed gas ledger;
- the owner retired.

The negative controls (radius-2 IN, fractional Water without normalization,
the independent normalization rule, pressure refusals for Oil/Brine, and the
variant catalogue) passed again at the campaign source on both OSes.

**Participation.** Every configured-four arm observed 4 task claimants.
Ticks with more than one claimant out of the horizon:

- Dam: FM/CY/PF 1800/1800, IN 1021/1800.
- Vented two-limb: FM/CY/IN only 3/2400 (they sleep), PF 2400/2400 (it never rests).
- Leak and drain: about 1050–1080/1200.

These are participation counts, not utilization.

## Physical outcomes (identical on both OSes)

Water quantities are in native units (255 per full cell).
"Submerged Empty" is the maximum, across checkpoints, of Empty cells with
stored Water above them in the same tank column.

| Slot / measurement | FreeMass | CellularYield | PressureFlow | InertialCellular |
|---|---:|---:|---:|---:|
| 1 Leak: Water through the side puncture into the basin, t1200 | 194,086 | 244,290 | 270,662 | 22,185 |
| 1 Leak: max submerged Empty in tank | 0 | 0 | 0 | 18 |
| 2 Sealed drain: Water in the basin, t1200 | 549,780 | 549,780 | 805,443 | 219,810 |
| 2 Sealed drain: max submerged Empty in tank | 0 | 1 | 1 (PF label `vacuum`) | **193** |
| 3 Dam: reservoir remaining, t1800 (from 4,700,160) | 3,951,226 | 3,940,515 | 2,053,886 | 4,343,160 |
| 3 Dam: farthest band (6) Water, t1200 | 0 | 0 | 85,720 | 1,785 |
| 4 Vented two-limb: left / right limb, t2400 | 1,860,480 / 391,680 | 1,860,480 / 391,680 | 983,838 / 1,097,616 | 1,860,480 / 391,680 |
| 5 Remote wake: explicit source / sink | 16,320 / 16,320 | 16,320 / 16,320 | 16,320 / 16,320 | 16,320 / 16,320 |
| 6 Stream: admitted source, t1800 | 80,900 | 81,600 | 81,600 | 64,260 |
| 6 Stream: Water past the steps (runout), t1800 | 0 | 0 | 0 | 1,020 |
| Cells moved, dam (1800 ticks) | 2.30 M | 4.90 M | 30.1 M | 0.16 M |

Interpretation, limited to source mechanisms already documented:

- **Head transmission.** Only PressureFlow moves Water through the roofed
  two-limb passage. FM, CY and IN move **zero cells** in 2,400 ticks and sleep
  after three. The full-cell limbs are already supported columns, and nothing
  without a pressure term drives flow through the roofed passage. PF had not settled to equal levels by tick 2400 (right is above
  left). Equal levels are the vented target only, and the horizon is not
  extended after seeing the result.
- **Sealed drain.** PF drains fastest even under a sealed lid. This matches
  the documented PF limitation: gas bookkeeping does not resist falling Water.
  PF created 2,601 gas units across 4 compartments, but only one submerged
  Empty cell was ever observed, labelled `vacuum`.
- **IN apparent bubbles.** IN's large submerged-Empty count is an Empty-cell
  column inside the tank: retained-motion cells vacate faster than whole cells
  refill. IN has no gas state. These are visual voids, **not** gas bubbles. A
  rendered example is described in the [route guide](../operations/lcb-feel-comparison-route.md).
- **IN dam stall.** IN's reservoir is unchanged from tick 600 to 1800 at
  4,343,160, and no cells are moving at the horizon. Its early front still
  reached band 6. The other families keep spreading. This needs owner
  review and #363 routing; it is not a conservation fault.
- **Different source quantities.** The scheduled fill tops up partly occupied
  cells, so the admitted source quantity depends on the family. The ledger
  closes exactly in every arm.

## Desktop-host cohort (Windows, windowed)

A small cohort through the **real desktop application**: the launcher
feature, Main, the asynchronous owner and native World, the Rapier bridge, and
the windowed renderer. It was not headless.

| Item | Identity |
|---|---|
| Source | `d99daed8…`, clean tree; same source-matched runtimes |
| Display | Windows display server, NVIDIA TITAN RTX, GL Compatibility, vsync on (60 Hz) |
| Matrix | Dam d96 and quiet pool × 4 families × configured workers 1/4 × 3 repeats, family order rotated per repeat. 48 fresh processes, 600 native ticks each, matched radius 3 |
| Run | 2026-11-04 02:01:40–02:16:05Z; machine otherwise idle (no campaign overlap) |
| Packet | [`lcb360-host-cohort-2026-11-04/`](lcb360-host-cohort-2026-11-04/): `windows/packet.json` (`8f11899f…cb5a1`), all 48 arm records, `summary.json` (`316cad88…92a38`). Logs are retained outside Git |
| Reduction | `python tools/lcb/feel_host_cohort.py reduce --packet …` gives 0 failures. Every arm's applied family, radius and capacity match the request, and every owner capture's integer Water ledger closes |

Medians across the three repeats:

| Scenario | Family | Workers (claimants max) | Native ticks/s (target 60) | Owner capture tick p50 / p95 ms | Owner step p50 ms | Main frame p95 ms | Snapshot age p50 ms |
|---|---|---|---:|---|---:|---:|---:|
| Dam | FM | 1 (1) / 4 (4) | 59.2 / 59.4 | 10.44 / 15.87 → 6.85 / 8.86 | 10.63 → 7.09 | 16.78 / 16.82 | 23.9 / 23.5 |
| Dam | CY | 1 (1) / 4 (4) | 59.3 / 59.3 | 7.31 / 11.02 → 6.15 / 7.32 | 7.59 → 6.50 | 16.80 / 16.83 | 19.8 / 26.7 |
| Dam | PF ref | 1 (1) / 4 (4) | **29.7 / 38.7** | 31.84 / 40.54 → 24.07 / 29.34 | 32.10 → 24.34 | 16.80 / 16.78 | 23.7 / 23.6 |
| Dam | IN | 1 (1) / 4 (4) | 59.5 / 59.5 | 4.58 / 6.61 → 4.19 / 6.36 | 4.84 → 4.42 | 16.78 / 16.78 | 23.9 / 23.0 |
| Quiet pool | FM / CY / IN | 1 (1) / 4 (4) | 58.8–59.9 | 0.03 / 0.04 | 0.24–0.28 | 16.79–16.81 | 20.6–28.2 |
| Quiet pool | PF ref | 1 (1) / 4 (4) | **23.8 / 26.4** | 41.05 / 50.03 → 35.95 / 45.74 | 41.30 → 36.12 | 16.81 / 16.81 | 24.0 / 23.5 |

- **Rendering stays smooth while the simulation falls behind.** Main frames
  held vsync (p95 ≈ 16.8 ms) for every family. Simulation and presentation are
  independently paced, as designed.
- **PressureFlow reference cannot sustain the 60 Hz owner on this machine.**
  The dam ran at about half rate with 1 worker and about two-thirds with 4. The
  motionless pool ran at about 40–44%. In gameplay, PF Water would visibly run
  in slow motion here. Cached and cached_dormant variants are the registered
  next measurement before any PF gameplay profile is considered.
- **Four workers help the active dam:** FM 10.4 → 6.9 ms, CY 7.3 → 6.2 ms,
  PF 31.8 → 24.1 ms. IN changed little (4.6 → 4.2 ms). FM, CY and IN all
  stayed within the 16.7 ms budget at both capacities.
- **Native ticks per second is a pacing measure.** The owner targets 60 Hz, so
  only PF measures throughput shortfall. Actor-free scenes carry no Rapier
  bodies: the Rapier bridge step was about 0 ms and is not a contact cost.
- **Single machine, three repeats, 600 ticks.** Scenario and worker order were
  fixed; only family order rotated. These are observations, not a portable
  benchmark or a feel rating.

## Comparison report

| Family | Correctness / support in this campaign | Distinctive measured behavior | Measured cost (clean evidence) | Uncertainty |
|---|---|---|---|---|
| FreeMass (Current default) | 24/24 rows; fractional cells (18,496 vs 18,432 for the same dam quantity) | Moderate leak and drain; no head transmission; sleeps at rest | Desktop host dam owner tick 10.4 → 6.9 ms (1 → 4 workers) at 60 Hz; quiet 0.03 ms | No feel data |
| CellularYield | 24/24 rows; whole cells | Leak slightly faster than FM; drain identical to FM; no head transmission | Desktop host dam owner tick 7.3 → 6.2 ms at 60 Hz; quiet 0.03 ms | No feel data |
| PressureFlow reference | 24/24 rows; closed gas ledger | Fastest dam surge and drain; only family with head transmission; gas labels do not resist a sealed drain | Desktop host: 29.7/38.7 ticks/s on the dam and 23.8/26.4 on the quiet pool (1/4 workers), against a 60 Hz target | Cached and dormant variants not measured here; sealed-gas physics not validated |
| InertialCellular | 24/24 rows; zero negative `vy`; tuple digest parity | Slowest leak and drain onset; large Empty-cell columns during drains; far-reaching early front; reservoir stall from tick 600 | Desktop host dam owner tick 4.6 → 4.2 ms at 60 Hz; quiet 0.03 ms | Stall and void appearance need owner review |

## Answers to the #360 questions

1. **Selectable and playable in the normal app?** Yes. The launcher route
   rebuilds all four families through Main's owner on a real native World.
   The regression exercises each family, capture, the radius-2 refusal and a
   fresh-owner worker change.
2. **Equivalent, repeatable comparison?** Yes for the registered fixtures:
   identical fixtures, zero-delta normalization and matched radius 3. Worker
   and cross-OS hashes are identical.
3. **One versus four workers?** Physical state is identical. Configured four
   observed four claimants. The dam's FM/CY tick time fell (preflight); PF
   did not.
4. **Which profiles exercise several workers?** Dam, leak and drain on most
   ticks. The two-limb and quiet pool only while settling, except PF, which
   is busy on every tick.
5. **CPU, memory and pacing overhead?** In the real desktop host, FM, CY and IN
   all sustain the 60 Hz owner with frames held at vsync. PF reference reaches
   only 24–39 native ticks/s, with an owner tick of 24–41 ms, even at rest.
   Process RSS (preflight) was highest for PF, then IN. A solver-only memory
   census and heap profile are not measured.
6. **Inertial Water during leakage and bottom draining?** It is the slowest
   to drain. It shows Empty-cell columns of up to 193 cells, and retained
   lateral motion up to |vx| 26 (16 quanta per cell). There is no gas, and no
   upward ballistic motion: zero negative `vy` in every census.
7. **PF and IN versus the original models?** PF transmits head and releases
   faster, at a high fixed cost. IN moves far fewer cells, voids more, and can
   stall a reservoir.
8. **Contact, conservation and lifecycle guarantees preserved?**
   - Conservation, boundaries, refusal retention and owner retirement hold in
     every registered row.
   - The PLAY UI007, LIFE007 and LIFE008 regressions and the existing liquid
     host and UI regressions pass locally on Windows.
   - Contact is not exercised (slot 7 gap).
9. **Physically unqualified or future-dependent?**
   - Rapier impact and splash (#362).
   - Directed-momentum nozzles and reversible openings (#361).
   - Sealed-gas resistance, PF settling, and the IN stall.
   - Long-horizon cost, browser execution and GitHub-hosted exact-head gates.
10. **Owner assessment still needed?** The whole [playtest sheet](../operations/lcb-feel-comparison-route.md#owner-playtest-sheet--untested)
    is UNTESTED.

## Successor handovers

- **#361 IN-TOOLS** can consume:
  - the leak and drain capsules and their generator;
  - the drain/leak baselines above, especially IN's slow onset and voids;
  - the route's capture schema;
  - the stream baseline (no directed-momentum inlet exists);
  - the open-only limitation: scheduled events cannot place Wall, so
    reversible openings need a tool.
- **#362 WATER-CONTACT** can consume:
  - the controlled-route gap record for slot 7;
  - the probe's submerged-void classification, including PF gas labels;
  - the Exploratory route through the same panel;
  - the parity and census tooling.
  - Contact baselines were not measured here.
- **Native owner (handover, unchanged here):** `diagnostic_snapshot` increments a
  132-entry per-material array indexed by the stored byte. This is unreachable
  while native writes validate material IDs, but an unadmitted byte would index
  out of bounds. Bound Water on a combined #358 material union also still needs
  a carrier readback wired by its integrator; see the
  [observer census record](2026-11-04-lcb360-observer-census.md).
- **#363 LCB-DECIDE** can consume:
  - this report, both packets and the preflight;
  - the IN stall and PF never-rest findings, routed for decision;
  - the UNTESTED feel sheet.
  - Nothing here selects a default.

## Limits

- Native-only campaign: no Rapier bodies, and slot 7 is unexecuted.
- Campaign timings are overlapped and excluded.
- The host cohort ran on one Windows machine; no Linux graphical cohort was run.
- Documentation retrieval: the frozen set is unchanged (19 top-1, 32/32 top-5,
  MRR 0.7536). The challenge set moved from 123 to 122 top-1, and MRR from
  0.8696 to 0.8659:
  - ACT14 went from rank 1 to 2 through a corpus IDF shift;
  - PLAY-UI007-01 went from rank 2 to 3, because the new route guide ranks second;
  - LCB05 improved from rank 4 to 3.

  These deltas are disclosed rather than tuned away.
- The "submerged Empty" column metric counts every Empty cell below any stored
  Water in a column, so a film or droplet can inflate it. A connected-region
  classifier is being added separately.
- Both OS legs ran locally on one machine; this is not GitHub-hosted CI.
- Horizons end at each fixture's registration and are not extended.
- `host_eligible_for_full_matched_evidence` stays `false`.
- Heap-allocation profiles and per-worker utilization are not measured.
