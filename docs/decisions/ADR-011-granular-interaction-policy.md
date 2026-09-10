---
title: ADR-011 — Versioned granular interaction and sampled support
status: Current
document-kind: decision
scope: Version 1 powder exchange, player packing and Mercury eligibility; excludes barrel bearing
canonical-for: [decision-granular-interaction-policy]
last-reviewed: 2026-09-10
related-documents: [../systems/granular-interaction-policy.md, ADR-007-rigid-body-cellular-coupling.md, ../audits/2026-09-09-issue-10-granular-policy.md]
---

# ADR-011: Granular interaction policy version 1

## Decision

**Current implementation decision for issue #10:** adopt the compiled immutable
`InteractionPolicy` version 1. Its canonical [contract](../systems/granular-interaction-policy.md)
defines material capabilities, pair permissions, units, geometry and bounds.
Density is retained. Powder rearrangement uses real voids. Mercury exchange uses
one deterministic opportunity every 30 ticks, with coalesced activity-block wakes.
Player downward packing uses eight of nine stable samples; side resistance uses
nine centred samples as well as downward support.

These are explicitly selected gameplay settings, separate from the provisional
barrel impact/creep envelope. They do not create a global solid flag, Rapier
support collider, persistent bearing impulse or ownership handoff.

## Evidence and alternatives

The issue #9 baseline reaches 32-cell Mercury/Sand breakthrough in 32 ticks.
The [issue #10 screen](../audits/2026-09-09-issue-10-granular-policy.md) gives
320/960/1920 ticks at periods 10/30/60, in both one-cell and 32-cell confinement
over five seeds. Period 30 selects a 30-fold slowdown with measurable progress;
period 60 exceeds the proposed 10–50-fold range. Raising lateral viscosity or
lowering Mercury density does not express this behavior and is rejected here.

Support screening quantizes 0.65/0.8/0.95 occupancy to 6/8/9 samples in the stated
nine-cell neighbourhood. Six can accept a missing whole column; nine rejects
even one missing sample and permits more sampled overlap on the tested slope.
Eight accepts one missing sample while excluding thin/loose films. This is a
bounded local approximation, not a globally connected or mechanically calibrated
load path. Reacting Seed, moving grains and unsupported structures remain dynamic.

## Consequences and revision boundary

Normal reset constructs the versioned defaults; diagnostic overrides require a
fresh world. The Tower now authors transport profiles with explicit restart;
there is no unsynchronized table mutation or new level-save field. State hashes
include this configuration and native pending deadlines, but full saved replay
is still absent. Fallback deliberately retains its narrower Water, chemistry
and Stone state semantics. Main-thread Rapier ownership is unchanged.

Any later tuning must version the policy decision and rerun affected fixtures.
Issue #11 owns barrel feedback, barrier-aware ejection and bearing calibration.
Dynamic aggregate membership still requires a separate ownership decision.


## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.


## Issue #13 version decision, 2026-09-10

Retain transport profile schema/presets v1 as opt-in starting values: powder
mixing 96; Water carrying 255, pickup 64, packing 8; Gentle requires loose exposure,
Threshold erosion allows exposed packed pickup. The moderate powder setting
produced greater final coflow interleaving than the maximum despite fewer swaps.
The controls are independently screenable; zero pickup/packing can meet the same
fixed minimum threshold and are not evidence of independent physical units.

Keep Baseline and all presets at horizontal 2/cadence 1. Sampled lateral search
changes transport strength and geometry, including the poured Mercury scene when
applied to all liquids. It is an explicit user-copy experiment, not a new default.
The original period-30 permeability and powder/player support v1 remain unchanged.
No flow field, new rule radius, chemistry cadence or barrel/aggregate policy is
introduced. See the [dated screen](../audits/2026-09-09-issue-13-transport.md) for
scope, shared-host timing, visual checks and outstanding owner taste assessment.
