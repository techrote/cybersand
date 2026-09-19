---
title: Issue 12 Stage 3 Luna draft rejection review
status: Current
document-kind: evidence
scope: Parent review of two interrupted, untrusted substitute-worker drafts; neither draft was integrated or accepted as Stage-3 evidence
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../../operations/soliding-stage3-freeze.md, producer-hook-review.md]
---

# Issue 12 Stage 3 Luna draft rejection review

## Why this record exists

The requested `gpt-5.3-codex-spark` runner was invoked explicitly on 2026-09-19
and rejected before work began because that model was unavailable to the active
ChatGPT-backed Codex account. Two disclosed `gpt-5.6-luna` high-effort substitutes
were then started in isolated Producer and Connectivity worktrees. Owner direction
changed while they were working; both were stopped at their next safe checkpoint.

These outputs are **untrusted drafts, not implementation or validation evidence**.
No Luna-authored change entered `codex/issue-12-stage3-integration` or `main`.

## Retained identities

- Producer worktree branch `codex/issue-12-stage3-producer` contains local-only
  commit `e9348f1336d67ae54d71a63528fddc070c2576e4`, based on Stage-3 freeze head
  `a440e9aad3c18b6ebe196c283b7413420636ab86`. The binary-diff stream passed to
  `git hash-object --stdin` is `0a1a6ae6d7a26c82d8ad6add8d902d55eabd268a`.
- Connectivity worktree branch `codex/issue-12-stage3-connectivity` remains at
  `a440e9aad3c18b6ebe196c283b7413420636ab86` with one untracked file,
  `native/include/cybersand/settled_regions.hpp`, SHA-256
  `0CB165251EBFBAA010F892F6D864459C4DA3A5711D4393C777F0F6E60A5E9C5A`.

The local worktrees preserve the source drafts for inspection. They are not pushed
as candidate branches and must not be cherry-picked as implementation shortcuts.

## Parent review: Producer draft

The Producer draft added a wrapper/header seam and declarations but no World
constructor, mutation, worker-barrier, activity, event, mask, inclusion, failure,
sampling or service implementation and no meaningful tests. It therefore covers
none of the frozen producer matrix as executable behavior.

Independent source review also found reasons not to reuse the wrapper unchanged:

- `tile_at()` assigns `optional<DiscoverySignals>` to `DiscoverySignals`, so the
  draft is not type-correct as written;
- duplicate canonical keys return `Unchanged` without proving matching bounds;
- registration uses a linear key search, retaining quadratic total setup growth;
- every rectangle invalidation linearly probes every tracked tile, making common
  direct edits scale with total tracked coverage rather than local change;
- refusal counts attempts as unknown tiles rather than unique unknown coverage;
- fixed capacities and memory cost were selected without evidence; and
- the declarations expose an integration shape before the ownership hooks exist.

Useful retained idea only: connectivity needs an owner-serialized, revision-checked
value seam for exact tile tuples. The replacement design must derive direct tile
mapping from canonical geometry and must not adopt the draft's global scans.

## Parent review: Connectivity draft

The single header was neither compiled nor tested. Independent review found
multiple Stage-3 blockers:

- it accepts different payload/signals at an unchanged tile revision;
- noncanonical Empty becomes a normal publishable component instead of blocking
  connectivity candidacy;
- `DiscoverySignals::occupied` is omitted from the signal refusal;
- every upsert rebuilds all cross-tile adjacency using tile-pair and cell-pair
  scans, which is neither local nor resumably budgeted;
- adjacency capacity exhaustion globally poisons otherwise unrelated candidates;
- component/region digests include allocation-order tile slots;
- insertion of a previously untracked tile does not retire facing-neighbor region
  completeness when the tile can create a new bridge;
- region generation increments can wrap;
- boundary arithmetic and `llabs(wx-rx)` can overflow near signed endpoints;
- `published_revision` stores a work-unit counter rather than a dependency witness;
- duplicate adjacency edges can consume capacity for one shared face; and
- no adversarial fixture or build integration exists.

Useful retained ideas only: immutable complete tile inputs, exact component keys,
generation-bearing region observations and explicit sealed/unknown edge coverage
match the frozen layering. Replacement code must implement those ideas with local
revision-bound adjacency, canonical ordering and complete-only publication.

## Disposition

Both drafts are rejected as implementation. Their negative findings reduce future
rework but satisfy no Stage-3 exit item. Correctness-critical Producer and
Connectivity work continues under direct parent ownership from clean integration
head `5001f7f8665cf4e3bc67b3617796127c908ac368`.
