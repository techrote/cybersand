---
title: Issue 63 Stage 3B sparse non-payload producer evidence
status: Review-ready implementation
document-kind: audit
scope: Issue #63 mask, event, inclusion and coverage witness package
canonical-for: [issue-63-stage3b-sparse-nonpayload-witnesses]
last-reviewed: 2026-09-20
related-documents: [../operations/soliding-stage3b-production-plan.md, ../systems/settled-region-discovery.md, issue-12-2026-09-19/stage3b-parent-decision.md]
---

# Issue 63 Stage 3B sparse non-payload producer evidence

## Authority and ownership

Issue #63 is the serialized central-World producer package after #62. Its authority is
parent #12, the resolved #57 event/halo contract, the Stage-3B production plan and
landed #58-#64 guarantees. It does not absorb #64 graph reconstruction/incidence,
#65 reconstruction/reclamation, #66+ fast paths/consumer work, Stage 4 or INT-000
material semantics.

The #62 boundary is preserved: activity/deadline maintenance remains parent-local.
Payload refresh preserves the #63-owned mask/event/inclusion tuple instead of
recomputing it from World containers.

## Bounded witness state

Each construction-reserved World discovery owner record carries:

- exact transient-mask occupancy count plus nonwrapping mask generation;
- exact pending-event count plus nonwrapping event generation;
- requested/applied inclusion epochs and the corresponding per-record inclusion bits.

The record vector remains reserved to configured tile capacity `T`; no hot overflow
container or lazy stale-entry queue was introduced. Storage layout exposes the sparse
witness capacity/bytes and producer metrics expose occupancy/event high-water values.

Transient-mask set/clear changes adjust one canonical owner directly. Configuration
change/restore walks canonical logical tiles only inside the changed mask rectangle;
if an enormous mostly absent rectangle would exceed the bounded logical traversal
limit, observation is quarantined rather than scanning all residents or allocating an
unbounded incidence structure.

## Event footprint and incidence

Explosion acceptance/execution semantics are unchanged. After an authoritative event
passes the existing `R + 2` acceptance endpoint checks, observation uses #57 exactly:

`P = (R + 2) + maximum_rule_radius`.

Endpoints use checked signed arithmetic. The checked footprint arithmetic is a
single production helper used by World event observation and by the #57 geometry
regressions. In particular, the required smaller non-default `r = 1` case is tested
directly against that helper. A full current World cannot safely set
`maximum_rule_radius = 1` because the live material catalogue contains an active
Rocket rule with write radius 2; #63 does not weaken that independent scheduler-safety
validation merely to make the geometry fixture constructible.

Canonical tile traversal increments one exact pending count per intersecting represented
tile; drain decrements the same footprint. Overlapping events therefore cannot clear a
shared tile early. Registration while an event is pending derives its initial count
from the bounded authoritative pending-event queue, so absent/untracked coverage that
becomes resident before drain inherits the obligation.

If the wider `P` box is unrepresentable although the authoritative `R + 2` event
was valid, or bounded local witness traversal cannot preserve integrity, only the
observer is failed closed. The accepted event is not narrowed, rejected or rolled back.

## Inclusion and coverage ordering

Simulation-region requests advance a requested inclusion epoch. Tick entry advances
the applied epoch to the newest request even when request ABA restores the same
geometric coverage before application. A record is invalidated when its requested or
applied inclusion value changes; epoch-only acknowledgement does not manufacture a
payload mutation.

Coverage state is explicit at the World/coordinator boundary:
`NotResident`, `ResidentUntracked`, `RegisteredUnknown`, `Ready`,
`Excluded`, `Blocked`, `CapacityRefused` and `Failed`.

With region connectivity enabled, new residency is registered as graph-side unknown
before journal payload registration. That ordering revokes any maintained absence
certificate before newly resident payload can become consumer-visible. A later local
registration failure after that revocation fails observation closed.

## Locality and failure behavior

Ordinary unchanged worlds do not poll represented tiles for #63 state. Mask cell
changes use direct canonical-key lookup; event work is bounded by the accepted event
footprint; inclusion reconciliation runs only when the global request/applied epochs
change. The existing semantic-policy global fence remains explicit rather than being
repurposed as ordinary maintenance.

World state remains authoritative when witness state cannot be represented.
Capacity exhaustion maps to `CapacityRefused`; producer/source/generation failure
maps to `Failed`. World incarnation and append-only owner slots retain stale-handle
protection across reset/move; mask/event generations and inclusion epochs refuse
wraparound rather than aliasing ABA.

## Regression obligations

The focused native suite covers mask add/clear/reconfigure and change/restore ABA,
multiple occupancies in one owner, overlapping event add/staggered drain, rejected and
drained events, default/smaller/larger rule radii, halo-only face/corner crossings,
negative coordinates, authoritative-endpoint versus wider-observation overflow,
pending inheritance on late residency, requested/applied inclusion and pre-tick ABA,
explicit coverage states, tracking capacity failure, failed/reset behavior,
generation exhaustion, bounded-storage/high-water accounting and quiet-world locality.

The complete native/soliding suite remains the regression authority for #61 payload,
#62 activity/deadline, #64 graph behavior, workers 1/4 determinism, observer-disabled
neutrality and sanitizer coverage.

## Source-matched runtime publication

The final native source was reconciled with authoritative `main`
`4e4381d304458ef9b0dfa9336cfe08e8cc162210` before publication. The exact
publication source is `688c934a63b22a0aee180b11d05a357d86643300`, source tree
`c4b54ddc2570e2b8e1fdd51ad5d6419975ded42e`.

Actions run `35539993947` passed the focused #63 soliding suite and sanitized
World-discovery freeze gate before building either runtime, then passed:

- Linux x86_64 Godot 4.7 build plus ABI/runtime-floor validation, SHA-256
  `edc4399fc7d1b1140d678ceeaead5b402388719f7947e766764f6f2a30f8e84b`;
- Windows x86_64 pinned LLVM-MinGW cross-build, SHA-256
  `4509d97b5e5b4c2976459ee78597603cb65c59def70876ba4caa5a21b53b65d9`;
- exact source-input provenance regeneration and verification;
- retained runtime artifact publication and Git LFS verification.

The publication commit is
`51e74dad9944b994792988bef1e4bf1d2bd2ae36`. It changes only the two
runtime artifacts/provenance manifests and removes the temporary publisher workflow;
the published native source inputs are unchanged. Windows execution is unavailable
and is not claimed.

Final merge acceptance still requires the normal exact-head Documentation/provenance,
Native C++ and GDExtension/Godot workflows to pass after this evidence-only audit
update. Their run identities are retained on PR #101 so this document does not require
another post-validation commit.
