---
title: AMBIENT-002 behavioural intelligence lane
status: Current
document-kind: evidence
scope: Incremental pure-value engine, bounded memory, editable personalities and focused qualification; physical gameplay remains separately measured
canonical-for: [ambient-002-behaviour-evidence]
last-reviewed: 2026-11-25
related-documents: [mission-ledger.md, ../../systems/ambient-actors.md]
---

# AMBIENT-002 behavioural intelligence lane

## Source and authority

The lane begins at predecessor `d0af9b6015c27417fddd67f79afdcf656a609571`.
The principal AMBIENT-001 application and Windows evaluator remain unchanged.
The successor is Draft/HOLD and does not change actor capacity, physics laws,
production defaults, native cell authority or command admission.

Owned source is `ambient_profile.gd`, `ambient_engine.gd`, `ambient_modules.gd`,
the new `ambient_memory.gd` and `ambient_stateful_modules.gd`, the editable
`profiles.json` catalogue and focused pure-value regressions.
All engine inputs remain copied values. No World, node, body, RID or peer-policy
object enters a rule. The lead owns the owner/session integration; perception
and actual movement have an independent lane; editor and scenarios have another.

## Initial implementation checkpoint

The 11 predecessor rules remain in their original implementation functions.
There are 18 additional typed rules: investigation, unfamiliar-space exploration,
historical-patch revisit, patrol sequence, preferred region, avoided region,
lost-target search, temporary destination, repeated-failure withdrawal,
resource-sensitive rest, drive-sensitive home return, peer observation,
regrouping, peer-velocity alignment, dispersion, material-boundary following,
observed-clearance steering and negative-affinity peer avoidance.

Strict authored version 1 is still accepted. Version 2 adds independently
documented personality settings, an explicit personality switch, an explicit
drive switch, bounded memory and perception settings, authored relationship
tags/preferred peer, and up to 12 authored regions. Upgrade is an explicit copied
authoring operation. The six predecessor profile values are preserved; ten
ordinary editable version-2 profiles bring the catalogue to 16.

Urgent overrides retain predecessor precedence and tie ordering. A new utility
tier selects one goal with a finite persistence-dependent commitment; ordinary
local preferences influence its motion. A chosen neutral inspection/patrol/home
phase suppresses ordinary wandering while urgent reflexes may interrupt it.
Neutral intent does not claim physical stillness. Goal deadlines and drive
updates use actual supplied simulation progression, never elapsed wall time.

Private spatial memory retains at most 128 visited cells, 32 material interests
and 32 failed approaches, with lower configurable capacities. The defaults are
64/16/16 records and a 90-second lifetime. Failed approaches expire within
30 seconds. Oldest observations are deterministically evicted, and unavailable
coverage does not prove empty space. New World generation clears ephemeral
state; unknown generation suspends memory learning and memory-dependent use.
Run/epoch/slot and actor identity admission remain intact.

Memory, personality and drives have explicit independent ablations. Turning
spatial memory off removes place habituation and visited/failure penalties;
finite module latches/cooldowns remain. Historical revisits and accumulated
failure withdrawal are unavailable when memory is disabled. Turning personality
off uses neutral trait values; turning drives off holds explicit fixed values.

## Initial local verification and preserved findings

The local executor was unavailable during initial implementation, so source was
first assembled through immutable connector blobs. It later recovered. The
isolated worktree is `/tmp/ambient-002/behaviour`; evidence is stored outside the
repository under `/tmp/ambient-002/evidence/behaviour`.

Pinned runtime: Godot `4.7.stable.official.5b4e0cb0f`, Linux x86_64, with the
retained native and Rapier libraries. The editor import completed with exit 0
and no parser errors. The first predecessor pure-value suite ran 895 checks and
reported one failure: its catalogue assertion expected exactly eleven entries.
The assertion now explicitly expects eleven predecessor plus eighteen successor
rules. This was a stale catalogue expectation, not a suppressed runtime failure.
Subsequent local results and new stateful regressions are recorded below as they
complete. These checks do not execute physical actor episodes or qualify Windows.

## Qualification still in progress

New stateful-rule regressions, actual native gameplay comparisons, integrated UI,
save/reopen, graphical and Windows extracted-package execution remain separate
gates. The first source checkpoint is provided early so independent lanes can
exercise the integrated implementation while this lane continues adversarial
testing. No overall success or owner-hardware playfeel claim follows from import.
