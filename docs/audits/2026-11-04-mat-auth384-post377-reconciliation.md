---
title: MAT-AUTH-001 B post-377 accepted-main reconciliation
status: Current
document-kind: record
scope: Bounded PR 384 source admission after accepted Phase A evidence, historical custody and the stop-before-Ready qualification handoff
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md, ../operations/material-liveness-investigation.md, 2026-11-04-mat-auth384-current-main-reconciliation.md, ../reference/validation-evidence.md]
---

# MAT-AUTH-001 B post-377 accepted-main reconciliation

**Current source reconciliation; STOP BEFORE READY.** The owner authorized one
ancestry-preserving merge of accepted #377/main into the existing #384 branch,
the necessary B executable-inventory update, fresh source-bound qualification
and normal cheap hosted Draft checks. No Ready transition, merge, auto-merge,
issue closure, new consumer, material/physics change or other-PR modification
is authorized. The [PR #384 ledger](https://github.com/techrote/cybersand/pull/384)
and retained new evidence packet record the actual published candidate SHA/tree,
command ledger, raw runtime evidence, hosted checkouts and final disposition.
This record defines the reconciliation; it does not reuse an earlier run as a
test of the commit containing this document.

## Authenticated intake and historical review

| Role | Exact identity |
|---|---|
| Independently reviewed previous #384 head | `c6d1603f3c144f6730e2014ab32b98b0240f1e37` |
| Previous candidate tree | `63ccd60e6e1943bdbcd19fe48e4e0fc28508b6b1` |
| Previous accepted main | `01f9b7c8e382ca6bdbaf0bf70c7847adc12fe0bc` |
| Previous accepted main tree | `4cf99921dc2b33233c3a254f4b6f27ed7cb0f204` |
| Accepted #377 merge / new main | `0103de80d11304388868f89f7b26c672ad6100ad` |
| New accepted main tree | `0ba07dc799afca43716bbab966f48266fa924718` |
| Accepted main ordered parents | `01f9b7c8e382ca6bdbaf0bf70c7847adc12fe0bc`, `c4d4aa0ab34436441af51f1431bc3555973e0932` |
| Existing branch | `feat/mat-auth-353b-display-names-20261104` |

[#377](https://github.com/techrote/cybersand/pull/377) merged at
2026-11-04 18:14:18 UTC. Its accepted content is Phase A investigation and
evidence. **H1 remains unrepaired; #354 and #352 remain open.** Its original
failed attempts, recovery chronology, source-specific Linux/Windows and
sanitizer evidence retain their historical meanings.

The [completed independent read-only GO report](https://chatgpt.com/library?file_id=libfile_d3ee9e7f5e108191905cc6560fffe1f1&account_id=personal)
was read in full: 29,905 UTF-8 bytes, SHA-256
`94b39e8b47fa964d60c31d3d204d71327f8685dd94bfa38005bc296c0a1830a2`.
It observed the old source pair at 17:55:47 UTC and returned **GO TO READY,
not merge authorization** for `c6d1603f` / `01f9b7c8`. Its conclusion is
historical for the new source pair. The similarly named independent-review
Markdown assignment is a prompt, not that completed report.

Both old packets were reauthenticated without rewriting them:

| Historical packet | SHA-256 | Manifest authentication |
|---|---|---|
| [Original reconciliation packet](https://chatgpt.com/library?file_id=libfile_b90009b1d2608191bd1456b61bc3711f&account_id=personal) | `1ba7c56ff137143d8f05217eb1523824a666881c61f94d0a772c77c772933094` | 271 entries plus manifest; 272 ZIP members |
| [Terminal hosted packet](https://chatgpt.com/library?file_id=libfile_1255ff1f033c81919e60e550fcd80401&account_id=personal) | `541446480803b12aa763ff75a3b4a5121e501e9c7b7630b065296b3645248359` | 7 entries plus manifest; 8 ZIP members |

All listed sizes, hashes and CRCs match. The old 32-command ledger, 64 process
streams and 24 raw B files authenticate as old-source evidence. Old hosted runs
`41863226175` and `41863226196` executed synthetic merge
`2ad16fc6312be29f03602934c60e7d11c72be009`, whose tree equals the old candidate.
They do not qualify this reconciliation.

## Accepted delta and shared-document resolutions

The exact old-main to new-main comparison has **145 changed paths**: 134 under
`docs/`, eight under `tools/`, two under `native/`, and one workflow; 133 additions
and 12 modifications. The retained packet lists every path, accepted Git blob,
byte length, SHA-256 and candidate identity. There are no changes under
`native/src`, `native/include`, `godot` or `materials` in that accepted delta.
The reconciliation itself preserves the previous #384 production display and
MicroScenario changes byte-for-byte; it adds no production/material authority.

The ordinary merge produced nine shared-document conflicts: documentation
index, architecture plan, development handover, shadow guide, retrieval index,
MAT353A and MAT-AUTH retrieval expectations, roadmap and validation index.
Their resolutions retain both programmes, mark the original Phase A admission
as historical and state the actual #377 merge separately. The original B
architecture section and anchors remain usable alongside the accepted Phase A
section. The merged retrieval corpus retains both canonical routes. Query
wording/routes and frozen32/challenge157 fixtures stay unchanged; only affected
revision-sensitive expectations advance. No historical #384 or #377 audit/raw
evidence file is rewritten.

All other accepted #377 paths, including the new workflow, probe, fixture,
MAT354 tooling and retained transport evidence, must match accepted main bytes.
The new `material-liveness-phase-a.yml` brings the workflow inventory from
27 to 28. Its path-scoped Draft investigation is unchanged; the #384 delta
against accepted main does not change its triggering paths. No manual campaign
dispatch or repeat of the 552-case scientific campaign is required here.

## Three independent authorities

| Authority | Authenticated source | Treatment |
|---|---|---|
| Frozen 27-owner compatibility lock | `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` | Original raw/LF source identities and lock bytes unchanged |
| Historical Main/CellWorld display oracle | `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`, tree `36ce5a01e754a141c321f41cac7f1c6b6059c371` | Original 277-case fixture unchanged; never generated from candidate labels |
| Current B executable admission | `0103de80d11304388868f89f7b26c672ad6100ad`, tree `0ba07dc799afca43716bbab966f48266fa924718` | Accepted inventory includes the exact native probe, with no exemption |

Only `B_ADMISSION_BASELINE`, `B_ADMISSION_TREE` and explanatory comments change
in the admission implementation. All guards, roots and 16 suffixes stay intact.
Main and the apparatus identity must still equal their historical pre-cutover
versions before applying the already approved exact transformation. The only
permitted consumer delta remains Main's preload/name method, the generated
labels resource and the MicroScenario source-list addition.

| Accepted input | Git blob | Bytes | SHA-256 |
|---|---|---:|---|
| `native/tests/material_liveness_probe.cpp` | `5185801e469cfed975b901243a42f3a02a0e1ee4` | 28,669 | `26e421d2b9de3e4e6c0c6e7e74f503f3f26f7baf17b02c6d02712eb15dcc9bb9` |
| `native/tests/fixtures/material_liveness_campaign_v1.json` | `0da7d77887f55bdaacc2f1b344ff48bfc16c98c5` | 359,666 | `320bd76b5bc69d68fe7ed21324999f9f1b9272109da646138a2b31820f1f2b4b` |

The C++ probe includes unchanged `world.cpp` for instrumentation and has its
own standalone entry point. Its recorded compiler dependencies are native
sources only. The production build lists exclude it; no generated UI names
are consumed. These conclusions use accepted source/build/dependency bytes,
not the filename alone. The JSON fixture is data: `.json` is absent from the
unchanged B executable suffix set and its bytes are authenticated separately.

Independent measurement gives old accepted inventory **660**, new accepted
inventory **661**, old #384 **661**, and reconciled B inventory **662**. The
probe is the only added accepted executable; the candidate adds the previously
approved labels resource and changes only Main/identity relative to accepted
source. The narrower MicroScenario source list does not acquire the probe.

Before the baseline edit, the original guard actually returned exit 1 for
`extra=['native/tests/material_liveness_probe.cpp']`, with no missing source.
That expected refusal is retained. Three focused tests add exact accepted
probe/fixture authentication, refusal under the retained pre-#377 admission,
and tamper/removal/rename/copy controls. Existing suffix, alias, routing, missing
apparatus, wrong-tree and frozen-authority adversarial tests remain in place.

## Fresh qualification and evidence custody

Freeze and qualify the actual published two-parent merge commit, after checking
that its parents are old #384 then accepted main. Retain a separate preliminary
local run if publication assigns a different commit SHA. Never relabel either.
The final command ledger must record source/tree/status before and after,
original argv, timeout, exit status, stdout/stderr sizes and hashes, toolchain,
artifact identities and unexecuted gates.

Required local checks are the 27-owner raw authentication, compatibility,
compiler, presentation, independent historical oracle, static B admission,
complete catalogue tests, native parity, separate GDScript shadow v2 and the
pinned Godot 4.7 four-stage B run plus verifier. Retain every legacy/candidate/
ordinary `sand` to `SAND` poison/rollback report, source manifest and process
stream. Both actual Main and inherited Web-controller routes must propagate
the poison, and rollback must restore the historical source-map fingerprint.
The 132-slot domain, invalid10, five exceptions and signed/int64 fallbacks
remain unchanged. Static/native/shadow receipts never substitute for B runtime.

Also execute documentation, M11, repository/materialization, LFS, CI provider,
workflow inventory/actionlint, focused contract/retrieval and whitespace gates.
Record retained #377 evidence authentication separately from execution: its
successful historical campaigns and failed Windows source-byte attempts retain
their original source and outcomes; no new H1/H2/H3 campaign is asserted.

The preceding review's LCB03 challenge miss and partial MAT-AUTH-01 answer are
historical retrieval limitations to compare explicitly with the fresh run.
Report new metrics and expected-fact sufficiency without retuning unrelated
queries or treating a canonical hit as complete answer coverage.

## Draft hosted evidence and next reviewer

After a guarded ordinary non-force publication, retain terminal Documentation/
provenance and Native source-scope advisory runs, jobs, attempts, original
artifacts and logs. Authenticate actual checkout SHA/tree and synthetic-merge
tree equivalence; distinguish executed, skipped and inapplicable steps. A Draft
provenance skip is not a materialized hosted pass, and the advisory supplies
**no Native-skip authority**. Do not bypass Draft suppression or manually rerun
expensive Ready-only jobs.

Request a distinct strictly read-only **GO TO READY / CONDITIONAL / NO-GO**
admission review for the new candidate plus `0103de80` accepted main. Include
both historical packets and the actual old GO report, this narrow source delta,
new published-head qualification and terminal hosted evidence. No independent
GO for this new pair is inferred from the old report or implementation checks.

After a new GO, a separately authorized Ready-state agent must complete actual
hosted materialized provenance, full Native/sanitizers, Linux/Windows Godot/
GDExtension, palette/backend and applicable Water/LCB gates; establish pinned
Godot 4.7 export-template provenance before reproducible Web export/package
loading; measure old/new lookup, startup and memory; and obtain a separate final
integration review. Those later stages are not started here.

At intake #358, #347 and #370 are Draft/unmerged; #162 is open/non-draft/unmerged.
None is imported. Recheck their state, accepted main and the expected #384 head
before publication and handoff. Unexpected head movement, unadmitted main drift,
authority mismatch, failed real-controller poison, rollback/custody mismatch
or an executable requiring exemption stops this task. **Record progress and
stop with #384 Draft and unmerged; keep #353/#352 open.**
