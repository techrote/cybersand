# Ambient native completion and material publication reconciliation

## Recorded integration failure

The frozen candidate `0670733eb0a418c8580458a9c5dd9aff24f342c6` failed the original
`test_ambient_default_off_integration` on both Windows and Linux in
[qualification run 46136935975](https://github.com/techrote/cybersand/actions/runs/46136935975).
The original processes completed their initial 30 native ticks and subsequent
12-tick external-command workload with actual physical progression. Both then
reached the existing 300-second watchdog while waiting for the explicitly
activated Ambient sensor and policy. The original 46 completed checks and failure
remain failed evidence.

[Read-only inspection run 46138173340](https://github.com/techrote/cybersand/actions/runs/46138173340)
authenticated the original run, attempt, source, artifact identity, archive
SHA-256, byte size and ZIP CRC before printing the unchanged process records.
Linux artifact `15259949712` is 7,753,028 bytes with SHA-256
`e941fe8e53106d5d64a428aa228c7b40d3c46027514236a98c81af046a4b6953`.
Windows artifact `15260600876` is 6,053,788 bytes with SHA-256
`139f6ddb4cdcb192a62da09d79de052b53edb6e51de83841c8411b1bc9e2f09b`.
Inspection executed no application code and did not change the original outcome.

## Production contract defect

Main deliberately observes the early physical completion before completing the
corresponding physical callback. That packet contains native World generation,
native tick and revision, but no material bytes or render identity. The previous
Ambient entry point interpreted every packet as a material envelope. Early
packets inherited the snapshot class defaults `render_world_generation=0`,
`render_snapshot_serial=0` and `backend_name="unknown"`; these defaults could
refuse a previously valid native material view immediately before policy sensing.

The production source proves this contract mismatch. The observed timeout alone
does not prove that this is the only possible Ambient failure. Repair acceptance
requires the resulting-source original native/Rapier integration workload.

## Reconciled contract

The existing worker and session remain the only native and physical owners.

- Early packets explicitly mark absent render generation and render serial as
  `-1`, and copy truthful backend and failure scalars from their native source.
  The coupling-only producer supplies its actual backend identity. Combined
  publication remains unchanged.
- The session uses the genuine physical World identity where supplied. It sends
  an explicitly material-free packet to the existing Ambient consumer's new
  native-owner observation method.
- Owner observation advances native tick/revision freshness, detects failure and
  owner contradictions, and retires a replaced World's cached material. It
  allocates no material image, copies no material payload and invents no render
  identity.
- Material ingestion retains its own serial, sample tick, revision, complete
  baseline and patch validation. A delayed genuine material envelope may update
  that same World after a newer physical envelope, while current native
  freshness remains at the newer owner. It must not exceed its original owner
  tick/revision or regress accepted material identity.
- Owner refusal and material refusal are separate. A healthy early completion
  cannot cure malformed or incomplete material coverage. Foreign epoch, older
  World, regressed native progress, contradictory immutable owner, unsupported
  backend and native failure remain visible refusals.
- Default-OFF Ambient policy returns before sensor work as before. Main
  callsites, physical scheduling, callbacks, publication acknowledgement, native
  simulation allowances and simulation clocks do not change.

This adds no detached-body transaction owner. Subsequent ObjectShard integration
must preserve the distinction between truthful native completion metadata and a
separately admitted material view.

## Qualification and review scope

The new `test_ambient_publication_owner.gd` supplies 49 deterministic checks
through the production consumer. It covers early admission without bytes,
same-owner material arrival, coupling-only reuse, changed-revision age,
delayed material after newer ownership, older-envelope refusal, World
replacement, incomplete baseline, foreign epoch, backend refusal, failure,
immutable contradiction and real recovery identities. It explicitly records that
it does not execute native simulation.

The existing `test_ambient_perception.gd` remains unchanged. Its 130 checks
include actual native material edits/progression, Oil/Water policy decisions,
bounded sensing and existing ownership/material semantics. The original mounted
default-OFF native/Rapier test retains its actor population, control route,
progression counts, watchdog and check callsites. It adds only bounded scalar
diagnostics at the existing progress-report cadence, failure and successful
activation.

Specialist B independently reviewed the owner/material contract and the new
focused-reader fields. Specialist C independently checked the unchanged
130-check test's source assumptions and final expected state of the 49-check
controls. Hosted execution is required; local execution was unavailable when
these source changes were prepared. Source review is not a passing runtime
result. The definitive mission ledger records resulting-source outcomes and
does not relabel the failed candidate as passing.
