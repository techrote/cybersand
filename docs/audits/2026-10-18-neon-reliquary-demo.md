---
title: Neon Reliquary scene implementation and validation
status: Current
document-kind: audit
scope: 2026-10-18 authored example level, source/runtime identity, Linux native/controller tests and actual software-OpenGL scene review
canonical-for: []
last-reviewed: 2026-10-18
related-documents: [../operations/neon-reliquary-demo.md, ../reference/validation-evidence.md, ../operations/microscenarios.md]
---

# Neon Reliquary implementation checkpoint

## Request and source boundary

The owner requested an example Cybersand demo level, prioritizing advanced detail
and scene aesthetics over practicality or realism. This increment implements a
machine cathedral with a suspended luminous engine, varied side architecture,
ornate materials, cable runs and flooded vaults.

Baseline: accepted `main` **`ec05d7227885bda59bf72a5889b004296b9a07e5`**,
after MAT-001 / PR #159. Work branch: `scene/neon-reliquary-demo`.
PR #148 remains separate player-traversal work. No native implementation,
material palette/program, emission/glow shader, material rule, dependency pin or
retained runtime was changed. Source/visual checks below apply to the working
delta retained by this checkpoint, with file digests in the
[evidence manifest](2026-10-18-neon-reliquary-evidence.json).

## Implemented scene and lifecycle

The shared native recipe contains **3,973 ordered rectangles**, **543,468 total
authored cell writes**, and **34 material identities**. It passes the existing
4,096-record, eight-world-area, material-ID, bounds and 1 MiB schema limits.
Its seed-zero canonical definition SHA-256 is
`895796380f2f82692724fb4378d77c2b239223f6a81bbb018233629e6ccaed0f`.

Desktop F11/the launcher and the Web menu enter the same schema-2
`showcase/neon-reliquary` definition through the established owner boundary.
It starts paused at tick zero with a 960 × 540 overview. Four detail viewpoints
change camera framing without replacing or advancing native state. The scene
fixes interest to its declared `[32,16,960,540]` region, retains Baseline transport
and Water8/coherence12, and has no Rapier bodies, scheduled events or objectives.

The optional distant-city backdrop reads accepted current/previous RG8 textures
and masks filled cells, unfinished transitions and the sampled player. It is
disabled when an edited definition enables bodies. Palette, emission and glow
remain the normal engine pipeline. Viewpoint popups block painting until pointer
release; pending reset/experiment-modal states block new showcase launches;
exiting through the Web demo menu restores the selected ordinary quality/view.
F8 now also hides the player/environment controls, giving the scene a clean view.

## Executed local evidence

Host: Linux x86_64; one native worker for deterministic scene tests. Godot:
**`4.7.stable.official.5b4e0cb0f`** from the exact pinned archive. Native Linux
GDExtension SHA-256:
`43e747137249041d56a522dbe0ec35219082ea555e1ec1cbdd40971c6a58db9c`.
Rapier Linux SHA-256:
`147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831`.
Retained native source inputs match the current native files; no rebuild was
needed for this GDScript/scene-only change.

| Check | Executed result | Scope |
|---|---|---|
| Pinned runtime and required LFS bytes | Passed | Exact Godot version/archive and native/Rapier identities; native source-input freshness |
| Baseline headless import and scene startup | Passed | Established the runtime before scene edits |
| `test_neon_reliquary.gd` | **89 assertions, zero failures** | Deterministic construction, JSON round-trip, budgets, landmarks, safe spawn, rejected replacement preserving state, exact reset; 120 native ticks; real desktop and synchronous Web-controller lifecycle |
| Controller presentation/input checks | Passed in the same focused fixture | Paused viewpoint/atmosphere neutrality, F8, popup/held-button guards, pending-reset/modal refusal, step/reset, exit cleanup and Web quality restoration |
| Eight existing shared-controller regressions | **All passed; exit zero, no script/runtime errors** | MicroScenario controllers (55 assertions), Web demo setup, PCHAR-001, PENV-001, PLAY-VAL-001 (75 assertions), brush owner commands, Water controller/blind lifecycle and render-patch handoff |
| `test_showcase_backdrop_render.gd` | **Zero failures, actual rendered pixels** | Current solid/liquid, previous transition and sampled player remain visible; erase, fresh paint and completed transitions update the backdrop mask |
| Normal desktop scene capture | **Five 1920 × 1080 PNGs rendered and inspected** | Existing material palette, immutable native publication and glow pipeline; paused tick-zero overview and four views |

