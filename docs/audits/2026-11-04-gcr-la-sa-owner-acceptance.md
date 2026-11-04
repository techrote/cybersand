---
title: LA-SA owner gameplay acceptance and test-campaign closeout
status: Current
document-kind: validation
scope: Actual owner acceptance of the reviewed LA-SA gameplay and U Scooper; retained scientific failures and separate integration gates
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-scooper-u-hull.md, 2026-11-04-gcr-selective-events.md, ../systems/granular-review-flight-fleet.md, ../reference/product-intent-and-priorities.md, ../operations/microscenarios-programme.md]
---

# Owner verdict — 4 November 2026

## Actual judgement and source

After reviewing the U-shaped Scooper build, the owner reports that remaining
leaks are drips rather than flows and that a small amount of material can be
lifted, carried and dumped successfully. The owner explicitly states:

> I think we shall consider current LA-SA acceptable for production.

This is actual human gameplay acceptance, not an agent inference. It follows
the earlier three-response comparison favouring selective arrivals for burial,
incoming loading/torque and powered contact. Residual Scooper leakage is an
accepted gameplay limitation in this review, rather than a claim of perfect
retention or a new automated pass.

The supplied review copy is titled **CyberSand — flyer review · 52f19b51a9e5**,
from source `52f19b51a9e53d88802eceed917b935f96fe2b27`, on branch
`codex/gcr-scooper-u-hull-20261104`, draft PR389. It uses Godot
4.7.stable.official.5b4e0cb0f, Rapier addon0.35.2/core0.35.1 and the Windows native
SDK compiled from `3df1279f799230bafdc7a34766eb2995bf4ae69b`, SHA256
`c3b1f28f155d6bb871e596ad69df3cdec355ac7dd83e87aad362ce1ee883e2e1`.
The retained launch identity is `build/u-hull-playable-01/identity.json` and the
prior final binding is `build/u-hull-final-head-01/final-validation-receipt.json`,
SHA256 `96138e81917ddb247482258392547b04ce3abd1db0dae113f4775c2ce87a8ef1`.
Those records authenticate the supplied build; the owner's new message does not
provide a fresh machine-recorded selector/settings/trajectory receipt. Attribute
acceptance to the stated LA-SA review, without inventing a complete new matrix.

## What closes, and what remains

**Owner gameplay review: ACCEPTED.** The current manual comparison campaign can
stop. No additional open-ended friction, sleep or hull tuning is required by
this verdict. Preserve the tested build, authoring data, compact evidence and
useful regression fixtures for integration and future changes.

**Historical scientific results: unchanged.** The selective-arrival campaign's
registered joint creep/loading/rebound criteria remain NO-GO. The U campaign
still loses all16 cavity grains in its fast strafe/diagonal arms, despite the
positive owner experience with small loads. Its finite static-mask and rounding
findings remain scoped. The owner accepts the observed gameplay tradeoffs; that
product decision does not retroactively pass the stricter registered criteria.

**Production integration: pending.** Record the adopted gameplay scope and known
exceptions, reconcile the required branch stack with current main, resolve the
protected-source compatibility transition through its proper owner, and qualify
the resulting source/runtime before release. Production/default selection is
not changed by this documentation checkpoint. No merge is authorised or performed.
PR389 and its prerequisites remain draft/unmerged. REM-004 issue83 remains open
until its correctness, controlled envelope, stress-limit, integrated-source and
landed-state obligations are actually met. Detached structures and other
independently owned work are not accepted by this flyer review.

## Reusable testing direction

The owner finds this room's UX coherent, well organised and the nicest used so
far, and wants future testing to be more cohesive while preserving a reusable
engine for varied game types. This preference is recorded in
[owner intent](../reference/product-intent-and-priorities.md).

The referenced [specdocz development guidance](https://github.com/techrote/specdocz/tree/601dfbec937ec541129514f2ff7000c1c37a18c4/development)
is advisory and engine-independent. Its four reviewed files are pinned to commit
`601dfbec937ec541129514f2ff7000c1c37a18c4`: README blob84cfb205,
Gym blobc9340ec2, Zoo blobcca48e95 and Museum blob0cd4da39. It distinguishes
mechanic interaction, asset discovery and explained system demonstrations;
these purposes can share a navigation/UI shell without becoming one giant map.
No external document is promoted to CyberSand implementation authority.

**Recommendation, not implemented architecture:** reuse the current dense UI as
the starting shell; compose versioned scenario recipes, real runtime adapters,
capability-specific tools and run receipts around it. Use the existing shared
PLAY/session and MicroScenarios contracts, rather than a competing host or
another physics owner. Begin with the current flyer painting setup and one
barrel/cut setup, then one material-only scenario. Preserve the current control
layout, named presets, cheap reset/navigation and requested/applied values.
Keep saved construction presets distinct from exact continuing-state replay,
and exploratory edits distinct from controlled fixtures. Retain older fixtures
as evidence instead of replacing their historical source identities.

Inertial material carrying is a separate future hypothesis. The current
[IN reference](../architecture/inertial-cellular-v1.md) is qualified for Water
and Brine, not a drop-in powder/Scooper carrier. A later granular/inertial
carrying experiment must establish collision, momentum, ownership, conservation
and cost on its own; it is not required to close this manual review.

## Documentation-only checkpoint

This record and its canonical routes change no production/native/Godot inputs,
dependencies, runtimes, selectors, material laws or test thresholds. Runtime
execution remains attributed to the exact source above. Documentation, historical
M11, materialized repository/provenance, retrieval and whitespace checks are run
for the new record; no unchanged runtime suite is relabelled as a fresh execution.
