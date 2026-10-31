---
title: PLAY-PACE-004 individual input custody and measured gameplay
status: Planned
document-kind: evidence
scope: New source candidate for exact 40-event actual-host input accounting and bounded Windows/Linux measurements; qualification results remain source-specific
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../operations/profiling-observability-and-performance.md, ../operations/local-build-and-validation.md, 2026-10-31-play-life009-automatic-pause.md]
---

# PLAY-PACE-004 individual input custody and gameplay measurement

## Status and ownership

This is a **new, unqualified source candidate** from accepted main
`0bf28d5760aed989a79386de03ef4fc6171fef42`, consuming the separate LIFE009
candidate and INPUT010 immediate pause/input-generation correction. It does not
modify or merge held #308/#310 or frozen #312/#316. Windows shader compilation,
cache investigation, decomposition and optimization remain owner-deferred.
Scheduswarm stays paused. No programme, release or physical-device gate closes.

The change owns only the new PACE004 fixture, copied-value worker observer,
Python runner/reducer/adverse controls, one dedicated GitHub-hosted workflow and
this audit. The INPUT010 production correction remains a separate dependency.
The source does not introduce another simulation owner, change native code,
runtime bytes, material shaders, solver defaults, protected fixtures or existing
validation limits. Existing LIFE001's 50 real lifetimes per OS and LIFE002–005,
UI005 and accepted real-native-busy #302 evidence retain their original scopes.
Held LIFE006–008 work is not copied into this package.

## Gap addressed

PACE003's retained `input_tape` is an inventory of grouped intentions: a direction
entry dispatches two key events and a primary-tap entry dispatches two more.
Its wall-bounded loop can end before a final intended action is physically
consumed. Advancing native/Rapier counters and increasing admission sequences
alone cannot establish that every intended nonneutral action was applied.

The new [actual Main fixture](../../godot/tests/play_pace004_input_tape.gd)
registers **40 individual `InputEventKey` events**, identified 1 through 40.
The [independent reducer](../../tools/play/pace004_contract.py) owns an explicit
matching inventory. No event counter or fixture-supplied outcome substitutes for
the original chronological observations.

## Input and lifecycle contract

The real integrated **Play session** selector constructs the authored course,
selected SetP actor and construction-time policy. The original `main.tscn`,
exclusive asynchronous worker, native phased World and main-thread Rapier run
their normal automatic callbacks. The positive OS seam is the focus predicate;
physical keyboard/controller/OS-focus qualification is not claimed.

Every input records its actual production handler count, copied admission
before/after, command sequence and control generation. The reducer checks the
accepted command's intended component and reconstructs a queue whose elements
retain their originating input-event ID. A button edge can complete only when
the real FIFO removes it in order, that callback advances both actual session
tick and Rapier bridge step exactly once, and the copied applied action contains
the expected button value. Increasing counters with neutral actions fails.

Analogue movement and trim retain their **latest-state semantics**. This tape
holds every admitted analogue change through a completed physical step and
fails if another analogue state supersedes it first. It does not invent a
movement-edge queue or claim that a momentary analogue state must be preserved
like a discrete button press.

The expected terminal inventory is **29 applied, 6 cancelled, 5 refused**:

- IDs 1–16 exercise forward/reverse, both trim directions and quick primary,
  secondary and auxiliary press/release pairs during the measured gameplay.
- IDs 17–22 exercise pending button cancellation during P→P in one Main turn,
  held-input refusal, neutral release and fresh rearming. This requires INPUT010;
  the pre-correction source retains stale edges at that boundary.
- IDs 23–28 exercise automatic focus cancellation and neutral rearming through
  the explicit synthetic focus predicate.
- IDs 29–40 exercise pending-edge retirement across ordinary R reconstruction,
  refusal while paused and fresh commands on the replacement owner.

Separately recorded transitions include actual native pause acknowledgement,
at least 350 ms of quiescence, resume, immediate pause/resume, focus loss/regain
and reset. Source IDs, old/new generations, actor retirement and completed
physical steps remain visible. No manual physics calls, pose injection, invented
publication or automatic retry is used.

