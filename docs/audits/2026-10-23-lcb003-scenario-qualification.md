---
title: LCB-003 scenario catalogue v1 qualification
status: Current
document-kind: evidence
scope: Dated execution evidence for the LCB scenario catalogue v1 on unchanged Current native liquids — 27 controlled scenarios at 1 and 4 workers, regressions, negative contracts, PR #215 fixture reproduction and Linux CI cross-check; measured, blocked and failed cases kept separate
canonical-for: [lcb-003-scenario-qualification-evidence]
last-reviewed: 2026-10-23
related-documents: [../operations/lcb-scenario-catalogue.md, ../operations/lcb-water-comparison-and-fixtures.md, 2026-10-23-lcb000-gates-cde-design-evidence.md]
---

# LCB-003 scenario catalogue v1 qualification

## Summary

| Class | Count | Meaning |
|---|---:|---|
| **Measured** | 27 scenarios / 27 Current-default arms | completed at 1 and 4 workers with identical observations and checkpoint hashes |
| of which characterization-only | 1 | `lcb.head.sealed-two-limb.v1`: `measured_not_a_sealed_control` (no gas state in Current) |
| **Blocked** | 83 arms | need #200, #201 and/or #212; each lists `depends_on` |
| **Proposed** | 7 arms | PR #215 mixed-fixture arms (M1, M2, M2b proposed; M1-alt proposed alternate) |
| **Failed** | 0 | no campaign case refused, faulted or hit a fail condition |

- **No native physics, Cell layout, scheduler or solver semantics changed.**
- **No non-default solver family executed.** Every mixed scenario ran two
  families: Water `freemass_v1` and `cellular_yield_v1` for the other liquids.
- **LCB-000 remains NOT PASS.**

## Identities

- **Apparatus commit:** `a6bde31a06ec4331513d22e3548d4fd682287225` on
  `claude/lcb003-scenario-qualification`, stacked on PR #215 head `6fc0e25`.
  Main is `4caa2c3`, which differs from `9012425` only by a MAT-003 workflow
  file. The definitions, runner and helper used by the campaign are unchanged
  in this PR.
- **Runtime:** Godot `4.7.stable.official.5b4e0cb0f`; Windows GDExtension
  SHA-256 `e6d9ec7d0847287c4c6b1acaffd52dc2807fe43e9dccfc36123ffa117fb6045f`.
  The PR #215 record shows it native-source-matched to main. The runtime
  `script_set_sha256` is `c5e6ab4f…3559`.
- **Platform:** Windows 11 Pro 10.0.26300 workstation; native-only headless.
- **Reduced controls:**
  [`lcb-scenario-controls-2026-10-23.json`](../reference/lcb-scenario-controls-2026-10-23.json)
  (SHA-256 `989ff70dba646285991a2a5e8ca5c3b0aa94b9381dc44c849528518e4238fac1`).
  It holds the per-case report SHA-256s of the raw w1/w4 outputs. The raw
  outputs themselves are not committed.

## Campaign

**Command:**
`Godot_v4.7-stable_win64_console.exe --headless --path godot --script res://tests/run_lcb_scenario_suite.gd -- --list=<27 absolute paths> --workers={1,4} --output-dir=<dir> --source-sha=a6bde31…`

- **Timeout:** 3000 s per pass.
- **Wall time:** 254 s (w1) and 160 s (w4).
- **Result:** 54/54 `completed`.

**Reduction:** `python tools/lcb/lcb_registry.py reduce …` reported
problems `[]`.

