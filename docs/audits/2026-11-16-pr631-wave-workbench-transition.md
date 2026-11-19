---
title: PR631 Wave Workbench physical-identity transition
date: 2026-11-16
status: reviewed-per-file-transition
pr: 631
---

# PR631 Wave Workbench physical-identity transition

This record admits one bounded edit to the protected non-identity consumer
`native/src/world_pressure.inc` for CyberSand PR #631. The immutable material
catalogue lock, retained catalogue identities, accepted-main policy vectors and
production Water defaults are unchanged.

The transition is:

- path: `native/src/world_pressure.inc`
- from LF SHA-256: `a545d153f0f68c930837c59be449ac455b3fd35f36e268f21cffbfc940cb6da9`
- to LF SHA-256: `ccd3c773992560a22989a3009c5dc383e4a16cc83d6dd21be0ca4b5111a842b4`
- authenticated source commit: `9bf39e70df4fbfdee87222cc8fa208a932729f72`

The source change is deliberately narrower than the Workbench tuning feature:
when Wave Flow uses any non-default authoring parameter, complete
`physical_state_hash()` now binds the same explicit
`wave-authoring-tuning-v1` parameter domain already bound by `state_hash()`.
The exact qualified-v2 parameter point takes the old branch and therefore
retains its historical byte stream, Wave physical-hash version and persistence
boundary. Non-Wave Worlds are unchanged.

The new Wave regression requires a World whose only difference is a tuning
parameter to have different state and complete physical identities. Publication
12's normal Wave suite passed all 30 registered cases after this repair. The
transition does not admit a new material identity, solver-family identity,
wire-format revision, save format or production default.

Future edits to this protected path require another explicit transition.