## Measurements and costs

The first 16 events span a **15-second measured gameplay window** with actual
movement and trim held for substantial intervals. After this window, the same
owner performs the cancellation/reset cases. The recorder is fixture-only;
production frame paths acquire no general-purpose profiling overhead.

The [worker observer](../../godot/tests/play_pace004_worker_probe.gd) subclasses
the existing production worker once, before that owner starts. It observes each
distinct native completion on the exclusive owner and calls the accepted copied
statistics adapter there. Main never reads a live World or the owner-written
rows. The **actual stop/join** transfers those rows for terminal reduction.

The raw records separate:

- native completed ticks/s and complete native-duration distributions;
- configured native capacity from actual task-claiming worker participation,
  per-phase job counts, parallel phases, visited/moved cells and overruns;
- Main callback duration and cadence, completed Rapier steps and bridge step
  duration;
- every Main-visible immutable publication, coalesced serials, no-new-publication
  returns, retained age and render-versus-authoritative revision lag;
- the existing WAIT001 snapshot mutex acquire/critical-section observer;
- per-event admission-to-completed-physics latency;
- Main construction acknowledgement, pause/resume/reset and actual joined
  shutdown latency;
- actual `frame_post_draw` submission cadence when a graphical display exists.

Owner-written packet receipts include pre-window and paused publications. Main's
observed serial, tick, epoch, World generation, timestamps and revisions must
match the exact packet. Native completion rows must also cover every measured
completion identified by those packets; dropping a prefix, suffix or outlier is
rejected. The measured Rapier inventory is derived from callback timestamps and
complete owner identity, then checked against the initial/final tick and step
deltas. A self-reported sampling flag cannot omit or relabel physical work.

Native timing excludes the copied statistics query; wall pacing includes its
bounded observation cost, which is retained separately. Participation is the
maximum number of distinct task-claiming pool workers in a dispatch; it is not
simultaneous utilization or causal speedup. Snapshot-acquisition wait does not
attribute other Main locks. Render submissions are **not displayed FPS**.
No new performance threshold is substituted for fixture integrity.

## Graphical controls

Linux graphics uses the same fixture, source and ordinary compatibility renderer.
After measured gameplay, a real reset returns the actor to its authored spawn;
the fixture does not inject a pose. Once paused, a bounded diagnostic sequence
retains actual baseline, unchanged, actor-hidden, terrain-hidden and restored
PNG frames, each tied to a fresh real draw submission.

The offline reducer checks every PNG digest and chunk CRC, decodes its actual
pixels, binds actor regions to the real Rapier-derived overlay polygons and
compares actor/terrain removal against unchanged-frame noise. A nonblank UI
alone does not pass. These layer controls occur after measurement and never
become normal gameplay state. Source/runtime identity and original process
receipts accompany every image.

This qualifies the observed software-rendered actor/terrain output only when
the complete graphical case and independent pixel checks actually pass. It
cannot qualify physical scanout, physical input or human feel. Windows graphical
shader startup remains the separately preserved failure/deferral; it is not
repeated or relabelled by this workflow.

## Frozen bounds and execution inventory

The [campaign runner](../../tools/play/run_pace004_campaign.py) uses one fresh
engine process per case, a **240-second import** and **180-second case** limit.
The fixture retains **150 seconds overall**, **15 seconds per ordinary
operation** and **30 seconds for Main construction acknowledgement**. Main
records acknowledgement inside its callback; the separate later coroutine poll
does not move the acknowledgement deadline. Every wait, timeout, incomplete
inventory and failure remains evidence, never a pass.

Windows and Linux each execute 14 headless cases: all five mechanical rigs with
one worker and Auto under Current policy, plus Acrobat/Jetbarrel one/Auto pairs
under the admitted pressure preset. Linux also executes six graphical cases:
Acrobat/Jetbarrel one/Auto under Current and Jetbarrel one/Auto under pressure.
The first failed graphical case stops that graphical cohort while retaining its
original evidence; its incomplete inventory fails. Independent headless cohorts
still execute and are separately classified.

