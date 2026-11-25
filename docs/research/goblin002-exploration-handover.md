---
title: GIP-014-goblin-002 exploration specialist handover
status: Planned
document-kind: research
scope: Branch-scoped goblin exploration mechanisms and bounded experiment memory; Draft/HOLD
canonical-for: [goblin002-exploration-handover]
last-reviewed: 2026-11-25
related-documents: [gip014-goblin-gameplay-qa.md]
---

# Exploration specialist handover — Draft/HOLD

## Source and ownership

This successor begins at predecessor `d4484bd5b488cb419bfaa94f1e69be8128734405`,
including the separately documented shared CI repair. Predecessor native gameplay
qualification and evaluator identities are preserved by ancestry; the additions
below do not relabel that evidence.

The exploration lane owns `godot/goblin/goblin_policy.gd`,
`goblin_state.gd`, `goblin_coverage.gd`, `goblin_corpus.gd` and
`godot/goblin/tests/test_exploration.gd`. The lead owns the controller,
laboratory and fixed-profile file controls. The gameplay lane owns the actual
action adapter and its observations; the replay lane owns tapes, independently
recomputed campaign results and regression packages.

## Current source behavior

The six original policy generators remain intact: CONTROL, WANDERER, BUILDER,
TINKERER, CURIOSITY and RANDOM. Ten additional personalities share finite
intentions and weighted state-sensitive action selection: STATEFUL, NOVELTY,
COVERAGE_HUNTER, DISASTER_ARTIST, BOUNDARY_GOBLIN, HISTORY_GOBLIN,
MATERIAL_ALCHEMIST, ACTOR_ENTHUSIAST, IMPATIENT_SWITCHER and
OBSESSIVE_REPRODUCER. Their action families and parameter choices differ under
matched synthetic observations; native behavioural diversity remains a separate
campaign result.

New personalities use the actual offered adapter menu. Reusable primitives
construct cups, place two admitted materials, advance simulation, breach and
repair gates, exercise reversible edits and authored persistence, visit bounded
corners, or investigate observed actor capabilities. An offered or queued action
is never treated as a successful action. A proposed actor placement does not
make its intended identity selectable.

`goblin_state.gd` produces a bounded state projection from actual observations.
Missing facts stay unknown. The projection includes fixture, observed world size,
pause state, tool/material/radius, history, bounded selection and clipboard state,
actor models and spatial zones, pilot role, saved-state availability, camera,
configuration and coarse native progression phase. Exact generation, revision,
tick and physical epoch remain separately available as observation identity.
Their increasing integers do not create unlimited novelty.

Material composition is explicitly a source-matched captured-region sample.
It is not inferred from selected material, fixture recipe, nominal capability or
the entire World. Every accepted material sample checks its capture operation,
native identity, paused source stability, bounds and array shape.

## Coverage contract

Current-episode coverage and historical search hints are separate.

| Dimension | Required observation and meaning |
| --- | --- |
| Action vocabulary | Actual admission, observed native before/after and completed terminal status |
| Action transition | Adjacent completed admitted actions; a refusal or partial operation breaks adjacency |
| State transition | Admitted completed or partial operation between bounded factual state signatures |
| Material interaction | Source-matched captured-region adjacency or independently read edit transformations; no inferred chemical reaction |
| Tool/material | Completed native edit and an actual observed tool/material pair |
| Actor/environment | Observed actor model, authored fixture, world spatial zone and pilot role; no inferred contact or route success |
| Lifecycle | Observed pause/play, world replacement, authored identity, actor population, control or saved-state transitions |
| Boundary/refusal | Actual refused outcome with its explicit classification and reason |
| Outcome | Observed terminal status, receipt/change bucket, native progression relation and independent failed-assertion identities |

Each map holds at most 2,048 keys, then reports saturation explicitly. Counts
cap at one million. Refused parameter variants reduce their repeat-selection
priority without being promoted to completed-action evidence. Parameter variants,
native observations absent from a record, partials and refusals have separate
reported counts. The predecessor's `observed_action_counts` remain attempted
policy-history statistics; the new `coverage` object is the admitted-coverage
authority.

