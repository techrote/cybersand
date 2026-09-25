---
title: REM-003 sampled player↔granular C1 acceptance evidence
status: Current
document-kind: evidence
scope: Objective engineering evidence for issue #82 candidate C1; owner gameplay acceptance remains a separate open gate
canonical-for: [rem-003-player-granular-acceptance]
last-reviewed: 2026-09-25
related-documents: [2026-09-24-rem003-player-granular-preregistration.md, 2026-09-24-rem003-current-characterisation.md, ../systems/granular-interaction-policy.md, ../operations/development-claims-remediation-programme.md]
---

# REM-003 sampled player↔granular C1 acceptance — 2026-09-25

## Scope and frozen source

REM-003 / #82 keeps the shared version-1 8/9 downward and 9/9 side/upward
granular support classifier unchanged. Candidate C1 is a sampled-player-only
landing response: impact below 24 px/s causes no disturbance, 24..<72 may
relocate one supported foot-edge grain, and >=72 may relocate at most two.
Hard terrain, Water and unsupported grains do not enter the disturbance path.

Frozen candidate source is `2a5c99b9c3c9569bede3c37a80656f191b61eb84`,
tree `01b317e780061499e22ccac15b711a65cd69d04d`. The C1 native adapter remains
outside the public C ABI and does not change REM-002 generic Rapier body bearing,
Water semantics, soliding, INT-000 or transport profiles.

## Objective execution evidence

- Current pre-change baseline: `c4ebb4856b60ec8c85ea48d37313a38d0be1226c`;
  Documentation `36063834522`, GDExtension/Godot `36063834330` and Native
  `36063834321` passed.
- C1 native-source validation: Native C++ run `36071291457` passed on the same
  native/C++ inputs retained by the frozen candidate; later candidate changes were
  GDScript/reference-apparatus corrections only.
- C1 Linux runtime: GDExtension run `36075409671` built the source-matched Linux
  artifact used by the corrected recurrence below. Its build inputs are unchanged
  at the frozen candidate source.
- Corrected exact-runtime recurrence: validation run `36076161414` passed the
  schema-2 reference contract (**459 assertions, zero failures**), workbench,
  presentation, Water profiles, Web setup and `test_rem002_body_granular` on the
  exact C1 Linux runtime.
- Real Chromium: validation run `36075766808` passed both compatibility and
  threaded profiles. Both reported disturbance counts ordinary=1, hard=2,
  hard-terrain=0 and Water=0; threaded execution was cross-origin isolated.
  Compatibility artifact ID `10839389584`; threaded artifact ID `10839577941`.
  Built Web side-module SHA-256 values were
  `31a2fd0f1f219eca73af892bd0b4ca11e77670949575c57b5344f22d1366c171`
  (compatibility) and
  `59fa2555d86eccef2c0984bb553fc477ad01d433de1518f851df985d0f9cb3bb`
  (threaded), using Emscripten 4.0.20 and Godot 4.7.
- The reference-pack failure that produced three failed assertions was an apparatus
  defect: the newly added owner-review scenario rejected the three non-zero seed
  identities exercised by the shared contract. The corrected deterministic review
  definition passed independently in validation run `36075999430`.

Retained Linux/Windows runtime publication is a merge gate. The authoritative
published hashes and publication run are recorded in
`runtime-provenance.linux.json` and `runtime-provenance.json`; old runtime bytes
must not be relabelled.

## Preserved failures and corrections

The initial REM-003 fixture attempt rejected zero-height rectangles and was not
promoted. The later owner-review reference-contract failure is likewise retained:
three assertions failed because the review definition refused three legal non-zero
seed identities. Neither failure is reinterpreted as a C1 physics failure. The
successor 459-assertion contract and exact-runtime recurrence are separate evidence.

## Gameplay-review boundary

Automated evidence supports the bounded C1 engineering candidate: packed
standing/walking do not churn the bed; ordinary/hard landings are distinguishable
and conservative; hard terrain/Water controls remain out; excavation,
representative powders, seams/re-entry and REM-002 generic-body recurrence remain
covered.

This is **not owner gameplay acceptance**. The selectable
`rem003/player-granular-review` MicroScenario is the owner-review surface for
walking/reversal, step/shoulder/edge transitions, Dust/Salt, jetpack landings and
erase-driven collapse. Issue #82 remains open until the owner explicitly accepts
C1 or records a rejected/no-go/rework disposition. CI and this audit do not make
that decision.

## Limits

C1 is deliberately bounded to at most two foot-edge relocations on sampled-player
landing. It is not calibrated granular mechanics, arbitrary-shape or generic-body
acceptance, torque/fracture/soliding, target-GPU performance, Windows execution or
a claim that every granular feel defect is resolved. REM-004 / #83 retains generic
body↔granular acceptance.
