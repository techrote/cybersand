# WB-ART-SLM-001 Controls — original native coral visual review (13 November 2026)

**Scope:** visual inspection and exact stored-material measurement of previously executed v1 reference art; **not** v1.1 native qualification, a new model, or a new graphical/runtime run.

## Grounded artifact and source

* Original historical Linux native source: `90719c72b9fcf90593fb7878354051ad601b47fd`; not accepted main or a Windows build.
* Recovered owner Library archive `wb_art_slm_001_native_and_model_evidence.zip`, **29,081,943 bytes**, SHA-256 `d2f8b16f081b7c371afd2eadf1468bc6941cb2a7a83ee349a11d667257f9cfa9`.
* Extracted `native/teacher-evidence.zip`, SHA-256 `2381736839bfca8ad6b4563a1c77698140438ef39ee8f0a6529f23cae4f1f62b`.
* Selected actual pre-existing `native_full_01/coral-v{0..7}-m0-s{17,73}.png` plus each matching original `.materials.i32le` 96×96 native stored-material crop and `.receipt.json`. No generated drawings substitute for native.
* A 16-panel contact sheet, all 16 original PNGs, their exact binary material crops, per-case SHA-256s and measurements were organized into an owner-visible companion archive `CyberSand_Coral_v1_Original_Native_16_Review.zip` (118,628 bytes; SHA-256 `9e25fdc737fbba5b9cd3ce5f5fa199fa70a2b0b0e2d377280b72d7abf735ffdb`). This companion is a conversation artifact, **not uploaded to Git**. The canonical native source data remain in the preserved owner Library archive above.

## Direct visual findings

In the six single-layer center/offset/split images (variants 0–2 at both seeds), the entire upper third has **zero occupied material-58 cells**. All variants and seeds combined have mean upper-third fraction **0.104738** of occupied cells, agreeing with the earlier independent v1 baseline report. The artwork tends toward thin, bottom-heavy coral clumps rather than tall, spatially distributed colonies.

The companion `branch` reference patterns (variants 4–6) visibly add a few largely disconnected stems, including floating small branches, rather than a coherent upper canopy connected to the primary coral. This is a qualitative visual observation, not a new numerical acceptance gate. Border variants 3/7 occupy upper/lower strips and preserve a large central void; they should not be forced into the center merely to increase upper occupancy. Seed 17 vs 73 changes local coral detail but does not solve the bottom-heavy silhouette in variants 0–2.

## Actual next action and blocked gate

The non-default `1.1.0-coral-spread` compiler should be inspected as **paired native World outputs**, not just source-level region coordinates. The existing 32-case fixture and fail-closed 20-method evidence auditor remain the canonical path: run `make_v11_native_pairs.py`, execute source-compatible `evaluation/run_native_replay.py --history each`, verify all global native gates and material readbacks, and render 16 matched v1/v1.1 seed pairs.

This execution environment recovered the published historical **native extension** but does **not** have the pinned Godot 4.7 Linux executable, the 117,275,416-byte source-matched Rapier Linux library, or a reconstructed source-matched Godot project. No genuine v1.1/native comparison was executed; **v1.1's visual improvement and all Windows/current-main acceptance remain unproven**. Do not promote, relabel baseline readbacks as new captures, or alter the frozen admitted v1 compiler hash.

Controls branch was read at `29f040f5edb9435b277c18c5cc80a5979849c2af`; existing code and audit tests were not modified by this checkpoint. PR #567 remains Integration-owned Draft/HOLD. Training's v5 re-train is a separate role responsibility. **No new model quality gain is claimed.**
