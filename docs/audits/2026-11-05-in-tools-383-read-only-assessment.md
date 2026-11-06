---
title: PR383 read-only assessment against IN-TOOLS #361 current-main successor authority
status: Current
document-kind: audit
scope: Strictly read-only comparison of PR #383 with current main and Draft successor #404; no #383 source modification, integration or acceptance
last-reviewed: 2026-11-05
---

# PR #383 read-only assessment against successor authority

## Source custody

- Current main / successor base: `ba9cbc89029be88b812af59b19e5c59829bbcd90`.
- Successor authority: Draft PR #404, thirteen exact production inputs.
- Frozen historical predecessor: PR #379 at `e7e404b696fb9fc48cdadc95a69baf3a6f5fc6d1`.
- PR #383 observed head: `8f99d391f35708e665810e6732a6777baa7c2cf5`.
- PR #383 remains open, Draft and unmodified by this assessment.
- Against current main, #383 is diverged: five commits ahead of merge base `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1` and seventy commits behind current main.

The assessment distinguishes useful design intent from production-admissible bytes. Similarity to the successor contract is not acceptance.

## Classification

| #383 area | Classification | Assessment |
|---|---|---|
| `godot/scripts/metered_liquid_drain.gd` algorithm and its focused tests | **A — COMPATIBLE / SALVAGEABLE** as design/test material | Finite per-native-generation stock, explicit requested quantity, native instance/generation/policy binding, full preflight, actual post-write readback, refusal before destructive work where possible, and terminal quarantine after uncertain partial mutation align with the successor's conservation/refusal intent. The file itself is not current authority and must be re-admitted against current source. |
| Native quantity/census test concepts and parser/custody controls | **A — COMPATIBLE / SALVAGEABLE** | Independent Water-unit/Brine-cell census, exact applied sink accounting, finite-stock closure, stale-owner controls and partial-fault evidence are valuable successor implementation tests. Historical numeric results qualify only #383's tested source. |
| `physical_usable_equipment.gd` v2 request identity/readback | **B — REQUIRES REWORK** | `profile`, material, native generation, policy hash, World instance and quantity budget are useful identities, as is immediate retirement of released uncommitted work. This path is one of the successor's thirteen protected current-main authority inputs and has changed since #383's base; current bytes and owner lifetime must be reconciled first. |
| `physical_usable_runtime.gd` exclusive execution / terminal fault state | **B — REQUIRES REWORK** | Keeping destructive effects inside the existing exclusive physical-usable owner agrees with the successor. The persistent metered owner/stock and terminal latch need a fresh current-main implementation review, especially around current runtime publication, failure recovery and ordinary U10 behavior. |
| `physical_actor_session.gd` metered held-state/button-edge changes | **B — REQUIRES REWORK** | Immediate release/cancellation intent is useful, but #383 edits a protected current owner that has advanced materially. The old button-edge assumptions cannot be transplanted without current session/lifecycle tests. |
| `simulation_worker.gd` integration | **D — INCOMPATIBLE AS-IS** | #383 directly edits the exclusive worker owner from a source seventy commits behind main. Its patch is coupled to the pre-current execution-settings topology: current main routes scenario/window/cadence/adhesion through `apply_world_execution_settings(...)`, whereas #383 contains manual execution-setting writes in the same loop region. Direct reconciliation risks reintroducing stale ownership/settings behavior. Terminal-fault and cancellation ideas may be redesigned, but these bytes are not admissible. |
| `main.gd` / panel / UI integration | **B — REQUIRES REWORK** | Profile/material selection, cancellation on focus/pause and explicit metered readback are useful UX requirements. Current #394 shared-workbench/Main architecture has advanced substantially; #383's UI wiring is not current-main integration. |
| Existing ordinary U10 `liquid_drain` identity and ordinary physical usable behavior | **C — REDUNDANT / ALREADY PROVIDED** | Current main already provides ordinary U10. A successor implementation must add the stricter opt-in metered contract without relabelling ordinary U10 as #361-qualified. |
| #383 dated audits, exact test packets, runtime identities and old host results | **E — HISTORICAL EXPERIMENT ONLY** | Preserve as source-qualified evidence. They do not qualify current main, the #404 authority or a future implementation successor. #383 itself records Windows/native/Godot and human-input gaps; no result is promoted here. |

## Required future reconciliation boundaries

A later implementation successor may use #383 as design/test input, but should start from current main and re-derive the implementation through the thirteen-input #404 authority. At minimum it must:

- preserve current `apply_world_execution_settings` worker ownership and #394 workbench/session lifetimes;
- prove exact native instance/generation/policy identity using the current adapter/runtime;
- keep finite supply and actual quantity accounting independent for Water units and non-Water cell counts;
- prove that every normal refusal is non-mutating;
- retain explicit terminal quarantine for any mutation whose quantity/readback becomes uncertain rather than pretending rollback occurred;
- prove cancellation/release against the current physical equipment/session queues;
- preserve ordinary U10 outside an explicit opt-in profile;
- execute current Linux and actual-Windows source-matched qualification rather than inheriting #383's historical packets.

## Recommendation

**SALVAGE SELECTED COMMITS/FILES INTO A NEW IMPLEMENTATION SUCCESSOR**

Do not directly reconcile or merge #383. The metered-drain algorithm, focused quantity/refusal tests, request-identity concepts and terminal-fault evidence are valuable, but the production owner integrations are too stale and too entangled with superseded worker/session/Main topology for direct admission.
