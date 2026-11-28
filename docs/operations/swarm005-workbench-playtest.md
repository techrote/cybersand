---
title: SWARM-005 experimental Workbench owner evaluation
status: Current
document-kind: guide
scope: Frozen SWARM-005 donor controls, historical synthetic reproduction and separate physical owner acceptance
canonical-for: [swarm005-workbench-owner-evaluation]
last-reviewed: 2026-11-21
related-documents: [swarm004-workbench-playtest.md, ../architecture/experimental-workbench-authoring-patch.md, ../systems/gentek-reciprocal-assembly.md]
---

# SWARM-005 experimental Workbench owner evaluation

**Draft/HOLD only.** Native pilot: issue #695, PR #696. Experimental integration: PR #697. This is a new source/binary identity, not a replacement for the prior qualified SWARM-004 evaluator.

**21 November integration note:** the [current integration runbook](swarm45-mainline-integration.md) supersedes the outstanding-holdout wording below: #698's registered matrix is complete and negative. The hash below belongs to the frozen donor, not the reconstructed integration. Current exact-source/runtime/package and physical-owner gates remain separate.

Under **Reciprocal assembly...**, two additional options are **OFF by default**:

- **Source-feasible terminal parts (SWARM-005):** a true source-time welded steel part where the incoming authored source connector and native geometry can support it; no retrospective discharge of already-required foreign connectors.
- **Source-bound MOSAIC receptors (SWARM-005):** source-backed typed receptors only where native MOSAIC masonry and original FRAME requirements can meet. The original final path, ownership, budget and hard-closure validation remains authoritative.

Enabling either option emits the explicit SWARM005 V3 protocol, retaining separate FRAME/MOSAIC knobs, territory-sharing bit and both option bits. With both OFF the earlier SWARM004 V1/V2 text protocol is unchanged. Do not substitute the old Windows ZIP; its native source definition and runtime manifest are different.

## Reproduction from the owner's blocked examples

Use a fresh paused blank 512×512 native world; dab around (64,48), ensuring 192×112 crop origin (0,0), seed **605**, rounds **2**, width **192**, height **112**, **FRAME left / MOSAIC right**, border **4**, reach **13**, negotiated territory sharing **ON**, optional negotiation **ON**, balanced orientation and destruction **0**. Choose **Irregular Megastructure**, independent overrides disabled, variation 0.65, branching 1.0, irregularity 0.95, environmental affinity 0.7, cohesion 0.2 and decoration 0.25.

1. Both new switches OFF: Generate. Capture native Blocked/Complete status, unresolved obligations and material count. **Do not Apply if Blocked.**
2. Switch ON only source-feasible terminal parts, Generate again, inspect Joints/Unresolved and compare native source receipts. In a **headless blank synthetic native fixture**, this exact geometry was Blocked with 6034 occupied cells and one hard obligation; with the new source-time option, **Complete/Apply-authorized**, 6026 occupied cells and zero outstanding obligations.
3. Switch both ON. Repeat and record separately. The same native fixture was again Complete with 6026 cells. No additional foreign joints are claimed: a genuine source-time local cap is not a foreign join.
4. Only if the native validator genuinely authorizes Apply: Apply, Undo, regenerate, Apply, save an ordinary start map, fully exit Workbench, relaunch and reopen. Verify entire native material plane and evidence checksum.
5. Repeat with **Viaduct-like** keeping all other settings. The synthetic source fixture still **Blocked** with new options; never treat this negative as a success. Industrial remains to be evaluated.

The synthetic native fixture is **not** a substitute for the owner's exact saved/painted 2048×2048 world, captured protected cells or physical Windows/NVIDIA test. It cannot prove player collision quality, real GPU behavior or load-bearing stability.

## Qualification
- The native test is deterministic, bounded, paired and checks true original closure/Apply, not a visual screenshot.
- The new source-bound compiler hash is 12a4816dab749a9c872a4d531836db8ec6a170aab31576d70086efa80eeb3b6b.
- Independent review, preregistered held-out cases, exact source-matched graphical Windows capture and pristine ZIP reopen, then explicit owner acceptance are still required before any Ready or merge.