| Scenario | 1/4 parity | Outcome | Ledger | Last active tick | Final content / state hash |
|---|---|---|---|---:|---|
| `dam.water.freemass.reference.v1` (protected) | identical | complete | closed | 1800 | `163e4c93b98320a8` / `140af7ed71e7d2e5` |
| `mixed.water-oil-brine.v1` (protected, M0) | identical | complete | open by declared reaction | 900 | `d43b52e8bbaf9176` / `7bdf182aa1cecd70` |
| `dam.water.freemass.depth-48.v1` | identical | complete | closed | 1800 | `8c539beb32ab8efc` / `1dd8559bcec14ad2` |
| `dam.water.freemass.depth-96.v1` | identical | complete | closed | 1800 | `455020c5acd94dff` / `8fb1007492b1c54b` |
| `dam.water.freemass.depth-160.v1` | identical | complete | closed | 1800 | `163e4c93b98320a8` / `140af7ed71e7d2e5` |
| `shallow.stream-steps.v1` | identical | no condition | closed | 1800 | `11a60a508ae79c0c` / `e8b6d4c9dd4e9bdc` |
| `shallow.ledge-sheet-fall.v1` | identical | complete | closed | 900 | `29b3a7e23df6a521` / `9376277d5c4bf5af` |
| `shallow.obstacle-run.v1` | identical | complete | closed | 1800 | `91b8bb27acab4e29` / `29e5586437032f18` |
| `head.vented-two-limb.v1` | identical | complete | closed | 2400 | `c0a255ed9e65a9d3` / `eb995071ea910de` |
| `head.narrow-passage.v1` | identical | complete | closed | 2400 | `c1d888eb7ed0fb2b` / `88002d7389a16dde` |
| `head.sealed-two-limb.v1` | identical | complete | closed | 2400 | `794c96c49b59432b` / `b8ce0f5f5c3b789` |
| `rest.deep-quiet-pool.v1` | identical | complete | closed | 600 | `5dd5b765a0d282cb` / `2eb51468a34e0d3f` |
| `rest.remote-disturbance.v1` | identical | complete | closed | 1200 | `e9930caf3820194e` / `386705f7f59dc34a` |
| `rest.two-pool-partial-activity.v1` | identical | complete | closed | 600 | `dc6d61d27327dd07` / `7baf676072f7fa60` |
| `viscous.lane-gallery.v1` | identical | no condition | closed | 1200 | `875ba407168dc3ba` / `95be37dd05292a59` |
| `viscous.pour-heaps.v1` | identical | no condition | closed | 900 | `f103b21103be2535` / `8e1a93f08a2cdb04` |
| `density.inverted-column.v1` | identical | no condition | closed | 1800 | `e2c5b783b881302b` / `5bf5561f9fd7f77c` |
| `density.mercury-drop.v1` | identical | complete | closed | 600 | `7322b48768ee9b9e` / `1ecbaef020582a0d` |
| `density.water-brine-lock-exchange.v1` | identical | complete | closed | 1200 | `be937095c9ad4075` / `94c7b35c6bfd1076` |
| `density.oil-water-lock-exchange.v1` | identical | complete | closed | 1200 | `f6c0e1cc31e5e10` / `d68ce72d0afd7ddf` |
| `granular.water-sand-baseline.v1` | identical | complete | closed | 1800 | `76e4cd11b76f2210` / `e2a99d509bb4a6f1` |
| `granular.water-sand-erosion.v1` | identical | complete | closed | 1800 | `885cfc4929077688` / `efbb3c1ae63e4c62` |
| `granular.salt-dissolution.v1` | identical | no condition | open by declared reaction | 1200 | `99c20835768e25e5` / `5c89b04223470b89` |
| `mixed.repeated-openings.v1` | identical | complete | closed | 1500 | `c95ec2ee77799747` / `c037e740a66e8c44` |
| `mixed.sodium-oil-fire.v1` | identical | no condition | open by declared reaction | 900 | `e2d07aa293977a71` / `b1d520887d7e36ea` |
| `seam.dam-on-chunk-seams.v1` | identical | complete | closed | 1800 | `1b948551e6ab7eec` / `6f6facb815c2171a` |
| `seam.world-boundary.v1` | identical | complete | closed | 1800 | `804bc60d07c429c1` / `154f7b2f10ecacb3` |

- **"Ledger closed"** means the final world Water equals the initial amount
  plus explicit scheduled sources minus explicit sinks.
- **"No condition"** means that scenario preregistered observations only.

## What the Current controls show

These are characterizations of Current behaviour, not acceptance.

- **Dam depth ladder.**
  - **Release barely depends on depth.** Retained reservoir fraction at tick
    1800 is 0.839 (48 rows), 0.841 (96) and 0.851 (160).
  - **The front is slow at every depth.** It reaches only the second
    124-cell band by tick 1200, and band 1 holds 119,713 / 276,496 / 460,855
    units at tick 240.
  - This matches the WEX deep-release deficit: depth above saturated outlet
    cells adds almost no drive.
  - **depth-160 reproduces the protected reference exactly** (same final
    hashes and the same reservoir values).
- **Communicating heads.**
  - In the vented two-limb, the 2-row narrow passage and the roofed geometry,
    **zero cells moved in 2400 ticks**. The limb level difference stays 120.0
    rows.
  - Current pairwise Water cannot push mass up the low limb through a fully
    saturated passage.
  - The roofed result is labelled not a sealed control.
- **Rest and wake.**
  - **Deep quiet pool:** the content hash is constant from tick 0 and no cell
    moves. However, `active_chunks` falls from 40 to 18 and stays at 18
    through tick 600, so activity counters did not reach zero within the
    horizon. This is useful input for #201 dormancy, not a defect claim.
  - **Remote disturbance:** the ledger closes. The total is +16,320 at tick
    900 (before the sink) and returns exactly to the initial amount by tick
    1200.
  - **Two pools:** pool B is unchanged (17,952,000), and pool A gains exactly
    16,320.
- **Viscous lanes.** Runout fraction at tick 1200 orders as Brine 0.486 >
  Water 0.414 (mass-weighted) > Mercury 0.395 > Oil 0.354 > Slush 0.253 >
  Paste 0.204. In pour-heaps only Paste keeps cells above the low band (61);
  Slush, Oil, Brine and Mercury flatten.
