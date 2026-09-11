---
title: Water Feel Lab programme synchronization
status: Current
document-kind: evidence
scope: Planning/documentation synchronization after owner-led #19 refinement; no runtime implementation or production migration
canonical-for: []
last-reviewed: 2026-09-11
related-documents: [../operations/architecture-programme-water-feel-addendum.md, ../operations/architecture-programme-prompts/fractional-presentation.md, ../reference/status-and-roadmap.md]
---

# Water Feel Lab programme synchronization

## Purpose

Record the repository housekeeping performed after issue #19 was expanded from a presentation-only experiment into fractional presentation plus Water Feel Lab/H-preparation.

This is a planning/documentation synchronization record. No production Cell, Water solver, renderer, runtime policy, save format or adapter behavior is changed by these commits.

## Preserved prior evidence

Completed #15/G-C, #16/G-L and #17/G-P evidence remains unchanged. In particular:

- mass8 remains #17's quantitative/reference Water precision;
- current Water coherence 0..12 is exactly representable in four bits;
- lower/higher precision behavior measured by #17 is retained as evidence rather than reclassified as equivalent;
- no production layout or precision migration is authorized.

The new owner-led refinement changes how later desirability is decided: numerical divergence is descriptive evidence, while later controlled human evaluation judges perceptual adequacy under fixed presentation and hard correctness invariants.

## Synchronized planning surfaces

Branch: `codex/issue-19-water-feel-lab-sync`, based on the completed #17 state-precision branch.

Updated/added:

- `docs/operations/architecture-programme-prompts/fractional-presentation.md`
  - expanded into the self-contained #19 V + H-preparation contract;
  - four-level presentation, Water Feel Lab scenarios, runtime mass3..8/coherence0..12 policy, UI/profile/launch resolution, Apply+Reset and blind A/B preparation;
  - retains #17 correspondence as the trust gate and does not select a human winner.
- `docs/operations/architecture-programme-water-feel-addendum.md`
  - new dated post-G-P planning authority for the affected #19/#18 ordering;
  - records the principle that quantitative equivalence and perceptual adequacy are separate gates;
  - leaves completed C/L/P evidence intact.
- `docs/operations/experiment-tower.md`
  - retains current #13 functionality as Current;
  - adds a clearly marked Planned #19 Water Feel Lab extension without claiming unimplemented controls exist.
- `docs/reference/status-and-roadmap.md`
  - records #19 as V + H-preparation, #18 as held pending a later human-selected target/no-go, #20 unchanged and G-final open.
- `docs/reference/retrieval-corpus.json`
  - adds the Water-feel programme addendum to current architecture-programme retrieval.
- `docs/reference/retrieval-index.md`
  - routes questions about #17 perceptual interpretation, #19 deliverables and #18's held state.
- `docs/reference/architecture-programme-questions.json`
  - adds explicit development questions for perceptual minimum, H-ready #19 and #18 admission.
- `docs/reference/programme-gate-questions.json`
  - updates PG03 facts for expanded #19 and adds PG04 for the post-G-P precision/perception distinction.

GitHub #19 was separately revised in-place to match this contract. #14/#18 receive dated issue-thread notes rather than historical evidence being silently rewritten.

## Deliberate non-changes

- Historical #17 audit/result bytes are not rewritten.
- Existing #13 evidence is not re-labelled as Water Feel Lab evidence.
- No H preference issue is created yet; its final charter should consume the actual #19 apparatus after implementation.
- #18 implementation is not admitted by this synchronization.
- #20 dependency is unchanged.
- No production ABI/save/render/profile migration is performed.

## Validation scope

Repository-side readback should verify the new branch contains the synchronized prompt, addendum, roadmap, Tower note and retrieval files and that #14/#18/#19 issue notes point at the same sequencing.

The repository's local documentation/retrieval scripts cannot be truthfully reported as executed by this GitHub-only synchronization unless a later CI/local run records them. Any existing provenance/release failures remain inherited rather than repaired here.
