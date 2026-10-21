---
title: ADR-013 — Canonical semantic generation before rasterization
status: Current
document-kind: decision
scope: GEN-004 finite regional ownership, stable hierarchy identities and independently qualified material routes
canonical-for: [decision-canonical-semantic-generation]
last-reviewed: 2026-10-21
related-documents: [../systems/procedural-hierarchical-generation.md, ../systems/procedural-world-generation.md, ../architecture/data-ownership-and-lifetimes.md, ../audits/2026-10-21-gen004-hierarchical-generation.md]
---

# ADR-013: Canonical semantic generation before rasterization

## Decision

GEN-004 compiles immutable semantic plans in a finite, authored window of
world-zero-anchored regions. A region owns its feature hierarchy; each feature's
identity combines the authored world namespace, grid size, signed region address,
parent path, rule ID and stable slot. Storage chunks only sample the plan.
Shared boundary ports use canonical west/north ownership and keys independent of
the compilation window. Neighbor generation and worker completion never negotiate
which feature wins.

Routine place construction is declarative. Bounded authored candidates and
deterministic rule priority provide layout decisions, with explicit hard
constraints, weighted preferences, rejection and authored omission receipts.
GEN-003's finite assignment solver remains the single categorical adjacency
solver. Trusted native modules remain an extension point within the established
generation stack.

The [hierarchy contract](../systems/procedural-hierarchical-generation.md) owns
the executable vocabulary and precise scope. The planner supports region-contained
buildings crossing storage chunks and explicit route/service structures crossing
region boundaries. It does not admit arbitrary region-spanning building boxes or
claim complete geometric constraint search.

## Why this boundary?

Request-order ownership would make neighboring chunks disagree when produced
independently. A mutable shared global plan would add synchronization, lifetime
and streaming obligations before the programme's streaming stage. Recursive
neighbor planning would lack a finite dependency footprint. Canonical regions
and shared boundary records provide independently reproducible discovery while
keeping the plan's work and memory finite.

Semantic identity and content receipts answer different questions. The former
identifies a place across unrelated edits; the latter detects changed geometry,
material or constraints. Declaration order and recipe revisions therefore do not
rename surviving places. Changing the region grid explicitly changes the
identity namespace instead of silently moving an old place to a new owner.

Curve order supplies a repeatable structural sequence. It cannot certify a
physical path, especially for Morton jumps or repeated finite tiles. Routes use
explicit rectilinear geometry and compatible sockets. Final raster validation
then checks Empty-cell clearance/connectivity for the declared floating square
profile, including independently authored shared apertures.
Final support qualification separately checks retained solid contact along
declared floor/ceiling/wall edges, with partial-contact diagnostics. Neither
profile claims post-simulation structural stability or controller performance.

## Consequences and acceptance boundary

Fields may consume only declared immutable semantic geometry, never partial
raster state. Final hard material overrides retain authority. A blocker stays
in the material output and produces an explicit route conflict; the planner
does not silently remove the override or turn graph connectivity into a traversal
claim. World admission remains the separate exclusive-owner operation, and no
semantic plan grants permission to replace edited resident chunks.

This decision does not alter material physics, actor control, depth-layer ownership,
dependency pins, CI provider policy, save/replay or runtime streaming. Native,
Godot, source-matched runtime publication and exact-head hosted acceptance are
separate evidence gates in the [dated audit](../audits/2026-10-21-gen004-hierarchical-generation.md).
