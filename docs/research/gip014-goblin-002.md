---
title: GIP-014 goblin 002 experimental playtester
status: Planned
document-kind: research
scope: Branch-scoped in-game gameplay discovery, persistent experimental memory and qualification; Draft/HOLD
canonical-for: [gip014-goblin-002]
last-reviewed: 2026-11-25
related-documents: [gip014-goblin-gameplay-qa.md, ../operations/local-build-and-validation.md, ../operations/github-development-and-release.md]
---

# GIP-014-goblin-002 — experimental playtester

**Draft / HOLD.** The owner authorizes an ancestry-preserving successor, substantial
implementation, isolated gameplay campaigns and a self-contained Windows developer
evaluator. There is no authority to merge, mark Ready, activate goblin by default,
import unfinished programmes or claim physical Windows/NVIDIA acceptance.

## Foundation and evidence custody

The live predecessor [PR #772](https://github.com/techrote/cybersand/pull/772) was
refreshed before selecting the foundation. It is open and Ready at
`d4484bd5b488cb419bfaa94f1e69be8128734405`. Its two parents preserve the closing
source `66ee554a9faaac6776599a676fd95acb39942450` and the CI-only repair
`585520e7e62b67ce8c4c86605b08e1f8cc920bba` from #778. This successor starts there,
on `experiment/gip014-goblin-002-20261125`, without altering #772 or its state.

The [predecessor guide](gip014-goblin-gameplay-qa.md) retains its original evidence:
Linux gameplay source `1649f086a5795d88d03d19fd161ad549365a3fc4`; qualified Windows
source `3e3aa217b49036ac4a87dd57073ad2cbb5a314c8`; qualified
[run 45474099351](https://github.com/techrote/cybersand/actions/runs/45474099351)
and [evaluator artifact 14958249728](https://github.com/techrote/cybersand/actions/runs/45474099351/artifacts/14958249728).
Neither those passes nor the prototype #749 establish a newly discovered production
bug. The retained CURIOSITY256 original ended after 220 completed actions with an
unattributed SIGKILL and a pending brush; RANDOM256 ended before a fixed tape.
A separate CURIOSITY256 repeat passed. There was no qualified matched256 comparison.

The initial source-only clone exhausted the shared workspace. An attempted move
was followed by execution-host replacement. The fresh checkout is isolated in
`/home/agent/goblin002/cybersand`; no unrelated workspace data was deleted. Prepared
specialist sources were preserved as unattached Git blobs during the outage, then
materialized after host recovery. This interruption is infrastructure evidence,
not a game defect. Runtime observations and source checkpoints below remain separate.

## Ownership and mission ledger

| Lane | Source ownership | Responsibility |
| --- | --- | --- |
| Lead | Controller, UI, findings, guide, integration | Lifecycle, bounded execution, interactive reduction and evidence adjudication |
| A | State, coverage, corpus, policies, exploration tests | Observation-driven search, finite intentions, memory and behavioural diversity |
| B | Adapter, expanded actions, assertions/oracles, fixtures, capabilities | Ordinary gameplay authority, independent contracts and defect investigation |
| C | Transcript, Python tools, package and focused workflows | Replay, queue, bounded processes, comparative campaigns and Windows custody |

At the initial implementation checkpoint, source supplies 55 distinct admitted
operation contracts, 16 policy identities and ten fixture definitions. These are
**source capability counts**, not proof that every operation has completed or that
every policy has been gameplay-qualified. Exact runtime results belong in the
qualification ledger, with every failed and incomplete attempt retained.

The lead preserves ordinary startup. Native C++ remains authoritative for cells;
the mounted ordinary Workbench owns tools, configuration, actors and UI. Goblin
proposes finite typed commands, then records actual acknowledgements and copied
observations. Its optional feature seam requires explicit versioned capability
negotiation; unfinished AMBIENT, ObjectShard, Strata, Materials Lab, Gentek and Art
candidate branches are not imported.

### 2026-11-25 intake and implementation

- Refreshed main remains `00cdb02f103265b6dc5224c68283e9a0c8cb449f`.
- Pinned Linux Godot is `4.7.stable.official.5b4e0cb0f`; the official release ZIP
  matches SHA-256 `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
- Retained native Linux SHA-256 is `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`;
  retained Rapier is `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
  Those bytes match this branch's Git LFS pointers. The launcher separately verifies
  all source-input manifests before each admitted runtime programme.
- Initial exploration checks passed on the exact pinned engine. They are synthetic
  mechanism and tamper controls, not game-engine discoveries. Expanded gameplay,
  metamorphic, controller, graphical and campaign qualification are pending at this
  checkpoint.

### Initial native and infrastructure results

`expanded-001` exercised the new operations and exposed harness assumptions about
articulated collision proxies, empty actor sessions, the RFT budget precondition
and additive camera observation fields. After checking the ordinary Workbench and
native contracts, corrections stayed within goblin. `expanded-002` completed all
29 additional operation IDs in 20.488 seconds, peak observed process-tree RSS
583,782,400 bytes, with no diagnostics or surviving owned processes. Its source
was local checkpoint `06893e99` plus a recorded dirty source snapshot; this is
development evidence, not qualification of the later published source. The raw local
artifact bytes were subsequently lost with the execution host. The recorded checks
are not a substitute for fresh hosted evidence.

`metamorphic-001` was externally killed during import (exit -9 at 4.137 seconds,
peak sampled RSS 665,964,544 bytes). `laboratory-001` was externally killed without
import, before the first test output (exit -9 at 0.507 seconds, peak sampled RSS
150,646,784 bytes). Neither reached its gameplay assertions. The configured child
RSS ceiling did not attribute these kills, and no surviving owned process remained.
The cause is unresolved infrastructure; further equivalent local retries were
stopped in favor of dedicated hosted qualification. Their process results and identities remain recorded; the second host loss described below removed the local raw files.

The first published successor source is `c947143a7cb62bc8b56acd0b78b683a9fef749e0`,
tree `4c234199b1db9934aa5ba40e84b96fbb57c2c844`, in
[Draft PR #781](https://github.com/techrote/cybersand/pull/781). GitHub blob/tree
publication reproduced the exact local committed tree after CLI authentication
was unavailable. Local and remote commit IDs differ; their trees were explicitly
compared before switching the local parent while preserving uncommitted work.


### First hosted qualification and independent challenge

[Run 45527805069](https://github.com/techrote/cybersand/actions/runs/45527805069)
executed exact clean source `be64fa7896a37672c3e5d0652517789e469b9061`,
tree `c0d2875b01c41f7287fa9191922e2b3bf88b222b`. Both platforms failed the
existing fixture-edit budget control: the new Alchemy recipe contained 22 initial
edits, above the established 20-edit contract. The recipe was simplified to 18
ordinary rectangles; the gate was preserved. This was a goblin fixture defect.

The Linux run retained passing focused discovery, original adapter, expanded
adapter, controller, laboratory, gameplay, metamorphic, ordinary deferred-paint
and ordinary input checks. Graphical and full campaign execution did not start
after the failed unit gate. Windows stopped at that gate and did not qualify a
package. These partial passes do not qualify either platform as a whole.

- [Linux evidence artifact 14983617239](https://github.com/techrote/cybersand/actions/runs/45527805069/artifacts/14983617239):
  25,349,638 bytes; ZIP SHA-256
  `99b6a53dd8dd20ac5efa290e459d91a22c8f77c319ca31d9c42d6d4a1721893e`.
- [Windows evidence artifact 14983177716](https://github.com/techrote/cybersand/actions/runs/45527805069/artifacts/14983177716):
  6,029,271 bytes; ZIP SHA-256
  `19092618b62cbe440fc85cdcd7b64a61cce0f6585f9807ec34e8ed27b97dfe9f`.

Independent examination of the first native laboratory tape found two campaigns,
six completed admitted actions and zero simulation ticks. The retained-prefix
selection reused one Pause action, followed by new history actions. This proves
a native corpus round trip and selected-prefix dispatch, not an edited construction
replay, behavioral improvement or successful native reduction. The next laboratory
gate therefore cultivates a real four-action construction prefix, demands positive
native material readback on reuse, and separately reduces an actual legal semantic
outcome through fresh repeated probes.

### Recovery and stricter regression capture

The integrated local checkpoint `eaf193eaca9330a4e49ed9a5430047e0c5f82f57`,
tree `a33744521d8b4b14183f4757b58163cf5f52a59c`, passed 60 Python controls
before a second execution-host replacement. No gameplay process was running.
That local commit was not published. Exact Git blobs recovered most specialist
sources; several lead files and one gameplay action file were reconstructed from
the retained design and patches. The next published candidate is explicitly a
new source tree, and receives fresh qualification. The lost tree's local test
result does not qualify the reconstructed tree.

Automatic failing-invariant capture writes a fixed `candidate-NNN.json` beside
the raw tape. Original action arguments, semantic admission, disposition, assertion
identity and expected value are bound into reduction acceptance. Interrupted,
timed-out or unrelated failing probes cannot substitute for the target. A passing
regression must complete the originally accepted operation; changing an accepted
partial effect into a refusal cannot make the regression pass.

A subsequent independent artificial counterexample found that an earlier duplicate
successful action could still mask refusal at the actual failing occurrence. The
reader now derives the target occurrence from the chosen retained tape and checks
that aligned step in fresh observed evidence. The same before-fix counterexample
is rejected after correction. This is a confirmed regression-reader defect, not a
production gameplay defect; exact challenge and reader identities are retained in
the gameplay handover.

The data-only `regression_bundle.py` exporter supplies original and reduced tapes,
authored fixture, material evidence, exact source/runtime provenance, a hashed
fixed-member manifest, a reproduction plan and a constant ordinary unittest.
The test reads a separately produced `observed-transcript.json`; it never executes
commands supplied by a tape. Corrective-source provenance must be explicit.
Export itself makes no claim that a fresh reproduction has occurred.

An ordinary finite-canvas body stop is legal product behavior. Classification now
requires the exact authoritative refusal reason in a healthy paused immutable
Workbench publication, matching World generation and tick, plus matching action
interval evidence. Arbitrary partial effects remain unresolved. The new native
metamorphic gate must actually encounter this stop and recover through ordinary
actor reset; inability to reach it is unqualified coverage, not a production bug.


### Second hosted qualification and native regression evidence

[Run 45536048675](https://github.com/techrote/cybersand/actions/runs/45536048675)
tested clean source `89c91ba5342d485e787d39e64103fc6c91c5f92b`,
tree `18facfba0ce5a93afd00200a7f6a971458f40aa8`. Both platforms passed
63 Python/tooling controls, 333 original policy controls and 82 pure gameplay
oracle controls. A new synthetic 1024-action tape omitted all per-row assertions,
so the strict transcript validator correctly rejected it. The test fixture was
repaired to use the existing independent assertion evaluator, and an explicit
missing-assertion negative control was added. The validator was not weakened.
The repaired pure contract gate passed 194 checks.

Linux also passed discovery, original and expanded adapters, controller,
laboratory, gameplay, metamorphic and ordinary Workbench baseline groups.
The failed unit gate prevented graphical, comparative campaign and package
qualification. Windows stopped at the unit gate.

- [Linux artifact 14987252426](https://github.com/techrote/cybersand/actions/runs/45536048675/artifacts/14987252426):
  25,666,356 bytes; SHA-256
  `1b0a78406835332dc4a350273c5b2ad1543fc77a6404c6490422d0fb630a640f`.
- [Windows artifact 14987073203](https://github.com/techrote/cybersand/actions/runs/45536048675/artifacts/14987073203):
  6,049,477 bytes; SHA-256
  `08fb0ddfe01fddb20cbb702b8756d7dc8f184de270839f2881a1ec453d442061`.

The actual Linux laboratory passed 70 checks, including 29 separately labelled
synthetic controls. Its cultivated prefix was Pause, Camera, material 58 selection
and Rectangle (32,32)-(39,39). Both original cultivation and reuse completed the
same four admitted inputs. Independent before/after material arrays and native
receipts both show 64 changed cells. Memory import did not inherit completed
coverage; the reused episode earned new observations.

The laboratory also reduced four actual Pause operations to one, retaining six
fresh-World probes with action counts 4, 4, 2, 2, 1, 1. Both baseline and every shorter
accepted case were observed twice. This is legal semantic-outcome reduction,
not a discovered bug or a full physical checkpoint. The retained native bundle
was exported separately through the fixed Python tool; its occurrence-bound
reader and constant unittest passed on the actual reduced tape. The Python
export step did not run new gameplay.

### Native finite-edge follow-up repair

Independent source review identified a recovery gap after a legal finite-canvas
actor stop. A new bounded native diagnostic reproduced it: ordinary Kestrel up
input reached the edge; the next Brush was refused before gameplay admission,
with unchanged healthy paused generation/revision/tick and the exact worker
reason, but goblin classified it as `adapter_failure`. Ordinary Reset and
Play recovered the game. This was a goblin classification defect.

The narrowly scoped repair requires the exact current immutable-publication proof,
a matching refused capture admission, unchanged healthy paused source and no
successful native receipt or materials. Unrelated capture refusals remain
unresolved. No production engine code changed. The same diagnostic failed one
of 194 checks before the repair and passed 195 after it; both had 11 actual rows,
four up pulses, ordinary recovery, bounded wall/RSS monitoring and no surviving
owned process. The runs took 11.594 s and 10.658 s, with peak sampled tree RSS
585,859,072 and 585,789,440 bytes. Their exact source overlays, raw observations and
hashes are retained in the gameplay handover.

The added hostile pure oracle controls passed 110/110. The next hosted candidate
must requalify this repair, the transcript fixture correction, graphical controls,
full comparative queue and extracted Windows package together.

## Experimental contract

`godot/goblin/goblin_state.gd` abstracts admitted observations. Monotonically growing
clocks and instance identities do not create artificial novelty. Unknown or stale
material samples remain unknown. Coverage separates action vocabulary, adjacent
admitted actions, state transitions, sampled material interactions, tool/material
pairs, observed actor/environment combinations, lifecycle, boundaries/refusals and
outcomes. Nominal menu entries and proposed commands receive no completed coverage.

The original six policy generators are retained. Ten additional personalities use
shared finite weighted choices and construction/history/actor intentions. Random,
stateful, novelty and coverage cohorts use matched fixture/seed/action budgets.
Imported history can inform search only in a separately labelled reuse cohort.
The original six personalities preserve their baseline behavior; the UI enables
explicit prefix reuse only for successor personalities.

The corpus holds at most 64 bounded records and 2 MiB. Reusable prefixes are limited
to 128 actions from an exact matching authored fixture and source/runtime identity.
Longer discoveries retain observation identities without pretending to contain a
full setup or physics checkpoint. Imported confirmed labels are downgraded; imported
coverage remains a heuristic prior, never this campaign's measured coverage.

Candidate anomalies are triaged into unresolved observation, legal unusual gameplay,
unsupported action, expected refusal, harness defect, oracle defect, infrastructure
failure, deliberate negative control or independently confirmed production defect.
The live UI cannot promote an observation to a confirmed defect. Reproduction and
reduction provide evidence; independent examination establishes the classification.

## Laboratory controls

Open the supplied developer evaluator with **Open goblin.cmd** when qualified.
For source use, run the committed isolated launcher:

```text
python tools/gip014/run_goblin.py --godot /path/to/pinned-godot --case interactive --out /path/to/new-test-run --fixture construction --policy COVERAGE_HUNTER --seed 605 --budget 128 --pacing-ms 150
```

The ordinary game remains usable without goblin. The dedicated scene requires a
marked disposable profile before mounting a Workbench. The panel has Play,
Discovery, Memory and Guide tabs, a visible animated pointer and optional observed
trajectory/edit overlays. Start installs a fresh fixture; Pause holds decisions;
Step admits one decision; Stop drains input and pauses the game. Native simulation
and actor clocks are displayed separately from action count and elapsed real time.

Budgets are 1..1024 actions. Active campaign bounds grow from 150 seconds to at most
900 seconds; absolute session bounds include pacing and manual decision pauses and
never exceed 5400 seconds. Each action still has its own existing bounded native
receipt/operation completion contract. The launcher supplies a separate owned-process
wall/memory bound. A profile admits at most 64 campaigns and 512 MiB of retained
run archives. Tapes are capped at 32 MiB; failures to retain evidence fail closed.

Memory import reads only the launcher's staged `goblin-corpus.json`. Memory export
and clear use fixed files below the marked test profile. Clearing experimental
memory preserves existing campaign evidence. No gameplay action accepts an arbitrary
file path, network destination, shell command or external desktop operation.

## Replay, reduction and regression export

Semantic replay compares documented game outcomes. Exact asynchronous observation
replay has a distinct result and is not inferred from semantic equality. Authored
Save/Reopen and experiment-queue resume do not resume evolved physical state.

Interactive reduction admits up to 128 actions, at most twelve fresh-world probes,
30 seconds active time and 60 seconds absolute time per probe. The original target
must reproduce twice before deletion search begins. Every accepted shorter candidate
must reproduce twice; failed attempts remain separate run archives. Original pacing
is retained, so a case whose timing cannot fit the bound remains unqualified.

A target is either the same independently evaluated failing invariant or a precise
completed semantic outcome. Reducing a legal successful outcome is not a discovered
bug. The exported bounded bundle includes original and reduced tapes, the actual
initial authored fixture, exact provenance, required action IDs, acceptance rule,
observed failures and fixed-entrypoint reproduction instructions. Longer sequences
use the separately bounded Python reducer.

## Qualification and decision status

**Pending for the next candidate:** comparative campaigns, long-horizon completion,
graphical laboratory and extracted package qualification, plus fresh source-matched
focused gates for the repairs above. Prior focused native passes remain attached
to their exact published source. No successor Windows evaluator is yet qualified.
The predecessor evaluator remains independently valid at its original source.

Qualification will retain every process, exit code, watchdog/cancellation result,
source snapshot, native/runtime identity and raw terminal or incomplete tape. No
novel production gameplay defect has yet been established by this successor.

## Documentation impact

This is a branch-scoped developer-only candidate. Production subsystem contracts,
startup defaults, material laws, native interfaces, owner profiles and accepted
runtime provenance are unchanged. The focused research guide and specialist
handovers own the candidate facts; the documentation index routes to them and the
retrieval manifest excludes them from ordinary accepted-product answers. Historical
records and the predecessor guide remain unchanged.
