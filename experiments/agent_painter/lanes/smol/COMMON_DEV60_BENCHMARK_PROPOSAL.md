# Proposed shared 60-request DEVELOPMENT evaluation contract

**15 November 2026 · SMOL worker research contribution · REVIEW-ONLY / NOT FROZEN**

This is a **cross-model suggestion** for the #568 shepherd and independent reviewer,
not a SMOL-only benchmark, a new corpus admission, a new evaluation launch, a
training recipe, a rubric frozen by the owner, or a request for the worker to
write shared #569 files. Its aim is to make the next common DEVELOPMENT cohort
comparable across SMOL, VOID, root SPROCKET and LFM2.5-VL. The current sole
SMOL PR #573 stays Draft/HOLD and all FINAL targets/images remain sealed.

## 1. Denominator and structural custody

Use **three families × four independent whole-structure assignments per family
× five precommitted semantically equivalent formulations per assignment =
60 language requests**. Each request has two **host-owned** replay seeds
(104729 and 130363), thus **120 possible native views**. The two seeds are
NOT two independent architectural, pipework or greeble structures. Similarly,
the five formulations exercise language robustness for **one** structure; they
must not be represented as five independent design generalizations.

| Family | Slot 1 — existing DEVELOPMENT | Slot 2 — existing DEVELOPMENT | Slot 3 | Slot 4 |
| --- | --- | --- | --- | --- |
| Greebles | `open_center_modules` | `spine_assembly` | **NEW DEV whole design — not yet admitted** | **NEW DEV whole design — not yet admitted** |
| Pipework | `three_branch_manifold` | `closed_loop_with_tap` | **NEW DEV whole design — not yet admitted** | **NEW DEV whole design — not yet admitted** |
| Architecture | `stacked_rooms_and_shaft` | `bridge_between_towers` | **NEW DEV whole design — not yet admitted** | **NEW DEV whole design — not yet admitted** |

The six named original DEVELOPMENT groups are *structural identities* from
source-633, not six prospective extra TRAIN examples. Do not add the new six
DEVELOPMENT whole designs or form prompts through the SMOL branch; shepherd and
shared corpus owner must admit/freeze them with the **same native evidence and
visible-group de-duplication** that would be required of new TRAIN designs.
A source-only compiler preview is not positive native admission. No original
FINAL target, image or structure is eligible for this expansion.

The future slot 3/4 design selection should be a **global** decision,
independent of any model's raw completions and performance. It must screen the
whole TRAIN/DEVELOPMENT/peer registry for topology AND whole-silhouette
near-aliases, including candidate P01 versus held-out manifold and R10
versus held-out loop. A low exact material IoU or nonisomorphic graph alone
is not proof of safe independence. Record distance/proximity as diagnostics,
not an invented automatic accept/reject threshold. Retain rejected candidates
and their evidence separately; never covertly move a DEVELOPMENT design into
TRAIN after seeing model failures.

## 2. Five common prompt formulations

For every one of the 12 frozen assignments, a neutral author creates exactly
five **equivalent** prompts before running *any* candidate on this suite.
The formulations are intended to alter expression rather than the underlying
design. They must specify all identity-defining invariants clearly enough to
judge request fulfilment, without handing the model compiler JSON/teacher
operations or a reference raster.

| Code | Formulation | Fixed information contract |
| --- | --- | --- |
| F0 | **Concise imperative** | One direct drawing request with primary topology/layout and scale/material constraints |
| F1 | **Constraints-first specification** | The same graph/geometry, exact counts, placement/connection/clearance constraints in natural language |
| F2 | **Spatial-relations description** | The same design expressed using relative positions and explicit connections/openings; no coordinate or graph change |
| F3 | **Outcome/function description** | The same visible components and relations explained by their purpose, without relaxing mandatory geometry |
| F4 | **Exclusions and correctness** | The same positive requirements plus logically redundant prohibitions of likely errors; never add a new harder task |

The formulation author must verify **semantic equivalence** in a separate
blind review. If an invariant cannot honestly be expressed in all forms,
revise the *whole* five-prompt set **before freeze** rather than silently
discarding a difficult formulation. Do not tune these prompts against SMOL's
known malformed JSON responses, P01 coordinates, old TRAIN patterns or other
lanes' sample outputs. Model-specific chat templates are applied by the
respective pinned official loader **outside** this canonical request text.

**Family-wide requirements across all five forms:** Greebles require visible,
recognizable panels/components and the assignment's intended negative space;
Pipework require actual connected topology, endpoint/junction/cycle counts
where applicable and consistent diameter; Architecture require strictly
orthographic 2D side elevation with horizontal floors, vertical walls,
front-facing openings and specified geometric clearance. Geometric clearances
are **not** gravity/jump/climb playability claims. Do not add perspective,
isometric tops, invisible passages or decorative disconnected branches as
implicit alternate interpretations.

## 3. Freeze procedure and immutable identities

1. Shepherd records 12 distinct structural group IDs, assignment/source
   program digests, family, target semantics and **TRAIN/DEVELOPMENT group
   disjointness**. Reviewer independently inspects the 12 visible target
   silhouettes and both native reference seeds. Sealed FINAL is not opened.
