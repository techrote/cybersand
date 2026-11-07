---
title: IN-TOOLS successor fixtures and playtest
status: Planned
scope: Issue 361 current-main successor fixture definitions and acceptance intent; all successor fixtures NOT_RUN until implemented and executed
last-reviewed: 2026-11-07
related-documents: [../architecture/in-tools-gameplay-admission.md, ../audits/2026-11-07-in-tools-361-source-authority-renewal.md]
---

# IN-TOOLS successor fixtures and playtest

All six fixtures are **Planned / NOT_RUN** on newly adopted main `ab12ccef49ba2afaed2520d4d9a86eb14c7779cb`. These preserve useful concepts from #379 and Draft #404, but are defined against the renewed current-main owner architecture. Historical #379/#404 source or runtime outcomes do **not** qualify any new executable #361 gameplay command.

## Common acceptance rules

Every implemented fixture must record source commit/tree, runtime identity, solver/material policy, owner generation/session, issue/accept/result ticks, exact geometry, requested quantity, actual applied quantity, refusal reason where applicable, and deterministic before/after readback.

A refusal must leave material state, accounting state and owner/session state unchanged. A source must have finite explicit supply. A sink may only book quantity actually removed. A stop/close event affects only future uncommitted work.

## Six successor concepts

### `in-tools.valve-side.v2`

A bounded side aperture is opened and later closed while liquid remains under the current owner. It must demonstrate exact event timing, no mutation outside the declared aperture, deterministic close semantics and conservation across the admitted domain.

### `in-tools.valve-bottom.v2`

A bottom aperture exercises the same contract with gravity-aligned outflow. It must distinguish material leaving through the admitted geometry from material disappearing elsewhere.

### `in-tools.sink-bottom.v2`

A bounded bottom intake removes only admitted liquid. It records exact actual removed quantity and refuses when owner/session/source or capacity preconditions fail.

### `in-tools.sink-side.v2`

A side intake tests the same metered sink contract without relying on gravity alignment. Negative controls include stale owner generation, unsupported material/solver state and geometry outside the admitted domain.

### `in-tools.source-channel.v2`

A finite source injects only its declared supply into a bounded channel. Whole-cell geometric deposition and any future velocity-directed inlet are separate capabilities; the latter is not implied by the former.

### `in-tools.usable-liquid-drain.v2`

The first gameplay usable candidate starts from current U10 `liquid_drain` but must prove the stricter #361 contract separately: exact actual removal, finite owner-local allowance if introduced, stale request refusal, stop/reset behavior, deterministic readback and preservation of ordinary U10 behavior outside the opt-in profile.

## Windows precondition

Before broad fixture qualification, the successor executes the unchanged `test_liquid_desktop_default_host` on actual Windows. The run is a causal gate for the historical shutdown failure, not a substitute for these six fixtures.

## Human playtest boundary

Human feel, graphical usability and controller ergonomics remain unqualified by this admission. They become relevant only after executable successor commands exist and exact-source automated gates are satisfactory.
