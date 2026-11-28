---
title: Workbench native-pixel sampler transition
status: Historical
document-kind: audit
scope: Exact material-palette consumer byte change as incorporated by PR 682
canonical-for: [evidence-pubpres-sampler-transition]
last-reviewed: 2026-11-20
related-documents: [../operations/pubpres-integration-evaluation.md, ../systems/material-appearance-and-rendering.md]
---

# Workbench native-pixel sampler transition

PR [#682](https://github.com/techrote/cybersand/pull/682) incorporates the reviewed pixel-coordinate sampler from [#566](https://github.com/techrote/cybersand/pull/566) through #609. `godot/shaders/material_palette.gdshader` has the same bytes as the donor, with LF SHA-256 `b8e5542dae2c36fd6fbef0170a7b537bce5c853fc10920174cefe13dbec78d4f`, retained in integration ancestry at `6a7069cc67167661497c319b4a73e8d381ea2564`. The previous protected consumer's LF SHA-256 was `f686ca416b5b011751ddd5d38a24824742d01cb8d489b46710ee1f1fbb2a09c1`.

The change selects material sample coordinates from a shared physical-pixel camera transform, with the prior UV mapping available when native-pixel mapping is unavailable. Material IDs, condition channels, palette and program lookup, and Wave data are unchanged. The established GPU tests exercise pixel alignment, effects and previous/current history. The original catalogue lock remains the historical reference. The exact-head integration qualification is recorded in the PR.
