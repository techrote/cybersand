---
title: GEN-005 semantic-plane implementation and acceptance evidence
status: Current
document-kind: evidence
scope: Dated source, runtime, platform, deterministic generation, native fixture and rendered evidence for issue 192
canonical-for: []
last-reviewed: 2026-10-21
related-documents: [../systems/procedural-semantic-planes.md, ../operations/semantic-depth-authoring.md, ../operations/local-build-and-validation.md]
---

# GEN-005 semantic-plane implementation and acceptance evidence

## Source and recovery boundary

Implementation starts at `bc6af48d14f5da74db9548043ba5a6ac2a57477a` (current main
with GEN-003, GEN-004 and player playground #189 integrated). Work is isolated on
`feat/gen005-semantic-planes`. Relevant unrelated open Water/presentation/map
work remains separate. The implementation PR records recoverable checkpoints.

The [canonical contract](../systems/procedural-semantic-planes.md),
[ADR-014](../decisions/ADR-014-semantic-plane-admission.md) and
[authoring guide](../operations/semantic-depth-authoring.md) distinguish source
behavior from executed acceptance. Two existing depth routes and native material
kernels are retained. No persistent streaming or player-edit rebasing is claimed.

## Gate ledger

This initial recoverable checkpoint is implementation-in-progress. Exact source
commits, assertion totals, runtime hashes, captures and hosted result URLs are
filled from completed executions before acceptance; a Pending entry is not a pass.

| Gate | State at this checkpoint |
|---|---|
| Native four-plane deterministic and rejection tests | Linux optimized: 217,773 assertions, zero failures, including actors and shared typed masks. |
| ASan/UBSan semantic-plane tests | Same 217,773 assertions, zero failures in 30.890 s; local leak detection disabled because LeakSanitizer is incompatible with this ptrace environment. |
| Native adapter whole/tiled examples and immutable copies | Source-built Linux extension: 606 assertions, zero failures; all five sections completed, including retained workbench revision compatibility. |
| Four-World host lifecycle, bounded events and native chemistry | Source-built Linux extension: 1,108 assertions, zero failures; all six sections completed. Base depth regression: 83 checks passed. |
| Actual example native fixtures | 1,391 assertions, zero failures, all 40 fixture IDs verified across both recipes. |
| Actual composited/per-plane captures and pixel controls | Actual Xvfb/Mesa OpenGL pixel oracle: 104 assertions, zero failures, both examples complete. Final capture files pending. |
| Canonical docs, historical M11 and RAG | Local docs and M11 passed; canonical retrieval hit 35/35 frozen and 102/102 challenge queries. Source/runtime provenance remains pending publication. |
| Matching Linux/Windows native runtime publication | Pending scoped publisher. |
| Exact-head Documentation, Native, Linux/Windows GDExtension and scoped apparatus | Pending ready-for-review execution. |

The launcher also passed 43 assertions and the direct semantic-depth argument/return regression. Publisher guard tests passed 19 adversarial cases. These local controls are development feedback until the platform and exact-head gates pass. The final accepted source and
platform scope will be recorded below and in the PR before closing #192.

## Reproducible local controls

```sh
make -j2 build/test_generation_planes
./build/test_generation_planes
make -j2 build/test_generation_planes_sanitized
./build/test_generation_planes_sanitized
make worldgen-test
make worldgen-sanitize
python3 tools/ci/test_gen005_runtime_publication.py
python3 tools/ci/check_ci_provider_policy.py
python3 tools/ci/check_docs.py
python3 tools/ci/check_m11_consistency.py
python3 tools/ci/check_repository.py
```

Source-matched Godot cases: `test_worldgen_planes.gd`,
`test_semantic_planes_runtime.gd`, `test_semantic_planes_examples.gd` and
`test_semantic_depth_render.gd`.
The render case requires Xvfb/software OpenGL on this Linux host; it must not use
a headless skip. Retained generation, depth, Deepworks and player regressions
protect the integrated prerequisites. The normal hosted test discovery includes
the new cases and keeps errors/timeouts/skips distinct from passes.

## Actual fixture observations

The two example revisions tested locally are `a9ae4e7ecad92a14` (refinery) and
`94b7ebaa1329d946` (flooded cavern). Each completed 20 fixture IDs, 544 scheduled
applications, 9,664 source/drain cell writes and 448 cleanup writes, exactly
matching its declared finite programmes. Rear-only execution ran 220 ticks with
play, effects and background bytes and play actor tick unchanged. Subsequent
240 play/effects ticks left rear and background unchanged.

Eight native rear Water/Salt reactors started with zero Brine and reached
48–56 observed Brine cells. Brine was never a source/setup material. Water below
the reactor feeds grew from zero to 404–408 cells. Eight waterfall observations
grew from 112 to 516–530 downstream Water cells. Inactive-source and missing-Salt
controls qualify the mechanism. In the focused native counterfactuals, retiring
the Water source leaves zero Brine and zero downstream Water after 180 ticks;
removing Salt leaves zero Brine despite four Water feeds and observed transport.
A paired two-tick atmosphere control creates Steam from an empty nozzle; an
active drain removes four seeded Water cells while its retired counterpart
retains all four. Helper completion and exact per-fixture schedule counts qualify
the accounting; the 24 atmospheric example records are accounted by schedules
and cleanup rather than separate per-record material-effect observations. These are finite observation windows, not a
claim of eventual equilibrium or persistent streaming.

## Explicit qualifications

The semantic scene uses the existing synchronous depth owner. Actor proposals
are play-only and use the existing sampled actor session. It is not a new
non-play physics owner, an articulated-controller traversal qualification or
production asynchronous layer integration. Real four-plane material captures
and isolated native reaction checks do not establish browser execution or target
hardware performance. Linux and Windows execution require their own receipts.