- **Density.**
  - **Inverted column:** sorted by tick 600, with Oil top 4070 and Brine
    bottom 4091, plus a residual of 26 Oil and 5 Brine cells in the middle
    third that persists to 1800.
  - **Mercury** reaches the pool bottom between ticks 120 and 600.
  - **Lock exchanges:** Water undercuts Oil and Brine undercuts Water.
    Whole-cell Oil and Brine counts are conserved (preregistered conditions).
- **Granular.** Sand band 1 drops from 5952 to 5838 cells (Baseline) and to
  5861 (Threshold erosion). On this geometry the transport profile changes the
  outcome only slightly.
- **Salt dissolution (#160 evidence).** All 2048 Salt cells became 4096
  Brine, but Water fell by 514,527 rather than 2048 × 255 = 522,240. The
  7,713-unit gap is reacting Water cells that were **not full**: whole-cell
  conversion turns partial Water mass into full Brine cells.
- **Sodium/Oil/Fire.** Sodium reacts and Fire and Steam appear, but Oil did
  not ignite (47,616 cells unchanged). World Water rises by 6,547 through
  Steam condensation. The reaction ledger is open by design.
- **Seams and boundary.** Conservation holds, and 1/4-worker hashes are
  identical with the gate on the x=384 chunk seam and with the container
  formed by the world bounds.

## Regressions

All three ran on 2026-10-23 on the same Windows runtime, with a 300 s timeout
each.

| Test | Result | Wall time |
|---|---|---:|
| `test_lcb_scenario_catalogue.gd` | 27 scenarios, 523 assertions, 0 failures | 32 s |
| `test_lcb_negative_contracts.gd` | 74 assertions, 0 failures | 4 s |
| `test_lcb_fixture_manifests.gd` (PR #215) | 26 assertions, 0 failures | 2 s |

What the catalogue test checks for every scenario:
- contract admission and canonical hash;
- the Python-derived material inventory and Water quantity against native
  tick 0;
- the tick-30 content/state/Water goldens;
- 1/4-worker prefix equality;
- that each arm's status agrees with its `executable_today` flag.

## Linux cross-check

PR #215's ready-state GDExtension run **39875771737** ran
`test_lcb_fixture_manifests` on GitHub-hosted Linux (shard 3, source-built
runtime): 26 assertions, 0 failures. The same test also passed on Windows
headless in that run.
- **What that proves:** the Windows-measured Dam Break and mixed-fixture
  goldens (tick-30/60 observations, Salt ledger, 1/4 parity) reproduce on
  Linux.
- **What is still pending:** the new catalogue and negative tests have not run
  on Linux yet. They run on this PR's GitHub-hosted Linux shards via workflow
  dispatch or the ready state.

## Retained process events

1. **First campaign attempt superseded.** It ran on an earlier uncommitted
   runner. Its 1-worker pass completed 27/27; the 4-worker pass was stopped
   deliberately when the runner logic moved into `lcb_scenario_runner.gd`. Its
   values are not used. The committed runner produced the campaign above.
2. **Reducer correction before publication.** The first reduction marked the
   protected mixed fixture `OPEN_UNEXPLAINED` because the reducer did not load
   protected inventories (so Salt was not recognised as reactive). The tool was
   fixed and the uncommitted controls file regenerated **from the same raw
   outputs**; no physics value changed.
3. **Authoring refusals.** Generation assertions refused several drafts for
   exceeding the 1024² observation-area budget, before any execution. Regions
   were tightened without seeing results.

## Gaps

- **Platforms and coverage:**
  - Windows local only for the long-horizon campaign.
  - No Web, packaged-build, Rapier/player or rendered execution.
  - The native-only runner refuses player- or body-enabled definitions.
- **Timing:** characterization only (in the controls file). Official timing is
  #203's.
- **Not yet available:**
  - flow-front and occupied-extent metrics (bands are used);
  - per-family state observations;
  - negative coordinates in the MicroScenario frame.
- **Blocked:**
  - the NC-1/2/3/4/5/6/8/9/10 family and UI contracts (see the
    [catalogue](../operations/lcb-scenario-catalogue.md#negative-contracts));
  - three-family execution;
  - LCB-000 PASS. At writing, Gates A and B lacked accepted evidence.

## Addendum — CI and gate status (2026-10-23, later)

- **Gate status.** Main now records Gate A PASS and Gate B bounded PASS
  ([refresh](2026-10-23-lcb000-admission-gatea-gateb-refresh.md)). Gates C–E
  are still under review, so LCB-000 remains NOT PASS.
- **Dispatched GDExtension run 39879178132 at `91f093a`.**
  - All three LCB tests passed on Windows CI: fixture manifests 26/0,
    negative contracts 74/0, catalogue 523/0.
  - Negative contracts also passed on Linux (74/0).
  - The run failed on two **timeouts in untouched physical-actor tests**:
    Linux shard 1 `test_physical_usable_course` (180 s), and Windows
    `test_physical_actor_arena` (180 s). Both passed in PR #215's run
    39875771737.
  - The aggregate `linux x86_64` gate failed as a consequence.
- **Next step.** The run is retained as a failure, not counted as green. A
  fresh dispatch at the updated head requalifies it.
