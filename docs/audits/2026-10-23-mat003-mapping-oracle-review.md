---
title: MAT-003 eight-arm mapping and independent oracle review
status: Current
document-kind: audit
scope: Independent document-contract review closure only; no implementation, apparatus admission, execution or timing
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [../research/mat003-correctness-only-plan.md, ../research/mat003-state-schema-proposal.md, ../decisions/ADR-015-material-state-schema-and-carrier-gates.md, 2026-10-23-mat003-budget-acceptance.md]
---

# Mapping/oracle review closure

Owner instruction: close the independent plan review findings with exact eight-arm mapping tables and an independent oracle contract, reconcile status wording, then independently review the revision. Preserve R16-T1 conditional status, both draft PRs and production; no implementation or qualification execution. Source intake is `49ad67dec6d754e8c8296e33eecf14180db25c74` on `codex/mat003-continuation`, managed source checkout in `C:/Users/_/.codex/worktrees/mat003-continuation/khybersand`, origin techrote/cybersand. The preexisting WCLEAR registration status marker was untouched. Accepted campaign inputs/artifacts/statistics, dependency pins and unmaterialized LFS runtime state are unchanged.

## Closure and independent disposition

An independent read-only reviewer inspected the revised plan, source carrier/accessor maps, schema and ADR. All four findings are **closed at document-contract level**, with no new blocking contradiction:

- Eight exact maps specify common fields, epoch, neutral16, unused bits, capability/refusal, byte order and intended ABI/stride. E8 retains epoch56–63/R40–55; expanded E16 uses epoch40–55/R56–71. K64-E16 retains epoch48–63/U40–47 and refuses every nonzero R request, including numerically small values.
- DUAL64 high-lane obligations are operation-relative: expanded E16 R may change high bits0–7 only; unused high bits8–63 remain preserved. Raw sentinel probes are distinct from schema-valid zero-unused-bit records and do not approve new semantics.
- The independent logical oracle defines bit enumeration, full canonical bytes, operations, refusal atomicity, common-field control projection, complete state/sidecar/ledger inventory, negative-verifier requirements and retained transition coverage. C64-E16 is a refusal control, never a successful nonzero neutral16 comparator.
- ADR/schema wording now distinguishes accepted qualification budgets from conditional semantics/maps/adoption. Stale unqualified budget-pending wording is reconciled.

The reviewer confirms152 processes and32 compiler invocations per platform remain consistent. Large complete endpoint datasets total at most about47.75GiB across both platforms under the stated cell/metadata caps, below50GiB; additional streams/checkpoints have explicit caps under64GiB. Eight endpoint datasets mean complete World states, not sampled cells. The independent review does not establish runtime exportability, measured resource compliance, ABI/sanitizer support or restoration correctness.

Canonical UTF-8/LF SHA256 identities independently read by the reviewer:

| Document | SHA256 |
|---|---|
| correctness-only plan | `f134267c2304cc03974605595089cced53f03a09918e097681ae3f6bf11c0b23` |
| schema proposal | `c0addb05320183297389a991e9003fb93f6a6c18202a4173c5d48cfe6f30fb2c` |
| ADR015 | `a1b408fc4127cb4a75a67be283556046ea906dc675b17c2fe58a7ebfcedb3ad4` |

## Documentation validation and checkpoint

On Windows x86-64 with local Python3.12, each documentation command used a30second command budget: `python tools/ci/check_docs.py`, `python tools/ci/check_repository.py`, `python tools/ci/check_m11_consistency.py`, and `git diff --check` passed. Historical M11 verifies18records/28hashes without rewriting history. Offline retrieval commands used `python tools/docs/retrieval_eval.py --output build/mat003-continuation/map-review-frozen.json` and the same command with `--queries docs/reference/retrieval-challenges.json --output build/mat003-continuation/map-review-supplementary.json`. Frozen32 remains21 at1/32 at5,MRR0.7937; supplementary125 is99 at1/124 at5,MRR0.8749. New MATSCHEMA06 ranks1; prior124 question objects and frozen fixture remain unchanged. Prior C09 lexical top5 miss remains retained. Manual source/expected-fact review, not lexical scores, supports the status/mapping conclusions.

Change checklist: canonical plan/schema/ADR own revised contracts; consolidated report and retrieval index route them, with supplementary question coverage. Production subsystem ownership/lifetimes/interfaces/configuration, roadmap dependency order, build/test tooling, user controls, persistence/streaming and accepted runtime evidence are unaffected. No new corpus owner is introduced; this dated audit is reached through the consolidated report. Recoverable checkpoint is the committed/pushed docs-only revision on existing draft PR221. The docs-only commit uses the GitHub Actions skip directive to avoid launching automatic qualification jobs under the owner's no-execution instruction; hosted exact-head execution is not claimed. Documentation checks are not apparatus tests; no native/Godot binary, qualification process or timing campaign ran locally for this task.

## Remaining gates

The exact proposed maps and oracle are now reviewable document contracts, not implemented or adopted formats. Future isolated apparatus work still needs separate owner authority, immutable source/fixture/verifier/binary/platform seals, source-bound full-state export and natural/prepared equivalence qualification, exact field encodings within output ceilings, sanitizer feasibility and independent apparatus readback/admission. No map may reinterpret historical raw records. Neutral payload tests do not approve R16-T1 Water overfill/history, feedback, epoch/carrier adoption or GEN-006 changes. Both PR211/221 remain draft; production and all accepted evidence stay unchanged. No new timing authority is created.
