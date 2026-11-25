---
title: Troubleshooting simulation and integration
status: Current
document-kind: guide
scope: Symptom routing and discriminating checks; fixes require a separate implementation checkpoint
canonical-for: [symptom-routing]
last-reviewed: 2026-11-24
related-documents: [../reference/status-and-roadmap.md, testing-validation-and-replay.md, profiling-observability-and-performance.md]
---

# Troubleshooting simulation and integration

## First launch and ordinary Workbench problems

Start with a small repeatable case. Record the actual checkout or evaluator
identity, then choose the matching symptom below. A portable evaluator, a source
checkout and an experimental package can have different launchers and content.
The [first-launch guide](getting-started.md) distinguishes those paths.

| Symptom | What to check first | Safe next step |
|---|---|---|
| Launcher rejects Godot or a native library | Exact Godot version and selected runtime identity; a Git LFS pointer is text, not a library | Follow [source/runtime checks](local-build-and-validation.md). Materialize and verify the required inputs before launch; do not substitute a nearby engine version or relabel a stale binary. |
| Project opens but a feature or native class is missing | Source, native runtime and complete package contents; normal startup is the feature launcher | Follow the matching [getting-started route](getting-started.md). A script-only import cannot implement a missing native method. |
| Drawing is pending, Save is refused, or Stop leaves a partial edit | Native completion receipt, active/pending gesture and history state | Stop or wait as the UI instructs, inspect the actual result and use the supported recovery/Undo path. Queue admission is not completed drawing. See [painting and history](workbench-painting-and-history.md). |
| Generated scene is refused or a large import will not install | Native admission result, format, extent and host claim; preview completion versus World installation | Keep the existing World and reduce or correct the authored request. Do not infer success from a preview or silently raise native limits. See [generator walkthrough](architectural-generator-playtest.md). |
| A saved scene reopens with different motion or reactions | Which format was saved and which fields it contains | Ordinary Workbench Save preserves the authored start. Flatten stores material IDs and retires old authoring history; it is not exact physical continuation. See [saving](workbench-saving.md). |
| Native owner has failed but the authored setup is valuable | Failed World status versus settled authored document | Save the settled authored start if its edit fences permit it, then restart and Load that start. This does not capture or resume the failed physical state. See [saving](workbench-saving.md). |
| Art cannot reach a model/provider | Selected provider, endpoint/model, availability, response/error and credentials entered locally | Use [Art setup and errors](workbench-art.md). An offline documentation check needs no provider request. Keep credentials and full request/response traffic out of bug reports. |
| Hiding Art did not cancel work, or reopening the game did not restore chat | Hide versus Stop, application-session lifetime and native receipt state | Follow [Art lifecycle](workbench-art.md). Accepted session-only logging does not restore a previous game session's conversation. |
| Actor controls appear ineffective | The active control mode, current selected actor and input focus; accepted actor versus a later candidate | Use [actor composition](workbench-actor-composition.md) and its source-defined controls. A moving camera or HUD counter is not proof of physical progression. |
| Extracted evaluator misses files | Complete archive, manifest and launcher supplied with that evaluator | Extract into a fresh directory and retain its files together. The [current state register](../reference/status-and-roadmap.md) distinguishes accepted features from an unmerged evaluator or repair. |

## Establish the failing path first

Record source/runtime identity, native versus GDScript fallback, desktop versus
Web, profile, worker count and first failing tick. Use
[build checks](local-build-and-validation.md) and the [evidence ledger](../reference/validation-evidence.md)
to distinguish a new failure from an old result. Preserve a minimal fixture before
changing behavior. A source diagnostic explains a defect; it does not approve a fix.

