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

### Actual Windows-hosted synthetic experiment (2026-11-05)

The standalone experiment **executed successfully** in [GitHub-hosted Windows Actions run 41994416705](https://github.com/techrote/cybersand/actions/runs/41994416705) against exact **executed source commit** `94a5b713377b812c21a14c05751c8460f245231b`. It used Windows Server 2022 hosted runner, official **Godot 4.7 stable** (`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`) from the official verified SHA-512-pinned Windows ZIP, and a separate minimal synthetic Godot project. The experimental script blob was `a2a1d571305c38dff2b32f4c75f634b15e792b9e`. The raw engine stdout and structured 36 rows plus engine/source identities are retained as [artifact 13399063622](https://github.com/techrote/cybersand/actions/runs/41994416705/artifacts/13399063622), scheduled to expire after 30 days. **36 rows / 0 parity failures**; clone counts and independent-readback checks passed. The host GPU/driver were irrelevant to this headless synthetic CPU measurement and no actual framebuffer was rendered.

Median total elapsed time for **800 synthetic update iterations**, from 3 independently executed repetitions (units are **microseconds**, not a measured real-game frame time):

| Nested observations | Publication stride | Every-frame clone | Once-per-publication clone |
| ---: | ---: | ---: | ---: |
| 0 | 1 | 1,973 | 2,215 |
| 0 | 4 | 1,773 | 730 |
| 64 | 1 | 66,225 | 65,754 |
| 64 | 4 | 64,596 | 16,456 |
| 256 | 1 | 261,259 | 266,937 |
| 256 | 4 | 277,191 | 70,165 |

At 256 synthetic observations with publication once per four render-frame iterations, the raw every-frame times were `[299117,277191,275897]` µs and the hypothetical publication-only times were `[77367,66202,70165]` µs, a roughly 3.95x **isolated copy-loop time ratio**. At stride one, both arms copy the same amount and no advantage was observed. This strong stride dependence is expected from the *synthetic* contract: **800 versus 200 deep-copy operations**. It does **not** demonstrate a 4x faster CyberSand, production memory reduction, improved FPS, or safe real gameplay cache.

The original first Windows [run 41994278217](https://github.com/techrote/cybersand/actions/runs/41994278217) **failed** after successful download/verification because the harness extracted only the Godot console executable, which requires its GUI companion beside it. The unaltered original failure log and [artifact 13398744342](https://github.com/techrote/cybersand/actions/runs/41994278217/artifacts/13398744342) are retained. The correction extracted both validated members; no production source, benchmark assertions or test input was weakened.

**Limitations:** no real `Main` graphical or input/render profiling, no native World/GDExtension or Rapier runtime in this standalone test, no Windows end-user GPU cohort, no Linux comparison, no claim of cold ANGLE startup or exit-crash repair. Any later documentation-only head differs from the **executed** source SHA above while preserving the tested synthetic script; exact-head qualified gameplay claims would require fresh dedicated execution.

## Admission / next discrimination

1. The Windows Godot 4.7 synthetic probe has now run and its positive/negative source-bound results are retained above. A Linux synthetic cohort is still absent. Determine whether the copied real scenario payload and publication cadence actually produce meaningful Main CPU cost on a real graphical host before changing any production source.
2. If material, use an **isolated temporary host instrument** or source-qualified benchmark branch to time the real `workbench.refresh` subphases in both a running and paused MicroScenario, with unchanged actual content, snapshot publication rate, camera and UI. Do not infer end-to-end fps from the synthetic fixture.
3. Only then propose a guarded optimization. Any cache must preserve desktop and Web refresh, same-definition reset, captured observations, modal/hide state and the bounded-run step acknowledgment. The current `godot/tests/test_microscenario_workbench.gd` and `test_microscenario_workbench_lifecycle.gd` cover important behavior and must pass unchanged, alongside real-host tests.
4. Do not modify `main.gd`, `physical_actor_overlay.gd`, shader or native worker while #409/#402/#403/other owners hold adjacent active work. No production speedup, fix, merge or owner disposition is claimed here.

**Disposition:** DIAGNOSTIC APPARATUS ONLY. This is a new controlled cost discriminator and precise source-derived hypothesis, not a finished performance optimization. Preserve negative data and stop before production integration.
