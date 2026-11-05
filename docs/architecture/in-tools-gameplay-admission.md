---
title: IN-TOOLS gameplay command admission — current-main successor
status: Planned
scope: Issue 361 current-main admission for opt-in inertial liquid leaks, drains, nozzles and gameplay usables; design and qualification authority only, not gameplay implementation
canonical-for: [in-tools-gameplay-admission, in-tools-command-ownership]
last-reviewed: 2026-11-05
related-documents: [../audits/2026-11-05-in-tools-361-successor-salvage.md, ../operations/in-tools-fixtures-and-playtest.md, ../systems/actor-usables.md]
---

# IN-TOOLS gameplay command admission — current-main successor

## Disposition

**Planned.** This document succeeds PR #379 as the current-main admission authority for issue #361. It does not make PR #379 current, does not import PR #383, and does not claim that the six proposed gameplay fixtures have executed.

Historical predecessor PR #379 is frozen at `e7e404b696fb9fc48cdadc95a69baf3a6f5fc6d1` / tree `3b5acd41fd7fb49ac8b06c94719fa1a700d8fd57`. Its actual-Windows `0xC0000005` shutdown result remains historical evidence tied to that exact source.

The successor base is current `main` `ba9cbc89029be88b812af59b19e5c59829bbcd90`, merged as #394. The exact source authority is registered in `godot/tests/fixtures/lcb/in_tools/in-tools-current-main-admission.2026-11-05.json` and verified by `tools/lcb/in_tools_current_main_admission.py`.

## Current behavior inherited from main

The existing U10 `liquid_drain` remains **Current** only in its present ordinary form:

- catalogue identity: `liquid_drain`;
- operation: `liquid_sink`;
- cooldown: 0.10 s;
- accepted cost: 0.85;
- range: 29;
- radius: 4;
- current physical usable path selects the existing declared liquid set.

This admission does **not** relabel the current U10 as exact-metered, finite-stock, native-command-authenticated or #361-complete.

Current main also owns the World, quantity ledger, Water normalization, IN execution, native adapter, simulation worker, physical actor session and the shared development workbench. The successor does not duplicate those owners.

## Minimal production authority

The reviewed current-main source set has eleven inputs:

1. `godot/scripts/usable_catalog.gd`
2. `godot/scripts/usable_runtime.gd`
3. `godot/scripts/physical_usable_script.gd`
4. `godot/scripts/physical_actor_session.gd`
5. `godot/scripts/simulation_worker.gd`
6. `godot/native_extension/cyber_native_cell_world.cpp`
7. `godot/native_extension/cyber_native_cell_world.hpp`
8. `native/include/cybersand/world.hpp`
9. `native/src/world.cpp`
10. `native/include/cybersand/water_normalization.hpp`
11. `native/src/world_inertial.inc`

Each path is bound to the exact Git blob present on the adopted main. The checker also refuses a successor that modifies any of these production authority paths while continuing to claim this admission.

The old #379 25-lock model is intentionally not reproduced. Its extra inputs described an older implementation topology and a specific #390 transition rather than the smallest current authority required for this design.

## Planned command contract

Any later #361 gameplay command implementation admitted under this successor must satisfy all of the following.

**Owner and source**

- Native C++ World remains the material authority.
- A Godot caller submits through the current exclusive owner/session route; no parallel material owner is introduced.
- Generation, session, policy and native owner identity are checked before application.
- Source/runtime identity is externally qualified; filenames alone are never evidence.

**Quantity and conservation**

- Sources have a finite explicit supply.
- Sinks account the exact actual quantity removed.
- Water uses its current quantity semantics; a whole-cell IN requirement may refuse unsupported fractional state rather than silently normalize it.
- Non-Water whole-cell liquids are counted according to their material contract, not by reinterpreting Water state bytes.
- Applied source/sink deltas are explicit. No hidden creation/destruction is permitted.

**Refusal**

- Preconditions are checked before mutation wherever the current owner can make that guarantee.
- A refused command preserves world state, quantity accounting and owner/session state.
- Stale generation/session/source requests refuse.
- Unsupported solver/material/geometry combinations refuse rather than falling through to ordinary edits while claiming the stricter contract.

**Time and geometry**

- Issue tick, accepted tick and resulting completed tick are unambiguous.
- Geometry is explicit and bounded.
- Width/radius/target caps are contract fields, not inferred from visual effect.
- Stop/close/reset semantics cannot authenticate a synthetic receipt after the fact.

**Readback**

- Qualification uses deterministic native/readback facts sufficient to verify actual quantity, refusal and resulting state.
- A caller-provided before/after hash is not authentication.
- Current workbench integration may host a future implementation, but no workbench-specific #361 command is Current here.

## Planned fixtures

The successor retains six concepts, re-registered as v2:

- `in-tools.valve-side.v2`
- `in-tools.valve-bottom.v2`
- `in-tools.sink-bottom.v2`
- `in-tools.sink-side.v2`
- `in-tools.source-channel.v2`
- `in-tools.usable-liquid-drain.v2`

All six are **Planned / NOT_RUN**. Their purpose is to qualify reversible openings, bounded sinks, finite sources and the first usable path under the current owner architecture. Details are in the runbook.

## Windows causal gate

Before broad successor qualification, the unchanged current equivalent of `test_liquid_desktop_default_host` is executed on an actual GitHub-hosted Windows runner with the source-matched committed runtime and natural process completion. Assertion result, natural completion, process exit, timeout, source commit/tree and runtime identity are recorded separately.

A zero assertion-failure footer cannot override a nonzero process exit. A green successor run cannot erase PR #379's historical failure. Godot #117991 remains a causal lead only; this admission does not patch or upgrade Godot to manufacture a pass.
