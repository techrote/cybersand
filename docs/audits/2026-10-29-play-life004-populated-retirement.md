---
title: PLAY-LIFE-004 populated command and lap retirement
status: Planned
document-kind: evidence
scope: Actual five-rig host regression for populated input and lap retirement through construction-time policy replacement and reset; source-bound platform qualification pending
canonical-for: []
last-reviewed: 2026-10-29
related-documents: [../systems/player-control-playground.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/liquid-prepared-setup-and-receipts.md, ../operations/local-build-and-validation.md, 2026-10-28-play-life002-solver-reconstruction.md, 2026-10-28-play-life003-prepared-shutdown.md]
---

# PLAY-LIFE-004 populated retirement — 2026-10-29

## Clean committed-source Windows qualification

Source **`fc3143fa4796b3a02463f9cd8e86387adb0947b6`** executes strict import
plus all five rigs, **335 assertions / zero failures**, 67 per rig. All six
processes exit0 without diagnostic error, skip, timeout or retry. Ten independently
populated transactions complete: five supported pressure/reference rebuilds,
five retaining resets and ten exact `run_or_epoch` refusals. Every old lap has
one credited gate and positive completed native elapsed ticks, with exactly two
pending primary edges and held movement. Every final host joins its owner and
retires its actual Rapier session.

Collector `C:/tmp/run_play_life004_exact.py` starts only from clean exact HEAD,
verifies all six Git/working test hashes, all80 native input hashes and retained
native/Rapier payloads, reuses the strict existing `run_case`, checks every result
row and requires all737 scoped tested inputs unchanged after execution.
This later evidence append does not change the six executed test files; its
final CI/review remains separately required.

```text
python C:/tmp/run_play_life004_exact.py --root C:/Users/_/.codex/worktrees/play-pending-prepare-20261028/khybersand --source fc3143fa4796b3a02463f9cd8e86387adb0947b6 --output C:/Users/_/.codex/tmp/play-life004-20261029/exact-fc3143fa
```

