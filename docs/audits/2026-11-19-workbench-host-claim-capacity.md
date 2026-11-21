# WORKBENCH-HOST-CLAIMS-001 — large original landscape admission

Date: 2026-11-19. Source parent: `de109d0131641d6adc8d25bb9ced7ca3d4991105`.

## Failure

Workbench-generated MicroScenario definitions contain a flat `rectangles` Array of
`[x,y,w,h,material]` words (five integers per rectangle).
`godot/scripts/liquid_host_evidence.gd::_claims` rejects an individual Array
whose `size() > 32768`, whereas native Workbench construction is permitted up
to **32,768 rectangles** (`CyberMicroScenarioContract.WORKBENCH_MAX_RECORDS`,
`CyberDemoBridge.workbench_start_rectangle_capacity()`). These are separate
contracts. An authored Setup with at least 6,554 construction rectangles passes
the source Setup-v2/recipe limits but fails *before native commit* when
`microscenario_host.gd::_prepare_liquid_host_observation` passes the entire
definition through `HostEvidence.collect`.

Observed UI: `Refused · Host claims exceed the pure value/depth/capacity contract`.

## Original map reproduction matrix

| Level | Committed rectangles | Flat claim words | Old per-container outcome |
|---|---:|---:|---|
| Thunderclap Switchyard | 12,609 | 63,045 | REJECT |
| Morrow Array | 11,657 | 58,285 | REJECT |
| Cinderwake Dual Harbour | 12,166 | 60,830 | REJECT |
| Graftloom Slipway | 13,839 | 69,195 | REJECT |
| The Meridian Scar | 12,384 | 61,920 | REJECT |
| Stormline Pneumatic Port | 9,167 | 45,835 | REJECT |
| Nacre Fusion Observatory | 10,080 | 50,400 | REJECT |
| Pyrewater Quarantine Ring | 2,834 | 14,170 | below this limit |
| Ashlight Counterflow Foundry | 3,994 | 19,970 | below this limit |
| The Long Pour | 4,092 | 20,460 | below this limit |

Values above are independently calculated from the original ten committed
Setup JSON payloads, including two local candidate maps.

## Narrow repair

Only the **unverified host-evidence observation claim** for a validated Workbench
definition is projected when it would violate the 32,768-value *per-Array*
evidence limit. Full `checked.definition`, including all ordered rectangles,
continues to be passed unchanged to `bridge.prepare_liquid_world`; the validated
definition SHA-256 remains `checked.hash` and is included in the projection.

The observation explicitly records that the rectangle array was omitted, its
exact five-word rectangle and total-word counts, the hash of the validated
**complete** definition and the limited unverified-host-claim scope. It must not
be mistaken for full executed-host proof. No scenario law, native rectangle
limit, global claim budget, or serialization refusal criterion changes.
Non-Workbench scenarios keep their full original claims and refusals.

Existing in-envelope Workbench definitions remain byte-for-byte equivalent in
the `host_claims` input. Large definitions use the explicit
`definition_projection` field.

## Tests

Pure Godot regression: `godot/tests/test_workbench_host_claim_capacity.gd`.
It checks Workbench 6,553 vs 6,554 rectangle boundary, representative 9,167 and
13,839 original maps, full 32,768 rectangle source limit, unchanged original
definition data, preserved complete-source hash, non-Workbench refusal and
unsupported object rejection.

Run from a source-matched Godot 4.7 checkout:

```
godot --headless --path godot --script res://tests/test_workbench_host_claim_capacity.gd
```

Static data analysis and source-level code review are distinct from executing
the Godot regression. Do not claim a native PASS without actually running the
updated source and compatible Windows/Linux GDExtension with Setup loading,
actor movement/collision/simulation and a fresh-process save/reopen.

## Remaining independent installed-runtime gate

Old **installed** CyberDemoBridge builds can still report 4,096 construction
rectangles. The source-advertised 32,768 rectangle capacity and this observation
fix do not upgrade an old DLL. The actual installed native bridge capability and
Midge/Rapier/save-reopen acceptance must be checked separately.

Keep this PR Draft/HOLD. Do not merge, mark Ready or automatically promote the
original map PRs.
