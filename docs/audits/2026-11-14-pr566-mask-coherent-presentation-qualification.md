# PR566-FLYER-COHERENCE — guarded material-clear live-overlay repair

**Date:** 2026-11-14  
**Status:** IMPLEMENTED / host-qualified Windows+Linux / **DRAFT-HOLD, not yet physical Owner GPU accepted**  
**Stacked Draft PR:** [#593](https://github.com/techrote/cybersand/pull/593) → [#566](https://github.com/techrote/cybersand/pull/566)'s source branch. **Do not merge either without explicit Owner approval.**

## Problem, proven cause and prior discriminators

Owner observed smooth camera movement with a flickering/double-imaged moving flyer after activating Workbench **Thruster fire**, persisting after Fire OFF, even in Free camera, until **Restore start**. An embedded-cell physics-recoil hypothesis is valid as an architectural risk, but the exact open-air four-arm native/Rapier test [43561255396](https://github.com/techrote/cybersand/actions/runs/43561255396) produced **20 Fire insertions and zero unresolved Fire/Smoke recoil**, with identical Rapier trajectories and visible overlay-frame age.

The [Windows 4.7 presentation-only A/B](https://github.com/techrote/cybersand/actions/runs/43584091153) demonstrated that a live Rapier overlay removes sampled holds in Free/Follow camera without changing physics, but an unconditional live pose could differ from the uploaded World-mask geometry by **up to 44 world-cell positions**. It is not admissible as an unguarded production fix.

## Implemented mechanism

**Source parent:** PR #566 evaluated `214de85adef2aaabc8e26de8612a3bf27cc1a081`, source tree `603fa56ad5fcdddcc64084d79975d42ad28753c3`.

The application changes are scoped to:
- `godot/scripts/workbench_presentation_coherence.gd`: exact oriented rectangle inclusion at world **cell centres**, matching `CyberNativeCellWorld::rasterize_transform_in` for the admitted Workbench rectangle-mask geometry. Checks *every material-bearing cell* in a swept sequence between upload-bound and live-Rapier transforms, including intervening rotation/translation; no vertex-only or endpoint-only clearance. Conservative full turning radius bounds can reject a safe pose but cannot miss a stored material on the evaluated sweep. A swept pose is rejected if there is any occupied cell of **any material ID**, including Fire, Smoke, Water, Sand and hard Walls.
- `godot/scripts/main.gd`: when rendering a Workbench actor, require the uploaded frame's **World generation, material revision, session, epoch and actor generation** all match the currently uploaded native material and Rapier owner. On an eligible frame, request the actual live RID pose; accept it *only* if the swept-mask clearance oracle succeeds. On any mismatch, unknown previous material, scan budget exhaustion, out-of-world path or material collision, keep the old uploaded-mask-bound visual pose. The original immutable uploaded frame stays untouched. The camera, texture upload, native World and render ACK code remain unchanged.
- `godot/scripts/physical_actor_session.gd`: optional body-index → visual pose map in `render_parts`; only the scene overlay uses it. No input, controller, actual Rapier RID, geometry, native mask, material, force, impulse, solver or sample/ACK identities are changed.
- **Previous texture coherence:** before a bounded render patch modifies the CPU image, record only its old nonempty pixel IDs (up to **16,384 patch cells**) so that a still-active shader `snapshot_blend` also checks material in the previous GPU texture. Outside the changed rectangles, old texture material IDs equal current material IDs. Any oversized patch/full World reset marks old pixels **unknown** and disables speculative live poses for the blend interval. No full World duplicate, per-cell physics state or additional GPU image is introduced.
- **Explicit limits:** 32-world-cell maximum translation, 32-cell rotational sweep, at most 32 interpolated poses and **12,000 bounding-cell reads** per actor per frame. Geometry and image identities must be finite/valid; otherwise the gate fails closed. No unbounded per-pixel work and no increased rendering publication frequency. Paused Workbench and diagnostic `CYBERSAND_DIAG_FLYER_POSE=mask` retain the exact original pose. Default is guarded.
- Rendered actor pose can still differ geometrically from the old native mask **only when the entire intervening swept mask is empty of displayed stored material** in both active textures. That is a visible occupancy/mask **coherence invariant**, not a claim that actual live Rapier and uploaded cellular mask bytes represent the same physics tick.

## Exact-source qualification

### Windows actual-host reproduction

- [Windows source-qualified A/B run 43586885390 — SUCCESS](https://github.com/techrote/cybersand/actions/runs/43586885390) on early implementation source `7e996808d53a821e47ad3eb6486b840f5d6b7b87`.
- [Final Windows run 43587503505 — SUCCESS](https://github.com/techrote/cybersand/actions/runs/43587503505), source `b427c919e8dada276f38ca16c76617893addc78a`. The final source app files were unchanged by later documentation/Linux workflow additions.
- [All eight raw Windows graphical A/B test processes, 64 PNG frame readbacks, geometry/material ledgers, safety and original logs](https://github.com/techrote/cybersand/actions/runs/43587503505/artifacts/14111610429).
- Windows 2022, official pinned Godot **4.7.stable.official.5b4e0cb0f**, real Rapier2D **0.35.2**, real non-headless GL Compatibility/ANGLE renderer; original **PR #566-qualified Windows native DLL** SHA-256 `6c7811b78c12e34a68931f83f2fd505c20078c089bce245a9be8be6e02e6d04d`, source/input hashes reverified.

Results from the *final* Windows execution:

| Trial | Original uploaded-mask pose: held sampled positions | Guarded pose: held sampled positions | Guarded safe live admissions | Explicit fallback for unknown previous texture |
|---|---:|---:|---:|---:|
| No Fire / Free camera | 7 | **0** | 97 | 0 |
| No Fire / Follow camera | 11 | **0** | 115 | 0 |
| Fire ON then OFF / Free camera | 9 | **1** | 90 | 33 |
| Fire ON then OFF / Follow camera | 10 | **1** | 92 | 26 |

Each Fire arm inserted **exactly 20 actual Fire cells** through the real nozzle; No-Fire arms inserted zero. Every paired comparison had **0.0 maximum Rapier position difference** and **0.0 maximum Rapier velocity difference** across matched sampled physics ticks. The safety oracle passed **21/21** checks; existing Workbench input **24/24**. All eight graphical trials completed 220 physics ticks and produced eight actual framebuffer PNGs each. The reducer verified the real renderer/Windows/native identities and preserved original screenshots.

**Real-World safety gate:** The separate [native-World probe](../../godot/tests/test_pr566_mask_coherent_native_world.gd) installed a fresh genuine 512×512 authored Wall, verified material ID **58** at world pixel `(260,345)` in the acknowledged CPU→GPU material image (World generation 3, revision 3). A swept candidate flyer crossing that Wall was refused **`material_in_swept_mask` after scanning 160 cells**; a nearby unobstructed move was admitted after **225 cells**; an unknown active previous texture was refused. **7/7** real-World host assertions passed on Windows.

### Linux source-matched execution

- [Exact-source Linux CI 43587729551 — SUCCESS](https://github.com/techrote/cybersand/actions/runs/43587729551), source `453bba55648176c29e395ca3297b9442f4e05509`.
- [Linux original native logs, Workbench results and real X11 graphical frames](https://github.com/techrote/cybersand/actions/runs/43587729551/artifacts/14111310477).
- Reused PR #566 *independently qualified Linux GDExtension* SHA-256 `44c906356a98c84b09c01f6e83bcae2391a4c0e39c5c632431a4a3f4cc1578e9`, exact native source input hashes, pinned Rapier and official Godot 4.7.
- Safety oracle **21/21**, real native-Wall veto **7/7**, Workbench input **24/24**, Workbench fleet **88/88**, and full `test_workbench_physics_play.gd` completed without failures. Real Linux X11 Compatibility GL rendered Fire/Smoke Free/Follow, with **20 actual Fire insertions** and 8 PNG captures per camera, **152/156 safe live admissions**. No native World or physics change.

## Safety and remaining acceptance

**Proven within the declared contract:** the guarded presentation rejects known visible material intersections in native-oriented swept collider geometry; its old-frame blend mask is bounded/fail-closed; native physics trajectories and source provenance are unchanged; actual Windows and Linux tests show a large reduction in sampled overlay holds.

**Not yet proven:** whether the precise Owner Windows physical NVIDIA GPU/monitor displays no double-image under their customary high-speed pilot movements, all DPI scales and VSync configurations; robust feel across densely loaded biomes, multiple crowded actors or arbitrary long-lived embedded-material contacts; a broad CPU/GPU p95 regression claim under target hardware; bytewise native transient mask comparison under every rotating compound collider. Existing hard-Wall integration tests prove the guard's veto from real stored material but do **not** prove contact-rich live-play performance.

The appropriate next gate is **Owner physical Windows 11 GPU retest** on the guarded candidate, particularly Fire ON→OFF, high-speed Free/Follow camera and movements near/through authored sand, water and hard terrain, then consider a separately qualified retained-snapshot interpolation/design if the guard's fail-closed holds remain objectionable in material-dense scenes. Do not replace the guard with unconditionally live pose as a purported repair.

**Disposition:** this is a source-qualified **candidate** staged on [Draft #593](https://github.com/techrote/cybersand/pull/593). Parent #566 remains Draft/HOLD, both PRs unmerged, and `main` unchanged by this work. No Ready/merge tag or release was performed.
