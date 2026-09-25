---
title: PLAY-VAL-001 selectable player representation fixtures
status: Current
document-kind: evidence
scope: Issue #139 reset-scoped selectable REM-003 player fixtures for sampled baseline, sampled burial-safe and barrel/Rapier comparison; not owner gameplay acceptance
canonical-for: []
last-reviewed: 2026-09-25
related-documents: [../operations/microscenario-reference-pack.md, ../operations/microscenarios.md, 2026-09-25-pchar001-player-representation-experiment.md, 2026-09-25-rem003-player-granular-acceptance.md]
---

# PLAY-VAL-001 selectable player representation fixtures — 2026-09-25

## Starting point and ownership

Issue #139 fixture integration starts from authoritative `main`
`82f1aa24e8b92b994098ff81f8c9a19cb5a1a86d`.
No open #139 implementation PR or matching branch existed at preflight.

This checkpoint changes only the owner/test apparatus used to select an already
implemented PCHAR representation. It does not change sampled-character physics,
PCHAR barrel control constants, native material authority, generic
Rapier↔cellular coupling, Water semantics, REM-003 support thresholds or #12
soliding. #82 remains sampled player↔granular acceptance and #83 remains the
generic body↔granular acceptance owner.

## Selectable experimental arms

The shared MicroScenario catalogue adds three explicit exploratory IDs:

- `rem003/player-granular-review/sampled-baseline`
- `rem003/player-granular-review/sampled-burial-safe`
- `rem003/player-granular-review/barrel-rapier`

All three are derived from `rem003/player-granular-review`. They retain the same
authored rectangles, events, player start, camera, tools and ancestral
geometry/action recipe hash. Their complete definition hashes differ because the
catalogue ID, presentation identity and sampled-player/body participation are
different.

The original `rem003/player-granular-review` remains unchanged as the historical
candidate-C1 owner-review surface.

The barrel definition omits the original three `material_cells` census probes.
Schema 2 intentionally rejects material-cell census while a body mask is active,
so the barrel arm retains only the neutral 600-tick completion observation and
uses gameplay/material-state recording for visual comparison. This changes no
authored world geometry or scheduled event.

## Why representation is not a schema field

The versioned MicroScenario definition continues to describe reproducible world
setup and admitted owners. PCHAR representation/recovery selection is reset-scoped
controller configuration, not new simulation data in schema 2.

On launch, the desktop owner maps only the three registered PLAY-VAL IDs to:

| Fixture | Sampled owner | Runtime enclosure recovery | Rapier player |
|---|---:|---:|---:|
| sampled-baseline | yes | enabled | no |
| sampled-burial-safe | yes | disabled | no |
| barrel-rapier | no | n/a | body 0 only |

The worker receives explicit sampled-owner/recovery booleans in the admitted
fresh-reset command. The barrel arm initializes only body 0 at the same authored
player start; the other generic reference bodies are not admitted to the matched
fixture.

F6/F7 remain deliberately blocked while a controlled MicroScenario is active.
Changing representation means selecting another registered fixture and performing
a fresh reset. This preserves explicit identity instead of mutating an active
reference definition.

These three representation fixtures are **desktop-only**. The Web controller has
a different synchronous player/body owner and does not implement the PCHAR reset
contract; it therefore refuses the PLAY-VAL IDs with an explicit platform-scope
error instead of silently running the wrong representation. No Web gameplay
acceptance is claimed by this checkpoint.

## Capture and visible identity

The MicroScenario status line identifies the active player arm. GUI capture adds
the player representation, sampled runtime-recovery state and barrel body index
where applicable to the owner identity supplied to the existing scenario capture.

This is fixture/capture identity only. It does not make gameplay recording,
MicroScenario capture or the definition itself exact replay.

## Regression contract

`test_playval001_selectable_player_fixtures.gd` requires:

- all three IDs to be selectable and schema-valid;
- authored geometry/events/start/camera/tools and ancestral hash to match the
  original REM-003 review surface;
- each fresh reset to install the correct sampled/recovery/body ownership;
- F6/F7-style live switching to remain refused inside the controlled fixture;
- fresh reset to preserve the selected arm;
- barrel mode to initialize only Rapier body 0 at the matched start;
- returning to a sampled arm to remove the barrel body owner.

The repository's Godot regression runner discovers this test automatically.

## Validation state

Implementation is **review-ready but not yet runtime-verified** at this document
checkpoint. Draft Documentation/provenance passed before the PR was marked ready.
A post-ready synchronization commit intentionally triggers the full exact-head
Documentation/provenance, GDExtension/Godot and applicable repository gates before
merge. No Windows gameplay judgment is claimed here.

Even after those objective gates pass, #139 remains open for its recorded owner
review campaign and disposition.
