---
title: Rapier2D migration runbook
status: Current
scope: Pinned dependency acquisition, safe activation, staged coupling migration, diagnostics, acceptance gates, packaging, and rollback
keywords: [Rapier2D, migration, install addon, activate physics server, preflight, manual stepping]
related-documents: [../decisions/ADR-009-rapier-2d-rigid-body-backend.md, ../architecture/rigid-body-and-cellular-coupling.md, testing-validation-and-replay.md]
last-reviewed: 2026-09-08
implementation-state: Rapier2D v0.35.2 is selected behind a main-thread adapter. Dated Linux M11 and local Windows/Chromium proofs are distinct; current Web coupling is synchronous and desktop cellular ownership asynchronous. Generalized shapes, exact replay and high-count callback removal remain unimplemented.
---

# Rapier2D migration runbook

## At a glance

- Purpose: switch the rigid-body backend without conflating dependency, behavior, coupling, and optimization changes.
- **Current**: `godot/third_party/rapier2d.lock.json` pins Godot 4.7.x, Rapier v0.35.2, the official asset size, and SHA-256.
- **Current**: the official 2D single add-on is vendored and `project.godot` selects `Rapier2D` at 60 physics ticks per second.
- **Historical validation**: dependency, drop-in RigidBody2D, full-scene, and manual-step fixtures passed on Linux x86_64 in the M11 records; current Windows/Web evidence is scoped below.
- **Current**: one main-thread bridge owns manual stepping, direct server state, batch active transforms, and callback flushing.
- **Current**: moving-body samples use bounded swept overlap reconciliation before the endpoint obstacle mask is published to cells.
- **Planned**: package and validate every intended export architecture.

## Local Web acceptance — 2026-09-08

Scope: this is retained checkpoint evidence, not a clean-commit attestation or
an audit rerun. The [2026-09-08 documentation audit](../audits/2026-09-08-documentation-audit.md)
identifies the reconstructed source plus local changes and fresh checks.

**Current source:** `dev.cmd web` and `dev.cmd web --profile threaded` include Rapier2D
v0.35.2 and enable Physics Pit after the real manual-step/CCD capability probe.
Compatibility uses one cellular worker; threaded retains the 2/4/6 Auto policy.
Rapier calls stay on the Godot main thread through the existing backend adapter.
No Rust rebuild, toolchain upgrade, or cellular solver replacement was needed.

The restored binaries came from the retained official 2D single release ZIP
(SHA-256 `73b46bfe2cfc40e3875f4f367478bbd2b1090f563eeef57f4fed3fc274aae1f0`).
Both match the original Git LFS object digests. Their hashes are now recorded in
[the Rapier lock](../../godot/third_party/rapier2d.lock.json) and verified by
[build_web.py](../../tools/build_web.py) before staging and after export:

| Profile | WASM bytes | SHA-256 |
|---|---:|---|
| Compatibility | 2,751,606 | `5ff6933670c1377c24dcbac30d67758a307165eacdcbd33b25bf01669577c4c2` |
| Threaded | 2,754,113 | `b4020962f6ff6c5f2c07436a94cdbf7b5e2096a5fc5832e4ff5526378ce88528` |

Exports include `godot_rapier.wasm`, `RAPIER_LICENSE.txt`, and
`RAPIER_THIRDPARTY.txt`; build identity and delivery checks verify the selected
variant. Restore those exact ZIP members if the source files are LFS pointers.
The low-level builder retains explicit `--cellular-only` for diagnostic builds.

`test_web_rapier.gd` runs the real Web scene under `dev.cmd godot-test`.
Open a fresh test URL with `?test=1&rapier=1` to run the same fixture in Web.
Read `rapier_test` in the opt-in `cybersand-test-state` DOM node, or the
`WEB_RAPIER_TEST` console record. The fixture temporarily owns its test scene,
then returns to the Neon Works menu. Normal play URLs do not run it.

Windows native, Chromium compatibility (1 worker), and Chromium threaded
(6 workers) each passed 600 ticks with identical final body states, 308,087
cellular contacts and 151 displaced cells. Pause/menu ownership, demo switching,
reset, exact cellular payload restoration, and body state restoration passed.
Both browser profiles recorded no errors or warnings. Evidence is retained in
`C:/kybersand/validation/local/rapier-web-20260908/browser-results.json`.
Its native fixture reference is
`C:/kybersand/validation/local/20260908-152453/godot-fixtures.json` (15/15 runners).
This retained summary does not carry a complete immutable source/export hash manifest.

Limits: the one-pixel floor body settled at y=159.000656, with maximum centre
y=160.317276 (about 1.32 pixels transient penetration). The fixture bounds this
at two pixels and rejects tunnelling. Body restoration allows 1e-5 numerical
error because angle/matrix reconstruction rounds; CYSD1 does not preserve all
Rapier contact caches or native scheduler state. Rectangular three-body coupling
remains the existing proof, not generalized shapes or high-count stress coverage.
Firefox and Safari have not been tested. The native historical Linux claims below
remain separate from this local Windows/Web evidence.

## Search anchors

install Rapier2D, enable Rapier Physics, Rapier migration order, activate Rapier2D safely, Rapier preflight, manual stepping workflow

## Prepared inputs