| Symptom | Discriminating check and canonical contract |
|---|---|
| Web drawing stalls despite pthreads | The outer callback still waits for native work; [threading](../architecture/simulation-tick-and-threading.md) distinguishes desktop ownership |
| One core dominates | Confirm backend/count, eligible jobs per phase, threshold and serial planning; [profiling](profiling-observability-and-performance.md) |
| Simulation freezes after camera returns | Check failed-world status/capacity first; phased re-entry should wake new coverage once without catch-up; [storage/re-entry contract](../systems/world-storage-and-interest-region.md) |
| Native tick fails or appears to continue | Both owners stop; World is quarantined and may contain partial mutations. Preserve diagnostics, then explicitly reset or replace; never retry the partial World; [tick failure](../architecture/simulation-tick-and-threading.md) |
| Every other falling row is Empty | Inspect source/destination update stamps and bottom-up vacancies; [materials](../systems/materials-and-rule-kernels.md) |
| Water changes while apparently settled | Compare exact mass, content hash and dirty/activity counts; full state hash advances with time; [Water](../systems/water-design.md) |
| Stable cells look dithered or shimmer | Separate render animation from authority; [appearance](../systems/material-appearance-and-rendering.md) |
| Water forms a heap | Identify native conserved mass versus discrete fallback, pressure bounds and sleep; preserve closed-basin fixture; [Water](../systems/water-design.md) |
| Smoke fails to rise through a medium | Inspect directional exchange/target traits and activity; do not make all solids permeable; [materials](../systems/materials-and-rule-kernels.md) |
| Boundary seam or worker-count divergence | Compare first divergent phase, write domain, stamps, merge effects and conserved totals in shifted/negative-coordinate fixtures; [determinism](../architecture/determinism-and-boundary-transfers.md) |
| Body tunnels, traps or deletes cells | Separate stale samples, sweep limits, terrain backlog, displacement exhaustion and backend selection; [coupling](../architecture/rigid-body-and-cellular-coupling.md) |
| Rapier class missing or body does not step | Run dependency preflight, then isolated automatic/manual fixtures; [Rapier runbook](rapier-2d-migration-runbook.md) |
| Snapshot rejected or Image expects nonzero bytes | Record serial, rectangle, offset, stride and byte count; reject/retain until full-refresh recovery; [render handoff](../architecture/rendering-and-gameplay-bridges.md) |
| Low FPS with small bridge payloads | Dirty bridge patches still end in a full RG8 GPU texture update; distinguish copy/upload/render time; [render handoff](../architecture/rendering-and-gameplay-bridges.md) |
| Capacity exhausted or steady memory grows | Inspect category/use/capacity and lazy chunk/job storage; do not infer atomic rollback or zero allocations; [capacity](configuration-and-capacity-budgets.md) |
| Identical saves diverge after load | Workbench authored formats and CYSD1 omit future-affecting state; native physical checkpoint formats have their own support/refusal contracts; [save/replay contract](../reference/level-saves-and-replay.md) |
| Unsafe Godot thread warning | Native workers call no Godot API; desktop owner only exclusive adapter/value APIs; [ownership](../architecture/data-ownership-and-lifetimes.md) |

## Preserve the failure boundary

For mass loss, divergent exact fixtures, dropped authoritative work, invalid leases
or unsafe ownership, stop the affected implementation checkpoint and retain its
inputs/logs. Do not hide the failure with clipping, silently increased capacities,
disabled collision or rewritten historical hashes. Some current failure paths are
incomplete; follow the precise contract instead of assuming the Approved invariant
is already enforced. [Roadmap](../reference/status-and-roadmap.md) names open issues.

For performance-only symptoms, measure the dominant stage and correctness on the
same fixture before tuning. More workers, reduced publication cadence or changing
the renderer cannot by themselves repair faulty sleeping, ownership or physics.

## A useful failure report

Include the source commit/tree or package identity, exact Godot/native runtime,
platform/renderer, feature and smallest reproduction steps, expected result,
actual result and the first relevant error. Say whether the failure was observed
in a native fixture, headless Godot, a rendered hosted session or a physical device.
Keep any timeout or failed attempt visible when reporting a later successful run.

Prefer a small public recipe or synthetic fixture to an owner map. Share only
relevant sanitized diagnostics; Art traffic can contain prompts, model responses,
local endpoints and private scene content. Do not attach provider credentials or
entire user-data directories. The [validation guide](testing-validation-and-replay.md)
explains isolated profiles and evidence boundaries.
