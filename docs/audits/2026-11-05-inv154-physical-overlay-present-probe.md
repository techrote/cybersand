---
title: INV-004 physical actor overlay copy-cost negative/positive discriminator
status: Current
document-kind: evidence
scope: Isolated unmodified physical overlay presentation CPU cost and aliasing, not graphical Main, GPU or gameplay qualification
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../operations/profiling-observability-and-performance.md, ../systems/material-appearance-and-rendering.md]
---

# INV-004 — physical actor overlay present() cost and ownership probe (5 November 2026)

## Bounded question and why a separate investigation

Accepted main at registration: `ba9cbc89029be88b812af59b19e5c59829bbcd90`, tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`.
The following are exact accepted-main Git blob identities:

- `godot/scripts/main.gd`: `791ef440efd6edb206c6f1be33989cb62e9213b2`.
- `godot/scripts/physical_actor_overlay.gd`: `349bbe886f6f7f0502b8d78ae70b97a7430f1806`.
- `godot/scripts/physical_actor_session.gd`: `bde4503df99d7e317cfb0987004d525f72177316`.
- `godot/scripts/physical_actor_rig.gd`: `86e77f2f9e177263a9f402571bd82856920fdbe0`.

`main.gd:1920–1922` calls `physical_actor_overlay.present(physical_actor_session.render_parts(...), ...)` on **every** rendered Main frame; unlike MicroScenario, the presented actors may move between material worker publications due to Rapier stepping/interpolation. `physical_actor_session.gd:789–822` builds fresh presentable part dictionaries from actual physics bodies, and `physical_actor_overlay.gd:18–25` copies the resulting Array with `duplicate(true)`, updates geometry and queues a redraw. The **copy is a legitimate ownership boundary**, not self-evident waste. Neither a copy-on-worker-publication shortcut nor a renderer mutation is authorized.

Live companion work is independently owned: draft [#417](https://github.com/techrote/cybersand/pull/417) measures the **different** MicroScenario Control path; draft [#403](https://github.com/techrote/cybersand/pull/403) owns ANGLE/FXC cold-start and a separate local steady-state pacing experiment; draft [#401](https://github.com/techrote/cybersand/pull/401) owns the Windows exit-access-violation diagnostic. Do not modify any of those branches, protected Main, renderer, Rapier or native physics source.

## Predeclared standalone experiment

`godot/tests/performance/test_physical_overlay_present_probe.gd` is one self-contained SceneTree test. The diagnostic workflow copies the accepted-main production `physical_actor_overlay.gd` **byte-for-byte** into a temporary Godot project. The manifest guards the Main, Session, Rig and Overlay Git blob identities before execution; production is never instrumented.

- Synthetic immutable part counts: **0, 8, 64, 512**. The upper synthetic stress envelope is based on at most eight actors, eight parts each and eight rectangles per compound part; it is **not** a measured typical player scene, and those maxima need not co-occur.
- Three source-bound CPU arms: actual `overlay.present()`, only `parts.duplicate(true)`, and count-only baseline. Three interleaved repetitions with arm order rotated, 24 batches per arm, 20 calls per batch, 12 warm-up calls. Every timed batch retains monotonic `Time.get_ticks_usec()` elapsed time. No artificially slowed simulation, cold-cache resets or GPU confounder.
- Correctness checks: the actual overlay receives the proper part count; batch count/checksum is exact; copying isolates a post-publication owner mutation, while a subsequent call makes that changed value visible.
- Host: **GitHub-hosted Windows Server 2022**, source SHA/tree recorded, pinned official **Godot 4.7 stable** executable archive verified against the repository's `GODOT_SHA512`. The headless DisplayServer is recorded, not represented as a Windows desktop display/GPU. No loaded native World, Rapier DLL, graphical Main, moving actors, real render, frame interval, gameplay throughput or driver-side latency is exercised.
- Raw artifacts include complete batch times, positive/negative ownership controls, source guards, Godot provenance, stdout and failure logs. A missing run, skipped job or failed assertion must remain visibly nonqualifying.

Run manually with an actual Godot 4.7 installation by copying the unmodified overlay source into a minimal Godot project as `scripts/physical_actor_overlay.gd`, copying this test to `probe.gd`, importing that project and invoking:

```sh
godot --headless --editor --path /path/to/standalone --import
godot --headless --path /path/to/standalone --script res://probe.gd
```

Success is exactly one `INV154_PHYSICAL_OVERLAY_PROBE` JSON readback, 36 rows, 24 nonnegative timed batches per row, accurate checksum, two ownership controls true and clean engine exit. This is diagnostic-only; no production optimization follows from a low/large synthetic overhead without **actual graphical Main** and physics owner timing evidence.

## Current qualification boundary

This branch and the focused Windows runner are **experimental**, not a merge candidate. No production source, GLSL shader, native World, Rapier, worker, material, default or ABI changed. The next gate, if the measured per-frame cost warrants investigation, is a real Windows Main per-phase trace with source-matched Rapier part counts and a serial counterbalanced workload; the synthetic copy number must not be extrapolated into a frame-rate improvement.


## Executed Windows headless Godot evidence — first complete cohort

The preregistered diagnostic completed **PASS** at executed source commit `8feccfbbf9e635298b86c70dd2a05c053835bf22`, tree `2b12db4839d5161dfae6b871186238836ef3a204`, in [GitHub-hosted Windows run 42014112905](https://github.com/techrote/cybersand/actions/runs/42014112905), job `windows-actual-overlay-method`. [Raw result, logs and source/engine identity artifact 13407813412](https://github.com/techrote/cybersand/actions/runs/42014112905/artifacts/13407813412) is retained by Actions with its configured 30-day retention. Runner: **Windows Server 2022**, reported AMD EPYC 9V45 CPU; runtime: **Godot 4.7-stable official** (`5b4e0cb0f`), verified repository SHA-512 archive pin; actual `DisplayServer=headless`. Only `physical_actor_overlay.gd` was executed from copied production source; no Rapier or native World binary was loaded. Test exit was 0, failures 0, isolation/readback true.

There were **36 arm/repeat combinations**, **864 raw measured batches**, **20 method calls per batch** and three rotated-order repetitions. The following times are **median and p95 of *20-call batch-average* durations**, *not p95 individual rendered frames*. Units are **ms per method call**, measured using monotonic Godot `Time.get_ticks_usec()` elapsed wall time:

| Synthetic part dictionaries | Actual `present()` median | `present()` p95 batch-average | Clone-only median | Clone-only p95 batch-average |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 0.00110 | 0.00115 | 0.00030 | 0.00045 |
| 8 | 0.01105 | 0.01260 | 0.01020 | 0.01105 |
| 64 | 0.079625 | 0.08190 | 0.07845 | 0.08385 |
| 512 (combined synthetic extreme) | 0.64450 | 0.66940 | 0.63105 | 0.64980 |

**Interpretation:** most of the isolated `present()` elapsed time for populated synthetic payloads is explained by the existing required deep copy, not by additional Control-property assignment or redraw-queuing overhead. At 8 parts, the entire path is approximately 0.011 ms/operation on this *hosted headless CPU*; at 64 parts approximately 0.080 ms; only the deliberately extreme 512-part synthetic workload approaches 0.65 ms. Neither the input population nor workload cadence is known to be typical of actual Main gameplay. No desktop frame-time, GPU, 60 Hz pacing, actor preparation cost, actual redraw/render cost or throughput improvement was measured.

**Correctness negative control:** after one real `present()`, mutating the caller's part dictionary did **not** change the overlay's held copy; a second `present()` did expose the new ID. Both required controls passed. This argues **against** casually removing `duplicate(true)` merely to reduce the isolated copy cost. The test's count-only arm provides a measurement-floor control, not a semantics-preserving production replacement.

All sample arrays and aggregate reduction are preserved unchanged with the source-qualified Windows job. The Windows runner cannot establish end-user GPU performance; no physical device, human-feel or gameplay acceptance is inferred. The experimental PR must remain Draft. Its later documentation-only revision does not imply a new Windows test of a changed fixture.

**Decision:** The measured small-population cost does **not** motivate an immediate production cache or unsafe copy removal. The one useful next gate is a real Windows graphical Main trace showing actual `render_parts()` cardinality, `render_parts()` CPU time, `present()` CPU time, and p50/p95/p99 Main frame durations in a matched actor-heavy and control scene. If that trace does not establish material impact, close this hypothesis without changing production.
