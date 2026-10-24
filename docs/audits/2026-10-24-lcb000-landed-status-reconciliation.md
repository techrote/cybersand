---
title: LCB-000 landed admission and status reconciliation
status: Current
document-kind: evidence
scope: Documentation and issue-summary reconciliation of the final bounded Gate A–E PASS; no successor implementation or new runtime acceptance
canonical-for: [lcb000-landed-status-reconciliation]
last-reviewed: 2026-10-24
related-documents: [../reference/status-and-roadmap.md, ../operations/lcb-scenario-catalogue.md, ../architecture/lcb-pressure-inertial-handoff.md]
---

# LCB-000 landed admission and status reconciliation — 2026-10-24

## Decision and source checkpoint

The [final landed-stack evidence](https://github.com/techrote/cybersand/issues/213#issuecomment-6377498947)
records Gates A–E and integrated LCB-000 **PASS within bounded admission**, without
RECHARTER. The subsequent [closure comment](https://github.com/techrote/cybersand/issues/213#issuecomment-6377517354)
closes #213 completed. The earlier evidence comment's instruction to leave #213
open was superseded only by that closure; its scientific limits remain intact.
The [independent closure review](https://github.com/techrote/cybersand/pull/226#issuecomment-6374404221)
and [Gate E decision](https://github.com/techrote/cybersand/issues/213#issuecomment-6374417194)
retain the detailed reproducer commands, timeouts and hashes.

| PR | Reviewed head | Landed merge |
|---|---|---|
| #215 | `5b0a7c6ab25bbfd0d15dc0fd07e8ee9b8ab9a4fe` | `758f02de453c70911a3ebb71932c84acf85a4e69` |
| #217 | `e0d26fdf1ae6889fcc75325ce5e9018a95841945` | `9c832f3d5d491d9cc880086bc2fe37c69318dc8e` |
| #226 | `774da032fceccbaa3cbebb592bed8a37d3181f8b` | `e95fe85d82e108a682a2ae0212d85569f1c03cd8` |

This documentation change starts from main `e95fe85d82e108a682a2ae0212d85569f1c03cd8`
in an isolated `codex/lcb-status-reconciliation` worktree. The landed tree
`fece020ef7fc83faf5cfe3081b018f2647f7e4fe` equals reviewed #226. The separate
primary checkout and its unrelated local changes are outside this reconciliation.

## Evidence carried forward, not rerun as new physics evidence

**GitHub-reported, independently inspected in the final review:** successful
first-attempt push runs at the actual landed main commit:

| Workflow | Run |
|---|---|
| Documentation and executed materialized provenance | [40040151106](https://github.com/techrote/cybersand/actions/runs/40040151106) |
| Native C++ validation | [40040151380](https://github.com/techrote/cybersand/actions/runs/40040151380) |
| GDExtension/Godot | [40040151125](https://github.com/techrote/cybersand/actions/runs/40040151125) |

The linked log review records Python suites **14/81/24**, all five historical
producer replays v2–v6, and LCB Godot totals on both Linux and Windows:
physics **174/0**, catalogue **774/0**, negative contracts **74/0**, manifests
**26/0** (assertions/failures). Provenance actually executed and passed with no
unmaterialized runtime files. Native executed the 84-test suites.

**Independently executed:** the earlier local closure probes and source-matched
Windows Godot checks remain evidence at their recorded revisions, not new runs
of this documentation-only change. **Characterization-only:** retained campaigns
and v7 re-reduction. **Contract-model:** policy, inertial and gas expectations.
**Blocked:** all 90 candidate arms, native gas and three-family World execution.

Controls and v2–v6 remain byte-unchanged; v7 accounting bodies equal v6, with
**20 closed / 4 unverified source-sink timing / 3 unverified reaction amount**
and `changed_from_v6=[]`. Protected definitions, goldens and inventories remain
unchanged. This change edits no runtime, fixture, record, dependency or runner.

## Current claims and successor limits

The [roadmap checkpoint](../reference/status-and-roadmap.md#liquid-comparison-build-design-checkpoint--2026-10-23)
owns the current gate table. Current-status passages in the development handover,
Water programme/design, family policy, comparison contract, scenario catalogue
and implementation handoff now route to that decision. Navigation routes are
updated together. Dated audits and original evidence are preserved.

Issue summaries #213 and #200/#201/#202/#203/#204/#212 are reconciled with the
same checkpoint. The original #213 admission checklist is retained as historical
tracker text; successor requirements remain future work. Gate B is a bounded
reversible design PASS, not completion of #204 or a representation/ABI winner.
#202 has delivered scenario apparatus, not the complete comparison host.

Only a **separately scoped initial opt-in #200 start** is admitted. The owner
currently holds both #200 and #212; neither starts in this reconciliation.
Admission excludes #212, a pressure/inertial port, schema/ABI freeze, defaults
changes and Rapier integration. Production #45/WEX decisions and Current Water
versus other-liquid semantics are unchanged.

## Documentation validation

Validation on Windows with Python 3.12.10 (no explicit process timeout; each
command completed in seconds):

- `python tools/ci/check_docs.py`: PASS, no errors or warnings.
- `python tools/ci/check_m11_consistency.py`: PASS, 18 retained records and 28
  source hashes checked against the historical revision.
- `python tools/ci/check_repository.py --require-materialized`: PASS, all 18
  runtime files materialized, no errors or unmaterialized runtime files.
- `python tools/docs/retrieval_eval.py --output <external-output>`: frozen 32
  questions unchanged; 21/32 canonical hits at 1, 32/32 at 5, MRR 0.7953.
- The same evaluator with `--queries docs/reference/retrieval-challenges.json`:
  116 supplementary questions, 93/116 at 1, 116/116 at 5, MRR 0.8839. New LCB01
  is rank 1 and its expected facts were checked against the roadmap. It is
  reported separately, not as an improvement to the frozen question set.
- `git diff --check`: PASS. The diff is documentation-only; all existing dated
  audits, runtime/fixture/record files and the frozen 32 questions are unchanged.

The initial isolated-worktree documentation/provenance runs reported six missing
companion-source references. The five referenced files were then materialized
outside the source repository from the CI-pinned companion revision
`6a58311982941b75f46e22109a0829e5acb83c7e`; `git lfs checkout` materialized the
existing pinned runtime objects before the passing checks above. These are
documentation/artifact identity checks, separate from the landed runtime results.
