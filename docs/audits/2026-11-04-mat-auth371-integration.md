---
title: MAT-AUTH-001 PR371 adopted-main reconciliation and integration qualification
status: Current
document-kind: evidence
scope: Source-preserving 353-A reconciliation, compiler escaping correction and independently reviewed qualification; final hosted and merge identities belong to the PR ledger
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md, 2026-11-04-mat-auth-353a-compatibility.md, ../reference/validation-evidence.md]
---

# MAT-AUTH-001 PR371 integration qualification — 2026-11-04

**Bounded A-only integration candidate.** The owner authorized reconciliation of
the existing shadow compiler with the adopted architecture, correction of genuine
defects, independent review, resulting-head checks and a guarded merge only after
every applicable gate passes. The [PR371 ledger](https://github.com/techrote/cybersand/pull/371)
records the final immutable candidate, hosted runs, artifact identities, review
disposition and actual merge/post-merge outcome. This in-tree record does not
predeclare those external results or complete broad #353/#352.

## Source authority and non-rewriting reconciliation

| Identity | Source |
|---|---|
| Adopted main at intake | `3da7e7be4a6af4c85e03a7d8a0ed57229e5db33d` |
| Final documentation-only #357 head | `ad20ca47f11eb8f634b334c87521951400cc1cca` |
| Independently reviewed original implementation | `6d3737594beb39e83e555f66f2e81184a4bdbf77` |
| Original implementation tree | `936e81b364b3977cdf06248607bc20b2f85f04ba` |
| Original base and common ancestor | `9b776d109e7843fb9b2d25239f9d088181309aa1` |
| Frozen legacy authority | `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` |
| Pinned companion documentation | `6a58311982941b75f46e22109a0829e5acb83c7e` |

An isolated worktree uses the existing
`feat/mat-auth-353a-compatibility-shadow-20261104` branch. A normal merge of
accepted main preserves both accepted architecture and original implementation
in ancestry. There is no rebase, history rewrite, forced push, competing compiler
or import of another material/World branch.

Six overlapping documentation files required manual reconciliation: the docs
index, architecture plan, development handover, retrieval index, roadmap and
validation ledger. Current summaries now say #357 is merged/adopted, A is
implemented and being qualified, B and #354–#356 need separate admission, and
#358 remains experimental. Architecture sections1–10 and the original adopted
section12 body are preserved verbatim. Section13 owns the new status; explicit
historical wrappers keep old decisions interpretable. The original architecture
audit and all original implementation receipts remain byte-identical.

Supplementary MAT-AUTH fixture v3 and MAT353A fixture v2 update only their first
question's revision-sensitive status facts and fixture metadata. Queries,
canonical routes, source routes, unrelated question objects, frozen32 and
challenge157 remain unchanged. The canonical shadow guide explains the current
workflow and directs dated results here and to the PR ledger.

## Independently found generator defect and correction

The reviewer reproduced a valid free-text family purpose containing `??/` that
passed schema validation but made the generated header fail the parity driver's
own C++20 `-Wall -Wextra -Werror` build: GCC emits a trigraph warning even though
C++20 does not interpret it. `_cpp_string` now escapes question marks as `\?`.
No diagnostic flag or validation rule was relaxed.

The added regression generates a complete header containing all nine trigraph
spellings, quotes, backslashes, control characters and UTF-8, compiles it with the
same warning policy and compares the actual binary-file readback byte for byte.
The regression failed before the repair and passes afterward. Binary output
avoids a false Windows failure from CRT newline translation. The focused suite
increases from98 to99 tests; no old assertion or negative control is removed.

The existing catalogue has no affected text. Its C++ and GDScript shadow bytes,
all authored values and normalized catalogue digest remain unchanged. Only
`inspection.json` and `manifest.json` refresh the compiler's own source identity
and the inspection artifact hash. The compatibility lock is untouched.

## Independent metadata, query and backend proof

The [new native receipt](mat-auth371-integration-20261104/native-parity.json)
records original-authority and generated-candidate compilation, complete input
hashes and actual exhaustive query results. Its `source_commit` field identifies
the frozen legacy authority; the integration commit/tree is a distinct identity
recorded by the PR ledger and exact-head workflow checkout.

| Comparison | Executed coverage |
|---|---:|
| Allocated descriptors / fields per descriptor | 132 /15 |
| Valid IDs / reserved invalid slot | 131 /10 |
| Hard-surface / granular-support identities | 101 /9 |
| Ordered pair rules / specialized records | 56 /19 |
| Semantic families / memberships | 7 /33 |
| Pair resolver combinations | 16,777,216 |
| MaterialRules pair-wrapper combinations | 16,777,216 |
| Viscosity combinations | 16,777,216 |
| Appearance/projection combinations | 17,170,432 |
| Density-exchange combinations | 327,680 |
| Validity / lateral-rate combinations | 65,536 each |
| Family membership combinations | 2,048 |
| Descriptor/capability/layer-kind byte domains | 256 each |

The [pinned Godot readback](mat-auth371-integration-20261104/gdscript-parity.json)
authenticates editor4.7, its complete archive, the matching native receipt and
snapshot, then loads the native metadata shadow in an empty temporary project.
It passes132 material and256 capability rows. Native Slush1080 and fallback1100
remain distinct. No fallback simulation, production project, pixels or World
physics is qualified by this metadata readback.

Independent adverse probes also verify rollback after a staged-directory rename
failure, preservation of input bytes/mtime when an output file is hard-linked to
the source, and actual Godot readback of all trigraph spellings, UTF-8, control
bytes1–31 and Unicode line separators. Existing symlink/input/output guards,
nonwriting checks and deterministic permutation tests remain enabled. The tools
remain offline build utilities, not a hostile concurrent filesystem or
crash-durable transaction service.

## Identity and active-branch consequences

All27 protected owners authenticate against immutable legacy main, independently
of the editable lock. Production native/GDScript/LCB files are unchanged relative
to adopted main, including Cell/save/transport/quantity/policy sources. Transport
v1 still has its81-material schema, reserved10 remains invalid, and synthetic
powder132 remains an isolated compiler fixture. No production target imports the
generated shadow headers or GDScript.

| Retained identity | SHA-256 |
|---|---|
| Legacy catalogue | `82b5ab9a6e87ae817072390105052f8a5ac6d0ee22b3301cd973efdfc7fdbad3` |
| Legacy capability matrix | `33c608f875e3d8b5730f1d3b81a54dbeff9579b433e061535610a8bfa276e237` |
| Unchanged compatibility lock | `8b4d3351cbe4380e976655d10dc34c4bf9e81d95442719a53770b62d219183dc` |
| Corrected compiler source | `81a0658655574ee5e65ecc144db9750b9128380595d51af70c2b04d0a209a098` |

Live overlapping PRs at intake were #358 `7383946a`, #347 `5b9b5a98`, #370
`9a7436aa`, #162 `19f7ff43` and #343 `2aff460c`; all were unmerged. None is
imported or modified here. #358's132–137 claims remain branch-qualified and do
not allocate new production identities in A.

**The universal Documentation guard will reject future changes to protected
owners**, including World, fallback, material headers and identity tools. This
is an intentional frozen checkpoint, not a claim that those files can never
change. Integration owners for #347/#358/#370 and later work must present a
separately reviewed compatibility transition. Do not delete protected rows,
refresh hashes or change the fixed baseline just to obtain a green check.

## Qualification and CI boundaries

The corrected focused suite passes99 tests:49 compiler,22 compatibility,
13 native report-path and15 Godot receipt/output cases. The independent reviewer
repeats the complete suite and native parity, then accepts the corrected tooling
for A only. The [review receipt](mat-auth371-integration-20261104/review.json)
binds its exact tool/output identities and independent probes.

The resulting-head record must cover documentation, all existing LCB capability,
wire/hash/native-artifact/normalization/receipt/registry checks, validation
contracts, provider/scheduling policy, retained M11, retrieval,18 materialized
runtime payloads, Git LFS and whitespace. Historical-ledger replay initially
failed in the local partial clone because historical blobs could not be
materialized. Restoring that clone's promised-object fetch configuration repairs
the environment; no ledger, old hash, assertion or production source is changed.
The incomplete first local run remains separate from the final run.

Original hosted Documentation41749294625 and artifact13285826248 qualify only
the earlier head. The changed Documentation workflow retains its bounded shadow
checks and90-day parity artifact. Its runtime-provenance step is skipped while
draft and must execute in ready/post-merge acceptance; skipped is not passed.

Independent workflow review establishes that additive `materials/catalogue/**`
and `tools/material_catalogue/**` are implementation paths under the existing
ready-scope classifiers. The configured final transition therefore requires
all six Native families (including sanitizers) and complete Linux/Windows Godot
execution/coverage. At intake the unchanged planner derived251 Linux cases in20
shards and237 Windows cases in19 shards. No path exemption, threshold, watchdog,
matrix, source-lock or runner policy changes are made to avoid these gates.
No changed path admits a separate Water, palette or PLAY campaign. Main push
will also trigger the ordinary Native/Godot checks if this candidate merges.

Local metadata/query execution, existing source-byte identity and any later
standard runtime regressions remain separately described evidence. They do not
admit a production consumer switch, fallback/native physics equivalence, human
gameplay acceptance, new materials or completion of downstream issues.

## Remaining programme boundary

After successful A-only integration, the next recommendation is a separate,
minimal #353-B consumer-migration admission review. Start with one constant
consumer whose switch can preserve runtime semantics and identity-bearing source
bytes. If a change cannot preserve the digest-bound literal headers/parser form,
stop for an explicitly versioned compatibility transition with rollback.

#354 requires reproduced liveness cases; #355 owns endpoint/state/quantity
effects; their overlapping World writes must serialize. #356 may inspect
accepted metadata, but editing needs a real consumer and applied readback.
Parent #352 and broad #353 stay open. No B implementation, material rebalance,
runtime packs, hot reload or later programme stage begins in this assignment.
