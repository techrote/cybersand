---
title: "MAP-AUTO-03 three-lane Godot pilot integration"
status: Planned
document-kind: evidence
scope: Source-pinned and keyless integrated pilot of the three Atlas art lanes using actual Godot PNG captures, bounded revisions, independent structure checks and verifiable receipts
canonical-for: [issue-500-integrated-three-lane-pilot]
last-reviewed: 2026-11-07
related-documents: [../operations/atlas-agent-runner.md, ../tools/world-art-capture.md]
---

# MAP-AUTO-03 / #500 — three-lane real-pixel integration

## What this candidate actually does

The new pull-request-triggered, **keyless** workflow
`.github/workflows/atlas-agent-pilot.yml` checks out three independent source
identities: runner PR #516 (this stacked branch), capture-tool PR #506
`7b960b5eac5b7a4ed159ade97b1093a1b623ac19`, and the **unchanged**
world-atlas art PR #454 at `c4aab63eed538a25687c66d368b0801d2d2e04d0`.

Each of the existing three custody lanes runs a source-pinned, tightly bounded
pilot on a dedicated art collection without changing #454:

| Lane | Collection | Approved feature | Design intent |
|---|---|---|---|
| Terrain Art | `lumen-fault` | `seal-gate` | The previously observed improvement: two attached gate shoulders and a small rust accent, omitting the unaccepted floating/cistern edits |
| Ruin Detail | `silt-clockworks` | `flood-beacon` | Braced lighthouse/beacon ribs and a deliberately bounded brass crown |
| Art Curation | `drowned-observatory` | `broken-star-dome` | Bronze dome crown ribs and a small gold apex, keeping the original structural silhouette |

For each: real Godot 4.7 BEFORE capture; model-facing structured inspection;
actual source validators; safe `pack_add_rectangles` changes **on a disposable
working copy**; preview regeneration; real Godot AFTER capture; before/after
framing and SHA comparison; runner receipt verification; apply exported patch
to a separate staging copy; independent `pilot_quality.py` checks:
old geometry preserved, no changed palette/placements/variants, only one
allowed static feature modified, no existing-cell overwrite (even identical
material), no detached new mass, at least 20 and at most 2,500 new occupied
cells, and actual verified Godot pixel/pack change. All outputs are retained
for 30 days, including before/after PNGs, manifests, receipts and diff.

### Scope and claims

**This workflow executes a scripted no-key planner, not a Responses API
model.** The receipt explicitly labels all model calls simulated; nothing
in this workflow constitutes an artistic model's qualitative critique,
a new paid API smoke test, human benchmark/gallery superiority, four-native
planes, dynamic native physics acceptance, or a schedule migration.

A real `gpt-6-luna` before→model critique→edit→real-Godot-after run was
previously recorded on #516, but its original broad patch was independently
rejected for disconnected geometry and seal breaches. This new pilot instead
specifies small curated connected proposals. It is technical/structural
acceptance **only**; independent human side-by-side review of the reference
gallery is still required before art publication.

## Source and ownership safety

- Never run the script from #454 as an authorized direct writer; copy into
  disposable workspace and apply exported patch only to staging.
- Existing three ChatGPT scheduled workers stay unchanged. No recurring
  Responses API automation is installed, no secret is provided, and
  `workflow_dispatch` remains manual for the API runner.
- The #506 capture executable and Godot 4.7 archive are commit- and SHA-pinned.
  The actual Linux driver is OpenGL/llvmpipe under Xvfb; capture image pixels
  are not expected to be byte-identical on different hardware.
- Module quality is not fully decidable through geometry connectivity alone;
  human compositional and material-semantics review is an independent gate.

## Acceptance / next integration

Actual hosted results, run URLs, exact PR head, pass/fail and PNG identities
must be appended to the PR discussion after the workflow executes. A green
keyless workflow is necessary but **not sufficient** for #500 issue closure.

After #516 is independently approved and merged, reconcile this stacked branch
to accepted `main`; incorporate/qualify #506's real renderer dependency;
run a separately owner-authorised small paid three-lane pilot with verified
credit, per-project spend limits and isolated code execution, and request
human benchmark acceptance before any shared #454 write or schedule cutover.
