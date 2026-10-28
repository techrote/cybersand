---
title: SOL-DETACH-001 bounded ejection-search policy preregistration
status: Approved design
document-kind: audit
scope: Frozen protocol and experimental admission for opt-in diagnostic-only ejection search; no measured candidate outcome
canonical-for: [sol281-ejection-search-preregistration]
last-reviewed: 2026-10-28
related-documents: [../systems/solid-detachment.md, 2026-10-28-sol281-unresolved-cause-characterisation.md, 2026-10-27-sol281-compound-cellular-coupling.md]
---

# SOL-DETACH-001 — ejection search preregistration (2026-10-28)

**Registration source/head:** `37294a3b5913957dc5165c04dc746f221aeed309`
(draft PR #283, stacked on #282). The last executed source on that branch is
`756ae4882d346a1439244189c76eda8496070229`. Neither a candidate
implementation nor a candidate runtime result exists at registration.

## Baseline and question

The copied 12-float result ABI records displaced, unresolved, immovable,
no-target and relocation-refused separately. The existing search checks **nine**
longitudinal positions (from `max(1, ceil(penetration))` through that value
plus eight), each with **nine** symmetric tangent probes in this exact order:
`0, +1, -1, +2, -2, +3, -3, +4, -4`. At most 81 candidates are checked per
overlap; a candidate must be in bounds, empty, outside all transient masks
and reachable without crossing a hard surface or another transient owner.
The path permits crossing ordinary *movable* cells, as in the Current baseline.
World relocation, not the proxy, performs authoritative writes.

The actual Linux/Windows 520-cell, six-proxy, one-body dense-bank experiment
on `756ae488` recorded 1,557/1,592 and 1,501/1,541 unresolved displacement
attempts, respectively (97.8015%/97.4043%). **Every** live unresolved event
was classified no-target; these were cumulative asynchronous attempts, not
unique cells, and absolute totals are not a cross-run oracle. See the
[retained dated evidence](2026-10-28-sol281-unresolved-cause-characterisation.md).

**Hypothesis:** bounded diagnostic widening reduces failed searches in a
crowded movable Sand bank, without changing native ownership, collision holes,
liquid policy, Rapier motion, or baseline probe decisions.

## Frozen candidates, ordering, capacities and refusal

- **A — Current:** existing 81-probe search with unchanged normal, physics
  impulses, path rule, material rules and authoritative relocation.
- **B — Opt-in extended:** execute those **same 81 candidates in exactly the
  same order first**. Only after A returns no target, inspect the original
  nine distances at tangent offsets `+5,-5,+6,-6,+7,-7,+8,-8`
  (72 additional probes), followed by eight further distances
  `first+9 .. first+16` with tangent offsets
  `0,+1,-1,...,+8,-8` (136). Hard maximum **289** candidates per
  overlap, with the existing endpoint/path admission unchanged. No new
  queue, allocation, stochastic exploration, mutation before selection,
  per-cell body, material law or alternate liquid solver.
- **Admission:** B is diagnostic-only at native-world construction/reset
  under an explicit bounded `ejection_policy=1`; 0 is the default. Reject
  any other value before mutating the old world. An ordinary demo-world reset
  restores policy 0. The GDScript fallback's experimental selector also
  defaults to 0. No runtime, save, material or construction policy inherits
  B implicitly.
- **Refusal:** if the extra 208 candidates find nothing, preserve the
  existing no-target and reaction-impulse semantics. No relocation after an
  invalid/stale owner fence, through hard surfaces, into any mask, or into
  nonempty destinations. Baseline successful destinations must remain the same.

This is an *experimental displacement approximation*, not a license for
large-distance teleportation. Inspect accepted displacement distances and
visually reject B if long moves look unphysical even if the no-target rate
improves. Do not promote on contact-count improvement alone.

## Locked qualification plan and decision

1. **Controlled protocol pairs, native and fallback, workers 1 and 4:** the
   same 9×10 Sand enclosure near a 1×1 body produces A:no-target and
   B:displaced; a completely filled 17×18 area produces no-target in both;
   a hard Wall stripe blocks B's longer reach; an isolated Sand pixel returns
   the exact same target under A and B. Verify source/destination material
   counts, result-body/sample offsets, unresolved cause sums and repeat
   signatures. Malformed ejection policy must refuse without replacing authority.
2. **Real 520-cell host, per-platform paired A/B runs:** reuse the exact
   setup, cut, 120+30 native settling ticks, 360 Rapier steps, worker count 4,
   six registered proxies, hole probes `[2,0,0,6]`, Sand count 104, Water
   mass 1020, aggregate payload 520, retained 21/20/296 lifecycle suites
   and current movement thresholds. Record actual sample count, attempts,
   cause partition and rate; do not require equal raw attempts across runs.
3. **Main-thread cost:** time just the synchronous per-frame
   `session.physics_step()` calls (not awaited frame time); report
   p50/p95/p99/max microseconds and per-run total for A and B. Also publish
   actual frame timestamps/tick rate and native timing when available;
   the per-frame call measurement alone does not qualify total worker cost.
   Record target displacements and optionally distribution by distance.
4. **Success threshold (precommitted):** B must reduce the live
   attempt-level no-target proportion by **at least 20 absolute percentage
   points on each actual Linux and Windows host**, not merely reduce a
   cumulative raw count; both must meet the controlled protocol/prefix,
   conservation, hole, motion, stale-generation and all existing regression
   invariants. The paired p95 main-thread step cost must not exceed both
   **2.0× the platform-matched A median p95** and **2,000 μs**; stronger
   representative frame/worker evidence is required before production
   admission. This is a finite **experiment**, not an automatic release gate.
5. **Negative/no-go:** if efficacy, physical plausibility, platform parity
   or cost fails, retain B as an unselected diagnostic candidate or remove
   it in a follow-up; keep A default and record exact source, commands,
   artifact/runtime hashes, counterexamples and all non-passing results.

## Boundaries and independent gates

The native World retains authoritative cells until the established fenced
aggregate transfer; the aggregate exclusively owns its exact 520 tuples
thereafter. Rapier RIDs remain on the main thread, and the immutable
swept-proxy state/results cross the existing worker boundary. Six exact
rectangles, including crown and AABB holes, are never replaced by a filled
box. Do not alter selected Water/other-liquid solver options or their
construction-time application. Do not change Stage 3B's preregistered
campaign or specialist NPC/physics fixtures.

A scored B result requires source-matched actual Linux **and** Windows Godot
4.7/Rapier 0.35.2 runs, a pinned native build, exact source/runtime
receipts, independent code/evidence review and retained failures. Any
missing gate is explicitly **unqualified**. Branch #283 stays draft; issue
#281 remains open for reactive Wood, fracture, persistence, normal-app
integration, runtime publication and full final matrices.
