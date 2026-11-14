---
title: Owner authoring and world intent — 14 November 2026
status: Approved design
document-kind: decision
scope: Direct owner clarification of product intent; implementation, qualification and execution permissions remain separate
canonical-for: [owner-clarifications-2026-11-14]
last-reviewed: 2026-11-14
related-documents: [../reference/product-intent-and-priorities.md]
authority: owner-confirmed-intent
---

# Owner authoring and world intent — 14 November 2026

## Provenance and scope

The owner supplied these clarifications directly in the engineering archaeology
conversation and then explicitly authorised their capture under Milestone 1.
The authorised assistant transferred that conversation into the
[programme plan record](https://github.com/techrote/cybersand/issues/571#issuecomment-6871615830).
That GitHub comment is a transcription by the assistant, not an independently
owner-authored GitHub approval. This record preserves the stated intent and
marks interpretations and unresolved engineering details separately.

The owner said [#534](https://github.com/techrote/cybersand/pull/534) **broadly**
matches their intent. This does not adopt every sentence, milestone quota or
acceptance condition in that PR, and does not authorise its merge. The current
record governs these clarified product questions; historical implementation
failures and source-qualified results remain evidence with their original limits.

## Paint, play and the Workbench

**Confirmed:** CyberSand is a paint-and-play engine as an authoring system.
Workbench is the creative workshop, control centre and monitoring outpost, with
creative-mode and development/cheat-level control in an ergonomic interface.
Make valuable capabilities compatible with and accessible through Workbench.
Provide easy-to-learn, multiple levels of access to dials, modifiers and controls,
while allowing deeper manipulation. Painting should develop toward the range
between classic MSPaint and GIMP/Krita.

The engine should remain flexible across a passive plasma chamber, a forest
drone game, a digging game and other experiments. The owner wants continued
integration, testing, tuning and incremental improvements while personally
evaluating authored scenes. **Game-facing scoring and consequential player/actor
combat damage wait until the arrangements, materials and actors feel fun.**
This is not a prohibition on internal diagnostic or training metrics.

**Confirmed near-term interest:** revisit NPC controllers, Rapier actors and drone
training. Envisaged authoring roles include conversational autofill, automated
feature/flavour/item generation, and tiny/local models for detailing, texture and
randomisation. Model roles may evolve; these are not permanent capability claims
about any model or instructions to start training.

## Physical character and destructible structures

**Confirmed principle:** “convincing>consistent.” Deliberately authored effects,
approximations and selectable behaviours are desirable for appearance, art,
feel, feasibility, significant performance savings and interesting possibilities.
The owner does not regard scientific parameter sweeps as the primary way to
judge feel at this stage. Representative scenes and continued owner evaluation
matter. This does not retroactively make a failed experiment pass.

**Confirmed outcome:** cutting or blasting coherent pieces loose so that they
move, roll or topple is valuable. Full building structural-integrity analysis
is not a prerequisite; deliberately rigged collapses can be useful.

**Exploratory owner suggestion:** “prepare then declare,” using authored chunk
sizes and break conditions for predictable detachment. This is a promising
mechanism to investigate, not a selected algorithm. A fracture piece need not
equal a storage chunk. Native ownership/ACK preparation is a separate concern.

**Engineering interpretation, not a new owner dictate:** correctness and targeted
performance checks remain useful for data loss, ownership and specific technical
claims. Historical scientific campaign thresholds should not silently become
universal product-feel requirements.

## Save, Flatten and compatibility

**Confirmed:** saving should preserve the desired evolved material layout without
unexpectedly destroying the session's Undo history. Oil painted in mid-air and
allowed to settle should restart in its saved location. Acid used to damage a
wall, followed by water and fire cleanup, should not reappear merely because the
original construction strokes were replayed.

**Confirmed:** explicit Flatten is a material-occupancy snapshot using two bytes
per cell, allowing burdensome or blocking construction history to be discarded.
It is not a full physical checkpoint. Normal map saves need not always flatten;
richer authoring data can remain useful. Neither this clarification nor the
word “save” requires persisting the entire session's Undo stack.

**Confirmed:** do not promise advanced cross-version compatibility of all old maps.
Flatten may provide a fallback that recovers useful material layout in newer
versions. Material identity mapping and container/version handling remain
engineering details. This is not a guarantee that every old simulation state or
every future material ID remains interpretable. Flatten is also distinct from
merging the visual/semantic layers of Strata.

## Live materials and layered presentation

**Confirmed:** Materials Lab should support easy material modification and
audition, including changing values in a Workbench window for dynamic/custom
trials. The existing comparison tabs are appreciated; isolated comparisons
alone do not fulfil the desired current-scene interaction. Which properties can
apply safely at runtime remains an engineering question.

**Confirmed:** the four-layer Strata Theatre presentation should be an available
Workbench option. Its visual impact is important. Historical integration
exclusions are not a permanent rejection; the prototype's exact clocks and
cross-layer event rules are not automatically the eventual product contract.

## World extent, persistence and time

**Confirmed:** one fixed canvas plus persistent areas loaded while travelling
should cover most intended uses. Broad continuous canvases should accommodate
biomes or small towns; later presentation can disguise boundaries. The prepared
brief interprets moving beyond “1:1 canvases” as allowing non-square/broad maps,
not changing display-pixel scale. Concrete dimensions await practical work.

**Confirmed:** a useful simulated border around the viewport/activity, potentially
extended in the travel direction, is desirable. On returning to an area,
approximate headless catch-up is preferable to a conspicuously frozen room.
Use **game time**, not real-world offline time. Occasional transitions lasting
a few seconds are acceptable. An optional deliberate **simulate ahead** control
is desired. Approximation and quantisation can be acceptable.

**Engineering questions:** retained state, bounded catch-up algorithms, activity
margins, cross-area exchanges and material-policy evolution remain unresolved.
Track the last simulated/accounted-for time rather than merely last visit if an
area can keep simulating in a border. Headless execution still consumes compute.
These observations do not authorise implementation or a large benchmark campaign.

## Interpreting abandoned attempts

**Confirmed history:** implementations were sometimes set aside because results
disappointed, a concurrent approach looked more promising, supporting systems
landed elsewhere, or the branch became stale relative to short-term goals.
A second implementation could begin minutes after the first exploratory one.
Missing debriefs therefore do not establish rejection of the idea.

Preserve the purpose, result, stopping reason when evidenced, surviving value and
successor separately. An unknown stopping reason remains unknown. Substantial
past effort also does not establish present merit.

## Authorisation remains phase-specific

The owner authorised Milestone 1 investigation and capture on one isolated branch
and one Draft/HOLD PR. Merge, canonical successor issue creation, historical
retirement, broad Markdown/RAG rewriting and implementation remain separate gates.
Current active work and historical custody holds are protected. Product intent
does not automatically resume a held branch or grant execution permission.