## Corpus and controller integration

`goblin_corpus.gd` is pure data. It accepts no path, executes no action and
performs no file or network access. Controller-owned verified-profile operations
provide fixed-path clear/import/export controls.

A corpus holds at most 64 interesting records and 2 MiB of serialized data.
Complete action prefixes stop at 128 actions. Observations later in a 1,024-action
episode retain identity and classification, but no truncated setup prefix and
no claim of a resumable physical state. Retention favors higher-scored discoveries
and independently failed assertions; equally scored oldest records retire first.

A record binds exact fixture ID/version, authored fixture digest and provenance
digest. Successful complete prefixes may be explicitly reused only from a newly
installed matching authored fixture and before the first policy decision.
The preserved six baseline personalities do not use prefix replay, maintaining
their controlled comparison role. Imported records are marked
`imported_unverified`; serialized confirmed findings are downgraded to unresolved.
No import creates current-episode coverage, and no failed assertion is automatically
classified as a production defect.

Import is transactional and requires the finite adapter action validator.
Malformed or oversized nested values, unknown actions, duplicate record identities,
wrong numeric bounds, stale semantic record hashes, incomplete prefixes and
failure-as-success claims refuse before any retained memory changes.

Controller sequence:

1. Construct one corpus for the isolated laboratory session and optionally import
   a bounded supported record through `import_data(value, adapter_validator)`.
2. Configure a policy, install the disposable fixture and call
   `policy.bind_memory(corpus, context, reuse_prefix)`.
3. Supply context `fixture_id`, `fixture_version`, `fixture_sha256`,
   `provenance_sha256`, `seed` and `personality`; the provenance digest is the
   canonical digest of the full exact runtime/source provenance.
4. After actual execution and independent assertions, append the transcript row,
   then call `policy.observe_result(transcript.steps.back())`.
5. Persist the bounded `corpus.export_data()` through the controller's fixed
   profile location. A subsequent process resumes an experiment queue or reuses an
   authored prefix, never an asynchronous physics snapshot.

Policy API remains `configure`, `next_action`, `observe_result` and `summary`,
with additive `bind_memory`, `coverage_memory` and `describe`. Summary includes
the current intention, last novelty, coverage, memory classifications and the
explicit prefix-reuse request. Corpus exposes `begin_episode`, `observe`,
`export_data`, `import_data`, `clear`, `summary`, `reuse_actions`,
`search_hints` and `compatible_context`.

## Qualification and retained limits

The execution host disappeared during intake before any local implementation
existed. Implementation continued as tool-store source and recoverable Git blob
objects. After replacement, the shared predecessor checkout and pinned runtime
were restored. Neither the outage nor the original workspace capacity problem
is classified as a CyberSand defect.

A separate pure temporary Godot project ran the exploration tests on Linux x86_64,
first with available Godot 4.7.2 for parser feedback, then with exact
`4.7.stable.official.5b4e0cb0f`. The latest exact-version synthetic test run
passes **131 checks**, including all 16 policies, distinct action-only sequences,
source/capture admission, refusal starvation, exact-context memory reuse,
transactional hostile imports and 1,024 synthetic observations with bounded
retention. It is mechanism evidence only: no native gameplay occurred in that
pure project and no game-engine defect was found by it.

Command:

```text
Godot_v4.7-stable_linux.x86_64 --headless --path <isolated-pure-project> --script res://goblin/tests/test_exploration.gd
```

Shared-project/native, graphical, long-horizon, replay, Windows and extracted
package qualification belongs to the integrated mission ledger. A pure test pass
does not close those gates. The exact final integrated source, campaign outcomes
and runtime/package identities must be supplied by the lead.

## Documentation change map

The predecessor guide remains the preserved evidence home. This branch-scoped
handover records the new mechanism contracts and test limitations. The lead's
successor guide, mission ledger, retrieval exclusion and developer controls will
route this candidate explicitly. Accepted startup, production physics, ordinary
Workbench behavior, the historical archaeology corpus and other active programme
branches are unaffected by this lane.
