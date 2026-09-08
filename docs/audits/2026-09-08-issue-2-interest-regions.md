---
title: Issues 1 and 2 — interest pause/re-entry and combined acceptance, 2026-09-08
status: Historical record
document-kind: audit
scope: Dated coordinated investigation, issue 2 implementation and platform-specific combined validation
canonical-for: []
last-reviewed: 2026-09-08
related-documents: [2026-09-08-issue-1-failed-ticks.md, ../systems/world-storage-and-interest-region.md, ../decisions/ADR-004-interest-region-and-reconfiguration.md]
---

# Issue #2 and combined acceptance, 2026-09-08

## Inputs and implementation order

Both current GitHub issues were read through authenticated GitHub access; both
were open with no discussion comments at intake. Source and workspace are separate
repositories. The [issue #1 intake](2026-09-08-issue-1-failed-ticks.md) records clean
source `bfac0bc` and workspace `6a58311`, pins, materialized runtime payloads,
retained diagnostics and separate binding checkouts. No issue #3 task was found
in the app task inventory; no other agent, shared artifact or environment was
modified. The user confirmed a USB backup; it was not inspected.

Implementation is on source branch `codex/issues-1-2`. Issue #1 is local commit
`0778845` and its browser probe lifecycle correction is `061ad23`. Issue #2 is a
subsequent focused change. No shared prerequisite or remote mutation was needed.
The parent workspace repository remains unchanged. Generated DLL/WASM/test output
is retained locally and excluded from implementation commits.

## Were the defects linked?

They have independent causes in adjacent lifecycle stages. F01 reproduces with no
region changes: accepted explosions and tick/epoch mutate before planning capacity
failure, and later-phase preparation can fail after an earlier phase moved cells.
F02 reproduces with successful ticks and no queued events: excluded active blocks
were aged into sleep and the old setter supplied no re-entry wake. Serial advances
the same excluded Sand because it deliberately does not filter the region.

The preserved diagnostics were reproduced unchanged against intake `bfac0bc`.
Their source and historical audits remain intact. The issue #2 red regression
`issue2-red` reproduced frozen re-entry after issue #1 was fixed, while all failure
regressions remained green. Thus issue #1 alone did not resolve issue #2.

Their interaction is real: region entry changes activity before events and core
planning; an accepted event can wake more work; capacity failure skips activity
finalization. The new combined fixture wakes new coverage, optionally applies an
explosion, then fails the candidate budget. Narrowing the region cannot resume
that partial World. Clear followed by fresh setup uses the latest region, runs
tick one and does not replay the explosion. Both event/no-event cases run at
one/four workers. The [issue #1 lifecycle table](2026-09-08-issue-1-failed-ticks.md)
records begin/events/planning/execution/finalization/publication/cleanup separately.

## Chosen contracts and tradeoffs

The user separately delegated both behavioral choices to engineering judgement.
Issue #1 quarantines failures until explicit clear/reset or validated replacement,
with no rollback, partial-world retry, automatic event replay or successful partial
publication. Desktop preserves its previous valid snapshot and reports failure;
Web stops synchronously and withholds partial output. Prior character/Rapier work
is not rewound. Native jobs still call no Godot APIs; Rapier stays main-thread owned.

Issue #2 pauses ordinary phased work outside selected cores, retaining content,
compact state, temperature, pending activity and quiet counts. Newly included
resident blocks wake once at healthy tick entry, including sleepers. Ordinary ticks
resume without elapsed-time catch-up. Explicit external writes/events and selected
neighbor reach remain possible. Serial still scans whole active chunks without the
filter. Cross-mode equality is only required by existing fixtures that promise it.

Rechecking sleepers costs bounded work at actual transitions and may expose capacity
exhaustion. This was chosen over retaining wake flags alone, which could leave stale
sleepers frozen. Equivalent coverage and coalesced excursions do not repeatedly
wake work. Transition checks reuse existing metadata passes, with no additional
sparse-world or cell scan/region-sized allocation. Existing whole-resident metadata
passes and epoch-wrap cell clears remain; no process-wide allocation/performance
claim follows from source counters. Custom single-worker blocks spanning cores are
conservatively retained whenever any part remains excluded.

Failed Worlds only latch region requests; no re-entry transition runs until fresh
recovery. Live state-preserving resize, general field catch-up and complete replay
remain Planned separately. Automatic retry, rollback and repeated unchanged-window
waking are Rejected for these fixes. See canonical
[storage](../systems/world-storage-and-interest-region.md),
[activity](../systems/activity-dirty-regions-and-waking.md) and
[ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md).

## Regression and runtime acceptance

- Native C++ Debug: 46/46 tests and C11 header inclusion passed. Six signed
  core/chunk boundary positions at one/four workers retain Sand/temperature across
  eight excluded ticks and resume one step. Sleeping, overlap/disjoint, unchanged,
  equivalent/coalesced, unbounded return, neighbor wake and custom geometry pass.
- Closed Water mass and Sand counts are conserved through a fixed moving-region
  sequence. Forty per-tick state hashes match at worker counts 1/4/4. Preallocated
  fixtures report zero owned chunk/temperature allocations across transitions.
- Event/no-event re-entry faults, subsequent rejection and clear recovery pass;
  all issue #1 native regressions remain green. The first combined fixture used
  Sand on an activity boundary with a one-entry budget and correctly exhausted
  the duplicate candidate count on fresh setup; the final fixture uses an interior
  cell so recovery itself fits its declared budget. That failed run is retained.
- Windows rebuilt release adapter: one/four-worker real faults and region resume,
  desktop exclusive owner stop/reset plus leave/re-entry, and actual Web controller
  publication/step gating passed. Full suite: 16/16 Godot runners, including
  existing Water, save, rendering, body/Rapier, Auto and worker comparisons.
- Both Web profiles were rebuilt with pinned Emscripten 4.0.20 and separate bindings.
  Actual Chromium browser outcomes, hashes and final checks are in the evidence
  JSON below. The async probe correction and initial threaded stall are preserved
  in the separate [issue #1 browser record](issue-1-browser-2026-09-08-evidence.json).

[Curated evidence JSON](issue-2-2026-09-08-evidence.json) identifies exact commands,
timeouts, revisions/local deltas, tools, profiles, worker counts, source/artifact
SHA-256 values, red/green results, browser observations and documentation checks.
Raw logs are under `C:/kybersand/validation/local/20260908-issues-1-2` plus the
wrapper-stamped directories recorded in that JSON. Build-info's historical source
label alone does not identify these exports.

## Documentation checklist and limits

| Area | Canonical synchronization / disposition |
|---|---|
| Source/recovery | Separate roots/intake, sequential local commits, source checkpoint route and evidence JSON |
| Tick/ownership | Tick entry and finalization, failed-region lifecycle, native/desktop/Web ownership unchanged |
| Storage/activity | Core-normalized requests, retained activity, one-time eligibility wake, conservative custom geometry and capacities |
| Interfaces/config | Setter admission/latching, transition capacity outcomes; no ABI signature or toolchain changes for issue #2 |
| Invariants | INT-002 and TIME-002; within-mode parity, explicit failure and conservation retained |
| ADRs | ADR-004 policy/tradeoffs, ADR-002 mode distinction, ADR-008 fidelity; ADR-010 failure choice unchanged |
| Roadmap/controls | F02 Current fix; F04/F06/F08 and future fields/resize remain open; handover, intent, Material Lab and troubleshooting |
| Build/tests | 46 native / 16 Godot inventory, shared real-adapter/browser probe and separate artifact evidence |
| Retrieval | Canonical routes and indexes, existing C02 expected facts updated with wording retained; new C03/C04 reported separately |
| History/checks | Foundation and M11 records/hashes preserved; structure, lexical retrieval/manual fact review, historical M11 and diff checks recorded |

No current Linux/macOS/WSL/sanitizer, Firefox/Safari, process-wide zero-allocation,
production frame-pacing/visual acceptance, arbitrary failure-site or all-material
sleep/cadence coverage is claimed. Native source tests, Windows Godot and actual
browser execution are separate evidence classes. Historical M11 hash mismatches
remain disclosed; no historical hashes were rewritten. Nothing was pushed,
published or closed on GitHub.

## Final reviewed artifacts and checks

After removing two introduced signedness warnings, final native tests again
passed 46/46 (26.032 seconds, 120-second timeout). Windows release rebuild
`20260908-225505` and full Godot suite `20260908-225600` passed 16/16. Final Web
rebuilds `20260908-225549` (compatibility) and `20260908-225652` (threaded) passed
18/18 manifest and 9/9 HTTP checks each. Both actual Chromium profiles passed
failure and re-entry probes, at one and six workers respectively, with no
reported console errors/warnings. Threaded one/four-worker samples matched all
120 per-tick level hashes across four demos (98,286 moves each, 480 parallel
phases with four workers). These samples both use PhasedInPlace.

Documentation structure and diff checks passed. Frozen-query lexical retrieval
retains 23/32 hit@1 and 32/32 hit@5; MRR is .8307 (issue #1: .8385). Existing C01/C02
have canonical rank one; new C03/C04 rank two/one. C04 needs the linked storage
section for full capacity/work detail despite its canonical route hit. Both
iterations and manual sufficiency limits are retained. This is no embedding or
held-out evaluation. Historical M11 still reports 12 source/artifact hash
mismatches; the exact list is in the JSON. The pre-existing unused-lambda-capture
warning remains. Historical hashes and audits were not edited.
