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

## First hosted original result: 2026-10-31, d464edc0

The first [PR #320](https://github.com/techrote/cybersand/pull/320) scoped run,
[41175719451, attempt 1](https://github.com/techrote/cybersand/actions/runs/41175719451),
executed source `d464edc0a81b9e0ce343f878179d95c8c831245f`, tree
`ee34f3800abde0f029926050873d7b3ca4776407`, on fresh GitHub-hosted runners.
**Both original headless cohorts passed. The mandatory original Linux graphical
cohort failed.** This is scoped evidence at that exact source, not full PR
qualification, a merged result, or evidence for a later source head.

All three original ZIPs were downloaded and checked against the Actions API's
byte count and SHA-256, then CRC checked. Their catalog identities are:

| Dimension | Job | Artifact | ZIP bytes | ZIP SHA-256 |
| --- | --- | --- | ---: | --- |
| Linux headless | 124462746447 | 13033062790 | 84,510,312 | `cd0b334f0afa1080aedf80ad4a0e7214ebf6e3a305ae9d4508a62a5606b3bd33` |
| Windows headless | 124462746610 | 13032838223 | 84,385,168 | `a88e55db82ffdb09cef792c75e70ebaf92543f73eec200c7dedfdf817ae38721` |
| Linux graphical | 124462746562 | 13033451326 | 76,804,327 | `81ecd64f15a12da445bdc64830f54e62b31e363d6d1d9e04d97f2ec721532fe5` |

The complete retained source archive is 106,977,280 bytes, SHA-256
`79c320613fa62f5e664d7b25c51347888b1d78b83ebb3610fde92cc971b83b8b`,
in each cohort. Independent readback authenticated the commit and reconstructed
Git tree, all archived blobs/modes, all **905 scoped execution inputs**, the two
selected LFS payload/provenance chains per OS, and the original process nonce,
engine executable, fixture/probe hashes and platform/renderer identity. Original
source/runtime postflight checks passed. The campaign manifest SHA-256 values are:

| Dimension | Original manifest SHA-256 |
| --- | --- |
| Linux headless | `90636e96b5ac4082b87cfb63d9b52dc445b8084e2657c3448f59cd1724cf927e` |
| Windows headless | `bca6ad7b520a5ab58a031189b4ae6270b815bf9660a47193a8bb0d0a996c2df1` |
| Linux graphical | `abb5cffdedb61941b12201b853ddaf013a4ab6eab603ce289d85faea1754d9b2` |

The engine is `4.7.stable.official.5b4e0cb0f`, full build hash
`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`. Its original executable SHA-256
is `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`
on Linux and
`b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`
on Windows; the separate Windows console launcher is identified in the raw
campaign. The source-matched native/Rapier payloads are:

| OS | Native SHA-256 | Rapier SHA-256 |
| --- | --- | --- |
| Linux | `496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6` | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Windows | `e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb` | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |

### Input and physical-step accounting

Each OS completed the full 14-case inventory: five rigs under Current with one
and Auto workers, plus Acrobat and Jetbarrel under the explicitly requested
pressure preset with one and Auto workers. Every case executed 102 engine
assertions with zero failures and all 40 individual input events. Every admitted
nonneutral press has its original control generation and a later completed
Rapier step with the copied applied action. The reducer did not infer success
from counters or elapsed time.

| OS | Cases | Assertions / failures | Individual events | Applied / cancelled / refused | Applied nonneutral presses | Native completed ticks | Rapier completed steps |
| --- | ---: | --- | ---: | --- | ---: | ---: | ---: |
| Linux | 14 | 1,428 / 0 | 560 | 406 / 84 / 70 | 196 | 12,600 | 12,601 |
| Windows | 14 | 1,428 / 0 | 560 | 406 / 84 / 70 | 196 | 11,697 | 12,601 |

Each case contributes 29 applied events, six explicit cancellations and five
refusals. Its 14 applied presses are reported separately from the 15 applied
releases. The following pooled latency distributions use the original admission
timestamp through the observation of the corresponding completed physical step.
They are synthetic-input processing evidence, not physical keyboard/gamepad,
OS focus, display or human-feel qualification. Percentiles use nearest rank.

| OS | Applied press/release samples | All-applied p95 / max (ms) | Nonneutral press samples | Nonneutral press p95 / max (ms) |
| --- | ---: | --- | ---: | --- |
| Linux | 406 | 33.211 / 33.598 | 196 | 20.120 / 20.681 |
| Windows | 406 | 32.282 / 33.277 | 196 | 19.823 / 20.378 |

All 61 apparatus controls passed normally and under optimized Python in each
hosted job. Separate post-download mutation controls against each OS's first
actual result rejected neutralized admitted movement, a substituted Rapier
bridge, a dropped first native completion, an inverted sampling flag, an altered
engine build, Current relabelled as pressure, and an event count retained without
its handler. Each rejection matched its intended reason. These mutations were
made only in memory; original logs, reports and ZIPs were not changed.

### Paired pacing and workload observations

Each paired entry below is **one worker / Auto**, in that order. The observed
construction capacities were one and four, respectively. `Participants` is the
maximum distinct task-claiming workers in a native phase dispatch, including the
owner for a nonempty inline phase; it is neither utilization nor simultaneous
execution. Rapier and native rates count actual completed work. No headless
callback cadence or render submission is labelled displayed FPS.

The Linux headless runner reported an AMD EPYC 9V74 and four logical processors;
the Windows runner reported an Intel Xeon Platinum 8370C and four logical
processors. These different machines/builds do not provide an isolated OS speed
comparison. Samples are approximately 15 seconds each; raw counts and precise
window endpoints remain in every original result.

#### Linux: one worker / Auto

| Rig / policy | Native Hz | Native p50 ms | Native p95 ms | Max participants | Rapier Hz | Main callback max ms | Nonneutral press p95 ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| stuntbuggy / Current | 59.997 / 59.997 | 0.049 / 0.049 | 0.087 / 0.086 | 1 / 4 | 59.997 / 59.997 | 3.077 / 3.010 | 19.966 / 20.021 |
| trialsbike / Current | 59.997 / 59.998 | 0.050 / 0.049 | 0.123 / 0.110 | 1 / 3 | 59.997 / 59.998 | 4.450 / 3.169 | 20.224 / 20.102 |
| acrobat / Current | 59.976 / 60.037 | 0.042 / 0.046 | 0.062 / 0.070 | 1 / 4 | 59.976 / 59.970 | 3.330 / 3.222 | 20.076 / 20.044 |
| arcadelander / Current | 59.998 / 59.998 | 0.044 / 0.049 | 0.066 / 0.091 | 1 / 4 | 59.998 / 59.998 | 2.578 / 3.165 | 20.153 / 20.155 |
| jetbarrel / Current | 59.970 / 60.042 | 0.040 / 0.040 | 0.066 / 0.062 | 1 / 3 | 60.037 / 59.975 | 3.208 / 3.106 | 20.254 / 20.118 |
| acrobat / pressure | 59.997 / 59.846 | 13.657 / 13.695 | 15.415 / 16.512 | 1 / 4 | 59.997 / 59.979 | 3.773 / 5.079 | 20.125 / 20.681 |
| jetbarrel / pressure | 59.997 / 59.997 | 13.644 / 13.648 | 16.099 / 14.145 | 1 / 4 | 59.997 / 59.997 | 5.723 / 4.764 | 20.127 / 19.836 |

#### Windows: one worker / Auto

| Rig / policy | Native Hz | Native p50 ms | Native p95 ms | Max participants | Rapier Hz | Main callback max ms | Nonneutral press p95 ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| stuntbuggy / Current | 59.985 / 60.032 | 0.042 / 0.043 | 0.098 / 0.083 | 1 / 3 | 59.985 / 59.965 | 6.128 / 5.167 | 15.320 / 20.073 |
| trialsbike / Current | 59.973 / 59.999 | 0.043 / 0.042 | 0.089 / 0.090 | 1 / 4 | 59.973 / 59.999 | 5.157 / 4.753 | 19.418 / 19.410 |
| acrobat / Current | 59.999 / 59.999 | 0.030 / 0.030 | 0.048 / 0.046 | 1 / 4 | 59.999 / 59.999 | 4.262 / 4.321 | 19.317 / 19.548 |
| arcadelander / Current | 59.999 / 60.034 | 0.042 / 0.045 | 0.068 / 0.081 | 1 / 3 | 59.999 / 59.967 | 3.821 / 5.276 | 19.649 / 20.378 |
| jetbarrel / Current | 59.998 / 60.046 | 0.035 / 0.029 | 0.053 / 0.048 | 1 / 4 | 59.998 / 59.980 | 4.063 / 4.056 | 20.165 / 19.911 |
| acrobat / pressure | 45.311 / 45.132 | 19.721 / 19.869 | 24.112 / 24.631 | 1 / 4 | 60.038 / 59.998 | 6.337 / 6.168 | 20.189 / 19.396 |
| jetbarrel / pressure | 44.052 / 45.044 | 20.366 / 19.712 | 24.590 / 24.798 | 1 / 4 | 59.979 / 59.970 | 5.710 / 6.588 | 18.912 / 19.802 |

A per-case nonneutral p95 uses 14 presses, so nearest-rank p95 equals that case's
maximum; the 196-press pooled p95 above has a larger sample. The worst observed
native tick was 24.624 ms on Linux and 34.730 ms on Windows. The pressure cases
show sustained native cost in their medians, not merely a few long ticks. On the
Windows cohort that cost reduced completed native cadence to 44.052–45.311 Hz,
while actual Rapier completion remained approximately 60 Hz. No solver default,
physics meaning, pacing threshold or worker setting was changed to conceal it.

The Current course was mostly settled during its sampled interval. Across all
cases the reported generic visited-cell and moved-cell p95 values were zero.
Pressure-family traversal work is not separately counted by this fixture's
generic cell counters; the applied policy receipt and sustained native timings
bind the pressure workload, without inventing a pressure-cell count. Its higher
native cost therefore must be kept distinct from the sparse generic counters:

| OS / policy | Case mean visited cells per native tick, range | Case mean moved cells per native tick, range | Auto mean participants, range | Auto participant p95 | Auto max participants, range |
| --- | --- | --- | --- | ---: | --- |
| Linux / Current | 2.533–4.049 | 0.022–0.059 | 1.0122–1.0155 | 1 | 3–4 |
| Linux / pressure | 3.293–4.062 | 0.037–0.059 | 1.0144–1.0156 | 1 | 4–4 |
| Windows / Current | 2.533–4.049 | 0.022–0.059 | 1.0122–1.0144 | 1 | 3–4 |
| Windows / pressure | 5.365–5.519 | 0.078–0.080 | 1.0236–1.0237 | 1 | 4–4 |

Auto's capacity four and occasional observed participation three/four are not
scaling results: participant p95 was one, parallel-phase p95 was zero, and the
scheduler-job p95 ranged from one to four. The maxima were four parallel phases
and 26 jobs in a tick. The paired observations above do not establish a reliable
speedup. Sustained dense material/equipment activity and wider scheduler
participation remain a distinct workload qualification gap.

### Callback, publication and lifecycle measurements

Ranges below are the smallest and largest case values within each OS's 14
original cases. All durations are milliseconds. Reset completion is measured
from the original reset request observation and already includes synchronous
request work; the two must not be added together.

| Measurement | Linux | Windows |
| --- | --- | --- |
| Main callback p95 | 1.663–2.805 | 2.639–3.878 |
| Main callback maximum | 2.578–5.723 | 3.821–6.588 |
| Rapier step p95 | 0.125–0.203 | 0.144–0.255 |
| Rapier step maximum | 0.159–0.587 | 0.217–1.503 |
| Snapshot publication age p95 | 16.679–17.388 | 16.845–24.117 |
| Native observer collection p95 | 0.018–0.031 | 0.039–0.058 |
| Construction acknowledgement | 912.266–940.136 | 1391.224–1453.666 |
| Pause acknowledgement | 13.080–28.322 | 12.633–25.890 |
| Resume through native and Rapier progress | 22.431–35.715 | 22.648–50.169 |
| Rapid pause/resume synchronous revocation | 0.260–0.574 | 0.421–1.023 |
| Synchronous reset request | 70.161–75.375 | 129.551–137.004 |
| Complete reset installation | 882.920–930.486 | 1431.747–1485.329 |
| Shutdown including retirement | 65.512–94.859 | 56.390–78.987 |
| Worker join | 2.309–15.548 | 0.351–19.912 |

The snapshot acquisition mutex wait p95 was 0.001 ms in every case, with observed
maxima 0.246 ms on Linux and 0.502 ms on Windows. Critical-section p95 was also
0.001 ms; maxima were 0.021 and 0.041 ms. These measure only that snapshot mutex.
They are not a claim about all possible Main-thread locks.

The measured owner published 12,599 packets on Linux and 11,697 on Windows;
Main acquired 12,597 and 11,696 new packets, respectively. Native completion and
publication timestamps have different window boundaries, so these counts must
not be forced equal. Every consumed publication matched its exact retained
owner receipt, and the complete measured native inventory matched producer
completion receipts. Coalesced-publication serials and render-payload rejections
were zero in all 28 cases. No graphical draw was executed in these cohorts.

Retained render-payload age p95 was about 14.1–14.2 seconds while render revision
lag p95 was zero in every case and the largest lag was one revision. This is a
retained unchanged cell payload on a mostly settled course, not a 14-second-old
Main publication or evidence of displayed-frame freshness. Current immutable
publication age, render-payload age and revision lag remain separate raw fields.

### Original mandatory graphical failure

The first Acrobat/one-worker/Current graphical process returned exit 1 after
64.960 seconds, within the unchanged 180-second process bound. Its nine engine
assertions contained two failures: Main construction acknowledgement and its
original 30-second deadline. No acknowledgement timestamp was recorded, and the
waiting coroutine observed the failure 51.020961 seconds after the selection
request. It admitted zero input-tape events. The fixture joined its worker and
retired one session, then the campaign stopped with an incomplete case inventory.
The prior 240-second import passed in 5.811 seconds.

This source-matched run used X11 compatibility OpenGL with Mesa llvmpipe
(LLVM 20.1.2, 256 bits) on an AMD EPYC 7763 with four logical processors. The
failure class is **graphical Main-acknowledgement deadline exceeded**. No shader
or cache causal diagnosis, warmed retry, deadline extension or graphical
qualification follows from these results. The independent reducer refuses the
original failed campaign. No actor/terrain pixel controls, displayed FPS,
physical-device tests or human judgement are claimed.

### Local extraction anomaly and reproducibility

The first local extraction of the authentic Linux headless ZIP acquired one
unsealed temporary archive file absent from the original ZIP and its manifest.
Strict readback rejected that directory for its extra inventory entry. The
original source archive itself retained its correct 106,977,280-byte digest;
the extra file was 19,136,512 bytes, SHA-256
`fe7b569ad97b016b4548a4b8c6e74a366285006107cc9148ea242cf880bc898f`.
No writer or cause was established. Readback code only reads evidence; its
verify-only path does not call the source archive publisher. The ZIP, anomalous
directory, file metadata and failure receipt remain unchanged. A fresh unique
`/tmp` extraction of the same API-authenticated ZIP passed the complete strict
readback without ignoring files or changing a manifest. This repeated only
evidence readback, not an engine case or qualification attempt.

Local review records under `evidence/pace004-hosted-41175719451` retain the raw
ZIPs/catalogs, original job log and failed graphical extraction, the anomalous
Linux extraction, and reproducible `review_original_headless.py`. The derived
headless review SHA-256 is
`daf02961c796e850c018345326818451a4a19fbc1638fbf00058e00a3c653eca`;
the extraction-anomaly receipt SHA-256 is
`43c145c45c2a10b6f3126f696975016c3807aac61166169f01883bb34263d61e`.
These local receipts supplement the original Actions artifacts and do not
replace their source/process records.

Reproduce offline readback from an authenticated original ZIP in a fresh
extraction directory, using the verifier from the executed source:

```sh
python -m zipfile -e <original-headless-artifact.zip> <fresh-extraction>
python tools/play/run_pace004_campaign.py \
  --output <fresh-extraction>/campaign --verify-only \
  --expected-source-sha d464edc0a81b9e0ce343f878179d95c8c831245f
```

The ordinary Native/Godot jobs at this PR head were draft-skipped, not qualified.
The mandatory graphical gate remains failed. This evidence does not transfer to
later source changes, close #270, promote the PLAY epic, or replace the separate
physical-device, real OS focus, display and human-playability packet. All original
30/180/240-second and applicable 15/150-second bounds remain unchanged.

## Active-cell workload successor — development feasibility

The original fourteen-case results above expose a specific remaining gap:
settled Current courses and sparse generic cellular work do not qualify
sustained active-cell gameplay. A separate opt-in workload is being developed
on the reviewed immutable-publication UI007 base, without altering the original
source or relabeling those results. It extends this same PACE004 apparatus and
retains the original forty-event tape, actual shared Main, one native worker
owner and main-thread Rapier.

The initial development recipe requests a square 8-by-8 Sand footprint at
`(396,176)` and Water footprint at `(576,176)` every 100 milliseconds for the
existing 15-second measurement interval: 150 identified pulses, 300 identified
commands, no priming interval. Main uses the existing bounded
`queue_brush_footprint_mutation` path. The exclusive worker applies ordinary
queued paint and records small copied cell observations alongside actual
completed-tick statistics. Main reads owner-written observations only after
the existing join. A matched idle control retains the same scheduling,
observation and forty-event tape while explicitly skipping each paint request.

Every pulse records source recipe, original owner/control generation, exact
footprint, admission outcome and timestamps. Brush enqueue/observer cost is
separate from the production Main callback and native tick timing. Queue
admission is not an individual native application receipt: this production
queue has no such acknowledgement, and the apparatus must not fabricate one.
Actual source-bound cell activity and observed native cell values supply the
separate workload evidence.

This section registers development scope only. The workload's activity
thresholds and final version will be frozen after bounded local feasibility;
no active-load or comparative performance acceptance is claimed here. Local
feasibility may overlap a separately owned native build and therefore cannot
support performance comparisons. Original platform/graphical failures,
15-second operation, 150-second fixture, 30-second Main acknowledgement,
180-second case and 240-second import bounds remain unchanged. No production,
native, shader, solver-default or scientific-fixture source changes are part
of this package.

### Source-bound recipe feasibility and retained correction

Development source `f28810f53ae02b82a8aaa27562bc9c532750af3c`, tree
`1c653cff2927bca6f17df4198c90f85dd1a4ebda`, ran eight bounded actual-host
processes: Acrobat/1 and Jetbarrel/Auto, each with Current/pressure and explicit
active/idle modes. All eight retained the complete forty-event base reduction
and passed 832 engine assertions with zero engine failures. Source and both
materialized runtimes remained unchanged. The complete 107,008,000-byte source
archive passed commit/tree/blob/runtime verification before and after execution,
SHA-256 `32092dab674940bc0f66bfdd77479f4936880d1f032c5493303b15a9846196a0`.
The original development report SHA-256 is
`41f2754a8498019dfc526fdd3f3d4bc2f5c5c1a3d99f3753fd975d3d9fbbb028`.
Both use the same pinned Godot/native/Rapier objects already identified above.

| Development active case | Median visited cells/tick | Median moved cells/tick | Ticks with both kinds of activity | Matched idle medians |
|---|---:|---:|---:|---|
| Acrobat, one worker, Current | 8,028 | 4,079 | 100% | 0 visited / 0 moved |
| Acrobat, one worker, pressure | 5,853 | 3,760 | 100% | 0 / 0 |
| Jetbarrel, Auto, Current | 8,028 | 4,079 | 100% | 0 / 0 |
| Jetbarrel, Auto, pressure | 5,828 | 3,731 | 100% | 0 / 0 |

Each active process admitted all 300 ordinary requests and had measured cell
activity in all fifteen one-second buckets. Native-owned observations saw the
intended Sand/Water material and empty cells between pulses. Idle controls
issued zero requests, observed empty cells at both source positions and had
only 0.44–0.68% active ticks from course startup; fourteen of fifteen seconds had
no generic cell activity. Auto's observed participant p95 was four during these
loaded Jetbarrel cases and one during the idle controls. These local cases may
have overlapped an independently owned bounded native build, so they establish
recipe/activity feasibility, **not comparative performance or speedup**.

The provisional structural readback rejected the first pulse in all four
pressure-mode processes: Main controls had rearmed, but its latest native
receipt still reported paused tick zero. The original requests and subsequent
cell activity remain evidence; those processes are not promoted to a passing
frozen workload contract. The correction explicitly awaits an unpaused native
publication with completed tick greater than zero, under the existing
15-second operation bound, before beginning the opt-in measurement. It adds
no paint priming, fixed-time warmup or manual stepping. The producer also
refuses suspended/native-paused observations. Normal fourteen-case and graphical
cohorts retain their existing start contract.

The original local records are retained under
`build/pace004-active-feasibility/development-f28810f5`, with a separate
`evidence/pace004-active-feasibility/provisional-reducer-f28810f.json` receipt;
their original logs, source archive and manifests are not rewritten. The first
sandboxed import also remains failed because the editor could not open its
ordinary loopback socket or write default configuration. A succeeding bounded
import used permitted socket access and explicit local XDG paths, completing
in 3.823 seconds under the unchanged 240-second limit. This environment repair
does not qualify a graphical case.

### Frozen active workload contract: brush_rain_v1

The [brush helper](../../godot/tests/play_pace004_brush_load.gd) and
[independent load reducer](../../tools/play/pace004_load_contract.py) freeze the
following requirements after that development feasibility. Later failures
retain their exact source and cannot be repaired by lowering these thresholds.

- Exactly 150 sequential pulses and 300 individually identified commands in
  the original 15-second gameplay window; both 64-cell square footprints,
  materials, flags, coordinates and recipe hash must match source.
- Each pulse starts within its own 100-millisecond slot, after its observed
  Main callback, and finishes before the next callback. Its complete
  worker/session/bridge/run/epoch/world/control-generation tuple stays equal to
  the measurement owner and its native publication matches Main's retained
  source packet. Every active request is attempted and admitted; each matched
  idle request is explicitly unattempted, unadmitted and marked control-skipped.
- The complete measured native inventory must pass the original publication
  and statistics checks before load reduction. Median visited cells must be at
  least 64 and median moved cells at least 16; at least 75% of completed ticks
  must have both positive visited and moved counts.
- Each of the fifteen complete one-second buckets contains native completions,
  at least 64 visited and 16 moved cells in total, at least 75% active ticks and
  at least one observation of the intended material at each source position.
  Cell query coordinates and completed ticks bind to the real native row.
  These observed values are not individual application acknowledgements.
- The matched no-load process must first pass the same full forty-event and
  native/Rapier contract, then fail this exact activity predicate for recorded
  reasons. A failed, timed-out or incomplete process is not an adverse-control
  success. Active counters without moved cells, continuous activity or genuine
  intended-material observations fail.

The additional headless matrix is Acrobat/Jetbarrel × one/Auto ×
Current/pressure × active/idle: sixteen cases on each OS. It is separate from
the unchanged fourteen-case headless cohort and mandatory six-case Linux
graphical inventory. Dedicated GitHub-hosted jobs retain 35-minute job,
25-minute execution, 180-second process, 240-second import, 30-second Main and
15/150-second operation/fixture bounds. No Windows graphical pass is invented,
and the original failed cold Linux graphical run remains failed.

Production callback time, enqueue-call time, whole diagnostic-pulse time,
native tick time, base observer time and additional native cell-observer time
are reported separately. Main callback cadence includes the actual elapsed
diagnostic cost; configured capacity and observed task participants remain
different measurements. The 30 new offline adverse-control methods supplement
the original 61 methods, run in normal and optimized Python modes, and do not
replace fresh exact-source host execution.

Reproduce the additional complete registered headless cohort after source and
runtime checkout, using the pinned OS-specific engine archive:

```sh
python tools/play/run_pace004_campaign.py --active-workload \
  --godot-archive <pinned-engine-archive> --expected-source-sha <exact-head> \
  --output <new-evidence-directory>
python tools/play/run_pace004_campaign.py --verify-only \
  --expected-source-sha <exact-head> --output <new-evidence-directory>
```

This extension has no physical-device, real OS focus, display scanout, human
feel, shader or release acceptance claim. The complete source and resulting
platform evidence still require independent review and fresh hosted execution.

### First frozen local sixteen-case result — source898f8f2

The complete first local active/control cohort passed at exact source
`898f8f2344ec7e83c12665009bdbc96f3895c6a8`, tree
`0babc92c254974bec48b414a27803e5108c33a1b`: **sixteen actual processes,
1,680 assertions, zero failures**, followed by a passing independent sealed
CLI readback. All 640 identified input events reconcile to 464 applied,
96 cancelled and 80 refused outcomes. Every applied event joins its actual
admission generation and completed Rapier step. This result is local Linux
headless evidence; Windows and fresh hosted resulting-head gates remain open.

The eight active processes each admitted all 300 commands and observed positive
visited and moved counts in 100% of measured native ticks. All fifteen seconds
in each process met the frozen activity/material requirements. The eight
matched idle processes had zero median visited and moved cells and failed the
same active predicate for recorded cell-work/material reasons, while their
full input/native/Rapier contract passed. The new native-running acknowledgement
passed in every pressure case; the original development tick-zero observations
above remain unchanged.

| Loaded local rig/policy | Native completed Hz, one / Auto | Native tick p95 ms, one / Auto | Median visited cells, one / Auto | Median moved cells, one / Auto |
|---|---:|---:|---:|---:|
| Acrobat, Current | 59.997 / 59.999 | 13.239 / 9.695 | 8,021 / 8,021 | 4,095 / 4,091 |
| Acrobat, pressure | 40.198 / 44.443 | 30.162 / 24.889 | 5,472 / 5,963 | 3,548 / 3,787 |
| Jetbarrel, Current | 59.973 / 59.932 | 11.661 / 8.962 | 8,028 / 8,028 | 4,085 / 4,079 |
| Jetbarrel, pressure | 39.583 / 44.862 | 28.166 / 24.244 | 5,391 / 6,019 | 3,514 / 3,812 |

The local engine reported AMD EPYC 9V74, nine logical processors; Auto capacity
was four. Actual participant p95 was four in all loaded Auto processes and one
in their idle controls. The host may have been contended by other authorized
work and offline review. These are source-bound measurements, not an isolated
threading comparison or a speedup claim. The pressure cases visibly remained
below 60 completed native ticks per second. Actual Main callback maxima across
the cohort ranged from 6.283 to 58.501 milliseconds; passing workload custody
does not turn those stalls into a pacing target pass. No displayed-FPS value is
derived from this headless cohort.

Latency groups preserve their different populations. Across the eight loaded
processes, all 232 applied tape events had p95 32.951 milliseconds; the 112
nonneutral presses across the full tape had p95 19.969 milliseconds. The
measurement window itself contained exactly sixteen applied events and eight
nonneutral presses per process. Its 64 loaded nonneutral presses had p95
15.156 milliseconds and maximum 19.459 milliseconds. Later pause/focus/reset
events are excluded from that last population. Matched idle measurement
presses had p95 15.052 milliseconds and maximum 19.612 milliseconds. These
admission-to-completed-step timings do not measure physical-device or display
latency. Producer pulse p95 was 0.424–0.814 milliseconds for loaded cases;
additional native cell-observer p95 was 18–40 microseconds, outside native tick
timing. Full raw rows retain enqueue-call, observer, callback, snapshot and
lifecycle distributions separately.

Complete source/runtime custody covers 908 scoped inputs and both materialized
Linux runtime chains, unchanged before/after execution. The original records
are under `build/pace004-active-exact-898f8f23/campaign`:

- `executed-source.tar`: 107,048,960 bytes, SHA-256
  `07eacfff86bb435c83caa540b4e21fadfce5e0ae7e313c00fe139217a8b01990`.
- `manifest.json`: SHA-256
  `3bb2494e305b6c5e04537acc3c52403d83c1f9d39a1302dc18e29f40b8b1da7f`.
- `campaign.json`: SHA-256
  `b60e7abb778a145918868523322838eb3d00f398d3e1222c1aee7c9672f56147`.
- The derived local summary, including each distinct input-latency population,
  is `evidence/pace004-active-feasibility/frozen-local-summary-898f8f2.json`,
  SHA-256 `67beeb575feab4b8e02e87446fa9051f9978dc321e0c70a06ec886f6a390f4a4`.

The import completed in 4.977 seconds; the sixteen engine cases totaled 328.548
seconds, with each original case bound unchanged. An additional focused
ordinary `--workload=none` Acrobat case passed 103/0 in 20.549 seconds at the
same exact source. It retained all forty events and had no brush-cell query
fields in any native sample. Its sibling `normal-mode-smoke/receipt.json`
SHA-256 is `c36fac820d1335317d29673fc96347cd79080db1a4d56f8d1a40f0bc212d2e98`.
It supplements, and does not replace, the original fourteen-case hosted gate.

Independent source review passed all 91 controls in both Python modes (182
executions), receipt
`qualification-pace004-independent-review/control-run-receipt.json`, SHA-256
`59d01e2c76815bd278c8dbd30523ef0121749c3d15dd6d8652d8eb9245cf2775`.
Twelve additional in-memory mutations of actual frozen-source active/idle
results rejected for their intended reasons: missing/duplicate pulses or
commands, stale generation/cell observations, queue refusal, late scheduling,
dropped native interval endpoints, zero motion, absent intended material and
idle-as-active relabeling. The original files were untouched; the adverse
receipt SHA-256 is
`1a428b00fcb3333ab0447dcec68d42462b5e963b93bf246658326cc9d00ac15c`.

A separate agent independently reduced the complete original sixteen-case
campaign into fresh review files. All 38 retained files, 908 inputs, runtime
chains, process identities, 13,000 native completions, 2,400 active brush
admissions and complete event inventories passed; original archive, manifest
and campaign hashes remained unchanged. All 224 admitted nonneutral presses
joined later completed Rapier steps in the same control generation. Every idle
control failed the median visited, median moved and active-fraction criteria,
not merely a label or missing-file check. The independent readback receipt
SHA-256 is `dab39060445f7c96cd71b0284eb2709e0799c8f43bcfdf84ac02d4bfb29ae598`;
the full reduction is
`de2f2e76efb02adf327ff9bd8263e477903d2216f68e2785829fad0adbded298`, and its
additional physical/workload inspection is
`6ccf7608b025ff87c6e171ca7d0c753e3f557aa14d16e37a4019c677d71f2d57`.
They are retained under
`qualification-pace004-independent-review/active-898f8f2`; no engine rerun or
original artifact write occurred during that review.

The same independent source review found no additional blocking ownership,
complete-inventory or workflow-composition issue. Documentation, current
repository identity, historical M11 retention, CI provider policy and retrieval
checks passed; retrieval retained 32/32 canonical top-k hits, 19 top-one hits
and MRR 0.7536. This local result does not transfer automatically to a later
integration head, remove the original graphical failure or justify merging
before all applicable fresh hosted and final review gates are satisfied.
