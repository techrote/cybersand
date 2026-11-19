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