The [dedicated workflow](../../.github/workflows/play-pace004.yml) uses literal
GitHub-hosted Ubuntu/Windows labels, no retries or alternate runner provider.
It preserves original successful/failed process logs, timeout diagnostics,
fixture output, captured PNGs, source archive, execution-input/runtime digests,
run/attempt identity and a sealed artifact manifest. The engine output carries
an expected process nonce, actual PID and fixture/probe hashes. Offline readback
checks original logs, exact process/configuration inventories, committed source
archive and selected LFS identity before accepting the reduced records.
Original commit-object bytes and the recursive Git tree inventory permit offline
reconstruction of the commit/tree/blob identities, including file modes. The
execution inventory must include every tracked file in the declared scopes;
runtime records must match each selected archived LFS pointer's SHA-256 and
size, plus its native/Rapier source manifest. Engine version, full build hash,
executable digest, actual OS and renderer are cross-checked. Requested policy
assignments are independently encoded into their canonical native policy hash,
and construction receipts must match the owner generation and worker capacity.

```text
python tools/play/test_pace004_contract.py
python -O tools/play/test_pace004_contract.py
python tools/play/run_pace004_campaign.py --godot-archive <pinned-archive> --expected-source-sha <exact-head> --output <fresh-directory>
xvfb-run -a python tools/play/run_pace004_campaign.py --graphical --godot-archive <pinned-Linux-archive> --expected-source-sha <exact-head> --output <fresh-graphical-directory>
python tools/play/run_pace004_campaign.py --output <original-campaign-directory> --verify-only
```

## Development observations, not accepted qualification

The first source-development Linux invocation used the correct pinned Godot
binary and authentic native/Rapier payloads. It executed all 40 events, 102
assertions/zero failures and 1,051 trace rows in 18.22 seconds. The strict reducer
reconstructed the expected 29/6/5 outcome inventory. This invocation used an
uncommitted fixture overlay and an abbreviated development source marker; it is
**not credited as an exact-commit campaign or integration result**. The complete
committed-source campaign must run afresh.

Original development negatives are retained in the local development evidence:
the sandboxed editor import emitted socket-creation errors despite process exit
zero, so it was not accepted; the authorized unrestricted import completed
cleanly. The first reducer implementation incorrectly treated a saved
pre-transition observation as a newly delivered post-callback state; its
original valid-engine trace exposed that ordering error. The correction keeps
saved pre-operation states distinct from current publications. An early PNG
negative-control mutation hit chunk length instead of CRC; the corrected test
mutates the actual CRC byte and requires that precise rejection reason.

Sixty-one focused adversarial test methods pass normally and under optimized
Python in development. They reject absent/misidentified input, neutral-only
application, fake physical progress, wrong-generation input, dropped or reordered
edges, undeclared supersession, incomplete tapes, rapid-pause stale edges,
paused drift, retained reset owners, rounded signed IDs, duplicate handlers,
false graphical scope, altered PNGs, missing actor/terrain output and reused draw
submissions. These synthetic reducer controls validate the apparatus; they do
not replace actual Windows/Linux engine execution.

Final exact-head standard gates, original hosted evidence, independent review,
guarded merge and post-merge verification remain required. No physical-device,
real OS focus, display scanout or human-playability result is asserted.

## First committed Linux attempts: failures retained

The first local committed campaigns executed source
`1d9f11165efd7cf2a73b210c160452e3b6994cfd`, tree
`e67a9fa68d5527f260c88895f2385ac866b7e8b3`. Their original source archive SHA-256 is
`4087e4488ef68aee62b31d7094d3ed4711a837089e248d5c3a25dcdb18e48658`.

The headless cohort completed all 14 original engine cases, each 102 assertions
and zero engine failures, for 1,428 assertions. **The campaign failed.** Five
cases exposed a recorder boundary defect: a packet completed immediately before
the measured window could be consumed after it began, but the recorder had
discarded the producer's earlier receipt. Four other cases exposed an early
fixture transition: two Rapier steps had completed while native resume was still
pending. The independent reducer correctly refused those records. Their original
results remain unchanged; adding the missing publication custody and waiting
for both actual owners requires a new committed-source campaign.