Rendered environment: Godot Compatibility / OpenGL 4.5 / Mesa
`25.2.8-0ubuntu0.24.04.2`, **llvmpipe LLVM 20.1.2**, on Xvfb. The unsupported
V-Sync warning is a software-display limitation; no Godot script/shader/runtime
error was present in successful captures or the actual-pixel oracle.

The initial scene capture was reviewed before refinement. A second geometry pass
added fine bus spokes, wound copper coils, inner-ring engraving, three suspended
cable curves and a broken arch segment. The final recipe and all five viewpoints
were then captured again. Selected images are retained under
[`docs/images/neon-reliquary`](../images/neon-reliquary/overview.png).

Initial validation failures were resolved without changing test criteria: an
editor import needed writable XDG directories and IPC access; the scene contract
required an explicit string-key schema-2 `presentation` field; the held-mouse test
fixture needed a button mask and buffered-event flush to produce its intended
input. The implementation review also replaced signed `pow(x,2)` expressions
with multiplication for portable shader squares, and corrected the UI/exit
issues described above. Final failures are not hidden by these earlier attempts.

Final documentation checks passed with no errors or warnings: 79 current corpus
documents, 136 canonical claims and 1,314 local links. Current repository
provenance passed with all 18 required runtime files materialized. Historical M11
integrity separately passed for 18 records and 28 source hashes against
`05ea45fda7bdd7b0150eb86c4922c202e89e08f4`. Retrieval canonical hit@5 is **32/32**
for the frozen questions and **37/37** for the independent challenge set;
`SCENE01` returns the scene guide at rank one. `git diff --check` passed.
The capture helper was finally tightened to fail on manifest open/write/flush
errors, then successfully repeated all five paused tick-zero rendered captures.

## Reproduction commands

With writable Godot user directories and the exact pinned runtime:

```sh
timeout 150 godot --headless --path godot \
  --script res://tests/test_neon_reliquary.gd
timeout 120 godot --path godot --rendering-method gl_compatibility \
  --script res://tests/test_showcase_backdrop_render.gd
timeout 180 godot --path godot --rendering-method gl_compatibility \
  --resolution 1920x1080 --max-fps 30 \
  --script res://tools/capture_neon_reliquary.gd -- \
  --capture-dir=/absolute/output/directory
```

The second and third commands require a rendering display. The first uses
native Godot even though it has no display; invoking the synchronous Web
controller on Linux is not browser/WebAssembly execution. The capture tool
records runtime/recipe/view metadata alongside the images.

## Documentation map and acceptance scope

| Concern | Canonical disposition |
|---|---|
| Scene design, entry points, controls, capture | New [scene guide](../operations/neon-reliquary-demo.md), README and Material Lab routes |
| Schema/install/reset and bounds | Existing [MicroScenario contract](../operations/microscenarios.md), with a new consumer route; no schema or native ABI change |
| Ownership/lifetimes/render masking | Scene guide and [appearance contract](../systems/material-appearance-and-rendering.md); existing render leases and worker contracts unchanged |
| Configuration/capacity | [Configuration reference](../reference/configuration-reference.md) records explicit scene framing/interest; no increased limits |
| Programme/roadmap/handover | Scene content is separately scoped; no physics gate or issue-order change |
| Retrieval | New canonical scene guide plus independent SCENE01 challenge; frozen questions preserved |
| ADRs, material invariants, source/runtime manifests | No architectural/material/native changes requiring revised decisions or attestations |

This establishes an implemented, rendered Linux scene candidate and focused
controller correctness. It does not claim new Windows execution, actual browser
execution, physical-GPU performance, broad gameplay/physics qualification, or
owner aesthetic acceptance. Required GitHub integration checks are recorded on
the implementation PR after publication; a local pass does not substitute for
them. At this checkpoint, the completed implementation is committed locally.
Branch publication is awaiting explicit owner approval after the automatic
publication review gate refused the push, so no PR or new GitHub CI result is
claimed.
