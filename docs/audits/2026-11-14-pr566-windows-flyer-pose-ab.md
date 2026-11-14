# PR #566 — Windows graphical flyer-pose presentation A/B, 14 November 2026

**Disposition: Investigation complete; production fix and physical-GPU acceptance remain HOLD.**
This is a read-only diagnosis of the presentation mismatch, not acceptance to merge [PR #566](https://github.com/techrote/cybersand/pull/566), to modify native physics or to silently abandon material-mask/actor consistency.

## Exact sources and observed runs

| Role | Identity |
|---|---|
| Owner-evaluated camera PR | [#566](https://github.com/techrote/cybersand/pull/566), Draft/HOLD, source `214de85adef2aaabc8e26de8612a3bf27cc1a081` |
| Actual Windows graphical execution source | `1905b0087b044a0798dde6a24e4ddcc56c0f4c59` |
| Read-only corrected reducer source | `41f1c347d6c13216e6ac4b7e71c048545710239a` |
| Hosted Windows 2022 graphical campaign | [run 43583366027](https://github.com/techrote/cybersand/actions/runs/43583366027), **8/8 physical+graphical processes PASS**, original Python aggregate FAIL solely due to assuming >=190 distinct render observations |
| Original eight-arm evidence | [artifact 14109053892](https://github.com/techrote/cybersand/actions/runs/43583366027/artifacts/14109053892), **64 actual PNGs**, all 8 GDScript logs, per-observation pose/World records and source identities |
| Independent correction/reduction | [run 43584091153](https://github.com/techrote/cybersand/actions/runs/43584091153), **SUCCESS**; eight original arms/64 PNGs/four paired physical trajectories revalidated; expensive hosted Windows trials not rerun |
| Independently reduced report | [artifact 14109383272](https://github.com/techrote/cybersand/actions/runs/43584091153/artifacts/14109383272) |
| Exact reused qualified native | [PR566 Windows build artifact 14090443146](https://github.com/techrote/cybersand/actions/runs/43537909868/artifacts/14090443146), SHA256 `6c7811b78c12e34a68931f83f2fd505c20078c089bce245a9be8be6e02e6d04d` |

The test branch starts at evaluated PR #566 and changes exactly **one existing application file**, `godot/scripts/main.gd`, by adding a GDScript-only, default-off environment selection immediately before `physical_actor_overlay.present`. Four new files contain one graphical test, runner, reducer and CI workflow. Native source, Rapier, physics session, worker, shaders, rendering transport, camera transform, input, material/World bytes and tests remain unchanged.

A/B selection: `CYBERSAND_DIAG_FLYER_POSE=mask` (default) retains `workbench_display_frame()` and `WorkBenchBridge.display_pose()`'s **uploaded material-revision-matched** pose. `=live` supplies an empty presentation frame to the existing renderer, activating `WorkbenchBridge.display_pose()`'s existing **current Rapier body transform** fallback. No native/physics result, World update or ACK path is modified.

## Experimental controls

Eight fresh 512² native World sessions, same Kestrel, identical deterministic 220-step Rapier control stream with modest positive-x/negative-y thrust. Thruster fire is OFF in four arms; ON during the bounded middle interval then OFF in four arms. Camera is independent (Free or Follow), and flyer visual pose source is independent (native-revision mask-bound or live Rapier).

Each arm:
- Executed in a real **Windows** rendering DisplayServer using pinned **Godot 4.7 OpenGL Compatibility / ANGLE**, not `--headless`, with the exact qualified PR566 native DLL and pinned Rapier2D.
- Produced its entire flight, actual Workbench native publication receipts, per-render-callback Rapier position/velocity, current and bound display poses, and eight **actual root-window framebuffer** images.
- Was independently checked for real Fire insertions (exactly 20 in either Fire arm, zero in no-Fire), zero GDScript test assertion failures and the correct graphical renderer.
- Reused no material or physical session between arms.

Actual hosted renderer sample counts are **121–163** per 220 Rapier ticks. The initial reducer incorrectly demanded >=190 render samples, yielding a failed overall workflow despite eight successful engine processes. The corrected reducer verifies terminal tick >=215, >=90 render samples, >=70 *matched* physics sample ticks, eight PNGs per arm, and every PNG's readback dimensions and selected actor pose. This is read-only qualification of the original exact files.

## Results

| Comparison | Mask-bound visual pose | Live-Rapier visual pose | Matched physical observations |
|---|---:|---:|---:|
| No Fire · Free camera · repeated drawn position | 13 | **0** | 94 |
| No Fire · Follow camera · repeated drawn position | 12 | **0** | 115 |
| Fire ON then OFF · Free camera · repeated drawn position | 15 | **0** | 79 |
| Fire ON then OFF · Follow camera · repeated drawn position | 9 | **0** | 75 |

Across every matched observation in all four pairs, maximum live-Rapier position difference **0.0000 world px** and maximum live-Rapier velocity difference **0.0000 px/s**. Both variants draw the same authoritative physical trajectory; only the display-pose source differs.

For Fire ON/OFF under Free camera, the 95th-percentile distance between **render-observed drawn** and current live positions falls from **7.529 world px (mask)** to **3.901 (live)**. Under Follow, it falls **7.885 → 3.853**. Nonzero remaining live-mode error is due in part to the per-`process_frame` observation occurring on a different callback phase from the actual `_process()` redraw; importantly, at all 64 actual framebuffer capture receipts, the engine's drawn overlay transform matches its **selected mode's** pose with recorded error 0.0.

One maximum measured native-mask-bound/current-live pose separation under Windows is **9.768 world px** in the Fire/Follow arm. Slow hosted rendering can also produce nonzero pose age without Fire; do not call this a Fire-only coupling defect. The Fire-specific effect must be read against the no-Fire controls and the previous Linux fixed-cadence test.

**Geometry/mask tradeoff:** the native material-published sample also identifies the mask geometry the cellular World used. Projecting the exact authored Kestrel collider rectangles under the native-revision and current-Rapier transforms produces a maximum symmetric difference of **44 world-cell positions** in the original Windows captures (and 28 in the Fire/Follow live arm). This is a **geometric footprint mismatch**, not 44 physically embedded Fire cells. A live-only visual overlay can run ahead of what the latest uploaded material/mask frame represents and may expose apparent pixel/body intersections during dense contacts. A raw native transient mask-byte comparison or a contact-rich scene is still needed for complete safety acceptance.

**Other observation:** in this open-air flight, no native Fire/Smoke overlap/recoil was observed; this independently aligns with the previous [four-arm physics diagnostic](https://github.com/techrote/cybersand/actions/runs/43561255396), which measured zero unresolved Fire/Smoke recoil and identical Rapier trajectories. Historical embedded-Sand defects are neither disproven nor repaired.

## Frame inspection and limitations

The raw Windows PNGs in artifact 14109053892 show the independently drawn body and its real Fire particles under both modes. Enlarged comparisons of the frame crops (drawn from the original PNGs with nearest-neighbour enlargement, no image synthesis) reveal small position differences between mask-bound and live modes at nominally matched requested ticks. Windows engine animation/time and capture tick can differ by 0–2 ticks across separate processes; **do not treat per-pixel PNG subtraction as an exact same-frame shader difference**.

Actual temporal hold/jump is established by callback pose observations, not by extrapolating flicker from isolated still frames. The runner is hosted Windows with ANGLE; it **does not establish GPU-vendor-specific behaviour, physical GPU scan-out, vsync, 125–200% DPI, or Owner feel**. Those remain separate Owner acceptance gates.

## Engineering conclusion and follow-up gate

The controlled A/B demonstrates a **presentation-timing artifact in the revision-locked flyer overlay**, without an underlying Rapier trajectory change. Live pose is a useful diagnostic and removes observed sampled holds, but **is not an approved production solution** because the displayed body can diverge from the native material/mask sample by up to a multi-cell footprint.

The next authorized production change should deliver one coherent pose/material presentation contract rather than indiscriminately changing `workbench_display_frame()` to current physics. Candidate designs include bounded interpolation between confirmed mask poses, or a synchronized render-time actor pose lane that explicitly accounts for the current material-mask sample. Explicitly test contact-rich Fire/Smoke, Sand, Water and walls, rapid camera movement and zoom; preserve cell conservation, Rapier authority, exact source/runtime identity and default PR566 camera behaviour. Request a separate Windows physical-GPU owner retest before Ready/merge.

**Status: diagnostic COMPLETE; PR #566 remains Draft/HOLD; no production fix accepted.**
