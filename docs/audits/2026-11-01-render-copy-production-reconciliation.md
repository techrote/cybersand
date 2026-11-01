---
title: Current-main chunk-run render-copy reconciliation
status: Current
document-kind: audit
scope: Frozen current-main R source selection, native differential proof, runtime provenance and graphical Control versus R qualification
canonical-for: [render-copy-production-reconciliation-evidence]
last-reviewed: 2026-11-01
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../operations/profiling-observability-and-performance.md, ../reference/validation-evidence.md]
---

# Current-main chunk-run render-copy reconciliation

## Frozen source and authority

This implementation starts from main
`25ce0731d89b9540c2d95cfa8bae321c37e6e118`, tree
`26bac27fb535f15e594dc62df8eac183d7b75fea`, on the fresh branch
`codex/render-copy-production-20261101`. Main had not advanced beyond the
accepted #340 scheduling rehabilitation when fetched. No subsequent rebase is
part of the experiment. The final PR remains draft and must not merge without
explicit owner mergedown approval.

| Authority | Source identity | Use in this reconciliation |
|---|---|---|
| [#290](https://github.com/techrote/cybersand/pull/290) | Corrected executable `60915dc86631271ea8661377a3458149adda9361`; World blob `a6afd8cad4264ac2eca0362d14711158e3606760` | Production function, including last-included-coordinate overflow preflight |
| [#301](https://github.com/techrote/cybersand/pull/301) | Publication stack `b5e415784d5e0884684869dd622883dacf3c9de5` | Historical runtime/source provenance; no binaries silently reused |
| [#333](https://github.com/techrote/cybersand/pull/333) | Older reconciliation `21d44e43e071d2d5777c2ed46a92f59675639599` | Superseded integration evidence; original draft preserved |
| [#335](https://github.com/techrote/cybersand/pull/335) | Investigation `902fc5b518855911c1b6761a7165573843e567ed` | Test-only differential coverage and real-consumer tracing; not production R authority |

The current-main World blob is
`6987e9d05564cb11294d7704514df2f811a26c48`. Its entire difference from the
corrected #290/#301/#333 World is the intended `copy_render_cells` function:
35 added lines and 9 removed. The header and all other World operations remain
unchanged. All 80 native inputs in #301's historical manifest match the ported
native source; nevertheless this task rebuilds and republishes both libraries
through a newly scoped current-source publisher, retaining current build and
host-execution identities.

## Production contract

Each row is split into contiguous runs ending at a chunk boundary. One address
calculation and one chunk lookup serve each run. The unchanged material and
state accessors feed the unchanged `project_visual_state`; missing chunks
produce Empty with zero stored state. Existing layout/stride validation remains
first. Zero extents return before dimension subtraction, and the inclusive
last-coordinate check accepts `INT64_MAX` while refusing unrepresentable
regions before writing. The counted-column loop never forms an overflowing
exclusive endpoint.

World remains sparse and signed: this change introduces no world clipping,
dirty-state modification, simulation change, publication policy or ACK change.
The literal reference exists only in tests/benchmarks. Ordinary runtime has no
Control/R selector and no second permanent production implementation.

## Qualification plan and evidence boundaries

The registered native case compares complete guarded destination buffers for
dense/sparse 1024-square frames, partial and signed rectangles, all material
state lanes, fractional Water policies, deterministic randomized Worlds,
absent chunks and integer boundaries. Separate before/after receipts cover
each implementation's persistent bytes, quantities, temperatures, hashes,
revisions, resident storage/chunk counts and dirty metadata. Paired continuation checks
compare subsequent simulation with an untouched World. Any byte mismatch is
a blocker.

The benchmark retains actual per-sample values and p50/p95/p99/max. Separate
builds of the same benchmark use frozen main's production function and R, so
an external literal oracle cannot inflate the claimed production speedup.
Structural address/lookup/run counts are source-derived logical counts, not
observed hardware counters.

The graphical campaign uses real Godot `Main`, the same tracing worker in both
arms, separately source-matched Control/R libraries, fresh processes and normal
versus deliberately withheld ACK cohorts. It records monotonic causal events,
native exchanges, publication, receipt, CPU patch, texture API submission,
ACK retirement, retry-chain length and frame intervals. It preserves final
native/CPU/texture equality and a rendered PNG witness. CPU texture-call time
does not establish GPU completion time. Software-renderer evidence does not
establish physical Windows/NVIDIA or human feel acceptance.

E is conditional on a meaningful residual after the primary comparison:
repeated normal-client feedback chains, material worker stalls, graphical
hitching or operationally important excess copy work. Withheld-ACK retries
alone do not force E. No E, coalescing or baseline-drop implementation is part
of this initial candidate.

## Runtime publication and CI

The newly scoped publisher uses the existing shared publication engine with
its exact source/tree, native/build-input ledgers, target-host execution,
artifact-byte checks, four-path append and branch lease. Its fresh request is
armed only after source review. Historical requests are not replayed.

All existing #340 workflows, concurrency caps, retry/setup policy, watchdogs
and expected-cost shard scheduling are preserved. Full qualification uses
manual dispatch at the frozen candidate while the PR remains draft. Draft
skips are not passes. Documentation/provenance, Native, complete Godot,
Water, PLAY identity and the informational native-scope advisory retain their
separate acceptance scopes.

## Current disposition

Local GCC 13.3 normal qualification passes 153,284 assertions, 231 region
comparisons, 8,338,180 compared payload bytes, 42 nonmutation receipts and 18
invalid-call refusals. The same ASan/UBSan binary first failed because this
executor's ptrace environment does not support LeakSanitizer. That original
failure is retained; a subsequent run with only leak detection disabled passes
the same counts. Hosted leak detection remains enabled and required. These
assertions include fixture/state checks and are not 153,284 separate regions.

Independent source, tests, observation-seam and publisher reviews found no
material production defect. Review corrected resident-storage wording and
excluded processes that crash after writing a valid graphical receipt from
successful cohort aggregates. Those processes still fail the whole campaign.

Implementation and qualification are in progress. No new graphical
performance, full-CI or production-acceptance result is claimed by this
preparation record. Final source/runtime hashes, retained failures,
measurements, independent review and the R/E decisions will be appended after
execution. No unrelated physical/Y1 or PLAY stack is consumed.
