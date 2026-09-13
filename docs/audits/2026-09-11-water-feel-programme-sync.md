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
  - adds the Water-feel programme addendum to current architecture-programme retrieval; final diff is one intentional added corpus entry.
- `docs/reference/retrieval-index.md`
  - routes questions about #17 perceptual interpretation, #19 deliverables and #18's held state.
- `docs/reference/architecture-programme-questions.json`
  - adds explicit development questions for perceptual minimum, H-ready #19 and #18 admission.
- `docs/reference/programme-gate-questions.json`
  - updates PG03 facts for expanded #19 and adds PG04 for the post-G-P precision/perception distinction.

GitHub #19 was separately revised in-place to match this contract.

Dated issue-thread notes were added rather than silently rewriting historical issue evidence:

- #14 comment `5637574966`: records the post-G-P sequencing refinement, H gate and unchanged G-final status;
- #18 comment `5637576255`: records that implementation remains held pending a human-selected target/no-go;
- #19 comment `5637577364`: records repository synchronization and the H-ready/non-selection boundary.

## Deliberate non-changes

- Historical #17 audit/result bytes are not rewritten.
- Existing #13 evidence is not re-labelled as Water Feel Lab evidence.
- No H preference issue is created yet; its final charter should consume the actual #19 apparatus after implementation.
- #18 implementation is not admitted by this synchronization.
- #20 dependency is unchanged.
- No production ABI/save/render/profile migration is performed.
- The historical body of `architecture-programme.md` is not retrospectively rewritten; the dated Water-feel addendum is the later planning authority for the affected #19/#18 ordering, and roadmap/retrieval routes point to it.

## Final repository readback

A branch comparison of `codex/issue-17-state-precision` -> `codex/issue-19-water-feel-lab-sync` after housekeeping reports:

- branch status: ahead;
- ahead by 10 commits, behind by 0 at the readback point;
- nine changed files;
- **every changed file is under `docs/`**;
- no native, Godot, runtime, build, save or adapter source is changed;
- retrieval-corpus semantic diff is reduced to the single intended Water-feel addendum entry.

The branch therefore remains a documentation/planning synchronization only.

## Validation scope and remaining check

Repository-side readback verifies the new branch contains the synchronized prompt, addendum, roadmap, Tower note, retrieval routes/questions and this audit, and the relevant GitHub issue threads record the same sequencing.

The repository's local documentation/retrieval scripts (`check_docs.py`, `check_m11_consistency.py`, `check_repository.py`, retrieval evaluation and `git diff --check`) were **not executed by this GitHub-only synchronization** and are not claimed as passed. They remain an explicit first validation step when the branch is checked out for #19 implementation or earlier if a local/CI validation environment is invoked. Existing provenance/release failures remain inherited rather than repaired here.