2. One common row builder emits 60 unique request IDs (e.g.
   `DEV60-G-S01-F0`), with a frozen `formulation_id`, `group_id`,
   `family`, literal UTF-8 prompt SHA-256, assignment criteria digest,
   source/admission manifest SHA-256, and evaluation contract version.
   The expected teacher program and protected reference artwork are *not*
   exposed to the model's prompt or to TRAIN optimization.
3. Independent reviewer audits the cross-product exactly
   (3 families × 4 whole groups × 5 forms), checks every group/form
   uniqueness, required semantic equivalence and no overlap with TRAIN.
   Freeze the **canonical request-manifest byte digest** and immutable source,
   native/runtime/compiler/schema identities before any model-first-pass
   evaluation; preserve the manifest and all accepted teacher/archive
   SHA-256 values in #568.
4. The six-prompt original DEVELOPMENT mini-cohort remains a **separate frozen
   historical comparator** (six unique requests / 12 seed views). Never
   retroactively mix its older prompt text, training objective, or scores
   into DEV60's denominator, even where a structural group matches.
5. If material assignment, wording, validator, numerical/seed or admission
   changes, mint **DEV60-v2** and re-evaluate all applicable candidates.
   Do not quietly patch a frozen row, cherry-pick prompts, or relabel the
   previous results with the new source.

Suggested manifest keys, for review only: `version`, `native_source_sha`,
`admission_manifest_sha256`, `schema_sha256`, `compiler_sha256`,
`seed_pair`, `groups`, `requests`, `manifest_sha256`. Never fabricate
a provisional SHA for missing slot 3/4 teacher data.

## 4. Raw first-pass and native execution rules

Each model receives the *same frozen request bytes*, with its own *pinned,
upstream-authentic* chat framing and EOS; greedy single first pass, recorded
token IDs, text bytes, stop reason, terminal EOS, JSON parse and compiler
rejection, all without repair, retries, hidden teacher fallback, selection
among candidates or model-specific extra hints. A shared nominal generation
budget of 512 new tokens is the baseline proposal, but report each model's
actual tokens and output bytes because different tokenizers do not imply
equal language capacity. Any truncation counts as a failed first pass; never
continue generation privately to fabricate compliance.

The compiler independently enforces schema/legal operations, then the **native
Art host** separately controls material whitelist, focus/seed, work budgets,
protected cells, acknowledgements, Stop, Undo/Redo, save/reopen and engine
authority. Only a compiler-accepted original proposal may enter native replay,
and its original accepted output is replayed at both host seeds. Store source-
matched receipts, **actual material cells** and original PNGs for each executed
view. A blocked, refused or rejected proposal has no claimed native painting.

For each request record three separate outcomes: (a) legal terminal completion,
(b) compiler/safety acceptance, (c) fulfilment of the specific structure and
visual intent after actual native painting. Keep art quality, graph connectivity
and native safety separate; no 'syntactically valid == good painting' shortcut.

## 5. Reporting and decision thresholds

Publish immutable raw per-request records, per-seed native receipts (or refusal),
original PNG gallery, model/adapter/checkpoint/recipe identities, source SHA,
artifact hashes, wall/CPU time, peak RSS, token count and at least the following
non-interchangeable denominators:

- **60 language requests**, 20 per family, 12 per formulation, 5 per
  structure. Macro-aggregate per family and per whole group before any
  across-form average; do not treat paraphrases as independent evidence.
- **120 potential host-seed views**, with explicit attempted/executed/accepted
  counts. A single compiler-accepted request may yield two legitimate native
  views but remains **one** unique language completion. If original decoder
  has no seed input, do not invent per-seed distinct model generations.
- **12 whole structures** as the independence denominator. Publish individual
  group success rates (0–5 forms each), including the held-out manifold and
  closed-loop failure modes; do not hide poor groups behind many similar
  successful views.
- **Authentic EOS, strict complete JSON, legal compile, real native safety,
  geometric/request-conformance and human visual usefulness** as distinct
  columns, each with an exact numerator and denominator. Source/method and
  omissions must accompany every score.

A reviewer/owner-defined useful-art threshold belongs in #568 and must be set
*before* seeing the suite's candidates. This proposal deliberately invents
**no** numeric near-alias threshold or automatic promotion. Published scores
are diagnostic; they never authorize default-provider promotion or merging a
Draft PR.

**Current gate at drafting:** original 12 TRAIN / 12 DEVELOPMENT seed rows /
six sealed FINAL remain source-633; **zero** new globally shared positive
TRAIN groups, **zero** new DEV60 whole designs/native admissions, no approved
DEV60 manifest and no useful SMOL freeze. The EOS-v2 two-step first pass
currently has **0/6** compiler-accepted original DEVELOPMENT requests.
The SMOL P01/R10 peer-comparison evidence at
[run #43669644596](https://github.com/techrote/cybersand/actions/runs/43669644596)
remains **review-only**, not a teacher admission.

**Handoff:** shepherd and independent reviewer may adopt, amend or reject this
contract in **shared #569** after global structural selection. The SMOL worker
must not generate, score against or optimize on DEV60 until it is globally
frozen; continue only genuinely new in-scope work while admission is held.
