---
title: MAT-003 reconciliation after retirement of the historical runtime publishers
status: Current
document-kind: audit
scope: Import landed PR242 through the unmerged MAT stack, preserve prior results and historical publication records, and require fresh exact-head integration checks
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [2026-10-24-mat003-post-241-integration-checkpoint.md, 2026-10-24-mat003-post-240-integration-checkpoint.md, 2026-10-24-mat003-lcb001-integration-checkpoint.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md]
---

# MAT-003 and the publisher retirement — 2026-10-24

## Current main and the retained publication policy

While the fourth reconciliation's Native/Godot jobs were still executing, main
advanced from `4348516aba4c8e7036370d73afc14e86a19ea6a2` to
`fd97367acc5bcf5757b9ca69ae594279f0ad96bf`, merging
[PR #242](https://github.com/techrote/cybersand/pull/242). Main retains the bounded
#239 policy foundation, #240 worker/allocation-failure regressions and #241
physical-timeout diagnostics. #242 removes the six spent GEN-003, GEN-004,
GEN-005, GEN-007, player and LCB-001 publisher workflows, six publication helpers
and four helper tests. It changes the publication guide, not production Native
source, published runtimes or the active Native/Godot/Documentation workflows.

The imported [branch-scoped publication policy](../operations/local-build-and-validation.md#branch-scoped-runtime-publishers)
is retained exactly from main. Dated audits and build-input hashes continue to
describe the original publications; references to retired helpers/workflows are
historical and intentionally resolve through Git history. This task restores no
publisher or helper. A future changed Native input would require a separately
re-scoped publication path under that policy; no such input changes here.

## Completed and partial earlier checks remain separate

The [post-#240 checkpoint](2026-10-24-mat003-post-240-integration-checkpoint.md)
preserves the earlier complete **15 current-source and seven scoped PASS**
workflows at main `1e032e4` and the recorded exact stacked heads. The
[post-#241 checkpoint](2026-10-24-mat003-post-241-integration-checkpoint.md)
retains the next reconciliation's completed checks and superseded partial
Native/Godot work. Their original failures, cancellations and unchanged retries
remain source-qualified historical evidence.

The fourth reconciliation incorporated main `4348516`. Its five ready-state
Documentation/materialized provenance workflows completed successfully, with
the provenance steps actually executed, Python suites **15/81/24**, every
current `--check` and the five v2–v6 producer replays passing. Draft checks with
provenance skipped are not used for that claim.

| PR | Fourth-reconciliation exact head, preserved | Completed ready Documentation/provenance |
|---|---|---|
| #208 | `3bf3085e28ee98ce056c95a41f6d58c6737be719` | [40084094639](https://github.com/techrote/cybersand/actions/runs/40084094639) |
| #211 | `ad539b5ff1a9934cce6944cb668c53390cabebe7` | [40084264810](https://github.com/techrote/cybersand/actions/runs/40084264810) |
| #221 | `13ea52c96c403cfea34d92b747f58e049d6b59af` | [40084266715](https://github.com/techrote/cybersand/actions/runs/40084266715) |
| #235 | `c5f12a22e739c0259129e9b8da6a75c4d014f567` | [40084267920](https://github.com/techrote/cybersand/actions/runs/40084267920) |
| #238 | `f31ad152e85243eee270c60860aadcfc7ba5990d` | [40084270266](https://github.com/techrote/cybersand/actions/runs/40084270266) |

Completed scoped outcomes remain limited to their declared controls:

| Scoped check | Completed fourth-reconciliation run |
|---|---|
| S0 storage; S1 changed-input guard, without new World collection | [40084094635](https://github.com/techrote/cybersand/actions/runs/40084094635) |
| Historical S2F source and candidate twins | [40084095314](https://github.com/techrote/cybersand/actions/runs/40084095314) |
| Historical C128 | [40084094620](https://github.com/techrote/cybersand/actions/runs/40084094620) |
| Historical S2P | [40084094899](https://github.com/techrote/cybersand/actions/runs/40084094899) |
| #235 verifier contracts | [40084094575](https://github.com/techrote/cybersand/actions/runs/40084094575) |
| #238 verifier contracts and actual historical v4 publication check | [40084094021](https://github.com/techrote/cybersand/actions/runs/40084094021); same-head copy [40084094132](https://github.com/techrote/cybersand/actions/runs/40084094132) also passed |

The archived scoped outputs were retained with their selected historical source
identities and separately inspected reader results. They do not qualify MAT
candidates on the policy-enabled current World. The v4 publication test is a
static historical-source check; it does not repeat the 152-case author readback
or provide independent scientific acceptance.

Fourth-reconciliation Native/Godot execution was still partial at this main
advance. Completed build steps are preserved separately; no full Native/Godot
or physical-timing PASS is claimed for this phase. Supersession and intentional
cancellation do not themselves establish a test failure or a successful test.
Any actual failure or later result retains its original source/run identity.
Nothing is silently transferred to a new head.

## Fifth reconciliation and preservation boundaries

This reconciliation imports main `fd97367` into #208 and propagates merge
ancestry through #211, #221, #235 and #238. The previous heads remain ancestors;
earlier MAT checkpoints, registrations, controls, producer revisions, archives,
v4 seal and nine revised readers remain unchanged. The upstream #200 and #233
audits are retained exactly, along with the new main's publication-guide section.
Separate branches and unrelated primary-checkout work remain untouched.

Main's inventory now contains **669 protected blobs** under the established
Native/Godot/dependency/checker/build/current-gate filter, and **765
non-documentation paths** overall. Independent matching of every propagated
head is a separate pending proof. The existing five MAT historical-checkout
workflow wrappers retain their documented purpose; no retired publisher is
restored to satisfy a historical link or hash.

The **56 canonical Native runtime source inputs** are unchanged. Published
Windows/Linux Native binaries and runtime-provenance records are unchanged.
The retained provenance's **394 build inputs** describe the historical build at
`c8f14c7bc18d6ed8349d568cb00e47a826313cf9`. Independent preflight checks all 394
hashes against that recorded build revision. Against new main and this bottom
stage, **384 are unchanged, seven present test/CI paths differ and three retired
paths are absent**: `.github/workflows/lcb001-runtime-publication.yml`,
`tools/ci/lcb001_runtime_publication.py` and
`tools/ci/test_lcb001_runtime_publication.py`. Absence after deliberate retirement
does not rewrite the historical record. The complete old build map is not
falsely asserted equal to the current checkout; runtime source equivalence and
actual binary identity remain separate from that historical build snapshot.

The frozen 32-question file and all supplementary question objects are unchanged
by #242 and this route update. The current bottom stage retains 124 questions;
the full top-stage union is expected to retain 147 after propagation, including
the exact main-approved `TEST04`. This is not a claim that a top-stage retrieval
evaluation has already run at the bottom source.

## Fresh gates and unchanged authority

Fresh exact-head Documentation/materialized provenance, Native,
GDExtension/Godot and applicable scoped checks remain required. Native **94 per
mode** and Godot **139 total / 127 Windows-applicable cases** are expected source
counts until actual logs confirm them. The ordinary Godot **physical regression
timing distribution** job remains part of the required workflow result. Active
workflow bytes are imported unchanged from new main; prior exact-head passes
do not substitute for the new integration checks.

Final head/base pairs, tested merge parents/tree equality, workflow outcomes,
decoded logs, artifact seals, versions and command limits belong in the PR
reports after the fresh checks complete. GitHub-reported execution, independent
archive/hash inspection, characterization and contract-model outcomes remain
distinct. No paired MAT timing campaign, manual physical stress dispatch or
#234 causal repair is started here.

No PR is merged or issue closed. #204 and independent scientific acceptance
remain open; #213's closed final Gates A–E PASS and landed evidence remain valid.
The #200 foundation stays defaults-only, all 90 candidate arms remain blocked,
and #212, pressure/inertial ports, changed defaults, schema/ABI freeze and Rapier
integration remain outside scope.
