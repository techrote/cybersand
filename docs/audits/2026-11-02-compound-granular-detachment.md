---
title: Compound granular response and native detachment qualification
status: Planned
document-kind: audit
scope: Exact-source integration checkpoint; combined runtime qualification in progress; no production or gameplay acceptance
canonical-for: [compound-granular-detachment-evidence-20261102]
last-reviewed: 2026-11-02
related-documents: [../operations/gcr-detachment-integration-plan.md, ../architecture/compound-granular-coupling.md]
---

# Compound granular response and native detachment qualification

## Inputs and fixed decisions

The new isolated branch starts at main
`a8f08a67fea3c58f6df7473cbae1831334fcc04e`, tree
`4bfc2fbdda3704dfbf386235e54d2fe525ca32bc`. Source/test reconstruction consumes
detachment#347 `5af50b3c5a5f11614099a82090ad431646db4cba` and GCR#348
`be1847464803bab0f74d184d60d77aea5e384228`; neither branch is merged or rebased.
The separate fleet checkout and unrelated dirty material checkout are untouched.
The [registration](../operations/gcr-detachment-integration-plan.md) and
[machine protocol](gcr-detachment-2026-11-01/protocol.json) precede physical
acquisition. No sleep, friction/load-law tuning, material-law change, mass
rescaling or default promotion is part of this integration.

The native 520-member aggregate remains mass520, six exact shapes, with native
payload COM and lamina inertia. Geometry proxies share one physical COM state,
one GCR budget and one applied COM wrench. Conservative relocation retains its
separate material-operation meaning. Mechanical admission does not establish
credible heavy-terrain penetration resistance or owner gameplay acceptance.

## Retained pre-fix checkpoint

Source `e6485b5f7a807ca5be3e14ef5ae72262af5104dd` built Windows and Linux
extensions successfully; its Linux ABI-floor check passed. Windows core177,
detachment9 groups/19,338 checks and conservative displacement6 groups/281 checks
passed. The full matrix was interrupted after read-only review found defects;
two Linux binaries built but no Linux native tests ran in that attempt. These
results are pre-fix evidence only, not qualification of the successor.

Review identified finite-double angle overflow into host-float geometry, empty
compound input clearing an active mask, exceptions escaping mutating preparation,
and copied actionable GCR fields in failed worker publications. The successor
refuses invalid angles/empty membership before mutation, quarantines unexpected
preparation failure, and clears actionable failure-snapshot fields. Native
commit `d34848f80714369a5dc700e8b44f900154e6d083` passed Windows/Linux detachment
10 groups/19,355 checks including allocation-forbidden explicit quarantine.
The adapter catch itself has not been fault-injected.

Pre-fix raw evidence remains ignored under `build/pre-fix-e648`,
`build/full-native-composition` and `build/compound-native`. The final evidence
manifest will identify retained commands, tools, bounds, raw/log/binary hashes,
platforms and all successor failures. No physical efficacy acquisition has run
at this checkpoint. Qualification and the focused integration draft remain open;
all PRs remain unmerged.
