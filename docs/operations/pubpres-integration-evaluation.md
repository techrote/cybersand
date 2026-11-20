---
title: Workbench publication and progression evaluation
status: Current
document-kind: guide
scope: PUBPRES-INTEGRATION-001 draft desktop candidate, operation and evidence boundaries
canonical-for: [pubpres-integration-evaluation]
last-reviewed: 2026-11-20
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../architecture/simulation-tick-and-threading.md, ../architecture/data-ownership-and-lifetimes.md, ../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md, github-development-and-release.md]
---

# Workbench publication and progression evaluation

**Draft/HOLD.** PUBPRES-INTEGRATION-001 branches from accepted `de109d0131641d6adc8d25bb9ced7ca3d4991105` (tree `ecca857905825ce6c478952eb0a1ad3902569007`). That is the Wave Waterwall merge. The evaluation joins one native/physics handoff, one material publisher and one presentation decision. Gameplay acceptance and promotion require the matched campaign and owner review.

## Design choices

| Source | Candidate use | Scope left in donor |
| --- | --- | --- |
| [#609](https://github.com/techrote/cybersand/pull/609) `5a36ce49404ed7dc8a9e5815593d250ab990615a` | Camera, mask-checked actors, Engine Lab, two-target texture staging and value-only physics mailbox | Custom Windows EGL engine, Separate rendering launch default, and historical packaging and workflows |
| [#628](https://github.com/techrote/cybersand/pull/628) `e8818048391e1560aaa973392e0de655b6dd46c4` | Bounded observed pose timeline, elapsed receipt checks, current-origin holds, paced recovery and measured material age | Duplicate renderer, runner and raw texture identity as a pose certificate |
| [#651](https://github.com/techrote/cybersand/pull/651) `839f70ff8cf2d6dd7466580e31ed897a4b6e3983` | Registered dense/sparse transition schedule and negative evidence | Second hybrid publisher and pending CPU compaction cache |
| [#335](https://github.com/techrote/cybersand/pull/335) and [#345](https://github.com/techrote/cybersand/pull/345) | One complete retained baseline outside dirty limits, adapted for real Workbench extents and clipped native RG8 patches | Older publication ancestry and fixed 1024-only packet checks |

#566 (`214de85adef2`), #593 (`9628729af052`) and #606 (`2632422aa67e`) are inherited through #609. The candidate uses the stock pinned Godot 4.7 engine, accepted native and Rapier binary inputs, and Safe rendering. The explicit candidate launcher selects `blit`, `early`, `coherent` and `measured` through `CYBERSAND_MATERIAL_PUBLICATION`, `CYBERSAND_DIAG_PHYSICS_PUBLICATION`, `CYBERSAND_DIAG_PRESENTATION` and `CYBERSAND_DIAG_MATERIAL_TIMING`. The same-source comparison uses full, combined, legacy and legacy timing. Default launches without treatment settings use the comparison policies. The strict sample fence and manual Rapier fixed step apply to both arms. The optional donor wait modes are outside the candidate campaign.

## Owners and lifetime

```mermaid
flowchart LR
    World[Native World and phased pool] --> Owner[Exclusive desktop worker]
    Owner --> Receipt[Immutable physics and terrain receipt]
    Owner --> Material[Immutable material packet]
    Receipt --> Rapier[Main-thread fixed-step Rapier]
    Rapier -->|Copied sample| Owner
    Material --> Upload[Main-thread material publisher]
    Upload -->|Accepted serial| Owner
    Rapier --> Decision[Main-thread presentation decision]
    Upload --> Decision
    Decision --> View[Actor, terrain, effects, Follow camera and picking]
```

Before publishing either receipt the worker performs all fallible native reads and checks World health. The early mailbox can overlap immutable GDScript payload packing. It grants no material authority. Collider packets follow native source identity, body epoch and hard-surface revision. Material-only refresh requests leave that cache eligible. Rapier gates on exact feedback and complete terrain. The Main callback may drain a pending terrain installation with an additional 32-chunk, 1 ms allowance before material upload.

The worker holds one exact full frame plus the existing maximum of 256 dirty records and twice the larger of the finite default area or Workbench area in dirty bytes. It checks the cap before appending, keeps recovery pending until a complete replacement is acquired, and ignores ACKs beyond the last handed-off serial. Stale ACKs cannot release later bytes. A native packet may retain padding or clipped halo bytes and those bytes count toward the cap.

A complete native packet arrives detached from World and exchange storage. The worker retains that immutable byte array as both the full baseline and the publication while it contains only the baseline. The first unacknowledged delta copies the baseline into a writable journal before appending. Later snapshots copy the accumulated journal for publication. This keeps older snapshots valid through ACKs, refreshes and appended deltas. The trace records the first native capture status and total time inside native capture, including a retry when required. The existing exchange interval also covers worker retention.

The blit publisher rotates two persistent linear RGBA8 texture targets. It takes a large, entirely dirty image directly through bounded staging and avoids extracting every tile before the whole copy. When a dense publication invalidates all slots in the recycled plane and the incoming edit touches at most four tiles, it copies the complete accepted GPU plane to the recycled target and stages only those tiles. It never reads from the target it is writing. The two drawable identities and preceding frame remain intact. Small or partial areas normally take the tile path. Neither path swaps texture representations when density changes. Queued `Image` inputs have a distinct immutable lifetime. The stage ring offers reuse distance. A submission receipt establishes queued work and ACK authority. It supplies no completion or scanout timestamp.

At 128 or more logical tiles, the copy-and-patch transition has its own preallocated one-tile and four-tile staging rings. Each ring uses the same slot limit as ordinary staging and independent textures, samplers and cursors. At 2048² RG8 with three slots the additional GPU texture payload is 491,520 bytes. Setup warms and accounts for those resources. This keeps the transition's staging reuse independent of later ordinary sparse updates.

The coherent controller uses copied Rapier observations with actual completed step timestamps. Historical endpoints need qualified receipts and bounded age. A currently paused step can remain current. A previously current pose may hold briefly while continuously visible and certified against every contributing material texture. After withholding, re-entry requires a fresh endpoint check. Workbench paint and actor selection use the last submitted camera mapping.

## Evidence boundaries

- [#651 graphical qualification](https://github.com/techrote/cybersand/actions/runs/43854022451) retained 60 repeated full-plane seeds and an unresolved transition regression. Production stages and the installed `transition_2048_w1` case must be measured independently of that donor.
- [#609 exact-head application gate](https://github.com/techrote/cybersand/actions/runs/43987453993) passed scoped correctness but retained adverse Windows Follow p95 and maxima. The recorded maxima were 335.063 to 390.963 ms and 248.674 to 460.038 ms. The worst spans included terrain holds and long callback intervals.
- [#628 exact-head application gate](https://github.com/techrote/cybersand/actions/runs/44440448157) passed the corrected history controls on the donor source. [The previous exact-head attempt](https://github.com/techrote/cybersand/actions/runs/44438101082) retains its current-origin hold failure.
- [#456](https://github.com/techrote/cybersand/pull/456) observed predominantly off-CPU `space_step` wall time on the calling thread. A new wall-only trace cannot distinguish Rapier waits, descheduling and its background work. [#449](https://github.com/techrote/cybersand/pull/449) provides the earlier stage comparison.
- The accepted-main defect was reproduced on Windows with stock Godot and the accepted native DLL. Two separate two-byte changes forced two full replacements on each of 1024×1024, 2048×1024 and 2048×2048, even when the second edit followed ACK of the original baseline.
- [Hosted Windows evidence at `5f0681c8`](https://github.com/techrote/cybersand/actions/runs/44655894455/artifacts/14593754055) includes a transition regression on software ANGLE. Frame p95 in A–B–B–A order was 14.122, 42.350, 42.184 and 13.928 ms. In 29 of 30 candidate cycles, the first ordinary reuse of the staging resource used by the history-copy transition coincided with a roughly 38 ms upload-call stall. The separate rings address that observed reuse path.
- On the NVIDIA TITAN RTX at `5f0681c8`, all Wave Flow Follow arms produced a complete 8 MiB native packet on ticks 1–19 despite prompt ACKs. In the longest candidate physical gap of 83.342 ms, native tick wall time was 54.567 ms, render exchange was 8.719 ms and the completed Rapier call was 0.256 ms. This evidence locates the delay before physics admission and leaves the native tick's CPU versus wait split unresolved.

Keep per-arm source and runtime hashes, renderer identity, workload hash, native and actual Rapier receipts, raw frame traces and rejected arms together. `transition_2048_w1` uses synthetic timed edits through Main to isolate the publisher. The Free/Follow workloads launch real native Worlds and Needle instances. Future gameplay timing uses a dedicated Wave Flow cohort with the same authored World and Needle tape. It requires a native construction receipt for the effective `wave_flow_v1` solver and observes completed Wave rounds and task participation. FreeMass remains a matched control, and PressureFlow is a separate workload. Software-hosted and local NVIDIA timing have distinct evidence scopes. The comparison arm is an isolated treatment on integration source. Accepted `main` is a separate source comparison.

## Focused Windows WARP transition comparison

The [focused workflow](../../.github/workflows/pubpres-warp-transition.yml) takes its runtime and project from the [retained Windows evaluation artifact](https://github.com/techrote/cybersand/actions/runs/44706204266/artifacts/14616761210) at `8503ec19e4d6`. It verifies the package, then uses an isolated project copy with a recorded test overlay that can bypass the history copy at sparse re-entry. The ordinary publication policy and installed launchers are outside the overlay.

On one Windows host the workflow requires ANGLE on the actual Microsoft Basic Render Driver. It runs the unchanged uncapped `transition_2048_w1` fixture in fresh processes. The four comparison arms use blit publication in clone, compact full, compact full and clone order. Two full-only references bookend that comparison. A separate untimed replay for each treatment compares both complete RG8 texture histories against independently advanced expected images after every measured admission. The workflow keeps individual run receipts and reports frame intervals, accepted cadence and publication wall time, including the ordinary frames following sparse re-entry. A valid capture establishes the scope for evaluating recovery. This fixture contains no active native World or Rapier progression.
