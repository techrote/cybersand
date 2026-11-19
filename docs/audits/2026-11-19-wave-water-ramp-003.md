---
title: Horizontal Water spread and returning crests on the owner ramp
status: Current
document-kind: audit
scope: Water ramp and tank measurements, player defaults, evaluated runtime and platform qualifications on the branch above PR 676
last-reviewed: 2026-11-19
related-documents: [../architecture/wave-flow-v1.md, ../operations/workbench-water-lab.md, 2026-11-19-wave-waterwall-002.md]
---

# Water ramp, 19 November 2026

The owner selected Wave Flow, waterfall spill and ballistic release for new player sessions. The parent for this evaluation is [Waterwall 002](https://github.com/techrote/cybersand/pull/676) at `57de8e73f93f10e63761b7e8d2430ddafcb970cb`. Its recommended Sloshy + Max over-ledge bundle is the comparison setting.

## Authored ramp

The supplied file is an ordinary 2,048 × 2,048 Workbench setup v2 with 635 rectangle edits and no actors or sources. Its SHA-256 is `7aba8a47c926cc1911bc4ee519179c595b686692d5c78db8f103b8b62d311acb`. Two suspended bodies start with 9,773,895 units of Water in 38,329 cells. The lower body ends at x738 above a long shallow trough that first rises and then falls. The parent Windows Workbench loaded the named setup through its ordinary Load action and conserved the initial quantity at ticks 0, 100, 300 and 600.

## Protected native source review

| File | Change | Before LF SHA-256 | After LF SHA-256 | Source-first commit |
|---|---|---|---|---|
| native/src/world_pressure.inc | Hash Floor gain only when nonzero in Wave physical identity. Pressure transport and material definitions use their existing paths. | `0e012c7f2944cf8d5f9d8aa383e8635bbbd313d26fc5079160a02d5f4e1e3a0f` | `fca639dfbf6274c590fb38283207aa838d6aa659e3ed0e95b397f6a7d8ab5be1` | `1604b66b19705d79d2704e5119a25823caee0973` |

## Why the flat-floor law changed

Raising ordinary Gain to 256, Deep gain to 48 and running two rounds doubled front speed but produced tall, persistent strips of Water on the actual ramp. At x706 the initial Water occupied y98–371. At tick 100 the native grid occupied all 469 rows from y1–469, with total Water still exactly conserved. The first Windows build of that setting and the parent started from the identical material-ID plane (SHA-256 `b0d7981527cf86c8e744af20d5185ed6f66354248c76950c908086eb1ae84e7d`). The same narrow columns appeared in submitted framebuffer captures and in independent native-ID samples. This ruled out using high ordinary Gain as the gameplay default.

The owner then asked for faster initial motion on flat ground and less uphill climbing. The chosen approach couples a shallow front to the **actual solid floor beneath it**. Across a horizontal face, both columns must have a floor at the same height, within three rows, with full Water in any intervening cells. Paused or unsolved terrain, bodies, drops and steps supply no extra floor acceleration. The pressure difference used for the extra impulse is capped at one full cell. Ordinary donor, two-face receiver, overfill, wall and ballistic budgets cap the full transfer. Floor gain zero restores the earlier law, including its thin-film leveling. This adds no pass, allocation, parcel, persistent cell state or new scheduler work. Stronger bulk motion on flat ground comes from the existing retained horizontal flux.

The one-row experiment reached x57 beyond the starting block at tick 64, versus x61 for the three-row approach with the same 512 feed-head limit. When weighted by the quantity of Water moving outward, travel rose from 16.59 to 21.78 cells. Both climbed 20 cells on the matched 1:2 grade. A smaller feed-head limit further reduced run-up. The native grid still allows ordinary pressure-driven movement and real impact run-up.

## Gameplay settings and comparison

The gameplay profile runs two rounds with Gain 32, Deep gain 32, Floor gain 1024, flux smoothing 16, Coast 32, Empty pour shift 2 and spill draw head 255. Damping shift is 16, calm damping shift 8, Calm and Stick 128, and sleep after 90. The spill sheet rate is 64 with four coyote ticks, fall 8, draw 127 and a 128-parcel launch budget. Blobs and generic Ballistic Water are enabled. Water Lab can stage this whole profile with **Gameplay default**. Raw fixtures retain zero floor gain and the established Water-law options.

The comparison uses the ordinary named Workbench setup, a 32 × 32 Water block on a horizontal floor, the same block dropped from 32 cells, and a 1:2 uphill grade. The flat-front probe requires eight contiguous floor columns with at least one full cell's worth of Water in each column. The authored ramp uses two full cells of depth for its front. The uphill probe also measures how much Water actually crosses a given elevation, independently of particles. On the authored ramp, the reported height at the far wall is relative to the contemporaneous basin waterline, since faster delivery raises the whole pool.

The returning tank wave keeps the same initial height, so a deeper trough or steeper face reflects the dynamics rather than extra starting Water. The gains in crest-to-trough depth are small. [Tank returns, column profiles and flat-floor blob](wave-water-ramp-003-2026-11-19/tank-comparison.md)

## Compatibility and scope

The default selection lives in the GDExtension's `CyberNativeCellWorld::select_gameplay_water`. Fresh desktop sandbox, Workbench and ordinary curated Web demos share it. An authored alternate liquid law or explicitly selected comparison fixture keeps its own solver. The ordinary v2 canvas stores no Wave toggle. A new session loading a plain carrier canvas uses the fresh setting. Wave still refuses a full physical-state save. The Web demo's FreeMass setting supports the CYSD1 Save operation. Loading an existing CYSD1 slot reconstructs that slot's original law. Web controller tests on Windows do not qualify a WebAssembly browser build.

The independent review caught a legacy Web/Rapier test trying to save an active Wave World. The corrected case tests the Wave refusal and exercises a moving-body FreeMass save/restore. It also identified historical capture modes inheriting new settings. The comparison driver now explicitly stages the original Wave and spill controls before applying any named historical bundle. The previous Windows package supplies an independent baseline. The four-chunk-corner native test includes shallow sheets, a real ascending step, paused floor, a partial two-sided donor and a legal 65,535-unit donor. Its original narrow observation box excluded Water rising inside an overfilled column. The regression now uses a box that contains the entire column.

## Measured results

| Fixture and six-worker metric | Previous Sloshy + Max, one round | Selected gameplay profile, two rounds |
|---|---:|---:|
| Level floor, contiguous front beyond the starting block at ticks 8 / 16 / 32 / 64 | 4 / 6 / 16 / 24 cells | 8 / 16 / 31 / 61 cells |
| Flat-floor travel weighted by all initial Water at t64 | 4.80 cells | 15.52 cells |
| Drop from 32 cells, bulk front at t8 / 16 / 32 / 64 | 3 / 5 / 15 / 25 cells | 7 / 14 / 29 / 59 cells |
| 1:2 grade, highest bulk run-up in 400 ticks | 24 cells | 19 cells |
| Average of initial Water at least 16 cells up that grade | 1.88% | 0.35% |
| Authored ramp, 128 full-cell equivalents on the floor beyond x960 | 728 ticks | 416 ticks |
| Authored far bank, peak height above contemporaneous basin surface | 10.4 cells | 8.0 cells |
| 22+10-row tank, first full crest return | 388 ticks | 138 ticks |
| 22+10-row tank, broad slope at first return | 0.516 | 0.583 |
| 22+10-row tank, crest-to-trough range at first return | 8.47 cells | 8.55 cells |

At two rounds, the previous Sloshy tuning reaches 37 cells on the flat at tick 64 and the bank rises 22.8 cells above the basin waterline. The new law improves those two measures at the same number of rounds. The basin fills earlier, so the absolute water level against the wall can be higher than with one-round Sloshy. The reduced climb is measured relative to the waterline and in the matched incline fixture.

Two sequential six-worker 900-tick native runs on the owner's Ryzen 5 5600X gave median / p95 times of **4.114 / 9.304 ms and 3.576 / 6.221 ms**. The one-round parent measured 1.837 / 3.134 and 2.652 / 5.237 ms. Two-round Sloshy measured 4.342 / 11.143 and 3.555 / 6.041 ms. Run order was reversed between replicates. The only background Workbench was the owner's preexisting session, lightly active. The new profile's slowest individual ticks exceeded the 16.67 ms interval of a 60 Hz simulation. Timings cover native ticks, excluding rendering and Rapier. One-round gameplay tuning measured 1.893 / 3.253 and 2.005 / 3.724 ms.