Platform Windows x86_64; pinned Godot `4.7.stable.official.5b4e0cb0f`;
native DLL `e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb`
and Rapier DLL `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
Native build/source remains `d7e35aa3897ffa0bde422ece98226c551588040e`;
all80 current native inputs match, without a rebuild claim. Import/case/predicate
limits remain240s/180s/15,000ms. Import takes4.289s;
Acrobat/Buggy/Bike/Lander/Barrel take5.474/5.280/5.190/5.188/5.391s.
These are strict process durations, not gameplay or performance measurements.

| Retained local evidence | SHA-256 |
|---|---|
| `identity.json` | `84a1cd736ea020c6eca127d6095a31f9628575183d6af1f5010bd29b338b2251` |
| `timings.json` | `cca97bfcce5be774a0151b7c4a4818577217f16d261f616b4956e28372ecc20d` |
| `results.json` | `6666ee966bc5c02a8a1e09215721db3dc23258ade6f0d11842557004d5a7dd41` |

Raw logs and all737 input hashes remain in the named output directory. No
previous-head proof is promoted to a later source. Hosted Windows/Linux,
final independent source/execution review and accepted-tree verification remain
pending; #269/#270 are open.

## Source and dependency boundary

Branch `codex/play-life004-populated-retirement` starts at accepted main
`91778603db950a817b82fc6a4f75efee201f5044`, tree
`3e513ab8b38a5d1d8076b5a4156d234f8d8a068f`, after #287/#288/#289 passed
their exact-head checks, distinct source/execution reviews and guarded merges.
The [LIFE003 acceptance record](2026-10-28-play-life003-prepared-shutdown.md#accepted-source-and-subsequent-main-verification--2026-10-29)
separately records those results and subsequent passing main push runs.
The source root is
`C:/Users/_/.codex/worktrees/play-pending-prepare-20261028/khybersand`.
The unrelated dirty primary checkout `C:/khybersand` is preserved.

This child owns six new test paths and focused documentation only. Concurrent
PR #290's native render-copy source is separate; no native, production gameplay,
runtime, dependency, default, solver or CI configuration change is selected.
The supplementary six-worker evidence remains byte-identical at
`43ebaf9e8f60ee7bd45360ec8dab28502348c793`, with all51 original logs backed up
outside temporary storage. Its measurement source and limitations are unchanged.

## Added coverage and limits

LIFE001/LIFE002 inspect fresh replacement state; UI003 already populates one
real Jet Barrel lap before reset. This successor adds all five mechanical rigs,
construction-time policy reconstruction and reset with genuinely populated
production input edges, actual completed Rapier checkpoint progress and a
captured observed-identity command from the retiring session.

The apparatus reuses actual Main, `CyberSimulationWorker` and main-thread
Rapier. Fixture placement translates every articulated body through the bridge,
then requires an actual completed physics step/observed authored gate; it is
test instrumentation, not natural human traversal. Production keyboard events
populate ordered press/release edges immediately before the replacement request.
The replacement must retire the old graph, clear its lap/edges, reject the old
command for `run_or_epoch` through the new active session's human producer, and
require neutral input before fresh admission. A producer/schema/suspension
refusal would not establish the intended stale-identity fence.

Native World access stays on the exclusive owner. No new native-busy hook,
synthetic tracker state, second scheduler or timeout relaxation is introduced.
The established process/import/predicate bounds remain 180s/240s/15,000ms, with
no retries or skip masking. Source-matched local and hosted results, independent
review and final accepted-tree evidence must be recorded before acceptance.

This is not a native phase-job shutdown trace, failure-recovery campaign,
general race/leak qualification, equipment-effect replay test, physical gamepad
test, gameplay performance measurement or human-feel pass. #266/#268/#269/#270
remain open. Per-material admission, requested/applied receipts, construction
commit/refusal and defaults retain their accepted semantics; no live hot swap.

## Documentation update map

| Area | Disposition |
|---|---|
| Current behavior, controls and validation | Player contract adds the bounded fixture and its pending qualification |
| Ownership, interfaces, invariants, capacity and ADR | Existing worker, observed-command, Rapier, lap fences and solver construction contract reused; no change |
| Build/test and user configuration | Existing automatic strict test discovery and pinned runtimes reused; no command/default changes |
| Roadmap and navigation | Add a route without closing broader lifecycle or release gates |
| Retrieval | Add an independent PLAY question; preserve the frozen32 questions |
| Prior evidence | Append #289 acceptance; preserve all earlier source-specific results and failures |

## Qualification status

The first strict pinned Windows smoke executes import and Acrobat against the
six-file working overlay on main91778603. It passes **67 assertions / zero
failures**, one populated reconstruction, one populated policy-retaining reset,
two precise stale-command refusals and final owner join/Rapier retirement.
Helper SHA-256 `5b448eb78e1d5958f5695a81cf3480ef18cf2b4e89263650b6bc9c4765a3f5c5`;
the complete source hashes and raw logs are retained under
`C:/Users/_/.codex/tmp/play-life004-20261029/strong-oracle-acrobat`.
Import takes3.688s and the case5.200s; both exit0 without error, skip, timeout or
retry. This dirty-overlay smoke is not clean committed-source or five-rig proof.

The earlier `initial-acrobat` directory retains the initial source identity and
passing import. Its external collector reversed the strict runner's failure
Boolean and stopped before executing a case. The collector was corrected
outside Git, using a fresh directory; this was an apparatus failure, not an
engine test failure or retry of a failed case. Independent review also
strengthened the gate oracle before the smoke: a HUD refresh after placement
without a completed step must retain zero credit, then the completed physics
callback must credit the gate before any further HUD refresh.

Documentation, repository/runtime provenance, historical M11 checks and lexical
retrieval pass during preparation. Frozen32 retrieval remains32/32 at5;
the separate additive PLAY set is5/5 at1. Exact committed-source five-rig
execution, hosted Windows/Linux CI, final distinct review and merge remain
pending. Previous-head evidence is not transferred to a changed test.
