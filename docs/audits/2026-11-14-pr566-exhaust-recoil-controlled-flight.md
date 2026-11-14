# PR #566 — real Rapier / Fire–Smoke recoil diagnostic: four-arm result

**Status:** Tested, automated qualification PASS for experiment execution; **causal verdict remains limited**. This evidence is diagnostic only and does not authorize a merge or production fix.

**Authoritative camera PR:** [#566](https://github.com/techrote/cybersand/pull/566), evaluated parent `214de85adef2aaabc8e26de8612a3bf27cc1a081`.  
**Isolated experiment head:** `a37404ba34d6b2b675aa4336319de95bf9b2cb99`.  
**Completed source-built experiment:** [GitHub Actions run 43561255396](https://github.com/techrote/cybersand/actions/runs/43561255396), completed SUCCESS on Linux Godot 4.7 / Rapier2D v0.35.2.  
**Original per-tick records and reducer:** [artifact 14100387637](https://github.com/techrote/cybersand/actions/runs/43561255396/artifacts/14100387637), includes `trials/{nofire_normal,nofire_suppressed,fire_normal,fire_suppressed}.json`, logs and `recoil-summary.json`.  
**Source:** [narrow native diagnostic](../../godot/native_extension/cyber_native_cell_world.cpp), [actual-host flight fixture](../../godot/tests/test_pr566_exhaust_recoil.gd), [reducer](../../tools/ci/reduce_pr566_exhaust_recoil.py).

## Original physical question

The Owner reproduced a speed-dependent, flickering double-image/tail after enabling Workbench **Thruster fire**, persisting after the switch is disabled and with Free camera; **Restore start** clears it. A historical barrel defect had allowed material to become trapped in a Rapier mask and deliver repeated opposing impulses. The code path is real: `reconcile_overlap()` may retain an unresolved stored cell and deliver an unscaled recoil before body-level caps. However, a source-level possibility is not proof of occurrence in this flight.

The experiment tested whether **actual** Fire/Smoke unresolved recoil causes actual Rapier oscillation, rather than inferring physics from the displayed image. The only variant difference was the opt-in environment variable `CYBERSAND_DIAG_SUPPRESS_EXHAUST_UNRESOLVED_RECOIL=1`, disabling the impulse contribution for *unresolved Fire/Smoke overlaps only*, without removing the cells, modifying emission or suppressing any other contact path. Suppression was OFF by default and restricted to this isolated branch.

## Controlled experiment

Four fresh Main/native-World/manual-step Rapier sessions, with exactly the same authored Kestrel, flight controls, 512-cell canvas, and 220-step trace:

| Arm | Thruster Fire | Unresolved Fire/Smoke recoil | Actual Fire insertions |
|---|---|---|---:|
| nofire_normal | OFF throughout | Normal | 0 |
| nofire_suppressed | OFF throughout | Suppressed | 0 |
| fire_normal | ON for a bounded middle interval, then OFF | Normal | 20 |
| fire_suppressed | ON for the same interval, then OFF | Suppressed | 20 |

Across each completed source-built host run, there were no reported native step failures. Fire-enabled runs actually admitted twenty authored Fire cells through the real main/side nozzle paths (receipts: ten `main-fire` and ten `side-fire`). The surrounding world was deliberately open; it was **not** a forced embedded-material positive control.

## Result: physics negative in this scene; presentation discrepancy positive

- **No unresolved Fire/Smoke overlap was observed** in any arm; the sampled values of both `diag_exhaust_unresolved_fire` and `diag_exhaust_unresolved_smoke` were zero. The recorded candidate recoil, actual native wrench and applied cellular impulse were zero.
- **Rapier trajectories matched numerically.** Comparing corresponding ticks against nofire_normal yielded a maximum position difference of **0.0 world pixels** and maximum velocity difference **0.0 world pixels/s** in each of the other three arms over all 220 matching ticks. No physics oscillation was induced by the Fire used in this open-air fixture.
- **Fire changed world publication.** In the fire_normal arm, during the 60-observation fire window, the uploaded texture held 41 unique render serials, with a later observed actual render publication rate around **44 Hz**. The nofire arm had one unchanged render serial throughout; its material texture was static. Render publication remained active after Fire was disabled because the native material lifecycle continued.
- **Displayed Rapier pose fell behind.** Over the 60 fire-window observations, the fire_normal arm had **29** instances where the pose frame was one native sample behind (no-fire: **0**). Across the following 121 observations after Fire was OFF, there were **60** such instances (no-fire: **0**). The suppression arm had **27/60** and **61/121**, respectively. These are sampled process-frame counts, not independently timed physical-GPU frames.
- **Visible pose holds and catch-up jumps:** In fire_normal, adjacent displayed positions were identical over **17/59** fire-window intervals and **35/120** after-OFF intervals; in nofire_normal those counts were **0/59** and **0/120**. The maximum distance between the current Rapier pose and the displayed pose increased from **1.9561** world pixels (nofire_normal, post-OFF) to **3.9050** (fire_normal, post-OFF). The 95th percentile of displayed position step magnitudes in the post-OFF interval increased from **1.9352** to **3.7303** world pixels per observation. That hold-then-jump pattern is compatible with the Owner's speed-dependent flicker/tail.
- **There was no effect of recoil suppression** on either the Rapier trajectory or the displayed pose-hold mechanism in this fixture. This is expected given that no unresolved Fire/Smoke overlap occurred and does not qualify suppressing recoil as a fix.

The actual pose discrepancy arises from an existing deliberate contract: `main.gd::workbench_display_frame()` uses `latest_snapshot.lab_context.workbench_display` only if its material revision is the uploaded revision; otherwise it returns `_uploaded_workbench_frame`, a pose tied to the last accepted material texture. `physical_actor_session.gd::render_parts()` and `workbench_physics_bridge.gd::display_pose()` use that pose for drawing. With static material the live frame remains revision-matched; with continuous Fire/Smoke publication the overlay can hold its previous pose for an extra physics interval, then jump.

## Evidence boundaries

1. The experiment **does not reproduce unresolved Fire/Smoke recoil** under these open-air conditions; trapping remains possible in more confined conditions and the pre-existing embedded-Sand issues are not refuted.
2. The headless trace provides **strong evidence for a display-pose cadence mechanism**, but it does **not** contain physical Windows GPU framebuffer recordings. It cannot prove that this is the only contributor to the Owner's double-image tail.
3. Native rendering data were measured under Linux host conditions, not Windows graphics drivers. Preserve source-parent identity and do not extrapolate measured publication Hz to physical Windows GPU.
4. The experiment's **successful workflow** is successful execution and integrity, **not a qualified production repair**. PR #566 remains Draft/HOLD.

## Recommended next bounded diagnostic

In the isolated experiment branch only, run a **presentation-only** A/B that preserves the exact physics / contact and material stream but compares:

- **Current** `workbench_display_frame()` actor pose tied to the uploaded material revision.
- **Diagnostic live-pose overlay**, for visual comparison only, derived from the actual current Rapier RID, with per-frame current-vs-uploaded pose age and material-mask alignment logged.

Capture actual consecutive Windows GPU frames in Free and Follow modes with Fire ON, then OFF, and correlate hold/jump counts and double edges. A direct live-pose overlay is **not** automatically a safe production fix: evaluate whether moving the drawn actor ahead of the native masked pixels causes visible material/body interpenetration. If so, engineer a coherent presentation model rather than silently abandoning the native-mask revision contract. Preserve the smooth camera implementation, remaining physics contact constraints, and the no-merge gate.

**Disposition: The Owner's fire-triggered symptom is not yet visually requalified. #566 stays Draft/HOLD.**
