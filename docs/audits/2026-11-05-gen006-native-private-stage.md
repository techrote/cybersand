---
title: GEN-006 native private-stage semantic bundle discriminator
status: Planned
document-kind: audit
scope: Experimental owner-side whole-World staging boundary, not a production streaming or selective-restore implementation
last-reviewed: 2026-11-05
related-documents: [../systems/world-storage-and-interest-region.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/level-saves-and-replay.md]
---

# GEN-006 #194 — private native bundle staging, refusal and three-tick continuation

**EXPERIMENT ONLY; retain Draft; DO NOT MERGE.** This diagnostic deliberately does not change production code, expose a new native API, implement eviction/reload, choose a persistence format, or authorize live World replacement. It uses a whole-World CYPS checkpoint as an **ephemeral** private candidate copy only for the subset of state that the current native format can preserve. It is not an endorsed transaction design.

## Source/ownership intake

Repository `techrote/cybersand`; accepted main on 5 November 2026 `ba9cbc89029be88b812af59b19e5c59829bbcd90`, tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`. Read root `AGENTS.md`, development handover, canonical storage/interest, procedural generation, ownership, level saves, ADR-004 and GEN-006 #194. No nested AGENTS files existed under the changed directories when checked. Other GEN-006 experiments remain separately owned: #415 disk ACK/fault model, #422 whole-World vs material-only native restoration, #426 native generator demand/session/race and budget, #435 optional native state/actor pin refusal, #442 sequential semantic bundle partial-commit demonstration. #230 is a proposed nonproduction codec and #398 historical MoltenGlass importer migration is unresolved. MAT-AUTH/SOL/LCB and any player/workbench writers remain untouched.

Current `World::install_generated_chunk` accepts only one *absent* chunk, refusing resident Empty, over-capacity or invalid material spans; it does not supply semantic bundle atomicity. #442 demonstrated the expected partial-commit outcome when a host installs west before a refusing east chunk. This experiment instead probes a **separate, test-only** publish boundary: recreate a private World using the current whole-World checkpoint, install both halves privately, discard the candidate if either refuses and publish its pointer only if both succeed and owner identity still matches.

## Registered experiment

`native/tests/test_gen006_private_bundle_stage.cpp` builds unchanged production `World`, `material_rules`, `scheduler_geometry` and `settled_world_discovery` into a test executable. Scenario: an anchor at signed chunk (-9,0) and an exactly two-cell Wall connection crossing world x = -1/0, y = 64 in generated chunks (-1,0) and (0,0). The host model carries a session, recipe and monotonic mutation-generation stamp; these are **test harness fields**, not existing native transaction receipts. The configured resident cap is four (two in the capacity-failure control), with worker settings of 1 and 4, parallel threshold 1.

The preregistered controls are:

1. **Resident Empty east:** the strict installer refuses the second half. Private candidate is discarded, original chunk count/hash and absence of both bridge halves remain unchanged.
2. **Only one free resident slot:** west stages but east returns capacity refusal. No staged west is visible in the original.
3. **Malformed later payload:** invalid east material refuses and leaves the original unchanged.
4. **Retired session:** an old receipt is refused before candidate preparation.
5. **Intervening live mutation:** a deterministic before-publish hook edits the anchor and increments the harness mutation generation. The old staged candidate must refuse; the edit must remain live with neither seam half published.
6. **Actor pin/unsupported optional domain:** explicit harness pin and sidecar flags refuse candidate adoption. A real native transient obstacle ID 7 is verified unchanged after the pin refusal. **These flags are not proof of a production owner pin registry**.
7. **Restricted positive control:** both halves stage and publish together. A separately constructed native World with the same anchor and both halves supplies an exact physical-state-hash and quantity-ledger reference over three actual subsequent ticks for each worker configuration.

These checks only show that whole-World private staging can avoid the #442 *visible partial-commit symptom* in a restricted native harness. They do not establish complete transaction safety: a real host must fence immutable snapshot leases, sidecar and actor ownership, material-state policy, session/recipe/mutation/incarnation identity, native scheduler reservations, external readers and Godot/Rapier publication. Whole-World CYPS does not preserve all optional witness/body-mask/host domains (#435); it is not a per-chunk save and cannot become a general GEN-006 eviction codec. Cloning the entire World also has unbounded world-scale cost and is expressly **not proposed as a production implementation**.

## Execution and evidence

Branch-specific GitHub-hosted `ubuntu-24.04` `g++-13` job, bounded at 25 minutes. Run:

```sh
g++-13 -std=c++20 -O0 -g1 -pthread -Wall -Wextra -Wpedantic -I native/include \
  native/src/world.cpp native/src/material_rules.cpp \
  native/src/scheduler_geometry.cpp native/src/settled_world_discovery.cpp \
  native/tests/test_gen006_private_bundle_stage.cpp -o /tmp/gen006-private-stage
/tmp/gen006-private-stage
```

Workflow: `.github/workflows/gen006-native-private-stage.yml`. The workflow checks `GITHUB_SHA` against checked-out HEAD, records source SHA/tree, GCC version and provider policy, retains *original compile and run failure logs*, and uploads source-matched evidence even on failure. **Execution status is not established by this registration document**; only completed source-matched logs and run conclusions can change it to PASS/FAIL. No Windows, Godot, real camera/actor ownership, worker overlap, cross-process durability, interruption recovery or native selective eviction is claimed.

## Next owner decision

The observed #442 partial-commit limitation and this narrowly scoped private-stage experiment should drive **a reviewed owner-mediated two-chunk admission transaction**: prevalidate all chunks and receipts, reserve quota and exclusive owner/lease boundary, fence session/incarnation/recipe/mutation and optional sidecars, then publish all related chunks atomically or refuse without modifying World. Choose and approve the native transaction primitive only after its bounded memory, cancellation, external visibility and failure semantics are established. The first genuine dirty-save ACK → pin-aware selective eviction/reload → fixed-tick continuation remains the subsequent GEN-006 gate.

Keep GEN-006 #194, MAT-003PREPASS #204 and MAT-AUTH #352/#353/#354 open. No Ready state or merge from a passing experimental workflow.
