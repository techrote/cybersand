---
title: PLAY-UI-003 exact-head cadence-test parse failure
status: Current
document-kind: evidence
scope: Retained failed Linux shard receipt for the first completed-Rapier cadence candidate and its source-only parser correction
canonical-for: []
last-reviewed: 2026-10-27
related-documents: [2026-10-27-play-ui003-lifetime-review.md, ../systems/player-control-playground.md, ../operations/local-build-and-validation.md]
---

# PLAY-UI-003 exact-head parse failure — 2026-10-27

This record preserves a failed required workflow. It is not physics evidence and
does not qualify PR #280, #268, #269 or the PLAY epic.

## Exact failed source and runtime identity

| Field | Value |
|---|---|
| PR | [#280](https://github.com/techrote/cybersand/pull/280) |
| Source head | `bbc93183c61e0d768e3c54bd2e0d4e9011f7d416` |
| Prospective merge checkout | `c0e95dce7d01e590ad6ec6b45b475f770a30ad14` |
| Prospective merge tree | `d6168aaab066ae84137302cd056edb1b36695422` |
| Workflow | [GDExtension/Godot run 40597750726](https://github.com/techrote/cybersand/actions/runs/40597750726) |
| Failed job | [Linux regression shard 2, job 122521415608](https://github.com/techrote/cybersand/actions/runs/40597750726/job/122521415608) |
| Archived artifact | `linux-godot-shard-2-40597750726`, ID `12777707784` |
| Artifact ZIP SHA-256 | `7aa1ca0a8a52ca1016652635b807d8af4ecbeeaf5cace32106b3b1bf51939554` |
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Native runtime SHA-256 | `02ea0661d3a62e2ab346c3fe46f9f85b808c6a0099c639144f053dc70a5c3d46` |
| Rapier runtime SHA-256 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |

Shard 0, shard 1 and shard 3 completed successfully at the same source. Shard 2
failed one assigned case, `test_play_ui003_physics_cadence`; that fact blocks the
whole workflow regardless of other jobs. The runner's `timings.json` records the
case as `status=failed`, `returncode=1`, `diagnostic_error=true`, elapsed
`0.164 s`, with no timeout or launch failure. All other shard-2 case logs in the
archive remain available and are not relabelled by this record.

## Exact failure

The new case did not execute either real-host arm. Godot rejected its source:

```text
SCRIPT ERROR: Parse Error: Expected closing ")" after call arguments.
          at: GDScript::reload (res://tests/test_play_ui003_physics_cadence.gd:227)
ERROR: Failed to load script "res://tests/test_play_ui003_physics_cadence.gd" with error "Parse error".
```

Therefore there is **no** `PLAY_UI003_PHYSICS_RESULT` for this source, no
completed positive checkpoint visit, no completed render-only negative control,
and no basis for a Rapier-cadence acceptance claim. This is a source defect, not
a flaky physics outcome, Water failure or timeout. Re-running the same source
would not be qualification.

## Bounded correction

PR #280 was returned to draft. Commit
[`4cbe03fd9ca1621b248e67a741ad53ade50eeb0f`](https://github.com/techrote/cybersand/commit/4cbe03fd9ca1621b248e67a741ad53ade50eeb0f)
replaces only the ambiguous inline asynchronous reset predicate with a named,
typed `replacement_ready()` predicate and a `reset_epoch_floor` value. It does
not remove, skip or relax the positive/negative-control assertions, change the
production completed-step hook, alter native/Rapier ownership, increase a
timeout or request a retry of the failed source.

The corrected source has not been executed merely by publishing that commit.
Before returning the PR to ready-for-review, documentation/provenance checks and
source review must cover the new head. Required full Windows/Linux Native and
Godot/GDExtension execution must then produce the expected focused receipts,
zero diagnostics, clean checkout and exact source/runtime identity. The failed
run and artifact above remain historical evidence after any later pass.

Construction-time per-material solver selection, requested-versus-applied
receipts, the Water `pressure_flow_v1` option and unsupported-route refusal are
unchanged. Specialist scientific/4LY/NPC-training fixtures remain isolated;
material swarms #271 remain deferred and #265 remains closed.