The graphical cohort's first Acrobat/one-worker/Current process failed the
original 30-second Main acknowledgement requirement. Its original output has
nine assertions, two failures, no acknowledged timestamp, and a later coroutine
observation at 57.17 seconds. The process used Linux X11 compatibility rendering
with Mesa llvmpipe. No later graphical case ran, and **no graphical qualification
was obtained**. No warmed retry, shader change, cache experiment or deadline
change follows this local failure. A fresh hosted graphical job retains the same
mandatory bounds and remains a separate gate.

Both original campaigns report unchanged execution source and runtime bytes.
Their immutable local directories are `build/pace004-local/exact-headless-1` and
`build/pace004-local/exact-graphical-1`; the respective original manifest SHA-256
identities are
`256d6a7c11f3b572aa229e4b7b2277945974eb7ced760bb788377e46ce11fb23` and
`738f05805a3ceee6c76cfa3220500e7edd3824104943fd5e8cde1a68d591150a`.

Independent review also supplied counterexamples involving unowned nonneutral
actions, partial owner substitution, relabelled policy/OS/renderer, incomplete
sampling flags and incomplete source/runtime inventories. The corrected
reducer rejects each with a focused adverse control. Those controls establish
verifier behaviour; they do not change the classification of either original
campaign.

The second original headless campaign, source
`50af39968b0d16c21a52a636d403028ed4706546`, completed all 14 engine cases and
all 14 input/publication/policy reductions, again with 1,428 assertions and zero
engine failures. **Its final campaign readback failed** on a source-export
verification defect. Git's archive applies the committed `*.bat text eol=crlf`
and `*.ps1 text eol=crlf` rules, while Git blob identities contain canonical LF.
Exactly `build_windows_msvc.bat` and `tools/launch_desktop.ps1` were affected;
every other archived blob matched directly. The corrected verifier first
authenticates the root attributes blob and inverts only those explicit rules.
It rejects normalization elsewhere, and a control executes a real temporary
Git archive to reproduce the conversion. The original second report remains
failed and immutable; a new exact-source campaign is required.

Review additionally required a pre-window render-rejection counter baseline
and monotonic observations, so the first callback's rejection cannot disappear
or a regressed counter produce a negative count. That measurement correction
does not alter simulation, rendering, input or acceptance deadlines.

The third original headless campaign, source
`7cb6d1add46e4b373a3179f36ca2a06e0b80397b`, again completed 14 strict case
reductions and 1,428 engine assertions with zero engine failures. **The campaign
failed its final source-artifact integrity check.** Its recorded archive digest
was `0b9f9e442b278382b5b6fc509c409258114dd0750fb84700d1ab40f51197a99b`,
but the retained 90,316,800-byte file hashes to
`e382b00543a30e86a06c8162017c89ca758e3902aff01cd9735fcc88dbc86f3b` and
ends inside a PNG member. Independent and same-host readbacks reproduced the
truncation. Source/runtime postflight hashes remained unchanged, disk space was
available, and no writer was identified; the cause is **unproven artifact
truncation**, not an established gameplay defect. The original artifact and
failed report remain untouched under `build/pace004-local/exact-headless-3`,
with manifest SHA-256
`a348bf7f0861982527e8eb6642b6c2a04ce0374a982c2159050eab5659968043`.

The publisher now writes a unique temporary archive, requires successful Git
export, flushes and fsyncs it, and atomically publishes the retained filename.
Complete commit/tree/blob/runtime verification runs before any import or engine
case, and final independent readback remains mandatory. It refuses to replace
an original archive and introduces no retry. This hardening cannot retroactively
qualify the damaged third cohort. Fresh hosted Windows/Linux cohorts at the
published head remain decisive. Windows checkout and archive export both pin
implicit text EOL to LF while retaining the two explicit committed CRLF rules.