| Input | Path | Purpose |
|---|---|---|
| Dependency lock | `godot/third_party/rapier2d.lock.json` | Version, source, expected addon/server, release metadata, and verified checksum |
| Vendored add-on | `godot/addons/godot-rapier2d` | Official 2D binaries, GDExtension descriptor, license, and notices |
| Guarded activation | `godot/tools/activate_rapier_2d.gd` | Select Rapier2D only after registration and version checks |
| Backend preflight | `godot/tests/test_rapier_backend_preflight.gd` | Confirm registration, project selection, and Godot version after restart |
| Drop-in fixture | `godot/tests/test_rapier_drop_in.gd` | Confirm an ordinary RigidBody2D/RectangleShape2D advances under automatic Rapier stepping |
| Manual-step fixture | `godot/tests/test_rapier_manual_step.gd` | Confirm explicit stepping, packed samples, and pause ownership |
| Behavioral fixture | `godot/main.tscn` | Three 8×14 bodies plus cellular mask/force observations |
| Coupling contract | `godot/scripts/rigid_body_coupling.gd` | Backend-neutral packed body samples and results |
| Step owner | `godot/scripts/rapier_physics_bridge.gd` | Main-thread RID ownership, force application, stepping, batch reads, and flush |

## Stage 1: acquire and activate — historical Linux procedure

1. Install exact Godot `4.7.stable.official.5b4e0cb0f`; export templates are only required for exports, and must match that version/profile.
2. Download the official Rapier2D release asset for tag v0.35.2 from the upstream release page.
3. Record the asset filename and SHA-256 in the lock manifest; retain the MIT license/notice.
4. Extract only the Rapier2D `addons` content into `godot/addons` and verify all intended platform libraries exist.
5. Open the project once so Godot imports the GDExtension without selecting it.
6. Run `godot --headless --path godot --script res://tools/activate_rapier_2d.gd`.
7. Restart Godot, then run `res://tests/test_rapier_backend_preflight.gd`.

No Rapier-specific solver setting is changed in this stage. Rapier's default 2D
length unit of 100 matches Godot's conventional 100 pixels per metre and the
project's current pixel-space scale.

## Stage 2: drop-in baseline — current fixture, dated passes above

Retain RigidBody2D nodes, automatic stepping, callbacks, current shapes, and the
packed cellular bridge. Exercise body/body collision, falling onto cellular
Wall, displacement through Water/Sand/Smoke/Paste/Slush, reset, sleep, and pause.
Record physics-step time, query-flush time where available, worker snapshot age,
contacts, displaced cells, and unresolved overlaps. Fix only backend
compatibility defects in this stage.

## Stage 3: explicit coupling ownership — current

The [current main-thread Rapier bridge](../../godot/scripts/rapier_physics_bridge.gd) owns the space RID, body RID table,
fixed delta, and coupling stage order. Disable automatic space stepping, apply
cell-derived impulses before `space_step`, fetch active transforms directly,
perform swept-mask reconciliation, and call `space_flush_queries` once. Keep all
cellular mutation on the platform's explicit owner through packed samples/results.

On desktop, the current main thread performs one Rapier step per Godot physics callback and
consumes the newest unapplied cellular result. The cellular worker remains
asynchronous, so its response may be one or more samples old under overload;
sample serials prevent duplicate force application. A bounded swept rectangle
mask covers skipped transforms for displacement, then is discarded in favour
of the endpoint mask before cell movement and pressure sampling.

On Web, [web_demo_controller.gd](../../godot/scripts/web_demo_controller.gd)
`_physics_process` applies the preceding cellular result, manually steps Rapier,
captures bodies, prepares coupling, then completes the native cellular tick on
the same Godot main thread. Compatibility uses one cellular worker and threaded
Web uses a persistent C++ pool internally; both calls remain synchronous from
Godot's perspective. The desktop async sample-age limitation is therefore not
an accurate description of the Web owner. Fully asynchronous Web ownership is
**Deferred**; changing the coupling order requires a new measured contract.

Add Rapier substeps only when a motion/shape fixture demonstrates tunnelling.
Enable CCD per fast body before raising any global substep bound.

## Stage 4: scale path

Active RIDs and transforms are already read in a batch and the shader renders
the bridge's authoritative transform cache. The three low-count test nodes keep
their state-sync callbacks. Disabling callbacks and moving high-count body
classes to direct-server rendering remains **Planned** and must be measured.

## Acceptance and rollback

Historical Linux activation/manual stepping and the dated Windows/Chromium
fixtures above are accepted within their recorded scope. Other export architectures
are not accepted merely because binaries are present. Rollback requires an
actually available verified checkpoint; this local snapshot has no Git history.
The historical pre-Rapier rollback proposal is not a locally verified artifact;
the production project does not carry a runtime Godot-physics fallback.

On Windows, `C:/kybersand/dev.cmd godot-test` runs the current fixture inventory
with individual timeouts and logs. Focused POSIX invocations from `source/`
(procedures, not fresh Linux validation):

```sh
timeout 60 godot --headless --path godot --script res://tests/test_rapier_backend_preflight.gd
timeout 60 godot --headless --path godot --script res://tests/test_rapier_drop_in.gd
timeout 60 godot --headless --path godot --script res://tests/test_rapier_manual_step.gd
timeout 60 godot --headless --path godot --quit-after 180
```

## Related decisions

- [ADR-009: Rapier2D backend](../decisions/ADR-009-rapier-2d-rigid-body-backend.md)
- [Rigid-body and cellular coupling](../architecture/rigid-body-and-cellular-coupling.md)
- [Testing and replay](testing-validation-and-replay.md)
