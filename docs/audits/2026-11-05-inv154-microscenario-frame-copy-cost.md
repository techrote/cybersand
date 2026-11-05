---
title: INV-004 — bounded MicroScenario per-frame copy cost discrimination
status: Current
document-kind: evidence
scope: Source-pinned Main/Workbench UI hot-path inspection and a synthetic Godot copy-cost apparatus; no production changes or measured gameplay-speed claim
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../operations/profiling-observability-and-performance.md, ../systems/material-appearance-and-rendering.md]
---

# INV-004 — MicroScenario per-frame copy cost discrimination (5 November 2026)

## Source custody and question

- Baseline accepted main: `ba9cbc89029be88b812af59b19e5c59829bbcd90`, merged at 2026-11-05 02:00:57 UTC.
- `godot/scripts/main.gd` baseline blob: `791ef440efd6edb206c6f1be33989cb62e9213b2`.
- `godot/scripts/microscenario_panel.gd` baseline blob: `010eecde9754ea786cdeeaf800cca0f29ded4245`.
- `godot/scripts/microscenario_workbench.gd` baseline blob: `2014230bf06c12c6a084b359229cbd0682313dfb`.
- Existing independent graphical work: [PR #403](https://github.com/techrote/cybersand/pull/403), **draft and not integrated** at this checkpoint. Its reported 1.4–4.6 ms `Main._process` observation is a separate local Windows workload; no attribution of any portion of that time to this particular path is justified.
- Existing Windows Godot shutdown causal A/B: [PR #401](https://github.com/techrote/cybersand/pull/401), independently owned. This experiment does not attempt to explain or repair `0xC0000005`.

The bounded question is whether `Main` spends nontrivial per-render-frame CPU time copying MicroScenario data which only changes on completed worker publications, before any proposal to alter Main, native World, shader or worker. This is **one hypothesis**, not a demonstrated bottleneck.

## Source-verified control flow (no timing claim)

1. `main.gd:1881–1884`: for non-shared-workbench sessions, every `_process(delta)` calls `_refresh_microscenario_controls()` regardless of scenario activity.
2. `main.gd:1025–1029`: `_refresh_microscenario_controls()` immediately calls `microscenario_panel.refresh(tower_context)` whenever the panel exists.
3. `microscenario_panel.gd:116–118`: `refresh` unconditionally calls `workbench.refresh(context)` even if the modal liquid panel is closed.
4. `microscenario_workbench.gd:181–183`: `refresh` calls `context.get("microscenario", {}).duplicate(true)` before determining whether a schema-2 scenario is enabled or its UI may be shown. Thus the call site is **one deep-copy attempt per applicable rendered frame**; actual copied content varies with the scenario.
5. `microscenario_workbench.gd:191–205`: when enabled and unguarded, the region overlay also invokes `queue_redraw()` on every refresh, irrespective of a new publication or camera change.
6. `main.gd:2872` assigns `tower_context = snapshot.lab_context` only upon consumption of a new worker snapshot, but a second distinct synchronous Web controller also uses the MicroScenario panel. A future cache keyed to desktop snapshot identity **cannot** simply be imposed on Web without a separate identity/freshness contract.

This inspection establishes a repeated allocation/copy opportunity, not a proven amount of time, retained allocation, frame-time reduction or semantic safety of caching. In particular, `Main`'s **shared workbench** branch skips `_refresh_microscenario_controls`; observations measured solely there are not evidence for this path.

## Executable, strictly diagnostic probe

`godot/tests/performance/test_microscenario_refresh_copy_cost.gd` benchmarks the isolated dictionary clone expression under a deterministic synthetic scenario corpus with 0, 64, 256 nested observations and owner-publication strides 1 and 4. It alternates the current **copy every render frame** arm and a deliberately **counterfactual** copy-on-new-publication arm. Its exact artificial readback checksum must match between arms; 800 frames per case, three repetitions; bounded memory and execution.

Example supported command from repository root with an installed matching Godot 4.7 binary:

```sh
godot --headless --path godot --script res://tests/performance/test_microscenario_refresh_copy_cost.gd
```

It prints `INV154_MICROSCENARIO_COPY_PROBE` JSON with engine version, OS, observation count, publication stride, arm, elapsed microseconds, copy counts, digest, repetition and failure count. No game or native runtime is accessed. Its intentional expected copy counts are 800/current arm and 800/stride/counterfactual arm; these are **fixture invariants, not measured performance wins**.

The branch was authored without an accessible Godot binary or Windows graphical host; therefore **no native/Godot execution or timing values are claimed at this checkpoint**. An ordinary source-read audit cannot qualify a GDScript binary nor assert measured Windows benefit.

## Admission / next discrimination

1. Run the probe on real Godot 4.7 Windows (and Linux as a separate cohort), retain raw unrounded results and source/engine/hardware identities. Evaluate paired median and variability for the large/paused/active scenario cases; include a zero-observation control. Reject the hypothesis if copy cost is negligible relative to actual frame time.
2. If material, use an **isolated temporary host instrument** or source-qualified benchmark branch to time the real `workbench.refresh` subphases in both a running and paused MicroScenario, with unchanged actual content, snapshot publication rate, camera and UI. Do not infer end-to-end fps from the synthetic fixture.
3. Only then propose a guarded optimization. Any cache must preserve desktop and Web refresh, same-definition reset, captured observations, modal/hide state and the bounded-run step acknowledgment. The current `godot/tests/test_microscenario_workbench.gd` and `test_microscenario_workbench_lifecycle.gd` cover important behavior and must pass unchanged, alongside real-host tests.
4. Do not modify `main.gd`, `physical_actor_overlay.gd`, shader or native worker while #409/#402/#403/other owners hold adjacent active work. No production speedup, fix, merge or owner disposition is claimed here.

**Disposition:** DIAGNOSTIC APPARATUS ONLY. This is a new controlled cost discriminator and precise source-derived hypothesis, not a finished performance optimization. Preserve negative data and stop before production integration.
