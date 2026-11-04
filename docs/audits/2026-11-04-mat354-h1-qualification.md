---
title: MAT-AUTH-002 H1 candidate qualification and custody
status: Current
document-kind: evidence
scope: Narrow unmerged MoltenGlass deadline successor, proposed one-source transition and exact available qualification; no runtime adoption or merge
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-mat354-h1-preregistration.md, 2026-11-04-mat354-correction-admission.md, ../operations/material-liveness-investigation.md, ../operations/material-catalogue-shadow.md]
---

# MAT-AUTH-002 H1 candidate qualification

## Scope and source

The owner explicitly authorized this bounded production correction and source
transition after merged Phase A #377. No merge, runtime adoption, release,
generic retry or H2 thermal-law change is authorized. #354/#352 stay open.

| Identity | Value |
|---|---|
| Initial accepted main | `751edc0b495dc85484ad5509a7c95f863651c76b` |
| Initial tree | `b0d42a256285e6049a6d3bdd1613d7ecd89f43c6` |
| Source-only H1 commit | `16533ff81c561677308665357eb1d0d5f65e85bc` |
| Source-only tree | `c0545655f190f0c9e990010873d24b1e702385a5` |
| Historical authority | `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` |
| Historical World LF SHA-256 | `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1` |
| Proposed World LF SHA-256 | `df0bb080084972c49ca400b7bfc6504f7ec27fa474112bc2bd56abe5d3d21539` |

The clean isolated branch is `fix/mat354b-moltenglass-deadline-20261104`.
The source commit changes one file: 13 additions and one removal entirely inside
`World::schedule_pending_reaction_wake`. The existing kernel, thermal arithmetic,
temperature, products, streams, epoch/mask checks, job effects and owner barriers
are untouched. All eight visible neighbours use the exact Fire/Lava/MoltenGlass
predicate. Cold sources and hot non-fixed points request the existing strictly
future four-tick/stream-192 lane. Hot180 pools do not add an intrinsic obligation.

## Ownership at intake

At approximately 20:14 UTC on 4 November, all 81 open PRs, #354/#355 comments
and relevant branches were inspected. No #354-B implementation existed. #358
was parked on a source-transition hold at `7383946a`; #347 was a stopped NO-GO
at `1598115c`; #386 was evidence-only at `b661a6f3`. #393's facade-only repair
at `e4c2649e` changed no protected World source. #382 at `12e4043e` owns
`world_pressure.inc` changes and explicitly leaves `world.cpp` unchanged.

#384 at `87418298` changes the catalogue checker for its separate display-name
consumer. H1's dedicated transition module does not import that migration.
Both branches require explicit checker composition and resulting-source review
when eventually integrating. This transition admits none of the other lanes'
protected-source mismatches. Recheck live ownership before every publication.

## Compatibility and identity policy

The original 27-source lock is unchanged and authenticated from historical Git.
The proposed successor is authenticated from a pinned source-only commit, its
parent, exact file inventory and unchanged bytes outside the named helper.
Unknown identities and unrelated protected changes fail closed. Guard success
means source identity has been authenticated; it does not grant adoption.

Catalogue/capability digests, headers, ABI, Cell storage, liquid-policy wires,
normalization vectors and saved-state versions stay unchanged. CYPS2/3 stores
activity/deadlines without a kernel-source version. Strict source/runtime evidence
therefore stays external; historical-state import is not an automatic migration
or a claim of cross-source replay. Same-source and historical import tests are
reported separately below when executed.

## Qualification ledger

Qualification is in progress at this checkpoint. Missing receipts are not passes.
The final evidence/PR ledger must report exact commands, compiler/dependency and
binary hashes, one/four-worker execution, actual claimants, correctness failures,
sanitizer scope and current merge-checkout identity.

Initial shared command-owner attempt refused before launching the compiler with
`Cannot establish process ownership: /proc PID namespace mismatch`. Its original
receipt is retained. Direct bounded native execution is a separate local scope;
it does not qualify the shared process-owner gate.

Initial repository check correctly reports the old Windows/Linux runtime
manifests need a rebuild for changed `world.cpp`. Missing companion workspace
documentation is an environment-preparation failure. Neither is waived.

## Performance and stopping decision

The [preregistration](2026-11-04-mat354-h1-preregistration.md) freezes baseline,
successor, workloads, repeats, timing windows, worker settings and measurement
limits before performance runs. The existing CI policy has advisory ratios;
there is no numerical H1 adoption threshold. An explicit owner performance
disposition is required after measured results, even if all correctness checks
pass. No threshold will be selected retrospectively.

The candidate remains unmerged. Incomplete compatibility, runtime, performance,
CI or independent-review gates require outcome **B — IMPLEMENTED, ADOPTION
BLOCKED**, with Draft state. Final actual results and unresolved limitations
will be recorded before stopping.

## Local and published source custody

The [publication mapping](2026-11-04-mat354-publication-identity.json) records
the local source-only commit `ca11dd4f…` and its public counterpart
`16533ff8…`. Their complete trees, parent and production bytes are identical;
GitHub publication changes commit metadata. The original local qualification
receipts remain bound to `9d218bb1…`, and the local runtime build to
`246014e7…`. They are retained under their original identities. Fresh checks
and exact compiled-input/binary comparisons establish any resulting-source
claim; no historical baseline or earlier receipt is rewritten.
