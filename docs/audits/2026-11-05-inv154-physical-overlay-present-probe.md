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
