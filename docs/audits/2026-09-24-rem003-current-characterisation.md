---
title: REM-003 Current player↔granular characterization and candidate registration
status: Current
document-kind: evidence
scope: Exact-source REM-003 Current measurements and frozen first candidate selected before semantic implementation
canonical-for: []
last-reviewed: 2026-09-24
related-documents: [2026-09-24-rem003-player-granular-preregistration.md, ../systems/granular-interaction-policy.md, ../operations/development-claims-remediation-programme.md, 2026-09-24-rem002-issue11-integration-forensics.md]
---

# REM-003 Current characterization and candidate registration — 2026-09-24

## Frozen Current baseline

REM-003 Current characterization ran at PR #129 head
`c4ebb4856b60ec8c85ea48d37313a38d0be1226c`.

Exact-head GitHub Actions:

- Documentation/provenance `36063834522` — success.
- GDExtension/Godot `36063834330` — success.
- Native C++ `36063834321` — success.
- Linux x86_64 Godot 4.7 executed the generated source-matched runtime in all
  four isolated shards. Windows x86_64 is a cross-build only.

The first REM-003 apparatus attempt at `a7bad673...` is retained separately:
its new slope builder emitted zero-height diagnostic rectangles. Native correctly
rejected those malformed fixture records. That run is not promoted as the clean
baseline.

## What Current actually does

The clean native baseline supports the shared version-1 support predicate rather
than contradicting it.

| Case | Current observation |
|---|---|
| Packed Sand stand | 300/300 grounded ticks, zero overlap, no material motion |
| Shallow supported Sand | 240/240 grounded ticks, zero overlap |
| Flat walk/reverse | full 42 px/s travel and reversal, zero overlap/material motion |
| Repeated flat traversal | stable repeated path, zero material motion |
| Dust / Salt / granular Stone | representative slow traversal remains supported |
| Excavation | support releases immediately at the registered tick and the player descends to later real support |
| Ordinary Sand landing | ~46.0 px/s first impact; final y ~185.986; zero bed motion |
| Hard Sand landing | ~87.53 px/s first impact; final y ~185.998; zero bed motion |
| Slope | bounded one-cell overlap observed; five grounded-state transitions |
| Edge/runout | multiple grounded transitions and later floor/wall contact after leaving the finite bed |

The ordinary and hard landing cases are the key reproduced structural defect for
this first candidate: materially different impact speeds resolve to effectively the
same rigid support height and produce **zero granular response**. This is not a
failure of the 8/9 downward support classification; it is a sampled-player response
gap.

Current packed standing and flat traversal also do not justify weakening the
shared support predicate. REM-002 generic body bearing depends on that predicate
and remains outside this candidate.

The registered chunk-seam case at x≈512 is excluded from candidate selection:
the finite adapter's default simulation window did not cover that fixture, so
active grains were correctly treated as paused/non-bearing. The harness will move
that case into an explicit matching simulation window before it is used as seam
evidence. The bad case is retained rather than interpreted as a chunk-seam defect.

## Candidate C1 — bounded landing disturbance

C1 is frozen here before its semantic implementation.

**Goal:** make a supported granular bed respond observably to player impact without
changing support classification, allowing arbitrary penetration, adding a second
rigid-body solver, or giving the player ownership of granular material.

C1 adds one serialized owner operation used only by the sampled character on a
downward collision with support-capable granular material:

- impact speed < 24 px/s: no disturbance;
- 24 <= impact speed < 72 px/s: relocate at most **one** exposed foot-edge grain;
- impact speed >= 72 px/s: relocate at most **two** exposed foot-edge grains;
- only the left/right foot-edge stored granular cells are candidates;
- each moved grain goes one cell diagonally outward/up into real Empty;
- the destination must be unoccupied by another transient body;
- movement reuses the existing whole-cell conservative relocation path, retaining
  material state and temperature;
- the player still stops on the accepted support surface for this candidate;
- no grain is erased, duplicated, teleported across a barrier, or moved from the
  centre of the footprint;
- no disturbance occurs on hard terrain, liquids, loose/non-supporting grains or
  ordinary resting contact.

These thresholds deliberately separate the exact frozen ordinary (~46) and hard
(~87.5) landing controls while leaving the ~1.53 px/s standing re-contact lane
inactive. They are a bounded gameplay candidate, not calibrated material mechanics.

## Candidate acceptance before owner review

C1 must demonstrate objectively:

1. packed standing and flat walking/reversal remain supported and do not churn the bed;
2. ordinary landing moves at most one conserved granular cell;
3. hard landing moves at most two conserved granular cells and therefore differs
   observably from the ordinary arm;
4. hard terrain and liquids move zero granular cells;
5. loose one-cell film remains non-supporting;
6. excavation still releases support promptly;
7. Dust/Salt/granular-Stone support remains available;
8. native/fallback behavior agrees on the disturbance count and resulting bounded
   material accounting for matched fixtures;
9. REM-002 generic body/granular recurrence remains unchanged;
10. failed-world, interest/re-entry, deterministic worker and repository/documentation
    gates remain green.

C1 does **not** claim that two edge grains are the final desired feel. If objective
gates pass, the result proceeds to owner gameplay review. Owner review may accept,
reject or request a different response; CI will not be cited as that decision.
