---
title: ADR-014 Single semantic place and atomic four-plane admission
status: Current
document-kind: decision
scope: GEN-005 semantic projection ownership, immutable runtime commands and complete preview replacement
canonical-for: [semantic-plane-admission-decision]
last-reviewed: 2026-10-21
related-documents: [ADR-013-canonical-semantic-generation.md, ../systems/procedural-semantic-planes.md, ../systems/depth-layers-and-parallax.md, ../architecture/data-ownership-and-lifetimes.md]
---

# ADR-014 Single semantic place and atomic four-plane admission

## Context

GEN-004 already owns stable features and finite canonical planning regions.
The depth host already owns four independent native Worlds, per-plane clocks,
immutable copied render packets and a frozen background. Generating independent
districts per plane or letting presentation discover cross-plane physics would
create conflicting authorities and unstable correspondence.

## Decision

Compile one immutable semantic plane plan from the existing hierarchy. Projection
records reference canonical feature or route geometry. Typed links are static,
presentation or narrowly permitted runtime routes. Fixtures declare finite
material feeds and cleanup; existing native rules own reaction products.

Keep generated arrays private until all four are Ready. Copy and validate the
complete bundle at the owner boundary, construct all candidate Worlds before
replacing the active set, and publish matching feature revisions in one
synchronous commit. Preserve the last valid set on any admission failure.

Runtime routes consume owner-issued, copied, identity-bound observations with
bounded effects and one-use serials. A static background reference cannot grant
runtime write authority. Actor proposals are play-only values consumed through
an existing actor session. Generation workers cannot instantiate physics bodies.

## Alternatives and consequences

Four independent layout generators are rejected because a shared presentation
label cannot prove geometric correspondence. Pixel-overlap event forwarding is
rejected because it bypasses explicit lifecycle and owner admission. Incremental
live installation of related plane tiles is deferred to GEN-006's residency and
reconciliation contracts; GEN-005 commits bounded complete configurations.

The complete proposal plus old/new owner staging has an explicit memory cost.
Configured publication and host caps bound it. Retrying identical configuration
is idempotent; intentional reset creates a new generation. Browser qualification
and production asynchronous integration remain separate from this opt-in host.
