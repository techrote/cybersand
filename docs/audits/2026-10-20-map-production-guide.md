---
title: Map-production guide and retrieval validation
status: Current
document-kind: evidence
scope: Documentation-only production playbooks, source-scope review and retrieval evaluation against accepted main with separately pinned Deepworks examples
canonical-for: []
last-reviewed: 2026-10-20
related-documents: [../operations/map-production-workflow.md, ../operations/map-exhibition-design.md, ../operations/map-layer-polish-and-validation.md, ../operations/documentation-maintenance.md, ../reference/retrieval-index.md]
---

# Map-production guide and retrieval validation — 2026-10-20

## Request and source scope

After the Deepworks map was published, the owner requested another PR containing
Markdown RAG documentation that teaches an agent how to produce a map with that
level of quality and polish from start to finish.

This documentation-only branch, `docs/polished-map-production-guide`, starts at
accepted main `fc015a77d3b851fef4ea7734923bcdb3762a19a5`. It is independent of
[Deepworks PR #185](https://github.com/techrote/cybersand/pull/185), which was open
at this review. Deepworks-specific examples link to immutable revision
`7590316e01f0b6efbcc11598fc454656f38f8558`; its map, runtime changes and images
are not imported into this branch. Linked test results retain their original
source/platform scope and are not reclassified as accepted-main execution.

The source main baseline includes MAT-002 and its retained native runtime. Its
Strata Theatre authored ROI remains 640 × 360 over 1024-square backing. The new
guides explicitly distinguish that source from Deepworks's parameterized depth
path, free-camera host and bounded source programme. Source contracts retain
authority; the playbooks describe recommended production practice.

## Documentation package

| Canonical guide | Purpose |
|---|---|
| [Map production workflow](../operations/map-production-workflow.md) | Intake, material/reference research, measurable brief, capability selection, representative district, map expansion, bounded programmes, controls, polish, separate validation gates and PR handoff |
| [Exhibition design](../operations/map-exhibition-design.md) | Native reaction research, apparatus geometry, finite feeds, meaningful chemical/transport/growth witnesses, controls and complete-map validation |
| [Layer polish and visual validation](../operations/map-layer-polish-and-validation.md) | Overview/district/close-up composition, district-by-plane coverage, apertures, detail hierarchy, full-size rendering, source-local atmospheric pixels and actual HUD/input review |

The guides include reusable brief, district, exhibit and evidence worksheets,
ordered exit criteria, source links and retained failure lessons. They link to
the canonical material/ownership/capacity/build contracts rather than copying
those contracts into competing owners.

The entry route is wired through AGENTS, the documentation index, the retrieval
index, and short handover/roadmap sections. Three focused pages and six unique
canonical topics enter the explicit corpus. This dated evidence page is excluded
from default Current retrieval.

## Changed-claim review

| Area | Disposition |
|---|---|
| Materials and chemistry | Existing source rules and catalogue linked; no material ID, kernel, reaction table or API changes |
| Ownership, interfaces and invariants | Existing contracts linked; the rendering bridge answer is clarified to distinguish native leases, copied Godot buffers and explicit consumption acknowledgement; no runtime owner, interface or enforced invariant changes |
| Dimensions and capacities | Main-versus-example scope stated; constants remain in their source/configuration owners |
| Rendering, controls and launcher | Recommended implementation/review procedure only; no Godot scene, shader or control changes |
| Build, dependencies, runtime provenance and CI | Existing commands and source/artifact distinctions documented; no dependency, LFS payload, provenance manifest or workflow changes |
| Documentation and RAG | New guides, canonical topics, routes and five supplementary natural questions; old questions and historical records retained |
| Roadmap and handover | Narrow documentation reading route; no new physics completion or platform acceptance claim |

## Source and semantic review

The authors inspected current-main material, depth, ownership, build and
documentation contracts alongside the immutable Deepworks composer, runtime,
host, tests, captures and audit. The referenced PRs were checked for their
actual scope: Neon Reliquary is a separately loaded four-scene descent;
Blacksite is a continuous complex; Grey Area 51 is a five-tile bunker.

Review checks include native-versus-authored outcomes, finite exhibit feeds,
independent layer clocks, frozen distant architecture, full-map versus isolated
fixtures, actual pixels versus occupancy, and native/controller/render evidence
versus platform or user acceptance. Retrieval review additionally checks that a
canonical hit carries the qualifiers needed to answer the question.

Two review corrections were made before final validation: the runnable retrieval
command uses `--queries`, and the native acceptance table restricts the
absent-product condition to novel-product cases. Consumption, growth and
transport witnesses must account for direct feed contributions when that
condition is inapplicable. The rendered CI guidance is explicitly Linux scoped.
The exhibit page's source links were moved inline because the heading chunker
does not carry end-of-document reference-link definitions into every section;
per-chunk scope metadata also identifies the inspected main and pinned example.

The [rendering bridge answer](../architecture/rendering-and-gameplay-bridges.md#can-rendering-read-native-cells-directly)
was clarified after a retrieval regression. It now explains native lease release,
adapter copies, the separate private accumulator, frozen published generations,
complete packet validation and render-serial acknowledgement together. The
acknowledgement follows CPU consumption and the texture-update call; it is not
a hardware GPU completion fence. Source and the existing handoff regression were
inspected; no implementation behavior was changed.

## Validation

The [evidence manifest](2026-10-20-map-production-guide-evidence.json) records
the baseline, document SHA-256 identities, commands, timeouts, durations, tools,
fixture preservation, retrieval results and manual context review. Local checks
ran on Linux x86_64 using Python 3.12.14 and Git 2.51.1. Each check had an explicit
180-second timeout. Native/Godot execution was not repeated for this
documentation-only change; linked map results keep their original source and
platform scope.

| Gate | Accepted guide candidate result |
|---|---|
| Documentation structure | 95 corpus documents, 181 unique canonical claims; 1,957 local links and 177 heading anchors; zero errors or warnings |
| Repository/current provenance | Passed with `--require-materialized`; all 18 retained runtime payloads available; no source, dependency or runtime changes |
| Historical M11 integrity | Passed, 18 records and 28 source hashes; no claim of current runtime execution |
| Immutable example references | 49 blob/tree link occurrences, 22 exact Git objects, five fragments; zero resolution errors |
| Frozen fixture retention | All 32 questions byte-for-byte unchanged |
| Prior supplementary retention | All 77 complete question objects, including IDs, queries, facts and source routes, unchanged |
| New question retention | MAP01–MAP05 unchanged across all three measured guide revisions |
| Whitespace and scope | `git diff --check` passed; root README, implementation, dependencies and CI unchanged |

The immutable-link check resolves paths and fragments against the exact retained
Git objects. It proves those references identify real source content; it does
not claim fresh HTTP availability or execute the linked code. The frozen
question SHA-256 remains
`f2727cbe26633359798736537e06c7754db8c5588af90627f79c6bd798bbb6ec`.
Required companion-workspace inputs were already restored from identified
retained files and shared by the sibling worktree. The questions/checkers were
not altered to avoid those dependencies.

### Retrieval method and accepted result

The existing evaluator uses heading chunks with a maximum 420-word body,
metadata on every chunk, BM25, five returned contexts, no overlap and no
embeddings, query expansion or reranker. The accepted-main baseline was captured
before additions. The same evaluator and unchanged query fixtures measured
each candidate.

| Set | Baseline hit@1 | Baseline hit@5 | Baseline MRR@5 | Accepted hit@1 | Accepted hit@5 | Accepted MRR@5 |
|---|---:|---:|---:|---:|---:|---:|
| Frozen 32 | 21/32 | 32/32 | 0.8031 | 22/32 | 32/32 | 0.8229 |
| Existing supplementary 77 | 59/77 | 77/77 | 0.8652 | 59/77 | 77/77 | 0.8623 |
| New map questions 5 | — | — | — | 4/5 | 5/5 | 0.9000 |
| Combined supplementary 82 | — | — | — | 63/82 | 82/82 | 0.8646 |

The new questions are source-discovered development questions, not a held-out
benchmark. Their results are reported separately from the unchanged sets.
Canonical hits measure routing; the fact review below is a separate assessment.

### Preserved retrieval failures and corrections

The first measured guide revision passed structural/provenance checks but
reduced frozen hit@5 to **31/32**. Q15's buffer-lifetime owner, previously rank
five, was displaced by a new visual-guide section. Some broad new questions
retrieved a valid canonical page while omitting finite feeds/reset, the first
atmospheric pulse, HUD verification or the publication/merge distinction.

The second revision clarified the existing bridge answer and added compact
procedure synopses linking the detailed guide sections. Q15 reached rank one
and all canonical hit@5 results recovered. Manual review still found missing
qualifiers in the returned map contexts: backing versus authored dimensions,
exclusive-owner/layer-local scheduling, and hashes/timeouts/history/final-diff
requirements.

The third revision added those substantive qualifiers within the existing short
synopses. Each synopsis remains one chunk below the configured limit. The
second and third revisions have the same aggregate retrieval scores; the third
improves the completeness of the actual returned text. All three attempts,
their file identities and raw report hashes are retained in the evidence
manifest. Query wording, expected facts and canonical destinations were not
changed to obtain a score.

### Manual context sufficiency

| Question | Accepted canonical rank | Facts checked in the retrieved contexts |
|---|---:|---|
| MAP01 — complete production workflow | 1 | Actual checkout/material research, measurable brief, representative district, bounded expansion, separate gates and qualified handoff |
| MAP02 — reuse a linked implementation | 2 | Main 640 × 360 authored ROI versus 1024-square backing, absent capability assumptions, pinned Deepworks APIs and separate source/platform scope |
| MAP03 — native exhibits and replay | 1 | Minimal native apparatus, true reactants, exclusive-owner scheduling, bounded layer-local sources/sinks, native witnesses, finite feeds and reset-generation retirement |
| MAP04 — visible full depth and controls | 1 | District/plane coverage, controlled actual-pixel differences, native-masked first pulse, fixed other clocks, actual HUD/map pixels, input and platform scope |
| MAP05 — handoff and PR state | 1 | Launch/controls/replay, source/runtime/tool hashes, commands/timeouts, preserved fixtures/history, final diff, exact-head checks and distinct readiness/merge/platform claims |
| Q15 — live cells and buffer reuse | 1 | Immutable copies, native lease versus Godot generation lifetime, payload validation, explicit consumption acknowledgement and no GPU-fence inference |

Some checklist details still require the linked procedures: MAP04's exact
camera-extreme and paused-first-frame steps, and the complete evidence-record
schema. The manual review records those linked-detail limits instead of treating
a canonical hit as a complete generated answer.

Three existing queries move down while retaining canonical hits: Q19 from rank
two to three, C03 from two to three, and USABLE02 from four to five. Their
relevant scope/ownership qualifications remain in the returned contexts or
explicitly linked protocols; the review records that distinction. The retained
rank changes explain the slight existing-supplementary MRR reduction. They are
not hidden behind the combined-set score.

These results support the inspected development questions and documented
workflow. They do not prove unseen answer accuracy or that every future agent
will follow the guide correctly.

## Limits and publication

This package provides a source-backed guide and a deterministic lexical
retrieval baseline. It does not install a vector database, establish unseen
retrieval accuracy, or constitute a blind end-to-end trial in which a new agent
builds another map. General recommended steps are distinguished from the
version-pinned example's implemented behavior and tested results.

The final PR description records the published head/tree and exact-head hosted
Documentation/provenance status. Any skipped or inapplicable runtime jobs remain
distinct from passed execution. Opening the documentation PR does not merge
either this branch or the separate map implementation.
