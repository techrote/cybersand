---
title: Rapier2D dependency and validation runbook
status: Current
document-kind: guide
scope: Current pinned backend verification and change procedure; migration history and coupling semantics are linked separately
canonical-for: [rapier-dependency-validation, rapier-packaging]
last-reviewed: 2026-09-08
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, ../reference/validation-evidence.md, web-threading.md]
---

# Rapier2D dependency and validation runbook

## Is Rapier already installed and selected?

**Current:** the official single-precision 2D **v0.35.2** add-on is vendored and
[project.godot](../../godot/project.godot) selects `Rapier2D`. The bridge reads
`physics/common/physics_ticks_per_second` with a default of 60; the project does
not override that setting.
The [lock](../../godot/third_party/rapier2d.lock.json) records the release archive
SHA-256 `73b46bfe2cfc40e3875f4f367478bbd2b1090f563eeef57f4fed3fc274aae1f0`.
Godot is pinned to `4.7.stable.official.5b4e0cb0f` by the build requirements.

The main-thread [CyberRapierPhysicsBridge](../../godot/scripts/rapier_physics_bridge.gd)
deactivates automatic space stepping, applies the newest accepted cell result,
steps the space, reads direct server transforms and flushes callbacks. The
desktop and Web owners have different timing; the exact order, rectangle sweep,
terrain budget and remaining limitations belong to
[rigid-body/cellular coupling](../architecture/rigid-body-and-cellular-coupling.md)
and [tick/threading](../architecture/simulation-tick-and-threading.md).
Do not rerun activation as if migration were still unimplemented.

## Verify dependency before diagnosing coupling

Use exact Godot and the intended architecture's real library bytes. Run these
scripts with `godot --headless --path godot --script res://tests/<name>.gd` from
source, bounded to 180 seconds each, or use the workspace `dev.cmd godot-test`.

| Runner | What it checks |
|---|---|
| [test_rapier_backend_preflight.gd](../../godot/tests/test_rapier_backend_preflight.gd) | Version, registered server class, vendored extension and selected backend |
| [test_rapier_drop_in.gd](../../godot/tests/test_rapier_drop_in.gd) | Ordinary body integration with automatic stepping in an isolated fixture |
| [test_rapier_manual_step.gd](../../godot/tests/test_rapier_manual_step.gd) | Explicit bridge stepping, packed samples and pause ownership |
| [test_web_rapier.gd](../../godot/tests/test_web_rapier.gd) | Real Web scene under native Godot: three-body coupling, thin floor, pause/reset and level/body restoration |

Missing `RapierPhysicsServer2D` indicates registration/version/architecture trouble.
Wrong project selection needs activation/restart. A valid backend with material
overlap needs a coupling fixture, not a dependency upgrade. Inspect direct server
state when SceneTree transform timing differs. Native pool workers never call
Rapier or Godot APIs.

## Web packaging and browser fixture

Both default compatibility and optional threaded exports include Rapier and
Physics Pit after a real manual-step/CCD capability probe. The
[builder](../../tools/build_web.py) verifies selected WASM hashes before staging
and after export; the lock is their canonical home. Exported files include
`godot_rapier.wasm`, `RAPIER_LICENSE.txt` and `RAPIER_THIRDPARTY.txt`.
`--cellular-only` remains an explicit diagnostic path.

Build/serve the selected profile using [Web threading](web-threading.md), then
open a fresh URL with `?test=1&rapier=1`. Read `rapier_test` in the opt-in
`cybersand-test-state` DOM node or the `WEB_RAPIER_TEST` console record. The fixture
temporarily owns the test scene and returns to Neon Works; normal play URLs do
not run it. Native headless execution of this scene does not establish Web WASM
execution. Capture browser version, export hashes, profile/worker count and console.

## Evidence and acceptance limits

[Validation evidence](../reference/validation-evidence.md) records historical
Linux M11, September Windows and retained Chromium results separately. The
three-rectangle fixture allows two pixels of transient floor penetration and
`1e-5` error for restored body values. It is not zero-penetration proof, generalized
shape/high-count acceptance or exact Rapier replay. [CYSD1](../reference/level-saves-and-replay.md)
omits Rapier caches and native continuation state. Linux binaries currently include
unresolved LFS pointers despite historical Linux passes.

## Future backend changes

Preserve [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md): Rapier remains
behind engine-owned interfaces. Establish a source checkpoint, update the lock and
notices, test registration then isolated automatic/manual fixtures, test coupled
behavior on each target, then measure performance. Preserve exclusive step ownership
and roll back a failed backend change before layering unrelated solver work.
Generalized shapes, high-count callback removal and unvalidated export architectures
remain **Planned**. Original staged migration/results are retained in the
[pre-rewrite historical record](../audits/pre-rag-rewrite-2026-09-08/README.md).
